#!/usr/bin/env bash
# gates.tests.sh — test deterministic gates (check-task-state, check-contract)
# Mirrors install.tests.sh style: ok/fail counters, exits 1 on any failure.
# Runs on Linux and macOS without pwsh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/plugins/sdd-quality-loop/scripts"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

# Create a temp workdir and clean it up on exit.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ============================================================================
# Helpers
# ============================================================================

# Invoke check-contract.sh and return exit code
run_check_contract() {
    local contract="$1"
    local root="${2:-.}"
    bash "${SCRIPTS_DIR}/check-contract.sh" "$contract" "$root" 2>&1 || true
}

# Check if check-contract passes (exit 0)
check_contract_passes() {
    local contract="$1"
    local root="${2:-.}"
    bash "${SCRIPTS_DIR}/check-contract.sh" "$contract" "$root" >/dev/null 2>&1
}

# Invoke check-task-state.sh and return output
run_check_task_state() {
    local tasks="$1"
    local reports="${2:-reports/quality-gate}"
    local impl_reports="${3:-reports/implementation}"
    local root="${4:-.}"
    bash "${SCRIPTS_DIR}/check-task-state.sh" "$tasks" "$reports" "$impl_reports" "$root" 2>&1 || true
}

# Check if check-task-state passes (exit 0)
check_task_state_passes() {
    local tasks="$1"
    local reports="${2:-reports/quality-gate}"
    local impl_reports="${3:-reports/implementation}"
    local root="${4:-.}"
    bash "${SCRIPTS_DIR}/check-task-state.sh" "$tasks" "$reports" "$impl_reports" "$root" >/dev/null 2>&1
}

# ============================================================================
# Test Fixtures
# ============================================================================

# Create a minimal valid contract template
make_valid_contract() {
    local task_id="$1"
    local dir="$2"
    local contract="${dir}/${task_id}.contract.json"
    cat > "$contract" <<EOF
{
  "task_id": "${task_id}",
  "feature": "test-feature",
  "created": "2026-06-13T00:00:00Z",
  "comment": "Test contract",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "integration-tests", "required": false, "passes": false, "evidence": "", "waiver_reason": "N/A for this task" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "smoke-run", "required": false, "passes": false, "evidence": "", "waiver_reason": "manual only" },
    { "id": "differential-baseline", "required": false, "passes": false, "evidence": "", "waiver_reason": "not applicable" },
    { "id": "ui-verification", "required": false, "passes": false, "evidence": "", "waiver_reason": "no UI changes" }
  ]
}
EOF
    printf '%s\n' "$contract"
}

# Create a minimal valid tasks.md
make_valid_tasks_md() {
    local task_id="$1"
    local dir="$2"
    local tasks_file="${dir}/tasks.md"
    cat > "$tasks_file" <<EOF
# Project Tasks

## ${task_id}

Approval: Approved
Status: Done

### Description
Test task.
EOF
    printf '%s\n' "$tasks_file"
}

# ============================================================================
# C-06: Contract Type Strictness Tests
# ============================================================================

echo "=== C-06: Contract Type Strictness ==="

