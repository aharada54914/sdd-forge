#!/bin/sh
# Deterministic run-record emitter for WFI effect measurement.
# Usage: emit-run-record.sh <feature-slug> [--track full|lite] [--model-main <id>]
#                           [--model-reviewers <id>] [--plugin-version <version>]
#                           [--effort-main <e>] [--effort-reviewers <e>]
#                           [--effort-control-main <flag|frontmatter|none>]
#                           [--effort-control-reviewers <flag|frontmatter|none>]
#                           [--effort-applied-main <e|none>]
#                           [--effort-applied-reviewers <e|none>]
#
# Writes reports/runs/RUN-<UTC-timestamp>-<feature>.json from repository
# artifacts only (tasks.md, reports/, docs/review-tickets/,
# docs/workflow-improvements/). All metrics are counts, never percentages:
# attribution analysis at small n needs numerators and denominators.
# Metadata the repository cannot know (model ids, track) arrives as arguments;
# everything countable is counted here, not by the calling agent.
# Fail-closed: exit 1 when the feature's tasks.md is missing.
#
# schema: emitted "sdd-run-record/v1" (unchanged, byte-identical to every
# pre-feature invocation) unless ANY --effort-* flag below is supplied, in
# which case "sdd-run-record/v2" is emitted with an additive sibling
# "effort" object (main/reviewers, each carrying effort_requested/
# effort_applied/effort_degraded_reason). effort_applied can only ever
# reach a non-null value through the confirmed-application path (an
# --effort-applied-<role> value paired with --effort-control-<role> flag);
# every other combination structurally yields null + a named
# effort_degraded_reason (security-spec.md B4 -- no path can report a
# false "applied").

feature="${1:-}"
shift 2>/dev/null || true

track="unknown"
model_main="unknown"
model_reviewers="unknown"
plugin_version="unknown"
emit_v2=0
effort_main=""; effort_main_set=0
effort_reviewers=""; effort_reviewers_set=0
effort_control_main=""; effort_control_main_set=0
effort_control_reviewers=""; effort_control_reviewers_set=0
effort_applied_main=""; effort_applied_main_set=0
effort_applied_reviewers=""; effort_applied_reviewers_set=0

require_effort_control_value() {
  # $1 = flag name (for diagnostics), $2 = value
  case "$2" in
    flag|frontmatter|none) ;;
    *)
      printf 'emit-run-record: %s must be one of flag|frontmatter|none (got: %s)\n' "$1" "$2" >&2
      exit 1
      ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --track)          track="${2:-unknown}"; shift 2 ;;
    --model-main)     model_main="${2:-unknown}"; shift 2 ;;
    --model-reviewers) model_reviewers="${2:-unknown}"; shift 2 ;;
    --plugin-version) plugin_version="${2:-unknown}"; shift 2 ;;
    --effort-main)
      effort_main="${2:-}"; effort_main_set=1; emit_v2=1; shift 2 ;;
    --effort-reviewers)
      effort_reviewers="${2:-}"; effort_reviewers_set=1; emit_v2=1; shift 2 ;;
    --effort-control-main)
      effort_control_main="${2:-}"
      require_effort_control_value "--effort-control-main" "$effort_control_main"
      effort_control_main_set=1; emit_v2=1; shift 2 ;;
    --effort-control-reviewers)
      effort_control_reviewers="${2:-}"
      require_effort_control_value "--effort-control-reviewers" "$effort_control_reviewers"
      effort_control_reviewers_set=1; emit_v2=1; shift 2 ;;
    --effort-applied-main)
      effort_applied_main="${2:-}"; effort_applied_main_set=1; emit_v2=1; shift 2 ;;
    --effort-applied-reviewers)
      effort_applied_reviewers="${2:-}"; effort_applied_reviewers_set=1; emit_v2=1; shift 2 ;;
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
# Escape ERE metacharacters in the slug (parity with the PowerShell
# [regex]::Escape) so a feature like "v2.0" cannot match unintended lines.
feature_re="$(printf '%s\n' "$feature" | sed 's/[][\\.^$*+?(){}|]/\\&/g')"
if [ -d "reports/quality-gate" ]; then
  feature_gate_files="$(grep -rlE "^Feature:[[:space:]]*${feature_re}[[:space:]]*$" reports/quality-gate 2>/dev/null || true)"
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
  feature_ticket_files="$(grep -rlE "^[[:space:]]*feature:[[:space:]]*${feature_re}[[:space:]]*$" docs/review-tickets 2>/dev/null || true)"
  for tf in $feature_ticket_files; do
    # Anchor to the top-level severity field (like ^Status: above); an
    # unanchored match would also pick up the word in free-text prose
    # (e.g. a resolution_record) and misclassify the ticket.
    if grep -qE '^severity:[[:space:]]*critical[[:space:]]*$' "$tf" 2>/dev/null; then
      tickets_critical=$((tickets_critical + 1))
    elif grep -qE '^severity:[[:space:]]*major[[:space:]]*$' "$tf" 2>/dev/null; then
      tickets_major=$((tickets_major + 1))
    elif grep -qE '^severity:[[:space:]]*minor[[:space:]]*$' "$tf" 2>/dev/null; then
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

