#!/usr/bin/env bash
# TDD suite for the projection generator (T-006, REQ-005, AC-025/AC-026).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
GENERATOR_SH="$ROOT/plugins/sdd-quality-loop/scripts/generate-gate-capabilities.sh"
FIXTURES="$ROOT/tests/fixtures/capability-registry"
STAGED_WORKFLOW="$ROOT/specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml"
STAGED_MANIFEST="$ROOT/specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256"

PASS=0
FAIL=0
DESIGNED_RED=0
ok() { PASS=$((PASS + 1)); printf 'ok: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'not ok: %s\n' "$1" >&2; }
# Established repo pattern for "stays red until a human applies a staged
# candidate" assertions (tests/deterministic-lane-selfcheck.tests.sh
# TEST-020's designed_red(), tests/design-system-contract.tests.sh
# TEST-039, tests/quality-gate-cycle-limit.tests.sh QGCL-016): a counter
# distinct from FAIL, so the suite's own summary can tell a genuine defect
# apart from an expected pre-human-copy state. A DESIGNED-RED result still
# makes the suite's own exit code non-zero (see footer) -- this is not a
# way to make the suite "pass" without the human action, it is a way to
# report that state honestly and deterministically instead of via prose.
designed_red() { DESIGNED_RED=$((DESIGNED_RED + 1)); printf 'DESIGNED-RED (pre-human-copy): %s\n' "$1" >&2; }

# Isolated repo-root fixture tree, built fresh per invocation (mktemp), never
# a static tracked fixture directory (this repo IS a git checkout, and the
# generator's own default resolution must never be exercised against it).
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
mkdir -p "$WORKDIR/contracts" "$WORKDIR/plugins/sdd-quality-loop/scripts/generated"
cp "$FIXTURES/gate-capabilities-clean-registry.json" "$WORKDIR/contracts/capability-registry.json"
OUTPUT="$WORKDIR/plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json"

run_generate() {
  # $@ = extra args (e.g. --check). Sets OUT, RC.
  OUT="$(bash "$GENERATOR_SH" --repo-root "$WORKDIR" "$@" 2>&1)"
  RC=$?
}

# =====================================================================
# TEST-025: generated-header conformance + content correctness
# =====================================================================
run_generate
if [[ "$RC" -eq 0 ]]; then
  ok "TEST-025(1): generator exits 0 against a clean fixture Registry"
else
  fail "TEST-025(1): generator exited $RC: $OUT"
fi

if [[ -f "$OUTPUT" ]] && diff -q "$OUTPUT" "$FIXTURES/gate-capabilities-clean-expected.json" >/dev/null 2>&1; then
  ok "TEST-025(2): fresh output is byte-identical to the golden expected projection"
else
  fail "TEST-025(2): fresh output diverges from the golden expected projection"
fi

py_out="$(python3 - "$OUTPUT" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
g = data.get("_generated", {})
checks = [
    (g.get("source") == "contracts/capability-registry.json", "source"),
    (g.get("schema_version") == 1, "schema_version"),
    (isinstance(g.get("sha256"), str) and len(g["sha256"]) == 64, "sha256"),
    (g.get("notice") == "This file is generated. Do not edit.", "notice"),
]
print("PASS" if all(c[0] for c in checks) else "FAIL:" + ",".join(n for c, n in checks if not c))
PYEOF
)"
if [[ "$py_out" == "PASS" ]]; then
  ok "TEST-025(3): _generated block carries source/schema_version/sha256/notice correctly"
else
  fail "TEST-025(3): _generated block malformed ($py_out)"
fi

if [[ "$(grep -c '^#' "$OUTPUT" 2>/dev/null || true)" -eq 0 ]]; then
  ok "TEST-025(4): no comment-line ('# Generated...') convention anywhere in the projection"
else
  fail "TEST-025(4): unexpected '#'-prefixed line found in the projection"
fi

