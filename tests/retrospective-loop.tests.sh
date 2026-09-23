#!/usr/bin/env bash
# Workflow retrospective prompt, templates, and WFI audit checks must stay aligned.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/plugins/sdd-quality-loop/skills/workflow-retrospective/SKILL.md"
REPORT_TEMPLATE="$ROOT/plugins/sdd-quality-loop/templates/retrospective-report.template.md"
WFI_TEMPLATE="$ROOT/plugins/sdd-quality-loop/templates/workflow-improvement.template.md"
AUDITOR_A="$ROOT/plugins/sdd-quality-loop/agents/wfi-auditor-a.md"
AUDITOR_B="$ROOT/plugins/sdd-quality-loop/agents/wfi-auditor-b.md"
AUDIT_CYCLE="$ROOT/plugins/sdd-quality-loop/skills/wfi-audit-cycle/SKILL.md"

fail() { printf 'not ok: %s\n' "$1" >&2; exit 1; }

for section in \
  'Sample Size' \
  'Data Completeness' \
  'Confidence' \
  '## Improvement Verification Plan' \
  '## Review Gate Metrics' \
  'Task Attempts' \
  'Review Rounds' \
  'Quality-Gate Runs' \
  'Model Escalations' \
  'Repeat Finding Rate' \
  'WFI Verification Rate'; do
  grep -Fq "$section" "$SKILL" || fail "workflow-retrospective skill missing ${section}"
  grep -Fq "$section" "$REPORT_TEMPLATE" || fail "retrospective template missing ${section}"
done

grep -Fq 'Do not draft a WFI from a single-task observation' "$SKILL" || \
  fail "retrospective must guard against one-off overfitting"
for derivation in \
  'Task Attempts — read `Task Attempt Count`' \
  'Review Rounds — count independent review rounds' \
  'Quality-Gate Runs — count quality-gate reports' \
  'Model Escalations — count complete escalation transitions' \
  'Legacy implementation reports without these additive fields contribute `N/A`'; do
  grep -Fq "$derivation" "$SKILL" ||
    fail "workflow-retrospective skill missing metric derivation: $derivation"
done
for deterministic_rule in \
  'lexicographically smallest canonical path' \
  'greatest numeric `Task Attempt Count`' \
  'reports/implementation/<feature>/T-NNN-review-<positive integer>.md' \
  'De-duplicate on `(task ID, Run ID)`' \
  'Conflicting reasons for one de-duplication key make Data' \
  'filesystem iteration'; do
  grep -Fq "$deterministic_rule" "$SKILL" ||
    fail "workflow-retrospective skill missing deterministic rule: $deterministic_rule"
done

# Fixture-backed derivation proves that selection, association, ordering, and
# de-duplication produce exact counts rather than merely exposing metric names.
METRIC_WORK="$(mktemp -d)"
trap 'rm -rf "$METRIC_WORK"' EXIT
mkdir -p \
  "$METRIC_WORK/reports/implementation/demo" \
  "$METRIC_WORK/reports/quality-gate/archive"

write_impl_fixture() {
  file="$1"
  attempt="$2"
  run="$3"
  escalation_attempt="${4:-None}"
  prior="${5:-None}"
  next="${6:-None}"
  failure="${7:-None}"
  reason="${8:-None}"
  cat > "$file" <<EOF
# Implementation Report: T-101
Report Schema: implementation-report/v2
- **Task Attempt Count**: $attempt
- **Run ID**: $run
- **Escalation Prior Tier**: $prior
- **Escalation Next Tier**: $next
- **Escalation Failure Class**: $failure
- **Escalation Attempt Number**: $escalation_attempt
- **Escalation Reason**: $reason
EOF
}

write_review_fixture() {
  file="$1"
  run="$2"
  escalation_attempt="${3:-None}"
  prior="${4:-None}"
  next="${5:-None}"
  failure="${6:-None}"
  reason="${7:-None}"
  cat > "$file" <<EOF
# Independent Implementation Review
Task: T-101
Run ID: $run
- **Escalation Prior Tier**: $prior
- **Escalation Next Tier**: $next
- **Escalation Failure Class**: $failure
- **Escalation Attempt Number**: $escalation_attempt
- **Escalation Reason**: $reason
EOF
}

write_gate_fixture() {
  file="$1"
  run="$2"
  escalation_attempt="${3:-None}"
  prior="${4:-None}"
  next="${5:-None}"
  failure="${6:-None}"
  reason="${7:-None}"
  cat > "$file" <<EOF
# Quality Gate
Task: T-101
Run ID: $run
- **Escalation Prior Tier**: $prior
- **Escalation Next Tier**: $next
- **Escalation Failure Class**: $failure
- **Escalation Attempt Number**: $escalation_attempt
- **Escalation Reason**: $reason
EOF
}

