$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# scenario.tests.ps1 — cross-runtime end-to-end scenario suite (PowerShell mirror of scenario.tests.sh).
# Covers:
#   A.  Full-chain multi-tier lifecycle (T-101 low/docs, T-102 high/tdd, T-103 critical).
#   B1. Hook contract for all 3 CLI forms (Claude Code, Codex, Copilot) + drift guard.
#   E.  Critical signing round-trip (ephemeral key, generate => pass; tamper => fail).

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$scriptsDir     = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts"
$hooksDir       = Join-Path $repositoryRoot "plugins/sdd-quality-loop/hooks"

$script:PASS = 0
$script:FAIL = 0

function global:ok   { param([string]$Name) Write-Host "ok: $Name";   $script:PASS++ }
function global:fail { param([string]$Name) Write-Host "FAIL: $Name"; $script:FAIL++ }

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-scenario-tests-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $workDir | Out-Null

# ---------------------------------------------------------------------------
# Gate wrapper helpers
# ---------------------------------------------------------------------------

function Invoke-Gate {
    param([string]$Script, [string[]]$Arguments)
    $script:gateOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir $Script) @Arguments 2>&1
    return $LASTEXITCODE
}

function Assert-ExitCode {
    param([string]$Name, [int]$Actual, [int]$Expected)
    if ($Actual -ne $Expected) {
        $details = ($script:gateOutput | Out-String).Trim()
        fail "$Name (expected exit $Expected but got $Actual`n$details)"
    } else {
        ok $Name
    }
}

# Invoke a gate and return ($exitCode, $outputString)
function Run-Gate {
    param([string]$Script, [string[]]$Arguments)
    $out = & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir $Script) @Arguments 2>&1
    return $LASTEXITCODE, ($out | Out-String)
}

function git_init_and_commit {
    param([string]$Repo)
    & git -C $Repo init -q 2>&1 | Out-Null
    & git -C $Repo config user.name  ci
    & git -C $Repo config user.email ci@example.com
    & git -C $Repo config commit.gpgsign false
    & git -C $Repo add -A 2>&1 | Out-Null
    & git -C $Repo commit -q -m "scenario fixture initial commit" 2>&1 | Out-Null
}

# ===========================================================================
# SCENARIO A: FULL-CHAIN MULTI-TIER LIFECYCLE
# ===========================================================================
Write-Host "=== Scenario A: full-chain multi-tier lifecycle ==="

$sa   = Join-Path $workDir "sa-lifecycle"
$feat = "feat-multi"

foreach ($d in @(
    (Join-Path $sa "verification"),
    (Join-Path $sa "specs/$feat/verification"),
    (Join-Path $sa "specs/$feat"),
    (Join-Path $sa "reports/quality-gate"),
    (Join-Path $sa "reports/implementation"),
    (Join-Path $sa "src")
)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }

# Shared evidence log
"All checks passed." | Set-Content -Encoding Utf8 (Join-Path $sa "specs/$feat/verification/ev.log")
# Red/green TDD evidence for T-102
"RED: test_payment FAILED"  | Set-Content -Encoding Utf8 (Join-Path $sa "specs/$feat/verification/tdd-red.log")
"GREEN: test_payment PASSED" | Set-Content -Encoding Utf8 (Join-Path $sa "specs/$feat/verification/tdd-green.log")
# Clean source
"def add(a, b):`n    return a + b" | Set-Content -Encoding Utf8 (Join-Path $sa "src/widget.py")

# ---- A.1: check-risk passes for the well-formed tasks.md ----
Write-Host "--- A.1: check-risk passes ---"

@"
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
"@ | Set-Content -Encoding Utf8 (Join-Path $sa "tasks.md")

$ec = Invoke-Gate "check-risk.ps1" @((Join-Path $sa "tasks.md"))
Assert-ExitCode "A.1: check-risk passes for well-formed three-task tasks.md" $ec 0

# ---- A.2: check-risk fails-closed when T-102 drops 'Required Workflow: tdd' ----
Write-Host "--- A.2: check-risk fails-closed on missing Required Workflow ---"

@"
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
"@ | Set-Content -Encoding Utf8 (Join-Path $sa "tasks-no-tdd.md")

$ec2, $out2 = Run-Gate "check-risk.ps1" @((Join-Path $sa "tasks-no-tdd.md"))
if ($ec2 -ne 0 -and $out2 -match "Required Workflow: tdd") {
    ok "A.2: check-risk fails-closed when T-102 drops Required Workflow: tdd"
} else {
    fail "A.2: check-risk should fail when T-102 drops Required Workflow: tdd (ec=$ec2, out='$out2')"
}

# --- T-101 contract (low risk, docs stack) ---
@"
{
  "task_id": "T-101",
  "feature": "$feat",
  "risk": "low",
  "stack": "docs",
  "created": "2026-06-14T00:00:00Z",
  "checks": [
    { "id": "lint",             "required": false, "passes": false, "evidence": "", "waiver_reason": "docs stack — no linter applicable" },
    { "id": "typecheck",        "required": false, "passes": false, "evidence": "", "waiver_reason": "docs stack — no type checker applicable" },
    { "id": "build",            "required": false, "passes": false, "evidence": "", "waiver_reason": "docs stack — no build step applicable" },
    { "id": "unit-tests",       "required": false, "passes": false, "evidence": "", "waiver_reason": "docs stack — no unit tests applicable" },
    { "id": "placeholder-scan", "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" }
  ]
}
"@ | Set-Content -Encoding Utf8 (Join-Path $sa "verification/T-101.contract.json")

# ---- A.3: check-contract passes T-101 (docs stack, compile checks waived) ----
Write-Host "--- A.3: check-contract passes T-101 with docs stack ---"

$ec = Invoke-Gate "check-contract.ps1" @((Join-Path $sa "verification/T-101.contract.json"), "-RepoRoot", $sa)
Assert-ExitCode "A.3: check-contract passes T-101 (docs stack, compile checks waived with waiver_reason)" $ec 0