map_out="$(python3 - "$OUTPUT" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
m = data.get("capability_gate_map", {})
ok = (
    m.get("first-capability") == ["check-alpha-impl", "check-zeta-impl"]
    and m.get("second-capability") == ["check-alpha-impl"]
    and m.get("no-gates-capability") == []
    and all(g.get("stage") == "implementation" for g in data.get("gates", []))
    and [g["id"] for g in data.get("gates", [])] == ["check-alpha-impl", "check-zeta-impl"]
)
print("PASS" if ok else "FAIL")
PYEOF
)"
if [[ "$map_out" == "PASS" ]]; then
  ok "TEST-025(5): capability_gate_map omits the promotion-stage gate (dangling-reference filtering), sorted, empty-array capability preserved"
else
  fail "TEST-025(5): capability_gate_map / gates filtering incorrect"
fi

# =====================================================================
# TEST-026: drift detection (negative canary) + no-write proof
# =====================================================================
run_generate --check
if [[ "$RC" -eq 0 ]]; then
  ok "TEST-026(1): --check exits 0 against a freshly-regenerated, unmutated file"
else
  fail "TEST-026(1): --check exited $RC against a clean file: $OUT"
fi

cp "$FIXTURES/gate-capabilities-mutated.json" "$OUTPUT"
run_generate --check
if [[ "$RC" -ne 0 && "$OUT" == *"stale"* ]]; then
  ok "TEST-026(2): --check exits non-zero with a 'stale' diagnostic against a hand-mutated file"
else
  fail "TEST-026(2): expected non-zero exit + 'stale' diagnostic -- actual (rc=$RC): $OUT"
fi

run_generate
before_mtime="$(python3 -c "import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)" "$OUTPUT")"
sleep 1
run_generate --check
after_mtime="$(python3 -c "import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)" "$OUTPUT")"
if [[ "$RC" -eq 0 && "$before_mtime" == "$after_mtime" ]]; then
  ok "TEST-026(3): --check performs no filesystem write (mtime unchanged)"
else
  fail "TEST-026(3): mtime changed across a --check invocation (rc=$RC, before=$before_mtime, after=$after_mtime)"
fi

# =====================================================================
# Missing/invalid canonical Registry: fail closed
# =====================================================================
EMPTYDIR="$(mktemp -d)"
OUT="$(bash "$GENERATOR_SH" --repo-root "$EMPTYDIR" 2>&1)"; RC=$?
rm -rf "$EMPTYDIR"
if [[ "$RC" -ne 0 && "$OUT" == *"not found"* ]]; then
  ok "TEST-026(4): missing canonical Registry fails closed with a diagnostic"
else
  fail "TEST-026(4): expected fail-closed on missing Registry -- actual (rc=$RC): $OUT"
fi

# =====================================================================
# Suite/CI registration
# =====================================================================
if grep -q 'tests/generate-gate-capabilities.tests.sh' "$ROOT/tests/run-all.sh"; then
  ok "run-all.sh registers this suite"
else
  fail "run-all.sh does not register this suite"
fi

# Quality-gate cycle 3 remediation (2026-08-09): this check previously only
# grepped for this suite's own two test-invocation step names, which the
# STALE human-copy/ file happens to already contain (T-006 appended them
# before the staleness below was discovered) -- so it read "ok" even though
# the SAME staged file is missing the "--check" drift-lock step this task's
# own Scope requires ("stage the .github/workflows/test.yml candidate...
# adding the --check steps") and predates the CI job-split commit
# (3baadda5). The cycle-2 quality-gate Critical named this exact pair of
# "ok:" results as contradicting the DESIGNED-RED checks added below
# ("納品スイート自身が旧 staged workflow を ok: 2 件で肯定している" --
# assertions affirming a stale artifact contradict the designed-red).
# Reviewed per that finding: this check now also requires the --check
# step, so a stale human-copy/ file correctly reports DESIGNED-RED (not a
# false "ok") until a human replaces it with drafts/human-copy-candidate/.
if [[ -f "$STAGED_WORKFLOW" ]] \
  && grep -q 'tests/generate-gate-capabilities.tests.sh' "$STAGED_WORKFLOW" \
  && grep -q 'tests/generate-gate-capabilities.tests.ps1' "$STAGED_WORKFLOW" \
  && grep -Fq 'generate-gate-capabilities.py --check' "$STAGED_WORKFLOW"; then
  ok "human-copy: staged workflow candidate registers this suite's CI steps, including the --check drift-lock step (Scope)"
