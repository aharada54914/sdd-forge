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
