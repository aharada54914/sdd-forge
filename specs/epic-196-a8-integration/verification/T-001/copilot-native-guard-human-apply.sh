#!/usr/bin/env bash
# Human-only, one-shot application of the separately approved Copilot guard repair.
# Never run this as an agent workaround for a PreToolUse refusal.
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
cd "$here/../../../.."
for tool in git shasum python3 node pwsh; do
  command -v "$tool" >/dev/null 2>&1 || { echo "NO APPLY: missing required tool $tool"; exit 1; }
done
patch=specs/epic-196-a8-integration/verification/T-001/copilot-native-guard-candidate.patch
paths=(
  plugins/sdd-quality-loop/scripts/sdd-hook-guard.py
  plugins/sdd-quality-loop/scripts/sdd-hook-guard.js
  plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1
  tests/guard-r10-port.tests.ps1
)
test "$(git rev-parse --show-toplevel)" = "$(pwd -P)" || { echo 'NO APPLY: wrong repository'; exit 1; }
for path in "$patch" "${paths[@]}"; do
  test -f "$path" && test ! -L "$path" || { echo "NO APPLY: missing or linked $path"; exit 1; }
done

# Includes the patch bytes; a prior application or any changed base is a no-op.
shasum -a 256 -c <<'HASHES' || { echo 'NO APPLY: patch/base hash differs; inspect before any new attempt'; exit 1; }
562a6a6531644043881bf73477ce2a643d62c1c1350cead900841f41b79c1db1  specs/epic-196-a8-integration/verification/T-001/copilot-native-guard-candidate.patch
6537e32f47bbeaa87ad645162b45ce0f78e70826d7108ca8a0fb462827051015  plugins/sdd-quality-loop/scripts/sdd-hook-guard.py
a520d69a04751df0630e641d6424d0f13f7f6ee299824fd98387279879215bc4  plugins/sdd-quality-loop/scripts/sdd-hook-guard.js
8df36c4c8041e136ba350cc877518ecfd8e62989253713b0bea27adbc02ad6b8  plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1
4847ef35cac51e20f672d85997f2430c19c9e8cc9d73bae1e933aecbb4126fa8  tests/guard-r10-port.tests.ps1
HASHES

backup=$(mktemp -d "${TMPDIR:-/tmp}/sdd-copilot-guard-backup.XXXXXX")
for path in "${paths[@]}"; do
  mkdir -p "$backup/$(dirname -- "$path")"
  cp -p "$path" "$backup/$path"
done
echo "Backup retained: $backup"
git apply --check "$patch"
git apply "$patch"

# Syntax and the existing three-runtime parity lane. Do not claim a native
# Copilot pass: actual command-hook stdin has not yet been captured.
python3 -c 'import ast, pathlib; ast.parse(pathlib.Path("plugins/sdd-quality-loop/scripts/sdd-hook-guard.py").read_text())'
node --check plugins/sdd-quality-loop/scripts/sdd-hook-guard.js
pwsh -NoProfile -Command '$tokens=$null; $errors=$null; $null=[System.Management.Automation.Language.Parser]::ParseFile("plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1",[ref]$tokens,[ref]$errors); if($errors.Count -gt 0){$errors | Write-Error; exit 1}'
pwsh -NoProfile -File tests/guard-r10-port.tests.ps1
pwsh -NoProfile -File tests/hooks.tests.ps1
git diff --check -- "${paths[@]}"
echo 'Applied and local checks passed. No commit, push, task status, approval, ledger, live host, or quality-gate action performed.'