else
  designed_red "human-copy: staged workflow candidate is STALE -- missing this suite's --check drift-lock step and/or predates the current CI job structure -- HUMAN ACTION REQUIRED: replace specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml with specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/.github/workflows/test.yml.candidate (see that directory's README.md), then re-run this suite"
fi
if [[ -f "$STAGED_MANIFEST" ]]; then
  staged_hash="$(shasum -a 256 "$STAGED_WORKFLOW" | awk '{print $1}')"
  manifest_hash="$(grep -F 'workflows/test.yml' "$STAGED_MANIFEST" | awk '{print $1}')"
  if [[ -n "$manifest_hash" && "$staged_hash" == "$manifest_hash" ]]; then
    # NOTE: this proves only that the staged file matches its own recorded
    # MANIFEST hash (internal self-consistency) -- it is NOT a freshness or
    # completeness proof; a stale-but-internally-consistent bundle still
    # passes this specific, narrower check by design. See the DESIGNED-RED
    # checks in this block and below for the freshness proof the cycle-2
    # Critical asked for.
    ok "human-copy: staged workflow candidate sha256 matches MANIFEST.sha256 (self-consistency only, not a freshness proof)"
  else
    fail "human-copy: staged workflow candidate sha256 does not match MANIFEST.sha256"
  fi
else
  fail "human-copy: MANIFEST.sha256 missing"
fi

# =====================================================================
# Quality-gate remediation regression lock (2026-08-09): the bundle staged
# under human-copy/ was found to have been built from a pre-epic-189-a1-merge
# baseline, so applying it to the current live tree would silently DROP the
# epic_a1_targets top-level key (28 paths) and tests/guard-parity.tests.sh
# from phase2_human_copy_targets -- a regression this suite's own prior
# checks (above) could not detect, since they only ever compared the staged
# bundle against ITSELF (internal self-consistency), never against live.
# The regenerated candidate lives outside human-copy/ (agents may not write
# there) at drafts/human-copy-candidate/, with each file named
# `<target>.candidate` so its path does not match a protected-gate suffix
# (see that directory's README.md). This block is a permanent guard against
# the same class of regression recurring: it fails if the CANDIDATE ever
# drops a path/key the LIVE canonical file already protects.
# =====================================================================
CANDIDATE_DIR="$ROOT/specs/epic-190-a2-capability-registry/drafts/human-copy-candidate"
CANDIDATE_GUARD_JSON="$CANDIDATE_DIR/plugins/sdd-quality-loop/references/guard-invariants.json.candidate"
LIVE_GUARD_JSON="$ROOT/plugins/sdd-quality-loop/references/guard-invariants.json"

