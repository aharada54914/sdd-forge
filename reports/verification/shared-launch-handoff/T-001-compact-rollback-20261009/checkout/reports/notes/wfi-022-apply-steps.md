# WFI-022 apply and verify

```bash
set -euo pipefail
WFI022_REPO=/Users/jrmag/Projects/active/sdd-forge-wt-phase4
WFI022_PATCH="$WFI022_REPO/reports/notes/wfi-022-guard-falsepositive.patch"
cd "$WFI022_REPO"
test "$(shasum -a 256 "$WFI022_PATCH" | awk '{print $1}')" = 5f137dc2ca5d56e6fb773f4278dad13e304d3d28319357592e567711a11b6f49
git apply --check "$WFI022_PATCH"
git apply "$WFI022_PATCH"
WFI022_TMP="$(mktemp -d)"
trap 'rm -rf "$WFI022_TMP"' EXIT
PYTHONPYCACHEPREFIX="$WFI022_TMP/pycache" python3 -m py_compile plugins/sdd-quality-loop/scripts/sdd-hook-guard.py
node --check plugins/sdd-quality-loop/scripts/sdd-hook-guard.js
pwsh -NoProfile -Command '$null = [scriptblock]::Create((Get-Content -Raw "plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1")); "PowerShell parse OK"'
bash tests/guard-parity.tests.sh
git diff --check -- plugins/sdd-quality-loop/scripts/sdd-hook-guard.py plugins/sdd-quality-loop/scripts/sdd-hook-guard.js plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1 plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh tests/guard-parity.tests.sh
```
