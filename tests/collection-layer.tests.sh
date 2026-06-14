#!/usr/bin/env bash
# collection-layer.tests.sh — offline tests for T-005 collection layer scripts
# Tests detect-panel graceful-degrade and runner presence/format.
# No real CLI invocations; no network access.
# Style: mirrors cross-model.tests.sh (ok/fail counters, mktemp, exits 1 on failure)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ============================================================================
# CL-001: detect-panel — no CLIs in PATH → exit 1, warning on stderr
# ============================================================================

echo "=== CL-001: detect-panel graceful degrade (no CLIs) ==="

# Run with a minimal PATH that has no codex/gemini/openai
DP_EXIT=0
DP_OUTPUT=""
DP_OUTPUT=$(PATH="/usr/bin:/bin" bash "${SCRIPTS_DIR}/detect-panel.sh" 2>&1) || DP_EXIT=$?

if [ "${DP_EXIT}" = "1" ]; then
    ok "CL-001a: no CLIs in PATH → exit 1 (graceful degrade, not crash)"
else
    fail "CL-001a: expected exit 1, got ${DP_EXIT}"
fi

if echo "${DP_OUTPUT}" | grep -qi "warning\|no non-anthropic\|not found"; then
    ok "CL-001b: warning message emitted to stderr"
else
    fail "CL-001b: expected warning message, got: ${DP_OUTPUT}"
fi

if echo "${DP_OUTPUT}" | grep -qi "codex\|gemini"; then
    ok "CL-001c: warning names missing CLIs"
else
    fail "CL-001c: warning should mention codex or gemini, got: ${DP_OUTPUT}"
fi

# ============================================================================
# CL-002: detect-panel --quiet — suppresses warning on no CLIs
# ============================================================================

echo "=== CL-002: detect-panel --quiet suppresses warning ==="

DP_EXIT=0
DP_OUTPUT=""
DP_OUTPUT=$(PATH="/usr/bin:/bin" bash "${SCRIPTS_DIR}/detect-panel.sh" --quiet 2>&1) || DP_EXIT=$?

if [ "${DP_EXIT}" = "1" ]; then
    ok "CL-002a: --quiet still exits 1 on no CLIs"
else
    fail "CL-002a: --quiet should still exit 1, got ${DP_EXIT}"
fi

if [ -z "${DP_OUTPUT}" ]; then
    ok "CL-002b: --quiet produces no output"
else
    fail "CL-002b: --quiet should produce no output, got: ${DP_OUTPUT}"
fi

# ============================================================================
# CL-003: detect-panel — stub codex in PATH → exit 0, 'gpt' slug emitted
# ============================================================================

echo "=== CL-003: detect-panel detects stub codex CLI ==="

# Create a stub codex that just exits 0
STUB_BIN="${WORK}/stub-bin"
mkdir -p "$STUB_BIN"
printf '#!/bin/sh\nexit 0\n' > "${STUB_BIN}/codex"
chmod +x "${STUB_BIN}/codex"

DP_EXIT=0
DP_OUTPUT=""
DP_OUTPUT=$(PATH="${STUB_BIN}:/usr/bin:/bin" bash "${SCRIPTS_DIR}/detect-panel.sh" 2>/dev/null) || DP_EXIT=$?

if [ "${DP_EXIT}" = "0" ]; then
    ok "CL-003a: codex stub in PATH → exit 0"
else
    fail "CL-003a: expected exit 0 with codex stub, got ${DP_EXIT}"
fi

if echo "${DP_OUTPUT}" | grep -q "^gpt$"; then
    ok "CL-003b: 'gpt' slug emitted"
else
    fail "CL-003b: expected 'gpt' slug, got: ${DP_OUTPUT}"
fi

# ============================================================================
# CL-004: detect-panel — stub gemini in PATH → exit 0, 'gemini' slug emitted
# ============================================================================

echo "=== CL-004: detect-panel detects stub gemini CLI ==="

STUB_BIN2="${WORK}/stub-bin2"
mkdir -p "$STUB_BIN2"
printf '#!/bin/sh\nexit 0\n' > "${STUB_BIN2}/gemini"
chmod +x "${STUB_BIN2}/gemini"

DP_EXIT=0
DP_OUTPUT=""
DP_OUTPUT=$(PATH="${STUB_BIN2}:/usr/bin:/bin" bash "${SCRIPTS_DIR}/detect-panel.sh" 2>/dev/null) || DP_EXIT=$?

