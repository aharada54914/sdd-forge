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
# Helper: run payload through both guards, assert same exit code AND expected.
# Usage: parity_check "scenario name" <expected_exit_code> <payload_json>
# ---------------------------------------------------------------------------
parity_check() {
    local scenario="$1"
    local expected="$2"
    local payload="$3"
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

    if [ "$js_code" != "$py_code" ]; then
        fail "parity [$scenario]: JS=$js_code PY=$py_code — DIVERGENCE (expected $expected)"
    elif [ "$js_code" != "$expected" ]; then
        fail "parity [$scenario]: both exit $js_code but expected $expected"
    else
        ok "parity [$scenario]: both exit $js_code (expected)"
    fi
}

# Helper: same as parity_check but runs guards from a given CWD.
# Required for checks that resolve reports/ relative to CWD (ADR-004).
# Usage: parity_check_in <cwd> "scenario name" <expected_exit_code> <payload_json>
# ---------------------------------------------------------------------------
parity_check_in() {
    local cwd="$1"
    local scenario="$2"
    local expected="$3"
    local payload="$4"
    local js_code=0
    local py_code=0

    printf '%s' "$payload" \
        | (cd "$cwd" && CLAUDE_PROJECT_DIR="$cwd" node "${SCRIPTS_DIR}/sdd-hook-guard.js" --emit exit) \
        >/dev/null 2>&1 || js_code=$?

    printf '%s' "$payload" \
        | (cd "$cwd" && CLAUDE_PROJECT_DIR="$cwd" python3 "${SCRIPTS_DIR}/sdd-hook-guard.py" --emit exit) \
        >/dev/null 2>&1 || py_code=$?

    if [ "$js_code" != "$py_code" ]; then
        fail "parity [$scenario]: JS=$js_code PY=$py_code — DIVERGENCE (expected $expected)"
    elif [ "$js_code" != "$expected" ]; then
        fail "parity [$scenario]: both exit $js_code but expected $expected"
    else
        ok "parity [$scenario]: both exit $js_code (expected)"
    fi
}

# Helper: run guards from <cwd> while pointing CLAUDE_PROJECT_DIR at a DIFFERENT
# <proj> root. WFI-016: the agent's CWD is outside the repository but the repo
# root (with the verdict) is supplied via CLAUDE_PROJECT_DIR.
# Usage: parity_check_cwd_env <cwd> <proj> "scenario" <expected> <payload_json>
# ---------------------------------------------------------------------------
parity_check_cwd_env() {
    local cwd="$1"
    local proj="$2"
    local scenario="$3"
    local expected="$4"
    local payload="$5"
    local js_code=0
    local py_code=0

    printf '%s' "$payload" \
        | (cd "$cwd" && CLAUDE_PROJECT_DIR="$proj" node "${SCRIPTS_DIR}/sdd-hook-guard.js" --emit exit) \
        >/dev/null 2>&1 || js_code=$?

    printf '%s' "$payload" \
        | (cd "$cwd" && CLAUDE_PROJECT_DIR="$proj" python3 "${SCRIPTS_DIR}/sdd-hook-guard.py" --emit exit) \
        >/dev/null 2>&1 || py_code=$?

    if [ "$js_code" != "$py_code" ]; then
        fail "parity [$scenario]: JS=$js_code PY=$py_code — DIVERGENCE (expected $expected)"
    elif [ "$js_code" != "$expected" ]; then
        fail "parity [$scenario]: both exit $js_code but expected $expected"
    else
        ok "parity [$scenario]: both exit $js_code (expected)"
    fi
}