no_regression_check() {
  # $1 = candidate guard-invariants.json path. Exits 0 (prints PASS) iff the
  # candidate is a pure superset of live across the top-level key set,
  # protected_gate_suffixes, phase2_human_copy_targets, and epic_a1_targets
  # (when present in live); exits 1 (prints FAIL + the exact removed
  # entries) otherwise.
  python3 - "$1" "$LIVE_GUARD_JSON" <<'PYEOF'
import json, sys
candidate_path, live_path = sys.argv[1], sys.argv[2]
live = json.load(open(live_path, encoding="utf-8"))
try:
    candidate = json.load(open(candidate_path, encoding="utf-8"))
except FileNotFoundError:
    print("FAIL: candidate file not found: " + candidate_path)
    sys.exit(1)

removed_total = []


def check(label, live_values, candidate_values):
    live_set, candidate_set = set(live_values), set(candidate_values)
    removed = sorted(live_set - candidate_set)
    if removed:
        removed_total.extend((label, item) for item in removed)


check("top-level keys", live.keys(), candidate.keys())
check("protected_gate_suffixes", live.get("protected_gate_suffixes", []), candidate.get("protected_gate_suffixes", []))
check("phase2_human_copy_targets", live.get("phase2_human_copy_targets", []), candidate.get("phase2_human_copy_targets", []))
if "epic_a1_targets" in live:
    check("epic_a1_targets", live["epic_a1_targets"], candidate.get("epic_a1_targets", []))

if removed_total:
    print(f"FAIL: candidate drops {len(removed_total)} live-protected entr(y/ies):")
    for label, item in removed_total:
        print(f"  [{label}] {item}")
    sys.exit(1)
print("PASS: candidate is a pure superset of live (0 removals)")
sys.exit(0)
PYEOF
}

if no_regression_out="$(no_regression_check "$CANDIDATE_GUARD_JSON" 2>&1)"; then
  ok "QG-fix: regenerated guard-invariants candidate drops no live-protected path/key"
else
  fail "QG-fix: regenerated guard-invariants candidate drops no live-protected path/key -- $no_regression_out"
fi

# =====================================================================
# Quality-gate cycle 3 remediation (2026-08-09) -- Major finding 5: the
# no_regression_check block above only ever inspects the JSON side of the
# staged bundle. tasks.md's own Protected Files section warns this is
# insufficient: "Editing guard-invariants.json alone... is therefore
# insufficient -- generate-guard-invariants.py itself must be edited in the
# same staged change so PHASE2_TARGETS gains the identical seven new
# entries" -- so a JSON-only superset check cannot catch a candidate whose
# .py sibling was swapped back to a stale/destructive version while the
# JSON candidate stayed correct. Mutation-verified as part of this
# remediation (see this task's own implementation report, "Quality-gate
# remediation correction" section): swapping the CANDIDATE .py for the
# real human-copy/ (pre-epic-189-a1-merge) .py leaves the check below
# FAILING, where the JSON-only check above alone would have stayed green.
# =====================================================================
LIVE_PY="$ROOT/plugins/sdd-quality-loop/scripts/generate-guard-invariants.py"
CANDIDATE_PY="$CANDIDATE_DIR/plugins/sdd-quality-loop/scripts/generate-guard-invariants.py.candidate"
HUMAN_COPY_GUARD_JSON="$ROOT/specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/references/guard-invariants.json"
HUMAN_COPY_PY="$ROOT/specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/scripts/generate-guard-invariants.py"

py_tuple_superset_check() {
  # $1 = a generate-guard-invariants.py(.candidate) path. Loads it as a
  # Python module (importlib, stdlib only; __name__ != "__main__" so
  # main() never runs on import) and compares its PHASE2_TARGETS /
  # BASELINE_SUFFIXES / EPIC_A1_TARGETS module-level tuples against
  # $LIVE_PY's own tuples. Prints PASS and exits 0 iff every live entry in
  # each tuple is also present in the corresponding argument's tuple (a
  # pure superset, 0 removals); prints FAIL + the exact removed entries
  # and exits 1 otherwise (including when the argument's own attribute is
  # absent entirely, e.g. a pre-epic-189-a1-merge script with no
  # EPIC_A1_TARGETS constant at all -- getattr(..., ()) reads that as "no
  # entries", which is correctly a removal of every live entry).
  python3 - "$1" "$LIVE_PY" <<'PYEOF'
import importlib.machinery
import importlib.util
import sys

target_path, live_path = sys.argv[1], sys.argv[2]


def load(path, name):
    loader = importlib.machinery.SourceFileLoader(name, path)
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


live = load(live_path, "live_guard_invariants_gen")
try:
    target = load(target_path, "target_guard_invariants_gen")
except Exception as exc:
    # Any load failure (syntax error, missing file, etc.) is itself a
    # FAIL, not a crash of this check.
    print(f"FAIL: script failed to load: {exc}")
    sys.exit(1)

removed_total = []


def check(label, live_values, target_values):
    live_set, target_set = set(live_values), set(target_values)
    removed = sorted(live_set - target_set)
    if removed:
        removed_total.extend((label, item) for item in removed)


for attr in ("PHASE2_TARGETS", "BASELINE_SUFFIXES", "EPIC_A1_TARGETS"):
    check(attr, getattr(live, attr, ()), getattr(target, attr, ()))

if removed_total:
    print(f"FAIL: script drops {len(removed_total)} live-protected entr(y/ies):")
    for label, item in removed_total:
        print(f"  [{label}] {item}")
    sys.exit(1)
print("PASS: script tuples are a pure superset of live (0 removals)")
sys.exit(0)
PYEOF
}

