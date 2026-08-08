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
jq '.attempt = "1"' "${FIXTURE}" > "${TEMP_CONTRACT}"
expect_failure "${VALIDATOR}" --feature utf8-feature --attempt 1 --round 2 --stage spec --report-root "${REPORT_ROOT}" --contract "${TEMP_CONTRACT}"
jq '.round = "2"' "${FIXTURE}" > "${TEMP_CONTRACT}"
expect_failure "${VALIDATOR}" --feature utf8-feature --attempt 1 --round 2 --stage spec --report-root "${REPORT_ROOT}" --contract "${TEMP_CONTRACT}"
jq '.input_sha256 = "not-a-sha256"' "${FIXTURE}" > "${TEMP_CONTRACT}"
expect_failure "${VALIDATOR}" --feature utf8-feature --attempt 1 --round 2 --stage spec --report-root "${REPORT_ROOT}" --contract "${TEMP_CONTRACT}"
jq '.run_id = ["not", "a-string"]' "${FIXTURE}" > "${TEMP_CONTRACT}"
expect_failure "${VALIDATOR}" --feature utf8-feature --attempt 1 --round 2 --stage spec --report-root "${REPORT_ROOT}" --contract "${TEMP_CONTRACT}"
jq '.run_id = "   "' "${FIXTURE}" > "${TEMP_CONTRACT}"
expect_failure "${VALIDATOR}" --feature utf8-feature --attempt 1 --round 2 --stage spec --report-root "${REPORT_ROOT}" --contract "${TEMP_CONTRACT}"
jq '.unexpected = true' "${FIXTURE}" > "${TEMP_CONTRACT}"
expect_failure "${VALIDATOR}" --feature utf8-feature --attempt 1 --round 2 --stage spec --report-root "${REPORT_ROOT}" --contract "${TEMP_CONTRACT}"
touch "${REPORT_FILE}"
expect_failure "${VALIDATOR}" --feature utf8-feature --attempt 1 --round 2 --stage spec --report-root "${REPORT_FILE}" --contract "${FIXTURE}"

echo "ok: review contract foundation validates canonical input and rejects unsafe inputs"

# ---------------------------------------------------------------------------
# T-004 (#179): CRLF-jq-output coverage for validate-review-context-set.sh's
# record-hash recomputation path (REQ-005, AC-022..024/026). Unrelated to
# the review-contract-validate.sh coverage above; appended to this file per
# acceptance-tests.md AC-022's task-time-decision note, because this suite
# is already registered in both tests/run-all.sh and
# .github/workflows/test.yml (INV-025) -- extending it needs no
# registration edit anywhere, unlike a brand-new suite file (this feature's
# own Global Constraints forbid adding a new entry to either runner array).
#
# Every jq -r consumption site in validate-review-context-set.sh is
# exercised under a portable, PATH-prepended jq shim that appends a
# trailing \r to ONE targeted site's -r output (CRLF_SHIM_QUERY, matched
# against the jq program text), reproducing on any OS the byte-level defect
# jq.exe emits natively on Windows Git Bash (INV-016/INV-017). Sites are
# shimmed ONE AT A TIME -- not with a single blanket "every -r call" shim
# -- because the manifest/ledger reads execute sequentially and an earlier
# corrupted field (stage/role, read at lines 178-179) fails the
# case-statement authorization check before a later site (e.g. the
# ledger-batch record-hash loop at lines 250-258) is ever reached; this was
# confirmed directly while authoring this suite. CRLF_SHIM_QUERY="__ALL__"
# corrupts every -r call at once and is used only for TEST-026's
# non-regression sweep, where the point is exactly that genuine tampering
# fails closed no matter how many sites are simultaneously corrupted.
#
# Set T004_VALIDATOR_UNDER_TEST to point this section at a different copy
# of validate-review-context-set.sh -- used once, before the T-004 fix
# landed, to capture RED evidence against the unfixed script; defaults to
# the real, repository script.

T004_VALIDATOR="${T004_VALIDATOR_UNDER_TEST:-${REPO_ROOT}/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh}"

T004_FIXTURE_ROOT="$(mktemp -d)"
trap 'rm -f "${TEMP_CONTRACT}" "${REPORT_FILE}"; rmdir "${REPORT_ROOT%/*}" 2>/dev/null || true; rm -rf "${T004_FIXTURE_ROOT}"' EXIT