# --- T-102 contract (high risk, code stack, required_workflow: tdd) ---
@"
{
  "task_id": "T-102",
  "feature": "$feat",
  "risk": "high",
  "stack": "code",
  "required_workflow": "tdd",
  "created": "2026-06-14T00:00:00Z",
  "checks": [
    { "id": "lint",                     "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "typecheck",                "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "unit-tests",               "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log",
      "red_evidence": "specs/$feat/verification/tdd-red.log",
      "green_evidence": "specs/$feat/verification/tdd-green.log",
      "waiver_reason": "" },
    { "id": "build",                    "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "placeholder-scan",         "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check",         "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "acceptance-tests",         "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log",
      "red_evidence": "specs/$feat/verification/tdd-red.log",
      "green_evidence": "specs/$feat/verification/tdd-green.log",
      "waiver_reason": "" },
    { "id": "regression",               "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "integration-tests",        "required": false, "passes": false,  "evidence": "", "waiver_reason": "not applicable for this task" }
  ]
}
"@ | Set-Content -Encoding Utf8 (Join-Path $sa "verification/T-102.contract.json")

# --- T-103 contract (critical risk, code stack) ---
@"
{
  "task_id": "T-103",
  "feature": "$feat",
  "risk": "critical",
  "stack": "code",
  "required_workflow": "tdd",
  "created": "2026-06-14T00:00:00Z",
  "checks": [
    { "id": "lint",                     "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "typecheck",                "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "unit-tests",               "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log",
      "red_evidence": "specs/$feat/verification/tdd-red.log",
      "green_evidence": "specs/$feat/verification/tdd-green.log",
      "waiver_reason": "" },
    { "id": "build",                    "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "placeholder-scan",         "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check",         "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "acceptance-tests",         "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log",
      "red_evidence": "specs/$feat/verification/tdd-red.log",
      "green_evidence": "specs/$feat/verification/tdd-green.log",
      "waiver_reason": "" },
    { "id": "regression",               "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" }
  ]
}
"@ | Set-Content -Encoding Utf8 (Join-Path $sa "verification/T-103.contract.json")

# ---- A.4: check-contract passes T-102 (high risk, tdd) ----
Write-Host "--- A.4: check-contract passes T-102 ---"

$ec = Invoke-Gate "check-contract.ps1" @((Join-Path $sa "verification/T-102.contract.json"), "-RepoRoot", $sa)
Assert-ExitCode "A.4: check-contract passes T-102 (high risk, tdd, full evidence)" $ec 0

# ---- A.5: check-contract fails when a required check has passes:false + empty waiver_reason ----
Write-Host "--- A.5: check-contract fails on required passes:false ---"

@"
{
  "task_id": "T-102",
  "feature": "$feat",
  "risk": "high",
  "stack": "code",
  "required_workflow": "tdd",
  "checks": [
    { "id": "lint",                     "required": true,  "passes": false, "evidence": "", "waiver_reason": "" },
    { "id": "typecheck",                "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "unit-tests",               "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log",
      "red_evidence": "specs/$feat/verification/tdd-red.log",
      "green_evidence": "specs/$feat/verification/tdd-green.log",
      "waiver_reason": "" },
    { "id": "build",                    "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "placeholder-scan",         "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check",         "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "acceptance-tests",         "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log",
      "red_evidence": "specs/$feat/verification/tdd-red.log",
      "green_evidence": "specs/$feat/verification/tdd-green.log",
      "waiver_reason": "" },
    { "id": "regression",               "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" }
  ]
}
"@ | Set-Content -Encoding Utf8 (Join-Path $sa "verification/T-102-bad.contract.json")

$ec5 = Invoke-Gate "check-contract.ps1" @((Join-Path $sa "verification/T-102-bad.contract.json"), "-RepoRoot", $sa)
if ($ec5 -ne 0) {
    ok "A.5: check-contract fails when required check has passes:false"
} else {
    fail "A.5: check-contract should fail on required passes:false (got exit 0)"
}

# ---- A.6: check-traceability passes the complete REQ->AC->TEST->evidence chain ----
Write-Host "--- A.6: check-traceability passes complete chain ---"

@"
{
  "feature": "$feat",
  "links": [
    {
      "req": "REQ-001",
      "acs": ["AC-001"],
      "tests": ["TEST-001"],
      "evidence": ["specs/$feat/verification/ev.log"]
    }
  ]
}
"@ | Set-Content -Encoding Utf8 (Join-Path $sa "specs/$feat/traceability.json")

$ec = Invoke-Gate "check-traceability.ps1" @(
    "-TracePath", (Join-Path $sa "specs/$feat/traceability.json"),
    "-RepoRoot", $sa,
    "-RequireEvidence"
)
Assert-ExitCode "A.6: check-traceability passes complete REQ->AC->TEST->evidence chain" $ec 0

# ---- A.7: check-traceability fails-closed on empty tests[] ----
Write-Host "--- A.7: check-traceability fails-closed on empty tests[] ---"

@"
{
  "feature": "$feat",
  "links": [
    {
      "req": "REQ-001",
      "acs": ["AC-001"],
      "tests": [],
      "evidence": ["specs/$feat/verification/ev.log"]
    }
  ]
}
"@ | Set-Content -Encoding Utf8 (Join-Path $sa "specs/$feat/traceability-bad.json")

$ec7, $out7 = Run-Gate "check-traceability.ps1" @(
    "-TracePath", (Join-Path $sa "specs/$feat/traceability-bad.json"),
    "-RepoRoot", $sa
)
if ($ec7 -ne 0 -and $out7 -imatch "no tests") {
    ok "A.7: check-traceability fails-closed on empty tests[] link"
} else {
    fail "A.7: check-traceability should fail on empty tests[] (ec=$ec7, out='$out7')"
}

# ---- A.8: check-task-state BLOCKS Done while Approval: Draft ----
Write-Host "--- A.8: check-task-state blocks Done with Approval: Draft ---"

@"
# Project Tasks

## T-101

Risk: low
Risk Rationale: documentation only
Status: Done
Approval: Draft
"@ | Set-Content -Encoding Utf8 (Join-Path $sa "tasks-draft.md")

$ec8, $out8 = Run-Gate "check-task-state.ps1" @(
    (Join-Path $sa "tasks-draft.md"),
    "-ReportsDir", (Join-Path $sa "reports/quality-gate"),
    "-ImplReportsDir", (Join-Path $sa "reports/implementation"),
    "-RepoRoot", $sa
)
if ($ec8 -ne 0) {
    ok "A.8: check-task-state BLOCKS Done while Approval: Draft"
} else {
    fail "A.8: check-task-state should block Done with Approval: Draft (out='$out8')"
}

# ---- A.9: check-task-state PASSES non-critical Done with Approval: Approved (named id) ----
Write-Host "--- A.9: check-task-state passes non-critical Done with named Approval ---"

$saT101 = Join-Path $workDir "sa-t101-done"
foreach ($d in @(
    (Join-Path $saT101 "verification"),
    (Join-Path $saT101 "specs/$feat/verification"),
    (Join-Path $saT101 "reports/quality-gate"),
    (Join-Path $saT101 "reports/implementation"),
    (Join-Path $saT101 "src")
)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }

"All checks passed." | Set-Content -Encoding Utf8 (Join-Path $saT101 "specs/$feat/verification/ev.log")
"def add(a, b):`n    return a + b" | Set-Content -Encoding Utf8 (Join-Path $saT101 "src/widget.py")

@"
Task ID: T-101
VERDICT: PASS

Docs-only task; all applicable checks green.
"@ | Set-Content -Encoding Utf8 (Join-Path $saT101 "reports/quality-gate/T-101.md")

@"
{
  "task_id": "T-101",
  "feature": "$feat",
  "risk": "low",
  "stack": "docs",
  "created": "2026-06-14T00:00:00Z",
  "checks": [
    { "id": "lint",             "required": false, "passes": false, "evidence": "", "waiver_reason": "docs stack — no linter applicable" },
    { "id": "typecheck",        "required": false, "passes": false, "evidence": "", "waiver_reason": "docs stack — no type checker applicable" },
    { "id": "build",            "required": false, "passes": false, "evidence": "", "waiver_reason": "docs stack — no build step applicable" },
    { "id": "unit-tests",       "required": false, "passes": false, "evidence": "", "waiver_reason": "docs stack — no unit tests applicable" },
    { "id": "placeholder-scan", "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check", "required": true,  "passes": true,  "evidence": "specs/$feat/verification/ev.log", "waiver_reason": "" }
  ]
}
"@ | Set-Content -Encoding Utf8 (Join-Path $saT101 "verification/T-101.contract.json")

@"
# Project Tasks

## T-101

Risk: low
Risk Rationale: documentation only
Status: Done
Approval: Approved (alice 2026-06-14T00:00:00Z)
"@ | Set-Content -Encoding Utf8 (Join-Path $saT101 "tasks.md")

git_init_and_commit $saT101

$ecBundle9 = Invoke-Gate "generate-evidence-bundle.ps1" @(
    "-ContractPath", (Join-Path $saT101 "verification/T-101.contract.json"),
    "-QualityReport", (Join-Path $saT101 "reports/quality-gate/T-101.md"),
    "-RepoRoot", $saT101
)
if ($ecBundle9 -eq 0) {
    $ec9 = Invoke-Gate "check-task-state.ps1" @(
        (Join-Path $saT101 "tasks.md"),
        "-ReportsDir", (Join-Path $saT101 "reports/quality-gate"),
        "-ImplReportsDir", (Join-Path $saT101 "reports/implementation"),
        "-RepoRoot", $saT101
    )
    Assert-ExitCode "A.9: check-task-state PASSES non-critical Done with named Approval: Approved (alice)" $ec9 0
} else {
    fail "A.9: generate-evidence-bundle failed for T-101 (exit $ecBundle9)"
}

# ---- A.10: check-task-state BLOCKS critical Done without Second Approval ----
Write-Host "--- A.10: check-task-state blocks critical Done without Second Approval ---"

$saT103 = Join-Path $workDir "sa-t103-nosecond"
foreach ($d in @(
    (Join-Path $saT103 "verification"),
    (Join-Path $saT103 "specs/$feat/verification"),
    (Join-Path $saT103 "reports/quality-gate"),
    (Join-Path $saT103 "reports/implementation"),
    (Join-Path $saT103 "src")
)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }

"All checks passed." | Set-Content -Encoding Utf8 (Join-Path $saT103 "specs/$feat/verification/ev.log")
"RED: test FAILED"   | Set-Content -Encoding Utf8 (Join-Path $saT103 "specs/$feat/verification/tdd-red.log")
"GREEN: test PASSED" | Set-Content -Encoding Utf8 (Join-Path $saT103 "specs/$feat/verification/tdd-green.log")
"def add(a, b):`n    return a + b" | Set-Content -Encoding Utf8 (Join-Path $saT103 "src/widget.py")
"# Requirements`n- REQ-001: signing must be verifiable" | Set-Content -Encoding Utf8 (Join-Path $saT103 "specs/$feat/requirements.md")

@"
Task ID: T-103
VERDICT: PASS

Critical-risk TDD task; all checks green.
"@ | Set-Content -Encoding Utf8 (Join-Path $saT103 "reports/quality-gate/T-103.md")

Copy-Item (Join-Path $sa "verification/T-103.contract.json") (Join-Path $saT103 "verification/T-103.contract.json")

@"
# Project Tasks

## T-103

Risk: critical
Risk Rationale: signs and verifies evidence bundles for critical tasks
Required Workflow: tdd
Status: Done
Approval: Approved (alice 2026-06-14T00:00:00Z)
"@ | Set-Content -Encoding Utf8 (Join-Path $saT103 "tasks.md")

git_init_and_commit $saT103

$t103Key = [System.BitConverter]::ToString([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).Replace("-","").ToLower()
$env:SDD_EVIDENCE_KEY = $t103Key
try {
    $ecBundle10 = Invoke-Gate "generate-evidence-bundle.ps1" @(
        "-ContractPath", (Join-Path $saT103 "verification/T-103.contract.json"),
        "-QualityReport", (Join-Path $saT103 "reports/quality-gate/T-103.md"),
        "-RepoRoot", $saT103
    )
    if ($ecBundle10 -eq 0) {
        $ec10, $out10 = Run-Gate "check-task-state.ps1" @(
            (Join-Path $saT103 "tasks.md"),
            "-ReportsDir", (Join-Path $saT103 "reports/quality-gate"),
            "-ImplReportsDir", (Join-Path $saT103 "reports/implementation"),
            "-RepoRoot", $saT103
        )
        if ($ec10 -ne 0) {
            ok "A.10: check-task-state BLOCKS critical Done without Second Approval"
        } else {
            fail "A.10: check-task-state should block critical Done without Second Approval (out='$out10')"
        }
    } else {
        fail "A.10: generate-evidence-bundle failed for T-103 (exit $ecBundle10)"
    }
} finally {
    Remove-Item Env:SDD_EVIDENCE_KEY -ErrorAction SilentlyContinue
}

# ---- A.11: check-task-state BLOCKS critical Done with same-name approvers ----
Write-Host "--- A.11: check-task-state blocks critical Done with same-name approvers ---"

$saT103B = Join-Path $workDir "sa-t103-samename"
foreach ($d in @(
    (Join-Path $saT103B "verification"),
    (Join-Path $saT103B "specs/$feat/verification"),
    (Join-Path $saT103B "reports/quality-gate"),
    (Join-Path $saT103B "reports/implementation"),
    (Join-Path $saT103B "src")
)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }

"All checks passed." | Set-Content -Encoding Utf8 (Join-Path $saT103B "specs/$feat/verification/ev.log")
"RED: test FAILED"   | Set-Content -Encoding Utf8 (Join-Path $saT103B "specs/$feat/verification/tdd-red.log")
"GREEN: test PASSED" | Set-Content -Encoding Utf8 (Join-Path $saT103B "specs/$feat/verification/tdd-green.log")
"def add(a, b):`n    return a + b" | Set-Content -Encoding Utf8 (Join-Path $saT103B "src/widget.py")
"# Requirements`n- REQ-001: signing must be verifiable" | Set-Content -Encoding Utf8 (Join-Path $saT103B "specs/$feat/requirements.md")

@"
Task ID: T-103
VERDICT: PASS

Critical-risk TDD task; all checks green.
"@ | Set-Content -Encoding Utf8 (Join-Path $saT103B "reports/quality-gate/T-103.md")

Copy-Item (Join-Path $sa "verification/T-103.contract.json") (Join-Path $saT103B "verification/T-103.contract.json")

@"
# Project Tasks

## T-103

Risk: critical
Risk Rationale: signs and verifies evidence bundles for critical tasks
Required Workflow: tdd
Status: Done
Approval: Approved (alice 2026-06-14T00:00:00Z)
Second Approval: Approved (alice 2026-06-14T01:00:00Z)
"@ | Set-Content -Encoding Utf8 (Join-Path $saT103B "tasks.md")

git_init_and_commit $saT103B

$t103BKey = [System.BitConverter]::ToString([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).Replace("-","").ToLower()
$env:SDD_EVIDENCE_KEY = $t103BKey
try {
    $ecBundle11 = Invoke-Gate "generate-evidence-bundle.ps1" @(
        "-ContractPath", (Join-Path $saT103B "verification/T-103.contract.json"),
        "-QualityReport", (Join-Path $saT103B "reports/quality-gate/T-103.md"),
        "-RepoRoot", $saT103B
    )
    if ($ecBundle11 -eq 0) {
        $ec11, $out11 = Run-Gate "check-task-state.ps1" @(
            (Join-Path $saT103B "tasks.md"),
            "-ReportsDir", (Join-Path $saT103B "reports/quality-gate"),
            "-ImplReportsDir", (Join-Path $saT103B "reports/implementation"),
            "-RepoRoot", $saT103B
        )
        if ($ec11 -ne 0 -and $out11 -imatch "same approver") {
            ok "A.11: check-task-state BLOCKS critical Done with same-name approvers (alice==alice)"
        } else {
            fail "A.11: check-task-state should block same-name approvers (ec=$ec11, out='$out11')"
        }
    } else {
        fail "A.11: generate-evidence-bundle failed for T-103 (same-name) (exit $ecBundle11)"
    }
} finally {
    Remove-Item Env:SDD_EVIDENCE_KEY -ErrorAction SilentlyContinue
}

# ---- A.12: check-task-state BLOCKS critical Done with 'sudo' as approver ----
Write-Host "--- A.12: check-task-state blocks critical Done with sudo approver ---"

$saT103C = Join-Path $workDir "sa-t103-sudo"
foreach ($d in @(
    (Join-Path $saT103C "verification"),
    (Join-Path $saT103C "specs/$feat/verification"),
    (Join-Path $saT103C "reports/quality-gate"),
    (Join-Path $saT103C "reports/implementation"),
    (Join-Path $saT103C "src")
)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }

"All checks passed." | Set-Content -Encoding Utf8 (Join-Path $saT103C "specs/$feat/verification/ev.log")
"RED: test FAILED"   | Set-Content -Encoding Utf8 (Join-Path $saT103C "specs/$feat/verification/tdd-red.log")
"GREEN: test PASSED" | Set-Content -Encoding Utf8 (Join-Path $saT103C "specs/$feat/verification/tdd-green.log")
"def add(a, b):`n    return a + b" | Set-Content -Encoding Utf8 (Join-Path $saT103C "src/widget.py")
"# Requirements`n- REQ-001: signing must be verifiable" | Set-Content -Encoding Utf8 (Join-Path $saT103C "specs/$feat/requirements.md")

@"
Task ID: T-103
VERDICT: PASS

Critical-risk TDD task; all checks green.
"@ | Set-Content -Encoding Utf8 (Join-Path $saT103C "reports/quality-gate/T-103.md")

Copy-Item (Join-Path $sa "verification/T-103.contract.json") (Join-Path $saT103C "verification/T-103.contract.json")

@"
# Project Tasks

## T-103

Risk: critical
Risk Rationale: signs and verifies evidence bundles for critical tasks
Required Workflow: tdd
Status: Done
Approval: Approved (sudo 2026-06-14T00:00:00Z)
Second Approval: Approved (bob 2026-06-14T01:00:00Z)
"@ | Set-Content -Encoding Utf8 (Join-Path $saT103C "tasks.md")

git_init_and_commit $saT103C

$t103CKey = [System.BitConverter]::ToString([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).Replace("-","").ToLower()
$env:SDD_EVIDENCE_KEY = $t103CKey
try {
    $ecBundle12 = Invoke-Gate "generate-evidence-bundle.ps1" @(
        "-ContractPath", (Join-Path $saT103C "verification/T-103.contract.json"),
        "-QualityReport", (Join-Path $saT103C "reports/quality-gate/T-103.md"),
        "-RepoRoot", $saT103C
    )
    if ($ecBundle12 -eq 0) {
        $ec12, $out12 = Run-Gate "check-task-state.ps1" @(
            (Join-Path $saT103C "tasks.md"),
            "-ReportsDir", (Join-Path $saT103C "reports/quality-gate"),
            "-ImplReportsDir", (Join-Path $saT103C "reports/implementation"),
            "-RepoRoot", $saT103C
        )
        if ($ec12 -ne 0 -and $out12 -imatch "sudo") {
            ok "A.12: check-task-state BLOCKS critical Done with 'sudo' as primary approver"
        } else {
            fail "A.12: check-task-state should block sudo approver (ec=$ec12, out='$out12')"
        }
    } else {
        fail "A.12: generate-evidence-bundle failed for T-103 (sudo) (exit $ecBundle12)"
    }
} finally {
    Remove-Item Env:SDD_EVIDENCE_KEY -ErrorAction SilentlyContinue
}

# ---- A.13: generate-evidence-bundle + check-evidence-bundle succeed for high task T-102 ----
Write-Host "--- A.13: evidence bundle round-trip for high task T-102 ---"

$saT102 = Join-Path $workDir "sa-t102-done"
foreach ($d in @(
    (Join-Path $saT102 "verification"),
    (Join-Path $saT102 "specs/$feat/verification"),
    (Join-Path $saT102 "reports/quality-gate"),
    (Join-Path $saT102 "reports/implementation"),
    (Join-Path $saT102 "src")
)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }

"All checks passed." | Set-Content -Encoding Utf8 (Join-Path $saT102 "specs/$feat/verification/ev.log")
"RED: test FAILED"   | Set-Content -Encoding Utf8 (Join-Path $saT102 "specs/$feat/verification/tdd-red.log")
"GREEN: test PASSED" | Set-Content -Encoding Utf8 (Join-Path $saT102 "specs/$feat/verification/tdd-green.log")
"def add(a, b):`n    return a + b" | Set-Content -Encoding Utf8 (Join-Path $saT102 "src/widget.py")
"# Requirements`n- REQ-001: payment must succeed" | Set-Content -Encoding Utf8 (Join-Path $saT102 "specs/$feat/requirements.md")

Copy-Item (Join-Path $sa "verification/T-102.contract.json") (Join-Path $saT102 "verification/T-102.contract.json")

@"
Task ID: T-102
VERDICT: PASS

High-risk TDD task; all checks green including red->green evidence.
"@ | Set-Content -Encoding Utf8 (Join-Path $saT102 "reports/quality-gate/T-102.md")

git_init_and_commit $saT102

$ecBundle13 = Invoke-Gate "generate-evidence-bundle.ps1" @(
    "-ContractPath", (Join-Path $saT102 "verification/T-102.contract.json"),
    "-QualityReport", (Join-Path $saT102 "reports/quality-gate/T-102.md"),
    "-RepoRoot", $saT102
)
if ($ecBundle13 -eq 0) {
    ok "A.13a: generate-evidence-bundle succeeds for high task T-102"
} else {
    fail "A.13a: generate-evidence-bundle failed (exit $ecBundle13)"
}

$bundleT102 = Join-Path $saT102 "verification/T-102.evidence.json"
$ec13b = Invoke-Gate "check-evidence-bundle.ps1" @($bundleT102, "-RepoRoot", $saT102)
Assert-ExitCode "A.13b: check-evidence-bundle passes for high task T-102" $ec13b 0

# ===========================================================================
# SCENARIO B1: HOOK CONTRACT FOR ALL 3 CLI FORMS
# ===========================================================================
Write-Host "=== Scenario B1: hook contract — all 3 CLI forms ==="

$sb = Join-Path $workDir "sb-hooks"
New-Item -ItemType Directory -Path (Join-Path $sb "specs/x") -Force | Out-Null

$guardJs = Join-Path $scriptsDir "sdd-hook-guard.js"
$guardSh = Join-Path $scriptsDir "sdd-hook-guard.sh"
$guardPs = Join-Path $scriptsDir "sdd-hook-guard.ps1"

# Self-approval payload (deny): Edit targeting tasks.md adding Approval: Approved
$selfApprovePayload = '{"tool_name":"Edit","tool_input":{"file_path":"' + ($sb -replace '\\','/') + '/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'
# Benign payload (allow): Edit to a non-tasks path
$benignPayload = '{"tool_name":"Edit","tool_input":{"file_path":"' + ($sb -replace '\\','/') + '/src/foo.js","old_string":"a","new_string":"b"}}'
# Write payload temp files WITHOUT a UTF-8 BOM: the guards parse stdin with
# JSON.parse / json.loads, which reject a leading BOM as a malformed payload
# (fail-closed => deny). [System.Text.Encoding]::UTF8 would emit a BOM.
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

# ---- B1.1: Claude Code: node sdd-hook-guard.js --emit exit ----
Write-Host "--- B1.1: Claude Code node --emit exit ---"

$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCmd) {
    # Self-approval => exit 2
    $tmpNodeDenyIn  = [System.IO.Path]::GetTempFileName()
    $tmpNodeDenyOut = [System.IO.Path]::GetTempFileName()
    $tmpNodeDenyErr = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tmpNodeDenyIn, $selfApprovePayload, $utf8NoBom)
    $proc = Start-Process -FilePath "node" -ArgumentList @($guardJs, "--emit", "exit") `
        -RedirectStandardInput  $tmpNodeDenyIn `
        -RedirectStandardOutput $tmpNodeDenyOut `
        -RedirectStandardError  $tmpNodeDenyErr `
        -Wait -PassThru -NoNewWindow
    $ccDenyCode = $proc.ExitCode
    if ($ccDenyCode -eq 2) {
        ok "B1.1a: Claude Code node guard exits 2 on self-approval (deny)"
    } else {
        fail "B1.1a: Claude Code node guard should exit 2 on self-approval (got $ccDenyCode)"
    }

    # Benign => exit 0
    $tmpNodeAlwIn  = [System.IO.Path]::GetTempFileName()
    $tmpNodeAlwOut = [System.IO.Path]::GetTempFileName()
    $tmpNodeAlwErr = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tmpNodeAlwIn, $benignPayload, $utf8NoBom)
    $proc2 = Start-Process -FilePath "node" -ArgumentList @($guardJs, "--emit", "exit") `
        -RedirectStandardInput  $tmpNodeAlwIn `
        -RedirectStandardOutput $tmpNodeAlwOut `
        -RedirectStandardError  $tmpNodeAlwErr `
        -Wait -PassThru -NoNewWindow
    $ccAllowCode = $proc2.ExitCode
    if ($ccAllowCode -eq 0) {
        ok "B1.1b: Claude Code node guard exits 0 on benign payload (allow)"
    } else {
        fail "B1.1b: Claude Code node guard should exit 0 on benign payload (got $ccAllowCode)"
    }
} else {
    fail "B1.1a: node not found — skipped"
    fail "B1.1b: node not found — skipped"
}

# ---- B1.2: Codex: sh sdd-hook-guard.sh --emit exit ----
Write-Host "--- B1.2: Codex sh --emit exit ---"

$shCmd = Get-Command sh -ErrorAction SilentlyContinue
if ($shCmd) {
    # Self-approval => exit 2
    $tmpShDeny = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tmpShDeny, $selfApprovePayload, $utf8NoBom)
    $procSh1 = Start-Process -FilePath "sh" -ArgumentList @($guardSh, "--emit", "exit") `
        -RedirectStandardInput  $tmpShDeny `
        -RedirectStandardOutput ([System.IO.Path]::GetTempFileName()) `
        -RedirectStandardError  ([System.IO.Path]::GetTempFileName()) `
        -Wait -PassThru -NoNewWindow
    $cxDenyCode = $procSh1.ExitCode
    if ($cxDenyCode -eq 2) {
        ok "B1.2a: Codex sh guard exits 2 on self-approval (deny)"
    } else {
        fail "B1.2a: Codex sh guard should exit 2 on self-approval (got $cxDenyCode)"
    }

    # Benign => exit 0
    $tmpShAllow = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tmpShAllow, $benignPayload, $utf8NoBom)
    $procSh2 = Start-Process -FilePath "sh" -ArgumentList @($guardSh, "--emit", "exit") `
        -RedirectStandardInput  $tmpShAllow `
        -RedirectStandardOutput ([System.IO.Path]::GetTempFileName()) `
        -RedirectStandardError  ([System.IO.Path]::GetTempFileName()) `
        -Wait -PassThru -NoNewWindow
    $cxAllowCode = $procSh2.ExitCode
    if ($cxAllowCode -eq 0) {
        ok "B1.2b: Codex sh guard exits 0 on benign payload (allow)"
    } else {
        fail "B1.2b: Codex sh guard should exit 0 on benign payload (got $cxAllowCode)"
    }
} else {
    fail "B1.2a: sh not found — skipped"
    fail "B1.2b: sh not found — skipped"
}

