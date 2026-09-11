#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/t004-bump.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

rsync -a --exclude '.git' "$ROOT/" "$WORK/repo/"
OLD="$(sed -n 's/.*"sdd-ship"[[:space:]]*=[[:space:]]*"\([0-9.]*\)".*/\1/p' "$WORK/repo/tests/validate-repository.ps1" | head -1)"
IFS=. read -r major minor patch <<< "$OLD"
NEW="$major.$minor.$((patch + 1))"

sed -i.bak "s/^## Unreleased/## v$NEW (scratch replay)/" "$WORK/repo/CHANGELOG.md"
rm "$WORK/repo/CHANGELOG.md.bak"
REPLAY_PATH="$PATH"
if sed --version >/dev/null 2>&1; then
  printf '%s\n' 'BUMP-REPLAY-SED: host sed is GNU-compatible'
else
  GNU_SED="$(command -v gsed)"
  mkdir -p "$WORK/bin"
  ln -s "$GNU_SED" "$WORK/bin/sed"
  REPLAY_PATH="$WORK/bin:$PATH"
  printf 'BUMP-REPLAY-SED: host sed is BSD; unchanged script uses %s as sed\n' "$GNU_SED"
fi
(
  cd "$WORK/repo"
  PATH="$REPLAY_PATH" bash scripts/bump-version.sh "$NEW"
  STRUCTURAL_COMPAT_REPO_ROOT="$WORK/repo" bash tests/structural-compatibility.tests.sh
  STRUCTURAL_COMPAT_REPO_ROOT="$WORK/repo" pwsh -NoProfile -File tests/structural-compatibility.tests.ps1
)
printf 'BUMP-REPLAY-GREEN: structural baselines survived %s -> %s\n' "$OLD" "$NEW"
