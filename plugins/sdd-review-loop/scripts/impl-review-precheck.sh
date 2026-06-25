#!/usr/bin/env bash
# impl-review-precheck.sh
# Usage: impl-review-precheck.sh <feature-slug> <attempt> <round>
#
# Generates precheck-result.json for the impl-review-loop.
# Outputs to: reports/impl-review/<feature>/attempt-<M>/round-<N>/
#
# Exit codes:
#   0  — precheck passed (downstream reviewers may run)
#   1  — precheck failed (halt review loop; display error)

set -euo pipefail

FEATURE="${1:?Usage: impl-review-precheck.sh <feature-slug> <attempt> <round>}"
ATTEMPT="${2:?Usage: impl-review-precheck.sh <feature-slug> <attempt> <round>}"
ROUND="${3:?Usage: impl-review-precheck.sh <feature-slug> <attempt> <round>}"

SPECS_DIR="specs/${FEATURE}"
REPORT_DIR="reports/impl-review/${FEATURE}/attempt-${ATTEMPT}/round-${ROUND}"
DESIGN_MD="${SPECS_DIR}/design.md"
REQS_MD="${SPECS_DIR}/requirements.md"
ACCEPT_MD="${SPECS_DIR}/acceptance-tests.md"
SPEC_REPORT_ROOT="reports/spec-review/${FEATURE}"
IMPL_REPORT_ROOT="reports/impl-review/${FEATURE}"
repo_root="$(cd "$(dirname "$0")/../../.." && pwd -P)"

fail() { echo "ERROR: impl-review-precheck: $*" >&2; exit 1; }
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}
require_persisted_pass() {
  local root="$1" stage="$2" requirements_hash="$3" acceptance_hash="$4" design_hash="$5" verdict contract contract_dir
  [[ -d "$root" && ! -L "$root" ]] || fail "missing ${stage} predecessor report root"
  verdict="$(find "$root" -type f -name integrated-verdict.json ! -lname '*' -print | sort | tail -n 1)"
  [[ -n "$verdict" ]] || fail "missing persisted ${stage} PASS verdict"
  contract_dir="$(dirname "$verdict")"
  contract="${contract_dir}/${stage}-review-contract.json"
  [[ -f "$contract" && ! -L "$contract" ]] || fail "missing persisted ${stage} review contract"
  jq -e --arg feature "$FEATURE" --arg stage "$stage" '
    .feature == $feature and .stage == $stage and (.attempt | type == "number" and . > 0) and (.round | type == "number" and . > 0) and .verdict == "PASS" and
    (if $stage == "spec" then .schema == "spec-review-integrated-verdict/v1" and
      ([.reviewer_a_run_id, .reviewer_b_run_id, .reviewer_a_host_session_id, .reviewer_b_host_session_id] | all(type == "string" and length > 0)) and
      .reviewer_a_run_id != .reviewer_b_run_id and .reviewer_a_host_session_id != .reviewer_b_host_session_id
     else .schema == "integrated-verdict/v1" and (.run_id | type == "string" and length > 0) end)' "$verdict" >/dev/null ||
    fail "persisted ${stage} verdict is not a complete PASS contract"
  jq -e --arg feature "$FEATURE" --arg stage "$stage" --arg req "$requirements_hash" --arg accept "$acceptance_hash" --arg design "$design_hash" '
    .schema == ($stage + "-review-contract/v1") and .feature == $feature and .stage == $stage and
    (.attempt | type == "number" and . > 0) and (.round | type == "number" and . > 0) and
    (.run_id | type == "string" and length > 0) and .verdict == "PASS" and
    ([.reviewers[]? | .role] | sort) == [($stage + "-reviewer-a"), ($stage + "-reviewer-b")] and
    ([.reviewers[]? | .host_session_id] | (all(type == "string" and length > 0) and (unique | length == 2))) and
    ([.reviewers[]? | .run_id] | (all(type == "string" and length > 0) and (unique | length == 2))) and
    ([.reviewers[]?.allowed_input_manifest[]? | (.path | type == "string" and startswith("specs/" + $feature + "/") and contains("reviewer-") | not) and (.sha256 | type == "string" and test("^[0-9a-f]{64}$"))] | all) and
    (any(.reviewers[]?.allowed_input_manifest[]?; .path == ("specs/" + $feature + "/requirements.md") and .sha256 == $req)) and
    (any(.reviewers[]?.allowed_input_manifest[]?; .path == ("specs/" + $feature + "/acceptance-tests.md") and .sha256 == $accept)) and
    ($stage != "impl" or any(.reviewers[]?.allowed_input_manifest[]?; .path == ("specs/" + $feature + "/design.md") and .sha256 == $design))
  ' "$contract" >/dev/null || fail "persisted ${stage} contract does not match canonical current inputs"
  jq -e --slurpfile verdict "$verdict" --arg stage "$stage" '
    . as $contract | $verdict[0] as $verdict |
    $contract.attempt == $verdict.attempt and
    $contract.round == $verdict.round and
    $contract.verdict == $verdict.verdict and
    (if $stage == "spec" then
       ($contract.reviewers | map({key: .role, value: {run_id: .run_id, host_session_id: .host_session_id}}) | from_entries) as $reviewers |
       $reviewers["spec-reviewer-a"].run_id == $verdict.reviewer_a_run_id and
       $reviewers["spec-reviewer-b"].run_id == $verdict.reviewer_b_run_id and
       $reviewers["spec-reviewer-a"].host_session_id == $verdict.reviewer_a_host_session_id and
       $reviewers["spec-reviewer-b"].host_session_id == $verdict.reviewer_b_host_session_id
     else $contract.run_id == $verdict.run_id end)
  ' "$contract" >/dev/null || fail "persisted ${stage} verdict and contract contradict each other"
}

