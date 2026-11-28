#!/usr/bin/env bash
# TDD suite for the projection generator (T-006, REQ-005, AC-025/AC-026).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
GENERATOR_SH="$ROOT/plugins/sdd-quality-loop/scripts/generate-gate-capabilities.sh"
FIXTURES="$ROOT/tests/fixtures/capability-registry"

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
if suite_list="$(bash "$ROOT/tests/run-all.sh" --list)" &&
   grep -Fx 'tests/generate-gate-capabilities.tests.sh' <<< "$suite_list" >/dev/null; then
  ok "run-all.sh registers this suite"
else
  fail "run-all.sh does not register this suite"
fi

# The checked-in projection and vendored contracts must match their canonical
# sources. Both --check modes are read-only (TEST-026(3)); the repository root
# is passed explicitly, never resolved by default.
#
# 2026-11-28 owner decision (ADR-0051 decisions 1 and 4): the staged
# human-copy/ bundle of epic-190, its guard-invariants.json and
# generate-guard-invariants.py candidates and the staged CI workflow
# candidates belonged to the retired human-copy procedure and v1 CI layout.
# The checks on them retired with it; they compared artifacts the product no
# longer ships (guard-invariants) or no longer applies (staged workflows).
if live_out="$(python3 "$ROOT/plugins/sdd-quality-loop/scripts/generate-gate-capabilities.py" --repo-root "$ROOT" --check 2>&1)"; then
  ok "checked-in gate-capabilities.json matches the canonical Registry"
else
  fail "checked-in gate-capabilities.json is stale -- $live_out"
fi
if vendor_out="$(python3 "$ROOT/plugins/sdd-quality-loop/scripts/vendor-capability-registry.py" --check 2>&1)"; then
  ok "vendored plugin contracts match their canonical sources"
else
  fail "vendored plugin contracts drifted -- $vendor_out"
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

printf -- '---- summary: pass=%d fail=%d ----\n' "$PASS" "$FAIL"
if [[ "$FAIL" -eq 0 ]]; then
  printf 'generate-gate-capabilities suite passed (%d checks)\n' "$PASS"
  exit 0
fi
printf 'generate-gate-capabilities suite FAILED (%d passed, %d failed)\n' "$PASS" "$FAIL"
exit 1
