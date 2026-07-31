#!/bin/sh
# T-007 (epic-189-a1-project-context, REQ-007): acceptance checks for
# plugins/sdd-quality-loop/scripts/apply-human-copy.sh -- the anchored-
# publisher-equivalent human-copy tool (design.md "Human-copy publisher
# transactional bundle contract"; AC-033/TEST-033, the task's single
# acceptance anchor).
#
# TEST-033 covers, each as an independent fixture (never one combined
# "denies bad input" case):
#   - pre-existing symlink/reparse-point denial at either held handle
#     (destination AND source sides, both the final leaf and an
#     intermediate segment)
#   - hard-link-alias non-propagation
#   - held-handle substitution resistance (destination-parent renamed
#     between validation and publish does not redirect the write)
#   - atomic-rename-only publish; live target unchanged on any
#     preparation-stage failure (staged-candidate hash mismatch)
#   - manifest shape validation
#   - multi-target journaled transaction crash recovery across all four
#     AC-033 injection points (before any rename; mid-batch; after the
#     last rename before journal delete; a SECOND crash injected during
#     recovery itself)
#   - journal shape-mismatch fail-closed (carry-forward obligation 2 --
#     never silently treated as "no journal")
#   - recovery no-op when nothing is stale
#
# This suite invokes the tool through apply-human-copy.sh directly (the
# real dispatcher surface -- there is no .py master for this task,
# design.md Components; T-007's own architecture constraint).
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/apply-human-copy-test.XXXXXX")
# Physical-path normalization (design.md Test Strategy item 12).
WORK=$(cd "$WORK" && pwd -P)
trap 'rm -rf "$WORK"' EXIT INT TERM

APPLY_SH="$ROOT/plugins/sdd-quality-loop/scripts/apply-human-copy.sh"
APPLY_PS1_FOR_PARITY="$ROOT/plugins/sdd-quality-loop/scripts/apply-human-copy.ps1"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$1" | awk '{print $1}'
  else
    shasum -a 256 -- "$1" | awk '{print $1}'
  fi
}

# ---------------------------------------------------------------------------
# Fixture helpers.
# ---------------------------------------------------------------------------

fixture_counter=0
# new_fixture_dir -- sets the global NEW_FIXTURE_DIR. NEVER call this via
# `F=$(new_fixture_dir)`: command substitution runs the function in a
# SUBSHELL, so `fixture_counter=$((fixture_counter + 1))` would silently
# mutate only the subshell's own copy and every call would collide on the
# same "f1" directory -- exactly the class of bug apply-human-copy.sh's
# own recover_all()/RECOVERED fix (its header comment references the
# incident) was written to avoid. Correct usage:
# `new_fixture_dir; F=$NEW_FIXTURE_DIR`.
new_fixture_dir() {
  fixture_counter=$((fixture_counter + 1))
  NEW_FIXTURE_DIR="$WORK/f$fixture_counter"
  mkdir -p "$NEW_FIXTURE_DIR/repo/sdd/.staging" "$NEW_FIXTURE_DIR/stage"
}

write_file() {
  # write_file <path> <content>
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" >"$1"
}

# manifest_line <stagedir> <relpath> -> "<hash>  <relpath>"
manifest_line() {
  h=$(sha256_of "$1/$2")
  printf '%s  %s\n' "$h" "$2"
}

# run_apply <repo_dir> [args...] -> runs the tool with cwd=repo_dir,
# capturing stdout/stderr to $WORK/out / $WORK/err, returns its exit code.
run_apply() {
  repo_dir=$1
  shift
  ( cd "$repo_dir" && "$APPLY_SH" "$@" ) >"$WORK/out" 2>"$WORK/err"
  return $?
}

category_of() {
  # category_of <file> -> extracts the "category":"..." value.
  sed -n 's/.*"category":"\([^"]*\)".*/\1/p' "$1" | head -1
}

# ===========================================================================
# TEST-033a: basic single-target publish (fresh live path, no pre-existing
# content) -- sanity precondition for everything below.
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/stage/plugins/x/file.txt" "candidate-v1"
manifest_line "$F/stage" "plugins/x/file.txt" >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
rc=$?
if [ "$rc" = 0 ]; then
  pass "TEST-033a fresh single-target publish: tool exits 0"
else
  fail "TEST-033a fresh single-target publish: tool exits 0 (got $rc; $(cat "$WORK/err"))"
fi
if [ "$(cat "$F/repo/plugins/x/file.txt" 2>/dev/null)" = "candidate-v1" ]; then
  pass "TEST-033a fresh single-target publish: live content matches candidate"
else
  fail "TEST-033a fresh single-target publish: live content matches candidate"
fi
if [ ! -e "$F/repo/sdd/.staging" ] || [ -z "$(find "$F/repo/sdd/.staging" -type f 2>/dev/null)" ]; then
  pass "TEST-033a fresh single-target publish: no journal/staging litter remains"
else
  fail "TEST-033a fresh single-target publish: no journal/staging litter remains"
fi

# ===========================================================================
# TEST-033b: publish over EXISTING live content (pre-hash is a real hash,
# not ABSENT) -- content is correctly replaced.
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/repo/plugins/x/file.txt" "old-content"
write_file "$F/stage/plugins/x/file.txt" "new-content"
manifest_line "$F/stage" "plugins/x/file.txt" >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
if [ "$(cat "$F/repo/plugins/x/file.txt")" = "new-content" ]; then
  pass "TEST-033b publish over existing live content: content replaced"
else
  fail "TEST-033b publish over existing live content: content replaced"
fi

# ===========================================================================
# TEST-033c: pre-existing symlink at the DESTINATION leaf is denied; the
# symlink's target (a canary file elsewhere) is never touched.
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/canary.txt" "untouched-canary"
mkdir -p "$F/repo/plugins/x"
ln -s "$F/canary.txt" "$F/repo/plugins/x/file.txt"
write_file "$F/stage/plugins/x/file.txt" "malicious"
manifest_line "$F/stage" "plugins/x/file.txt" >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
rc=$?
cat_val=$(category_of "$WORK/out")
if [ "$rc" != 0 ] && [ "$cat_val" = "RENAME_FAILED" -o "$cat_val" = "PRE_EXISTING_SYMLINK_DENIED" ]; then
  pass "TEST-033c pre-existing symlink at destination leaf denied (exit $rc, category $cat_val)"
else
  fail "TEST-033c pre-existing symlink at destination leaf denied (exit $rc, category $cat_val)"
fi
if [ "$(cat "$F/canary.txt")" = "untouched-canary" ]; then
  pass "TEST-033c symlink target (canary) is never written through"
else
  fail "TEST-033c symlink target (canary) is never written through"
fi
if [ -L "$F/repo/plugins/x/file.txt" ]; then
  pass "TEST-033c the pre-existing symlink itself is left in place, not silently replaced"
else
  fail "TEST-033c the pre-existing symlink itself is left in place, not silently replaced"
fi

# ===========================================================================
# TEST-033d: symlink at an INTERMEDIATE destination-parent segment is
# denied (denial at the held destination-parent handle, not just the leaf).
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
mkdir -p "$F/repo/plugins" "$F/elsewhere-dir"
write_file "$F/elsewhere-dir/untouched.txt" "elsewhere-canary"
ln -s "$F/elsewhere-dir" "$F/repo/plugins/x"
write_file "$F/stage/plugins/x/file.txt" "malicious2"
manifest_line "$F/stage" "plugins/x/file.txt" >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
rc=$?
if [ "$rc" != 0 ]; then
  pass "TEST-033d symlinked intermediate destination-parent segment denied (exit $rc)"
