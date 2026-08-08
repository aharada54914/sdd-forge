#!/bin/sh
# T-008 (epic-189-a1-project-context, REQ-010): acceptance checks for
# plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py and
# its .sh/.ps1 dispatcher wrappers.
#
# TEST-027 host-canary challenge/response fail-closed proof (AC-027): for
#   EACH of the three runtimes (claude-code, codex-cli, copilot-cli),
#   independently: a fixture matching the runtime's documented
#   expected-deny-signature + matching nonce -> HOOK_ACTIVE; a fixture
#   showing the write executed -> CAPABILITY_RUNTIME_UNAVAILABLE/
#   WRITE_EXECUTED; an unrecognized/ambiguous non-executed result ->
#   .../UNRECOGNIZED_RESULT; a missing recorded-result file ->
#   .../NO_RECORDED_RESULT; a stale/mismatched nonce (otherwise-correct
#   signature) -> .../STALE_CHALLENGE_REJECTED. Codex CLI additionally:
#   plugin_hooks_enabled: false (even alongside denied_by_plugin_hooks:
#   true) collapses into .../PLUGIN_HOOKS_DISABLED, never a denial.
#   Copilot CLI additionally: an affirmatively-"allow" permissionDecision
#   (the well-known "subagent hook does not fire" case) is
#   UNRECOGNIZED_RESULT, not a special case. Runtime-independent evidence
#   malformation (invalid JSON, non-object top level, invalid UTF-8) ->
#   .../RECORDED_RESULT_UNREADABLE, asserted once (shared code path).
# TEST-032 sentinel two-branch non-mutation + cleanup-success observation
#   + stale-start recovery (AC-032): (a) hook FIRES -- HOOK_ACTIVE, no
#   cleanup step, sentinel absent-before/absent-after; (b) hook does NOT
#   fire, cleanup SUCCEEDS -- SENTINEL_CLEANUP_CONFIRMED alongside the
#   standing CAPABILITY_RUNTIME_UNAVAILABLE; (c) hook does NOT fire,
#   cleanup FAILS or is unconfirmed (no recorded cleanup result, OR the
#   create-to-delete race) -- SENTINEL_CLEANUP_UNCONFIRMED alongside
#   CAPABILITY_RUNTIME_UNAVAILABLE, two independent sub-fixtures; a
#   SEPARATE stale-start fixture proves the NEXT --emit-challenge
#   invocation detects a pre-existing stale sentinel at START (diagnostic
#   only, never touches it) and still emits/resolves a fresh challenge
#   correctly regardless. A dedicated non-mutation battery proves
#   placeholder "live sidecar" fixture files are byte-identical across an
#   entire multi-invocation battery (the script never performs a write
#   attempt at all, B4).
# TEST-HARDEN(a..n): fail-closed exhaustiveness for usage errors (missing/
#   empty/conflicting flags, unknown --runtime) and evidence-file hostile
#   inputs (missing, invalid JSON, non-object, invalid UTF-8, unusual
#   path characters) -- never an uncaught traceback.
#
# This suite invokes the tool through check-hook-activation-handshake.sh
# (the real dispatcher surface), mirroring detect-policy-weakening.tests.sh's
# / validate-approval-sidecar.tests.sh's own convention.
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/check-hook-activation-handshake-test.XXXXXX")
# Physical-path normalization (design.md Test Strategy item 12).
WORK=$(cd "$WORK" && pwd -P)
trap 'rm -rf "$WORK"' EXIT INT TERM

HH_SH="$ROOT/plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.sh"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

if command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  printf 'FAIL: no python3/python interpreter available\n'
  exit 1
fi

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$1" | awk '{print $1}'
  else
    shasum -a 256 -- "$1" | awk '{print $1}'
  fi
}

# run_hh [args...] -- invokes the .sh dispatcher in the CURRENT directory
# (the sentinel path is CWD-relative), capturing stdout to $WORK/out,
# stderr to $WORK/err, returning its exit code.
run_hh() {
  "$HH_SH" "$@" >"$WORK/out" 2>"$WORK/err"
  return $?
}

