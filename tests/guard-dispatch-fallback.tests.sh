#!/usr/bin/env bash
# guard-dispatch-fallback.tests.sh — REQ-001 / AC-001..007 (issue #123,
# epic-136-phase3 T-001, Stream A).
#
# Proves every branch of sdd-hook-guard.sh's own
#   python3 -> pwsh/powershell.exe/powershell -> deny_unavailable
# fallback chain (sdd-hook-guard.sh:36-52) actually selects the runtime it
# claims to under a REAL `PATH` lookup, and that the selected runtime's
# decision matches a direct invocation of the same guard for the same
# payload (decision parity) — across BOTH `--emit exit` and `--emit copilot`
# modes. Before this suite existed, no test drove the dispatcher directly
# under a controlled python3-absent PATH at all: `guard-parity.tests.sh`
# SKIPs when either node or python3 is absent and never invokes
# sdd-hook-guard.sh; `guard-r10-port.tests.ps1` invokes `.ps1` directly,
# bypassing the dispatcher's own selection logic. This suite's
# TEST-001..004 are therefore this feature's RED-demonstrable core in the
# "the assertion has never been possible to make" sense (design.md Test
# Strategy item 1) — a POSITIVE, previously-unobservable-behavior proof, not
# a RED-then-GREEN bugfix regression (there is no prior "wrong behavior" to
# reproduce).
#
# Technique: every combo's `PATH` is an explicitly constructed, isolated
# fixture directory (never `/usr/bin:/bin` directly — on this repo's own
# dev/CI hosts, `/usr/bin/python3` is a real, working interpreter (Xcode CLT
# stub on macOS; system Python on many Linux distros), so `/usr/bin:/bin` is
# NOT genuinely python3-free — Field Definitions' documented fallback,
# applied UNIFORMLY here for every combo rather than conditionally, so every
# "absent" premise is genuine by construction, not host-shape-dependent).
# Each combo's directory is prefixed onto a shared, coreutils-only
# `core-bin/` directory (sh/dirname/cat/grep/pwd/printf symlinked from the
# REAL host binaries, captured from this suite's own unrestricted PATH) so
# the dispatcher's own internal shell operations keep working under the
# narrowed PATH (`tests/collection-layer.tests.sh:28,56,84,200,228`
# technique).
#
# PowerShell-name stubs are thin forwarding shims (design.md Design
# Decisions): ONE shared script body satisfies `command -v <name>` under the
# narrowed PATH, then `exec`s the REAL `pwsh` interpreter captured from this
# suite's own unrestricted PATH (before any override) — so the `.ps1`
# DECISION under test stays genuine (a real `pwsh` execution), while the
# stub's only real job is controlling which NAME the dispatcher's own
# `for ps in pwsh powershell.exe powershell` loop (`sdd-hook-guard.sh:41`)
# observes. Per-combo symlinks named pwsh/powershell.exe/powershell all
# point at the SAME shared script; each recovers its own invoked name via
# `${0##*/}` (a symlinked shebang script's own `$0` is the resolved symlink
# path, so this never collides across combos). Every payload is a fixed,
# benign, ALLOW-shaped command (never adversarial content interpolated into
# a shell command line) — security-spec.md Boundary B1: this suite invokes
# the live, protected guard binaries READ-ONLY via PATH/env-var indirection,
# never opening any of them for writing.
#
# Every fixture (PATH-restricted subshells, PowerShell forwarding stubs) is
# mktemp-scoped (security-spec.md Boundary B4); no case reserves a real
# identity-ledger record or invokes a real `gh` CLI. Style mirrors
# tests/guard-cwd-bypass.tests.sh (ok/fail counters, mktemp fixtures, exits
# 1 on any failure) and tests/collection-layer.tests.sh (PATH-restricted
# subshell technique).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts"
GUARD_SH="${SCRIPTS_DIR}/sdd-hook-guard.sh"
GUARD_PY="${SCRIPTS_DIR}/sdd-hook-guard.py"
GUARD_PS1="${SCRIPTS_DIR}/sdd-hook-guard.ps1"

PASS=0
FAIL=0
ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

