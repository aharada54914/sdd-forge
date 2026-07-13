#!/usr/bin/env bash
# guard-cwd-bypass.tests.sh — REQ-002 / AC-004 / AC-005 (issue #110).
#
# Proves the R-10 working-directory bypass is closed in BOTH runtime twins.
# `has_protected_path` used to match a protected path only as a literal
# substring of the command text, so `cd <protected-dir> && rm <basename>` (and
# `pushd` equivalents) resolved the write target below the protected prefix and
# escaped denial. After the fix, cd/pushd transitions are tracked across
# compound-command segments and resolved write targets are compared against the
# protected table.
#
# RED-first (AC-004): run this against the PRE-FIX live guards and the cwd-bypass
# cases fail (guard allows the write). GREEN (AC-005): point GUARD_PY / GUARD_JS
# at the staged fixed guards; every case passes and .py/.js decisions are equal.
#
# Guard paths are parameterized so the same corpus drives the live guards (RED)
# and the staged fixed guards (GREEN):
#   GUARD_PY  default plugins/sdd-quality-loop/scripts/sdd-hook-guard.py
#   GUARD_JS  default plugins/sdd-quality-loop/scripts/sdd-hook-guard.js
#
# Both guards read the payload from the PAYLOAD env var and, under
# `--emit exit`, return exit 0 = allow, exit 2 = deny. Every case asserts the
# two runtimes agree (decision parity) AND match the expected decision.
#
# Style mirrors tests/guard-parity.tests.sh (ok/fail counters, mktemp fixtures,
# exits 1 on any failure).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts"
GUARD_PY="${GUARD_PY:-${SCRIPTS_DIR}/sdd-hook-guard.py}"
GUARD_JS="${GUARD_JS:-${SCRIPTS_DIR}/sdd-hook-guard.js}"