else
  fail "TEST-033d symlinked intermediate destination-parent segment denied (exit $rc)"
fi
if [ ! -e "$F/elsewhere-dir/file.txt" ]; then
  pass "TEST-033d write never redirected through the symlinked segment"
else
  fail "TEST-033d write never redirected through the symlinked segment"
fi

# ===========================================================================
# TEST-033e: the STAGED SOURCE candidate itself being a symlink is denied.
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/canary2.txt" "source-canary"
mkdir -p "$F/stage/plugins/x"
ln -s "$F/canary2.txt" "$F/stage/plugins/x/file.txt"
h=$(sha256_of "$F/canary2.txt")
printf '%s  plugins/x/file.txt\n' "$h" >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
rc=$?
if [ "$rc" != 0 ]; then
  pass "TEST-033e symlinked staged source candidate denied (exit $rc)"
else
  fail "TEST-033e symlinked staged source candidate denied (exit $rc)"
fi
if [ ! -e "$F/repo/plugins/x/file.txt" ]; then
  pass "TEST-033e no live target created from a symlinked source"
else
  fail "TEST-033e no live target created from a symlinked source"
fi

# ===========================================================================
# TEST-033f: hard-link-alias non-propagation.
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/repo/plugins/x/live.txt" "shared-old"
ln "$F/repo/plugins/x/live.txt" "$F/repo/plugins/x/alias.txt"
write_file "$F/stage/plugins/x/live.txt" "shared-new"
manifest_line "$F/stage" "plugins/x/live.txt" >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
if [ "$(cat "$F/repo/plugins/x/live.txt")" = "shared-new" ]; then
  pass "TEST-033f hard-link non-propagation: live target updated"
else
  fail "TEST-033f hard-link non-propagation: live target updated"
fi
if [ "$(cat "$F/repo/plugins/x/alias.txt")" = "shared-old" ]; then
  pass "TEST-033f hard-link non-propagation: alias name retains OLD bytes"
else
  fail "TEST-033f hard-link non-propagation: alias name retains OLD bytes"
fi

# ===========================================================================
# TEST-033g: staged-candidate hash mismatch (manifest disagrees with the
# actual staged bytes) is a preparation-stage failure -- live target
# unchanged, no rename ever attempted.
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/repo/plugins/x/file.txt" "untouched-live"
write_file "$F/stage/plugins/x/file.txt" "whatever"
printf '%s  plugins/x/file.txt\n' "0000000000000000000000000000000000000000000000000000000000000000" >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
rc=$?
cat_val=$(category_of "$WORK/out")
if [ "$rc" != 0 ] && [ "$cat_val" = "STAGED_CANDIDATE_HASH_MISMATCH" ]; then
  pass "TEST-033g staged-candidate hash mismatch denied (STAGED_CANDIDATE_HASH_MISMATCH)"
else
  fail "TEST-033g staged-candidate hash mismatch denied (exit $rc, category $cat_val)"
fi
if [ "$(cat "$F/repo/plugins/x/file.txt")" = "untouched-live" ]; then
  pass "TEST-033g live target unchanged on preparation-stage failure"
else
  fail "TEST-033g live target unchanged on preparation-stage failure"
fi

# ===========================================================================
# TEST-033h: manifest shape validation (MANIFEST_INVALID), several
# independent fixtures.
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/stage/plugins/x/file.txt" "x"
printf 'not-a-valid-manifest-line\n' >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
if [ $? != 0 ] && [ "$(category_of "$WORK/out")" = "MANIFEST_INVALID" ]; then
  pass "TEST-033h malformed manifest line rejected (MANIFEST_INVALID)"
else
  fail "TEST-033h malformed manifest line rejected (MANIFEST_INVALID)"
fi

new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/stage/plugins/x/file.txt" "x"
h=$(sha256_of "$F/stage/plugins/x/file.txt")
printf '%s  ../escape.txt\n' "$h" >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
if [ $? != 0 ] && [ "$(category_of "$WORK/out")" = "MANIFEST_INVALID" ]; then
  pass "TEST-033h traversal target path rejected (MANIFEST_INVALID)"
else
  fail "TEST-033h traversal target path rejected (MANIFEST_INVALID)"
fi

new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/stage/plugins/x/file.txt" "x"
h=$(sha256_of "$F/stage/plugins/x/file.txt")
printf '%s  plugins/x/file.txt\n%s  plugins/x/file.txt\n' "$h" "$h" >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
if [ $? != 0 ] && [ "$(category_of "$WORK/out")" = "MANIFEST_INVALID" ]; then
  pass "TEST-033h duplicate manifest target rejected (MANIFEST_INVALID)"
else
  fail "TEST-033h duplicate manifest target rejected (MANIFEST_INVALID)"
fi

# ===========================================================================
# TEST-033i: multi-target journaled transaction -- crash BEFORE any rename
# (right after the journal itself is durably written) recovers to
# ALL-PRE.
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/repo/plugins/x/a.txt" "old-a"
write_file "$F/repo/plugins/x/b.txt" "old-b"
write_file "$F/stage/plugins/x/a.txt" "new-a"
write_file "$F/stage/plugins/x/b.txt" "new-b"
{
  manifest_line "$F/stage" "plugins/x/a.txt"
  manifest_line "$F/stage" "plugins/x/b.txt"
} >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256" --simulate-crash-after journal-write
if [ "$(cat "$F/repo/plugins/x/a.txt")" = "old-a" ] && [ "$(cat "$F/repo/plugins/x/b.txt")" = "old-b" ]; then
  pass "TEST-033i crash before any rename: both targets still PRE immediately after the crash"
else
  fail "TEST-033i crash before any rename: both targets still PRE immediately after the crash"
fi
run_apply "$F/repo"
if [ "$(cat "$F/repo/plugins/x/a.txt")" = "old-a" ] && [ "$(cat "$F/repo/plugins/x/b.txt")" = "old-b" ]; then
  pass "TEST-033i recovery converges to ALL-PRE (crash before any rename)"
else
  fail "TEST-033i recovery converges to ALL-PRE (crash before any rename)"
fi
if [ -z "$(find "$F/repo/sdd/.staging" -type f 2>/dev/null)" ]; then
  pass "TEST-033i stale journal cleaned up after recovery"
else
  fail "TEST-033i stale journal cleaned up after recovery"
fi

# ===========================================================================
# TEST-033j: multi-target journaled transaction -- crash MID-BATCH (after
# the first of two renames) recovers to ALL-PRE (the already-committed
# target is rolled back).
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/repo/plugins/x/a.txt" "old-a"
write_file "$F/repo/plugins/x/b.txt" "old-b"
write_file "$F/stage/plugins/x/a.txt" "new-a"
write_file "$F/stage/plugins/x/b.txt" "new-b"
{
  manifest_line "$F/stage" "plugins/x/a.txt"
  manifest_line "$F/stage" "plugins/x/b.txt"
} >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256" --simulate-crash-after rename-1
if [ "$(cat "$F/repo/plugins/x/a.txt")" = "new-a" ] && [ "$(cat "$F/repo/plugins/x/b.txt")" = "old-b" ]; then
  pass "TEST-033j mid-batch crash leaves an observable partial state right after the crash (a advanced, b not)"
