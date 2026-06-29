#!/usr/bin/env bash
# scenario.tests.sh — cross-runtime end-to-end scenario suite.
# Covers:
#   A.  Full-chain multi-tier lifecycle (T-101 low/docs, T-102 high/tdd, T-103 critical).
#   B1. Hook contract for all 3 CLI forms (Claude Code, Codex, Copilot) + drift guard.
#   E.  Critical signing round-trip (ephemeral key, generate => pass; tamper => fail).
#
# House style mirrors eval.tests.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts"
HOOKS_DIR="${REPO_ROOT}/plugins/sdd-quality-loop/hooks"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# Gate wrapper helpers (same idiom as eval.tests.sh)
# ---------------------------------------------------------------------------
run_check_risk() {
    bash "${SCRIPTS_DIR}/check-risk.sh" "$1" "${2:-}" 2>&1 || true
}
check_risk_passes() {
    bash "${SCRIPTS_DIR}/check-risk.sh" "$1" "${2:-}" >/dev/null 2>&1
}

run_check_contract() {
    bash "${SCRIPTS_DIR}/check-contract.sh" "$1" "${2:-.}" 2>&1 || true
}
check_contract_passes() {
    bash "${SCRIPTS_DIR}/check-contract.sh" "$1" "${2:-.}" >/dev/null 2>&1
}

run_check_traceability() {
    bash "${SCRIPTS_DIR}/check-traceability.sh" "$1" "${2:-.}" "${3:-}" 2>&1 || true
}
check_traceability_passes() {
    bash "${SCRIPTS_DIR}/check-traceability.sh" "$1" "${2:-.}" "${3:-}" >/dev/null 2>&1
}

run_check_task_state() {
    bash "${SCRIPTS_DIR}/check-task-state.sh" "$1" "$2" "$3" "$4" 2>&1 || true
}
check_task_state_passes() {
    bash "${SCRIPTS_DIR}/check-task-state.sh" "$1" "$2" "$3" "$4" >/dev/null 2>&1
}

run_generate_bundle() {
    bash "${SCRIPTS_DIR}/generate-evidence-bundle.sh" "$1" "$2" "$3" 2>&1 || true
}
generate_bundle_passes() {
    bash "${SCRIPTS_DIR}/generate-evidence-bundle.sh" "$1" "$2" "$3" >/dev/null 2>&1
}

run_check_bundle() {
    bash "${SCRIPTS_DIR}/check-evidence-bundle.sh" "$1" "$2" 2>&1 || true
}
check_bundle_passes() {
    bash "${SCRIPTS_DIR}/check-evidence-bundle.sh" "$1" "$2" >/dev/null 2>&1
}

git_init_and_commit() {
    local repo="$1"
    git -C "$repo" init -q
    git -C "$repo" config user.name  ci
    git -C "$repo" config user.email ci@example.com
    git -C "$repo" config commit.gpgsign false
    git -C "$repo" add -A
    git -C "$repo" commit -q -m "scenario fixture initial commit"
}

# ===========================================================================
# SCENARIO A: FULL-CHAIN MULTI-TIER LIFECYCLE
#
# Project tree holds THREE tasks (task ids must match T-\d+):
#   T-101  Risk: low,      stack: docs  (compile checks waivable)
#   T-102  Risk: high,     stack: code, Required Workflow: tdd
#           + complete REQ->AC->TEST->evidence traceability.json
#   T-103  Risk: critical, stack: code
#
# Lifecycle assertions:
#   check-risk        pass / fail-closed on missing Required Workflow: tdd
#   check-contract    pass; docs stack waives compile checks; fail on passes:false+empty waiver
#   check-traceability pass complete chain; fail-closed empty tests[]
#   check-task-state  blocks Done while Approval: Draft; passes non-critical Done+Approved;
#                     blocks critical Done without distinct second approver; blocks 'sudo'
#   generate-evidence-bundle + check-evidence-bundle succeed for high task
# ===========================================================================
echo "=== Scenario A: full-chain multi-tier lifecycle ==="

SA="${WORK}/sa-lifecycle"
feat="feat-multi"
mkdir -p "${SA}/verification"
mkdir -p "${SA}/specs/${feat}/verification"
mkdir -p "${SA}/specs/${feat}"
mkdir -p "${SA}/reports/quality-gate"
mkdir -p "${SA}/reports/implementation"
mkdir -p "${SA}/src"

# Shared evidence log
printf 'All checks passed.\n' > "${SA}/specs/${feat}/verification/ev.log"
# Red/green TDD evidence for T-102
printf 'RED: test_payment FAILED\n'  > "${SA}/specs/${feat}/verification/tdd-red.log"
printf 'GREEN: test_payment PASSED\n' > "${SA}/specs/${feat}/verification/tdd-green.log"
# Clean source
printf 'def add(a, b):\n    return a + b\n' > "${SA}/src/widget.py"

# ---- A.1: check-risk passes for the well-formed tasks.md ----
echo "--- A.1: check-risk passes ---"

cat > "${SA}/tasks.md" <<TEOF
# Project Tasks

## T-101

Risk: low
Risk Rationale: documentation only, no runtime code
Status: Planned
Approval: Draft

## T-102

Risk: high
Risk Rationale: touches the payment processing path
Required Workflow: tdd
Status: Planned
Approval: Draft

## T-103

Risk: critical
Risk Rationale: signs and verifies evidence bundles for critical tasks
Required Workflow: tdd
Status: Planned
Approval: Draft
TEOF

if check_risk_passes "${SA}/tasks.md"; then
    ok "A.1: check-risk passes for well-formed three-task tasks.md"
