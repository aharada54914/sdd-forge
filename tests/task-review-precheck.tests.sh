#!/usr/bin/env bash
# Regression tests for task-review-precheck.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FEATURE="task-review-precheck-fixture"
SPEC_DIR="${REPO_ROOT}/specs/${FEATURE}"
REPORT_DIR="${REPO_ROOT}/reports/task-review/${FEATURE}"
SPEC_REPORT_DIR="${REPO_ROOT}/reports/spec-review/${FEATURE}"
IMPL_REPORT_DIR="${REPO_ROOT}/reports/impl-review/${FEATURE}"
REGISTRY="${REPO_ROOT}/specs/workflow-state-registry.json"
REGISTRY_BACKUP="$(mktemp)"
cp "${REGISTRY}" "${REGISTRY_BACKUP}"

cleanup() {
  cp "${REGISTRY_BACKUP}" "${REGISTRY}"
  rm -f "${REGISTRY_BACKUP}"
  rm -rf "${SPEC_DIR}" "${REPORT_DIR}" "${SPEC_REPORT_DIR}" "${IMPL_REPORT_DIR}"
}
trap cleanup EXIT

jq --arg feature "${FEATURE}" \
  '.entries += [{feature:$feature,profile:"lite"}]' "${REGISTRY}" > "${REGISTRY}.tmp"
mv "${REGISTRY}.tmp" "${REGISTRY}"

mkdir -p "${SPEC_DIR}"
cat > "${SPEC_DIR}/requirements.md" <<'EOF'
Spec-Review-Status: Passed
EOF
cat > "${SPEC_DIR}/design.md" <<'EOF'
Impl-Review-Status: Passed
EOF
cat > "${SPEC_DIR}/acceptance-tests.md" <<'EOF'
# Acceptance Tests
EOF

sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}

write_pass_artifacts() {
  local stage="$1"
  local output_dir="$2"
  local requirements_hash acceptance_hash design_hash calibration_path calibration_hash precheck_hash summary_hash
  requirements_hash="$(sha256 "${SPEC_DIR}/requirements.md")"
  acceptance_hash="$(sha256 "${SPEC_DIR}/acceptance-tests.md")"
  design_hash="$(sha256 "${SPEC_DIR}/design.md")"
  if [[ "${stage}" == "spec" ]]; then
    calibration_path="plugins/sdd-review-loop/references/spec-review-calibration.md"
  else
    calibration_path="plugins/sdd-review-loop/references/reviewer-calibration.md"
  fi
  calibration_hash="$(sha256 "${REPO_ROOT}/${calibration_path}")"
  mkdir -p "${output_dir}"
  printf '{}\n' > "${output_dir}/precheck-result.json"
  printf '{}\n' > "${output_dir}/integrated-summary.json"
  precheck_hash="$(sha256 "${output_dir}/precheck-result.json")"
  summary_hash="$(sha256 "${output_dir}/integrated-summary.json")"

  if [[ "${stage}" == "spec" ]]; then
    jq -n --arg feature "${FEATURE}" '{schema:"spec-review-integrated-verdict/v1",stage:"spec",feature:$feature,attempt:1,round:1,verdict:"PASS",reviewer_a_run_id:"spec-a-run",reviewer_b_run_id:"spec-b-run",reviewer_a_host_session_id:"spec-a-session",reviewer_b_host_session_id:"spec-b-session",finding_count:0,warning_count:0}' > "${output_dir}/integrated-verdict.json"
  else
    jq -n --arg feature "${FEATURE}" --arg stage "${stage}" '{schema:"integrated-verdict/v1",stage:$stage,feature:$feature,attempt:1,round:1,run_id:($stage + "-contract-run"),verdict:"PASS"}' > "${output_dir}/integrated-verdict.json"
  fi

  jq -n \
    --arg stage "${stage}" \
    --arg feature "${FEATURE}" \
    --arg requirements_hash "${requirements_hash}" \
    --arg acceptance_hash "${acceptance_hash}" \
    --arg design_hash "${design_hash}" \
    --arg calibration_path "${calibration_path}" \
    --arg calibration_hash "${calibration_hash}" \
    --arg precheck_hash "${precheck_hash}" \
    --arg summary_hash "${summary_hash}" \
    '{schema:($stage + "-review-contract/v1"),stage:$stage,feature:$feature,attempt:1,round:1,run_id:($stage + "-contract-run"),verdict:"PASS",reviewers:[
      {role:($stage + "-reviewer-a"),run_id:($stage + "-a-run"),host_session_id:($stage + "-a-session"),allowed_input_manifest:[
        {path:("specs/" + $feature + "/requirements.md"),sha256:$requirements_hash},
        {path:("specs/" + $feature + "/acceptance-tests.md"),sha256:$acceptance_hash},
        {path:$calibration_path,sha256:$calibration_hash},
        {path:("reports/" + $stage + "-review/" + $feature + "/attempt-1/round-1/precheck-result.json"),sha256:$precheck_hash}
      ]},
      {role:($stage + "-reviewer-b"),run_id:($stage + "-b-run"),host_session_id:($stage + "-b-session"),allowed_input_manifest:[
        {path:("specs/" + $feature + "/requirements.md"),sha256:$requirements_hash},
        {path:("specs/" + $feature + "/acceptance-tests.md"),sha256:$acceptance_hash},
        {path:$calibration_path,sha256:$calibration_hash},
        {path:("reports/" + $stage + "-review/" + $feature + "/attempt-1/round-1/precheck-result.json"),sha256:$precheck_hash},
        {path:("reports/" + $stage + "-review/" + $feature + "/attempt-1/round-1/integrated-summary.json"),sha256:$summary_hash}
      ]}
    ]}
    | if $stage == "impl" then .reviewers |= map(.allowed_input_manifest += [
        {path:("specs/" + $feature + "/design.md"),sha256:$design_hash}
      ]) else . end' > "${output_dir}/${stage}-review-contract.json"
}

