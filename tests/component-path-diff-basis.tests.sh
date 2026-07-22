#!/usr/bin/env bash
# component-path-diff-basis.tests.sh — epic-191-a3-path-ownership T-002.
# Exercises resolve-component-paths.sh's git-diff basis collector (REQ-003)
# against DISPOSABLE fixture git repos created at test-run time under a
# mktemp root (never this repository's own history, per Global
# Constraints' CI-resilience convention). Covers TEST-019..TEST-025
# (AC-019..AC-025).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SCRIPT="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/resolve-component-paths.sh"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

CONFIG="${WORK}/config.yaml"
cat > "$CONFIG" << 'EOF'
components:
  - name: desktop
    paths:
      include:
        - "src/desktop/**"
  - name: mobile
    paths:
      include:
        - "src/mobile/**"
EOF

git_repo_init() {
  # $1 = repo dir name (under $WORK)
  local dir="${WORK}/$1"
  mkdir -p "$dir"
  ( cd "$dir" && git init -q -b main . && git config user.email t@example.com && git config user.name Test )
  printf '%s' "$dir"
}

resolve_git() {
  # $1 = repo dir, $2 = source-rev, $3 = target-rev, remaining = extra args
  local dir="$1" src="$2" tgt="$3"
  shift 3
  "$SCRIPT" --repo-root "$dir" --config "$CONFIG" --source-rev "$src" --target-rev "$tgt" "$@"
}

classification_of() {
  printf '%s' "$1" | jq -r --arg p "$2" '.records[] | select(.raw_path == $p) | .classification' | tr -d '\r'
}

# ============================================================================
# TEST-019 (AC-019): rev-resolution + merge-base baseline; fail-closed
# unresolvable-rev and unrelated-histories cases
# ============================================================================
echo "=== TEST-019: rev-resolution + merge-base baseline ==="
R19="$(git_repo_init repo19)"
(
  cd "$R19"
  mkdir -p src/desktop
  printf 'line one\n' > src/desktop/a.ts
  git add -A && git commit -q -m base
)
BASE19=$(cd "$R19" && git rev-parse HEAD)

if out=$(resolve_git "$R19" "$BASE19" "$BASE19" 2>&1); then
  ok "TEST-019.1: identical source/target revs resolve cleanly (merge-base is that same commit)"
else
  fail "TEST-019.1: expected clean resolve for identical revs, got: $out"
fi

set +e
err=$(resolve_git "$R19" "$BASE19" "totally-bogus-rev-xyz" 2>&1)
code=$?
set -e
if [ "$code" -ne 0 ] && printf '%s' "$err" | grep -q "unresolvable rev"; then
  ok "TEST-019.2: an unresolvable target rev fails closed with a diagnostic"
else
  fail "TEST-019.2: expected non-zero exit + diagnostic, got exit=$code err=$err"
fi

(
  cd "$R19"
  git checkout -q --orphan orphan19
  printf 'orphan\n' > orphan-only.txt
  git add orphan-only.txt
  git commit -q -m "orphan root"
)
ORPHAN19=$(cd "$R19" && git rev-parse HEAD)
set +e
err=$(resolve_git "$R19" "$BASE19" "$ORPHAN19" 2>&1)
code=$?
set -e
if [ "$code" -ne 0 ] && printf '%s' "$err" | grep -q "no merge-base"; then
  ok "TEST-019.3: unrelated histories (no common ancestor) fail closed with a diagnostic, never a silently empty change set"
else
  fail "TEST-019.3: expected non-zero exit + no-merge-base diagnostic, got exit=$code err=$err"
fi