# This suite proves REAL fallback-chain branch selection, not a simulation —
# it needs a genuine python3 (control case, AC-001) and a genuine pwsh (the
# real interpreter every PowerShell-name stub forwards to, AC-002..007) on
# the HOST's own unrestricted PATH. Absent either, SKIP with a named reason
# (never a silent pass) — mirrors guard-cwd-bypass.tests.sh's own
# python3+node precondition SKIP.
if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP: guard-dispatch-fallback.tests.sh requires python3 on the host (not found)"
    exit 0
fi
if ! command -v pwsh >/dev/null 2>&1; then
    echo "SKIP: guard-dispatch-fallback.tests.sh requires pwsh on the host (not found; needed as the real interpreter every PowerShell-name forwarding stub execs into)"
    exit 0
fi

REAL_PYTHON3="$(command -v python3)"
REAL_PWSH="$(command -v pwsh)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# Shared fixture construction
# ---------------------------------------------------------------------------

CORE_DIR="${WORK}/core-bin"
mkdir -p "$CORE_DIR"
for _tool in sh dirname cat grep pwd printf; do
    _real="$(command -v "$_tool" 2>/dev/null || true)"
    case "$_real" in
        /*) ln -s "$_real" "${CORE_DIR}/${_tool}" ;;
    esac
done

STUB_SRC="${WORK}/ps-stub.sh"
cat > "$STUB_SRC" <<'STUBEOF'
#!/bin/sh
printf '%s\n' "${0##*/}" >> "$STUB_MARKER_FILE"
exec "$STUB_REAL_PWSH" "$@"
STUBEOF
chmod +x "$STUB_SRC"

MARKER_FILE="${WORK}/marker.txt"
PROJECT_DIR="${WORK}/project"
mkdir -p "$PROJECT_DIR"

PAYLOAD_ALLOW='{"tool_name":"Bash","tool_input":{"command":"echo dispatch-fallback-check"}}'
PAYLOAD_FILE="${WORK}/payload-allow.json"
printf '%s' "$PAYLOAD_ALLOW" > "$PAYLOAD_FILE"

# assert_absent <path> <tool> <label> — Edge Cases (requirements.md): a
# fixture's setup step must confirm the intended tool is genuinely absent
# under the constructed PATH BEFORE asserting on the guard's decision, so a
# false "absent" premise never silently passes.
assert_absent() {
    local path="$1" tool="$2" label="$3"
    if ( PATH="$path" command -v "$tool" >/dev/null 2>&1 ); then
        fail "${label} setup: ${tool} unexpectedly present under the constructed PATH (false-negative premise)"
        return 1
    fi
    ok "${label} setup: ${tool} genuinely absent under the constructed PATH"
}

# assert_present <path> <tool> <label> — the mirror check: a controlled stub
# (or the real target, for the python3 control case) is genuinely visible.
assert_present() {
    local path="$1" tool="$2" label="$3"
    if ( PATH="$path" command -v "$tool" >/dev/null 2>&1 ); then
        ok "${label} setup: ${tool} genuinely present under the constructed PATH"
        return 0
    fi
    fail "${label} setup: ${tool} unexpectedly absent under the constructed PATH (fixture construction bug)"
}

# run_dispatcher <combo_path> <emit> <payload_file> — sets DISP_EXIT/DISP_OUT.
run_dispatcher() {
    local combo_path="$1" emit="$2" payload_file="$3"
    local out rc=0
    out="$(PATH="$combo_path" CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
        STUB_MARKER_FILE="$MARKER_FILE" STUB_REAL_PWSH="$REAL_PWSH" \
        sh "$GUARD_SH" --emit "$emit" < "$payload_file" 2>&1)" || rc=$?
    DISP_EXIT="$rc"
    DISP_OUT="$out"
}

# run_direct_py <emit> <payload> — sets DIRECT_EXIT/DIRECT_OUT.
run_direct_py() {
    local emit="$1" payload="$2"
    local out rc=0
    out="$(PAYLOAD="$payload" CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
        "$REAL_PYTHON3" "$GUARD_PY" --emit "$emit" 2>&1)" || rc=$?
    DIRECT_EXIT="$rc"
    DIRECT_OUT="$out"
}

