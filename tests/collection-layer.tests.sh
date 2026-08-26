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
    # WFI-054: cross-model-verify is a ship-delegated stage; its caller is the
    # model executing ship, so it must be model-invocable while staying out of
    # the user-facing menu (user-invocable: false). Both flags true+false made
    # it unreachable by anyone.
    if grep -q "disable-model-invocation: false" "$SKILL"; then
        ok "CL-012c: SKILL.md has disable-model-invocation: false (ship-delegated, WFI-054)"
    else
        fail "CL-012c: SKILL.md missing disable-model-invocation: false"
    fi
    if grep -q "user-invocable: false" "$SKILL"; then
        ok "CL-012c2: SKILL.md keeps user-invocable: false (not a menu entry)"
    else
        fail "CL-012c2: SKILL.md missing user-invocable: false"
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
# CL-014: run-panelist-gpt — CLI exits 0 but emits no parseable verdict JSON
# → exit non-zero, no verdict file written (invocation-fix hardening: this
# is the "silent success" regression class this suite must catch).
# ============================================================================

echo "=== CL-014: run-panelist-gpt unparseable-output hardening ==="

CL014_BIN="${WORK}/cl014-bin"
mkdir -p "${CL014_BIN}"
printf '#!/bin/sh\nprintf "usage: codex [OPTIONS]\\n"\nexit 0\n' > "${CL014_BIN}/codex"
chmod +x "${CL014_BIN}/codex"

mkdir -p "${WORK}/cl014/specs"
printf 'plain bundle content, no JSON here.\n' > "${WORK}/cl014/input.txt"

RUN_EXIT=0
RUN_OUTPUT=""
RUN_OUTPUT=$(PATH="${CL014_BIN}:/usr/bin:/bin" bash "${SCRIPTS_DIR}/run-panelist-gpt.sh" \
    --task T-014 --feature feat \
    --input "${WORK}/cl014/input.txt" \
    --spec-root "${WORK}/cl014/specs" \
    --digest "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" 2>&1) || RUN_EXIT=$?

if [ "${RUN_EXIT}" != "0" ]; then
    ok "CL-014a: codex CLI exits 0 with no parseable JSON → run-panelist-gpt still exits non-zero (got ${RUN_EXIT})"
else
    fail "CL-014a: expected non-zero exit when codex produces no parseable verdict, got 0 -- ${RUN_OUTPUT}"
fi

if echo "${RUN_OUTPUT}" | grep -qi "no json object found"; then
    ok "CL-014b: run-panelist-gpt names the parse failure in its diagnostic"
else
    fail "CL-014b: expected a parse-failure diagnostic, got: ${RUN_OUTPUT}"
fi

if [ ! -f "${WORK}/cl014/specs/feat/verification/T-014.panelist-openai.verdict.json" ]; then
    ok "CL-014c: no verdict file is written when the CLI output does not parse"
else
    fail "CL-014c: a verdict file was written despite unparseable CLI output"
fi

# ============================================================================
# CL-015: run-panelist-gemini — same unparseable-output hardening.
# ============================================================================

echo "=== CL-015: run-panelist-gemini unparseable-output hardening ==="

CL015_BIN="${WORK}/cl015-bin"
mkdir -p "${CL015_BIN}"
printf '#!/bin/sh\nprintf "No input provided via stdin.\\n"\nexit 0\n' > "${CL015_BIN}/gemini"
chmod +x "${CL015_BIN}/gemini"

mkdir -p "${WORK}/cl015/specs"
printf 'plain bundle content, no JSON here.\n' > "${WORK}/cl015/input.txt"

RUN_EXIT=0
RUN_OUTPUT=""
RUN_OUTPUT=$(PATH="${CL015_BIN}:/usr/bin:/bin" bash "${SCRIPTS_DIR}/run-panelist-gemini.sh" \
    --task T-015 --feature feat \
    --input "${WORK}/cl015/input.txt" \
    --spec-root "${WORK}/cl015/specs" \
    --digest "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" 2>&1) || RUN_EXIT=$?

if [ "${RUN_EXIT}" != "0" ]; then
    ok "CL-015a: gemini CLI exits 0 with no parseable JSON → run-panelist-gemini still exits non-zero (got ${RUN_EXIT})"
else
    fail "CL-015a: expected non-zero exit when gemini produces no parseable verdict, got 0 -- ${RUN_OUTPUT}"
fi

if [ ! -f "${WORK}/cl015/specs/feat/verification/T-015.panelist-google.verdict.json" ]; then
    ok "CL-015b: no verdict file is written when the CLI output does not parse"
