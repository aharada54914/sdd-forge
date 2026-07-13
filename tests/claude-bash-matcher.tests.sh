#!/usr/bin/env bash
# claude-bash-matcher.tests.sh
# T-006 (issue #160 / #116 verdict): prove that the Claude Code PreToolUse hook
# matcher in hooks/claude-hooks.json routes Bash tool calls to the SDD guard,
# that the guard denies a Bash-mediated protected-file write while allowing a
# read-only Bash command over a protected path (AC-012), that malformed /
# unclassifiable payloads stay denied (fail-closed, AC-013), and that the
# Claude (node .js), Codex (sh dispatcher -> python3 .py), and Copilot
# (--emit copilot) hook paths agree on the shared Bash corpus (AC-013).
#
# RED/GREEN is driven ONLY by $HOOKS_JSON (default the live claude-hooks.json):
#   HOOKS_JSON=<live   claude-hooks.json> -> matcher lacks Bash  -> (a) FAILS (RED)
#   HOOKS_JSON=<staged claude-hooks.json> -> matcher covers Bash -> all pass (GREEN)
# Sections (b) guard decisions and (c) cross-runtime parity drive the guard
# binaries directly and are independent of $HOOKS_JSON, so they pass in BOTH
# runs -- this demonstrates the guard logic already denies Bash-mediated
# protected writes and is fail-closed; only the Claude matcher ROUTING was
# missing (issue #160). The RED evidence therefore isolates the matcher gap.
#
# Usage:
#   bash tests/claude-bash-matcher.tests.sh
#   HOOKS_JSON=specs/epic-136-phase1-guards/human-copy/claude-hooks.json \
#     bash tests/claude-bash-matcher.tests.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts"
GUARD_JS="${SCRIPTS_DIR}/sdd-hook-guard.js"
GUARD_SH="${SCRIPTS_DIR}/sdd-hook-guard.sh"