# ---- B1.3: Copilot: sh sdd-hook-guard.sh --emit copilot ----
Write-Host "--- B1.3: Copilot sh --emit copilot ---"

if ($shCmd) {
    # Self-approval => stdout JSON with permissionDecision="deny", exit 0
    $tmpCopDenyIn  = [System.IO.Path]::GetTempFileName()
    $tmpCopDenyOut = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tmpCopDenyIn, $selfApprovePayload, $utf8NoBom)
    $procCop1 = Start-Process -FilePath "sh" -ArgumentList @($guardSh, "--emit", "copilot") `
        -RedirectStandardInput  $tmpCopDenyIn `
        -RedirectStandardOutput $tmpCopDenyOut `
        -RedirectStandardError  ([System.IO.Path]::GetTempFileName()) `
        -Wait -PassThru -NoNewWindow
    $copDenyCode = $procCop1.ExitCode
    $copDenyOut  = Get-Content -Raw -Encoding Utf8 $tmpCopDenyOut
    try {
        $copDenyDecision = ($copDenyOut | ConvertFrom-Json).permissionDecision
    } catch {
        $copDenyDecision = ""
    }
    if ($copDenyCode -eq 0 -and $copDenyDecision -eq "deny") {
        ok "B1.3a: Copilot sh guard emits permissionDecision=deny on self-approval (exit 0)"
    } else {
        fail "B1.3a: Copilot sh guard should emit deny (code=$copDenyCode, decision='$copDenyDecision', out='$copDenyOut')"
    }

    # Benign => stdout JSON with permissionDecision="allow", exit 0
    $tmpCopAlwIn  = [System.IO.Path]::GetTempFileName()
    $tmpCopAlwOut = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tmpCopAlwIn, $benignPayload, $utf8NoBom)
    $procCop2 = Start-Process -FilePath "sh" -ArgumentList @($guardSh, "--emit", "copilot") `
        -RedirectStandardInput  $tmpCopAlwIn `
        -RedirectStandardOutput $tmpCopAlwOut `
        -RedirectStandardError  ([System.IO.Path]::GetTempFileName()) `
        -Wait -PassThru -NoNewWindow
    $copAllowCode = $procCop2.ExitCode
    $copAllowOut  = Get-Content -Raw -Encoding Utf8 $tmpCopAlwOut
    try {
        $copAllowDecision = ($copAllowOut | ConvertFrom-Json).permissionDecision
    } catch {
        $copAllowDecision = ""
    }
    if ($copAllowCode -eq 0 -and $copAllowDecision -eq "allow") {
        ok "B1.3b: Copilot sh guard emits permissionDecision=allow on benign payload (exit 0)"
    } else {
        fail "B1.3b: Copilot sh guard should emit allow (code=$copAllowCode, decision='$copAllowDecision', out='$copAllowOut')"
    }
} else {
    fail "B1.3a: sh not found — skipped"
    fail "B1.3b: sh not found — skipped"
}

