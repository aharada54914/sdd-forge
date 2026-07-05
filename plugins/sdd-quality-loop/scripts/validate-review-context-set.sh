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

evaluator_output_is_declared() {
  local path=$1 expected_hash=$2 report=$3
  awk -v expected_path="$path" -v expected_hash="$expected_hash" '
    /^## Outputs[[:space:]]*$/ { in_outputs = 1; next }
    in_outputs && /^##[[:space:]]/ { exit }
    in_outputs {
      expected_line = "| `" expected_path "` | `" expected_hash "` |"
      if ($0 == expected_line) found = 1
    }
    END { exit(found ? 0 : 1) }
  ' "$report"
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
      [[ "$path" =~ ^specs/"$feature"/(requirements|acceptance-tests|design|investigation|ux-spec|frontend-spec|infra-spec|security-spec)\.md$ ]] ||
        [[ "$path" == plugins/sdd-review-loop/references/reviewer-calibration.md ]] ||
        [[ "$path" =~ ^reports/impl-review/"$feature"/attempt-[1-9][0-9]*/round-[1-9][0-9]*/precheck-result\.json$ ]] ||
        { [[ "$role" == impl-reviewer-b ]] &&
          [[ "$path" =~ ^reports/impl-review/"$feature"/attempt-[1-9][0-9]*/round-[1-9][0-9]*/integrated-summary\.json$ ]]; }
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
          "$path" "$expected_hash" "$repository_root/$implementation_report_path"
      ;;
    *) return 1 ;;
  esac
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
      ((keys | sort) == ((base_keys + ["task_id"]) | sort)) and
      (.task_id | type == "string" and test("^T-[0-9]{3}$"))) or
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

stage=$(jq -r '.stage' "$manifest")
role=$(jq -r '.role' "$manifest")
feature=$(jq -r '.feature' "$manifest")
run_id=$(jq -r '.run_id' "$manifest")
host_session_id=$(jq -r '.host_session_id' "$manifest")
sequence=$(jq -r '.sequence' "$manifest")
previous_record_sha256=$(jq -r '.previous_record_sha256' "$manifest")
bound_ledger_sha256=$(jq -r '.identity_ledger_sha256' "$manifest")
task_id=''
[[ "$stage" == quality ]] && task_id=$(jq -r '.task_id' "$manifest")

case "$stage:$role" in
  spec:spec-reviewer-a|spec:spec-reviewer-b|impl:impl-reviewer-a|impl:impl-reviewer-b|task:task-reviewer-a|task:task-reviewer-b|quality:sdd-evaluator) ;;
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
actual_ledger_sha256=$(sha256_file "$ledger")
[[ "$actual_ledger_sha256" == "$bound_ledger_sha256" ]] ||
  fail IDENTITY 'canonical identity ledger hash is stale or mismatched'
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
] | @tsv' "$ledger")

[[ "$sequence" -eq "$expected_sequence" && "$previous_record_sha256" == "$expected_previous" ]] ||
  fail IDENTITY 'invocation does not extend the canonical identity ledger'
jq -e --arg run "$run_id" --arg session "$host_session_id" '
  all(.records[]; .run_id != $run and .host_session_id != $session)
' "$ledger" >/dev/null 2>&1 ||
  fail IDENTITY 'run or host-session identity was already persisted'

implementation_report_path=''
if [[ "$stage:$role" == quality:sdd-evaluator ]]; then
  implementation_report_count=0
  while IFS= read -r candidate_report; do
    if [[ "$candidate_report" == "reports/implementation/$feature/$task_id.md" ]]; then
      implementation_report_path=$candidate_report
      implementation_report_count=$((implementation_report_count + 1))
    fi
  done < <(jq -r '.allowed_input_manifest[].path' "$manifest")
  [[ "$implementation_report_count" -eq 1 ]] ||
    fail PATH 'sdd-evaluator requires the current task implementation report'
  [[ "$(sed -n '1p' "$repository_root/$implementation_report_path")" == "# Implementation Report: $task_id" ]] ||
    fail PATH 'sdd-evaluator implementation report heading does not match task ID'
  grep -Fxq -- "- Task ID: $task_id" "$repository_root/$implementation_report_path" ||
    fail PATH 'sdd-evaluator implementation report task field does not match task ID'
fi

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
  [[ "$actual_hash" == "$expected_hash" ]] ||
    fail HASH "$role hash mismatch: $path"
done < <(jq -r '.allowed_input_manifest[] | [.path, .sha256] | @tsv' "$manifest")

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

printf 'REVIEW_CONTEXT_OK %s\n' "$record_hash"
