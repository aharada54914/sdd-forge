#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
FEATURE="task-layer-inputs-fixture"
WORK_ROOT="$(mktemp -d)"
SPEC_DIR="$WORK_ROOT/specs/$FEATURE"
REPORT_DIR="$WORK_ROOT/reports/task-review/$FEATURE/attempt-1/round-1"
REGISTRY="$WORK_ROOT/specs/workflow-state-registry.json"
mkdir -p "$WORK_ROOT/specs"
cp "$ROOT/specs/workflow-state-registry.json" "$REGISTRY"
mkdir -p "$WORK_ROOT/plugins"
cp -R "$ROOT/plugins/sdd-review-loop" "$ROOT/plugins/sdd-quality-loop" "$WORK_ROOT/plugins/"

cleanup() {
  rm -rf "$WORK_ROOT"
}
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }
sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
validator="$ROOT/plugins/sdd-review-loop/scripts/validate-layer-traceability.py"

write_inputs() {
  mkdir -p "$SPEC_DIR" "$REPORT_DIR"
  printf '# Tasks\n' > "$SPEC_DIR/tasks.md"
  printf '# Requirements\n\n## REQ-001\n\n## REQ-002\n' > "$SPEC_DIR/requirements.md"
  printf '# Acceptance\n' > "$SPEC_DIR/acceptance-tests.md"
  printf '# Design\n' > "$SPEC_DIR/design.md"
  for name in ux-spec.md frontend-spec.md infra-spec.md security-spec.md; do
    printf '# %s\n' "$name" > "$SPEC_DIR/$name"
  done
  printf '| Requirement | Design | Layer Spec |\n|---|---|---|\n| REQ-001 | D | ux-spec.md#journey |\n| REQ-002 | D | N/A — cross-layer only: orchestration |\n' > "$SPEC_DIR/traceability.md"
}

write_precheck() {
  local layers
  layers="$(jq -n \
    --arg ux "$(sha256 "$SPEC_DIR/ux-spec.md")" \
    --arg frontend "$(sha256 "$SPEC_DIR/frontend-spec.md")" \
    --arg infra "$(sha256 "$SPEC_DIR/infra-spec.md")" \
    --arg security "$(sha256 "$SPEC_DIR/security-spec.md")" \
    '{"ux-spec.md":$ux,"frontend-spec.md":$frontend,"infra-spec.md":$infra,"security-spec.md":$security}')"
  jq -n --arg feature "$FEATURE" \
    --arg tasks "$(sha256 "$SPEC_DIR/tasks.md")" \
    --arg requirements "$(sha256 "$SPEC_DIR/requirements.md")" \
    --arg acceptance "$(sha256 "$SPEC_DIR/acceptance-tests.md")" \
    --arg design "$(sha256 "$SPEC_DIR/design.md")" \
    --arg traceability "$(sha256 "$SPEC_DIR/traceability.md")" \
    --argjson layers "$layers" \
    '{schema:"task-review-precheck/v1",feature:$feature,attempt:1,round:1,
      tasks_sha256:$tasks,requirements_sha256:$requirements,acceptance_sha256:$acceptance,
      design_sha256:$design,traceability_sha256:$traceability,layer_sha256:$layers}' > "$REPORT_DIR/precheck-result.json"
}

jq --arg feature "$FEATURE" '.entries += [{feature:$feature,profile:"full"}]' \
  "$REGISTRY" > "$REGISTRY.tmp"
mv "$REGISTRY.tmp" "$REGISTRY"
write_inputs
write_precheck

(cd "$WORK_ROOT" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh \
  "$FEATURE" 1 1 --verify-inputs) >/dev/null ||
  fail "complete canonical task-review inputs should verify"
pass "complete task-review layer input set verifies"

for value in '' 'N/A' 'ux-spec.md' 'N/A — cross-layer only:'; do
  printf '| Requirement | Design | Layer Spec |\n|---|---|---|\n| REQ-001 | D | %s |\n' "$value" > "$SPEC_DIR/traceability.md"
  write_precheck
  if python3 "$validator" "$SPEC_DIR/traceability.md" "$SPEC_DIR/requirements.md" >/dev/null 2>&1; then
    fail "invalid Layer Spec value should fail: $value"
  fi
  if (cd "$WORK_ROOT" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh \
    "$FEATURE" 1 1 --verify-inputs) >/dev/null 2>&1; then
    fail "reviewer-time precheck should reject invalid Layer Spec value: $value"
  fi
