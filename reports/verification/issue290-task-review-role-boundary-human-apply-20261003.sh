#!/usr/bin/env bash
set -euo pipefail

# Human-only, exact-byte candidate. Do not run as an agent or against a changed tree.
[[ "${ISSUE290_ROLE_APPLY:-}" == 1 ]] || {
  printf '%s\n' 'Refusing protected-file apply; set ISSUE290_ROLE_APPLY=1 after human review.' >&2
  exit 2
}

repo="${ISSUE290_ROLE_REPO:-$(pwd -P)}"
patch="$repo/reports/verification/issue290-task-review-role-boundary-candidate-20261003.patch"
cd "$repo"

check_sha() {
  local path="$1" expected="$2" actual
  [[ -f "$path" ]] || { printf 'Missing: %s\n' "$path" >&2; exit 2; }
  actual="$(shasum -a 256 "$path" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || {
    printf 'Changed: %s (expected %s; got %s)\n' "$path" "$expected" "$actual" >&2
    exit 2
  }
}

check_sha "$patch" 6590f15b62985c5b2d5d3499e454b42b6cfaeb32b900b28e88e9a020c4d2952d
check_sha plugins/sdd-review-loop/agents/task-reviewer-a.md bdb7c2cde255ae57c676abf1fc7031d88ea4ce257e7a13223632e4e05b448bdf
check_sha plugins/sdd-review-loop/agents/task-reviewer-b.md 9af60291bfabdff5058e870a4f749837f5180853e91435cf8fcdb54cab257e82
git diff --quiet -- plugins/sdd-review-loop/agents/task-reviewer-a.md plugins/sdd-review-loop/agents/task-reviewer-b.md || {
  printf '%s\n' 'Protected targets are dirty; aborting.' >&2
  exit 2
}

# All preflight checks precede the first write; failure leaves the targets untouched.
git apply --check "$patch"
git apply "$patch"
git diff --check -- plugins/sdd-review-loop/agents/task-reviewer-a.md plugins/sdd-review-loop/agents/task-reviewer-b.md
printf '%s\n' 'Applied the exact candidate to both protected reviewer roles. No reservation, commit, push, or merge performed.'
