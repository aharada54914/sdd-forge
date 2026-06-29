#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
FEATURE="impl-layer-inputs-fixture"
SPEC_DIR="$ROOT/specs/$FEATURE"
SPEC_REPORT="$ROOT/reports/spec-review/$FEATURE"
IMPL_REPORT="$ROOT/reports/impl-review/$FEATURE"
REGISTRY="$ROOT/specs/workflow-state-registry.json"
REGISTRY_BACKUP="$(mktemp)"
cp "$REGISTRY" "$REGISTRY_BACKUP"

cleanup() {
  cp "$REGISTRY_BACKUP" "$REGISTRY"
  rm -f "$REGISTRY_BACKUP"
  rm -rf "$SPEC_DIR" "$SPEC_REPORT" "$IMPL_REPORT"
}
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }
sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
spec_sha256() {
  sed 's/^Spec-Review-Status:[[:space:]]*.*/Spec-Review-Status: Pending/' "$1" |
    shasum -a 256 | awk '{print $1}'
}

write_inputs() {
  mkdir -p "$SPEC_DIR"
  printf 'Spec-Review-Status: Passed\n' > "$SPEC_DIR/requirements.md"
  printf 'Impl-Review-Status: Pending\n' > "$SPEC_DIR/design.md"
  printf '# Acceptance\n' > "$SPEC_DIR/acceptance-tests.md"
  for name in ux-spec.md frontend-spec.md infra-spec.md security-spec.md; do
    printf '# %s\n' "$name" > "$SPEC_DIR/$name"
  done
}

