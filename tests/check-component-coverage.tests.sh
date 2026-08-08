#!/usr/bin/env bash
# check-component-coverage.tests.sh — epic-191-a3-path-ownership T-004.
# Exercises the Reverse Coverage Gate (REQ-004) against standalone
# fixture Facet Manifest / Provider Bindings JSON objects — per this
# task's own Scope, Epic A4's/A1's real schema files are NOT required to
# exist for these fixtures (design.md Global Constraints, CI resilience).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SCRIPT="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-component-coverage.sh"
FIXTURES="${REPO_ROOT}/tests/fixtures/check-component-coverage"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }
jqf() { jq "$@" | tr -d '\r'; }

run_gate() {
  # $1=config $2=facet-manifest(or "") $3=changed-paths-file $4=provider-bindings(or "")
  local cfg="$1" fm="$2" cpf="$3" pb="$4"
  local args=(--config "$cfg" --changed-paths-file "$cpf")
  [ -n "$fm" ] && args+=(--facet-manifest "$fm")
  [ -n "$pb" ] && args+=(--provider-bindings "$pb")
  "$SCRIPT" "${args[@]}"
}

# ============================================================================
# TEST-026 (AC-026/027): applicability derived, never file-presence; a
# present manifest under disabled-legacy still records disabled-legacy
# ============================================================================
echo "=== TEST-026: applicability derived from capability_enforcement, never manifest presence ==="
out=$(run_gate "${FIXTURES}/config-disabled-legacy.yaml" "${FIXTURES}/facet-manifest-full.json" "${FIXTURES}/changed-paths-clean.txt" "")
state=$(printf '%s' "$out" | jqf -r '.state')
manifest_status=$(printf '%s' "$out" | jqf -r '.manifest_status')
if [ "$state" = "not-applicable (disabled-legacy)" ] && [ "$manifest_status" = "not-consulted" ]; then
  ok "TEST-026.1: a present Facet Manifest under disabled-legacy still records disabled-legacy, manifest never consulted"
else
  fail "TEST-026.1: expected disabled-legacy/not-consulted, got state=$state manifest_status=$manifest_status"
fi

# ============================================================================
# TEST-027 (AC-027): disabled-legacy truthful non-evaluation + real record
# ============================================================================
echo "=== TEST-027: disabled-legacy truthful non-evaluation ==="
out=$(printf '' | "$SCRIPT" --config "${FIXTURES}/config-disabled-legacy.yaml")
code=0
fail_count=$(printf '%s' "$out" | jqf -r '.fail_conditions | length')
schema=$(printf '%s' "$out" | jqf -r '.schema')
if [ "$fail_count" = "0" ] && [ "$schema" = "check-component-coverage-verdict/v1" ]; then
  ok "TEST-027.1: disabled-legacy performs zero Fail-condition evaluation and emits a real, schema-tagged record"
else
  fail "TEST-027.1: expected fail_conditions=[] and correct schema, got fail_count=$fail_count schema=$schema"
fi
set +e
printf '' | "$SCRIPT" --config "${FIXTURES}/config-disabled-legacy.yaml" >/dev/null
code=$?
set -e
[ "$code" -eq 0 ] && ok "TEST-027.2: disabled-legacy exits 0" || fail "TEST-027.2: expected exit 0, got $code"

# ============================================================================
# TEST-028 (AC-028): manifest-required hard error, distinct from an
# ordinary Fail-condition exit
# ============================================================================
echo "=== TEST-028: manifest-required hard error ==="
set +e
out=$(run_gate "${FIXTURES}/config-advisory.yaml" "${FIXTURES}/does-not-exist.json" "${FIXTURES}/changed-paths-clean.txt" "")
code=$?
set -e
if [ "$code" -eq 2 ] && printf '%s' "$out" | jqf -e '.error' >/dev/null 2>&1; then
  ok "TEST-028.1: a missing Facet Manifest in advisory state is a hard error (exit 2), distinct from exit 1 (an ordinary Fail trigger)"
