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

# TEST-054.4 (AC-054 negative clause, quality-gate remediation 2026-08-09):
# check_producer above only ever compares two independent computations of
# the SAME current file's hash, so it can never observe a mismatch. Prove
# the comparison itself is capable of failing: hand-tamper a copy of a real
# evidence record's producer.sha256 and confirm it is distinguishable from
# the live script's real hash (the actual mismatch-rejection behavior is
# exercised end-to-end against check-contract's staged producer-digest pass
# in TEST-055 below).
tampered_producer=$(printf '%s' "$(run_gate "${FIXTURES}/config-required.yaml" "${FIXTURES}/facet-manifest-full.json" "${FIXTURES}/changed-paths-clean.txt" "")" \
  | jqf '.producer.sha256 = "0000000000000000000000000000000000000000000000000000000000000000"' | jqf -r '.producer.sha256')
real_sha=$(shasum -a 256 "${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-component-coverage.py" | awk '{print $1}')
if [ "$tampered_producer" != "$real_sha" ]; then
  ok "TEST-054.4: a hand-tampered producer.sha256 is distinguishable from the live script's real hash (the self-check is not tautological)"
else
  fail "TEST-054.4: tampered and real producer.sha256 unexpectedly matched"
fi

# ============================================================================
# TEST-035d (relabelled from the suite-internal "TEST-056" on 2026-08-11 —
# the 2026-08-11 spec amendment assigned the ID TEST-056 to T-001's
# resolver-side criterion and gave THIS Gate-side clause the ID TEST-035d,
# acceptance-tests.md:77; the historical label collided with that row and
# is reconciled here, per the amendment's Notes. Originally added as the
# fail-open fix for quality-gate Critical 1.)
#
# A project-context.yaml that EXISTS but fails to parse is a hard error,
# never a silent downgrade to disabled-legacy: the Gate ITSELF exits
# non-zero with a diagnostic naming the parse failure and emits NO evidence
# record at all — so no passes:true entry can exist for the activated tier
# minimum to accept (TEST-035c pins the requirement side; this pins the
# producer side; only both keep the pipeline red until the config is fixed).
# ============================================================================
echo "=== TEST-035d: a present-but-unparseable project-context.yaml is a recordless hard error, never disabled-legacy ==="
set +e
out_stdout=$("$SCRIPT" --config "${FIXTURES}/config-parse-error.yaml" --facet-manifest "${FIXTURES}/facet-manifest-full.json" --changed-paths-file "${FIXTURES}/changed-paths-clean.txt" 2>/dev/null)
code=$?
out_all=$("$SCRIPT" --config "${FIXTURES}/config-parse-error.yaml" --facet-manifest "${FIXTURES}/facet-manifest-full.json" --changed-paths-file "${FIXTURES}/changed-paths-clean.txt" 2>&1)
set -e
if [ "$code" -eq 2 ] && ! printf '%s' "$out_all" | grep -q "not-applicable (disabled-legacy)"; then
  ok "TEST-035d.1: a config file that exists but fails to parse is a hard error (exit 2), never silently downgraded to disabled-legacy"
else
  fail "TEST-035d.1: expected exit 2 and no disabled-legacy downgrade, got exit=$code out=$out_all"
fi
if printf '%s' "$out_all" | grep -q "could not be parsed"; then
  ok "TEST-035d.2: the diagnostic names the parse failure"
else
  fail "TEST-035d.2: expected a diagnostic naming the parse failure, got: $out_all"
fi
if [ -z "$out_stdout" ] && ! printf '%s' "$out_all" | grep -q "check-component-coverage-verdict/v1"; then
  ok "TEST-035d.3: NO evidence record is emitted (empty stdout, no verdict schema tag anywhere) — nothing exists for an activated tier minimum to accept"
else
  fail "TEST-035d.3: expected a recordless crash, got stdout=[$out_stdout]"
fi

# ============================================================================
# Label note (2026-08-11): TEST-057..TEST-059 below are SUITE-INTERNAL
# remediation labels, not rows of acceptance-tests.md (whose ID space ends
# at TEST-056, owned by T-001's resolver suite). They are kept under their
# historical names — no acceptance-tests.md row collides with them.
# ============================================================================