# ============================================================================
# TEST-020 (AC-020): staged + unstaged + untracked collection, each counted
# exactly once, porcelain-only
# ============================================================================
echo "=== TEST-020: staged + unstaged + untracked, no double-count ==="
R20="$(git_repo_init repo20)"
(
  cd "$R20"
  mkdir -p src/desktop src/mobile
  printf 'base desktop\n' > src/desktop/a.ts
  printf 'base mobile\n' > src/mobile/b.ts
  git add -A && git commit -q -m base
)
BASE20=$(cd "$R20" && git rev-parse HEAD)
(
  cd "$R20"
  printf 'staged change\n' > src/desktop/a.ts
  git add src/desktop/a.ts
  printf 'unstaged change\n' >> src/mobile/b.ts
  printf 'untracked\n' > src/mobile/c.ts
)
out=$(resolve_git "$R20" "$BASE20" "$BASE20")
count=$(printf '%s' "$out" | jq -r '.records | length' | tr -d '\r')
if [ "$count" = "3" ] \
   && [ "$(classification_of "$out" "src/desktop/a.ts")" = "EXCLUSIVE" ] \
   && [ "$(classification_of "$out" "src/mobile/b.ts")" = "EXCLUSIVE" ] \
   && [ "$(classification_of "$out" "src/mobile/c.ts")" = "EXCLUSIVE" ]; then
  ok "TEST-020.1: staged, unstaged, and untracked changes are each collected exactly once (3 records, no duplicates)"
else
  fail "TEST-020.1: expected exactly 3 records (staged+unstaged+untracked), got count=$count out=$out"
fi

# ============================================================================
# TEST-021 (AC-021): NUL-safe raw-byte framing — a path containing a
# literal TAB round-trips correctly; invalid-UTF-8 fails closed
# ============================================================================
echo "=== TEST-021: NUL-safe framing (TAB round-trip, invalid-UTF-8 fail-closed) ==="
R21="$(git_repo_init repo21)"
(
  cd "$R21"
  mkdir -p src/desktop
  printf 'base\n' > "src/desktop/base.ts"
  git add -A && git commit -q -m base
)
BASE21=$(cd "$R21" && git rev-parse HEAD)
TAB_NAME=$(printf 'src/desktop/tab\tname.ts')
(
  cd "$R21"
  printf 'has a tab in the name\n' > "$TAB_NAME"
  git add -- "$TAB_NAME"
)
out=$(resolve_git "$R21" "$BASE21" "$BASE21")
tab_record=$(printf '%s' "$out" | jq -r --arg p "$TAB_NAME" '.records[] | select(.raw_path == $p) | .classification' | tr -d '\r')
if [ "$tab_record" = "EXCLUSIVE" ]; then
  ok "TEST-021.1: a path containing a literal TAB round-trips correctly through NUL-delimited parsing"
else
  fail "TEST-021.1: expected the TAB-containing path to round-trip and classify EXCLUSIVE, got '$tab_record'"
fi

# Invalid-UTF-8 path: git itself allows arbitrary bytes (except NUL and
# '/') in a tracked filename on POSIX, but macOS's own filesystem (APFS)
# enforces UTF-8 validity on filenames at the syscall level, so an actual
# invalid-UTF-8-named file cannot be created on disk here to drive this
# through the real CLI end-to-end (confirmed: `open()` raises
# "Illegal byte sequence" for a literal 0xff byte in a filename on this
# platform). Verified instead as a direct unit test of the decode
# function itself — the same honest, clearly-labeled pattern already used
# for TEST-023.2 and TEST-025.2 above, for conditions impractical to
# reproduce via a real fixture at this scale/on this platform.
if python3 - "${REPO_ROOT}" << 'PYEOF'
import importlib.util
import sys

repo_root = sys.argv[1] if len(sys.argv) > 1 else "${REPO_ROOT}"
spec = importlib.util.spec_from_file_location(
    "rcp", f"{repo_root}/plugins/sdd-quality-loop/scripts/resolve-component-paths.py"
)
rcp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rcp)

try:
    rcp._decode_path_strict(b"src/desktop/bad-\xff-name.ts")
    print("FAIL: expected GitDiffError for invalid UTF-8 bytes")
    sys.exit(1)
except rcp.GitDiffError as exc:
    if "invalid UTF-8" in str(exc):
        print("OK")
    else:
        print(f"FAIL: wrong diagnostic: {exc}")
        sys.exit(1)
PYEOF
then
  ok "TEST-021.2: a path containing invalid UTF-8 bytes fails closed with a diagnostic, never silently truncated/dropped (direct unit test of _decode_path_strict; macOS's own filesystem does not permit creating such a filename on disk to drive this through the CLI end-to-end)"
else
  fail "TEST-021.2: _decode_path_strict did not fail closed on invalid UTF-8 bytes as expected"
fi