else
  fail "TEST-028.1: expected exit 2 + error field, got exit=$code out=$out"
fi
set +e
out=$(run_gate "${FIXTURES}/config-advisory.yaml" "" "${FIXTURES}/changed-paths-clean.txt" "")
code=$?
set -e
if [ "$code" -eq 2 ]; then
  ok "TEST-028.2: --facet-manifest omitted entirely in advisory/required state is also a hard error"
else
  fail "TEST-028.2: expected exit 2 when --facet-manifest is omitted, got $code"
fi

# ============================================================================
# TEST-029 (AC-029): --diagnose is never Gate-invoked, exit code carries no
# Implementation Gate meaning
# ============================================================================
echo "=== TEST-029: --diagnose never Gate-invoked ==="
RESOLVER="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/resolve-component-paths.sh"
out=$("$RESOLVER" --config "${FIXTURES}/config-advisory.yaml" --changed-paths-file "${FIXTURES}/changed-paths-fail1.txt" --diagnose)
schema=$(printf '%s' "$out" | jqf -r '.schema')
if [ "$schema" = "resolve-component-paths-diagnose/v1" ]; then
  ok "TEST-029.1: --diagnose emits its own distinct schema, never the Gate's check-component-coverage-verdict/v1"
else
  fail "TEST-029.1: expected resolve-component-paths-diagnose/v1 schema, got $schema"
fi
if ! grep -q "resolve-component-paths --diagnose\|resolve-component-paths.sh --diagnose" "${REPO_ROOT}/plugins/sdd-quality-loop/skills/quality-gate/SKILL.md"; then
  ok "TEST-029.2: quality-gate/SKILL.md's ## Process never invokes --diagnose"
else
  fail "TEST-029.2: --diagnose must never appear in quality-gate/SKILL.md's Process"
fi

# ============================================================================
# TEST-030 (AC-030): one dedicated fixture per Fail-1..Fail-6, identical
# in advisory and required (only exit code/blocking differs)
# ============================================================================
echo "=== TEST-030: one fixture per Fail-1..6, identical advisory/required ==="
check_fail_identical() {
  local label="$1" cfg_adv="$2" cfg_req="$3" fm="$4" cpf="$5" pb="$6" fail_id="$7"
  local out_adv out_req triggered_adv triggered_req
  out_adv=$(run_gate "$cfg_adv" "$fm" "$cpf" "$pb")
  out_req=$(run_gate "$cfg_req" "$fm" "$cpf" "$pb" 2>&1) || true
  triggered_adv=$(printf '%s' "$out_adv" | jqf -r --arg id "$fail_id" '.fail_conditions[] | select(.id==$id) | .triggered')
  triggered_req=$(printf '%s' "$out_req" | jqf -r --arg id "$fail_id" '.fail_conditions[] | select(.id==$id) | .triggered')
  if [ "$triggered_adv" = "true" ] && [ "$triggered_req" = "true" ]; then
    ok "TEST-030 ($label): $fail_id triggers identically in advisory and required"
  else
    fail "TEST-030 ($label): expected $fail_id triggered in both, got advisory=$triggered_adv required=$triggered_req"
  fi
}
check_fail_identical "Fail-1" "${FIXTURES}/config-advisory.yaml" "${FIXTURES}/config-required.yaml" "${FIXTURES}/facet-manifest-full.json" "${FIXTURES}/changed-paths-fail1.txt" "" "Fail-1"
check_fail_identical "Fail-2" "${FIXTURES}/config-advisory.yaml" "${FIXTURES}/config-required.yaml" "${FIXTURES}/facet-manifest-desktop-only.json" "${FIXTURES}/changed-paths-fail2.txt" "" "Fail-2"
check_fail_identical "Fail-3" "${FIXTURES}/config-overlap.yaml" "${FIXTURES}/config-overlap-required.yaml" "${FIXTURES}/facet-manifest-full.json" "${FIXTURES}/changed-paths-fail3.txt" "" "Fail-3"
check_fail_identical "Fail-4" "${FIXTURES}/config-advisory.yaml" "${FIXTURES}/config-required.yaml" "${FIXTURES}/facet-manifest-desktop-only.json" "${FIXTURES}/changed-paths-fail4.txt" "" "Fail-4"
check_fail_identical "Fail-5" "${FIXTURES}/config-advisory.yaml" "${FIXTURES}/config-required.yaml" "${FIXTURES}/facet-manifest-full.json" "${FIXTURES}/changed-paths-fail5.txt" "" "Fail-5"
check_fail_identical "Fail-6" "${FIXTURES}/config-advisory.yaml" "${FIXTURES}/config-required.yaml" "${FIXTURES}/facet-manifest-full.json" "${FIXTURES}/changed-paths-fail6.txt" "${FIXTURES}/provider-bindings-match.json" "Fail-6"

