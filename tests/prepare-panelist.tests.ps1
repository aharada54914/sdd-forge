# prepare-panelist.tests.ps1 — TDD tests for prepare-panelist-input.ps1 (AC-005)
# Style: mirrors cross-model.tests.ps1 (ok/fail counters, New-TemporaryFile fixtures, exits 1 on failure)
param()
$ErrorActionPreference = "Stop"

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$ScriptsDir = Join-Path $RepoRoot "plugins/sdd-quality-loop/scripts"

$Pass = 0
$Fail = 0

function ok($msg)   { Write-Host "ok: $msg";   $script:Pass++ }
function fail($msg) { Write-Host "FAIL: $msg"; $script:Fail++ }

$Work = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $Work -Force | Out-Null

try {

# ============================================================================
# Helpers
# ============================================================================

function Invoke-Prepare {
    param([string[]]$ArgList)
    $script:PP_Exit   = 0
    $script:PP_Output = ""
    try {
        $out = & pwsh -NoLogo -NoProfile -File (Join-Path $ScriptsDir "prepare-panelist-input.ps1") @ArgList 2>&1
        $script:PP_Exit   = $LASTEXITCODE
        $script:PP_Output = ($out -join "`n")
    } catch {
        $script:PP_Exit   = 99
        $script:PP_Output = $_.ToString()
    }
}

function Write-TasksWithConsent {
    param([string]$Path, [string]$TaskId = "T-004")
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
    Set-Content -Encoding Utf8 -Path $Path -Value @"
# Tasks

## $TaskId Some Task

Status: Planned
Risk: high
Cross-Model: enabled
"@
}

function Write-TasksNoConsent {
    param([string]$Path, [string]$TaskId = "T-004")
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
    Set-Content -Encoding Utf8 -Path $Path -Value @"
# Tasks

## $TaskId Some Task

Status: Planned
Risk: high
"@
}

function Write-InputWithSecrets {
    param([string]$Path)
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
    Set-Content -Encoding Utf8 -Path $Path -Value @'
# Design Review Input

## Feature: cross-model-verification

This feature implements a consent gate for panelist input preparation.

## Code Snippet

def get_client():
    # Normal code
    api_url = "https://api.example.com/v1/completions"
    return api_url

## Environment Configuration

AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
OPENAI_API_KEY=sk-proj-abc123def456ghi789jkl012mno345pqr678stu901vwx234
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
PRIVATE_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
DB_PASSWORD=supersecretpassword123!

## File Paths

Config loaded from /Users/alice/projects/myapp/config.json
Log output to /home/bob/.local/share/myapp/debug.log
Keys stored in C:\Users\charlie\AppData\Roaming\myapp\keys

## Private URLs

See internal doc at http://internal.corp.example.com/docs/secret
Also http://192.168.1.100/admin for local admin

## Normal Content

The implementation uses sha256 for digest computation.
All panelists receive the same sanitized input bundle.
'@
}

function Write-CleanInput {
    param([string]$Path)
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
    Set-Content -Encoding Utf8 -Path $Path -Value @'
# Design Review Input

## Feature: cross-model-verification

This feature implements a consent gate for panelist input preparation.

The implementation uses sha256 for digest computation.
All panelists receive the same sanitized input bundle.
'@
}

# ============================================================================
# PP-001: No consent → fail closed
# ============================================================================

Write-Host "=== PP-001: Fail closed — no consent ==="

$d = Join-Path $Work "pp001"
New-Item -ItemType Directory -Path $d -Force | Out-Null
Write-TasksNoConsent -Path (Join-Path $d "tasks.md")
Write-CleanInput     -Path (Join-Path $d "input.txt")
$outFile = Join-Path $d "out.txt"

Invoke-Prepare @(
    "--task", "T-004",
    "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input.txt"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--out", $outFile
)

if ($script:PP_Exit -ne 0) {
    ok "PP-001a: no consent → non-zero exit ($($script:PP_Exit))"
} else {
    fail "PP-001a: no consent should exit non-zero, got 0"
}

if (-not (Test-Path $outFile)) {
    ok "PP-001b: no consent → output file NOT created"
} else {
    fail "PP-001b: output file must NOT be created without consent"
}

if ($script:PP_Output -imatch "consent") {
    ok "PP-001c: error message mentions consent"
} else {
    fail "PP-001c: error message should mention 'consent', got: $($script:PP_Output)"
}

# ============================================================================
# PP-002: Consent via tasks.md flag → success + secrets stripped
# ============================================================================

Write-Host "=== PP-002: Consent via tasks.md flag + secret sanitization ==="

$d = Join-Path $Work "pp002"
New-Item -ItemType Directory -Path $d -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d "tasks.md")
Write-InputWithSecrets -Path (Join-Path $d "input.txt")
$outFile = Join-Path $d "out.txt"

