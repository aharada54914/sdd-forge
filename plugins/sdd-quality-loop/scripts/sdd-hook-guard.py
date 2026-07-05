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
import stat
import sys
import time

APPROVAL_RE = re.compile(r"Approval:\s*Approved")
SECOND_APPROVAL_RE = re.compile(r"Second Approval:\s*Approved")
WFI_APPROVAL_RE = re.compile(r"Status:\s*Approved")
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
    "SDD決定論ゲート: エージェントは tasks.md に 'Approval: Approved' を設定できません。タスクの承認は、ファイルを直接編集する人間のみが行えます。タスクは Draft のままにし、人間に承認を依頼してください。"
    "\n[EN] SDD deterministic gate: agents must not set 'Approval: Approved' in "
    "tasks.md. Only a human may approve a task by editing the file directly. "
    "Leave the task as Draft and ask the human to approve it."
)
WFI_APPROVAL_MSG = (
    "SDD決定論ゲート: エージェントは docs/workflow-improvements/WFI-*.md ファイルに 'Status: Approved' を設定できません。Workflow Improvement の承認は人間のみが行え、sudo でもバイパスされません。Draft のままにし、人間に承認を依頼してください。"
    "\n[EN] SDD deterministic gate: agents must not set 'Status: Approved' in a "
    "docs/workflow-improvements/WFI-*.md file. Only a human may approve a "
    "Workflow Improvement; this is never bypassed by sudo. Leave it as Draft "
    "and ask the human to approve it."
)
SECOND_APPROVAL_MSG = (
    "SDD決定論ゲート: エージェントは tasks.md に 'Second Approval: Approved' を設定できません。第二承認は（Workflow Improvement と同様に）独立した人間の判断であり、sudo でもバイパスされません。第二の人間の承認者が記録するまで残してください。"
    "\n[EN] SDD deterministic gate: agents must not set 'Second Approval: Approved' in "
    "tasks.md. A second approval is an independent human judgment (like a Workflow "
    "Improvement) and is never bypassed by sudo. Leave it for a second human "
    "approver to record."
)
IMPL_REVIEW_STATUS_PASSED_RE = re.compile(r"Impl-Review-Status:\s*Passed")
IMPL_REVIEW_STATUS_MSG = (
    "SDD決定論ゲート: エージェントは impl-review-loop の PASS 判定なしに design.md に 'Impl-Review-Status: Passed' を書き込めません。impl-review-loop を実行し、integrated-verdict.json が PASS または PASS-with-warnings を返すまで待ってください。"
    "\n[EN] SDD deterministic gate: agents must not write 'Impl-Review-Status: Passed' in "
    "design.md without a valid integrated-verdict.json with verdict PASS or PASS-with-warnings "
    "from impl-review-loop. Run impl-review-loop and wait for it to return PASS or PASS-with-warnings."
)
SDD_SUDO_WRITE_MSG = (
    "SDD決定論ゲート: エージェントは SDD_SUDO フラグファイルの作成・編集・削除を行えません。sudo モードの管理は人間のみが行えます。"
    "\n[EN] SDD deterministic gate: agents must not create, edit, or delete the "
    "SDD_SUDO flag file. Only a human may manage sudo mode."
)
KILL_MSG = (
    "SDDキルスイッチ: プロジェクトルートに AGENT_STOP が存在します。人間がこのファイルを削除するまで、すべてのツール使用が停止されます。"
    "\n[EN] SDD kill switch: AGENT_STOP exists at the project root. All tool use is "
    "suspended until a human deletes the file."
)
AGENT_ROLE_MSG = (
    "SDD決定論ゲート: developer_instructions の無い Codex エージェントロールファイルの書き込みを拒否しました。.codex/agents/ 配下のファイルは developer_instructions を定義する必要があり、無い場合 Codex は起動時にこれを無視します（'Ignoring malformed agent role definition'）。新規作成せず、同梱の sdd-investigator / sdd-evaluator ロールを使用してください。"
    "\n[EN] SDD deterministic gate: refusing to write a Codex agent role file without "
    "developer_instructions. Files under .codex/agents/ must define "
    "developer_instructions or Codex ignores them at startup "
    "('Ignoring malformed agent role definition'). Use the shipped "
    "sdd-investigator/sdd-evaluator roles instead of creating new ones."
)


