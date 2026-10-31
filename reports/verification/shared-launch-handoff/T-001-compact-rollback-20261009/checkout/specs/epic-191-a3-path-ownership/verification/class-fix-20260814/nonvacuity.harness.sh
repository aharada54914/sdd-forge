#!/usr/bin/env bash
# Non-vacuity harness for the epic-191 class lock (2026-08-14).
#
# Two corrections over the first attempt:
#  - `git clone` copies HEAD, so the uncommitted class fix was not under test.
#    The working tree is now overlaid on top of each clone.
#  - a full clone always takes TEST-045.6's full-history branch, so the shallow
#    branch (the one this fix rewrites) never ran. M3/M4 now use a depth-1
#    clone via file:// so the substance form is the code under test.
#
# Every mutation lands inside a disposable clone; the real worktree is never
# written.
set -uo pipefail

SRC="$1"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# depth: "full" or "shallow"
run_case() {
  local label="$1" depth="$2" expect="$3"; shift 3
  local c="$WORK/$label"
  if [ "$depth" = "shallow" ]; then
    git clone -q --depth 1 "file://$SRC" "$c" 2>/dev/null
  else
    git clone -q --no-hardlinks "$SRC" "$c" 2>/dev/null
  fi
  # Apply the uncommitted fix as a patch, NOT as a file overlay: a tar overlay
  # cannot express DELETIONS, so the evicted staged snapshot survived from the
  # clone's HEAD and the control failed on the harness's own artifact.
  ( cd "$SRC" && git diff HEAD ) | ( cd "$c" && git apply --index - ) 2>/dev/null
  ( cd "$c" && git config user.email t@example.invalid && git config user.name t ) >/dev/null 2>&1
  ( cd "$c" && "$@" ) >/dev/null 2>&1
  local out line tally shallow
  shallow=$(cd "$c" && git rev-parse --is-shallow-repository 2>/dev/null)
  out=$(cd "$c" && bash tests/component-path-resolver.tests.sh 2>&1)
  line=$(printf '%s\n' "$out" | grep -E "^(ok|FAIL): ${expect}" | head -1)
  tally=$(printf '%s\n' "$out" | grep -E '^Results:' | head -1)
  printf '%-24s shallow=%-5s  %s\n' "$label" "$shallow" "$tally"
  printf '    %.150s\n' "${line:-<assertion line not found>}"
}

D=specs/epic-191-a3-path-ownership/human-copy

echo "=== controls (must stay green in both depths) ==="
run_case control-full    full    'TEST-045\.5' true
run_case control-shallow shallow 'TEST-045\.6' true

echo
echo "=== M1: re-add the staged snapshot file only (half-revert) ==="
run_case M1-staged-file full 'TEST-045\.5' \
  sh -c "mkdir -p $D/.github/workflows && cp .github/workflows/test.yml $D/.github/workflows/"

echo
echo "=== M2: re-add the manifest entry only (other half-revert) ==="
run_case M2-manifest-entry full 'TEST-045\.5' \
  sh -c "printf '%s  %s\n' deadbeef .github/workflows/test.yml >> $D/MANIFEST.sha256"

echo
echo "=== M3: drop the bash-leg registration from the live workflow ==="
run_case M3-bash-leg shallow 'TEST-045\.6' \
  sh -c "perl -0pi -e 's{      - name: Test component-path-resolver suite \\(bash\\).*?\n\n}{}s' .github/workflows/test.yml"

echo
echo "=== M4: drop the pwsh-leg registration from the live workflow ==="
run_case M4-pwsh-leg shallow 'TEST-045\.6' \
  sh -c "perl -0pi -e 's{      - name: Test component-path-resolver suite \\(pwsh\\).*?\n\n}{}s' .github/workflows/test.yml"