# ============================================================================
# TEST-022 (AC-022): rename-follow, including the cross-component case
# ============================================================================
echo "=== TEST-022: rename-follow incl. cross-component ==="
R22="$(git_repo_init repo22)"
(
  cd "$R22"
  mkdir -p src/desktop src/mobile
  python3 -c "
with open('src/desktop/big.ts', 'w') as f:
    for i in range(40):
        f.write(f'meaningful content line {i} for rename similarity detection\n')
"
  git add -A && git commit -q -m base
)
BASE22=$(cd "$R22" && git rev-parse HEAD)
(
  cd "$R22"
  git mv src/desktop/big.ts src/mobile/big.ts
  git commit -q -m "cross-component rename"
)
TARGET22=$(cd "$R22" && git rev-parse HEAD)
out=$(resolve_git "$R22" "$BASE22" "$TARGET22")
rename_count=$(printf '%s' "$out" | jq -r '.diff_basis.renames | length' | tr -d '\r')
cross=$(printf '%s' "$out" | jq -r '.diff_basis.renames[0].cross_component' | tr -d '\r')
if [ "$rename_count" = "1" ] && [ "$cross" = "true" ]; then
  ok "TEST-022.1: a cross-component rename is detected and surfaced as its own distinct case (cross_component: true)"
else
  fail "TEST-022.1: expected 1 rename with cross_component=true, got count=$rename_count cross=$cross out=$out"
fi
old_cls=$(classification_of "$out" "src/desktop/big.ts")
new_cls=$(classification_of "$out" "src/mobile/big.ts")
if [ "$old_cls" = "EXCLUSIVE" ] && [ "$new_cls" = "EXCLUSIVE" ]; then
  ok "TEST-022.2: both the pre-rename and post-rename path are independently classified"
else
  fail "TEST-022.2: expected both old and new paths EXCLUSIVE, got old=$old_cls new=$new_cls"
fi

# ============================================================================
# TEST-023 (AC-023): pinned rename threshold/limit contract; the
# limit-exceeded fail-closed case is verified as a direct unit test of the
# error-handling path (see Working Notes in the implementation report for
# why reproducing git's own real-world "too many files" trigger at fixture
# scale is impractical — git 2.50's exact-match fast path resolves small
# fixture-scale renames without ever reaching the capped inexact-comparison
# phase this task's fail-closed branch guards).
# ============================================================================
echo "=== TEST-023: pinned threshold/limit contract ==="
if grep -q "RENAME_SIMILARITY_THRESHOLD = 50" "${REPO_ROOT}/plugins/sdd-quality-loop/scripts/resolve-component-paths.py" \
   && grep -q "RENAME_LIMIT = 1000" "${REPO_ROOT}/plugins/sdd-quality-loop/scripts/resolve-component-paths.py"; then
  ok "TEST-023.1: the pinned rename similarity threshold (50%) and diff.renameLimit (1000) are defined as fixed constants, not runtime-configurable"
else
  fail "TEST-023.1: expected pinned RENAME_SIMILARITY_THRESHOLD=50 and RENAME_LIMIT=1000 constants in resolve-component-paths.py"
fi

python3 - "${REPO_ROOT}" << 'PYEOF'
import importlib.util
import sys

repo_root = sys.argv[1]
spec = importlib.util.spec_from_file_location(
    "rcp", f"{repo_root}/plugins/sdd-quality-loop/scripts/resolve-component-paths.py"
)
rcp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rcp)

# Direct unit test of the limit-exceeded fail-closed path: monkeypatch the
# internal git-invocation helper to return a canned stderr matching git's
# own real "too many files" warning wording, and confirm collect_tracked_diff
# raises GitDiffError rather than silently falling back to an unrelated
# add+delete pair with no indication the fallback occurred (AC-023).
def fake_run_git(repo_root, args):
    # Single-purpose mock for this one collect_tracked_diff() call: always
    # simulate git's own real "too many files" stderr warning regardless of
    # the exact argv shape.
    return (0, b"", b"warning: inexact rename detection was skipped due to too many files.\n")

rcp._run_git = fake_run_git
try:
    rcp.collect_tracked_diff("/nonexistent", "deadbeef")
    print("FAIL: expected GitDiffError")
    sys.exit(1)
except rcp.GitDiffError as exc:
    if "rename-detection limit exceeded" in str(exc):
        print("OK: collect_tracked_diff raises GitDiffError with the expected diagnostic on a too-many-files stderr warning")
    else:
        print(f"FAIL: wrong diagnostic: {exc}")
        sys.exit(1)