def count(text):
    """Count primary Approval: Approved markers, excluding Second Approval occurrences."""
    if not text:
        return 0
    # Subtract second approvals from primary count to avoid over-counting
    # (since "Second Approval: Approved" contains "Approval: Approved" as a substring)
    return len(APPROVAL_RE.findall(text)) - len(SECOND_APPROVAL_RE.findall(text))


def is_tasks_md(path):
    """Return True if path ends with 'tasks.md' (case-insensitive)."""
    # Case-insensitive match (intentional: matches JS/PS1 behavior; Windows FS is case-insensitive).
    return bool(path) and str(path).replace("\\", "/").lower().endswith("tasks.md")



def is_design_md(path):
    """Return True if path ends with 'design.md' (case-insensitive)."""
    return bool(path) and str(path).replace("\\", "/").lower().endswith("design.md")


def _impl_review_verdict_exists(feature):
    """CWD-relative path resolution (matches JS behavior, ADR-004)."""
    import glob as _glob
    import json as _json
    pattern = f"reports/impl-review/{feature}/attempt-*/round-*/integrated-verdict.json"
    for f in _glob.glob(pattern):
        try:
            with open(f) as fh:
                data = _json.load(fh)
            if data.get("verdict") in ("PASS", "PASS-with-warnings"):
                return True
        except Exception:
            pass
    return False


def impl_review_status_passed_increases(payload):
    """Return True if this call would newly introduce Impl-Review-Status: Passed without verdict."""
    tool_input = payload.get("tool_input") or {}
    tool_name = (payload.get("tool_name") or "").lower()
    file_path = tool_input.get("file_path") or ""

    if tool_name not in TARGETED_FILE_TOOLS:
        return False
    if not is_design_md(file_path):
        return False

    new_content = ""
    if isinstance(tool_input.get("edits"), list):
        for edit in tool_input["edits"]:
            e = edit or {}
            if IMPL_REVIEW_STATUS_PASSED_RE.search(e.get("new_string") or ""):
                new_content = e.get("new_string") or ""
                break
    elif "new_string" in tool_input:
        new_content = tool_input.get("new_string") or ""
    elif "content" in tool_input:
        new_content = tool_input.get("content") or ""

    if not IMPL_REVIEW_STATUS_PASSED_RE.search(new_content):
        return False

    try:
        with open(file_path, encoding="utf-8") as fh:
            old_content = fh.read()
    except Exception:
        old_content = ""
    if IMPL_REVIEW_STATUS_PASSED_RE.search(old_content):
        return False  # already set; not a new introduction

    m = re.search(r"specs/([^/]+)/design\.md$",
                  str(file_path).replace("\\", "/"), re.IGNORECASE)
    if not m:
        return False
    feature = m.group(1)
    return not _impl_review_verdict_exists(feature)


def is_wfi_path(path):
    """Return True if path is a Workflow Improvement file under docs/workflow-improvements/."""
    # WFI docs live under docs/workflow-improvements/ and end with .md.
    if not path:
        return False
    normalized = str(path).replace("\\", "/").lower()
    return "workflow-improvements/" in normalized and normalized.endswith(".md")


def wfi_count(text):
    """Count Status: Approved occurrences in WFI file content."""
    if not text:
        return 0
    return len(WFI_APPROVAL_RE.findall(text))