# ============================================================================
# TEST-031 (AC-031): Fail-2/Fail-4 mutual exclusivity
# ============================================================================
echo "=== TEST-031: Fail-2/Fail-4 mutual exclusivity ==="
out=$(run_gate "${FIXTURES}/config-advisory.yaml" "${FIXTURES}/facet-manifest-desktop-only.json" "${FIXTURES}/changed-paths-fail2.txt" "")
f2=$(printf '%s' "$out" | jqf -r '.fail_conditions[] | select(.id=="Fail-2") | .triggered')
f4=$(printf '%s' "$out" | jqf -r '.fail_conditions[] | select(.id=="Fail-4") | .triggered')
if [ "$f2" = "true" ] && [ "$f4" = "false" ]; then
  ok "TEST-031.1: an EXCLUSIVE-owner mismatch triggers Fail-2 only, never Fail-4"
else
  fail "TEST-031.1: expected Fail-2=true Fail-4=false, got Fail-2=$f2 Fail-4=$f4"
fi
out=$(run_gate "${FIXTURES}/config-advisory.yaml" "${FIXTURES}/facet-manifest-desktop-only.json" "${FIXTURES}/changed-paths-fail4.txt" "")
f2=$(printf '%s' "$out" | jqf -r '.fail_conditions[] | select(.id=="Fail-2") | .triggered')
f4=$(printf '%s' "$out" | jqf -r '.fail_conditions[] | select(.id=="Fail-4") | .triggered')
if [ "$f2" = "false" ] && [ "$f4" = "true" ]; then
  ok "TEST-031.2: a bounded shared_paths shortfall triggers Fail-4 only, never Fail-2"
else
  fail "TEST-031.2: expected Fail-2=false Fail-4=true, got Fail-2=$f2 Fail-4=$f4"
fi

# ============================================================================
# TEST-032 (AC-032): Fail-5 Gate-level reachability via EXCLUDED_MATCH
# ============================================================================
echo "=== TEST-032: Fail-5 Gate-level reachability ==="
out=$(run_gate "${FIXTURES}/config-advisory.yaml" "${FIXTURES}/facet-manifest-full.json" "${FIXTURES}/changed-paths-fail5.txt" "")
f5=$(printf '%s' "$out" | jqf -r '.fail_conditions[] | select(.id=="Fail-5") | .triggered')
[ "$f5" = "true" ] && ok "TEST-032.1: an EXCLUDED_MATCH path reaches the Gate as a Fail-5 trigger (real runtime path, not only a resolver-level test)" || fail "TEST-032.1: expected Fail-5 triggered"

