#!/usr/bin/env python3
"""Unified cross-runtime PreToolUse guard for the SDD quality loop.

Runs the same three checks for Claude Code, Codex CLI, and GitHub Copilot CLI:

  1. Kill switch: if an ``AGENT_STOP`` file exists at ``$CLAUDE_PROJECT_DIR``
     (fallback: cwd), deny every tool call until a human deletes it.
  2. Approval guard: deny any tool call that would INCREASE the number of
     ``Approval: Approved`` occurrences in a file whose path ends with
     ``tasks.md``. Only a human may approve a task.
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
  - Codex Bash/shell (tool_name Bash/shell/exec_command/exec): a conservative
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
AGENT_ROLE_PATH_RE = re.compile(r"\.codex/agents/[^/]+\.toml$")
DEVELOPER_INSTRUCTIONS_RE = re.compile(r"(^|\n)[ \t]*developer_instructions[ \t]*=")

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
    """Return True if this would write an invalid agent role file."""
    tool_input = payload.get("tool_input") or {}
    tool_name = (payload.get("tool_name") or "").lower()

    # --- Codex apply_patch: check Add File sections for agent role paths ---
    if tool_name == "apply_patch" or _looks_like_patch(tool_input.get("command")):
        patch = tool_input.get("command") or ""
        current_is_agent_role = False
        body_lines = []
        for raw in patch.splitlines():
            m = re.match(r"\*\*\* (Update|Add|Delete) File: (.+)$", raw)
            if m:
                # Flush previous section if it was Add File for agent role.
                # An empty body is also malformed: no developer_instructions.
                if current_is_agent_role and not has_developer_instructions(
                    "\n".join(body_lines)
                ):
                    return True
                body_lines = []
                op = m.group(1)
                path = m.group(2).strip()
                current_is_agent_role = op == "Add" and is_agent_role_path(path)
                continue
            if raw.startswith("*** End Patch") or raw.startswith("*** Begin Patch"):
                continue
            if current_is_agent_role and raw.startswith("+") and not raw.startswith("+++"):
                body_lines.append(raw[1:])
        # Flush final section.
        if current_is_agent_role and not has_developer_instructions(
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


def _shell_writes_invalid_agent_role(cmd):
    """Conservative heuristic: deny if shell writes invalid agent role file."""
    if not isinstance(cmd, str):
        return False
    # Check if command contains developer_instructions.
    if "developer_instructions" in cmd:
        return False
    # Check if command redirects into an agent role path.
    normalized_cmd = cmd.replace("\\", "/")
    # Match: >> or > or tee followed by path matching .codex/agents/*.toml
    redirect_re = re.compile(
        r'(>>?|tee(?:\s+-a)?)\s*["\']?[^"\'\s]*\.codex/agents/[^"\'\ \s]*\.toml',
        re.IGNORECASE
    )
    return bool(redirect_re.search(normalized_cmd))


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
            if _shell_writes_invalid_agent_role(tool_input["command"]):
                emit("deny", AGENT_ROLE_MSG, mode)
    except Exception:
        # Never crash; fail open on the agent-role check.
        emit("allow", None, mode)
        return

    emit("allow", None, mode)


if __name__ == "__main__":
    main()
