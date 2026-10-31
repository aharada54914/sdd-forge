#!/bin/sh
# T-010 (epic-193-a5): resolve-project-context-metamorphic -- the
# completeness/invariance suite design.md Test Strategy item 9 (M10) fixes
# in full: (a) TT/TF/FT/FF union-match combination matrix; (b) affected-
# component input-order invariance; (c) >1-true-component single-recording
# (no duplication); (d) verbatim applied:false reason template; (e) the
# three WARN-branch fixtures, each independently Blocking; (f)
# nested-array-completeness via validate-resolver-evidence's own exact-set
# checks; (g) the dependency-invocation-order spy, per-position
# forced-failure sub-fixtures. Plus the feature-wide REQ-006 (a)-(h) +
# nine-suite completeness lock the Done When bullet requires (AC-026/
# AC-027).
set -u

# Runtime marker (recurring cross-model panel Minor, every round): a leading
# capture line naming the invoking runtime so sh/ps1 captures of this
# suite's own output stop being byte-identical -- the PowerShell lane
# becomes self-evidencing (proof pwsh genuinely ran it, not a duplicated sh
# capture pasted under a different filename).
printf '%s\n' '# runner: bash'

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if command -v python3 >/dev/null 2>&1; then
  exec python3 "$ROOT/tests/resolve-project-context-metamorphic-check.py" --launcher sh
fi
if command -v python >/dev/null 2>&1; then
  exec python "$ROOT/tests/resolve-project-context-metamorphic-check.py" --launcher sh
fi
printf '%s\n' 'FAIL: no python3/python interpreter available'
exit 1