t004_sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'
  fi
}
t004_sha256_text() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else shasum -a 256 | awk '{print $1}'
  fi
}

T004_SHIM_DIR="${T004_FIXTURE_ROOT}/bin"
mkdir -p "${T004_SHIM_DIR}"
T004_REAL_JQ="$(command -v jq)"
cat > "${T004_SHIM_DIR}/jq" <<'JQSHIM'
#!/usr/bin/env bash
# Test-only CRLF-emitting jq shim (T-004 / issue #179). Appends a trailing
# \r to the stdout of the ONE -r invocation whose jq program text exactly
# matches CRLF_SHIM_QUERY (or, when CRLF_SHIM_QUERY="__ALL__", to every -r
# invocation); every other call is proxied to the real jq unmodified.
set -uo pipefail
real_jq="${CRLF_SHIM_REAL_JQ:?CRLF_SHIM_REAL_JQ must name the real jq binary}"
target="${CRLF_SHIM_QUERY:-}"
prog=""
want_r=0
for arg in "$@"; do
  [[ "${arg}" == -r ]] && want_r=1
done
for arg in "$@"; do
  case "${arg}" in
    -*) continue ;;
    *) prog="${arg}"; break ;;
  esac
done
if [[ "${want_r}" -eq 1 && -n "${target}" && ( "${target}" == "__ALL__" || "${prog}" == "${target}" ) ]]; then
  "${real_jq}" "$@" | sed $'s/$/\r/'
  exit "${PIPESTATUS[0]}"
fi
exec "${real_jq}" "$@"
JQSHIM
chmod +x "${T004_SHIM_DIR}/jq"

t004_run_shimmed() {
  # t004_run_shimmed <query> <validator-args...>  (stdout+stderr combined)
  local query="$1"; shift
  CRLF_SHIM_REAL_JQ="${T004_REAL_JQ}" CRLF_SHIM_QUERY="${query}" PATH="${T004_SHIM_DIR}:${PATH}" "${T004_VALIDATOR}" "$@" 2>&1
}
t004_run_clean() {
  # stdout+stderr combined
  "${T004_VALIDATOR}" "$@" 2>&1
}

# This section deliberately runs with `set +e` so every assertion below is
# recorded in one pass (not just the first failure) -- both when capturing
# RED evidence against the unfixed script (multiple genuine failures in one
# run) and for ordinary GREEN regression runs.
set +e
T004_FAIL_COUNT=0

t004_assert_eq() {
  local desc="$1" actual="$2" expected="$3"
  if [[ "${actual}" == "${expected}" ]]; then
    echo "PASS (T-004): ${desc}"
  else
    echo "FAIL (T-004): ${desc}" >&2
    echo "  expected: ${expected}" >&2
    echo "  actual:   ${actual}" >&2
    T004_FAIL_COUNT=$((T004_FAIL_COUNT + 1))
  fi
}
t004_assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if [[ "${haystack}" == *"${needle}"* ]]; then
    echo "PASS (T-004): ${desc}"
  else
    echo "FAIL (T-004): ${desc}" >&2
    echo "  expected to contain: ${needle}" >&2
    echo "  actual: ${haystack}" >&2
    T004_FAIL_COUNT=$((T004_FAIL_COUNT + 1))
  fi
}

