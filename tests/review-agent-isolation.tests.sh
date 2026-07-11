#!/usr/bin/env bash
# T-005: every reviewer/evaluator launch has a sequential, persisted boundary.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_GIT_ROOT="${T005_SOURCE_GIT_ROOT:-$ROOT}"
AGENTS="$ROOT/plugins/sdd-review-loop/agents"
EVALUATOR="$ROOT/plugins/sdd-quality-loop/agents/evaluator.md"
QUALITY_GATE="$ROOT/plugins/sdd-quality-loop/skills/quality-gate/SKILL.md"
VALIDATOR_SH="$ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
VALIDATOR_PS1="$ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"
fail() { printf 'not ok: %s\n' "$1" >&2; exit 1; }
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

for stage in spec impl task; do
  skill="$ROOT/plugins/sdd-review-loop/skills/${stage}-review-loop/SKILL.md"
  [[ -f "$skill" ]] || fail "missing ${stage} review skill"
  grep -Fq 'validate-review-context-set' "$skill" ||
    fail "${stage} review skill must invoke the deterministic launch boundary"
  grep -Fq -- '--reserve' "$skill" ||
    fail "${stage} review skill must reserve identity before each launch"
  for reviewer in a b; do
    file="$AGENTS/${stage}-reviewer-${reviewer}.md"
    [[ -f "$file" ]] || fail "missing ${stage} reviewer ${reviewer}"
    grep -Fq "name: ${stage}-reviewer-${reviewer}" "$file" || fail "wrong name in ${file##*/}"
    grep -Fq 'disallowedTools: Write, Edit, NotebookEdit' "$file" || fail "${file##*/} must be read-only"
    tr '\n' ' ' < "$file" | grep -Eqi 'fresh.*context|never share context' || fail "${file##*/} must require a fresh independent context"
    grep -Fq 'review-context-invocation/v2' "$file" || fail "${file##*/} must require the sequential invocation contract"
    grep -Fq 'canonical identity ledger' "$file" || fail "${file##*/} must require persisted identity history"
  done
done

[[ -f "$EVALUATOR" && -f "$QUALITY_GATE" ]] || fail "evaluator isolation artifacts are missing"
grep -Fq 'review-context-invocation/v2' "$EVALUATOR" ||
  fail 'evaluator must require the sequential invocation contract'
grep -Fq 'canonical identity ledger' "$EVALUATOR" ||
  fail 'evaluator must require persisted identity history'
grep -Fq 'broad repository namespaces are not an' "$EVALUATOR" ||
  fail 'evaluator must reject namespace-only input authorization'
grep -Fq -- '--reserve' "$QUALITY_GATE" ||
  fail 'quality gate must reserve evaluator identity before launch'
grep -Fq "implementation report's \`## Outputs\` table" "$QUALITY_GATE" ||
  fail 'quality gate must bind evaluator inputs to the task output set'
grep -Fq 'No same-session fallback is permitted for the evaluator.' "$QUALITY_GATE" ||
  fail "quality gate must fail closed instead of using evaluator fallback"
[[ -x "$VALIDATOR_SH" && -f "$VALIDATOR_PS1" ]] ||
  fail "paired deterministic review-context validators are missing"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

