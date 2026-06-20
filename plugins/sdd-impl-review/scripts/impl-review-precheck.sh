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

# ──────────────────────────────────────────────────────────────────────────────
# STEP 1: Check design.md exists and has Impl-Review-Status: Pending
# ──────────────────────────────────────────────────────────────────────────────

if [[ ! -f "${DESIGN_MD}" ]]; then
  echo "ERROR: impl-review-precheck: ${DESIGN_MD} not found." >&2
  exit 1
fi

if [[ ! -f "${REQS_MD}" ]]; then
  echo "ERROR: impl-review-precheck: ${REQS_MD} not found." >&2
  exit 1
fi

# Check for Impl-Review-Status field
impl_review_status=$(grep -oP '^Impl-Review-Status:\s*\K.*' "${DESIGN_MD}" 2>/dev/null | head -1 | tr -d '[:space:]' || echo "")

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

design_sha256=$(sha256sum "${DESIGN_MD}" | awk '{print $1}')
requirements_sha256=$(sha256sum "${REQS_MD}" | awk '{print $1}')

acceptance_sha256=""
if [[ -f "${ACCEPT_MD}" ]]; then
  acceptance_sha256=$(sha256sum "${ACCEPT_MD}" | awk '{print $1}')
fi

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
# STEP 5: Create output directory and write precheck-result.json
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
