#!/bin/sh
# T-010 (epic-189-a1-project-context, REQ-008, AC-023): TEST-023 --
# protected-write full-matrix deny for the four basenames REQ-007 registered.
#
# WHAT THIS PROVES
#   A write attempt against EACH of the four protected basenames, through
#   EVERY ONE of the 12 mutation surfaces design.md Test Strategy item 8
#   enumerates, is DENIED -- including under an ACTIVE, fixture-signed
#   SDD_SUDO token. 4 basenames x 12 surfaces x 2 sudo states = 96
#   independent assertions, never a per-basename spot check.
#
# HOW THE GUARD IS DRIVEN (no agent in the loop, CI-reproducible)
#   Each cell pipes a synthetic hook payload on stdin to the real guard
#   entry point and reads its exit status (0 = allow, 2 = deny), the same
#   mechanism tests/guards.tests.sh and tests/guard-r10-port.tests.ps1
#   already use. An agent observing its OWN tool call being blocked would
#   be evidence about the environment's hook, not about the guard's
#   decision function, and would not be reproducible in CI.
#
# WHY THE ASSERTIONS CANNOT PASS VACUOUSLY
#   The single largest risk for this task is a cell that "passes" for the
#   wrong reason -- e.g. a malformed payload denied by the payload
#   validator rather than by the protected-file rule, which would claim
#   protection that does not hold. Three structural defences:
#     PRE-*  preflight: the four basenames really are in the LIVE
#            inventory, the stripped fixture really lacks them, and the
#            fixture SDD_SUDO token really is ACTIVE (asserted via an
#            approval-increase payload that only an active token allows).
#            Without the last one, "sudo does not bypass" would pass
#            trivially against an inactive token.
#     MUT-*  detection power: the SAME 48 payloads, replayed against a
#            throwaway copy of the guard whose inventory has exactly the
#            four entries removed, must be ALLOWED. A cell that denies
#            there is denying for some other reason and is reported.
#     BASE-* pristine pair: the same 48 payloads against an UNMODIFIED
#            throwaway copy must still be DENIED, so MUT-* cannot pass
#            because the copying itself broke the guard.
#
# RED MODE
#   SDD_T010_SIMULATE_PRE_APPLY=1 runs the AC-023 block against the
#   stripped (pre-REQ-007-application) inventory instead of the live one.
#   Every one of the 96 cells then FAILS. That is this suite's Red
#   evidence; it is a fixture-only simulation and never touches the repo.
#
# SUPPLEMENTARY (explicitly OUTSIDE the 96; per the 2026-08-03 ruling)
#   SUPP-* asserts that the R-10 pre-filter (_command_references_protected
#   _path) also recognises the four basenames. That call site is
#   load-bearing for denial but is NOT one of design.md's 12 rows; the gap
#   is recorded in reports/notes/epic-189-a1-carryover-items.md. These
#   assertions are counted separately and are NOT part of AC-023's 96.
#
# Every scratch mutation happens under a mktemp directory. The repository
# working tree is never modified by this suite.
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/hook-guard-epic-a1-boundary.XXXXXX")
WORK=$(cd "$WORK" && pwd -P)
trap 'rm -rf "$WORK"' EXIT INT TERM

SCRIPTS_REL="plugins/sdd-quality-loop/scripts"
LIVE_SCRIPTS="$ROOT/$SCRIPTS_REL"
LIVE_GUARD="$LIVE_SCRIPTS/sdd-hook-guard.py"
INV_REL="generated/guard_invariants.py"

# The four basenames REQ-007 registered (design.md Test Strategy item 8).
BASENAMES="sdd/project-context.approval.json sdd/provider-bindings.approval.json sdd/approver-registry.yaml sdd/.hook-canary-sentinel"
SURFACES="01 02 03 04 05 06 07 08 09 10 11 12"
SUDO_KEY="t010-fixture-key-not-a-real-secret"

PASS=0
FAIL=0
AC_CELLS=0
MUT_CELLS=0
BASE_CELLS=0
pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

if command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  printf 'FAIL: no python3/python interpreter available (required to drive sdd-hook-guard.py)\n'
  printf 'PASS: 0\nFAIL: 1\n'
  exit 1