# run_direct_ps1 <emit> <payload> — sets DIRECT_EXIT/DIRECT_OUT.
run_direct_ps1() {
    local emit="$1" payload="$2"
    local out rc=0
    out="$(PAYLOAD="$payload" CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
        "$REAL_PWSH" -NoProfile -ExecutionPolicy Bypass -File "$GUARD_PS1" -Emit "$emit" 2>&1)" || rc=$?
    DIRECT_EXIT="$rc"
    DIRECT_OUT="$out"
}

# assert_ps_branch <test_id> <combo_path> <expected_marker> <emit> <extra_label>
# Runs the dispatcher for the given combo+emit and asserts (1) decision
# parity against a direct sdd-hook-guard.ps1 invocation of the SAME payload
# and emit mode, (2) for --emit copilot, stdout shape parity too, and (3)
# that ONLY the expected stub name actually executed (the precedence proof,
# AC-006) by inspecting the marker file, never merely trusting `command -v`.
assert_ps_branch() {
    local test_id="$1" combo_path="$2" expected_marker="$3" emit="$4" extra="$5"
    local d_exit d_out marker_seen

    : > "$MARKER_FILE"
    run_dispatcher "$combo_path" "$emit" "$PAYLOAD_FILE"
    d_exit="$DISP_EXIT"
    d_out="$DISP_OUT"
    run_direct_ps1 "$emit" "$PAYLOAD_ALLOW"
    marker_seen="$(cat "$MARKER_FILE" 2>/dev/null || true)"

    if [ "$d_exit" = "$DIRECT_EXIT" ]; then
        ok "${test_id}: dispatcher (--emit ${emit}) exit ${d_exit} matches direct sdd-hook-guard.ps1 exit ${DIRECT_EXIT} (decision parity)${extra}"
    else
        fail "${test_id}: dispatcher (--emit ${emit}) exit ${d_exit} != direct .ps1 exit ${DIRECT_EXIT} (decision DIVERGENCE)${extra}"
    fi

    if [ "$emit" = "copilot" ]; then
        if [ "$d_out" = "$DIRECT_OUT" ]; then
            ok "${test_id}: dispatcher (--emit copilot) stdout matches direct .ps1 copilot JSON byte-for-byte${extra}"
        else
            fail "${test_id}: dispatcher (--emit copilot) stdout [${d_out}] != direct .ps1 stdout [${DIRECT_OUT}]${extra}"
        fi
    fi

    if [ "$marker_seen" = "$expected_marker" ]; then
        ok "${test_id}: only the '${expected_marker}'-named stub actually executed (marker=[${marker_seen}])${extra}"
    else
        fail "${test_id}: expected only '${expected_marker}' stub invoked, marker file contains [${marker_seen}]${extra}"
    fi
}

# ===========================================================================
# TEST-001 (AC-001): python3 present (control) -> .py branch selected,
# decision matches a direct sdd-hook-guard.py invocation.
# ===========================================================================
echo "=== TEST-001 (AC-001): python3 present (control) -> .py branch, decision parity ==="

CONTROL_DIR="${WORK}/combo-control"
mkdir -p "$CONTROL_DIR"
ln -s "$REAL_PYTHON3" "${CONTROL_DIR}/python3"
CONTROL_PATH="${CONTROL_DIR}:${CORE_DIR}"

assert_present "$CONTROL_PATH" python3 "TEST-001" || true

run_dispatcher "$CONTROL_PATH" exit "$PAYLOAD_FILE"
disp1_exit="$DISP_EXIT"
disp1_out="$DISP_OUT"
run_direct_py exit "$PAYLOAD_ALLOW"

if [ "$disp1_exit" = "$DIRECT_EXIT" ]; then
    ok "TEST-001: dispatcher (python3 present) exit ${disp1_exit} matches direct sdd-hook-guard.py exit ${DIRECT_EXIT} (decision parity, AC-001)"
