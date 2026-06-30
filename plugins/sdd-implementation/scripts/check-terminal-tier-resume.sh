#!/usr/bin/env bash
set -euo pipefail

evidence=""
tasks=""
repo_root=""
expected_task=""
blocked_state=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --evidence) evidence="${2:-}"; shift 2 ;;
    --tasks) tasks="${2:-}"; shift 2 ;;
    --repo-root) repo_root="${2:-}"; shift 2 ;;
    --expected-task) expected_task="${2:-}"; shift 2 ;;
    --blocked-state) blocked_state="${2:-}"; shift 2 ;;
    *)
      printf 'TERMINAL_RESUME_ERROR: unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$evidence" || -z "$tasks" || -z "$repo_root" ||
  -z "$expected_task" || -z "$blocked_state" ]]; then
  printf 'TERMINAL_RESUME_ERROR: evidence, blocked-state, tasks, repo-root, and expected-task are required\n' >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf 'BLOCKED deterministic-runtime-unavailable\n'
  exit 1
fi

python3 - "$evidence" "$blocked_state" "$tasks" "$repo_root" "$expected_task" <<'PY'
import hashlib
import json
import os
import re
import sys

evidence_path, blocked_state_path, tasks_path, repo_root, expected_task = sys.argv[1:]
SHA = re.compile(r"^[a-f0-9]{64}$")
TASK = re.compile(r"^T-\d{3}$")
TIME = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")

def fail(code, message):
    print(f"TERMINAL_RESUME_{code}: {message}", file=sys.stderr)
    sys.exit(1)

def digest(path):
    value = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()