make_repository() {
  local repository=$1
  mkdir -p \
    "$repository/specs/f" \
    "$repository/plugins/sdd-review-loop/references" \
    "$repository/plugins/sdd-quality-loop/references" \
    "$repository/reports/spec-review/f/attempt-1/round-1" \
    "$repository/reports/impl-review/f/attempt-1/round-1" \
    "$repository/reports/task-review/f/attempt-1/round-1" \
    "$repository/reports/implementation/f" \
    "$repository/reports/review-context" \
    "$repository/plugins/internal" \
    "$repository/plugins/task" \
    "$repository/private"
  printf 'requirements\n' > "$repository/specs/f/requirements.md"
  printf 'acceptance\n' > "$repository/specs/f/acceptance-tests.md"
  printf 'design\n' > "$repository/specs/f/design.md"
  printf 'tasks\n' > "$repository/specs/f/tasks.md"
  printf 'traceability\n' > "$repository/specs/f/traceability.md"
  printf 'calibration\n' > "$repository/plugins/sdd-review-loop/references/spec-review-calibration.md"
  printf 'calibration\n' > "$repository/plugins/sdd-review-loop/references/reviewer-calibration.md"
  printf 'calibration\n' > "$repository/plugins/sdd-quality-loop/references/quality-gate-calibration.md"
  printf '{}\n' > "$repository/reports/spec-review/f/attempt-1/round-1/precheck-result.json"
  printf '{}\n' > "$repository/reports/impl-review/f/attempt-1/round-1/precheck-result.json"
  printf '{}\n' > "$repository/reports/task-review/f/attempt-1/round-1/precheck-result.json"
  printf 'authorized output\n' > "$repository/plugins/task/authorized-output.txt"
  printf 'unrelated plugin input\n' > "$repository/plugins/internal/arbitrary-existing.txt"
  local authorized_output_hash
  authorized_output_hash="$(sha256 "$repository/plugins/task/authorized-output.txt")"
  {
    printf '# Implementation Report: T-001\n\n'
    printf '## Task\n\n'
    printf '%s\n\n' '- Task ID: T-001'
    printf '## Outputs\n\n'
    printf '| Path | SHA-256 |\n'
    printf '|---|---|\n'
    printf '| `plugins/task/authorized-output.txt` | `%s` |\n' "$authorized_output_hash"
  } > "$repository/reports/implementation/f/T-001.md"
  printf 'secret\n' > "$repository/private/arbitrary-existing.txt"

  local first_hash
  first_hash="$(printf '%s' '1|implementation|implementer|implementation-run|implementation-session|' |
    { if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi; } | awk '{print $1}')"
  jq -n --arg hash "$first_hash" '{
    schema:"review-identity-ledger/v1",
    records:[{
      sequence:1,
      stage:"implementation",
      role:"implementer",
      run_id:"implementation-run",
      host_session_id:"implementation-session",
      previous_record_sha256:"",
      record_sha256:$hash
    }]
  }' > "$repository/reports/review-context/identity-ledger.json"
}

input_for_role() {
  case "$1" in
    spec-reviewer-a|spec-reviewer-b) printf '%s\n' 'specs/f/requirements.md' ;;
    impl-reviewer-a|impl-reviewer-b) printf '%s\n' 'specs/f/design.md' ;;
    task-reviewer-a|task-reviewer-b) printf '%s\n' 'specs/f/tasks.md' ;;
    sdd-evaluator) printf '%s\n' 'reports/implementation/f/T-001.md' ;;
    *) fail "unknown fixture role: $1" ;;
  esac
}

stage_for_role() {
  case "$1" in
    spec-reviewer-*) printf '%s\n' spec ;;
    impl-reviewer-*) printf '%s\n' impl ;;
    task-reviewer-*) printf '%s\n' task ;;
    sdd-evaluator) printf '%s\n' quality ;;
    *) fail "unknown fixture role: $1" ;;
  esac
}

make_manifest() {
  local repository=$1 role=$2 output=$3
  local ledger="$repository/reports/review-context/identity-ledger.json"
  local path stage ledger_hash previous sequence input_hash
  path="$(input_for_role "$role")"
  stage="$(stage_for_role "$role")"
  ledger_hash="$(sha256 "$ledger")"
  previous="$(jq -r '.records[-1].record_sha256' "$ledger")"
  sequence="$(jq '.records[-1].sequence + 1' "$ledger")"
  input_hash="$(sha256 "$repository/$path")"
  jq -n \
    --arg stage "$stage" --arg role "$role" --arg path "$path" \
    --arg ledger_hash "$ledger_hash" --arg previous "$previous" \
    --arg input_hash "$input_hash" --argjson sequence "$sequence" '({
      schema:"review-context-invocation/v2",
      stage:$stage,
      role:$role,
      feature:"f",
      run_id:($role + "-run"),
      host_session_id:($role + "-session"),
      read_only:true,
      input_mode:"file-manifest",
      fallback_mode:"none",
      identity_ledger_path:"reports/review-context/identity-ledger.json",
      identity_ledger_sha256:$ledger_hash,
      previous_record_sha256:$previous,
      sequence:$sequence,
      allowed_input_manifest:[{path:$path,sha256:$input_hash}]
    } + (if $role == "sdd-evaluator" then {task_id:"T-001"} else {} end))' > "$output"
}

