#!/bin/sh
# Deterministic gate: validate the tasks.md state machine on disk.
# Usage: check-task-state.sh <path-to-tasks.md> [reports-dir]
# Rules enforced:
#  - Approval is Draft or Approved; Status is a known lifecycle value.
#  - In Progress / Implementation Complete / Done require Approval: Approved.
#  - Done additionally requires a quality-gate report mentioning the task id.
tasks="$1"
reports="${2:-reports/quality-gate}"

if [ -z "$tasks" ] || [ ! -f "$tasks" ]; then
  echo "check-task-state: tasks file not found: $tasks" >&2
  exit 1
fi

TASKS="$tasks" REPORTS="$reports" awk '
BEGIN { task = ""; failures = 0; count = 0 }
function fail(msg) { print " - " msg; failures++ }
/^## T-[0-9]+/ {
  if (task != "") finish()
  task = $2; approval = ""; status = ""; count++
}
/^Approval:/ { if (task != "") { approval = $0; sub(/^Approval:[ \t]*/, "", approval) } }
/^Status:/ { if (task != "") { status = $0; sub(/^Status:[ \t]*/, "", status) } }
function finish() {
  if (approval == "") fail(task " has no Approval line")
  else if (approval != "Draft" && approval != "Approved") fail(task " has invalid Approval: " approval)
  if (status == "") fail(task " has no Status line")
  else if (status != "Planned" && status != "In Progress" && status != "Blocked" && status != "Implementation Complete" && status != "Done")
    fail(task " has invalid Status: " status)
  if ((status == "In Progress" || status == "Implementation Complete" || status == "Done") && approval != "Approved")
    fail(task " is \x27" status "\x27 without Approval: Approved")
  if (status == "Done") {
    cmd = "grep -rl \x27" task "\x27 \"" ENVIRON["REPORTS"] "\" 2>/dev/null | head -1"
    cmd | getline report; close(cmd)
    if (report == "") fail(task " is Done but no quality-gate report in " ENVIRON["REPORTS"] " mentions it")
    report = ""
  }
}
END {
  if (task != "") finish()
  if (count == 0) { print "check-task-state: no tasks found"; exit 1 }
  if (failures > 0) { exit 1 }
  print "Task state check passed for " count " task(s)."
}
' "$tasks" > /tmp/check-task-state.$$ 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "Task state check FAILED:"
fi
cat /tmp/check-task-state.$$
rm -f /tmp/check-task-state.$$
exit $rc