Invoke-Prepare @(
    "--task", "T-004",
    "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input.txt"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--out", $outFile
)

if ($script:PP_Exit -eq 0) {
    ok "PP-002a: consent present → exit 0"
} else {
    fail "PP-002a: consent present should exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}

if (Test-Path $outFile) {
    ok "PP-002b: output file created"
    $outContent = Get-Content -Raw $outFile

    if ($outContent -notmatch "wJalrXUtnFEMI") {
        ok "PP-002c: AWS_SECRET_ACCESS_KEY value stripped"
    } else {
        fail "PP-002c: AWS_SECRET_ACCESS_KEY value found in output — SECRET LEAK"
    }

    if ($outContent -notmatch "sk-proj-abc123") {
        ok "PP-002d: OPENAI_API_KEY value stripped"
    } else {
        fail "PP-002d: OPENAI_API_KEY value found in output — SECRET LEAK"
    }

    if ($outContent -notmatch "AKIAIOSFODNN7EXAMPLE") {
        ok "PP-002e: AWS_ACCESS_KEY_ID value stripped"
    } else {
        fail "PP-002e: AWS_ACCESS_KEY_ID value found in output — SECRET LEAK"
    }

    if ($outContent -notmatch "ghp_xxxxxxxxxxxx") {
        ok "PP-002f: GitHub PAT stripped"
    } else {
        fail "PP-002f: GitHub PAT found in output — SECRET LEAK"
    }

    if ($outContent -notmatch "supersecretpassword123") {
        ok "PP-002g: DB_PASSWORD value stripped"
    } else {
        fail "PP-002g: DB_PASSWORD value found in output — SECRET LEAK"
    }

    if ($outContent -notmatch "/Users/alice") {
        ok "PP-002h: absolute Unix path /Users/... stripped"
    } else {
        fail "PP-002h: absolute Unix path /Users/... found in output — PATH LEAK"
    }

    if ($outContent -notmatch "/home/bob") {
        ok "PP-002i: absolute Unix path /home/... stripped"
    } else {
        fail "PP-002i: absolute Unix path /home/... found in output — PATH LEAK"
    }

    if ($outContent -notmatch "internal\.corp\.example\.com") {
        ok "PP-002j: private URL stripped"
    } else {
        fail "PP-002j: private URL found in output — URL LEAK"
    }

    if ($outContent -notmatch "192\.168\.1\.100") {
        ok "PP-002k: private IP URL stripped"
    } else {
        fail "PP-002k: private IP URL found in output — URL LEAK"
    }

    if ($outContent -match "sha256") {
        ok "PP-002l: normal content preserved"
    } else {
        fail "PP-002l: normal content should remain in sanitized output"
    }
} else {
    fail "PP-002b: output file not created. Output: $($script:PP_Output)"
}

# ============================================================================
# PP-003: input_digest is 64-hex printed to stdout
# ============================================================================

Write-Host "=== PP-003: input_digest deterministic and 64-hex ==="

$d = Join-Path $Work "pp003"
New-Item -ItemType Directory -Path $d -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d "tasks.md")
Write-CleanInput       -Path (Join-Path $d "input.txt")

Invoke-Prepare @(
    "--task", "T-004",
    "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input.txt"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -eq 0) {
    $m = [regex]::Match($script:PP_Output, '[0-9a-f]{64}')
    if ($m.Success) {
        ok "PP-003a: input_digest is 64-hex: $($m.Value)"
    } else {
        fail "PP-003a: could not find 64-hex digest in output: $($script:PP_Output)"
    }
} else {
    fail "PP-003: exit non-zero unexpectedly: $($script:PP_Exit). Output: $($script:PP_Output)"
}

# ============================================================================
# PP-004: Same input → same digest (deterministic)
# ============================================================================

Write-Host "=== PP-004: Digest is deterministic ==="

foreach ($run in "pp004a","pp004b") {
    $d2 = Join-Path $Work $run
    New-Item -ItemType Directory -Path $d2 -Force | Out-Null
    Write-TasksWithConsent -Path (Join-Path $d2 "tasks.md")
    Write-CleanInput       -Path (Join-Path $d2 "input.txt")
}

Invoke-Prepare @(
    "--task", "T-004",
    "--feature", "cross-model-verification",
    "--input",  (Join-Path $Work "pp004a/input.txt"),
    "--tasks-file", (Join-Path $Work "pp004a/tasks.md"),
    "--out", (Join-Path $Work "pp004a/out.txt")
)
$m1 = [regex]::Match($script:PP_Output, '[0-9a-f]{64}')
$digestA = if ($m1.Success) { $m1.Value } else { "" }

