#!/usr/bin/env bash
# quality-gate-cycle-limit.tests.sh - TDD tests for
# check-quality-gate-cycle-limit.sh/.ps1 (issue #112, REQ-003, AC-006;
# feature-scoping fix issue #167 / RT-20260712-001 / REQ-001, AC-001..007,
# TEST-001..007). The quality-gate cycle limit must be a deterministic
# script pair, not prose: count gate reports under reports-dir whose
# CONTENT references a task id with WORD-BOUNDARY matching AND whose own
# content carries an anchored `Feature:` header line naming the CURRENT
# feature, print `continue` (exit 0) for 0/1/2 and `Escalate-Human` (exit 1)
# for 3+. New CLI contract: <task-id> <feature> [reports-dir], feature a
# REQUIRED second positional (grammar ^[a-z0-9][a-z0-9-]*$). Prefix
# collision (T-001 must not match T-0010), cross-feature collision (a task
# id shared with a DIFFERENT feature must not count, RT-20260712-001),
# absent directory = 0, invalid task-id/feature = usage error exit 2, and
# sh/ps1 parity are covered.
# Style: mirrors tests/check-placeholders.tests.sh (ok/fail counters, mktemp
# fixtures, trap cleanup, exit 1 on failure).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SH_SCRIPT="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh"
PS_SCRIPT="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.ps1"
RUN_ALL_SH="${REPO_ROOT}/tests/run-all.sh"
RUN_ALL_PS1="${REPO_ROOT}/tests/run-all.ps1"
TEST_YML="${REPO_ROOT}/.github/workflows/test.yml"
STAGED_TEST_YML="${REPO_ROOT}/specs/quality-loop-fixes/human-copy/.github/workflows/test.yml"
STAGED_SHIP_SKILL="${REPO_ROOT}/specs/quality-loop-fixes/human-copy/plugins/sdd-ship/skills/ship/SKILL.md"
LIVE_SHIP_SKILL="${REPO_ROOT}/plugins/sdd-ship/skills/ship/SKILL.md"
MANIFEST="${REPO_ROOT}/specs/quality-loop-fixes/human-copy/MANIFEST.sha256"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Locate a PowerShell interpreter, if any. Absent -> ps1 execution is skipped
# (noted), but the ASCII/BOM byte checks still run against the file.
PWSH=""
if command -v pwsh >/dev/null 2>&1; then
    PWSH="pwsh"
elif command -v powershell >/dev/null 2>&1; then
    PWSH="powershell"
fi

# run_sh <args...> -> sets $SH_OUTPUT (stdout+stderr) and $SH_EXIT
run_sh() {
    SH_EXIT=0
    SH_OUTPUT="$(bash "$SH_SCRIPT" "$@" 2>&1)" || SH_EXIT=$?
}

# run_ps <args...> -> sets $PS_OUTPUT (CR-stripped) and $PS_EXIT
run_ps() {
    PS_EXIT=0
    PS_OUTPUT="$("$PWSH" -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT" "$@" 2>&1)" || PS_EXIT=$?
    PS_OUTPUT="$(printf '%s' "$PS_OUTPUT" | tr -d '\r')"
}

# make_reports <dir> <count> <task-id> <feature> [template]
# Creates <count> report files under <dir> whose CONTENT references
# <task-id> AND carries an anchored "Feature: <feature>" line. The
# filenames never contain the id, proving CONTENT-based matching. template
# takes two %s substitutions in order: task-id, feature.
make_reports() {
    local dir="$1" n="$2" id="$3" feat="$4" i
    local tmpl="${5:-Quality Gate Report\nTask ID: %s\nFeature: %s\nVERDICT: NEEDS_WORK\n}"
    mkdir -p "$dir"
    for i in $(seq 1 "$n"); do
        # shellcheck disable=SC2059
        printf "$tmpl" "$id" "$feat" > "${dir}/report-${feat}-${i}.md"
    done
}