# Test: required field must be boolean, not string
mkdir -p "${WORK}/c06_test1"
cat > "${WORK}/c06_test1/T-001.contract.json" <<'EOF'
{
  "task_id": "T-001",
  "checks": [
    { "id": "lint", "required": "true", "passes": true, "evidence": "", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_contract "${WORK}/c06_test1/T-001.contract.json" "${WORK}/c06_test1")
if echo "$output" | grep -q "invalid type for required"; then
    ok "C-06.1: reject string 'true' for required field"
else
    fail "C-06.1: should reject string 'true' for required field"
fi

# Test: passes field must be boolean, not number
mkdir -p "${WORK}/c06_test2"
cat > "${WORK}/c06_test2/T-002.contract.json" <<'EOF'
{
  "task_id": "T-002",
  "checks": [
    { "id": "lint", "required": true, "passes": 1, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_contract "${WORK}/c06_test2/T-002.contract.json" "${WORK}/c06_test2")
if echo "$output" | grep -q "invalid type for passes"; then
    ok "C-06.2: reject numeric 1 for passes field"
else
    fail "C-06.2: should reject numeric 1 for passes field"
fi

# Test: evidence must be a regular file (not directory)
mkdir -p "${WORK}/c06_test3/reports"
mkdir -p "${WORK}/c06_test3/reports/test_dir"
cat > "${WORK}/c06_test3/T-003.contract.json" <<'EOF'
{
  "task_id": "T-003",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test_dir", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_contract "${WORK}/c06_test3/T-003.contract.json" "${WORK}/c06_test3")
if echo "$output" | grep -q "not a regular file"; then
    ok "C-06.3: reject directory as evidence"
else
    fail "C-06.3: should reject directory as evidence"
fi

# Test: evidence must not be empty (size 0)
mkdir -p "${WORK}/c06_test4/reports"
touch "${WORK}/c06_test4/reports/empty.log"
cat > "${WORK}/c06_test4/T-004.contract.json" <<'EOF'
{
  "task_id": "T-004",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/empty.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_contract "${WORK}/c06_test4/T-004.contract.json" "${WORK}/c06_test4")
if echo "$output" | grep -q "empty"; then
    ok "C-06.4: reject empty (0-byte) evidence file"
else
    fail "C-06.4: should reject empty evidence file"
fi

# Test: valid contract passes
mkdir -p "${WORK}/c06_test5/reports"
echo "test" > "${WORK}/c06_test5/reports/test.log"
make_valid_contract "T-005" "${WORK}/c06_test5" >/dev/null
if check_contract_passes "${WORK}/c06_test5/T-005.contract.json" "${WORK}/c06_test5"; then
    ok "C-06.5: valid contract with boolean types passes"
else
    fail "C-06.5: valid contract should pass"
fi

# ============================================================================
# C-07: Done State Strictness Tests
# ============================================================================

echo "=== C-07: Done State Strictness ==="

# Test: reject Done without contract.json
mkdir -p "${WORK}/c07_test1/verification"
mkdir -p "${WORK}/c07_test1/reports/quality-gate"
mkdir -p "${WORK}/c07_test1/reports/implementation"
cat > "${WORK}/c07_test1/tasks.md" <<'EOF'
# Tasks

## T-001

Approval: Approved
Status: Done
EOF
echo "test" > "${WORK}/c07_test1/verification/T-001.evidence.json"
output=$(run_check_task_state "${WORK}/c07_test1/tasks.md" \
    "${WORK}/c07_test1/reports/quality-gate" \
    "${WORK}/c07_test1/reports/implementation" \
    "${WORK}/c07_test1")
if echo "$output" | grep -q "contract.json does not exist"; then
    ok "C-07.1: reject Done without contract.json"
else
    fail "C-07.1: should require contract.json for Done task"
fi

# Test: reject Done with empty contract.json
mkdir -p "${WORK}/c07_test2/verification"
mkdir -p "${WORK}/c07_test2/reports/quality-gate"
mkdir -p "${WORK}/c07_test2/reports/implementation"
cat > "${WORK}/c07_test2/tasks.md" <<'EOF'
# Tasks

## T-002

Approval: Approved
Status: Done
EOF
echo "test" > "${WORK}/c07_test2/verification/T-002.evidence.json"
touch "${WORK}/c07_test2/verification/T-002.contract.json"
output=$(run_check_task_state "${WORK}/c07_test2/tasks.md" \
    "${WORK}/c07_test2/reports/quality-gate" \
    "${WORK}/c07_test2/reports/implementation" \
    "${WORK}/c07_test2")
if echo "$output" | grep -q "empty"; then
    ok "C-07.2: reject Done with empty contract.json"
else
    fail "C-07.2: should reject empty contract.json"
fi

# Test: reject Done with mismatched task_id in contract
mkdir -p "${WORK}/c07_test3/verification"
mkdir -p "${WORK}/c07_test3/reports/quality-gate"
mkdir -p "${WORK}/c07_test3/reports/implementation"
cat > "${WORK}/c07_test3/tasks.md" <<'EOF'
# Tasks

## T-003

Approval: Approved
Status: Done
EOF
echo "test" > "${WORK}/c07_test3/verification/T-003.evidence.json"
cat > "${WORK}/c07_test3/verification/T-003.contract.json" <<'EOF'
{
  "task_id": "T-004",
  "checks": []
}
EOF
output=$(run_check_task_state "${WORK}/c07_test3/tasks.md" \
    "${WORK}/c07_test3/reports/quality-gate" \
    "${WORK}/c07_test3/reports/implementation" \
    "${WORK}/c07_test3")
if echo "$output" | grep -q "mismatched task_id"; then
    ok "C-07.3: reject Done with mismatched contract task_id"
else
    fail "C-07.3: should reject mismatched task_id"
fi

# ============================================================================
# C-05: Sudo Approval Format Tests
# ============================================================================

echo "=== C-05: Sudo Approval Format ==="

# Test: valid sudo format passes
mkdir -p "${WORK}/c05_test1/reports/quality-gate"
mkdir -p "${WORK}/c05_test1/reports/implementation"
cat > "${WORK}/c05_test1/tasks.md" <<'EOF'
# Tasks

## T-001

Approval: Approved (sudo 2026-06-13T00:00:00Z)
Status: In Progress
EOF
if check_task_state_passes "${WORK}/c05_test1/tasks.md" \
    "${WORK}/c05_test1/reports/quality-gate" \
    "${WORK}/c05_test1/reports/implementation" \
    "${WORK}/c05_test1"; then
    ok "C-05.1: valid sudo format Approved (sudo ISO8601) passes"
else
    fail "C-05.1: valid sudo format should pass"
fi

# Test: invalid sudo format rejected
mkdir -p "${WORK}/c05_test2/reports/quality-gate"
mkdir -p "${WORK}/c05_test2/reports/implementation"
cat > "${WORK}/c05_test2/tasks.md" <<'EOF'
# Tasks

## T-002

Approval: Approved (sudo bogus)
Status: In Progress
EOF
output=$(run_check_task_state "${WORK}/c05_test2/tasks.md" \
    "${WORK}/c05_test2/reports/quality-gate" \
    "${WORK}/c05_test2/reports/implementation" \
    "${WORK}/c05_test2")
if echo "$output" | grep -q "invalid Approval"; then
    ok "C-05.2: reject malformed sudo format Approved (sudo bogus)"
else
    fail "C-05.2: should reject malformed sudo format"
fi

# Test: Approved (sudo ...) allows Done status
mkdir -p "${WORK}/c05_test3/verification"
mkdir -p "${WORK}/c05_test3/reports/quality-gate"
mkdir -p "${WORK}/c05_test3/reports/implementation"
echo "test" > "${WORK}/c05_test3/reports/quality-gate/test.log"
echo "test" > "${WORK}/c05_test3/reports/implementation/test.log"
cat > "${WORK}/c05_test3/tasks.md" <<'EOF'
# Tasks

## T-003

Approval: Approved (sudo 2026-06-13T00:00:00Z)
Status: Done
EOF
echo "test" > "${WORK}/c05_test3/verification/T-003.evidence.json"
cat > "${WORK}/c05_test3/verification/T-003.contract.json" <<'EOF'
{
  "task_id": "T-003",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/quality-gate/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_task_state "${WORK}/c05_test3/tasks.md" \
    "${WORK}/c05_test3/reports/quality-gate" \
    "${WORK}/c05_test3/reports/implementation" \
    "${WORK}/c05_test3")
if ! echo "$output" | grep -q "without Approval: Approved"; then
    ok "C-05.3: sudo-format Approved allows Done status"
else
    fail "C-05.3: sudo-format Approval should allow Done status"
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "====== Test Summary ======"
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo "=========================="

if [ $FAIL -eq 0 ]; then
    exit 0
else
    exit 1
fi
