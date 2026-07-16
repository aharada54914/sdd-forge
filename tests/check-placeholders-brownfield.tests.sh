#!/usr/bin/env bash
# tests/check-placeholders-brownfield.tests.sh -- canonical brownfield seed
# existence + check-placeholders brownfield behavior lock (T-002 / Issue
# #146 / epic-159-pillar-a2 REQ-002).
#
# TEST-007 (AC-007, partial): tests/fixtures/loops/brownfield-seed/ is
#   committed with all three documented categories -- a legitimate
#   NotImplementedError abstract base class, a pre-existing task-unrelated
#   TODO marker, and a bootstrap-complete tasks.md. (AC-007's second clause
#   -- `loop_fixture_init brownfield` succeeding with the seed content
#   present verbatim under $LOOP_FIXTURE_ROOT -- is proven in
#   tests/loop-consistency.tests.sh/.ps1's brownfield-profile leg instead:
#   design.md's Constraint Compliance table declares THIS suite jq-free by
#   design ("check-placeholders-brownfield only inspects exit codes and the
#   gate's plain-text findings only" -- INV-031), and loop_fixture_init
#   itself calls jq internally, so driving it here would contradict that
#   declaration; the loop-consistency suite already depends on jq and
#   already sources tests/lib/loop-driver.sh, so the verbatim-copy proof
#   lives there where it does not introduce a new jq dependency.)
# TEST-008 (AC-008, Case A): check-placeholders.sh/.ps1, invoked with only
#   the seed's marker-free CHANGED_FILES.txt subset (src/service.py,
#   specs/brownfield-seed-demo/tasks.md), exits 0 despite the seed's
#   pre-existing markers elsewhere.
# TEST-009 (AC-009, Case B): check-placeholders.sh/.ps1, invoked with the
#   full seed directory, exits 1 and reports BOTH pre-existing marker
#   findings (base.py NotImplementedError, legacy_util.py TODO), while the
#   two marker-free files never appear in the findings.
#
# Mirrors tests/check-placeholders.tests.sh's run_cp() helper pattern. Both
# real gate scripts are driven READ-ONLY against a mktemp COPY of the
# canonical seed -- never the real repository path directly.
#
# CI resilience (AC-018): the mktemp work directory is normalized with
# `pwd -P` immediately after creation (INV-030); this suite consumes no jq
# output anywhere (INV-031 non-use declaration -- it inspects exit codes
# and the gate's plain-text findings only); the one array this suite
# declares (CHANGED_ARGS) is checked for emptiness before any
# "${arr[@]}" expansion (INV-029).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SC="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-placeholders.sh"
SEED="${REPO_ROOT}/tests/fixtures/loops/brownfield-seed"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/check-placeholders-brownfield.XXXXXX")"
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

SEED_COPY="${WORK}/seed"
mkdir -p "$SEED_COPY"
cp -R "${SEED}/." "${SEED_COPY}/"

# Run check-placeholders.sh capturing stdout+stderr and exit code, against
# the mktemp COPY -- mirrors tests/check-placeholders.tests.sh's run_cp().
# Usage: run_cp [args...]  ->  sets $CP_OUTPUT and $CP_EXIT
run_cp() {
    CP_EXIT=0
    CP_OUTPUT="$(bash "$SC" "$@" 2>&1)" || CP_EXIT=$?
}

# ============================================================================
# TEST-007 (AC-007, partial): canonical seed existence + three categories
# ============================================================================
echo "=== TEST-007: canonical brownfield seed existence + three documented categories ==="

if [[ -f "${SEED}/src/base.py" ]] && grep -q 'NotImplementedError' "${SEED}/src/base.py"; then
    ok "TEST-007.1 (AC-007): src/base.py carries a legitimate NotImplementedError abstract-base-class marker"
else
    fail "TEST-007.1 (AC-007): src/base.py missing or does not carry a NotImplementedError marker"
fi

if [[ -f "${SEED}/src/legacy_util.py" ]] && grep -q '# TODO' "${SEED}/src/legacy_util.py"; then
    ok "TEST-007.2 (AC-007): src/legacy_util.py carries a pre-existing, task-unrelated TODO marker"
else
    fail "TEST-007.2 (AC-007): src/legacy_util.py missing or does not carry a TODO marker"
fi

TASKS_MD="${SEED}/specs/brownfield-seed-demo/tasks.md"
if [[ -f "$TASKS_MD" ]] \
   && grep -q '^# Tasks:' "$TASKS_MD" \
   && grep -q '^Task-Review-Status:' "$TASKS_MD" \
   && grep -q '^## T-[0-9]' "$TASKS_MD" \
   && grep -q '^Status:' "$TASKS_MD" \
   && grep -q '^Risk:' "$TASKS_MD" \
   && grep -q '^Risk Rationale:' "$TASKS_MD" \
   && grep -q '^Required Workflow:' "$TASKS_MD" \
   && grep -q '^### Blockers' "$TASKS_MD"; then
    ok "TEST-007.3 (AC-007): specs/brownfield-seed-demo/tasks.md is bootstrap-complete (header/Task-Review-Status/T-NNN block with Status,Risk,Risk Rationale,Required Workflow/Blockers section)"
else
    fail "TEST-007.3 (AC-007): specs/brownfield-seed-demo/tasks.md is missing the bootstrap-complete structure"
fi

if grep -qF '{{' "$TASKS_MD" 2>/dev/null; then
    fail "TEST-007.4 (AC-007, negative self-check): specs/brownfield-seed-demo/tasks.md carries an unresolved {{...}} template placeholder"
else
    ok "TEST-007.4 (AC-007): specs/brownfield-seed-demo/tasks.md carries no unresolved {{...}} template placeholder"
