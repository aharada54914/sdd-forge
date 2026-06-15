#!/bin/sh
# Deterministic gate (lite): validate the tasks.md state machine for the sdd-lite flow.
# Usage: check-task-state-lite.sh <path-to-tasks.md> [reports-dir] [impl-reports-dir] [repo-root]
# Reports dirs default to reports/quality-gate and reports/implementation.
# Lite differences vs check-task-state.sh:
#  - Done does NOT require verification/<id>.evidence.json or .contract.json.
#  - Done requires: Approval: Approved + an implementation report mentioning the
#    task id + a quality-gate report mentioning the task id with VERDICT: PASS.
#  - No critical two-person-approval enforcement (lite has no critical tier).
# Shared rules (same as the full gate):
#  - Approval is Draft or Approved; Status is a known lifecycle value.
#  - In Progress / Implementation Complete / Done require Approval: Approved.
#  - Implementation Complete (and Done) require an implementation report mentioning the task id.
#  - Blocked requires non-empty ### Blockers content.
#  - Duplicate task ids → fail.
tasks="$1"
reports="${2:-reports/quality-gate}"
impl_reports="${3:-reports/implementation}"
repo_root="${4:-.}"

if [ -z "$tasks" ] || [ ! -f "$tasks" ]; then
  echo "check-task-state-lite: tasks file not found: $tasks" >&2
  exit 1
fi

_tmpout="$(mktemp)"
trap 'rm -f "$_tmpout"' EXIT

TASKS="$tasks" REPORTS="$reports" IMPL_REPORTS="$impl_reports" REPO_ROOT="$repo_root" awk '
BEGIN { task=""; failures=0; count=0; in_blockers=0; blockers_content="" }
# Strip trailing CR so CRLF tasks.md parses identically to LF (cross-platform parity).
{ sub(/\r$/, "") }
function fail(msg) { print " - " msg; failures++ }
/^## T-[0-9]+/ {
  if (task != "") finish()
  newid = $2
  if (seen[newid]) fail("duplicate task id " newid)
  seen[newid] = 1
  task = newid; approval=""; status=""; count++
  in_blockers=0; blockers_content=""
}
/^Approval:/ { if (task != "") { approval=$0; sub(/^Approval:[ \t]*/, "", approval); in_blockers=0 } }
/^Status:/   { if (task != "") { status=$0;   sub(/^Status:[ \t]*/, "", status);   in_blockers=0 } }
/^### Blockers/ { if (task != "") { in_blockers=1 } }
/^## [^#]/ { if ($0 !~ /^## T-[0-9]+/) { in_blockers=0 } }
{
  if (in_blockers && $0 !~ /^### Blockers/) {
    line=$0
    gsub(/^[ \t]*[-*][ \t]*/, "", line)
    gsub(/^[ \t]+/, "", line)
    if (line != "" && tolower(line) != "none") blockers_content = blockers_content line
  }
}
function finish(   is_valid_approval, is_approved, cmd, impl_report, f, ok, vc, qa_found) {
  if (approval == "") fail(task " has no Approval line")
  else {
    is_valid_approval = (approval == "Draft" || approval == "Approved" || \
      approval ~ /^Approved \([^ )]+ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\)$/)
    if (!is_valid_approval) fail(task " has invalid Approval: " approval)
  }
  is_approved = (approval == "Approved" || approval ~ /^Approved \([^ )]+ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\)$/)
  if (status == "") fail(task " has no Status line")
  else if (status != "Planned" && status != "In Progress" && status != "Blocked" && status != "Implementation Complete" && status != "Done")
    fail(task " has invalid Status: " status)
  if ((status == "In Progress" || status == "Implementation Complete" || status == "Done") && !is_approved)
    fail(task " is \x27" status "\x27 without Approval: Approved")
  # Implementation report required for Implementation Complete AND Done (word-boundary match)
  if (status == "Implementation Complete" || status == "Done") {
    cmd = "grep -rlw \x27" task "\x27 \"" ENVIRON["IMPL_REPORTS"] "\" 2>/dev/null | head -1"
    cmd | getline impl_report; close(cmd)
    if (impl_report == "") fail(task " is \x27" status "\x27 but no implementation report in " ENVIRON["IMPL_REPORTS"] " mentions it")
  }
  # Lite Done: require a quality-gate report mentioning the task with VERDICT: PASS
  if (status == "Done") {
    qa_found = ""
    cmd = "grep -rlw \x27" task "\x27 \"" ENVIRON["REPORTS"] "\" 2>/dev/null"
    while ((cmd | getline f) > 0) {
      vc = "grep -Eq \x27^VERDICT:[ \t]*PASS[ \t]*$\x27 \"" f "\" && echo yes || echo no"
      vc | getline ok; close(vc)
      if (ok == "yes") { qa_found = f; break }
    }
    close(cmd)
    if (qa_found == "") fail(task " is Done but no quality-gate report in " ENVIRON["REPORTS"] " mentions it with VERDICT: PASS")
  }
  if (status == "Blocked") {
    if (blockers_content == "") fail(task " is Blocked but ### Blockers section has no content (not None or empty)")
  }
}
END {
  if (task != "") finish()
  if (count == 0) { print "check-task-state-lite: no tasks found"; exit 1 }
  if (failures > 0) { exit 1 }
  print "Task state (lite) check passed for " count " task(s)."
}
' "$tasks" > "$_tmpout" 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "Task state (lite) check FAILED:"
fi
cat "$_tmpout"
exit $rc
