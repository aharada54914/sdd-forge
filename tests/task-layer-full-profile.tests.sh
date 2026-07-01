#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
FEATURE="workflow-state-integrity"
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }
sha256() { shasum -a 256 "$1" | awk '{print $1}'; }

mkdir -p \
  "$TMP/plugins/sdd-review-loop" \
  "$TMP/plugins/sdd-quality-loop" \
  "$TMP/contracts" \
  "$TMP/specs" \
  "$TMP/reports/spec-review" \
  "$TMP/reports/impl-review" \
  "$TMP/reports/task-review"
cp -R "$ROOT/plugins/sdd-review-loop/scripts" "$TMP/plugins/sdd-review-loop/"
cp -R "$ROOT/plugins/sdd-review-loop/references" "$TMP/plugins/sdd-review-loop/"
cp -R "$ROOT/plugins/sdd-quality-loop/scripts" "$TMP/plugins/sdd-quality-loop/"
cp -R "$ROOT/plugins/sdd-quality-loop/references" "$TMP/plugins/sdd-quality-loop/"
cp -R "$ROOT/specs/$FEATURE" "$TMP/specs/"
cp -R "$ROOT/reports/spec-review/$FEATURE" "$TMP/reports/spec-review/"
cp -R "$ROOT/reports/impl-review/$FEATURE" "$TMP/reports/impl-review/"
cp -R "$ROOT/reports/task-review/$FEATURE" "$TMP/reports/task-review/"
# Force a "full" profile for the isolated fixture regardless of the real
# registry's current classification of $FEATURE. This test exercises the
# full-profile layer-binding code path specifically; $FEATURE may be
# grandfathered to "legacy" in the live registry (e.g. after provenance-hash
# drift), which is orthogonal to what this fixture needs to validate.
jq --arg feature "$FEATURE" \
  '{schema_version,migration_baseline_commit,entries:[.entries[]|select(.feature==$feature)|.profile="full"|del(.legacy)]}' \
  "$ROOT/specs/workflow-state-registry.json" > "$TMP/specs/workflow-state-registry.json"
cp "$ROOT/contracts/workflow-state-registry.schema.json" "$TMP/contracts/"

while IFS= read -r evidence; do
  sed -i.bak "s#$ROOT#$TMP#g" "$evidence"
  rm -f "$evidence.bak"
done < <(find "$TMP/reports" -type f \
  \( -name '*-review-contract.json' -o -name 'reviewer-a.json' -o -name 'reviewer-b.json' \))

SPEC="$TMP/specs/$FEATURE"
for name in ux-spec.md frontend-spec.md infra-spec.md security-spec.md; do
  printf '# %s\n\n## canonical\n\nFixture.\n' "$name" > "$SPEC/$name"
done
printf '| Requirement | Design | Layer Spec |\n|---|---|---|\n' > "$SPEC/traceability.md"
while IFS= read -r requirement_id; do
  printf '| %s | D | ux-spec.md#canonical |\n' "$requirement_id" >> "$SPEC/traceability.md"
done < <(grep -Eo 'REQ-[0-9]{3}' "$SPEC/requirements.md" | sort -u)

TASK_ROUND="$(find "$TMP/reports/task-review/$FEATURE" -type f -name integrated-verdict.json \
  -exec dirname {} \; | sort -V | tail -1)"
PRECHECK="$TASK_ROUND/precheck-result.json"
CONTRACT="$TASK_ROUND/task-review-contract.json"
DESIGN_HASH="$(sha256 "$SPEC/design.md")"
TRACE_HASH="$(sha256 "$SPEC/traceability.md")"
LAYERS="$(jq -n \
  --arg ux "$(sha256 "$SPEC/ux-spec.md")" \
  --arg frontend "$(sha256 "$SPEC/frontend-spec.md")" \
  --arg infra "$(sha256 "$SPEC/infra-spec.md")" \
  --arg security "$(sha256 "$SPEC/security-spec.md")" \
  '{"ux-spec.md":$ux,"frontend-spec.md":$frontend,"infra-spec.md":$infra,"security-spec.md":$security}')"
jq --arg design "$DESIGN_HASH" --arg trace "$TRACE_HASH" --argjson layers "$LAYERS" \
  '.design_sha256=$design|.traceability_sha256=$trace|.layer_sha256=$layers' \
  "$PRECHECK" > "$TMP/precheck.tmp"
mv "$TMP/precheck.tmp" "$PRECHECK"
PRECHECK_REL="${PRECHECK#"$TMP/"}"
PRECHECK_HASH="$(sha256 "$PRECHECK")"

