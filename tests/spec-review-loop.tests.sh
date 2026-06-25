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

write_contract() {
  local directory="$1" verdict="$2" severity="$3"
  local requirements_sha acceptance_sha precheck_sha summary_sha round a_verdict a_result a_fails a_passes critical major minor warning
  round="$(jq -r .round "${directory}/precheck-result.json")"
  case "${severity}" in
    none) a_verdict="PASS"; a_result="PASS"; a_fails=0; a_passes=1; critical=0; major=0; minor=0 ;;
    Critical) a_verdict="BLOCKED"; a_result="FAIL"; a_fails=1; a_passes=0; critical=1; major=0; minor=0 ;;
    Major) a_verdict="NEEDS_WORK"; a_result="FAIL"; a_fails=1; a_passes=0; critical=0; major=1; minor=0 ;;
    Minor) a_verdict="NEEDS_WORK"; a_result="FAIL"; a_fails=1; a_passes=0; critical=0; major=0; minor=1 ;;
    *) fail "unknown fixture severity: ${severity}" ;;
  esac
  warning=0
  [[ "${round}" == 3 && "${severity}" == Minor ]] && warning=1
  jq -n --argjson attempt 1 --argjson round "${round}" --arg result "${a_result}" --arg severity "${severity}" \
    --argjson fail_count "${a_fails}" --argjson pass_count "${a_passes}" \
    '{schema:"integrated-summary/v1",attempt:$attempt,round:$round,reviewer_a_checks:[{id:"REQ-TESTABILITY",result:$result,severity:$severity}],reviewer_a_fail_count:$fail_count,reviewer_a_pass_count:$pass_count,reviewer_a_skip_count:0,generated_at:"2026-06-23T00:00:00Z"}' \
    > "${directory}/integrated-summary.json"
  local requirements_sha acceptance_sha precheck_sha summary_sha
  requirements_sha="$(jq -r .requirements_sha256 "${directory}/precheck-result.json")"
  acceptance_sha="$(jq -r .acceptance_sha256 "${directory}/precheck-result.json")"
  precheck_sha="$(sha256sum "${directory}/precheck-result.json" | awk '{print $1}')"
  summary_sha="$(sha256sum "${directory}/integrated-summary.json" | awk '{print $1}')"
  jq -n --arg feature "${FEATURE}" --arg result "${a_result}" --arg severity "${severity}" --arg verdict "${a_verdict}" \
    --arg requirements "${SPEC_DIR}/requirements.md" --arg acceptance "${SPEC_DIR}/acceptance-tests.md" --arg precheck "${directory}/precheck-result.json" \
    --arg requirements_sha "${requirements_sha}" --arg acceptance_sha "${acceptance_sha}" --arg precheck_sha "${precheck_sha}" \
    '{schema:"spec-reviewer-a/v1",stage:"spec",role:"spec-reviewer-a",run_id:"fixture-a",host_session_id:"session-a",allowed_input_manifest:[{path:$requirements,sha256:$requirements_sha},{path:$acceptance,sha256:$acceptance_sha},{path:$precheck,sha256:$precheck_sha}],verdict:$verdict,checks:[{id:"REQ-TESTABILITY",result:$result,severity:$severity,finding:"fixture finding"}]}' \
    > "${directory}/reviewer-a.json"
  jq -n --arg requirements "${SPEC_DIR}/requirements.md" --arg acceptance "${SPEC_DIR}/acceptance-tests.md" --arg precheck "${directory}/precheck-result.json" --arg summary "${directory}/integrated-summary.json" \
    --arg requirements_sha "${requirements_sha}" --arg acceptance_sha "${acceptance_sha}" --arg precheck_sha "${precheck_sha}" --arg summary_sha "${summary_sha}" \
    '{schema:"spec-reviewer-b/v1",stage:"spec",role:"spec-reviewer-b",run_id:"fixture-b",host_session_id:"session-b",allowed_input_manifest:[{path:$requirements,sha256:$requirements_sha},{path:$acceptance,sha256:$acceptance_sha},{path:$precheck,sha256:$precheck_sha},{path:$summary,sha256:$summary_sha}],verdict:"PASS",checks:[{id:"AMBIGUITY",result:"PASS",severity:"Minor",finding:"fixture pass"}]}' \
    > "${directory}/reviewer-b.json"
  jq -n --arg feature "${FEATURE}" --arg verdict "${verdict}" --argjson round "${round}" --argjson warning "${warning}" --argjson critical "${critical}" --argjson major "${major}" --argjson minor "${minor}" \
    '{schema:"spec-review-integrated-verdict/v1",stage:"spec",feature:$feature,attempt:1,round:$round,reviewer_a_run_id:"fixture-a",reviewer_b_run_id:"fixture-b",reviewer_a_host_session_id:"session-a",reviewer_b_host_session_id:"session-b",finding_counts:{critical:$critical,major:$major,minor:$minor},verdict:$verdict,warningCount:$warning}' \
    > "${directory}/integrated-verdict.json"
  jq -n --arg feature "${FEATURE}" --arg verdict "${verdict}" \
    --arg requirements_sha256 "${requirements_sha}" --arg acceptance_sha256 "${acceptance_sha}" \
    --argjson round "${round}" --argjson warning "${warning}" \
    --arg requirements "${SPEC_DIR}/requirements.md" --arg acceptance "${SPEC_DIR}/acceptance-tests.md" --arg precheck "${directory}/precheck-result.json" --arg summary "${directory}/integrated-summary.json" \
    --arg precheck_sha "${precheck_sha}" --arg summary_sha "${summary_sha}" \
    '{schema:"spec-review-contract/v1",stage:"spec",feature:$feature,attempt:1,round:$round,requirements_sha256:$requirements_sha256,acceptance_sha256:$acceptance_sha256,reviewers:[
      {role:"spec-reviewer-a",run_id:"fixture-a",host_session_id:"session-a",allowed_input_manifest:[
        {path:$requirements,sha256:$requirements_sha256},{path:$acceptance,sha256:$acceptance_sha256},{path:$precheck,sha256:$precheck_sha}
      ]},
      {role:"spec-reviewer-b",run_id:"fixture-b",host_session_id:"session-b",allowed_input_manifest:[
        {path:$requirements,sha256:$requirements_sha256},{path:$acceptance,sha256:$acceptance_sha256},{path:$precheck,sha256:$precheck_sha},{path:$summary,sha256:$summary_sha}
      ]}
    ],run_id:"fixture-orchestrator",verdict:$verdict,warningCount:$warning}' \
    > "${directory}/spec-review-contract.json"
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
expect_failure "${PRECHECK}" "../escape" 1 1
expect_failure "${PRECHECK}" "${FEATURE^^}" 0 1
[[ "${before_hash}" == "$(sha256sum "${ROUND_ONE}/precheck-result.json" | awk '{print $1}')" ]] || fail "replay overwrote evidence"