write_spec_pass() {
  local directory="$SPEC_REPORT/attempt-1/round-1"
  local req acc calibration precheck summary
  mkdir -p "$directory"
  req="$(spec_sha256 "$SPEC_DIR/requirements.md")"
  acc="$(sha256 "$SPEC_DIR/acceptance-tests.md")"
  calibration="$(sha256 "$ROOT/plugins/sdd-review-loop/references/spec-review-calibration.md")"
  jq -n --arg feature "$FEATURE" --arg req "$req" --arg acc "$acc" --arg calibration "$calibration" \
    '{schema:"spec-review-precheck/v1",stage:"spec",feature:$feature,attempt:1,round:1,
      spec_review_status_field:"Pending",requirements_sha256:$req,acceptance_sha256:$acc,
      calibration_sha256:$calibration,input_sha256:$req,edit_summary:"",reset:false,
      generated_at:"2026-06-23T00:00:00Z"}' > "$directory/precheck-result.json"
  jq -n \
    '["REQ-TESTABILITY","GOAL-AC-TRACE","AC-OBSERVABLE","SCOPE-BOUNDARY","CONSTRAINTS-EXPLICIT","RISK-VALIDATION-SURFACE"] as $ids |
    {schema:"integrated-summary/v1",attempt:1,round:1,
      reviewer_a_checks:($ids | map({id:.,result:"PASS",severity:"Minor"})),
      reviewer_a_fail_count:0,reviewer_a_pass_count:6,reviewer_a_skip_count:0,
      generated_at:"2026-06-23T00:00:00Z"}' > "$directory/integrated-summary.json"
  precheck="$(sha256 "$directory/precheck-result.json")"
  summary="$(sha256 "$directory/integrated-summary.json")"
  jq -n --arg requirements "$SPEC_DIR/requirements.md" --arg acceptance "$SPEC_DIR/acceptance-tests.md" \
    --arg calibration_path "$ROOT/plugins/sdd-review-loop/references/spec-review-calibration.md" \
    --arg precheck_path "$directory/precheck-result.json" \
    --arg req "$req" --arg acc "$acc" --arg calibration "$calibration" --arg precheck "$precheck" \
    '["REQ-TESTABILITY","GOAL-AC-TRACE","AC-OBSERVABLE","SCOPE-BOUNDARY","CONSTRAINTS-EXPLICIT","RISK-VALIDATION-SURFACE"] as $ids |
    {schema:"spec-reviewer-a/v1",stage:"spec",role:"spec-reviewer-a",run_id:"spec-a",host_session_id:"session-a",
      allowed_input_manifest:[
        {path:$requirements,sha256:$req},{path:$acceptance,sha256:$acc},
        {path:$precheck_path,sha256:$precheck},{path:$calibration_path,sha256:$calibration}],
      verdict:"PASS",checks:($ids | map({id:.,result:"PASS",severity:"Minor",finding:"fixture pass"}))}' \
    > "$directory/reviewer-a.json"
  jq -n --arg requirements "$SPEC_DIR/requirements.md" --arg acceptance "$SPEC_DIR/acceptance-tests.md" \
    --arg calibration_path "$ROOT/plugins/sdd-review-loop/references/spec-review-calibration.md" \
    --arg precheck_path "$directory/precheck-result.json" --arg summary_path "$directory/integrated-summary.json" \
    --arg req "$req" --arg acc "$acc" --arg calibration "$calibration" --arg precheck "$precheck" --arg summary "$summary" \
    '["AMBIGUITY","CONTRADICTION","EDGE-CASE-COVERAGE","ASSUMPTIONS-RESOLVABLE","APPROVAL-BOUNDARY","DOWNSTREAM-READINESS"] as $ids |
    {schema:"spec-reviewer-b/v1",stage:"spec",role:"spec-reviewer-b",run_id:"spec-b",host_session_id:"session-b",
      allowed_input_manifest:[
        {path:$requirements,sha256:$req},{path:$acceptance,sha256:$acc},
        {path:$precheck_path,sha256:$precheck},{path:$calibration_path,sha256:$calibration},
        {path:$summary_path,sha256:$summary}],
      verdict:"PASS",checks:($ids | map({id:.,result:"PASS",severity:"Minor",finding:"fixture pass"}))}' \
    > "$directory/reviewer-b.json"
  jq -n --arg feature "$FEATURE" \
    '{schema:"spec-review-integrated-verdict/v1",stage:"spec",feature:$feature,attempt:1,round:1,reviewer_a_run_id:"spec-a",reviewer_b_run_id:"spec-b",reviewer_a_host_session_id:"session-a",reviewer_b_host_session_id:"session-b",finding_counts:{critical:0,major:0,minor:0},verdict:"PASS",warningCount:0}' \
    > "$directory/integrated-verdict.json"
  jq -n --arg feature "$FEATURE" --arg req "$req" --arg acc "$acc" \
    --arg calibration "$calibration" --arg precheck "$precheck" --arg summary "$summary" \
    --arg requirements "$SPEC_DIR/requirements.md" --arg acceptance "$SPEC_DIR/acceptance-tests.md" \
    --arg calibration_path "$ROOT/plugins/sdd-review-loop/references/spec-review-calibration.md" \
    --arg precheck_path "$directory/precheck-result.json" --arg summary_path "$directory/integrated-summary.json" \
    '{schema:"spec-review-contract/v1",stage:"spec",feature:$feature,attempt:1,round:1,run_id:"spec-orchestrator",verdict:"PASS",warningCount:0,requirements_sha256:$req,acceptance_sha256:$acc,reviewers:[
      {role:"spec-reviewer-a",run_id:"spec-a",host_session_id:"session-a",allowed_input_manifest:[
        {path:$requirements,sha256:$req},{path:$acceptance,sha256:$acc},
        {path:$precheck_path,sha256:$precheck},{path:$calibration_path,sha256:$calibration}]},
      {role:"spec-reviewer-b",run_id:"spec-b",host_session_id:"session-b",allowed_input_manifest:[
        {path:$requirements,sha256:$req},{path:$acceptance,sha256:$acc},
        {path:$precheck_path,sha256:$precheck},{path:$calibration_path,sha256:$calibration},
        {path:$summary_path,sha256:$summary}]}
    ]}' > "$directory/spec-review-contract.json"
}

reset_impl_report() { rm -rf "$IMPL_REPORT"; }
run_precheck() {
  (cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh "$FEATURE" 1 1)
}

