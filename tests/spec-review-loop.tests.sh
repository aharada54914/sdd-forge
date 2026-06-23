#!/usr/bin/env bash
# Integration coverage for the specification-review precheck state boundary.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
PRECHECK="${ROOT}/plugins/sdd-review-loop/scripts/spec-review-precheck.sh"
FEATURE="spec-review-fixture-$RANDOM-$$"
SPEC_DIR="${ROOT}/specs/${FEATURE}"
REPORT_ROOT="${ROOT}/reports/spec-review/${FEATURE}"

cleanup() {
  rm -rf "${SPEC_DIR}" "${REPORT_ROOT}"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

expect_failure() {
  if "$@" >/dev/null 2>&1; then
    fail "expected failure: $*"
  fi
}

mkdir -p "${SPEC_DIR}"
cat > "${SPEC_DIR}/requirements.md" <<'EOF'
# Requirements

Spec-Review-Status: Pending

## Goals

- Demonstrate the spec-review precheck fixture.
EOF
cat > "${SPEC_DIR}/acceptance-tests.md" <<'EOF'
# Acceptance tests

| AC-ID | Requirement | Status |
|---|---|---|
| AC-001 | REQ-001 | Planned |
EOF

# Clean first round writes immutable hashes before any reviewer runs.
"${PRECHECK}" "${FEATURE}" 1 1
ROUND_ONE="${REPORT_ROOT}/attempt-1/round-1"
[[ -f "${ROUND_ONE}/precheck-result.json" ]] || fail "missing precheck artifact"
jq -e '.schema == "spec-review-precheck/v1" and .requirements_sha256 and .acceptance_sha256' \
  "${ROUND_ONE}/precheck-result.json" >/dev/null || fail "missing canonical hashes"

# Replays and skipped/invalid transitions must fail without overwriting evidence.
before_hash="$(sha256sum "${ROUND_ONE}/precheck-result.json" | awk '{print $1}')"
expect_failure "${PRECHECK}" "${FEATURE}" 1 1
expect_failure "${PRECHECK}" "${FEATURE}" 1 2
expect_failure "${PRECHECK}" "${FEATURE}" "${FEATURE}/../escape" 1
expect_failure "${PRECHECK}" "${FEATURE^^}" 0 1
[[ "${before_hash}" == "$(sha256sum "${ROUND_ONE}/precheck-result.json" | awk '{print $1}')" ]] || fail "replay overwrote evidence"

# A NEEDS_WORK result authorizes exactly one edited next round; stale input is rejected.
cat > "${ROUND_ONE}/spec-review-contract.json" <<EOF
{"schema":"spec-review-contract/v1","stage":"spec","feature":"${FEATURE}","attempt":1,"round":1,"requirements_sha256":"$(jq -r .requirements_sha256 "${ROUND_ONE}/precheck-result.json")","acceptance_sha256":"$(jq -r .acceptance_sha256 "${ROUND_ONE}/precheck-result.json")","run_id":"fixture-run-1","verdict":"NEEDS_WORK","warningCount":0}
EOF
expect_failure "${PRECHECK}" "${FEATURE}" 1 2 --edit-summary="fixed wording"
printf '\n- Human correction recorded.\n' >> "${SPEC_DIR}/requirements.md"
"${PRECHECK}" "${FEATURE}" 1 2 --edit-summary="fixed wording"

# Round-three Minor-only PASS is represented by a PASS contract with warnings.
ROUND_TWO="${REPORT_ROOT}/attempt-1/round-2"
cat > "${ROUND_TWO}/spec-review-contract.json" <<EOF
{"schema":"spec-review-contract/v1","stage":"spec","feature":"${FEATURE}","attempt":1,"round":2,"requirements_sha256":"$(jq -r .requirements_sha256 "${ROUND_TWO}/precheck-result.json")","acceptance_sha256":"$(jq -r .acceptance_sha256 "${ROUND_TWO}/precheck-result.json")","run_id":"fixture-run-2","verdict":"NEEDS_WORK","warningCount":0}
EOF
printf '\n- Another human correction.\n' >> "${SPEC_DIR}/requirements.md"
"${PRECHECK}" "${FEATURE}" 1 3 --edit-summary="addressed major findings"

# Reset starts a preserved new attempt and symlinked/pre-existing destinations are denied.
"${PRECHECK}" "${FEATURE}" 2 1 --reset
expect_failure "${PRECHECK}" "${FEATURE}" 2 1 --reset
cleanup
mkdir -p "${SPEC_DIR}" "${ROOT}/reports/spec-review"
printf 'Spec-Review-Status: Pending\n' > "${SPEC_DIR}/requirements.md"
printf '# Acceptance\n' > "${SPEC_DIR}/acceptance-tests.md"
ln -s "${ROOT}/reports/spec-review" "${REPORT_ROOT}"
expect_failure "${PRECHECK}" "${FEATURE}" 1 1

echo "ok: spec review precheck enforces state, hashes, replay, reset, and safe paths"