def count_second(text):
    """Count Second Approval: Approved occurrences in tasks.md."""
    if not text:
        return 0
    return len(SECOND_APPROVAL_RE.findall(text))


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
        sys.stdout.buffer.write(json.dumps(out, separators=(",", ":"), ensure_ascii=False).encode("utf-8"))
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
        # R-11: Use O_NOFOLLOW to close lstat→open symlink-swap race at kernel level.
        # O_NOFOLLOW is available on Linux/macOS; falls back to 0 (no-op) on Windows.
        # On POSIX, if SDD_SUDO is a symlink, os.open raises OSError(ELOOP) → caught below → False.
        # O_NONBLOCK prevents blocking on FIFOs masquerading as the flag file.
        try:
            o_nofollow = getattr(os, "O_NOFOLLOW", 0)
            o_nonblock = getattr(os, "O_NONBLOCK", 0)
            if o_nofollow == 0:
                # Windows: no O_NOFOLLOW — use lstat to reject symlinks before open.
                try:
                    _lst = os.lstat(flag)
                except OSError:
                    return False
                if stat.S_ISLNK(_lst.st_mode):
                    return False
            _oflags = os.O_RDONLY | o_nofollow | o_nonblock
            _fd = os.open(flag, _oflags)
        except OSError:
            return False
        try:
            _st = os.fstat(_fd)
            if not stat.S_ISREG(_st.st_mode):
                os.close(_fd)
                return False
            with os.fdopen(_fd, encoding="utf-8") as f:
                content = f.read()
        except UnicodeDecodeError:
            return False
        except OSError:
            try:
                os.close(_fd)
            except OSError:
                pass
            return False

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
    except (OSError, ValueError, TypeError, UnicodeDecodeError):
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
    """Return True if command string looks like a Codex apply_patch envelope."""
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


def wfi_approval_increases(payload):
    """Return True if this tool call would set 'Status: Approved' in a WFI file.

    WFI approval is human-only and is NEVER bypassed by sudo. Mirrors the tasks.md
    approval guard but keyed on the 'Status: Approved' marker and scoped to
    docs/workflow-improvements/*.md.
    """
    tool_input = payload.get("tool_input") or {}
    tool_name = (payload.get("tool_name") or "").lower()

    if tool_name == "apply_patch" or _looks_like_patch(tool_input.get("command")):
        return _wfi_patch_increases(tool_input.get("command") or "")

    if tool_name in ("bash", "shell", "exec_command", "exec") and isinstance(
        tool_input.get("command"), str
    ):
        cmd = tool_input["command"]
        if "workflow-improvements/" in cmd.lower() and WFI_APPROVAL_RE.search(cmd):
            return True
        return False

    file_path = tool_input.get("file_path") or ""
    if not is_wfi_path(file_path):
        return False

    if isinstance(tool_input.get("edits"), list):
        for edit in tool_input["edits"]:
            if wfi_count((edit or {}).get("new_string")) > 0:
                return True
        return False
    elif "new_string" in tool_input:
        return wfi_count(tool_input.get("new_string")) > 0
    elif "content" in tool_input:
        return _wfi_write_content_increases(file_path, tool_input.get("content") or "")
    else:
        return False


def _wfi_write_content_increases(file_path, new_content):
    """Return True if new_content raises the WFI approval count compared to the file on disk."""
    try:
        with open(file_path, encoding="utf-8") as f:
            old_content = f.read()
    except OSError:
        old_content = ""
    return wfi_count(new_content) > wfi_count(old_content)


def _wfi_patch_increases(patch):
    """Parse a Codex patch envelope; return True if net Status: Approved added to a WFI file."""
    current_is_wfi = False
    added = removed = 0
    for raw in patch.splitlines():
        m = re.match(r"\*\*\* (Update|Add|Delete) File: (.+)$", raw)
        if m:
            current_is_wfi = is_wfi_path(m.group(2).strip())
            continue
        if raw.startswith("*** End Patch") or raw.startswith("*** Begin Patch"):
            continue
        if not current_is_wfi:
            continue
        if raw.startswith("+") and not raw.startswith("+++"):
            added += wfi_count(raw[1:])
        elif raw.startswith("-") and not raw.startswith("---"):
            removed += wfi_count(raw[1:])
    return (added - removed) > 0


