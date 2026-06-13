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

# Invoke check-risk.sh and return output
run_check_risk() {
    local tasks="$1"
    local task_id="${2:-}"
    if [ -z "$task_id" ]; then
        bash "${SCRIPTS_DIR}/check-risk.sh" "$tasks" 2>&1 || true
    else
        bash "${SCRIPTS_DIR}/check-risk.sh" "$tasks" "$task_id" 2>&1 || true
    fi
}

# Check if check-risk passes (exit 0)
check_risk_passes() {
    local tasks="$1"
    local task_id="${2:-}"
    if [ -z "$task_id" ]; then
        bash "${SCRIPTS_DIR}/check-risk.sh" "$tasks" >/dev/null 2>&1
    else
        bash "${SCRIPTS_DIR}/check-risk.sh" "$tasks" "$task_id" >/dev/null 2>&1
    fi
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
# H-02: Evidence Bundle Round-Trip + git_commit Binding Tests
# ============================================================================

echo "=== H-02: Evidence Bundle Round-Trip + git_commit Binding ==="

# Helpers for H-02 that avoid set -e triggering on non-zero exit codes
# by capturing exit codes safely with ||
run_generate_bundle() {
    local contract="$1" report="$2" root="$3"
    "${SCRIPTS_DIR}/generate-evidence-bundle.sh" "$contract" "$report" "$root" 2>&1 || true
}
generate_bundle_passes() {
    local contract="$1" report="$2" root="$3"
    "${SCRIPTS_DIR}/generate-evidence-bundle.sh" "$contract" "$report" "$root" >/dev/null 2>&1
}
run_check_bundle() {
    local bundle="$1" root="$2"
    bash "${SCRIPTS_DIR}/check-evidence-bundle.sh" "$bundle" "$root" 2>&1 || true
}
check_bundle_passes() {
    local bundle="$1" root="$2"
    bash "${SCRIPTS_DIR}/check-evidence-bundle.sh" "$bundle" "$root" >/dev/null 2>&1
}

# Create a fixture git repo for these tests
H02_REPO="${WORK}/h02_repo"
mkdir -p "${H02_REPO}/specs/test-feature/verification"
mkdir -p "${H02_REPO}/reports/quality-gate"

# Configure git identity for CI (no global identity available)
git -C "${H02_REPO}" init -q
git -C "${H02_REPO}" config user.name ci
git -C "${H02_REPO}" config user.email ci@example.com
git -C "${H02_REPO}" config commit.gpgsign false

# Create evidence file and quality report
printf 'lint output: OK\n' > "${H02_REPO}/specs/test-feature/verification/ev.log"
cat > "${H02_REPO}/reports/quality-gate/T-099.md" <<'EOF'
Task ID: T-099
VERDICT: PASS
Quality gate report for T-099.
EOF

# Create a valid contract
cat > "${H02_REPO}/specs/test-feature/verification/T-099.contract.json" <<'EOF'
{
  "task_id": "T-099",
  "feature": "test-feature",
  "created": "2026-06-13T00:00:00Z",
  "comment": "H-02 test contract",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "integration-tests", "required": false, "passes": false, "evidence": "", "waiver_reason": "N/A" },
    { "id": "build", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "smoke-run", "required": false, "passes": false, "evidence": "", "waiver_reason": "manual only" },
    { "id": "differential-baseline", "required": false, "passes": false, "evidence": "", "waiver_reason": "not applicable" },
    { "id": "ui-verification", "required": false, "passes": false, "evidence": "", "waiver_reason": "no UI changes" }
  ]
}
EOF

# Commit everything so git_commit is valid
git -C "${H02_REPO}" add -A
git -C "${H02_REPO}" commit -q -m "H-02 fixture initial commit"

H02_COMMIT1="$(git -C "${H02_REPO}" rev-parse HEAD)"

# --- H-02.1: generate then check → PASS ---
if generate_bundle_passes \
    "${H02_REPO}/specs/test-feature/verification/T-099.contract.json" \
    "${H02_REPO}/reports/quality-gate/T-099.md" \
    "${H02_REPO}"; then
    ok "H-02.1a: generate-evidence-bundle succeeds"
