#!/usr/bin/env bash
# check-quality-gate-cycle-limit.sh - deterministic quality-gate cycle limit.
# Issue #112 / REQ-003 / AC-006. Replaces the prose count in ship/SKILL.md
# Step 4 with a script-plus-test safety boundary matching every other gate.
#
# Contract (internal):
#   check-quality-gate-cycle-limit.sh <task-id> [reports-dir]
#     task-id     : must match ^T-[0-9]{3}$ (else usage error, exit 2)
#     reports-dir : directory of quality-gate reports (default reports/quality-gate)
#   Behaviour:
#     count = number of files under reports-dir whose CONTENT references the
#             task id with a WORD-BOUNDARY match (so T-001 does not match
#             T-0010, mirroring issue #111). An absent reports-dir counts 0.
#     count 0/1/2 -> print `continue`,       exit 0
#     count >= 3  -> print `Escalate-Human`, exit 1
set -euo pipefail

usage() {
    echo "usage: check-quality-gate-cycle-limit.sh <task-id> [reports-dir]" >&2
    echo "  task-id must match ^T-[0-9]{3}\$ (e.g. T-001)" >&2
    echo "  reports-dir defaults to reports/quality-gate" >&2
}

task_id="${1:-}"
reports_dir="${2:-reports/quality-gate}"

# Validate the task id shape; an invalid id is a usage error (exit 2), never a
# silent zero count.
if [[ ! "$task_id" =~ ^T-[0-9]{3}$ ]]; then
    usage
    exit 2
fi

# Count gate reports whose CONTENT references this task id. Word-boundary,
# fixed-string matching (-w -F) is the shell equivalent of the .ps1
# `\b` + [regex]::Escape pattern: it rejects T-0010 when counting T-001.
# An absent directory is zero reports (fresh checkout); a real scan error
# (grep exit >= 2) fails closed rather than under-counting.
count=0
if [ -d "$reports_dir" ]; then
    set +e
    matches="$(grep -rlwF -e "$task_id" "$reports_dir" 2>/dev/null)"
    rc=$?
    set -e
    if [ "$rc" -ge 2 ]; then
        echo "check-quality-gate-cycle-limit: error scanning $reports_dir" >&2
        exit 3
    fi
    if [ -n "$matches" ]; then
        count="$(printf '%s\n' "$matches" | wc -l | tr -d '[:space:]')"
    fi
fi

if [ "$count" -ge 3 ]; then
    echo "Escalate-Human"
    exit 1
fi

echo "continue"
exit 0
