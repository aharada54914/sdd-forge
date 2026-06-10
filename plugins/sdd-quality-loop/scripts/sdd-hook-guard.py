#!/usr/bin/env python3
"""Unified cross-runtime PreToolUse guard for the SDD quality loop.

Runs the same two checks for Claude Code, Codex CLI, and GitHub Copilot CLI:

  1. Kill switch: if an ``AGENT_STOP`` file exists at ``$CLAUDE_PROJECT_DIR``
     (fallback: cwd), deny every tool call until a human deletes it.
  2. Approval guard: deny any tool call that would INCREASE the number of
     ``Approval: Approved`` occurrences in a file whose path ends with
     ``tasks.md``. Only a human may approve a task.

Payload formats handled:
  - Claude / Copilot Edit/Write: ``tool_input.file_path`` plus
    ``old_string``/``new_string``, ``edits[]``, or ``content`` (the latter is
    compared against the file currently on disk).
  - Codex ``apply_patch``: ``tool_input.command`` holds the raw patch envelope.
    For each ``*** Update File:``/``*** Add File:`` section targeting a
    tasks.md, count ``Approval: Approved`` on ``+`` lines vs ``-`` lines and
    deny if the net is positive.
  - Codex Bash/shell (tool_name Bash/shell/exec_command): a conservative
    heuristic - if the shell command string mentions ``tasks.md`` AND contains
    ``Approval: Approved`` (e.g. ``sed``/``echo >>``), deny. This intentionally
    over-blocks shell tricks that would smuggle an approval in.

Output modes:
  --emit exit     (default) allow = exit 0; deny = reason on stderr, exit 2.
  --emit copilot  always print {"permissionDecision": ...} to stdout, exit 0.

Malformed/unknown payloads are ALWAYS allowed. The guard never crashes.
"""
import json
import os
import re
import sys

APPROVAL_RE = re.compile(r"Approval:\s*Approved")

APPROVAL_MSG = (
    "SDD deterministic gate: agents must not set 'Approval: Approved' in "
    "tasks.md. Only a human may approve a task by editing the file directly. "
    "Leave the task as Draft and ask the human to approve it."
)
KILL_MSG = (
    "SDD kill switch: AGENT_STOP exists at the project root. All tool use is "
    "suspended until a human deletes the file."
)


def count(text):
    if not text:
        return 0
    return len(APPROVAL_RE.findall(text))


def is_tasks_md(path):
    return bool(path) and str(path).replace("\\", "/").endswith("tasks.md")


def emit(decision, reason, mode):
    """decision: 'allow' or 'deny'."""
    if mode == "copilot":
        out = {"permissionDecision": decision}
        if decision == "deny" and reason:
            out["permissionDecisionReason"] = reason
        sys.stdout.write(json.dumps(out))
        sys.exit(0)
    # exit mode
    if decision == "deny":
        if reason:
            sys.stderr.write(reason + "\n")
        sys.exit(2)
    sys.exit(0)


def kill_switch_tripped():
    root = os.environ.get("CLAUDE_PROJECT_DIR") or "."
    for base in (root, "."):
        try:
            if os.path.isfile(os.path.join(base, "AGENT_STOP")):
                return True
        except OSError:
            pass
    return False


def approval_increases(payload):
    """Return True if this tool call would add net new approvals to a tasks.md."""
    tool_input = payload.get("tool_input") or {}
    tool_name = (payload.get("tool_name") or "").lower()

    # --- Codex apply_patch: raw patch envelope in tool_input.command ---
    if tool_name == "apply_patch" or _looks_like_patch(tool_input.get("command")):
        return _patch_increases(tool_input.get("command") or "")

    # --- Codex Bash/shell: conservative heuristic ---
    if tool_name in ("bash", "shell", "exec_command", "exec") and isinstance(
        tool_input.get("command"), str
    ):
        cmd = tool_input["command"]
        if "tasks.md" in cmd and APPROVAL_RE.search(cmd):
            return True
        return False

    # --- Claude / Copilot Edit / Write ---
    file_path = tool_input.get("file_path") or ""
    if not is_tasks_md(file_path):
        return False

    old = new = 0
    if isinstance(tool_input.get("edits"), list):
        for edit in tool_input["edits"]:
            old += count((edit or {}).get("old_string"))
            new += count((edit or {}).get("new_string"))
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
        return False

    return new > old


def _looks_like_patch(command):
    return isinstance(command, str) and "*** Begin Patch" in command


def _patch_increases(patch):
    """Parse a Codex patch envelope; return True if net approvals added to a tasks.md."""
    current_is_tasks = False
    added = removed = 0
    net_for_file = 0
    for raw in patch.splitlines():
        # File section headers.
        m = re.match(r"\*\*\* (Update|Add|Delete) File: (.+)$", raw)
        if m:
            current_is_tasks = is_tasks_md(m.group(2).strip())
            continue
        if raw.startswith("*** End Patch") or raw.startswith("*** Begin Patch"):
            continue
        if not current_is_tasks:
            continue
        # Patch body lines.
        if raw.startswith("+") and not raw.startswith("+++"):
            added += count(raw[1:])
        elif raw.startswith("-") and not raw.startswith("---"):
            removed += count(raw[1:])
    net_for_file = added - removed
    return net_for_file > 0


def parse_args(argv):
    mode = "exit"
    i = 0
    while i < len(argv):
        if argv[i] == "--emit" and i + 1 < len(argv):
            mode = argv[i + 1]
            i += 2
        elif argv[i].startswith("--emit="):
            mode = argv[i].split("=", 1)[1]
            i += 1
        else:
            i += 1
    return mode if mode in ("exit", "copilot") else "exit"


def main():
    mode = parse_args(sys.argv[1:])

    raw = os.environ.get("PAYLOAD")
    if raw is None:
        try:
            raw = sys.stdin.read()
        except Exception:
            raw = ""

    # Check 1: kill switch runs regardless of payload validity.
    if kill_switch_tripped():
        emit("deny", KILL_MSG, mode)

    try:
        payload = json.loads(raw) if raw else {}
        if not isinstance(payload, dict):
            payload = {}
    except Exception:
        emit("allow", None, mode)
        return

    try:
        if approval_increases(payload):
            emit("deny", APPROVAL_MSG, mode)
    except Exception:
        # Never crash; fail open on the approval check.
        emit("allow", None, mode)
        return

    emit("allow", None, mode)


if __name__ == "__main__":
    main()
