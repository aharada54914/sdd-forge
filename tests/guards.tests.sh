#!/usr/bin/env bash
# guards.tests.sh — pure-bash test runner for sdd-hook-guard and kill-switch.
# Mirrors install.tests.sh style: ok/fail counters, exits 1 on any failure.
# Runs on Linux and macOS without pwsh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

# Create a temp workdir and clean it up on exit.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# Helper: invoke sdd-hook-guard.sh with a payload on stdin.
# Returns exit code in GUARD_CODE, stdout in GUARD_OUT.
# ---------------------------------------------------------------------------
invoke_guard_sh() {
    local payload="$1"
    local emit="${2:-exit}"
    local outfile="${WORK}/sh-$(date +%s%N 2>/dev/null || date +%s).out"
    GUARD_CODE=0
    GUARD_OUT=""
    printf '%s' "$payload" | bash "${SCRIPTS_DIR}/sdd-hook-guard.sh" "--emit" "$emit" >"$outfile" 2>/dev/null || GUARD_CODE=$?
    GUARD_OUT="$(cat "$outfile" 2>/dev/null || true)"
}

# ---------------------------------------------------------------------------
# Helper: invoke kill-switch.sh in a given directory.
# ---------------------------------------------------------------------------
invoke_kill_switch_sh() {
    local dir="$1"
    local project_dir="${2:-}"
    local code=0
    if [[ -n "$project_dir" ]]; then
        CLAUDE_PROJECT_DIR="$project_dir" bash "${SCRIPTS_DIR}/kill-switch.sh" >/dev/null 2>&1 || code=$?
    else
        (cd "$dir" && unset CLAUDE_PROJECT_DIR && bash "${SCRIPTS_DIR}/kill-switch.sh" >/dev/null 2>&1) || code=$?
    fi
    echo "$code"
}

# ---------------------------------------------------------------------------
# sdd-hook-guard.sh — basic deny/allow/malformed
# ---------------------------------------------------------------------------
mkdir -p "${WORK}/specs/x"

invoke_guard_sh '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'
if [[ $GUARD_CODE -eq 2 ]]; then
    ok "sh: edit adds approval -> deny (exit 2)"
else
    fail "sh: edit adds approval -> deny (expected 2, got $GUARD_CODE)"
fi

invoke_guard_sh '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Status: Planned","new_string":"Status: In Progress"}}'
if [[ $GUARD_CODE -eq 0 ]]; then
    ok "sh: status-only change -> allow (exit 0)"
else
    fail "sh: status-only change -> allow (expected 0, got $GUARD_CODE)"
fi

invoke_guard_sh 'not valid json'
if [[ $GUARD_CODE -eq 0 ]]; then
    ok "sh: malformed payload -> allow (exit 0)"
else
    fail "sh: malformed payload -> allow (expected 0, got $GUARD_CODE)"
fi

# copilot mode deny
invoke_guard_sh '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}' "copilot"
if [[ $GUARD_CODE -eq 0 ]] && echo "$GUARD_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('permissionDecision')=='deny' else 1)" 2>/dev/null; then
    ok "sh: copilot deny -> JSON deny, exit 0"
else
    fail "sh: copilot deny -> JSON deny (code=$GUARD_CODE out='$GUARD_OUT')"
fi

# ---------------------------------------------------------------------------
# kill-switch.sh — basic absent/present
# ---------------------------------------------------------------------------
KS_DIR="${WORK}/ks-basic"
mkdir -p "$KS_DIR"

code="$(cd "$KS_DIR" && unset CLAUDE_PROJECT_DIR && bash "${SCRIPTS_DIR}/kill-switch.sh" >/dev/null 2>&1; echo $?)"
if [[ "$code" -eq 0 ]]; then
    ok "sh: kill-switch absent -> 0"
else
    fail "sh: kill-switch absent -> 0 (got $code)"
fi

echo "stop" > "${KS_DIR}/AGENT_STOP"
code="$(cd "$KS_DIR" && unset CLAUDE_PROJECT_DIR && bash "${SCRIPTS_DIR}/kill-switch.sh" >/dev/null 2>&1; echo $?)"
if [[ "$code" -eq 2 ]]; then
    ok "sh: kill-switch present -> 2"
else
    fail "sh: kill-switch present -> 2 (got $code)"