jq --arg feature "$FEATURE" '.entries += [{feature:$feature,profile:"full"}]' \
  "$REGISTRY" > "$REGISTRY.tmp"
mv "$REGISTRY.tmp" "$REGISTRY"
write_inputs
write_spec_pass

run_precheck >/dev/null || fail "complete canonical layer inputs should pass"
PRECHECK="$IMPL_REPORT/attempt-1/round-1/precheck-result.json"
jq -e '
  .layer_sha256 |
  keys == ["frontend-spec.md","infra-spec.md","security-spec.md","ux-spec.md"] and
  all(.[]; test("^[0-9a-f]{64}$"))
' "$PRECHECK" >/dev/null || fail "precheck must hash-bind all four layer inputs"
pass "complete implementation-review layer input set is hash-bound"

(cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh \
  "$FEATURE" 1 1 --verify-inputs) >/dev/null ||
  fail "unchanged layer inputs should verify"
pass "unchanged layer manifest verifies before reviewer invocation"

jq --arg feature "$FEATURE" '(.entries[] | select(.feature == $feature) | .profile) = "lite"' \
  "$REGISTRY" > "$REGISTRY.tmp"
mv "$REGISTRY.tmp" "$REGISTRY"
printf '\npost-manifest tamper\n' >> "$SPEC_DIR/ux-spec.md"
if (cd "$ROOT" && bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh \
  "$FEATURE" 1 1 --verify-inputs) >/dev/null 2>&1; then
  fail "post-manifest layer tamper should fail after a registry profile downgrade"
fi
pass "persisted full manifest rejects tamper after registry profile downgrade"
jq --arg feature "$FEATURE" '(.entries[] | select(.feature == $feature) | .profile) = "full"' \
  "$REGISTRY" > "$REGISTRY.tmp"
mv "$REGISTRY.tmp" "$REGISTRY"
write_inputs

for name in ux-spec.md frontend-spec.md infra-spec.md security-spec.md; do
  reset_impl_report
  mv "$SPEC_DIR/$name" "$SPEC_DIR/$name.missing"
  if run_precheck >/dev/null 2>&1; then
    fail "missing $name should fail"
  fi
  [[ ! -e "$IMPL_REPORT" ]] || fail "missing $name created review evidence"
  mv "$SPEC_DIR/$name.missing" "$SPEC_DIR/$name"
  pass "missing $name fails before reviewer invocation"
done

reset_impl_report
outside="$(mktemp)"
printf '# outside\n' > "$outside"
rm "$SPEC_DIR/security-spec.md"
ln -s "$outside" "$SPEC_DIR/security-spec.md"
if run_precheck >/dev/null 2>&1; then fail "symlink-substituted layer should fail"; fi
[[ ! -e "$IMPL_REPORT" ]] || fail "substituted layer created review evidence"
rm "$SPEC_DIR/security-spec.md" "$outside"
printf '# security-spec.md\n' > "$SPEC_DIR/security-spec.md"
pass "path-substituted layer fails before reviewer invocation"

jq --arg feature "$FEATURE" '(.entries[] | select(.feature == $feature) | .profile) = "lite"' \
  "$REGISTRY" > "$REGISTRY.tmp"
mv "$REGISTRY.tmp" "$REGISTRY"
reset_impl_report
run_precheck >/dev/null || fail "legacy-compatible profile should retain the core-only precheck"
legacy_expected="$(printf '%s:%s:%s' \
  "$(sha256 "$SPEC_DIR/design.md")" "$(sha256 "$SPEC_DIR/requirements.md")" \
  "$(sha256 "$SPEC_DIR/acceptance-tests.md")" | shasum -a 256 | awk '{print $1}')"
jq -e --arg expected "$legacy_expected" \
  '.layer_sha256 == {} and .input_sha256 == $expected' "$PRECHECK" >/dev/null ||
  fail "legacy-compatible profile changed the historical core-input contract hash"
pass "isolated rollback fixture preserves the legacy core-input contract hash"

printf 'PASS: implementation-review layer inputs\n'