else
    fail "TEST-001: dispatcher exit ${disp1_exit} != direct .py exit ${DIRECT_EXIT} (decision DIVERGENCE, AC-001)"
fi

if [ "$disp1_out" = "$DIRECT_OUT" ]; then
    ok "TEST-001: dispatcher stdout/stderr matches direct .py stdout/stderr byte-for-byte (AC-001)"
else
    fail "TEST-001: dispatcher output [${disp1_out}] != direct .py output [${DIRECT_OUT}] (AC-001)"
fi

if [ "$disp1_exit" = "0" ]; then
    ok "TEST-001: benign ALLOW payload correctly allowed (exit 0) via the .py branch (AC-001)"
else
    fail "TEST-001: expected exit 0 for the benign ALLOW payload, got ${disp1_exit} (AC-001)"
fi

# ===========================================================================
# TEST-002 (AC-002): python3 absent + pwsh present -> .ps1 via pwsh.
# ===========================================================================
echo "=== TEST-002 (AC-002): python3 absent + pwsh present -> .ps1 via pwsh ==="

PWSH_DIR="${WORK}/combo-pwsh"
mkdir -p "$PWSH_DIR"
ln -s "$STUB_SRC" "${PWSH_DIR}/pwsh"
PWSH_PATH="${PWSH_DIR}:${CORE_DIR}"

assert_absent "$PWSH_PATH" python3 "TEST-002" || true
assert_present "$PWSH_PATH" pwsh "TEST-002" || true
assert_absent "$PWSH_PATH" powershell.exe "TEST-002" || true
assert_absent "$PWSH_PATH" powershell "TEST-002" || true

assert_ps_branch "TEST-002" "$PWSH_PATH" "pwsh" exit " (AC-002)"

# ===========================================================================
# TEST-003 (AC-003): python3+pwsh absent + powershell.exe present -> .ps1
# via powershell.exe.
# ===========================================================================
echo "=== TEST-003 (AC-003): python3+pwsh absent + powershell.exe present -> .ps1 via powershell.exe ==="

PSEXE_DIR="${WORK}/combo-psexe"
mkdir -p "$PSEXE_DIR"
ln -s "$STUB_SRC" "${PSEXE_DIR}/powershell.exe"
PSEXE_PATH="${PSEXE_DIR}:${CORE_DIR}"

assert_absent "$PSEXE_PATH" python3 "TEST-003" || true
assert_absent "$PSEXE_PATH" pwsh "TEST-003" || true
assert_present "$PSEXE_PATH" powershell.exe "TEST-003" || true
assert_absent "$PSEXE_PATH" powershell "TEST-003" || true

assert_ps_branch "TEST-003" "$PSEXE_PATH" "powershell.exe" exit " (AC-003)"

# ===========================================================================
# TEST-004 (AC-004): python3+pwsh+powershell.exe absent + powershell
# present -> .ps1 via powershell.
# ===========================================================================
echo "=== TEST-004 (AC-004): python3+pwsh+powershell.exe absent + powershell present -> .ps1 via powershell ==="

PSNAME_DIR="${WORK}/combo-psname"
mkdir -p "$PSNAME_DIR"
ln -s "$STUB_SRC" "${PSNAME_DIR}/powershell"
PSNAME_PATH="${PSNAME_DIR}:${CORE_DIR}"

assert_absent "$PSNAME_PATH" python3 "TEST-004" || true
assert_absent "$PSNAME_PATH" pwsh "TEST-004" || true
assert_absent "$PSNAME_PATH" powershell.exe "TEST-004" || true
assert_present "$PSNAME_PATH" powershell "TEST-004" || true

assert_ps_branch "TEST-004" "$PSNAME_PATH" "powershell" exit " (AC-004)"

# ===========================================================================
# TEST-005 (AC-005): all four absent -> deny_unavailable, 2 named sub-cases.
# ===========================================================================
echo "=== TEST-005 (AC-005): all four absent -> deny_unavailable (2 sub-cases) ==="

EMPTY_DIR="${WORK}/combo-empty"
mkdir -p "$EMPTY_DIR"
EMPTY_PATH="${EMPTY_DIR}:${CORE_DIR}"

