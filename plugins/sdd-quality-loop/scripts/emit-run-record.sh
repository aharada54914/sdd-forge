#!/bin/sh
# Deterministic run-record emitter for WFI effect measurement.
# Usage: emit-run-record.sh <feature-slug> [--track full|lite] [--model-main <id>]
#                           [--model-reviewers <id>] [--plugin-version <version>]
#
# Writes reports/runs/RUN-<UTC-timestamp>-<feature>.json from repository
# artifacts only (tasks.md, reports/, docs/review-tickets/,
# docs/workflow-improvements/). All metrics are counts, never percentages:
# attribution analysis at small n needs numerators and denominators.
# Metadata the repository cannot know (model ids, track) arrives as arguments;
# everything countable is counted here, not by the calling agent.
# Fail-closed: exit 1 when the feature's tasks.md is missing.

feature="${1:-}"
shift 2>/dev/null || true

track="unknown"
model_main="unknown"
model_reviewers="unknown"
plugin_version="unknown"
while [ $# -gt 0 ]; do
  case "$1" in
    --track)          track="${2:-unknown}"; shift 2 ;;
    --model-main)     model_main="${2:-unknown}"; shift 2 ;;
    --model-reviewers) model_reviewers="${2:-unknown}"; shift 2 ;;
    --plugin-version) plugin_version="${2:-unknown}"; shift 2 ;;
    *) echo "emit-run-record: unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$feature" ]; then
  echo "Usage: emit-run-record.sh <feature-slug> [--track full|lite] [--model-main <id>] [--model-reviewers <id>] [--plugin-version <version>]" >&2
  exit 1
fi

tasks="specs/${feature}/tasks.md"
if [ ! -f "$tasks" ]; then
  echo "emit-run-record: tasks file not found: $tasks" >&2
  exit 1
fi

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
file_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
out_dir="reports/runs"
out="${out_dir}/RUN-${file_stamp}-${feature}.json"
mkdir -p "$out_dir"

# --- Task counts from tasks.md (CRLF tolerated) --------------------------
task_ids="$(sed 's/\r$//' "$tasks" | sed -n 's/^## \(T-[0-9][0-9]*\).*/\1/p')"
tasks_total=0
tasks_done=0
tasks_blocked=0
for tid in $task_ids; do
  tasks_total=$((tasks_total + 1))
done
tasks_done="$(sed 's/\r$//' "$tasks" | grep -c '^Status:[ \t]*Done[ \t]*$' || true)"
tasks_blocked="$(sed 's/\r$//' "$tasks" | grep -c '^Status:[ \t]*Blocked[ \t]*$' || true)"

# --- Quality-gate reports per task (scoped to this feature) ----------------
# Task IDs (T-NNN) restart per feature, so the same bare id lives in every
# feature's reports. Restrict counting to reports whose own "Feature:" line
# names this feature -- the same per-feature identity the evidence-bundle
# validator keys on -- or T-002 from ci-mcp, sdd-domain, local-env-mcp, ...
# would all be folded into one feature's totals. Trailing-space class tolerates
# a CRLF carriage return on the Feature line.
gate_total=0
gate_blocked=0
first_pass_tasks=0
max_gate_runs=0
if [ -d "reports/quality-gate" ]; then
  feature_gate_files="$(grep -rlE "^Feature:[[:space:]]*${feature}[[:space:]]*$" reports/quality-gate 2>/dev/null || true)"
  for tid in $task_ids; do
    n=0
    for gf in $feature_gate_files; do
      grep -q "Task: ${tid}\b" "$gf" 2>/dev/null && n=$((n + 1))
    done
    gate_total=$((gate_total + n))
    [ "$n" -gt "$max_gate_runs" ] && max_gate_runs="$n"
    if [ "$n" -eq 1 ]; then
      first_pass_tasks=$((first_pass_tasks + 1))
    fi
  done
  for gf in $feature_gate_files; do
    grep -q 'BLOCKED' "$gf" 2>/dev/null && gate_blocked=$((gate_blocked + 1))
  done
fi

# --- Review tickets by severity (scoped to this feature) -------------------
# The ticket schema (references/review-ticket-rules.md) keys a ticket to its
# subject via target.feature. Without that scope every open ticket in the repo,
# regardless of which feature it targets, is charged to this run record.
tickets_critical=0
tickets_major=0
tickets_minor=0
if [ -d "docs/review-tickets" ]; then
  feature_ticket_files="$(grep -rlE "^[[:space:]]*feature:[[:space:]]*${feature}[[:space:]]*$" docs/review-tickets 2>/dev/null || true)"
  for tf in $feature_ticket_files; do
    # Anchor to the top-level severity field (like ^Status: above); an
    # unanchored match would also pick up the word in free-text prose
    # (e.g. a resolution_record) and misclassify the ticket.
    if grep -qE '^severity:[ \t]*critical[ \t]*$' "$tf" 2>/dev/null; then
      tickets_critical=$((tickets_critical + 1))
    elif grep -qE '^severity:[ \t]*major[ \t]*$' "$tf" 2>/dev/null; then
      tickets_major=$((tickets_major + 1))
    elif grep -qE '^severity:[ \t]*minor[ \t]*$' "$tf" 2>/dev/null; then
      tickets_minor=$((tickets_minor + 1))
    fi
  done
fi

# --- Active (Applied) WFIs --------------------------------------------------
active_wfis=""
if [ -d "docs/workflow-improvements" ]; then
  for wfi in docs/workflow-improvements/WFI-*.md; do
    [ -f "$wfi" ] || continue
    if sed 's/\r$//' "$wfi" | grep -q '^Status:[ \t]*Applied[ \t]*$'; then
      id="$(basename "$wfi" .md)"
      # Strip audit-artifact suffixes; only bare WFI-NNN files carry status.
      case "$id" in
        WFI-[0-9]*[!0-9]*) continue ;;
      esac
      if [ -z "$active_wfis" ]; then
        active_wfis="\"$id\""
      else
        active_wfis="$active_wfis, \"$id\""
      fi
    fi
  done
fi

cat > "$out" <<EOF
{
  "schema": "sdd-run-record/v1",
  "run_id": "${file_stamp}-${feature}",
  "generated": "${timestamp}",
  "feature": "${feature}",
  "track": "${track}",
  "model_ids": {
    "main": "${model_main}",
    "reviewers": "${model_reviewers}"
  },
  "plugin_version": "${plugin_version}",
  "active_wfis": [${active_wfis}],
  "metrics": {
    "tasks": {"done": ${tasks_done}, "blocked": ${tasks_blocked}, "total": ${tasks_total}},
    "first_pass_gate": {"passed_first_try": ${first_pass_tasks}, "total": ${tasks_total}},
    "gate_reports": {"total": ${gate_total}, "blocked": ${gate_blocked}, "max_runs_single_task": ${max_gate_runs}},
    "review_tickets": {"critical": ${tickets_critical}, "major": ${tickets_major}, "minor": ${tickets_minor}}
  }
}
EOF

echo "emit-run-record: wrote ${out}"
