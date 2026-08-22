#!/usr/bin/env bash
# Validate (and optionally reserve) one chronological reviewer/evaluator launch.
set -euo pipefail

fail() {
  printf 'REVIEW_CONTEXT_%s: %s\n' "$1" "$2" >&2
  exit 1
}

[[ $# -eq 2 || ( $# -eq 3 && $3 == --reserve ) ]] ||
  fail USAGE 'usage: validate-review-context-set.sh <manifest> <repository-root> [--reserve]'

manifest=$1
repository_root=$2
reserve=false
[[ ${3:-} == --reserve ]] && reserve=true

command -v jq >/dev/null 2>&1 ||
  fail RUNTIME 'deterministic-runtime-unavailable: jq'
[[ -f "$manifest" && ! -L "$manifest" ]] ||
  fail MANIFEST 'manifest is missing or is not a regular file'
[[ -d "$repository_root" ]] ||
  fail PATH 'repository root is missing'
repository_root=$(cd "$repository_root" && pwd -P) ||
  fail PATH 'repository root cannot be resolved'

sha256_file() {
  local path=$1
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
  else
    fail RUNTIME 'deterministic-runtime-unavailable: SHA-256'
  fi
}

sha256_text() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    fail RUNTIME 'deterministic-runtime-unavailable: SHA-256'
  fi
}

is_canonical_path() {
  local path=$1
  [[ "$path" =~ ^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$ ]] &&
    [[ "$path" != /* ]] &&
    [[ "$path" != *\\* ]] &&
    [[ ! "$path" =~ (^|/)\.\.?(/|$) ]] &&
    [[ ! "$path" =~ ^[A-Za-z]: ]]
}

is_forbidden_review_output() {
  local path=$1
  [[ "$path" =~ ^reports/(spec|impl|task)-review/.*/reviewer-[^/]*\.json$ ]] ||
    [[ "$path" =~ (^|/)reviewer-[ab]\.json$ ]]
}

# WFI-036. A declaration channel is one markdown document plus one section
# heading. Two channels exist: the frozen implementation report's `## Outputs`
# table, and -- only when the manifest explicitly names and hash-pins one --
# the gate report's `## Post-Fix Artifacts` table. Both are matched by exact
# row equality, so both are hash-checked identically.
evaluator_output_is_declared() {
  local path=$1 expected_hash=$2 report=$3 heading=$4
  awk -v expected_path="$path" -v expected_hash="$expected_hash" -v heading="$heading" '
    index($0, heading) == 1 && substr($0, length(heading) + 1) ~ /^[[:space:]]*$/ {
      in_outputs = 1
      next
    }
    in_outputs && /^##[[:space:]]/ { exit }
    in_outputs {
      expected_line = "| `" expected_path "` | `" expected_hash "` |"
      if ($0 == expected_line) found = 1
    }
    END { exit(found ? 0 : 1) }
  ' "$report"
}

# WFI-017 ratified a SECOND serialization for the implementation report's own
# declaration -- the legacy `## Output Paths And Hashes` bullet section --
# "retained solely so previously committed bullet-only and dual-form v2 reports
# remain valid" (validate-implementation-report.sh:113-119). That acceptance
# landed on the report contract and never on this authorization boundary, so a
# report the repository considers valid could declare artifacts this validator
# could not read, and the task became ungateable through no fault of its own.
#
# The grammar below is a byte-for-byte mirror of the pattern that script already
# enforces (its output_pattern at :167-170); nothing is invented here. Only the
# serialization differs -- the path/hash pair is still matched by exact equality
# and the live file is still re-hashed afterwards by the caller, so this admits
# no artifact the table form would not have admitted.
#
# Scoped to the implementation report on purpose: the gate report's post-fix
# channel (WFI-036) defines its own table form and gains no legacy grammar.
implementation_report_legacy_declares() {
  local path=$1 expected_hash=$2 report=$3
  awk -v expected_path="$path" -v expected_hash="$expected_hash" '
    index($0, "## Output Paths And Hashes") == 1 &&
      substr($0, length("## Output Paths And Hashes") + 1) ~ /^[[:space:]]*$/ {
      in_legacy = 1
      next
    }
    in_legacy && /^##[[:space:]]/ { exit }
    in_legacy {
      line = $0
      sub(/[[:space:]]+$/, "", line)
      expected_line = "- **Path**: `" expected_path "`; **SHA-256**: `" expected_hash "`"
      if (line == expected_line) found = 1
    }
    END { exit(found ? 0 : 1) }
  ' "$report"
}

# WFI-036 second channel. Consulted only when the manifest named a gate report
# AND that document's own live SHA-256 already matched the pinned value -- that
# verification happens in the quality:sdd-evaluator block below, before any row
# here is read. Nothing is scanned or discovered: an unnamed, undeclared or
# stale gate report authorizes nothing.
#
# A gate report never authorizes another gate report. Post-fix artifacts are
# source, test and evidence files; handing an evaluator a prior verdict would
# defeat the fresh-context requirement it is launched under.
gate_report_output_is_declared() {
  local path=$1 expected_hash=$2
  [[ -n "$gate_report_declaration_path" ]] || return 1
  [[ "$path" != reports/quality-gate/* ]] || return 1
  evaluator_output_is_declared "$path" "$expected_hash" \
    "$repository_root/$gate_report_declaration_path" '## Post-Fix Artifacts'
}

path_is_authorized() {
  local stage=$1 role=$2 feature=$3 path=$4 expected_hash=$5
  case "$stage:$role" in
    spec:spec-reviewer-a|spec:spec-reviewer-b)
      [[ "$path" =~ ^specs/"$feature"/(requirements|acceptance-tests|investigation)\.md$ ]] ||
        [[ "$path" == plugins/sdd-review-loop/references/spec-review-calibration.md ]] ||
        [[ "$path" =~ ^reports/spec-review/"$feature"/attempt-[1-9][0-9]*/round-[1-9][0-9]*/precheck-result\.json$ ]] ||
        { [[ "$role" == spec-reviewer-b ]] &&
          [[ "$path" =~ ^reports/spec-review/"$feature"/attempt-[1-9][0-9]*/round-[1-9][0-9]*/integrated-summary\.json$ ]]; }
      ;;
    impl:impl-reviewer-a|impl:impl-reviewer-b)
      # Issue #143: impl-review-precheck requires impl-reviewer-a to carry the
      # PREVIOUS round's integrated-summary.json when round > 1 (see
      # impl-review-precheck.sh allowed_input + require_persisted_pass), so the
      # summary must be authorized for both reviewer roles here. Without this,
      # reviewer-a's required input is rejected as role-unlisted and impl-review
      # can never pass at round > 1. The precheck contract still pins reviewer-a
      # to the exact previous round, so this remains defense-in-depth.
      [[ "$path" =~ ^specs/"$feature"/(requirements|acceptance-tests|design|investigation|ux-spec|frontend-spec|infra-spec|security-spec)\.md$ ]] ||
        [[ "$path" == plugins/sdd-review-loop/references/reviewer-calibration.md ]] ||
        [[ "$path" =~ ^reports/impl-review/"$feature"/attempt-[1-9][0-9]*/round-[1-9][0-9]*/precheck-result\.json$ ]] ||
        [[ "$path" =~ ^reports/impl-review/"$feature"/attempt-[1-9][0-9]*/round-[1-9][0-9]*/integrated-summary\.json$ ]]
      ;;
    task:task-reviewer-a|task:task-reviewer-b)
      [[ "$path" =~ ^specs/"$feature"/(requirements|acceptance-tests|design|tasks|traceability|ux-spec|frontend-spec|infra-spec|security-spec)\.md$ ]] ||
        [[ "$path" == plugins/sdd-review-loop/references/reviewer-calibration.md ]] ||
        { [[ "$role" == task-reviewer-b ]] &&
          [[ "$path" =~ ^plugins/sdd-quality-loop/references/(risk-gate-matrix|risk-classification-policy)\.md$ ]]; } ||
        [[ "$path" =~ ^reports/task-review/"$feature"/attempt-[1-9][0-9]*/round-[1-9][0-9]*/precheck-result\.json$ ]] ||
        { [[ "$role" == task-reviewer-a ]] &&
          [[ "$path" =~ ^reports/task-review/"$feature"/attempt-[1-9][0-9]*/round-[1-9][0-9]*/dependency-graph\.json$ ]]; } ||
        { [[ "$role" == task-reviewer-b ]] &&
          [[ "$path" =~ ^reports/task-review/"$feature"/attempt-[1-9][0-9]*/round-[1-9][0-9]*/integrated-summary\.json$ ]]; }
      ;;
    quality:sdd-evaluator)
      [[ "$path" =~ ^specs/"$feature"/(requirements|acceptance-tests|design|tasks|traceability|baseline-behavior|ux-spec|frontend-spec|infra-spec|security-spec)\.(md|json)$ ]] ||
        [[ "$path" == plugins/sdd-quality-loop/references/quality-gate-calibration.md ]] ||
        [[ "$path" == "$implementation_report_path" ]] ||
        evaluator_output_is_declared \
          "$path" "$expected_hash" \
          "$repository_root/$implementation_report_path" '## Outputs' ||
        implementation_report_legacy_declares \
          "$path" "$expected_hash" \
          "$repository_root/$implementation_report_path" ||
        gate_report_output_is_declared "$path" "$expected_hash"
      ;;
    domain:domain-reviewer-a|domain:domain-reviewer-b)
      [[ "$path" =~ ^domain/(domain-story|event-storming|ubiquitous-language|context-map|message-flow|c4-container)\.md$ ]] ||
        [[ "$path" =~ ^domain/aggregates/[^/]+\.md$ ]] ||
        [[ "$path" == domain/domain-contract.json ]] ||
        [[ "$path" == plugins/sdd-domain/references/domain-review-calibration.md ]] ||
        [[ "$path" =~ ^reports/domain-review/attempt-[1-9][0-9]*/round-[1-9][0-9]*/precheck-result\.json$ ]] ||
        { [[ "$role" == domain-reviewer-b ]] &&
          [[ "$path" =~ ^reports/domain-review/attempt-[1-9][0-9]*/round-[1-9][0-9]*/integrated-summary\.json$ ]]; }
      ;;
    *) return 1 ;;
  esac
}