else
    fail "CL-015b: a verdict file was written despite unparseable CLI output"
fi

# ============================================================================
# CL-016: run-panelist-gemini — argv/stdin contract: panelist instructions
# go through -p, the sanitized bundle goes on stdin (no duplication), per
# the installed gemini CLI's documented headless-mode contract.
# ============================================================================

echo "=== CL-016: run-panelist-gemini -p/stdin contract ==="

CL016_BIN="${WORK}/cl016-bin"
mkdir -p "${CL016_BIN}"
CL016_ARGV="${WORK}/cl016-argv.txt"
CL016_STDIN="${WORK}/cl016-stdin.txt"
ZERO_DIGEST_CL="$(printf '0%.0s' $(seq 1 64))"
cat > "${CL016_BIN}/gemini" <<STUBEOF
#!/bin/sh
printf '%s\n' "\$@" > "${CL016_ARGV}"
cat > "${CL016_STDIN}"
printf '%s\n' '{"schema":"cross-model-verdict/v1","task_id":"T-016","feature":"feat","vendor":"google","model":"stub","verdict":"PASS","findings":[],"blind":true,"input_digest":"${ZERO_DIGEST_CL}","consent":{"kind":"human-flag","ref":"stub"}}'
exit 0
STUBEOF
chmod +x "${CL016_BIN}/gemini"

mkdir -p "${WORK}/cl016/specs"
printf 'sanitized bundle body, no panelist instructions here.\n' > "${WORK}/cl016/input.txt"

PATH="${CL016_BIN}:/usr/bin:/bin" bash "${SCRIPTS_DIR}/run-panelist-gemini.sh" \
    --task T-016 --feature feat \
    --input "${WORK}/cl016/input.txt" \
    --spec-root "${WORK}/cl016/specs" \
    --digest "${ZERO_DIGEST_CL}" \
    --model gemini-2.0-flash >/dev/null 2>&1 || true

CL016_ARGV_FLAT="$(tr '\n' ' ' < "${CL016_ARGV}" 2>/dev/null | sed 's/[[:space:]]*$//')"
if [[ "${CL016_ARGV_FLAT}" == "--model gemini-2.0-flash -p "* ]] && \
   echo "${CL016_ARGV_FLAT}" | grep -q "READ-ONLY"; then
    ok "CL-016a: gemini argv is --model <m> -p <panelist-instructions> (instructions travel via -p, not stdin)"
else
    fail "CL-016a: gemini argv did not match the -p contract -- ${CL016_ARGV_FLAT}"
fi

if [ -f "${CL016_STDIN}" ] && grep -q "sanitized bundle body" "${CL016_STDIN}" \
   && ! grep -q "READ-ONLY" "${CL016_STDIN}"; then
    ok "CL-016b: stdin carries only the sanitized bundle (no duplicated panelist instructions)"
else
    fail "CL-016b: stdin content did not match the bundle-only contract -- $(cat "${CL016_STDIN}" 2>/dev/null | head -c 200)"
fi

# ============================================================================
# CL-017: detect-panel — CLI resolves via `command -v` but `--version` fails
# (e.g. broken auth) → not reported available (liveness probe, not just
# presence).
# ============================================================================

echo "=== CL-017: detect-panel liveness probe (--version must succeed) ==="

CL017_BIN="${WORK}/cl017-bin"
mkdir -p "${CL017_BIN}"
cat > "${CL017_BIN}/gemini" <<'STUBEOF'
#!/bin/sh
if [ "$1" = "--version" ]; then
    exit 1
fi
exit 0
STUBEOF
chmod +x "${CL017_BIN}/gemini"

DP_EXIT=0
DP_OUTPUT=""
DP_OUTPUT=$(PATH="${CL017_BIN}:/usr/bin:/bin" bash "${SCRIPTS_DIR}/detect-panel.sh" --quiet 2>&1) || DP_EXIT=$?

if ! echo "${DP_OUTPUT}" | grep -q "^gemini$"; then
    ok "CL-017: a gemini CLI present in PATH but failing --version is NOT reported available"
else
    fail "CL-017: detect-panel reported 'gemini' available despite --version failing -- ${DP_OUTPUT}"
fi

# ============================================================================
# CL-018: detect-panel — a `codex` resolving to a codex-sync-named target is
# never reported available, even though it answers exit 0/--version.
# ============================================================================

echo "=== CL-018: detect-panel codex-sync avoidance ==="