def second_approval_increases(payload):
    """Return True if this tool call would set 'Second Approval: Approved' in tasks.md.

    Second Approval is human-only and is NEVER bypassed by sudo. Mirrors the tasks.md
    approval guard but keyed on the 'Second Approval: Approved' marker and scoped to
    tasks.md (not a separate path).
    """
    tool_input = payload.get("tool_input") or {}
    tool_name = (payload.get("tool_name") or "").lower()

    if tool_name == "apply_patch" or _looks_like_patch(tool_input.get("command")):
        return _second_approval_patch_increases(tool_input.get("command") or "")

    if tool_name in ("bash", "shell", "exec_command", "exec") and isinstance(
        tool_input.get("command"), str
    ):
        cmd = tool_input["command"]
        if "tasks.md" in cmd.lower() and SECOND_APPROVAL_RE.search(cmd):
            return True
        return False

    file_path = tool_input.get("file_path") or ""
    if not is_tasks_md(file_path):
        return False

    if isinstance(tool_input.get("edits"), list):
        # Deny if any edit's new_string adds a Second Approval
        for edit in tool_input["edits"]:
            if count_second((edit or {}).get("new_string")) > 0:
                return True
        return False
    elif "new_string" in tool_input:
        # Deny if new_string has any Second Approval
        return count_second(tool_input.get("new_string")) > 0
    elif "content" in tool_input:
        # Write: deny if net increase in Second Approval markers
        return _second_approval_write_content_increases(file_path, tool_input.get("content") or "")
    else:
        return False


def _second_approval_write_content_increases(file_path, new_content):
    """Return True if new_content raises the file-wide Second Approval count."""
    try:
        with open(file_path, encoding="utf-8") as f:
            old_content = f.read()
    except OSError:
        old_content = ""

    return count_second(new_content) > count_second(old_content)


def _second_approval_patch_increases(patch):
    """Parse a Codex patch envelope; return True if net second approvals added to tasks.md."""
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
            added += count_second(raw[1:])
        elif raw.startswith("-") and not raw.startswith("---"):
            removed += count_second(raw[1:])
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


# R-10: Enforcement-chain file protection.
# Files whose write denial is NOT bypassable by sudo. Patterns are matched
# case-insensitively against the normalized (forward-slash) path.
# NOTE: Bash tool path-substring scan (below) is best-effort only — agents
# using python3 -c / node -e inline may bypass verb detection. Edit/Write/MultiEdit
# path is the primary enforcement point.
_PROTECTED_GATE_SUFFIXES = (
    # hook guard scripts (self-protection)
    "plugins/sdd-quality-loop/scripts/sdd-hook-guard.js",
    "plugins/sdd-quality-loop/scripts/sdd-hook-guard.py",
    "plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1",
    "plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh",
    # kill-switch scripts
    "plugins/sdd-quality-loop/scripts/kill-switch.js",
    "plugins/sdd-quality-loop/scripts/kill-switch.sh",
    "plugins/sdd-quality-loop/scripts/kill-switch.ps1",
    # hook registration files
    "plugins/sdd-quality-loop/hooks/claude-hooks.json",
    "plugins/sdd-quality-loop/hooks/hooks.json",
    "plugins/sdd-quality-loop/hooks/copilot-hooks.json",
    # gate scripts
    "plugins/sdd-quality-loop/scripts/check-contract.sh",
    "plugins/sdd-quality-loop/scripts/check-contract.ps1",
    "plugins/sdd-quality-loop/scripts/check-contract.py",
    "plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh",
    "plugins/sdd-quality-loop/scripts/check-evidence-bundle.ps1",
    "plugins/sdd-quality-loop/scripts/check-evidence-bundle.py",
    # shared path-validation utility (R-01)
    "plugins/sdd-quality-loop/scripts/validate_path.py",
    # Claude Code hook-loading config
    ".claude/settings.json",
    ".claude/settings.local.json",
    # critical test files (hollowing breaks CI safety net)
    "tests/gates.tests.sh",
    "tests/eval.tests.sh",
    "tests/guard-parity.tests.sh",
    "tests/constant-parity.tests.sh",
    # R-10: task-review and impl-review gate files (enforcement chain)
    # R-10 NEW: sdd-review-loop gate files (T-002 Phase 1)
    "plugins/sdd-review-loop/agents/impl-reviewer-a.md",
    "plugins/sdd-review-loop/agents/impl-reviewer-b.md",
    "plugins/sdd-review-loop/agents/task-reviewer-a.md",
    "plugins/sdd-review-loop/agents/task-reviewer-b.md",
    "plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md",
    "plugins/sdd-review-loop/skills/task-review-loop/SKILL.md",
    # R-10: sdd-ship orchestrator (self-protection of the second public command)
    "plugins/sdd-ship/skills/ship/SKILL.md",
)

