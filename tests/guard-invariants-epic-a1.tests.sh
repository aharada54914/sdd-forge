#!/bin/sh
# T-009 (epic-189-a1-project-context, REQ-007): acceptance checks for the
# STAGED guard-invariants registration batch under
# specs/epic-189-a1-project-context/human-copy/.
#
# This suite deliberately asserts against the STAGED candidates only. The
# live inventory cannot be asserted until a human has applied the batch
# (tasks.md T-009 "Human apply step"), so every check below is either a
# staged-tree check or a live-tree NON-MUTATION check.
#
# TEST-021 staged-inventory conformance + manifest-derived count +
#   staged-tree --check pass (AC-021): PROTECTED-MANIFEST.md is parsed as
#   the single canonical source; the staged guard-invariants.json's
#   protected_gate_suffixes and epic_a1_targets, and the staged
#   generate-guard-invariants.py's EPIC_A1_TARGETS tuple, are each
#   re-derived from it and must match EXACTLY (ordered, no duplicates). A
#   hand edit to either candidate that is not mirrored in the manifest is
#   therefore a failure here, not a silent divergence. The staged
#   generator is then run with --check AGAINST ITS OWN STAGED TREE
#   (Path(__file__)-anchored, the same mechanism
#   tests/phase2-guard-invariants.tests.sh:41 already uses for the frozen
#   epic-136 stage) and must exit 0.
# TEST-021-MUT staged --check detection power: three independent mutations
#   of a THROWAWAY COPY of the staged tree (never the repository) must each
#   make --check fail -- a dropped JSON entry, a dropped EPIC_A1_TARGETS
#   entry, and a stale generated output. Without these, a --check that
#   passed vacuously would look identical to one that passed meaningfully.
# TEST-022 live-file non-mutation (AC-022): each of the six LIVE
#   guard-invariants files must be in EXACTLY ONE of two allowed states --
#   the pre-apply baseline digest recorded before T-009's agent commit, or
#   the digest of this batch's own staged candidate (i.e. the human apply
#   landed precisely the reviewed bytes). Any third value means the live
#   file drifted to something nobody reviewed, and fails closed. This
#   phrasing is what lets one assertion express AC-022 both before and
#   after the human apply step, instead of a pinned digest that would go
#   red the moment the batch is legitimately applied.
# TEST-038 reservation inventory (AC-038): both RESERVED groups
#   (resolve-project-context.{py,sh,ps1}, generated/project-context
#   .resolved.json) are present in the staged candidate, and all six
#   ADR-0019-item-3 categories are represented, concretely or as a
#   reservation.
# TEST-HARDEN staging integrity: MANIFEST.sha256 grammar, digest agreement
#   with the staged bytes, preservation of the pre-existing
#   .github/workflows/test.yml entry (which belongs to a later task and
#   must not be disturbed by this one), the nested self-path manifest copy
#   being byte-identical to the canonical one, and the frozen
#   PHASE2_TARGETS/BASELINE_SUFFIXES constants being untouched.
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/guard-invariants-epic-a1-test.XXXXXX")
WORK=$(cd "$WORK" && pwd -P)
trap 'rm -rf "$WORK"' EXIT INT TERM

STAGE="$ROOT/specs/epic-189-a1-project-context/human-copy"
MANIFEST_MD="$STAGE/PROTECTED-MANIFEST.md"
MANIFEST_SHA="$STAGE/MANIFEST.sha256"
LOOP_REL="plugins/sdd-quality-loop"
STAGED_LOOP="$STAGE/$LOOP_REL"
STAGED_JSON="$STAGED_LOOP/references/guard-invariants.json"
STAGED_GEN="$STAGED_LOOP/scripts/generate-guard-invariants.py"
STAGED_GENDIR="$STAGED_LOOP/scripts/generated"
LIVE_LOOP="$ROOT/$LOOP_REL"
LIVE_JSON="$LIVE_LOOP/references/guard-invariants.json"
LIVE_GEN="$LIVE_LOOP/scripts/generate-guard-invariants.py"
LIVE_GENDIR="$LIVE_LOOP/scripts/generated"

