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
import hashlib
import hmac
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
SUDO_ISSUED_RE = re.compile(r"(^|\n)[ \t]*issued-epoch:[ \t]*(\d+)")
SHELL_AGENT_ROLE_READ_ONLY_RE = re.compile(
    r"(?is)^\s*(?:cat|ls|stat|head|tail|grep|rg)\b[^;&|><]*\.codex/agents(?:/|\b)"
)
# C-02: shell write patterns that indicate SDD_SUDO manipulation
SHELL_SUDO_WRITE_RE = re.compile(
    r"(?i)(?:>|>>|\btee\b|\btouch\b|\bcp\b|\bmv\b|\brm\b|\bSet-Content\b|\bOut-File\b|\bNew-Item\b|\bRemove-Item\b)"
)
SHELL_SUDO_READ_ONLY_RE = re.compile(
    r"(?i)^\s*(?:cat|ls|test|grep|stat|head|tail|rg)\b"
)
TARGETED_COMMAND_TOOLS = {"apply_patch", "bash", "shell", "exec_command", "exec"}
TARGETED_FILE_TOOLS = {"edit", "write", "multiedit"}

SDD_SUDO_NAME = "SDD_SUDO"
APPROVAL_MSG = (
    "SDD deterministic gate: agents must not set 'Approval: Approved' in "
    "tasks.md. Only a human may approve a task by editing the file directly. "
    "Leave the task as Draft and ask the human to approve it."
)
SDD_SUDO_WRITE_MSG = (
    "SDD deterministic gate: agents must not create, edit, or delete the "
    "SDD_SUDO flag file. Only a human may manage sudo mode."
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


def _find_git_root(start):
    """Walk up from start up to 20 levels; return the git root dir, or None."""
    current = os.path.abspath(start)
    for _ in range(20):
        git_candidate = os.path.join(current, ".git")
        try:
            if os.path.exists(git_candidate):
                return current
        except OSError:
            pass
        parent = os.path.dirname(current)
        if parent == current:
            break
        current = parent
    return None


def _resolve_project_root():
    """Return (root_for_SDD_SUDO, bases_for_AGENT_STOP) per C-08 spec."""
    env_root = os.environ.get("CLAUDE_PROJECT_DIR")
    if env_root:
        return env_root, [env_root, "."]
    git_root = _find_git_root(".")
    if git_root:
        return git_root, [git_root, "."]
    return ".", [".", "."]


def kill_switch_tripped():
    """C-08: walk parents up to git root checking for AGENT_STOP."""
    env_root = os.environ.get("CLAUDE_PROJECT_DIR")
    if env_root:
        bases = [env_root, "."]
    else:
        # Walk up to 20 levels; check every directory up to and including git root.
        bases = []
        current = os.path.abspath(".")
        git_root_found = None
        for _ in range(21):
            bases.append(current)
            git_candidate = os.path.join(current, ".git")
            try:
                if os.path.exists(git_candidate):
                    git_root_found = current
                    break
            except OSError:
                pass
            parent = os.path.dirname(current)
            if parent == current:
                break
            current = parent
        if not git_root_found and "." not in bases:
            bases.append(".")
    for base in bases:
        try:
            if os.path.isfile(os.path.join(base, "AGENT_STOP")):
                return True
        except OSError:
            pass
    return False


def _parse_sudo_fields(content):
    """Parse key: value lines from SDD_SUDO content into a dict (stripped values)."""
    fields = {}
    for line in content.splitlines():
        line = line.rstrip("\r")
        if ":" in line:
            key, _, val = line.partition(":")
            fields[key.strip()] = val.strip()
    return fields


def _strip_key_bytes(raw):
    """Normalize raw key-file bytes: drop a leading UTF-8 BOM (so a key written
    by a BOM-emitting editor/tool matches a BOM-less one across runtimes) and
    strip trailing whitespace/newlines."""
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    return raw.rstrip(b" \t\r\n")


def _resolve_sudo_key():
    """C-04: Resolve signing key bytes per priority order.
    Returns key bytes or None if no key is available."""
    # 1. env SDD_SUDO_KEY
    env_key = os.environ.get("SDD_SUDO_KEY")
    if env_key:
        return env_key.encode("utf-8")
    # 2. env SDD_SUDO_KEY_FILE
    env_key_file = os.environ.get("SDD_SUDO_KEY_FILE")
    if env_key_file:
        try:
            with open(env_key_file, "rb") as f:
                raw = _strip_key_bytes(f.read())
            if raw:
                return raw
        except OSError:
            pass
        return None
    # 3. <HOME>/.sdd/sudo-key
    home = os.environ.get("HOME") or os.environ.get("USERPROFILE", "")
    if home:
        key_path = os.path.join(home, ".sdd", "sudo-key")
        try:
            with open(key_path, "rb") as f:
                raw = _strip_key_bytes(f.read())
            if raw:
                return raw
        except OSError:
            pass
    # 4. No key
    return None


def _sudo_canonical(fields):
    """Return the canonical string to HMAC-sign/verify (5 fields joined by LF)."""
    issuer = fields.get("issuer", "")
    nonce = fields.get("nonce", "")
    repo = fields.get("repo", "")
    issued_str = str(int(fields.get("issued-epoch", "0")))
    expires_str = str(int(fields.get("expires-epoch", "0")))
    return "\n".join([issuer, nonce, repo, issued_str, expires_str])


def sudo_active():
    """C-02/C-04/C-08: True if a valid, signed, unexpired SDD_SUDO flag exists at project root only.
    Validates: not a symlink, required fields present, nonce format, epoch ranges, repo-binding,
    and HMAC-SHA256 signature with key resolved from env/file."""
    sudo_root, _ = _resolve_project_root()
    try:
        flag = os.path.join(sudo_root, SDD_SUDO_NAME)
        # C-02: symlink check — symlink SDD_SUDO is invalid.
        if os.path.islink(flag):
            return False
        if not os.path.isfile(flag):
            return False
        with open(flag, encoding="utf-8") as f:
            content = f.read()

        fields = _parse_sudo_fields(content)

        # Required fields: issuer, nonce, repo, issued-epoch, expires-epoch, sig
        for req in ("issuer", "nonce", "repo", "issued-epoch", "expires-epoch", "sig"):
            if req not in fields or not fields[req]:
                return False

        # Nonce format: >= 32 hex chars
        if not re.match(r"^[0-9a-fA-F]{32,}$", fields["nonce"]):
            return False

        try:
            expires = int(fields["expires-epoch"])
            issued = int(fields["issued-epoch"])
        except (ValueError, TypeError):
            return False

        now = time.time()
        # C-02: issued-epoch <= now < expires-epoch AND TTL <= 86400
        if issued > now:
            return False
        if expires <= now:
            return False
        if (expires - issued) > 86400:
            return False

        # Repo-binding: compare the canonical realpath on BOTH sides so that
        # symlinked representations of the same directory (e.g. macOS /var vs
        # /private/var) compare equal. A token whose repo does not resolve to
        # this directory is rejected (fail-closed, blocks cross-repo replay).
        try:
            actual_repo = os.path.realpath(sudo_root)
            stored_repo = os.path.realpath(fields["repo"])
        except (OSError, ValueError):
            return False
        if stored_repo != actual_repo:
            return False

        # Key resolution and HMAC verification
        key_bytes = _resolve_sudo_key()
        if key_bytes is None:
            return False

        canonical = _sudo_canonical(fields)
        expected_mac = hmac.new(key_bytes, canonical.encode("utf-8"), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(expected_mac, fields["sig"].lower()):
            return False

        return True
    except (OSError, ValueError, TypeError):
        pass
    return False


def approval_increases(payload):
    """Return True if this tool call would add Approval to a tasks.md.

    C-03: Edit/MultiEdit deny if any edit's new_string adds Approved (no net-zero).
    Write deny if task-section-level transition Draft→Approved or new Approved task.
    apply_patch deny if net Approved additions on tasks.md.
    """
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

    if isinstance(tool_input.get("edits"), list):
        # C-03: any Approved added in any new_string is a deny, regardless of deletions.
        for edit in tool_input["edits"]:
            if count((edit or {}).get("new_string")) > 0:
                return True
        return False
    elif "new_string" in tool_input:
        # C-03: any Approved in new_string is a deny (don't subtract old).
        return count(tool_input.get("new_string")) > 0
    elif "content" in tool_input:
        # C-03 Write: task-section-level comparison.
        return _write_content_increases(file_path, tool_input.get("content") or "")
    else:
        return False


def _write_content_increases(file_path, new_content):
    """C-03 Write: deny any net increase in Approved markers.

    Returns True if new_content raises the file-wide Approved count (which also
    covers a brand-new file and any 'Approval: Approved' written outside a
    recognized ``## T-NNN`` section), or if any individual task section goes
    from un-approved to Approved while the file-wide total stays constant
    (e.g. one task un-approved and another approved in the same write).
    """
    try:
        with open(file_path, encoding="utf-8") as f:
            old_content = f.read()
    except OSError:
        old_content = ""

    # File-wide guard: any net increase in total Approved markers is a deny.
    # Catches headerless approvals, brand-new files, and bulk additions that a
    # task-section diff alone would miss.
    if count(new_content) > count(old_content):
        return True

    # Task-section guard: catch a per-task Draft->Approved swap that keeps the
    # file-wide total constant.
    # Extract task sections from old and new content.
    old_tasks = {}  # {task_id: approval_count}
    new_tasks = {}

    # TASK_SECTION_RE.split() returns [text_before, id_1, body_1, id_2, body_2, ...]
    # So odd indices (1, 3, 5, ...) are task IDs, and even indices after 1 (2, 4, 6, ...) are bodies.
    old_parts = TASK_SECTION_RE.split(old_content)
    for i in range(1, len(old_parts) - 1, 2):
        task_id = old_parts[i]
        body = old_parts[i + 1] if i + 1 < len(old_parts) else ""
        if task_id:
            old_tasks[task_id] = count(body)

    new_parts = TASK_SECTION_RE.split(new_content)
    for i in range(1, len(new_parts) - 1, 2):
        task_id = new_parts[i]
        body = new_parts[i + 1] if i + 1 < len(new_parts) else ""
        if task_id:
            new_tasks[task_id] = count(body)

    # Check for transitions: Draft → Approved or new Approved tasks.
    for task_id, new_count in new_tasks.items():
        if new_count > 0:
            old_count = old_tasks.get(task_id, 0)
            # If Approved count increased, or if this is a new task with Approved.
            if new_count > old_count:
                return True

    return False


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


def _target_path_is_sdd_sudo(file_path):
    """C-02: Return True if file_path ends with 'SDD_SUDO' (case-insensitive)."""
    if not file_path:
        return False
    normalized = str(file_path).replace("\\", "/").lower()
    return normalized.endswith(SDD_SUDO_NAME.lower())


def _shell_targets_sdd_sudo(cmd):
    """C-02: Return True if shell command targets SDD_SUDO file for write/delete."""
    if not isinstance(cmd, str):
        return False
    # Check if SDD_SUDO appears in the command (case-insensitive).
    if SDD_SUDO_NAME.lower() not in cmd.lower():
        return False
    # Check if there's a write operator or destructive verb.
    if SHELL_SUDO_WRITE_RE.search(cmd):
        return True
    return False


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

        # Check 2a: C-02 SDD_SUDO write/delete protection (never bypassed by sudo).
        tool_name_lower = tool_name.lower()
        file_path = (tool_input.get("file_path") or "").lower()

        # File tools: Edit, Write, MultiEdit targeting SDD_SUDO.
        if tool_name_lower in ("edit", "write", "multiedit"):
            if _target_path_is_sdd_sudo(file_path):
                emit("deny", SDD_SUDO_WRITE_MSG, mode)
                return

        # Shell commands targeting SDD_SUDO.
        if tool_name_lower in ("bash", "shell", "exec_command", "exec") and isinstance(
            tool_input.get("command"), str
        ):
            if _shell_targets_sdd_sudo(tool_input["command"]):
                emit("deny", SDD_SUDO_WRITE_MSG, mode)
                return

        # apply_patch: check for SDD_SUDO targets.
        if tool_name_lower == "apply_patch" or _looks_like_patch(tool_input.get("command")):
            patch = tool_input.get("command") or ""
            for line in patch.splitlines():
                m = re.match(r"\*\*\* (Update|Add|Delete) File: (.+)$", line)
                if m and _target_path_is_sdd_sudo(m.group(2).strip()):
                    emit("deny", SDD_SUDO_WRITE_MSG, mode)
                    return

        # Check 2b: Approval guard (bypassed by valid sudo).
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
