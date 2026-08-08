#!/usr/bin/env bash
# guard-negative-corpus.tests.sh — REQ-002 / AC-008..011 (issue #124,
# epic-136-phase3 T-002, Stream B).
#
# Proves 3 previously fixed defect-class payloads are correctly decided
# across ALL 4 guard-runtime surfaces (sdd-hook-guard.py/.js/.ps1, and the
# sdd-hook-guard.sh POSIX dispatcher) AND all 3 representative `tool_name`
# shapes this feature's Field Definitions name (Claude-Code-shaped "Bash";
# Codex-shaped "exec_command" and "apply_patch"):
#   1. `cd <dir> && rm <basename>` R-10 working-directory bypass (issue #110).
#      The Bash/exec_command payload is `guard-cwd-bypass.tests.sh`'s own
#      corpus reused VERBATIM (tasks.md Scope); the apply_patch payload
#      mirrors `tests/guard-r10-port.tests.ps1:181`'s own established
#      R-10-via-apply_patch corpus shape (a direct `*** Update File:` on the
#      protected path — apply_patch has no `cd` concept of its own, so the
#      same defect CLASS's apply_patch-shaped proof is "can apply_patch write
#      the protected file", which the R-10 gate must still deny).
#   2. A triple-quote-shaped (`"""`) command-text payload (issue #108 shape,
#      adapted to a PreToolUse command string — NEW corpus, design.md Design
#      Decisions / tasks.md Out of Scope: NOT `prepare-panelist-input.sh`'s
#      HMAC-key-field corpus, a structurally different injection surface).
#      Each payload is ONE compound command carrying BOTH a read-only
#      segment and a write-shaped segment against a protected path, both
#      decorated with `"""` — proving the tokenizer is not confused into
#      misreading the write segment (no read/write misclassification) while
#      staying inside acceptance-tests.md's hash-frozen 12-sub-case cardinality
#      for TEST-009 (see this file's own Specification Differences note in
#      the implementation report for the exact reasoning). A SEPARATE
#      control payload — a single, non-compound, `"""`-decorated READ-ONLY
#      command that DOES reference the SAME protected path (`cat """x"""
#      <protected-path>`, no write verb anywhere) — proves the `"""`
#      decoration never perturbs a decision in the false-DENY direction
#      EITHER: the live guard's own read-only short-circuit (reviewed
#      directly in `sdd-hook-guard.py`'s `_shell_targets_protected_gate_file`
#      docstring and confirmed empirically across all 4 runtimes during QG
#      remediation, issue #124) ALLOWs a command that merely mentions a
#      protected path with no write verb present, regardless of `"""`
#      decoration — this is a LITERAL (not a narrowed/"achievable-reading")
#      satisfaction of tasks.md's own Done-When: "ALLOW for read-only cases
#      ... against a protected path". See the implementation report's
#      Specification Differences for the full QG-remediation record,
#      including the correction of an earlier, inaccurate premise that the
#      live guard never distinguishes read from write once a protected
#      basename is present.
#   3. A task-id-substring-collision non-interference payload (issue #111
#      word-boundary defect class, ported from `check-task-state.ps1` to
#      prove `sdd-hook-guard`'s own basename matcher has no analogous
#      collision) — a `# see T-0010`-shaped decoy token immediately adjacent
#      to (but textually distinct from) a real R-10 attack targeting
#      `sdd-hook-guard.py`; the DENY decision must be driven purely by the
#      real protected-basename match, never perturbed by the decoy. A
#      SEPARATE control payload (`# see T-0010` alone, no protected basename
#      anywhere) proves the numeric substring alone never triggers a false
#      DENY.
#
# AC-011 adds a SEPARATE, post-loop cross-runtime decision-parity
# aggregation: for every (class, tool_name-shape) payload identity, every
# runtime surface that reached a decision agrees with every other reaching
# runtime — a divergence names both disagreeing runtimes.
#
# Every adversarial payload is constructed via a QUOTED heredoc
# (`python3 - <<'PYEOF'`) reading the corpus text from an environment
# variable and JSON-encoding it with `json.dumps` — never raw shell
# interpolation of the corpus string into a JSON literal — the same
# discipline `prepare-panelist-input.sh:211,225,238` already establishes
# (security-spec.md STRIDE row, Tampering). No fixture mutates a real file;
# every guard invocation is a pure DENY/ALLOW decision query against the
# LIVE, unmodified guard binaries via env-var indirection
# (`GUARD_PY`/`GUARD_JS`/`GUARD_PS1`/`GUARD_SH`, extending
# `guard-cwd-bypass.tests.sh`'s existing `GUARD_PY`/`GUARD_JS` pair —
# security-spec.md Boundary B1). `CLAUDE_PROJECT_DIR` is pinned to a
# mktemp-scoped, always-empty fixture directory for every invocation so no
# real kill-switch/sudo state can influence a decision (security-spec.md
# Boundary B4) and no real identity-ledger record or `gh` CLI call is ever
# made.
#
# A host lacking `node` SKIPs only the `.js`-runtime sub-cases (named
# reason, never a silent PASS — mirrors `guard-parity.tests.sh`'s own SKIP
# convention); a host lacking every PowerShell interpreter
# (`pwsh`/`powershell.exe`/`powershell`) SKIPs only the `.ps1`-runtime
# sub-cases likewise (acceptance-tests.md Notes' "for example" generality
# applied to the second interpreter-dependent runtime). `python3` is
# required for the suite itself (also the `.py` runtime and the `.sh`
# dispatcher's own primary fallback branch) — its absence SKIPs the whole
# suite, mirroring `guard-cwd-bypass.tests.sh`'s own precondition.
#
# Style mirrors tests/guard-cwd-bypass.tests.sh (ok/fail counters, mktemp
# fixtures, exit 1 on any failure). No `declare -A` anywhere; the only
# arrays used (the AC-011 parity-aggregation arrays) are indexed arrays,
# unconditionally populated before TEST-011 ever expands them, and are only
# ever queried via `${#ARR[@]}` (length) or bounded index access — never via
# a bare `${ARR[@]}` that could hit bash 3.2's empty-array/`set -u`
# interaction (bash 3.2 safety, REQ-006).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts"
GUARD_PY="${GUARD_PY:-${SCRIPTS_DIR}/sdd-hook-guard.py}"
GUARD_JS="${GUARD_JS:-${SCRIPTS_DIR}/sdd-hook-guard.js}"
GUARD_PS1="${GUARD_PS1:-${SCRIPTS_DIR}/sdd-hook-guard.ps1}"
GUARD_SH="${GUARD_SH:-${SCRIPTS_DIR}/sdd-hook-guard.sh}"