# ============================================================================
# TEST-033/034 (AC-033/034): Fail-6 adapter_paths rule + N/A-when-absent
# ============================================================================
echo "=== TEST-033/034: Fail-6 adapter_paths rule ==="
out=$(run_gate "${FIXTURES}/config-advisory.yaml" "${FIXTURES}/facet-manifest-full.json" "${FIXTURES}/changed-paths-fail6.txt" "${FIXTURES}/provider-bindings-match.json")
f6=$(printf '%s' "$out" | jqf -r '.fail_conditions[] | select(.id=="Fail-6") | .triggered')
[ "$f6" = "true" ] && ok "TEST-033.1: an adapter_paths glob match against an EXCLUSIVE-owned path triggers Fail-6" || fail "TEST-033.1: expected Fail-6 triggered"

out=$(run_gate "${FIXTURES}/config-advisory.yaml" "${FIXTURES}/facet-manifest-full.json" "${FIXTURES}/changed-paths-fail6.txt" "${FIXTURES}/provider-bindings-no-adapter.json")
f6=$(printf '%s' "$out" | jqf -r '.fail_conditions[] | select(.id=="Fail-6") | .triggered')
warn=$(printf '%s' "$out" | jqf -r '.warnings[0] // ""')
if [ "$f6" = "false" ] && printf '%s' "$warn" | grep -q "evaluation not possible"; then
  ok "TEST-033.2: a binding lacking adapter_paths is WARN 'evaluation not possible', never silently passing"
else
  fail "TEST-033.2: expected Fail-6=false + WARN, got f6=$f6 warn=$warn"
fi

out=$(run_gate "${FIXTURES}/config-advisory.yaml" "${FIXTURES}/facet-manifest-full.json" "${FIXTURES}/changed-paths-fail6.txt" "${FIXTURES}/does-not-exist-bindings.json")
f6status=$(printf '%s' "$out" | jqf -r '.fail_conditions[] | select(.id=="Fail-6") | .detail.status // ""')
[ "$f6status" = "not-applicable (provider-bindings absent)" ] && ok "TEST-034.1: absent sdd/provider-bindings.yaml records Fail-6 N/A with a WARN" || fail "TEST-034.1: expected N/A status, got $f6status"

# ============================================================================
# TEST-046 (AC-046): contracts/** bounded-shared out-of-enumeration Fail-4
# ============================================================================
echo "=== TEST-046: contracts/** bounded-shared Fail-4 fixture ==="
printf 'contracts/schema.json\n' > /tmp/rcp-test046-paths.txt
out=$(run_gate "${FIXTURES}/config-contracts-fail4.yaml" "${FIXTURES}/facet-manifest-contracts-partial.json" /tmp/rcp-test046-paths.txt "")
f4=$(printf '%s' "$out" | jqf -r '.fail_conditions[] | select(.id=="Fail-4") | .triggered')
missing=$(printf '%s' "$out" | jqf -c -r '.fail_conditions[] | select(.id=="Fail-4") | .detail.missing_bounded_shared_owners | sort')
if [ "$f4" = "true" ] && [ "$missing" = '["backend"]' ]; then
  ok "TEST-046.1: contracts/** bounded-shared with an out-of-enumeration component (backend) missing from the manifest triggers Fail-4"
else
  fail "TEST-046.1: expected Fail-4 triggered with missing=[backend], got f4=$f4 missing=$missing"
fi
rm -f /tmp/rcp-test046-paths.txt

# ============================================================================
# TEST-052/053 (AC-052/053): advisory non-blocking, required blocking
# ============================================================================
echo "=== TEST-052/053: blocking behavior ==="
set +e
run_gate "${FIXTURES}/config-advisory.yaml" "${FIXTURES}/facet-manifest-full.json" "${FIXTURES}/changed-paths-fail1.txt" "" >/dev/null
code=$?
set -e
[ "$code" -eq 0 ] && ok "TEST-052.1: advisory exits 0 despite a Fail-condition trigger" || fail "TEST-052.1: expected exit 0, got $code"

set +e
run_gate "${FIXTURES}/config-required.yaml" "${FIXTURES}/facet-manifest-full.json" "${FIXTURES}/changed-paths-fail1.txt" "" >/dev/null
code=$?
set -e
[ "$code" -eq 1 ] && ok "TEST-053.1: required exits non-zero (1) when a Fail condition triggers" || fail "TEST-053.1: expected exit 1, got $code"