# A NEEDS_WORK result authorizes exactly one edited next round; stale input is rejected.
write_contract "${ROUND_ONE}" NEEDS_WORK Major
expect_failure "${PRECHECK}" "${FEATURE}" 1 2 --edit-summary="fixed wording"
printf '\n- Human correction recorded.\n' >> "${SPEC_DIR}/requirements.md"
tmp_contract="${ROUND_ONE}/spec-review-contract.tmp"
jq '.reviewers[0].allowed_input_manifest += [{"path":"../reports/impl-review/x/reviewer-a.json","sha256":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"}]' \
  "${ROUND_ONE}/spec-review-contract.json" > "${tmp_contract}"
mv "${tmp_contract}" "${ROUND_ONE}/spec-review-contract.json"
expect_failure "${PRECHECK}" "${FEATURE}" 1 2 --edit-summary="fixed wording"
write_contract "${ROUND_ONE}" NEEDS_WORK Major
"${PRECHECK}" "${FEATURE}" 1 2 --edit-summary="fixed wording"

# Round-three Minor-only PASS is represented by a PASS contract with warnings.
ROUND_TWO="${REPORT_ROOT}/attempt-1/round-2"
write_contract "${ROUND_TWO}" NEEDS_WORK Major
printf '\n- Another human correction.\n' >> "${SPEC_DIR}/requirements.md"
"${PRECHECK}" "${FEATURE}" 1 3 --edit-summary="addressed major findings"