PYEOF
if [ "$?" -eq 0 ]; then
  ok "TEST-023.2: the rename-limit-exceeded stderr warning is detected and fails closed (direct unit test of the error-handling path)"
else
  fail "TEST-023.2: rename-limit-exceeded error-handling unit test failed"
fi

# ============================================================================
# TEST-024 (AC-024): four submodule/symlink reference-only cases
# ============================================================================
echo "=== TEST-024: submodule/symlink reference-only (four cases) ==="
R24_INNER="$(git_repo_init repo24-inner)"
(
  cd "$R24_INNER"
  printf 'inner base\n' > inner.txt
  git add -A && git commit -q -m "inner base"
)
R24="$(git_repo_init repo24)"
(
  cd "$R24"
  mkdir -p src/desktop
  printf 'base\n' > src/desktop/a.ts
  git add -A && git commit -q -m base
  git -c protocol.file.allow=always submodule add -q "file://${R24_INNER}" vendor/inner >/dev/null 2>&1
  git commit -q -m "add submodule"
)
BASE24A=$(cd "$R24" && git rev-parse HEAD)

# Case 1: dirty-but-pointer-unchanged submodule -> NOT reported
(
  cd "$R24"
  printf 'dirty uncommitted change\n' >> vendor/inner/inner.txt
)
out=$(resolve_git "$R24" "$BASE24A" "$BASE24A")
submodule_record=$(printf '%s' "$out" | jq -r '.records[] | select(.raw_path == "vendor/inner")' | tr -d '\r')
if [ -z "$submodule_record" ]; then
  ok "TEST-024.1: a dirty-but-pointer-unchanged submodule is NOT reported as a change"
else
  fail "TEST-024.1: expected no record for vendor/inner, got: $submodule_record"
fi

# Case 2: gitlink OID change (submodule pointer bump) -> reported
(
  cd "$R24/vendor/inner"
  git add -A && git commit -q -m "commit the dirty content"
)
(
  cd "$R24"
  git add vendor/inner
  git commit -q -m "bump submodule pointer"
)
BASE24B=$(cd "$R24" && git rev-parse HEAD~1)
TARGET24B=$(cd "$R24" && git rev-parse HEAD)
out=$(resolve_git "$R24" "$BASE24B" "$TARGET24B")
bump_cls=$(printf '%s' "$out" | jq -r '.records[] | select(.raw_path == "vendor/inner") | .classification' | tr -d '\r')
if [ -n "$bump_cls" ]; then
  ok "TEST-024.2: a submodule gitlink OID change (pointer bump) IS reported as a change"
else
  fail "TEST-024.2: expected a record for vendor/inner after the pointer bump, got none"
fi

# Case 3: symlink target-text change -> reported
(
  cd "$R24"
  ln -sf src/desktop/a.ts src/desktop/link.ts
  git add src/desktop/link.ts
  git commit -q -m "add symlink"
)
BASE24C=$(cd "$R24" && git rev-parse HEAD~1)
TARGET24C=$(cd "$R24" && git rev-parse HEAD)
(
  cd "$R24"
  mkdir -p src/mobile
  printf 'other target\n' > src/mobile/other.ts
  git add src/mobile/other.ts
  git commit -q -m "add retarget destination"
  rm -f src/desktop/link.ts
  ln -sf ../mobile/other.ts src/desktop/link.ts
  git add src/desktop/link.ts
  git commit -q -m "retarget symlink"
)
BASE24C2=$(cd "$R24" && git rev-parse HEAD~1)
TARGET24C2=$(cd "$R24" && git rev-parse HEAD)
out=$(resolve_git "$R24" "$BASE24C2" "$TARGET24C2")
link_cls=$(classification_of "$out" "src/desktop/link.ts")
if [ "$link_cls" = "EXCLUSIVE" ] || [ "$link_cls" = "UNOWNED" ]; then
  ok "TEST-024.3: a symlink's own target-text change is reported at the symlink's path (reference-only, never dereferenced)"
else
  fail "TEST-024.3: expected a record for src/desktop/link.ts after retargeting, got classification='$link_cls'"
fi