fi

PYTHONDONTWRITEBYTECODE=1
export PYTHONDONTWRITEBYTECODE

# ---------------------------------------------------------------------------
# Fixtures: guard trees (live / pristine copy / stripped copy)
# ---------------------------------------------------------------------------

PRISTINE_DIR="$WORK/guard-pristine"
STRIPPED_DIR="$WORK/guard-stripped"
cp -R "$LIVE_SCRIPTS" "$PRISTINE_DIR" || { printf 'FAIL: could not copy scripts tree\n'; exit 1; }
cp -R "$LIVE_SCRIPTS" "$STRIPPED_DIR" || { printf 'FAIL: could not copy scripts tree\n'; exit 1; }
rm -rf "$PRISTINE_DIR/__pycache__" "$STRIPPED_DIR/__pycache__"

# Remove exactly the four REQ-007 entries from the stripped copy's inventory.
STRIP_RC=0
"$PY" - "$STRIPPED_DIR/$INV_REL" $BASENAMES <<'PYEOF' || STRIP_RC=$?
import sys
path, entries = sys.argv[1], sys.argv[2:]
text = open(path, encoding="utf-8").read()
for entry in entries:
    needle = "'%s', " % entry
    if needle not in text:
        sys.stderr.write("strip: entry absent from fixture inventory: %s\n" % entry)
        raise SystemExit(3)
    text = text.replace(needle, "")
open(path, "w", encoding="utf-8").write(text)
PYEOF
if [ "$STRIP_RC" -ne 0 ]; then
  printf 'FAIL: could not build the stripped-inventory fixture (rc=%s)\n' "$STRIP_RC"
  printf 'PASS: %s\nFAIL: %s\n' "$PASS" "$((FAIL + 1))"
  exit 1
fi

# ---------------------------------------------------------------------------
# Fixtures: project roots (no sudo / active signed sudo token)
# ---------------------------------------------------------------------------

PROJ_PLAIN="$WORK/proj-plain"
PROJ_SUDO="$WORK/proj-sudo"
mkdir -p "$PROJ_PLAIN/sdd" "$PROJ_SUDO/sdd"

MINT_RC=0
"$PY" - "$PROJ_SUDO" "$SUDO_KEY" <<'PYEOF' || MINT_RC=$?
import hashlib, hmac, os, sys, time
project_dir, key = sys.argv[1], sys.argv[2]
repo = os.path.realpath(project_dir)
issuer, nonce = "t010-fixture@ci", "b" * 64
issued, expires = int(time.time()) - 60, int(time.time()) + 3600
canonical = "\n".join([issuer, nonce, repo, str(issued), str(expires)])
sig = hmac.new(key.encode(), canonical.encode(), hashlib.sha256).hexdigest()
open(os.path.join(project_dir, "SDD_SUDO"), "w", encoding="utf-8").write(
    "enabled-by: human via /sdd-sudo\nenabled-at: 2026-08-03T00:00:00Z\n"
    "issuer: %s\nnonce: %s\nrepo: %s\nissued-epoch: %d\nexpires-epoch: %d\n"
    "duration: 1h\nsig: %s\n" % (issuer, nonce, repo, issued, expires, sig)
)
PYEOF
if [ "$MINT_RC" -ne 0 ]; then
  printf 'FAIL: could not mint the fixture SDD_SUDO token (rc=%s)\n' "$MINT_RC"
  printf 'PASS: %s\nFAIL: %s\n' "$PASS" "$((FAIL + 1))"
  exit 1
fi

