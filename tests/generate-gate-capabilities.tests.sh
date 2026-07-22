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

printf -- '---- summary: pass=%d fail=%d ----\n' "$PASS" "$FAIL"
if [[ "$FAIL" -eq 0 ]]; then
  printf 'generate-gate-capabilities suite passed (%d checks)\n' "$PASS"
  exit 0
else
  printf 'generate-gate-capabilities suite FAILED (%d passed, %d failed)\n' "$PASS" "$FAIL"
  exit 1
fi