if candidate_py_out="$(py_tuple_superset_check "$CANDIDATE_PY" 2>&1)"; then
  ok "QG-fix: regenerated generate-guard-invariants.py candidate's PHASE2_TARGETS/BASELINE_SUFFIXES/EPIC_A1_TARGETS are a pure superset of live (.py, not just JSON)"
else
  fail "QG-fix: regenerated generate-guard-invariants.py candidate drops live-protected .py tuple entries -- $candidate_py_out"
fi

# =====================================================================
# Quality-gate cycle 3 remediation (2026-08-09) -- Critical finding: the
# ACTUAL trap. tasks.md Done When #2, AC-029(a), and AC-030 all point a
# human at applying whatever is staged under human-copy/ -- NOT at
# drafts/human-copy-candidate/. The two checks below inspect that REAL
# location directly; they are the deterministic gate the cycle-2 evaluator
# asked for ("罠が残置されたまま、決定論的ゲートが無い"). They intentionally
# FAIL (DESIGNED-RED) for as long as human-copy/ still holds the
# pre-epic-189-a1-merge bundle, and turn GREEN automatically the moment a
# human replaces human-copy/'s contents with drafts/human-copy-candidate/'s
# (that directory's own README.md "Human apply step"). This is not a bug
# in this suite -- it is the requested structural gate, following this
# repository's own established pattern for "red until a human applies a
# staged candidate" assertions (tests/deterministic-lane-selfcheck.tests.sh
# TEST-020, tests/design-system-contract.tests.sh TEST-039).
# =====================================================================
if human_copy_json_out="$(no_regression_check "$HUMAN_COPY_GUARD_JSON" 2>&1)"; then
  ok "human-copy/ staged guard-invariants.json is a pure superset of live (human apply already landed)"
else
  designed_red "human-copy/ staged guard-invariants.json is STALE and would DROP live-protected paths/keys if applied -- $human_copy_json_out -- HUMAN ACTION REQUIRED: replace specs/epic-190-a2-capability-registry/human-copy/ with specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/ (see that directory's README.md), then re-run this suite"
fi

if human_copy_py_out="$(py_tuple_superset_check "$HUMAN_COPY_PY" 2>&1)"; then
  ok "human-copy/ staged generate-guard-invariants.py is a pure superset of live (human apply already landed)"
else
  designed_red "human-copy/ staged generate-guard-invariants.py is STALE (e.g. missing EPIC_A1_TARGETS entirely) and would DROP live-protected .py tuple entries if applied -- $human_copy_py_out -- HUMAN ACTION REQUIRED: same as above"
fi