else
    fail "H-02.1a: generate-evidence-bundle failed: $(run_generate_bundle \
        "${H02_REPO}/specs/test-feature/verification/T-099.contract.json" \
        "${H02_REPO}/reports/quality-gate/T-099.md" \
        "${H02_REPO}")"
fi

bundle_file="${H02_REPO}/specs/test-feature/verification/T-099.evidence.json"
if [ -f "$bundle_file" ]; then
    ok "H-02.1b: bundle file created at expected path"
else
    fail "H-02.1b: bundle file not created at expected path"
fi

if check_bundle_passes "$bundle_file" "${H02_REPO}"; then
    ok "H-02.1c: check-evidence-bundle passes on generated bundle"
else
    fail "H-02.1c: check-evidence-bundle should pass on generated bundle: $(run_check_bundle "$bundle_file" "${H02_REPO}")"
fi

# --- H-02.2: tamper artifact after generation → digest mismatch → FAIL ---
# Tamper ev.log; the bundle still has the old sha256, so check must fail
printf 'tampered\n' >> "${H02_REPO}/specs/test-feature/verification/ev.log"
h02_2_out="$(run_check_bundle "$bundle_file" "${H02_REPO}")"
if ! check_bundle_passes "$bundle_file" "${H02_REPO}" && \
   echo "$h02_2_out" | grep -q "sha256 mismatch"; then
    ok "H-02.2: tampered artifact → check fails with sha256 mismatch"
else
    fail "H-02.2: tampered artifact should cause sha256 mismatch failure: $h02_2_out"
fi

# Restore ev.log for subsequent tests
printf 'lint output: OK\n' > "${H02_REPO}/specs/test-feature/verification/ev.log"

# --- H-02.3: bogus/foreign git_commit → FAIL ---
# Overwrite git_commit with 40 f's (valid hex format but unknown commit)
python3 - <<PYEOF
import json, pathlib
p = pathlib.Path("${H02_REPO}/specs/test-feature/verification/T-099.evidence.json")
b = json.loads(p.read_text(encoding="utf-8"))
b["git_commit"] = "f" * 40
p.write_text(json.dumps(b, indent=2) + "\n", encoding="utf-8")
PYEOF
h02_3_out="$(run_check_bundle "$bundle_file" "${H02_REPO}")"
if ! check_bundle_passes "$bundle_file" "${H02_REPO}"; then
    ok "H-02.3: bogus git_commit → check-evidence-bundle fails"
else
    fail "H-02.3: bogus git_commit should cause check-evidence-bundle to fail: $h02_3_out"
fi

# --- H-02.4: missing git_commit → FAIL ---
python3 - <<PYEOF
import json, pathlib
p = pathlib.Path("${H02_REPO}/specs/test-feature/verification/T-099.evidence.json")
b = json.loads(p.read_text(encoding="utf-8"))
b.pop("git_commit", None)
p.write_text(json.dumps(b, indent=2) + "\n", encoding="utf-8")
PYEOF
h02_4_out="$(run_check_bundle "$bundle_file" "${H02_REPO}")"
if ! check_bundle_passes "$bundle_file" "${H02_REPO}" && \
   echo "$h02_4_out" | grep -q "git_commit is required"; then
    ok "H-02.4: missing git_commit → check-evidence-bundle fails"
else
    fail "H-02.4: missing git_commit should cause check-evidence-bundle to fail: $h02_4_out"
fi

# --- H-02.5: ancestor commit still PASSES ---
# Make a second commit, then test that a bundle with the first (ancestor) commit passes
printf 'second commit file\n' > "${H02_REPO}/second.txt"
git -C "${H02_REPO}" add second.txt
git -C "${H02_REPO}" commit -q -m "H-02 fixture second commit"

# Re-generate so digests are fresh (ev.log is now restored)
generate_bundle_passes \
    "${H02_REPO}/specs/test-feature/verification/T-099.contract.json" \
    "${H02_REPO}/reports/quality-gate/T-099.md" \
    "${H02_REPO}"

