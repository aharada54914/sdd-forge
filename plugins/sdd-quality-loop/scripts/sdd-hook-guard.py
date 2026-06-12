#!/usr/bin/env python3
"""Unified cross-runtime PreToolUse guard for the SDD quality loop.

Runs the same three checks for Claude Code, Codex CLI, and GitHub Copilot CLI:

  1. Kill switch: if an ``AGENT_STOP`` file exists at ``$CLAUDE_PROJECT_DIR``
     (fallback: cwd), deny every tool call until a human deletes it.
  2. Approval guard: deny any tool call that would INCREASE the number of
     ``Approval: Approved`` occurrences in a file whose path ends with
     ``tasks.md``. Only a human may approve a task. Bypassed while a human-enabled
     SDD_SUDO flag file with an unexpired 'expires-epoch: <unix-seconds>' line
     exists at the project root (sudo mode). Checks 1 and 3 are never bypassed.
  3. Agent-role guard: deny any tool call that would write a Codex agent role
     file (path matching ``.codex/agents/[^/]+.toml``) without a
     ``developer_instructions`` field. Such files are ignored by Codex at startup.

Payload formats handled:
  - Claude / Copilot Edit/Write: ``tool_input.file_path`` plus
    ``old_string``/``new_string``, ``edits[]``, or ``content`` (the latter is
    compared against the file currently on disk).
  - Codex ``apply_patch``: ``tool_input.command`` holds the raw patch envelope.
    For each ``*** Update File:``/``*** Add File:`` section targeting a
    tasks.md, count ``Approval: Approved`` on ``+`` lines vs ``-`` lines and
    deny if the net is positive.
  - Codex Bash/shell (tool_name Bash/shell/exec_command/exec): deny shell
    commands that write to a Codex agent role path; read-only commands are
    allowed. Shell approval edits still follow the approval guard.

Output modes:
  --emit exit     (default) allow = exit 0; deny = reason on stderr, exit 2.
  --emit copilot  always print {"permissionDecision": ...} to stdout, exit 0.

Malformed/unknown payloads are denied. The guard never crashes.
"""
import json
import os
import re
import sys
import time

APPROVAL_RE = re.compile(r"Approval:\s*Approved")
AGENT_ROLE_PATH_RE = re.compile(r"\.codex/agents/[^/]+\.toml$")
TASK_SECTION_RE = re.compile(r"^##\s+(T-\S+)", re.MULTILINE)
DEVELOPER_INSTRUCTIONS_RE = re.compile(r"(^|\n)[ \t]*developer_instructions[ \t]*=")
SUDO_EPOCH_RE = re.compile(r"(^|\n)[ \t]*expires-epoch:[ \t]*(\d+)")
SHELL_AGENT_ROLE_READ_ONLY_RE = re.compile(
    r"(?is)^\s*(?:cat|ls|stat|head|tail|grep|rg)\b[^;&|><]*\.codex/agents(?:/|\b)"
)
TARGETED_COMMAND_TOOLS = {"apply_patch", "bash", "shell", "exec_command", "exec"}
TARGETED_FILE_TOOLS = {"edit", "write", "multiedit"}

APPROVAL_MSG = (
    "SDD deterministic gate: agents must not set 'Approval: Approved' in "
    "tasks.md. Only a human may approve a task by editing the file directly. "
    "Leave the task as Draft and ask the human to approve it."
)
KILL_MSG = (
    "SDD kill switch: AGENT_STOP exists at the project root. All tool use is "
    "suspended until a human deletes the file."
)
AGENT_ROLE_MSG = (
    "SDD deterministic gate: refusing to write a Codex agent role file without "
    "developer_instructions. Files under .codex/agents/ must define "
    "developer_instructions or Codex ignores them at startup "
    "('Ignoring malformed agent role definition'). Use the shipped "
    "sdd-investigator/sdd-evaluator roles instead of creating new ones."
)


def count(text):
    if not text:
        return 0
    return len(APPROVAL_RE.findall(text))


def is_tasks_md(path):
    # Case-insensitive match (intentional: matches JS/PS1 behavior; Windows FS is case-insensitive).
    return bool(path) and str(path).replace("\\", "/").lower().endswith("tasks.md")


def is_agent_role_path(path):
    """Check if path is an agent role file: .codex/agents/<name>.toml"""
    if not path:
        return False
    normalized = str(path).replace("\\", "/").lower()
    return bool(AGENT_ROLE_PATH_RE.search(normalized))


def has_developer_instructions(content):
    """Check if content has developer_instructions field."""
    if not isinstance(content, str) or not content:
        return False
    return bool(DEVELOPER_INSTRUCTIONS_RE.search(content))


def emit(decision, reason, mode):
    """decision: 'allow' or 'deny'."""
    if mode == "copilot":
        out = {"permissionDecision": decision}
        if decision == "deny" and reason:
            out["permissionDecisionReason"] = reason
        sys.stdout.write(json.dumps(out, separators=(",", ":")))
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