# Helper: run guards from <cwd> with CLAUDE_PROJECT_DIR UNSET. WFI-016: repo-root
# resolution falls to the git root walked up from the edited file_path (which
# must be an absolute path in the payload).
# Usage: parity_check_cwd_noenv <cwd> "scenario" <expected> <payload_json>
# ---------------------------------------------------------------------------
parity_check_cwd_noenv() {
    local cwd="$1"
    local scenario="$2"
    local expected="$3"
    local payload="$4"
    local js_code=0
    local py_code=0

    printf '%s' "$payload" \
        | (cd "$cwd" && env -u CLAUDE_PROJECT_DIR node "${SCRIPTS_DIR}/sdd-hook-guard.js" --emit exit) \
        >/dev/null 2>&1 || js_code=$?

    printf '%s' "$payload" \
        | (cd "$cwd" && env -u CLAUDE_PROJECT_DIR python3 "${SCRIPTS_DIR}/sdd-hook-guard.py" --emit exit) \
        >/dev/null 2>&1 || py_code=$?

    if [ "$js_code" != "$py_code" ]; then
        fail "parity [$scenario]: JS=$js_code PY=$py_code — DIVERGENCE (expected $expected)"
    elif [ "$js_code" != "$expected" ]; then
        fail "parity [$scenario]: both exit $js_code but expected $expected"
    else
        ok "parity [$scenario]: both exit $js_code (expected)"
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
parity_check "kill-switch: AGENT_STOP exists" 2 \
    '{"tool_name":"write","tool_input":{"file_path":"README.md","content":"x"}}'
rm -f "${WORK}/AGENT_STOP"

# ---------------------------------------------------------------------------
# Scenario 2: kill switch not tripped (allow — exit 0)
# ---------------------------------------------------------------------------
parity_check "kill-switch: no AGENT_STOP" 0 \
    '{"tool_name":"write","tool_input":{"file_path":"README.md","content":"x"}}'

# ---------------------------------------------------------------------------
# Scenario 3: approval guard — Write adding Approval: Approved (deny — exit 2)
# ---------------------------------------------------------------------------
parity_check "approval-guard: Write adds Approval" 2 \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"${TASKS_MD}\",\"content\":\"## T-001\\nApproval: Approved\"}}"

# ---------------------------------------------------------------------------
# Scenario 4: approval guard — Edit adding Approval: Approved (deny — exit 2)
# ---------------------------------------------------------------------------
parity_check "approval-guard: Edit adds Approval" 2 \
    "{\"tool_name\":\"edit\",\"tool_input\":{\"file_path\":\"${TASKS_MD}\",\"old_string\":\"Approval: Draft\",\"new_string\":\"Approval: Approved\"}}"

# ---------------------------------------------------------------------------
# Scenario 5: WFI guard — write Status: Approved in WFI path (deny — exit 2)
# ---------------------------------------------------------------------------
mkdir -p "${WORK}/docs/workflow-improvements"
WFI_FILE="${WORK}/docs/workflow-improvements/WFI-001.md"
printf 'Status: Draft\n' > "$WFI_FILE"
parity_check "wfi-guard: write Status: Approved" 2 \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"${WFI_FILE}\",\"content\":\"Status: Approved\"}}"

# ---------------------------------------------------------------------------
# Scenario 5b (WFI-022): the three reproduced false positives become allowed,
# and three operations that could grant (or hide a grant of) an approval stay
# refused. The three allowed cases replay the 2026-08-04 refusals recorded in
# WFI-022's Problem Evidence.
# ---------------------------------------------------------------------------
# (1) Prose-quoting edit: the edit's new text names the field mid-sentence
# but adds no column-0 field line. Previously refused (Edit path looked only
# at new_string with an unanchored matcher).
parity_check "wfi-022: prose-quoting edit allowed" 0 \
    "{\"tool_name\":\"edit\",\"tool_input\":{\"file_path\":\"${WFI_FILE}\",\"old_string\":\"Pending\",\"new_string\":\"The guard denies any edit that sets \`Status: Approved\` in a WFI file.\"}}"

# (2) Read-only listing: grep across WFI files quoting the field. No write
# verb, no redirect, no compound operator. Previously refused (Bash path was
# a substring test blind to read-vs-write).
parity_check "wfi-022: read-only grep allowed" 0 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"grep -H 'Status: Approved' ${WORK}/docs/workflow-improvements/WFI-001.md\"}}"

# (3) Creating a WFI document whose prose quotes the field (no column-0 field
# line). Previously refused — WFI-022.md itself could only be created in
# split form.
parity_check "wfi-022: create doc quoting field in prose allowed" 0 \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"${WORK}/docs/workflow-improvements/WFI-099.md\",\"content\":\"# WFI\\n\\nThe guard refuses any operation that sets \`Status: Approved\` in this file.\\n\"}}"

# (4) The approval-removing sed stays refused BY DESIGN: it is write-capable,
# and whether shell text nets out to a removal is not decidable, so the broad
# match is kept. Paired with the allowed Edit-path equivalent of the same
# transition below.
parity_check "wfi-022: approval-removing sed still refused" 2 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"sed -i '' 's/Status: Approved/Status: Applied/' ${WORK}/docs/workflow-improvements/WFI-001.md\"}}"

# The supported route for that transition: an Edit that REMOVES the field
# (old_string has it at column 0, new_string does not) is a net decrease.
parity_check "wfi-022: status-advance via Edit path allowed" 0 \
    "{\"tool_name\":\"edit\",\"tool_input\":{\"file_path\":\"${WFI_FILE}\",\"old_string\":\"Status: Approved\",\"new_string\":\"Status: Applied\"}}"

# An edit that PRESERVES the field (both sides carry it) is not a grant.
parity_check "wfi-022: field-preserving edit allowed" 0 \
    "{\"tool_name\":\"edit\",\"tool_input\":{\"file_path\":\"${WFI_FILE}\",\"old_string\":\"Status: Approved\\nold prose\",\"new_string\":\"Status: Approved\\nnew prose\"}}"

# (5) Real bypass, kept refused: a Write whose content carries the column-0
# field line inside a larger document (the anchored matcher must still count
# it; scenario 5 above covers the field as the whole content).
parity_check "wfi-022: write with embedded column-0 field still refused" 2 \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"${WFI_FILE}\",\"content\":\"# WFI\\n\\nStatus: Approved\\n\\nprose\\n\"}}"

# An Edit whose new_string ADDS a column-0 field line stays refused (net
# increase — new 1 > old 0), even though the surrounding text is prose.
parity_check "wfi-022: edit adding column-0 field still refused" 2 \
    "{\"tool_name\":\"edit\",\"tool_input\":{\"file_path\":\"${WFI_FILE}\",\"old_string\":\"Pending\",\"new_string\":\"prose\\nStatus: Approved\\nprose\"}}"

# (6) Real bypass, kept refused: an append via a shell redirect. The field
# literal sits inside quotes mid-line, which is why the Bash path keeps the
# unanchored match; echo is not a read-only verb and >> is a write token.
parity_check "wfi-022: redirect append still refused" 2 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"echo 'Status: Approved' >> ${WORK}/docs/workflow-improvements/WFI-001.md\"}}"

# A compound command is never exempt even when it starts read-only.
parity_check "wfi-022: compound read-then-write still refused" 2 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"grep -l 'Status: Approved' ${WORK}/docs/workflow-improvements/WFI-001.md && rm ${WORK}/docs/workflow-improvements/WFI-001.md\"}}"

# (7, WFI-022 amendment — external review PR #336) Syntax that can EXECUTE a
# further command disqualifies the read-only exemption: the embedded command
# is invisible to the write vocabulary, so a reader-shaped outer verb can
# smuggle an unmodeled writer. All four forms stay refused.
parity_check "wfi-022: command substitution not exempt" 2 \
    '{"tool_name":"bash","tool_input":{"command":"cat \"$(tar -xf /tmp/approved.tar -C .)\" docs/workflow-improvements/WFI-999.md Status: Approved"}}'
parity_check "wfi-022: backtick substitution not exempt" 2 \
    '{"tool_name":"bash","tool_input":{"command":"cat `tar -xf /tmp/approved.tar -C .` docs/workflow-improvements/WFI-999.md Status: Approved"}}'
parity_check "wfi-022: newline-joined second command not exempt" 2 \
    '{"tool_name":"bash","tool_input":{"command":"grep -H Status: Approved docs/workflow-improvements/WFI-001.md\ntar -xf /tmp/approved.tar -C ."}}'
parity_check "wfi-022: backgrounded second command not exempt" 2 \
    '{"tool_name":"bash","tool_input":{"command":"cat docs/workflow-improvements/WFI-001.md Status: Approved & tar -xf /tmp/approved.tar -C ."}}'

# ---------------------------------------------------------------------------
# Scenario 6: Second Approval guard — Write adding Second Approval: Approved (deny — exit 2)
# ---------------------------------------------------------------------------
parity_check "second-approval-guard: Write adds Second Approval" 2 \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"${TASKS_MD}\",\"content\":\"## T-001\\nApproval: Draft\\nSecond Approval: Approved\"}}"

# ---------------------------------------------------------------------------
# Scenario 7: Agent-role guard — write .toml without developer_instructions (deny — exit 2)
# ---------------------------------------------------------------------------
mkdir -p "${WORK}/.codex/agents"
parity_check "agent-role-guard: toml without developer_instructions" 2 \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"${WORK}/.codex/agents/custom.toml\",\"content\":\"name = \\\"test\\\"\"}}"

# ---------------------------------------------------------------------------
# Scenario 8: Agent-role guard — write .toml WITH developer_instructions (allow — exit 0)
# ---------------------------------------------------------------------------
parity_check "agent-role-guard: toml with developer_instructions" 0 \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"${WORK}/.codex/agents/custom.toml\",\"content\":\"developer_instructions = \\\"ok\\\"\"}}"

# ---------------------------------------------------------------------------
# Scenario 9: R-10 gate protect — write hook guard file (deny — exit 2)
# ---------------------------------------------------------------------------
parity_check "r10-gate-protect: write sdd-hook-guard.py" 2 \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"plugins/sdd-quality-loop/scripts/sdd-hook-guard.py\",\"content\":\"x\"}}"

# ---------------------------------------------------------------------------
# Scenario 10: R-10 gate protect — write claude-hooks.json (deny — exit 2)
# ---------------------------------------------------------------------------
parity_check "r10-gate-protect: write claude-hooks.json" 2 \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"plugins/sdd-quality-loop/hooks/claude-hooks.json\",\"content\":\"x\"}}"

# ---------------------------------------------------------------------------
# Scenario 11: SDD_SUDO protection — write SDD_SUDO file (deny — exit 2)
# ---------------------------------------------------------------------------
parity_check "sudo-protect: write SDD_SUDO" 2 \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"${WORK}/SDD_SUDO\",\"content\":\"x\"}}"

# ---------------------------------------------------------------------------
# Scenario 12: Valid tool call (allow — exit 0)
# ---------------------------------------------------------------------------
parity_check "allow: write non-sensitive file" 0 \
    '{"tool_name":"write","tool_input":{"file_path":"src/main.py","content":"print(1)"}}'

# ---------------------------------------------------------------------------
# Scenario 13: apply_patch approval guard (deny — exit 2)
# Codex-format patch that adds Approval: Approved to tasks.md must be denied.
# ---------------------------------------------------------------------------
PATCH_PAYLOAD='{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Update File: tasks.md\n+Approval: Approved\n*** End Patch"}}'
parity_check "approval-guard: apply_patch adds Approval" 2 "$PATCH_PAYLOAD"

# ---------------------------------------------------------------------------
# Scenario 14: multiedit approval guard (deny — exit 2)
# An edits[] array with new_string containing full "Approval: Approved" must be denied.
# ---------------------------------------------------------------------------
parity_check "approval-guard: multiedit edits adds Approval: Approved" 2 \
    "{\"tool_name\":\"multiedit\",\"tool_input\":{\"file_path\":\"${TASKS_MD}\",\"edits\":[{\"old_string\":\"Approval: Draft\",\"new_string\":\"Approval: Approved\"}]}}"

# ---------------------------------------------------------------------------
# Scenario 15: bash command approval guard (deny — exit 2)
# Bash command echoing Approval: Approved into tasks.md must be denied.
# ---------------------------------------------------------------------------
parity_check "approval-guard: bash echo Approval to tasks.md" 2 \
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
    parity_check "sudo-active: approval bypass allowed" 0 \
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
parity_check "r10-gate-protect: compound cat+rm on guard file denied" 2 \
    '{"tool_name":"bash","tool_input":{"command":"cat plugins/sdd-quality-loop/scripts/sdd-hook-guard.py && rm plugins/sdd-quality-loop/scripts/sdd-hook-guard.py"}}'

# ---------------------------------------------------------------------------
# Scenario 18: heredoc redirect overwrite denied (deny — exit 2)
# `cat > protected_file << EOF` starts with a read-only verb but writes to the
# protected file via redirect. Must be denied even without compound operators.
# ---------------------------------------------------------------------------
parity_check "r10-gate-protect: cat heredoc redirect to guard file denied" 2 \
    '{"tool_name":"bash","tool_input":{"command":"cat > plugins/sdd-quality-loop/scripts/sdd-hook-guard.py << EOF\nmalicious content\nEOF"}}'

# ---------------------------------------------------------------------------
# Scenario 19: impl-review-status guard — deny Passed write without verdict (exit 2)
# Guards look for reports/impl-review/<feature>/ relative to CWD (ADR-004).
# feat-x has no verdict dir → guard must deny.
# ---------------------------------------------------------------------------
mkdir -p "${WORK}/specs/feat-x"
touch "${WORK}/specs/feat-x/design.md"
IMPL_STATUS_PAYLOAD='{"tool_name":"write","tool_input":{"file_path":"specs/feat-x/design.md","content":"Impl-Review-Status: Passed\n"}}'

parity_check_in "$WORK" "impl-review-status: write Passed without verdict" 2 \
    "$IMPL_STATUS_PAYLOAD"

# ---------------------------------------------------------------------------
# Scenario 20: impl-review-status guard — allow Passed write with PASS verdict (exit 0)
# ⚠️ guards resolve reports/ relative to CWD — parity_check_in sets cd "$WORK".
# ---------------------------------------------------------------------------
mkdir -p "${WORK}/reports/impl-review/feat-x/attempt-1/round-1"
printf '{"verdict":"PASS"}' \
    > "${WORK}/reports/impl-review/feat-x/attempt-1/round-1/integrated-verdict.json"

parity_check_in "$WORK" "impl-review-status: write Passed with PASS verdict" 0 \
    "$IMPL_STATUS_PAYLOAD"

# ---------------------------------------------------------------------------
# Scenario 21: impl-review-status guard — deny Passed write with FAIL verdict (exit 2)
# ---------------------------------------------------------------------------
printf '{"verdict":"FAIL"}' \
    > "${WORK}/reports/impl-review/feat-x/attempt-1/round-1/integrated-verdict.json"

parity_check_in "$WORK" "impl-review-status: write Passed with FAIL verdict" 2 \
    "$IMPL_STATUS_PAYLOAD"

# ---------------------------------------------------------------------------
# Scenario 22: impl-review-status guard — allow Passed write with PASS-with-warnings (exit 0)
# ---------------------------------------------------------------------------
printf '{"verdict":"PASS-with-warnings"}' \
    > "${WORK}/reports/impl-review/feat-x/attempt-1/round-1/integrated-verdict.json"

parity_check_in "$WORK" "impl-review-status: write Passed with PASS-with-warnings verdict" 0 \
    "$IMPL_STATUS_PAYLOAD"

# ---------------------------------------------------------------------------
# Scenario 23: R-10 read-only cp FROM guard file allowed (allow — exit 0)
# Issue #62: the protected file is the cp SOURCE; the write target is /tmp.
# ---------------------------------------------------------------------------
parity_check "r10-gate-protect: cp guard file to /tmp allowed" 0 \
    '{"tool_name":"bash","tool_input":{"command":"cp plugins/sdd-quality-loop/scripts/sdd-hook-guard.py /tmp/guard-backup.py"}}'

# ---------------------------------------------------------------------------
# Scenario 24: R-10 unrelated mv + read of protected file allowed (allow — exit 0)
# Issue #62: mv writes /tmp/b; the protected path is only read by grep.
# ---------------------------------------------------------------------------
parity_check "r10-gate-protect: mv in /tmp + grep settings allowed" 0 \
    '{"tool_name":"bash","tool_input":{"command":"mv /tmp/a /tmp/b && grep foo .claude/settings.json"}}'

# ---------------------------------------------------------------------------
# Scenario 25: R-10 unrelated redirect + cat of protected file allowed (allow — exit 0)
# Issue #62: the > redirect targets /tmp/log, not the protected file.
# ---------------------------------------------------------------------------
parity_check "r10-gate-protect: redirect to /tmp + cat settings allowed" 0 \
    '{"tool_name":"bash","tool_input":{"command":"echo done > /tmp/log; cat .claude/settings.local.json"}}'

# ---------------------------------------------------------------------------
# Scenario 26: R-10 grep of guard file with 2>/dev/null allowed (allow — exit 0)
# Issue #62: the only redirect is stderr to /dev/null; the guard file is read.
# ---------------------------------------------------------------------------
parity_check "r10-gate-protect: grep guard file with stderr redirect allowed" 0 \
    '{"tool_name":"bash","tool_input":{"command":"grep -n R-10 plugins/sdd-quality-loop/scripts/sdd-hook-guard.py 2>/dev/null | head -30"}}'

# ---------------------------------------------------------------------------
# Scenario 27: R-10 redirect INTO guard file denied (deny — exit 2)
# ---------------------------------------------------------------------------
parity_check "r10-gate-protect: echo redirect into guard file denied" 2 \
    '{"tool_name":"bash","tool_input":{"command":"echo x > plugins/sdd-quality-loop/scripts/sdd-hook-guard.py"}}'

# ---------------------------------------------------------------------------
# Scenario 28: R-10 cp ONTO guard file denied (deny — exit 2)
# The protected file is the cp DESTINATION (final argument).
# ---------------------------------------------------------------------------
parity_check "r10-gate-protect: cp onto guard file denied" 2 \
    '{"tool_name":"bash","tool_input":{"command":"cp /tmp/x plugins/sdd-quality-loop/scripts/sdd-hook-guard.py"}}'

# ---------------------------------------------------------------------------
# Scenario 29: R-10 unresolvable write target fails closed (deny — exit 2)
# $DST may expand to the protected path mentioned in the command — deny.
# ---------------------------------------------------------------------------
parity_check "r10-gate-protect: variable write target fails closed" 2 \
    '{"tool_name":"bash","tool_input":{"command":"DST=plugins/sdd-quality-loop/scripts/sdd-hook-guard.py; cp /tmp/x $DST"}}'

# ---------------------------------------------------------------------------
# T-006: domain-model approval guard (sdd-domain plugin)
#
# Mirrors the tasks.md Approval guard's net-increase counting logic EXACTLY
# (same sudo-bypass behavior) -- this is explicitly NOT the never-sudo-
# bypassable WFI/Second-Approval pattern. Field: "Domain-Model-Status:
# Approved". Gated path: domain/context-map.md only.
# ---------------------------------------------------------------------------
mkdir -p "${WORK}/domain"
CONTEXT_MAP="${WORK}/domain/context-map.md"
printf 'Domain-Model-Status: Pending\n' > "$CONTEXT_MAP"

# ---------------------------------------------------------------------------
# Scenario 30: domain-model guard — Write sets Domain-Model-Status: Approved
# (deny — exit 2). Agent-authored write with no sudo token active.
# ---------------------------------------------------------------------------
parity_check "domain-model-guard: Write sets Domain-Model-Status: Approved" 2 \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"${CONTEXT_MAP}\",\"content\":\"Domain-Model-Status: Approved\"}}"

# ---------------------------------------------------------------------------
# Scenario 31: domain-model guard — Edit sets Domain-Model-Status: Approved
# (deny — exit 2).
# ---------------------------------------------------------------------------
parity_check "domain-model-guard: Edit sets Domain-Model-Status: Approved" 2 \
    "{\"tool_name\":\"edit\",\"tool_input\":{\"file_path\":\"${CONTEXT_MAP}\",\"old_string\":\"Domain-Model-Status: Pending\",\"new_string\":\"Domain-Model-Status: Approved\"}}"

# ---------------------------------------------------------------------------
# Scenario 32: domain-model guard — apply_patch sets Domain-Model-Status:
# Approved (deny — exit 2).
# ---------------------------------------------------------------------------
DOMAIN_PATCH_PAYLOAD='{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Update File: domain/context-map.md\n-Domain-Model-Status: Pending\n+Domain-Model-Status: Approved\n*** End Patch"}}'
parity_check "domain-model-guard: apply_patch sets Domain-Model-Status: Approved" 2 "$DOMAIN_PATCH_PAYLOAD"

# ---------------------------------------------------------------------------
# Scenario 33: domain-model guard — bash command echoing the approved status
# into context-map.md (deny — exit 2).
# ---------------------------------------------------------------------------
parity_check "domain-model-guard: bash echo Domain-Model-Status: Approved to context-map.md" 2 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"echo 'Domain-Model-Status: Approved' >> ${CONTEXT_MAP}\"}}"

# ---------------------------------------------------------------------------
# Scenario 34: domain-model guard — a valid SDD_SUDO token PERMITS the same
# write (allow — exit 0). This is the key distinction from the WFI/Second-
# Approval guards: the domain-model guard is sudo-bypassable, same class as
# the tasks.md Approval guard (Scenario 16 above).
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
    parity_check "domain-model-guard: sudo-active bypass allowed" 0 \
        "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"${CONTEXT_MAP}\",\"content\":\"Domain-Model-Status: Approved\"}}"
    rm -f "${WORK}/SDD_SUDO"
else
    echo "ok: parity [domain-model-guard: sudo-active bypass allowed] SKIP (no python3)"
    PASS=$((PASS+1))
fi

# ---------------------------------------------------------------------------
# Scenario 35: domain-model guard path precision — a DIFFERENT domain/ file
# (not context-map.md) carrying the same marker text must NOT be denied by
# this guard. The path gate is exact to domain/context-map.md.
# ---------------------------------------------------------------------------
parity_check "domain-model-guard: non-context-map domain/ file unaffected" 0 \
    "{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"${WORK}/domain/aggregate-order.md\",\"content\":\"Domain-Model-Status: Approved\"}}"

# ---------------------------------------------------------------------------
# Scenario 36: domain-model guard — a status change that is NOT to Approved
# (e.g. Pending -> Reviewed) must be allowed (exit 0). Only a net increase in
# the Approved marker is denied, matching the tasks.md guard's semantics.
# ---------------------------------------------------------------------------
parity_check "domain-model-guard: Pending to Reviewed transition allowed" 0 \
    "{\"tool_name\":\"edit\",\"tool_input\":{\"file_path\":\"${CONTEXT_MAP}\",\"old_string\":\"Domain-Model-Status: Pending\",\"new_string\":\"Domain-Model-Status: Reviewed\"}}"

# ---------------------------------------------------------------------------
# WFI-016: impl-review verdict resolution when CWD is OUTSIDE the repository.
# The pre-fix guards resolved reports/impl-review/ relative to CWD only, so a
# genuine PASS verdict was missed and the write was falsely denied (observed
# 2026-07-22, epic-191). The fix resolves the repo root like
# resolveProjectRoot: CLAUDE_PROJECT_DIR first, then the git root walked up
# from the edited file_path, then CWD. Verdict criterion unchanged.
# ---------------------------------------------------------------------------
WFI016_REPO="${WORK}/wfi016-repo"
WFI016_OUTSIDE="${WORK}/wfi016-outside"
mkdir -p "${WFI016_REPO}/.git"
mkdir -p "${WFI016_REPO}/specs/feat-y"
printf 'Impl-Review-Status: Pending\n' > "${WFI016_REPO}/specs/feat-y/design.md"
mkdir -p "${WFI016_REPO}/reports/impl-review/feat-y/attempt-1/round-1"
printf '{"verdict":"PASS"}' \
    > "${WFI016_REPO}/reports/impl-review/feat-y/attempt-1/round-1/integrated-verdict.json"
mkdir -p "${WFI016_OUTSIDE}"

WFI016_PAYLOAD="{\"tool_name\":\"write\",\"tool_input\":{\"file_path\":\"${WFI016_REPO}/specs/feat-y/design.md\",\"content\":\"Impl-Review-Status: Passed\\n\"}}"

# ---------------------------------------------------------------------------
# Scenario 37: CWD outside repo, repo supplied via CLAUDE_PROJECT_DIR, PASS
# verdict exists in the repo (allow — exit 0). Fails (exit 2) on pre-fix guards.
# ---------------------------------------------------------------------------
parity_check_cwd_env "$WFI016_OUTSIDE" "$WFI016_REPO" \
    "wfi016: outside CWD + CLAUDE_PROJECT_DIR + PASS verdict allowed" 0 \
    "$WFI016_PAYLOAD"

# ---------------------------------------------------------------------------
# Scenario 38: CWD outside repo, CLAUDE_PROJECT_DIR unset, repo root discovered
# by walking up from the absolute file_path (allow — exit 0).
# ---------------------------------------------------------------------------
parity_check_cwd_noenv "$WFI016_OUTSIDE" \
    "wfi016: outside CWD + file_path git-root walk + PASS verdict allowed" 0 \
    "$WFI016_PAYLOAD"

# ---------------------------------------------------------------------------
# Scenario 39: same outside-CWD setup but the verdict is FAIL — the write must
# still be denied (exit 2). Proves the fix widens WHERE the guard looks, not
# WHAT it accepts (non-decreasing gate).
# ---------------------------------------------------------------------------
printf '{"verdict":"FAIL"}' \
    > "${WFI016_REPO}/reports/impl-review/feat-y/attempt-1/round-1/integrated-verdict.json"

parity_check_cwd_env "$WFI016_OUTSIDE" "$WFI016_REPO" \
    "wfi016: outside CWD + FAIL verdict still denied" 2 \
    "$WFI016_PAYLOAD"

# ---------------------------------------------------------------------------
# WFI-040: the protected set must cover every script the chain executes
# ---------------------------------------------------------------------------
# The guard's denial message names a category ("gate scripts"); what it holds is
# a hand-maintained suffix list. Measured 2026-08-19, 31 scripts that CI, the
# suite runner or a SKILL invokes matched no protected suffix. Enumeration
# drifts silently, because a missing entry presents as "allowed" rather than as
# an error. This is the check that makes the next omission fail loudly.
wfi037_drift="$(cd "${REPO_ROOT}" && python3 - <<'PY'
import glob, importlib.util, os
spec = importlib.util.spec_from_file_location(
    "gi", "plugins/sdd-quality-loop/scripts/generated/guard_invariants.py")
gi = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gi)
protected = set(gi.PROTECTED_GATE_SUFFIXES) | {
    s.lstrip("/") for s in gi.PROTECTED_GATE_PLUGIN_JSON_SUFFIXES}