# The staged CI workflow candidate must also be rebuilt against the current
# live test.yml (post-3baadda5 job split), not the pre-split staged file,
# and must carry the generate-gate-capabilities.py --check drift lock plus
# T-005's generate-registry-digest suite registration.
CANDIDATE_WORKFLOW="$CANDIDATE_DIR/.github/workflows/test.yml.candidate"
if [[ -f "$CANDIDATE_WORKFLOW" ]] \
  && grep -Fq 'generate-gate-capabilities.py --check' "$CANDIDATE_WORKFLOW" \
  && grep -Fq 'tests/generate-registry-digest.tests.sh' "$CANDIDATE_WORKFLOW" \
  && grep -Fq 'tests/generate-registry-digest.tests.ps1' "$CANDIDATE_WORKFLOW"; then
  ok "QG-fix: rebuilt CI workflow candidate carries the gate-capabilities --check step and the generate-registry-digest suite"
else
  fail "QG-fix: rebuilt CI workflow candidate is missing the gate-capabilities --check step or the generate-registry-digest suite"
fi

CANDIDATE_MANIFEST="$CANDIDATE_DIR/MANIFEST.sha256.candidate"
if [[ -f "$CANDIDATE_MANIFEST" ]]; then
  candidate_workflow_hash="$(shasum -a 256 "$CANDIDATE_WORKFLOW" | awk '{print $1}')"
  candidate_manifest_hash="$(grep -F 'workflows/test.yml' "$CANDIDATE_MANIFEST" | awk '{print $1}')"
  if [[ -n "$candidate_manifest_hash" && "$candidate_workflow_hash" == "$candidate_manifest_hash" ]]; then
    ok "QG-fix: rebuilt CI workflow candidate sha256 matches its own MANIFEST.sha256.candidate"
  else
    fail "QG-fix: rebuilt CI workflow candidate sha256 does not match its own MANIFEST.sha256.candidate"
  fi
else
  fail "QG-fix: MANIFEST.sha256.candidate missing"
fi

# =====================================================================
# Quality-gate cycle 3 remediation (2026-08-09) -- Minor finding 10: the
# checks above only ever grep for specific substrings (this suite's own
# step names, the --check step) or compare a whole-file hash -- neither
# can detect a candidate that silently DROPS an unrelated live job
# wholesale (a structural regression, not a substring regression). Add a
# genuinely structural check: every job key present in the LIVE workflow
# must also be present in the candidate (a pure superset of job names),
# using the same line-based `jobs:`-block parser
# tests/deterministic-lane-selfcheck.tests.sh's job_keys() already
# established for this exact purpose in this repository (text markers
# only, no YAML-parsing dependency, per that file's own "Technique" note).
# Applied to BOTH the drafts/ candidate (expected PASS) and the REAL
# human-copy/ workflow (expected DESIGNED-RED): the real human-copy/ file
# predates the `test`-job parallel split (commit 3baadda5) and is missing
# three whole jobs outright (measured: `installers`, `loops-routing`,
# `version-gates`), not just a missing step inside an existing job.
# =====================================================================
LIVE_WORKFLOW="$ROOT/.github/workflows/test.yml"

job_keys() {
  # $1 = a GitHub Actions workflow YAML path. Prints each top-level job
  # key under `jobs:`, one per line.
  python3 - "$1" <<'PYEOF'
import sys
lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
injobs = False
for ln in lines:
    if ln.rstrip() == "jobs:":
        injobs = True
        continue
    if injobs:
        if ln and not ln.startswith(" "):
            break
        if ln.startswith("  ") and not ln.startswith("   ") and ln.rstrip().endswith(":"):
            print(ln.strip().rstrip(":"))
PYEOF
}

