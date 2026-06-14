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

# Invoke check-traceability.sh and return output
run_check_traceability() {
    local traceability="$1"
    local root="${2:-.}"
    local require_evidence="${3:-}"
    if [ -z "$require_evidence" ]; then
        bash "${SCRIPTS_DIR}/check-traceability.sh" "$traceability" "$root" 2>&1 || true
    else
        bash "${SCRIPTS_DIR}/check-traceability.sh" "$traceability" "$root" "$require_evidence" 2>&1 || true
    fi
}

# Check if check-traceability passes (exit 0)
check_traceability_passes() {
    local traceability="$1"
    local root="${2:-.}"
    local require_evidence="${3:-}"
    if [ -z "$require_evidence" ]; then
        bash "${SCRIPTS_DIR}/check-traceability.sh" "$traceability" "$root" >/dev/null 2>&1
    else
        bash "${SCRIPTS_DIR}/check-traceability.sh" "$traceability" "$root" "$require_evidence" >/dev/null 2>&1
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
Required Workflow: tdd
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
Required Workflow: tdd
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
Required Workflow: tdd
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
Required Workflow: tdd
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
Required Workflow: tdd
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

# Test: T-002.15 - high risk WITHOUT Required Workflow line fails (T-010 follow-up)
mkdir -p "${WORK}/t002_test15"
cat > "${WORK}/t002_test15/tasks.md" <<'EOF'
# Tasks

## T-001

Risk: high
Risk Rationale: verifies tokens
Status: Planned
EOF
output=$(run_check_risk "${WORK}/t002_test15/tasks.md")
if echo "$output" | grep -q "Required Workflow: tdd"; then
    ok "T-002.15: high risk without Required Workflow fails"
else
    fail "T-002.15: high risk must require Required Workflow: tdd"
fi

# Test: T-002.16 - high risk with WRONG (too-weak) workflow fails
mkdir -p "${WORK}/t002_test16"
cat > "${WORK}/t002_test16/tasks.md" <<'EOF'
# Tasks

## T-001

Risk: high
Risk Rationale: verifies tokens
Required Workflow: acceptance-first
Status: Planned
EOF
output=$(run_check_risk "${WORK}/t002_test16/tasks.md")
if echo "$output" | grep -q "Required Workflow: tdd"; then
    ok "T-002.16: high risk with acceptance-first fails (must be tdd)"
else
    fail "T-002.16: high risk with non-tdd workflow must fail"
fi

# Test: T-002.17 - critical risk WITHOUT Required Workflow fails
mkdir -p "${WORK}/t002_test17"
cat > "${WORK}/t002_test17/tasks.md" <<'EOF'
# Tasks

## T-001

Risk: critical
Risk Rationale: payment settlement path
Status: Planned
EOF
output=$(run_check_risk "${WORK}/t002_test17/tasks.md")
if echo "$output" | grep -q "Required Workflow: tdd"; then
    ok "T-002.17: critical risk without Required Workflow fails"
else
    fail "T-002.17: critical risk must require Required Workflow: tdd"
fi

# Test: T-002.18 - high risk WITH Required Workflow: tdd passes
mkdir -p "${WORK}/t002_test18"
cat > "${WORK}/t002_test18/tasks.md" <<'EOF'
# Tasks

## T-001

Risk: high
Risk Rationale: verifies tokens
Required Workflow: tdd
Status: Planned
EOF
if check_risk_passes "${WORK}/t002_test18/tasks.md"; then
    ok "T-002.18: high risk with Required Workflow: tdd passes"
else
    fail "T-002.18: high risk + tdd should pass"
fi

# Test: T-002.19 - critical risk WITH Required Workflow: tdd passes
mkdir -p "${WORK}/t002_test19"
cat > "${WORK}/t002_test19/tasks.md" <<'EOF'
# Tasks

## T-001

Risk: critical
Risk Rationale: payment settlement path
Required Workflow: tdd
Status: Planned
EOF
if check_risk_passes "${WORK}/t002_test19/tasks.md"; then
    ok "T-002.19: critical risk with Required Workflow: tdd passes"
else
    fail "T-002.19: critical risk + tdd should pass"
fi

# Test: T-002.20 - medium risk withOUT Required Workflow passes (rule scoped to high/critical)
mkdir -p "${WORK}/t002_test20"
cat > "${WORK}/t002_test20/tasks.md" <<'EOF'
# Tasks

## T-001

Risk: medium
Risk Rationale: normal feature implementation
Status: Planned
EOF
if check_risk_passes "${WORK}/t002_test20/tasks.md"; then
    ok "T-002.20: medium risk without Required Workflow passes (not over-enforced)"
else
    fail "T-002.20: medium risk must NOT require tdd workflow"
fi

# ============================================================================
# T-003: risk-aware check-contract Tests
# ============================================================================

echo "=== T-003: risk-aware check-contract ==="

# Helper to create evidence file for a contract
create_evidence() {
    local path="$1"
    mkdir -p "$(dirname "$path")"
    echo "evidence data" > "$path"
}

# Test: T-003.1 - LEGACY: contract with NO risk field passes (regression test)
mkdir -p "${WORK}/t003_test1/reports"
create_evidence "${WORK}/t003_test1/reports/test.log"
cat > "${WORK}/t003_test1/T-003.1.contract.json" <<'EOF'
{
  "task_id": "T-003.1",
  "feature": "test-feature",
  "created": "2026-06-13T00:00:00Z",
  "comment": "LEGACY: no risk field",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
if check_contract_passes "${WORK}/t003_test1/T-003.1.contract.json" "${WORK}/t003_test1"; then
    ok "T-003.1: LEGACY (no risk field) with baseline set passes"
else
    fail "T-003.1: LEGACY contract should pass"
fi

# Test: T-003.2 - risk: low with required set all required:true+passing
mkdir -p "${WORK}/t003_test2/reports"
create_evidence "${WORK}/t003_test2/reports/test.log"
cat > "${WORK}/t003_test2/T-003.2.contract.json" <<'EOF'
{
  "task_id": "T-003.2",
  "feature": "test-feature",
  "risk": "low",
  "created": "2026-06-13T00:00:00Z",
  "comment": "risk: low, required set (unit-tests optional per low tier)",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": false, "passes": false, "evidence": "", "waiver_reason": "test-after approach" }
  ]
}
EOF
if check_contract_passes "${WORK}/t003_test2/T-003.2.contract.json" "${WORK}/t003_test2"; then
    ok "T-003.2: risk: low with required set passes (unit-tests optional)"
else
    fail "T-003.2: risk: low should pass with required set"
fi

# Test: T-003.3 - risk: low but build required:false → FAILS
mkdir -p "${WORK}/t003_test3/reports"
create_evidence "${WORK}/t003_test3/reports/test.log"
cat > "${WORK}/t003_test3/T-003.3.contract.json" <<'EOF'
{
  "task_id": "T-003.3",
  "feature": "test-feature",
  "risk": "low",
  "created": "2026-06-13T00:00:00Z",
  "comment": "risk: low, but build is required:false (should fail)",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": false, "passes": false, "evidence": "", "waiver_reason": "downgraded" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_contract "${WORK}/t003_test3/T-003.3.contract.json" "${WORK}/t003_test3")
if echo "$output" | grep -q "requires check 'build' to be required:true"; then
    ok "T-003.3: risk: low with build required:false fails correctly"
else
    fail "T-003.3: should fail with 'requires check build to be required:true'. Got: $output"
fi

# Test: T-003.4 - risk: medium WITHOUT acceptance-tests check → FAILS
mkdir -p "${WORK}/t003_test4/reports"
create_evidence "${WORK}/t003_test4/reports/test.log"
cat > "${WORK}/t003_test4/T-003.4.contract.json" <<'EOF'
{
  "task_id": "T-003.4",
  "feature": "test-feature",
  "risk": "medium",
  "created": "2026-06-13T00:00:00Z",
  "comment": "risk: medium, missing acceptance-tests",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_contract "${WORK}/t003_test4/T-003.4.contract.json" "${WORK}/t003_test4")
if echo "$output" | grep -q "requires check 'acceptance-tests' present"; then
    ok "T-003.4: risk: medium missing acceptance-tests fails correctly"
else
    fail "T-003.4: should fail with 'requires check acceptance-tests present'. Got: $output"
fi

# Test: T-003.5 - risk: medium full (adds unit-tests, acceptance-tests, regression)
mkdir -p "${WORK}/t003_test5/reports"
create_evidence "${WORK}/t003_test5/reports/test.log"
cat > "${WORK}/t003_test5/T-003.5.contract.json" <<'EOF'
{
  "task_id": "T-003.5",
  "feature": "test-feature",
  "risk": "medium",
  "created": "2026-06-13T00:00:00Z",
  "comment": "risk: medium, full required set",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
if check_contract_passes "${WORK}/t003_test5/T-003.5.contract.json" "${WORK}/t003_test5"; then
    ok "T-003.5: risk: medium with full required set passes"
else
    fail "T-003.5: risk: medium with full set should pass"
fi

# Test: T-003.6 - risk: high WITHOUT requirement-traceability → FAILS
mkdir -p "${WORK}/t003_test6/reports"
create_evidence "${WORK}/t003_test6/reports/test.log"
cat > "${WORK}/t003_test6/T-003.6.contract.json" <<'EOF'
{
  "task_id": "T-003.6",
  "feature": "test-feature",
  "risk": "high",
  "created": "2026-06-13T00:00:00Z",
  "comment": "risk: high, missing requirement-traceability",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_contract "${WORK}/t003_test6/T-003.6.contract.json" "${WORK}/t003_test6")
if echo "$output" | grep -q "requires check 'requirement-traceability' present"; then
    ok "T-003.6: risk: high missing requirement-traceability fails correctly"
else
    fail "T-003.6: should fail with 'requires check requirement-traceability present'. Got: $output"
fi

# Test: T-003.7 - risk: high full (adds requirement-traceability)
mkdir -p "${WORK}/t003_test7/reports"
create_evidence "${WORK}/t003_test7/reports/test.log"
cat > "${WORK}/t003_test7/T-003.7.contract.json" <<'EOF'
{
  "task_id": "T-003.7",
  "feature": "test-feature",
  "risk": "high",
  "created": "2026-06-13T00:00:00Z",
  "comment": "risk: high, full required set",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
if check_contract_passes "${WORK}/t003_test7/T-003.7.contract.json" "${WORK}/t003_test7"; then
    ok "T-003.7: risk: high with full required set passes"
else
    fail "T-003.7: risk: high with full set should pass"
fi

# Test: T-003.8 - risk: critical (same set as high)
mkdir -p "${WORK}/t003_test8/reports"
create_evidence "${WORK}/t003_test8/reports/test.log"
cat > "${WORK}/t003_test8/T-003.8.contract.json" <<'EOF'
{
  "task_id": "T-003.8",
  "feature": "test-feature",
  "risk": "critical",
  "created": "2026-06-13T00:00:00Z",
  "comment": "risk: critical, full required set (same as high)",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
if check_contract_passes "${WORK}/t003_test8/T-003.8.contract.json" "${WORK}/t003_test8"; then
    ok "T-003.8: risk: critical with full required set passes"
else
    fail "T-003.8: risk: critical with full set should pass"
fi

# Test: T-003.9 - risk: "severe" (invalid) → FAILS
mkdir -p "${WORK}/t003_test9/reports"
create_evidence "${WORK}/t003_test9/reports/test.log"
cat > "${WORK}/t003_test9/T-003.9.contract.json" <<'EOF'
{
  "task_id": "T-003.9",
  "feature": "test-feature",
  "risk": "severe",
  "created": "2026-06-13T00:00:00Z",
  "comment": "risk: severe (invalid)",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_contract "${WORK}/t003_test9/T-003.9.contract.json" "${WORK}/t003_test9")
if echo "$output" | grep -q "contract risk is invalid"; then
    ok "T-003.9: risk: 'severe' (invalid) fails correctly"
else
    fail "T-003.9: should fail with 'contract risk is invalid'. Got: $output"
fi

# ============================================================================
# T-012: stack descriptor — compile-checks waivable on non-code stacks
#  (lint/typecheck/build) while test/trace/placeholder/task-state stay mandatory.
# ============================================================================

echo "=== T-012: stack descriptor (compile-check applicability) ==="

# Test: T-012.1 - stack: docs, medium, compile checks waived (required:false+reason),
#   test set required:true+passing → PASSES (the new behavior).
mkdir -p "${WORK}/t012_test1/reports"
create_evidence "${WORK}/t012_test1/reports/test.log"
cat > "${WORK}/t012_test1/T-012.1.contract.json" <<'EOF'
{
  "task_id": "T-012.1",
  "feature": "test-feature",
  "risk": "medium",
  "stack": "docs",
  "created": "2026-06-13T00:00:00Z",
  "comment": "stack docs: lint/typecheck/build waivable",
  "checks": [
    { "id": "lint", "required": false, "passes": false, "evidence": "", "waiver_reason": "docs/json repo: no lint toolchain" },
    { "id": "typecheck", "required": false, "passes": false, "evidence": "", "waiver_reason": "no typed language" },
    { "id": "build", "required": false, "passes": false, "evidence": "", "waiver_reason": "no build step" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
if check_contract_passes "${WORK}/t012_test1/T-012.1.contract.json" "${WORK}/t012_test1"; then
    ok "T-012.1: stack docs waives compile checks with reasons → passes"
else
    fail "T-012.1: stack docs should pass with compile checks waived"
fi

# Test: T-012.2 - stack ABSENT (legacy=code), medium, build required:false → STILL FAILS (backward compat).
mkdir -p "${WORK}/t012_test2/reports"
create_evidence "${WORK}/t012_test2/reports/test.log"
cat > "${WORK}/t012_test2/T-012.2.contract.json" <<'EOF'
{
  "task_id": "T-012.2",
  "feature": "test-feature",
  "risk": "medium",
  "created": "2026-06-13T00:00:00Z",
  "comment": "no stack = code: build must be required:true",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": false, "passes": false, "evidence": "", "waiver_reason": "no build" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_contract "${WORK}/t012_test2/T-012.2.contract.json" "${WORK}/t012_test2")
if echo "$output" | grep -q "requires check 'build' to be required:true"; then
    ok "T-012.2: absent stack (=code) keeps build mandatory (backward compat)"
else
    fail "T-012.2: absent stack should keep build mandatory. Got: $output"
fi

# Test: T-012.3 - stack: docs but unit-tests required:false → STILL FAILS (tests never waivable).
mkdir -p "${WORK}/t012_test3/reports"
create_evidence "${WORK}/t012_test3/reports/test.log"
cat > "${WORK}/t012_test3/T-012.3.contract.json" <<'EOF'
{
  "task_id": "T-012.3",
  "feature": "test-feature",
  "risk": "medium",
  "stack": "docs",
  "created": "2026-06-13T00:00:00Z",
  "comment": "abuse vector: docs must NOT waive unit-tests",
  "checks": [
    { "id": "lint", "required": false, "passes": false, "evidence": "", "waiver_reason": "no lint" },
    { "id": "typecheck", "required": false, "passes": false, "evidence": "", "waiver_reason": "no types" },
    { "id": "build", "required": false, "passes": false, "evidence": "", "waiver_reason": "no build" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": false, "passes": false, "evidence": "", "waiver_reason": "trying to skip tests" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_contract "${WORK}/t012_test3/T-012.3.contract.json" "${WORK}/t012_test3")
if echo "$output" | grep -q "requires check 'unit-tests' to be required:true"; then
    ok "T-012.3: stack docs cannot waive unit-tests (abuse blocked)"
else
    fail "T-012.3: stack docs must keep unit-tests mandatory. Got: $output"
fi

# Test: T-012.4 - stack: docs, lint required:false WITHOUT waiver_reason → STILL FAILS.
mkdir -p "${WORK}/t012_test4/reports"
create_evidence "${WORK}/t012_test4/reports/test.log"
cat > "${WORK}/t012_test4/T-012.4.contract.json" <<'EOF'
{
  "task_id": "T-012.4",
  "feature": "test-feature",
  "risk": "medium",
  "stack": "docs",
  "created": "2026-06-13T00:00:00Z",
  "comment": "waived compile check still needs a reason",
  "checks": [
    { "id": "lint", "required": false, "passes": false, "evidence": "", "waiver_reason": "" },
    { "id": "typecheck", "required": false, "passes": false, "evidence": "", "waiver_reason": "no types" },
    { "id": "build", "required": false, "passes": false, "evidence": "", "waiver_reason": "no build" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
if check_contract_passes "${WORK}/t012_test4/T-012.4.contract.json" "${WORK}/t012_test4"; then
    fail "T-012.4: waived lint without reason should FAIL"
else
    ok "T-012.4: stack docs waiver still requires waiver_reason"
fi

# Test: T-012.5 - stack: code (explicit), build required:false → FAILS (explicit code = legacy).
mkdir -p "${WORK}/t012_test5/reports"
create_evidence "${WORK}/t012_test5/reports/test.log"
cat > "${WORK}/t012_test5/T-012.5.contract.json" <<'EOF'
{
  "task_id": "T-012.5",
  "feature": "test-feature",
  "risk": "medium",
  "stack": "code",
  "created": "2026-06-13T00:00:00Z",
  "comment": "explicit code stack keeps compile checks mandatory",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": false, "passes": false, "evidence": "", "waiver_reason": "trying to skip" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_contract "${WORK}/t012_test5/T-012.5.contract.json" "${WORK}/t012_test5")
if echo "$output" | grep -q "requires check 'build' to be required:true"; then
    ok "T-012.5: explicit stack code keeps build mandatory"
else
    fail "T-012.5: explicit code stack should keep build mandatory. Got: $output"
fi

# Test: T-012.6 - invalid stack value → FAILS.
mkdir -p "${WORK}/t012_test6/reports"
create_evidence "${WORK}/t012_test6/reports/test.log"
cat > "${WORK}/t012_test6/T-012.6.contract.json" <<'EOF'
{
  "task_id": "T-012.6",
  "feature": "test-feature",
  "risk": "low",
  "stack": "bogus",
  "created": "2026-06-13T00:00:00Z",
  "comment": "unknown stack must fail",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": false, "passes": false, "evidence": "", "waiver_reason": "low tier: test-after" }
  ]
}
EOF
output=$(run_check_contract "${WORK}/t012_test6/T-012.6.contract.json" "${WORK}/t012_test6")
if echo "$output" | grep -q "contract stack is invalid"; then
    ok "T-012.6: invalid stack value fails correctly"
else
    fail "T-012.6: should fail with 'contract stack is invalid'. Got: $output"
fi

# Test: T-012.7 - stack: shell, HIGH tier + tdd (Red→Green), compile waived + full
#   test set + traceability → PASSES. Proves stack composes with the tdd/high rules.
mkdir -p "${WORK}/t012_test7/reports"
create_evidence "${WORK}/t012_test7/reports/test.log"
create_evidence "${WORK}/t012_test7/reports/test.red.log"
create_evidence "${WORK}/t012_test7/reports/test.green.log"
cat > "${WORK}/t012_test7/T-012.7.contract.json" <<'EOF'
{
  "task_id": "T-012.7",
  "feature": "test-feature",
  "risk": "high",
  "stack": "shell",
  "required_workflow": "tdd",
  "created": "2026-06-13T00:00:00Z",
  "comment": "shell stack at high tier with tdd red/green",
  "checks": [
    { "id": "lint", "required": false, "passes": false, "evidence": "", "waiver_reason": "shell repo: no lint target" },
    { "id": "typecheck", "required": false, "passes": false, "evidence": "", "waiver_reason": "no typed language" },
    { "id": "build", "required": false, "passes": false, "evidence": "", "waiver_reason": "no build step" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "", "red_evidence": "reports/test.red.log", "green_evidence": "reports/test.green.log" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "", "red_evidence": "reports/test.red.log", "green_evidence": "reports/test.green.log" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
if check_contract_passes "${WORK}/t012_test7/T-012.7.contract.json" "${WORK}/t012_test7"; then
    ok "T-012.7: stack shell at high+tdd tier waives compile checks → passes"
else
    fail "T-012.7: stack shell high+tdd tier should pass with compile checks waived"
fi

# ============================================================================
# T-004: Red→Green evidence enforcement
# ============================================================================

echo "=== T-004: Red→Green evidence enforcement ==="

# Test: T-004.1 - LEGACY: no risk, no required_workflow, valid set → passes (regression)
mkdir -p "${WORK}/t004_test1/reports"
echo "test" > "${WORK}/t004_test1/reports/test.log"
cat > "${WORK}/t004_test1/T-001.contract.json" <<'EOF'
{
  "task_id": "T-001",
  "feature": "test-feature",
  "created": "2026-06-13T00:00:00Z",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
if check_contract_passes "${WORK}/t004_test1/T-001.contract.json" "${WORK}/t004_test1"; then
    ok "T-004.1: LEGACY (no risk, no required_workflow) passes without red/green"
else
    fail "T-004.1: LEGACY contract should pass"
fi

# Test: T-004.2 - required_workflow: test-after (low), no red/green present → passes (no tdd requirement)
mkdir -p "${WORK}/t004_test2/reports"
echo "test" > "${WORK}/t004_test2/reports/test.log"
cat > "${WORK}/t004_test2/T-002.contract.json" <<'EOF'
{
  "task_id": "T-002",
  "feature": "test-feature",
  "risk": "low",
  "required_workflow": "test-after",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": false, "passes": false, "evidence": "", "waiver_reason": "test-after workflow" }
  ]
}
EOF
if check_contract_passes "${WORK}/t004_test2/T-002.contract.json" "${WORK}/t004_test2"; then
    ok "T-004.2: required_workflow: test-after (low) passes without red/green"
else
    fail "T-004.2: test-after workflow should pass without red/green"
fi

# Test: T-004.3 - required_workflow: tdd, unit-tests and acceptance-tests required:true WITH valid red_evidence+green_evidence → passes
mkdir -p "${WORK}/t004_test3/reports"
echo "test" > "${WORK}/t004_test3/reports/test.log"
echo "red log" > "${WORK}/t004_test3/reports/red.log"
echo "green log" > "${WORK}/t004_test3/reports/green.log"
cat > "${WORK}/t004_test3/T-003.contract.json" <<'EOF'
{
  "task_id": "T-003",
  "feature": "test-feature",
  "risk": "high",
  "required_workflow": "tdd",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "", "red_evidence": "reports/red.log", "green_evidence": "reports/green.log" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "", "red_evidence": "reports/red.log", "green_evidence": "reports/green.log" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
if check_contract_passes "${WORK}/t004_test3/T-003.contract.json" "${WORK}/t004_test3"; then
    ok "T-004.3: required_workflow: tdd with valid red+green evidence passes"
else
    fail "T-004.3: tdd contract with red/green should pass"
fi

# Test: T-004.4 - required_workflow: tdd, unit-tests required:true MISSING red_evidence → FAILS
mkdir -p "${WORK}/t004_test4/reports"
echo "test" > "${WORK}/t004_test4/reports/test.log"
echo "green log" > "${WORK}/t004_test4/reports/green.log"
cat > "${WORK}/t004_test4/T-004.contract.json" <<'EOF'
{
  "task_id": "T-004",
  "feature": "test-feature",
  "risk": "high",
  "required_workflow": "tdd",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "", "red_evidence": "", "green_evidence": "reports/green.log" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_contract "${WORK}/t004_test4/T-004.contract.json" "${WORK}/t004_test4")
if echo "$output" | grep -q "needs non-empty red_evidence"; then
    ok "T-004.4: missing red_evidence fails with correct message"
else
    fail "T-004.4: should fail with 'needs non-empty red_evidence'. Got: $output"
fi

# Test: T-004.5 - required_workflow: tdd, unit-tests required:true with red_evidence pointing at NON-EXISTENT file → FAILS
mkdir -p "${WORK}/t004_test5/reports"
echo "test" > "${WORK}/t004_test5/reports/test.log"
cat > "${WORK}/t004_test5/T-005.contract.json" <<'EOF'
{
  "task_id": "T-005",
  "feature": "test-feature",
  "risk": "high",
  "required_workflow": "tdd",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "", "red_evidence": "reports/missing-red.log", "green_evidence": "reports/test.log" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_contract "${WORK}/t004_test5/T-005.contract.json" "${WORK}/t004_test5")
if echo "$output" | grep -q "red_evidence file missing"; then
    ok "T-004.5: non-existent red_evidence file fails correctly"
else
    fail "T-004.5: should fail with 'red_evidence file missing'. Got: $output"
fi

# Test: T-004.6 - risk: high, required_workflow: acceptance-first (wrong workflow) → FAILS
mkdir -p "${WORK}/t004_test6/reports"
echo "test" > "${WORK}/t004_test6/reports/test.log"
cat > "${WORK}/t004_test6/T-006.contract.json" <<'EOF'
{
  "task_id": "T-006",
  "feature": "test-feature",
  "risk": "high",
  "required_workflow": "acceptance-first",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_contract "${WORK}/t004_test6/T-006.contract.json" "${WORK}/t004_test6")
if echo "$output" | grep -q "risk high requires required_workflow: tdd"; then
    ok "T-004.6: risk high with wrong required_workflow fails"
else
    fail "T-004.6: should fail with 'risk high requires required_workflow: tdd'. Got: $output"
fi

# Test: T-004.7 - risk: high, required_workflow: tdd, FULL high tier set required:true with red+green → passes
mkdir -p "${WORK}/t004_test7/reports"
echo "test" > "${WORK}/t004_test7/reports/test.log"
echo "red log" > "${WORK}/t004_test7/reports/red.log"
echo "green log" > "${WORK}/t004_test7/reports/green.log"
cat > "${WORK}/t004_test7/T-007.contract.json" <<'EOF'
{
  "task_id": "T-007",
  "feature": "test-feature",
  "risk": "high",
  "required_workflow": "tdd",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "", "red_evidence": "reports/red.log", "green_evidence": "reports/green.log" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "", "red_evidence": "reports/red.log", "green_evidence": "reports/green.log" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
if check_contract_passes "${WORK}/t004_test7/T-007.contract.json" "${WORK}/t004_test7"; then
    ok "T-004.7: risk high full tier set with tdd red+green passes"
else
    fail "T-004.7: full high tier set with tdd should pass"
fi

# ============================================================================
# T-005: check-traceability
# ============================================================================

echo "=== T-005: check-traceability ==="

# Test: T-005.1 - valid traceability (req+acs+tests, no evidence, no require-evidence) → exit 0
mkdir -p "${WORK}/t005_test1"
cat > "${WORK}/t005_test1/traceability.json" <<'EOF'
{
  "feature": "test-feature",
  "links": [
    { "req": "REQ-001", "acs": ["AC-001"], "tests": ["TEST-001"] }
  ]
}
EOF
if check_traceability_passes "${WORK}/t005_test1/traceability.json" "${WORK}/t005_test1"; then
    ok "T-005.1: valid traceability (req+acs+tests, no evidence) passes"
else
    fail "T-005.1: valid traceability should pass"
fi

# Test: T-005.2 - empty acs array → exit 1 ("has no acceptance criteria")
mkdir -p "${WORK}/t005_test2"
cat > "${WORK}/t005_test2/traceability.json" <<'EOF'
{
  "feature": "test-feature",
  "links": [
    { "req": "REQ-001", "acs": [], "tests": ["TEST-001"] }
  ]
}
EOF
output=$(run_check_traceability "${WORK}/t005_test2/traceability.json" "${WORK}/t005_test2")
if echo "$output" | grep -q "has no acceptance criteria"; then
    ok "T-005.2: empty acs array fails with correct message"
else
    fail "T-005.2: should fail with 'has no acceptance criteria'. Got: $output"
fi

# Test: T-005.3 - empty tests array → exit 1 ("has no tests")
mkdir -p "${WORK}/t005_test3"
cat > "${WORK}/t005_test3/traceability.json" <<'EOF'
{
  "feature": "test-feature",
  "links": [
    { "req": "REQ-001", "acs": ["AC-001"], "tests": [] }
  ]
}
EOF
output=$(run_check_traceability "${WORK}/t005_test3/traceability.json" "${WORK}/t005_test3")
if echo "$output" | grep -q "has no tests"; then
    ok "T-005.3: empty tests array fails with correct message"
else
    fail "T-005.3: should fail with 'has no tests'. Got: $output"
fi

# Test: T-005.4 - evidence key present but file missing → exit 1
mkdir -p "${WORK}/t005_test4"
cat > "${WORK}/t005_test4/traceability.json" <<'EOF'
{
  "feature": "test-feature",
  "links": [
    { "req": "REQ-001", "acs": ["AC-001"], "tests": ["TEST-001"], "evidence": ["specs/missing.log"] }
  ]
}
EOF
output=$(run_check_traceability "${WORK}/t005_test4/traceability.json" "${WORK}/t005_test4")
if echo "$output" | grep -q "file missing"; then
    ok "T-005.4: missing evidence file fails correctly"
else
    fail "T-005.4: should fail with 'file missing'. Got: $output"
fi

# Test: T-005.5 - evidence present + existing non-empty file → exit 0
mkdir -p "${WORK}/t005_test5/specs/test-feature/verification"
echo "evidence data" > "${WORK}/t005_test5/specs/test-feature/verification/T-001.unit.log"
cat > "${WORK}/t005_test5/traceability.json" <<'EOF'
{
  "feature": "test-feature",
  "links": [
    { "req": "REQ-001", "acs": ["AC-001"], "tests": ["TEST-001"], "evidence": ["specs/test-feature/verification/T-001.unit.log"] }
  ]
}
EOF
if check_traceability_passes "${WORK}/t005_test5/traceability.json" "${WORK}/t005_test5"; then
    ok "T-005.5: evidence file present and non-empty passes"
else
    fail "T-005.5: should pass with existing evidence file"
fi

# Test: T-005.6 - require-evidence mode, link has NO evidence → exit 1 ("requires evidence")
mkdir -p "${WORK}/t005_test6"
cat > "${WORK}/t005_test6/traceability.json" <<'EOF'
{
  "feature": "test-feature",
  "links": [
    { "req": "REQ-001", "acs": ["AC-001"], "tests": ["TEST-001"] }
  ]
}
EOF
output=$(run_check_traceability "${WORK}/t005_test6/traceability.json" "${WORK}/t005_test6" "require-evidence")
if echo "$output" | grep -q "requires evidence"; then
    ok "T-005.6: require-evidence mode without evidence fails correctly"
else
    fail "T-005.6: should fail with 'requires evidence'. Got: $output"
fi

# Test: T-005.7 - require-evidence mode, link has existing evidence → exit 0
mkdir -p "${WORK}/t005_test7/specs/test-feature/verification"
echo "evidence data" > "${WORK}/t005_test7/specs/test-feature/verification/T-001.unit.log"
cat > "${WORK}/t005_test7/traceability.json" <<'EOF'
{
  "feature": "test-feature",
  "links": [
    { "req": "REQ-001", "acs": ["AC-001"], "tests": ["TEST-001"], "evidence": ["specs/test-feature/verification/T-001.unit.log"] }
  ]
}
EOF
if check_traceability_passes "${WORK}/t005_test7/traceability.json" "${WORK}/t005_test7" "require-evidence"; then
    ok "T-005.7: require-evidence mode with evidence passes"
else
    fail "T-005.7: should pass with evidence in require-evidence mode"
fi

# Test: T-005.8 - invalid JSON → exit 1
mkdir -p "${WORK}/t005_test8"
echo "{ invalid json" > "${WORK}/t005_test8/traceability.json"
output=$(run_check_traceability "${WORK}/t005_test8/traceability.json" "${WORK}/t005_test8")
if echo "$output" | grep -q "invalid JSON"; then
    ok "T-005.8: invalid JSON fails with correct message"
else
    fail "T-005.8: should fail with 'invalid JSON'. Got: $output"
fi

# Test: T-005.9 - file not found → exit 1
output=$(run_check_traceability "${WORK}/nonexistent.json" "${WORK}")
if echo "$output" | grep -q "file not found"; then
    ok "T-005.9: nonexistent file fails with correct message"
else
    fail "T-005.9: should fail with 'file not found'. Got: $output"
fi

# Test: T-005.10 - links empty array → exit 1 ("has no links")
mkdir -p "${WORK}/t005_test10"
cat > "${WORK}/t005_test10/traceability.json" <<'EOF'
{
  "feature": "test-feature",
  "links": []
}
EOF
output=$(run_check_traceability "${WORK}/t005_test10/traceability.json" "${WORK}/t005_test10")
if echo "$output" | grep -q "has no links"; then
    ok "T-005.10: empty links array fails with correct message"
else
    fail "T-005.10: should fail with 'has no links'. Got: $output"
fi

# Test: T-005.11 - require-evidence with EMPTY evidence array fails closed (no silent pass)
mkdir -p "${WORK}/t005_test11"
cat > "${WORK}/t005_test11/traceability.json" <<'EOF'
{
  "feature": "test-feature",
  "links": [ { "req": "REQ-001", "acs": ["AC-001"], "tests": ["TEST-001"], "evidence": [] } ]
}
EOF
output=$(bash "${SCRIPTS_DIR}/check-traceability.sh" "${WORK}/t005_test11/traceability.json" "${WORK}/t005_test11" require-evidence 2>&1 || true)
if echo "$output" | grep -q "requires evidence but none listed"; then
    ok "T-005.11: require-evidence + empty array fails closed"
else
    fail "T-005.11: empty evidence array must fail in require-evidence mode. Got: $output"
fi

# ============================================================================
# T-006: Evidence bundle provenance (risk, spec_revision, build_env, builder, review_verdict)
# ============================================================================

echo "=== T-006: evidence provenance ==="

# Create a reusable high-risk repo for T-006 tests
T006_REPO="${WORK}/t006_repo"
mkdir -p "${T006_REPO}/specs/test-feature/verification"
mkdir -p "${T006_REPO}/reports/quality-gate"

git -C "${T006_REPO}" init -q
git -C "${T006_REPO}" config user.name ci
git -C "${T006_REPO}" config user.email ci@example.com
git -C "${T006_REPO}" config commit.gpgsign false

# Create spec files for spec_revision hash computation
cat > "${T006_REPO}/specs/test-feature/requirements.md" <<'EOF'
# Requirements

REQ-001: basic functionality
EOF

cat > "${T006_REPO}/specs/test-feature/design.md" <<'EOF'
# Design

Technical approach for test-feature.
EOF

cat > "${T006_REPO}/specs/test-feature/acceptance-tests.md" <<'EOF'
# Acceptance Tests

AC-001: requirement verified
EOF

# Create evidence file
printf 'lint output: OK\n' > "${T006_REPO}/specs/test-feature/verification/ev.log"

# Test: T-006.1 - LEGACY: generate bundle without risk field, then check → passes (regression)
# Create quality report for T-099 (legacy contract)
cat > "${T006_REPO}/reports/quality-gate/T-099.md" <<'EOF'
Task ID: T-099
VERDICT: PASS
Critical: 0
Major: 0
Minor: 0
Quality gate report for T-099.
EOF

cat > "${T006_REPO}/specs/test-feature/verification/T-099-legacy.contract.json" <<'EOF'
{
  "task_id": "T-099",
  "feature": "test-feature",
  "created": "2026-06-13T00:00:00Z",
  "comment": "LEGACY: no risk field",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" }
  ]
}
EOF

git -C "${T006_REPO}" add -A
git -C "${T006_REPO}" commit -q -m "T-006 legacy fixture"

if generate_bundle_passes \
    "${T006_REPO}/specs/test-feature/verification/T-099-legacy.contract.json" \
    "${T006_REPO}/reports/quality-gate/T-099.md" \
    "${T006_REPO}"; then
    ok "T-006.1a: generate-evidence-bundle succeeds for legacy contract"
else
    fail "T-006.1a: generate-evidence-bundle failed for legacy contract: $(run_generate_bundle \
        "${T006_REPO}/specs/test-feature/verification/T-099-legacy.contract.json" \
        "${T006_REPO}/reports/quality-gate/T-099.md" \
        "${T006_REPO}")"
fi

legacy_bundle="${T006_REPO}/specs/test-feature/verification/T-099.evidence.json"
if [ -f "$legacy_bundle" ]; then
    ok "T-006.1b: legacy bundle file created at expected path"
else
    fail "T-006.1b: legacy bundle file not created"
fi

if check_bundle_passes "$legacy_bundle" "${T006_REPO}"; then
    ok "T-006.1c: check-evidence-bundle passes on legacy bundle (no risk field)"
else
    fail "T-006.1c: check-evidence-bundle should pass on legacy bundle: $(run_check_bundle "$legacy_bundle" "${T006_REPO}")"
fi

# Test: T-006.2 - generated bundle CONTAINS the new provenance fields (risk, spec_revision, build_env, builder, review_verdict)
if grep -q '"risk"' "$legacy_bundle"; then
    ok "T-006.2a: generated bundle contains 'risk' field"
else
    fail "T-006.2a: generated bundle missing 'risk' field"
fi

if grep -q '"spec_revision"' "$legacy_bundle"; then
    ok "T-006.2b: generated bundle contains 'spec_revision' field"
else
    fail "T-006.2b: generated bundle missing 'spec_revision' field"
fi

if grep -q '"build_env"' "$legacy_bundle"; then
    ok "T-006.2c: generated bundle contains 'build_env' field"
else
    fail "T-006.2c: generated bundle missing 'build_env' field"
fi

if grep -q '"builder"' "$legacy_bundle"; then
    ok "T-006.2d: generated bundle contains 'builder' field"
else
    fail "T-006.2d: generated bundle missing 'builder' field"
fi

if grep -q '"review_verdict"' "$legacy_bundle"; then
    ok "T-006.2e: generated bundle contains 'review_verdict' field"
else
    fail "T-006.2e: generated bundle missing 'review_verdict' field"
fi

# Test: T-006.3 - high-risk bundle happy path: spec files exist, contract has risk:high, VERDICT: PASS
# Create quality report for T-100
cat > "${T006_REPO}/reports/quality-gate/T-100.md" <<'EOF'
Task ID: T-100
VERDICT: PASS
Critical: 0
Major: 0
Minor: 0
Quality gate report for T-100.
EOF

cat > "${T006_REPO}/specs/test-feature/verification/T-100.contract.json" <<'EOF'
{
  "task_id": "T-100",
  "feature": "test-feature",
  "risk": "high",
  "required_workflow": "tdd",
  "created": "2026-06-13T00:00:00Z",
  "comment": "T-006 high-risk happy path",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "", "red_evidence": "specs/test-feature/verification/ev.log", "green_evidence": "specs/test-feature/verification/ev.log" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "", "red_evidence": "specs/test-feature/verification/ev.log", "green_evidence": "specs/test-feature/verification/ev.log" },
    { "id": "build", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" }
  ]
}
EOF

git -C "${T006_REPO}" add specs/test-feature/verification/T-100.contract.json
git -C "${T006_REPO}" commit -q -m "T-006 high-risk contract"

if generate_bundle_passes \
    "${T006_REPO}/specs/test-feature/verification/T-100.contract.json" \
    "${T006_REPO}/reports/quality-gate/T-100.md" \
    "${T006_REPO}"; then
    ok "T-006.3a: generate-evidence-bundle succeeds for high-risk contract"
else
    fail "T-006.3a: generate-evidence-bundle failed for high-risk: $(run_generate_bundle \
        "${T006_REPO}/specs/test-feature/verification/T-100.contract.json" \
        "${T006_REPO}/reports/quality-gate/T-100.md" \
        "${T006_REPO}")"
fi

high_bundle="${T006_REPO}/specs/test-feature/verification/T-100.evidence.json"
if check_bundle_passes "$high_bundle" "${T006_REPO}"; then
    ok "T-006.3b: check-evidence-bundle passes on high-risk bundle with full provenance"
else
    fail "T-006.3b: check-evidence-bundle should pass on high-risk bundle: $(run_check_bundle "$high_bundle" "${T006_REPO}")"
fi

# Verify spec_revision is 64-char hex
if python3 -c "import json, re; b=json.load(open('${high_bundle}')); assert re.fullmatch(r'[a-f0-9]{64}', b.get('spec_revision', '') or ''), 'invalid spec_revision'" 2>/dev/null; then
    ok "T-006.3c: spec_revision is valid 64-char hex"
else
    fail "T-006.3c: spec_revision is not valid 64-char hex"
fi

# Verify review_verdict.verdict is PASS
if python3 -c "import json; b=json.load(open('${high_bundle}')); assert b.get('review_verdict', {}).get('verdict') == 'PASS', 'verdict not PASS'" 2>/dev/null; then
    ok "T-006.3d: review_verdict.verdict is PASS"
else
    fail "T-006.3d: review_verdict.verdict is not PASS"
fi

# Test: T-006.4 - high bundle with VERDICT: NEEDS_WORK (not PASS) → check FAILS
cat > "${T006_REPO}/reports/quality-gate/T-101.md" <<'EOF'
Task ID: T-101
VERDICT: NEEDS_WORK
Critical: 1
Major: 0
Minor: 0
Fail for testing.
EOF

cat > "${T006_REPO}/specs/test-feature/verification/T-101.contract.json" <<'EOF'
{
  "task_id": "T-101",
  "feature": "test-feature",
  "risk": "high",
  "required_workflow": "tdd",
  "created": "2026-06-13T00:00:00Z",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "", "red_evidence": "specs/test-feature/verification/ev.log", "green_evidence": "specs/test-feature/verification/ev.log" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "", "red_evidence": "specs/test-feature/verification/ev.log", "green_evidence": "specs/test-feature/verification/ev.log" },
    { "id": "build", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" }
  ]
}
EOF

git -C "${T006_REPO}" add specs/test-feature/verification/T-101.contract.json reports/quality-gate/T-101.md
git -C "${T006_REPO}" commit -q -m "T-006 verdict NEEDS_WORK test"

if generate_bundle_passes \
    "${T006_REPO}/specs/test-feature/verification/T-101.contract.json" \
    "${T006_REPO}/reports/quality-gate/T-101.md" \
    "${T006_REPO}"; then
    fail_bundle="${T006_REPO}/specs/test-feature/verification/T-101.evidence.json"
    if check_bundle_passes "$fail_bundle" "${T006_REPO}"; then
        fail "T-006.4: high bundle with VERDICT: NEEDS_WORK should FAIL check"
    else
        ok "T-006.4: high bundle with VERDICT: NEEDS_WORK fails check correctly"
    fi
else
    fail "T-006.4: generate-evidence-bundle should succeed even with NEEDS_WORK report"
fi

# Test: T-006.5 - high bundle with empty spec_revision (no spec files) → check FAILS
T006_NO_SPEC="${WORK}/t006_no_spec"
mkdir -p "${T006_NO_SPEC}/specs/empty-feature/verification"
mkdir -p "${T006_NO_SPEC}/reports/quality-gate"

git -C "${T006_NO_SPEC}" init -q
git -C "${T006_NO_SPEC}" config user.name ci
git -C "${T006_NO_SPEC}" config user.email ci@example.com
git -C "${T006_NO_SPEC}" config commit.gpgsign false

printf 'test\n' > "${T006_NO_SPEC}/specs/empty-feature/verification/ev.log"
cat > "${T006_NO_SPEC}/reports/quality-gate/T-102.md" <<'EOF'
Task ID: T-102
VERDICT: PASS
Quality gate.
EOF

cat > "${T006_NO_SPEC}/specs/empty-feature/verification/T-102.contract.json" <<'EOF'
{
  "task_id": "T-102",
  "feature": "empty-feature",
  "risk": "high",
  "required_workflow": "tdd",
  "created": "2026-06-13T00:00:00Z",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "specs/empty-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "specs/empty-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "specs/empty-feature/verification/ev.log", "waiver_reason": "", "red_evidence": "specs/empty-feature/verification/ev.log", "green_evidence": "specs/empty-feature/verification/ev.log" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "specs/empty-feature/verification/ev.log", "waiver_reason": "", "red_evidence": "specs/empty-feature/verification/ev.log", "green_evidence": "specs/empty-feature/verification/ev.log" },
    { "id": "build", "required": true, "passes": true, "evidence": "specs/empty-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "specs/empty-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "specs/empty-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "specs/empty-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true, "passes": true, "evidence": "specs/empty-feature/verification/ev.log", "waiver_reason": "" }
  ]
}
EOF

git -C "${T006_NO_SPEC}" add -A
git -C "${T006_NO_SPEC}" commit -q -m "T-006 no spec files test"

if generate_bundle_passes \
    "${T006_NO_SPEC}/specs/empty-feature/verification/T-102.contract.json" \
    "${T006_NO_SPEC}/reports/quality-gate/T-102.md" \
    "${T006_NO_SPEC}"; then
    no_spec_bundle="${T006_NO_SPEC}/specs/empty-feature/verification/T-102.evidence.json"
    no_spec_out=$(run_check_bundle "$no_spec_bundle" "${T006_NO_SPEC}")
    if echo "$no_spec_out" | grep -q "spec_revision"; then
        ok "T-006.5: high bundle with empty spec_revision fails check"
    else
        fail "T-006.5: should fail with spec_revision requirement. Got: $no_spec_out"
    fi
else
    fail "T-006.5: generate-evidence-bundle should succeed (generates empty spec_revision)"
fi

# Test: T-006.6 - bundle risk mismatched vs contract risk → check FAILS
python3 - <<PYEOF
import json, pathlib
p = pathlib.Path("${high_bundle}")
b = json.loads(p.read_text(encoding="utf-8"))
b["risk"] = "low"  # hand-edit the bundle's risk to mismatch contract
p.write_text(json.dumps(b, indent=2) + "\n", encoding="utf-8")
PYEOF

mismatch_out=$(run_check_bundle "$high_bundle" "${T006_REPO}")
if echo "$mismatch_out" | grep -q "bundle risk"; then
    ok "T-006.6: risk mismatch (bundle vs contract) fails check"
else
    fail "T-006.6: should fail with risk mismatch. Got: $mismatch_out"
fi

# Restore high_bundle for later tests
python3 - <<PYEOF
import json, pathlib
p = pathlib.Path("${high_bundle}")
b = json.loads(p.read_text(encoding="utf-8"))
b["risk"] = "high"  # restore to correct risk
p.write_text(json.dumps(b, indent=2) + "\n", encoding="utf-8")
PYEOF

# Test: T-006.7 - bundle risk EMPTIED while contract is high → check FAILS (no fail-open)
python3 - <<PYEOF
import json, pathlib
p = pathlib.Path("${high_bundle}")
b = json.loads(p.read_text(encoding="utf-8"))
b["risk"] = ""  # strip the bundle risk to try to dodge provenance gating
p.write_text(json.dumps(b, indent=2) + "\n", encoding="utf-8")
PYEOF

empty_risk_out=$(run_check_bundle "$high_bundle" "${T006_REPO}")
if echo "$empty_risk_out" | grep -q "bundle risk"; then
    ok "T-006.7: emptied bundle risk vs high contract fails closed"
else
    fail "T-006.7: stripped bundle risk must not dodge provenance. Got: $empty_risk_out"
fi

# Restore high_bundle for later tests
python3 - <<PYEOF
import json, pathlib
p = pathlib.Path("${high_bundle}")
b = json.loads(p.read_text(encoding="utf-8"))
b["risk"] = "high"  # restore to correct risk
p.write_text(json.dumps(b, indent=2) + "\n", encoding="utf-8")
PYEOF

# ============================================================================
# T-007a: Evidence bundle cryptographic signing (CRITICAL bundles)
# ============================================================================

echo "=== T-007a: evidence bundle signing (critical risk) ==="

# Create a critical-risk repo for signing tests
T007A_REPO="${WORK}/t007a_repo"
mkdir -p "${T007A_REPO}/specs/test-feature/verification"
mkdir -p "${T007A_REPO}/reports/quality-gate"

git -C "${T007A_REPO}" init -q
git -C "${T007A_REPO}" config user.name ci
git -C "${T007A_REPO}" config user.email ci@example.com
git -C "${T007A_REPO}" config commit.gpgsign false

# Create spec files for spec_revision
cat > "${T007A_REPO}/specs/test-feature/requirements.md" <<'EOF'
# Requirements
REQ-001: critical functionality
EOF

cat > "${T007A_REPO}/specs/test-feature/design.md" <<'EOF'
# Design
Critical system design.
EOF

cat > "${T007A_REPO}/specs/test-feature/acceptance-tests.md" <<'EOF'
# Acceptance Tests
AC-001: critical requirement verified
EOF

# Create evidence file
printf 'critical evidence: OK\n' > "${T007A_REPO}/specs/test-feature/verification/ev.log"

# Create quality report for T-200
cat > "${T007A_REPO}/reports/quality-gate/T-200.md" <<'EOF'
Task ID: T-200
VERDICT: PASS
Critical: 0
Major: 0
Minor: 0
Quality gate report for T-200.
EOF

# Create critical contract
cat > "${T007A_REPO}/specs/test-feature/verification/T-200.contract.json" <<'EOF'
{
  "task_id": "T-200",
  "feature": "test-feature",
  "risk": "critical",
  "required_workflow": "tdd",
  "created": "2026-06-13T00:00:00Z",
  "comment": "T-007a critical-risk signing test",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "", "red_evidence": "specs/test-feature/verification/ev.log", "green_evidence": "specs/test-feature/verification/ev.log" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "", "red_evidence": "specs/test-feature/verification/ev.log", "green_evidence": "specs/test-feature/verification/ev.log" },
    { "id": "build", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" }
  ]
}
EOF

git -C "${T007A_REPO}" add -A
git -C "${T007A_REPO}" commit -q -m "T-007a critical bundle fixture"

# Test T-007a.1: critical bundle generated WITH key + verified WITH same key → PASS
export SDD_EVIDENCE_KEY="test-evidence-key-0123456789"
if generate_bundle_passes \
    "${T007A_REPO}/specs/test-feature/verification/T-200.contract.json" \
    "${T007A_REPO}/reports/quality-gate/T-200.md" \
    "${T007A_REPO}"; then
    ok "T-007a.1a: generate-evidence-bundle succeeds for critical with key"
else
    fail "T-007a.1a: generate-evidence-bundle failed for critical: $(run_generate_bundle \
        "${T007A_REPO}/specs/test-feature/verification/T-200.contract.json" \
        "${T007A_REPO}/reports/quality-gate/T-200.md" \
        "${T007A_REPO}")"
fi

critical_bundle="${T007A_REPO}/specs/test-feature/verification/T-200.evidence.json"
if [ -f "$critical_bundle" ]; then
    ok "T-007a.1b: critical bundle file created"
else
    fail "T-007a.1b: critical bundle file not created"
fi

# Verify bundle contains signature field
if python3 -c "import json; b=json.load(open('${critical_bundle}')); assert 'signature' in b, 'no signature field'" 2>/dev/null; then
    ok "T-007a.1c: critical bundle contains signature field"
else
    fail "T-007a.1c: critical bundle missing signature field"
fi

if check_bundle_passes "$critical_bundle" "${T007A_REPO}"; then
    ok "T-007a.1d: check-evidence-bundle passes on critical with matching key"
else
    fail "T-007a.1d: check-evidence-bundle should pass: $(run_check_bundle "$critical_bundle" "${T007A_REPO}")"
fi

# Test T-007a.2: critical bundle, DELETE signature field → FAIL
python3 - <<PYEOF
import json, pathlib
p = pathlib.Path("${critical_bundle}")
b = json.loads(p.read_text(encoding="utf-8"))
b.pop("signature", None)
p.write_text(json.dumps(b, indent=2) + "\n", encoding="utf-8")
PYEOF

t007a_2_out=$(run_check_bundle "$critical_bundle" "${T007A_REPO}")
if ! check_bundle_passes "$critical_bundle" "${T007A_REPO}" && \
   echo "$t007a_2_out" | grep -q "signature"; then
    ok "T-007a.2: critical bundle without signature fails check"
else
    fail "T-007a.2: should fail with signature requirement. Got: $t007a_2_out"
fi

# Restore signature for next tests
if generate_bundle_passes \
    "${T007A_REPO}/specs/test-feature/verification/T-200.contract.json" \
    "${T007A_REPO}/reports/quality-gate/T-200.md" \
    "${T007A_REPO}"; then
    :
else
    fail "T-007a.X: could not regenerate critical bundle for next test"
fi

# Test T-007a.3: critical bundle, tamper a signed field (change git_commit) → FAIL (HMAC mismatch)
python3 - <<PYEOF
import json, pathlib
p = pathlib.Path("${critical_bundle}")
b = json.loads(p.read_text(encoding="utf-8"))
b["git_commit"] = "0" * 40  # tamper git_commit
p.write_text(json.dumps(b, indent=2) + "\n", encoding="utf-8")
PYEOF

t007a_3_out=$(run_check_bundle "$critical_bundle" "${T007A_REPO}")
if ! check_bundle_passes "$critical_bundle" "${T007A_REPO}" && \
   echo "$t007a_3_out" | grep -q "signature"; then
    ok "T-007a.3: tampered git_commit fails HMAC check"
else
    fail "T-007a.3: should fail with HMAC mismatch. Got: $t007a_3_out"
fi

# Restore bundle
if generate_bundle_passes \
    "${T007A_REPO}/specs/test-feature/verification/T-200.contract.json" \
    "${T007A_REPO}/reports/quality-gate/T-200.md" \
    "${T007A_REPO}"; then
    :
else
    fail "T-007a.X: could not regenerate critical bundle for next test"
fi

# Test T-007a.4: critical bundle with sigstore alg but SDD_EVIDENCE_SIGSTORE_VERIFIED unset → FAIL
# First restore fresh bundle with correct signature for this test
if generate_bundle_passes \
    "${T007A_REPO}/specs/test-feature/verification/T-200.contract.json" \
    "${T007A_REPO}/reports/quality-gate/T-200.md" \
    "${T007A_REPO}"; then
    :
else
    fail "T-007a.X: could not regenerate critical bundle"
fi

python3 - <<PYEOF
import json, pathlib
p = pathlib.Path("${critical_bundle}")
b = json.loads(p.read_text(encoding="utf-8"))
b["signature"] = {"alg": "sigstore", "value": "x", "key_ref": "sigstore"}
p.write_text(json.dumps(b, indent=2) + "\n", encoding="utf-8")
PYEOF

unset SDD_EVIDENCE_SIGSTORE_VERIFIED
t007a_4_out=$(run_check_bundle "$critical_bundle" "${T007A_REPO}")
if ! check_bundle_passes "$critical_bundle" "${T007A_REPO}" && \
   echo "$t007a_4_out" | grep -q "SIGSTORE_VERIFIED"; then
    ok "T-007a.4: sigstore without SIGSTORE_VERIFIED env fails"
else
    fail "T-007a.4: should fail without SDD_EVIDENCE_SIGSTORE_VERIFIED. Got: $t007a_4_out"
fi

# Test T-007a.5: critical bundle with sigstore signature AND SDD_EVIDENCE_SIGSTORE_VERIFIED=1 → PASS
# Create a fresh critical bundle for this test to avoid dirty tree issues
# Create a new contract and bundle for T-201
cat > "${T007A_REPO}/reports/quality-gate/T-201.md" <<'EOF'
Task ID: T-201
VERDICT: PASS
Critical: 0
Major: 0
Minor: 0
Quality gate report for T-201.
EOF

cat > "${T007A_REPO}/specs/test-feature/verification/T-201.contract.json" <<'EOF'
{
  "task_id": "T-201",
  "feature": "test-feature",
  "risk": "critical",
  "required_workflow": "tdd",
  "created": "2026-06-13T00:00:00Z",
  "comment": "T-007a sigstore test",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "", "red_evidence": "specs/test-feature/verification/ev.log", "green_evidence": "specs/test-feature/verification/ev.log" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "", "red_evidence": "specs/test-feature/verification/ev.log", "green_evidence": "specs/test-feature/verification/ev.log" },
    { "id": "build", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true, "passes": true, "evidence": "specs/test-feature/verification/ev.log", "waiver_reason": "" }
  ]
}
EOF

git -C "${T007A_REPO}" add -A
git -C "${T007A_REPO}" commit -q -m "T-007a T-201 sigstore test fixture"

export SDD_EVIDENCE_KEY="test-evidence-key-0123456789"
if generate_bundle_passes \
    "${T007A_REPO}/specs/test-feature/verification/T-201.contract.json" \
    "${T007A_REPO}/reports/quality-gate/T-201.md" \
    "${T007A_REPO}"; then
    :
else
    fail "T-007a.X: could not generate T-201 bundle"
fi

t201_bundle="${T007A_REPO}/specs/test-feature/verification/T-201.evidence.json"
python3 - <<PYEOF
import json, pathlib
p = pathlib.Path("${t201_bundle}")
b = json.loads(p.read_text(encoding="utf-8"))
b["signature"] = {"alg": "sigstore", "value": "x", "key_ref": "sigstore"}
p.write_text(json.dumps(b, indent=2) + "\n", encoding="utf-8")
PYEOF

export SDD_EVIDENCE_SIGSTORE_VERIFIED=1
if check_bundle_passes "$t201_bundle" "${T007A_REPO}"; then
    ok "T-007a.5: sigstore with SIGSTORE_VERIFIED env passes"
else
    fail "T-007a.5: sigstore with SIGSTORE_VERIFIED should pass: $(run_check_bundle "$t201_bundle" "${T007A_REPO}")"
fi
unset SDD_EVIDENCE_SIGSTORE_VERIFIED

# Restore bundle with hmac-sha256
if generate_bundle_passes \
    "${T007A_REPO}/specs/test-feature/verification/T-200.contract.json" \
    "${T007A_REPO}/reports/quality-gate/T-200.md" \
    "${T007A_REPO}"; then
    :
else
    fail "T-007a.X: could not regenerate critical bundle"
fi

# Test T-007a.6: critical bundle with valid signature, but verify with NO key → FAIL
unset SDD_EVIDENCE_KEY
t007a_6_out=$(run_check_bundle "$critical_bundle" "${T007A_REPO}")
if ! check_bundle_passes "$critical_bundle" "${T007A_REPO}" && \
   echo "$t007a_6_out" | grep -q "no evidence key"; then
    ok "T-007a.6: verify without key fails"
else
    fail "T-007a.6: should fail without key. Got: $t007a_6_out"
fi

# Restore key for final tests
export SDD_EVIDENCE_KEY="test-evidence-key-0123456789"

# Test T-007a.7: critical bundle with git_generated_dirty:true → FAIL
python3 - <<PYEOF
import json, pathlib
p = pathlib.Path("${critical_bundle}")
b = json.loads(p.read_text(encoding="utf-8"))
b["git_generated_dirty"] = True
p.write_text(json.dumps(b, indent=2) + "\n", encoding="utf-8")
PYEOF

t007a_7_out=$(run_check_bundle "$critical_bundle" "${T007A_REPO}")
if ! check_bundle_passes "$critical_bundle" "${T007A_REPO}" && \
   echo "$t007a_7_out" | grep -q "dirty"; then
    ok "T-007a.7: critical with dirty tree fails"
else
    fail "T-007a.7: should fail with dirty tree. Got: $t007a_7_out"
fi

# Restore bundle
if generate_bundle_passes \
    "${T007A_REPO}/specs/test-feature/verification/T-200.contract.json" \
    "${T007A_REPO}/reports/quality-gate/T-200.md" \
    "${T007A_REPO}"; then
    :
else
    fail "T-007a.X: could not regenerate critical bundle"
fi

# Test T-007a.8: generate critical bundle with NO key → generate fails
unset SDD_EVIDENCE_KEY
if generate_bundle_passes \
    "${T007A_REPO}/specs/test-feature/verification/T-200.contract.json" \
    "${T007A_REPO}/reports/quality-gate/T-200.md" \
    "${T007A_REPO}"; then
    fail "T-007a.8: generate critical without key should fail"
else
    t007a_8_out=$(run_generate_bundle \
        "${T007A_REPO}/specs/test-feature/verification/T-200.contract.json" \
        "${T007A_REPO}/reports/quality-gate/T-200.md" \
        "${T007A_REPO}")
    if echo "$t007a_8_out" | grep -q "evidence signing key"; then
        ok "T-007a.8: generate critical without key fails"
    else
        fail "T-007a.8: should fail with 'evidence signing key'. Got: $t007a_8_out"
    fi
fi

# Restore key and regenerate for next tests
export SDD_EVIDENCE_KEY="test-evidence-key-0123456789"
generate_bundle_passes \
    "${T007A_REPO}/specs/test-feature/verification/T-200.contract.json" \
    "${T007A_REPO}/reports/quality-gate/T-200.md" \
    "${T007A_REPO}" >/dev/null 2>&1 || true

# Test T-007a.9: REGRESSION - high (not critical) bundle without signature → PASS
# Use the existing high bundle from T-006
if check_bundle_passes "$high_bundle" "${T006_REPO}"; then
    ok "T-007a.9: high-risk bundle without signature still passes"
else
    fail "T-007a.9: high-risk bundle should pass without signature: $(run_check_bundle "$high_bundle" "${T006_REPO}")"
fi

# Test T-007a.10: REGRESSION - legacy bundle (no risk) → PASS
if check_bundle_passes "$legacy_bundle" "${T006_REPO}"; then
    ok "T-007a.10: legacy bundle without risk field still passes"
else
    fail "T-007a.10: legacy bundle should pass: $(run_check_bundle "$legacy_bundle" "${T006_REPO}")"
fi

# ============================================================================
# T-007b: Two-Person Approval (Critical Risk)
# ============================================================================

echo "=== T-007b: Two-Person Approval (Critical Risk) ==="

# Test 1: critical + Done + NO Second Approval => output contains "Second Approval"
mkdir -p "${WORK}/t007b_test1/verification"
mkdir -p "${WORK}/t007b_test1/reports/quality-gate"
mkdir -p "${WORK}/t007b_test1/reports/implementation"
echo "test" > "${WORK}/t007b_test1/reports/quality-gate/test.log"
cat > "${WORK}/t007b_test1/tasks.md" <<'EOF'
# Tasks

## T-001

Approval: Approved (alice 2026-06-13T10:00:00Z)
Status: Done
Risk: critical
EOF
echo "test" > "${WORK}/t007b_test1/verification/T-001.evidence.json"
cat > "${WORK}/t007b_test1/verification/T-001.contract.json" <<'EOF'
{
  "task_id": "T-001",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/quality-gate/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_task_state "${WORK}/t007b_test1/tasks.md" \
    "${WORK}/t007b_test1/reports/quality-gate" \
    "${WORK}/t007b_test1/reports/implementation" \
    "${WORK}/t007b_test1")
if echo "$output" | grep -q "Second Approval"; then
    ok "T-007b.1: critical Done without Second Approval fails with correct message"
else
    fail "T-007b.1: should report missing Second Approval"
fi

# Test 2: critical + Done + primary bare Approved + named Second => output contains "named approver"
mkdir -p "${WORK}/t007b_test2/verification"
mkdir -p "${WORK}/t007b_test2/reports/quality-gate"
mkdir -p "${WORK}/t007b_test2/reports/implementation"
echo "test" > "${WORK}/t007b_test2/reports/quality-gate/test.log"
cat > "${WORK}/t007b_test2/tasks.md" <<'EOF'
# Tasks

## T-001

Approval: Approved
Status: Done
Risk: critical
Second Approval: Approved (bob 2026-06-13T11:00:00Z)
EOF
echo "test" > "${WORK}/t007b_test2/verification/T-001.evidence.json"
cat > "${WORK}/t007b_test2/verification/T-001.contract.json" <<'EOF'
{
  "task_id": "T-001",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/quality-gate/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_task_state "${WORK}/t007b_test2/tasks.md" \
    "${WORK}/t007b_test2/reports/quality-gate" \
    "${WORK}/t007b_test2/reports/implementation" \
    "${WORK}/t007b_test2")
if echo "$output" | grep -q "named approver"; then
    ok "T-007b.2: critical Done with bare primary Approval fails (needs named)"
else
    fail "T-007b.2: should report need for named approver"
fi

# Test 3: critical + Done + primary (alice) + secondary (alice) => output contains "two distinct"
mkdir -p "${WORK}/t007b_test3/verification"
mkdir -p "${WORK}/t007b_test3/reports/quality-gate"
mkdir -p "${WORK}/t007b_test3/reports/implementation"
echo "test" > "${WORK}/t007b_test3/reports/quality-gate/test.log"
cat > "${WORK}/t007b_test3/tasks.md" <<'EOF'
# Tasks

## T-001

Approval: Approved (alice 2026-06-13T10:00:00Z)
Status: Done
Risk: critical
Second Approval: Approved (alice 2026-06-13T11:00:00Z)
EOF
echo "test" > "${WORK}/t007b_test3/verification/T-001.evidence.json"
cat > "${WORK}/t007b_test3/verification/T-001.contract.json" <<'EOF'
{
  "task_id": "T-001",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/quality-gate/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_task_state "${WORK}/t007b_test3/tasks.md" \
    "${WORK}/t007b_test3/reports/quality-gate" \
    "${WORK}/t007b_test3/reports/implementation" \
    "${WORK}/t007b_test3")
if echo "$output" | grep -q "two distinct"; then
    ok "T-007b.3: critical Done with same approver fails"
else
    fail "T-007b.3: should report need for two distinct approvers"
fi

# Test 4: critical + Done + primary sudo + secondary bob => output contains "sudo"
mkdir -p "${WORK}/t007b_test4/verification"
mkdir -p "${WORK}/t007b_test4/reports/quality-gate"
mkdir -p "${WORK}/t007b_test4/reports/implementation"
echo "test" > "${WORK}/t007b_test4/reports/quality-gate/test.log"
cat > "${WORK}/t007b_test4/tasks.md" <<'EOF'
# Tasks

## T-001

Approval: Approved (sudo 2026-06-13T10:00:00Z)
Status: Done
Risk: critical
Second Approval: Approved (bob 2026-06-13T11:00:00Z)
EOF
echo "test" > "${WORK}/t007b_test4/verification/T-001.evidence.json"
cat > "${WORK}/t007b_test4/verification/T-001.contract.json" <<'EOF'
{
  "task_id": "T-001",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/quality-gate/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_task_state "${WORK}/t007b_test4/tasks.md" \
    "${WORK}/t007b_test4/reports/quality-gate" \
    "${WORK}/t007b_test4/reports/implementation" \
    "${WORK}/t007b_test4")
if echo "$output" | grep -q "sudo"; then
    ok "T-007b.4: critical Done with sudo primary approver fails"
else
    fail "T-007b.4: should reject sudo as primary approver"
fi

# Test 5: critical + Done + primary alice + secondary bob => rule passes
# (May still fail on bundle validation; just assert two-person msgs are ABSENT)
mkdir -p "${WORK}/t007b_test5/verification"
mkdir -p "${WORK}/t007b_test5/reports/quality-gate"
mkdir -p "${WORK}/t007b_test5/reports/implementation"
echo "test" > "${WORK}/t007b_test5/reports/quality-gate/test.log"
cat > "${WORK}/t007b_test5/tasks.md" <<'EOF'
# Tasks

## T-001

Approval: Approved (alice 2026-06-13T10:00:00Z)
Status: Done
Risk: critical
Second Approval: Approved (bob 2026-06-13T11:00:00Z)
EOF
echo "test" > "${WORK}/t007b_test5/verification/T-001.evidence.json"
cat > "${WORK}/t007b_test5/verification/T-001.contract.json" <<'EOF'
{
  "task_id": "T-001",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/quality-gate/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_task_state "${WORK}/t007b_test5/tasks.md" \
    "${WORK}/t007b_test5/reports/quality-gate" \
    "${WORK}/t007b_test5/reports/implementation" \
    "${WORK}/t007b_test5")
if ! echo "$output" | grep -q "Second Approval" && \
   ! echo "$output" | grep -q "two distinct" && \
   ! echo "$output" | grep -q "named approver" && \
   ! echo "$output" | grep -q "primary approver is 'sudo'"; then
    ok "T-007b.5: critical Done with alice + bob passes two-person rule"
else
    fail "T-007b.5: should pass two-person rule: $output"
fi

# Test 6: REGRESSION - non-critical Done without Second Approval => no two-person error
mkdir -p "${WORK}/t007b_test6/verification"
mkdir -p "${WORK}/t007b_test6/reports/quality-gate"
mkdir -p "${WORK}/t007b_test6/reports/implementation"
echo "test" > "${WORK}/t007b_test6/reports/quality-gate/test.log"
cat > "${WORK}/t007b_test6/tasks.md" <<'EOF'
# Tasks

## T-001

Approval: Approved
Status: Done
Risk: high
EOF
echo "test" > "${WORK}/t007b_test6/verification/T-001.evidence.json"
cat > "${WORK}/t007b_test6/verification/T-001.contract.json" <<'EOF'
{
  "task_id": "T-001",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/quality-gate/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_task_state "${WORK}/t007b_test6/tasks.md" \
    "${WORK}/t007b_test6/reports/quality-gate" \
    "${WORK}/t007b_test6/reports/implementation" \
    "${WORK}/t007b_test6")
if ! echo "$output" | grep -q "Second Approval" && \
   ! echo "$output" | grep -q "two distinct" && \
   ! echo "$output" | grep -q "two-person"; then
    ok "T-007b.6: non-critical Done without Second Approval passes (no enforcement)"
else
    fail "T-007b.6: should not enforce two-person for non-critical: $output"
fi

# Test 7: REGRESSION - named Approval format accepted (not invalid)
mkdir -p "${WORK}/t007b_test7/reports/quality-gate"
mkdir -p "${WORK}/t007b_test7/reports/implementation"
cat > "${WORK}/t007b_test7/tasks.md" <<'EOF'
# Tasks

## T-001

Approval: Approved (alice 2026-06-13T10:00:00Z)
Status: In Progress
EOF
output=$(run_check_task_state "${WORK}/t007b_test7/tasks.md" \
    "${WORK}/t007b_test7/reports/quality-gate" \
    "${WORK}/t007b_test7/reports/implementation" \
    "${WORK}/t007b_test7")
if ! echo "$output" | grep -q "invalid Approval"; then
    ok "T-007b.7: named Approval format accepted (not invalid)"
else
    fail "T-007b.7: should accept named Approval format"
fi

# Test 8: REGRESSION - sudo format still accepted
mkdir -p "${WORK}/t007b_test8/reports/quality-gate"
mkdir -p "${WORK}/t007b_test8/reports/implementation"
cat > "${WORK}/t007b_test8/tasks.md" <<'EOF'
# Tasks

## T-001

Approval: Approved (sudo 2026-06-13T10:00:00Z)
Status: In Progress
EOF
output=$(run_check_task_state "${WORK}/t007b_test8/tasks.md" \
    "${WORK}/t007b_test8/reports/quality-gate" \
    "${WORK}/t007b_test8/reports/implementation" \
    "${WORK}/t007b_test8")
if ! echo "$output" | grep -q "invalid Approval"; then
    ok "T-007b.8: sudo Approval format still accepted (backward compat)"
else
    fail "T-007b.8: should still accept sudo format"
fi

# ============================================================================
# T-003-CM: cross_model descriptor (cross-model-verification conditional pass)
#  Enforced only when a contract opts in via `cross_model`. Absent/"legacy" =>
#  no enforcement (backward compatible). Like signature/two-person, it is a
#  conditional control, NOT part of the machine-form RISK_TIERS set.
# ============================================================================

echo "=== T-003-CM: cross_model descriptor ==="

# CM.1 - critical + cross_model:required + passing cross-model-verification → PASS
mkdir -p "${WORK}/cm_test1/reports"; create_evidence "${WORK}/cm_test1/reports/test.log"
cat > "${WORK}/cm_test1/CM-1.contract.json" <<'EOF'
{
  "task_id": "CM-1", "feature": "test-feature", "risk": "critical", "cross_model": "required",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "cross-model-verification", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
if check_contract_passes "${WORK}/cm_test1/CM-1.contract.json" "${WORK}/cm_test1"; then
    ok "CM.1: critical cross_model:required with passing check → passes"
else
    fail "CM.1: should pass"
fi

# CM.2 - critical + cross_model:required but MISSING cross-model-verification → FAIL
mkdir -p "${WORK}/cm_test2/reports"; create_evidence "${WORK}/cm_test2/reports/test.log"
cat > "${WORK}/cm_test2/CM-2.contract.json" <<'EOF'
{
  "task_id": "CM-2", "feature": "test-feature", "risk": "critical", "cross_model": "required",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_contract "${WORK}/cm_test2/CM-2.contract.json" "${WORK}/cm_test2")
if echo "$output" | grep -q "cross_model:required needs"; then
    ok "CM.2: cross_model:required missing cross-model-verification fails"
else
    fail "CM.2: should fail with 'cross_model:required needs'. Got: $output"
fi

# CM.3 - critical + cross_model ABSENT (legacy) + no cross-model check → PASS (backward compat)
mkdir -p "${WORK}/cm_test3/reports"; create_evidence "${WORK}/cm_test3/reports/test.log"
cat > "${WORK}/cm_test3/CM-3.contract.json" <<'EOF'
{
  "task_id": "CM-3", "feature": "test-feature", "risk": "critical",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
if check_contract_passes "${WORK}/cm_test3/CM-3.contract.json" "${WORK}/cm_test3"; then
    ok "CM.3: critical with cross_model absent (legacy) → passes (backward compat)"
else
    fail "CM.3: legacy (no cross_model) critical should pass"
fi

# CM.4 - critical + cross_model:waived + cross-model-verification waived → PASS
mkdir -p "${WORK}/cm_test4/reports"; create_evidence "${WORK}/cm_test4/reports/test.log"
cat > "${WORK}/cm_test4/CM-4.contract.json" <<'EOF'
{
  "task_id": "CM-4", "feature": "test-feature", "risk": "critical", "cross_model": "waived",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "typecheck", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "build", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "placeholder-scan", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "unit-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "acceptance-tests", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "regression", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" },
    { "id": "cross-model-verification", "required": false, "passes": false, "evidence": "", "waiver_reason": "air-gapped repo: no external model access" }
  ]
}
EOF
if check_contract_passes "${WORK}/cm_test4/CM-4.contract.json" "${WORK}/cm_test4"; then
    ok "CM.4: critical cross_model:waived with waiver_reason → passes"
else
    fail "CM.4: waived with reason should pass"
fi

# CM.5 - cross_model:invalid → FAIL
mkdir -p "${WORK}/cm_test5/reports"; create_evidence "${WORK}/cm_test5/reports/test.log"
cat > "${WORK}/cm_test5/CM-5.contract.json" <<'EOF'
{
  "task_id": "CM-5", "feature": "test-feature", "risk": "critical", "cross_model": "bogus",
  "checks": [
    { "id": "lint", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }
  ]
}
EOF
output=$(run_check_contract "${WORK}/cm_test5/CM-5.contract.json" "${WORK}/cm_test5")
if echo "$output" | grep -q "cross_model is invalid"; then
    ok "CM.5: cross_model:bogus (invalid) fails correctly"
else
    fail "CM.5: should fail with 'cross_model is invalid'. Got: $output"
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