else
    fail "A.1: check-risk should pass — $(run_check_risk "${SA}/tasks.md")"
fi

# ---- A.2: check-risk fails-closed when T-102 drops 'Required Workflow: tdd' ----
echo "--- A.2: check-risk fails-closed on missing Required Workflow ---"

cat > "${SA}/tasks-no-tdd.md" <<TEOF
# Project Tasks

## T-101

Risk: low
Risk Rationale: documentation only, no runtime code
Status: Planned
Approval: Draft

## T-102

Risk: high
Risk Rationale: touches the payment processing path
Status: Planned
Approval: Draft

## T-103

Risk: critical
Risk Rationale: signs and verifies evidence bundles for critical tasks
Required Workflow: tdd
Status: Planned
Approval: Draft
TEOF

out_a2="$(run_check_risk "${SA}/tasks-no-tdd.md")"
if ! check_risk_passes "${SA}/tasks-no-tdd.md" && echo "$out_a2" | grep -q "Required Workflow: tdd"; then
    ok "A.2: check-risk fails-closed when T-102 drops Required Workflow: tdd"
else
    fail "A.2: check-risk should fail when T-102 drops Required Workflow: tdd (out='${out_a2}')"
fi

# --- T-101 contract (low risk, docs stack — compile checks waived with waiver_reason)
# Baseline set {lint,typecheck,unit-tests,build,placeholder-scan,task-state-check} must ALL be
# present; non-code stack allows them to be required:false if a waiver_reason is provided.
cat > "${SA}/verification/T-101.contract.json" <<CEOF
{
  "task_id": "T-101",
  "feature": "${feat}",
  "risk": "low",
  "stack": "docs",
  "created": "2026-06-14T00:00:00Z",
  "checks": [
    { "id": "lint",             "required": false, "passes": false, "evidence": "", "waiver_reason": "docs stack — no linter applicable" },
    { "id": "typecheck",        "required": false, "passes": false, "evidence": "", "waiver_reason": "docs stack — no type checker applicable" },
    { "id": "build",            "required": false, "passes": false, "evidence": "", "waiver_reason": "docs stack — no build step applicable" },
    { "id": "unit-tests",       "required": false, "passes": false, "evidence": "", "waiver_reason": "docs stack — no unit tests applicable" },
    { "id": "placeholder-scan", "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" }
  ]
}
CEOF

# ---- A.3: check-contract passes T-101 (docs stack, compile checks waived) ----
echo "--- A.3: check-contract passes T-101 with docs stack ---"

if check_contract_passes "${SA}/verification/T-101.contract.json" "$SA"; then
    ok "A.3: check-contract passes T-101 (docs stack, compile checks waived with waiver_reason)"
else
    fail "A.3: check-contract should pass T-101 — $(run_check_contract "${SA}/verification/T-101.contract.json" "$SA")"
fi

# --- T-102 contract (high risk, code stack, required_workflow: tdd) ---
cat > "${SA}/verification/T-102.contract.json" <<CEOF
{
  "task_id": "T-102",
  "feature": "${feat}",
  "risk": "high",
  "stack": "code",
  "required_workflow": "tdd",
  "created": "2026-06-14T00:00:00Z",
  "checks": [
    { "id": "lint",                    "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "typecheck",               "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "unit-tests",              "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log",
      "red_evidence": "specs/${feat}/verification/tdd-red.log",
      "green_evidence": "specs/${feat}/verification/tdd-green.log",
      "waiver_reason": "" },
    { "id": "build",                   "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "placeholder-scan",        "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check",        "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "acceptance-tests",        "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log",
      "red_evidence": "specs/${feat}/verification/tdd-red.log",
      "green_evidence": "specs/${feat}/verification/tdd-green.log",
      "waiver_reason": "" },
    { "id": "regression",              "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "requirement-traceability","required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "integration-tests",       "required": false, "passes": false,  "evidence": "", "waiver_reason": "not applicable for this task" }
  ]
}
CEOF

