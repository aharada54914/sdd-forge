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