else
  fail "TEST-033j mid-batch crash leaves an observable partial state right after the crash (a advanced, b not)"
fi
run_apply "$F/repo"
if [ "$(cat "$F/repo/plugins/x/a.txt")" = "old-a" ] && [ "$(cat "$F/repo/plugins/x/b.txt")" = "old-b" ]; then
  pass "TEST-033j recovery converges to ALL-PRE (mid-batch crash rolled back)"
else
  fail "TEST-033j recovery converges to ALL-PRE (mid-batch crash rolled back)"
fi

# ===========================================================================
# TEST-033k: multi-target journaled transaction -- crash AFTER the last
# rename but BEFORE journal deletion recovers to ALL-POST.
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/repo/plugins/x/a.txt" "old-a"
write_file "$F/repo/plugins/x/b.txt" "old-b"
write_file "$F/stage/plugins/x/a.txt" "new-a"
write_file "$F/stage/plugins/x/b.txt" "new-b"
{
  manifest_line "$F/stage" "plugins/x/a.txt"
  manifest_line "$F/stage" "plugins/x/b.txt"
} >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256" --simulate-crash-after rename-2
run_apply "$F/repo"
if [ "$(cat "$F/repo/plugins/x/a.txt")" = "new-a" ] && [ "$(cat "$F/repo/plugins/x/b.txt")" = "new-b" ]; then
  pass "TEST-033k recovery converges to ALL-POST (crash after last rename, before journal delete)"
else
  fail "TEST-033k recovery converges to ALL-POST (crash after last rename, before journal delete)"
fi
if [ -z "$(find "$F/repo/sdd/.staging" -type f 2>/dev/null)" ]; then
  pass "TEST-033k journal removed once recovery confirms ALL-POST"
else
  fail "TEST-033k journal removed once recovery confirms ALL-POST"
fi

# ===========================================================================
# TEST-033l: a SECOND crash injected DURING recovery itself still
# converges correctly on the FOLLOWING invocation (recovery idempotence).
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/repo/plugins/x/a.txt" "old-a"
write_file "$F/repo/plugins/x/b.txt" "old-b"
write_file "$F/repo/plugins/x/c.txt" "old-c"
write_file "$F/stage/plugins/x/a.txt" "new-a"
write_file "$F/stage/plugins/x/b.txt" "new-b"
write_file "$F/stage/plugins/x/c.txt" "new-c"
{
  manifest_line "$F/stage" "plugins/x/a.txt"
  manifest_line "$F/stage" "plugins/x/b.txt"
  manifest_line "$F/stage" "plugins/x/c.txt"
} >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256" --simulate-crash-after rename-2
run_apply "$F/repo" --simulate-crash-during-recovery-after revert-1
if [ "$(cat "$F/repo/plugins/x/a.txt")" = "old-a" ] && [ "$(cat "$F/repo/plugins/x/b.txt")" = "new-b" ] && [ "$(cat "$F/repo/plugins/x/c.txt")" = "old-c" ]; then
  pass "TEST-033l a second crash mid-recovery leaves an observable partial-recovery state"
else
  fail "TEST-033l a second crash mid-recovery leaves an observable partial-recovery state"
fi
run_apply "$F/repo"
if [ "$(cat "$F/repo/plugins/x/a.txt")" = "old-a" ] && [ "$(cat "$F/repo/plugins/x/b.txt")" = "old-b" ] && [ "$(cat "$F/repo/plugins/x/c.txt")" = "old-c" ]; then
  pass "TEST-033l the FOLLOWING invocation still converges to ALL-PRE (recovery is idempotent/re-entrant)"
else
  fail "TEST-033l the FOLLOWING invocation still converges to ALL-PRE (recovery is idempotent/re-entrant)"
fi
if [ -z "$(find "$F/repo/sdd/.staging" -type f 2>/dev/null)" ]; then
  pass "TEST-033l journal fully cleaned up after the second recovery invocation"
else
  fail "TEST-033l journal fully cleaned up after the second recovery invocation"
fi

# ===========================================================================
# TEST-033m: a journal that is valid JSON but does NOT conform to the
# required targets[]={live_path,pre_hash,post_hash} shape is REJECTED
# (fail-closed), never silently treated as "no journal" (carry-forward
# obligation 2).
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
mkdir -p "$F/repo/sdd/.staging/badbatch"
printf '{"schema":"x","status":"in-progress"}\n' >"$F/repo/sdd/.staging/badbatch/TRANSACTION.json"
run_apply "$F/repo"
rc=$?
cat_val=$(category_of "$WORK/out")
if [ "$rc" != 0 ] && [ "$cat_val" = "JOURNAL_SHAPE_INVALID" ]; then
  pass "TEST-033m shape-mismatched journal (missing targets[]) is REJECTED, not silently ignored (JOURNAL_SHAPE_INVALID)"
else
  fail "TEST-033m shape-mismatched journal (missing targets[]) is REJECTED, not silently ignored (exit $rc, category $cat_val)"
fi
if [ -f "$F/repo/sdd/.staging/badbatch/TRANSACTION.json" ]; then
  pass "TEST-033m the malformed journal is left in place for human inspection, not deleted"
else
  fail "TEST-033m the malformed journal is left in place for human inspection, not deleted"
fi

new_fixture_dir; F=$NEW_FIXTURE_DIR
mkdir -p "$F/repo/sdd/.staging/badbatch2"
printf 'not even json\n' >"$F/repo/sdd/.staging/badbatch2/TRANSACTION.json"
run_apply "$F/repo"
if [ $? != 0 ] && [ "$(category_of "$WORK/out")" = "JOURNAL_SHAPE_INVALID" ]; then
  pass "TEST-033m an unparsable (non-JSON) journal is ALSO fail-closed, identically to a shape mismatch"
else
  fail "TEST-033m an unparsable (non-JSON) journal is ALSO fail-closed, identically to a shape mismatch"
fi

# ===========================================================================
# TEST-033n: recovery is a safe no-op when nothing is stale.
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
run_apply "$F/repo"
if [ $? = 0 ]; then
  pass "TEST-033n recovery-only invocation with nothing stale exits 0"
else
  fail "TEST-033n recovery-only invocation with nothing stale exits 0"
fi
if grep -q '"recovered":0' "$WORK/out"; then
  pass "TEST-033n recovery-only invocation reports recovered:0"
else
  fail "TEST-033n recovery-only invocation reports recovered:0"
fi

# ===========================================================================
# TEST-033o: held-handle substitution resistance -- renaming the
# destination-parent directory aside between validation/anchoring and the
# actual write does NOT redirect the copy: the write still lands in the
# TRUE original (now differently-named) directory, never in the newly
# substituted one at the original path.
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/repo/plugins/x/file.txt" "old-content"
write_file "$F/stage/plugins/x/file.txt" "new-content"
manifest_line "$F/stage" "plugins/x/file.txt" >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256" --simulate-substitution
if [ $? = 0 ]; then
  pass "TEST-033o substitution-resistance fixture: tool still completes successfully"
else
  fail "TEST-033o substitution-resistance fixture: tool still completes successfully"