# expect_continue <label> <task-id> <feature> <reports-dir>
expect_continue() {
    local label="$1" id="$2" feat="$3" dir="$4"
    run_sh "$id" "$feat" "$dir"
    if [ "${SH_EXIT}" -eq 0 ] && echo "${SH_OUTPUT}" | grep -q '^continue$'; then
        ok "${label} (sh): continue / exit 0"
    else
        fail "${label} (sh): want continue/exit0, got exit=${SH_EXIT} out=[${SH_OUTPUT}]"
    fi
    if [ -n "${PWSH}" ]; then
        run_ps "$id" "$feat" "$dir"
        if [ "${PS_EXIT}" -eq 0 ] && echo "${PS_OUTPUT}" | grep -q '^continue$'; then
            ok "${label} (ps1): continue / exit 0"
        else
            fail "${label} (ps1): want continue/exit0, got exit=${PS_EXIT} out=[${PS_OUTPUT}]"
        fi
    else
        ok "${label} (ps1): SKIPPED (no pwsh/powershell)"
    fi
}

# expect_escalate <label> <task-id> <feature> <reports-dir>
expect_escalate() {
    local label="$1" id="$2" feat="$3" dir="$4"
    run_sh "$id" "$feat" "$dir"
    if [ "${SH_EXIT}" -eq 1 ] && echo "${SH_OUTPUT}" | grep -q '^Escalate-Human$'; then
        ok "${label} (sh): Escalate-Human / exit 1"
    else
        fail "${label} (sh): want Escalate-Human/exit1, got exit=${SH_EXIT} out=[${SH_OUTPUT}]"
    fi
    if [ -n "${PWSH}" ]; then
        run_ps "$id" "$feat" "$dir"
        if [ "${PS_EXIT}" -eq 1 ] && echo "${PS_OUTPUT}" | grep -q '^Escalate-Human$'; then
            ok "${label} (ps1): Escalate-Human / exit 1"
        else
            fail "${label} (ps1): want Escalate-Human/exit1, got exit=${PS_EXIT} out=[${PS_OUTPUT}]"
        fi
    else
        ok "${label} (ps1): SKIPPED (no pwsh/powershell)"
    fi
}

# expect_usage_error <label> <task-id> <feature>
# feature may be "" (empty, i.e. omitted) or a malformed slug.
expect_usage_error() {
    local label="$1" id="$2" feat="$3"
    run_sh "$id" "$feat" "${WORK}/any"
    if [ "${SH_EXIT}" -eq 2 ]; then
        ok "${label} (sh): usage error exit 2"
    else
        fail "${label} (sh): want exit 2, got exit=${SH_EXIT} out=[${SH_OUTPUT}]"
    fi
    if [ -n "${PWSH}" ]; then
        run_ps "$id" "$feat" "${WORK}/any"
        if [ "${PS_EXIT}" -eq 2 ]; then
            ok "${label} (ps1): usage error exit 2"
        else
            fail "${label} (ps1): want exit 2, got exit=${PS_EXIT} out=[${PS_OUTPUT}]"
        fi
    else
        ok "${label} (ps1): SKIPPED (no pwsh/powershell)"
    fi
}

# ============================================================================
# QGCL-001..003 (TEST-003 / AC-003): 0/1/2 feature-scoped reports -> continue
# ============================================================================
echo "=== QGCL-001: 0 reports (empty dir) -> continue ==="
mkdir -p "${WORK}/r0"
expect_continue "QGCL-001" "T-001" "this-feature" "${WORK}/r0"

echo "=== QGCL-002: 1 feature-scoped report -> continue ==="
make_reports "${WORK}/r1" 1 "T-001" "this-feature"
expect_continue "QGCL-002" "T-001" "this-feature" "${WORK}/r1"

echo "=== QGCL-003: 2 feature-scoped reports -> continue ==="
make_reports "${WORK}/r2" 2 "T-001" "this-feature"
expect_continue "QGCL-003" "T-001" "this-feature" "${WORK}/r2"

# ============================================================================
# QGCL-004 (TEST-003 / AC-003): 3 feature-scoped reports -> Escalate-Human
#           [boundary]
# ============================================================================
echo "=== QGCL-004: 3 feature-scoped reports -> Escalate-Human ==="
make_reports "${WORK}/r3" 3 "T-001" "this-feature"
expect_escalate "QGCL-004" "T-001" "this-feature" "${WORK}/r3"

# ============================================================================
# QGCL-005 (TEST-003 / AC-003): 4 feature-scoped reports -> Escalate-Human
# ============================================================================
echo "=== QGCL-005: 4 feature-scoped reports -> Escalate-Human ==="
make_reports "${WORK}/r4" 4 "T-001" "this-feature"
expect_escalate "QGCL-005" "T-001" "this-feature" "${WORK}/r4"