_PROTECTED_GATE_PLUGIN_JSON_SUFFIXES = (
    # plugin entry points that point to hook registration
    "/.plugin/plugin.json",
    "/.claude-plugin/plugin.json",
    "/.codex-plugin/plugin.json",
)

_GATE_PROTECT_MSG = (
    "SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。"
    "\n[EN] SDD deterministic gate: agents must not modify gate scripts, hook "
    "configuration, or critical test files. These are part of the enforcement chain "
    "and cannot be bypassed by sudo."
)


_SHELL_COMPOUND_RE = re.compile(r"&&|\|\||;|\|")

# Issue #62: write-target analysis for shell commands that mention a protected
# gate file. Verb sets and token patterns are kept identical to the JS twin
# (guard-parity.tests.sh verifies exit-code parity).
_SHELL_WRITE_ARG_CMDS = ("tee", "touch", "rm")
_SHELL_WRITE_DEST_CMDS = ("cp", "mv")
_SHELL_PS_WRITE_CMDS = ("set-content", "out-file", "new-item", "remove-item")
_SHELL_INDIRECT_CMDS = ("eval", "xargs", "source", "sh", "bash", "zsh", "dash", "ksh")
_SHELL_UNSAFE_TOKEN_CHARS = ("$", "`", "(", ")", "{", "}", "*", "?", "[", "]")
_SHELL_REDIRECT_TOKEN_RE = re.compile(r"^(?:\d*|&)(>>?)([\s\S]*)$")
_SHELL_FD_DUP_RE = re.compile(r"^&(?:\d+|-)$")


def _is_protected_gate_file(file_path):
    """R-10: Return True if file_path matches a protected enforcement-chain file."""
    if not file_path:
        return False
    # normpath collapses .. segments so `../../tests/gates.tests.sh` is caught.
    normalized = os.path.normpath(str(file_path).replace("\\", "/")).replace("\\", "/").lower()
    for suffix in _PROTECTED_GATE_SUFFIXES:
        if normalized.endswith(suffix.lower()):
            return True
    for suffix in _PROTECTED_GATE_PLUGIN_JSON_SUFFIXES:
        sl = suffix.lower()
        # Match absolute paths (suffix has leading /) AND relative paths (no leading /).
        if normalized.endswith(sl) or normalized.endswith(sl.lstrip("/")):
            return True
    return False


def _tokenize_shell_command(cmd):
    """Issue #62: simple shell tokenizer (same algorithm as the JS twin).
    Splits on unquoted spaces/tabs; ';', '|', '&' and newlines become separator
    tokens; single/double quotes group text (quote marks removed); '>&'/'&>'
    stay attached to their redirect token. Returns a list of (kind, text)
    tuples with kind 'word' or 'sep', or None when the command uses constructs
    the tokenizer does not model (backslash escapes, unclosed quotes) —
    callers must fail closed on None."""
    tokens = []
    cur = ""
    pending = False
    in_single = False
    in_double = False
    i = 0
    n = len(cmd)
    while i < n:
        ch = cmd[i]
        if in_single:
            if ch == "'":
                in_single = False
            else:
                cur += ch
            i += 1
            continue
        if in_double:
            if ch == '"':
                in_double = False
            elif ch == "\\":
                return None
            else:
                cur += ch
            i += 1
            continue
        if ch == "'":
            in_single = True
            pending = True
        elif ch == '"':
            in_double = True
            pending = True
        elif ch == "\\":
            return None
        elif ch in ("\n", "\r", ";", "|"):
            if pending:
                tokens.append(("word", cur))
                cur = ""
                pending = False
            tokens.append(("sep", ch))
        elif ch == "&":
            if pending and cur.endswith(">"):
                # 2>&1-style fd duplication stays inside the redirect token.
                cur += ch
            elif i + 1 < n and cmd[i + 1] == ">":
                # &>-style redirect starts a new token.
                if pending:
                    tokens.append(("word", cur))
                cur = "&"
                pending = True
            else:
                if pending:
                    tokens.append(("word", cur))
                    cur = ""
                pending = False
                tokens.append(("sep", ch))
        elif ch in (" ", "\t"):
            if pending:
                tokens.append(("word", cur))
                cur = ""
                pending = False
        else:
            cur += ch
            pending = True
        i += 1
    if in_single or in_double:
        return None
    if pending:
        tokens.append(("word", cur))
    return tokens


