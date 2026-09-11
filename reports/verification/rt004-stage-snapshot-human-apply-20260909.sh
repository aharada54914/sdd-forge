#!/usr/bin/env bash
# Human-terminal entry only. Codex must not execute this protected application.
set -euo pipefail
cd /Users/jrmag/sdd-forge
target=plugins/sdd-quality-loop/scripts/check-workflow-state.sh
candidate=reports/verification/adr-workflow-bash-snapshot-composed-candidate-20260909.patch
suite=tests/impl-review-adr-inputs.tests.sh
observer=tests/fixtures/adr-jq-read-boundary.py
check_hash() {
  local file=$1 expected=$2 actual
  [[ -f "$file" && ! -L "$file" ]] || { printf 'STOP: invalid file: %s\n' "$file"; exit 1; }
  actual=$(/usr/bin/shasum -a 256 "$file")
  [[ "${actual%% *}" == "$expected" ]] || { printf 'STOP: hash mismatch: %s\n' "$file"; exit 1; }
}
check_hash "$target" 15a4ef0a72c8be78c40b38e692ee7a46d8664d825e61ab99915086dae0f02d1e
check_hash "$candidate" 707df63e253eb90805ac9d209bc5295bf017d15befe32cfa34c1b6a94fbce5fb
check_hash "$suite" f66e61c292bfadf51b69e043cef83a03bd36362c455961678d4e5f694ae005ed
check_hash "$observer" e35f8e95734b0102204799d9a81a4bddfb0284ce9ba847de70a3e0ac334c1c7c
rtk proxy git apply --check --unidiff-zero "$candidate"
backup=$(/usr/bin/mktemp -d /tmp/sdd-rt004-stage-snapshot.XXXXXX)
printf 'Backup and logs: %s\n' "$backup"
/bin/cp -p "$target" "$backup/check-workflow-state.sh.before"
/bin/cp "$candidate" "$backup/candidate.patch"
check_hash "$target" 15a4ef0a72c8be78c40b38e692ee7a46d8664d825e61ab99915086dae0f02d1e
rtk proxy git apply --unidiff-zero "$candidate"
rtk proxy bash -n "$target"
rtk proxy git diff --check -- "$target"
/usr/bin/shasum -a 256 "$target"
failed=0
for selector in --late-contract-only --history-pin-only --workflow-only; do
  printf '\nCheck: %s\n' "$selector"
  set +e
  rtk proxy bash "$suite" "$selector" 2>&1 | /usr/bin/tee "$backup/${selector#--}.log"
  statuses=("${PIPESTATUS[@]}")
  set -e
  printf 'Test exit: %s; log exit: %s\n' "${statuses[0]}" "${statuses[1]}"
  if [[ "${statuses[0]}" != 0 || "${statuses[1]}" != 0 ]]; then failed=1; fi
done
printf '\nChecks failed flag: %s; backup and logs: %s\n' "$failed" "$backup"
printf 'Send the complete output to Codex. No commit/push/merge or review-state change was performed.\n'
exit "$failed"