fi

# ---------------------------------------------------------------------------
# kill-switch.sh — dual-path: AGENT_STOP in cwd, CLAUDE_PROJECT_DIR elsewhere
# ---------------------------------------------------------------------------
KS_CWD="${WORK}/ks-cwd"
KS_PROJ="${WORK}/ks-proj"
mkdir -p "$KS_CWD" "$KS_PROJ"
echo "stop" > "${KS_CWD}/AGENT_STOP"
# CLAUDE_PROJECT_DIR points to ks-proj (no AGENT_STOP there), but cwd has it.
code="$(cd "$KS_CWD" && CLAUDE_PROJECT_DIR="$KS_PROJ" bash "${SCRIPTS_DIR}/kill-switch.sh" >/dev/null 2>&1; echo $?)"
if [[ "$code" -eq 2 ]]; then
    ok "sh: kill-switch dual-path: cwd has AGENT_STOP -> 2"
else
    fail "sh: kill-switch dual-path: cwd has AGENT_STOP -> 2 (got $code)"
fi

# CLAUDE_PROJECT_DIR has AGENT_STOP, cwd does not.
KS_CWD2="${WORK}/ks-cwd2"
KS_PROJ2="${WORK}/ks-proj2"
mkdir -p "$KS_CWD2" "$KS_PROJ2"
echo "stop" > "${KS_PROJ2}/AGENT_STOP"
code="$(cd "$KS_CWD2" && CLAUDE_PROJECT_DIR="$KS_PROJ2" bash "${SCRIPTS_DIR}/kill-switch.sh" >/dev/null 2>&1; echo $?)"
if [[ "$code" -eq 2 ]]; then
    ok "sh: kill-switch dual-path: CLAUDE_PROJECT_DIR has AGENT_STOP -> 2"
else
    fail "sh: kill-switch dual-path: CLAUDE_PROJECT_DIR has AGENT_STOP -> 2 (got $code)"
fi

# ---------------------------------------------------------------------------
# Direct python3 sdd-hook-guard.py tests (not via dispatcher)
# ---------------------------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
    invoke_py_guard() {
        local payload="$1"
        local emit="${2:-exit}"
        local outfile="${WORK}/py-$(date +%s%N 2>/dev/null || date +%s).out"
        PY_CODE=0
        PY_OUT=""
        printf '%s' "$payload" | python3 "${SCRIPTS_DIR}/sdd-hook-guard.py" "--emit" "$emit" >"$outfile" 2>/dev/null || PY_CODE=$?
        PY_OUT="$(cat "$outfile" 2>/dev/null || true)"
    }

    invoke_py_guard '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'
    if [[ $PY_CODE -eq 2 ]]; then
        ok "py: edit adds approval -> deny (exit 2)"
    else
        fail "py: edit adds approval -> deny (expected 2, got $PY_CODE)"
    fi

    invoke_py_guard '{"tool_name":"Edit","tool_input":{"file_path":"/p/src/a.py","old_string":"a","new_string":"b"}}'
    if [[ $PY_CODE -eq 0 ]]; then
        ok "py: other file -> allow (exit 0)"
    else
        fail "py: other file -> allow (expected 0, got $PY_CODE)"
    fi

    invoke_py_guard 'not valid json'
    if [[ $PY_CODE -eq 0 ]]; then
        ok "py: malformed -> allow (exit 0)"
    else
        fail "py: malformed -> allow (expected 0, got $PY_CODE)"
    fi

    # copilot mode
    invoke_py_guard '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}' "copilot"
    if [[ $PY_CODE -eq 0 ]] && echo "$PY_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('permissionDecision')=='deny' else 1)" 2>/dev/null; then
        ok "py: copilot deny -> JSON deny, exit 0"
    else
        fail "py: copilot deny -> JSON (code=$PY_CODE out='$PY_OUT')"
    fi

    # TTY guard: run with stdin from /dev/null (not a TTY) — must not hang, must allow
    PY_TTY_CODE=0
    python3 "${SCRIPTS_DIR}/sdd-hook-guard.py" </dev/null >/dev/null 2>/dev/null || PY_TTY_CODE=$?
    if [[ $PY_TTY_CODE -eq 0 ]]; then
        ok "py: TTY guard with empty stdin (/dev/null) does not hang -> allow (exit 0)"
    else
        fail "py: TTY guard with empty stdin -> allow (expected 0, got $PY_TTY_CODE)"
    fi

    # kill-switch precedence: py guard checks kill-switch before reading stdin
    KS_PY_DIR="${WORK}/ks-py"
    mkdir -p "$KS_PY_DIR"
    echo "stop" > "${KS_PY_DIR}/AGENT_STOP"
    PY_KS_CODE=0
    (cd "$KS_PY_DIR" && unset CLAUDE_PROJECT_DIR && python3 "${SCRIPTS_DIR}/sdd-hook-guard.py" </dev/null >/dev/null 2>/dev/null) || PY_KS_CODE=$?
    if [[ $PY_KS_CODE -eq 2 ]]; then
        ok "py: kill-switch in cwd -> deny (exit 2)"
    else
        fail "py: kill-switch in cwd -> deny (expected 2, got $PY_KS_CODE)"
    fi