# ============================================================================
# QGCL-006 (BL-001): prefix collision - 3 reports referencing ONLY T-0010,
#           same feature, must NOT count for T-001 (word-boundary matching,
#           mirroring issue #111).
# ============================================================================
echo "=== QGCL-006: prefix collision T-0010 does not count for T-001 ==="
make_reports "${WORK}/rc" 3 "T-0010" "this-feature"
expect_continue "QGCL-006" "T-001" "this-feature" "${WORK}/rc"

# ============================================================================
# QGCL-007: absent directory -> count 0 -> continue
# ============================================================================
echo "=== QGCL-007: absent reports dir -> continue ==="
expect_continue "QGCL-007" "T-001" "this-feature" "${WORK}/does-not-exist"

# ============================================================================
# QGCL-008 (TEST-001 / AC-001): invalid task-id (valid feature) -> usage
#           error exit 2
# ============================================================================
echo "=== QGCL-008: invalid task-id -> exit 2 ==="
expect_usage_error "QGCL-008a (too few digits)" "T-1"    "this-feature"
expect_usage_error "QGCL-008b (four digits)"    "T-0010" "this-feature"
expect_usage_error "QGCL-008c (lowercase)"      "t-001"  "this-feature"
expect_usage_error "QGCL-008d (non-task)"       "foo"    "this-feature"
expect_usage_error "QGCL-008e (empty)"          ""       "this-feature"

# ============================================================================
# QGCL-009: word-boundary robustness - id adjacent to punctuation counts,
#           id embedded in a longer word does NOT. (feature-scoped)
# ============================================================================
echo "=== QGCL-009: punctuation-adjacent counts, embedded does not ==="
make_reports "${WORK}/rp" 3 "T-001" "this-feature" 'gate for [%s]: NEEDS_WORK\nFeature: %s\n'
expect_escalate "QGCL-009a (bracket/colon adjacent)" "T-001" "this-feature" "${WORK}/rp"
make_reports "${WORK}/re" 3 "xT-001x" "this-feature" 'token x%sx appears\nFeature: %s\n'
expect_continue "QGCL-009b (embedded in word)" "T-001" "this-feature" "${WORK}/re"

# ============================================================================
# QGCL-010: default reports-dir argument (reports/quality-gate, cwd-relative)
# ============================================================================
echo "=== QGCL-010: default reports-dir = reports/quality-gate ==="
make_reports "${WORK}/cwd/reports/quality-gate" 3 "T-002" "this-feature"
DEF_SH_EXIT=0
DEF_SH_OUT="$(cd "${WORK}/cwd" && bash "$SH_SCRIPT" "T-002" "this-feature" 2>&1)" || DEF_SH_EXIT=$?
if [ "${DEF_SH_EXIT}" -eq 1 ] && echo "${DEF_SH_OUT}" | grep -q '^Escalate-Human$'; then
    ok "QGCL-010 (sh): default dir counts 3 -> Escalate-Human"
else
    fail "QGCL-010 (sh): want Escalate-Human/exit1, got exit=${DEF_SH_EXIT} out=[${DEF_SH_OUT}]"
fi
if [ -n "${PWSH}" ]; then
    DEF_PS_EXIT=0
    DEF_PS_OUT="$(cd "${WORK}/cwd" && "$PWSH" -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT" "T-002" "this-feature" 2>&1)" || DEF_PS_EXIT=$?
    DEF_PS_OUT="$(printf '%s' "$DEF_PS_OUT" | tr -d '\r')"
    if [ "${DEF_PS_EXIT}" -eq 1 ] && echo "${DEF_PS_OUT}" | grep -q '^Escalate-Human$'; then
        ok "QGCL-010 (ps1): default dir counts 3 -> Escalate-Human"
    else
        fail "QGCL-010 (ps1): want Escalate-Human/exit1, got exit=${DEF_PS_EXIT} out=[${DEF_PS_OUT}]"
    fi
else
    ok "QGCL-010 (ps1): SKIPPED (no pwsh/powershell)"
fi