def sudo_active():
    """True if a valid, unexpired SDD_SUDO flag exists at the project root."""
    root = os.environ.get("CLAUDE_PROJECT_DIR") or "."
    for base in (root, "."):
        try:
            flag = os.path.join(base, "SDD_SUDO")
            if not os.path.isfile(flag):
                continue
            with open(flag, encoding="utf-8") as f:
                m = SUDO_EPOCH_RE.search(f.read())
            if m and int(m.group(2)) > time.time():
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

    # --- Codex Bash/shell: approval writes still denied ---
    if tool_name in ("bash", "shell", "exec_command", "exec") and isinstance(
        tool_input.get("command"), str
    ):
        cmd = tool_input["command"]
        if "tasks.md" in cmd.lower() and APPROVAL_RE.search(cmd):
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


def agent_role_invalid(payload):
    """Return True if this would write an invalid or protected agent role file."""
    tool_input = payload.get("tool_input") or {}
    tool_name = (payload.get("tool_name") or "").lower()

    # --- Codex apply_patch: deny Update/Delete, validate Add File bodies ---
    if tool_name == "apply_patch" or _looks_like_patch(tool_input.get("command")):
        patch = tool_input.get("command") or ""
        current_is_agent_role = False
        current_op = None
        body_lines = []
        for raw in patch.splitlines():
            m = re.match(r"\*\*\* (Update|Add|Delete) File: (.+)$", raw)
            if m:
                # Flush previous Add File section if it targeted an agent role.
                if current_op == "Add" and current_is_agent_role and not has_developer_instructions(
                    "\n".join(body_lines)
                ):
                    return True
                body_lines = []
                current_op = m.group(1)
                path = m.group(2).strip()
                current_is_agent_role = is_agent_role_path(path)
                if current_is_agent_role and current_op in ("Update", "Delete"):
                    return True
                continue
            if raw.startswith("*** End Patch") or raw.startswith("*** Begin Patch"):
                continue
            if current_op == "Add" and current_is_agent_role and raw.startswith("+") and not raw.startswith("+++"):
                body_lines.append(raw[1:])
        # Flush final section.
        if current_op == "Add" and current_is_agent_role and not has_developer_instructions(
            "\n".join(body_lines)
        ):
            return True
        return False

    # --- Write-style tools: full-file writes with file_path ---
    file_path = tool_input.get("file_path") or ""
    if is_agent_role_path(file_path) and "content" in tool_input:
        content = tool_input.get("content")
        if not has_developer_instructions(content):
            return True
    return False


def _shell_writes_agent_role(cmd):
    """Deny agent-role shell access unless it is an unambiguously read-only command."""
    if not isinstance(cmd, str):
        return False
    normalized_cmd = cmd.replace("\\", "/")
    if not re.search(r"(?i)\.codex/agents(?:/|\b)", normalized_cmd):
        return False
    return not bool(SHELL_AGENT_ROLE_READ_ONLY_RE.search(normalized_cmd))


def payload_is_malformed(payload):
    tool_name = (payload.get("tool_name") or "").lower()
    tool_input = payload.get("tool_input") or {}
    if tool_name in TARGETED_COMMAND_TOOLS and (
        not isinstance(tool_input.get("command"), str) or not tool_input.get("command").strip()
    ):
        return True
    if tool_name in TARGETED_FILE_TOOLS:
        if not isinstance(tool_input.get("file_path"), str) or not tool_input.get("file_path").strip():
            return True
        if not any(key in tool_input for key in ("edits", "new_string", "content")):
            return True
    return False


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

    # Check 1: kill switch runs regardless of payload validity (checked before stdin read, matching JS/PS1).
    if kill_switch_tripped():
        emit("deny", KILL_MSG, mode)

    raw = os.environ.get("PAYLOAD")
    if raw is None:
        try:
            # TTY guard: if stdin is a terminal, treat as empty (mirrors JS isTTY; avoids hang).
            if sys.stdin.isatty():
                raw = ""
            else:
                raw = sys.stdin.read()
        except Exception:
            raw = ""

    try:
        payload = json.loads(raw) if raw else {}
        if not isinstance(payload, dict):
            raise ValueError("payload must be a JSON object")
    except Exception:
        emit("deny", "SDD deterministic gate: malformed hook payload.", mode)
        return

    try:
        tool_input = payload.get("tool_input")
        tool_name = payload.get("tool_name")
        if not isinstance(tool_name, str) or not isinstance(tool_input, dict):
            emit("deny", "SDD deterministic gate: malformed hook payload.", mode)
            return
        if payload_is_malformed(payload):
            emit("deny", "SDD deterministic gate: malformed hook payload.", mode)
            return
        if approval_increases(payload) and not sudo_active():
            emit("deny", APPROVAL_MSG, mode)
    except Exception:
        # Never crash; fail closed on the approval check.
        emit("deny", "SDD deterministic gate: approval guard failed closed.", mode)
        return

    # Check 3: agent-role guard.
    try:
        tool_input = payload.get("tool_input") or {}
        tool_name = (payload.get("tool_name") or "").lower()
        # Write-style tools and apply_patch.
        if agent_role_invalid(payload):
            emit("deny", AGENT_ROLE_MSG, mode)
        # Bash/shell tools.
        if tool_name in ("bash", "shell", "exec_command", "exec") and isinstance(
            tool_input.get("command"), str
        ):
            if _shell_writes_agent_role(tool_input["command"]):
                emit("deny", AGENT_ROLE_MSG, mode)
    except Exception:
        # Never crash; fail closed on the agent-role check.
        emit("deny", "SDD deterministic gate: agent-role guard failed closed.", mode)
        return

    emit("allow", None, mode)


if __name__ == "__main__":
    main()