CL018_BIN="${WORK}/cl018-bin"
mkdir -p "${CL018_BIN}"
printf '#!/bin/sh\nexit 0\n' > "${CL018_BIN}/codex-sync"
chmod +x "${CL018_BIN}/codex-sync"
ln -s "${CL018_BIN}/codex-sync" "${CL018_BIN}/codex"

DP_EXIT=0
DP_OUTPUT=""
DP_OUTPUT=$(PATH="${CL018_BIN}:/usr/bin:/bin" bash "${SCRIPTS_DIR}/detect-panel.sh" --quiet 2>&1) || DP_EXIT=$?

if ! echo "${DP_OUTPUT}" | grep -q "^gpt$"; then
    ok "CL-018: a codex resolving to codex-sync is NOT reported as an available 'gpt' panelist"
else
    fail "CL-018: detect-panel reported 'gpt' available via a codex-sync-resolved codex -- ${DP_OUTPUT}"
fi

# ============================================================================
# CL-019: run-panelist-gpt -- `codex exec` echoes the whole prompt (including
# the JSON schema *example*, which is deliberately not valid JSON) before
# the real verdict. This is the actual bug reproduced verbatim: a greedy
# `\{[\s\S]*\}` regex spans from the example's `{` to the real verdict's
# final `}`, which fails to parse. Assert on the EXTRACTED CONTENT, not
# merely exit 0, so a revert to "first object wins" cannot pass silently.
# ============================================================================

echo "=== CL-019: run-panelist-gpt extracts the real verdict, not an echoed distractor ==="

CL019_BIN="${WORK}/cl019-bin"
mkdir -p "${CL019_BIN}"
cat > "${CL019_BIN}/codex" << 'STUBEOF'
#!/bin/sh
cat << 'TRANSCRIPT'
OpenAI Codex v0.147.0
--------
workdir: /tmp/scratch
model: gpt-5.6-sol
--------
user
## Output Format

Return ONLY a JSON object in this exact schema (no markdown, no prose):

{
  "schema": "cross-model-verdict/v1",
  "task_id": "<task_id>",
  "feature": "<feature>",
  "vendor": "openai",
  "model": "<model>",
  "verdict": "PASS" | "NEEDS_WORK",
  "findings": [
    { "severity": "Critical" | "Major" | "Minor", "ref": "<file:line or section>", "note": "<description>" }
  ],
  "blind": true,
  "input_digest": "<digest-from-bundle-header>",
  "consent": { "kind": "<consent-kind>", "ref": "<ref>" }
}

some other distractor object elsewhere in the echoed bundle: {"unrelated": true, "count": 2}

codex
{"schema":"cross-model-verdict/v1","task_id":"T-019","feature":"feat","vendor":"openai","model":"stub-model","verdict":"NEEDS_WORK","findings":[{"severity":"Major","ref":"x","note":"y"}],"blind":true,"input_digest":"a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2","consent":{"kind":"human-flag","ref":"stub"}}
hook: Stop
tokens used
193326
{"schema":"cross-model-verdict/v1","task_id":"T-019","feature":"feat","vendor":"openai","model":"stub-model","verdict":"NEEDS_WORK","findings":[{"severity":"Major","ref":"x","note":"y"}],"blind":true,"input_digest":"a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2","consent":{"kind":"human-flag","ref":"stub"}}
TRANSCRIPT
exit 0
STUBEOF
chmod +x "${CL019_BIN}/codex"

mkdir -p "${WORK}/cl019/specs"
printf 'bundle content\n' > "${WORK}/cl019/input.txt"

RUN_EXIT=0
RUN_OUTPUT=""
RUN_OUTPUT=$(PATH="${CL019_BIN}:/usr/bin:/bin" bash "${SCRIPTS_DIR}/run-panelist-gpt.sh" \
    --task T-019 --feature feat \
    --input "${WORK}/cl019/input.txt" \
    --spec-root "${WORK}/cl019/specs" \
    --digest "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" 2>&1) || RUN_EXIT=$?

CL019_OUT="${WORK}/cl019/specs/feat/verification/T-019.panelist-openai.verdict.json"
if [ "${RUN_EXIT}" = "0" ] && [ -f "${CL019_OUT}" ]; then
    ok "CL-019a: run-panelist-gpt exits 0 and writes a verdict file despite echoed distractor objects"
else
    fail "CL-019a: expected exit 0 and a written verdict file, got exit ${RUN_EXIT} -- ${RUN_OUTPUT}"
fi
if [ -f "${CL019_OUT}" ] && grep -q '"verdict": "NEEDS_WORK"' "${CL019_OUT}" && grep -q '"note": "y"' "${CL019_OUT}"; then
    ok "CL-019b: the extracted verdict is the REAL one (NEEDS_WORK/note=y), not the mangled schema example or the unrelated distractor"