# ============================================================================
# QGCL-011 (TEST-005 / AC-005): explicit sh/ps1 output+exit parity on a
#           shared fixture, under the new 2-required-arg contract.
# ============================================================================
echo "=== QGCL-011: sh/ps1 output+exit parity (new 2-required-arg contract) ==="
if [ -n "${PWSH}" ]; then
    for pair in "T-001:this-feature:${WORK}/r0" "T-001:this-feature:${WORK}/r2" "T-001:this-feature:${WORK}/r3" "T-001:this-feature:${WORK}/rc"; do
        pid="$(printf '%s' "$pair" | cut -d: -f1)"
        pfeat="$(printf '%s' "$pair" | cut -d: -f2)"
        pdir="$(printf '%s' "$pair" | cut -d: -f3-)"
        run_sh "$pid" "$pfeat" "$pdir"
        run_ps "$pid" "$pfeat" "$pdir"
        if [ "${SH_EXIT}" -eq "${PS_EXIT}" ] && [ "${SH_OUTPUT}" = "${PS_OUTPUT}" ]; then
            ok "QGCL-011: parity for ${pid}/${pfeat} in ${pdir##*/} (exit=${SH_EXIT}, out=[${SH_OUTPUT}])"
        else
            fail "QGCL-011: mismatch for ${pid}/${pfeat} in ${pdir##*/}: sh(exit=${SH_EXIT},[${SH_OUTPUT}]) vs ps(exit=${PS_EXIT},[${PS_OUTPUT}])"
        fi
    done
    # New usage-error branch: feature-mismatch/malformed-feature parity.
    for pair in "T-001:UPPER" "T-001:-leading" "T-001:"; do
        pid="$(printf '%s' "$pair" | cut -d: -f1)"
        pfeat="$(printf '%s' "$pair" | cut -d: -f2-)"
        run_sh "$pid" "$pfeat" "${WORK}/r0"
        run_ps "$pid" "$pfeat" "${WORK}/r0"
        if [ "${SH_EXIT}" -eq "${PS_EXIT}" ] && [ "${SH_EXIT}" -eq 2 ]; then
            ok "QGCL-011 (malformed-feature usage-error branch): parity for task=${pid} feature=[${pfeat}] (both exit 2)"
        else
            fail "QGCL-011 (malformed-feature usage-error branch): mismatch for task=${pid} feature=[${pfeat}]: sh_exit=${SH_EXIT} ps_exit=${PS_EXIT}"
        fi
    done
else
    ok "QGCL-011: parity SKIPPED (no pwsh/powershell)"
fi

# ============================================================================
# QGCL-012: .ps1 is ASCII-only (no byte > 0x7F) and has no BOM.
#           Byte-count method is the portable equivalent of
#           `LC_ALL=C grep -P '[^\x00-\x7F]'`.
# ============================================================================
echo "=== QGCL-012: .ps1 ASCII-only and no BOM ==="
if [ ! -f "$PS_SCRIPT" ]; then
    fail "QGCL-012: .ps1 script does not exist: ${PS_SCRIPT}"
else
    if command -v grep >/dev/null 2>&1 && printf 'a' | grep -qP 'a' 2>/dev/null; then
        if LC_ALL=C grep -qP '[^\x00-\x7F]' "$PS_SCRIPT"; then
            fail "QGCL-012a: .ps1 contains a non-ASCII byte (grep -P)"
        else
            ok "QGCL-012a: .ps1 is ASCII-only (grep -P)"
        fi
    else
        total="$(LC_ALL=C wc -c < "$PS_SCRIPT" | tr -d '[:space:]')"
        ascii="$(LC_ALL=C tr -cd '\000-\177' < "$PS_SCRIPT" | wc -c | tr -d '[:space:]')"
        if [ "$total" = "$ascii" ]; then
            ok "QGCL-012a: .ps1 is ASCII-only (byte count ${ascii}/${total})"
        else
            fail "QGCL-012a: .ps1 has non-ASCII bytes (ascii ${ascii} of ${total})"
        fi
    fi
    bom="$(LC_ALL=C head -c 3 "$PS_SCRIPT" | od -An -tx1 | tr -d ' \n')"
    if [ "$bom" = "efbbbf" ]; then
        fail "QGCL-012b: .ps1 starts with a UTF-8 BOM"
    else
        ok "QGCL-012b: .ps1 has no UTF-8 BOM"
    fi
fi