# Resolve to absolute paths so a per-case CWD change cannot mislocate a guard.
case "$GUARD_PY" in /*) : ;; *) GUARD_PY="${REPO_ROOT}/${GUARD_PY}" ;; esac
case "$GUARD_JS" in /*) : ;; *) GUARD_JS="${REPO_ROOT}/${GUARD_JS}" ;; esac
case "$GUARD_PS1" in /*) : ;; *) GUARD_PS1="${REPO_ROOT}/${GUARD_PS1}" ;; esac
case "$GUARD_SH" in /*) : ;; *) GUARD_SH="${REPO_ROOT}/${GUARD_SH}" ;; esac

PASS=0
FAIL=0
SKIP=0
ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }
skip() { echo "SKIP: $*"; SKIP=$((SKIP+1)); }

if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP: guard-negative-corpus.tests.sh requires python3 (not found)"
    exit 0
fi

HAVE_NODE=0
if command -v node >/dev/null 2>&1; then
    HAVE_NODE=1
fi

PS_INTERP=""
for _ps in pwsh powershell.exe powershell; do
    if command -v "$_ps" >/dev/null 2>&1; then
        PS_INTERP="$_ps"
        break
    fi
done

echo "GUARD_PY=${GUARD_PY}"
echo "GUARD_JS=${GUARD_JS}"
echo "GUARD_PS1=${GUARD_PS1}"
echo "GUARD_SH=${GUARD_SH}"
if [ "$HAVE_NODE" = "1" ]; then
    echo "node: present (.js legs run)"
else
    echo "node: absent (.js legs will SKIP)"
fi
if [ -n "$PS_INTERP" ]; then
    echo "PS_INTERP=${PS_INTERP} (.ps1 legs run)"
else
    echo "PS interpreter: absent (.ps1 legs will SKIP)"
fi

# Isolated, always-empty project dir so kill-switch/sudo state cannot
# influence any decision (mirrors guard-cwd-bypass.tests.sh).
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# Payload construction (security-spec.md STRIDE row / prepare-panelist-input.sh
# quoted-heredoc discipline: the corpus text crosses into JSON only via an
# environment variable read inside a QUOTED heredoc — never shell-interpolated
# into the JSON literal or into the Python source).
# ---------------------------------------------------------------------------

# build_payload <tool_name_shape> <command_text> -> JSON on stdout.
build_payload() {
    local shape="$1" cmd="$2"
    CORPUS_TOOL_NAME="$shape" CORPUS_COMMAND="$cmd" python3 - <<'PYEOF'
import json, os
print(json.dumps({
    "tool_name": os.environ["CORPUS_TOOL_NAME"],
    "tool_input": {"command": os.environ["CORPUS_COMMAND"]},
}))
PYEOF
}

# decision_label <exit_code> -> human-readable ALLOW/DENY/RC=N.
decision_label() {
    case "$1" in
        0) echo "ALLOW" ;;
        2) echo "DENY" ;;
        SKIP) echo "SKIP" ;;
        *) echo "RC=$1" ;;
    esac
}

# invoke_py/js/ps1/sh <payload_json> -> sets RC (global, read by caller).
invoke_py() {
    local payload="$1" rc=0
    PAYLOAD="$payload" CLAUDE_PROJECT_DIR="$WORK" python3 "$GUARD_PY" --emit exit >/dev/null 2>&1 || rc=$?
    RC="$rc"
}
invoke_js() {
    local payload="$1" rc=0
    PAYLOAD="$payload" CLAUDE_PROJECT_DIR="$WORK" node "$GUARD_JS" --emit exit >/dev/null 2>&1 || rc=$?
    RC="$rc"
}
invoke_ps1() {
    local payload="$1" rc=0
    PAYLOAD="$payload" CLAUDE_PROJECT_DIR="$WORK" "$PS_INTERP" -NoProfile -ExecutionPolicy Bypass -File "$GUARD_PS1" -Emit exit >/dev/null 2>&1 || rc=$?
    RC="$rc"
}
invoke_sh() {
    # The .sh dispatcher reads its payload from stdin unconditionally
    # (sdd-hook-guard.sh:34 `payload="$(cat)"`), unlike the .py/.js/.ps1
    # runtimes above which accept a PAYLOAD env var — so this leg pipes the
    # payload in rather than exporting it.
    local payload="$1" rc=0
    printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$WORK" sh "$GUARD_SH" --emit exit >/dev/null 2>&1 || rc=$?
    RC="$rc"
}

# AC-011 parity-aggregation storage: parallel indexed arrays (no declare -A),
# one entry per (class, tool_name-shape) payload identity, populated
# unconditionally by every run_combo call below before TEST-011 ever reads
# them (see header comment: never expanded while possibly empty).
PARITY_LABEL=()
PARITY_PY=()
PARITY_JS=()
PARITY_PS1=()
PARITY_SH=()

# run_combo <test_id> <class_label> <shape> <text> <expected_rc>
# Builds the shape's payload, invokes all 4 runtime surfaces, asserts each
# independently against expected_rc (up to 4 named leaf assertions per
# call), and records each runtime's raw decision into the parity-aggregation
# arrays for TEST-011's separate post-loop pass (AC-011) — never asserted on
# here, only recorded.
run_combo() {
    local test_id="$1" class_label="$2" shape="$3" text="$4" expected="$5"
    local payload rc_py rc_js rc_ps1 rc_sh

    payload="$(build_payload "$shape" "$text")"

    rc_py="SKIP"
    invoke_py "$payload"
    rc_py="$RC"
    if [ "$rc_py" = "$expected" ]; then
        ok "${test_id} .py/${shape}: ${class_label} -> $(decision_label "$rc_py") as expected"
    else
        fail "${test_id} .py/${shape}: ${class_label} -> $(decision_label "$rc_py"), expected $(decision_label "$expected")"
    fi

    rc_js="SKIP"
    if [ "$HAVE_NODE" = "1" ]; then
        invoke_js "$payload"
        rc_js="$RC"
        if [ "$rc_js" = "$expected" ]; then
            ok "${test_id} .js/${shape}: ${class_label} -> $(decision_label "$rc_js") as expected"
        else
            fail "${test_id} .js/${shape}: ${class_label} -> $(decision_label "$rc_js"), expected $(decision_label "$expected")"
        fi
    else
        skip "${test_id} .js/${shape}: ${class_label} — node not found on host"
    fi

    rc_ps1="SKIP"
    if [ -n "$PS_INTERP" ]; then
        invoke_ps1 "$payload"
        rc_ps1="$RC"
        if [ "$rc_ps1" = "$expected" ]; then
            ok "${test_id} .ps1/${shape}: ${class_label} -> $(decision_label "$rc_ps1") as expected"
        else
            fail "${test_id} .ps1/${shape}: ${class_label} -> $(decision_label "$rc_ps1"), expected $(decision_label "$expected")"
        fi
    else
        skip "${test_id} .ps1/${shape}: ${class_label} — no pwsh/powershell.exe/powershell found on host"
    fi

    invoke_sh "$payload"
    rc_sh="$RC"
    if [ "$rc_sh" = "$expected" ]; then
        ok "${test_id} .sh/${shape}: ${class_label} -> $(decision_label "$rc_sh") as expected"
    else
        fail "${test_id} .sh/${shape}: ${class_label} -> $(decision_label "$rc_sh"), expected $(decision_label "$expected")"
    fi

    PARITY_LABEL+=("${class_label}/${shape}")
    PARITY_PY+=("$rc_py")
    PARITY_JS+=("$rc_js")
    PARITY_PS1+=("$rc_ps1")
    PARITY_SH+=("$rc_sh")
}

# ---------------------------------------------------------------------------
# Corpus definitions
# ---------------------------------------------------------------------------

# Class 1 (AC-008): cd&&rm R-10 bypass. Bash/exec_command text is
# guard-cwd-bypass.tests.sh's OWN first payload, reused VERBATIM
# (guard-cwd-bypass.tests.sh:82-83). apply_patch text mirrors the
# established R-10-via-apply_patch corpus shape (guard-r10-port.tests.ps1:181).
CDRM_CMD='cd plugins/sdd-quality-loop/scripts && rm sdd-hook-guard.py'
CDRM_PATCH="$(printf '*** Begin Patch\n*** Update File: plugins/sdd-quality-loop/scripts/sdd-hook-guard.py\n+x\n*** End Patch')"

# Class 2 (AC-009): triple-quote-shaped command text. ONE compound command
# per shape carrying both a read-only segment (cat) and a write-shaped
# segment against the protected path (echo redirect), both """-decorated —
# the correct decision is DENY (the write segment targets a protected path);
# a tokenizer confused by the embedded """ into losing track of the write
# segment would wrongly ALLOW.
TQ_CMD='cat """notes""" README.md && echo """payload""" > plugins/sdd-quality-loop/scripts/sdd-hook-guard.py'
TQ_PATCH="$(printf '*** Begin Patch\n*** Update File: plugins/sdd-quality-loop/scripts/sdd-hook-guard.py\n+"""docstring"""\n*** End Patch')"
# Control (AC-009, QG remediation #124): a single, non-compound, """-
# decorated READ-ONLY command that DOES reference the SAME protected path
# (no write verb anywhere) — must ALLOW. Unlike the class-2 DENY payload
# above (whose write segment alone, plain-text-matched against the
# protected path, fully explains its DENY regardless of """ decoration),
# this control is the literal read-only-against-a-protected-path case
# tasks.md's own Done-When names; a """-tokenizer confused into treating
# this as a write, or into losing track of the protected-path reference,
# would wrongly DENY.
TQ_CONTROL_CMD='cat """notes""" plugins/sdd-quality-loop/scripts/sdd-hook-guard.py'

# Class 3 (AC-010): task-id-substring-collision non-interference. A
# comment-shaped decoy ("# see T-0010") textually adjacent to, but distinct
# from, a real R-10 attack on sdd-hook-guard.py — the DENY must be driven
# purely by the real protected-basename match, unperturbed by the decoy.
TID_CMD='# see T-0010; rm plugins/sdd-quality-loop/scripts/sdd-hook-guard.py'
TID_PATCH="$(printf '*** Begin Patch\n*** Update File: plugins/sdd-quality-loop/scripts/sdd-hook-guard.py\n+# see T-0010\n*** End Patch')"
# Control (AC-010): the SAME decoy token alone, no protected basename
# anywhere, no write verb — must never trigger a false DENY.
TID_CONTROL_CMD='# see T-0010'

# ===========================================================================
# TEST-008 (AC-008): cd&&rm R-10 bypass, 4 runtimes x 3 tool_name shapes.
# ===========================================================================
echo "=== TEST-008 (AC-008): cd&&rm R-10 bypass denied across 4 runtimes x 3 tool_name shapes ==="
run_combo "TEST-008" "cd&&rm-bypass" "Bash"         "$CDRM_CMD"   2
run_combo "TEST-008" "cd&&rm-bypass" "exec_command"  "$CDRM_CMD"   2
run_combo "TEST-008" "cd&&rm-bypass" "apply_patch"   "$CDRM_PATCH" 2

# ===========================================================================
# TEST-009 (AC-009): triple-quote-shaped payload, same matrix.
# ===========================================================================
echo "=== TEST-009 (AC-009): triple-quote payload correctly classified across 4 runtimes x 3 tool_name shapes ==="
run_combo "TEST-009" "triple-quote" "Bash"        "$TQ_CMD"   2
run_combo "TEST-009" "triple-quote" "exec_command" "$TQ_CMD"   2
run_combo "TEST-009" "triple-quote" "apply_patch"  "$TQ_PATCH" 2

echo "=== TEST-009 control (AC-009): read-only \"\"\"-decorated payload AGAINST the protected path must never trigger a false DENY ==="
TQ_CONTROL_PAYLOAD="$(build_payload "Bash" "$TQ_CONTROL_CMD")"
tq_control_mismatches=""
invoke_py "$TQ_CONTROL_PAYLOAD"
if [ "$RC" != "0" ]; then tq_control_mismatches="${tq_control_mismatches}py=$(decision_label "$RC"); "; fi
if [ "$HAVE_NODE" = "1" ]; then
    invoke_js "$TQ_CONTROL_PAYLOAD"
    if [ "$RC" != "0" ]; then tq_control_mismatches="${tq_control_mismatches}js=$(decision_label "$RC"); "; fi
else
    skip "TEST-009-control .js: node not found on host"
fi
if [ -n "$PS_INTERP" ]; then
    invoke_ps1 "$TQ_CONTROL_PAYLOAD"
    if [ "$RC" != "0" ]; then tq_control_mismatches="${tq_control_mismatches}ps1=$(decision_label "$RC"); "; fi
else
    skip "TEST-009-control .ps1: no pwsh/powershell.exe/powershell found on host"
fi
invoke_sh "$TQ_CONTROL_PAYLOAD"
if [ "$RC" != "0" ]; then tq_control_mismatches="${tq_control_mismatches}sh=$(decision_label "$RC"); "; fi

if [ -z "$tq_control_mismatches" ]; then
    ok "TEST-009-control: read-only triple-quote-decorated payload against the protected path ('cat \"\"\"notes\"\"\" plugins/sdd-quality-loop/scripts/sdd-hook-guard.py') ALLOWED across every available runtime — no false DENY (AC-009, literal Done-When satisfaction)"
else
    fail "TEST-009-control: read-only triple-quote-decorated payload against the protected path incorrectly DENIED by: ${tq_control_mismatches}(AC-009)"
fi

# ===========================================================================
# TEST-010 (AC-010): task-id-substring-collision, same matrix + 1 control.
# ===========================================================================
echo "=== TEST-010 (AC-010): task-id-collision decided purely on basename match, same matrix ==="
run_combo "TEST-010" "task-id-collision" "Bash"        "$TID_CMD"   2
run_combo "TEST-010" "task-id-collision" "exec_command" "$TID_CMD"   2
run_combo "TEST-010" "task-id-collision" "apply_patch"  "$TID_PATCH" 2

echo "=== TEST-010 control (AC-010): numeric-substring-alone payload must never trigger a false DENY ==="
CONTROL_PAYLOAD="$(build_payload "Bash" "$TID_CONTROL_CMD")"
control_mismatches=""
invoke_py "$CONTROL_PAYLOAD"
if [ "$RC" != "0" ]; then control_mismatches="${control_mismatches}py=$(decision_label "$RC"); "; fi
if [ "$HAVE_NODE" = "1" ]; then
    invoke_js "$CONTROL_PAYLOAD"
    if [ "$RC" != "0" ]; then control_mismatches="${control_mismatches}js=$(decision_label "$RC"); "; fi
else
    skip "TEST-010-control .js: node not found on host"
fi
if [ -n "$PS_INTERP" ]; then
    invoke_ps1 "$CONTROL_PAYLOAD"
    if [ "$RC" != "0" ]; then control_mismatches="${control_mismatches}ps1=$(decision_label "$RC"); "; fi
else
    skip "TEST-010-control .ps1: no pwsh/powershell.exe/powershell found on host"
fi
invoke_sh "$CONTROL_PAYLOAD"
if [ "$RC" != "0" ]; then control_mismatches="${control_mismatches}sh=$(decision_label "$RC"); "; fi

if [ -z "$control_mismatches" ]; then
    ok "TEST-010-control: numeric-substring-alone payload ('# see T-0010', no protected basename) ALLOWED across every available runtime — no false DENY (AC-010)"
else
    fail "TEST-010-control: numeric-substring-alone payload incorrectly DENIED by: ${control_mismatches}(AC-010)"
fi

# ===========================================================================
# TEST-011 (AC-011): cross-runtime decision-parity aggregation. A SEPARATE
# post-loop pass over the (class, tool_name-shape) payload identities
# run_combo already recorded above — never interleaved with the per-runtime
# assertions themselves, so a divergence's failure message can name exactly
# which runtimes disagreed.
# ===========================================================================
echo "=== TEST-011 (AC-011): cross-runtime decision-parity aggregation (post-loop pass) ==="
parity_count="${#PARITY_LABEL[@]}"
_i=0
while [ "$_i" -lt "$parity_count" ]; do
    label="${PARITY_LABEL[$_i]}"
    ref_name=""
    ref_dec=""
    mismatch=""
    for pair in "py:${PARITY_PY[$_i]}" "js:${PARITY_JS[$_i]}" "ps1:${PARITY_PS1[$_i]}" "sh:${PARITY_SH[$_i]}"; do
        rn="${pair%%:*}"
        rd="${pair#*:}"
        if [ "$rd" = "SKIP" ]; then
            continue
        fi
        if [ -z "$ref_name" ]; then
            ref_name="$rn"
            ref_dec="$rd"
        elif [ "$rd" != "$ref_dec" ]; then
            mismatch="${mismatch}${rn}=$(decision_label "$rd") vs ${ref_name}=$(decision_label "$ref_dec"); "
        fi
    done

    if [ -n "$mismatch" ]; then
        fail "TEST-011 ${label}: cross-runtime PARITY DIVERGENCE — ${mismatch}(AC-011)"
    else
        ok "TEST-011 ${label}: every runtime that reached a decision agrees ($(decision_label "$ref_dec")) (AC-011)"
    fi

    _i=$((_i + 1))
done

# ===========================================================================
# Summary
# ===========================================================================
echo ""
echo "guard-negative-corpus.tests.sh: $PASS passed, $FAIL failed, $SKIP skipped"
[ "$FAIL" -eq 0 ] || exit 1
