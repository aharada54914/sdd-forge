#!/bin/sh
# T-006 (epic-193-a5): resolve-project-context-cli, the required-flag
# argument-validation matrix (design.md Test Strategy item 1, TEST-001/
# AC-001).
set -u

# Runtime marker (recurring cross-model panel Minor, every round): a leading
# capture line naming the invoking runtime so sh/ps1 captures of this
# suite's own output stop being byte-identical -- the PowerShell lane
# becomes self-evidencing (proof pwsh genuinely ran it, not a duplicated sh
# capture pasted under a different filename).
printf '%s\n' '# runner: bash'

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if command -v python3 >/dev/null 2>&1; then
  exec python3 "$ROOT/tests/resolve-project-context-cli-check.py" --launcher sh
fi
if command -v python >/dev/null 2>&1; then
  exec python "$ROOT/tests/resolve-project-context-cli-check.py" --launcher sh
fi
printf '%s\n' 'FAIL: no python3/python interpreter available'
exit 1