fi
if [ ! -e "$F/repo/plugins/x/file.txt" ] || [ ! -s "$F/repo/plugins/x/file.txt" ]; then
  pass "TEST-033o the newly-substituted directory at the ORIGINAL name never receives the candidate"
else
  fail "TEST-033o the newly-substituted directory at the ORIGINAL name never receives the candidate"
fi
if [ "$(cat "$F/repo/plugins/x.attacker-moved/file.txt" 2>/dev/null)" = "new-content" ]; then
  pass "TEST-033o the write lands in the TRUE, anchored original directory (now at its new name)"
else
  fail "TEST-033o the write lands in the TRUE, anchored original directory (now at its new name)"
fi

# ===========================================================================
# TEST-033p (quality-gate seq0357 Critical remedy): a batch containing a
# PRE-EXISTING, LEGITIMATELY ZERO-BYTE live target must still converge to
# ALL-PRE after a mid-batch crash, and the publisher must remain usable
# afterward (the original bug permanently bricked it: `[ ! -s ... ] &&
# rm -f` deleted the zero-byte backup, so revert_one_target could never
# find it, exit 17 RECOVERY_FAILED forever).
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/repo/plugins/x/b.txt" "old-b"
: >"$F/repo/plugins/x/a.txt"
write_file "$F/stage/plugins/x/a.txt" "new-a"
write_file "$F/stage/plugins/x/b.txt" "new-b"
{
  manifest_line "$F/stage" "plugins/x/a.txt"
  manifest_line "$F/stage" "plugins/x/b.txt"
} >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256" --simulate-crash-after rename-1
run_apply "$F/repo"
rc=$?
if [ "$rc" = 0 ] && [ ! -s "$F/repo/plugins/x/a.txt" ] && [ "$(cat "$F/repo/plugins/x/b.txt")" = "old-b" ]; then
  pass "TEST-033p zero-byte live target survives mid-batch crash + recovery, converging ALL-PRE (exit 0)"
else
  fail "TEST-033p zero-byte live target survives mid-batch crash + recovery, converging ALL-PRE (exit $rc; a-size=$(wc -c <"$F/repo/plugins/x/a.txt" 2>/dev/null); b=$(cat "$F/repo/plugins/x/b.txt" 2>/dev/null))"
fi
write_file "$F/stage/plugins/x/a.txt" "newer-a"
manifest_line "$F/stage" "plugins/x/a.txt" >"$F/stage/MANIFEST2.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST2.sha256"
rc=$?
if [ "$rc" = 0 ] && [ "$(cat "$F/repo/plugins/x/a.txt")" = "newer-a" ]; then
  pass "TEST-033p the publisher remains usable afterward (a subsequent legitimate publish succeeds, not permanently bricked)"
else
  fail "TEST-033p the publisher remains usable afterward (exit $rc)"
fi

# ===========================================================================
# TEST-033q (quality-gate seq0357 Major #1 remedy): two targets sharing a
# basename in different directories within the SAME batch are refused at
# manifest-parse time (DUPLICATE_BASENAME_IN_BATCH), never silently
# colliding on a single `pre/<basename>` backup slot.
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/repo/dir1/same.txt" "old-1"
write_file "$F/repo/dir2/same.txt" "old-2"
write_file "$F/stage/dir1/same.txt" "new-1"
write_file "$F/stage/dir2/same.txt" "new-2"
{
  manifest_line "$F/stage" "dir1/same.txt"
  manifest_line "$F/stage" "dir2/same.txt"
} >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
rc=$?
cat_val=$(category_of "$WORK/out")
if [ "$rc" != 0 ] && [ "$cat_val" = "DUPLICATE_BASENAME_IN_BATCH" ]; then
  pass "TEST-033q duplicate-basename batch rejected (DUPLICATE_BASENAME_IN_BATCH)"
else
  fail "TEST-033q duplicate-basename batch rejected (exit $rc, category $cat_val)"
fi
if [ "$(cat "$F/repo/dir1/same.txt")" = "old-1" ] && [ "$(cat "$F/repo/dir2/same.txt")" = "old-2" ]; then
  pass "TEST-033q both live targets unchanged (refused before any live mutation)"
else
  fail "TEST-033q both live targets unchanged (refused before any live mutation)"
fi

# ===========================================================================
# TEST-033r (quality-gate seq0357 Major #3 remedy): the sh and ps1
# journal writers emit BYTE-IDENTICAL-AT-THE-HEADER, BOM-less UTF-8 --
# both must be parseable by a plain `python3 json.load`, discharging
# carry-forward obligation 1's "no silent divergence" against T-005's
# Python reader for real, not merely by key-name inspection. Skips
# gracefully (never fails) if pwsh or python3 is unavailable in this
# environment, matching this repo's established capability non-use
# declaration convention.
# ===========================================================================
if command -v pwsh >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  new_fixture_dir; F=$NEW_FIXTURE_DIR
  mkdir -p "$F/repo2/sdd/.staging" "$F/repo2/plugins/x"
  write_file "$F/stage/plugins/x/a.txt" "cross-runtime-a"
  manifest_line "$F/stage" "plugins/x/a.txt" >"$F/stage/MANIFEST.sha256"
  run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256" --simulate-crash-after journal-write
  ( cd "$F/repo2" && pwsh -NoProfile -ExecutionPolicy Bypass -File "$APPLY_PS1_FOR_PARITY" -StagingDir "$F/stage" -Manifest "$F/stage/MANIFEST.sha256" -SimulateCrashAfter journal-write ) >/dev/null 2>&1
  SHJ=$(find "$F/repo/sdd/.staging" -name TRANSACTION.json 2>/dev/null | head -1)
  PSJ=$(find "$F/repo2/sdd/.staging" -name TRANSACTION.json 2>/dev/null | head -1)
  if [ -n "$SHJ" ] && [ -n "$PSJ" ]; then
    SH3=$(head -c 3 "$SHJ" | od -An -tx1 | tr -d ' \n')
    PS3=$(head -c 3 "$PSJ" | od -An -tx1 | tr -d ' \n')
    if [ "$SH3" = "$PS3" ]; then
      pass "TEST-033r sh and ps1 journals have IDENTICAL leading 3 bytes (no BOM divergence, got $SH3)"
    else
      fail "TEST-033r sh and ps1 journals have IDENTICAL leading 3 bytes (sh=$SH3 ps1=$PS3)"
    fi
    if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$SHJ" 2>/dev/null; then
      pass "TEST-033r sh journal parses via plain python3 json.load"
    else
      fail "TEST-033r sh journal parses via plain python3 json.load"
    fi
    if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$PSJ" 2>/dev/null; then
      pass "TEST-033r ps1 journal parses via plain python3 json.load (no utf-8-sig needed)"
    else
      fail "TEST-033r ps1 journal parses via plain python3 json.load (no utf-8-sig needed)"
    fi
  else
    fail "TEST-033r both sh and ps1 journals must exist for comparison (sh=$SHJ ps1=$PSJ)"
  fi
else
  pass "TEST-033r sh/ps1 journal BOM parity (skipped: pwsh or python3 not available in this environment)"
fi

# ===========================================================================
# TEST-033s (quality-gate seq0358 Major remedy): a manifest target path
# containing WHITESPACE (embedded space, tab, and -- via a two-target
# batch -- a path that is a space-joined "substring" of another target's
# path, the exact class that broke the PRIOR duplicate-path/basename
# detection) is handled correctly end-to-end: parsed, published, journaled
# with a byte-accurate live_path and exactly one hash per hash field,
# survives a mid-batch crash + recovery convergence, and is never
# misclassified as a duplicate of an unrelated target.
# ===========================================================================