else
    fail "CL-019b: extracted verdict did not match the real payload -- $(cat "${CL019_OUT}" 2>/dev/null)"
fi

# ============================================================================
# CL-020: run-panelist-gpt -- a verdict wrapped in a ```json Markdown code
# fence is still extracted (models fence their replies constantly,
# regardless of what the prompt asks for).
# ============================================================================

echo "=== CL-020: run-panelist-gpt extracts a fenced verdict ==="

CL020_BIN="${WORK}/cl020-bin"
mkdir -p "${CL020_BIN}"
cat > "${CL020_BIN}/codex" << 'STUBEOF'
#!/bin/sh
cat << 'TRANSCRIPT'
codex
```json
{"schema":"cross-model-verdict/v1","task_id":"T-020","feature":"feat","vendor":"openai","model":"stub-model","verdict":"PASS","findings":[],"blind":true,"input_digest":"a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2","consent":{"kind":"human-flag","ref":"stub"}}
```
TRANSCRIPT
exit 0
STUBEOF
chmod +x "${CL020_BIN}/codex"

mkdir -p "${WORK}/cl020/specs"
printf 'bundle content\n' > "${WORK}/cl020/input.txt"

RUN_EXIT=0
RUN_OUTPUT=""
RUN_OUTPUT=$(PATH="${CL020_BIN}:/usr/bin:/bin" bash "${SCRIPTS_DIR}/run-panelist-gpt.sh" \
    --task T-020 --feature feat \
    --input "${WORK}/cl020/input.txt" \
    --spec-root "${WORK}/cl020/specs" \
    --digest "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" 2>&1) || RUN_EXIT=$?

CL020_OUT="${WORK}/cl020/specs/feat/verification/T-020.panelist-openai.verdict.json"
if [ "${RUN_EXIT}" = "0" ] && [ -f "${CL020_OUT}" ] && grep -q '"verdict": "PASS"' "${CL020_OUT}"; then
    ok "CL-020: a \`\`\`json-fenced verdict is extracted"
else
    fail "CL-020: expected the fenced verdict to be extracted, got exit ${RUN_EXIT} -- ${RUN_OUTPUT}"
fi

# ============================================================================
# CL-021: run-panelist-gpt -- output contains parseable JSON objects, but
# none carries "schema": "cross-model-verdict/v1" -> exit non-zero, no
# verdict file written (a stray object must never be mistaken for a
# verdict).
# ============================================================================

echo "=== CL-021: run-panelist-gpt rejects output with no schema-matching object ==="

CL021_BIN="${WORK}/cl021-bin"
mkdir -p "${CL021_BIN}"
cat > "${CL021_BIN}/codex" << 'STUBEOF'
#!/bin/sh
cat << 'TRANSCRIPT'
codex
preamble text with {"schema": "cross-model-verdict/v0", "task_id": "T-021"} and also {"other": "thing", "count": 1}
TRANSCRIPT
exit 0
STUBEOF
chmod +x "${CL021_BIN}/codex"

mkdir -p "${WORK}/cl021/specs"
printf 'bundle content\n' > "${WORK}/cl021/input.txt"

RUN_EXIT=0
RUN_OUTPUT=""
RUN_OUTPUT=$(PATH="${CL021_BIN}:/usr/bin:/bin" bash "${SCRIPTS_DIR}/run-panelist-gpt.sh" \
    --task T-021 --feature feat \
    --input "${WORK}/cl021/input.txt" \
    --spec-root "${WORK}/cl021/specs" \
    --digest "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" 2>&1) || RUN_EXIT=$?

if [ "${RUN_EXIT}" != "0" ]; then
    ok "CL-021a: no schema-matching candidate -> non-zero exit (got ${RUN_EXIT})"
else
    fail "CL-021a: expected non-zero exit when no candidate carries the verdict schema, got 0 -- ${RUN_OUTPUT}"
fi
if echo "${RUN_OUTPUT}" | grep -qi "candidate"; then
    ok "CL-021b: diagnostic reports candidate objects were considered and rejected"
else
    fail "CL-021b: expected a candidate-aware diagnostic, got: ${RUN_OUTPUT}"
fi
if [ ! -f "${WORK}/cl021/specs/feat/verification/T-021.panelist-openai.verdict.json" ]; then
    ok "CL-021c: no verdict file is written when no candidate matches the schema"
else
    fail "CL-021c: a verdict file was written despite no schema-matching candidate"