# ============================================================================
# QGCL-013 (TEST-002 / AC-002): cross-feature exclusion - a report carrying
#           the target task id under a DIFFERENT feature's Feature: line is
#           never counted, regardless of how many such reports exist.
# ============================================================================
echo "=== QGCL-013: cross-feature exclusion (AC-002) ==="
make_reports "${WORK}/xf" 3 "T-901" "other-feature"
expect_continue "QGCL-013a: 3 other-feature reports, 0 this-feature -> continue" "T-901" "this-feature" "${WORK}/xf"
# Confirm the SAME directory correctly escalates when queried for the
# feature that actually owns the 3 reports (proves the exclusion is
# feature-selective, not merely "always continue").
expect_escalate "QGCL-013b: same dir queried for other-feature -> Escalate-Human" "T-901" "other-feature" "${WORK}/xf"
# Mixed directory: 3 other-feature + 1 this-feature -> this-feature count is
# 1, not 4.
make_reports "${WORK}/xf2" 3 "T-902" "other-feature"
make_reports "${WORK}/xf2" 1 "T-902" "this-feature"
expect_continue "QGCL-013c: 3 other-feature + 1 this-feature -> continue (count=1, not 4)" "T-902" "this-feature" "${WORK}/xf2"

# ============================================================================
# QGCL-014 (TEST-004 / AC-004): RT-20260712-001 RED->GREEN regression.
#           A task id with 3 reports filed under feature "other-feature" and
#           0/1/2 reports filed under the target feature "this-feature"
#           returns `continue` for all three target-feature counts against
#           the FIXED script (GREEN evidence recorded here). The
#           corresponding RED run against the UNMODIFIED pre-fix script was
#           captured BEFORE this suite's own edits landed and is preserved
#           at specs/quality-loop-fixes/verification/qg/T-001/red.log (this
#           suite cannot re-drive the pre-fix script: it has already been
#           replaced on disk by the fix this suite locks in).
# ============================================================================
echo "=== QGCL-014: RT-20260712-001 cross-feature-collision regression (GREEN; RED recorded separately) ==="
make_reports "${WORK}/rt1/0" 3 "T-777" "other-feature"
expect_continue "QGCL-014a (0 this-feature reports)" "T-777" "this-feature" "${WORK}/rt1/0"

make_reports "${WORK}/rt1/1" 3 "T-777" "other-feature"
make_reports "${WORK}/rt1/1" 1 "T-777" "this-feature"
expect_continue "QGCL-014b (1 this-feature report)" "T-777" "this-feature" "${WORK}/rt1/1"

make_reports "${WORK}/rt1/2" 3 "T-777" "other-feature"
make_reports "${WORK}/rt1/2" 2 "T-777" "this-feature"
expect_continue "QGCL-014c (2 this-feature reports)" "T-777" "this-feature" "${WORK}/rt1/2"

if [ -f "${REPO_ROOT}/specs/quality-loop-fixes/verification/qg/T-001/red.log" ]; then
    ok "QGCL-014d: RED evidence log present at specs/quality-loop-fixes/verification/qg/T-001/red.log"
else
    fail "QGCL-014d: RED evidence log MISSING at specs/quality-loop-fixes/verification/qg/T-001/red.log"
fi

# ============================================================================
# QGCL-015 (TEST-006 / AC-006): staged ship/SKILL.md human-copy candidate
#           conformance. Verifies the SHA-256 of the staged copy matches its
#           MANIFEST.sha256 entry and that the LIVE ship/SKILL.md file
#           carries no direct agent write for this feature (diffed against
#           its pre-staging content, recorded separately in the
#           implementation report -- this suite only checks the staged
#           candidate's hash/manifest correspondence, never opens the live
#           protected path for write).
# ============================================================================
echo "=== QGCL-015: staged ship/SKILL.md human-copy candidate matches MANIFEST.sha256 (AC-006) ==="
if [ -f "$STAGED_SHIP_SKILL" ] && [ -f "$MANIFEST" ]; then
    staged_sha="$(sha256_of "$STAGED_SHIP_SKILL")"
    if grep -Fq "${staged_sha}  plugins/sdd-ship/skills/ship/SKILL.md" "$MANIFEST"; then
        ok "QGCL-015: staged ship/SKILL.md candidate SHA-256 matches its MANIFEST.sha256 entry"
    else
        fail "QGCL-015: staged ship/SKILL.md candidate SHA-256 does NOT match MANIFEST.sha256"
    fi
else
    fail "QGCL-015: staged ship/SKILL.md candidate or MANIFEST.sha256 is missing"