# (a) basic publish + journal byte-accuracy for an embedded-space path.
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/repo/live/d/a b.txt" "old content"
write_file "$F/stage/live/d/a b.txt" "new content"
manifest_line "$F/stage" "live/d/a b.txt" >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
rc=$?
if [ "$rc" = 0 ] && [ "$(cat "$F/repo/live/d/a b.txt")" = "new content" ]; then
  pass "TEST-033s embedded-space path publishes correctly (exit 0, correct content)"
else
  fail "TEST-033s embedded-space path publishes correctly (exit $rc; content=$(cat "$F/repo/live/d/a b.txt" 2>/dev/null))"
fi

# (b) mid-batch crash with an embedded-space path -- journal byte-accuracy
# (live_path preserves the space; each hash field is EXACTLY one 64-hex
# value, never two concatenated) + recovery convergence.
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/repo/live/d/a b.txt" "old content"
write_file "$F/repo/live/d/c.txt" "old-c"
write_file "$F/stage/live/d/a b.txt" "new content"
write_file "$F/stage/live/d/c.txt" "new-c"
{
  manifest_line "$F/stage" "live/d/a b.txt"
  manifest_line "$F/stage" "live/d/c.txt"
} >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256" --simulate-crash-after rename-1
JF=$(find "$F/repo/sdd/.staging" -name TRANSACTION.json 2>/dev/null | head -1)
if [ -n "$JF" ] && grep -qF '"live_path":"live/d/a b.txt"' "$JF"; then
  pass "TEST-033s journal preserves the embedded-space live_path byte-exact"
else
  fail "TEST-033s journal preserves the embedded-space live_path byte-exact (journal: $(cat "$JF" 2>/dev/null))"
fi
if [ -n "$JF" ] && command -v python3 >/dev/null 2>&1; then
  if python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
t = [x for x in d['targets'] if x['live_path'] == 'live/d/a b.txt'][0]
import re
assert re.fullmatch(r'[0-9a-f]{64}', t['pre_hash']), t['pre_hash']
assert re.fullmatch(r'[0-9a-f]{64}', t['post_hash']), t['post_hash']
" "$JF" 2>/dev/null; then
    pass "TEST-033s journal's pre_hash/post_hash for the space-containing target are each EXACTLY one 64-hex value (never concatenated)"
  else
    fail "TEST-033s journal hash fields are single, well-formed 64-hex values"
  fi
else
  pass "TEST-033s journal hash-field shape check (skipped: python3 not available)"
fi
run_apply "$F/repo"
rc=$?
if [ "$rc" = 0 ] && [ "$(cat "$F/repo/live/d/a b.txt")" = "old content" ] && [ "$(cat "$F/repo/live/d/c.txt")" = "old-c" ]; then
  pass "TEST-033s mid-batch crash with an embedded-space target converges to ALL-PRE on recovery"
else
  fail "TEST-033s mid-batch crash with an embedded-space target converges to ALL-PRE (exit $rc)"
fi

# (c) the false-positive class the PRIOR space-joined duplicate-detection
# scheme was vulnerable to: target "b.txt" must NOT be flagged as a
# duplicate merely because an EARLIER target's path is "a b.txt" (whose
# space-joined representation contains " b.txt " as a literal substring).
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/stage/live/a b.txt" "content-ab"
write_file "$F/stage/live/b.txt" "content-b"
{
  manifest_line "$F/stage" "live/a b.txt"
  manifest_line "$F/stage" "live/b.txt"
} >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
rc=$?
if [ "$rc" = 0 ] && [ "$(cat "$F/repo/live/a b.txt")" = "content-ab" ] && [ "$(cat "$F/repo/live/b.txt")" = "content-b" ]; then
  pass "TEST-033s 'b.txt' is never false-positive-flagged as a duplicate of 'a b.txt' (both publish correctly)"
else
  fail "TEST-033s no false-positive duplicate-path rejection for space-containing paths (exit $rc)"
fi

# (d) genuine duplicate detection still fires correctly (regression lock
# for the grep-based rewrite): exact duplicate path, and duplicate
# basename in different directories.
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/stage/live/x.txt" "c"
h=$(sha256_of "$F/stage/live/x.txt")
printf '%s  live/x.txt\n%s  live/x.txt\n' "$h" "$h" >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
if [ $? != 0 ] && [ "$(category_of "$WORK/out")" = "MANIFEST_INVALID" ]; then
  pass "TEST-033s genuine duplicate-path rejection still fires (regression lock on the grep-based rewrite)"
else
  fail "TEST-033s genuine duplicate-path rejection still fires"
fi

# (e) tab character and leading/trailing whitespace within a path are
# preserved end-to-end (adjacent whitespace classes, quality-gate
# seq0358's explicit "pin these too" guidance).
new_fixture_dir; F=$NEW_FIXTURE_DIR
tab_path="live/a$(printf '\t')b.txt"
write_file "$F/stage/$tab_path" "tab-content"
manifest_line "$F/stage" "$tab_path" >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
if [ $? = 0 ] && [ "$(cat "$F/repo/$tab_path" 2>/dev/null)" = "tab-content" ]; then
  pass "TEST-033s a tab character embedded in a path is preserved end-to-end"
else
  fail "TEST-033s a tab character embedded in a path is preserved end-to-end"
fi

# ===========================================================================
# TEST-033t (quality-gate seq0359 CLASS-ELIMINATION mandate): a hostile-
# path PROPERTY MATRIX -- for each of the required character classes,
# drives publish -> mid-batch crash -> recovery convergence -> journal
# byte round-trip (python3 json.load + exact live_path match) -> a
# faithful T-005-reader surrogate query, for BOTH runtimes, plus a direct
# sh-vs-ps1 parity check on the published bytes. This is a MACHINE-DRIVEN
# fixture matrix (one small function, invoked once per class), not
# scattered ad hoc cases, per the coordinator's explicit remedy mandate
# after three consecutive same-class regressions (round 1: byte-count
# heuristic; round 2: `read`-based IFS field-splitting; round 3: a
# non-JSON-aware hand-rolled parser AND unquoted pathname expansion).
# ===========================================================================