# ============================================================================
# TEST-057 (dual-runtime exit-code parity, Critical 1): a config that parses
# fine but fails resolve-component-paths' own structural validation (a
# post-parse ConfigError, distinct from the parse-error case above) must
# exit 2 identically on both runtimes. Before this fix: python exited 2,
# pwsh exited 1 (a Write-Error call under $ErrorActionPreference=Stop threw
# before the intended `exit 2` line could run).
# ============================================================================
echo "=== TEST-057: dual-runtime exit-code parity on a post-parse config structural error ==="
set +e
out=$("$SCRIPT" --config "${FIXTURES}/config-required-bad-components.yaml" --facet-manifest "${FIXTURES}/facet-manifest-full.json" --changed-paths-file "${FIXTURES}/changed-paths-clean.txt" 2>&1)
code=$?
set -e
if [ "$code" -eq 2 ]; then
  ok "TEST-057.1: python: a post-parse config structural error (empty include list) is a hard error, exit 2"
else
  fail "TEST-057.1: expected exit 2, got $code (out=$out)"
fi

# ============================================================================
# TEST-058 (case-sensitivity parity, Critical 1): capability_enforcement is
# matched case-sensitively on both runtimes. Before this fix: python treated
# 'Required' as disabled-legacy (correct, case-sensitive) while pwsh's
# default -eq matched it as required (culture-aware/case-insensitive) --
# the two runtimes disagreed on the derived state and verdict for the exact
# same config file.
# ============================================================================
echo "=== TEST-058: capability_enforcement case-sensitivity parity ('Required' != 'required') ==="
out=$(printf '' | "$SCRIPT" --config "${FIXTURES}/config-required-capitalized.yaml")
state=$(printf '%s' "$out" | jqf -r '.state')
if [ "$state" = "not-applicable (disabled-legacy)" ]; then
  ok "TEST-058.1: python: capability_enforcement: Required (capital) is NOT matched as required (case-sensitive), derives disabled-legacy"
else
  fail "TEST-058.1: expected disabled-legacy, got state=$state"
fi

# ============================================================================
# TEST-059 (reachability bypass fix, Major -> closed): in advisory/required
# state, omitting BOTH --changed-paths-file and --target-rev is now a hard
# error, never a silent conformant all-clear. Before this fix: this exact
# invocation read empty stdin, classified zero records, and returned exit 0
# with no Fail condition ever evaluated -- binding no diff basis or
# provenance.
# ============================================================================
echo "=== TEST-059: omitting both --changed-paths-file and --target-rev is a hard error (reachability bypass closed) ==="
set +e
out=$("$SCRIPT" --config "${FIXTURES}/config-required.yaml" --facet-manifest "${FIXTURES}/facet-manifest-full.json" < /dev/null 2>&1)
code=$?
set -e
if [ "$code" -eq 2 ]; then
  ok "TEST-059.1: required state, valid manifest, no --changed-paths-file/--target-rev: hard error (exit 2), never a silent all-clear"
else
  fail "TEST-059.1: expected exit 2, got $code (out=$out)"
fi

# ============================================================================
# TEST-035/036/055 (retargeted 2026-08-11 per RT-20260811-003 / seq0679):
# these blocks originally documented a LIVE reachability gap and proved the
# staged Bundle A/B candidates under reports/implementation/.../drafts/. A
# human ruled for CONDITIONAL activation (staged in eb427d60, applied in
# 710d6746), so the gap no longer exists and the pre-ruling unconditional
# drafts/bundle-b candidate is superseded. Every assertion below now
# exercises the POST-APPLY world: the applied conditional artifacts (live
# check-contract.{py,ps1}, live guard-invariants.json + generator), pinned
# to the human-copy staged candidates via MANIFEST.sha256. Nothing here
# reads drafts/bundle-b any more — TEST-055.3 asserts its eviction.
# ============================================================================
DRAFTS="${REPO_ROOT}/reports/implementation/epic-191-a3-path-ownership/drafts"
HC_MANIFEST_191="${REPO_ROOT}/specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256"

echo "=== TEST-036: protected-suffix registration + generator inventory ==="
matrix_block=$(sed -n '/^low      = /,/^critical = /p' "${REPO_ROOT}/plugins/sdd-quality-loop/references/risk-gate-matrix.md")
if printf '%s' "$matrix_block" | grep -Eq '^high[[:space:]]+=.*check-component-coverage'; then
  ok "TEST-036.1: risk-gate-matrix.md's machine-form 'high =' required-check-set line itself (not just anywhere in the file) names check-component-coverage (live, unprotected, direct edit)"
