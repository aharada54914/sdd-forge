#!/bin/sh
# Deterministic gate: validate the tasks.md state machine on disk.
# Usage: check-task-state.sh <path-to-tasks.md> [reports-dir] [impl-reports-dir] [repo-root]
# Reports dirs default to reports/quality-gate and reports/implementation.
# Rules enforced:
#  - Approval is Draft or Approved; Status is a known lifecycle value.
#  - In Progress / Implementation Complete / Done require Approval: Approved.
#  - Done additionally requires a verification/<task-id>.evidence.json file
#    in the tasks.md directory, and that bundle must validate the report,
#    contract, and passing evidence artifacts.
#  - Implementation Complete requires an implementation report mentioning the task id.
#  - Blocked requires non-empty ### Blockers content (not None/whitespace/bare list markers).
#  - Duplicate task ids (## T-NNN repeated) → fail.
tasks="$1"
reports="${2:-reports/quality-gate}"
impl_reports="${3:-reports/implementation}"
repo_root="${4:-.}"
script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

if [ -z "$tasks" ] || [ ! -f "$tasks" ]; then
  echo "check-task-state: tasks file not found: $tasks" >&2
  exit 1
fi

_tmpout="$(mktemp)"
trap 'rm -f "$_tmpout"' EXIT

TASKS="$tasks" REPORTS="$reports" IMPL_REPORTS="$impl_reports" SCRIPT_DIR="$script_dir" REPO_ROOT="$repo_root" awk '
BEGIN {
  task = ""; failures = 0; count = 0
  in_blockers = 0; blockers_content = ""
}
function fail(msg) { print " - " msg; failures++ }
function approver_id(s,   rest) {
  if (s ~ /^Approved \([^ )]+ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\)$/) {
    rest = s
    sub(/^Approved \(/, "", rest)
    sub(/ .*$/, "", rest)
    return rest
  }
  return ""
}
/^## T-[0-9]+/ {
  if (task != "") finish()
  newid = $2
  if (seen[newid]) {
    fail("duplicate task id " newid)
  }
  seen[newid] = 1
  task = newid; approval = ""; status = ""; risk = ""; second = ""; count++
  in_blockers = 0; blockers_content = ""
}
/^Approval:/ { if (task != "") { approval = $0; sub(/^Approval:[ \t]*/, "", approval); in_blockers = 0 } }
/^Status:/ { if (task != "") { status = $0; sub(/^Status:[ \t]*/, "", status); in_blockers = 0 } }
/^Risk:/ { if (task != "") { risk = $0; sub(/^Risk:[ \t]*/, "", risk); risk = tolower(risk); sub(/[ \t]+$/, "", risk); in_blockers = 0 } }
/^Second Approval:/ { if (task != "") { second = $0; sub(/^Second Approval:[ \t]*/, "", second); in_blockers = 0 } }
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
  else {
    # Accept: Draft | Approved | Approved (<id> YYYY-MM-DDTHH:MM:SSZ) where <id> can be any non-space/non-paren token
    is_valid_approval = (approval == "Draft" || approval == "Approved" || \
      approval ~ /^Approved \([^ )]+ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\)$/)
    if (!is_valid_approval) fail(task " has invalid Approval: " approval)
  }
  # For gate checks, treat Approved (with any id) same as Approved
  is_approved = (approval == "Approved" || approval ~ /^Approved \([^ )]+ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\)$/)
  if (status == "") fail(task " has no Status line")
  else if (status != "Planned" && status != "In Progress" && status != "Blocked" && status != "Implementation Complete" && status != "Done")
    fail(task " has invalid Status: " status)
  if ((status == "In Progress" || status == "Implementation Complete" || status == "Done") && !is_approved)
    fail(task " is \x27" status "\x27 without Approval: Approved")
  if (status == "Done") {
    tasks_dir = ENVIRON["TASKS"]
    # NOTE: escape "/" instead of bracketing it ([/]) — BSD awk (macOS) rejects
    # an unescaped "/" inside a bracket expression as an unterminated regex.
    sub(/\/[^\/]*$/, "", tasks_dir)
    if (tasks_dir == ENVIRON["TASKS"]) tasks_dir = "."
    bundle_path = tasks_dir "/verification/" task ".evidence.json"
    # C-07: contract must be non-empty regular file with valid JSON and task_id match
    contract_path = tasks_dir "/verification/" task ".contract.json"

    # Check bundle existence and validity
    cmd = "test -f \"" bundle_path "\" && echo yes || echo no"
    cmd | getline exists; close(cmd)
    if (exists != "yes") fail(task " is Done but verification/" task ".evidence.json does not exist in " tasks_dir)
    else {
      cmd2 = "sh \"" ENVIRON["SCRIPT_DIR"] "/check-evidence-bundle.sh\" \"" bundle_path "\" \"" ENVIRON["REPO_ROOT"] "\""
      status_code = system(cmd2)
      if (status_code != 0) fail(task " evidence bundle failed validation: " bundle_path)
    }

    # Check contract existence and validity
    cmd = "test -f \"" contract_path "\" && echo yes || echo no"
    cmd | getline contract_exists; close(cmd)
    if (contract_exists != "yes") fail(task " is Done but verification/" task ".contract.json does not exist in " tasks_dir)
    else {
      # Validate contract is non-empty regular file
      cmd = "test -s \"" contract_path "\" && echo yes || echo no"
      cmd | getline contract_nonempty; close(cmd)
      if (contract_nonempty != "yes") fail(task " is Done but verification/" task ".contract.json is empty in " tasks_dir)
      else {
        # Validate contract has matching task_id using python3 if available, else grep
        if (system("command -v python3 >/dev/null 2>&1") == 0) {
          cmd3 = "python3 -c \"import json,sys; c=json.load(open(\\\"" contract_path "\\\")); sys.exit(0 if c.get(\\\"task_id\\\") == \\\"" task "\\\" else 1)\" 2>/dev/null"
          if (system(cmd3) != 0) fail(task " is Done but verification/" task ".contract.json has mismatched task_id")
        } else {
          # Fallback to grep for task_id match without python3
          grep_cmd = "grep -F \"\\\"task_id\\\"\" \"" contract_path "\" | grep -F \"\\\"" task "\\\"\" >/dev/null 2>&1"
          if (system(grep_cmd) != 0) fail(task " is Done but verification/" task ".contract.json has mismatched task_id (or invalid JSON)")
        }
      }
    }
  }
  if (status == "Implementation Complete") {
    # C-07: word-boundary match to prevent T-001 matching T-0010
    cmd = "grep -rlw \x27" task "\x27 \"" ENVIRON["IMPL_REPORTS"] "\" 2>/dev/null | head -1"
    cmd | getline impl_report; close(cmd)
    if (impl_report == "") fail(task " is Implementation Complete but no implementation report in " ENVIRON["IMPL_REPORTS"] " mentions it")
    impl_report = ""
  }
  if (status == "Blocked") {
    if (blockers_content == "") fail(task " is Blocked but ### Blockers section has no content (not None or empty)")
  }
  # Two-person approval enforcement for critical Done tasks
  if (status == "Done" && risk == "critical") {
    prim_id = approver_id(approval)
    sec_id = approver_id(second)

    if (prim_id == "") {
      fail(task " is critical Done but primary Approval lacks a named approver (need \x27Approved (<id> <ISO>)\x27)")
    }
    if (tolower(prim_id) == "sudo") {
      fail(task " is critical Done but primary approver is \x27sudo\x27; critical requires a named human approver")
    }
    if (second == "" || sec_id == "") {
      fail(task " is critical Done but Second Approval is missing or not a named \x27Approved (<id> <ISO>)\x27")
    }
    if (tolower(sec_id) == "sudo") {
      fail(task " is critical Done but Second Approval approver is \x27sudo\x27; critical requires a named human second approver")
    }
    if (tolower(prim_id) == tolower(sec_id) && prim_id != "") {
      fail(task " is critical Done but both approvals are by the same approver \x27" prim_id "\x27; two distinct approvers required")
    }
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