hostile_matrix_case() {
  # hostile_matrix_case <label> <basename-fragment>
  label=$1
  frag=$2
  new_fixture_dir; F=$NEW_FIXTURE_DIR
  relpath="hostile/${frag}"
  write_file "$F/repo/hostile/zz.txt" "old-z"
  write_file "$F/stage/$relpath" "new-$label"
  write_file "$F/stage/hostile/zz.txt" "new-z"
  {
    manifest_line "$F/stage" "$relpath"
    manifest_line "$F/stage" "hostile/zz.txt"
  } >"$F/stage/MANIFEST.sha256"

  # (1) publish, with a mid-batch crash between the two renames.
  run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256" --simulate-crash-after rename-1
  JF=$(find "$F/repo/sdd/.staging" -name TRANSACTION.json 2>/dev/null | head -1)

  # (2) journal byte round-trip: parses via plain python3 json.load, and
  # live_path matches the declared path EXACTLY (obligation 1's real
  # contract, not merely "some journal exists").
  if [ -n "$JF" ] && command -v python3 >/dev/null 2>&1; then
    if python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
paths = [t['live_path'] for t in d['targets']]
assert sys.argv[2] in paths, (sys.argv[2], paths)
" "$JF" "$relpath" 2>/dev/null; then
      pass "TEST-033t [$label] journal round-trips live_path exactly via plain python3 json.load"
    else
      fail "TEST-033t [$label] journal round-trips live_path exactly via plain python3 json.load"
    fi
    # (3) T-005-reader surrogate: the SAME glob+json.load+live_path
    # membership check detect-policy-weakening.py's own
    # _check_no_publish_in_progress performs, against the path actually
    # mid-publish -- must report IN-PROGRESS (fail-closed), never a
    # false negative on a different, wrongly-decoded path.
    if ( cd "$F/repo" && python3 -c "
import json, glob, sys
found = False
for jf in glob.glob('sdd/.staging/*/TRANSACTION.json'):
    d = json.load(open(jf))
    if sys.argv[1] in [t['live_path'] for t in d['targets']]:
        found = True
sys.exit(0 if found else 1)
" "$relpath" ); then
      pass "TEST-033t [$label] T-005-reader surrogate correctly reports IN-PROGRESS for the mid-publish path"
    else
      fail "TEST-033t [$label] T-005-reader surrogate correctly reports IN-PROGRESS for the mid-publish path"
    fi
  else
    pass "TEST-033t [$label] journal round-trip + T-005 surrogate (skipped: python3 not available)"
    pass "TEST-033t [$label] journal round-trip + T-005 surrogate (skipped: python3 not available)"
  fi

  # (4) recovery converges ALL-PRE, and the publisher is not bricked
  # afterward (a second, unrelated publish still succeeds).
  run_apply "$F/repo"
  rc=$?
  if [ "$rc" = 0 ] && [ ! -e "$F/repo/$relpath" ] && [ "$(cat "$F/repo/hostile/zz.txt")" = "old-z" ]; then
    pass "TEST-033t [$label] recovery converges ALL-PRE (target absent, sibling unchanged)"
  else
    fail "TEST-033t [$label] recovery converges ALL-PRE (exit $rc)"
  fi
  if [ -z "$(find "$F/repo/sdd/.staging" -type f 2>/dev/null)" ]; then
    pass "TEST-033t [$label] no journal/staging litter remains after recovery"
  else
    fail "TEST-033t [$label] no journal/staging litter remains after recovery"
  fi

  # (5) sh vs ps1 parity, on a FRESH, non-crashed publish of the same path.
  if command -v pwsh >/dev/null 2>&1; then
    new_fixture_dir; F2=$NEW_FIXTURE_DIR
    write_file "$F2/stage/$relpath" "parity-$label"
    manifest_line "$F2/stage" "$relpath" >"$F2/stage/MANIFEST.sha256"
    mkdir -p "$F2/repo2/sdd/.staging"
    run_apply "$F2/repo" --staging-dir "$F2/stage" --manifest "$F2/stage/MANIFEST.sha256"
    sh_rc=$?
    ( cd "$F2/repo2" && pwsh -NoProfile -ExecutionPolicy Bypass -File "$APPLY_PS1_FOR_PARITY" -StagingDir "$F2/stage" -Manifest "$F2/stage/MANIFEST.sha256" ) >/dev/null 2>&1
    ps1_rc=$?
    sh_content=$(cat "$F2/repo/$relpath" 2>/dev/null)
    ps1_content=$(cat "$F2/repo2/$relpath" 2>/dev/null)
    if [ "$sh_rc" = 0 ] && [ "$ps1_rc" = 0 ] && [ "$sh_content" = "parity-$label" ] && [ "$ps1_content" = "parity-$label" ]; then
      pass "TEST-033t [$label] sh/ps1 parity: both publish identically (exit 0, same content, same declared path)"
    else
      fail "TEST-033t [$label] sh/ps1 parity (sh_rc=$sh_rc ps1_rc=$ps1_rc sh='$sh_content' ps1='$ps1_content')"
    fi
  else
    pass "TEST-033t [$label] sh/ps1 parity (skipped: pwsh not available)"
  fi
}

# The required character-class matrix (space/tab/leading-trailing already
# have dedicated TEST-033s coverage; included again here for the FULL
# machine-driven matrix's own completeness per the mandate). Backslash is
# DELIBERATELY EXCLUDED from this success-path matrix -- see the
# dedicated UNSUPPORTED_PATH_CHARACTER rejection test below instead.
hostile_matrix_case space 'sp ace.txt'
hostile_matrix_case tab "ta$(printf '\t')b.txt"
hostile_matrix_case leadtrail ' lead-trail '
hostile_matrix_case dquote 'qu"ote.txt'
hostile_matrix_case obrace 'o{pen.txt'
hostile_matrix_case cbrace 'c}lose.txt'
hostile_matrix_case comma 'com,ma.txt'
hostile_matrix_case star 'st*ar.txt'
hostile_matrix_case question 'que?stion.txt'
hostile_matrix_case obracket 'ob[racket.txt'
hostile_matrix_case cbracket 'cb]racket.txt'
hostile_matrix_case dollar 'do$llar.txt'
hostile_matrix_case backtick 'back`tick.txt'
hostile_matrix_case squote "sq'uote.txt"
hostile_matrix_case utf8 'utf8-café-日本語.txt'

# C0 control-character classes (quality-gate seq0360 Major #1 remedy):
# the evaluator's own extended matrix found vtab(0x0B)/soh(0x01)/
# formfeed(0x0C)/esc(0x1B) journaled as INVALID JSON (json_escape only
# escaped backslash/quote/TAB); "unitsep" (0x1F, the highest C0 value) is
# an additional representative sample proving the fix is GENERIC across
# the full C0 range, not a fifth single-character patch. CR (0x0D) is
# DELIBERATELY EXCLUDED here too -- see the dedicated CR
# UNSUPPORTED_PATH_CHARACTER rejection test below instead (symmetric
# with backslash's own treatment).
hostile_matrix_case vtab "vt$(printf '\013')ab.txt"
hostile_matrix_case soh "so$(printf '\001')h.txt"
hostile_matrix_case formfeed "ff$(printf '\014')eed.txt"
hostile_matrix_case esc "es$(printf '\033')c.txt"
hostile_matrix_case unitsep "un$(printf '\037')itsep.txt"

# ---------------------------------------------------------------------------
# Newline-in-path: confirmed structurally UNREPRESENTABLE in this
# line-oriented manifest format (a raw newline terminates the manifest
# LINE itself before the path portion could ever be assembled) --
# verified directly rather than merely asserted: a manifest line
# containing an embedded newline byte cannot even be constructed as a
# single line for `parse_manifest`'s own `IFS= read -r line` loop to
# consume; the "path" that would follow becomes a SEPARATE line, which
# --- lacking a valid 64-hex-lowercase prefix and two-space separator of
# its own --- is independently rejected as MANIFEST_INVALID by the
# existing hash/separator check. No new rejection code was needed or
# added; this is the parser's PRE-EXISTING behavior, confirmed here.
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/stage/live/x.txt" "x"
h=$(sha256_of "$F/stage/live/x.txt")
printf '%s  live/x' "$h" >"$F/stage/MANIFEST.sha256"
printf '\n' >>"$F/stage/MANIFEST.sha256"
printf '.txt\n' >>"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
if [ $? != 0 ] && [ "$(category_of "$WORK/out")" = "MANIFEST_INVALID" ]; then
  pass "TEST-033t a literal newline inside a manifest path is structurally unrepresentable -- the resulting malformed line is rejected (MANIFEST_INVALID), confirming no separate rejection code is needed"
else
  fail "TEST-033t a literal newline inside a manifest path is structurally unrepresentable"
fi

# ---------------------------------------------------------------------------
# Backslash: a GENUINELY unsupportable character (quality-gate seq0359) --
# verified empirically that PowerShell/.NET's FileSystemProvider treats
# `\` as a directory separator on every platform, even under -LiteralPath,
# so the .ps1 twin could never literally address such a path regardless of
# implementation technique. Classified-rejected in BOTH runtimes
# (UNSUPPORTED_PATH_CHARACTER) rather than silently letting sh accept what
# ps1 can never publish.
# ---------------------------------------------------------------------------
new_fixture_dir; F=$NEW_FIXTURE_DIR
write_file "$F/stage/back\\slash.txt" "x"
h=$(sha256_of "$F/stage/back\\slash.txt")
printf '%s  back\\slash.txt\n' "$h" >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
rc=$?
if [ "$rc" != 0 ] && [ "$(category_of "$WORK/out")" = "UNSUPPORTED_PATH_CHARACTER" ]; then
  pass "TEST-033t sh rejects a literal backslash in a manifest path (UNSUPPORTED_PATH_CHARACTER, both-runtime parity by design)"
else
  fail "TEST-033t sh rejects a literal backslash in a manifest path (exit $rc, category $(category_of "$WORK/out"))"
fi
if command -v pwsh >/dev/null 2>&1; then
  new_fixture_dir; F=$NEW_FIXTURE_DIR
  write_file "$F/stage/back\\slash.txt" "x"
  h=$(sha256_of "$F/stage/back\\slash.txt")
  printf '%s  back\\slash.txt\n' "$h" >"$F/stage/MANIFEST.sha256"
  ( cd "$F/repo" && pwsh -NoProfile -ExecutionPolicy Bypass -File "$APPLY_PS1_FOR_PARITY" -StagingDir "$F/stage" -Manifest "$F/stage/MANIFEST.sha256" ) >"$WORK/out" 2>"$WORK/err"
  rc=$?
  if [ "$rc" != 0 ] && [ "$(category_of "$WORK/out")" = "UNSUPPORTED_PATH_CHARACTER" ]; then
    pass "TEST-033t ps1 ALSO rejects a literal backslash in a manifest path (UNSUPPORTED_PATH_CHARACTER, parity confirmed)"
  else
    fail "TEST-033t ps1 ALSO rejects a literal backslash in a manifest path (exit $rc, category $(category_of "$WORK/out"))"
  fi
else
  pass "TEST-033t ps1 backslash rejection parity (skipped: pwsh not available)"
fi

# ---------------------------------------------------------------------------
# Carriage return (CR): a GENUINELY unsupportable character (quality-gate
# seq0360 Major #2) -- a literal CR embedded in a manifest target path is,
# by raw bytes alone, indistinguishable from a legitimate CRLF line
# terminator, and this runtime's ps1 twin ALSO independently mis-splits a
# bare CR via Get-Content's own line-splitting (verified: an accidental,
# mis-categorized MANIFEST_INVALID on the identical input, BEFORE this
# remedy). Classified-rejected in BOTH runtimes (UNSUPPORTED_PATH_
# CHARACTER), whole-file, symmetric with the backslash precedent.
# ---------------------------------------------------------------------------
new_fixture_dir; F=$NEW_FIXTURE_DIR
cr=$(printf '\r')
write_file "$F/stage/cr${cr}path.txt" "x"
h=$(sha256_of "$F/stage/cr${cr}path.txt")
printf '%s  cr%spath.txt\n' "$h" "$cr" >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
rc=$?
if [ "$rc" != 0 ] && [ "$(category_of "$WORK/out")" = "UNSUPPORTED_PATH_CHARACTER" ]; then
  pass "TEST-033t sh rejects a literal CR in a manifest path (UNSUPPORTED_PATH_CHARACTER, both-runtime parity by design)"
else
  fail "TEST-033t sh rejects a literal CR in a manifest path (exit $rc, category $(category_of "$WORK/out"))"
fi
if command -v pwsh >/dev/null 2>&1; then
  new_fixture_dir; F=$NEW_FIXTURE_DIR
  write_file "$F/stage/cr${cr}path.txt" "x"
  h=$(sha256_of "$F/stage/cr${cr}path.txt")
  printf '%s  cr%spath.txt\n' "$h" "$cr" >"$F/stage/MANIFEST.sha256"
  ( cd "$F/repo" && pwsh -NoProfile -ExecutionPolicy Bypass -File "$APPLY_PS1_FOR_PARITY" -StagingDir "$F/stage" -Manifest "$F/stage/MANIFEST.sha256" ) >"$WORK/out" 2>"$WORK/err"
  rc=$?
  if [ "$rc" != 0 ] && [ "$(category_of "$WORK/out")" = "UNSUPPORTED_PATH_CHARACTER" ]; then
    pass "TEST-033t ps1 ALSO rejects a literal CR in a manifest path (UNSUPPORTED_PATH_CHARACTER, parity confirmed)"
  else
    fail "TEST-033t ps1 ALSO rejects a literal CR in a manifest path (exit $rc, category $(category_of "$WORK/out"))"
  fi
else
  pass "TEST-033t ps1 CR rejection parity (skipped: pwsh not available)"
fi

# ===========================================================================
# TEST-033u (quality-gate seq0360 Major #3 remedy): a glob-metacharacter
# DIRECTORY SEGMENT, not merely a leaf basename -- TEST-033t's own
# hostile_matrix_case fragments are ALWAYS "hostile/${frag}", i.e. the
# hostile fragment is always the LEAF, so a decoy directory a naive
# glob-vulnerable walk would substitute into is never actually exercised
# (the seq0359 walk_relative_dir/Invoke-WalkRelativeDir fix itself had NO
# regression lock at the exact layer it operates on). A pre-existing
# decoy directory 'axxb' sits next to the real target 'a*b'; a
# glob-vulnerable walk would silently substitute into the decoy while
# reporting success under the DECLARED name.
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
mkdir -p "$F/repo/axxb"
write_file "$F/repo/axxb/decoy-canary.txt" "decoy-untouched"
write_file "$F/stage/a*b/t.txt" "real-payload"
manifest_line "$F/stage" "a*b/t.txt" >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
rc=$?
if [ "$rc" = 0 ] && [ "$(cat "$F/repo/a*b/t.txt" 2>/dev/null)" = "real-payload" ]; then
  pass "TEST-033u glob-metacharacter DIRECTORY SEGMENT publishes to the literal name, not a decoy"
else
  fail "TEST-033u glob-metacharacter DIRECTORY SEGMENT publishes to the literal name (rc=$rc)"
fi
if [ "$(cat "$F/repo/axxb/decoy-canary.txt" 2>/dev/null)" = "decoy-untouched" ] && [ ! -e "$F/repo/axxb/t.txt" ]; then
  pass "TEST-033u decoy directory 'axxb' left completely untouched (no substitution into it)"
else
  fail "TEST-033u decoy directory 'axxb' left completely untouched"
fi

# ===========================================================================
# TEST-033v (quality-gate seq0360 CRITICAL remedy, requirements 1+2+3): the
# evaluator's own 3-trigger regression fixture. A genuine MIXED state
# (t1 already committed to POST, t2 still at PRE) is created via a real
# mid-batch crash; the destination-parent of the ALREADY-COMMITTED target
# is then attacked via 3 independent, non-adversarial triggers (symlink
# replacement / rename-aside / chmod 000). Recovery must FAIL CLOSED
# (nonzero exit, category RECOVERY_FAILED, journal AND pre/ backup
# RETAINED) while the trigger is active -- never silently coerce the
# probe failure to "ABSENT" and delete the only durable record of the
# pre-transaction state -- then CONVERGE to ALL-PRE, with the journal
# finally removed, once the trigger is undone.
# ===========================================================================

recovery_probe_failure_setup() {
  # Creates a fresh fixture with a genuine MIXED state (t1 at POST, t2 at
  # PRE) via a real mid-batch crash. Sets F / JOURNAL_DIR globals.
  new_fixture_dir; F=$NEW_FIXTURE_DIR
  write_file "$F/repo/sub1/a.txt" "old-a"
  write_file "$F/repo/sub2/b.txt" "old-b"
  write_file "$F/stage/sub1/a.txt" "new-a"
  write_file "$F/stage/sub2/b.txt" "new-b"
  {
    manifest_line "$F/stage" "sub1/a.txt"
    manifest_line "$F/stage" "sub2/b.txt"
  } >"$F/stage/MANIFEST.sha256"
  run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256" --simulate-crash-after rename-1
  JOURNAL_DIR=$(dirname "$(find "$F/repo/sdd/.staging" -name TRANSACTION.json 2>/dev/null | head -1)")
}

recovery_probe_failure_case() {
  # recovery_probe_failure_case <label> -- label is symlink/renameaside/chmod000.
  label=$1
  recovery_probe_failure_setup
  case "$label" in
    symlink)
      mv "$F/repo/sub1" "$F/repo/sub1.saved"
      ln -s "$F/repo/sub1.saved" "$F/repo/sub1"
      ;;
    renameaside)
      mv "$F/repo/sub1" "$F/repo/sub1.attacker-moved"
      ;;
    chmod000)
      chmod 000 "$F/repo/sub1"
      ;;
  esac

  run_apply "$F/repo"
  rc=$?
  if [ "$rc" != 0 ] && [ "$(category_of "$WORK/out")" = "RECOVERY_FAILED" ]; then
    pass "TEST-033v [$label] recovery fails closed while the destination-parent is unwalkable (RECOVERY_FAILED)"
  else
    fail "TEST-033v [$label] recovery fails closed (exit $rc, category $(category_of "$WORK/out"))"
  fi
  if [ -f "$JOURNAL_DIR/TRANSACTION.json" ] && [ -n "$(find "$JOURNAL_DIR/pre" -type f 2>/dev/null)" ]; then
    pass "TEST-033v [$label] journal and pre/ backup RETAINED after the failed recovery attempt"
  else
    fail "TEST-033v [$label] journal and pre/ backup RETAINED after the failed recovery attempt"
  fi

  # Undo the trigger (chmod 000 back to a workable mode; restore the
  # renamed-aside/symlink-shadowed real directory to its original name).
  case "$label" in
    symlink)
      rm -f "$F/repo/sub1"
      mv "$F/repo/sub1.saved" "$F/repo/sub1"
      ;;
    renameaside)
      mv "$F/repo/sub1.attacker-moved" "$F/repo/sub1"
      ;;
    chmod000)
      chmod 755 "$F/repo/sub1"
      ;;
  esac

  run_apply "$F/repo"
  rc=$?
  if [ "$rc" = 0 ] && [ "$(cat "$F/repo/sub1/a.txt")" = "old-a" ] && [ "$(cat "$F/repo/sub2/b.txt")" = "old-b" ]; then
    pass "TEST-033v [$label] recovery converges to ALL-PRE once the trigger is undone"
  else
    fail "TEST-033v [$label] recovery converges to ALL-PRE once the trigger is undone (exit $rc)"
  fi
  if [ -z "$(find "$F/repo/sdd/.staging" -type f 2>/dev/null)" ]; then
    pass "TEST-033v [$label] journal/staging litter fully cleaned up after convergence"
  else
    fail "TEST-033v [$label] journal/staging litter fully cleaned up after convergence"
  fi
}