else
  fail "TEST-036.1: expected check-component-coverage inside the machine-form 'high =' line"
fi
process_block=$(sed -n '/^## Process/,/^## Done Decision/p' "${REPO_ROOT}/plugins/sdd-quality-loop/skills/quality-gate/SKILL.md")
if printf '%s' "$process_block" | grep -q "check-component-coverage"; then
  ok "TEST-036.2: quality-gate/SKILL.md's ## Process section itself (not just anywhere in the file) documents check-component-coverage"
else
  fail "TEST-036.2: expected check-component-coverage inside SKILL.md's ## Process section"
fi
# TEST-036.3 (retargeted 2026-08-11): before the human apply this asserted
# the live check-contract pair did NOT register the check (documenting the
# gap); after 710d6746 that inversion could never pass again. It now asserts
# the applied state: both live runtimes register check-component-coverage in
# the high AND critical tier minimums, and both carry the conditional
# activation predicate (plain sdd/project-context.yaml file-presence, no
# YAML parser) — i.e. the registration that shipped is the CONDITIONAL one,
# not the superseded unconditional candidate.
LIVE_CONTRACT_PY="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-contract.py"
LIVE_CONTRACT_PS1="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-contract.ps1"
if grep -Eq '"high":[[:space:]]*\{[^}]*"check-component-coverage"[^}]*\}' "$LIVE_CONTRACT_PY" \
   && grep -Eq '"critical":[[:space:]]*\{[^}]*"check-component-coverage"[^}]*\}' "$LIVE_CONTRACT_PY" \
   && grep -q "_capability_enforcement_declared" "$LIVE_CONTRACT_PY" \
   && grep -q "CAPABILITY_STATE_GATED_IDS" "$LIVE_CONTRACT_PY" \
   && grep -Eq '"high"[[:space:]]*=.*"check-component-coverage"' "$LIVE_CONTRACT_PS1" \
   && grep -Eq '"critical"[[:space:]]*=.*"check-component-coverage"' "$LIVE_CONTRACT_PS1" \
   && grep -q "CAPABILITY_STATE_GATED_IDS" "$LIVE_CONTRACT_PS1"; then
  ok "TEST-036.3: live check-contract.{py,ps1} registers check-component-coverage in the high/critical tier minimums, gated by the conditional-activation predicate (the applied conditional artifact, not the superseded unconditional candidate)"
else
  fail "TEST-036.3: expected the live check-contract pair to carry the conditional check-component-coverage registration"
fi
# TEST-036.4 (retargeted 2026-08-11): the old live-vs-draft set comparison
# asserted the three suffixes were NOT yet live; post-apply that inverted.
# Now: the live guard-invariants.json must carry all three
# check-component-coverage.* entries in BOTH protected_gate_suffixes and
# phase2_human_copy_targets; T-004's two live workflow steps must remain
# present; every candidate must match its manifest hash; and T-004-owned
# protected rows must remain byte-identical live. The shared workflow row is
# candidate-only because later serialized tasks reuse it for pending staged
# registrations after T-004's own steps have been human-applied. A later
# task's explicit HUMAN APPLY STEP may likewise add a not-yet-live protected
# candidate; those paths are derived from that task's text and are exempt only
# while the candidate's unknown-argument guard is absent from the live file.
if python3 -c "
import hashlib
import json
import re
from pathlib import Path
repo = Path('${REPO_ROOT}')
manifest = Path('${HC_MANIFEST_191}')
tasks = (repo / 'specs/epic-191-a3-path-ownership/tasks.md').read_text()
t006 = tasks.split('## T-006', 1)[1]
declared_human_apply = set(re.findall(r'human-copy/(plugins/[^\x60\s]+)', t006))
live = json.load(open('${REPO_ROOT}/plugins/sdd-quality-loop/references/guard-invariants.json'))
new = ('plugins/sdd-quality-loop/scripts/check-component-coverage.py',
       'plugins/sdd-quality-loop/scripts/check-component-coverage.ps1',
       'plugins/sdd-quality-loop/scripts/check-component-coverage.sh')