run_bash() {
  local manifest=$1 repository=$2
  shift 2
  "$VALIDATOR_SH" "$manifest" "$repository" "$@"
}
run_pwsh() {
  local manifest=$1 repository=$2
  shift 2
  if [[ ${1:-} == --reserve ]]; then
    pwsh -NoLogo -NoProfile -File "$VALIDATOR_PS1" \
      -Manifest "$manifest" -RepositoryRoot "$repository" -Reserve
  else
    pwsh -NoLogo -NoProfile -File "$VALIDATOR_PS1" \
      -Manifest "$manifest" -RepositoryRoot "$repository"
  fi
}

assert_rejected_both() {
  local name=$1 manifest=$2 repository=$3 expected=$4
  local bash_output pwsh_output bash_category pwsh_category
  if bash_output=$(run_bash "$manifest" "$repository" 2>&1); then
    fail "Bash accepted invalid invocation: $name"
  fi
  bash_category="${bash_output%%:*}"
  [[ "$bash_category" == "$expected" ]] ||
    fail "unexpected Bash category for $name: $bash_category"
  if command -v pwsh >/dev/null 2>&1; then
    if pwsh_output=$(run_pwsh "$manifest" "$repository" 2>&1); then
      fail "PowerShell accepted invalid invocation: $name"
    fi
    pwsh_category="${pwsh_output%%:*}"
    [[ "$pwsh_category" == "$bash_category" ]] ||
      fail "validator diagnostic mismatch for $name: Bash=$bash_category PowerShell=$pwsh_category"
  fi
}

assert_reservation_preserves_foreign_lock_both() {
  local manifest=$1 repository=$2
  local lock="$repository/reports/review-context/identity-ledger.json.lock"
  local expected='foreign reservation owner'
  printf '%s\n' "$expected" > "$lock"
  local bash_output pwsh_output
  if bash_output=$(run_bash "$manifest" "$repository" --reserve 2>&1); then
    fail 'Bash acquired a reservation lock owned by another process'
  fi
  [[ "${bash_output%%:*}" == REVIEW_CONTEXT_IDENTITY ]] ||
    fail "unexpected Bash category for foreign reservation lock: ${bash_output%%:*}"
  [[ -f "$lock" && "$(<"$lock")" == "$expected" ]] ||
    fail 'Bash removed or changed a reservation lock it did not own'
  if command -v pwsh >/dev/null 2>&1; then
    if pwsh_output=$(run_pwsh "$manifest" "$repository" --reserve 2>&1); then
      fail 'PowerShell acquired a reservation lock owned by another process'
    fi
    [[ "${pwsh_output%%:*}" == REVIEW_CONTEXT_IDENTITY ]] ||
      fail "validator diagnostic mismatch for foreign reservation lock: Bash=${bash_output%%:*} PowerShell=${pwsh_output%%:*}"
    [[ -f "$lock" && "$(<"$lock")" == "$expected" ]] ||
      fail 'PowerShell removed or changed a reservation lock it did not own'
  fi
}

assert_missing_manifest_both() {
  local missing="$tmp/does-not-exist.json"
  local bash_output pwsh_output
  if bash_output=$(run_bash "$missing" "$bash_repository" 2>&1); then
    fail 'Bash accepted a missing invocation manifest'
  fi
  [[ "${bash_output%%:*}" == REVIEW_CONTEXT_MANIFEST ]] ||
    fail "unexpected Bash category for missing manifest: ${bash_output%%:*}"
  if command -v pwsh >/dev/null 2>&1; then
    if pwsh_output=$(run_pwsh "$missing" "$bash_repository" 2>&1); then
      fail 'PowerShell accepted a missing invocation manifest'
    fi
    [[ "${pwsh_output%%:*}" == REVIEW_CONTEXT_MANIFEST ]] ||
      fail "validator diagnostic mismatch for missing manifest: ${pwsh_output%%:*}"
  fi
}