recovery_probe_failure_case symlink
recovery_probe_failure_case renameaside
recovery_probe_failure_case chmod000

# ===========================================================================
# TEST-033w (quality-gate seq0360 CRITICAL remedy): the SAME probe-failure
# fail-closed discipline also applies at PREPARE time (before ANY journal
# for a NEW batch is written) -- a symlinked destination-parent denies
# the WHOLE batch (LIVE_PROBE_FAILED) rather than silently proceeding
# with a guessed pre_hash="ABSENT" that could hide real live content
# behind the symlink from the backup step.
# ===========================================================================
new_fixture_dir; F=$NEW_FIXTURE_DIR
mkdir -p "$F/repo/real-sub1"
write_file "$F/repo/real-sub1/hidden.txt" "hidden-content"
ln -s "$F/repo/real-sub1" "$F/repo/sub1"
write_file "$F/stage/sub1/hidden.txt" "new-content"
manifest_line "$F/stage" "sub1/hidden.txt" >"$F/stage/MANIFEST.sha256"
run_apply "$F/repo" --staging-dir "$F/stage" --manifest "$F/stage/MANIFEST.sha256"
rc=$?
if [ "$rc" != 0 ] && [ "$(category_of "$WORK/out")" = "LIVE_PROBE_FAILED" ]; then
  pass "TEST-033w PREPARE-time symlinked destination-parent denies the whole batch (LIVE_PROBE_FAILED)"