# --- Fixture: canonically valid genesis ledger + extending "spec" manifest
T004_SPEC_DIR="${T004_FIXTURE_ROOT}/spec-fixture"
mkdir -p "${T004_SPEC_DIR}/reports/review-context" "${T004_SPEC_DIR}/specs/crlf-fixture"
T004_SPEC_RUN1=RUN-t004-crlf-0001
T004_SPEC_SESSION1=SESS-t004-crlf-0001
T004_SPEC_RECORD1_HASH="$(printf '%s' "1|spec|spec-reviewer-a|${T004_SPEC_RUN1}|${T004_SPEC_SESSION1}|" | t004_sha256_text)"
cat > "${T004_SPEC_DIR}/reports/review-context/identity-ledger.json" <<EOF
{
  "schema": "review-identity-ledger/v1",
  "records": [
    {
      "sequence": 1,
      "stage": "spec",
      "role": "spec-reviewer-a",
      "run_id": "${T004_SPEC_RUN1}",
      "host_session_id": "${T004_SPEC_SESSION1}",
      "previous_record_sha256": "",
      "record_sha256": "${T004_SPEC_RECORD1_HASH}"
    }
  ]
}
EOF
T004_SPEC_LEDGER_HASH="$(t004_sha256_of "${T004_SPEC_DIR}/reports/review-context/identity-ledger.json")"
printf 'T-004 CRLF fixture requirements content\n' > "${T004_SPEC_DIR}/specs/crlf-fixture/requirements.md"
T004_SPEC_REQ_HASH="$(t004_sha256_of "${T004_SPEC_DIR}/specs/crlf-fixture/requirements.md")"
cat > "${T004_SPEC_DIR}/manifest.json" <<EOF
{
  "schema": "review-context-invocation/v2",
  "input_mode": "file-manifest",
  "fallback_mode": "none",
  "read_only": true,
  "stage": "spec",
  "role": "spec-reviewer-a",
  "feature": "crlf-fixture",
  "run_id": "RUN-t004-crlf-0002",
  "host_session_id": "SESS-t004-crlf-0002",
  "sequence": 2,
  "identity_ledger_path": "reports/review-context/identity-ledger.json",
  "identity_ledger_sha256": "${T004_SPEC_LEDGER_HASH}",
  "previous_record_sha256": "${T004_SPEC_RECORD1_HASH}",
  "allowed_input_manifest": [
    {"path": "specs/crlf-fixture/requirements.md", "sha256": "${T004_SPEC_REQ_HASH}"}
  ]
}
EOF

T004_SPEC_BASELINE="$(t004_run_clean "${T004_SPEC_DIR}/manifest.json" "${T004_SPEC_DIR}")"
t004_assert_contains "TEST-022/baseline: no-shim lane is green (spec fixture)" \
  "${T004_SPEC_BASELINE}" "REVIEW_CONTEXT_OK"

# --- Fixture: canonically valid genesis ledger + extending "quality" manifest
T004_Q_DIR="${T004_FIXTURE_ROOT}/quality-fixture"
mkdir -p "${T004_Q_DIR}/reports/review-context" "${T004_Q_DIR}/reports/implementation/crlf-fixture-q"
T004_Q_RUN1=RUN-t004-crlf-q-0001
T004_Q_SESSION1=SESS-t004-crlf-q-0001
T004_Q_RECORD1_HASH="$(printf '%s' "1|spec|spec-reviewer-a|${T004_Q_RUN1}|${T004_Q_SESSION1}|" | t004_sha256_text)"
cat > "${T004_Q_DIR}/reports/review-context/identity-ledger.json" <<EOF
{
  "schema": "review-identity-ledger/v1",
  "records": [
    {
      "sequence": 1,
      "stage": "spec",
      "role": "spec-reviewer-a",
      "run_id": "${T004_Q_RUN1}",
      "host_session_id": "${T004_Q_SESSION1}",
      "previous_record_sha256": "",
      "record_sha256": "${T004_Q_RECORD1_HASH}"
    }
  ]
}
EOF
T004_Q_LEDGER_HASH="$(t004_sha256_of "${T004_Q_DIR}/reports/review-context/identity-ledger.json")"
cat > "${T004_Q_DIR}/reports/implementation/crlf-fixture-q/T-999.md" <<'EOF'
# Implementation Report: T-999

- Task ID: T-999

## Outputs

| Path | SHA-256 |
|---|---|
EOF
T004_Q_REPORT_HASH="$(t004_sha256_of "${T004_Q_DIR}/reports/implementation/crlf-fixture-q/T-999.md")"
cat > "${T004_Q_DIR}/manifest.json" <<EOF
{
  "schema": "review-context-invocation/v2",
  "input_mode": "file-manifest",
  "fallback_mode": "none",
  "read_only": true,
  "stage": "quality",
  "role": "sdd-evaluator",
  "feature": "crlf-fixture-q",
  "task_id": "T-999",
  "run_id": "RUN-t004-crlf-q-0002",
  "host_session_id": "SESS-t004-crlf-q-0002",
  "sequence": 2,
  "identity_ledger_path": "reports/review-context/identity-ledger.json",
  "identity_ledger_sha256": "${T004_Q_LEDGER_HASH}",
  "previous_record_sha256": "${T004_Q_RECORD1_HASH}",
  "allowed_input_manifest": [
    {"path": "reports/implementation/crlf-fixture-q/T-999.md", "sha256": "${T004_Q_REPORT_HASH}"}
  ]
}
EOF