callers = ["tests/run-all.sh", "tests/run-all.ps1"]
callers += glob.glob("plugins/*/skills/*/SKILL.md")
callers += glob.glob(os.path.join(".github", "workflows", "*"))
blob = ""
for c in callers:
    if os.path.exists(c):
        with open(c, encoding="utf-8", errors="replace") as fh:
            blob += fh.read()
for path in sorted(glob.glob("plugins/*/scripts/*")):
    if not os.path.isfile(path):
        continue
    if any(path.endswith(s) for s in protected):
        continue
    if os.path.basename(path) in blob:
        print(path)
PY
)"
if [ -z "${wfi037_drift}" ]; then
    ok "wfi037: every chain-invoked script under plugins/*/scripts is protected"
else
    fail "wfi037: chain-invoked scripts are unprotected: $(echo "${wfi037_drift}" | tr '\n' ' ')"
fi

# ---------------------------------------------------------------------------
# WFI-040 item 2b: the generated modules must agree with their JSON source
# ---------------------------------------------------------------------------
# The guard reads the generated modules, not the JSON. An applied JSON change
# that was never regenerated leaves behaviour unchanged while every suite
# reports green -- observed once already. Regenerate into a throwaway copy and
# require the result to be byte-identical to what is committed.
wfi037_gen="${WORK}/regen"
mkdir -p "${wfi037_gen}/plugins/sdd-quality-loop"
cp -R "${REPO_ROOT}/plugins/sdd-quality-loop/scripts" "${wfi037_gen}/plugins/sdd-quality-loop/"
cp -R "${REPO_ROOT}/plugins/sdd-quality-loop/references" "${wfi037_gen}/plugins/sdd-quality-loop/"
if (cd "${wfi037_gen}/plugins/sdd-quality-loop/scripts" \
        && python3 generate-guard-invariants.py >/dev/null 2>&1); then
    wfi037_stale=""
    for wfi037_mod in guard_invariants.py guard-invariants.generated.js \
                      guard-invariants.generated.ps1 guard-invariants.generated.sh; do
        if ! cmp -s "${REPO_ROOT}/plugins/sdd-quality-loop/scripts/generated/${wfi037_mod}" \
                    "${wfi037_gen}/plugins/sdd-quality-loop/scripts/generated/${wfi037_mod}"; then
            wfi037_stale="${wfi037_stale} ${wfi037_mod}"
        fi
    done
    if [ -z "${wfi037_stale}" ]; then
        ok "wfi037: generated invariant modules match guard-invariants.json"
    else
        fail "wfi037: generated modules are stale (run generate-guard-invariants.py):${wfi037_stale}"
    fi