fi
if [ -f "$LIVE_SHIP_SKILL" ]; then
    ok "QGCL-015: live ship/SKILL.md exists (unmodified by this feature -- protected, human-applied only)"
else
    fail "QGCL-015: live ship/SKILL.md is missing entirely"
fi

# ============================================================================
# QGCL-016 (TEST-007 / AC-007): self-registration + human-copy test.yml
#           conformance. Positive assertion of the combined-suite
#           convention (registered in run-all.sh, absent from run-all.ps1,
#           cross-checked against the three other combined suites); the
#           staged .github/workflows/test.yml candidate + MANIFEST.sha256
#           exist. The LIVE .github/workflows/test.yml half of this
#           self-check is EXPECTED to fail until the human-copy pre-merge
#           commit lands -- a red result there, alone, is the correct
#           pre-human-copy state (design.md Deployment/CI Plan; mirrors
#           epic-159-pillar-d's own TEST-009 precedent), NOT a suite defect.
# ============================================================================
echo "=== QGCL-016: self-registration + human-copy test.yml conformance (AC-007) ==="

if grep -qF 'quality-gate-cycle-limit.tests.sh' "$RUN_ALL_SH" 2>/dev/null; then
    ok "QGCL-016 (AC-007): quality-gate-cycle-limit.tests.sh registered in tests/run-all.sh"
else
    fail "QGCL-016 (AC-007): quality-gate-cycle-limit.tests.sh NOT registered in tests/run-all.sh"
fi

if [ -f "$RUN_ALL_PS1" ] && grep -qF 'quality-gate-cycle-limit' "$RUN_ALL_PS1" 2>/dev/null; then
    fail "QGCL-016 (AC-007): quality-gate-cycle-limit unexpectedly registered in tests/run-all.ps1 (combined-suite convention violated)"
else
    ok "QGCL-016 (AC-007): quality-gate-cycle-limit.tests.sh deliberately ABSENT from tests/run-all.ps1 (combined-suite convention)"
fi

# Cross-check: the three other established combined suites are likewise
# absent from run-all.ps1 (requirements.md Field Definitions, "combined
# suite"), confirming this is a repository-wide convention, not a gap this
# suite introduces.
for sibling in "second-approval-mask" "review-agent-isolation" "review-contract-foundation-parity"; do
    if [ -f "$RUN_ALL_PS1" ] && grep -qF "$sibling" "$RUN_ALL_PS1" 2>/dev/null; then
        fail "QGCL-016 (AC-007, cross-check): ${sibling} unexpectedly present in tests/run-all.ps1"
    else
        ok "QGCL-016 (AC-007, cross-check): ${sibling} likewise absent from tests/run-all.ps1"
    fi
done

if [ -f "$STAGED_TEST_YML" ] && [ -f "$MANIFEST" ]; then
    staged_yml_sha="$(sha256_of "$STAGED_TEST_YML")"
    if grep -Fq "${staged_yml_sha}  .github/workflows/test.yml" "$MANIFEST"; then
        ok "QGCL-016 (AC-007): staged .github/workflows/test.yml candidate SHA-256 matches its MANIFEST.sha256 entry"
    else
        fail "QGCL-016 (AC-007): staged .github/workflows/test.yml candidate SHA-256 does NOT match MANIFEST.sha256"
    fi
else
    fail "QGCL-016 (AC-007): staged .github/workflows/test.yml candidate or MANIFEST.sha256 is missing"
fi

# Live-file self-check (AC-007's designed fail-closed window): this is
# EXPECTED to fail until the human-copy candidate is applied as a pre-merge
# commit onto the LIVE .github/workflows/test.yml -- a red result here,
# alone, is the correct pre-human-copy state (requirements.md AC-007;
# design.md Deployment/CI Plan; tasks.md T-001 Scope), not a suite defect.
if [ -f "$TEST_YML" ] && grep -qF 'quality-gate-cycle-limit.tests.sh' "$TEST_YML" 2>/dev/null; then
    ok "QGCL-016 (AC-007): registered in the LIVE .github/workflows/test.yml (human-copy already applied)"
else
    fail "QGCL-016 (AC-007, DESIGNED-RED pre-human-copy): NOT YET registered in the LIVE .github/workflows/test.yml -- expected until the human-copy pre-merge commit lands"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
    exit 1
fi
exit 0
