#!/usr/bin/env bash
# Regression tests for the impl-review contract shape that
# task-review-precheck.sh requires once an impl review has run more than one
# round (WFI-029 defect 4), and for the investigation.md binding it requires
# from both reviewers (WFI-029 defect 1).
#
# Why this suite exists
# ---------------------
# impl-reviewer-a.md forbade reading any prior-round integrated-summary.json
# while task-review-precheck.sh failed the task stage unless reviewer A's
# manifest bound exactly that file. Both statements were load-bearing; an
# orchestrator could satisfy one or the other but never both, so every feature
# whose impl review needed a second round produced evidence the task stage
# rejected. fea5ccd0 resolved it in reviewer A's favour: the role file now
# admits the previous round's summary as a stated Issue #143 exception, bounded
# to counts and check IDs.
#
# The tests guarding that resolution (review-context-boundary.tests.sh:50-54)
# only grep for the presence of two strings. They cannot tell whether a contract
# assembled the way the role file and the impl-review-loop SKILL.md instruct is
# actually accepted, and task-review-precheck.tests.sh never builds a round > 1
# fixture at all, so the stored_round > 1 branch had no behavioural coverage.
# This suite supplies it, and proves non-vacuity by mutating each binding away
# and requiring the specific denial back.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FEATURE="impl-review-round2-fixture"
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
# investigation.md is the normal case for a bootstrapped feature, and the
# precheck hash-binds it in BOTH reviewer manifests whenever it exists.
cat > "${SPEC_DIR}/investigation.md" <<'EOF'
# Investigation

- INV-001: fixture evidence for the round-2 contract suite.
EOF
cat > "${SPEC_DIR}/tasks.md" <<'EOF'
# Tasks

## T-001 First
Risk: low
Risk Rationale: Fixture coverage for the round-2 impl contract.
Required Workflow: test-after
### Blockers
None

## T-002 Second
Risk: low
Risk Rationale: Fixture coverage for the round-2 impl contract.
Required Workflow: test-after
### Blockers
T-001
EOF

sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}

CALIBRATION_PATH="plugins/sdd-review-loop/references/reviewer-calibration.md"
SPEC_CALIBRATION_PATH="plugins/sdd-review-loop/references/spec-review-calibration.md"

# Round evidence a reviewer pair leaves behind, independent of verdict.
write_round_evidence() {
  local output_dir="$1"
  mkdir -p "${output_dir}"
  printf '{}\n' > "${output_dir}/precheck-result.json"
  printf '{}\n' > "${output_dir}/integrated-summary.json"
}

# The spec-stage predecessor. Single round, clean PASS.
write_spec_contract() {
  local output_dir="${SPEC_REPORT_DIR}/attempt-1/round-1"
  local round_root="reports/spec-review/${FEATURE}/attempt-1/round-1"
  write_round_evidence "${output_dir}"
  jq -n --arg feature "${FEATURE}" \
    '{schema:"spec-review-integrated-verdict/v1",stage:"spec",feature:$feature,attempt:1,round:1,verdict:"PASS",reviewer_a_run_id:"spec-a-run",reviewer_b_run_id:"spec-b-run",reviewer_a_host_session_id:"spec-a-session",reviewer_b_host_session_id:"spec-b-session",finding_count:0,warning_count:0}' \
    > "${output_dir}/integrated-verdict.json"
  jq -n \
    --arg feature "${FEATURE}" \
    --arg calibration "${SPEC_CALIBRATION_PATH}" \
    --arg calibration_hash "$(sha256 "${REPO_ROOT}/${SPEC_CALIBRATION_PATH}")" \
    --arg requirements_hash "$(sha256 "${SPEC_DIR}/requirements.md")" \
    --arg acceptance_hash "$(sha256 "${SPEC_DIR}/acceptance-tests.md")" \
    --arg investigation_hash "$(sha256 "${SPEC_DIR}/investigation.md")" \
    --arg precheck_hash "$(sha256 "${output_dir}/precheck-result.json")" \
    --arg summary_hash "$(sha256 "${output_dir}/integrated-summary.json")" \
    --arg round_root "${round_root}" \
    '[{path:("specs/" + $feature + "/requirements.md"),sha256:$requirements_hash},
      {path:("specs/" + $feature + "/acceptance-tests.md"),sha256:$acceptance_hash},
      {path:("specs/" + $feature + "/investigation.md"),sha256:$investigation_hash},
      {path:$calibration,sha256:$calibration_hash},
      {path:($round_root + "/precheck-result.json"),sha256:$precheck_hash}] as $shared |
     {schema:"spec-review-contract/v1",stage:"spec",feature:$feature,attempt:1,round:1,
      run_id:"spec-contract-run",verdict:"PASS",
      reviewers:[
        {role:"spec-reviewer-a",run_id:"spec-a-run",host_session_id:"spec-a-session",
         allowed_input_manifest:$shared},
        {role:"spec-reviewer-b",run_id:"spec-b-run",host_session_id:"spec-b-session",
         allowed_input_manifest:($shared + [{path:($round_root + "/integrated-summary.json"),sha256:$summary_hash}])}
      ]}' > "${output_dir}/spec-review-contract.json"
}