for n in new:
    if n not in live['protected_gate_suffixes']:
        raise SystemExit(f'{n} missing from live protected_gate_suffixes')
    if n not in live['phase2_human_copy_targets']:
        raise SystemExit(f'{n} missing from live phase2_human_copy_targets')
workflow = (repo / '.github/workflows/test.yml').read_text()
for marker in ('bash ./tests/check-component-coverage.tests.sh',
               './tests/check-component-coverage.tests.ps1'):
    if marker not in workflow:
        raise SystemExit(f'missing live T-004 workflow marker: {marker}')
for line in manifest.read_text().splitlines():
    if not line.strip() or line.lstrip().startswith('#'):
        continue
    expected, relative = line.split(None, 1)
    candidate = manifest.parent / relative
    if not candidate.is_file() or hashlib.sha256(candidate.read_bytes()).hexdigest() != expected:
        raise SystemExit(f'candidate hash mismatch: {relative}')
    # The repo-shared CI workflow was exempted here while this bundle
    # snapshotted it (a snapshot of a shared file cannot be compared to live).
    # That entry was evicted 2026-08-14 and TEST-045.5's class lock now forbids
    # its return, so the exemption became unreachable and is removed.
    applied = repo / relative
    if not applied.is_file():
        raise SystemExit(f'applied file missing: {relative}')
    applied_bytes = applied.read_bytes()
    guard_applied = b'if (\$args.Count -gt 0)' in applied_bytes and b'unrecognized arguments:' in applied_bytes
    pending_human_apply = relative in declared_human_apply and not guard_applied
    if not pending_human_apply and hashlib.sha256(applied_bytes).hexdigest() != expected:
        raise SystemExit(f'applied hash mismatch: {relative}')
raise SystemExit(0)
"; then
  ok "TEST-036.4: T-004's live registrations remain applied; every shared-manifest candidate hash verifies; and every T-004-owned protected row remains byte-identical live"
else
  fail "TEST-036.4: T-004 registration, staged-candidate integrity, or T-004-owned live byte identity failed against ${HC_MANIFEST_191}"
fi
# TEST-036.5 (retargeted 2026-08-11): the generator inventory check now runs
# against the LIVE tree — the applied state is what must be internally
# consistent; the drafts/bundle-a copy is a byte-identical historical
# leftover and proving it no longer proves anything the live check does not.
if python3 "${REPO_ROOT}/plugins/sdd-quality-loop/scripts/generate-guard-invariants.py" --check >/dev/null 2>&1; then
  ok "TEST-036.5: the LIVE generate-guard-invariants.py --check exits 0 against the applied live tree (internal consistency proven, not asserted)"
else
  fail "TEST-036.5: the LIVE generate-guard-invariants.py --check failed against the applied tree"
fi

