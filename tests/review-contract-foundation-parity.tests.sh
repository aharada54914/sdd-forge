#!/usr/bin/env bash
# T-002: verify the two runtime entry points emit the same canonical JSON.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASH_VALIDATOR="${REPO_ROOT}/plugins/sdd-review-loop/scripts/review-contract-validate.sh"
PS_VALIDATOR="${REPO_ROOT}/plugins/sdd-review-loop/scripts/review-contract-validate.ps1"
FIXTURE="${REPO_ROOT}/tests/fixtures/review-contract/utf8-contract.json"
REPORT_PARENT="${REPO_ROOT}/reports/spec-review"
REPORT_ROOT="${REPORT_PARENT}/utf8-feature"

if ! command -v pwsh >/dev/null 2>&1; then
  echo 'skip: PowerShell is not available on this host'
  exit 0
fi

mkdir -p "${REPORT_PARENT}"
trap 'rmdir "${REPORT_PARENT}" 2>/dev/null || true' EXIT

bash_output="$("${BASH_VALIDATOR}" --feature utf8-feature --attempt 1 --round 2 --stage spec --report-root "${REPORT_ROOT}" --contract "${FIXTURE}" | jq -cS .)"
ps_output="$(pwsh -NoProfile -File "${PS_VALIDATOR}" -Feature utf8-feature -Attempt 1 -Round 2 -Stage spec -ReportRoot "${REPORT_ROOT}" -Contract "${FIXTURE}" | jq -cS .)"

if [[ "${bash_output}" != "${ps_output}" ]]; then
  echo "runtime output mismatch: bash=${bash_output} ps=${ps_output}" >&2
  exit 1
fi

echo 'ok: review contract validators have equivalent semantic JSON output'