write_impl_fixture \
  "$METRIC_WORK/reports/implementation/demo/T-101.md" \
  1 run-001
write_impl_fixture \
  "$METRIC_WORK/reports/implementation/demo/T-101-attempt-2.md" \
  3 run-003 2 lightweight standard review-major repeated-review-major
# Same run and values: canonical-path de-duplication retains attempt-2.
write_impl_fixture \
  "$METRIC_WORK/reports/implementation/demo/T-101-attempt-3.md" \
  3 run-003 2 lightweight standard review-major repeated-review-major
# Lower cumulative attempt count cannot become "latest" merely from its suffix.
write_impl_fixture \
  "$METRIC_WORK/reports/implementation/demo/T-101-attempt-4.md" \
  2 run-004
# Equal attempt count loses the documented Run ID tie-break.
write_impl_fixture \
  "$METRIC_WORK/reports/implementation/demo/T-101-attempt-5.md" \
  3 run-002

write_review_fixture \
  "$METRIC_WORK/reports/implementation/demo/T-101-review-1.md" \
  review-run-001 2 lightweight standard review-major repeated-review-major
write_review_fixture \
  "$METRIC_WORK/reports/implementation/demo/T-101-review-2.md" \
  review-run-002 3 standard strong review-major repeated-review-major

write_gate_fixture \
  "$METRIC_WORK/reports/quality-gate/gate-a.md" \
  qg-run-001
write_gate_fixture \
  "$METRIC_WORK/reports/quality-gate/gate-b.md" \
  qg-run-002 3 standard strong review-major repeated-review-major
# A copied quality-gate artifact with the same run is one run, not two.
write_gate_fixture \
  "$METRIC_WORK/reports/quality-gate/archive/gate-b-copy.md" \
  qg-run-002 3 standard strong review-major repeated-review-major
# An unrelated task must not be associated from directory proximity.
sed 's/T-101/T-999/' \
  "$METRIC_WORK/reports/quality-gate/gate-a.md" \
  > "$METRIC_WORK/reports/quality-gate/unrelated.md"

python3 - "$METRIC_WORK" "$SKILL" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
task = "T-101"

# RT-20260821-017: the selection/tie-break/de-dup directions are PARSED from
# the real SKILL.md instead of being re-implemented as constants, so editing
# the production document's algorithm (e.g. inverting "smallest" to
# "greatest") changes this engine's behavior and fails the hardcoded
# expectations below. Previously this block never opened any repository file
# and passed in an empty directory.
skill_text = pathlib.Path(sys.argv[2]).read_text()

def rule_direction(pattern):
    match = re.search(pattern, skill_text, re.S)
    assert match, f"SKILL.md lost the pinned rule: {pattern}"
    return match.group(1)

DEDUP_PATH_DIR = rule_direction(
    r"De-duplicate candidates with the same `\(task ID, Run ID\)` by\s+"
    r"retaining the lexicographically (smallest|greatest) canonical path\.\s+Select")
ATTEMPT_DIR = rule_direction(
    r"Select the current\s+task report by the (greatest|smallest) numeric `Task Attempt Count`")
TIE_RUN_DIR = rule_direction(
    r"break a tie by the\s+lexicographically (greatest|smallest) `Run ID`")
TIE_PATH_DIR = rule_direction(
    r"`Run ID`, then the lexicographically (smallest|greatest)\s+canonical path")
impl_root = root / "reports/implementation/demo"

def one(pattern, text):
    matches = re.findall(pattern, text, re.MULTILINE)
    if len(matches) != 1:
        raise AssertionError((pattern, matches))
    return matches[0]

def transition(path, text):
    fields = (
        "Escalation Prior Tier",
        "Escalation Next Tier",
        "Escalation Failure Class",
        "Escalation Attempt Number",
        "Escalation Reason",
    )
    values = {
        field: one(rf"^- \*\*{re.escape(field)}\*\*: ([^\n]+)$", text)
        for field in fields
    }
    if all(value == "None" for value in values.values()):
        return None
    return (
        task,
        int(values["Escalation Attempt Number"]),
        values["Escalation Prior Tier"],
        values["Escalation Next Tier"],
        values["Escalation Failure Class"],
        values["Escalation Reason"],
        path.as_posix(),
    )

impl_pattern = re.compile(r"(T-\d{3})(?:-attempt-([1-9]\d*))?\.md")
implementation = []
for path in sorted(impl_root.glob("*.md")):
    match = impl_pattern.fullmatch(path.name)
    if not match or match.group(1) != task:
        continue
    text = path.read_text()
    assert one(r"^# Implementation Report: (T-\d{3})$", text) == task
    implementation.append({
        "path": path,
        "run": one(r"^- \*\*Run ID\*\*: ([^\n]+)$", text),
        "attempt": int(one(r"^- \*\*Task Attempt Count\*\*: ([1-9]\d*)$", text)),
        "text": text,
    })