# Round-three Minor-only PASS keeps the warning count while Major/Critical BLOCK.
ROUND_THREE="${REPORT_ROOT}/attempt-1/round-3"
write_contract "${ROUND_THREE}" PASS Minor
jq -e '.verdict == "PASS" and .warningCount == 1' "${ROUND_THREE}/spec-review-contract.json" >/dev/null || fail "round-three Minor finding must pass with a warning"
tmp_verdict="${ROUND_THREE}/integrated-verdict.tmp"
jq '.finding_counts.major = 1 | .verdict = "BLOCKED"' "${ROUND_THREE}/integrated-verdict.json" > "${tmp_verdict}"
mv "${tmp_verdict}" "${ROUND_THREE}/integrated-verdict.json"
expect_failure "${PRECHECK}" "${FEATURE}" 2 1 --reset
write_contract "${ROUND_THREE}" PASS Minor
tmp_reviewer="${ROUND_THREE}/reviewer-a.tmp"
jq '.allowed_input_manifest += [{"path":"../reports/task-review/x/reviewer-a.json","sha256":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"}]' "${ROUND_THREE}/reviewer-a.json" > "${tmp_reviewer}"
mv "${tmp_reviewer}" "${ROUND_THREE}/reviewer-a.json"
expect_failure "${PRECHECK}" "${FEATURE}" 2 1 --reset
write_contract "${ROUND_THREE}" BLOCKED Critical
"${PRECHECK}" "${FEATURE}" 2 1 --reset
rm -rf "${REPORT_ROOT}/attempt-2"
write_contract "${ROUND_THREE}" BLOCKED Major
"${PRECHECK}" "${FEATURE}" 2 1 --reset
rm -rf "${REPORT_ROOT}/attempt-2"
write_contract "${ROUND_THREE}" PASS Minor

# Reset starts only from a validated terminal contract; symlinked/pre-existing destinations are denied.
sed -i.bak 's/^Spec-Review-Status: Pending$/Spec-Review-Status: Passed/' "${SPEC_DIR}/requirements.md"
rm -f "${SPEC_DIR}/requirements.md.bak"
"${PRECHECK}" "${FEATURE}" 2 1 --reset
expect_failure "${PRECHECK}" "${FEATURE}" 2 1 --reset
cleanup
mkdir -p "${SPEC_DIR}" "${ROOT}/reports/spec-review"
printf 'Spec-Review-Status: Pending\n' > "${SPEC_DIR}/requirements.md"
printf '# Acceptance\n' > "${SPEC_DIR}/acceptance-tests.md"
ln -s "${ROOT}/reports/spec-review" "${REPORT_ROOT}"
expect_failure "${PRECHECK}" "${FEATURE}" 1 1
cleanup
mkdir -p "${SPEC_DIR}"
printf 'Spec-Review-Status: Passed\n' > "${SPEC_DIR}/requirements.md"
printf '# Acceptance\n' > "${SPEC_DIR}/acceptance-tests.md"
expect_failure "${PRECHECK}" "${FEATURE}" 1 1
mkdir -p "${REPORT_ROOT}/attempt-1/round-1"
expect_failure "${PRECHECK}" "${FEATURE}" 2 1 --reset
rm "${SPEC_DIR}/requirements.md"
ln -s "${ROOT}/README.md" "${SPEC_DIR}/requirements.md"
expect_failure "${PRECHECK}" "${FEATURE}" 1 1

# Reviewer definitions are distinct, read-only, and deny raw cross-role input.
agent_a="${ROOT}/plugins/sdd-review-loop/agents/spec-reviewer-a.md"
agent_b="${ROOT}/plugins/sdd-review-loop/agents/spec-reviewer-b.md"
agent_names="$(sed -n 's/^name: //p' "${ROOT}"/plugins/sdd-review-loop/agents/*-reviewer-*.md | sort -u | wc -l | tr -d ' ')"
[[ "${agent_names}" == 6 ]] || fail "expected six distinct review roles"
rg -q '^name: spec-reviewer-a$' "${agent_a}" || fail "missing reviewer A identity"
rg -q '^name: spec-reviewer-b$' "${agent_b}" || fail "missing reviewer B identity"
rg -q '^tools: Read, Grep, Glob$' "${agent_a}" || fail "reviewer A is not read-only"
rg -q '^tools: Read, Grep, Glob$' "${agent_b}" || fail "reviewer B is not read-only"
rg -q 'host-session identifier' "${agent_a}" || fail "reviewer A lacks session contract"
rg -q 'allowed-input manifest' "${agent_b}" || fail "reviewer B lacks input manifest contract"
rg -q 'allowed_input_manifest' "${agent_a}" || fail "reviewer A does not persist its input manifest"
rg -q 'allowed_input_manifest' "${agent_b}" || fail "reviewer B does not persist its input manifest"
rg -q 'reviewer-a.json' "${agent_b}" || fail "reviewer B lacks raw-report denial"

echo "ok: spec review precheck enforces state, hashes, replay, reset, and safe paths"