[[ "$FEATURE" =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "invalid feature slug"
[[ "$ATTEMPT" =~ ^[1-9][0-9]*$ ]] || fail "attempt must be a positive integer"
[[ "$ROUND" =~ ^[1-9][0-9]*$ ]] || fail "round must be a positive integer"
[[ ! -e "$REPORT_DIR" && ! -L "$REPORT_DIR" ]] || fail "round destination already exists (replay is forbidden)"
[[ -d "$SPECS_DIR" && ! -L "$SPECS_DIR" ]] || fail "feature specification directory must be a real directory"
[[ "$(cd "$SPECS_DIR" && pwd -P)" == "$repo_root/specs/$FEATURE" ]] || fail "feature specification directory escapes repository"

# ──────────────────────────────────────────────────────────────────────────────
# STEP 1: Check design.md exists and has Impl-Review-Status: Pending
# ──────────────────────────────────────────────────────────────────────────────

if [[ ! -f "${DESIGN_MD}" || -L "${DESIGN_MD}" ]]; then
  echo "ERROR: impl-review-precheck: ${DESIGN_MD} not found." >&2
  exit 1
fi

if [[ ! -f "${REQS_MD}" || -L "${REQS_MD}" ]]; then
  echo "ERROR: impl-review-precheck: ${REQS_MD} not found." >&2
  exit 1
fi

spec_review_status=$(sed -n 's/^Spec-Review-Status:[[:space:]]*//p' "${REQS_MD}" | head -n 1 | tr -d '[:space:]')
[[ "$spec_review_status" == "Passed" ]] || fail "requirements.md must declare Spec-Review-Status: Passed"

# Check for Impl-Review-Status field
impl_review_status=$(sed -n 's/^Impl-Review-Status:[[:space:]]*//p' "${DESIGN_MD}" | head -n 1 | tr -d '[:space:]')

if [[ -z "${impl_review_status}" ]]; then
  echo "ERROR: impl-review-precheck: design.md is missing 'Impl-Review-Status:' header field." \
    "Add 'Impl-Review-Status: Pending' to design.md before invoking impl-review-loop." >&2
  exit 1
fi

if [[ "${impl_review_status}" != "Pending" ]] && [[ "${impl_review_status}" != "pending" ]]; then
  echo "ERROR: impl-review-precheck: Impl-Review-Status is '${impl_review_status}', expected 'Pending'." \
    "Use --reset to start a new attempt if a previous review has passed." >&2
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# STEP 2: Detect legacy_design
# Criteria: design.md predates new template if it lacks required template fields
# ──────────────────────────────────────────────────────────────────────────────

legacy_design=false
required_fields=(
  "## Components"
  "Feature Type:"
  "Data Entities:"
  "Existing Data Affected:"
  "## Security Boundaries"
)

missing_count=0
for field in "${required_fields[@]}"; do
  if ! grep -qF "${field}" "${DESIGN_MD}" 2>/dev/null; then
    missing_count=$((missing_count + 1))
  fi
done

# If 3 or more required template fields are missing, treat as legacy design
if [[ "${missing_count}" -ge 3 ]]; then
  legacy_design=true
fi

# ──────────────────────────────────────────────────────────────────────────────
# STEP 3: Compute sha256 for each input file
# ──────────────────────────────────────────────────────────────────────────────

design_sha256=$(sha256 "${DESIGN_MD}")
requirements_sha256=$(sha256 "${REQS_MD}")

acceptance_sha256=""
[[ -f "${ACCEPT_MD}" && ! -L "${ACCEPT_MD}" ]] || fail "${ACCEPT_MD} not found"
acceptance_sha256=$(sha256 "${ACCEPT_MD}")
require_persisted_pass "$SPEC_REPORT_ROOT" spec "$requirements_sha256" "$acceptance_sha256" ""

# ──────────────────────────────────────────────────────────────────────────────
# STEP 4: Round > 1 — verify design.md changed; check DESIGN-REQ-DRIFT
# ──────────────────────────────────────────────────────────────────────────────

design_req_drift=false

if [[ "${ROUND}" -gt 1 ]]; then
  prior_round=$((ROUND - 1))
  prior_contract="reports/impl-review/${FEATURE}/attempt-${ATTEMPT}/round-${prior_round}/impl-review-contract.json"

  if [[ -f "${prior_contract}" ]]; then
    prior_design_sha256=$(python3 -c "import json,sys; d=json.load(open('${prior_contract}')); print(d.get('design_sha256',''))" 2>/dev/null || echo "")

    if [[ "${design_sha256}" == "${prior_design_sha256}" ]]; then
      echo "ERROR: impl-review-precheck: design.md sha256 is unchanged from round ${prior_round}." \
        "Edit design.md before re-invoking, then provide --edit-summary." >&2
      exit 1
    fi

    # DESIGN-REQ-DRIFT: compare requirements_sha256 against round-1 stored value
    round1_contract="reports/impl-review/${FEATURE}/attempt-${ATTEMPT}/round-1/impl-review-contract.json"
    if [[ -f "${round1_contract}" ]]; then
      round1_req_sha256=$(python3 -c "import json,sys; d=json.load(open('${round1_contract}')); print(d.get('requirements_sha256',''))" 2>/dev/null || echo "")

      if [[ -n "${round1_req_sha256}" ]] && [[ "${requirements_sha256}" != "${round1_req_sha256}" ]]; then
        design_req_drift=true
        echo "WARNING: impl-review-precheck: requirements.md has changed since round 1 of this attempt." \
          "DESIGN-REQ-DRIFT detected. Reviewers will note this condition." >&2
      fi
    fi
  fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# STEP 5: Validate the shared portable contract before creating output evidence.
# ──────────────────────────────────────────────────────────────────────────────

input_sha256="$(printf '%s:%s:%s' "$design_sha256" "$requirements_sha256" "$acceptance_sha256" | if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'; else shasum -a 256 | awk '{print $1}'; fi)"
foundation_contract="$(mktemp)"
trap 'rm -f "$foundation_contract"' EXIT
jq -n --arg feature "$FEATURE" --argjson attempt "$ATTEMPT" --argjson round "$ROUND" --arg input_sha256 "$input_sha256" \
  '{schema:"review-contract/v1",stage:"impl",feature:$feature,attempt:$attempt,round:$round,input_sha256:$input_sha256,run_id:"impl-precheck",verdict:"PASS"}' > "$foundation_contract"
mkdir -p "reports/impl-review"
"${repo_root}/plugins/sdd-review-loop/scripts/review-contract-validate.sh" --feature "$FEATURE" --attempt "$ATTEMPT" --round "$ROUND" --stage impl --report-root "$IMPL_REPORT_ROOT" --contract "$foundation_contract" >/dev/null

# ──────────────────────────────────────────────────────────────────────────────
# STEP 6: Create output directory and write precheck-result.json
# ──────────────────────────────────────────────────────────────────────────────

mkdir -p "${REPORT_DIR}"

generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "${REPORT_DIR}/precheck-result.json" <<EOF
{
  "schema": "impl-review-precheck/v1",
  "feature": "${FEATURE}",
  "attempt": ${ATTEMPT},
  "round": ${ROUND},
  "impl_review_status_field": "${impl_review_status}",
  "legacy_design": ${legacy_design},
  "design_req_drift": ${design_req_drift},
  "design_sha256": "${design_sha256}",
  "requirements_sha256": "${requirements_sha256}",
  "acceptance_sha256": "${acceptance_sha256}",
  "generated_at": "${generated_at}"
}
EOF

echo "impl-review-precheck: complete. Output written to ${REPORT_DIR}/"

exit 0
