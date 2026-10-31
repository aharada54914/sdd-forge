#!/usr/bin/env bash
# Human application only; do not run through an agent to evade a hook refusal.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
cd "$here/../../../.."
test "$(git rev-parse --show-toplevel)" = "$(pwd -P)"
patch=specs/epic-196-a8-integration/verification/T-001/copilot-json-shape-repair.patch
paths=(plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1 plugins/sdd-quality-loop/scripts/sdd-hook-guard.py tests/guard-r10-port.tests.ps1)
for tool in git shasum pwsh; do command -v "$tool" >/dev/null; done
for path in "$patch" "${paths[@]}"; do test -f "$path" && test ! -L "$path"; done
shasum -a 256 -c <<'HASHES'
9fb5b6e59a823ab7b89d2fd5786315c3e2bf91f0e239e3a43133a4a46901d423  plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1
d0a81f4b9762288c2d2833f0a340e2eb8c593d6013fd3415eac30f93e53f5bfc  plugins/sdd-quality-loop/scripts/sdd-hook-guard.py
ebfcc9d71362981206a155d12fb588e1f62f4fbb43103fc20be81a4437b0d482  tests/guard-r10-port.tests.ps1
59a06ff3d56cdd3ad9694ff8b8384b91f2a1020cc812c345cec507baff2fada4  specs/epic-196-a8-integration/verification/T-001/copilot-json-shape-repair.patch
HASHES
git apply --check --unidiff-zero "$patch"
backup=$(mktemp -d "${TMPDIR:-/tmp}/sdd-copilot-json-backup.XXXXXX")
for path in "${paths[@]}"; do mkdir -p "$backup/$(dirname -- "$path")"; cp -p "$path" "$backup/$path"; done
echo "Backup: $backup"
git apply --unidiff-zero "$patch"
pwsh -NoProfile -File tests/guard-r10-port.tests.ps1
pwsh -NoProfile -File tests/hooks.tests.ps1
git diff --check -- "${paths[@]}"
echo 'Applied and local regressions passed. Native activation, formal review, CI and merge remain unverified. No commit/push/merge.'
