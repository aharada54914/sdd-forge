#!/usr/bin/env bash
# loop-driver.tests.sh — smoke suite for the shared loop driver
# (T-002 / Issue #142 / epic-159-pillar-a REQ-002).
#
#   TEST-005 — loop_fixture_init greenfield/brownfield: fixture root lies
#     outside the repository working tree, the genesis identity-ledger
#     record matches the canonical INV-006 hash formula, and no real repo
#     path is written for the fixture feature.
#   TEST-006 — drive_review_round drives spec-review rounds 1->3 green
#     through the REAL spec-review-precheck.sh and the REAL
#     validate-review-context-set.sh --reserve; round-N (N>1) transitions
#     are gated on the on-disk round-(N-1) output set (assert_prior_round_
#     complete), and a manifest missing an artifact turns that check red.
#   TEST-007 — assert_artifacts_schema / assert_terminal negative
#     self-checks on a jq-mutated artifact and a contradicted end state.
#   TEST-017 — runtime budget: measured wall-clock printed in the summary
#     line, self-FAIL above LOOP_SUITE_BUDGET_SECONDS, threshold-0 negative
#     self-check.
#
# Only the spec-review leg is driven here (tasks.md T-002 Scope/Out of
# Scope); drive_review_round's dispatcher intentionally refuses impl/task/
# domain for now (see tests/lib/loop-driver.sh).
set -euo pipefail

START_EPOCH=$(date +%s)

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
# shellcheck source=tests/lib/loop-driver.sh
source "${REPO_ROOT}/tests/lib/loop-driver.sh"

