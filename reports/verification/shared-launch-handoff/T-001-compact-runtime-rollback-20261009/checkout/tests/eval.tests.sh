#!/usr/bin/env bash
# eval.tests.sh — outcome-based eval suite for H-05.
# Runs the REAL deterministic gate scripts against realistic end-to-end scenario
# fixtures and asserts the correct OUTCOME (pass / fail + cause).
# Mirrors the style of tests/guards.tests.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

# Global temp workdir; cleaned on exit.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# Gate wrapper helpers — all capture output+exit without tripping set -e.
# ---------------------------------------------------------------------------
run_check_contract() {
    bash "${SCRIPTS_DIR}/check-contract.sh" "$1" "${2:-.}" 2>&1 || true
}
check_contract_passes() {
    bash "${SCRIPTS_DIR}/check-contract.sh" "$1" "${2:-.}" >/dev/null 2>&1
}

run_check_task_state() {
    bash "${SCRIPTS_DIR}/check-task-state.sh" "$1" "$2" "$3" "$4" 2>&1 || true
}
check_task_state_passes() {
    bash "${SCRIPTS_DIR}/check-task-state.sh" "$1" "$2" "$3" "$4" >/dev/null 2>&1
}

run_check_placeholders() {
    bash "${SCRIPTS_DIR}/check-placeholders.sh" "$@" 2>&1 || true
}
check_placeholders_passes() {
    bash "${SCRIPTS_DIR}/check-placeholders.sh" "$@" >/dev/null 2>&1
}

run_check_bundle() {
    bash "${SCRIPTS_DIR}/check-evidence-bundle.sh" "$1" "$2" 2>&1 || true
}
check_bundle_passes() {
    bash "${SCRIPTS_DIR}/check-evidence-bundle.sh" "$1" "$2" >/dev/null 2>&1
}

run_generate_bundle() {
    bash "${SCRIPTS_DIR}/generate-evidence-bundle.sh" "$1" "$2" "$3" 2>&1 || true
}
generate_bundle_passes() {
    bash "${SCRIPTS_DIR}/generate-evidence-bundle.sh" "$1" "$2" "$3" >/dev/null 2>&1
}

run_check_risk() {
    bash "${SCRIPTS_DIR}/check-risk.sh" "$1" "${2:-}" 2>&1 || true
}
check_risk_passes() {
    bash "${SCRIPTS_DIR}/check-risk.sh" "$1" "${2:-}" >/dev/null 2>&1
}

run_check_traceability() {
    bash "${SCRIPTS_DIR}/check-traceability.sh" "$1" "${2:-.}" "${3:-}" 2>&1 || true
}
check_traceability_passes() {
    bash "${SCRIPTS_DIR}/check-traceability.sh" "$1" "${2:-.}" "${3:-}" >/dev/null 2>&1
}

git_init_and_commit() {
    local repo="$1"
    git -C "$repo" init -q
    git -C "$repo" config user.name  ci
    git -C "$repo" config user.email ci@example.com
    git -C "$repo" config commit.gpgsign false
    git -C "$repo" add -A
    git -C "$repo" commit -q -m "eval fixture initial commit"
}