# Tests are strengthened before implementation: the committed Red test was
# introduced by a745aed directly on top of the pre-implementation baseline.
red_commit="$(git -C "$SOURCE_GIT_ROOT" rev-parse a745aed^{commit})"
red_parent="$(git -C "$SOURCE_GIT_ROOT" rev-parse a745aed^)"
[[ "$red_commit" == a745aed* ]] || fail 'cannot resolve committed Red test'
[[ "$red_parent" == 1bba72f* ]] || fail 'Red test does not precede implementation baseline'
git -C "$SOURCE_GIT_ROOT" diff-tree --no-commit-id --name-only -r "$red_commit" |
  grep -Fxq 'tests/review-agent-isolation.tests.sh' ||
  fail 'a745aed did not commit the failing isolation test'

bash_repository="$tmp/bash-repository"
make_repository "$bash_repository"
valid="$tmp/valid.json"
make_manifest "$bash_repository" spec-reviewer-a "$valid"
run_bash "$valid" "$bash_repository" >/dev/null ||
  fail 'Bash rejected a valid sequential invocation'
if command -v pwsh >/dev/null 2>&1; then
  run_pwsh "$valid" "$bash_repository" >/dev/null ||
    fail 'PowerShell rejected a valid sequential invocation'
fi

assert_missing_manifest_both
candidate="$tmp/candidate.json"
jq '.run_id = "   "' "$valid" > "$candidate"
assert_rejected_both whitespace-run-id "$candidate" "$bash_repository" REVIEW_CONTEXT_IDENTITY
jq '.host_session_id = "\t"' "$valid" > "$candidate"
assert_rejected_both whitespace-session-id "$candidate" "$bash_repository" REVIEW_CONTEXT_IDENTITY
jq '.allowed_input_manifest = .allowed_input_manifest[0]' "$valid" > "$candidate"
assert_rejected_both object-valued-allowed-input-manifest "$candidate" "$bash_repository" REVIEW_CONTEXT_CONTRACT
jq '.sequence |= tostring' "$valid" > "$candidate"
assert_rejected_both string-valued-invocation-sequence "$candidate" "$bash_repository" REVIEW_CONTEXT_CONTRACT
jq '.allowed_input_manifest[0] = {
  path:"private/arbitrary-existing.txt",
  sha256:"'"$(sha256 "$bash_repository/private/arbitrary-existing.txt")"'"
}' "$valid" > "$candidate"
assert_rejected_both arbitrary-existing-unlisted-file "$candidate" "$bash_repository" REVIEW_CONTEXT_PATH
jq '.allowed_input_manifest[0].sha256 = ("b" * 64)' "$valid" > "$candidate"
assert_rejected_both hash-mismatch "$candidate" "$bash_repository" REVIEW_CONTEXT_HASH
jq '.input_mode = "chat-only"' "$valid" > "$candidate"
assert_rejected_both chat-only "$candidate" "$bash_repository" REVIEW_CONTEXT_CONTRACT
jq '.read_only = false' "$valid" > "$candidate"
assert_rejected_both writable-context "$candidate" "$bash_repository" REVIEW_CONTEXT_CONTRACT
jq '.fallback_mode = "same-session-file-reload"' "$valid" > "$candidate"
assert_rejected_both fallback-enabled "$candidate" "$bash_repository" REVIEW_CONTEXT_CONTRACT
jq '.identity_ledger_sha256 = ("b" * 64)' "$valid" > "$candidate"
assert_rejected_both stale-ledger "$candidate" "$bash_repository" REVIEW_CONTEXT_IDENTITY
ln -s requirements.md "$bash_repository/specs/f/investigation.md"
jq '.allowed_input_manifest[0] = {
  path:"specs/f/investigation.md",
  sha256:"'"$(sha256 "$bash_repository/specs/f/requirements.md")"'"
}' "$valid" > "$candidate"
assert_rejected_both symlink-input "$candidate" "$bash_repository" REVIEW_CONTEXT_PATH