else
    fail "wfi037: generate-guard-invariants.py rejected the committed JSON"
fi

# ---------------------------------------------------------------------------
# WFI-040: write-vocabulary coverage, both directions
# ---------------------------------------------------------------------------
# Every payload aims at kill-switch.sh, a path the guard's own predicate treats
# as protected, so a permissive verdict cannot be blamed on the target. Group A
# is the non-vacuity control: the verbs the original vocabulary modelled, which
# must stay denied. Group B is what this WFI adds. Group D is the anti-Goodhart
# control -- coverage must not have been bought by denying reads.
wfi037_target="plugins/sdd-quality-loop/scripts/kill-switch.sh"
wfi037_payload() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"; }

for wfi037_case in \
    "cp src ${wfi037_target}" \
    "tee ${wfi037_target}" \
    "rm ${wfi037_target}"; do
    parity_check "wfi037 vocabulary A (modelled, deny): ${wfi037_case%% *}" 2 \
        "$(wfi037_payload "${wfi037_case}")"
done

for wfi037_case in \
    "git checkout -- ${wfi037_target}" \
    "git restore ${wfi037_target}" \
    "git reset --hard HEAD ${wfi037_target}" \
    "sed -i '' s/a/b/ ${wfi037_target}" \
    "install -m 755 src ${wfi037_target}" \
    "ln -sf src ${wfi037_target}" \
    "truncate -s 0 ${wfi037_target}" \
    "dd if=src of=${wfi037_target}" \
    "perl -pi -e s/a/b/ ${wfi037_target}"; do
    parity_check "wfi037 vocabulary B (widened, deny): ${wfi037_case%% *}" 2 \
        "$(wfi037_payload "${wfi037_case}")"
done

# Readers must survive. sed and git are in the fail-closed vocabulary, so these
# two cases are what proves the regex admits sed only in its -i form and git
# only on worktree-writing subcommands.
for wfi037_case in \
    "cat ${wfi037_target}" \
    "grep x ${wfi037_target}" \
    "sed -n 1,5p ${wfi037_target}" \
    "git log -- ${wfi037_target}"; do
    parity_check "wfi037 vocabulary D (reader, allow): ${wfi037_case%% *}" 0 \
        "$(wfi037_payload "${wfi037_case}")"
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "guard-parity.tests.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