# The impl-stage predecessor, exactly as impl-review-loop leaves it after a
# round-1 NEEDS_WORK and a round-2 clean PASS:
#
#   attempt-1/round-1/  precheck-result.json, integrated-summary.json,
#                       integrated-verdict.json (NEEDS_WORK)
#   attempt-1/round-2/  the same, plus the PASS contract
#
# Reviewer A's round-2 manifest carries round-1's integrated-summary.json --
# the Issue #143 exception stated in impl-reviewer-a.md. Reviewer B's carries
# round-2's, per the ordinary A -> summary -> B bridge.
write_impl_contract_round2() {
  local round1_dir="${IMPL_REPORT_DIR}/attempt-1/round-1"
  local round2_dir="${IMPL_REPORT_DIR}/attempt-1/round-2"
  local attempt_root="reports/impl-review/${FEATURE}/attempt-1"
  write_round_evidence "${round1_dir}"
  write_round_evidence "${round2_dir}"
  jq -n --arg feature "${FEATURE}" \
    '{schema:"integrated-verdict/v1",stage:"impl",feature:$feature,attempt:1,round:1,run_id:"impl-contract-run-r1",verdict:"NEEDS_WORK"}' \
    > "${round1_dir}/integrated-verdict.json"
  jq -n --arg feature "${FEATURE}" \
    '{schema:"integrated-verdict/v1",stage:"impl",feature:$feature,attempt:1,round:2,run_id:"impl-contract-run",verdict:"PASS"}' \
    > "${round2_dir}/integrated-verdict.json"
  jq -n \
    --arg feature "${FEATURE}" \
    --arg calibration "${CALIBRATION_PATH}" \
    --arg calibration_hash "$(sha256 "${REPO_ROOT}/${CALIBRATION_PATH}")" \
    --arg requirements_hash "$(sha256 "${SPEC_DIR}/requirements.md")" \
    --arg acceptance_hash "$(sha256 "${SPEC_DIR}/acceptance-tests.md")" \
    --arg design_hash "$(sha256 "${SPEC_DIR}/design.md")" \
    --arg investigation_hash "$(sha256 "${SPEC_DIR}/investigation.md")" \
    --arg precheck_hash "$(sha256 "${round2_dir}/precheck-result.json")" \
    --arg prev_summary_hash "$(sha256 "${round1_dir}/integrated-summary.json")" \
    --arg summary_hash "$(sha256 "${round2_dir}/integrated-summary.json")" \
    --arg attempt_root "${attempt_root}" \
    '[{path:("specs/" + $feature + "/requirements.md"),sha256:$requirements_hash},
      {path:("specs/" + $feature + "/acceptance-tests.md"),sha256:$acceptance_hash},
      {path:("specs/" + $feature + "/design.md"),sha256:$design_hash},
      {path:("specs/" + $feature + "/investigation.md"),sha256:$investigation_hash},
      {path:$calibration,sha256:$calibration_hash},
      {path:($attempt_root + "/round-2/precheck-result.json"),sha256:$precheck_hash}] as $shared |
     {schema:"impl-review-contract/v1",stage:"impl",feature:$feature,attempt:1,round:2,
      run_id:"impl-contract-run",verdict:"PASS",
      reviewers:[
        {role:"impl-reviewer-a",run_id:"impl-a-run",host_session_id:"impl-a-session",
         allowed_input_manifest:($shared + [{path:($attempt_root + "/round-1/integrated-summary.json"),sha256:$prev_summary_hash}])},
        {role:"impl-reviewer-b",run_id:"impl-b-run",host_session_id:"impl-b-session",
         allowed_input_manifest:($shared + [{path:($attempt_root + "/round-2/integrated-summary.json"),sha256:$summary_hash}])}
      ]}' > "${round2_dir}/impl-review-contract.json"
}