mkdir -p "${SPEC_REPORT_DIR}/attempt-1/round-1" "${IMPL_REPORT_DIR}/attempt-1/round-1"
write_pass_artifacts spec "${SPEC_REPORT_DIR}/attempt-1/round-1"
write_pass_artifacts impl "${IMPL_REPORT_DIR}/attempt-1/round-1"
cat > "${SPEC_DIR}/tasks.md" <<'EOF'
# Tasks

## T-001 First
Risk: low
Risk Rationale: Fixture coverage for dependency graph parsing.
Required Workflow: test-after
### Blockers
None

## T-002 Second
Risk: low
Risk Rationale: Fixture coverage for dependency graph parsing.
Required Workflow: test-after
### Blockers
T-001
EOF

(
  cd "${REPO_ROOT}"
  bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "${FEATURE}" 1 1 >/dev/null
)

edges="$(jq -c '.edges' "${REPORT_DIR}/attempt-1/round-1/dependency-graph.json")"
if [[ "${edges}" != '[{"from":"T-002","to":"T-001"}]' ]]; then
  echo "expected dependency edge T-002 -> T-001; got ${edges}" >&2
  exit 1
fi

echo "ok: task review precheck records heading-style blocker dependencies"

# ──────────────────────────────────────────────────────────────────────────────
# Issue #61 regression (task gate): predecessor gates persist manifest paths as
# absolute paths of the checkout that generated them. The task gate must accept
# that canonical format from any checkout, while tampered hashes and
# anchor-less absolute paths keep failing closed.
# ──────────────────────────────────────────────────────────────────────────────

rewrite_contract_paths_to_checkout() {
  local contract="$1" checkout_root="$2"
  jq --arg root "${checkout_root}/" \
    '(.reviewers[].allowed_input_manifest[].path) |= ($root + .)' \
    "${contract}" > "${contract}.tmp"
  mv "${contract}.tmp" "${contract}"
}

write_foreign_checkout_artifacts() {
  local checkout_root="$1"
  write_pass_artifacts spec "${SPEC_REPORT_DIR}/attempt-1/round-1"
  write_pass_artifacts impl "${IMPL_REPORT_DIR}/attempt-1/round-1"
  rewrite_contract_paths_to_checkout "${SPEC_REPORT_DIR}/attempt-1/round-1/spec-review-contract.json" "${checkout_root}"
  rewrite_contract_paths_to_checkout "${IMPL_REPORT_DIR}/attempt-1/round-1/impl-review-contract.json" "${checkout_root}"
}

expect_denied_without_evidence() {
  local label="$1"
  if (cd "${REPO_ROOT}" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "${FEATURE}" 1 1) >/dev/null 2>&1; then
    echo "expected task precheck to deny: ${label}" >&2
    exit 1
  fi
  if [[ -e "${REPORT_DIR}/attempt-1/round-1" ]]; then
    echo "denied task precheck must not create round evidence: ${label}" >&2
    exit 1
  fi
}

rm -rf "${REPORT_DIR}"

write_foreign_checkout_artifacts "/original-checkout/sdd-forge"
(
  cd "${REPO_ROOT}"
  bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "${FEATURE}" 1 1 >/dev/null
) || {
  echo "task precheck must accept canonical predecessor contracts from another checkout" >&2
  exit 1
}
rm -rf "${REPORT_DIR}"
echo "ok: task review precheck accepts predecessor contracts from another checkout"