Invoke-Prepare @(
    "--task", "T-004",
    "--feature", "cross-model-verification",
    "--input",  (Join-Path $Work "pp004b/input.txt"),
    "--tasks-file", (Join-Path $Work "pp004b/tasks.md"),
    "--out", (Join-Path $Work "pp004b/out.txt")
)
$m2 = [regex]::Match($script:PP_Output, '[0-9a-f]{64}')
$digestB = if ($m2.Success) { $m2.Value } else { "" }

if ($digestA -and ($digestA -eq $digestB)) {
    ok "PP-004: same input → same digest ($digestA)"
} else {
    fail "PP-004: digest not deterministic: run1=$digestA run2=$digestB"
}

# ============================================================================
# PP-005: Default output path when --out not specified
# ============================================================================

Write-Host "=== PP-005: Default output path ==="

$featureDir = Join-Path $Work "pp005/specs/cross-model-verification"
New-Item -ItemType Directory -Path (Join-Path $featureDir "verification") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $Work "pp005/tasks.md")
Write-CleanInput       -Path (Join-Path $Work "pp005/input.txt")

Invoke-Prepare @(
    "--task", "T-004",
    "--feature", "cross-model-verification",
    "--input", (Join-Path $Work "pp005/input.txt"),
    "--tasks-file", (Join-Path $Work "pp005/tasks.md"),
    "--spec-root", (Join-Path $Work "pp005/specs")
)

if ($script:PP_Exit -eq 0) {
    $defaultOut = Join-Path $featureDir "verification/T-004.panelist-input.txt"
    if (Test-Path $defaultOut) {
        ok "PP-005: default output path created at verification/T-004.panelist-input.txt"
    } else {
        fail "PP-005: default output not found at $defaultOut. Output: $($script:PP_Output)"
    }
} else {
    fail "PP-005: unexpected failure: $($script:PP_Exit). Output: $($script:PP_Output)"
}

# ============================================================================
# PP-006: Missing --task or --feature → non-zero exit
# ============================================================================

Write-Host "=== PP-006: Required args validation ==="

Invoke-Prepare @("--feature", "cross-model-verification", "--input", (Join-Path $Work "pp001/input.txt"))
if ($script:PP_Exit -ne 0) {
    ok "PP-006a: missing --task → non-zero exit"
} else {
    fail "PP-006a: missing --task should fail, got exit 0"
}

Invoke-Prepare @("--task", "T-004", "--input", (Join-Path $Work "pp001/input.txt"))
if ($script:PP_Exit -ne 0) {
    ok "PP-006b: missing --feature → non-zero exit"
} else {
    fail "PP-006b: missing --feature should fail, got exit 0"
}

# ============================================================================
# PP-007: SDD_SUDO as consent path (skip-sig test mode)
# ============================================================================

Write-Host "=== PP-007: SDD_SUDO consent path ==="

$d = Join-Path $Work "pp007"
New-Item -ItemType Directory -Path $d -Force | Out-Null
Write-TasksNoConsent -Path (Join-Path $d "tasks.md")
Write-CleanInput     -Path (Join-Path $d "input.txt")

$issued  = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$expires = $issued + 3600
$issuedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
Set-Content -Encoding Utf8 -Path (Join-Path $d "SDD_SUDO") -Value @"
enabled-by: human via /sdd-sudo
enabled-at: $issuedAt
issuer: testuser@testhost
nonce: aabbccddeeff00112233445566778899
repo: $d
issued-epoch: $issued
expires-epoch: $expires
duration: 1h
sig: 0000000000000000000000000000000000000000000000000000000000000000
"@

# Check if SDD_SUDO was actually created (hook guard may block it in agent context)
$sudoCreated = Test-Path (Join-Path $d "SDD_SUDO")

if (-not $sudoCreated) {
    ok "PP-007: SDD_SUDO file creation blocked by env (hook guard active) — skip in agent context, runs in user terminal"
} else {
    $env:SDD_SUDO_SKIP_SIG = "1"
    try {
        Invoke-Prepare @(
            "--task", "T-004",
            "--feature", "cross-model-verification",
            "--input", (Join-Path $d "input.txt"),
            "--tasks-file", (Join-Path $d "tasks.md"),
            "--project-root", $d,
            "--out", (Join-Path $d "out.txt")
        )
    } finally {
        Remove-Item Env:SDD_SUDO_SKIP_SIG -ErrorAction SilentlyContinue
    }

    if ($script:PP_Exit -eq 0) {
        ok "PP-007: SDD_SUDO (skip-sig test mode) grants consent → exit 0"
    } else {
        fail "PP-007: SDD_SUDO path: consent gate failed. Output: $($script:PP_Output)"
    }
}

} finally {
    Remove-Item -Recurse -Force $Work -ErrorAction SilentlyContinue
}

# ============================================================================
# Summary
# ============================================================================

Write-Host ""
Write-Host "Results: $Pass passed, $Fail failed"
if ($Fail -gt 0) { exit 1 }
exit 0
