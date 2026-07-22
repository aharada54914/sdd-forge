#!/usr/bin/env bash
# TDD suite for the Registry validator (T-004, REQ-003, nine checks a-i).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
VALIDATOR_SH="$ROOT/plugins/sdd-quality-loop/scripts/validate-capability-registry.sh"
FIXTURES="$ROOT/tests/fixtures/capability-registry"
IDENTITY_REPO="$FIXTURES/identity-bidirectional-repo"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); printf 'ok: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'not ok: %s\n' "$1" >&2; }

run_validate() {
  # $1 = fixture basename, $2.. = extra args (e.g. --repo-root). Sets OUT, RC.
  local fixture="$1"; shift
  OUT="$(bash "$VALIDATOR_SH" --registry "$FIXTURES/$fixture.json" "$@" 2>&1)"
  RC=$?
}

assert_contains() {
  local name="$1" needle="$2"
  if [[ "$RC" -ne 0 && "$OUT" == *"$needle"* ]]; then
    ok "$name"
  else
    fail "$name: expected non-zero exit + diagnostic containing '$needle' -- actual (rc=$RC): $OUT"
  fi
}

assert_not_contains() {
  local name="$1" needle="$2"
  if [[ "$OUT" != *"$needle"* ]]; then
    ok "$name"
  else
    fail "$name: unexpectedly found '$needle' -- actual: $OUT"
  fi
}

# =====================================================================
# TEST-028: structural placement (this suite's own setup assertion, AC-028)
# =====================================================================
if [[ ! -e "$ROOT/plugins/sdd-capability" ]]; then
  ok "TEST-028: plugins/sdd-capability/ does not exist"
else
  fail "TEST-028: plugins/sdd-capability/ unexpectedly exists"
fi
placement_ok=1
for f in \
  plugins/sdd-quality-loop/scripts/evaluate-predicate.py \
  plugins/sdd-quality-loop/scripts/registry_discovery.py \
  plugins/sdd-quality-loop/scripts/vendor-capability-registry.py \
  plugins/sdd-quality-loop/scripts/validate-capability-registry.py \
  plugins/sdd-quality-loop/references/provider-terms.json
do
  [[ -f "$ROOT/$f" ]] || { placement_ok=0; fail "TEST-028: expected REQ-002..005 file missing under plugins/sdd-quality-loop/: $f"; }
done
[[ "$placement_ok" -eq 1 ]] && ok "TEST-028: every REQ-002..005 script/reference file lives under plugins/sdd-quality-loop/"

# =====================================================================
# TEST-014 (a): Gate-ID uniqueness
# =====================================================================
run_validate validate-registry-dup-gate-id
assert_contains "TEST-014: gate-id-duplicate detected" "registry: gate-id-duplicate: dup-gate"

# =====================================================================
# TEST-015 (b): stage-completeness
# =====================================================================
run_validate validate-registry-missing-impl-ref
assert_contains "TEST-015: implementation-ref-missing (field absent) detected" "registry: implementation-ref-missing: no-ref-gate"

run_validate validate-registry-impl-ref-nonexistent-path
assert_contains "TEST-015: implementation-ref-missing (path does not exist) detected" "registry: implementation-ref-missing: bad-path-gate"

# =====================================================================
# TEST-016/TEST-017 (c): Gate implementation identity, bidirectional
# =====================================================================
run_validate validate-registry-identity-bidirectional --repo-root "$IDENTITY_REPO"
assert_contains "TEST-016/017: unregistered check-*.py master flagged" "registry: unregistered-script: plugins/sdd-quality-loop/scripts/check-unregistered.py"
assert_not_contains "TEST-017(i): a properly-referenced master is not flagged" "check-registered.py"
assert_not_contains "TEST-017(ii): a script outside the scan root is never flagged" "check-outside.py"
assert_not_contains "TEST-017(iv): a non-check-* script under the scan root is never scanned" "emit-run-record.py"

# =====================================================================
# TEST-018 (e): defense-in-depth stage-missing re-assertion (schema-bypassing fixture)
# =====================================================================
run_validate validate-registry-stage-missing
assert_contains "TEST-018: stage-missing re-asserted independent of schema" "registry: stage-missing: no-stage-gate"

