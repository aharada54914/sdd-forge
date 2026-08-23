#!/usr/bin/env bash
# task-state-grammar-parity.tests.sh — WFI-042: the task approval field has ONE
# annotated grammar across every deterministic checker.
#
# Two properties, fixture-driven:
#  1. ACCEPT/REJECT PARITY: the full checker (check-task-state.sh) and the lite
#     checker (check-task-state-lite.sh) agree on every fixture — bare,
#     strict-annotated, minutes-precision, fractional-seconds, empty-annotation,
#     free-text. The ps1 twins run when pwsh is available (CI), with a visible
#     skip line otherwise.
#  2. EXTRACTION AGREEMENT: no fixture may reproduce the pre-WFI-042
#     disagreement class — a line the validity test accepts as an annotated
#     approval but approver_id() cannot extract a named approver from. Run
#     against the pre-change checkers this suite FAILS on the minutes-precision
#     and fractional-seconds fixtures (the committed 8-line class), which is
#     the discriminating order Verification Plan item 1 requires.
#
# Checker paths are env-overridable (FULL_SH / LITE_SH / FULL_PS1 / LITE_PS1)
# so the discriminating replay can point at a pre-change copy.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FULL_SH="${FULL_SH:-${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-task-state.sh}"
LITE_SH="${LITE_SH:-${REPO_ROOT}/plugins/sdd-lite/scripts/check-task-state-lite.sh}"
FULL_PS1="${FULL_PS1:-${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-task-state.ps1}"
LITE_PS1="${LITE_PS1:-${REPO_ROOT}/plugins/sdd-lite/scripts/check-task-state-lite.ps1}"

PASS=0
FAIL=0
ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/reports/quality-gate" "$WORK/reports/implementation"

HAVE_PWSH=0
if command -v pwsh >/dev/null 2>&1; then HAVE_PWSH=1; fi
if [ "$HAVE_PWSH" -eq 0 ]; then
    echo "skip - ps1 legs: pwsh not found on this host (CI runs them)"
fi

# write_fixture <dir> <approval-line> [status-line]: a task carrying the forms
# under test. The default status, In Progress, requires a valid approval and
# nothing else, so the checker verdict isolates the grammar decision.
write_fixture() {
    _status="${3:-In Progress}"
    mkdir -p "$1"
    printf '# Tasks\n\n## T-001\n\nApproval: %s\nStatus: %s\n' "$2" "$_status" > "$1/tasks.md"
}

