#!/usr/bin/env bash
set -euo pipefail

# Human-only application for issue #311/WFI-034. The deterministic guard
# rejects agent writes to the validator and critical-test files, so this
# script refuses to mutate them unless the operator explicitly opts in.
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
SOURCE_ROOT="${ISSUE311_SOURCE_ROOT:-/Users/jrmag/.codex/worktrees/issue311-scratch-audit}"
if [[ "${ISSUE311_APPLY:-}" != 1 ]]; then
  printf '%s\n' 'Refusing protected-file writes. Re-run with ISSUE311_APPLY=1.' >&2
  exit 2
fi

for path in \
  plugins/sdd-quality-loop/scripts/validate-review-context-set.issue311-candidate.sh \
  plugins/sdd-quality-loop/scripts/validate-review-context-set.issue311-candidate.ps1 \
  tests/issue311-scratch-isolation-candidate.tests.py; do
  [[ -f "$SOURCE_ROOT/$path" ]] || {
    # The candidate aliases use a different basename for the Python fixture.
    [[ "$path" == tests/issue311-scratch-isolation-candidate.tests.py &&
      -f "$SOURCE_ROOT/tests/issue311-scratch-isolation-candidate.tests.py" ]] || {
      printf 'missing candidate source: %s\n' "$SOURCE_ROOT/$path" >&2
      exit 1
    }
  }
done

origin_main="$(git -C "$ROOT" rev-parse origin/main)"
[[ "$origin_main" == 493ff5a84da4ab993dcdceb8cf5d07927ae45db1 ]] || {
  printf 'origin/main moved; refresh the candidate against the new tip: %s\n' "$origin_main" >&2
  exit 1
}
command -v pwsh >/dev/null 2>&1 || {
  printf '%s\n' 'pwsh is required for the cross-runtime syntax check; no files were changed' >&2
  exit 1
}
for path in tests/review-agent-isolation.tests.sh tests/review-scratch-history.tests.py; do
  git -C "$ROOT" cat-file -e "origin/main:$path" || {
    printf 'origin/main is missing required fixture: %s\n' "$path" >&2
    exit 1
  }
done
backup="$(mktemp -d "${TMPDIR:-/tmp}/sdd-issue311-apply.XXXXXX")"
printf 'Backup: %s\nOrigin main: %s\n' "$backup" "$origin_main"

protected=(
  plugins/sdd-quality-loop/scripts/validate-review-context-set.sh
  plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1
  tests/review-agent-isolation.tests.sh
  tests/review-scratch-history.tests.py
  tests/issue311-scratch-isolation.tests.py
)
for path in "${protected[@]}"; do
  if [[ -e "$ROOT/$path" ]]; then
    mkdir -p "$backup/$(dirname "$path")"
    cp -p "$ROOT/$path" "$backup/$path"
  fi
done

tmp="$(mktemp -d "${TMPDIR:-/tmp}/sdd-issue311-stage.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/plugins/sdd-quality-loop/scripts" "$tmp/tests"

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

[[ "$(sha256 "$SOURCE_ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.issue311-candidate.sh")" == \
  efc6aac7aba50f123dc74f3f2bc8c88629aa0fd959f04f25bec99dc8b0d9345d ]] || {
  printf '%s\n' 'candidate Bash validator hash mismatch' >&2
  exit 1
}
[[ "$(sha256 "$SOURCE_ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.issue311-candidate.ps1")" == \
  284e4a5e9f5335363ace48838a571d7134db73c39dac4966dbfc0e842a261d2d ]] || {
  printf '%s\n' 'candidate PowerShell validator hash mismatch' >&2
  exit 1
}
[[ "$(sha256 "$SOURCE_ROOT/tests/issue311-scratch-isolation-candidate.tests.py")" == \
  0683027ed0251a71fccde28cdfa823108d33a8b68477a4ae88c83087cf4b4ac ]] || {
  printf '%s\n' 'candidate Python test hash mismatch' >&2
  exit 1
}

# The aliases were verified against the candidate suite (28/0). Copy them to
# canonical names only after the backup above has completed.
cp "$SOURCE_ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.issue311-candidate.sh" \
  "$tmp/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
cp "$SOURCE_ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.issue311-candidate.ps1" \
  "$tmp/plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"
cp "$SOURCE_ROOT/tests/issue311-scratch-isolation-candidate.tests.py" \
  "$tmp/tests/issue311-scratch-isolation.tests.py"

# The old branch lacks the annotation/WFI-034 fixture blocks, so do not apply
# the stale follow-up patch. Take those protected fixtures from origin/main,
# where the patch's context already exists.
git -C "$ROOT" show "origin/main:tests/review-agent-isolation.tests.sh" > \
  "$tmp/tests/review-agent-isolation.tests.sh"
git -C "$ROOT" show "origin/main:tests/review-scratch-history.tests.py" > \
  "$tmp/tests/review-scratch-history.tests.py"

cp "$tmp/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh" \
  "$ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
cp "$tmp/plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1" \
  "$ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"
cp "$tmp/tests/issue311-scratch-isolation.tests.py" \
  "$ROOT/tests/issue311-scratch-isolation.tests.py"
cp "$tmp/tests/review-agent-isolation.tests.sh" \
  "$ROOT/tests/review-agent-isolation.tests.sh"
cp "$tmp/tests/review-scratch-history.tests.py" \
  "$ROOT/tests/review-scratch-history.tests.py"

chmod +x "$ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh" \
  "$ROOT/tests/review-agent-isolation.tests.sh"

bash -n "$ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
pwsh -NoProfile -Command \
  "[System.Management.Automation.Language.Parser]::ParseFile('$(printf '%s' "$ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1" | sed "s/'/''/g")',[ref]\$null,[ref]\$null) | Out-Null"

printf '%s\n' 'Applied protected #311 candidate and origin/main fixture set.'
python3 "$ROOT/tests/issue311-scratch-isolation.tests.py" --repo "$ROOT"
bash "$ROOT/tests/review-agent-isolation.tests.sh"