evaluator_manifest="$tmp/evaluator-valid.json"
make_manifest "$bash_repository" sdd-evaluator "$evaluator_manifest"
jq --arg hash "$(sha256 "$bash_repository/plugins/internal/arbitrary-existing.txt")" \
  '.allowed_input_manifest = [{
    path:"plugins/internal/arbitrary-existing.txt",
    sha256:$hash
  }]' "$evaluator_manifest" > "$candidate"
assert_rejected_both missing-task-implementation-report "$candidate" "$bash_repository" REVIEW_CONTEXT_PATH
jq --arg hash "$(sha256 "$bash_repository/plugins/task/authorized-output.txt")" \
  '.allowed_input_manifest += [{
    path:"plugins/task/authorized-output.txt",
    sha256:$hash
  }]' "$evaluator_manifest" > "$candidate"
run_bash "$candidate" "$bash_repository" >/dev/null ||
  fail 'Bash rejected an implementation-report-listed evaluator input'
if command -v pwsh >/dev/null 2>&1; then
  run_pwsh "$candidate" "$bash_repository" >/dev/null ||
    fail 'PowerShell rejected an implementation-report-listed evaluator input'
fi
jq --arg hash "$(sha256 "$bash_repository/plugins/internal/arbitrary-existing.txt")" \
  '.allowed_input_manifest += [{
    path:"plugins/internal/arbitrary-existing.txt",
    sha256:$hash
  }]' "$evaluator_manifest" > "$candidate"
assert_rejected_both unrelated-real-plugin-file "$candidate" "$bash_repository" REVIEW_CONTEXT_PATH

cp "$bash_repository/reports/implementation/f/T-001.md" \
  "$bash_repository/reports/implementation/f/T-999.md"
jq '
  .allowed_input_manifest[0].path = "reports/implementation/f/T-999.md"
' "$evaluator_manifest" > "$candidate"
candidate_report_hash="$(sha256 "$bash_repository/reports/implementation/f/T-999.md")"
jq --arg hash "$candidate_report_hash" \
  '.allowed_input_manifest[0].sha256 = $hash' "$candidate" > "$tmp/wrong-task.json"
mv "$tmp/wrong-task.json" "$candidate"
assert_rejected_both wrong-task-report "$candidate" "$bash_repository" REVIEW_CONTEXT_PATH

cp "$bash_repository/reports/implementation/f/T-001.md" "$tmp/canonical-report.md"
sed 's/ |$/ | extra-column/' "$tmp/canonical-report.md" \
  > "$bash_repository/reports/implementation/f/T-001.md"
make_manifest "$bash_repository" sdd-evaluator "$candidate"
jq --arg hash "$(sha256 "$bash_repository/plugins/task/authorized-output.txt")" \
  '.allowed_input_manifest += [{
    path:"plugins/task/authorized-output.txt",
    sha256:$hash
  }]' "$candidate" > "$tmp/malformed-output-row.json"
assert_rejected_both malformed-output-extra-column "$tmp/malformed-output-row.json" "$bash_repository" REVIEW_CONTEXT_PATH
cp "$tmp/canonical-report.md" "$bash_repository/reports/implementation/f/T-001.md"

lock_repository="$tmp/lock-repository"
make_repository "$lock_repository"
make_manifest "$lock_repository" spec-reviewer-a "$candidate"
assert_reservation_preserves_foreign_lock_both "$candidate" "$lock_repository"