# ---- B1.4: DRIFT GUARD ----
Write-Host "--- B1.4: drift guard — hook configs reference the correct CLI invocations ---"

$claudeHooks  = Join-Path $hooksDir "claude-hooks.json"
$codexHooks   = Join-Path $hooksDir "hooks.json"
$copilotHooks = Join-Path $hooksDir "copilot-hooks.json"

# Claude Code config must reference sdd-hook-guard.js with --emit and exit
$claudeContent = Get-Content -Raw -Encoding Utf8 $claudeHooks
if (($claudeContent | Select-String "sdd-hook-guard.js" -Quiet) -and
    ($claudeContent | Select-String '"--emit"' -Quiet) -and
    ($claudeContent | Select-String '"exit"' -Quiet)) {
    ok "B1.4a: claude-hooks.json references sdd-hook-guard.js with --emit exit"
} else {
    fail "B1.4a: claude-hooks.json must reference sdd-hook-guard.js --emit exit (check $claudeHooks)"
}

# Codex config must reference sdd-hook-guard.sh --emit exit
$codexContent = Get-Content -Raw -Encoding Utf8 $codexHooks
if (($codexContent | Select-String "sdd-hook-guard.sh" -Quiet) -and
    ($codexContent | Select-String "\-\-emit exit" -Quiet)) {
    ok "B1.4b: hooks.json references sdd-hook-guard.sh --emit exit"
} else {
    fail "B1.4b: hooks.json must reference sdd-hook-guard.sh --emit exit (check $codexHooks)"
}