# WFI-025: the STATUS-NORMALIZED task-plan digest — byte-for-byte the same
# recipe as check-workflow-state.sh normalized_hash() for the task stage
# (canonical form 1). The one scoped exception to the raw hash-equality rule
# below is defined over exactly the fields this normalization rewrites.
tasks_normalized_hash() {
  local file="$1" cr=""
  LC_ALL=C grep -q $'^Task-Review-Status:.*\r$' "$file" && cr=$'\r'
  sed \
    -e "s/^Task-Review-Status:[[:space:]]*.*/Task-Review-Status: Pending${cr}/" \
    -e "s/^Approval:[[:space:]]*.*/Approval: Draft${cr}/" \
    -e "s/^Status:[[:space:]]*.*/Status: Planned${cr}/" \
    -e "/^Second Approval:/d" "$file" | sha256_text
}

jq -e . "$manifest" >/dev/null 2>&1 ||
  fail JSON 'manifest is not valid JSON'

jq -e '
  def base_keys: [
    "allowed_input_manifest",
    "fallback_mode",
    "feature",
    "host_session_id",
    "identity_ledger_path",
    "identity_ledger_sha256",
    "input_mode",
    "previous_record_sha256",
    "read_only",
    "role",
    "run_id",
    "schema",
    "sequence",
    "stage"
  ];
  type == "object" and
  (
    (.stage == "quality" and
      (((keys | sort) == ((base_keys + ["task_id"]) | sort)) or
        ((keys | sort) ==
          ((base_keys + ["task_id", "gate_report_declaration"]) | sort))) and
      (.task_id | type == "string" and test("^T-[0-9]{3}$")) and
      (if has("gate_report_declaration") then
        (.gate_report_declaration |
          type == "object" and
          ((keys | sort) == ["path", "sha256"]) and
          (.path | type == "string" and length > 0) and
          (.sha256 | type == "string" and test("^[0-9a-f]{64}$")))
      else true end)) or
    (.stage != "quality" and ((keys | sort) == (base_keys | sort)))
  ) and
  .schema == "review-context-invocation/v2" and
  .input_mode == "file-manifest" and
  .fallback_mode == "none" and
  .read_only == true and
  (.feature | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$")) and
  (.sequence | type == "number" and floor == . and . >= 2) and
  (.identity_ledger_path == "reports/review-context/identity-ledger.json") and
  (.identity_ledger_sha256 | type == "string" and test("^[0-9a-f]{64}$")) and
  (.previous_record_sha256 | type == "string" and test("^[0-9a-f]{64}$")) and
  (.allowed_input_manifest | type == "array" and length > 0) and
  all(.allowed_input_manifest[];
    type == "object" and
    ((keys | sort) == ["path", "sha256"]) and
    (.path | type == "string" and length > 0) and
    (.sha256 | type == "string" and test("^[0-9a-f]{64}$"))
  ) and
  ([.allowed_input_manifest[].path] | unique | length) ==
    (.allowed_input_manifest | length)
' "$manifest" >/dev/null 2>&1 ||
  fail CONTRACT 'required fields, file-manifest input, read-only mode, or no-fallback contract is invalid'

stage=$(jq -r '.stage' "$manifest" | tr -d '\r')
role=$(jq -r '.role' "$manifest" | tr -d '\r')
feature=$(jq -r '.feature' "$manifest" | tr -d '\r')
run_id=$(jq -r '.run_id' "$manifest" | tr -d '\r')
host_session_id=$(jq -r '.host_session_id' "$manifest" | tr -d '\r')
sequence=$(jq -r '.sequence' "$manifest" | tr -d '\r')
previous_record_sha256=$(jq -r '.previous_record_sha256' "$manifest" | tr -d '\r')
bound_ledger_sha256=$(jq -r '.identity_ledger_sha256' "$manifest" | tr -d '\r')
task_id=''
[[ "$stage" == quality ]] && task_id=$(jq -r '.task_id' "$manifest" | tr -d '\r')
# WFI-036. Optional, quality-only, and inert unless present: the contract check
# above rejects the key outright on any other stage.
gate_report_declaration_path=''
gate_report_declaration_sha256=''
if [[ "$stage" == quality ]] &&
  jq -e 'has("gate_report_declaration")' "$manifest" >/dev/null 2>&1; then
  gate_report_declaration_path=$(jq -r '.gate_report_declaration.path' "$manifest" | tr -d '\r')
  gate_report_declaration_sha256=$(jq -r '.gate_report_declaration.sha256' "$manifest" | tr -d '\r')
fi

case "$stage:$role" in
  spec:spec-reviewer-a|spec:spec-reviewer-b|impl:impl-reviewer-a|impl:impl-reviewer-b|task:task-reviewer-a|task:task-reviewer-b|quality:sdd-evaluator|domain:domain-reviewer-a|domain:domain-reviewer-b) ;;
  *) fail CONTRACT 'stage and role are not an authorized invocation pair' ;;
