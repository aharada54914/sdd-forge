#!/usr/bin/env bash
# check-quality-gate-cycle-limit.sh - deterministic quality-gate cycle limit,
# scoped to the current feature.
# Issue #112 / REQ-003 / AC-006 (original contract). Issue #167 /
# RT-20260712-001 / REQ-001 (feature-scoping fix, AC-001..AC-005): task ids
# (T-NNN) restart per feature, so an unscoped count across ALL features'
# gate reports produced a false Escalate-Human once three or more features
# happened to share a bare task id, even though the CURRENT feature's own
# count was 0. Replaces the prose count in ship/SKILL.md Step 4 with a
# script-plus-test safety boundary matching every other gate.
#
# Contract (internal):
#   check-quality-gate-cycle-limit.sh <task-id> <feature> [reports-dir]
#     task-id     : must match ^T-[0-9]{3}$ (else usage error, exit 2)
#     feature     : REQUIRED. Must match ^[a-z0-9][a-z0-9-]*$ (else usage
#                   error, exit 2)
#     reports-dir : directory of quality-gate reports (default reports/quality-gate)
#   Behaviour:
#     count = number of files under reports-dir whose CONTENT references the
#             task id with a WORD-BOUNDARY match (so T-001 does not match
#             T-0010, mirroring issue #111) AND whose OWN content carries an
#             anchored `Feature:` header line naming THIS feature
#             (^Feature:[[:space:]]*<feature>[[:space:]]*$ -- the same
#             two-predicate shape emit-run-record.sh:123,125 already
#             establishes, reused here rather than invented fresh). A
#             report carrying the task id under a DIFFERENT feature's
#             Feature: line is never counted (issue #167 /
#             RT-20260712-001). An absent reports-dir counts 0.
#     count 0/1/2 -> print `continue`,       exit 0
#     count >= 3  -> print `Escalate-Human`, exit 1
set -euo pipefail

usage() {
    echo "usage: check-quality-gate-cycle-limit.sh <task-id> <feature> [reports-dir]" >&2
    echo "  task-id must match ^T-[0-9]{3}\$ (e.g. T-001)" >&2
    echo "  feature must match ^[a-z0-9][a-z0-9-]*\$ (e.g. epic-159-pillar-d)" >&2
    echo "  reports-dir defaults to reports/quality-gate" >&2
}

task_id="${1:-}"
feature="${2:-}"
reports_dir="${3:-reports/quality-gate}"

# Validate the task id shape; an invalid id is a usage error (exit 2), never a
# silent zero count.
if [[ ! "$task_id" =~ ^T-[0-9]{3}$ ]]; then
    usage
    exit 2
fi

# Validate the feature slug shape; a missing (empty) or malformed feature is
# a usage error too -- feature is a REQUIRED second positional (AC-001).
if [[ ! "$feature" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    usage
    exit 2
fi

# Count gate reports whose CONTENT references this task id AND whose own
# Feature: header line names this feature. Word-boundary, fixed-string
# matching (-w -F) is the shell equivalent of the .ps1 `\b` +
# [regex]::Escape pattern: it rejects T-0010 when counting T-001 (BL-001).
# The Feature: predicate is applied SECOND, on the SAME file, mirroring
# emit-run-record.sh:123,125's already-landed anchor shape: escape ERE
# metacharacters in the slug (parity with the .ps1 [regex]::Escape and with
# emit-run-record.sh's own sed escape) so a feature containing an ERE
# metacharacter cannot match unintended lines -- defense in depth, since the
# stricter [a-z0-9][a-z0-9-]* grammar (AC-001) contains no ERE metacharacter
# today. An absent directory is zero reports (fresh checkout); a real scan
# error (grep exit >= 2) fails closed rather than under-counting.
count=0
if [ -d "$reports_dir" ]; then
    feature_re="$(printf '%s\n' "$feature" | sed 's/[][\\.^$*+?(){}|]/\\&/g')"
    set +e
    task_matches="$(grep -rlwF -e "$task_id" "$reports_dir" 2>/dev/null)"
    rc=$?
    set -e
    if [ "$rc" -ge 2 ]; then
        echo "check-quality-gate-cycle-limit: error scanning $reports_dir" >&2
        exit 3
    fi
    if [ -n "$task_matches" ]; then
        # Heredoc (not a pipe) so the loop runs in THIS shell, not a
        # subshell -- a `... | while read` pipeline would lose the `count`
        # increments once the pipeline exits (classic bash subshell trap).
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            if grep -qE "^Feature:[[:space:]]*${feature_re}[[:space:]]*\$" "$f" 2>/dev/null; then
                count=$((count + 1))
            fi
        done <<TASK_MATCHES
$task_matches
TASK_MATCHES
    fi
fi

if [ "$count" -ge 3 ]; then
    echo "Escalate-Human"
    exit 1
fi

echo "continue"
exit 0