# --- T-103 contract (critical risk, code stack) ---
cat > "${SA}/verification/T-103.contract.json" <<CEOF
{
  "task_id": "T-103",
  "feature": "${feat}",
  "risk": "critical",
  "stack": "code",
  "required_workflow": "tdd",
  "created": "2026-06-14T00:00:00Z",
  "checks": [
    { "id": "lint",                    "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "typecheck",               "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "unit-tests",              "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log",
      "red_evidence": "specs/${feat}/verification/tdd-red.log",
      "green_evidence": "specs/${feat}/verification/tdd-green.log",
      "waiver_reason": "" },
    { "id": "build",                   "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "placeholder-scan",        "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check",        "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "acceptance-tests",        "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log",
      "red_evidence": "specs/${feat}/verification/tdd-red.log",
      "green_evidence": "specs/${feat}/verification/tdd-green.log",
      "waiver_reason": "" },
    { "id": "regression",              "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "requirement-traceability","required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" }
  ]
}
CEOF

# ---- A.4: check-contract passes T-102 (high risk, tdd) ----
echo "--- A.4: check-contract passes T-102 ---"

if check_contract_passes "${SA}/verification/T-102.contract.json" "$SA"; then
    ok "A.4: check-contract passes T-102 (high risk, tdd, full evidence)"
else
    fail "A.4: check-contract should pass T-102 — $(run_check_contract "${SA}/verification/T-102.contract.json" "$SA")"
fi

# ---- A.5: check-contract fails when a required check has passes:false + empty waiver_reason ----
echo "--- A.5: check-contract fails on required passes:false ---"

cat > "${SA}/verification/T-102-bad.contract.json" <<CEOF
{
  "task_id": "T-102",
  "feature": "${feat}",
  "risk": "high",
  "stack": "code",
  "required_workflow": "tdd",
  "checks": [
    { "id": "lint",             "required": true,  "passes": false, "evidence": "", "waiver_reason": "" },
    { "id": "typecheck",        "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "unit-tests",       "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log",
      "red_evidence": "specs/${feat}/verification/tdd-red.log",
      "green_evidence": "specs/${feat}/verification/tdd-green.log",
      "waiver_reason": "" },
    { "id": "build",            "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "acceptance-tests", "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log",
      "red_evidence": "specs/${feat}/verification/tdd-red.log",
      "green_evidence": "specs/${feat}/verification/tdd-green.log",
      "waiver_reason": "" },
    { "id": "regression",                "required": true, "passes": true, "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "requirement-traceability",  "required": true, "passes": true, "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" }
  ]
}
CEOF

out_a5="$(run_check_contract "${SA}/verification/T-102-bad.contract.json" "$SA")"
if ! check_contract_passes "${SA}/verification/T-102-bad.contract.json" "$SA"; then
    ok "A.5: check-contract fails when required check has passes:false"
else
    fail "A.5: check-contract should fail on required passes:false (out='${out_a5}')"
fi

# ---- A.6: check-traceability passes the complete REQ->AC->TEST->evidence chain ----
echo "--- A.6: check-traceability passes complete chain ---"

cat > "${SA}/specs/${feat}/traceability.json" <<JEOF
{
  "feature": "${feat}",
  "links": [
    {
      "req": "REQ-001",
      "acs": ["AC-001"],
      "tests": ["TEST-001"],
      "evidence": ["specs/${feat}/verification/ev.log"]
    }
  ]
}
JEOF

if check_traceability_passes "${SA}/specs/${feat}/traceability.json" "$SA" "require-evidence"; then
    ok "A.6: check-traceability passes complete REQ->AC->TEST->evidence chain"
else
    fail "A.6: check-traceability should pass — $(run_check_traceability "${SA}/specs/${feat}/traceability.json" "$SA" "require-evidence")"
fi

# ---- A.7: check-traceability fails-closed on empty tests[] ----
echo "--- A.7: check-traceability fails-closed on empty tests[] ---"

cat > "${SA}/specs/${feat}/traceability-bad.json" <<JEOF
{
  "feature": "${feat}",
  "links": [
    {
      "req": "REQ-001",
      "acs": ["AC-001"],
      "tests": [],
      "evidence": ["specs/${feat}/verification/ev.log"]
    }
  ]
}
JEOF

out_a7="$(run_check_traceability "${SA}/specs/${feat}/traceability-bad.json" "$SA")"
if ! check_traceability_passes "${SA}/specs/${feat}/traceability-bad.json" "$SA" \
   && echo "$out_a7" | grep -qi "no tests"; then
    ok "A.7: check-traceability fails-closed on empty tests[] link"
else
    fail "A.7: check-traceability should fail on empty tests[] (out='${out_a7}')"
fi

# ---- A.8: check-task-state BLOCKS Done while Approval: Draft ----
echo "--- A.8: check-task-state blocks Done with Approval: Draft ---"

cat > "${SA}/tasks-draft.md" <<TEOF
# Project Tasks

## T-101

Risk: low
Risk Rationale: documentation only
Status: Done
Approval: Draft
TEOF

out_a8="$(run_check_task_state "${SA}/tasks-draft.md" \
    "${SA}/reports/quality-gate" "${SA}/reports/implementation" "$SA")"
if ! check_task_state_passes "${SA}/tasks-draft.md" \
        "${SA}/reports/quality-gate" "${SA}/reports/implementation" "$SA"; then
    ok "A.8: check-task-state BLOCKS Done while Approval: Draft"
else
    fail "A.8: check-task-state should block Done with Approval: Draft (out='${out_a8}')"
fi

# ---- A.9: check-task-state PASSES non-critical Done with Approval: Approved (named id) ----
echo "--- A.9: check-task-state passes non-critical Done with named Approval ---"

SA_T101="${WORK}/sa-t101-done"
mkdir -p "${SA_T101}/verification"
mkdir -p "${SA_T101}/specs/${feat}/verification"
mkdir -p "${SA_T101}/reports/quality-gate"
mkdir -p "${SA_T101}/reports/implementation"
mkdir -p "${SA_T101}/src"

printf 'All checks passed.\n' > "${SA_T101}/specs/${feat}/verification/ev.log"
printf 'def add(a, b):\n    return a + b\n' > "${SA_T101}/src/widget.py"

cat > "${SA_T101}/reports/quality-gate/T-101.md" <<RPTEOF
Task ID: T-101
Feature: ${feat}
VERDICT: PASS

Docs-only task; all applicable checks green.
RPTEOF

cat > "${SA_T101}/verification/T-101.contract.json" <<CEOF
{
  "task_id": "T-101",
  "feature": "${feat}",
  "risk": "low",
  "stack": "docs",
  "created": "2026-06-14T00:00:00Z",
  "checks": [
    { "id": "lint",             "required": false, "passes": false, "evidence": "", "waiver_reason": "docs stack — no linter applicable" },
    { "id": "typecheck",        "required": false, "passes": false, "evidence": "", "waiver_reason": "docs stack — no type checker applicable" },
    { "id": "build",            "required": false, "passes": false, "evidence": "", "waiver_reason": "docs stack — no build step applicable" },
    { "id": "unit-tests",       "required": false, "passes": false, "evidence": "", "waiver_reason": "docs stack — no unit tests applicable" },
    { "id": "placeholder-scan", "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true,  "passes": true,  "evidence": "specs/${feat}/verification/ev.log", "waiver_reason": "" }
  ]
}
CEOF

cat > "${SA_T101}/tasks.md" <<TEOF
# Project Tasks

## T-101

Risk: low
Risk Rationale: documentation only
Status: Done
Approval: Approved (alice 2026-06-14T00:00:00Z)
TEOF

git_init_and_commit "$SA_T101"

if generate_bundle_passes "${SA_T101}/verification/T-101.contract.json" \
        "${SA_T101}/reports/quality-gate/T-101.md" "$SA_T101"; then
    if check_task_state_passes "${SA_T101}/tasks.md" \
            "${SA_T101}/reports/quality-gate" "${SA_T101}/reports/implementation" "$SA_T101"; then
        ok "A.9: check-task-state PASSES non-critical Done with named Approval: Approved (alice)"
    else
        fail "A.9: check-task-state should pass non-critical Done+Approved — $(run_check_task_state "${SA_T101}/tasks.md" "${SA_T101}/reports/quality-gate" "${SA_T101}/reports/implementation" "$SA_T101")"
    fi
else
    fail "A.9: generate-evidence-bundle failed for T-101 — $(run_generate_bundle "${SA_T101}/verification/T-101.contract.json" "${SA_T101}/reports/quality-gate/T-101.md" "$SA_T101")"
fi

# ---- A.10: check-task-state BLOCKS critical Done without Second Approval ----
echo "--- A.10: check-task-state blocks critical Done without Second Approval ---"

SA_T103="${WORK}/sa-t103-nosecond"
mkdir -p "${SA_T103}/verification"
mkdir -p "${SA_T103}/specs/${feat}/verification"
mkdir -p "${SA_T103}/reports/quality-gate"
mkdir -p "${SA_T103}/reports/implementation"
mkdir -p "${SA_T103}/src"

printf 'All checks passed.\n' > "${SA_T103}/specs/${feat}/verification/ev.log"
printf 'RED: test FAILED\n'   > "${SA_T103}/specs/${feat}/verification/tdd-red.log"
printf 'GREEN: test PASSED\n' > "${SA_T103}/specs/${feat}/verification/tdd-green.log"
printf 'def add(a, b):\n    return a + b\n' > "${SA_T103}/src/widget.py"
# spec files required by compute_spec_revision for critical bundles
printf '# Requirements\n- REQ-001: signing must be verifiable\n' > "${SA_T103}/specs/${feat}/requirements.md"

cat > "${SA_T103}/reports/quality-gate/T-103.md" <<RPTEOF
Task ID: T-103
Feature: ${feat}
VERDICT: PASS

Critical-risk TDD task; all checks green.
RPTEOF

cp "${SA}/verification/T-103.contract.json" "${SA_T103}/verification/T-103.contract.json"

# tasks.md: critical Done with only one approver (no Second Approval)
cat > "${SA_T103}/tasks.md" <<TEOF
# Project Tasks

## T-103

Risk: critical
Risk Rationale: signs and verifies evidence bundles for critical tasks
Required Workflow: tdd
Status: Done
Approval: Approved (alice 2026-06-14T00:00:00Z)
TEOF

git_init_and_commit "$SA_T103"

_T103_KEY="$(head -c32 /dev/urandom | xxd -p | tr -d '\n')"
if SDD_EVIDENCE_KEY="$_T103_KEY" generate_bundle_passes \
        "${SA_T103}/verification/T-103.contract.json" \
        "${SA_T103}/reports/quality-gate/T-103.md" "$SA_T103"; then
    # check-task-state should block: no Second Approval
    out_a10="$(SDD_EVIDENCE_KEY="$_T103_KEY" run_check_task_state "${SA_T103}/tasks.md" \
        "${SA_T103}/reports/quality-gate" "${SA_T103}/reports/implementation" "$SA_T103")"
    if ! SDD_EVIDENCE_KEY="$_T103_KEY" check_task_state_passes "${SA_T103}/tasks.md" \
            "${SA_T103}/reports/quality-gate" "${SA_T103}/reports/implementation" "$SA_T103"; then
        ok "A.10: check-task-state BLOCKS critical Done without Second Approval"
    else
        fail "A.10: check-task-state should block critical Done without Second Approval (out='${out_a10}')"
    fi
else
    fail "A.10: generate-evidence-bundle failed for T-103 — $(SDD_EVIDENCE_KEY="$_T103_KEY" run_generate_bundle "${SA_T103}/verification/T-103.contract.json" "${SA_T103}/reports/quality-gate/T-103.md" "$SA_T103")"
fi
unset _T103_KEY

# ---- A.11: check-task-state BLOCKS critical Done with same-name approvers ----
echo "--- A.11: check-task-state blocks critical Done with same-name approvers ---"

SA_T103B="${WORK}/sa-t103-samename"
mkdir -p "${SA_T103B}/verification"
mkdir -p "${SA_T103B}/specs/${feat}/verification"
mkdir -p "${SA_T103B}/reports/quality-gate"
mkdir -p "${SA_T103B}/reports/implementation"
mkdir -p "${SA_T103B}/src"

printf 'All checks passed.\n' > "${SA_T103B}/specs/${feat}/verification/ev.log"
printf 'RED: test FAILED\n'   > "${SA_T103B}/specs/${feat}/verification/tdd-red.log"
printf 'GREEN: test PASSED\n' > "${SA_T103B}/specs/${feat}/verification/tdd-green.log"
printf 'def add(a, b):\n    return a + b\n' > "${SA_T103B}/src/widget.py"
printf '# Requirements\n- REQ-001: signing must be verifiable\n' > "${SA_T103B}/specs/${feat}/requirements.md"

cat > "${SA_T103B}/reports/quality-gate/T-103.md" <<RPTEOF
Task ID: T-103
Feature: ${feat}
VERDICT: PASS

Critical-risk TDD task; all checks green.
RPTEOF

cp "${SA}/verification/T-103.contract.json" "${SA_T103B}/verification/T-103.contract.json"

cat > "${SA_T103B}/tasks.md" <<TEOF
# Project Tasks

## T-103

Risk: critical
Risk Rationale: signs and verifies evidence bundles for critical tasks
Required Workflow: tdd
Status: Done
Approval: Approved (alice 2026-06-14T00:00:00Z)
Second Approval: Approved (alice 2026-06-14T01:00:00Z)
TEOF

git_init_and_commit "$SA_T103B"

_T103B_KEY="$(head -c32 /dev/urandom | xxd -p | tr -d '\n')"
if SDD_EVIDENCE_KEY="$_T103B_KEY" generate_bundle_passes \
        "${SA_T103B}/verification/T-103.contract.json" \
        "${SA_T103B}/reports/quality-gate/T-103.md" "$SA_T103B"; then
    out_a11="$(SDD_EVIDENCE_KEY="$_T103B_KEY" run_check_task_state "${SA_T103B}/tasks.md" \
        "${SA_T103B}/reports/quality-gate" "${SA_T103B}/reports/implementation" "$SA_T103B")"
    if ! SDD_EVIDENCE_KEY="$_T103B_KEY" check_task_state_passes "${SA_T103B}/tasks.md" \
            "${SA_T103B}/reports/quality-gate" "${SA_T103B}/reports/implementation" "$SA_T103B" \
       && echo "$out_a11" | grep -qi "same approver"; then
        ok "A.11: check-task-state BLOCKS critical Done with same-name approvers (alice==alice)"
    else
        fail "A.11: check-task-state should block same-name approvers (out='${out_a11}')"
    fi
else
    fail "A.11: generate-evidence-bundle failed for T-103 (same-name) — $(SDD_EVIDENCE_KEY="$_T103B_KEY" run_generate_bundle "${SA_T103B}/verification/T-103.contract.json" "${SA_T103B}/reports/quality-gate/T-103.md" "$SA_T103B")"
fi
unset _T103B_KEY

# ---- A.12: check-task-state BLOCKS critical Done with 'sudo' as approver ----
echo "--- A.12: check-task-state blocks critical Done with sudo approver ---"

SA_T103C="${WORK}/sa-t103-sudo"
mkdir -p "${SA_T103C}/verification"
mkdir -p "${SA_T103C}/specs/${feat}/verification"
mkdir -p "${SA_T103C}/reports/quality-gate"
mkdir -p "${SA_T103C}/reports/implementation"
mkdir -p "${SA_T103C}/src"

printf 'All checks passed.\n' > "${SA_T103C}/specs/${feat}/verification/ev.log"
printf 'RED: test FAILED\n'   > "${SA_T103C}/specs/${feat}/verification/tdd-red.log"
printf 'GREEN: test PASSED\n' > "${SA_T103C}/specs/${feat}/verification/tdd-green.log"
printf 'def add(a, b):\n    return a + b\n' > "${SA_T103C}/src/widget.py"
printf '# Requirements\n- REQ-001: signing must be verifiable\n' > "${SA_T103C}/specs/${feat}/requirements.md"

cat > "${SA_T103C}/reports/quality-gate/T-103.md" <<RPTEOF
Task ID: T-103
Feature: ${feat}
VERDICT: PASS

Critical-risk TDD task; all checks green.
RPTEOF

cp "${SA}/verification/T-103.contract.json" "${SA_T103C}/verification/T-103.contract.json"

cat > "${SA_T103C}/tasks.md" <<TEOF
# Project Tasks

## T-103

Risk: critical
Risk Rationale: signs and verifies evidence bundles for critical tasks
Required Workflow: tdd
Status: Done
Approval: Approved (sudo 2026-06-14T00:00:00Z)
Second Approval: Approved (bob 2026-06-14T01:00:00Z)
TEOF

git_init_and_commit "$SA_T103C"

_T103C_KEY="$(head -c32 /dev/urandom | xxd -p | tr -d '\n')"
if SDD_EVIDENCE_KEY="$_T103C_KEY" generate_bundle_passes \
        "${SA_T103C}/verification/T-103.contract.json" \
        "${SA_T103C}/reports/quality-gate/T-103.md" "$SA_T103C"; then
    out_a12="$(SDD_EVIDENCE_KEY="$_T103C_KEY" run_check_task_state "${SA_T103C}/tasks.md" \
        "${SA_T103C}/reports/quality-gate" "${SA_T103C}/reports/implementation" "$SA_T103C")"
    if ! SDD_EVIDENCE_KEY="$_T103C_KEY" check_task_state_passes "${SA_T103C}/tasks.md" \
            "${SA_T103C}/reports/quality-gate" "${SA_T103C}/reports/implementation" "$SA_T103C" \
       && echo "$out_a12" | grep -qi "sudo"; then
        ok "A.12: check-task-state BLOCKS critical Done with 'sudo' as primary approver"
    else
        fail "A.12: check-task-state should block sudo approver (out='${out_a12}')"
    fi
else
    fail "A.12: generate-evidence-bundle failed for T-103 (sudo) — $(SDD_EVIDENCE_KEY="$_T103C_KEY" run_generate_bundle "${SA_T103C}/verification/T-103.contract.json" "${SA_T103C}/reports/quality-gate/T-103.md" "$SA_T103C")"
fi
unset _T103C_KEY

# ---- A.13: generate-evidence-bundle + check-evidence-bundle succeed for high task T-102 ----
echo "--- A.13: evidence bundle round-trip for high task T-102 ---"

SA_T102="${WORK}/sa-t102-done"
mkdir -p "${SA_T102}/verification"
mkdir -p "${SA_T102}/specs/${feat}/verification"
mkdir -p "${SA_T102}/reports/quality-gate"
mkdir -p "${SA_T102}/reports/implementation"
mkdir -p "${SA_T102}/src"

printf 'All checks passed.\n' > "${SA_T102}/specs/${feat}/verification/ev.log"
printf 'RED: test FAILED\n'   > "${SA_T102}/specs/${feat}/verification/tdd-red.log"
printf 'GREEN: test PASSED\n' > "${SA_T102}/specs/${feat}/verification/tdd-green.log"
printf 'def add(a, b):\n    return a + b\n' > "${SA_T102}/src/widget.py"
# spec files required by compute_spec_revision for high/critical bundles
printf '# Requirements\n- REQ-001: payment must succeed\n' > "${SA_T102}/specs/${feat}/requirements.md"

cp "${SA}/verification/T-102.contract.json" "${SA_T102}/verification/T-102.contract.json"

cat > "${SA_T102}/reports/quality-gate/T-102.md" <<RPTEOF
Task ID: T-102
Feature: ${feat}
VERDICT: PASS

High-risk TDD task; all checks green including red->green evidence.
RPTEOF

git_init_and_commit "$SA_T102"

if generate_bundle_passes "${SA_T102}/verification/T-102.contract.json" \
        "${SA_T102}/reports/quality-gate/T-102.md" "$SA_T102"; then
    ok "A.13a: generate-evidence-bundle succeeds for high task T-102"
else
    fail "A.13a: generate-evidence-bundle failed — $(run_generate_bundle "${SA_T102}/verification/T-102.contract.json" "${SA_T102}/reports/quality-gate/T-102.md" "$SA_T102")"
fi

bundle_t102="${SA_T102}/verification/T-102.evidence.json"
if check_bundle_passes "$bundle_t102" "$SA_T102"; then
    ok "A.13b: check-evidence-bundle passes for high task T-102"
else
    fail "A.13b: check-evidence-bundle should pass — $(run_check_bundle "$bundle_t102" "$SA_T102")"
fi

# ===========================================================================
# SCENARIO B1: HOOK CONTRACT FOR ALL 3 CLI FORMS
# ===========================================================================
echo "=== Scenario B1: hook contract — all 3 CLI forms ==="

SB="${WORK}/sb-hooks"
mkdir -p "${SB}/specs/x"
_had_claude_project_dir=0
if [ "${CLAUDE_PROJECT_DIR+x}" = x ]; then
    _had_claude_project_dir=1
    _original_claude_project_dir="$CLAUDE_PROJECT_DIR"
fi
export CLAUDE_PROJECT_DIR="$SB"

GUARD_JS="${SCRIPTS_DIR}/sdd-hook-guard.js"
GUARD_SH="${SCRIPTS_DIR}/sdd-hook-guard.sh"

# Self-approval payload (deny): Edit targeting tasks.md adding Approval: Approved
SELF_APPROVE_PAYLOAD='{"tool_name":"Edit","tool_input":{"file_path":"'"${SB}"'/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'
# Benign payload (allow): Edit to a non-tasks path
BENIGN_PAYLOAD='{"tool_name":"Edit","tool_input":{"file_path":"'"${SB}"'/src/foo.js","old_string":"a","new_string":"b"}}'

# ---- B1.1: Claude Code: node sdd-hook-guard.js --emit exit ----
echo "--- B1.1: Claude Code node --emit exit ---"

# Self-approval => exit 2
_cc_deny_code=0
printf '%s' "$SELF_APPROVE_PAYLOAD" | \
    node "$GUARD_JS" --emit exit >/dev/null 2>&1 || _cc_deny_code=$?
if [ "$_cc_deny_code" -eq 2 ]; then
    ok "B1.1a: Claude Code node guard exits 2 on self-approval (deny)"
else
    fail "B1.1a: Claude Code node guard should exit 2 on self-approval (got ${_cc_deny_code})"
fi

# Benign => exit 0
_cc_allow_code=0
printf '%s' "$BENIGN_PAYLOAD" | \
    node "$GUARD_JS" --emit exit >/dev/null 2>&1 || _cc_allow_code=$?
if [ "$_cc_allow_code" -eq 0 ]; then
    ok "B1.1b: Claude Code node guard exits 0 on benign payload (allow)"
else
    fail "B1.1b: Claude Code node guard should exit 0 on benign payload (got ${_cc_allow_code})"
fi

# ---- B1.2: Codex: sh sdd-hook-guard.sh --emit exit ----
echo "--- B1.2: Codex sh --emit exit ---"

_cx_deny_code=0
printf '%s' "$SELF_APPROVE_PAYLOAD" | \
    sh "$GUARD_SH" --emit exit >/dev/null 2>&1 || _cx_deny_code=$?
if [ "$_cx_deny_code" -eq 2 ]; then
    ok "B1.2a: Codex sh guard exits 2 on self-approval (deny)"
else
    fail "B1.2a: Codex sh guard should exit 2 on self-approval (got ${_cx_deny_code})"
fi

_cx_allow_code=0
printf '%s' "$BENIGN_PAYLOAD" | \
    sh "$GUARD_SH" --emit exit >/dev/null 2>&1 || _cx_allow_code=$?
if [ "$_cx_allow_code" -eq 0 ]; then
    ok "B1.2b: Codex sh guard exits 0 on benign payload (allow)"
else
    fail "B1.2b: Codex sh guard should exit 0 on benign payload (got ${_cx_allow_code})"
fi

# ---- B1.3: Copilot: sh sdd-hook-guard.sh --emit copilot ----
echo "--- B1.3: Copilot sh --emit copilot ---"

# Self-approval => stdout JSON with permissionDecision="deny", exit 0
_cop_deny_out=""
_cop_deny_code=0
_cop_deny_out="$(printf '%s' "$SELF_APPROVE_PAYLOAD" | \
    sh "$GUARD_SH" --emit copilot 2>/dev/null)" || _cop_deny_code=$?
_cop_deny_decision="$(printf '%s' "$_cop_deny_out" | \
    python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('permissionDecision',''))" 2>/dev/null || true)"
if [ "$_cop_deny_code" -eq 0 ] && [ "$_cop_deny_decision" = "deny" ]; then
    ok "B1.3a: Copilot sh guard emits permissionDecision=deny on self-approval (exit 0)"
else
    fail "B1.3a: Copilot sh guard should emit deny (code=${_cop_deny_code}, decision='${_cop_deny_decision}', out='${_cop_deny_out}')"
fi

# Benign => stdout JSON with permissionDecision="allow", exit 0
_cop_allow_out=""
_cop_allow_code=0
_cop_allow_out="$(printf '%s' "$BENIGN_PAYLOAD" | \
    sh "$GUARD_SH" --emit copilot 2>/dev/null)" || _cop_allow_code=$?
_cop_allow_decision="$(printf '%s' "$_cop_allow_out" | \
    python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('permissionDecision',''))" 2>/dev/null || true)"
if [ "$_cop_allow_code" -eq 0 ] && [ "$_cop_allow_decision" = "allow" ]; then
    ok "B1.3b: Copilot sh guard emits permissionDecision=allow on benign payload (exit 0)"
else
    fail "B1.3b: Copilot sh guard should emit allow (code=${_cop_allow_code}, decision='${_cop_allow_decision}', out='${_cop_allow_out}')"
fi

# ---- B1.4: DRIFT GUARD ----
echo "--- B1.4: drift guard — hook configs reference the correct CLI invocations ---"

CLAUDE_HOOKS="${HOOKS_DIR}/claude-hooks.json"
CODEX_HOOKS="${HOOKS_DIR}/hooks.json"
COPILOT_HOOKS="${HOOKS_DIR}/copilot-hooks.json"

# Claude Code config must reference sdd-hook-guard.js with --emit and exit
if grep -q 'sdd-hook-guard.js' "$CLAUDE_HOOKS" \
   && grep -q '"--emit"' "$CLAUDE_HOOKS" \
   && grep -q '"exit"' "$CLAUDE_HOOKS"; then
    ok "B1.4a: claude-hooks.json references sdd-hook-guard.js with --emit exit"
else
    fail "B1.4a: claude-hooks.json must reference sdd-hook-guard.js --emit exit (check ${CLAUDE_HOOKS})"
fi

# Codex config must reference sdd-hook-guard.sh --emit exit
if grep -q 'sdd-hook-guard.sh' "$CODEX_HOOKS" \
   && grep -q '\-\-emit exit' "$CODEX_HOOKS"; then
    ok "B1.4b: hooks.json references sdd-hook-guard.sh --emit exit"
else
    fail "B1.4b: hooks.json must reference sdd-hook-guard.sh --emit exit (check ${CODEX_HOOKS})"
fi

# Copilot config must reference sdd-hook-guard.sh --emit copilot
if grep -q 'sdd-hook-guard.sh' "$COPILOT_HOOKS" \
   && grep -q '\-\-emit copilot' "$COPILOT_HOOKS"; then
    ok "B1.4c: copilot-hooks.json references sdd-hook-guard.sh --emit copilot"
else
    fail "B1.4c: copilot-hooks.json must reference sdd-hook-guard.sh --emit copilot (check ${COPILOT_HOOKS})"
fi

if [ "$_had_claude_project_dir" -eq 1 ]; then
    export CLAUDE_PROJECT_DIR="$_original_claude_project_dir"
else
    unset CLAUDE_PROJECT_DIR
fi

# ===========================================================================
# SCENARIO E: CRITICAL SIGNING ROUND-TRIP
# ===========================================================================
echo "=== Scenario E: critical signing round-trip ==="

SE="${WORK}/se-signing"
feat_e="feat-signing"
mkdir -p "${SE}/verification"
mkdir -p "${SE}/specs/${feat_e}/verification"
mkdir -p "${SE}/reports/quality-gate"
mkdir -p "${SE}/reports/implementation"
mkdir -p "${SE}/src"

printf 'All checks passed.\n' > "${SE}/specs/${feat_e}/verification/ev.log"
printf 'RED: test FAILED\n'   > "${SE}/specs/${feat_e}/verification/tdd-red.log"
printf 'GREEN: test PASSED\n' > "${SE}/specs/${feat_e}/verification/tdd-green.log"
printf 'def sign(x):\n    return x\n' > "${SE}/src/signer.py"
# spec files required by compute_spec_revision for critical bundles
printf '# Requirements\n- REQ-001: signing must be verifiable\n' > "${SE}/specs/${feat_e}/requirements.md"

cat > "${SE}/reports/quality-gate/T-201.md" <<RPTEOF
Task ID: T-201
Feature: ${feat_e}
VERDICT: PASS

Critical signing task; all checks green.
RPTEOF

cat > "${SE}/verification/T-201.contract.json" <<CEOF
{
  "task_id": "T-201",
  "feature": "${feat_e}",
  "risk": "critical",
  "stack": "code",
  "required_workflow": "tdd",
  "created": "2026-06-14T00:00:00Z",
  "checks": [
    { "id": "lint",                    "required": true,  "passes": true,  "evidence": "specs/${feat_e}/verification/ev.log", "waiver_reason": "" },
    { "id": "typecheck",               "required": true,  "passes": true,  "evidence": "specs/${feat_e}/verification/ev.log", "waiver_reason": "" },
    { "id": "unit-tests",              "required": true,  "passes": true,  "evidence": "specs/${feat_e}/verification/ev.log",
      "red_evidence": "specs/${feat_e}/verification/tdd-red.log",
      "green_evidence": "specs/${feat_e}/verification/tdd-green.log",
      "waiver_reason": "" },
    { "id": "build",                   "required": true,  "passes": true,  "evidence": "specs/${feat_e}/verification/ev.log", "waiver_reason": "" },
    { "id": "placeholder-scan",        "required": true,  "passes": true,  "evidence": "specs/${feat_e}/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check",        "required": true,  "passes": true,  "evidence": "specs/${feat_e}/verification/ev.log", "waiver_reason": "" },
    { "id": "acceptance-tests",        "required": true,  "passes": true,  "evidence": "specs/${feat_e}/verification/ev.log",
      "red_evidence": "specs/${feat_e}/verification/tdd-red.log",
      "green_evidence": "specs/${feat_e}/verification/tdd-green.log",
      "waiver_reason": "" },
    { "id": "regression",              "required": true,  "passes": true,  "evidence": "specs/${feat_e}/verification/ev.log", "waiver_reason": "" },
    { "id": "requirement-traceability","required": true,  "passes": true,  "evidence": "specs/${feat_e}/verification/ev.log", "waiver_reason": "" }
  ]
}
CEOF

git_init_and_commit "$SE"

# Generate an ephemeral key (never hard-coded, never printed)
SDD_EVIDENCE_KEY="$(head -c32 /dev/urandom | xxd -p | tr -d '\n')"
export SDD_EVIDENCE_KEY

bundle_e="${SE}/verification/T-201.evidence.json"

# ---- E.1: generate signed bundle for critical task => PASS ----
echo "--- E.1: generate signed critical bundle ---"

if generate_bundle_passes "${SE}/verification/T-201.contract.json" \
        "${SE}/reports/quality-gate/T-201.md" "$SE"; then
    ok "E.1: generate-evidence-bundle succeeds for critical task with SDD_EVIDENCE_KEY"
else
    fail "E.1: generate-evidence-bundle failed for critical task — $(run_generate_bundle "${SE}/verification/T-201.contract.json" "${SE}/reports/quality-gate/T-201.md" "$SE")"
fi

# Verify the bundle actually has a signature field
_has_sig=0
python3 -c "
import json, sys
b = json.load(open('${bundle_e}'))
sig = b.get('signature', {})
assert sig.get('alg') == 'hmac-sha256', 'missing hmac-sha256 signature'
assert sig.get('value'), 'empty signature value'
" 2>/dev/null && _has_sig=1 || true
if [ "$_has_sig" -eq 1 ]; then
    ok "E.1b: signed bundle contains hmac-sha256 signature field"
else
    fail "E.1b: signed bundle should contain hmac-sha256 signature"
fi

# ---- E.2: check-evidence-bundle with correct key => PASS ----
echo "--- E.2: check-evidence-bundle with correct key passes ---"

if check_bundle_passes "$bundle_e" "$SE"; then
    ok "E.2: check-evidence-bundle PASS with correct SDD_EVIDENCE_KEY"
else
    fail "E.2: check-evidence-bundle should pass with correct key — $(run_check_bundle "$bundle_e" "$SE")"
fi

# ---- E.3: tamper one byte of the bundle payload => FAIL (mentions signature/HMAC) ----
echo "--- E.3: tampered bundle fails signature check ---"

SE_TAMPER="${WORK}/se-tampered"
mkdir -p "${SE_TAMPER}/verification"
# Copy all artifacts so check-evidence-bundle can validate paths
cp -r "${SE}/specs"  "${SE_TAMPER}/"
cp -r "${SE}/reports" "${SE_TAMPER}/"
cp "${SE}/verification/T-201.contract.json" "${SE_TAMPER}/verification/"
# Copy git dir so git_commit check passes
cp -r "${SE}/.git" "${SE_TAMPER}/"

# Tamper the bundle: flip one hex digit in the signature value
python3 - <<PYEOF
import json, pathlib
src = pathlib.Path("${bundle_e}")
b = json.loads(src.read_text(encoding="utf-8"))
sig = b.get("signature", {})
val = sig.get("value", "")
if val:
    flipped = val[:-1] + ('0' if val[-1] != '0' else '1')
    sig["value"] = flipped
    b["signature"] = sig
dst = pathlib.Path("${SE_TAMPER}/verification/T-201.evidence.json")
dst.write_text(json.dumps(b, indent=2) + "\n", encoding="utf-8")
PYEOF

out_e3="$(run_check_bundle "${SE_TAMPER}/verification/T-201.evidence.json" "$SE_TAMPER")"
if ! check_bundle_passes "${SE_TAMPER}/verification/T-201.evidence.json" "$SE_TAMPER" \
   && echo "$out_e3" | grep -qiE "signature|HMAC|hmac"; then
    ok "E.3: tampered critical bundle fails check-evidence-bundle (mentions signature/HMAC)"
else
    fail "E.3: tampered bundle should fail with signature/HMAC error (out='${out_e3}')"
fi

unset SDD_EVIDENCE_KEY

# ===========================================================================
# Summary
# ===========================================================================
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed."
if [ "${FAIL}" -eq 0 ]; then
    exit 0
else
    exit 1
fi
