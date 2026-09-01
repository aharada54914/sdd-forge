#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
PROMOTE_TOKEN='promote-golden-baseline'".sh"
CANDIDATE_TOKEN='--write-'"candidate"
WORKFLOW="${GOLDEN_WORKFLOW_UNDER_TEST:-${ROOT}/.github/workflows/test.yml}"
PROMOTE="${GOLDEN_PROMOTE_UNDER_TEST:-${ROOT}/tests/${PROMOTE_TOKEN}}"
BASELINE_ROOT="${ROOT}/specs/epic-195-a7-compatibility/verification/golden-baseline"
CANONICAL="${BASELINE_ROOT}/canonical"
PASS=0
FAIL=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ok() { printf 'ok: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

tree_hash() {
  python3 - "$1" <<'PY'
import hashlib
import sys
from pathlib import Path

root = Path(sys.argv[1])
digest = hashlib.sha256()
if root.is_dir():
    for path in sorted(item for item in root.rglob("*") if item.is_file()):
        relative = path.relative_to(root).as_posix()
        digest.update(relative.encode("utf-8") + b"\0" + path.read_bytes() + b"\0")
print(digest.hexdigest())
PY
}

workflow_is_safe() {
  local path="$1"
  [[ -f "$path" ]] || return 1
  ! grep -Fq -- "$PROMOTE_TOKEN" "$path" \
    && ! grep -Fq -- "$CANDIDATE_TOKEN" "$path"
}

workflow_case_passes=true
if ! workflow_is_safe "$WORKFLOW"; then
  workflow_case_passes=false
fi
for token in "$PROMOTE_TOKEN" "$CANDIDATE_TOKEN"; do
  fixture="${WORK}/workflow-$((PASS + FAIL)).yml"
  printf 'run: %s\n' "$token" >"$fixture"
  if workflow_is_safe "$fixture"; then
    workflow_case_passes=false
  fi
done
printf 'run: %s %s\n' "${PROMOTE_TOKEN^^}" "${CANDIDATE_TOKEN^^}" >"${WORK}/workflow-miscased.yml"
if ! workflow_is_safe "${WORK}/workflow-miscased.yml"; then
  workflow_case_passes=false
fi
if [[ "$workflow_case_passes" == true ]]; then
  ok 'AC-040 rejects both exact mutation-capable workflow references'
else
  fail 'AC-040 workflow scan must reject either exact forbidden reference and accept mis-cased text'
fi

baseline_before="$(tree_hash "$BASELINE_ROOT")"
ci_candidate="${WORK}/must-not-be-read"
ci_output="$(env CI=false "$PROMOTE" "$ci_candidate" --approved-by test-human 2>&1)"
ci_status=$?
baseline_after="$(tree_hash "$BASELINE_ROOT")"
expected_ci='promote-golden-baseline: promotion is forbidden when CI is non-empty'
if [[ $ci_status -ne 0 && "$ci_output" == "$expected_ci" \
      && "$baseline_after" == "$baseline_before" && ! -e "$ci_candidate" ]]; then
  ok 'AC-041 refuses non-empty CI before candidate or canonical file I/O'
else
  fail "AC-041 CI refusal mismatch (status=$ci_status candidate_exists=$([[ -e "$ci_candidate" ]] && printf yes || printf no))"
fi

approval_candidate="${WORK}/must-not-be-written"
canonical_before="$(tree_hash "$CANONICAL")"
approval_output="$(env -u CI "$PROMOTE" "$approval_candidate" 2>&1)"
approval_status=$?
empty_approval_output="$(env -u CI "$PROMOTE" "$approval_candidate" --approved-by '' 2>&1)"
empty_approval_status=$?
canonical_after="$(tree_hash "$CANONICAL")"
expected_usage="Usage: ${PROMOTE} <candidate-path> --approved-by <human-identifier>"
if [[ $approval_status -ne 0 && "$approval_output" == "$expected_usage" \
      && $empty_approval_status -ne 0 && "$empty_approval_output" == "$expected_usage" \
      && "$canonical_after" == "$canonical_before" && ! -e "$approval_candidate" ]]; then
  ok 'AC-041 refuses omitted or empty approval without canonical write'
else
  fail "AC-041 approval refusal mismatch (omitted_status=$approval_status empty_status=$empty_approval_status candidate_exists=$([[ -e "$approval_candidate" ]] && printf yes || printf no))"
fi

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $PASS -eq 3 && $FAIL -eq 0 ]]