# Fixture set: name|approval-line|status-line|expected (0 accept / 1 reject).
# The minutes-precision and fractional-seconds rows are the two shapes of the
# 8 committed lines measured in WFI-042's Problem Evidence.
#
# The mis-cased rows are the AGENTS.md case-sensitivity sweep's mandatory
# negative fixtures (WFI-012 rule), and they cover BOTH operator layers the
# ps1 legs use to judge these fields:
#   - mis-cased-annotated exercises the REGEX layer, governed by -cmatch
#     (added by the PR #336 review).
#   - mis-cased-bare-* exercise the STRING-EQUALITY layer. The awk twin
#     compares with ==, which is case-sensitive; PowerShell's -eq is not.
#     Until those sites moved to -ceq, `Approval: approved` was rejected by
#     the awk leg and accepted as a valid, gate-satisfying approval by both
#     ps1 legs -- a mis-cased value passed the approval gate on PowerShell
#     hosts and failed it on POSIX.
#   - mis-cased-status-* exercise the same layer for Status, where the ps1
#     legs tested membership with -in / -notin against $validStatuses, also
#     case-insensitive, against an awk twin comparing with == and !=.
run_parity_cases() {
    idx=0
    while IFS='|' read -r name approval status expected; do
        [ -z "$name" ] && continue
        idx=$((idx+1))
        dir="$WORK/case-$idx"
        write_fixture "$dir" "$approval" "$status"

        full_rc=0
        sh "$FULL_SH" "$dir/tasks.md" "$WORK/reports/quality-gate" "$WORK/reports/implementation" "$WORK" >/dev/null 2>&1 || full_rc=$?
        lite_rc=0
        sh "$LITE_SH" "$dir/tasks.md" "$WORK/reports/quality-gate" "$WORK/reports/implementation" "$WORK" >/dev/null 2>&1 || lite_rc=$?

        if [ "$full_rc" != "$lite_rc" ]; then
            fail "parity [$name]: full=$full_rc lite=$lite_rc — the checkers disagree"
        elif [ "$full_rc" != "$expected" ]; then
            fail "parity [$name]: both exit $full_rc but expected $expected"
        else
            ok "parity [$name]: full and lite agree (exit $full_rc)"
        fi

        if [ "$HAVE_PWSH" -eq 1 ]; then
            fullps_rc=0
            pwsh -NoProfile -File "$FULL_PS1" "$dir/tasks.md" -ReportsDir "$WORK/reports/quality-gate" -ImplReportsDir "$WORK/reports/implementation" -RepoRoot "$WORK" >/dev/null 2>&1 || fullps_rc=$?
            liteps_rc=0
            pwsh -NoProfile -File "$LITE_PS1" "$dir/tasks.md" "$WORK/reports/quality-gate" "$WORK/reports/implementation" "$WORK" >/dev/null 2>&1 || liteps_rc=$?
            if [ "$fullps_rc" != "$expected" ] || [ "$liteps_rc" != "$expected" ]; then
                fail "parity-ps1 [$name]: full=$fullps_rc lite=$liteps_rc expected $expected"
            else
                ok "parity-ps1 [$name]: both ps1 twins agree (exit $expected)"
            fi
        fi
    done <<'CASES'
bare-approved|Approved|In Progress|0
draft|Draft|In Progress|1
strict-annotated|Approved (alice 2026-08-22T01:02:03Z)|In Progress|0
minutes-precision|Approved (human 2026-08-17T03:35Z)|In Progress|1
fractional-seconds|Approved (sudo 2026-07-13T05:53:16.481Z)|In Progress|1
empty-annotation|Approved ()|In Progress|1
free-text|Approved (waived pending human sign-off)|In Progress|1
mis-cased-annotated|approved (alice 2026-08-22T01:02:03Z)|In Progress|1
mis-cased-bare-lower|approved|In Progress|1
mis-cased-bare-upper|APPROVED|In Progress|1
mis-cased-bare-mixed|ApProVeD|In Progress|1
mis-cased-status-planned|Draft|planned|1
mis-cased-status-inprogress|Approved|in progress|1
CASES
}
# Note the draft row: Draft is a VALID field value, but an In Progress task
# without an approval fails the gate — expected 1 on both checkers keeps the
# row a parity probe rather than a grammar probe.
run_parity_cases

# ---------------------------------------------------------------------------
# Extraction agreement: a critical Done task exercises approver_id() on the
# same line the validity test judged. The disagreement signature is: validity
# raised NO invalid-Approval failure, yet extraction reports a missing named
# approver. Any fixture showing that signature is the WFI-042 defect.
# ---------------------------------------------------------------------------
check_extraction_agreement() {
    name="$1"; approval="$2"
    dir="$WORK/crit-$name"
    mkdir -p "$dir"
    {
        printf '# Tasks\n\n## T-001\n\n'
        printf 'Approval: %s\n' "$approval"
        printf 'Second Approval: Approved (bob 2026-08-22T01:02:03Z)\n'
        printf 'Risk: critical\nStatus: Done\n'
    } > "$dir/tasks.md"
    out="$(sh "$FULL_SH" "$dir/tasks.md" "$WORK/reports/quality-gate" "$WORK/reports/implementation" "$WORK" 2>&1)"
    if ! printf '%s' "$out" | grep -q "has invalid Approval" \
        && printf '%s' "$out" | grep -q "lacks a named approver"; then
        fail "extraction [$name]: validity accepted the line but approver_id() could not extract a name (the WFI-042 disagreement class)"
    else
        ok "extraction [$name]: validity and approver extraction agree"
    fi
}
check_extraction_agreement "strict" "Approved (alice 2026-08-22T01:02:03Z)"
check_extraction_agreement "minutes-precision" "Approved (human 2026-08-17T03:35Z)"
check_extraction_agreement "fractional-seconds" "Approved (sudo 2026-07-13T05:53:16.481Z)"
check_extraction_agreement "free-text" "Approved (waived pending human sign-off)"

echo ""
echo "task-state-grammar-parity.tests.sh: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
