#!/bin/sh
# Deterministic gate: validate the tasks.md state machine on disk.
# Usage: check-task-state.sh <path-to-tasks.md> [reports-dir] [impl-reports-dir]
# Reports dirs default to reports/quality-gate and reports/implementation.
# Rules enforced:
#  - Approval is Draft or Approved; Status is a known lifecycle value.
#  - In Progress / Implementation Complete / Done require Approval: Approved.
#  - Done additionally requires a quality-gate report mentioning the task id,
#    AND a verification/<task-id>.contract.json file in the tasks.md directory.
#  - Implementation Complete requires an implementation report mentioning the task id.
#  - Blocked requires non-empty ### Blockers content (not None/whitespace/bare list markers).
#  - Duplicate task ids (## T-NNN repeated) → fail.
tasks="$1"
reports="${2:-reports/quality-gate}"
impl_reports="${3:-reports/implementation}"

if [ -z "$tasks" ] || [ ! -f "$tasks" ]; then
  echo "check-task-state: tasks file not found: $tasks" >&2
  exit 1
fi

_tmpout="$(mktemp)"
trap 'rm -f "$_tmpout"' EXIT

TASKS="$tasks" REPORTS="$reports" IMPL_REPORTS="$impl_reports" awk '
BEGIN {
  task = ""; failures = 0; count = 0
  in_blockers = 0; blockers_content = ""
}
function fail(msg) { print " - " msg; failures++ }
/^## T-[0-9]+/ {
  if (task != "") finish()
  newid = $2
  if (seen[newid]) {
    fail("duplicate task id " newid)
  }
  seen[newid] = 1
  task = newid; approval = ""; status = ""; count++
  in_blockers = 0; blockers_content = ""
}
/^Approval:/ { if (task != "") { approval = $0; sub(/^Approval:[ \t]*/, "", approval); in_blockers = 0 } }
/^Status:/ { if (task != "") { status = $0; sub(/^Status:[ \t]*/, "", status); in_blockers = 0 } }
/^### Blockers/ { if (task != "") { in_blockers = 1 } }
/^## [^#]/ { if ($0 !~ /^## T-[0-9]+/) { in_blockers = 0 } }
{
  if (in_blockers && $0 !~ /^### Blockers/) {
    line = $0
    # Strip leading whitespace, list markers, and common "none" values
    gsub(/^[ \t]*[-*][ \t]*/, "", line)
    gsub(/^[ \t]+/, "", line)
    if (line != "" && tolower(line) != "none") {
      blockers_content = blockers_content line
    }
  }
}
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
    # Check for verification contract file
    tasks_dir = ENVIRON["TASKS"]
    # NOTE: escape "/" instead of bracketing it ([/]) — BSD awk (macOS) rejects
    # an unescaped "/" inside a bracket expression as an unterminated regex.
    sub(/\/[^\/]*$/, "", tasks_dir)
    if (tasks_dir == ENVIRON["TASKS"]) tasks_dir = "."
    contract_path = tasks_dir "/verification/" task ".contract.json"
    cmd2 = "test -f \"" contract_path "\" && echo yes || echo no"
    cmd2 | getline exists; close(cmd2)
    if (exists != "yes") fail(task " is Done but verification/" task ".contract.json does not exist in " tasks_dir)
  }
  if (status == "Implementation Complete") {
    cmd = "grep -rl \x27" task "\x27 \"" ENVIRON["IMPL_REPORTS"] "\" 2>/dev/null | head -1"
    cmd | getline impl_report; close(cmd)
    if (impl_report == "") fail(task " is Implementation Complete but no implementation report in " ENVIRON["IMPL_REPORTS"] " mentions it")
    impl_report = ""
  }
  if (status == "Blocked") {
    if (blockers_content == "") fail(task " is Blocked but ### Blockers section has no content (not None or empty)")
  }
}
END {
  if (task != "") finish()
  if (count == 0) { print "check-task-state: no tasks found"; exit 1 }
  if (failures > 0) { exit 1 }
  print "Task state check passed for " count " task(s)."
}
' "$tasks" > "$_tmpout" 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "Task state check FAILED:"
fi
cat "$_tmpout"
exit $rc