T004_Q_BASELINE="$(t004_run_clean "${T004_Q_DIR}/manifest.json" "${T004_Q_DIR}")"
t004_assert_contains "TEST-022/baseline: no-shim lane is green (quality fixture)" \
  "${T004_Q_BASELINE}" "REVIEW_CONTEXT_OK"

# --- TEST-022: 9 manifest single-value jq -r reads (lines 178-185) plus
# the conditional task_id read (line 187) each survive the CRLF shim --
# proven by asserting the shimmed-single-site output exactly matches the
# clean baseline (identical REVIEW_CONTEXT_OK record hash), for every site.
for q in '.stage' '.role' '.feature' '.run_id' '.host_session_id' '.sequence' \
         '.previous_record_sha256' '.identity_ledger_sha256'; do
  out="$(t004_run_shimmed "${q}" "${T004_SPEC_DIR}/manifest.json" "${T004_SPEC_DIR}")"
  t004_assert_eq "TEST-022: manifest field ${q} (jq -r) survives the CRLF shim" \
    "${out}" "${T004_SPEC_BASELINE}"
done
out="$(t004_run_shimmed '.task_id' "${T004_Q_DIR}/manifest.json" "${T004_Q_DIR}")"
t004_assert_eq "TEST-022: conditional task_id read (line 187) survives the CRLF shim" \
  "${out}" "${T004_Q_BASELINE}"

# --- TEST-023: the @tsv ledger-batch read (lines 250-258) feeding the
# record-hash recomputation loop -- this feature's RED-demonstrable pair
# (tasks.md Risk Rationale/Scope). Against the UNFIXED script
# (T004_VALIDATOR_UNDER_TEST pointed at a pre-fix copy) this assertion
# FAILS, printing the exact historical defect signature as its "actual"
# value: "REVIEW_CONTEXT_IDENTITY: canonical identity ledger record hash is
# invalid" on this same canonically valid genesis ledger. Against the fixed
# script it PASSES (equal to the clean REVIEW_CONTEXT_OK baseline).
T004_LEDGER_QUERY='.records[] | [
  .sequence,
  .stage,
  .role,
  .run_id,
  .host_session_id,
  (if .previous_record_sha256 == "" then "-" else .previous_record_sha256 end),
  .record_sha256
] | @tsv'
out="$(t004_run_shimmed "${T004_LEDGER_QUERY}" "${T004_SPEC_DIR}/manifest.json" "${T004_SPEC_DIR}")"
t004_assert_eq "TEST-023: ledger @tsv batch read (lines 250-258) survives the CRLF shim" \
  "${out}" "${T004_SPEC_BASELINE}"

# --- TEST-024: the two allowed_input_manifest jq -r sites outside the
# record-hash path proper (lines 275, 305).
out="$(t004_run_shimmed '.allowed_input_manifest[].path' "${T004_Q_DIR}/manifest.json" "${T004_Q_DIR}")"
t004_assert_eq "TEST-024a: line 275 (.allowed_input_manifest[].path) survives the CRLF shim" \
  "${out}" "${T004_Q_BASELINE}"
out="$(t004_run_shimmed '.allowed_input_manifest[] | [.path, .sha256] | @tsv' "${T004_SPEC_DIR}/manifest.json" "${T004_SPEC_DIR}")"
t004_assert_eq "TEST-024b: line 305 (.allowed_input_manifest[] | [.path,.sha256] | @tsv) survives the CRLF shim" \
  "${out}" "${T004_SPEC_BASELINE}"

# --- TEST-026: BL-010 non-regression -- genuinely tampered ledgers still
# fail closed with the correct coded error, under BOTH the no-shim lane and
# the __ALL__ (every -r call) shim lane, proving the fix never masks real
# tampering. Independent of fix state: expected to pass identically against
# both the unfixed and the fixed script.
t004_tamper_case() {
  local name="$1" dir="$2" expected="$3"
  local out_noshim out_shim
  out_noshim="$(t004_run_clean "${dir}/manifest.json" "${dir}")"
  t004_assert_contains "TEST-026 (${name}, no-shim lane) fails closed" "${out_noshim}" "${expected}"
  out_shim="$(t004_run_shimmed '__ALL__' "${dir}/manifest.json" "${dir}")"
  t004_assert_contains "TEST-026 (${name}, __ALL__ shim lane) fails closed" "${out_shim}" "${expected}"
}