# Overwrite git_commit with the first (ancestor) commit sha
python3 - <<PYEOF
import json, pathlib
p = pathlib.Path("${H02_REPO}/specs/test-feature/verification/T-099.evidence.json")
b = json.loads(p.read_text(encoding="utf-8"))
b["git_commit"] = "${H02_COMMIT1}"
p.write_text(json.dumps(b, indent=2) + "\n", encoding="utf-8")
PYEOF
if check_bundle_passes "$bundle_file" "${H02_REPO}"; then
    ok "H-02.5: bundle with ancestor git_commit still passes check"
else
    fail "H-02.5: ancestor commit should pass check-evidence-bundle: $(run_check_bundle "$bundle_file" "${H02_REPO}")"
fi

# ============================================================================
# T-002: check-risk Tests
# ============================================================================

echo "=== T-002: check-risk ==="

# Test: T-002.1 - valid task with Risk and Rationale passes
mkdir -p "${WORK}/t002_test1"
cat > "${WORK}/t002_test1/tasks.md" <<'EOF'
# Tasks

## T-001

Risk: high
Risk Rationale: verifies tokens
Status: Planned
EOF
if check_risk_passes "${WORK}/t002_test1/tasks.md"; then
    ok "T-002.1: valid task with Risk: high and Rationale passes"
else
    fail "T-002.1: valid task should pass"
fi

# Test: T-002.2 - missing Risk line fails
mkdir -p "${WORK}/t002_test2"
cat > "${WORK}/t002_test2/tasks.md" <<'EOF'
# Tasks

## T-001

Risk Rationale: some reason
Status: Planned
EOF
output=$(run_check_risk "${WORK}/t002_test2/tasks.md")
if echo "$output" | grep -q "has no Risk line"; then
    ok "T-002.2: missing Risk line fails"
else
    fail "T-002.2: should fail on missing Risk line"
fi

# Test: T-002.3 - invalid Risk value fails
mkdir -p "${WORK}/t002_test3"
cat > "${WORK}/t002_test3/tasks.md" <<'EOF'
# Tasks

## T-001

Risk: severe
Risk Rationale: verifies tokens
Status: Planned
EOF
output=$(run_check_risk "${WORK}/t002_test3/tasks.md")
if echo "$output" | grep -q "has invalid Risk:"; then
    ok "T-002.3: invalid Risk value fails"
else
    fail "T-002.3: should fail on invalid Risk value"
fi

# Test: T-002.4 - placeholder Risk value fails
mkdir -p "${WORK}/t002_test4"
cat > "${WORK}/t002_test4/tasks.md" <<'EOF'
# Tasks

## T-001

Risk: {{risk}}
Risk Rationale: verifies tokens
Status: Planned
EOF
output=$(run_check_risk "${WORK}/t002_test4/tasks.md")
if echo "$output" | grep -q "has invalid Risk:"; then
    ok "T-002.4: placeholder Risk: {{risk}} fails"
else
    fail "T-002.4: should fail on placeholder Risk value"
fi

# Test: T-002.5 - empty Rationale fails
mkdir -p "${WORK}/t002_test5"
cat > "${WORK}/t002_test5/tasks.md" <<'EOF'
# Tasks

## T-001

Risk: high
Risk Rationale:
Status: Planned
EOF
output=$(run_check_risk "${WORK}/t002_test5/tasks.md")
if echo "$output" | grep -q "has empty Risk Rationale"; then
    ok "T-002.5: empty Risk Rationale fails"
else
    fail "T-002.5: should fail on empty Rationale"
fi

# Test: T-002.6 - missing Rationale line fails
mkdir -p "${WORK}/t002_test6"
cat > "${WORK}/t002_test6/tasks.md" <<'EOF'
# Tasks

## T-001

Risk: medium
Status: Planned
EOF
output=$(run_check_risk "${WORK}/t002_test6/tasks.md")
if echo "$output" | grep -q "has empty Risk Rationale"; then
    ok "T-002.6: missing Risk Rationale line fails"
else
    fail "T-002.6: should fail on missing Rationale line"
fi