# HOOKS_JSON default is the live Claude hook config; a relative value is
# resolved against the repository root so the default and the staged human-copy
# path both work regardless of the caller's working directory.
HOOKS_JSON_DEFAULT="plugins/sdd-quality-loop/hooks/claude-hooks.json"
HOOKS_JSON_INPUT="${HOOKS_JSON:-$HOOKS_JSON_DEFAULT}"
case "$HOOKS_JSON_INPUT" in
  /*) HOOKS_JSON_RESOLVED="$HOOKS_JSON_INPUT" ;;
  *)  HOOKS_JSON_RESOLVED="${REPO_ROOT}/${HOOKS_JSON_INPUT}" ;;
esac

PASS=0
FAIL=0
ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "== T-006 claude-bash-matcher tests =="
echo "REPO_ROOT:  ${REPO_ROOT}"
echo "HOOKS_JSON: ${HOOKS_JSON_RESOLVED}"
echo

if [ ! -f "$GUARD_JS" ]; then echo "FATAL: guard not found: $GUARD_JS" >&2; exit 3; fi
if [ ! -f "$GUARD_SH" ]; then echo "FATAL: dispatcher not found: $GUARD_SH" >&2; exit 3; fi
if [ ! -f "$HOOKS_JSON_RESOLVED" ]; then echo "FATAL: hooks config not found: $HOOKS_JSON_RESOLVED" >&2; exit 3; fi

# ---------------------------------------------------------------------------
# Bash-shaped payload corpus. The protected path is drawn from
# PROTECTED_GATE_SUFFIXES so the guard's R-10 write-target analysis applies.
# ---------------------------------------------------------------------------
PROT="plugins/sdd-quality-loop/scripts/sdd-hook-guard.py"
PAYLOAD_WRITE='{"tool_name":"Bash","tool_input":{"command":"rm '"$PROT"'"}}'
PAYLOAD_READ='{"tool_name":"Bash","tool_input":{"command":"grep -n foo '"$PROT"'"}}'
PAYLOAD_MISSING_INPUT='{"tool_name":"Bash"}'
PAYLOAD_NONJSON='this is not json'

# ---------------------------------------------------------------------------
# Guard invocation helpers. GCODE=exit code, GOUT=stdout.
#   guard_js: Claude path -- node runs the .js twin directly (this is what
#             claude-hooks.json routes Bash to after the fix). Payload via env.
#   guard_sh: Codex/Copilot path -- the sh dispatcher (hooks.json /
#             copilot-hooks.json) reads the payload on stdin, prefers python3
#             (.py twin), and falls back to PowerShell (.ps1).
# ---------------------------------------------------------------------------
guard_js() {
  local payload="$1" emit="${2:-exit}" tmp="${WORK}/js.out"
  GCODE=0
  PAYLOAD="$payload" node "$GUARD_JS" --emit "$emit" >"$tmp" 2>/dev/null || GCODE=$?
  GOUT="$(cat "$tmp" 2>/dev/null || true)"
}
guard_sh() {
  local payload="$1" emit="${2:-exit}" tmp="${WORK}/sh.out"
  GCODE=0
  printf '%s' "$payload" | bash "$GUARD_SH" --emit "$emit" >"$tmp" 2>/dev/null || GCODE=$?
  GOUT="$(cat "$tmp" 2>/dev/null || true)"
}

decision_of_code() {
  case "$1" in
    0) echo "allow" ;;
    2) echo "deny" ;;
    *) echo "error($1)" ;;
  esac
}
decision_of_copilot() {
  printf '%s' "$1" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get("permissionDecision", "missing"))
except Exception:
    print("parse-error")
'
}

# ===========================================================================
# (a) MATCHER COVERAGE -- reads $HOOKS_JSON; FAILS against the live file (RED).
# ===========================================================================
echo "-- (a) matcher coverage ($HOOKS_JSON_RESOLVED) --"

if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$HOOKS_JSON_RESOLVED" 2>/dev/null; then
  ok "claude-hooks.json is valid JSON"
else
  fail "claude-hooks.json is not valid JSON"
fi

# Extract the matcher of the PreToolUse entry whose hooks route to
# sdd-hook-guard (NOT the kill-switch entry).
MATCHER="$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
out = ""
for e in d.get("hooks", {}).get("PreToolUse", []):
    args = []
    for h in e.get("hooks", []):
        args += [str(a) for a in h.get("args", [])]
    if any("sdd-hook-guard" in a for a in args):
        out = e.get("matcher", "")
        break
print(out)
' "$HOOKS_JSON_RESOLVED" 2>/dev/null)"

if [ -n "$MATCHER" ]; then
  ok "extracted sdd-hook-guard matcher: ${MATCHER}"
else
  fail "could not extract sdd-hook-guard matcher"
fi

# a1: the tool name Bash must match the matcher as an anchored alternation.
#     This is the core issue #160 gap: the live matcher omits Bash.
if printf 'Bash' | grep -Eq "^(${MATCHER})\$"; then
  ok "matcher covers tool name Bash (anchored alternation)"
else
  fail "matcher does NOT cover tool name Bash (matcher='${MATCHER}')"
fi

# a2: existing file-tool coverage must be preserved.
for tool in Edit Write MultiEdit apply_patch; do
  if printf '%s' "$tool" | grep -Eq "^(${MATCHER})\$"; then
    ok "matcher still covers ${tool}"
  else
    fail "matcher no longer covers ${tool}"
  fi
done

# a3: kill-switch PreToolUse entry (matcher '*') must remain intact.
if python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
found = False
for e in d.get("hooks", {}).get("PreToolUse", []):
    args = []
    for h in e.get("hooks", []):
        args += [str(a) for a in h.get("args", [])]
    if e.get("matcher") == "*" and any("kill-switch" in a for a in args):
        found = True
sys.exit(0 if found else 1)
' "$HOOKS_JSON_RESOLVED" 2>/dev/null; then
  ok "kill-switch PreToolUse entry intact (matcher '*')"
else
  fail "kill-switch PreToolUse entry missing or altered"
fi

# ===========================================================================
# (b) GUARD DECISIONS -- drive the .js twin directly; independent of $HOOKS_JSON.
# ===========================================================================
echo "-- (b) guard decisions (Claude .js twin) --"

guard_js "$PAYLOAD_WRITE"
if [ "$GCODE" -eq 2 ]; then ok "Bash write to protected file -> deny (exit 2)"; else fail "Bash write to protected file -> deny (expected 2, got $GCODE)"; fi

guard_js "$PAYLOAD_READ"
if [ "$GCODE" -eq 0 ]; then ok "Bash read-only over protected path -> allow (exit 0)"; else fail "Bash read-only over protected path -> allow (expected 0, got $GCODE)"; fi

guard_js "$PAYLOAD_MISSING_INPUT"
if [ "$GCODE" -eq 2 ]; then ok "malformed Bash payload (missing tool_input) -> deny (exit 2)"; else fail "malformed Bash payload (missing tool_input) -> deny (expected 2, got $GCODE)"; fi

guard_js "$PAYLOAD_NONJSON"
if [ "$GCODE" -eq 2 ]; then ok "non-JSON payload -> deny (exit 2, fail-closed)"; else fail "non-JSON payload -> deny (expected 2, got $GCODE)"; fi

# ===========================================================================
# (c) CROSS-RUNTIME PARITY -- node .js vs sh dispatcher vs copilot emit.
# ===========================================================================
echo "-- (c) cross-runtime parity (Claude / Codex / Copilot) --"

parity_case() {
  local label="$1" payload="$2" expected="$3"
  local dj ds dc
  guard_js "$payload" "exit";    dj="$(decision_of_code "$GCODE")"
  guard_sh "$payload" "exit";    ds="$(decision_of_code "$GCODE")"
  guard_sh "$payload" "copilot"; dc="$(decision_of_copilot "$GOUT")"
  if [ "$dj" = "$expected" ] && [ "$ds" = "$expected" ] && [ "$dc" = "$expected" ]; then
    ok "parity[$label]: js=$dj sh=$ds copilot=$dc (all == $expected)"
  else
    fail "parity[$label]: js=$dj sh=$ds copilot=$dc (expected all=$expected)"
  fi
}

parity_case "write-deny"         "$PAYLOAD_WRITE"         "deny"
parity_case "read-allow"         "$PAYLOAD_READ"          "allow"
parity_case "missing-input-deny" "$PAYLOAD_MISSING_INPUT" "deny"
parity_case "nonjson-deny"       "$PAYLOAD_NONJSON"       "deny"

# ---------------------------------------------------------------------------
echo
echo "== summary: passed=${PASS} failed=${FAIL} =="
if [ "$FAIL" -gt 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