# assert_json_field <json_file> <python_expr_on_d> <expected> <label>
assert_json_field() {
  file=$1; expr=$2; expected=$3; label=$4
  actual=$("$PY" -c "
import json
d = json.load(open('$file'))
print($expr)
" 2>/dev/null)
  if [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    fail "$label (got '$actual', want '$expected')"
  fi
}

assert_exit() {
  actual=$1; expected=$2; label=$3
  if [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    fail "$label (got exit $actual, want $expected; stderr: $(cat "$WORK/err" 2>/dev/null))"
  fi
}

assert_no_traceback() {
  label=$1
  if grep -qi traceback "$WORK/err" 2>/dev/null; then
    fail "$label: no raw traceback on stderr (FOUND ONE)"
  else
    pass "$label: no raw traceback on stderr"
  fi
}

# ---------------------------------------------------------------------------
# TEST-027: per-runtime fail-closed verify-response proof -- AC-027.
# ---------------------------------------------------------------------------

T027=$(mktemp -d "$WORK/t027.XXXXXX")

# --- claude-code -------------------------------------------------------

NONCE_CC=nonce-cc-fixed-001

cat > "$T027/cc-deny.json" <<EOF
{"nonce": "$NONCE_CC", "executed": false, "guard_emit_mode": "exit", "exit_code": 2}
EOF
(cd "$T027" && run_hh --verify-response --nonce "$NONCE_CC" --recorded-result cc-deny.json --runtime claude-code)
rc=$?
assert_exit "$rc" 0 "TEST-027 claude-code: a genuine --emit exit deny signature + matching nonce -> exit 0"
assert_json_field "$WORK/out" "d['status']" "HOOK_ACTIVE" "TEST-027 claude-code: HOOK_ACTIVE reported"

cat > "$T027/cc-write.json" <<EOF
{"nonce": "$NONCE_CC", "executed": true}
EOF
(cd "$T027" && run_hh --verify-response --nonce "$NONCE_CC" --recorded-result cc-write.json --runtime claude-code)
rc=$?
assert_exit "$rc" 63 "TEST-027 claude-code: the write actually executing -> exit 63/WRITE_EXECUTED"
assert_json_field "$WORK/out" "d['status']" "CAPABILITY_RUNTIME_UNAVAILABLE" "TEST-027 claude-code: WRITE_EXECUTED -> CAPABILITY_RUNTIME_UNAVAILABLE"
assert_json_field "$WORK/out" "d['reason']" "WRITE_EXECUTED" "TEST-027 claude-code: WRITE_EXECUTED reason reported"

cat > "$T027/cc-unrecognized.json" <<EOF
{"nonce": "$NONCE_CC", "executed": false}
EOF
(cd "$T027" && run_hh --verify-response --nonce "$NONCE_CC" --recorded-result cc-unrecognized.json --runtime claude-code)
rc=$?
assert_exit "$rc" 64 "TEST-027 claude-code: executed:false with no guard_emit_mode/exit_code -> exit 64/UNRECOGNIZED_RESULT"
assert_json_field "$WORK/out" "d['reason']" "UNRECOGNIZED_RESULT" "TEST-027 claude-code: UNRECOGNIZED_RESULT reason reported"

(cd "$T027" && run_hh --verify-response --nonce "$NONCE_CC" --recorded-result does-not-exist.json --runtime claude-code)
rc=$?
assert_exit "$rc" 60 "TEST-027 claude-code: a missing recorded-result file -> exit 60/NO_RECORDED_RESULT"
assert_json_field "$WORK/out" "d['reason']" "NO_RECORDED_RESULT" "TEST-027 claude-code: NO_RECORDED_RESULT reason reported"

(cd "$T027" && run_hh --verify-response --nonce "a-different-nonce" --recorded-result cc-deny.json --runtime claude-code)
rc=$?
assert_exit "$rc" 62 "TEST-027 claude-code: an otherwise-correct signature with a MISMATCHED nonce -> exit 62/STALE_CHALLENGE_REJECTED"
assert_json_field "$WORK/out" "d['reason']" "STALE_CHALLENGE_REJECTED" "TEST-027 claude-code: STALE_CHALLENGE_REJECTED reason reported (never HOOK_ACTIVE without a fresh nonce match)"

# --- copilot-cli ---------------------------------------------------------

NONCE_CP=nonce-copilot-fixed-002

cat > "$T027/cp-deny.json" <<EOF
{"nonce": "$NONCE_CP", "executed": false, "permissionDecision": "deny"}
EOF
(cd "$T027" && run_hh --verify-response --nonce "$NONCE_CP" --recorded-result cp-deny.json --runtime copilot-cli)
rc=$?
assert_exit "$rc" 0 "TEST-027 copilot-cli: a genuine --emit copilot deny JSON + matching nonce -> exit 0"
assert_json_field "$WORK/out" "d['status']" "HOOK_ACTIVE" "TEST-027 copilot-cli: HOOK_ACTIVE reported"

cat > "$T027/cp-write.json" <<EOF
{"nonce": "$NONCE_CP", "executed": true}
EOF
(cd "$T027" && run_hh --verify-response --nonce "$NONCE_CP" --recorded-result cp-write.json --runtime copilot-cli)
rc=$?
assert_exit "$rc" 63 "TEST-027 copilot-cli: the write actually executing -> exit 63/WRITE_EXECUTED"

cat > "$T027/cp-absent-decision.json" <<EOF
{"nonce": "$NONCE_CP", "executed": false}
EOF
(cd "$T027" && run_hh --verify-response --nonce "$NONCE_CP" --recorded-result cp-absent-decision.json --runtime copilot-cli)
rc=$?
assert_exit "$rc" 64 "TEST-027 copilot-cli: an ABSENT permissionDecision -> exit 64/UNRECOGNIZED_RESULT, never HOOK_ACTIVE"

cat > "$T027/cp-allow.json" <<EOF
{"nonce": "$NONCE_CP", "executed": false, "permissionDecision": "allow"}
EOF
(cd "$T027" && run_hh --verify-response --nonce "$NONCE_CP" --recorded-result cp-allow.json --runtime copilot-cli)
rc=$?
assert_exit "$rc" 64 "TEST-027 copilot-cli: the well-known 'subagent hook often does not fire' case (permissionDecision: allow) -> exit 64/UNRECOGNIZED_RESULT, not a special case"

(cd "$T027" && run_hh --verify-response --nonce "$NONCE_CP" --recorded-result missing.json --runtime copilot-cli)
rc=$?
assert_exit "$rc" 60 "TEST-027 copilot-cli: a missing recorded-result file -> exit 60/NO_RECORDED_RESULT"

(cd "$T027" && run_hh --verify-response --nonce "wrong-nonce" --recorded-result cp-deny.json --runtime copilot-cli)
rc=$?
assert_exit "$rc" 62 "TEST-027 copilot-cli: a MISMATCHED nonce against an otherwise-correct deny signature -> exit 62/STALE_CHALLENGE_REJECTED"

# --- codex-cli -----------------------------------------------------------

NONCE_CX=nonce-codex-fixed-003

cat > "$T027/cx-deny.json" <<EOF
{"nonce": "$NONCE_CX", "executed": false, "plugin_hooks_enabled": true, "denied_by_plugin_hooks": true}
EOF
(cd "$T027" && run_hh --verify-response --nonce "$NONCE_CX" --recorded-result cx-deny.json --runtime codex-cli)
rc=$?
assert_exit "$rc" 0 "TEST-027 codex-cli: plugin_hooks_enabled + denied_by_plugin_hooks + matching nonce -> exit 0"
assert_json_field "$WORK/out" "d['status']" "HOOK_ACTIVE" "TEST-027 codex-cli: HOOK_ACTIVE reported"

cat > "$T027/cx-write.json" <<EOF
{"nonce": "$NONCE_CX", "executed": true}
EOF
(cd "$T027" && run_hh --verify-response --nonce "$NONCE_CX" --recorded-result cx-write.json --runtime codex-cli)
rc=$?
assert_exit "$rc" 63 "TEST-027 codex-cli: the write actually executing -> exit 63/WRITE_EXECUTED"

cat > "$T027/cx-flag-disabled.json" <<EOF
{"nonce": "$NONCE_CX", "executed": false, "plugin_hooks_enabled": false, "denied_by_plugin_hooks": true}
EOF
(cd "$T027" && run_hh --verify-response --nonce "$NONCE_CX" --recorded-result cx-flag-disabled.json --runtime codex-cli)
rc=$?
assert_exit "$rc" 65 "TEST-027 codex-cli: an unset/false plugin_hooks_enabled -> exit 65/PLUGIN_HOOKS_DISABLED even when denied_by_plugin_hooks claims true (the collapse-into-hook-not-active case, REQ-010)"
assert_json_field "$WORK/out" "d['reason']" "PLUGIN_HOOKS_DISABLED" "TEST-027 codex-cli: PLUGIN_HOOKS_DISABLED reason reported, never HOOK_ACTIVE"

cat > "$T027/cx-unrecognized.json" <<EOF
{"nonce": "$NONCE_CX", "executed": false, "plugin_hooks_enabled": true}
EOF
(cd "$T027" && run_hh --verify-response --nonce "$NONCE_CX" --recorded-result cx-unrecognized.json --runtime codex-cli)
rc=$?
assert_exit "$rc" 64 "TEST-027 codex-cli: plugin_hooks_enabled true but no denied_by_plugin_hooks -> exit 64/UNRECOGNIZED_RESULT"

(cd "$T027" && run_hh --verify-response --nonce "$NONCE_CX" --recorded-result missing.json --runtime codex-cli)
rc=$?
assert_exit "$rc" 60 "TEST-027 codex-cli: a missing recorded-result file -> exit 60/NO_RECORDED_RESULT"

(cd "$T027" && run_hh --verify-response --nonce "wrong-nonce" --recorded-result cx-deny.json --runtime codex-cli)
rc=$?
assert_exit "$rc" 62 "TEST-027 codex-cli: a MISMATCHED nonce against an otherwise-correct deny signature -> exit 62/STALE_CHALLENGE_REJECTED"

# --- runtime-independent evidence malformation (shared code path) --------

printf '{not valid json' > "$T027/bad-json.json"
(cd "$T027" && run_hh --verify-response --nonce "$NONCE_CC" --recorded-result bad-json.json --runtime claude-code)
rc=$?
assert_exit "$rc" 61 "TEST-027 shared: invalid JSON syntax -> exit 61/RECORDED_RESULT_UNREADABLE"

printf '[1, 2, 3]' > "$T027/array-toplevel.json"
(cd "$T027" && run_hh --verify-response --nonce "$NONCE_CC" --recorded-result array-toplevel.json --runtime claude-code)
rc=$?
assert_exit "$rc" 61 "TEST-027 shared: a non-object (JSON array) top level -> exit 61/RECORDED_RESULT_UNREADABLE"

printf '\xff\xfe not valid utf-8' > "$T027/bad-utf8.json"
(cd "$T027" && run_hh --verify-response --nonce "$NONCE_CC" --recorded-result bad-utf8.json --runtime claude-code)
rc=$?
assert_exit "$rc" 61 "TEST-027 shared: invalid UTF-8 bytes -> exit 61/RECORDED_RESULT_UNREADABLE"

# --- Challenge shape / cross-artifact contract check (AGENTS.md "High-risk
# task preflight", WFI-001): --emit-challenge's own 'schema' and
# 'canary_target' fields are FIXED literals design.md's CLI contract names
# verbatim -- a drift here would silently desynchronize from the guard-
# invariants protected-path registration (T-009) and every future entry
# point's own tool-call template resolution (T-011/T-012), so their exact
# values are asserted directly rather than merely relied upon implicitly.
mkdir -p "$T027/shape/sdd"
(cd "$T027/shape" && run_hh --emit-challenge)
assert_json_field "$WORK/out" "d['schema']" "sdd-hook-challenge/v1" \
  "TEST-027 challenge shape: 'schema' is the exact literal design.md's CLI contract fixes"
assert_json_field "$WORK/out" "d['canary_target']" "sdd/.hook-canary-sentinel" \
  "TEST-027 challenge shape: 'canary_target' is the exact literal protected sentinel path design.md's Data Plan registers"
for rt in claude-code codex-cli copilot-cli; do
  assert_json_field "$WORK/out" "'$rt' in d['tool_call_template']" "True" \
    "TEST-027 challenge shape: tool_call_template includes a '$rt' entry"
done

# ---------------------------------------------------------------------------
# TEST-032: sentinel two-branch non-mutation + cleanup-success observation
# + stale-start recovery -- AC-032.
# ---------------------------------------------------------------------------

T032=$(mktemp -d "$WORK/t032.XXXXXX")

# Placeholder "live sidecar" fixtures the redesigned handshake must NEVER
# touch in ANY branch (non-mutation proof, unconditional).
mkdir -p "$T032/branch-a/sdd"
printf 'placeholder project-context sidecar bytes\n' > "$T032/branch-a/sdd/project-context.approval.json"
printf 'placeholder provider-bindings sidecar bytes\n' > "$T032/branch-a/sdd/provider-bindings.approval.json"
HASH_PC_BEFORE=$(sha256_of "$T032/branch-a/sdd/project-context.approval.json")
HASH_PB_BEFORE=$(sha256_of "$T032/branch-a/sdd/provider-bindings.approval.json")

# (a) hook FIRES: HOOK_ACTIVE, absent-before/absent-after, no cleanup step.
if [ -e "$T032/branch-a/sdd/.hook-canary-sentinel" ]; then
  fail "TEST-032 (a) precondition: sentinel absent BEFORE the hook-fires branch"
else
  pass "TEST-032 (a) precondition: sentinel absent BEFORE the hook-fires branch"
fi
NONCE_A=nonce-branch-a-004
cat > "$T032/branch-a/deny.json" <<EOF
{"nonce": "$NONCE_A", "executed": false, "guard_emit_mode": "exit", "exit_code": 2}
EOF
(cd "$T032/branch-a" && run_hh --verify-response --nonce "$NONCE_A" --recorded-result deny.json --runtime claude-code)
rc=$?
assert_exit "$rc" 0 "TEST-032 (a) hook FIRES: HOOK_ACTIVE"
if [ -e "$T032/branch-a/sdd/.hook-canary-sentinel" ]; then
  fail "TEST-032 (a) the sentinel is absent-AFTER the hook-fires branch too (never created)"
else
  pass "TEST-032 (a) the sentinel is absent-AFTER the hook-fires branch too (never created)"
fi
HASH_PC_AFTER=$(sha256_of "$T032/branch-a/sdd/project-context.approval.json")
HASH_PB_AFTER=$(sha256_of "$T032/branch-a/sdd/provider-bindings.approval.json")
if [ "$HASH_PC_BEFORE" = "$HASH_PC_AFTER" ] && [ "$HASH_PB_BEFORE" = "$HASH_PB_AFTER" ]; then
  pass "TEST-032 (a) the live sidecar fixtures are byte-identical before/after (never touched)"
else
  fail "TEST-032 (a) the live sidecar fixtures are byte-identical before/after"
fi

# (b) hook does NOT fire, cleanup SUCCEEDS.
mkdir -p "$T032/branch-b"
NONCE_B=nonce-branch-b-005
cat > "$T032/branch-b/write.json" <<EOF
{"nonce": "$NONCE_B", "executed": true}
EOF
(cd "$T032/branch-b" && run_hh --verify-response --nonce "$NONCE_B" --recorded-result write.json --runtime claude-code)
rc=$?
assert_exit "$rc" 63 "TEST-032 (b) hook does not fire: CAPABILITY_RUNTIME_UNAVAILABLE/WRITE_EXECUTED"
cat > "$T032/branch-b/cleanup-ok.json" <<EOF
{"nonce": "$NONCE_B", "executed": true}
EOF
(cd "$T032/branch-b" && run_hh --confirm-cleanup --nonce "$NONCE_B" --recorded-cleanup-result cleanup-ok.json)
rc=$?
assert_exit "$rc" 0 "TEST-032 (b) a recorded cleanup delete showing success -> exit 0/SENTINEL_CLEANUP_CONFIRMED"
assert_json_field "$WORK/out" "d['cleanup_status']" "SENTINEL_CLEANUP_CONFIRMED" "TEST-032 (b) cleanup_status is SENTINEL_CLEANUP_CONFIRMED"
assert_json_field "$WORK/out" "d['capability_status']" "CAPABILITY_RUNTIME_UNAVAILABLE" "TEST-032 (b) the standing capability_status (from the original probe) is restated alongside the cleanup verdict"

# (c) hook does NOT fire, cleanup FAILS or is unconfirmed -- two independent
# sub-fixtures (no recorded result at all; the create-to-delete race).
mkdir -p "$T032/branch-c1" "$T032/branch-c2"
NONCE_C1=nonce-branch-c1-006
cat > "$T032/branch-c1/write.json" <<EOF
{"nonce": "$NONCE_C1", "executed": true}
EOF
(cd "$T032/branch-c1" && run_hh --verify-response --nonce "$NONCE_C1" --recorded-result write.json --runtime claude-code)
(cd "$T032/branch-c1" && run_hh --confirm-cleanup --nonce "$NONCE_C1" --recorded-cleanup-result never-recorded.json)
rc=$?
assert_exit "$rc" 70 "TEST-032 (c1) no cleanup-result evidence recorded at all -> exit 70/NO_CLEANUP_RESULT"
assert_json_field "$WORK/out" "d['cleanup_status']" "SENTINEL_CLEANUP_UNCONFIRMED" "TEST-032 (c1) cleanup_status is SENTINEL_CLEANUP_UNCONFIRMED"
assert_json_field "$WORK/out" "d['capability_status']" "CAPABILITY_RUNTIME_UNAVAILABLE" "TEST-032 (c1) the standing CAPABILITY_RUNTIME_UNAVAILABLE is restated alongside (independent verdicts, never retroactively changed)"

NONCE_C2=nonce-branch-c2-007
cat > "$T032/branch-c2/write.json" <<EOF
{"nonce": "$NONCE_C2", "executed": true}
EOF
(cd "$T032/branch-c2" && run_hh --verify-response --nonce "$NONCE_C2" --recorded-result write.json --runtime claude-code)
cat > "$T032/branch-c2/cleanup-denied.json" <<EOF
{"nonce": "$NONCE_C2", "executed": false}
EOF
(cd "$T032/branch-c2" && run_hh --confirm-cleanup --nonce "$NONCE_C2" --recorded-cleanup-result cleanup-denied.json)
rc=$?
assert_exit "$rc" 72 "TEST-032 (c2) the cleanup delete's own attempt was denied (create-to-delete race) -> exit 72/CLEANUP_DENIED, never a privileged force-delete"
assert_json_field "$WORK/out" "d['reason']" "CLEANUP_DENIED" "TEST-032 (c2) CLEANUP_DENIED reason reported"

# Cleanup-result nonce mismatch: never confirmed on stale/replayed evidence.
mkdir -p "$T032/branch-c3"
NONCE_C3=nonce-branch-c3-008
cat > "$T032/branch-c3/cleanup-stale.json" <<EOF
{"nonce": "a-totally-different-nonce", "executed": true}
EOF
(cd "$T032/branch-c3" && run_hh --confirm-cleanup --nonce "$NONCE_C3" --recorded-cleanup-result cleanup-stale.json)
rc=$?
assert_exit "$rc" 62 "TEST-032 (c3) a cleanup-result with a MISMATCHED nonce is never confirmed -> exit 62/STALE_CHALLENGE_REJECTED"

# --- Stale-start recovery: a SEPARATE fixture. ---------------------------

mkdir -p "$T032/stale-start/sdd"
printf 'leftover-from-a-crashed-invocation' > "$T032/stale-start/sdd/.hook-canary-sentinel"
STALE_HASH_BEFORE=$(sha256_of "$T032/stale-start/sdd/.hook-canary-sentinel")
(cd "$T032/stale-start" && run_hh --emit-challenge)
rc=$?
assert_exit "$rc" 0 "TEST-032 stale-start: --emit-challenge with a pre-existing stale sentinel still exits 0"
if grep -q STALE_SENTINEL_DETECTED "$WORK/err"; then
  pass "TEST-032 stale-start: the pre-existing stale sentinel is reported as a diagnostic (STALE_SENTINEL_DETECTED)"
else
  fail "TEST-032 stale-start: the pre-existing stale sentinel is reported as a diagnostic (STALE_SENTINEL_DETECTED) (stderr: $(cat "$WORK/err"))"
fi
assert_json_field "$WORK/out" "d['schema']" "sdd-hook-challenge/v1" "TEST-032 stale-start: a fresh, valid challenge is still emitted regardless"
NEW_NONCE=$("$PY" -c "import json; print(json.load(open('$WORK/out'))['nonce'])")
if [ -n "$NEW_NONCE" ]; then
  pass "TEST-032 stale-start: the new challenge carries a non-empty nonce"
else
  fail "TEST-032 stale-start: the new challenge carries a non-empty nonce"
fi
if [ -f "$T032/stale-start/sdd/.hook-canary-sentinel" ]; then
  STALE_HASH_AFTER=$(sha256_of "$T032/stale-start/sdd/.hook-canary-sentinel")
  if [ "$STALE_HASH_BEFORE" = "$STALE_HASH_AFTER" ]; then
    pass "TEST-032 stale-start: the stale sentinel itself is byte-identical before/after --emit-challenge (this script never touches it, only the calling skill does)"
  else
    fail "TEST-032 stale-start: the stale sentinel itself is left byte-identical (it changed!)"
  fi
else
  fail "TEST-032 stale-start: the stale sentinel is still present after --emit-challenge (this script never deletes it itself)"
fi
# The new challenge's own probe still resolves correctly regardless of the
# stale-sentinel condition at start.
cat > "$T032/stale-start/deny.json" <<EOF
{"nonce": "$NEW_NONCE", "executed": false, "guard_emit_mode": "exit", "exit_code": 2}
EOF
(cd "$T032/stale-start" && run_hh --verify-response --nonce "$NEW_NONCE" --recorded-result deny.json --runtime claude-code)
rc=$?
assert_exit "$rc" 0 "TEST-032 stale-start: the NEW challenge's own probe still resolves to HOOK_ACTIVE correctly, regardless of the stale-sentinel condition at start"
assert_json_field "$WORK/out" "d['status']" "HOOK_ACTIVE" "TEST-032 stale-start: HOOK_ACTIVE reported for the new challenge"

# Mirror: --emit-challenge with NO pre-existing sentinel never emits the
# stale diagnostic (proves it is conditional, not always-on).
mkdir -p "$T032/no-stale/sdd"
(cd "$T032/no-stale" && run_hh --emit-challenge)
rc=$?
assert_exit "$rc" 0 "TEST-032 no-stale: --emit-challenge with NO pre-existing sentinel exits 0"
if grep -q STALE_SENTINEL_DETECTED "$WORK/err"; then
  fail "TEST-032 no-stale: no STALE_SENTINEL_DETECTED diagnostic when the sentinel is genuinely absent"
else
  pass "TEST-032 no-stale: no STALE_SENTINEL_DETECTED diagnostic when the sentinel is genuinely absent"
fi

# --- Full-battery non-mutation proof: many invocations, one fixture dir. -

mkdir -p "$T032/battery/sdd"
printf 'battery project-context sidecar bytes\n' > "$T032/battery/sdd/project-context.approval.json"
printf 'battery provider-bindings sidecar bytes\n' > "$T032/battery/sdd/provider-bindings.approval.json"
printf 'battery approver registry bytes\n' > "$T032/battery/sdd/approver-registry.yaml"
BATTERY_PC_BEFORE=$(sha256_of "$T032/battery/sdd/project-context.approval.json")
BATTERY_PB_BEFORE=$(sha256_of "$T032/battery/sdd/provider-bindings.approval.json")
BATTERY_REG_BEFORE=$(sha256_of "$T032/battery/sdd/approver-registry.yaml")
(
  cd "$T032/battery" || exit 1
  run_hh --emit-challenge >/dev/null 2>&1
  cat > deny.json <<EOF
{"nonce": "battery-nonce", "executed": false, "guard_emit_mode": "exit", "exit_code": 2}
EOF
  run_hh --verify-response --nonce battery-nonce --recorded-result deny.json --runtime claude-code >/dev/null 2>&1
  cat > write.json <<EOF
{"nonce": "battery-nonce-2", "executed": true}
EOF
  run_hh --verify-response --nonce battery-nonce-2 --recorded-result write.json --runtime codex-cli >/dev/null 2>&1
  cat > cleanup.json <<EOF
{"nonce": "battery-nonce-2", "executed": true}
EOF
  run_hh --confirm-cleanup --nonce battery-nonce-2 --recorded-cleanup-result cleanup.json >/dev/null 2>&1
)
BATTERY_PC_AFTER=$(sha256_of "$T032/battery/sdd/project-context.approval.json")
BATTERY_PB_AFTER=$(sha256_of "$T032/battery/sdd/provider-bindings.approval.json")
BATTERY_REG_AFTER=$(sha256_of "$T032/battery/sdd/approver-registry.yaml")
if [ "$BATTERY_PC_BEFORE" = "$BATTERY_PC_AFTER" ] && [ "$BATTERY_PB_BEFORE" = "$BATTERY_PB_AFTER" ] && [ "$BATTERY_REG_BEFORE" = "$BATTERY_REG_AFTER" ]; then
  pass "TEST-032 battery: all three live sidecar/registry fixtures are byte-identical across a full multi-invocation battery (--emit-challenge, HOOK_ACTIVE, WRITE_EXECUTED, confirm-cleanup)"
else
  fail "TEST-032 battery: all three live sidecar/registry fixtures are byte-identical across a full multi-invocation battery"
fi
if [ -e "$T032/battery/sdd/.hook-canary-sentinel" ]; then
  fail "TEST-032 battery: the sentinel itself was never created by this script across the whole battery (it is absent -- a real host tool call is the only thing that could ever create it, out of this script's own scope)"
else
  pass "TEST-032 battery: the sentinel itself was never created by this script across the whole battery"
fi

# ---------------------------------------------------------------------------
# TEST-HARDEN(a..n): fail-closed exhaustiveness -- usage errors, hostile
# evidence-file inputs, never an uncaught traceback.
# ---------------------------------------------------------------------------

THARD=$(mktemp -d "$WORK/thard.XXXXXX")

(cd "$THARD" && run_hh --verify-response --recorded-result x.json --runtime claude-code)
rc=$?
assert_exit "$rc" 2 "TEST-HARDEN(a) --verify-response with NO --nonce -> exit 2 usage error"
assert_no_traceback "TEST-HARDEN(a)"

(cd "$THARD" && run_hh --verify-response --nonce n --runtime claude-code)
rc=$?
assert_exit "$rc" 2 "TEST-HARDEN(b) --verify-response with NO --recorded-result -> exit 2 usage error"
assert_no_traceback "TEST-HARDEN(b)"

(cd "$THARD" && run_hh --verify-response --nonce n --recorded-result x.json)
rc=$?
assert_exit "$rc" 2 "TEST-HARDEN(c) --verify-response with NO --runtime -> exit 2 usage error"
assert_no_traceback "TEST-HARDEN(c)"

(cd "$THARD" && run_hh --verify-response --nonce n --recorded-result x.json --runtime not-a-real-runtime)
rc=$?
assert_exit "$rc" 2 "TEST-HARDEN(d) an unrecognized --runtime value -> exit 2 usage error"
assert_no_traceback "TEST-HARDEN(d)"

cat > "$THARD/some-result.json" <<'EOF'
{"nonce": "n", "executed": false, "guard_emit_mode": "exit", "exit_code": 2}
EOF
(cd "$THARD" && run_hh --verify-response --nonce "" --recorded-result some-result.json --runtime claude-code)
rc=$?
assert_exit "$rc" 2 "TEST-HARDEN(e) an EMPTY --nonce value -> exit 2 usage error, never accepted as a trivial match"
assert_no_traceback "TEST-HARDEN(e)"

(cd "$THARD" && run_hh --emit-challenge --nonce n)
rc=$?
assert_exit "$rc" 2 "TEST-HARDEN(f) --emit-challenge combined with --nonce -> exit 2 usage error (takes no other arguments)"
assert_no_traceback "TEST-HARDEN(f)"

(cd "$THARD" && run_hh --confirm-cleanup --nonce n --recorded-result some-result.json --runtime claude-code --recorded-cleanup-result some-result.json)
rc=$?
assert_exit "$rc" 2 "TEST-HARDEN(g) --confirm-cleanup combined with --recorded-result/--runtime -> exit 2 usage error"
assert_no_traceback "TEST-HARDEN(g)"

(cd "$THARD" && run_hh --verify-response --nonce n --recorded-result some-result.json --runtime claude-code --recorded-cleanup-result some-result.json)
rc=$?
assert_exit "$rc" 2 "TEST-HARDEN(h) --verify-response combined with --recorded-cleanup-result -> exit 2 usage error"
assert_no_traceback "TEST-HARDEN(h)"

(cd "$THARD" && run_hh --confirm-cleanup --nonce n)
rc=$?
assert_exit "$rc" 2 "TEST-HARDEN(i) --confirm-cleanup with NO --recorded-cleanup-result -> exit 2 usage error"
assert_no_traceback "TEST-HARDEN(i)"

(cd "$THARD" && run_hh)
rc=$?
assert_exit "$rc" 2 "TEST-HARDEN(j) no mode flag at all -> exit 2 usage error (argparse's own required mutually-exclusive-group check)"

(cd "$THARD" && run_hh --emit-challenge --verify-response)
rc=$?
assert_exit "$rc" 2 "TEST-HARDEN(k) two mode flags together -> exit 2 usage error (argparse's own mutually-exclusive-group check)"

# A path with unusual characters (spaces) still resolves correctly (never a
# silent path-splitting bug) -- a positive smoke test, not a rejection.
mkdir -p "$THARD/weird dir name"
cat > "$THARD/weird dir name/evidence with spaces.json" <<EOF
{"nonce": "space-nonce", "executed": false, "guard_emit_mode": "exit", "exit_code": 2}
EOF
(cd "$THARD" && run_hh --verify-response --nonce "space-nonce" --recorded-result "weird dir name/evidence with spaces.json" --runtime claude-code)
rc=$?
assert_exit "$rc" 0 "TEST-HARDEN(l) an evidence path containing spaces resolves correctly -> exit 0/HOOK_ACTIVE"
assert_no_traceback "TEST-HARDEN(l)"

# A recorded-result whose 'executed' field is present but the wrong TYPE
# (not a boolean) is rejected as unrecognized, never coerced.
cat > "$THARD/executed-wrong-type.json" <<'EOF'
{"nonce": "n", "executed": "false"}
EOF
(cd "$THARD" && run_hh --verify-response --nonce n --recorded-result executed-wrong-type.json --runtime claude-code)
rc=$?
assert_exit "$rc" 64 "TEST-HARDEN(m) a string 'executed' field (not boolean) -> exit 64/UNRECOGNIZED_RESULT, never coerced to a truthy/falsy denial"
assert_no_traceback "TEST-HARDEN(m)"

# A recorded-cleanup-result whose 'executed' field is missing entirely.
cat > "$THARD/cleanup-no-executed.json" <<'EOF'
{"nonce": "n"}
EOF
(cd "$THARD" && run_hh --confirm-cleanup --nonce n --recorded-cleanup-result cleanup-no-executed.json)
rc=$?
assert_exit "$rc" 71 "TEST-HARDEN(n) a recorded-cleanup-result with no 'executed' field -> exit 71/CLEANUP_RESULT_UNREADABLE"
assert_no_traceback "TEST-HARDEN(n)"

# ---------------------------------------------------------------------------
# Self-registration (design.md Test Strategy item 11).
# ---------------------------------------------------------------------------

if grep -q 'check-hook-activation-handshake\.tests\.sh' "$ROOT/tests/run-all.sh"; then
  pass "self-registration: tests/check-hook-activation-handshake.tests.sh registered in tests/run-all.sh"
else
  fail "self-registration: tests/check-hook-activation-handshake.tests.sh registered in tests/run-all.sh"
fi
if grep -q 'check-hook-activation-handshake\.tests\.ps1' "$ROOT/tests/run-all.ps1"; then
  pass "self-registration: tests/check-hook-activation-handshake.tests.ps1 registered in tests/run-all.ps1"
else
  fail "self-registration: tests/check-hook-activation-handshake.tests.ps1 registered in tests/run-all.ps1"
fi
if [ -f "$ROOT/tests/check-hook-activation-handshake.tests.ps1" ]; then
  pass "self-registration: tests/check-hook-activation-handshake.tests.ps1 twin exists"
else
  fail "self-registration: tests/check-hook-activation-handshake.tests.ps1 twin exists"
fi

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