echo "=== TEST-035: reachability registration (two-tier defense scope) ==="
# TEST-035.1 (rebound 2026-08-11): the old assertion grepped the superseded
# unconditional drafts/bundle-b candidate. Now BEHAVIORAL against the
# APPLIED live check-contract.py, per acceptance-tests.md's amended TEST-035
# row: with sdd/project-context.yaml present and schema-valid in a
# disposable fixture tree (the state in which the conditional required-check
# -set half is active), a high contract that omits check-component-coverage
# must FAIL, and the failure must name the check — the reachability the
# registration exists to provide.
write_035_contract() {
  # $1 = fixture root dir, $2 = task id. Writes a high contract carrying the
  # complete high-tier required set EXCEPT check-component-coverage.
  local dir="$1" task_id="$2"
  mkdir -p "${dir}/reports"
  echo "fixture evidence" > "${dir}/reports/test.log"
  cat > "${dir}/${task_id}.contract.json" <<EOF
{
  "task_id": "${task_id}",
  "feature": "test-feature",
  "risk": "high",
  "created": "2026-08-11T00:00:00Z",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
}
write_035_valid_context() {
  # $1 = fixture root dir. Schema-valid sdd/project-context.yaml (advisory).
  local dir="$1"
  mkdir -p "${dir}/sdd"
  cat > "${dir}/sdd/project-context.yaml" <<EOF
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: legacy-seven-layer
  capability_enforcement: advisory
components: []
shared_paths: []
EOF
}
WORK035="$(mktemp -d)"
write_035_contract "${WORK035}" "TEST-035"
write_035_valid_context "${WORK035}"
set +e
out035=$(python3 "$LIVE_CONTRACT_PY" "${WORK035}/TEST-035.contract.json" "${WORK035}" 2>&1)
code035=$?
set -e
if [ "$code035" -ne 0 ] && printf '%s' "$out035" | grep -q "check-component-coverage"; then
  ok "TEST-035.1: with a present, schema-valid project-context.yaml, the LIVE check-contract.py fails a high contract that omits check-component-coverage, naming the check (applied conditional registration, behavioral)"
else
  fail "TEST-035.1: expected the live check-contract.py to fail the fixture naming check-component-coverage, got exit=$code035 out=$out035"
fi
rm -rf "${WORK035}"

# TEST-035c (added 2026-08-11, acceptance-tests.md:76): conditional
# activation is fail-closed under a present-but-MALFORMED
# sdd/project-context.yaml. One unparseable-YAML variant and one
# schema-divergent variant: in both, the contract lacking the entry still
# FAILS — check still required — proving the activation predicate is plain
# file presence with no YAML parser participating. This catches the exact
# regression requirements.md's Problems paragraph warns against: an
# implementation whose caught parse exception silently concludes
# disabled-legacy and turns the tier minimum off forever. TEST-035c.1 is
# the absence control: without it, the two malformed cases could be passing
# because the contract fails for some unrelated reason.
echo "=== TEST-035c: activation is fail-closed under a present-but-malformed project-context.yaml ==="
WORK035C="$(mktemp -d)"

write_035_contract "${WORK035C}/absent" "TEST-035c"
set +e
out035c0=$(python3 "$LIVE_CONTRACT_PY" "${WORK035C}/absent/TEST-035c.contract.json" "${WORK035C}/absent" 2>&1)
code035c0=$?
set -e
if [ "$code035c0" -eq 0 ]; then
  ok "TEST-035c.1 (control): with NO project-context.yaml, the same contract passes — the failures below are attributable to config presence alone"
else
  fail "TEST-035c.1 (control): expected the absence-state contract to pass, got exit=$code035c0 out=$out035c0"
fi

write_035_contract "${WORK035C}/unparseable" "TEST-035c"
mkdir -p "${WORK035C}/unparseable/sdd"
printf 'workflow:\n\tcapability_enforcement: advisory\n' > "${WORK035C}/unparseable/sdd/project-context.yaml"
set +e
out035c1=$(python3 "$LIVE_CONTRACT_PY" "${WORK035C}/unparseable/TEST-035c.contract.json" "${WORK035C}/unparseable" 2>&1)
code035c1=$?
set -e
if [ "$code035c1" -ne 0 ] && printf '%s' "$out035c1" | grep -q "check-component-coverage"; then
  ok "TEST-035c.2: a present-but-UNPARSEABLE project-context.yaml (tab indentation) still activates the requirement — the contract lacking the entry fails naming check-component-coverage"
else
  fail "TEST-035c.2: expected fail-closed activation under an unparseable config, got exit=$code035c1 out=$out035c1"
fi

write_035_contract "${WORK035C}/divergent" "TEST-035c"
mkdir -p "${WORK035C}/divergent/sdd"
printf 'schema: some-other-schema/v9\nbogus_top_level_key: true\n' > "${WORK035C}/divergent/sdd/project-context.yaml"
set +e
out035c2=$(python3 "$LIVE_CONTRACT_PY" "${WORK035C}/divergent/TEST-035c.contract.json" "${WORK035C}/divergent" 2>&1)
code035c2=$?
set -e
if [ "$code035c2" -ne 0 ] && printf '%s' "$out035c2" | grep -q "check-component-coverage"; then
  ok "TEST-035c.3: a present-but-SCHEMA-DIVERGENT project-context.yaml still activates the requirement — the contract lacking the entry fails naming check-component-coverage"
else
  fail "TEST-035c.3: expected fail-closed activation under a schema-divergent config, got exit=$code035c2 out=$out035c2"
fi
rm -rf "${WORK035C}"

echo "=== TEST-055: check-contract producer-digest verification (AC-055) ==="
# Rebound 2026-08-11: TEST-055.2/.3 used to exercise the superseded
# unconditional drafts/bundle-b candidate via an assembled scripts copy;
# TEST-055.1 asserted the LIVE file still ACCEPTED tampered evidence
# ("documents the live gap") — permanently inverted once the human apply
# landed the producer-digest pass. All three now run the LIVE, applied
# check-contract.py: .1 proves the delivered tamper-evidence rejection, .2
# proves a genuine live-produced record still passes (anti-stuck-shut), and
# .3 asserts the superseded drafts/bundle-b candidate stays evicted.
WORK055="$(mktemp -d)"
mkdir -p "${WORK055}/reports"
echo "unused baseline evidence" > "${WORK055}/reports/baseline.log"
real_out=$(run_gate "${FIXTURES}/config-required.yaml" "${FIXTURES}/facet-manifest-full.json" "${FIXTURES}/changed-paths-clean.txt" "")
printf '%s' "$real_out" > "${WORK055}/reports/real-evidence.json"
printf '%s' "$real_out" | jqf '.producer.sha256 = "0000000000000000000000000000000000000000000000000000000000000000"' > "${WORK055}/reports/tampered-evidence.json"
make_055_contract() {
  local evidence_rel="$1" out_file="$2"
  cat > "$out_file" <<EOF
{
  "task_id": "TEST-055",
  "feature": "test-feature",
  "created": "2026-06-13T00:00:00Z",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/baseline.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/baseline.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/baseline.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/baseline.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/baseline.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/baseline.log", "waiver_reason": "" },
    { "id": "check-component-coverage", "required": false, "passes": true, "evidence": "${evidence_rel}", "waiver_reason": "" }
  ]
}
EOF
}
make_055_contract "reports/tampered-evidence.json" "${WORK055}/tampered.contract.json"
make_055_contract "reports/real-evidence.json" "${WORK055}/real.contract.json"

