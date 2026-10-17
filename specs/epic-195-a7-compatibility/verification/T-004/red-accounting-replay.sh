#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
MODE="${1:?usage: red-accounting-replay.sh red|green}"
[[ "$MODE" == red || "$MODE" == green ]]
WORK="$(mktemp -d "${TMPDIR:-/tmp}/t004-red-accounting.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
git clone --quiet --shared "$ROOT" "$WORK/repo"
rsync -a --exclude '.git' "$ROOT/" "$WORK/repo/"
git -C "$WORK/repo" update-ref refs/remotes/origin/main "$(git -C "$ROOT" rev-parse origin/main)"
printf 'MODE=%s\nSOURCE_HEAD=%s\nORIGIN_MAIN=%s\n' "$MODE" "$(git -C "$ROOT" rev-parse HEAD)" "$(git -C "$ROOT" rev-parse origin/main)"
if [[ "$MODE" == red ]]; then
  git -C "$ROOT" show abc7ab4a:tests/structural-compatibility.tests.ps1 > "$WORK/repo/tests/structural-compatibility.tests.ps1"
  printf 'PRE_FIX_COMMIT=%s\n' "$(git -C "$ROOT" rev-parse abc7ab4a)"
fi
cd "$WORK/repo"
shasum -a 256 specs/epic-195-a7-compatibility/verification/T-004/mutation-proof.sh tests/structural-compatibility.tests.sh tests/structural-compatibility.tests.ps1
set +e
bash specs/epic-195-a7-compatibility/verification/T-004/mutation-proof.sh
rc=$?
set -e
printf 'EXIT_CODE=%d\n' "$rc"
[[ "$MODE" == red && "$rc" == 1 || "$MODE" == green && "$rc" == 0 ]]