if [ "${DP_EXIT}" = "0" ]; then
    ok "CL-004a: gemini stub in PATH → exit 0"
else
    fail "CL-004a: expected exit 0 with gemini stub, got ${DP_EXIT}"
fi

if echo "${DP_OUTPUT}" | grep -q "^gemini$"; then
    ok "CL-004b: 'gemini' slug emitted"
else
    fail "CL-004b: expected 'gemini' slug, got: ${DP_OUTPUT}"
fi

# ============================================================================
# CL-005: detect-panel — both stubs → exit 0, both slugs emitted
# ============================================================================

echo "=== CL-005: detect-panel detects both CLIs ==="

STUB_BIN3="${WORK}/stub-bin3"
mkdir -p "$STUB_BIN3"
printf '#!/bin/sh\nexit 0\n' > "${STUB_BIN3}/codex"
printf '#!/bin/sh\nexit 0\n' > "${STUB_BIN3}/gemini"
chmod +x "${STUB_BIN3}/codex" "${STUB_BIN3}/gemini"

DP_EXIT=0
DP_OUTPUT=""
DP_OUTPUT=$(PATH="${STUB_BIN3}:/usr/bin:/bin" bash "${SCRIPTS_DIR}/detect-panel.sh" 2>/dev/null) || DP_EXIT=$?

if [ "${DP_EXIT}" = "0" ]; then
    ok "CL-005a: both stubs in PATH → exit 0"
else
    fail "CL-005a: expected exit 0, got ${DP_EXIT}"
fi

if echo "${DP_OUTPUT}" | grep -q "^gpt$" && echo "${DP_OUTPUT}" | grep -q "^gemini$"; then
    ok "CL-005b: both 'gpt' and 'gemini' slugs emitted"
else
    fail "CL-005b: expected both slugs, got: ${DP_OUTPUT}"
fi

# ============================================================================
# CL-006: detect-panel — bad argument → exit 2
# ============================================================================

echo "=== CL-006: detect-panel rejects unknown argument ==="

DP_EXIT=0
DP_OUTPUT=""
DP_OUTPUT=$(bash "${SCRIPTS_DIR}/detect-panel.sh" --bogus 2>&1) || DP_EXIT=$?

if [ "${DP_EXIT}" = "2" ]; then
    ok "CL-006: unknown arg → exit 2"
else
    fail "CL-006: expected exit 2 for unknown arg, got ${DP_EXIT}"
fi

# ============================================================================
# CL-007: runner scripts are present and executable
# ============================================================================

echo "=== CL-007: runner scripts present ==="

for script in \
    detect-panel.sh detect-panel.ps1 \
    run-panelist-gpt.sh run-panelist-gpt.ps1 \
    run-panelist-gemini.sh run-panelist-gemini.ps1; do
    path="${SCRIPTS_DIR}/${script}"
    if [ -f "$path" ]; then
        ok "CL-007: ${script} present"
    else
        fail "CL-007: ${script} MISSING at ${path}"
    fi
done

# ============================================================================
# CL-008: runner — absent CLI → exit 1 (graceful degrade, not exit 2)
# ============================================================================

echo "=== CL-008: run-panelist-gpt graceful degrade (no codex) ==="

mkdir -p "${WORK}/cl008/specs/feat/verification"
printf '# Panelist Input Bundle\n# task_id: T-005\n# feature: feat\n# input_digest: %s\n# consent: human-flag\n\ntest\n' \
    "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" \
    > "${WORK}/cl008/input.txt"

RUN_EXIT=0
RUN_OUTPUT=""
RUN_OUTPUT=$(PATH="/usr/bin:/bin" bash "${SCRIPTS_DIR}/run-panelist-gpt.sh" \
    --task T-005 --feature feat \
    --input "${WORK}/cl008/input.txt" \
    --spec-root "${WORK}/cl008/specs" 2>&1) || RUN_EXIT=$?

if [ "${RUN_EXIT}" = "1" ]; then
    ok "CL-008a: run-panelist-gpt no CLI → exit 1 (graceful degrade)"
else
    fail "CL-008a: expected exit 1 for absent codex, got ${RUN_EXIT}"
fi

if echo "${RUN_OUTPUT}" | grep -qi "not found\|graceful\|degrade\|codex"; then
    ok "CL-008b: run-panelist-gpt emits informative message"
else
    fail "CL-008b: expected informative message, got: ${RUN_OUTPUT}"
fi

# ============================================================================
# CL-009: run-panelist-gemini graceful degrade (no gemini CLI)
# ============================================================================