PASS=0
FAIL=0
ok()   { printf 'ok: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required"; exit 1; }

CLEANUP_ROOTS=()
cleanup() {
  local d
  for d in "${CLEANUP_ROOTS[@]:-}"; do
    [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
  done
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# TEST-005 (AC-005): loop_fixture_init — greenfield + brownfield
# ---------------------------------------------------------------------------
echo "=== TEST-005: loop_fixture_init (greenfield + brownfield) ==="

FEATURE_GF="loop-driver-smoke-gf-$$"
if loop_fixture_init greenfield "$FEATURE_GF"; then
  ok "TEST-005.1: loop_fixture_init greenfield succeeds"
  CLEANUP_ROOTS+=("$LOOP_FIXTURE_ROOT")
else
  fail "TEST-005.1: loop_fixture_init greenfield failed"
fi
GF_ROOT="${LOOP_FIXTURE_ROOT:-}"

case "$GF_ROOT" in
  "${REPO_ROOT}"|"${REPO_ROOT}"/*)
    fail "TEST-005.2: greenfield fixture root resolves inside the repository working tree"
    ;;
  *)
    if [[ -n "$GF_ROOT" ]]; then
      ok "TEST-005.2: greenfield fixture root (${GF_ROOT}) lies outside the repository working tree"
    else
      fail "TEST-005.2: greenfield fixture root was not set"
    fi
    ;;
esac

LEDGER="${GF_ROOT}/reports/review-context/identity-ledger.json"
if [[ -f "$LEDGER" ]] && jq -e '.schema == "review-identity-ledger/v1" and (.records | length) == 1' "$LEDGER" >/dev/null 2>&1; then
  ok "TEST-005.3: greenfield genesis identity-ledger has exactly one well-formed record"
else
  fail "TEST-005.3: greenfield genesis identity-ledger is missing or malformed"
fi

genesis_expected="$(printf '%s' "1|genesis|loop-driver-fixture|fixture-genesis-run|fixture-genesis-session|" | { command -v sha256sum >/dev/null 2>&1 && sha256sum || shasum -a 256; } | awk '{print $1}')"
genesis_actual="$(jq -r '.records[0].record_sha256' "$LEDGER" 2>/dev/null | tr -d '\r' || true)"
if [[ -n "$genesis_actual" && "$genesis_actual" == "$genesis_expected" ]]; then
  ok "TEST-005.4: genesis record hash matches the canonical INV-006 formula (validate-review-context-set.sh:245)"
else
  fail "TEST-005.4: genesis record hash does not match the canonical INV-006 formula"
fi

if [[ ! -e "${REPO_ROOT}/reports/spec-review/${FEATURE_GF}" && ! -e "${REPO_ROOT}/specs/${FEATURE_GF}" ]]; then
  ok "TEST-005.5: loop_fixture_init writes no real repository path for the fixture feature"
else
  fail "TEST-005.5: a real repository path was written for the fixture feature"
fi

SEED_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/loop-driver-seed.XXXXXX")"
CLEANUP_ROOTS+=("$SEED_ROOT")
SEED_MARKER_REL="seed-marker-$$.txt"
printf 'brownfield seed marker\n' > "${SEED_ROOT}/${SEED_MARKER_REL}"

FEATURE_BF="loop-driver-smoke-bf-$$"
LOOP_FIXTURE_SEED="$SEED_ROOT"
export LOOP_FIXTURE_SEED
if loop_fixture_init brownfield "$FEATURE_BF"; then
  ok "TEST-005.6: loop_fixture_init brownfield succeeds"
  CLEANUP_ROOTS+=("$LOOP_FIXTURE_ROOT")
else
  fail "TEST-005.6: loop_fixture_init brownfield failed"
fi
BF_ROOT="${LOOP_FIXTURE_ROOT:-}"
unset LOOP_FIXTURE_SEED

if [[ -n "$BF_ROOT" && -f "${BF_ROOT}/${SEED_MARKER_REL}" ]]; then
  ok "TEST-005.7: brownfield fixture copies the caller-supplied seed content"
else
  fail "TEST-005.7: brownfield fixture does not contain the seed marker file"
fi
if [[ -n "$BF_ROOT" ]] && jq -e '.records | length == 1' "${BF_ROOT}/reports/review-context/identity-ledger.json" >/dev/null 2>&1; then
  ok "TEST-005.8: brownfield fixture also synthesizes the genesis identity-ledger"
else
  fail "TEST-005.8: brownfield fixture is missing the synthesized genesis identity-ledger"
fi

if (loop_fixture_init bogus-profile "loop-driver-smoke-neg-$$") 2>/dev/null; then
  fail "TEST-005.9 (negative self-check): an unknown fixture profile did NOT fail loop_fixture_init"
else
  ok "TEST-005.9 (negative self-check): an unknown fixture profile fails loop_fixture_init"
fi

# ---------------------------------------------------------------------------
# TEST-006 (AC-006): drive_review_round — spec-review rounds 1->3
# ---------------------------------------------------------------------------
echo "=== TEST-006: drive_review_round (spec-review rounds 1->3) ==="

SPEC_PRECHECK_SH="${REPO_ROOT}/plugins/sdd-review-loop/scripts/spec-review-precheck.sh"
if [[ ! -f "$SPEC_PRECHECK_SH" ]]; then
  echo "SKIP: TEST-006 spec-review-precheck.sh not found at ${SPEC_PRECHECK_SH}"
else
  LOOP_FIXTURE_ROOT="$GF_ROOT"
  export LOOP_FIXTURE_ROOT
  LOOP_FIXTURE_FEATURE="$FEATURE_GF"
  export LOOP_FIXTURE_FEATURE

  ROUND1_DIR="${GF_ROOT}/reports/spec-review/${FEATURE_GF}/attempt-1/round-1"
  if ! loop_validator_capability_probe; then
    for skip_id in TEST-006.1 TEST-006.2 TEST-006.3 TEST-006.4 TEST-006.5 TEST-006.6; do
      loop_validator_skip "$skip_id"
    done
  else
  if drive_review_round spec 1 1 NEEDS_WORK Major; then
    ok "TEST-006.1: drive_review_round spec attempt 1 round 1 (NEEDS_WORK/Major) succeeds"
  else
    fail "TEST-006.1: drive_review_round spec attempt 1 round 1 (NEEDS_WORK/Major) failed"
  fi
  if [[ -f "${ROUND1_DIR}/spec-review-contract.json" ]] && \
     jq -e '.verdict == "NEEDS_WORK"' "${ROUND1_DIR}/spec-review-contract.json" >/dev/null 2>&1; then
    ok "TEST-006.2: round-1 contract records verdict NEEDS_WORK"
  else
    fail "TEST-006.2: round-1 contract is missing or does not record NEEDS_WORK"
  fi

  if drive_review_round spec 1 2 NEEDS_WORK Major; then
    ok "TEST-006.3: drive_review_round spec attempt 1 round 2 (NEEDS_WORK/Major) succeeds"
  else
    fail "TEST-006.3: drive_review_round spec attempt 1 round 2 (NEEDS_WORK/Major) failed"
  fi

  if drive_review_round spec 1 3 PASS Minor; then
    ok "TEST-006.4: drive_review_round spec attempt 1 round 3 (PASS/Minor) succeeds"
  else
    fail "TEST-006.4: drive_review_round spec attempt 1 round 3 (PASS/Minor) failed"
  fi
  ROUND3_DIR="${GF_ROOT}/reports/spec-review/${FEATURE_GF}/attempt-1/round-3"
  if [[ -f "${ROUND3_DIR}/spec-review-contract.json" ]] && \
     jq -e '.verdict == "PASS" and .warningCount == 1' "${ROUND3_DIR}/spec-review-contract.json" >/dev/null 2>&1; then
    ok "TEST-006.5: round-3 contract records verdict PASS with warningCount 1 (Minor-only)"
  else
    fail "TEST-006.5: round-3 contract does not record the Minor-only PASS shape"
  fi

  if assert_prior_round_complete spec "$ROUND1_DIR"; then
    ok "TEST-006.6: assert_prior_round_complete recognizes round-1's genuine on-disk output set"
  else
    fail "TEST-006.6: assert_prior_round_complete rejects round-1's genuine on-disk output set"
  fi
  fi

  INCOMPLETE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/loop-driver-incomplete.XXXXXX")"
  CLEANUP_ROOTS+=("$INCOMPLETE_DIR")
  cp "${ROUND1_DIR}"/*.json "$INCOMPLETE_DIR/" 2>/dev/null || true
  rm -f "${INCOMPLETE_DIR}/spec-review-contract.json"
  if assert_prior_round_complete spec "$INCOMPLETE_DIR"; then
    fail "TEST-006.7 (negative self-check): a manifest referencing a nonexistent artifact did NOT turn assert_prior_round_complete red"
  else
    ok "TEST-006.7 (negative self-check): a manifest referencing a nonexistent artifact (missing spec-review-contract.json) turns assert_prior_round_complete red"
  fi
fi

# ---------------------------------------------------------------------------
# TEST-007 (AC-007): assert_artifacts_schema / assert_terminal
# ---------------------------------------------------------------------------
echo "=== TEST-007: assert_artifacts_schema / assert_terminal ==="

# Self-contained synthetic directory: independent of whether TEST-006 could
# drive a real round, so this leg always runs (see tests/lib/loop-driver.ps1
# for the pwsh degradation note on TEST-006's spec-review leg).
SCHEMA_DIR="$(mktemp -d "${TMPDIR:-/tmp}/loop-driver-schema.XXXXXX")"
CLEANUP_ROOTS+=("$SCHEMA_DIR")
jq -n '{schema:"spec-review-precheck/v1", feature:"loop-driver-schema-fixture", attempt:1, round:1}' \
  > "${SCHEMA_DIR}/precheck-result.json"
jq -n '{schema:"spec-review-contract/v1", feature:"loop-driver-schema-fixture", attempt:1, round:1, verdict:"PASS"}' \
  > "${SCHEMA_DIR}/spec-review-contract.json"

if assert_artifacts_schema "$SCHEMA_DIR"; then
  ok "TEST-007.1: assert_artifacts_schema passes on genuine, inventory-registered artifact schemas"
else
  fail "TEST-007.1: assert_artifacts_schema failed on genuine, inventory-registered artifact schemas"
fi

MUTATED_DIR="$(mktemp -d "${TMPDIR:-/tmp}/loop-driver-mutated.XXXXXX")"
CLEANUP_ROOTS+=("$MUTATED_DIR")
cp "${SCHEMA_DIR}"/*.json "$MUTATED_DIR/"
jq '.schema = "bogus-schema/v1"' "${MUTATED_DIR}/precheck-result.json" > "${MUTATED_DIR}/precheck-result.json.tmp"
mv "${MUTATED_DIR}/precheck-result.json.tmp" "${MUTATED_DIR}/precheck-result.json"
if assert_artifacts_schema "$MUTATED_DIR"; then
  fail "TEST-007.2 (negative self-check): a jq-mutated artifact schema did NOT turn assert_artifacts_schema red"
else
  ok "TEST-007.2 (negative self-check): a jq-mutated artifact schema turns assert_artifacts_schema red"
fi

if assert_terminal spec-review PASS; then
  ok "TEST-007.3: assert_terminal confirms spec-review's genuine PASS state matches the inventory"
else
  fail "TEST-007.3: assert_terminal rejected spec-review's genuine PASS state"
fi

if assert_terminal spec-review BLOCKED; then
  fail "TEST-007.4 (negative self-check): an end state contradicting the inventory did NOT turn assert_terminal red"
else
  ok "TEST-007.4 (negative self-check): an end state contradicting the inventory (BLOCKED vs PASS) turns assert_terminal red"
fi

# ---------------------------------------------------------------------------
# TEST-017 (AC-017): runtime budget
# ---------------------------------------------------------------------------
echo "=== TEST-017: runtime budget (LOOP_SUITE_BUDGET_SECONDS=${LOOP_SUITE_BUDGET_SECONDS}) ==="

SYNTHETIC_PAST_EPOCH=$(( START_EPOCH - 1 ))
if assert_runtime_budget "$SYNTHETIC_PAST_EPOCH" 0; then
  fail "TEST-017.1 (negative self-check): forcing the runtime budget to 0 did NOT turn the assertion red"
else
  ok "TEST-017.1 (negative self-check): forcing the runtime budget to 0 turns the assertion red"
fi

ELAPSED_SECONDS=$(( $(date +%s) - START_EPOCH ))
if assert_runtime_budget "$START_EPOCH"; then
  ok "TEST-017.2: suite completed within the ${LOOP_SUITE_BUDGET_SECONDS}s runtime budget"
else
  fail "TEST-017.2: suite exceeded the ${LOOP_SUITE_BUDGET_SECONDS}s runtime budget"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf 'loop-driver.tests.sh: %d passed, %d failed, %ds elapsed\n' "$PASS" "$FAIL" "$ELAPSED_SECONDS"
[[ "$FAIL" -eq 0 ]]
