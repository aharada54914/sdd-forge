#!/bin/sh
# Deterministic gate: validate Risk field in tasks.md
# Usage: check-risk.sh <path-to-tasks.md> [task-id]
#
# Rules enforced:
#  - Every task must have a Risk: line with a valid value (low, medium, high, critical)
#  - Every task must have a Risk Rationale: line with non-empty content
#  - A high/critical task MUST declare `Required Workflow: tdd` (risk->workflow
#    derivation, design.md:118; matrix red->green row). low/medium are not
#    constrained here (stricter is allowed; absent risk = legacy, not reached).
#  - If task-id arg is given, validate only that task
#  - Fail-closed; exit 1 on any validation failure
tasks="$1"
task_id_filter="${2:-}"

if [ -z "$tasks" ] || [ ! -f "$tasks" ]; then
  echo "check-risk: tasks file not found: $tasks" >&2
  exit 1
fi

_tmpout="$(mktemp)"
trap 'rm -f "$_tmpout"' EXIT

awk \
  -v FILTER="$task_id_filter" \
  '
BEGIN {
  task = ""; failures = 0; count = 0; found_filter = 0
}
/^## T-[0-9]+/ {
  if (task != "") finish()
  newid = $2
  task = newid; risk = ""; risk_rationale = ""; required_workflow = ""; count++
}
/^Risk:/ { if (task != "") { risk = $0; sub(/^Risk:[ \t]*/, "", risk); gsub(/[ \t]+$/, "", risk) } }
/^Risk Rationale:/ { if (task != "") { risk_rationale = $0; sub(/^Risk Rationale:[ \t]*/, "", risk_rationale); gsub(/[ \t]+$/, "", risk_rationale) } }
/^Required Workflow:/ { if (task != "") { required_workflow = $0; sub(/^Required Workflow:[ \t]*/, "", required_workflow); gsub(/[ \t]+$/, "", required_workflow) } }

function finish() {
  if (FILTER != "" && task != FILTER) return
  if (FILTER != "") found_filter = 1

  if (risk == "") {
    print " - " task " has no Risk line"; failures++
  } else if (risk != "low" && risk != "medium" && risk != "high" && risk != "critical") {
    print " - " task " has invalid Risk: " risk; failures++
  }

  if (risk_rationale == "") {
    print " - " task " has empty Risk Rationale"; failures++
  }

  # high/critical risk must declare Required Workflow: tdd (design.md:118).
  # Only checked when risk is a valid high/critical value, to avoid stacking
  # this message on top of an "invalid Risk" report. low/medium unconstrained.
  if (risk == "high" || risk == "critical") {
    if (required_workflow == "") {
      print " - " task " (risk " risk ") must declare Required Workflow: tdd (none found)"; failures++
    } else if (required_workflow != "tdd") {
      print " - " task " (risk " risk ") must declare Required Workflow: tdd, found: " required_workflow; failures++
    }
  }
}

END {
  if (task != "") finish()

  if (FILTER != "" && !found_filter) {
    # Fail closed: a requested task id that is not present is an error, not a pass.
    print " - requested task " FILTER " not found in " FILENAME; failures++
  } else if (count == 0 && FILTER == "") {
    print "check-risk: no tasks found in " FILENAME; exit 1
  }

  if (failures > 0) { exit 1 }
  if (FILTER != "") {
    print "Risk check passed for task " FILTER "."
  } else {
    print "Risk check passed for " count " task(s)."
  }
}
' "$tasks" > "$_tmpout" 2>&1

rc=$?
if [ $rc -ne 0 ]; then
  echo "Risk check FAILED:"
fi
cat "$_tmpout"
exit $rc