assert_absent "$EMPTY_PATH" python3 "TEST-005" || true
assert_absent "$EMPTY_PATH" pwsh "TEST-005" || true
assert_absent "$EMPTY_PATH" powershell.exe "TEST-005" || true
assert_absent "$EMPTY_PATH" powershell "TEST-005" || true

run_dispatcher "$EMPTY_PATH" exit "$PAYLOAD_FILE"
if [ "$DISP_EXIT" = "2" ]; then
    ok "TEST-005a: all four absent, --emit exit -> exit 2 (deny_unavailable, AC-005 sub-case a)"
else
    fail "TEST-005a: expected exit 2, got ${DISP_EXIT} (out=[${DISP_OUT}])"
fi

run_dispatcher "$EMPTY_PATH" copilot "$PAYLOAD_FILE"
if printf '%s' "$DISP_OUT" | grep -q '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"'; then
    ok "TEST-005b: all four absent, --emit copilot -> copilot-shaped deny JSON (AC-005 sub-case b)"
else
    fail "TEST-005b: expected copilot-shaped deny JSON, got [${DISP_OUT}]"
fi
if [ "$DISP_EXIT" = "0" ]; then
    ok "TEST-005b: --emit copilot mode exits 0 even on deny_unavailable (decision is IN the JSON, never a crash)"
else
    fail "TEST-005b: expected exit 0 for --emit copilot deny_unavailable, got ${DISP_EXIT}"
fi

# ===========================================================================
# TEST-006 (AC-006): python3 absent, all 3 PowerShell names simultaneously
# present -> only pwsh's stub fires (precedence order proof).
# ===========================================================================
echo "=== TEST-006 (AC-006): python3 absent, all 3 PS names present -> pwsh wins (precedence) ==="

PRECEDENCE_DIR="${WORK}/combo-precedence"
mkdir -p "$PRECEDENCE_DIR"
ln -s "$STUB_SRC" "${PRECEDENCE_DIR}/pwsh"
ln -s "$STUB_SRC" "${PRECEDENCE_DIR}/powershell.exe"
ln -s "$STUB_SRC" "${PRECEDENCE_DIR}/powershell"
PRECEDENCE_PATH="${PRECEDENCE_DIR}:${CORE_DIR}"

assert_absent "$PRECEDENCE_PATH" python3 "TEST-006" || true
assert_present "$PRECEDENCE_PATH" pwsh "TEST-006" || true
assert_present "$PRECEDENCE_PATH" powershell.exe "TEST-006" || true
assert_present "$PRECEDENCE_PATH" powershell "TEST-006" || true

assert_ps_branch "TEST-006" "$PRECEDENCE_PATH" "pwsh" exit " (AC-006, precedence)"

# ===========================================================================
# TEST-007 (AC-007): every branch reaching .ps1 (AC-002/003/004/006) is
# independently re-run under BOTH --emit exit and --emit copilot. TEST-002/
# 003/004/006 above already cover the --emit exit half of each of the 4
# branches; the 4 sub-cases below cover the --emit copilot half — together,
# 8 named (branch x emit-mode) sub-cases, none combined into a single
# pass/fail (Done When).
# ===========================================================================
echo "=== TEST-007 (AC-007): AC-002/003/004/006 branches re-run under --emit copilot (4 of 8 sub-cases; the --emit exit half is TEST-002/003/004/006 above) ==="

assert_ps_branch "TEST-007a" "$PWSH_PATH" "pwsh" copilot " (AC-007, pwsh branch, copilot mode)"
assert_ps_branch "TEST-007b" "$PSEXE_PATH" "powershell.exe" copilot " (AC-007, powershell.exe branch, copilot mode)"
assert_ps_branch "TEST-007c" "$PSNAME_PATH" "powershell" copilot " (AC-007, powershell branch, copilot mode)"
assert_ps_branch "TEST-007d" "$PRECEDENCE_PATH" "pwsh" copilot " (AC-007, precedence branch, copilot mode)"

# ===========================================================================
# Summary
# ===========================================================================
echo ""
echo "guard-dispatch-fallback.tests.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