IMPL_CONTRACT="${IMPL_REPORT_DIR}/attempt-1/round-2/impl-review-contract.json"

edit_impl_contract() {
  jq "$1" "${IMPL_CONTRACT}" > "${IMPL_CONTRACT}.tmp"
  mv "${IMPL_CONTRACT}.tmp" "${IMPL_CONTRACT}"
}

build_fixture() {
  rm -rf "${SPEC_REPORT_DIR}" "${IMPL_REPORT_DIR}" "${REPORT_DIR}"
  write_spec_contract
  write_impl_contract_round2
}

run_precheck() {
  (cd "${REPO_ROOT}" && bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "${FEATURE}" 1 1)
}

expect_denied() {
  local label="$1" expected_message="$2" output=""
  if output="$(run_precheck 2>&1)"; then
    echo "expected task precheck to deny: ${label}" >&2
    exit 1
  fi
  if [[ -n "${expected_message}" && "${output}" != *"${expected_message}"* ]]; then
    echo "expected denial message '${expected_message}' for ${label}; got:" >&2
    echo "${output}" >&2
    exit 1
  fi
  if [[ -e "${REPORT_DIR}/attempt-1/round-1" ]]; then
    echo "denied task precheck must not create round evidence: ${label}" >&2
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# WFI-029 defect 4 -- the positive case that was previously impossible to build.
# -----------------------------------------------------------------------------

build_fixture
run_precheck >/dev/null || {
  echo "task precheck must accept a round-2 impl contract whose reviewer-a manifest binds the previous round's integrated-summary.json" >&2
  exit 1
}
# Exit 0 alone would also be produced by a precheck that never reached the
# predecessor-contract check. Require the evidence it only writes on the far
# side of that check.
[[ -f "${REPORT_DIR}/attempt-1/round-1/dependency-graph.json" ]] || {
  echo "accepted round-2 contract did not carry the precheck through to dependency-graph.json" >&2
  exit 1
}
echo "ok: task review precheck accepts a round-2 impl contract built as the role file instructs"

# Non-vacuity: drop reviewer A's previous-round summary and the specific
# denial must come back. Without this the assertion above could pass for
# reasons unrelated to the binding under test.
build_fixture
edit_impl_contract '(.reviewers[] | select(.role == "impl-reviewer-a") | .allowed_input_manifest) |= map(select(.path | endswith("/round-1/integrated-summary.json") | not))'
expect_denied "reviewer-a manifest without the previous-round summary" \
  "persisted impl reviewer-a manifest is missing previous-round summary"
echo "ok: task review precheck still denies a round-2 contract missing reviewer-a's previous-round summary"

# The A/B question WFI-029 item 7 posed, settled in the artifact rather than in
# prose: reviewer B carrying the previous round's summary is NOT a substitute.
# The contract allowlist admits round-N-1's summary for reviewer A only.
build_fixture
edit_impl_contract '
  [.reviewers[] | select(.role == "impl-reviewer-a") | .allowed_input_manifest[] | select(.path | endswith("/round-1/integrated-summary.json"))] as $moved
  | (.reviewers[] | select(.role == "impl-reviewer-a") | .allowed_input_manifest) |= map(select(.path | endswith("/round-1/integrated-summary.json") | not))
  | (.reviewers[] | select(.role == "impl-reviewer-b") | .allowed_input_manifest) += $moved'
expect_denied "previous-round summary moved to reviewer-b" ""
echo "ok: task review precheck denies the previous-round summary bound to reviewer-b instead of reviewer-a"

# -----------------------------------------------------------------------------
# WFI-029 defect 1 -- investigation.md must be bound by BOTH reviewers whenever
# the file exists. The impl-review-loop SKILL.md never named it; the gate has
# always required it.
# -----------------------------------------------------------------------------

for role in impl-reviewer-a impl-reviewer-b; do
  build_fixture
  edit_impl_contract "(.reviewers[] | select(.role == \"${role}\") | .allowed_input_manifest) |= map(select(.path | endswith(\"/investigation.md\") | not))"
  expect_denied "${role} manifest without investigation.md" \
    "persisted impl contract reviewer manifest is missing investigation evidence"
done
echo "ok: task review precheck denies an impl contract whose reviewer manifests omit investigation.md"

rm -rf "${REPORT_DIR}"