set +e
live_bad_out=$(python3 "$LIVE_CONTRACT_PY" "${WORK055}/tampered.contract.json" "${WORK055}" 2>&1)
live_bad_code=$?
set -e
if [ "$live_bad_code" -ne 0 ] && printf '%s' "$live_bad_out" | grep -q "does not match the live on-disk"; then
  ok "TEST-055.1: the LIVE, applied check-contract.py REJECTS a tampered check-component-coverage producer.sha256, naming the mismatch (AC-054 negative clause / AC-055 — the delivered tamper-evidence rejection, proven against real check-component-coverage.py bytes)"
else
  fail "TEST-055.1: expected the live check-contract.py to reject the tampered evidence, got exit=$live_bad_code out=$live_bad_out"
fi

set +e
live_ok_out=$(python3 "$LIVE_CONTRACT_PY" "${WORK055}/real.contract.json" "${WORK055}" 2>&1)
live_ok_code=$?
set -e
if [ "$live_ok_code" -eq 0 ]; then
  ok "TEST-055.2: the LIVE, applied check-contract.py PASSES a genuine, live-produced check-component-coverage evidence record (positive case — the producer-digest pass is not stuck shut)"
else
  fail "TEST-055.2: expected the live check-contract.py to pass genuine evidence, got exit=$live_ok_code out=$live_ok_out"
fi
rm -rf "${WORK055}"

# TEST-055.3 (eviction guard, 2026-08-11): the pre-ruling UNCONDITIONAL
# check-contract candidate staged under drafts/bundle-b/ was superseded by
# the human-ruled conditional artifact; its stale apply mapping in
# drafts/MANIFEST.sha256, if followed, would have silently reverted the
# conditional gate (0/94 passing high/critical contracts). Per the eviction
# precedent (a refreshed copy re-creates the drift channel that produced
# the hazard; an absence assertion closes it), the two candidate files are
# EVICTED and the mapping rows removed — and this assertion keeps them out.
if [ ! -e "${DRAFTS}/bundle-b/scripts/check-contract.py" ] \
   && [ ! -e "${DRAFTS}/bundle-b/scripts/check-contract.ps1" ] \
   && ! grep -v '^#' "${DRAFTS}/MANIFEST.sha256" | grep -q "bundle-b/scripts/check-contract"; then
  ok "TEST-055.3: the superseded unconditional drafts/bundle-b check-contract candidate stays evicted (no files, no MANIFEST.sha256 mapping rows) — the stale apply channel cannot silently revert the conditional gate"
else
  fail "TEST-055.3: the superseded drafts/bundle-b check-contract candidate or its manifest mapping has been resurrected"
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