esac
[[ "$run_id" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]] ||
  fail IDENTITY 'run ID must be a nonblank canonical identifier'
[[ "$host_session_id" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]] ||
  fail IDENTITY 'host-session ID must be a nonblank canonical identifier'

ledger="$repository_root/reports/review-context/identity-ledger.json"
ledger_component="$repository_root"
for component in reports review-context identity-ledger.json; do
  ledger_component="$ledger_component/$component"
  [[ ! -L "$ledger_component" ]] ||
    fail IDENTITY 'canonical identity ledger traverses a symbolic link'
done
[[ -f "$ledger" && ! -L "$ledger" ]] ||
  fail IDENTITY 'canonical identity ledger is missing or is not a regular file'
# NOTE: identity_ledger_sha256 is only meaningful for a reservation (the
# ledger state a reservation is validated against, before it appends). It is
# NOT checked here unconditionally -- see the reservation/verification
# branch below, which is the only place this comparison is enforced.
actual_ledger_sha256=$(sha256_file "$ledger")
jq -e '
  type == "object" and
  ((keys | sort) == ["records", "schema"]) and
  .schema == "review-identity-ledger/v1" and
  (.records | type == "array" and length > 0) and
  all(.records[];
    type == "object" and
    ((keys | sort) == ([
      "host_session_id",
      "previous_record_sha256",
      "record_sha256",
      "role",
      "run_id",
      "sequence",
      "stage"
    ] | sort)) and
    (.sequence | type == "number" and floor == . and . > 0) and
    (.stage | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._:-]*$")) and
    (.role | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._:-]*$")) and
    (.run_id | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._:-]*$")) and
    (.host_session_id | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._:-]*$")) and
    (.previous_record_sha256 | type == "string" and test("^$|^[0-9a-f]{64}$")) and
    (.record_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
  ) and
  ([.records[].run_id] | unique | length) == (.records | length) and
  ([.records[].host_session_id] | unique | length) == (.records | length)
' "$ledger" >/dev/null 2>&1 ||
  fail IDENTITY 'canonical identity ledger contract is invalid'

expected_sequence=1
expected_previous=''
while IFS=$'\t' read -r record_sequence record_stage record_role record_run record_session record_previous record_hash; do
  [[ "$record_previous" == - ]] && record_previous=''
  [[ "$record_sequence" -eq "$expected_sequence" && "$record_previous" == "$expected_previous" ]] ||
    fail IDENTITY 'canonical identity ledger chain is discontinuous'
  computed_hash=$(printf '%s' "$record_sequence|$record_stage|$record_role|$record_run|$record_session|$record_previous" | sha256_text)
  [[ "$computed_hash" == "$record_hash" ]] ||
    fail IDENTITY 'canonical identity ledger record hash is invalid'
  expected_previous=$record_hash
  expected_sequence=$((expected_sequence + 1))
done < <(jq -r '.records[] | [
  .sequence,
  .stage,
  .role,
  .run_id,
  .host_session_id,
  (if .previous_record_sha256 == "" then "-" else .previous_record_sha256 end),
  .record_sha256
] | @tsv' "$ledger" | tr -d '\r')

# A manifest describes either an identity not yet in the ledger (a
# reservation) or an identity whose record is already persisted (a
# verification of a prior reservation -- possibly with later records now
# chained on top of it, e.g. a branch merge/re-chain). The ledger itself
# disambiguates which case this is: an identity is "reserved" once some
# record's run_id AND host_session_id both match the manifest's. That, not
# the --reserve flag, decides which checks below apply.
persisted_match=$(jq -c --arg run "$run_id" --arg session "$host_session_id" '
  [.records[] | select(.run_id == $run and .host_session_id == $session)] | .[0] // empty
' "$ledger")

if [[ -n "$persisted_match" ]]; then
  # Verification of an already-reserved identity. The persisted record is
  # authoritative and must match the manifest exactly on every identity
  # field; its own record_sha256 was already proven to recompute correctly
  # by the whole-ledger chain walk above, which runs unconditionally. The
  # tip position and identity_ledger_sha256 are NOT re-checked here: both
  # are meaningless once later records may have landed on top of this one.
  if $reserve; then
    fail IDENTITY 'run and host-session identity are already persisted in the canonical identity ledger; an identity cannot be reserved twice'
  fi
  persisted_sequence=$(jq -r '.sequence' <<<"$persisted_match")
  persisted_stage=$(jq -r '.stage' <<<"$persisted_match")
  persisted_role=$(jq -r '.role' <<<"$persisted_match")
  persisted_previous=$(jq -r '.previous_record_sha256' <<<"$persisted_match")
  [[ "$persisted_sequence" -eq "$sequence" ]] ||
    fail IDENTITY 'invocation sequence does not match the persisted identity-ledger record'
  [[ "$persisted_stage" == "$stage" ]] ||
    fail IDENTITY 'invocation stage does not match the persisted identity-ledger record'
  [[ "$persisted_role" == "$role" ]] ||
    fail IDENTITY 'invocation role does not match the persisted identity-ledger record'
  [[ "$persisted_previous" == "$previous_record_sha256" ]] ||
    fail IDENTITY 'invocation previous-record hash does not match the persisted identity-ledger record'
  # WFI-037: the uniqueness the REVIEW_CONTEXT_OK line asserts must be
  # proven in this branch too, not inherited from the reserve path.
  persisted_count=$(jq -r --arg run "$run_id" --arg session "$host_session_id" '
    [.records[] | select(.run_id == $run and .host_session_id == $session)] | length
  ' "$ledger")
  [[ "$persisted_count" -eq 1 ]] ||
    fail IDENTITY 'run and host-session identity appears more than once in the canonical identity ledger'
  # Tip position is meaningless for a persisted verification (see above), so
  # the emitted chain fact says so explicitly.
  pre_append_tip_sequence='-'
else
  # A partial match -- one of the two identity fields already persisted
  # under a DIFFERENT value for the other -- means two different launches
  # are colliding on one identity. That is never valid, in either mode, so
  # it fails loudly here rather than silently falling into reservation mode.
  if jq -e --arg run "$run_id" --arg session "$host_session_id" '
    any(.records[]; .run_id == $run and .host_session_id != $session)
  ' "$ledger" >/dev/null 2>&1; then
    fail IDENTITY 'run ID matches a persisted identity-ledger record but host-session ID does not: two launches are colliding on one identity'
  fi
  if jq -e --arg run "$run_id" --arg session "$host_session_id" '
    any(.records[]; .host_session_id == $session and .run_id != $run)
  ' "$ledger" >/dev/null 2>&1; then
    fail IDENTITY 'host-session ID matches a persisted identity-ledger record but run ID does not: two launches are colliding on one identity'
  fi

  # Reservation of a new identity: today's behaviour, unchanged.
  [[ "$actual_ledger_sha256" == "$bound_ledger_sha256" ]] ||
    fail IDENTITY 'canonical identity ledger hash is stale or mismatched'
  [[ "$sequence" -eq "$expected_sequence" && "$previous_record_sha256" == "$expected_previous" ]] ||
    fail IDENTITY 'invocation does not extend the canonical identity ledger'
  # WFI-037: the record extends the pre-append tip, proven just above.
  pre_append_tip_sequence=$((expected_sequence - 1))
fi

implementation_report_path=''
if [[ "$stage:$role" == quality:sdd-evaluator ]]; then
  implementation_report_count=0
  while IFS= read -r candidate_report; do
    if [[ "$candidate_report" == "reports/implementation/$feature/$task_id.md" ]]; then
      implementation_report_path=$candidate_report
      implementation_report_count=$((implementation_report_count + 1))
    fi
  done < <(jq -r '.allowed_input_manifest[].path' "$manifest" | tr -d '\r')
  [[ "$implementation_report_count" -eq 1 ]] ||
    fail PATH 'sdd-evaluator requires the current task implementation report'
  [[ "$(sed -n '1p' "$repository_root/$implementation_report_path")" == "# Implementation Report: $task_id" ]] ||
    fail PATH 'sdd-evaluator implementation report heading does not match task ID'
  grep -Fxq -- "- Task ID: $task_id" "$repository_root/$implementation_report_path" ||
    fail PATH 'sdd-evaluator implementation report task field does not match task ID'

  # WFI-036. The named gate report is a declaration source, not a manifest
  # input. It is verified in full here -- canonical path, confined to the gate's
  # own report namespace, no symlink component, regular file, and byte-exact
  # SHA-256 against the pinned value -- before a single table row is read from
  # it during authorization below.
  if [[ -n "$gate_report_declaration_path" ]]; then
    is_canonical_path "$gate_report_declaration_path" ||
      fail PATH "sdd-evaluator gate-report declaration is not a canonical repository-relative path: $gate_report_declaration_path"
    [[ "$gate_report_declaration_path" =~ ^reports/quality-gate/[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*\.md$ ]] ||
      fail PATH "sdd-evaluator gate-report declaration is not a quality-gate report: $gate_report_declaration_path"
    gate_report_component="$repository_root"
    IFS='/' read -r -a gate_report_components <<< "$gate_report_declaration_path"
    for component in "${gate_report_components[@]}"; do
      gate_report_component="$gate_report_component/$component"
      [[ ! -L "$gate_report_component" ]] ||
        fail PATH "sdd-evaluator gate-report declaration traverses a symbolic link: $gate_report_declaration_path"
    done
    gate_report_absolute="$repository_root/$gate_report_declaration_path"
    [[ -f "$gate_report_absolute" && ! -L "$gate_report_absolute" ]] ||
      fail PATH "sdd-evaluator gate-report declaration is missing or is not a regular file: $gate_report_declaration_path"
    [[ "$(sha256_file "$gate_report_absolute")" == "$gate_report_declaration_sha256" ]] ||
      fail HASH "sdd-evaluator gate-report declaration hash mismatch: $gate_report_declaration_path"
  fi
fi

# Located before the manifest-entry loop: the WFI-025 task-plan exception
# inside the loop cross-checks the round's precheck record. The precheck
# entry's own raw-hash verification still runs in the loop, so a tampered
# precheck cannot buy a reservation — any mismatch fails the whole run.
precheck_rel=$(jq -r '
  .allowed_input_manifest[].path
  | select(test("^reports/(spec|impl|task)-review/[^/]+/attempt-[1-9][0-9]*/round-[1-9][0-9]*/precheck-result\\.json$"))
' "$manifest" | tr -d '\r' | head -1)
precheck_abs=''
[[ -n "$precheck_rel" ]] && precheck_abs="$repository_root/$precheck_rel"

while IFS=$'\t' read -r path expected_hash; do
  is_canonical_path "$path" ||
    fail PATH "$role contains a non-canonical repository-relative path: $path"
  is_forbidden_review_output "$path" &&
    fail PATH "$role contains a forbidden raw reviewer report: $path"
  path_is_authorized "$stage" "$role" "$feature" "$path" "$expected_hash" ||
    fail PATH "$role contains a real but role-unlisted path: $path"

  candidate="$repository_root/$path"
  current="$repository_root"
  IFS='/' read -r -a components <<< "$path"
  for component in "${components[@]}"; do
    current="$current/$component"
    [[ ! -L "$current" ]] ||
      fail PATH "$role input traverses a symbolic link: $path"
  done
  [[ ! -L "$candidate" && -f "$candidate" ]] ||
    fail PATH "$role contains a missing or non-regular input: $path"
  actual_hash=$(sha256_file "$candidate")
  if [[ "$actual_hash" != "$expected_hash" ]]; then
    # WFI-025: the ONE scoped exception to the raw-equality rule. A
    # task-stage manifest may declare the task plan's normalized digest, but
    # only when the same round's precheck declares tasks_sha256_form:
    # normalized AND pinned exactly this digest AND the live file still
    # normalizes to it — the entry keeps binding every byte outside the
    # lifecycle fields. Every other entry keeps the strict raw requirement.
    if [[ "$stage" == task && "$path" == "specs/$feature/tasks.md" &&
          -n "$precheck_abs" && -f "$precheck_abs" && ! -L "$precheck_abs" ]]; then
      [[ "$(jq -r '.tasks_sha256_form // "raw"' "$precheck_abs" | tr -d '\r')" == normalized ]] ||
        fail HASH "$role hash mismatch: $path"
      [[ "$expected_hash" == "$(jq -r '.tasks_sha256 // empty' "$precheck_abs" | tr -d '\r')" ]] ||
        fail HASH "$role hash mismatch: $path (a normalized task-plan digest must be the one this round's precheck recorded)"
      [[ "$(tasks_normalized_hash "$candidate")" == "$expected_hash" ]] ||
        fail HASH "$role hash mismatch: $path (the live task plan does not normalize to the declared digest)"
    else
      fail HASH "$role hash mismatch: $path"
    fi
  fi
done < <(jq -r '.allowed_input_manifest[] | [.path, .sha256] | @tsv' "$manifest" | tr -d '\r')

# Round consistency. A manifest freezes hashes at reservation time; the round's
# precheck-result.json froze them when the round opened. If the two disagree, a
# reviewed document changed between the precheck and this reservation, so the two
# reviewers of one round would be judging different text. Precheck replay is
# forbidden, so that state is unrecoverable once a reviewer has run -- refuse the
# reservation now rather than discovering it a round later.
if [[ -n "$precheck_rel" ]]; then
  if [[ -f "$precheck_abs" && ! -L "$precheck_abs" ]]; then
    while IFS=$'\t' read -r pinned_path pinned_hash; do
      [[ -n "$pinned_path" ]] || continue
      manifest_hash=$(jq -r --arg p "$pinned_path" '
        .allowed_input_manifest[] | select(.path == $p) | .sha256
      ' "$manifest" | tr -d '\r' | head -1)
      [[ -n "$manifest_hash" ]] || continue
      [[ "$manifest_hash" == "$pinned_hash" ]] ||
        fail ROUND "manifest freezes $pinned_path at a hash this round's precheck did not pin: the document changed mid-round"
    done < <(jq -r --arg f "$feature" '
      [ {p: ("specs/" + $f + "/requirements.md"),     h: .requirements_sha256},
        {p: ("specs/" + $f + "/acceptance-tests.md"), h: .acceptance_sha256},
        {p: ("specs/" + $f + "/design.md"),           h: .design_sha256},
        {p: ("specs/" + $f + "/tasks.md"),            h: .tasks_sha256},
        {p: ("specs/" + $f + "/traceability.json"),   h: .traceability_sha256} ]
      + [ ((.layer_sha256 // {}) | to_entries[]) | {p: ("specs/" + $f + "/" + .key), h: .value} ]
      | .[]
      | select((.h | type) == "string" and (.h | test("^[0-9a-f]{64}$")))
      | [.p, .h] | @tsv
    ' "$precheck_abs" | tr -d '\r')
  fi
fi

record_hash=$(printf '%s' "$sequence|$stage|$role|$run_id|$host_session_id|$previous_record_sha256" | sha256_text)
if $reserve; then
  lock_dir="$ledger.lock"
  mkdir "$lock_dir" 2>/dev/null ||
    fail IDENTITY 'canonical identity ledger reservation is already in progress'
  trap 'rm -f "${temp_ledger:-}"; rmdir "${lock_dir:-}" 2>/dev/null || true' EXIT
  [[ "$(sha256_file "$ledger")" == "$bound_ledger_sha256" ]] ||
    fail IDENTITY 'canonical identity ledger changed before reservation'
  ledger_dir=$(dirname "$ledger")
  temp_ledger=$(mktemp "$ledger_dir/.identity-ledger.XXXXXX") ||
    fail IO 'cannot create identity-ledger transaction'
  jq \
    --arg stage "$stage" --arg role "$role" --arg run "$run_id" \
    --arg session "$host_session_id" --arg previous "$previous_record_sha256" \
    --arg hash "$record_hash" --argjson sequence "$sequence" \
    '.records += [{
      sequence:$sequence,
      stage:$stage,
      role:$role,
      run_id:$run,
      host_session_id:$session,
      previous_record_sha256:$previous,
      record_sha256:$hash
    }]' "$ledger" > "$temp_ledger" ||
    fail IO 'cannot stage identity-ledger reservation'
  mv "$temp_ledger" "$ledger" ||
    fail IO 'cannot publish identity-ledger reservation'
  rmdir "$lock_dir" ||
    fail IO 'cannot release identity-ledger reservation'
  trap - EXIT
fi

# WFI-037: the OK line carries the chain facts a launched role needs to
# verify its own identity WITHOUT reading the ledger (which no role's
# manifest may authorize): the reserved record's sequence, the
# previous-record hash the record chains from, the pre-append tip sequence
# ('-' when verifying an already-persisted identity, where tip position is
# meaningless), and the uniqueness assertion for the run/session ids —
# every one proven by a fail-closed check above before this line prints.
printf 'REVIEW_CONTEXT_OK %s sequence=%s previous_record_sha256=%s pre_append_tip_sequence=%s identity_unique=yes\n' \
  "$record_hash" "$sequence" "${previous_record_sha256:--}" "$pre_append_tip_sequence"