def text_digest(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()

def safe_repo_file(relative_path):
    if not isinstance(relative_path, str) or not relative_path:
        fail("PATH", "diagnosis path is missing")
    if relative_path.startswith(("/", "\\")) or "\\" in relative_path:
        fail("PATH", "diagnosis path must be repository-relative")
    parts = relative_path.split("/")
    if any(part in ("", ".", "..") for part in parts):
        fail("PATH", "diagnosis path is not canonical")
    root = os.path.realpath(repo_root)
    target = os.path.join(root, *parts)
    if os.path.islink(target) or not os.path.isfile(target):
        fail("PATH", "diagnosis reference is missing or unsafe")
    if os.path.commonpath((root, os.path.realpath(target))) != root:
        fail("PATH", "diagnosis reference escapes repository")
    return target

try:
    with open(evidence_path, encoding="utf-8") as handle:
        data = json.load(handle)
except Exception as exc:
    fail("JSON", str(exc))

required = {
    "schema", "task_id", "blocked_task_contract_sha256",
    "revised_task_contract_sha256", "diagnosis_reference",
    "human_reapproval", "blocked_state_reference",
}
if not isinstance(data, dict) or set(data) != required:
    fail("JSON", "evidence fields do not match terminal-tier-resume/v1")
if data["schema"] != "terminal-tier-resume/v1":
    fail("JSON", "unsupported schema")
if not isinstance(data["task_id"], str) or not TASK.match(data["task_id"]):
    fail("TASK", "invalid task_id")
if data["task_id"] != expected_task:
    fail("TASK", "task_id does not match expected task")
for field in ("blocked_task_contract_sha256", "revised_task_contract_sha256"):
    if not isinstance(data[field], str) or not SHA.match(data[field]):
        fail("HASH", f"invalid {field}")
blocked_reference = data["blocked_state_reference"]
if (not isinstance(blocked_reference, dict)
        or set(blocked_reference) != {"path", "sha256"}):
    fail("JSON", "invalid blocked_state_reference")
if (not isinstance(blocked_reference["sha256"], str)
        or not SHA.match(blocked_reference["sha256"])):
    fail("HASH", "invalid blocked state reference hash")
trusted_blocked_path = safe_repo_file(blocked_reference["path"])
if os.path.realpath(trusted_blocked_path) != os.path.realpath(blocked_state_path):
    fail("PATH", "blocked state does not match trusted persisted input")
if digest(trusted_blocked_path) != blocked_reference["sha256"]:
    fail("HASH", "blocked state reference hash mismatch")
try:
    with open(trusted_blocked_path, encoding="utf-8") as handle:
        blocked = json.load(handle)
except Exception as exc:
    fail("JSON", f"invalid blocked state: {exc}")
blocked_fields = {
    "schema", "task_id", "blocked_task_contract_sha256", "tier",
    "failure_class", "attempt_number", "reason", "blocked_at",
}
if not isinstance(blocked, dict) or set(blocked) != blocked_fields:
    fail("JSON", "blocked state fields do not match terminal-tier-blocked-state/v1")
if blocked["schema"] != "terminal-tier-blocked-state/v1":
    fail("JSON", "unsupported blocked state schema")
if blocked["task_id"] != expected_task:
    fail("TASK", "blocked state task_id does not match expected task")
if blocked["blocked_task_contract_sha256"] != data["blocked_task_contract_sha256"]:
    fail("HASH", "blocked task contract hash does not match persisted blocked state")
if blocked["tier"] != "strong" or blocked["reason"] != "terminal-tier-recurrence":
    fail("CONTRACT", "blocked state is not a terminal-tier recurrence")
if blocked["failure_class"] not in {
    "test", "lint", "typecheck", "build", "review-major", "review-critical"
}:
    fail("CONTRACT", "invalid blocked state failure class")
if (not isinstance(blocked["attempt_number"], int)
        or isinstance(blocked["attempt_number"], bool)
        or blocked["attempt_number"] < 2):
    fail("CONTRACT", "invalid blocked state attempt number")
if not isinstance(blocked["blocked_at"], str) or not TIME.match(blocked["blocked_at"]):
    fail("CONTRACT", "invalid blocked state timestamp")
if data["blocked_task_contract_sha256"] == data["revised_task_contract_sha256"]:
    fail("CONTRACT", "task contract was not revised after terminal blocking")
diagnosis = data["diagnosis_reference"]
if not isinstance(diagnosis, dict) or set(diagnosis) != {"path", "sha256"}:
    fail("JSON", "invalid diagnosis_reference")
if not isinstance(diagnosis["sha256"], str) or not SHA.match(diagnosis["sha256"]):
    fail("HASH", "invalid diagnosis reference hash")
diagnosis_path = safe_repo_file(diagnosis["path"])
if digest(diagnosis_path) != diagnosis["sha256"]:
    fail("HASH", "diagnosis reference hash mismatch")

approval = data["human_reapproval"]
if not isinstance(approval, dict) or set(approval) != {"authority", "timestamp"}:
    fail("JSON", "invalid human_reapproval")
if not isinstance(approval["authority"], str) or not re.match(
    r"^[A-Za-z0-9][A-Za-z0-9._:@ -]{1,127}$", approval["authority"]
):
    fail("APPROVAL", "invalid human reapproval authority")
if not isinstance(approval["timestamp"], str) or not TIME.match(approval["timestamp"]):
    fail("APPROVAL", "invalid human reapproval timestamp")

with open(tasks_path, encoding="utf-8", newline="") as handle:
    tasks_text = handle.read()
section_match = re.search(
    rf"(?ms)^## {re.escape(expected_task)}\b.*?(?=^## T-\d{{3}}\b|\Z)",
    tasks_text,
)
if not section_match:
    fail("TASK", "task section is missing")
section = section_match.group(0)
if text_digest(section.rstrip("\r\n")) != data["revised_task_contract_sha256"]:
    fail("HASH", "revised task contract hash does not match the task section")
if not re.search(r"(?m)^Approval: Approved(?:\b| \()", section):
    fail("APPROVAL", "task is not explicitly reapproved")
if not re.search(r"(?m)^Status: (?:Planned|In Progress)$", section):
    fail("APPROVAL", "reapproved task is not eligible to resume")
if f"Diagnosis Reference: {diagnosis['path']}" not in section:
    fail("DIAGNOSIS", "tasks.md does not record the diagnosis reference")
expected_reapproval = (
    f"Terminal Reapproval: {approval['authority']} @ {approval['timestamp']}"
)
if expected_reapproval not in section:
    fail("APPROVAL", "tasks.md does not record matching terminal reapproval")

print("TERMINAL_RESUME_OK")
PY