# Copilot config must reference sdd-hook-guard.sh --emit copilot
$copilotContent = Get-Content -Raw -Encoding Utf8 $copilotHooks
if (($copilotContent | Select-String "sdd-hook-guard.sh" -Quiet) -and
    ($copilotContent | Select-String "\-\-emit copilot" -Quiet)) {
    ok "B1.4c: copilot-hooks.json references sdd-hook-guard.sh --emit copilot"
} else {
    fail "B1.4c: copilot-hooks.json must reference sdd-hook-guard.sh --emit copilot (check $copilotHooks)"
}

# ===========================================================================
# SCENARIO E: CRITICAL SIGNING ROUND-TRIP
# ===========================================================================
Write-Host "=== Scenario E: critical signing round-trip ==="

$se     = Join-Path $workDir "se-signing"
$featE  = "feat-signing"
foreach ($d in @(
    (Join-Path $se "verification"),
    (Join-Path $se "specs/$featE/verification"),
    (Join-Path $se "reports/quality-gate"),
    (Join-Path $se "reports/implementation"),
    (Join-Path $se "src")
)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }

"All checks passed." | Set-Content -Encoding Utf8 (Join-Path $se "specs/$featE/verification/ev.log")
"RED: test FAILED"   | Set-Content -Encoding Utf8 (Join-Path $se "specs/$featE/verification/tdd-red.log")
"GREEN: test PASSED" | Set-Content -Encoding Utf8 (Join-Path $se "specs/$featE/verification/tdd-green.log")
"def sign(x):`n    return x" | Set-Content -Encoding Utf8 (Join-Path $se "src/signer.py")
"# Requirements`n- REQ-001: signing must be verifiable" | Set-Content -Encoding Utf8 (Join-Path $se "specs/$featE/requirements.md")