# BL-010: wrong sequence
T004_TA_DIR="${T004_FIXTURE_ROOT}/tamper-wrong-sequence"
mkdir -p "${T004_TA_DIR}/reports/review-context" "${T004_TA_DIR}/specs/crlf-fixture"
cat > "${T004_TA_DIR}/reports/review-context/identity-ledger.json" <<EOF
{
  "schema": "review-identity-ledger/v1",
  "records": [
    {
      "sequence": 5,
      "stage": "spec",
      "role": "spec-reviewer-a",
      "run_id": "${T004_SPEC_RUN1}",
      "host_session_id": "${T004_SPEC_SESSION1}",
      "previous_record_sha256": "",
      "record_sha256": "${T004_SPEC_RECORD1_HASH}"
    }
  ]
}
EOF
T004_TA_LEDGER_HASH="$(t004_sha256_of "${T004_TA_DIR}/reports/review-context/identity-ledger.json")"
printf 'T-004 CRLF fixture requirements content\n' > "${T004_TA_DIR}/specs/crlf-fixture/requirements.md"
cat > "${T004_TA_DIR}/manifest.json" <<EOF
{
  "schema": "review-context-invocation/v2",
  "input_mode": "file-manifest",
  "fallback_mode": "none",
  "read_only": true,
  "stage": "spec",
  "role": "spec-reviewer-a",
  "feature": "crlf-fixture",
  "run_id": "RUN-t004-crlf-0002",
  "host_session_id": "SESS-t004-crlf-0002",
  "sequence": 2,
  "identity_ledger_path": "reports/review-context/identity-ledger.json",
  "identity_ledger_sha256": "${T004_TA_LEDGER_HASH}",
  "previous_record_sha256": "${T004_SPEC_RECORD1_HASH}",
  "allowed_input_manifest": [
    {"path": "specs/crlf-fixture/requirements.md", "sha256": "${T004_SPEC_REQ_HASH}"}
  ]
}
EOF
t004_tamper_case "wrong sequence" "${T004_TA_DIR}" \
  "REVIEW_CONTEXT_IDENTITY: canonical identity ledger chain is discontinuous"

# BL-010: wrong previous hash
T004_TB_DIR="${T004_FIXTURE_ROOT}/tamper-wrong-previous-hash"
mkdir -p "${T004_TB_DIR}/reports/review-context" "${T004_TB_DIR}/specs/crlf-fixture"
T004_FAKE_HASH="0000000000000000000000000000000000000000000000000000000000000000"
T004_FAKE_HASH="${T004_FAKE_HASH:0:64}"
cat > "${T004_TB_DIR}/reports/review-context/identity-ledger.json" <<EOF
{
  "schema": "review-identity-ledger/v1",
  "records": [
    {
      "sequence": 1,
      "stage": "spec",
      "role": "spec-reviewer-a",
      "run_id": "${T004_SPEC_RUN1}",
      "host_session_id": "${T004_SPEC_SESSION1}",
      "previous_record_sha256": "${T004_FAKE_HASH}",
      "record_sha256": "${T004_SPEC_RECORD1_HASH}"
    }
  ]
}
EOF
T004_TB_LEDGER_HASH="$(t004_sha256_of "${T004_TB_DIR}/reports/review-context/identity-ledger.json")"
printf 'T-004 CRLF fixture requirements content\n' > "${T004_TB_DIR}/specs/crlf-fixture/requirements.md"
cat > "${T004_TB_DIR}/manifest.json" <<EOF
{
  "schema": "review-context-invocation/v2",
  "input_mode": "file-manifest",
  "fallback_mode": "none",
  "read_only": true,
  "stage": "spec",
  "role": "spec-reviewer-a",
  "feature": "crlf-fixture",
  "run_id": "RUN-t004-crlf-0002",
  "host_session_id": "SESS-t004-crlf-0002",
  "sequence": 2,
  "identity_ledger_path": "reports/review-context/identity-ledger.json",
  "identity_ledger_sha256": "${T004_TB_LEDGER_HASH}",
  "previous_record_sha256": "${T004_SPEC_RECORD1_HASH}",
  "allowed_input_manifest": [
    {"path": "specs/crlf-fixture/requirements.md", "sha256": "${T004_SPEC_REQ_HASH}"}
  ]
}
EOF
t004_tamper_case "wrong previous hash" "${T004_TB_DIR}" \
  "REVIEW_CONTEXT_IDENTITY: canonical identity ledger chain is discontinuous"