# The six LIVE files' digests as recorded BEFORE T-009's agent commit
# (implementation report T-009.md, "Live-file baseline"). See TEST-022.
PRE_APPLY_JSON=fde0a57e33fb6b1a21e11af120cbf946e14ce53d0313d77c14e22538dfd422ad
PRE_APPLY_GEN=827d154754599f6231445fad6056c17700bb371e72f01346b56d0147ce4facc7
PRE_APPLY_PY=121818ba4c6d60c4abb081a652ef5b7e22c1fae8ee2d1efefa50fddddde115ad
PRE_APPLY_JS=16c05a8c56cd2b1befd33c8ac405916123da551876e5de56b6f4b1989d82a1d6
PRE_APPLY_PS1=52de1d386b94787898dc02dc47c1bbb25ecc57f1d713b8a9ea417e61c7281b1b
PRE_APPLY_SH=30eaddedbc5837d0684f13fdedd67aab66a2e0f471d35fd376196727ac17ca88

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }
assert_eq() {
  if [ "$1" = "$2" ]; then pass "$3"; else fail "$3 (expected [$2], got [$1])"; fi
}

# Importing the staged generator (below) would otherwise drop a
# __pycache__/ directory into a human-copy STAGING area. It is gitignored,
# but a publisher staging tree must contain only reviewed artifacts.
PYTHONDONTWRITEBYTECODE=1
export PYTHONDONTWRITEBYTECODE

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

# ---------------------------------------------------------------------------
# Canonical source: parse PROTECTED-MANIFEST.md
# ---------------------------------------------------------------------------

if [ -f "$MANIFEST_MD" ]; then
  pass "manifest: PROTECTED-MANIFEST.md exists"
else
  fail "manifest: PROTECTED-MANIFEST.md exists"
  printf 'PASS: %s\nFAIL: %s\n' "$PASS" "$FAIL"
  exit 1
fi

# Rows that merely LOOK like inventory rows, versus rows that satisfy the
# normative grammar. Comparing the two counts is what makes a malformed row
# fail closed instead of being silently skipped by the field extractor.
grep -E '^\| [0-9][0-9] \| ' "$MANIFEST_MD" >"$WORK/rows.loose" 2>/dev/null || :
grep -E '^\| [0-9][0-9] \| [^|]+ \| [^|]+ \| `[^`|]+` \| (concrete|reserved) \|$' \
  "$MANIFEST_MD" >"$WORK/rows.strict" 2>/dev/null || :
LOOSE=$(wc -l <"$WORK/rows.loose" | tr -d ' ')
STRICT=$(wc -l <"$WORK/rows.strict" | tr -d ' ')
assert_eq "$STRICT" "$LOOSE" "manifest: every inventory-shaped row satisfies the normative grammar"