@"
Task ID: T-201
VERDICT: PASS

Critical signing task; all checks green.
"@ | Set-Content -Encoding Utf8 (Join-Path $se "reports/quality-gate/T-201.md")

@"
{
  "task_id": "T-201",
  "feature": "$featE",
  "risk": "critical",
  "stack": "code",
  "required_workflow": "tdd",
  "created": "2026-06-14T00:00:00Z",
  "checks": [
    { "id": "lint",                     "required": true,  "passes": true,  "evidence": "specs/$featE/verification/ev.log", "waiver_reason": "" },
    { "id": "typecheck",                "required": true,  "passes": true,  "evidence": "specs/$featE/verification/ev.log", "waiver_reason": "" },
    { "id": "unit-tests",               "required": true,  "passes": true,  "evidence": "specs/$featE/verification/ev.log",
      "red_evidence": "specs/$featE/verification/tdd-red.log",
      "green_evidence": "specs/$featE/verification/tdd-green.log",
      "waiver_reason": "" },
    { "id": "build",                    "required": true,  "passes": true,  "evidence": "specs/$featE/verification/ev.log", "waiver_reason": "" },
    { "id": "placeholder-scan",         "required": true,  "passes": true,  "evidence": "specs/$featE/verification/ev.log", "waiver_reason": "" },
    { "id": "task-state-check",         "required": true,  "passes": true,  "evidence": "specs/$featE/verification/ev.log", "waiver_reason": "" },
    { "id": "acceptance-tests",         "required": true,  "passes": true,  "evidence": "specs/$featE/verification/ev.log",
      "red_evidence": "specs/$featE/verification/tdd-red.log",
      "green_evidence": "specs/$featE/verification/tdd-green.log",
      "waiver_reason": "" },
    { "id": "regression",               "required": true,  "passes": true,  "evidence": "specs/$featE/verification/ev.log", "waiver_reason": "" },
    { "id": "requirement-traceability", "required": true,  "passes": true,  "evidence": "specs/$featE/verification/ev.log", "waiver_reason": "" }
  ]
}
"@ | Set-Content -Encoding Utf8 (Join-Path $se "verification/T-201.contract.json")