fi

# ============================================================================
# TEST-008 (AC-008): Case A -- marker-free changed-files subset -> exit 0
# ============================================================================
echo "=== TEST-008: marker-free CHANGED_FILES.txt subset passes (Case A) ==="

CHANGED_FILES_MANIFEST="${SEED}/CHANGED_FILES.txt"
if [[ -f "$CHANGED_FILES_MANIFEST" ]]; then
    ok "TEST-008.1 (AC-008): CHANGED_FILES.txt manifest exists"
else
    fail "TEST-008.1 (AC-008): CHANGED_FILES.txt manifest missing"
fi

CHANGED_ARGS=()
while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    CHANGED_ARGS+=("${SEED_COPY}/${rel}")
done < "$CHANGED_FILES_MANIFEST"

if [[ "${#CHANGED_ARGS[@]}" -eq 0 ]]; then
    fail "TEST-008.2 (AC-008): CHANGED_FILES.txt manifest is empty"
else
    run_cp "${CHANGED_ARGS[@]}"
    if [[ "$CP_EXIT" -eq 0 ]]; then
        ok "TEST-008.2 (AC-008): check-placeholders.sh invoked with only the marker-free changed-files subset exits 0"
    else
        fail "TEST-008.2 (AC-008): expected exit 0 for the marker-free changed-files subset, got ${CP_EXIT}. Output: ${CP_OUTPUT}"
    fi
fi

# Negative self-check (requirements.md Edge Cases): BOTH marker-bearing seed
# files must never appear in the manifest.
if grep -qF 'base.py' "$CHANGED_FILES_MANIFEST" || grep -qF 'legacy_util.py' "$CHANGED_FILES_MANIFEST"; then
    fail "TEST-008.3 (AC-008, negative self-check): CHANGED_FILES.txt unexpectedly lists a marker-bearing file"
else
    ok "TEST-008.3 (AC-008, negative self-check): CHANGED_FILES.txt lists neither marker-bearing file"
fi

# ============================================================================
# TEST-009 (AC-009): Case B -- full seed directory -> exit 1, BOTH findings
# ============================================================================
echo "=== TEST-009: full seed directory fails with BOTH pre-existing markers (Case B) ==="

run_cp "$SEED_COPY"
if [[ "$CP_EXIT" -eq 1 ]]; then
    ok "TEST-009.1 (AC-009): check-placeholders.sh invoked with the full seed directory exits 1"
else
    fail "TEST-009.1 (AC-009): expected exit 1 for the full seed directory, got ${CP_EXIT}. Output: ${CP_OUTPUT}"
fi

if echo "$CP_OUTPUT" | grep -q 'base\.py.*NotImplementedError'; then
    ok "TEST-009.2 (AC-009): output reports the base.py NotImplementedError finding"
else
    fail "TEST-009.2 (AC-009): output is missing the base.py NotImplementedError finding. Output: ${CP_OUTPUT}"
fi

if echo "$CP_OUTPUT" | grep -q 'legacy_util\.py.*TODO'; then
    ok "TEST-009.3 (AC-009): output reports the legacy_util.py TODO finding"
else
    fail "TEST-009.3 (AC-009): output is missing the legacy_util.py TODO finding. Output: ${CP_OUTPUT}"
fi

if echo "$CP_OUTPUT" | grep -q 'service\.py'; then
    fail "TEST-009.4 (AC-009, negative self-check): the marker-free service.py unexpectedly appears in the findings"
else
    ok "TEST-009.4 (AC-009, negative self-check): the marker-free service.py does not appear in the findings"
fi

if echo "$CP_OUTPUT" | grep -q 'tasks\.md'; then
    fail "TEST-009.5 (AC-009, negative self-check): the marker-free tasks.md unexpectedly appears in the findings"
else
    ok "TEST-009.5 (AC-009, negative self-check): the marker-free tasks.md does not appear in the findings"
fi

# ============================================================================
# Self-registration (design.md Test Strategy item 5, mirroring
# tests/second-approval-mask.tests.sh:285-289's established pattern)
# ============================================================================
echo "=== Self-registration: run-all.sh / run-all.ps1 / test.yml ==="

RUN_ALL_SH="${REPO_ROOT}/tests/run-all.sh"
RUN_ALL_PS1="${REPO_ROOT}/tests/run-all.ps1"
TEST_YML="${REPO_ROOT}/.github/workflows/test.yml"

if grep -q 'tests/check-placeholders-brownfield\.tests\.sh' "$RUN_ALL_SH" 2>/dev/null \
   && grep -q 'check-placeholders-brownfield\.tests\.sh' "$TEST_YML" 2>/dev/null; then
    ok "REG.1 (design.md Test Strategy item 5): check-placeholders-brownfield.tests.sh is registered in run-all.sh and test.yml"
else
    fail "REG.1 (design.md Test Strategy item 5): check-placeholders-brownfield.tests.sh is NOT registered in run-all.sh and/or test.yml"
fi

if grep -q 'tests/check-placeholders-brownfield\.tests\.ps1' "$RUN_ALL_PS1" 2>/dev/null \
   && grep -q 'check-placeholders-brownfield\.tests\.ps1' "$TEST_YML" 2>/dev/null; then
    ok "REG.2 (design.md Test Strategy item 5): check-placeholders-brownfield.tests.ps1 is registered in run-all.ps1 and test.yml"
else
    fail "REG.2 (design.md Test Strategy item 5): check-placeholders-brownfield.tests.ps1 is NOT registered in run-all.ps1 and/or test.yml"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
printf 'check-placeholders-brownfield.tests.sh: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