job_superset_check() {
  # $1 = candidate/target workflow path. Prints PASS/FAIL and exits
  # 0/1 depending on whether every LIVE_WORKFLOW job key also appears in
  # the target's job key set.
  local target="$1" missing=()
  if [[ ! -f "$target" ]]; then
    printf 'FAIL: workflow not found: %s\n' "$target"
    return 1
  fi
  local live_jobs target_jobs job found
  live_jobs="$(job_keys "$LIVE_WORKFLOW")"
  target_jobs="$(job_keys "$target")"
  while IFS= read -r job; do
    [[ -z "$job" ]] && continue
    found=0
    while IFS= read -r candidate_job; do
      [[ "$candidate_job" == "$job" ]] && found=1 && break
    done <<<"$target_jobs"
    [[ "$found" -eq 0 ]] && missing+=("$job")
  done <<<"$live_jobs"
  if [[ "${#missing[@]}" -gt 0 ]]; then
    printf 'FAIL: candidate drops %d live job(s): %s\n' "${#missing[@]}" "${missing[*]}"
    return 1
  fi
  printf 'PASS: candidate carries every live job (0 dropped)\n'
  return 0
}

if candidate_jobs_out="$(job_superset_check "$CANDIDATE_WORKFLOW" 2>&1)"; then
  ok "QG-fix: rebuilt CI workflow candidate is a job-set superset of live (structural, not just a step-name grep)"
else
  fail "QG-fix: rebuilt CI workflow candidate drops a live job -- $candidate_jobs_out"
fi

if human_copy_jobs_out="$(job_superset_check "$STAGED_WORKFLOW" 2>&1)"; then
  ok "human-copy/ staged workflow is a job-set superset of live (human apply already landed)"
else
  designed_red "human-copy/ staged workflow is STALE and would DROP whole live job(s) if applied -- $human_copy_jobs_out -- HUMAN ACTION REQUIRED: replace specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml with specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/.github/workflows/test.yml.candidate (see that directory's README.md), then re-run this suite"
fi

# Done When #4 (tasks.md, "Suite registration + structural checks"): "a
# grep self-check confirms no version string was mutated outside
# scripts/bump-version.sh" -- this task's own production files must never
# carry a hand-mutated, semver-looking version string (design.md Constraint
# Compliance: "Version bumps only via scripts/bump-version.sh"; this
# feature introduces no version-mutation path). Previously unimplemented in
# this suite (quality-gate remediation, 2026-08-09). Corrected label
# (quality-gate cycle 3, 2026-08-09): this is Done When item #4, not #3 --
# #3 is "Test-registration procedure proof" (TEST-030); #4 is "Suite
# registration + structural checks", which is where tasks.md's own text
# places this grep self-check.
version_hit=0
for name in generate-gate-capabilities.py generate-gate-capabilities.sh generate-gate-capabilities.ps1; do
  target="$ROOT/plugins/sdd-quality-loop/scripts/$name"
  if [[ -f "$target" ]] && grep -qE '[0-9]+\.[0-9]+\.[0-9]+' "$target"; then
    version_hit=1
  fi
done
if [[ "$version_hit" -eq 0 ]]; then
  ok "Done When #4: no version string was hand-mutated in this task's production files (grep self-check)"
else
  fail "Done When #4: a semver-looking version string was found in this task's production files"
fi

printf -- '---- summary: pass=%d fail=%d designed-red=%d ----\n' "$PASS" "$FAIL" "$DESIGNED_RED"
if [[ "$FAIL" -eq 0 && "$DESIGNED_RED" -eq 0 ]]; then
  printf 'generate-gate-capabilities suite passed (%d checks)\n' "$PASS"
  exit 0
elif [[ "$FAIL" -eq 0 ]]; then
  printf 'generate-gate-capabilities suite is DESIGNED-RED (%d passed, %d designed-red pending human apply, 0 genuine failures)\n' "$PASS" "$DESIGNED_RED"
  printf 'HUMAN ACTION REQUIRED: replace specs/epic-190-a2-capability-registry/human-copy/ with specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/ (see that directory'"'"'s README.md "Human apply step"), then re-run this suite.\n'
  exit 1
else
  printf 'generate-gate-capabilities suite FAILED (%d passed, %d failed, %d designed-red)\n' "$PASS" "$FAIL" "$DESIGNED_RED"
  exit 1
fi
