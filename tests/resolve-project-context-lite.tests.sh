#!/bin/sh
# T-006 (epic-193-a5): resolve-project-context-lite, the B5-narrowed
# advisory-missing/zero-match non-Blocking Lite-track states and the
# track-exclusive publication-set guarantee (design.md Test Strategy item
# 4, TEST-009/AC-009).
set -u

# Runtime marker (recurring cross-model panel Minor, every round): a leading
# capture line naming the invoking runtime so sh/ps1 captures of this
# suite's own output stop being byte-identical -- the PowerShell lane
# becomes self-evidencing (proof pwsh genuinely ran it, not a duplicated sh
# capture pasted under a different filename).
printf '%s\n' '# runner: bash'

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if command -v python3 >/dev/null 2>&1; then
  exec python3 "$ROOT/tests/resolve-project-context-lite-check.py" --launcher sh
fi
if command -v python >/dev/null 2>&1; then
  exec python "$ROOT/tests/resolve-project-context-lite-check.py" --launcher sh
fi
printf '%s\n' 'FAIL: no python3/python interpreter available'
exit 1
