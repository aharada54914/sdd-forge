#!/usr/bin/env bash
# self-improvement-pr-guard.sh -- deterministic pre-PR enforcement-chain guard.
#
# Usage: self-improvement-pr-guard.sh <changed-paths-file>
#
# <changed-paths-file> holds newline-separated, repository-relative paths of the
# files changed by the branches/PRs the weekly self-improvement session created.
#
#   * file empty or absent      -> vacuous pass, exit 0   (REQ-005 / AC-014)
#   * any path on the denylist  -> list them all, exit 1  (REQ-005 / AC-011)
#   * otherwise                 -> exit 0                  (REQ-005 / AC-011)
#   * no argument               -> usage error, exit 2
#
# The denylist is the enforcement-chain surface (design.md / infra-spec.md /
# security-spec.md boundary B2): guard twins, kill-switch, check-* scripts,
# plugin hook configs, reports/, docs/workflow-improvements/, workflow files,
# protected review/ship SKILL.md files, .claude settings, protected parity/gate
# tests, and plugin manifests. Matching is fail-closed: a path matching any
# pattern fails the run so the automation can never silently modify the chain
# that constrains it. Pure and side-effect free (reads one file, writes stdout/
# stderr, sets an exit code) so it is deterministically testable off-CI.
set -eo pipefail

# Returns 0 (match) when the path is an enforcement-chain surface, else 1.
# `case` glob `*` spans path separators, keeping the check broad / fail-closed.
is_enforcement_chain() {
  case "$1" in
    plugins/*/scripts/sdd-hook-guard.*) return 0 ;;
    plugins/*/scripts/kill-switch.*)    return 0 ;;
    plugins/*/scripts/check-*)          return 0 ;;
    plugins/*/hooks/*.json)             return 0 ;;
    reports/*)                          return 0 ;;
    docs/workflow-improvements/*)       return 0 ;;
    .github/workflows/*)                return 0 ;;
    plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md) return 0 ;;
    plugins/sdd-review-loop/skills/task-review-loop/SKILL.md) return 0 ;;
    plugins/sdd-ship/skills/ship/SKILL.md)                    return 0 ;;
    .claude/settings*.json)             return 0 ;;
    tests/gates.tests.sh)               return 0 ;;
    tests/eval.tests.sh)                return 0 ;;
    tests/guard-parity.tests.sh)        return 0 ;;
    tests/constant-parity.tests.sh)     return 0 ;;
    */plugin.json)                      return 0 ;;
    *) return 1 ;;
  esac
}

main() {
  local paths_file="${1:-}"
  if [ -z "$paths_file" ]; then
    printf 'usage: %s <changed-paths-file>\n' "${0##*/}" >&2
    exit 2
  fi

  # Vacuous pass: the session created no branch/PR, so there is nothing to
  # inspect. An absent file and an empty file both mean "no changed paths".
  if [ ! -e "$paths_file" ]; then
    printf 'self-improvement-pr-guard: no changed-paths file (%s) -- no branch/PR created; vacuous pass.\n' "$paths_file"
    exit 0
  fi
  if [ ! -s "$paths_file" ]; then
    printf 'self-improvement-pr-guard: changed-paths file is empty -- no enforcement-chain change; vacuous pass.\n'
    exit 0
  fi

  local line path violations="" count=0
  while IFS= read -r line || [ -n "$line" ]; do
    path="${line%$'\r'}" # tolerate CRLF input
    [ -z "$path" ] && continue
    if is_enforcement_chain "$path"; then
      violations="${violations}${path}"$'\n'
      count=$((count + 1))
    fi
  done <"$paths_file"

  if [ "$count" -gt 0 ]; then
    printf 'self-improvement-pr-guard: enforcement-chain violation -- the session changed %d protected surface(s):\n' "$count" >&2
    printf '%s' "$violations" | sed 's/^/  /' >&2
    exit 1
  fi

  printf 'self-improvement-pr-guard: no enforcement-chain surfaces changed -- pass.\n'
  exit 0
}

main "$@"