if [ "$emit_v2" = "1" ]; then
  # --- Effort field-population (sdd-run-record/v2, security-spec.md B4) ----
  # Per role slot: effort_requested is recorded iff its --effort-<role> flag
  # was supplied; effort_applied is non-null iff --effort-applied-<role>
  # carries a real (non-"none") value AND --effort-control-<role> resolved
  # to "flag" (the only confirmed-application path); every other reachable
  # combination structurally yields effort_applied=null plus a named,
  # non-vacuous effort_degraded_reason keyed on the resolved effort_control
  # value -- never on host identity (AC-051).
  json_str_or_null() {
    if [ -z "$1" ]; then printf 'null'; else printf '"%s"' "$1"; fi
  }

  resolve_effort_slot() {
    # $1=requested_set $2=requested_value $3=control_value
    # $4=applied_set $5=applied_value
    req_set="$1"; req_val="$2"; ctrl_val="$3"; app_set="$4"; app_val="$5"

    if [ "$req_set" != "1" ]; then
      OUT_REQUESTED=""; OUT_APPLIED=""; OUT_REASON=""
      return 0
    fi
    OUT_REQUESTED="$req_val"

    if [ "$app_set" = "1" ] && [ "$app_val" != "none" ]; then
      if [ "$ctrl_val" != "flag" ]; then
        printf 'emit-run-record: --effort-applied-* requires the paired --effort-control-* to resolve to "flag" (got: %s)\n' "${ctrl_val:-<unset>}" >&2
        exit 1
      fi
      OUT_APPLIED="$app_val"; OUT_REASON=""
      return 0
    fi

    OUT_APPLIED=""
    case "$ctrl_val" in
      frontmatter) OUT_REASON="effort-control-frontmatter" ;;
      none)        OUT_REASON="effort-control-none" ;;
      flag)
        if [ "$app_set" = "1" ]; then
          OUT_REASON="effort-application-declined"
        else
          OUT_REASON="effort-application-not-confirmed"
        fi
        ;;
      *) OUT_REASON="effort-control-unspecified" ;;
    esac
  }

  resolve_effort_slot "$effort_main_set" "$effort_main" "$effort_control_main" \
    "$effort_applied_main_set" "$effort_applied_main"
  effort_requested_main_json="$(json_str_or_null "$OUT_REQUESTED")"
  effort_applied_main_json="$(json_str_or_null "$OUT_APPLIED")"
  effort_degraded_reason_main_json="$(json_str_or_null "$OUT_REASON")"

  resolve_effort_slot "$effort_reviewers_set" "$effort_reviewers" "$effort_control_reviewers" \
    "$effort_applied_reviewers_set" "$effort_applied_reviewers"
  effort_requested_reviewers_json="$(json_str_or_null "$OUT_REQUESTED")"
  effort_applied_reviewers_json="$(json_str_or_null "$OUT_APPLIED")"
  effort_degraded_reason_reviewers_json="$(json_str_or_null "$OUT_REASON")"

  cat > "$out" <<EOF
{
  "schema": "sdd-run-record/v2",
  "run_id": "${file_stamp}-${feature}",
  "generated": "${timestamp}",
  "feature": "${feature}",
  "track": "${track}",
  "model_ids": {
    "main": "${model_main}",
    "reviewers": "${model_reviewers}"
  },
  "effort": {
    "main": {
      "effort_requested": ${effort_requested_main_json},
      "effort_applied": ${effort_applied_main_json},
      "effort_degraded_reason": ${effort_degraded_reason_main_json}
    },
    "reviewers": {
      "effort_requested": ${effort_requested_reviewers_json},
      "effort_applied": ${effort_applied_reviewers_json},
      "effort_degraded_reason": ${effort_degraded_reason_reviewers_json}
    }
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
else
  # v1 shape, byte-identical to every pre-feature invocation (AC-025). This
  # heredoc is intentionally an exact, unmodified copy of the pre-T-004
  # emission -- never touched when adding v2 fields above, so the no-flags
  # code path can never silently drift from v1's historical byte shape.
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
fi

echo "emit-run-record: wrote ${out}"
