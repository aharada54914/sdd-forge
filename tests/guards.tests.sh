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

write_sudo_flag() {
    local dir="$1"
    local expires="$2"
    cat > "${dir}/SDD_SUDO" <<EOF
expires-epoch: ${expires}
EOF
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
if [[ $GUARD_CODE -eq 2 ]]; then
    ok "sh: malformed payload -> deny (exit 2)"
else
    fail "sh: malformed payload -> deny (expected 2, got $GUARD_CODE)"
fi

# copilot mode deny
invoke_guard_sh '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}' "copilot"
if [[ $GUARD_CODE -eq 0 ]] && echo "$GUARD_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('permissionDecision')=='deny' else 1)" 2>/dev/null; then
    ok "sh: copilot deny -> JSON deny, exit 0"
else
    fail "sh: copilot deny -> JSON deny (code=$GUARD_CODE out='$GUARD_OUT')"
fi

# Agent-role guard tests for sh dispatcher
# 1. DENY: Write-style payload to agent role path without developer_instructions
invoke_guard_sh '{"tool_name":"Write","tool_input":{"file_path":"C:\\Users\\u\\.codex\\agents\\auditor.toml","content":"name = \"auditor\"\n"}}'
if [[ $GUARD_CODE -eq 2 ]]; then
    ok "sh: Write agent role without developer_instructions -> deny (exit 2)"
else
    fail "sh: Write agent role without developer_instructions -> deny (expected 2, got $GUARD_CODE)"
fi

# 2. ALLOW: Write-style payload to agent role path WITH developer_instructions
invoke_guard_sh '{"tool_name":"Write","tool_input":{"file_path":"C:\\Users\\u\\.codex\\agents\\auditor.toml","content":"name = \"auditor\"\ndeveloper_instructions = \"\"\"test\"\"\"\n"}}'
if [[ $GUARD_CODE -eq 0 ]]; then
    ok "sh: Write agent role with developer_instructions -> allow (exit 0)"
else
    fail "sh: Write agent role with developer_instructions -> allow (expected 0, got $GUARD_CODE)"
fi

# 3. ALLOW: Write-style payload lacking developer_instructions key to NON-agent path
invoke_guard_sh '{"tool_name":"Write","tool_input":{"file_path":"/tmp/pyproject.toml","content":"name = \"project\"\n"}}'
if [[ $GUARD_CODE -eq 0 ]]; then
    ok "sh: Write to non-agent path -> allow (exit 0)"
else
    fail "sh: Write to non-agent path -> allow (expected 0, got $GUARD_CODE)"
fi

# 4. DENY: apply_patch Add File targeting agent role path with empty body
invoke_guard_sh '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Add File: /home/u/.codex/agents/regression-judge.toml\n*** End Patch"}}'
if [[ $GUARD_CODE -eq 2 ]]; then
    ok "sh: apply_patch Add File agent role with empty body -> deny (exit 2)"
else
    fail "sh: apply_patch Add File agent role with empty body -> deny (expected 2, got $GUARD_CODE)"
fi

# 4b. ALLOW: apply_patch Add File with developer_instructions
invoke_guard_sh '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Add File: /home/u/.codex/agents/regression-judge.toml\n+name = \"regression-judge\"\n+developer_instructions = \"\"\"test\"\"\"\n*** End Patch"}}'
if [[ $GUARD_CODE -eq 0 ]]; then
    ok "sh: apply_patch Add File agent role with developer_instructions -> allow (exit 0)"
else
    fail "sh: apply_patch Add File agent role with developer_instructions -> allow (expected 0, got $GUARD_CODE)"
fi

# 4c. DENY: apply_patch Delete File targeting agent role path
invoke_guard_sh '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Delete File: /home/u/.codex/agents/regression-judge.toml\n*** End Patch"}}'
if [[ $GUARD_CODE -eq 2 ]]; then
    ok "sh: apply_patch Delete File agent role -> deny (exit 2)"
else
    fail "sh: apply_patch Delete File agent role -> deny (expected 2, got $GUARD_CODE)"
fi

# 5. ALLOW: apply_patch Update File section touching agent role path (partial diff)
invoke_guard_sh '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Update File: /home/u/.codex/agents/judge.toml\n-name = \"old\"\n+name = \"judge\"\n*** End Patch"}}'
if [[ $GUARD_CODE -eq 2 ]]; then
    ok "sh: apply_patch Update File agent role -> deny (exit 2)"
else
    fail "sh: apply_patch Update File agent role -> deny (expected 2, got $GUARD_CODE)"
fi

# 6. DENY: shell payload redirect into agent role path without developer_instructions in command
invoke_guard_sh '{"tool_name":"shell","tool_input":{"command":"cat > ~/.codex/agents/judge.toml <<EOF\nname=1\nEOF"}}'
if [[ $GUARD_CODE -eq 2 ]]; then
    ok "sh: shell redirect into agent role without developer_instructions -> deny (exit 2)"
else
    fail "sh: shell redirect into agent role without developer_instructions -> deny (expected 2, got $GUARD_CODE)"
fi

# 7. ALLOW: shell payload read from agent role path (no redirect)
invoke_guard_sh '{"tool_name":"shell","tool_input":{"command":"cat ~/.codex/agents/judge.toml"}}'
if [[ $GUARD_CODE -eq 0 ]]; then
    ok "sh: shell read agent role path -> allow (exit 0)"
else
    fail "sh: shell read agent role path -> allow (expected 0, got $GUARD_CODE)"
fi

# 8. DENY: shell heredoc command containing developer_instructions still counts as a write
invoke_guard_sh '{"tool_name":"shell","tool_input":{"command":"cat > ~/.codex/agents/judge.toml <<EOF\nname=judge\ndeveloper_instructions=\"\"\"test\"\"\"\nEOF"}}'
if [[ $GUARD_CODE -eq 2 ]]; then
    ok "sh: shell heredoc with developer_instructions -> deny (exit 2)"
else
    fail "sh: shell heredoc with developer_instructions -> deny (expected 2, got $GUARD_CODE)"
fi

# 9. DENY: sdd-hook-guard.sh with no python3 or PowerShell available
NORUNTIME_DIR="${WORK}/noruntime-bin"
mkdir -p "$NORUNTIME_DIR"
ln -s "$(command -v cat)" "${NORUNTIME_DIR}/cat"
ln -s "$(command -v dirname)" "${NORUNTIME_DIR}/dirname"
NO_RUNTIME_CODE=0
(PATH="$NORUNTIME_DIR"; printf '%s' '{"tool_name":"Edit","tool_input":{"file_path":"src/a.py","old_string":"a","new_string":"b"}}' | /bin/bash "${SCRIPTS_DIR}/sdd-hook-guard.sh" "--emit" "exit" >/dev/null 2>&1) || NO_RUNTIME_CODE=$?
if [[ $NO_RUNTIME_CODE -eq 2 ]]; then
    ok "sh: no runtime available -> deny (exit 2)"
else
    fail "sh: no runtime available -> deny (expected 2, got $NO_RUNTIME_CODE)"
fi

# ---------------------------------------------------------------------------
# sudo mode (SDD_SUDO flag) — tests for sh dispatcher and direct python3/node
# ---------------------------------------------------------------------------

# Test a: valid sudo (future epoch) + Edit payload that increases Approval -> ALLOW
SUDO_DIR_A="${WORK}/sudo-a"
mkdir -p "$SUDO_DIR_A"
SUDO_EPOCH=$(( $(date +%s) + 3600 ))
write_sudo_flag "$SUDO_DIR_A" "$SUDO_EPOCH"
SUDO_PAYLOAD='{"tool_name":"Edit","tool_input":{"file_path":"tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'
SUDO_CODE_A=0
(cd "$SUDO_DIR_A" && printf '%s' "$SUDO_PAYLOAD" | env CLAUDE_PROJECT_DIR="$SUDO_DIR_A" bash "${SCRIPTS_DIR}/sdd-hook-guard.sh" "--emit" "exit" >/dev/null 2>&1) || SUDO_CODE_A=$?
if [[ $SUDO_CODE_A -eq 0 ]]; then
    ok "sh sudo: valid future epoch + approval increase -> allow (exit 0)"
else
    fail "sh sudo: valid future epoch + approval increase -> allow (expected 0, got $SUDO_CODE_A)"
fi
rm -rf "$SUDO_DIR_A"

# Test b: expired sudo (past epoch) + same payload -> DENY
SUDO_DIR_B="${WORK}/sudo-b"
mkdir -p "$SUDO_DIR_B"
EXPIRED_EPOCH=$(( $(date +%s) - 10 ))
write_sudo_flag "$SUDO_DIR_B" "$EXPIRED_EPOCH"
SUDO_CODE_B=0
(cd "$SUDO_DIR_B" && printf '%s' "$SUDO_PAYLOAD" | env CLAUDE_PROJECT_DIR="$SUDO_DIR_B" bash "${SCRIPTS_DIR}/sdd-hook-guard.sh" "--emit" "exit" >/dev/null 2>&1) || SUDO_CODE_B=$?
if [[ $SUDO_CODE_B -eq 2 ]]; then
    ok "sh sudo: expired epoch + approval increase -> deny (exit 2)"
else
    fail "sh sudo: expired epoch + approval increase -> deny (expected 2, got $SUDO_CODE_B)"
fi
rm -rf "$SUDO_DIR_B"

# Test c: malformed flag (no expires-epoch line) + same payload -> DENY
SUDO_DIR_C="${WORK}/sudo-c"
mkdir -p "$SUDO_DIR_C"
echo "some-other-field: value" > "${SUDO_DIR_C}/SDD_SUDO"
SUDO_CODE_C=0
(cd "$SUDO_DIR_C" && printf '%s' "$SUDO_PAYLOAD" | env CLAUDE_PROJECT_DIR="$SUDO_DIR_C" bash "${SCRIPTS_DIR}/sdd-hook-guard.sh" "--emit" "exit" >/dev/null 2>&1) || SUDO_CODE_C=$?
if [[ $SUDO_CODE_C -eq 2 ]]; then
    ok "sh sudo: malformed flag + approval increase -> deny (exit 2)"
else
    fail "sh sudo: malformed flag + approval increase -> deny (expected 2, got $SUDO_CODE_C)"
fi
rm -rf "$SUDO_DIR_C"

# Test d: valid sudo AND AGENT_STOP both present -> DENY (kill switch wins)
SUDO_DIR_D="${WORK}/sudo-d"
mkdir -p "$SUDO_DIR_D"
write_sudo_flag "$SUDO_DIR_D" "$SUDO_EPOCH"
echo "stop" > "${SUDO_DIR_D}/AGENT_STOP"
SUDO_CODE_D=0
(cd "$SUDO_DIR_D" && printf '%s' "$SUDO_PAYLOAD" | env CLAUDE_PROJECT_DIR="$SUDO_DIR_D" bash "${SCRIPTS_DIR}/sdd-hook-guard.sh" "--emit" "exit" >/dev/null 2>&1) || SUDO_CODE_D=$?
if [[ $SUDO_CODE_D -eq 2 ]]; then
    ok "sh sudo: valid sudo + AGENT_STOP -> deny (exit 2, kill switch wins)"
else
    fail "sh sudo: valid sudo + AGENT_STOP -> deny (expected 2, got $SUDO_CODE_D)"
fi
rm -rf "$SUDO_DIR_D"

# Test e: valid sudo + invalid agent-role Write payload -> DENY (sudo does not bypass check 3)
SUDO_DIR_E="${WORK}/sudo-e"
mkdir -p "$SUDO_DIR_E"
write_sudo_flag "$SUDO_DIR_E" "$SUDO_EPOCH"
AGENT_PAYLOAD='{"tool_name":"Write","tool_input":{"file_path":"C:\\Users\\u\\.codex\\agents\\foo.toml","content":"name = \"foo\"\n"}}'
SUDO_CODE_E=0
(cd "$SUDO_DIR_E" && printf '%s' "$AGENT_PAYLOAD" | env CLAUDE_PROJECT_DIR="$SUDO_DIR_E" bash "${SCRIPTS_DIR}/sdd-hook-guard.sh" "--emit" "exit" >/dev/null 2>&1) || SUDO_CODE_E=$?
if [[ $SUDO_CODE_E -eq 2 ]]; then
    ok "sh sudo: valid sudo + invalid agent role -> deny (exit 2, check 3 not bypassed)"
else
    fail "sh sudo: valid sudo + invalid agent role -> deny (expected 2, got $SUDO_CODE_E)"
fi
rm -rf "$SUDO_DIR_E"

# Direct python3 sudo tests (same cases as above)
if command -v python3 >/dev/null 2>&1; then
    # Test a: valid sudo + approval increase -> ALLOW
    SUDO_DIR_PY_A="${WORK}/sudo-py-a"
    mkdir -p "$SUDO_DIR_PY_A"
    SUDO_EPOCH=$(($(date +%s) + 3600))
    write_sudo_flag "$SUDO_DIR_PY_A" "$SUDO_EPOCH"
    PY_SUDO_CODE_A=0
    (cd "$SUDO_DIR_PY_A" && printf '%s' "$SUDO_PAYLOAD" | env CLAUDE_PROJECT_DIR="$SUDO_DIR_PY_A" python3 "${SCRIPTS_DIR}/sdd-hook-guard.py" "--emit" "exit" >/dev/null 2>&1) || PY_SUDO_CODE_A=$?
    if [[ $PY_SUDO_CODE_A -eq 0 ]]; then
        ok "py sudo: valid future epoch + approval increase -> allow (exit 0)"
    else
        fail "py sudo: valid future epoch + approval increase -> allow (expected 0, got $PY_SUDO_CODE_A)"
    fi
    rm -rf "$SUDO_DIR_PY_A"

    # Test b: expired sudo + approval increase -> DENY
    SUDO_DIR_PY_B="${WORK}/sudo-py-b"
    mkdir -p "$SUDO_DIR_PY_B"
    EXPIRED_EPOCH=$(($(date +%s) - 10))
    write_sudo_flag "$SUDO_DIR_PY_B" "$EXPIRED_EPOCH"
    PY_SUDO_CODE_B=0
    (cd "$SUDO_DIR_PY_B" && printf '%s' "$SUDO_PAYLOAD" | env CLAUDE_PROJECT_DIR="$SUDO_DIR_PY_B" python3 "${SCRIPTS_DIR}/sdd-hook-guard.py" "--emit" "exit" >/dev/null 2>&1) || PY_SUDO_CODE_B=$?
    if [[ $PY_SUDO_CODE_B -eq 2 ]]; then
        ok "py sudo: expired epoch + approval increase -> deny (exit 2)"
    else
        fail "py sudo: expired epoch + approval increase -> deny (expected 2, got $PY_SUDO_CODE_B)"
    fi
    rm -rf "$SUDO_DIR_PY_B"

    # Test c: malformed flag + approval increase -> DENY
    SUDO_DIR_PY_C="${WORK}/sudo-py-c"
    mkdir -p "$SUDO_DIR_PY_C"
    echo "some-other-field: value" > "${SUDO_DIR_PY_C}/SDD_SUDO"
    PY_SUDO_CODE_C=0
    (cd "$SUDO_DIR_PY_C" && printf '%s' "$SUDO_PAYLOAD" | env CLAUDE_PROJECT_DIR="$SUDO_DIR_PY_C" python3 "${SCRIPTS_DIR}/sdd-hook-guard.py" "--emit" "exit" >/dev/null 2>&1) || PY_SUDO_CODE_C=$?
    if [[ $PY_SUDO_CODE_C -eq 2 ]]; then
        ok "py sudo: malformed flag + approval increase -> deny (exit 2)"
    else
        fail "py sudo: malformed flag + approval increase -> deny (expected 2, got $PY_SUDO_CODE_C)"
    fi
    rm -rf "$SUDO_DIR_PY_C"

    # Test d: valid sudo + AGENT_STOP both present -> DENY
    SUDO_DIR_PY_D="${WORK}/sudo-py-d"
    mkdir -p "$SUDO_DIR_PY_D"
    write_sudo_flag "$SUDO_DIR_PY_D" "$SUDO_EPOCH"
    echo "stop" > "${SUDO_DIR_PY_D}/AGENT_STOP"
    PY_SUDO_CODE_D=0
    (cd "$SUDO_DIR_PY_D" && printf '%s' "$SUDO_PAYLOAD" | env CLAUDE_PROJECT_DIR="$SUDO_DIR_PY_D" python3 "${SCRIPTS_DIR}/sdd-hook-guard.py" "--emit" "exit" >/dev/null 2>&1) || PY_SUDO_CODE_D=$?
    if [[ $PY_SUDO_CODE_D -eq 2 ]]; then
        ok "py sudo: valid sudo + AGENT_STOP -> deny (exit 2)"
    else
        fail "py sudo: valid sudo + AGENT_STOP -> deny (expected 2, got $PY_SUDO_CODE_D)"
    fi
    rm -rf "$SUDO_DIR_PY_D"

    # Test e: valid sudo + invalid agent role -> DENY
    SUDO_DIR_PY_E="${WORK}/sudo-py-e"
    mkdir -p "$SUDO_DIR_PY_E"
    write_sudo_flag "$SUDO_DIR_PY_E" "$SUDO_EPOCH"
    PY_SUDO_CODE_E=0
    (cd "$SUDO_DIR_PY_E" && printf '%s' "$AGENT_PAYLOAD" | env CLAUDE_PROJECT_DIR="$SUDO_DIR_PY_E" python3 "${SCRIPTS_DIR}/sdd-hook-guard.py" "--emit" "exit" >/dev/null 2>&1) || PY_SUDO_CODE_E=$?
    if [[ $PY_SUDO_CODE_E -eq 2 ]]; then
        ok "py sudo: valid sudo + invalid agent role -> deny (exit 2)"
    else
        fail "py sudo: valid sudo + invalid agent role -> deny (expected 2, got $PY_SUDO_CODE_E)"
    fi
    rm -rf "$SUDO_DIR_PY_E"
fi

# Node.js sudo tests (same cases via direct node invocation)
if command -v node >/dev/null 2>&1; then
    # Test a: valid sudo + approval increase -> ALLOW
    SUDO_DIR_NODE_A="${WORK}/sudo-node-a"
    mkdir -p "$SUDO_DIR_NODE_A"
    SUDO_EPOCH=$(($(date +%s) + 3600))
    write_sudo_flag "$SUDO_DIR_NODE_A" "$SUDO_EPOCH"
    NODE_SUDO_CODE_A=0
    (cd "$SUDO_DIR_NODE_A" && printf '%s' "$SUDO_PAYLOAD" | env CLAUDE_PROJECT_DIR="$SUDO_DIR_NODE_A" node "${SCRIPTS_DIR}/sdd-hook-guard.js" "--emit" "exit" >/dev/null 2>&1) || NODE_SUDO_CODE_A=$?
    if [[ $NODE_SUDO_CODE_A -eq 0 ]]; then
        ok "node sudo: valid future epoch + approval increase -> allow (exit 0)"
    else
        fail "node sudo: valid future epoch + approval increase -> allow (expected 0, got $NODE_SUDO_CODE_A)"
    fi
    rm -rf "$SUDO_DIR_NODE_A"

    # Test b: expired sudo + approval increase -> DENY
    SUDO_DIR_NODE_B="${WORK}/sudo-node-b"
    mkdir -p "$SUDO_DIR_NODE_B"
    EXPIRED_EPOCH=$(($(date +%s) - 10))
    write_sudo_flag "$SUDO_DIR_NODE_B" "$EXPIRED_EPOCH"
    NODE_SUDO_CODE_B=0
    (cd "$SUDO_DIR_NODE_B" && printf '%s' "$SUDO_PAYLOAD" | env CLAUDE_PROJECT_DIR="$SUDO_DIR_NODE_B" node "${SCRIPTS_DIR}/sdd-hook-guard.js" "--emit" "exit" >/dev/null 2>&1) || NODE_SUDO_CODE_B=$?
    if [[ $NODE_SUDO_CODE_B -eq 2 ]]; then
        ok "node sudo: expired epoch + approval increase -> deny (exit 2)"
    else
        fail "node sudo: expired epoch + approval increase -> deny (expected 2, got $NODE_SUDO_CODE_B)"
    fi
    rm -rf "$SUDO_DIR_NODE_B"

    # Test c: malformed flag + approval increase -> DENY
    SUDO_DIR_NODE_C="${WORK}/sudo-node-c"
    mkdir -p "$SUDO_DIR_NODE_C"
    echo "some-other-field: value" > "${SUDO_DIR_NODE_C}/SDD_SUDO"
    NODE_SUDO_CODE_C=0
    (cd "$SUDO_DIR_NODE_C" && printf '%s' "$SUDO_PAYLOAD" | env CLAUDE_PROJECT_DIR="$SUDO_DIR_NODE_C" node "${SCRIPTS_DIR}/sdd-hook-guard.js" "--emit" "exit" >/dev/null 2>&1) || NODE_SUDO_CODE_C=$?
    if [[ $NODE_SUDO_CODE_C -eq 2 ]]; then
        ok "node sudo: malformed flag + approval increase -> deny (exit 2)"
    else
        fail "node sudo: malformed flag + approval increase -> deny (expected 2, got $NODE_SUDO_CODE_C)"
    fi
    rm -rf "$SUDO_DIR_NODE_C"

    # Test d: valid sudo + AGENT_STOP both present -> DENY
    SUDO_DIR_NODE_D="${WORK}/sudo-node-d"
    mkdir -p "$SUDO_DIR_NODE_D"
    write_sudo_flag "$SUDO_DIR_NODE_D" "$SUDO_EPOCH"
    echo "stop" > "${SUDO_DIR_NODE_D}/AGENT_STOP"
    NODE_SUDO_CODE_D=0
    (cd "$SUDO_DIR_NODE_D" && printf '%s' "$SUDO_PAYLOAD" | env CLAUDE_PROJECT_DIR="$SUDO_DIR_NODE_D" node "${SCRIPTS_DIR}/sdd-hook-guard.js" "--emit" "exit" >/dev/null 2>&1) || NODE_SUDO_CODE_D=$?
    if [[ $NODE_SUDO_CODE_D -eq 2 ]]; then
        ok "node sudo: valid sudo + AGENT_STOP -> deny (exit 2)"
    else
        fail "node sudo: valid sudo + AGENT_STOP -> deny (expected 2, got $NODE_SUDO_CODE_D)"
    fi
    rm -rf "$SUDO_DIR_NODE_D"

    # Test e: valid sudo + invalid agent role -> DENY
    SUDO_DIR_NODE_E="${WORK}/sudo-node-e"
    mkdir -p "$SUDO_DIR_NODE_E"
    write_sudo_flag "$SUDO_DIR_NODE_E" "$SUDO_EPOCH"
    NODE_SUDO_CODE_E=0
    (cd "$SUDO_DIR_NODE_E" && printf '%s' "$AGENT_PAYLOAD" | env CLAUDE_PROJECT_DIR="$SUDO_DIR_NODE_E" node "${SCRIPTS_DIR}/sdd-hook-guard.js" "--emit" "exit" >/dev/null 2>&1) || NODE_SUDO_CODE_E=$?
    if [[ $NODE_SUDO_CODE_E -eq 2 ]]; then
        ok "node sudo: valid sudo + invalid agent role -> deny (exit 2)"
    else
        fail "node sudo: valid sudo + invalid agent role -> deny (expected 2, got $NODE_SUDO_CODE_E)"
    fi
    rm -rf "$SUDO_DIR_NODE_E"
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
    if [[ $PY_CODE -eq 2 ]]; then
        ok "py: malformed -> deny (exit 2)"
    else
        fail "py: malformed -> deny (expected 2, got $PY_CODE)"
    fi

    # copilot mode
    invoke_py_guard '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}' "copilot"
    if [[ $PY_CODE -eq 0 ]] && echo "$PY_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('permissionDecision')=='deny' else 1)" 2>/dev/null; then
        ok "py: copilot deny -> JSON deny, exit 0"
    else
        fail "py: copilot deny -> JSON (code=$PY_CODE out='$PY_OUT')"
    fi

    # TTY guard: run with stdin from /dev/null (not a TTY) — must not hang, must deny
    PY_TTY_CODE=0
    python3 "${SCRIPTS_DIR}/sdd-hook-guard.py" </dev/null >/dev/null 2>/dev/null || PY_TTY_CODE=$?
    if [[ $PY_TTY_CODE -eq 2 ]]; then
        ok "py: TTY guard with empty stdin (/dev/null) does not hang -> deny (exit 2)"
    else
        fail "py: TTY guard with empty stdin -> deny (expected 2, got $PY_TTY_CODE)"
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

    # Agent-role guard tests for python3
    # 1. DENY: Write-style payload to agent role path without developer_instructions
    WRITE_AGENT_NO_DEV='{"tool_name":"Write","tool_input":{"file_path":"C:\\Users\\u\\.codex\\agents\\auditor.toml","content":"name = \"auditor\"\n"}}'
    invoke_py_guard "$WRITE_AGENT_NO_DEV"
    if [[ $PY_CODE -eq 2 ]]; then
        ok "py: Write agent role without developer_instructions -> deny (exit 2)"
    else
        fail "py: Write agent role without developer_instructions -> deny (expected 2, got $PY_CODE)"
    fi

    # 2. ALLOW: Write-style payload to agent role path WITH developer_instructions
    WRITE_AGENT_WITH_DEV='{"tool_name":"Write","tool_input":{"file_path":"C:\\Users\\u\\.codex\\agents\\auditor.toml","content":"name = \"auditor\"\ndeveloper_instructions = \"\"\"test\"\"\"\n"}}'
    invoke_py_guard "$WRITE_AGENT_WITH_DEV"
    if [[ $PY_CODE -eq 0 ]]; then
        ok "py: Write agent role with developer_instructions -> allow (exit 0)"
    else
        fail "py: Write agent role with developer_instructions -> allow (expected 0, got $PY_CODE)"
    fi

    # 3. ALLOW: Write-style payload lacking developer_instructions key to NON-agent path
    WRITE_NON_AGENT='{"tool_name":"Write","tool_input":{"file_path":"/tmp/pyproject.toml","content":"name = \"project\"\n"}}'
    invoke_py_guard "$WRITE_NON_AGENT"
    if [[ $PY_CODE -eq 0 ]]; then
        ok "py: Write to non-agent path -> allow (exit 0)"
    else
        fail "py: Write to non-agent path -> allow (expected 0, got $PY_CODE)"
    fi

    # 4. DENY: apply_patch Add File targeting agent role path with empty body
    PATCH_AGENT_EMPTY='{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Add File: /home/u/.codex/agents/regression-judge.toml\n*** End Patch"}}'
    invoke_py_guard "$PATCH_AGENT_EMPTY"
    if [[ $PY_CODE -eq 2 ]]; then
        ok "py: apply_patch Add File agent role with empty body -> deny (exit 2)"
    else
        fail "py: apply_patch Add File agent role with empty body -> deny (expected 2, got $PY_CODE)"
    fi

    # 4b. ALLOW: apply_patch Add File with developer_instructions
    PATCH_AGENT_ADD='{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Add File: /home/u/.codex/agents/regression-judge.toml\n+name = \"regression-judge\"\n+developer_instructions = \"\"\"test\"\"\"\n*** End Patch"}}'
    invoke_py_guard "$PATCH_AGENT_ADD"
    if [[ $PY_CODE -eq 0 ]]; then
        ok "py: apply_patch Add File agent role with developer_instructions -> allow (exit 0)"
    else
        fail "py: apply_patch Add File agent role with developer_instructions -> allow (expected 0, got $PY_CODE)"
    fi

    # 4c. DENY: apply_patch Delete File targeting agent role path
    PATCH_AGENT_DELETE='{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Delete File: /home/u/.codex/agents/regression-judge.toml\n*** End Patch"}}'
    invoke_py_guard "$PATCH_AGENT_DELETE"
    if [[ $PY_CODE -eq 2 ]]; then
        ok "py: apply_patch Delete File agent role -> deny (exit 2)"
    else
        fail "py: apply_patch Delete File agent role -> deny (expected 2, got $PY_CODE)"
    fi

    # 5. DENY: apply_patch Update File section touching agent role path (partial diff)
    PATCH_AGENT_UPDATE='{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Update File: /home/u/.codex/agents/judge.toml\n-name = \"old\"\n+name = \"judge\"\n*** End Patch"}}'
    invoke_py_guard "$PATCH_AGENT_UPDATE"
    if [[ $PY_CODE -eq 2 ]]; then
        ok "py: apply_patch Update File agent role -> deny (exit 2)"
    else
        fail "py: apply_patch Update File agent role -> deny (expected 2, got $PY_CODE)"
    fi

    # 6. DENY: shell payload redirect into agent role path without developer_instructions in command
    SHELL_AGENT_NO_DEV='{"tool_name":"shell","tool_input":{"command":"cat > ~/.codex/agents/judge.toml <<EOF\nname=1\nEOF"}}'
    invoke_py_guard "$SHELL_AGENT_NO_DEV"
    if [[ $PY_CODE -eq 2 ]]; then
        ok "py: shell redirect into agent role without developer_instructions -> deny (exit 2)"
    else
        fail "py: shell redirect into agent role without developer_instructions -> deny (expected 2, got $PY_CODE)"
    fi

    # 7. ALLOW: shell payload read from agent role path (no redirect)
    SHELL_AGENT_READ='{"tool_name":"shell","tool_input":{"command":"cat ~/.codex/agents/judge.toml"}}'
    invoke_py_guard "$SHELL_AGENT_READ"
    if [[ $PY_CODE -eq 0 ]]; then
        ok "py: shell read agent role path -> allow (exit 0)"
    else
        fail "py: shell read agent role path -> allow (expected 0, got $PY_CODE)"
    fi

    # 8. DENY: shell heredoc command containing developer_instructions still counts as a write
    SHELL_AGENT_WITH_DEV='{"tool_name":"shell","tool_input":{"command":"cat > ~/.codex/agents/judge.toml <<EOF\nname=judge\ndeveloper_instructions=\"\"\"test\"\"\"\nEOF"}}'
    invoke_py_guard "$SHELL_AGENT_WITH_DEV"
    if [[ $PY_CODE -eq 2 ]]; then
        ok "py: shell heredoc with developer_instructions -> deny (exit 2)"
    else
        fail "py: shell heredoc with developer_instructions -> deny (expected 2, got $PY_CODE)"
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

    # Agent-role guard tests for node (via shell dispatcher which prefers python3 if available)
    # 1. DENY: Write-style payload to agent role path without developer_instructions
    invoke_node_guard '{"tool_name":"Write","tool_input":{"file_path":"C:\\Users\\u\\.codex\\agents\\auditor.toml","content":"name = \"auditor\"\n"}}'
    if [[ $NODE_CODE -eq 2 ]]; then
        ok "node: Write agent role without developer_instructions -> deny (exit 2)"
    else
        fail "node: Write agent role without developer_instructions -> deny (expected 2, got $NODE_CODE)"
    fi

    # 2. ALLOW: Write-style payload to agent role path WITH developer_instructions
    invoke_node_guard '{"tool_name":"Write","tool_input":{"file_path":"C:\\Users\\u\\.codex\\agents\\auditor.toml","content":"name = \"auditor\"\ndeveloper_instructions = \"\"\"test\"\"\"\n"}}'
    if [[ $NODE_CODE -eq 0 ]]; then
        ok "node: Write agent role with developer_instructions -> allow (exit 0)"
    else
        fail "node: Write agent role with developer_instructions -> allow (expected 0, got $NODE_CODE)"
    fi

    # 3. ALLOW: Write-style payload lacking developer_instructions key to NON-agent path
    invoke_node_guard '{"tool_name":"Write","tool_input":{"file_path":"/tmp/pyproject.toml","content":"name = \"project\"\n"}}'
    if [[ $NODE_CODE -eq 0 ]]; then
        ok "node: Write to non-agent path -> allow (exit 0)"
    else
        fail "node: Write to non-agent path -> allow (expected 0, got $NODE_CODE)"
    fi

    # 4. DENY: apply_patch Add File targeting agent role path with empty body
    invoke_node_guard '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Add File: /home/u/.codex/agents/regression-judge.toml\n*** End Patch"}}'
    if [[ $NODE_CODE -eq 2 ]]; then
        ok "node: apply_patch Add File agent role with empty body -> deny (exit 2)"
    else
        fail "node: apply_patch Add File agent role with empty body -> deny (expected 2, got $NODE_CODE)"
    fi

    # 4b. ALLOW: apply_patch Add File with developer_instructions
    invoke_node_guard '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Add File: /home/u/.codex/agents/regression-judge.toml\n+name = \"regression-judge\"\n+developer_instructions = \"\"\"test\"\"\"\n*** End Patch"}}'
    if [[ $NODE_CODE -eq 0 ]]; then
        ok "node: apply_patch Add File agent role with developer_instructions -> allow (exit 0)"
    else
        fail "node: apply_patch Add File agent role with developer_instructions -> allow (expected 0, got $NODE_CODE)"
    fi

    # 4c. DENY: apply_patch Delete File targeting agent role path
    invoke_node_guard '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Delete File: /home/u/.codex/agents/regression-judge.toml\n*** End Patch"}}'
    if [[ $NODE_CODE -eq 2 ]]; then
        ok "node: apply_patch Delete File agent role -> deny (exit 2)"
    else
        fail "node: apply_patch Delete File agent role -> deny (expected 2, got $NODE_CODE)"
    fi

    # 5. DENY: apply_patch Update File section touching agent role path (partial diff)
    invoke_node_guard '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Update File: /home/u/.codex/agents/judge.toml\n-name = \"old\"\n+name = \"judge\"\n*** End Patch"}}'
    if [[ $NODE_CODE -eq 2 ]]; then
        ok "node: apply_patch Update File agent role -> deny (exit 2)"
    else
        fail "node: apply_patch Update File agent role -> deny (expected 2, got $NODE_CODE)"
    fi

    # 6. DENY: shell payload redirect into agent role path without developer_instructions in command
    invoke_node_guard '{"tool_name":"shell","tool_input":{"command":"cat > ~/.codex/agents/judge.toml <<EOF\nname=1\nEOF"}}'
    if [[ $NODE_CODE -eq 2 ]]; then
        ok "node: shell redirect into agent role without developer_instructions -> deny (exit 2)"
    else
        fail "node: shell redirect into agent role without developer_instructions -> deny (expected 2, got $NODE_CODE)"
    fi

    # 7. ALLOW: shell payload read from agent role path (no redirect)
    invoke_node_guard '{"tool_name":"shell","tool_input":{"command":"cat ~/.codex/agents/judge.toml"}}'
    if [[ $NODE_CODE -eq 0 ]]; then
        ok "node: shell read agent role path -> allow (exit 0)"
    else
        fail "node: shell read agent role path -> allow (expected 0, got $NODE_CODE)"
    fi

    # 8. DENY: shell heredoc command containing developer_instructions still counts as a write
    invoke_node_guard '{"tool_name":"shell","tool_input":{"command":"cat > ~/.codex/agents/judge.toml <<EOF\nname=judge\ndeveloper_instructions=\"\"\"test\"\"\"\nEOF"}}'
    if [[ $NODE_CODE -eq 2 ]]; then
        ok "node: shell heredoc with developer_instructions -> deny (exit 2)"
    else
        fail "node: shell heredoc with developer_instructions -> deny (expected 2, got $NODE_CODE)"
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
RELATIVE_AGENT_WRITE='{"tool_name":"shell","tool_input":{"command":"cd ~/.codex/agents && cat > judge.toml <<EOF\nname=judge\nEOF"}}'
invoke_guard_sh "$RELATIVE_AGENT_WRITE"
if [[ $GUARD_CODE -eq 2 ]]; then
    ok "sh: relative write after cd into agent role directory -> deny (exit 2)"
else
    fail "sh: relative write after cd into agent role directory -> deny (expected 2, got $GUARD_CODE)"
fi

if command -v python3 >/dev/null 2>&1; then
    invoke_py_guard "$RELATIVE_AGENT_WRITE"
    if [[ $PY_CODE -eq 2 ]]; then
        ok "py: relative write after cd into agent role directory -> deny (exit 2)"
    else
        fail "py: relative write after cd into agent role directory -> deny (expected 2, got $PY_CODE)"
    fi
fi

if command -v node >/dev/null 2>&1; then
    invoke_node_guard "$RELATIVE_AGENT_WRITE"
    if [[ $NODE_CODE -eq 2 ]]; then
        ok "node: relative write after cd into agent role directory -> deny (exit 2)"
    else
        fail "node: relative write after cd into agent role directory -> deny (expected 2, got $NODE_CODE)"
    fi
fi

COPY_AGENT_WRITE='{"tool_name":"shell","tool_input":{"command":"cp /tmp/source.toml ~/.codex/agents/evil.toml"}}'
invoke_guard_sh "$COPY_AGENT_WRITE"
if [[ $GUARD_CODE -eq 2 ]]; then
    ok "sh: cp into agent role directory -> deny (exit 2)"
else
    fail "sh: cp into agent role directory -> deny (expected 2, got $GUARD_CODE)"
fi

if command -v python3 >/dev/null 2>&1; then
    invoke_py_guard "$COPY_AGENT_WRITE"
    if [[ $PY_CODE -eq 2 ]]; then
        ok "py: cp into agent role directory -> deny (exit 2)"
    else
        fail "py: cp into agent role directory -> deny (expected 2, got $PY_CODE)"
    fi
fi

if command -v node >/dev/null 2>&1; then
    invoke_node_guard "$COPY_AGENT_WRITE"
    if [[ $NODE_CODE -eq 2 ]]; then
        ok "node: cp into agent role directory -> deny (exit 2)"
    else
        fail "node: cp into agent role directory -> deny (expected 2, got $NODE_CODE)"
    fi
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed."
[[ $FAIL -eq 0 ]]