# Resolve to absolute paths so a per-case CWD change cannot mislocate the guard.
case "$GUARD_PY" in /*) : ;; *) GUARD_PY="${REPO_ROOT}/${GUARD_PY}" ;; esac
case "$GUARD_JS" in /*) : ;; *) GUARD_JS="${REPO_ROOT}/${GUARD_JS}" ;; esac

PASS=0
FAIL=0
ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP: guard-cwd-bypass.tests.sh requires python3 (not found)"
    exit 0
fi
if ! command -v node >/dev/null 2>&1; then
    echo "SKIP: guard-cwd-bypass.tests.sh requires node (not found)"
    exit 0
fi

echo "GUARD_PY=${GUARD_PY}"
echo "GUARD_JS=${GUARD_JS}"

# Isolated project dir so kill-switch/sudo state cannot influence the decision.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# assert_case <name> <expected_exit> <payload_json>
# Runs the payload through both guards, asserting equal exit codes AND expected.
assert_case() {
    local name="$1" expected="$2" payload="$3"
    local py=0 js=0
    PAYLOAD="$payload" CLAUDE_PROJECT_DIR="$WORK" python3 "$GUARD_PY" --emit exit >/dev/null 2>&1 || py=$?
    PAYLOAD="$payload" CLAUDE_PROJECT_DIR="$WORK" node "$GUARD_JS" --emit exit >/dev/null 2>&1 || js=$?
    if [ "$py" != "$js" ]; then
        fail "$name: PY=$py JS=$js — RUNTIME DIVERGENCE (expected $expected)"
    elif [ "$py" != "$expected" ]; then
        fail "$name: both exit $py but expected $expected"
    else
        ok "$name: both exit $py (expected)"
    fi
}

PY_PROT='plugins/sdd-quality-loop/scripts/sdd-hook-guard.py'
JS_PROT='plugins/sdd-quality-loop/scripts/sdd-hook-guard.js'
HOOK_PROT='plugins/sdd-quality-loop/hooks/claude-hooks.json'

echo "=== AC-004: working-directory bypass MUST be denied (RED before fix) ==="

# cd into the protected dir, then delete by basename.
assert_case "cwd: cd protected && rm basename (.py)" 2 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"cd plugins/sdd-quality-loop/scripts && rm sdd-hook-guard.py\"}}"

# pushd equivalent.
assert_case "cwd: pushd protected && rm basename (.js)" 2 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"pushd plugins/sdd-quality-loop/scripts && rm sdd-hook-guard.js\"}}"

# cd then redirect-overwrite by basename (';' segment separator).
assert_case "cwd: cd protected; echo x > basename" 2 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"cd plugins/sdd-quality-loop/scripts; echo x > sdd-hook-guard.py\"}}"

# cd into a different protected dir (hooks/) then delete a hook config by basename.
assert_case "cwd: cd protected hooks && rm claude-hooks.json" 2 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"cd plugins/sdd-quality-loop/hooks && rm claude-hooks.json\"}}"

# cp ONTO a protected basename after cd (destination is protected).
assert_case "cwd: cd protected && cp /tmp/x basename" 2 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"cd plugins/sdd-quality-loop/scripts && cp /tmp/x sdd-hook-guard.py\"}}"

# '..' obfuscation of the protected path (target resolves back onto the file).
assert_case "cwd: rm via .. path segment" 2 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"rm plugins/sdd-quality-loop/scripts/../scripts/sdd-hook-guard.py\"}}"

echo "=== AC-004: unknown cd transition + write on protected basename fails closed ==="

# `cd -` cannot be resolved statically; a subsequent write on a protected
# basename must fail closed (deny), never silently allow.
assert_case "cwd: cd - && rm protected basename (fail-closed)" 2 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"cd - && rm sdd-hook-guard.py\"}}"

echo "=== AC-004/AC-005: read-only over protected paths MUST stay allowed ==="

# Direct read of a protected path by full path.
assert_case "read-only: grep full protected path" 0 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"grep -n foo plugins/sdd-quality-loop/scripts/sdd-hook-guard.py\"}}"

# cd into protected dir then read by basename.
assert_case "read-only: cd protected && cat basename" 0 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"cd plugins/sdd-quality-loop/scripts && cat sdd-hook-guard.py\"}}"

# pushd into protected dir then read by basename.
assert_case "read-only: pushd protected && cat basename" 0 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"pushd plugins/sdd-quality-loop/scripts && cat sdd-hook-guard.py\"}}"

# A bare cd into the protected dir (no write) is harmless.
assert_case "read-only: plain cd into protected dir" 0 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"cd plugins/sdd-quality-loop/scripts\"}}"

echo "=== AC-005: direct protected write still denied (regression) ==="

assert_case "regression: rm full protected path" 2 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"rm plugins/sdd-quality-loop/scripts/sdd-hook-guard.py\"}}"

echo "=== AC-005: non-protected cd + write stays allowed ==="

assert_case "allow: cd /tmp && rm somefile" 0 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"cd /tmp && rm somefile.txt\"}}"

assert_case "allow: cd protected && rm unrelated file in it" 0 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"cd plugins/sdd-quality-loop/scripts && rm README.md\"}}"

echo "=== AC-005: malformed payload denied (fail-closed preserved) ==="

assert_case "malformed: non-JSON stdin denied" 2 'not-json {['
assert_case "malformed: missing tool_input denied" 2 '{"tool_name":"bash"}'

echo "=== AC-005: existing guard-parity shell corpus decisions unchanged ==="
# These mirror tests/guard-parity.tests.sh scenarios 17,18,23-29 so the fix is
# shown to preserve every prior shell decision AND .py/.js parity.

assert_case "corpus: cat guard && rm guard (compound) denied" 2 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"cat ${PY_PROT} && rm ${PY_PROT}\"}}"

assert_case "corpus: cat heredoc redirect into guard denied" 2 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"cat > ${PY_PROT} << EOF\nmalicious content\nEOF\"}}"

assert_case "corpus: cp guard SOURCE to /tmp allowed" 0 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"cp ${PY_PROT} /tmp/guard-backup.py\"}}"

assert_case "corpus: mv in /tmp + grep settings allowed" 0 \
    '{"tool_name":"bash","tool_input":{"command":"mv /tmp/a /tmp/b && grep foo .claude/settings.json"}}'

assert_case "corpus: redirect to /tmp + cat settings allowed" 0 \
    '{"tool_name":"bash","tool_input":{"command":"echo done > /tmp/log; cat .claude/settings.local.json"}}'

assert_case "corpus: grep guard with stderr redirect allowed" 0 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"grep -n R-10 ${PY_PROT} 2>/dev/null | head -30\"}}"

assert_case "corpus: echo redirect into guard denied" 2 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"echo x > ${PY_PROT}\"}}"

assert_case "corpus: cp ONTO guard (destination) denied" 2 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"cp /tmp/x ${PY_PROT}\"}}"

assert_case "corpus: variable write target fails closed (denied)" 2 \
    "{\"tool_name\":\"bash\",\"tool_input\":{\"command\":\"DST=${PY_PROT}; cp /tmp/x \$DST\"}}"

echo ""
echo "guard-cwd-bypass.tests.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