git_init_and_commit $se

# Generate an ephemeral key — never hard-coded, never printed
$sddEvidenceKey = [System.BitConverter]::ToString([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).Replace("-","").ToLower()
$env:SDD_EVIDENCE_KEY = $sddEvidenceKey

$bundleE = Join-Path $se "verification/T-201.evidence.json"

try {
    # ---- E.1: generate signed bundle for critical task => PASS ----
    Write-Host "--- E.1: generate signed critical bundle ---"

    $ecE1 = Invoke-Gate "generate-evidence-bundle.ps1" @(
        "-ContractPath", (Join-Path $se "verification/T-201.contract.json"),
        "-QualityReport", (Join-Path $se "reports/quality-gate/T-201.md"),
        "-RepoRoot", $se
    )
    if ($ecE1 -eq 0) {
        ok "E.1: generate-evidence-bundle succeeds for critical task with SDD_EVIDENCE_KEY"
    } else {
        fail "E.1: generate-evidence-bundle failed for critical task (exit $ecE1)"
    }

    # Verify the bundle actually has a signature field (hmac-sha256)
    if (Test-Path -LiteralPath $bundleE) {
        try {
            $bundleObj = Get-Content -Raw -Encoding Utf8 $bundleE | ConvertFrom-Json
            $sig = $bundleObj.signature
            $hasSig = ($null -ne $sig -and $sig.alg -eq "hmac-sha256" -and -not [string]::IsNullOrWhiteSpace($sig.value))
        } catch {
            $hasSig = $false
        }
    } else {
        $hasSig = $false
    }
    if ($hasSig) {
        ok "E.1b: signed bundle contains hmac-sha256 signature field"
    } else {
        fail "E.1b: signed bundle should contain hmac-sha256 signature"
    }

    # ---- E.2: check-evidence-bundle with correct key => PASS ----
    Write-Host "--- E.2: check-evidence-bundle with correct key passes ---"

    $ecE2 = Invoke-Gate "check-evidence-bundle.ps1" @($bundleE, "-RepoRoot", $se)
    Assert-ExitCode "E.2: check-evidence-bundle PASS with correct SDD_EVIDENCE_KEY" $ecE2 0

    # ---- E.3: tamper one byte of the bundle payload => FAIL (mentions signature/HMAC) ----
    Write-Host "--- E.3: tampered bundle fails signature check ---"

    $seTamper = Join-Path $workDir "se-tampered"
    New-Item -ItemType Directory -Path (Join-Path $seTamper "verification") -Force | Out-Null
    # Copy all artifacts so check-evidence-bundle can validate paths
    Copy-Item -Recurse (Join-Path $se "specs")   $seTamper
    Copy-Item -Recurse (Join-Path $se "reports") $seTamper
    Copy-Item (Join-Path $se "verification/T-201.contract.json") (Join-Path $seTamper "verification/")
    # Copy git dir so git_commit check passes
    Copy-Item -Recurse (Join-Path $se ".git") $seTamper

    # Tamper the bundle: flip one hex digit in the signature value
    $origBundle = Get-Content -Raw -Encoding Utf8 $bundleE | ConvertFrom-Json
    $origSig    = $origBundle.signature
    $sigVal     = [string]$origSig.value
    if ($sigVal.Length -gt 0) {
        $lastChar = $sigVal[-1]
        $flipped  = if ($lastChar -ne '0') { '0' } else { '1' }
        $origSig.value = $sigVal.Substring(0, $sigVal.Length - 1) + $flipped
    }
    # Re-assign the modified signature back to a new ordered object for serialization
    $tamperedBundle = [ordered]@{}
    $origBundle.PSObject.Properties | ForEach-Object {
        if ($_.Name -eq "signature") {
            $tamperedBundle["signature"] = [ordered]@{
                alg     = $origSig.alg
                value   = $origSig.value
                key_ref = $origSig.key_ref
            }
        } else {
            $tamperedBundle[$_.Name] = $_.Value
        }
    }
    $tamperedBundlePath = Join-Path $seTamper "verification/T-201.evidence.json"
    ($tamperedBundle | ConvertTo-Json -Depth 8) | Set-Content -Encoding Utf8 $tamperedBundlePath

    $ecE3, $outE3 = Run-Gate "check-evidence-bundle.ps1" @($tamperedBundlePath, "-RepoRoot", $seTamper)
    if ($ecE3 -ne 0 -and $outE3 -imatch "signature|HMAC|hmac") {
        ok "E.3: tampered critical bundle fails check-evidence-bundle (mentions signature/HMAC)"
    } else {
        fail "E.3: tampered bundle should fail with signature/HMAC error (ec=$ecE3, out='$outE3')"
    }

} finally {
    Remove-Item Env:SDD_EVIDENCE_KEY -ErrorAction SilentlyContinue
}

# ===========================================================================
# Cleanup temp directory
# ===========================================================================
try { Remove-Item -Recurse -Force $workDir -ErrorAction SilentlyContinue } catch {}

# ===========================================================================
# Summary
# ===========================================================================
Write-Host ""
Write-Host "Results: $($script:PASS) passed, $($script:FAIL) failed."
if ($script:FAIL -eq 0) {
    exit 0
} else {
    exit 1
}
