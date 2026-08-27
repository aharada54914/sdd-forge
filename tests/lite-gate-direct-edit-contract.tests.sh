#!/usr/bin/env bash
# lite-gate-direct-edit-contract.tests.sh (epic-194-a6-lite-integration,
# T-004 quality-gate remediation, report
# reports/quality-gate/20260809T082000Z-epic-194-a6-lite-integration-T-004.md,
# Major findings 1 and 3, TEST-014/TEST-017, AC-014/AC-017).
#
# acceptance-tests.md never assigned AC-014/AC-017 a numbered design.md Test
# Strategy item (that list runs 1-17 and names neither AC), so no suite
# existed for either -- the quality-gate NEEDS_WORK verdict's own proof was
# that replacing the "順序が重要" ordering note and re-running all five
# T-004 suites failed ZERO. This suite closes that gap:
#
#   - TEST-014 (AC-014, Step-2b insertion-point lock): design.md's own
#     Architecture diagram requires Step 2a/2b sit strictly between the
#     existing Step 2 and Step 3, and the pre-existing "順序が重要"
#     ordering note stay textually preserved, unchanged, byte-for-byte.
#   - TEST-017 (AC-017, direct-edit protection-status lock): design.md's
#     own Protected-File Statement requires re-running
#     `grep -n "sdd-lite" plugins/sdd-quality-loop/references/
#     guard-invariants.json` and confirming lite-gate/SKILL.md is absent
#     from every protected array before a direct edit is valid -- an
#     ongoing regression lock, not merely a one-time historical claim.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SKILL="${REPO_ROOT}/plugins/sdd-lite/skills/lite-gate/SKILL.md"
GUARD_INVARIANTS="${REPO_ROOT}/plugins/sdd-quality-loop/references/guard-invariants.json"
GOLDEN_NOTE="${REPO_ROOT}/tests/fixtures/epic-194-lite-gate/skill-ordering-note.golden.txt"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

# ---------------------------------------------------------------------------
# TEST-014a (AC-014): Step 2a/2b sit strictly between the existing Step 2
# and Step 3. Anchored on each step's own distinctive opening text (not a
# bare "^2\. " / "^3\. " pattern) so this cannot accidentally match the
# unrelated numbered list in the earlier Track Detection handshake section.
# ---------------------------------------------------------------------------
echo "=== TEST-014a: Step 2a/2b sit strictly between the existing Step 2 and Step 3 ==="
STEP2_LINE="$(grep -n -F '2. プロジェクトの' "${SKILL}" | head -1 | cut -d: -f1)"
STEP2A_LINE="$(grep -n -F '2a. **`full_upgrade_required`' "${SKILL}" | head -1 | cut -d: -f1)"
STEP2B_LINE="$(grep -n -F '2b. **Registry-sourced' "${SKILL}" | head -1 | cut -d: -f1)"
STEP3_LINE="$(grep -n -F '3. `reports/quality-gate' "${SKILL}" | head -1 | cut -d: -f1)"
if [ -n "${STEP2_LINE:-}" ] && [ -n "${STEP2A_LINE:-}" ] && [ -n "${STEP2B_LINE:-}" ] && [ -n "${STEP3_LINE:-}" ] \
   && [ "${STEP2_LINE}" -lt "${STEP2A_LINE}" ] && [ "${STEP2A_LINE}" -lt "${STEP2B_LINE}" ] && [ "${STEP2B_LINE}" -lt "${STEP3_LINE}" ]; then
  ok "TEST-014a: Step order is 2 (${STEP2_LINE}) < 2a (${STEP2A_LINE}) < 2b (${STEP2B_LINE}) < 3 (${STEP3_LINE})"
else
  fail "TEST-014a: expected Step2 < 2a < 2b < Step3, got Step2=${STEP2_LINE:-<missing>} 2a=${STEP2A_LINE:-<missing>} 2b=${STEP2B_LINE:-<missing>} Step3=${STEP3_LINE:-<missing>}"
fi

# ---------------------------------------------------------------------------
# TEST-014b (AC-014): the pre-existing "順序が重要" ordering note is
# preserved verbatim, byte-for-byte -- compared against a golden fixture
# captured from the known-good text, not retyped inline (avoids transcription
# risk for the Japanese content while still locking every byte of it).
# ---------------------------------------------------------------------------
echo "=== TEST-014b: '順序が重要' ordering note preserved verbatim ==="
ACTUAL_NOTE="$(grep -F '順序が重要' "${SKILL}" || true)"
EXPECTED_NOTE="$(cat "${GOLDEN_NOTE}")"
if [ -n "${ACTUAL_NOTE}" ] && [ "${ACTUAL_NOTE}" = "${EXPECTED_NOTE}" ]; then
  ok "TEST-014b: the 順序が重要 ordering note text is byte-for-byte unchanged"
else
  fail "TEST-014b: ordering note text has drifted from the golden fixture -- expected [${EXPECTED_NOTE}], got [${ACTUAL_NOTE}]"
fi

# ---------------------------------------------------------------------------
# TEST-017 (AC-017): re-run the direct-edit protection-status check and
# confirm lite-gate/SKILL.md is still absent from every guard-invariants.json
# array that mentions an sdd-lite path. This is an ongoing regression lock
# for the same check the implementation report claims was run once,
# immediately before this task's own SKILL.md edit landed -- if lite-gate/
# SKILL.md is ever added to a protected array, the direct-edit path this
# task took becomes invalid and must re-route through human-copy (OQ-001
# contingency).
# ---------------------------------------------------------------------------
echo "=== TEST-017: guard-invariants.json direct-edit protection-status re-verification ==="
GREP_OUTPUT="$(grep -n "sdd-lite" "${GUARD_INVARIANTS}" || true)"
printf '%s\n' "${GREP_OUTPUT}"
if [ -z "${GREP_OUTPUT}" ]; then
  fail "TEST-017: grep -n \"sdd-lite\" guard-invariants.json returned nothing -- the check itself is vacuous (expected at least the lite-spec/SKILL.md entries)"
elif printf '%s\n' "${GREP_OUTPUT}" | grep -q 'lite-gate/SKILL\.md'; then
  fail "TEST-017: lite-gate/SKILL.md now appears in guard-invariants.json -- the direct-edit path is no longer valid; re-route through human-copy"
else
  ok "TEST-017: lite-gate/SKILL.md is absent from every sdd-lite-tagged guard-invariants.json entry; direct-edit remains valid"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
exit 0