# ---------------------------------------------------------------------------
# make_clean_project DIR TASK_ID
#
# Builds a complete SDD project tree inside DIR for TASK_ID.
# Layout understood by ALL gate scripts:
#
#   DIR/
#     tasks.md                                      (Status: Done, Approval: Approved)
#     verification/TASK_ID.contract.json            (check-task-state looks HERE)
#     verification/TASK_ID.evidence.json            (written by generate-evidence-bundle)
#     reports/quality-gate/TASK_ID.md               (quality-gate report)
#     reports/implementation/                       (empty; satisfies impl_reports arg)
#     specs/feat-alpha/verification/ev.log          (evidence file for passing checks)
#     src/widget.py                                 (clean source file)
#
# The contract's evidence paths are relative to DIR (repo root), pointing at
#   specs/feat-alpha/verification/ev.log
# The contract file itself is at DIR/verification/TASK_ID.contract.json so that
# check-task-state can find it at <tasks_dir>/verification/<task>.contract.json.
#
# Echoes the contract path.
# ---------------------------------------------------------------------------
make_clean_project() {
    local dir="$1"
    local task_id="${2:-T-001}"
    local feat="feat-alpha"

    mkdir -p "${dir}/verification"
    mkdir -p "${dir}/specs/${feat}/verification"
    mkdir -p "${dir}/reports/quality-gate"
    mkdir -p "${dir}/reports/implementation"
    mkdir -p "${dir}/src"

    # Clean source — no placeholders
    cat > "${dir}/src/widget.py" <<'SRCEOF'
def add(a, b):
    return a + b
SRCEOF

    # Shared evidence log (used by all passing checks)
    printf 'All checks passed.\n' > "${dir}/specs/${feat}/verification/ev.log"

    # Quality-gate report (Task ID + VERDICT: PASS required by check-evidence-bundle)
    cat > "${dir}/reports/quality-gate/${task_id}.md" <<RPTEOF
Task ID: ${task_id}
Feature: ${feat}
VERDICT: PASS

All baseline checks green.
RPTEOF

    # Contract with 6 required baseline checks all passing + 4 optional with waivers.
    # Evidence path is relative to repo root (DIR).
    cat > "${dir}/verification/${task_id}.contract.json" <<CEOF
{
  "task_id": "${task_id}",
  "feature": "${feat}",
  "created": "2026-06-13T00:00:00Z",
  "comment": "Eval suite fixture",
  "checks": [
    { "id": "lint",            "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "typecheck",       "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "unit-tests",      "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "build",           "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "placeholder-scan","required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check","required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "integration-tests","required": false,"passes": false, "evidence": "", "waiver_reason": "not applicable for this task" },
    { "id": "smoke-run",       "required": false, "passes": false, "evidence": "", "waiver_reason": "manual only" },
    { "id": "differential-baseline","required": false,"passes": false,"evidence": "","waiver_reason": "not applicable" },
    { "id": "ui-verification", "required": false, "passes": false, "evidence": "", "waiver_reason": "no UI changes" }
  ]
}
CEOF

    # tasks.md: Done + Approved.  check-task-state derives tasks_dir from this file's
    # parent, then looks for verification/<task>.{contract,evidence}.json there.
    cat > "${dir}/tasks.md" <<TEOF
# Project Tasks

## ${task_id}

Approval: Approved
Status: Done

### Description
Eval fixture task.
TEOF

    printf '%s/verification/%s.contract.json\n' "$dir" "$task_id"
}

# ============================================================================
# SCENARIO 1: clean-pass
# Every gate must exit 0.  Evidence bundle GENERATED via the real script inside
# a git-init fixture so git_commit is a real ancestor of HEAD.
# ============================================================================
echo "=== Scenario: clean-pass ==="

S1="${WORK}/s1-clean-pass"
mkdir -p "$S1"
contract1="$(make_clean_project "$S1" "T-001")"
report1="${S1}/reports/quality-gate/T-001.md"

git_init_and_commit "$S1"

# generate-evidence-bundle writes T-001.evidence.json into the same dir as the contract
if generate_bundle_passes "$contract1" "$report1" "$S1"; then
    ok "clean-pass: generate-evidence-bundle succeeds"
else
    fail "clean-pass: generate-evidence-bundle failed — $(run_generate_bundle "$contract1" "$report1" "$S1")"
fi

bundle1="${S1}/verification/T-001.evidence.json"

if check_contract_passes "$contract1" "$S1"; then
    ok "clean-pass: check-contract PASS"
else
    fail "clean-pass: check-contract should pass — $(run_check_contract "$contract1" "$S1")"
fi

if check_placeholders_passes "${S1}/src"; then
    ok "clean-pass: check-placeholders PASS"
else
    fail "clean-pass: check-placeholders should pass — $(run_check_placeholders "${S1}/src")"
fi

if check_bundle_passes "$bundle1" "$S1"; then
    ok "clean-pass: check-evidence-bundle PASS"
else
    fail "clean-pass: check-evidence-bundle should pass — $(run_check_bundle "$bundle1" "$S1")"
fi

if check_task_state_passes "${S1}/tasks.md" \
        "${S1}/reports/quality-gate" "${S1}/reports/implementation" "$S1"; then
    ok "clean-pass: check-task-state PASS — Done permitted"
else
    fail "clean-pass: check-task-state should pass — $(run_check_task_state "${S1}/tasks.md" "${S1}/reports/quality-gate" "${S1}/reports/implementation" "$S1")"
fi

# ============================================================================
# SCENARIO 2: placeholder-stub
# Source file contains a stub/TODO; check-placeholders must flag it.
# ============================================================================
echo "=== Scenario: placeholder-stub ==="

S2="${WORK}/s2-placeholder-stub"
mkdir -p "$S2"
make_clean_project "$S2" "T-002" >/dev/null

# Inject a placeholder/stub
cat >> "${S2}/src/widget.py" <<'STUBEOF'

def process(x):
    # TODO: implement processing
    pass
STUBEOF

out2="$(run_check_placeholders "${S2}/src")"
if ! check_placeholders_passes "${S2}/src" && echo "$out2" | grep -qi "TODO"; then
    ok "placeholder-stub: check-placeholders FAILS (Done blocked) — mentions TODO"
else
    fail "placeholder-stub: check-placeholders should fail on TODO stub (out='${out2}')"
fi

# ============================================================================
# SCENARIO 3: missing-evidence
# A required check has passes:true but its evidence file is absent.
# check-contract must fail.
# ============================================================================
echo "=== Scenario: missing-evidence ==="

S3="${WORK}/s3-missing-evidence"
mkdir -p "${S3}/verification"
mkdir -p "${S3}/specs/feat-alpha/verification"

# Contract references ev.log — intentionally NOT created
cat > "${S3}/verification/T-003.contract.json" <<'CEOF3'
{
  "task_id": "T-003",
  "feature": "feat-alpha",
  "checks": [
    { "id": "lint",            "required": true, "passes": true, "evidence": "specs/feat-alpha/verification/ev.log", "waiver_reason": "" },
    { "id": "typecheck",       "required": true, "passes": true, "evidence": "specs/feat-alpha/verification/ev.log", "waiver_reason": "" },
    { "id": "unit-tests",      "required": true, "passes": true, "evidence": "specs/feat-alpha/verification/ev.log", "waiver_reason": "" },
    { "id": "build",           "required": true, "passes": true, "evidence": "specs/feat-alpha/verification/ev.log", "waiver_reason": "" },
    { "id": "placeholder-scan","required": true, "passes": true, "evidence": "specs/feat-alpha/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check","required": true, "passes": true, "evidence": "specs/feat-alpha/verification/ev.log", "waiver_reason": "" }
  ]
}
CEOF3

out3="$(run_check_contract "${S3}/verification/T-003.contract.json" "$S3")"
if ! check_contract_passes "${S3}/verification/T-003.contract.json" "$S3" \
   && echo "$out3" | grep -qi "missing"; then
    ok "missing-evidence: check-contract FAILS — mentions missing evidence"
else
    fail "missing-evidence: check-contract should fail on missing evidence file (out='${out3}')"
fi

# ============================================================================
# SCENARIO 4: tampered-evidence
# Generate a valid bundle, then modify an artifact file after generation.
# check-evidence-bundle must detect the sha256 mismatch.
# ============================================================================
echo "=== Scenario: tampered-evidence ==="

S4="${WORK}/s4-tampered-evidence"
mkdir -p "$S4"
contract4="$(make_clean_project "$S4" "T-004")"
report4="${S4}/reports/quality-gate/T-004.md"

git_init_and_commit "$S4"
generate_bundle_passes "$contract4" "$report4" "$S4"
bundle4="${S4}/verification/T-004.evidence.json"

# Tamper: append bytes to evidence file after bundle was sealed
printf '\ntampered content appended\n' >> "${S4}/specs/feat-alpha/verification/ev.log"

out4="$(run_check_bundle "$bundle4" "$S4")"
if ! check_bundle_passes "$bundle4" "$S4" && echo "$out4" | grep -qi "sha256 mismatch"; then
    ok "tampered-evidence: check-evidence-bundle FAILS — mentions sha256 mismatch"
else
    fail "tampered-evidence: check-evidence-bundle should fail on tampered artifact (out='${out4}')"
fi

# ============================================================================
# SCENARIO 5: foreign-commit-evidence
# Valid bundle except git_commit is 40 f's — not in repository history.
# ============================================================================
echo "=== Scenario: foreign-commit-evidence ==="

S5="${WORK}/s5-foreign-commit"
mkdir -p "$S5"
contract5="$(make_clean_project "$S5" "T-005")"
report5="${S5}/reports/quality-gate/T-005.md"

git_init_and_commit "$S5"
generate_bundle_passes "$contract5" "$report5" "$S5"
bundle5="${S5}/verification/T-005.evidence.json"

# Replace git_commit with 40 f's (will never exist in this repo)
python3 - <<PYEOF
import json, pathlib
p = pathlib.Path("${bundle5}")
b = json.loads(p.read_text(encoding="utf-8"))
b["git_commit"] = "f" * 40
p.write_text(json.dumps(b, indent=2) + "\n", encoding="utf-8")
PYEOF

out5="$(run_check_bundle "$bundle5" "$S5")"
if ! check_bundle_passes "$bundle5" "$S5"; then
    ok "foreign-commit-evidence: check-evidence-bundle FAILS (foreign git_commit not in history)"
else
    fail "foreign-commit-evidence: check-evidence-bundle should fail on foreign git_commit (out='${out5}')"
fi

# ============================================================================
# SCENARIO 6: self-approval-blocked
# Agent sends Edit payload adding "Approval: Approved" — no SDD_SUDO present.
# sdd-hook-guard.sh must exit 2 (deny).
# ============================================================================
echo "=== Scenario: self-approval-blocked ==="

S6="${WORK}/s6-self-approval"
mkdir -p "${S6}/specs/x"

APPROVE_PAYLOAD='{"tool_name":"Edit","tool_input":{"file_path":"'"${S6}"'/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'

GUARD_CODE6=0
printf '%s' "$APPROVE_PAYLOAD" | \
    CLAUDE_PROJECT_DIR="${S6}" \
    bash "${SCRIPTS_DIR}/sdd-hook-guard.sh" "--emit" "exit" >/dev/null 2>&1 \
    || GUARD_CODE6=$?

if [[ $GUARD_CODE6 -eq 2 ]]; then
    ok "self-approval-blocked: sdd-hook-guard.sh exits 2 (denied) — no SDD_SUDO"
else
    fail "self-approval-blocked: sdd-hook-guard.sh should exit 2 (got ${GUARD_CODE6})"
fi

# ============================================================================
# SCENARIO 7: done-without-report
# tasks.md: Status: Done + Approval: Approved + contract present, but the
# quality-gate report does NOT mention the task ID (wrong Task ID: line).
# check-task-state must fail because check-evidence-bundle will reject the
# report (missing "Task ID: T-007" line).
# ============================================================================
echo "=== Scenario: done-without-report ==="

S7="${WORK}/s7-done-without-report"
mkdir -p "$S7"
contract7="$(make_clean_project "$S7" "T-007")"
report7="${S7}/reports/quality-gate/T-007.md"

# Overwrite report: wrong task ID — T-007 never mentioned
cat > "$report7" <<'RPTEOF7'
# Quality Gate Report

Task ID: T-999
VERDICT: PASS

This report belongs to a different task.
RPTEOF7

git_init_and_commit "$S7"

# generate-evidence-bundle validates the report before generating;
# it will fail because Task ID: T-007 is absent.
gen_out7="$(run_generate_bundle "$contract7" "$report7" "$S7")"
bundle7="${S7}/verification/T-007.evidence.json"

if [ ! -f "$bundle7" ]; then
    # Expected: bundle was not created because the report failed validation.
    # check-task-state will fail on "evidence.json does not exist".
    out7="$(run_check_task_state "${S7}/tasks.md" \
        "${S7}/reports/quality-gate" "${S7}/reports/implementation" "$S7")"
    if ! check_task_state_passes "${S7}/tasks.md" \
            "${S7}/reports/quality-gate" "${S7}/reports/implementation" "$S7"; then
        ok "done-without-report: check-task-state FAILS — Done blocked (no valid quality report)"
    else
        fail "done-without-report: check-task-state should fail (out='${out7}')"
    fi
else
    # If bundle was somehow created, validate the state check still fails
    out7="$(run_check_task_state "${S7}/tasks.md" \
        "${S7}/reports/quality-gate" "${S7}/reports/implementation" "$S7")"
    if ! check_task_state_passes "${S7}/tasks.md" \
            "${S7}/reports/quality-gate" "${S7}/reports/implementation" "$S7"; then
        ok "done-without-report: check-task-state FAILS — Done blocked (report/bundle mismatch)"
    else
        fail "done-without-report: check-task-state should fail (out='${out7}')"
    fi
fi

# ============================================================================
# SCENARIO 8: optional-check-no-waiver
# An optional check has passes:false but waiver_reason is empty.
# check-contract must fail and mention waiver_reason.
# ============================================================================
echo "=== Scenario: optional-check-no-waiver ==="

S8="${WORK}/s8-optional-no-waiver"
mkdir -p "${S8}/specs/feat-alpha/verification"
printf 'evidence output\n' > "${S8}/specs/feat-alpha/verification/ev.log"

cat > "${S8}/T-008.contract.json" <<'CEOF8'
{
  "task_id": "T-008",
  "feature": "feat-alpha",
  "checks": [
    { "id": "lint",            "required": true,  "passes": true,  "evidence": "specs/feat-alpha/verification/ev.log", "waiver_reason": "" },
    { "id": "typecheck",       "required": true,  "passes": true,  "evidence": "specs/feat-alpha/verification/ev.log", "waiver_reason": "" },
    { "id": "unit-tests",      "required": true,  "passes": true,  "evidence": "specs/feat-alpha/verification/ev.log", "waiver_reason": "" },
    { "id": "build",           "required": true,  "passes": true,  "evidence": "specs/feat-alpha/verification/ev.log", "waiver_reason": "" },
    { "id": "placeholder-scan","required": true,  "passes": true,  "evidence": "specs/feat-alpha/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check","required": true,  "passes": true,  "evidence": "specs/feat-alpha/verification/ev.log", "waiver_reason": "" },
    { "id": "integration-tests","required": false,"passes": false, "evidence": "", "waiver_reason": "" }
  ]
}
CEOF8

out8="$(run_check_contract "${S8}/T-008.contract.json" "$S8")"
if ! check_contract_passes "${S8}/T-008.contract.json" "$S8" \
   && echo "$out8" | grep -qi "waiver_reason"; then
    ok "optional-check-no-waiver: check-contract FAILS — mentions waiver_reason"
else
    fail "optional-check-no-waiver: check-contract should fail on optional passes=false + empty waiver_reason (out='${out8}')"
fi

# ============================================================================
# SCENARIO 9: risk-tiered (check-risk + check-traceability, pass + adversarial)
# A high-risk task must declare Required Workflow: tdd and carry a complete
# REQ -> AC -> TEST traceability chain. Exercises both gates end-to-end and
# their fail-closed paths.
# ============================================================================
echo "=== Scenario: risk-tiered ==="

S9="${WORK}/s9-risk-tiered"
mkdir -p "$S9"

# (a) high task WITH Required Workflow: tdd -> check-risk passes
cat > "${S9}/tasks.md" <<'TEOF'
# Project Tasks

## T-009

Risk: high
Risk Rationale: touches the evidence-signing path
Required Workflow: tdd
Status: Planned
TEOF
if check_risk_passes "${S9}/tasks.md"; then
    ok "risk-tiered: high task with Required Workflow: tdd passes check-risk"
else
    fail "risk-tiered: high+tdd should pass check-risk — $(run_check_risk "${S9}/tasks.md")"
fi

# (b) ADVERSARIAL: same task with the workflow line removed -> check-risk fails closed
cat > "${S9}/tasks-bad.md" <<'TEOF'
# Project Tasks

## T-009

Risk: high
Risk Rationale: touches the evidence-signing path
Status: Planned
TEOF
out9a="$(run_check_risk "${S9}/tasks-bad.md")"
if ! check_risk_passes "${S9}/tasks-bad.md" && echo "$out9a" | grep -q "Required Workflow: tdd"; then
    ok "risk-tiered: high task missing tdd workflow fails check-risk (fail-closed)"
else
    fail "risk-tiered: high without tdd workflow must fail check-risk (out='${out9a}')"
fi

# (c) complete traceability chain REQ -> AC -> TEST -> evidence -> check-traceability passes
printf 'test ran\n' > "${S9}/ev.log"
cat > "${S9}/traceability.json" <<'JEOF'
{
  "feature": "feat-risk",
  "links": [
    { "req": "REQ-001", "acs": ["AC-001"], "tests": ["TEST-001"], "evidence": ["ev.log"] }
  ]
}
JEOF
if check_traceability_passes "${S9}/traceability.json" "$S9" "require-evidence"; then
    ok "risk-tiered: complete REQ->AC->TEST->evidence chain passes check-traceability"
else
    fail "risk-tiered: complete chain should pass check-traceability — $(run_check_traceability "${S9}/traceability.json" "$S9" "require-evidence")"
fi

# (d) ADVERSARIAL: a link with an empty tests array -> check-traceability fails closed
cat > "${S9}/traceability-bad.json" <<'JEOF'
{
  "feature": "feat-risk",
  "links": [
    { "req": "REQ-001", "acs": ["AC-001"], "tests": [], "evidence": ["ev.log"] }
  ]
}
JEOF
out9b="$(run_check_traceability "${S9}/traceability-bad.json" "$S9")"
if ! check_traceability_passes "${S9}/traceability-bad.json" "$S9" && echo "$out9b" | grep -qi "no tests"; then
    ok "risk-tiered: link with empty tests array fails check-traceability (fail-closed)"
else
    fail "risk-tiered: empty tests array must fail check-traceability (out='${out9b}')"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed."
if [ "${FAIL}" -eq 0 ]; then
    exit 0
else
    exit 1
fi