echo "=== CL-009: run-panelist-gemini graceful degrade (no gemini) ==="

mkdir -p "${WORK}/cl009/specs/feat/verification"
cp "${WORK}/cl008/input.txt" "${WORK}/cl009/input.txt"

RUN_EXIT=0
RUN_OUTPUT=""
RUN_OUTPUT=$(PATH="/usr/bin:/bin" bash "${SCRIPTS_DIR}/run-panelist-gemini.sh" \
    --task T-005 --feature feat \
    --input "${WORK}/cl009/input.txt" \
    --spec-root "${WORK}/cl009/specs" 2>&1) || RUN_EXIT=$?

if [ "${RUN_EXIT}" = "1" ]; then
    ok "CL-009a: run-panelist-gemini no CLI → exit 1 (graceful degrade)"
else
    fail "CL-009a: expected exit 1 for absent gemini, got ${RUN_EXIT}"
fi

if echo "${RUN_OUTPUT}" | grep -qi "not found\|graceful\|degrade\|gemini"; then
    ok "CL-009b: run-panelist-gemini emits informative message"
else
    fail "CL-009b: expected informative message, got: ${RUN_OUTPUT}"
fi

# ============================================================================
# CL-010: runner required arg validation → exit 2
# ============================================================================

echo "=== CL-010: runner required arg validation ==="

for runner in run-panelist-gpt.sh run-panelist-gemini.sh; do
    RUN_EXIT=0
    bash "${SCRIPTS_DIR}/${runner}" --feature feat --input /dev/null 2>/dev/null || RUN_EXIT=$?
    if [ "${RUN_EXIT}" = "2" ]; then
        ok "CL-010: ${runner} missing --task → exit 2"
    else
        fail "CL-010: ${runner} missing --task should exit 2, got ${RUN_EXIT}"
    fi
done

# ============================================================================
# CL-011: TOML agent files have developer_instructions
# ============================================================================

echo "=== CL-011: TOML agent files contain developer_instructions ==="

for toml in \
    "${REPO_ROOT}/.codex/agents/sdd-panelist-gpt.toml" \
    "${REPO_ROOT}/.codex/agents/sdd-panelist-gemini.toml"; do
    if [ ! -f "$toml" ]; then
        fail "CL-011: ${toml} not found"
        continue
    fi
    if grep -q "developer_instructions" "$toml"; then
        ok "CL-011: $(basename $toml) has developer_instructions"
    else
        fail "CL-011: $(basename $toml) missing developer_instructions"
    fi
done

# ============================================================================
# CL-012: SKILL.md present and has required frontmatter
# ============================================================================

echo "=== CL-012: SKILL.md present with required frontmatter ==="

SKILL="${REPO_ROOT}/plugins/sdd-quality-loop/skills/cross-model-verify/SKILL.md"
if [ -f "$SKILL" ]; then
    ok "CL-012a: SKILL.md present"
    if grep -q "name: cross-model-verify" "$SKILL"; then
        ok "CL-012b: SKILL.md has name frontmatter"
    else
        fail "CL-012b: SKILL.md missing name frontmatter"
    fi
    if grep -q "disable-model-invocation: true" "$SKILL"; then
        ok "CL-012c: SKILL.md has disable-model-invocation: true"
    else
        fail "CL-012c: SKILL.md missing disable-model-invocation: true"
    fi
    if grep -q "blind" "$SKILL" && grep -q "parallel" "$SKILL"; then
        ok "CL-012d: SKILL.md mentions blind and parallel"
    else
        fail "CL-012d: SKILL.md should document blind/parallel isolation"
    fi
else
    fail "CL-012a: SKILL.md not found at ${SKILL}"
fi

# ============================================================================
# CL-013: panelist agent .md files have disallowedTools
# ============================================================================

echo "=== CL-013: panelist agent .md files have disallowedTools ==="

for agent in \
    "${REPO_ROOT}/plugins/sdd-quality-loop/agents/panelist-gpt.md" \
    "${REPO_ROOT}/plugins/sdd-quality-loop/agents/panelist-gemini.md"; do
    if [ ! -f "$agent" ]; then
        fail "CL-013: $(basename $agent) not found"
        continue
    fi
    if grep -q "disallowedTools:.*Write" "$agent" || grep -q "disallowedTools: Write" "$agent"; then
        ok "CL-013: $(basename $agent) has disallowedTools with Write"
    else
        fail "CL-013: $(basename $agent) missing disallowedTools: Write"
    fi
done

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
    exit 1
fi
exit 0
