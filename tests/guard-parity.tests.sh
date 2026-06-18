#!/usr/bin/env bash
# guard-parity.tests.sh — R-02: Cross-runtime behavioral parity test.
# Verifies that sdd-hook-guard.js and sdd-hook-guard.py produce IDENTICAL
# exit codes for every scenario. Any divergence is a security boundary difference.
# Requires: node (14+), python3, bash.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# Runtime availability check
# ---------------------------------------------------------------------------
if ! command -v node >/dev/null 2>&1; then
    echo "SKIP: guard-parity.tests.sh requires node (not found)"
    exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP: guard-parity.tests.sh requires python3 (not found)"
    exit 0
fi

# ---------------------------------------------------------------------------
# Helper: run payload through both guards, assert same exit code.
# Usage: parity_check "scenario name" <payload_json>
# ---------------------------------------------------------------------------
parity_check() {
    local scenario="$1"
    local payload="$2"
    local js_code=0
    local py_code=0

    # JS guard
    printf '%s' "$payload" \
        | CLAUDE_PROJECT_DIR="$WORK" node "${SCRIPTS_DIR}/sdd-hook-guard.js" --emit exit \
        >/dev/null 2>&1 || js_code=$?

    # Python guard
    printf '%s' "$payload" \
        | CLAUDE_PROJECT_DIR="$WORK" python3 "${SCRIPTS_DIR}/sdd-hook-guard.py" --emit exit \
        >/dev/null 2>&1 || py_code=$?

    if [ "$js_code" = "$py_code" ]; then
        ok "parity [$scenario]: both exit $js_code"
    else
        fail "parity [$scenario]: JS=$js_code PY=$py_code — DIVERGENCE"
    fi
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
export SDD_SUDO_KEY="parity-test-key-do-not-use"

TASKS_MD="${WORK}/tasks.md"
cat >"$TASKS_MD" <<'EOF'
## T-001
Title: Test task
Approval: Draft
EOF

# ---------------------------------------------------------------------------
# Scenario 1: kill switch (deny — exit 2)
# ---------------------------------------------------------------------------
touch "${WORK}/AGENT_STOP"
parity_check "kill-switch: AGENT_STOP exists" \
    '{"tool_name":"write","tool_input":{"file_path":"README.md","content":"x"}}'
rm -f "${WORK}/AGENT_STOP"

# ---------------------------------------------------------------------------
# Scenario 2: kill switch not tripped (allow — exit 0)
# ---------------------------------------------------------------------------
parity_check "kill-switch: no AGENT_STOP" \
    '{"tool_name":"write","tool_input":{"file_path":"README.md","content":"x"}}'

# ---------------------------------------------------------------------------
# Scenario 3: approval guard — Write adding Approval: Approved (deny — exit 2)
# ---------------------------------------------------------------------------
parity_check "approval-guard: Write adds Approval" \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"${TASKS_MD}\",\"content\":\"## T-001\\nApproval: Approved\"}}"

# ---------------------------------------------------------------------------
# Scenario 4: approval guard — Edit adding Approval: Approved (deny — exit 2)
# ---------------------------------------------------------------------------
parity_check "approval-guard: Edit adds Approval" \
    "{\"tool_name\":\"edit\",\"tool_input\":{\"file_path\":\"${TASKS_MD}\",\"old_string\":\"Draft\",\"new_string\":\"Approved\"}}"

# ---------------------------------------------------------------------------
# Scenario 5: WFI guard — write Status: Approved in WFI path (deny — exit 2)
# ---------------------------------------------------------------------------
mkdir -p "${WORK}/docs/workflow-improvements"
WFI_FILE="${WORK}/docs/workflow-improvements/WFI-001.md"
printf 'Status: Draft\n' > "$WFI_FILE"
parity_check "wfi-guard: write Status: Approved" \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"${WFI_FILE}\",\"content\":\"Status: Approved\"}}"

# ---------------------------------------------------------------------------
# Scenario 6: Second Approval guard — Write adding Second Approval: Approved (deny — exit 2)
# ---------------------------------------------------------------------------
parity_check "second-approval-guard: Write adds Second Approval" \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"${TASKS_MD}\",\"content\":\"## T-001\\nApproval: Draft\\nSecond Approval: Approved\"}}"

# ---------------------------------------------------------------------------
# Scenario 7: Agent-role guard — write .toml without developer_instructions (deny — exit 2)
# ---------------------------------------------------------------------------
mkdir -p "${WORK}/.codex/agents"
parity_check "agent-role-guard: toml without developer_instructions" \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"${WORK}/.codex/agents/custom.toml\",\"content\":\"name = \\\"test\\\"\"}}"

# ---------------------------------------------------------------------------
# Scenario 8: Agent-role guard — write .toml WITH developer_instructions (allow — exit 0)
# ---------------------------------------------------------------------------
parity_check "agent-role-guard: toml with developer_instructions" \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"${WORK}/.codex/agents/custom.toml\",\"content\":\"developer_instructions = \\\"ok\\\"\"}}"

# ---------------------------------------------------------------------------
# Scenario 9: R-10 gate protect — write hook guard file (deny — exit 2)
# ---------------------------------------------------------------------------
parity_check "r10-gate-protect: write sdd-hook-guard.py" \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"plugins/sdd-quality-loop/scripts/sdd-hook-guard.py\",\"content\":\"x\"}}"

# ---------------------------------------------------------------------------
# Scenario 10: R-10 gate protect — write claude-hooks.json (deny — exit 2)
# ---------------------------------------------------------------------------
parity_check "r10-gate-protect: write claude-hooks.json" \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"plugins/sdd-quality-loop/hooks/claude-hooks.json\",\"content\":\"x\"}}"

# ---------------------------------------------------------------------------
# Scenario 11: SDD_SUDO protection — write SDD_SUDO file (deny — exit 2)
# ---------------------------------------------------------------------------
parity_check "sudo-protect: write SDD_SUDO" \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"${WORK}/SDD_SUDO\",\"content\":\"x\"}}"

# ---------------------------------------------------------------------------
# Scenario 12: Valid tool call (allow — exit 0)
# ---------------------------------------------------------------------------
parity_check "allow: write non-sensitive file" \
    '{"tool_name":"write","tool_input":{"file_path":"src/main.py","content":"print(1)"}}'

# ---------------------------------------------------------------------------
# Scenario 13: apply_patch approval guard (deny — exit 2)
# Codex-format patch that adds Approval: Approved to tasks.md must be denied.
# ---------------------------------------------------------------------------
PATCH_PAYLOAD='{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Update File: tasks.md\n+Approval: Approved\n*** End Patch"}}'
parity_check "approval-guard: apply_patch adds Approval" "$PATCH_PAYLOAD"

# ---------------------------------------------------------------------------
# Scenario 14: multiedit approval guard (deny — exit 2)
# An edits[] array with new_string containing full "Approval: Approved" must be denied.
# ---------------------------------------------------------------------------
parity_check "approval-guard: multiedit edits adds Approval: Approved" \
    "{\"tool_name\":\"multiedit\",\"tool_input\":{\"file_path\":\"${TASKS_MD}\",\"edits\":[{\"old_string\":\"Approval: Draft\",\"new_string\":\"Approval: Approved\"}]}}"

# ---------------------------------------------------------------------------
# Scenario 15: bash command approval guard (deny — exit 2)
# Bash command echoing Approval: Approved into tasks.md must be denied.
# ---------------------------------------------------------------------------
parity_check "approval-guard: bash echo Approval to tasks.md" \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"echo 'Approval: Approved' >> ${TASKS_MD}\"}}"

# ---------------------------------------------------------------------------
# Scenario 16: sudo-active approval bypass (allow — exit 0)
# With a valid SDD_SUDO token, an approval increase SHOULD be allowed.
# Token is generated with the test key and written directly (not via the guard).
# ---------------------------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
    REAL_WORK=$(python3 -c "import os; print(os.path.realpath('${WORK}'))")
    python3 - "${REAL_WORK}" >"${WORK}/SDD_SUDO" <<'PYEOF'
import hmac, hashlib, time, sys

key = b"parity-test-key-do-not-use"
repo = sys.argv[1]
now = int(time.time())
expires = now + 3600
nonce = "deadbeef" * 8  # 64 hex chars
issuer = "sdd-forge-test"
issued_str = str(now)
expires_str = str(expires)
canonical = "\n".join([issuer, nonce, repo, issued_str, expires_str])
sig = hmac.new(key, canonical.encode("utf-8"), hashlib.sha256).hexdigest()
print(f"issuer: {issuer}\nnonce: {nonce}\nrepo: {repo}\nissued-epoch: {issued_str}\nexpires-epoch: {expires_str}\nsig: {sig}", end="")
PYEOF
    parity_check "sudo-active: approval bypass allowed" \
        "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"${TASKS_MD}\",\"content\":\"## T-001\\nApproval: Approved\"}}"
    rm -f "${WORK}/SDD_SUDO"
else
    echo "ok: parity [sudo-active: approval bypass allowed] SKIP (no python3)"
    PASS=$((PASS+1))
fi

# ---------------------------------------------------------------------------
# Scenario 17: compound shell bypass denied (deny — exit 2)
# `cat file && rm file` previously bypassed the read-only short-circuit.
# After the compound-command fix, this must be denied by both runtimes.
# ---------------------------------------------------------------------------
parity_check "r10-gate-protect: compound cat+rm on guard file denied" \
    '{"tool_name":"bash","tool_input":{"command":"cat plugins/sdd-quality-loop/scripts/sdd-hook-guard.py && rm plugins/sdd-quality-loop/scripts/sdd-hook-guard.py"}}'

# ---------------------------------------------------------------------------
# Scenario 18: heredoc redirect overwrite denied (deny — exit 2)
# `cat > protected_file << EOF` starts with a read-only verb but writes to the
# protected file via redirect. Must be denied even without compound operators.
# ---------------------------------------------------------------------------
parity_check "r10-gate-protect: cat heredoc redirect to guard file denied" \
    '{"tool_name":"bash","tool_input":{"command":"cat > plugins/sdd-quality-loop/scripts/sdd-hook-guard.py << EOF\nmalicious content\nEOF"}}'

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "guard-parity.tests.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
