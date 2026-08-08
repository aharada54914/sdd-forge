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
ok() { PASS=$((PASS + 1)); printf 'ok: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'not ok: %s\n' "$1" >&2; }

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

if [[ -f "$STAGED_WORKFLOW" ]] && grep -q 'tests/generate-gate-capabilities.tests.sh' "$STAGED_WORKFLOW" && grep -q 'tests/generate-gate-capabilities.tests.ps1' "$STAGED_WORKFLOW"; then
  ok "human-copy: staged workflow candidate registers this suite's CI steps"
else
  fail "human-copy: staged workflow candidate missing this suite's CI steps"
fi
if [[ -f "$STAGED_MANIFEST" ]]; then
  staged_hash="$(shasum -a 256 "$STAGED_WORKFLOW" | awk '{print $1}')"
  manifest_hash="$(grep -F 'workflows/test.yml' "$STAGED_MANIFEST" | awk '{print $1}')"
  if [[ -n "$manifest_hash" && "$staged_hash" == "$manifest_hash" ]]; then
    ok "human-copy: staged workflow candidate sha256 matches MANIFEST.sha256"
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

# Done When #3 (tasks.md): "a grep self-check confirms no version string was
# mutated outside scripts/bump-version.sh" -- this task's own production
# files must never carry a hand-mutated, semver-looking version string
# (design.md Constraint Compliance: "Version bumps only via
# scripts/bump-version.sh"; this feature introduces no version-mutation
# path). Previously unimplemented in this suite (quality-gate remediation,
# 2026-08-09).
version_hit=0
for name in generate-gate-capabilities.py generate-gate-capabilities.sh generate-gate-capabilities.ps1; do
  target="$ROOT/plugins/sdd-quality-loop/scripts/$name"
  if [[ -f "$target" ]] && grep -qE '[0-9]+\.[0-9]+\.[0-9]+' "$target"; then
    version_hit=1
  fi
done
if [[ "$version_hit" -eq 0 ]]; then
  ok "Done When #3: no version string was hand-mutated in this task's production files (grep self-check)"
else
  fail "Done When #3: a semver-looking version string was found in this task's production files"
fi

printf -- '---- summary: pass=%d fail=%d ----\n' "$PASS" "$FAIL"
if [[ "$FAIL" -eq 0 ]]; then
  printf 'generate-gate-capabilities suite passed (%d checks)\n' "$PASS"
  exit 0
else
  printf 'generate-gate-capabilities suite FAILED (%d passed, %d failed)\n' "$PASS" "$FAIL"
  exit 1
fi