# ---------------------------------------------------------------------------
# Payload construction: design.md Test Strategy item 8's 12 surface rows
# ---------------------------------------------------------------------------
# $1 surface id, $2 repo-relative target, $3 bare basename, $4 absolute target.
payload_for() {
  case "$1" in
    01) printf '{"tool_name":"Bash","tool_input":{"command":"echo x > %s"}}' "$2" ;;
    02) printf '{"tool_name":"Bash","tool_input":{"command":"echo x >%s"}}' "$2" ;;
    03) printf '{"tool_name":"Bash","tool_input":{"command":"cp src.yaml %s"}}' "$2" ;;
    04) printf '{"tool_name":"Bash","tool_input":{"command":"rm %s"}}' "$2" ;;
    05) printf '{"tool_name":"Bash","tool_input":{"command":"cd /tmp && echo x > %s"}}' "$4" ;;
    06) printf '{"tool_name":"Bash","tool_input":{"command":"cd sdd && echo x > %s"}}' "$3" ;;
    07) printf '{"tool_name":"Bash","tool_input":{"command":"cd sdd && > %s"}}' "$3" ;;
    08) printf '{"tool_name":"Bash","tool_input":{"command":"cd sdd && echo x >%s"}}' "$3" ;;
    09) printf '{"tool_name":"Bash","tool_input":{"command":"cd sdd && cp x.yaml %s"}}' "$3" ;;
    10) printf '{"tool_name":"Bash","tool_input":{"command":"cd sdd && rm %s"}}' "$3" ;;
    11) printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}' "$2" ;;
    12) printf '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\\n*** Update File: %s\\n+x\\n*** End Patch"}}' "$2" ;;
    *)  printf 'UNKNOWN-SURFACE' ;;
  esac
}

surface_label() {
  case "$1" in
    01) printf 'detached-redirect' ;;
    02) printf 'attached-redirect' ;;
    03) printf 'cp/mv-dest' ;;
    04) printf 'tee/touch/rm' ;;
    05) printf 'cwd-absolute' ;;
    06) printf 'cwd-relative' ;;
    07) printf 'segment-detached-redirect' ;;
    08) printf 'segment-attached-redirect' ;;
    09) printf 'segment-cp/mv-dest' ;;
    10) printf 'segment-tee/touch/rm' ;;
    11) printf 'native-Edit/Write/MultiEdit' ;;
    12) printf 'apply_patch-envelope' ;;
    *)  printf 'unknown' ;;
  esac
}

# $1 guard path, $2 project dir, $3 payload, $4 sudo lane (0|1); echoes exit code.
guard_exit() {
  _code=0
  if [ "$4" = "1" ]; then
    printf '%s' "$3" | ( cd "$2" && CLAUDE_PROJECT_DIR="$2" SDD_SUDO_KEY="$SUDO_KEY" \
      "$PY" "$1" --emit exit >/dev/null 2>&1 ) || _code=$?
  else
    printf '%s' "$3" | ( cd "$2" && CLAUDE_PROJECT_DIR="$2" \
      "$PY" "$1" --emit exit >/dev/null 2>&1 ) || _code=$?
  fi
  printf '%s' "$_code"
}

# ---------------------------------------------------------------------------
# PRE-* preflight (not part of AC-023's 96)
# ---------------------------------------------------------------------------

for bn in $BASENAMES; do
  if grep -q "'$bn'" "$LIVE_SCRIPTS/$INV_REL"; then
    pass "PRE-live-inventory: $bn is registered in the LIVE generated inventory"
  else
    fail "PRE-live-inventory: $bn is MISSING from the LIVE generated inventory (REQ-007 not applied?)"
  fi
done

for bn in $BASENAMES; do
  if grep -q "'$bn'" "$STRIPPED_DIR/$INV_REL"; then
    fail "PRE-stripped-fixture: $bn should have been removed from the stripped fixture"
  else
    pass "PRE-stripped-fixture: $bn removed from the stripped fixture inventory"
  fi
done

# The fixture token must be genuinely ACTIVE, else every sudo-lane cell below
# would be proving nothing. An approval-increase payload is allowed ONLY when
# sudo is active, so it is a precise probe for token activation.
APPROVAL_PAYLOAD='{"tool_name":"Edit","tool_input":{"file_path":"specs/f/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'
rc=$(guard_exit "$LIVE_GUARD" "$PROJ_SUDO" "$APPROVAL_PAYLOAD" 1)
if [ "$rc" = "0" ]; then
  pass "PRE-sudo-active: fixture SDD_SUDO token is ACTIVE (approval-increase allowed)"
else
  fail "PRE-sudo-active: fixture SDD_SUDO token is NOT active (expected exit 0, got $rc) -- every sudo-lane cell would be vacuous"