jq --arg feature "$FEATURE" --arg design "$DESIGN_HASH" --arg trace "$TRACE_HASH" \
  --arg precheck "$PRECHECK_REL" --arg precheck_hash "$PRECHECK_HASH" \
  --argjson layers "$LAYERS" '
  .design_sha256=$design | .traceability_sha256=$trace | .layer_sha256=$layers |
  .reviewers[].allowed_input_manifest |=
    (map(select(
      ((.path | endswith($precheck)) | not) and
      ((.path | endswith("/design.md")) | not) and
      ((.path | endswith("/traceability.md")) | not) and
      ((.path | test("/(ux|frontend|infra|security)-spec\\.md$")) | not)
    )) + [
      {path:("specs/"+$feature+"/design.md"),sha256:$design},
      {path:("specs/"+$feature+"/traceability.md"),sha256:$trace},
      {path:("specs/"+$feature+"/ux-spec.md"),sha256:$layers["ux-spec.md"]},
      {path:("specs/"+$feature+"/frontend-spec.md"),sha256:$layers["frontend-spec.md"]},
      {path:("specs/"+$feature+"/infra-spec.md"),sha256:$layers["infra-spec.md"]},
      {path:("specs/"+$feature+"/security-spec.md"),sha256:$layers["security-spec.md"]},
      {path:$precheck,sha256:$precheck_hash}
    ])
  ' "$CONTRACT" > "$TMP/contract.tmp"
mv "$TMP/contract.tmp" "$CONTRACT"

jq --slurpfile contract "$CONTRACT" \
  '.manifest=($contract[0].reviewers[]|select(.role=="task-reviewer-a")|.allowed_input_manifest)' \
  "$TASK_ROUND/reviewer-a.json" > "$TMP/reviewer-a.tmp"
mv "$TMP/reviewer-a.tmp" "$TASK_ROUND/reviewer-a.json"
jq --slurpfile contract "$CONTRACT" \
  '.manifest.allowed_inputs=($contract[0].reviewers[]|select(.role=="task-reviewer-b")|.allowed_input_manifest)' \
  "$TASK_ROUND/reviewer-b.json" > "$TMP/reviewer-b.tmp"
mv "$TMP/reviewer-b.tmp" "$TASK_ROUND/reviewer-b.json"

if ! output="$(cd "$TMP" && bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh \
  --feature "$FEATURE" 2>&1)"; then
  printf '%s\n' "$output" >&2
  jq -r '.reviewers[] | .role, (.allowed_input_manifest[].path)' "$CONTRACT" >&2
  fail "full-profile task contract with design, traceability, and layer manifests should validate"
fi
pass "full-profile task contract validates complete reviewer manifests"

sed -i.bak \
  -e 's/^Task-Review-Status: Passed$/Task-Review-Status: Pending/' \
  -e 's/^Approval:.*/Approval: Draft/' \
  -e 's/^Status:.*/Status: Planned/' \
  "$SPEC/tasks.md"
rm -f "$SPEC/tasks.md.bak"
rm -rf "$TMP/reports/task-review/$FEATURE"

(cd "$TMP" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh \
  "$FEATURE" 1 1) >/dev/null ||
  fail "Bash normal full-profile task precheck should pass"
jq -e --arg design "$DESIGN_HASH" --arg trace "$TRACE_HASH" '
  .design_sha256==$design and .traceability_sha256==$trace and
  ((.layer_sha256|keys)==["frontend-spec.md","infra-spec.md","security-spec.md","ux-spec.md"])
' "$TMP/reports/task-review/$FEATURE/attempt-1/round-1/precheck-result.json" >/dev/null ||
  fail "Bash normal precheck did not bind every canonical full-profile input"
pass "Bash normal full-profile task precheck binds complete canonical inputs"

rm -rf "$TMP/reports/task-review/$FEATURE"
(cd "$TMP" && pwsh -NoProfile -File plugins/sdd-review-loop/scripts/task-review-precheck.ps1 \
  -Feature "$FEATURE" -Attempt 1 -Round 1) >/dev/null ||
  fail "PowerShell normal full-profile task precheck should pass"
jq -e --arg design "$DESIGN_HASH" --arg trace "$TRACE_HASH" '
  .design_sha256==$design and .traceability_sha256==$trace and
  ((.layer_sha256|keys)==["frontend-spec.md","infra-spec.md","security-spec.md","ux-spec.md"])
' "$TMP/reports/task-review/$FEATURE/attempt-1/round-1/precheck-result.json" >/dev/null ||
  fail "PowerShell normal precheck did not bind every canonical full-profile input"
pass "PowerShell normal full-profile task precheck binds complete canonical inputs"

printf 'PASS: full-profile task-review integration\n'