fi

# ============================================================================
# CL-022: run-panelist-gpt -- a `}` inside a JSON string value (a finding's
# note) must not truncate the object early. Proven by round-tripping the
# full note text through to the written verdict file.
# ============================================================================

echo "=== CL-022: run-panelist-gpt does not truncate on a '}' inside a string literal ==="

CL022_BIN="${WORK}/cl022-bin"
mkdir -p "${CL022_BIN}"
cat > "${CL022_BIN}/codex" << 'STUBEOF'
#!/bin/sh
cat << 'TRANSCRIPT'
codex
{"schema":"cross-model-verdict/v1","task_id":"T-022","feature":"feat","vendor":"openai","model":"stub-model","verdict":"PASS","findings":[{"severity":"Minor","ref":"x","note":"contains a closing brace } inside a string, must not truncate here"}],"blind":true,"input_digest":"a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2","consent":{"kind":"human-flag","ref":"stub"}}
TRANSCRIPT
exit 0
STUBEOF
chmod +x "${CL022_BIN}/codex"

mkdir -p "${WORK}/cl022/specs"
printf 'bundle content\n' > "${WORK}/cl022/input.txt"

RUN_EXIT=0
RUN_OUTPUT=""
RUN_OUTPUT=$(PATH="${CL022_BIN}:/usr/bin:/bin" bash "${SCRIPTS_DIR}/run-panelist-gpt.sh" \
    --task T-022 --feature feat \
    --input "${WORK}/cl022/input.txt" \
    --spec-root "${WORK}/cl022/specs" \
    --digest "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" 2>&1) || RUN_EXIT=$?

CL022_OUT="${WORK}/cl022/specs/feat/verification/T-022.panelist-openai.verdict.json"
if [ "${RUN_EXIT}" = "0" ] && [ -f "${CL022_OUT}" ] \
   && grep -q "must not truncate here" "${CL022_OUT}" \
   && grep -q '"input_digest"' "${CL022_OUT}"; then
    ok "CL-022: a '}' inside a string value does not truncate the object -- full note and trailing fields survived"
else
    fail "CL-022: expected the full note (through the trailing fields) to survive extraction, got exit ${RUN_EXIT} -- $(cat "${CL022_OUT}" 2>/dev/null)"
fi

# ============================================================================
# CL-023: run-panelist-gpt -- malformed JSON (a single, unparseable
# candidate) still exits non-zero, and the diagnostic names the candidate
# and its parse error rather than pointing at an unidentifiable span.
# ============================================================================

echo "=== CL-023: run-panelist-gpt reports a useful diagnostic for malformed JSON ==="

CL023_BIN="${WORK}/cl023-bin"
mkdir -p "${CL023_BIN}"
cat > "${CL023_BIN}/codex" << 'STUBEOF'
#!/bin/sh
cat << 'TRANSCRIPT'
codex
{"schema": "cross-model-verdict/v1", "verdict": }
TRANSCRIPT
exit 0
STUBEOF
chmod +x "${CL023_BIN}/codex"

mkdir -p "${WORK}/cl023/specs"
printf 'bundle content\n' > "${WORK}/cl023/input.txt"

RUN_EXIT=0
RUN_OUTPUT=""
RUN_OUTPUT=$(PATH="${CL023_BIN}:/usr/bin:/bin" bash "${SCRIPTS_DIR}/run-panelist-gpt.sh" \
    --task T-023 --feature feat \
    --input "${WORK}/cl023/input.txt" \
    --spec-root "${WORK}/cl023/specs" \
    --digest "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" 2>&1) || RUN_EXIT=$?

if [ "${RUN_EXIT}" != "0" ]; then
    ok "CL-023a: malformed JSON -> non-zero exit (got ${RUN_EXIT})"
else
    fail "CL-023a: expected non-zero exit for malformed JSON, got 0 -- ${RUN_OUTPUT}"
fi
if echo "${RUN_OUTPUT}" | grep -qi "candidate 1" && echo "${RUN_OUTPUT}" | grep -qi "parse error"; then
    ok "CL-023b: diagnostic names candidate 1 and its parse error (not just an unidentifiable span)"
else
    fail "CL-023b: expected a candidate-numbered parse-error diagnostic, got: ${RUN_OUTPUT}"
fi
if [ ! -f "${WORK}/cl023/specs/feat/verification/T-023.panelist-openai.verdict.json" ]; then
    ok "CL-023c: no verdict file is written for malformed JSON"
else
    fail "CL-023c: a verdict file was written despite malformed JSON"
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
    exit 1
fi
exit 0