def _shell_token_basename(tok):
    """Issue #62: lowercased final path component of a token (verb matching)."""
    return tok.lower().replace("\\", "/").rsplit("/", 1)[-1]


def _simple_shell_command_is_safe(words):
    """Issue #62: check one separator-free simple command. Returns False when a
    redirect or write verb in it targets (or may target) a protected gate file."""
    plain = []
    k = 0
    n = len(words)
    while k < n:
        w = words[k]
        if ">" in w:
            m = _SHELL_REDIRECT_TOKEN_RE.match(w)
            if not m:
                return False
            rest = m.group(2)
            if rest == "":
                # Detached target (`> file`): consume and check the next token.
                k += 1
                if k >= n or ">" in words[k]:
                    return False
                if _is_protected_gate_file(words[k]):
                    return False
            elif rest.startswith("&"):
                # fd duplication (2>&1, >&2, >&-) is harmless; anything else
                # (e.g. >&file) is not modeled — fail closed.
                if not _SHELL_FD_DUP_RE.match(rest):
                    return False
            else:
                if _is_protected_gate_file(rest):
                    return False
        else:
            plain.append(w)
        k += 1
    write_at = -1
    write_base = ""
    for idx in range(len(plain)):
        base = _shell_token_basename(plain[idx])
        if base in _SHELL_WRITE_ARG_CMDS or base in _SHELL_WRITE_DEST_CMDS:
            write_at = idx
            write_base = base
            break
    if write_at < 0:
        return True
    args = plain[write_at + 1:]
    non_flags = [a for a in args if not a.startswith("-")]
    if write_base in _SHELL_WRITE_DEST_CMDS:
        # cp/mv: only the final non-flag argument (the destination) is
        # written; sources are reads. Fewer than two path arguments cannot
        # be judged — fail closed.
        if len(non_flags) < 2:
            return False
        return not _is_protected_gate_file(non_flags[-1])
    # tee/touch/rm: every non-flag argument is written (or deleted).
    for a in non_flags:
        if _is_protected_gate_file(a):
            return False
    return True


def _shell_write_targets_are_safe(cmd):
    """Issue #62: True only when every write verb/redirect in cmd provably
    targets a non-protected path. Constructs the analysis cannot model
    (escapes, expansions, globs, subshells, eval/xargs/shell interpreters,
    PowerShell write verbs) return False (fail-close)."""
    tokens = _tokenize_shell_command(cmd)
    if tokens is None:
        return False
    commands = []
    words = []
    for kind, text in tokens:
        if kind == "sep":
            if words:
                commands.append(words)
                words = []
        else:
            words.append(text)
    if words:
        commands.append(words)
    for command in commands:
        for w in command:
            for c in _SHELL_UNSAFE_TOKEN_CHARS:
                if c in w:
                    return False
            base = _shell_token_basename(w)
            if base in _SHELL_INDIRECT_CMDS or base in _SHELL_PS_WRITE_CMDS:
                return False
        if not _simple_shell_command_is_safe(command):
            return False
    return True


