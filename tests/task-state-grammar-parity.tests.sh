#!/usr/bin/env bash
# Verify the persisted-state validators on both runtimes and the current Core gate.
# The former enforces the WFI-042 dated approver grammar; Core allows one note.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FULL_SH="${FULL_SH:-${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-task-state.sh}"
FULL_PS1="${FULL_PS1:-${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-task-state.ps1}"

PASS=0
FAIL=0
ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/reports/quality-gate" "$WORK/reports/implementation"

command -v pwsh >/dev/null || { echo "pwsh is required for parity" >&2; exit 1; }

# write_fixture <dir> <approval-line> [status-line]: a task carrying the forms
# under test. The default status, In Progress, requires a valid approval and
# nothing else, so the checker verdict isolates the grammar decision.
write_fixture() {
    _status="${3:-In Progress}"
    _akey="${4:-Approval}"
    _skey="${5:-Status}"
    _head="${6:-## T-001}"
    mkdir -p "$1"
    printf '# Tasks\n\n%s\n\n%s: %s\n%s: %s\n' \
        "$_head" "$_akey" "$2" "$_skey" "$_status" > "$1/tasks.md"
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
#   - mis-cased-key-* exercise the FIELD-NAME layer, which is separate again.
#     The awk twin selects lines with /^Approval:/ and /^Status:/ -- awk
#     regexes are case-sensitive -- while the ps1 legs used -match on the same
#     anchors. A file writing `approval:` was therefore parsed by the ps1 legs
#     and ignored by awk, which then reported the field missing. Both legs must
#     agree that a mis-cased key is not the field.
run_parity_cases() {
    idx=0
    while IFS='|' read -r name approval status akey skey head expected; do
        [ -z "$name" ] && continue
        idx=$((idx+1))
        dir="$WORK/case-$idx"
        write_fixture "$dir" "$approval" "$status" "$akey" "$skey" "$head"

        full_rc=0
        sh "$FULL_SH" "$dir/tasks.md" "$WORK/reports/quality-gate" "$WORK/reports/implementation" "$WORK" >/dev/null 2>&1 || full_rc=$?
        ps_rc=0
        pwsh -NoProfile -File "$FULL_PS1" "$dir/tasks.md" -ReportsDir "$WORK/reports/quality-gate" -ImplReportsDir "$WORK/reports/implementation" -RepoRoot "$WORK" >/dev/null 2>&1 || ps_rc=$?
        if [ "$full_rc" -ne "$expected" ] || [ "$ps_rc" -ne "$expected" ]; then
            fail "persisted grammar [$name]: sh=$full_rc ps1=$ps_rc expected=$expected"
        else
            ok "persisted grammar [$name]: sh and ps1 returned $expected"
        fi
    done <<'CASES'
bare-approved|Approved|In Progress|Approval|Status|## T-001|0
draft|Draft|In Progress|Approval|Status|## T-001|1
strict-annotated|Approved (alice 2026-08-22T01:02:03Z)|In Progress|Approval|Status|## T-001|0
minutes-precision|Approved (human 2026-08-17T03:35Z)|In Progress|Approval|Status|## T-001|1
fractional-seconds|Approved (sudo 2026-07-13T05:53:16.481Z)|In Progress|Approval|Status|## T-001|1
empty-annotation|Approved ()|In Progress|Approval|Status|## T-001|1
free-text|Approved (waived pending human sign-off)|In Progress|Approval|Status|## T-001|1
mis-cased-annotated|approved (alice 2026-08-22T01:02:03Z)|In Progress|Approval|Status|## T-001|1
mis-cased-bare-lower|approved|In Progress|Approval|Status|## T-001|1
mis-cased-bare-upper|APPROVED|In Progress|Approval|Status|## T-001|1
mis-cased-bare-mixed|ApProVeD|In Progress|Approval|Status|## T-001|1
mis-cased-status-planned|Draft|planned|Approval|Status|## T-001|1
mis-cased-status-inprogress|Approved|in progress|Approval|Status|## T-001|1
mis-cased-key-approval|Approved|In Progress|approval|Status|## T-001|1
mis-cased-key-status|Approved|In Progress|Approval|status|## T-001|1
mis-cased-key-both-upper|Approved|In Progress|APPROVAL|STATUS|## T-001|1
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

if python3 "$REPO_ROOT/tests/lib/core-lifecycle-checks.py" approvals; then
    ok "Core gate approval grammar"
else
    fail "Core gate approval grammar"
fi

if python3 "$REPO_ROOT/tests/lib/task-done-parity.py" "$FULL_SH" "$FULL_PS1"; then
    ok "Done requires the exact task and PASS in its declared report on both hosts"
else
    fail "Done report identity or verdict"
fi

# Exercise awk's real subprocess boundary with hostile path data. The persisted checker must transport values literally.
if python3 - "$FULL_SH" <<'PY'
import json
from pathlib import Path
import subprocess
import sys
import tempfile

with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    odd = root / 'quote\'" $` \\ 日本語\n$(touch SENTINEL)'
    odd.mkdir()
    tasks = odd / 'tasks.md'
    reports = odd / 'reports'
    reports.mkdir()
    (reports / 'impl.md').write_text('T-001\n')
    tasks.write_text('## T-001\nApproval: Approved\nStatus: Implementation Complete\n')
    for script in sys.argv[1:]:
        result = subprocess.run(['sh', script, str(tasks), str(reports), str(reports), str(root)],
            cwd=root, capture_output=True, text=True, timeout=10)
        assert result.returncode == 0, result.stdout + result.stderr
        assert not (root / 'SENTINEL').exists(), 'path data was executed'
    tasks.write_text('## T-001\nApproval: Approved\nStatus: Done\nRisk: low\n')
    (odd / 'verification').mkdir()
    (odd / 'verification/T-001.contract.json').write_text(json.dumps({'task_id': 'T-001', 'risk': 'low'}))
    result = subprocess.run(['sh', sys.argv[1], str(tasks), str(reports), str(reports), str(root)],
        cwd=root, capture_output=True, text=True, timeout=10)
    assert result.returncode == 1, 'absent evidence must still fail closed'
    assert 'mismatched task_id' not in result.stdout, result.stdout
    assert not (root / 'SENTINEL').exists()
PY
then
    ok 'Persisted task-state subprocesses preserve path data and reject absent evidence'
else
    fail 'task-state subprocess data boundary regression'
fi

# Root and discovered report filenames are data, even when brackets form a glob.
mkdir -p "$WORK/impl[x]" "$WORK/implx" "$WORK/qg[x]" "$WORK/qgx"
printf '## T-001\nApproval: Approved\nStatus: Implementation Complete\n' > "$WORK/tasks[x].md"
printf 'unrelated task\n' > "$WORK/impl[x]/report[x].md"
printf 'T-001\n' > "$WORK/implx/reportx.md"
code=0
output="$(pwsh -NoProfile -File "$FULL_PS1" "$WORK/tasks[x].md" "$WORK/qg[x]" "$WORK/impl[x]" "$WORK" 2>&1)" || code=$?
if [ "$code" -eq 1 ]; then ok "$(basename "$FULL_PS1") ignores wildcard sibling report roots";
else fail "$(basename "$FULL_PS1") accepted unrelated literal reports: $code $output"; fi
printf 'T-001\n' > "$WORK/impl[x]/report[x].md"
code=0
output="$(pwsh -NoProfile -File "$FULL_PS1" "$WORK/tasks[x].md" "$WORK/qg[x]" "$WORK/impl[x]" "$WORK" 2>&1)" || code=$?
if [ "$code" -eq 0 ]; then ok "$(basename "$FULL_PS1") reads literal bracket report filenames";
else fail "$(basename "$FULL_PS1") rejected valid literal report: $code $output"; fi
echo ""
echo "task-state-grammar-parity.tests.sh: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
