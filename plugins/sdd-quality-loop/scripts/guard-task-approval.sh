#!/bin/sh
# PreToolUse hook (Claude Code): dispatcher for guard-task-approval.
# Blocks edits that add "Approval: Approved" to a tasks.md file.
# Prefers python3, then PowerShell. If neither exists, allows with a warning
# (the prompt-level rule still applies; this guard is defense in depth).
dir="$(dirname "$0")"
payload="$(cat)"

case "$payload" in
  *tasks.md*) ;;
  *) exit 0 ;;
esac

if command -v python3 >/dev/null 2>&1; then
  PAYLOAD="$payload" python3 <<'PYEOF'
import json, os, re, sys

def count(text):
    return len(re.findall(r"Approval:\s*Approved", text or ""))

try:
    payload = json.loads(os.environ["PAYLOAD"])
except Exception:
    sys.exit(0)

tool_input = payload.get("tool_input") or {}
file_path = tool_input.get("file_path") or ""
if not file_path.endswith("tasks.md"):
    sys.exit(0)

old = new = 0
if "edits" in tool_input:
    for edit in tool_input["edits"]:
        old += count(edit.get("old_string"))
        new += count(edit.get("new_string"))
elif "new_string" in tool_input:
    old = count(tool_input.get("old_string"))
    new = count(tool_input.get("new_string"))
elif "content" in tool_input:
    try:
        with open(file_path, encoding="utf-8") as f:
            old = count(f.read())
    except OSError:
        old = 0
    new = count(tool_input.get("content"))
else:
    sys.exit(0)

if new > old:
    sys.stderr.write(
        "SDD deterministic gate: agents must not set 'Approval: Approved' in "
        "tasks.md. Only a human may approve a task by editing the file "
        "directly. Leave the task as Draft and ask the human to approve it.\n")
    sys.exit(2)
sys.exit(0)
PYEOF
  exit $?
fi

for ps in pwsh powershell.exe powershell; do
  if command -v "$ps" >/dev/null 2>&1; then
    printf '%s' "$payload" | "$ps" -NoProfile -ExecutionPolicy Bypass -File "$dir/guard-task-approval.ps1"
    exit $?
  fi
done

echo "guard-task-approval: python3 and PowerShell unavailable; approval guard skipped. Do not set 'Approval: Approved' yourself." >&2
exit 0