# =====================================================================
# TEST-019 (d): no Pack-owned Gate definitions (repository-wide forward-guard)
# =====================================================================
run_validate validate-registry-identity-bidirectional --repo-root "$IDENTITY_REPO"
assert_contains "TEST-019: pack-owned gates.yaml detected repository-wide" "registry: pack-owns-gate-definition: capability-packs/some-pack/gates.yaml"

# =====================================================================
# TEST-020 (g): Provider-name contamination + clean-fixture false-positive check
# =====================================================================
run_validate validate-registry-provider-name
assert_contains "TEST-020: provider-name-detected fires on a real provider term" "registry: provider-name-detected:"

run_validate validate-registry-provider-clean
assert_not_contains "TEST-020: provider-neutral vocabulary (durable_workflow) is not a false positive" "provider-name-detected"

# =====================================================================
# TEST-021 (f): referential integrity (validator-level only)
# =====================================================================
run_validate validate-registry-dangling-gate-ref
assert_contains "TEST-021: dangling-gate-reference detected" "registry: dangling-gate-reference: dangling-cap -> nonexistent-gate-id"

# =====================================================================
# TEST-022 (h): lite-upgrade-reason-catalog conformance, fail-closed
# =====================================================================
run_validate validate-registry-unknown-upgrade-reason
assert_contains "TEST-022: unknown-upgrade-reason fails closed against the real catalog" "registry: unknown-upgrade-reason: bad-reason-cap -> 'not_a_real_reason'"

# =====================================================================
# TEST-039 (i): Capability-ID uniqueness, independent of (a); combined-duplicate fixture
# =====================================================================
run_validate validate-registry-dup-capability-id
assert_contains "TEST-039: capability-id-duplicate detected" "registry: capability-id-duplicate: dup-cap"

run_validate validate-registry-combined-duplicate
assert_contains "TEST-039: combined fixture -- gate-id-duplicate surfaces" "registry: gate-id-duplicate: dup-gate-combo"
assert_contains "TEST-039: combined fixture -- capability-id-duplicate surfaces (neither masks the other)" "registry: capability-id-duplicate: dup-cap-combo"

# =====================================================================
# Fully-clean fixture: proves a negative -- the suite cannot pass vacuously
# =====================================================================
run_validate validate-registry-fully-clean
if [[ "$RC" -eq 0 && "$OUT" == *"all 9 checks passed"* ]]; then
  ok "fully-clean fixture: all 9 checks pass on valid input (negative proof)"
else
  fail "fully-clean fixture: expected exit 0 + all-9-checks-passed message -- actual (rc=$RC): $OUT"
fi

# =====================================================================
# Suite/CI registration self-checks
# =====================================================================
if grep -q 'tests/validate-capability-registry.tests.sh' "$ROOT/tests/run-all.sh"; then
  ok "self-registration: validate-capability-registry.tests.sh registered in tests/run-all.sh"
else
  fail "self-registration: validate-capability-registry.tests.sh NOT registered in tests/run-all.sh"
fi
if grep -q 'tests/validate-capability-registry.tests.ps1' "$ROOT/tests/run-all.ps1"; then
  ok "self-registration: validate-capability-registry.tests.ps1 registered in tests/run-all.ps1"
else
  fail "self-registration: validate-capability-registry.tests.ps1 NOT registered in tests/run-all.ps1"
fi

HUMAN_COPY_DIR="$ROOT/specs/epic-190-a2-capability-registry/human-copy"
STAGED_WORKFLOW="$HUMAN_COPY_DIR/.github/workflows/test.yml"
STAGED_MANIFEST="$HUMAN_COPY_DIR/MANIFEST.sha256"
if [[ -f "$STAGED_WORKFLOW" ]] && grep -q 'tests/validate-capability-registry.tests.sh' "$STAGED_WORKFLOW" && grep -q 'tests/validate-capability-registry.tests.ps1' "$STAGED_WORKFLOW"; then
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
  printf 'validate-capability-registry suite passed (%d checks)\n' "$PASS"
  exit 0
else
  printf 'validate-capability-registry suite FAILED (%d passed, %d failed)\n' "$PASS" "$FAIL"
  exit 1
fi