# BL-010: symlink traversal (identity-ledger.json is a symlink)
T004_TC_DIR="${T004_FIXTURE_ROOT}/tamper-symlink"
mkdir -p "${T004_TC_DIR}/reports/review-context" "${T004_TC_DIR}/specs/crlf-fixture"
cp "${T004_SPEC_DIR}/reports/review-context/identity-ledger.json" "${T004_TC_DIR}/reports/review-context/identity-ledger.real.json"
ln -s identity-ledger.real.json "${T004_TC_DIR}/reports/review-context/identity-ledger.json"
T004_TC_LEDGER_HASH="$(t004_sha256_of "${T004_TC_DIR}/reports/review-context/identity-ledger.real.json")"
printf 'T-004 CRLF fixture requirements content\n' > "${T004_TC_DIR}/specs/crlf-fixture/requirements.md"
cat > "${T004_TC_DIR}/manifest.json" <<EOF
{
  "schema": "review-context-invocation/v2",
  "input_mode": "file-manifest",
  "fallback_mode": "none",
  "read_only": true,
  "stage": "spec",
  "role": "spec-reviewer-a",
  "feature": "crlf-fixture",
  "run_id": "RUN-t004-crlf-0002",
  "host_session_id": "SESS-t004-crlf-0002",
  "sequence": 2,
  "identity_ledger_path": "reports/review-context/identity-ledger.json",
  "identity_ledger_sha256": "${T004_TC_LEDGER_HASH}",
  "previous_record_sha256": "${T004_SPEC_RECORD1_HASH}",
  "allowed_input_manifest": [
    {"path": "specs/crlf-fixture/requirements.md", "sha256": "${T004_SPEC_REQ_HASH}"}
  ]
}
EOF
t004_tamper_case "symlink traversal" "${T004_TC_DIR}" \
  "REVIEW_CONTEXT_IDENTITY: canonical identity ledger traverses a symbolic link"

# BL-010: duplicate run/session id (manifest.run_id reuses the ledger's own
# genesis record run_id)
T004_TD_DIR="${T004_FIXTURE_ROOT}/tamper-duplicate-identity"
mkdir -p "${T004_TD_DIR}/reports/review-context" "${T004_TD_DIR}/specs/crlf-fixture"
cp "${T004_SPEC_DIR}/reports/review-context/identity-ledger.json" "${T004_TD_DIR}/reports/review-context/identity-ledger.json"
T004_TD_LEDGER_HASH="$(t004_sha256_of "${T004_TD_DIR}/reports/review-context/identity-ledger.json")"
printf 'T-004 CRLF fixture requirements content\n' > "${T004_TD_DIR}/specs/crlf-fixture/requirements.md"
cat > "${T004_TD_DIR}/manifest.json" <<EOF
{
  "schema": "review-context-invocation/v2",
  "input_mode": "file-manifest",
  "fallback_mode": "none",
  "read_only": true,
  "stage": "spec",
  "role": "spec-reviewer-a",
  "feature": "crlf-fixture",
  "run_id": "${T004_SPEC_RUN1}",
  "host_session_id": "SESS-t004-crlf-0002",
  "sequence": 2,
  "identity_ledger_path": "reports/review-context/identity-ledger.json",
  "identity_ledger_sha256": "${T004_TD_LEDGER_HASH}",
  "previous_record_sha256": "${T004_SPEC_RECORD1_HASH}",
  "allowed_input_manifest": [
    {"path": "specs/crlf-fixture/requirements.md", "sha256": "${T004_SPEC_REQ_HASH}"}
  ]
}
EOF
t004_tamper_case "duplicate run/session id" "${T004_TD_DIR}" \
  "REVIEW_CONTEXT_IDENTITY: run or host-session identity was already persisted"

if [[ "${T004_FAIL_COUNT}" -gt 0 ]]; then
  echo "FAIL (T-004): ${T004_FAIL_COUNT} CRLF-shim assertion(s) failed for validate-review-context-set.sh (issue #179)" >&2
  exit 1
fi
echo "ok: T-004 CRLF-jq-output coverage for validate-review-context-set.sh (issue #179)"