by_run = {}
for record in implementation:
    existing = by_run.get(record["run"])
    if existing is None:
        by_run[record["run"]] = record
    else:
        pick = min if DEDUP_PATH_DIR == "smallest" else max
        by_run[record["run"]] = pick(
            existing, record, key=lambda item: item["path"].as_posix())
retained_impl = list(by_run.values())
def _lex_key(value, direction):
    # For use inside a max(): "greatest" keeps the natural ordering,
    # "smallest" inverts it so max() picks the lexicographically smallest.
    if direction == "greatest":
        return tuple(ord(char) for char in value)
    return tuple(-ord(char) for char in value)

selected = max(
    retained_impl,
    key=lambda record: (
        record["attempt"] if ATTEMPT_DIR == "greatest" else -record["attempt"],
        _lex_key(record["run"], TIE_RUN_DIR),
        _lex_key(record["path"].as_posix(), TIE_PATH_DIR),
    ),
)
assert selected["path"].name == "T-101-attempt-2.md"

review_pattern = re.compile(r"(T-\d{3})-review-([1-9]\d*)\.md")
reviews = {}
for path in sorted(impl_root.glob("*.md")):
    match = review_pattern.fullmatch(path.name)
    if not match or match.group(1) != task:
        continue
    text = path.read_text()
    assert one(r"^Task: (T-\d{3})$", text) == task
    reviews.setdefault(int(match.group(2)), (path, text))
assert sorted(reviews) == [1, 2]

gates = {}
for path in sorted((root / "reports/quality-gate").rglob("*.md")):
    text = path.read_text()
    identities = re.findall(r"^Task: (T-\d{3})$", text, re.MULTILINE)
    if identities != [task]:
        continue
    run = one(r"^Run ID: ([^\n]+)$", text)
    gates.setdefault(run, (path, text))
assert sorted(gates) == ["qg-run-001", "qg-run-002"]

evidence = [
    (record["path"], record["text"]) for record in retained_impl
] + list(reviews.values()) + list(gates.values())
escalations = {}
for path, text in sorted(evidence, key=lambda item: item[0].as_posix()):
    record = transition(path, text)
    if record is None:
        continue
    key = record[:5]
    reason = record[5]
    if key in escalations:
        assert escalations[key][0] == reason
        continue
    escalations[key] = (reason, record[6])
assert sorted(key[1] for key in escalations) == [2, 3]

actual = {
    "task_attempts": selected["attempt"],
    "review_rounds": len(reviews),
    "quality_gate_runs": len(gates),
    "model_escalations": len(escalations),
}
expected = {
    "task_attempts": 3,
    "review_rounds": 2,
    "quality_gate_runs": 2,
    "model_escalations": 2,
}
assert actual == expected, (actual, expected)
print("ok: retrospective fixture derives exact counts 3/2/2/2")
PY

grep -Fq 'Verified`: target met' "$SKILL" || fail "retrospective must classify WFI verification result"
grep -Fq 'Needs-Followup' "$SKILL" || fail "retrospective must support follow-up result"
grep -Fq 'Rejected' "$SKILL" || fail "retrospective must support rejected result"