malformed_ledger_repository="$tmp/malformed-ledger-repository"
make_repository "$malformed_ledger_repository"
malformed_ledger="$malformed_ledger_repository/reports/review-context/identity-ledger.json"
make_manifest "$malformed_ledger_repository" spec-reviewer-a "$candidate"
jq '.records = .records[0]' "$malformed_ledger" > "$tmp/malformed-ledger.json"
mv "$tmp/malformed-ledger.json" "$malformed_ledger"
jq --arg hash "$(sha256 "$malformed_ledger")" \
  '.identity_ledger_sha256 = $hash' "$candidate" > "$tmp/malformed-ledger-manifest.json"
mv "$tmp/malformed-ledger-manifest.json" "$candidate"
assert_rejected_both object-valued-ledger-records "$candidate" "$malformed_ledger_repository" REVIEW_CONTEXT_IDENTITY

string_sequence_repository="$tmp/string-sequence-repository"
make_repository "$string_sequence_repository"
string_sequence_ledger="$string_sequence_repository/reports/review-context/identity-ledger.json"
make_manifest "$string_sequence_repository" spec-reviewer-a "$candidate"
jq '.records[0].sequence |= tostring' "$string_sequence_ledger" > "$tmp/string-sequence-ledger.json"
mv "$tmp/string-sequence-ledger.json" "$string_sequence_ledger"
jq --arg hash "$(sha256 "$string_sequence_ledger")" \
  '.identity_ledger_sha256 = $hash' "$candidate" > "$tmp/string-sequence-manifest.json"
mv "$tmp/string-sequence-manifest.json" "$candidate"
assert_rejected_both string-valued-ledger-sequence "$candidate" "$string_sequence_repository" REVIEW_CONTEXT_IDENTITY

# Reserve one invocation, then prove omission is impossible: reuse is detected
# from the canonical ledger even though the next manifest contains no caller-
# supplied reserved-ID array.
run_bash "$valid" "$bash_repository" --reserve >/dev/null ||
  fail 'Bash could not reserve a valid reviewer identity'
make_manifest "$bash_repository" spec-reviewer-b "$candidate"
jq '.run_id = "spec-reviewer-a-run"' "$candidate" > "$tmp/reused-run.json"
assert_rejected_both reused-prior-run "$tmp/reused-run.json" "$bash_repository" REVIEW_CONTEXT_IDENTITY
jq '.host_session_id = "implementation-session"' "$candidate" > "$tmp/reused-session.json"
assert_rejected_both reused-implementation-session "$tmp/reused-session.json" "$bash_repository" REVIEW_CONTEXT_IDENTITY

# Every future role can be launched in chronological order; no future context
# is required at the first boundary.
for role in spec-reviewer-b impl-reviewer-a impl-reviewer-b task-reviewer-a task-reviewer-b sdd-evaluator; do
  make_manifest "$bash_repository" "$role" "$candidate"
  run_bash "$candidate" "$bash_repository" --reserve >/dev/null ||
    fail "Bash rejected sequential launch for $role"
done
[[ "$(jq '.records | length' "$bash_repository/reports/review-context/identity-ledger.json")" -eq 8 ]] ||
  fail 'Bash did not persist the complete chronological identity chain'

if command -v pwsh >/dev/null 2>&1; then
  ps_repository="$tmp/ps-repository"
  make_repository "$ps_repository"
  for role in spec-reviewer-a spec-reviewer-b impl-reviewer-a impl-reviewer-b task-reviewer-a task-reviewer-b sdd-evaluator; do
    make_manifest "$ps_repository" "$role" "$candidate"
    run_pwsh "$candidate" "$ps_repository" --reserve >/dev/null ||
      fail "PowerShell rejected sequential launch for $role"
  done
  [[ "$(jq '.records | length' "$ps_repository/reports/review-context/identity-ledger.json")" -eq 8 ]] ||
    fail 'PowerShell did not persist the complete chronological identity chain'
fi

