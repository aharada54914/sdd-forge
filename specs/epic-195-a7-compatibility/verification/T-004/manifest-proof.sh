#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
SOURCE="$ROOT/specs/epic-195-a7-compatibility/human-copy"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/t004-manifest.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

cp -R "$SOURCE/." "$WORK/"
(
  cd "$WORK"
  shasum -a 256 -c MANIFEST.sha256
)

printf '\n# mutation\n' >> "$WORK/.github/workflows/test.yml"
if (
  cd "$WORK"
  shasum -a 256 -c MANIFEST.sha256
) >/dev/null 2>&1; then
  printf '%s\n' 'MUTATION-SURVIVED: staged workflow corruption was accepted' >&2
  exit 1
fi
printf '%s\n' 'MUTATION-KILLED: staged workflow corruption invalidates MANIFEST.sha256'

cp "$SOURCE/.github/workflows/test.yml" "$WORK/.github/workflows/test.yml"
(
  cd "$WORK"
  shasum -a 256 -c MANIFEST.sha256
)
printf '%s\n' 'RESTORE-GREEN: staged workflow and manifest agree'
