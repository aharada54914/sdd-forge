# RT004: PowerShell candidate and current-consumption regression

Prepared 2026-09-10. Independent limited static review of both candidates is
complete; this sequence is ready for human application and measurement.
This document does not record execution or a gate PASS.
Do not rerun the old Bash application: its replacement already landed through
the human. This sequence changes only the PowerShell validator and ADR test
driver, after exact input hashes and patch target lists are checked.

Production candidate static re-review found no remaining Critical/Major in its
limited scope. The test candidate's diagnostic-recording Minor was addressed
and independently rechecked at SHA256 `5f927cbc1ff7d1bd13f3c0fb15c12c04424b635b68743da9b2899d0cf7344975`.
The commands below
are reserved for the human terminal because protected application/execution
must not be rerouted by the agent.

## Human command

Paste the entire block, including its final BASH line. It uses macOS `/bin/cat`,
not the nonexistent `/usr/bin/cat`, and does not require ripgrep. No commit,
push, merge, review verdict editing or automatic rollback is included.

```bash
rtk proxy bash <<'BASH'
set -euo pipefail
cd /Users/jrmag/sdd-forge
ps=plugins/sdd-quality-loop/scripts/check-workflow-state.ps1
suite=tests/impl-review-adr-inputs.tests.sh
ps_patch=reports/verification/adr-workflow-powershell-history-composed-candidate-20260909.patch
test_patch=reports/verification/adr-current-consumption-tests-candidate-20260910.patch
hash() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }
stop() { printf 'STOP: %s\n' "$*" >&2; exit 1; }
check_hash() { [ "$(hash "$1")" = "$2" ] || stop "Hash mismatch: $1"; }
for tool in git bash pwsh jq python3; do command -v "$tool" >/dev/null || stop "Missing command: $tool"; done
check_hash "$ps" 7a4663e154e7877362d43916087986849dd7625121d5c058332d3e27eb7b2644
check_hash "$suite" f66e61c292bfadf51b69e043cef83a03bd36362c455961678d4e5f694ae005ed
check_hash "$ps_patch" 2b90cefbbffebb8daeeedc37da23d8b8c7c9dd02e91734588b4697dabbd52791
check_hash "$test_patch" 5f927cbc1ff7d1bd13f3c0fb15c12c04424b635b68743da9b2899d0cf7344975
check_target() {
  local targets
  targets=$(git apply --numstat "$1" | /usr/bin/awk -F '\t' '{print $3}') || stop "Cannot inspect patch: $1"
  [ "$targets" = "$2" ] || stop "Unexpected patch target: $1"
}
check_target "$ps_patch" "$ps"
check_target "$test_patch" "$suite"
git apply --check --unidiff-zero "$test_patch"
git apply --check --unidiff-zero "$ps_patch"
backup=$(mktemp -d /tmp/sdd-rt004-pwsh.XXXXXX) || stop 'Backup allocation failed'
[ -d "$backup" ] || stop 'Backup directory missing'
printf 'Backup and logs: %s\n' "$backup"
/bin/cp -p "$ps" "$backup/check-workflow-state.ps1.before"
/bin/cp -p "$suite" "$backup/impl-review-adr-inputs.tests.sh.before"
git diff -- "$ps" "$suite" > "$backup/preexisting.diff"
run_log() {
  local label=$1 rc=0
  shift
  "$@" > "$backup/$label.log" 2>&1 || rc=$?
  /bin/cat "$backup/$label.log"
  printf '\nCheck: %s; exit: %s\n' "$label" "$rc"
  return "$rc"
}
# Tests first: preserve a measured baseline against the existing PowerShell.
check_hash "$suite" f66e61c292bfadf51b69e043cef83a03bd36362c455961678d4e5f694ae005ed
check_hash "$test_patch" 5f927cbc1ff7d1bd13f3c0fb15c12c04424b635b68743da9b2899d0cf7344975
git apply --unidiff-zero "$test_patch"
bash -n "$suite"
before_rc=0
run_log current-before bash "$suite" --current-adr-only || before_rc=$?
printf 'Baseline exit (not treated as a PASS): %s\n' "$before_rc"
# Apply only the independently reviewed, hash-pinned PowerShell candidate.
check_hash "$ps" 7a4663e154e7877362d43916087986849dd7625121d5c058332d3e27eb7b2644
check_hash "$ps_patch" 2b90cefbbffebb8daeeedc37da23d8b8c7c9dd02e91734588b4697dabbd52791
git apply --unidiff-zero "$ps_patch"
failed=0
run_log current-after bash "$suite" --current-adr-only || failed=1
run_log adr-complete bash "$suite" || failed=1
run_log boundary bash tests/review-context-boundary.tests.sh || failed=1
run_log round2 bash tests/impl-review-round2-contract.tests.sh || failed=1
run_log workflow-bash bash tests/workflow-state-registry.tests.sh || failed=1
run_log workflow-pwsh pwsh -NoProfile -File tests/workflow-state.tests.ps1 || failed=1
run_log whitespace git diff --check -- "$ps" "$suite" || failed=1
git diff --stat -- "$ps" "$suite"
/usr/bin/shasum -a 256 "$ps" "$suite"
printf '\nChecks failed flag: %s; backup and logs: %s\n' "$failed" "$backup"
printf 'Stop here. Send complete output to Codex. No commit/push/merge or verdict changes.\n'
exit "$failed"
BASH
```

The full Bash driver explicitly invokes both original Bash and PowerShell
validators; this is not a copied-validator test. macOS PowerShell is not native
Windows or PowerShell 5.1 proof. A PowerShell-specific snapshot race/mutation
regression is still required separately; the Bash-only jq observation seam
does not establish it. Any failure remains unresolved, even if other checks
pass. Preserve the backup and logs rather than replacing earlier FAIL evidence.