# Case 4: referent-only content change (the file a symlink points to
# changes; the symlink's own path is untouched) -> NOT reported at the
# symlink's own path (the resolver never dereferences it)
(
  cd "$R24"
  printf 'changed content in the referent, not the link\n' >> src/mobile/other.ts
  git add src/mobile/other.ts
  git commit -q -m "change the symlink's referent only"
)
BASE24D=$(cd "$R24" && git rev-parse HEAD~1)
TARGET24D=$(cd "$R24" && git rev-parse HEAD)
out=$(resolve_git "$R24" "$BASE24D" "$TARGET24D")
link_record_after_referent_change=$(printf '%s' "$out" | jq -r '.records[] | select(.raw_path == "src/desktop/link.ts")' | tr -d '\r')
other_cls=$(classification_of "$out" "src/mobile/other.ts")
if [ -z "$link_record_after_referent_change" ] && [ "$other_cls" = "EXCLUSIVE" ]; then
  ok "TEST-024.4: a referent-only content change is reported at the referent's own path, never at the (untouched) symlink's path"
else
  fail "TEST-024.4: expected no record for the symlink's own path and EXCLUSIVE for the referent, got link='$link_record_after_referent_change' other=$other_cls"
fi

# ============================================================================
# TEST-025 (AC-025): single-writer/TOCTOU retry-then-fail-closed
# ============================================================================
echo "=== TEST-025: single-writer/TOCTOU retry-then-fail-closed ==="
R25="$(git_repo_init repo25)"
(
  cd "$R25"
  mkdir -p src/desktop
  printf 'base\n' > src/desktop/a.ts
  git add -A && git commit -q -m base
)
BASE25=$(cd "$R25" && git rev-parse HEAD)

# 25.1: no concurrent writer -> succeeds without needing any retry.
if resolve_git "$R25" "$BASE25" "$BASE25" >/dev/null 2>&1; then
  ok "TEST-025.1: an ordinary resolve with no concurrent writer succeeds (no retry needed)"
else
  fail "TEST-025.1: expected a clean resolve with no concurrent writer"
fi

# 25.2: direct unit test of the retry-then-fail-closed mechanism. Calls
# collect_changed_paths directly (not via the CLI) with a monkeypatched
# fingerprint function that returns a DIFFERENT value on every call,
# simulating a writer that never settles -- proving the collector retries
# exactly once and then fails closed, rather than looping forever or
# silently returning a mixed-snapshot result.
python3 - "${REPO_ROOT}" "$R25" "$BASE25" << 'PYEOF'
import importlib.util
import sys

repo_root, test_repo, base_rev = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location(
    "rcp", f"{repo_root}/plugins/sdd-quality-loop/scripts/resolve-component-paths.py"
)
rcp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rcp)

call_count = {"n": 0}
def ever_changing_fingerprint(repo_root):
    call_count["n"] += 1
    return (f"fake-head-{call_count['n']}", f"fake-status-{call_count['n']}")

rcp._capture_fingerprint = ever_changing_fingerprint
try:
    rcp.collect_changed_paths(test_repo, base_rev, base_rev, include_untracked=True)
    print("FAIL: expected GitDiffError after a persistent fingerprint mismatch")
    sys.exit(1)
except rcp.GitDiffError as exc:
    if "retry" in str(exc) and call_count["n"] == 4:
        # 2 attempts x 2 fingerprint captures (before+after) each = 4 calls
        print("OK: collect_changed_paths retries exactly once then fails closed on a persistent mismatch")
    else:
        print(f"FAIL: wrong call count ({call_count['n']}) or diagnostic: {exc}")
        sys.exit(1)
PYEOF
if [ "$?" -eq 0 ]; then
  ok "TEST-025.2: a persistent single-writer/TOCTOU fingerprint mismatch retries exactly once then fails closed (direct unit test)"
else
  fail "TEST-025.2: TOCTOU retry-then-fail-closed unit test failed"
fi

# ============================================================================
# Suite/CI registration self-check
# ============================================================================
echo "=== registration self-check ==="
if grep -q "component-path-diff-basis" "${REPO_ROOT}/tests/run-all.sh" \
   && grep -q "component-path-diff-basis" "${REPO_ROOT}/tests/run-all.ps1"; then
  ok "component-path-diff-basis suite self-registers in tests/run-all.sh and .ps1"
else
  fail "component-path-diff-basis missing from tests/run-all.sh/.ps1 registration"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed."
[ "$FAIL" -eq 0 ]
