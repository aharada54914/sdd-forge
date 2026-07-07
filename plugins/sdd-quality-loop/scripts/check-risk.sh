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
#  - Structured risk fields (Risk Impact / Risk Reversibility / Risk Surface)
#    are optional (legacy tasks omit them). When present, each value maps to a
#    minimum tier per risk-classification-policy.md and the declared Risk must
#    be at or above the highest derived floor; unknown values and floor
#    violations are policy-inconsistent and fail closed (REQ-001).
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
  RANK["low"] = 1; RANK["medium"] = 2; RANK["high"] = 3; RANK["critical"] = 4
  TIER_NAME[1] = "low"; TIER_NAME[2] = "medium"; TIER_NAME[3] = "high"; TIER_NAME[4] = "critical"
  # Minimum tier implied by each structured value (risk-classification-policy.md):
  # material impact / difficult reversibility / sensitive surface describe the
  # high tier; behavioral surface excludes low ("non-behavioral"), so medium.
  IMPACT_FLOOR["limited"] = 1; IMPACT_FLOOR["material"] = 3
  REVERSIBILITY_FLOOR["controlled"] = 1; REVERSIBILITY_FLOOR["difficult"] = 3
  SURFACE_FLOOR["behavioral"] = 2; SURFACE_FLOOR["sensitive"] = 3
}
# Strip a trailing CR so a CRLF-encoded tasks.md parses identically to LF (cross-platform parity).
{ sub(/\r$/, "") }
/^## T-[0-9]+/ {
  if (task != "") finish()
  newid = $2
  task = newid; risk = ""; risk_rationale = ""; required_workflow = ""; count++
  risk_impact = ""; risk_reversibility = ""; risk_surface = ""
}
/^Risk:/ { if (task != "") { risk = $0; sub(/^Risk:[ \t]*/, "", risk); gsub(/[ \t]+$/, "", risk) } }
/^Risk Impact:/ { if (task != "") { risk_impact = $0; sub(/^Risk Impact:[ \t]*/, "", risk_impact); gsub(/[ \t]+$/, "", risk_impact) } }
/^Risk Reversibility:/ { if (task != "") { risk_reversibility = $0; sub(/^Risk Reversibility:[ \t]*/, "", risk_reversibility); gsub(/[ \t]+$/, "", risk_reversibility) } }
/^Risk Surface:/ { if (task != "") { risk_surface = $0; sub(/^Risk Surface:[ \t]*/, "", risk_surface); gsub(/[ \t]+$/, "", risk_surface) } }
/^Risk Rationale:/ { if (task != "") { risk_rationale = $0; sub(/^Risk Rationale:[ \t]*/, "", risk_rationale); gsub(/[ \t]+$/, "", risk_rationale) } }
/^Required Workflow:/ { if (task != "") { required_workflow = $0; sub(/^Required Workflow:[ \t]*/, "", required_workflow); gsub(/[ \t]+$/, "", required_workflow) } }

function finish(floor) {
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

  # Structured fields are optional; when present the declared Risk must not
  # sit below the highest tier floor they derive. Only compared when risk is
  # a valid tier, to avoid stacking on top of an "invalid Risk" report.
  floor = 0
  if (risk_impact != "") {
    if (!(risk_impact in IMPACT_FLOOR)) {
      print " - " task " has invalid Risk Impact: " risk_impact; failures++
    } else if (IMPACT_FLOOR[risk_impact] > floor) floor = IMPACT_FLOOR[risk_impact]
  }
  if (risk_reversibility != "") {
    if (!(risk_reversibility in REVERSIBILITY_FLOOR)) {
      print " - " task " has invalid Risk Reversibility: " risk_reversibility; failures++
    } else if (REVERSIBILITY_FLOOR[risk_reversibility] > floor) floor = REVERSIBILITY_FLOOR[risk_reversibility]
  }
  if (risk_surface != "") {
    if (!(risk_surface in SURFACE_FLOOR)) {
      print " - " task " has invalid Risk Surface: " risk_surface; failures++
    } else if (SURFACE_FLOOR[risk_surface] > floor) floor = SURFACE_FLOOR[risk_surface]
  }
  if (floor > 0 && (risk in RANK) && RANK[risk] < floor) {
    print " - " task " Risk: " risk " is inconsistent with its structured risk fields (policy floor: " TIER_NAME[floor] ")"; failures++
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