def _shell_targets_protected_gate_file(cmd):
    """R-10: Deny shell commands that WRITE to protected gate files.
    Uses substring scan (path appears literally in command) combined with
    write-target analysis (issue #62): a write verb/redirect elsewhere in the
    command no longer denies read-only access to a protected path.
    Read-only short-circuit only fires when ALL of the following hold:
      1. No compound operators (&&, ||, ;, |) — prevents `cat f && rm f`
      2. Command starts with a read-only verb (cat, grep, …)
      3. No write verb/redirect appears anywhere — prevents `cat > f << EOF`
    Otherwise, deny only when a write target is (or cannot be proven not to
    be) a protected gate file — fail-close on anything unmodeled."""
    if not isinstance(cmd, str):
        return False
    cmd_lower = cmd.lower()
    has_protected_path = any(s.lower() in cmd_lower for s in _PROTECTED_GATE_SUFFIXES) or \
                         any(s.lower() in cmd_lower or s.lower().lstrip("/") in cmd_lower
                             for s in _PROTECTED_GATE_PLUGIN_JSON_SUFFIXES)
    if not has_protected_path:
        return False
    has_write = bool(SHELL_SUDO_WRITE_RE.search(cmd))
    if not _SHELL_COMPOUND_RE.search(cmd) and SHELL_SUDO_READ_ONLY_RE.match(cmd) and not has_write:
        return False
    if not has_write:
        return False
    return not _shell_write_targets_are_safe(cmd)


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
    """Return True if required fields for the tool type are missing or empty."""
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
    """Parse --emit <mode> from argv; return 'exit' or 'copilot' (default 'exit')."""
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
    """Entry point: read payload from stdin or PAYLOAD env var, run all guards, emit decision."""
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
        emit("deny", "SDD決定論ゲート: フックのペイロードが不正です。\n[EN] SDD deterministic gate: malformed hook payload.", mode)
        return

    try:
        tool_input = payload.get("tool_input")
        tool_name = payload.get("tool_name")
        if not isinstance(tool_name, str) or not isinstance(tool_input, dict):
            emit("deny", "SDD決定論ゲート: フックのペイロードが不正です。\n[EN] SDD deterministic gate: malformed hook payload.", mode)
            return
        if payload_is_malformed(payload):
            emit("deny", "SDD決定論ゲート: フックのペイロードが不正です。\n[EN] SDD deterministic gate: malformed hook payload.", mode)
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

        # Check 2a-R10: Enforcement-chain file protection (never bypassed by sudo).
        if tool_name_lower in ("edit", "write", "multiedit"):
            if _is_protected_gate_file(tool_input.get("file_path") or ""):
                emit("deny", _GATE_PROTECT_MSG, mode)
                return

        if tool_name_lower in ("bash", "shell", "exec_command", "exec") and isinstance(
            tool_input.get("command"), str
        ):
            if _shell_targets_protected_gate_file(tool_input["command"]):
                emit("deny", _GATE_PROTECT_MSG, mode)
                return

        if tool_name_lower == "apply_patch" or _looks_like_patch(tool_input.get("command")):
            patch = tool_input.get("command") or ""
            for line in patch.splitlines():
                m = re.match(r"\*\*\* (Update|Add|Delete) File: (.+)$", line)
                if m and _is_protected_gate_file(m.group(2).strip()):
                    emit("deny", _GATE_PROTECT_MSG, mode)
                    return

        # Check 2b: Approval guard (bypassed by valid sudo).
        if approval_increases(payload) and not sudo_active():
            emit("deny", APPROVAL_MSG, mode)

        # Check 2c: WFI approval guard (NEVER bypassed by sudo).
        if wfi_approval_increases(payload):
            emit("deny", WFI_APPROVAL_MSG, mode)

        # Check 2d: Second Approval guard (NEVER bypassed by sudo).
        if second_approval_increases(payload):
            emit("deny", SECOND_APPROVAL_MSG, mode)

        # Check 2e: Impl-Review-Status: Passed guard (NEVER bypassed by sudo).
        if impl_review_status_passed_increases(payload):
            emit("deny", IMPL_REVIEW_STATUS_MSG, mode)
    except Exception:
        # Never crash; fail closed on the approval check.
        emit("deny", "SDD決定論ゲート: 承認ガードがフェイルクローズしました。\n[EN] SDD deterministic gate: approval guard failed closed.", mode)
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
        emit("deny", "SDD決定論ゲート: エージェントロールガードがフェイルクローズしました。\n[EN] SDD deterministic gate: agent-role guard failed closed.", mode)
        return

    emit("allow", None, mode)


if __name__ == "__main__":
    main()