else
  fail "TEST-033w PREPARE-time symlinked destination-parent denies the whole batch (exit $rc, category $(category_of "$WORK/out"))"
fi
if [ "$(cat "$F/repo/real-sub1/hidden.txt" 2>/dev/null)" = "hidden-content" ]; then
  pass "TEST-033w real content behind the symlink is unchanged (never silently overwritten)"
else
  fail "TEST-033w real content behind the symlink is unchanged"
fi
if [ -z "$(find "$F/repo/sdd/.staging" -type f 2>/dev/null)" ]; then
  pass "TEST-033w no journal/staging litter left behind by the denied batch"
else
  fail "TEST-033w no journal/staging litter left behind by the denied batch"
fi

# ===========================================================================
# Self-registration (design.md Test Strategy item 11; mirrors
# tests/second-approval-mask.tests.sh:285-289's established pattern).
# ===========================================================================
if grep -q 'apply-human-copy.tests.sh' "$ROOT/tests/run-all.sh"; then
  pass "self-registration: tests/run-all.sh references apply-human-copy.tests.sh"
else
  fail "self-registration: tests/run-all.sh references apply-human-copy.tests.sh"
fi
if grep -q 'apply-human-copy.tests.ps1' "$ROOT/tests/run-all.ps1"; then
  pass "self-registration: tests/run-all.ps1 references apply-human-copy.tests.ps1"
else
  fail "self-registration: tests/run-all.ps1 references apply-human-copy.tests.ps1"
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