fi
rc=$(guard_exit "$LIVE_GUARD" "$PROJ_PLAIN" "$APPROVAL_PAYLOAD" 0)
if [ "$rc" = "2" ]; then
  pass "PRE-sudo-inactive: no-token fixture leaves the approval guard enforcing (deny)"
else
  fail "PRE-sudo-inactive: expected exit 2 without a token, got $rc"
fi

# ---------------------------------------------------------------------------
# AC-023: the 96 cells (4 basenames x 12 surfaces x 2 sudo states)
# ---------------------------------------------------------------------------

AC_GUARD="$LIVE_GUARD"
AC_MODE="live post-application inventory"
if [ "${SDD_T010_SIMULATE_PRE_APPLY:-0}" = "1" ]; then
  AC_GUARD="$STRIPPED_DIR/sdd-hook-guard.py"
  AC_MODE="SIMULATED PRE-APPLICATION inventory (RED mode)"
fi
printf '\n--- AC-023 matrix: %s ---\n' "$AC_MODE"

for bn in $BASENAMES; do
  base=${bn##*/}
  for sf in $SURFACES; do
    for lane in 0 1; do
      if [ "$lane" = "1" ]; then
        proj="$PROJ_SUDO"; lane_label="sudo=ACTIVE"
      else
        proj="$PROJ_PLAIN"; lane_label="sudo=inactive"
      fi
      pl=$(payload_for "$sf" "$bn" "$base" "$proj/$bn")
      rc=$(guard_exit "$AC_GUARD" "$proj" "$pl" "$lane")
      AC_CELLS=$((AC_CELLS + 1))
      desc="AC-023 [$bn | surface $sf $(surface_label "$sf") | $lane_label] -> deny"
      if [ "$rc" = "2" ]; then
        pass "$desc"
      else
        fail "$desc (expected exit 2, got $rc)"
      fi
    done
  done
done

if [ "$AC_CELLS" -eq 96 ]; then
  pass "AC-023 exhaustiveness: all 96 matrix cells executed"
else
  fail "AC-023 exhaustiveness: expected 96 cells, executed $AC_CELLS"
fi

# ---------------------------------------------------------------------------
# BASE-* / MUT-*: pristine baseline paired with the inventory mutation
# ---------------------------------------------------------------------------
# The sudo axis is orthogonal to the inventory, so these two paired blocks
# run the sudo-inactive lane only (4 x 12 = 48 cells each).

printf '\n--- BASE-* pristine copy (must still deny) / MUT-* stripped copy (must allow) ---\n'
for bn in $BASENAMES; do
  base=${bn##*/}
  for sf in $SURFACES; do
    pl=$(payload_for "$sf" "$bn" "$base" "$PROJ_PLAIN/$bn")

    rc=$(guard_exit "$PRISTINE_DIR/sdd-hook-guard.py" "$PROJ_PLAIN" "$pl" 0)
    BASE_CELLS=$((BASE_CELLS + 1))
    if [ "$rc" = "2" ]; then
      pass "BASE [$bn | surface $sf] pristine copy still denies"
    else
      fail "BASE [$bn | surface $sf] pristine copy expected exit 2, got $rc (copy harness is unfaithful; MUT below would be meaningless)"
    fi

    rc=$(guard_exit "$STRIPPED_DIR/sdd-hook-guard.py" "$PROJ_PLAIN" "$pl" 0)
    MUT_CELLS=$((MUT_CELLS + 1))
    if [ "$rc" = "0" ]; then
      pass "MUT [$bn | surface $sf] de-registered basename is allowed (assertion has detection power)"
    else
      fail "MUT [$bn | surface $sf] expected exit 0 after de-registration, got $rc (the matching AC-023 cell may be denying for an unrelated reason)"
    fi
  done
done

if [ "$BASE_CELLS" -eq 48 ] && [ "$MUT_CELLS" -eq 48 ]; then
  pass "BASE/MUT exhaustiveness: 48 pristine + 48 mutated cells executed"
else
  fail "BASE/MUT exhaustiveness: expected 48/48, executed $BASE_CELLS/$MUT_CELLS"
fi

# ---------------------------------------------------------------------------
# SUPP-*: R-10 pre-filter (OUTSIDE AC-023's 96 -- see the header)
# ---------------------------------------------------------------------------

printf '\n--- SUPP-* R-10 pre-filter (supplementary; NOT counted in AC-023 96) ---\n'
for bn in $BASENAMES; do
  supp_rc=0
  "$PY" - "$LIVE_GUARD" "$bn" <<'PYEOF' >/dev/null 2>&1 || supp_rc=$?
import importlib.util, sys
guard_path, target = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("_t010_guard", guard_path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
raise SystemExit(0 if mod._command_references_protected_path("echo x > %s" % target) else 1)
PYEOF
  if [ "$supp_rc" -eq 0 ]; then
    pass "SUPP-prefilter: _command_references_protected_path recognises $bn"
  else
    fail "SUPP-prefilter: _command_references_protected_path does NOT recognise $bn (rc=$supp_rc)"
  fi
done

# ---------------------------------------------------------------------------
# WIN05-*: surface 05 with a NATIVE WINDOWS absolute target (STAGED candidate)
# ---------------------------------------------------------------------------
# Regression cover for the R-10 fail-open that CI run 31226882417 exposed on
# windows-latest: every surface-05 (cwd-absolute) AC-023 cell was ALLOWED
# (exit 0) instead of denied.
#
# On native Windows PowerShell's Join-Path emits the platform separator, so the
# suite's $absolute becomes "D:\...\sdd\approver-registry.yaml". That path (a)
# makes _tokenize_shell_command return None -- an unquoted backslash is an
# unmodeled construct -- and (b) does not contain the registry's POSIX-separator
# suffix "sdd/approver-registry.yaml", so the raw-substring fallback in
# _command_references_protected_path missed it and the pre-filter reported "no
# protected path". Only the separator immediately BEFORE the registered suffix
# mattered, which is why POSIX never saw it: Join-Path emits '/' there.
#
# The Windows path here is a hand-built literal, so these cells assert the same
# thing on every platform and reproduce the Windows failure on POSIX.
#
# These cells drive the STAGED candidate, because the live guard is R-10
# protected and cannot be modified by an agent. The live twins still carry the
# fail-open until a human runs specs/epic-189-a1-project-context/human-copy/
# RUNBOOK-pr229.md; the surface-05 cells in the AC-023 block above will only
# flip to green on real Windows CI after that apply.

printf '\n--- WIN05-* native-Windows absolute target (STAGED candidate) ---\n'

STAGED_SCRIPTS="$ROOT/specs/epic-189-a1-project-context/human-copy/$SCRIPTS_REL"
STAGED_GUARD="$STAGED_SCRIPTS/sdd-hook-guard.py"
# JSON-escaped (doubled) backslashes: the payload body must decode to single ones.
WIN_JSON_PREFIX='D:\\a\\sdd-forge\\sdd-forge\\proj-plain\\sdd\\'

if [ ! -f "$STAGED_GUARD" ]; then
  fail "WIN05-staged-present: staged candidate missing at $STAGED_GUARD"
else
  pass "WIN05-staged-present: staged candidate exists"

  # Detection-power pair: a copy of the STAGED tree with exactly the four
  # entries removed must ALLOW the same payloads. Without it, a cell could pass
  # because some unrelated rule denies every backslashed command.
  WIN05_STRIPPED="$WORK/guard-staged-stripped"
  cp -R "$STAGED_SCRIPTS" "$WIN05_STRIPPED" 2>/dev/null
  rm -rf "$WIN05_STRIPPED/__pycache__"
  WIN05_STRIP_RC=0
  "$PY" - "$WIN05_STRIPPED/$INV_REL" $BASENAMES <<'PYEOF' >/dev/null 2>&1 || WIN05_STRIP_RC=$?
import sys
path, entries = sys.argv[1], sys.argv[2:]
text = open(path, encoding="utf-8").read()
for entry in entries:
    needle = "'%s', " % entry
    if needle not in text:
        raise SystemExit(3)
    text = text.replace(needle, "")
open(path, "w", encoding="utf-8").write(text)
PYEOF
  if [ "$WIN05_STRIP_RC" -ne 0 ]; then
    fail "WIN05-strip-fixture: could not strip the staged inventory copy (rc=$WIN05_STRIP_RC)"
  else
    pass "WIN05-strip-fixture: staged inventory copy stripped of the four entries"
  fi

  for bn in $BASENAMES; do
    base=${bn##*/}
    pl=$(printf '{"tool_name":"Bash","tool_input":{"command":"cd /tmp && echo x > %s%s"}}' "$WIN_JSON_PREFIX" "$base")

    rc=$(guard_exit "$STAGED_GUARD" "$PROJ_PLAIN" "$pl" 0)
    if [ "$rc" = "2" ]; then
      pass "WIN05 [$bn] staged guard denies a native-Windows absolute write target"
    else
      fail "WIN05 [$bn] expected exit 2 from the staged guard, got $rc (R-10 fail-open on Windows-style paths)"
    fi

    rc=$(guard_exit "$STAGED_GUARD" "$PROJ_SUDO" "$pl" 1)
    if [ "$rc" = "2" ]; then
      pass "WIN05-sudo [$bn] staged guard denies it under an ACTIVE sudo token too"
    else
      fail "WIN05-sudo [$bn] expected exit 2 under active sudo, got $rc"
    fi

    rc=$(guard_exit "$WIN05_STRIPPED/sdd-hook-guard.py" "$PROJ_PLAIN" "$pl" 0)
    if [ "$rc" = "0" ]; then
      pass "WIN05-MUT [$bn] de-registered basename is allowed (assertion has detection power)"
    else
      fail "WIN05-MUT [$bn] expected exit 0 after de-registration, got $rc (WIN05 above may deny for an unrelated reason)"
    fi
  done

  # Controls: the widened scan must not deny more than it should.
  rc=$(guard_exit "$STAGED_GUARD" "$PROJ_PLAIN" \
    "$(printf '{"tool_name":"Bash","tool_input":{"command":"cd /tmp && echo x > %s/sdd/approver-registry.yaml"}}' "$PROJ_PLAIN")" 0)
  if [ "$rc" = "2" ]; then
    pass "WIN05-control-posix: staged guard still denies the POSIX-absolute equivalent"
  else
    fail "WIN05-control-posix: expected exit 2 for the POSIX path, got $rc (separator normalization replaced POSIX matching)"
  fi

  rc=$(guard_exit "$STAGED_GUARD" "$PROJ_PLAIN" \
    "$(printf '{"tool_name":"Bash","tool_input":{"command":"cat %sapprover-registry.yaml"}}' "$WIN_JSON_PREFIX")" 0)
  if [ "$rc" = "0" ]; then
    pass "WIN05-control-read: read-only access to a Windows-style protected path stays ALLOWED (issue #62)"
  else
    fail "WIN05-control-read: expected exit 0 for a read-only command, got $rc (over-denial)"
  fi

  rc=$(guard_exit "$STAGED_GUARD" "$PROJ_PLAIN" \
    "$(printf '{"tool_name":"Bash","tool_input":{"command":"cd /tmp && echo x > %snotes.txt"}}' "$WIN_JSON_PREFIX")" 0)
  if [ "$rc" = "0" ]; then
    pass "WIN05-control-unprotected: an unregistered Windows-style path stays ALLOWED (deny is suffix-specific, not backslash-specific)"
  else
    fail "WIN05-control-unprotected: expected exit 0 for an unregistered path, got $rc (over-denial: any backslash now denies)"
  fi
fi

# ---------------------------------------------------------------------------
# Self-registration
# ---------------------------------------------------------------------------

printf '\n--- self-registration ---\n'
if [ -f "$ROOT/tests/hook-guard-epic-a1-boundary.tests.ps1" ]; then
  pass "self-registration: PowerShell twin exists"
else
  fail "self-registration: PowerShell twin tests/hook-guard-epic-a1-boundary.tests.ps1 missing"
fi
for runner in run-all.sh run-all.ps1; do
  if grep -q "hook-guard-epic-a1-boundary.tests" "$ROOT/tests/$runner"; then
    pass "self-registration: registered in tests/$runner"
  else
    fail "self-registration: NOT registered in tests/$runner"
  fi
done

printf '\nPASS: %s\nFAIL: %s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
