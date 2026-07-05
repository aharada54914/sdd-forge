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

python3 - "$METRIC_WORK" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
task = "T-101"
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
    by_run.setdefault(record["run"], record)
retained_impl = list(by_run.values())
selected = max(
    retained_impl,
    key=lambda record: (
        record["attempt"],
        record["run"],
        tuple(-ord(char) for char in record["path"].as_posix()),
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
grep -Fq 'Spec Review Rounds' "$REPORT_TEMPLATE" || fail "retrospective template must include spec review rounds"
grep -Fq 'Spec Review Blocked Rate' "$REPORT_TEMPLATE" || fail "retrospective template must compare spec review blocked rate"
grep -Fq 'VERIFICATION-METRIC-DEFINED' "$AUDITOR_A" || fail "auditor A must check verification metric"
grep -Fq 'Current baseline and target' "$AUDITOR_B" || fail "auditor B must check baseline and target"
grep -Fq 'proposed_revisions' "$AUDITOR_A" || fail "auditor A must return structured proposed revisions"
grep -Fq 'proposed_revisions' "$AUDITOR_B" || fail "auditor B must return structured proposed revisions"
grep -Fq 'proposed_revisions' "$AUDIT_CYCLE" || fail "audit cycle must consume structured proposed revisions"
grep -Fq '"auditor_a_pass_count": 8' "$AUDITOR_B" || fail "auditor B schema example must match auditor A check count"
grep -Fq 'VERIFICATION-METRIC-DEFINED' "$AUDIT_CYCLE" || fail "audit cycle summary must include new auditor A check"
grep -Fq '"auditor_a_pass_count": 8' "$AUDIT_CYCLE" || fail "audit cycle example pass count must match auditor A check count"

printf 'ok: retrospective loop prompts and templates are synchronized\n'