done
pass "blank, bare N/A, malformed anchor, and reasonless exclusion fail"

write_inputs
printf '# Requirements\n\n## REQ-001\n\n## REQ-002\n' > "$SPEC_DIR/requirements.md"
printf '| Requirement | Design | Layer Spec |\n|---|---|---|\n| REQ-001 | D | ux-spec.md#journey |\n' > "$SPEC_DIR/traceability.md"
if python3 "$validator" "$SPEC_DIR/traceability.md" "$SPEC_DIR/requirements.md" >/dev/null 2>&1; then
  fail "omitted requirement row should fail Layer Spec coverage"
fi
pass "omitted applicable requirement row fails"

grep -q '\$stage == "task".*' "$ROOT/plugins/sdd-review-loop/scripts/task-review-precheck.sh" ||
  fail "task contract manifest allowlist is missing"
for name in ux-spec.md frontend-spec.md infra-spec.md security-spec.md; do
  grep -q "\$path == (\"specs/\" + \$feature + \"/$name\")" \
    "$ROOT/plugins/sdd-review-loop/scripts/task-review-precheck.sh" ||
    fail "Bash task contract manifest rejects layer input: $name"
  grep -q "\"specs/\$FeatureName/$name\"" \
    "$ROOT/plugins/sdd-review-loop/scripts/task-review-precheck.ps1" ||
    fail "PowerShell task contract manifest rejects layer input: $name"
done
pass "task contract manifests allow all four canonical layer inputs"

write_inputs
write_precheck
printf '\ndesign tamper\n' >> "$SPEC_DIR/design.md"
if (cd "$WORK_ROOT" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh \
  "$FEATURE" 1 1 --verify-inputs) >/dev/null 2>&1; then
  fail "post-manifest design tamper should fail"
fi
pass "task review binds the Phase 1 design input"

write_inputs
write_precheck
jq --arg feature "$FEATURE" '(.entries[] | select(.feature == $feature) | .profile) = "lite"' \
  "$REGISTRY" > "$REGISTRY.tmp"
mv "$REGISTRY.tmp" "$REGISTRY"
printf '\ntamper\n' >> "$SPEC_DIR/ux-spec.md"
if (cd "$WORK_ROOT" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh \
  "$FEATURE" 1 1 --verify-inputs) >/dev/null 2>&1; then
  fail "post-manifest layer tamper should fail"
fi
pass "persisted full manifest rejects tamper after profile downgrade"

write_inputs
write_precheck
rm "$SPEC_DIR/infra-spec.md"
if (cd "$WORK_ROOT" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh \
  "$FEATURE" 1 1 --verify-inputs) >/dev/null 2>&1; then
  fail "missing layer should fail"
fi
pass "missing layer input fails"

write_inputs
write_precheck
rm "$SPEC_DIR/security-spec.md"
outside="$(mktemp)"
printf '# outside\n' > "$outside"
ln -s "$outside" "$SPEC_DIR/security-spec.md"
if (cd "$WORK_ROOT" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh \
  "$FEATURE" 1 1 --verify-inputs) >/dev/null 2>&1; then
  fail "path-substituted layer should fail"
fi
rm -f "$outside"
pass "path-substituted layer input fails"

write_inputs
legacy_tasks="$(sha256 "$SPEC_DIR/tasks.md")"
legacy_req="$(sha256 "$SPEC_DIR/requirements.md")"
legacy_accept="$(sha256 "$SPEC_DIR/acceptance-tests.md")"
legacy_expected="$(printf '%s:%s:%s' "$legacy_tasks" "$legacy_req" "$legacy_accept" | shasum -a 256 | awk '{print $1}')"
grep -q 'printf.*tasks_sha256.*requirements_sha256.*acceptance_sha256' \
  "$ROOT/plugins/sdd-review-loop/scripts/task-review-precheck.sh" ||
  fail "legacy core-input hash path is missing"
[[ "$legacy_expected" =~ ^[0-9a-f]{64}$ ]] || fail "legacy input hash is invalid"
pass "legacy rollback retains the historical core-input hash"

printf 'PASS: task-review layer inputs\n'