else
    echo "python3 not found; skipping direct python3 guard tests."
fi

# ---------------------------------------------------------------------------
# Node.js sdd-hook-guard.js — deny/allow (conditional on node)
# ---------------------------------------------------------------------------
if command -v node >/dev/null 2>&1; then
    invoke_node_guard() {
        local payload="$1"
        local emit="${2:-exit}"
        local outfile="${WORK}/node-$(date +%s%N 2>/dev/null || date +%s).out"
        NODE_CODE=0
        NODE_OUT=""
        printf '%s' "$payload" | node "${SCRIPTS_DIR}/sdd-hook-guard.js" "--emit" "$emit" >"$outfile" 2>/dev/null || NODE_CODE=$?
        NODE_OUT="$(cat "$outfile" 2>/dev/null || true)"
    }

    invoke_node_guard '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'
    if [[ $NODE_CODE -eq 2 ]]; then
        ok "node: edit adds approval -> deny (exit 2)"
    else
        fail "node: edit adds approval -> deny (expected 2, got $NODE_CODE)"
    fi

    invoke_node_guard '{"tool_name":"Edit","tool_input":{"file_path":"/p/src/a.py","old_string":"a","new_string":"b"}}'
    if [[ $NODE_CODE -eq 0 ]]; then
        ok "node: other file -> allow (exit 0)"
    else
        fail "node: other file -> allow (expected 0, got $NODE_CODE)"
    fi
else
    echo "node not found; skipping Node.js guard tests."
fi

# ---------------------------------------------------------------------------
# check-task-state.sh — header-only task
# ---------------------------------------------------------------------------
HEADER_ONLY_FILE="${WORK}/tasks-header-only.md"
printf '## T-1 Header only task\n' > "$HEADER_ONLY_FILE"
HEADER_CODE=0
HEADER_OUT="$(bash "${SCRIPTS_DIR}/check-task-state.sh" "$HEADER_ONLY_FILE" 2>&1)" || HEADER_CODE=$?
if [[ $HEADER_CODE -eq 1 ]]; then
    ok "check-task-state.sh header-only exits 1"
else
    fail "check-task-state.sh header-only exits 1 (got $HEADER_CODE)"
fi
if echo "$HEADER_OUT" | grep -q "no tasks found"; then
    fail "check-task-state.sh header-only must NOT say 'no tasks found' (got: $HEADER_OUT)"
else
    ok "check-task-state.sh header-only produces per-field errors (not 'no tasks found')"
fi

# ---------------------------------------------------------------------------
# check-placeholders.sh — lowercase todo flagged (case-insensitive)
# ---------------------------------------------------------------------------
LOWER_TODO_FILE="${WORK}/todo-lower.py"
printf 'def f():\n    pass  # todo implement this\n' > "$LOWER_TODO_FILE"
PLACEHOLDER_CODE=0
bash "${SCRIPTS_DIR}/check-placeholders.sh" "$LOWER_TODO_FILE" >/dev/null 2>&1 || PLACEHOLDER_CODE=$?
if [[ $PLACEHOLDER_CODE -eq 1 ]]; then
    ok "check-placeholders.sh: lowercase todo flagged"
else
    fail "check-placeholders.sh: lowercase todo flagged (expected 1, got $PLACEHOLDER_CODE)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed."
[[ $FAIL -eq 0 ]]