grep -Fq '## Verification Metric' "$WFI_TEMPLATE" || fail "WFI template must include verification metric"
grep -Fq '## Verification Metric' "$SKILL" || fail "workflow-retrospective WFI draft must include verification metric"
grep -Fq '{{review_contract_count}} review contracts' "$REPORT_TEMPLATE" || fail "retrospective template must report review contract sample size"
# gate seq 856 (Major 1): these two rows were pinned with `grep -Fq` on the
# bare phrase, and "Spec Review Rounds" also occurs in the per-feature table
# header further down the same template. Deleting the `| Avg Spec Review Rounds
# |` METRIC row therefore left both this suite and the Pester twin green --
# measured, not inferred. A metric column is only pinned if deleting it reddens
# something, so pin every row of the comparison table as a whole line: label,
# both placeholders and the trend cell together.
retrospective_metric_rows() {
  cat <<'METRIC_ROWS'
| Avg QG Cycles per Task | {{prev_avg_qg}} | {{curr_avg_qg}} | {{trend}} |
| Avg Task Attempts | {{prev_task_attempts}} | {{curr_task_attempts}} | {{trend}} |
| Avg Review Rounds | {{prev_review_rounds}} | {{curr_review_rounds}} | {{trend}} |
| Avg Quality-Gate Runs | {{prev_quality_gate_runs}} | {{curr_quality_gate_runs}} | {{trend}} |
| Total Model Escalations | {{prev_model_escalations}} | {{curr_model_escalations}} | {{trend}} |
| Total Blocked Count | {{prev_blocked}} | {{curr_blocked}} | {{trend}} |
| Total Review Tickets | {{prev_tickets}} | {{curr_tickets}} | {{trend}} |
| Auto-fix Rate | {{prev_autofix_pct}} | {{curr_autofix_pct}} | {{trend}} |
| Avg Spec Review Rounds | {{prev_spec_review_rounds}} | {{curr_spec_review_rounds}} | {{trend}} |
| Spec Review Blocked Rate | {{prev_spec_review_blocked}} | {{curr_spec_review_blocked}} | {{trend}} |
| Avg Task Review Rounds | {{prev_task_review_rounds}} | {{curr_task_review_rounds}} | {{trend}} |
| Task Review Blocked Rate | {{prev_task_review_blocked}} | {{curr_task_review_blocked}} | {{trend}} |
| Avg Impl Review Rounds | {{prev_impl_review_rounds}} | {{curr_impl_review_rounds}} | {{trend}} |
| Impl Review Blocked Rate | {{prev_impl_review_blocked}} | {{curr_impl_review_blocked}} | {{trend}} |
| Impl Legacy Design Rate | {{prev_legacy_design_rate}} | {{curr_legacy_design_rate}} | {{trend}} |
| Repeat Finding Rate | {{prev_repeat_finding_rate}} | {{curr_repeat_finding_rate}} | {{trend}} |
| WFI Verification Rate | {{prev_wfi_verification_rate}} | {{curr_wfi_verification_rate}} | {{trend}} |
METRIC_ROWS
}

metric_row_total=0
while IFS= read -r metric_row; do
  [ -n "$metric_row" ] || continue
  metric_row_total=$((metric_row_total + 1))
  grep -Fxq "$metric_row" "$REPORT_TEMPLATE" ||
    fail "retrospective template lost the comparison-table row: $metric_row"
done <<EOF_METRIC_ROWS
$(retrospective_metric_rows)
EOF_METRIC_ROWS

[ "$metric_row_total" -eq 17 ] ||
  fail "retrospective metric-row pin covers $metric_row_total rows, expected 17"

# The rows must stay ONE contiguous table, so a row cannot be "kept" by moving
# it somewhere inert, and a new row cannot be added without updating the pin.
metric_block_span=$(grep -n '^| .* | {{prev_.*}} | {{curr_.*}} | {{trend}} |$' "$REPORT_TEMPLATE" |
  awk -F: 'NR == 1 { first = $1 } { last = $1; n++ } END { print last - first + 1, n }')
[ "$metric_block_span" = "17 17" ] ||
  fail "retrospective comparison table is no longer 17 contiguous rows (got: $metric_block_span)"
grep -Fq 'VERIFICATION-METRIC-DEFINED' "$AUDITOR_A" || fail "auditor A must check verification metric"
grep -Fq 'Current baseline and target' "$AUDITOR_B" || fail "auditor B must check baseline and target"
grep -Fq 'proposed_revisions' "$AUDITOR_A" || fail "auditor A must return structured proposed revisions"
grep -Fq 'proposed_revisions' "$AUDITOR_B" || fail "auditor B must return structured proposed revisions"
grep -Fq 'proposed_revisions' "$AUDIT_CYCLE" || fail "audit cycle must consume structured proposed revisions"
grep -Fq '"auditor_a_pass_count": 9' "$AUDITOR_B" || fail "auditor B schema example must match auditor A check count"
grep -Fq 'VERIFICATION-METRIC-DEFINED' "$AUDIT_CYCLE" || fail "audit cycle summary must include new auditor A check"
grep -Fq '"auditor_a_pass_count": 9' "$AUDIT_CYCLE" || fail "audit cycle example pass count must match auditor A check count"

# Why-why (5 Whys) root-cause analysis must stay wired through the whole WFI flow:
# template section, drafting instruction, auditor check, and audit-cycle bridge.
grep -Fq '## Why-Why Analysis' "$WFI_TEMPLATE" || fail "WFI template must include why-why analysis section"
grep -Fq '## Why-Why Analysis' "$SKILL" || fail "workflow-retrospective WFI draft must include why-why analysis section"
grep -Fq 'Run the why-why analysis' "$SKILL" || fail "workflow-retrospective must instruct running the why-why analysis before drafting the root cause"
grep -Fq 'WHY-CHAIN-VALID' "$AUDITOR_A" || fail "auditor A must validate the why-why chain"
grep -Fq 'WHY-CHAIN-VALID' "$AUDIT_CYCLE" || fail "audit cycle summary must include the why-chain check"
grep -Fq 'process/mechanism cause' "$AUDITOR_A" || fail "auditor A why-chain check must require a controllable process/mechanism terminal cause"

printf 'ok: retrospective loop prompts and templates are synchronized\n'