# Issue #143: impl-reviewer-a must be authorized to read the previous round's
# integrated-summary.json. impl-review-precheck.sh requires reviewer-a's manifest
# to carry it when round > 1, but this validator previously authorized the
# summary for reviewer-b only, so every round > 1 impl review was rejected with
# REVIEW_CONTEXT_PATH and impl-review could never pass past round 1.
issue143_repository="$tmp/issue143-repository"
make_repository "$issue143_repository"
issue143_summary='reports/impl-review/f/attempt-1/round-1/integrated-summary.json'
printf '{"schema":"integrated-summary/v1"}\n' > "$issue143_repository/$issue143_summary"
make_manifest "$issue143_repository" impl-reviewer-a "$candidate"
jq --arg path "$issue143_summary" \
   --arg hash "$(sha256 "$issue143_repository/$issue143_summary")" \
  '.allowed_input_manifest += [{path:$path,sha256:$hash}]' "$candidate" > "$tmp/issue143.json"
run_bash "$tmp/issue143.json" "$issue143_repository" >/dev/null ||
  fail 'issue #143: Bash rejected impl-reviewer-a previous-round integrated summary'
if command -v pwsh >/dev/null 2>&1; then
  run_pwsh "$tmp/issue143.json" "$issue143_repository" >/dev/null ||
    fail 'issue #143: PowerShell rejected impl-reviewer-a previous-round integrated summary'
fi

# Real rollback proof: restore only the pinned 1.4.0 boundary from 7df7318.
# Files introduced after that commit must be deleted, and all surviving files
# must be byte-identical to the archived baseline.
rollback_baseline="$tmp/rollback-baseline"
rollback_target="$tmp/rollback-target"
mkdir -p "$rollback_baseline" "$rollback_target"
boundary_paths=(
  plugins/sdd-quality-loop/scripts/validate-review-context-set.sh
  plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1
  plugins/sdd-quality-loop/skills/quality-gate/SKILL.md
  plugins/sdd-quality-loop/agents/evaluator.md
  plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md
  plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md
  plugins/sdd-review-loop/skills/task-review-loop/SKILL.md
  plugins/sdd-review-loop/agents/spec-reviewer-a.md
  plugins/sdd-review-loop/agents/spec-reviewer-b.md
  plugins/sdd-review-loop/agents/impl-reviewer-a.md
  plugins/sdd-review-loop/agents/impl-reviewer-b.md
  plugins/sdd-review-loop/agents/task-reviewer-a.md
  plugins/sdd-review-loop/agents/task-reviewer-b.md
)
baseline_paths=()
for path in "${boundary_paths[@]}"; do
  if git -C "$SOURCE_GIT_ROOT" cat-file -e "7df7318:$path" 2>/dev/null; then
    baseline_paths+=("$path")
  fi
done
git -C "$SOURCE_GIT_ROOT" archive 7df7318 "${baseline_paths[@]}" | tar -x -C "$rollback_baseline"
for path in "${boundary_paths[@]}"; do
  if [[ -f "$ROOT/$path" ]]; then
    mkdir -p "$rollback_target/$(dirname "$path")"
    cp "$ROOT/$path" "$rollback_target/$path"
  fi
done
for path in "${boundary_paths[@]}"; do
  if [[ -f "$rollback_baseline/$path" ]]; then
    mkdir -p "$rollback_target/$(dirname "$path")"
    cp "$rollback_baseline/$path" "$rollback_target/$path"
  else
    rm -f "$rollback_target/$path"
  fi
done
for path in "${boundary_paths[@]}"; do
  if [[ -f "$rollback_baseline/$path" ]]; then
    cmp -s "$rollback_baseline/$path" "$rollback_target/$path" ||
      fail "rollback differs from pinned baseline: $path"
  else
    [[ ! -e "$rollback_target/$path" ]] ||
      fail "rollback retained post-1.4.0 file: $path"
  fi
done
find "$rollback_target" -depth -type d -empty -delete
diff -qr "$rollback_baseline" "$rollback_target" >/dev/null ||
  fail 'restored reviewer/evaluator boundary is not equal to baseline 7df7318'

printf 'ok: sequential reviewer and evaluator contexts are distinct, authorized, and hash-chained\n'
