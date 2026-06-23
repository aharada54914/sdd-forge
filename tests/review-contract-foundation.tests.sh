#!/usr/bin/env bash
# T-002 red/green coverage for the portable review-contract foundation.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="${REPO_ROOT}/plugins/sdd-review-loop/scripts/review-contract-validate.sh"
FIXTURE="${REPO_ROOT}/tests/fixtures/review-contract/utf8-contract.json"
REPORT_ROOT="${REPO_ROOT}/reports/spec-review/utf8-feature"
TEMP_CONTRACT="$(mktemp)"
REPORT_FILE="${REPORT_ROOT%/*}/existing-file"

mkdir -p "${REPORT_ROOT%/*}"
trap 'rm -f "${TEMP_CONTRACT}" "${REPORT_FILE}"; rmdir "${REPORT_ROOT%/*}" 2>/dev/null || true' EXIT

expect_failure() {
  if "$@" >/dev/null 2>&1; then
    echo "expected failure: $*" >&2
    exit 1
  fi
}

output="$("${VALIDATOR}" --feature utf8-feature --attempt 1 --round 2 --stage spec --report-root "${REPORT_ROOT}" --contract "${FIXTURE}")"
expected='{"schema":"review-contract-validation/v1","feature":"utf8-feature","attempt":1,"round":2,"stage":"spec","verdict":"PASS"}'
if [[ "$(printf '%s' "${output}" | jq -c '{schema,feature,attempt,round,stage,verdict}')" != "${expected}" ]]; then
  echo "unexpected canonical output: ${output}" >&2
  exit 1
fi

expect_failure "${VALIDATOR}" --feature '../escape' --attempt 1 --round 2 --stage spec --report-root "${REPORT_ROOT}" --contract "${FIXTURE}"
expect_failure "${VALIDATOR}" --feature utf8-feature --attempt 0 --round 2 --stage spec --report-root "${REPORT_ROOT}" --contract "${FIXTURE}"
expect_failure "${VALIDATOR}" --feature utf8-feature --attempt +1 --round 2 --stage spec --report-root "${REPORT_ROOT}" --contract "${FIXTURE}"
expect_failure "${VALIDATOR}" --feature utf8-feature --attempt 1.5 --round 2 --stage spec --report-root "${REPORT_ROOT}" --contract "${FIXTURE}"
expect_failure "${VALIDATOR}" --feature utf8-feature --attempt 1 --round 0 --stage spec --report-root "${REPORT_ROOT}" --contract "${FIXTURE}"
expect_failure "${VALIDATOR}" --feature utf8-feature --attempt 1 --round 2 --stage spec --report-root "${REPO_ROOT}/../unsafe" --contract "${FIXTURE}"
jq '.feature = "different-feature"' "${FIXTURE}" > "${TEMP_CONTRACT}"
expect_failure "${VALIDATOR}" --feature utf8-feature --attempt 1 --round 2 --stage spec --report-root "${REPORT_ROOT}" --contract "${TEMP_CONTRACT}"
jq '.input_sha256 = "not-a-sha256"' "${FIXTURE}" > "${TEMP_CONTRACT}"
expect_failure "${VALIDATOR}" --feature utf8-feature --attempt 1 --round 2 --stage spec --report-root "${REPORT_ROOT}" --contract "${TEMP_CONTRACT}"
jq '.run_id = ["not", "a-string"]' "${FIXTURE}" > "${TEMP_CONTRACT}"
expect_failure "${VALIDATOR}" --feature utf8-feature --attempt 1 --round 2 --stage spec --report-root "${REPORT_ROOT}" --contract "${TEMP_CONTRACT}"
jq '.unexpected = true' "${FIXTURE}" > "${TEMP_CONTRACT}"
expect_failure "${VALIDATOR}" --feature utf8-feature --attempt 1 --round 2 --stage spec --report-root "${REPORT_ROOT}" --contract "${TEMP_CONTRACT}"
touch "${REPORT_FILE}"
expect_failure "${VALIDATOR}" --feature utf8-feature --attempt 1 --round 2 --stage spec --report-root "${REPORT_FILE}" --contract "${FIXTURE}"

echo "ok: review contract foundation validates canonical input and rejects unsafe inputs"