write_foreign_checkout_artifacts "/original-checkout/sdd-forge"
jq '(.reviewers[].allowed_input_manifest[] | select(.path | endswith("/requirements.md")) | .sha256) = ("1"*64)' \
  "${SPEC_REPORT_DIR}/attempt-1/round-1/spec-review-contract.json" > "${SPEC_REPORT_DIR}/attempt-1/round-1/spec-review-contract.tmp"
mv "${SPEC_REPORT_DIR}/attempt-1/round-1/spec-review-contract.tmp" "${SPEC_REPORT_DIR}/attempt-1/round-1/spec-review-contract.json"
expect_denied_without_evidence "tampered requirements hash in foreign-checkout spec contract"
echo "ok: task review precheck denies tampered foreign-checkout contract hashes"

write_foreign_checkout_artifacts "/original-checkout/sdd-forge"
jq '(.reviewers[0].allowed_input_manifest) += [{path:"/original-checkout/outside/escape.md",sha256:("0"*64)}]' \
  "${SPEC_REPORT_DIR}/attempt-1/round-1/spec-review-contract.json" > "${SPEC_REPORT_DIR}/attempt-1/round-1/spec-review-contract.tmp"
mv "${SPEC_REPORT_DIR}/attempt-1/round-1/spec-review-contract.tmp" "${SPEC_REPORT_DIR}/attempt-1/round-1/spec-review-contract.json"
expect_denied_without_evidence "anchor-less absolute manifest path in foreign-checkout contract"
echo "ok: task review precheck denies anchor-less absolute manifest paths"

# ──────────────────────────────────────────────────────────────────────────────
# WFI-030: frozen_artifact_done_when is a detector, not a gate
# ──────────────────────────────────────────────────────────────────────────────
# The rule that a Done When item must not require editing a review-frozen
# artifact was prose evaluated by a reviewer, with nothing deterministic behind
# it. This records the candidates so the review gate can adjudicate each one.
# It must not change the exit code: measured over this repository the trigger
# fires on six items and only three are real, so failing on it would block half
# the plans it fires on.
write_pass_artifacts spec "${SPEC_REPORT_DIR}/attempt-1/round-1"
write_pass_artifacts impl "${IMPL_REPORT_DIR}/attempt-1/round-1"
cat > "${SPEC_DIR}/tasks.md" <<'EOF'
# Tasks

## T-001 Single line
Risk: low
Risk Rationale: Fixture coverage for the frozen-artifact Done When detector.
Required Workflow: test-after
### Blockers
None
### Done When
- [ ] traceability.md rows for REQ-001 record this task's evidence paths.
- [ ] The design.md Test Strategy section is cited as the source of the
  fixture count.

## T-002 Wrapped across a continuation line
Risk: low
Risk Rationale: Fixture coverage for the frozen-artifact Done When detector.
Required Workflow: test-after
### Blockers
T-001
### Done When
- [ ] **Requirement traceability** — traceability.md rows for REQ-002 and
  REQ-003 record this task's evidence paths.
EOF

rm -rf "${REPORT_DIR}/attempt-1/round-1"
(
  cd "${REPO_ROOT}"
  bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "${FEATURE}" 1 1 >/dev/null
) || { echo "precheck failed while emitting frozen_artifact_done_when" >&2; exit 1; }

frozen="$(jq -c '[.frozen_artifact_done_when[] | {task, line}]' \
  "${REPORT_DIR}/attempt-1/round-1/precheck-result.json")"
if [[ "${frozen}" != '[{"task":"T-001","line":10},{"task":"T-002","line":21}]' ]]; then
  echo "expected the single-line and the wrapped item, and only those; got ${frozen}" >&2
  exit 1
fi
echo "ok: task review precheck records frozen-artifact Done When items"

# The citation-only item on T-001 names design.md but carries no write verb, so
# it must not be listed. Without this direction the detector could fire on every
# item that merely mentions a frozen artifact and still look correct.
if jq -e '[.frozen_artifact_done_when[].item] | any(test("cited as the source"))' \
  "${REPORT_DIR}/attempt-1/round-1/precheck-result.json" >/dev/null; then
  echo "citation-only Done When item was wrongly recorded" >&2
  exit 1
fi
echo "ok: task review precheck leaves citation-only Done When items unrecorded"

# The wrapped item's artifact name and write verb sit on different lines. A
# line-at-a-time scan finds only the single-line case, which is what the first
# implementation did over the live corpus (1 of 3 real items).
if ! jq -e '[.frozen_artifact_done_when[] | select(.task == "T-002") | .item]
            | any(test("REQ-003 record"))' \
  "${REPORT_DIR}/attempt-1/round-1/precheck-result.json" >/dev/null; then
  echo "continuation lines were not joined before matching" >&2
  exit 1
fi
echo "ok: task review precheck joins Done When continuation lines"