set +e
run_gate "${FIXTURES}/config-required.yaml" "${FIXTURES}/facet-manifest-full.json" "${FIXTURES}/changed-paths-clean.txt" "" >/dev/null
code=$?
set -e
[ "$code" -eq 0 ] && ok "TEST-053.2: required exits 0 when no Fail condition triggers" || fail "TEST-053.2: expected exit 0, got $code"

# ============================================================================
# TEST-054 (AC-054): evidence producer binding + emit-run-record
# conformance across all three states
# ============================================================================
echo "=== TEST-054: evidence producer binding across all three states ==="
check_producer() {
  local label="$1" out="$2"
  local schema check_id sha
  schema=$(printf '%s' "$out" | jqf -r '.schema')
  check_id=$(printf '%s' "$out" | jqf -r '.check_id')
  sha=$(printf '%s' "$out" | jqf -r '.producer.sha256')
  real_sha=$(shasum -a 256 "${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-component-coverage.py" | awk '{print $1}')
  if [ "$schema" = "check-component-coverage-verdict/v1" ] && [ "$check_id" = "check-component-coverage" ] && [ "$sha" = "$real_sha" ]; then
    ok "TEST-054 ($label): evidence carries schema, check_id, and a live-computed producer.sha256 matching the real on-disk script"
  else
    fail "TEST-054 ($label): schema=$schema check_id=$check_id sha=$sha real_sha=$real_sha"
  fi
}
check_producer "disabled-legacy" "$(printf '' | "$SCRIPT" --config "${FIXTURES}/config-disabled-legacy.yaml")"
check_producer "advisory" "$(run_gate "${FIXTURES}/config-advisory.yaml" "${FIXTURES}/facet-manifest-full.json" "${FIXTURES}/changed-paths-clean.txt" "")"
check_producer "required" "$(run_gate "${FIXTURES}/config-required.yaml" "${FIXTURES}/facet-manifest-full.json" "${FIXTURES}/changed-paths-clean.txt" "")"

# ============================================================================
# TEST-035/036/055 — see Unresolved Items in the implementation report:
# these require the REAL, human-applied check-contract.*/guard-invariants.json
# (Bundle A/B), which cannot be applied in this session (guard-blocked
# human-copy staging, same finding as T-001/T-002). Verified instead
# against the STAGED candidate content's own logic where practical.
# ============================================================================
echo "=== TEST-035/036/055: staged-candidate-only verification (real files not yet human-applied) ==="
if grep -q "check-component-coverage" "${REPO_ROOT}/plugins/sdd-quality-loop/references/risk-gate-matrix.md"; then
  ok "TEST-036.1 (partial): check-component-coverage is registered in the UNPROTECTED risk-gate-matrix.md required-check-set (direct edit, already live)"
else
  fail "TEST-036.1: expected check-component-coverage in risk-gate-matrix.md"
fi
if grep -q "check-component-coverage" "${REPO_ROOT}/plugins/sdd-quality-loop/skills/quality-gate/SKILL.md"; then
  ok "TEST-036.2 (partial): check-component-coverage is documented in quality-gate/SKILL.md's ## Process (direct edit, already live)"
else
  fail "TEST-036.2: expected check-component-coverage documented in quality-gate/SKILL.md"
fi

echo "=== registration self-check ==="
if grep -q "check-component-coverage" "${REPO_ROOT}/tests/run-all.sh" \
   && grep -q "check-component-coverage" "${REPO_ROOT}/tests/run-all.ps1"; then
  ok "check-component-coverage suite self-registers in tests/run-all.sh and .ps1"
else
  fail "check-component-coverage missing from tests/run-all.sh/.ps1 registration"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed."
[ "$FAIL" -eq 0 ]