# Test: T-002.7 - two valid tasks pass
mkdir -p "${WORK}/t002_test7"
cat > "${WORK}/t002_test7/tasks.md" <<'EOF'
# Tasks

## T-001

Risk: high
Risk Rationale: verifies tokens
Status: Planned

## T-002

Risk: low
Risk Rationale: documentation change
Status: Planned
EOF
if check_risk_passes "${WORK}/t002_test7/tasks.md"; then
    ok "T-002.7: two valid tasks pass"
else
    fail "T-002.7: two valid tasks should pass"
fi

# Test: T-002.8 - two tasks, one invalid fails
mkdir -p "${WORK}/t002_test8"
cat > "${WORK}/t002_test8/tasks.md" <<'EOF'
# Tasks

## T-001

Risk: high
Risk Rationale: verifies tokens
Status: Planned

## T-002

Risk: invalid_value
Risk Rationale: something
Status: Planned
EOF
output=$(run_check_risk "${WORK}/t002_test8/tasks.md")
if echo "$output" | grep -q "T-002 has invalid Risk:"; then
    ok "T-002.8: two tasks, one invalid fails"
else
    fail "T-002.8: should fail when one task is invalid"
fi

# Test: T-002.9 - file not found fails
output=$(run_check_risk "${WORK}/nonexistent.md")
if echo "$output" | grep -q "tasks file not found"; then
    ok "T-002.9: nonexistent file fails with correct message"
else
    fail "T-002.9: should fail with file not found message"
fi

# Test: T-002.10 - task-id arg selects one valid section among invalid file
mkdir -p "${WORK}/t002_test10"
cat > "${WORK}/t002_test10/tasks.md" <<'EOF'
# Tasks

## T-001

Risk: high
Risk Rationale: verifies tokens
Status: Planned

## T-002

Risk: bad_value
Risk Rationale: bad
Status: Planned
EOF
if check_risk_passes "${WORK}/t002_test10/tasks.md" "T-001"; then
    ok "T-002.10: task-id arg selects one valid section"
else
    fail "T-002.10: should pass when validating only specified task"
fi

# Test: T-002.11 - valid low risk passes
mkdir -p "${WORK}/t002_test11"
cat > "${WORK}/t002_test11/tasks.md" <<'EOF'
# Tasks

## T-001

Risk: low
Risk Rationale: documentation update
Status: Planned
EOF
if check_risk_passes "${WORK}/t002_test11/tasks.md"; then
    ok "T-002.11: valid Risk: low passes"
else
    fail "T-002.11: valid low risk should pass"
fi

# Test: T-002.12 - valid medium risk passes
mkdir -p "${WORK}/t002_test12"
cat > "${WORK}/t002_test12/tasks.md" <<'EOF'
# Tasks

## T-001

Risk: medium
Risk Rationale: normal feature implementation
Status: Planned
EOF
if check_risk_passes "${WORK}/t002_test12/tasks.md"; then
    ok "T-002.12: valid Risk: medium passes"
else
    fail "T-002.12: valid medium risk should pass"
fi

# Test: T-002.13 - valid critical risk passes
mkdir -p "${WORK}/t002_test13"
cat > "${WORK}/t002_test13/tasks.md" <<'EOF'
# Tasks

## T-001

Risk: critical
Risk Rationale: payment settlement path
Status: Planned
EOF
if check_risk_passes "${WORK}/t002_test13/tasks.md"; then
    ok "T-002.13: valid Risk: critical passes"
else
    fail "T-002.13: valid critical risk should pass"
fi

# Test: T-002.14 - task-id filter matching no task fails closed (no silent pass)
mkdir -p "${WORK}/t002_test14"
cat > "${WORK}/t002_test14/tasks.md" <<'EOF'
# Tasks

## T-001

Risk: high
Risk Rationale: verifies tokens
Status: Planned
EOF
output=$(run_check_risk "${WORK}/t002_test14/tasks.md" "T-999")
if echo "$output" | grep -q "requested task T-999 not found"; then
    ok "T-002.14: filter task-id not found fails closed"
else
    fail "T-002.14: missing filter task-id must fail closed, not silently pass"
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