awk -F' \\| ' '{
  nn = substr($1, 3);
  path = $4; gsub(/`/, "", path);
  status = $5; sub(/ \|$/, "", status);
  printf "%s\t%s\t%s\t%s\n", nn, $3, path, status;
}' "$WORK/rows.strict" >"$WORK/rows.tsv"

cut -f3 "$WORK/rows.tsv" >"$WORK/paths.txt"
cut -f2 "$WORK/rows.tsv" >"$WORK/adr.txt"
cut -f4 "$WORK/rows.tsv" >"$WORK/status.txt"

TOTAL=$(wc -l <"$WORK/paths.txt" | tr -d ' ')
CONCRETE=$(grep -c '^concrete$' "$WORK/status.txt" || :)
RESERVED=$(grep -c '^reserved$' "$WORK/status.txt" || :)
UNIQUE=$(sort "$WORK/paths.txt" | uniq | wc -l | tr -d ' ')

assert_eq "$TOTAL" "28" "manifest: total entry count is 28 (design.md Protected-File Statement)"
assert_eq "$CONCRETE" "24" "manifest: concrete entry count is 24"
assert_eq "$RESERVED" "4" "manifest: reserved entry count is 4"
assert_eq "$UNIQUE" "$TOTAL" "manifest: no duplicate paths"

# Ordinals contiguous and ascending from 01.
EXPECT_NN=$(awk 'BEGIN { for (i = 1; i <= 28; i++) printf "%02d\n", i }')
ACTUAL_NN=$(cut -f1 "$WORK/rows.tsv")
assert_eq "$ACTUAL_NN" "$EXPECT_NN" "manifest: ordinals are contiguous and ascending 01..28"

# Every path must satisfy generate-guard-invariants.py's _validate_repo_path
# shape rules: relative, no backslash, no empty/./.. segment.
BAD_PATHS=$(awk '
  /^\// { print; next }
  /\\\\/ { print; next }
  {
    n = split($0, seg, "/");
    for (i = 1; i <= n; i++) if (seg[i] == "" || seg[i] == "." || seg[i] == "..") { print; next }
  }' "$WORK/paths.txt")
assert_eq "$BAD_PATHS" "" "manifest: every path is a valid repository-relative path"

# The manifest's own prose Counts table must agree with its rows.
for pair in "concrete|24" "reserved|4" "total|28"; do
  label=${pair%%|*}
  want=${pair##*|}
  if grep -qE "^\| $label \| $want \|$" "$MANIFEST_MD"; then
    pass "manifest: prose Counts table states $label=$want, matching the rows"
  else
    fail "manifest: prose Counts table states $label=$want, matching the rows"
  fi
done

# ---------------------------------------------------------------------------
# TEST-038: reservation inventory and ADR-0019 item 3 category coverage
# ---------------------------------------------------------------------------

for slug in canonicalizer hash-generator approval-validator policy-weakening-detector resolver generated-projection; do
  if grep -qx "$slug" "$WORK/adr.txt"; then
    pass "TEST-038: ADR-0019 item 3 category represented: $slug"
  else
    fail "TEST-038: ADR-0019 item 3 category represented: $slug"
  fi
done

ITEM3=$(grep -vc '^beyond-item-3$' "$WORK/adr.txt" || :)
BEYOND=$(grep -c '^beyond-item-3$' "$WORK/adr.txt" || :)
assert_eq "$ITEM3" "20" "TEST-038: 20 entries fall under an ADR-0019 item 3 category"
assert_eq "$BEYOND" "8" "TEST-038: 8 entries are deliberate beyond-item-3 extensions (6 data + 2 publisher)"

RESOLVER_ROWS=$(awk -F'\t' '$2 == "resolver" { print $3 "\t" $4 }' "$WORK/rows.tsv")
EXPECT_RESOLVER=$(printf '%s\treserved\n%s\treserved\n%s\treserved' \
  "plugins/sdd-quality-loop/scripts/resolve-project-context.py" \
  "plugins/sdd-quality-loop/scripts/resolve-project-context.sh" \
  "plugins/sdd-quality-loop/scripts/resolve-project-context.ps1")
assert_eq "$RESOLVER_ROWS" "$EXPECT_RESOLVER" "TEST-038: resolver reservation is exactly the three resolve-project-context paths"

PROJECTION_ROWS=$(awk -F'\t' '$2 == "generated-projection" { print $3 "\t" $4 }' "$WORK/rows.tsv")
assert_eq "$PROJECTION_ROWS" \
  "plugins/sdd-quality-loop/scripts/generated/project-context.resolved.json	reserved" \
  "TEST-038: generated-projection reservation is exactly the resolved-projection path"

# B9 publisher self-protection and B3 anchor snapshots are concrete, not reserved.
for p in \
  "plugins/sdd-quality-loop/scripts/apply-human-copy.sh" \
  "plugins/sdd-quality-loop/scripts/apply-human-copy.ps1" \
  "sdd/.approved-context/project-context.approved.yaml" \
  "sdd/.approved-context/provider-bindings.approved.yaml"; do
  got=$(awk -F'\t' -v p="$p" '$3 == p { print $4 }' "$WORK/rows.tsv")
  assert_eq "$got" "concrete" "TEST-038: $p is a concrete entry"
done

# ---------------------------------------------------------------------------
# TEST-021: staged candidates re-derived from the manifest
# ---------------------------------------------------------------------------

for f in "$STAGED_JSON" "$STAGED_GEN"; do
  if [ -f "$f" ]; then
    pass "staged: candidate exists: ${f#"$ROOT/"}"
  else
    fail "staged: candidate exists: ${f#"$ROOT/"}"
  fi
done
for o in guard_invariants.py guard-invariants.generated.js guard-invariants.generated.ps1 guard-invariants.generated.sh; do
  if [ -f "$STAGED_GENDIR/$o" ]; then
    pass "staged: generated output exists: $o"
  else
    fail "staged: generated output exists: $o"
  fi
done

if [ ! -f "$STAGED_JSON" ] || [ ! -f "$STAGED_GEN" ]; then
  printf 'PASS: %s\nFAIL: %s\n' "$PASS" "$FAIL"
  exit 1
fi

# epic_a1_targets must equal the manifest, in order.
"$PY" - "$STAGED_JSON" >"$WORK/staged_epic.txt" <<'PYEOF'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
sys.stdout.write("".join(v + "\n" for v in data["epic_a1_targets"]))
PYEOF
if diff -u "$WORK/paths.txt" "$WORK/staged_epic.txt" >"$WORK/epic.diff" 2>&1; then
  pass "TEST-021: staged JSON epic_a1_targets equals the manifest exactly (ordered)"
else
  fail "TEST-021: staged JSON epic_a1_targets equals the manifest exactly (ordered)"
fi

# protected_gate_suffixes, asserted across the human-apply boundary.
"$PY" - "$LIVE_JSON" >"$WORK/live_protected.txt" <<'PYEOF'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
sys.stdout.write("".join(v + "\n" for v in data["protected_gate_suffixes"]))
PYEOF
cat "$WORK/live_protected.txt" "$WORK/paths.txt" >"$WORK/expect_protected.txt"
"$PY" - "$STAGED_JSON" >"$WORK/staged_protected.txt" <<'PYEOF'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
sys.stdout.write("".join(v + "\n" for v in data["protected_gate_suffixes"]))
PYEOF
# Two allowed states, mirroring TEST-022: BEFORE the human apply the staged
# list is the live list plus the 28 manifest paths; AFTER it, the live list
# IS the staged list. Anything else fails closed. A one-sided "live + 28"
# assertion is correct only until the batch is legitimately applied.
if diff -q "$WORK/expect_protected.txt" "$WORK/staged_protected.txt" >/dev/null 2>&1; then
  pass "TEST-021: staged protected_gate_suffixes is the live list plus the 28 manifest paths (pre-apply)"
elif diff -q "$WORK/live_protected.txt" "$WORK/staged_protected.txt" >/dev/null 2>&1; then
  pass "TEST-021: staged protected_gate_suffixes equals the live list (human apply landed)"
else
  fail "TEST-021: staged protected_gate_suffixes is neither live-plus-manifest nor live itself"
fi

# Apply-state INDEPENDENT, and the stronger of the two: the staged list's
# last 28 entries are exactly the manifest in order, and each manifest path
# occurs exactly once in the whole list.
tail -n 28 "$WORK/staged_protected.txt" >"$WORK/staged_tail.txt"
if diff -q "$WORK/paths.txt" "$WORK/staged_tail.txt" >/dev/null 2>&1; then
  pass "TEST-021: the staged protected_gate_suffixes tail is exactly the 28 manifest paths, in manifest order"
else
  fail "TEST-021: the staged protected_gate_suffixes tail is exactly the 28 manifest paths, in manifest order"
fi
MANIFEST_HITS=$(grep -c -x -F -f "$WORK/paths.txt" "$WORK/staged_protected.txt" || :)
assert_eq "$MANIFEST_HITS" "28" "TEST-021: each manifest path occurs exactly once in staged protected_gate_suffixes"

SP_TOTAL=$(wc -l <"$WORK/staged_protected.txt" | tr -d ' ')
SP_UNIQUE=$(sort "$WORK/staged_protected.txt" | uniq | wc -l | tr -d ' ')
assert_eq "$SP_UNIQUE" "$SP_TOTAL" "TEST-021: staged protected_gate_suffixes has no duplicates"

# The staged generator's own EPIC_A1_TARGETS tuple, read by importing the
# staged module (not by regex), must equal the manifest exactly.
"$PY" - "$STAGED_GEN" >"$WORK/staged_const.txt" 2>"$WORK/staged_const.err" <<'PYEOF'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("staged_gen", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
sys.stdout.write("".join(v + "\n" for v in module.EPIC_A1_TARGETS))
PYEOF
if diff -u "$WORK/paths.txt" "$WORK/staged_const.txt" >"$WORK/const.diff" 2>&1; then
  pass "TEST-021: staged generator EPIC_A1_TARGETS equals the manifest exactly (ordered)"
else
  fail "TEST-021: staged generator EPIC_A1_TARGETS equals the manifest exactly (ordered)"
fi

# Frozen constants must be byte-for-byte the live ones (Out of Scope).
for name in PHASE2_TARGETS BASELINE_SUFFIXES; do
  "$PY" - "$LIVE_GEN" "$name" >"$WORK/live_$name.txt" <<'PYEOF'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("live_gen", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
sys.stdout.write("".join(v + "\n" for v in getattr(module, sys.argv[2])))
PYEOF
  "$PY" - "$STAGED_GEN" "$name" >"$WORK/staged_$name.txt" <<'PYEOF'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("staged_gen", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
sys.stdout.write("".join(v + "\n" for v in getattr(module, sys.argv[2])))
PYEOF
  if diff -u "$WORK/live_$name.txt" "$WORK/staged_$name.txt" >/dev/null 2>&1; then
    pass "TEST-021: frozen constant untouched in the staged generator: $name"
  else
    fail "TEST-021: frozen constant untouched in the staged generator: $name"
  fi
done

# REQUIRED_TOP_LEVEL gains exactly the one new key.
"$PY" - "$LIVE_GEN" "$STAGED_GEN" >"$WORK/topkeys.txt" <<'PYEOF'
import importlib.util, sys
def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module
live = load("live_gen", sys.argv[1]).REQUIRED_TOP_LEVEL
staged = load("staged_gen", sys.argv[2]).REQUIRED_TOP_LEVEL
sys.stdout.write(",".join(sorted(staged - live)) + "\n")
sys.stdout.write(",".join(sorted(live - staged)) + "\n")
sys.stdout.write(("yes" if "epic_a1_targets" in staged else "no") + "\n")
PYEOF
# Apply-state independent: the staged generator always requires the new key.
assert_eq "$(sed -n 3p "$WORK/topkeys.txt")" "yes" \
  "TEST-021: staged REQUIRED_TOP_LEVEL requires epic_a1_targets"
# Two allowed states: pre-apply the staged generator adds the key relative to
# live; post-apply live already has it, so the delta is legitimately empty.
TOP_ADDED=$(sed -n 1p "$WORK/topkeys.txt")
if [ "$TOP_ADDED" = "epic_a1_targets" ]; then
  pass "TEST-021: staged REQUIRED_TOP_LEVEL adds exactly epic_a1_targets (pre-apply)"
elif [ "$TOP_ADDED" = "" ]; then
  pass "TEST-021: staged REQUIRED_TOP_LEVEL matches live, which already requires it (human apply landed)"
else
  fail "TEST-021: staged REQUIRED_TOP_LEVEL adds an unexpected key set [$TOP_ADDED]"
fi
assert_eq "$(sed -n 2p "$WORK/topkeys.txt")" "" \
  "TEST-021: staged REQUIRED_TOP_LEVEL removes no existing key"

# The staged JSON's top-level key set must equal the staged generator's.
"$PY" - "$STAGED_JSON" "$STAGED_GEN" >"$WORK/keyset.txt" <<'PYEOF'
import importlib.util, json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
spec = importlib.util.spec_from_file_location("staged_gen", sys.argv[2])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
sys.stdout.write("match\n" if set(data) == module.REQUIRED_TOP_LEVEL else "mismatch\n")
PYEOF
assert_eq "$(cat "$WORK/keyset.txt")" "match" \
  "TEST-021: staged JSON top-level key set equals the staged generator's REQUIRED_TOP_LEVEL"

# The design decision "no fifth generated-file consumer": the generated
# outputs must NOT project EPIC_A1_TARGETS.
LEAK=""
for o in guard_invariants.py guard-invariants.generated.js guard-invariants.generated.ps1 guard-invariants.generated.sh; do
  if [ -f "$STAGED_GENDIR/$o" ] && grep -q 'EPIC_A1' "$STAGED_GENDIR/$o"; then
    LEAK="$LEAK $o"
  fi
done
assert_eq "$LEAK" "" "TEST-021: no EPIC_A1 projection is emitted into the generated outputs (design decision)"

# Every manifest path must appear in the three value-carrying generated outputs.
for o in guard_invariants.py guard-invariants.generated.js guard-invariants.generated.ps1; do
  missing=0
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    grep -Fq "$p" "$STAGED_GENDIR/$o" 2>/dev/null || missing=$((missing + 1))
  done <"$WORK/paths.txt"
  assert_eq "$missing" "0" "TEST-021: all 28 manifest paths are projected into $o"
done

# ---------------------------------------------------------------------------
# TEST-021: staged-tree --check
# ---------------------------------------------------------------------------

stage_copy() {
  mkdir -p "$1"
  cp -R "$STAGED_LOOP" "$1/" || return 1
  return 0
}
run_check() {
  "$PY" "$1/sdd-quality-loop/scripts/generate-guard-invariants.py" --check \
    >"$WORK/check.out" 2>"$WORK/check.err"
}

if "$PY" "$STAGED_GEN" --check >"$WORK/live_check.out" 2>"$WORK/live_check.err"; then
  pass "TEST-021: staged-tree generate-guard-invariants.py --check passes"
else
  fail "TEST-021: staged-tree generate-guard-invariants.py --check passes ($(cat "$WORK/live_check.err"))"
fi

# The staged --check must never be able to touch the live tree: prove the
# staged generator resolves its canonical JSON inside the staging dir.
"$PY" - "$STAGED_GEN" >"$WORK/anchor.txt" <<'PYEOF'
import sys
from pathlib import Path
script_dir = Path(sys.argv[1]).resolve().parent
sys.stdout.write(str(script_dir.parent / "references" / "guard-invariants.json") + "\n")
PYEOF
assert_eq "$(cat "$WORK/anchor.txt")" "$(cd "$(dirname "$STAGED_JSON")" && pwd -P)/guard-invariants.json" \
  "TEST-021: the staged generator anchors on the STAGED canonical JSON, never the live one"

# TEST-021-MUT: detection power, on throwaway copies only.
#
# Each case asserts the PRISTINE copy passes --check BEFORE mutating it.
# Without that baseline the mutation assertion is vacuous whenever the
# staged tree is already broken (exactly the Red state), and a test that
# cannot distinguish "the mutation was detected" from "everything was
# already failing" has no detection power at all.
mut_baseline() {
  if run_check "$1"; then
    pass "TEST-021-MUT: pristine copy passes --check before mutation ($2)"
  else
    fail "TEST-021-MUT: pristine copy passes --check before mutation ($2)"
  fi
}

if stage_copy "$WORK/mut1"; then
  mut_baseline "$WORK/mut1" "dropped JSON entry"
  "$PY" - "$WORK/mut1/sdd-quality-loop/references/guard-invariants.json" <<'PYEOF'
import json, sys
p = sys.argv[1]
data = json.load(open(p, encoding="utf-8"))
data["protected_gate_suffixes"] = data["protected_gate_suffixes"][:-1]
open(p, "w", encoding="utf-8").write(json.dumps(data, indent=2) + "\n")
PYEOF
  if run_check "$WORK/mut1"; then
    fail "TEST-021-MUT: --check rejects a dropped protected_gate_suffixes entry"
  else
    pass "TEST-021-MUT: --check rejects a dropped protected_gate_suffixes entry"
  fi
else
  fail "TEST-021-MUT: could not stage mutation copy 1"
fi

if stage_copy "$WORK/mut2"; then
  mut_baseline "$WORK/mut2" "dropped EPIC_A1_TARGETS entry"
  gen="$WORK/mut2/sdd-quality-loop/scripts/generate-guard-invariants.py"
  "$PY" - "$gen" <<'PYEOF'
import re, sys
p = sys.argv[1]
text = open(p, encoding="utf-8").read()
m = re.search(r"EPIC_A1_TARGETS = \(\n(.*?)\n\)\n", text, re.S)
lines = m.group(1).split("\n")
open(p, "w", encoding="utf-8").write(
    text.replace(m.group(0), "EPIC_A1_TARGETS = (\n" + "\n".join(lines[:-1]) + "\n)\n", 1)
)
PYEOF
  if run_check "$WORK/mut2"; then
    fail "TEST-021-MUT: --check rejects a dropped EPIC_A1_TARGETS entry"
  else
    pass "TEST-021-MUT: --check rejects a dropped EPIC_A1_TARGETS entry"
  fi
else
  fail "TEST-021-MUT: could not stage mutation copy 2"
fi

if stage_copy "$WORK/mut3"; then
  mut_baseline "$WORK/mut3" "stale generated output"
  printf 'stale\n' >>"$WORK/mut3/sdd-quality-loop/scripts/generated/guard_invariants.py"
  if run_check "$WORK/mut3"; then
    fail "TEST-021-MUT: --check rejects a stale generated output"
  else
    pass "TEST-021-MUT: --check rejects a stale generated output"
  fi
else
  fail "TEST-021-MUT: could not stage mutation copy 3"
fi

# ---------------------------------------------------------------------------
# TEST-022: LIVE files are untouched by this task's agent commit
# ---------------------------------------------------------------------------

check_live() {
  live_path=$1
  staged_path=$2
  baseline=$3
  label=$4
  actual=$(sha256_of "$live_path")
  if [ "$actual" = "$baseline" ]; then
    pass "TEST-022: live $label is at the pre-apply baseline (agent commit changed nothing)"
  elif [ -f "$staged_path" ] && [ "$actual" = "$(sha256_of "$staged_path")" ]; then
    pass "TEST-022: live $label equals this batch's reviewed staged candidate (human apply landed)"
  else
    fail "TEST-022: live $label is neither the pre-apply baseline nor the staged candidate (got $actual)"
  fi
}

check_live "$LIVE_JSON" "$STAGED_JSON" "$PRE_APPLY_JSON" "guard-invariants.json"
check_live "$LIVE_GEN" "$STAGED_GEN" "$PRE_APPLY_GEN" "generate-guard-invariants.py"
check_live "$LIVE_GENDIR/guard_invariants.py" "$STAGED_GENDIR/guard_invariants.py" "$PRE_APPLY_PY" "generated/guard_invariants.py"
check_live "$LIVE_GENDIR/guard-invariants.generated.js" "$STAGED_GENDIR/guard-invariants.generated.js" "$PRE_APPLY_JS" "generated/guard-invariants.generated.js"
check_live "$LIVE_GENDIR/guard-invariants.generated.ps1" "$STAGED_GENDIR/guard-invariants.generated.ps1" "$PRE_APPLY_PS1" "generated/guard-invariants.generated.ps1"
check_live "$LIVE_GENDIR/guard-invariants.generated.sh" "$STAGED_GENDIR/guard-invariants.generated.sh" "$PRE_APPLY_SH" "generated/guard-invariants.generated.sh"

# ---------------------------------------------------------------------------
# TEST-HARDEN: staging integrity
# ---------------------------------------------------------------------------

if [ -f "$MANIFEST_SHA" ]; then
  pass "staging: MANIFEST.sha256 exists"
  BAD_LINES=$(grep -cvE '^[0-9a-f]{64}  [^ ].*$' "$MANIFEST_SHA" || :)
  assert_eq "$BAD_LINES" "0" "staging: every MANIFEST.sha256 line is <64-lowercase-hex><2 spaces><path>"

  # The CI-staging entry belongs to a later task, which owns refreshing it.
  # T-009 must neither drop nor duplicate it. Its digest is validated against
  # the staged bytes by the per-entry loop below, so pinning a literal digest
  # here would assert nothing extra while breaking the moment that later task
  # legitimately refreshes the entry — which is exactly what happened when
  # T-010 appended its own CI step (human ruling, 2026-08-04).
  WF_COUNT=$(grep -cF '  .github/workflows/test.yml' "$MANIFEST_SHA" || :)
  assert_eq "$WF_COUNT" "1" \
    "staging: the CI-staging .github/workflows/test.yml entry is present exactly once"

  # Every entry's digest must match the staged bytes at <stage>/<path>.
  mismatched=0
  missing=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    digest=${line%% *}
    target=${line#*  }
    if [ ! -f "$STAGE/$target" ]; then
      missing=$((missing + 1))
      continue
    fi
    [ "$(sha256_of "$STAGE/$target")" = "$digest" ] || mismatched=$((mismatched + 1))
  done <"$MANIFEST_SHA"
  assert_eq "$missing" "0" "staging: every MANIFEST.sha256 entry has staged bytes at <stage>/<path>"
  assert_eq "$mismatched" "0" "staging: every MANIFEST.sha256 digest matches its staged bytes"

  ENTRIES=$(grep -cE '^[0-9a-f]{64}  ' "$MANIFEST_SHA" || :)
  assert_eq "$ENTRIES" "8" "staging: MANIFEST.sha256 has 8 entries (1 pre-existing + 7 added by T-009)"

  for target in \
    "specs/epic-189-a1-project-context/human-copy/PROTECTED-MANIFEST.md" \
    "$LOOP_REL/references/guard-invariants.json" \
    "$LOOP_REL/scripts/generate-guard-invariants.py" \
    "$LOOP_REL/scripts/generated/guard_invariants.py" \
    "$LOOP_REL/scripts/generated/guard-invariants.generated.js" \
    "$LOOP_REL/scripts/generated/guard-invariants.generated.ps1" \
    "$LOOP_REL/scripts/generated/guard-invariants.generated.sh"; do
    if grep -Fq "  $target" "$MANIFEST_SHA"; then
      pass "staging: MANIFEST.sha256 registers $target"
    else
      fail "staging: MANIFEST.sha256 registers $target"
    fi
  done
else
  fail "staging: MANIFEST.sha256 exists"
fi

# The nested self-path staged copy of the canonical manifest must be
# byte-identical to the canonical one (design.md M15: ONE authoritative
# enumeration, so the publishable copy may never drift from it).
NESTED="$STAGE/specs/epic-189-a1-project-context/human-copy/PROTECTED-MANIFEST.md"
if [ -f "$NESTED" ]; then
  assert_eq "$(sha256_of "$NESTED")" "$(sha256_of "$MANIFEST_MD")" \
    "staging: the nested staged PROTECTED-MANIFEST.md copy is byte-identical to the canonical one"
else
  fail "staging: the nested staged PROTECTED-MANIFEST.md copy exists"
fi

# Self-registration.
if grep -q 'tests/guard-invariants-epic-a1.tests.sh' "$ROOT/tests/run-all.sh"; then
  pass "self-registration: tests/guard-invariants-epic-a1.tests.sh registered in tests/run-all.sh"
else
  fail "self-registration: tests/guard-invariants-epic-a1.tests.sh registered in tests/run-all.sh"
fi
if grep -q 'tests/guard-invariants-epic-a1.tests.ps1' "$ROOT/tests/run-all.ps1"; then
  pass "self-registration: tests/guard-invariants-epic-a1.tests.ps1 registered in tests/run-all.ps1"
else
  fail "self-registration: tests/guard-invariants-epic-a1.tests.ps1 registered in tests/run-all.ps1"
fi
if [ -f "$ROOT/tests/guard-invariants-epic-a1.tests.ps1" ]; then
  pass "self-registration: tests/guard-invariants-epic-a1.tests.ps1 twin exists"
else
  fail "self-registration: tests/guard-invariants-epic-a1.tests.ps1 twin exists"
fi

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
