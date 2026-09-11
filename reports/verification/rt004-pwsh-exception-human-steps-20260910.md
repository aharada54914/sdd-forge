# RT004: human-only exception-location diagnostic

Scope: diagnostic metadata only; not the underlying fix or a passing review gate.
Independent DATA reviewer `/root/rt004_snapshot_static_review` found no new
Critical/Major findings on 2026-09-10 for candidate SHA256
`61e422f7b8fbd51b8f7ccbb47139d3517eafffb46e3fbb8a8771cae08ed6b074`.
No candidate application or execution was performed by that reviewer or the
author. Existing runtime failures remain unresolved. The existing rejection is
retained even if diagnostic output fails. No exception message, input, source,
or stack text is added to output.

## Run once in the human's macOS terminal

Do not rerun earlier application commands. This requires the exact current
source and test hashes from the latest human run. It backs up the source,
applies only the diagnostic patch, checks syntax and runs the 14-case selector.
A failing selector is evidence to diagnose, not permission to merge.

```bash
rtk proxy bash <<'BASH'
set -euo pipefail
cd /Users/jrmag/sdd-forge
file=plugins/sdd-quality-loop/scripts/check-workflow-state.ps1
patch=reports/verification/rt004-pwsh-exception-location-candidate-20260910.patch
test_file=tests/impl-review-adr-inputs.tests.sh
hash_of() { rtk proxy /usr/bin/shasum -a 256 "$1" | rtk proxy /usr/bin/awk '{print $1}'; }
[ "$(hash_of "$file")" = 4825a5b0c893dd4bf7a6b713d73133caa826a22571d613ae72e7a367ad64baa0 ] || { printf 'STOP: source hash mismatch\n'; exit 1; }
[ "$(hash_of "$patch")" = 61e422f7b8fbd51b8f7ccbb47139d3517eafffb46e3fbb8a8771cae08ed6b074 ] || { printf 'STOP: patch hash mismatch\n'; exit 1; }
[ "$(hash_of "$test_file")" = 2bcbb2bb7a3d8a64be64fc36011e5736185a68c1f863c57401a951c6a7265ee2 ] || { printf 'STOP: test hash mismatch\n'; exit 1; }
rtk proxy git apply --check "$patch"
backup=$(rtk proxy /usr/bin/mktemp -d /tmp/sdd-rt004-exception.XXXXXX)
[ -n "$backup" ] && [ -d "$backup" ] || exit 1
printf 'Backup and logs: %s\n' "$backup"
rtk proxy /bin/cp -p "$file" "$backup/check-workflow-state.ps1.before"
rtk proxy git apply "$patch"
rtk proxy git diff --check -- "$file"
rtk proxy pwsh -NoLogo -NoProfile -NonInteractive -Command '$ErrorActionPreference="Stop"; $p=Join-Path (Get-Location) "plugins/sdd-quality-loop/scripts/check-workflow-state.ps1"; $t=$null; $e=$null; $null=[System.Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e); Write-Output ("Syntax errors: {0}" -f @($e).Count); if (@($e).Count -ne 0) { exit 1 }'
if rtk proxy bash "$test_file" --current-adr-only >"$backup/current.log" 2>&1; then
  test_exit=0
else
  test_exit=$?
fi
printf 'Current ADR test exit: %s\n' "$test_exit"
if rtk proxy /usr/bin/grep -E '^ADR_EXCEPTION type=[A-Za-z0-9_.+]+ line=[0-9]+$' "$backup/current.log"; then
  :
else
  printf 'No diagnostic metadata found; preserve current.log for investigation.\n'
fi
rtk proxy /usr/bin/shasum -a 256 "$file" "$test_file"
printf 'Send this output and the backup path to Codex. No commit/push/merge or review-state changes.\n'
BASH
```

The backup is retained. Do not restore it over subsequent work automatically.
If any preflight fails, stop and send that failure; do not bypass the checks.
If metadata reports line 0 or an unhelpful wrapper location, do not infer the
cause. A further diagnostic will need separate review within the same scope.
