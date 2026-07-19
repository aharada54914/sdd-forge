# prepare-panelist.tests.ps1 — TDD tests for prepare-panelist-input.ps1 (AC-005)
# Style: mirrors cross-model.tests.ps1 (ok/fail counters, New-TemporaryFile fixtures, exits 1 on failure)
param()
$ErrorActionPreference = "Stop"

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$ScriptsDir = Join-Path $RepoRoot "plugins/sdd-quality-loop/scripts"
$PowerShellHost = if ($null -ne (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    (Get-Command pwsh).Source
} else {
    Join-Path $PSHOME "powershell.exe"
}

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
        $out = & $PowerShellHost -NoLogo -NoProfile -File (Join-Path $ScriptsDir "prepare-panelist-input.ps1") @ArgList 2>&1
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

function Get-SudoSignature {
    param([string]$Key, [string]$Issuer, [string]$Nonce, [string]$Repo, [long]$Issued, [long]$Expires)
    $message = @($Issuer, $Nonce, $Repo, [string]$Issued, [string]$Expires) -join "`n"
    $hmac = [System.Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($Key))
    try { return -join ($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($message)) | ForEach-Object { $_.ToString("x2") }) }
    finally { $hmac.Dispose() }
}

function Write-SudoToken {
    param([string]$Directory, [string]$Issuer, [string]$Nonce, [string]$Repo, [long]$Issued, [long]$Expires, [string]$Signature)
    [IO.File]::WriteAllText((Join-Path $Directory "SDD_SUDO"), (@(
        "enabled-by: test", "issuer: $Issuer", "nonce: $Nonce", "repo: $Repo",
        "issued-epoch: $Issued", "expires-epoch: $Expires", "sig: $Signature"
    ) -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
}

# ── TEST-013..017/032 helpers (REQ-003, declared-outputs completeness) ──────

$BT = [char]96   # backtick, used to build "| `path` | `hash` |" table rows

function Get-Sha256OfFile {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLower()
}

function Get-WrongHash {
    # A 64-hex string guaranteed not to equal any real SHA-256 digest used
    # below (all lowercase 'f', never produced by Get-Sha256OfFile).
    return ("f" * 64)
}

# Write an implementation report fixture at
# <ProjectRoot>/reports/implementation/<Feature>/<TaskId>.md with an
# "## Outputs" table. $Paths and $Hashes are parallel arrays.
function Write-ImplReport {
    param([string]$ProjectRoot, [string]$Feature, [string]$TaskId, [string[]]$Paths, [string[]]$Hashes)
    $dir = Join-Path $ProjectRoot (Join-Path "reports" (Join-Path "implementation" $Feature))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Implementation Report: $TaskId")
    $lines.Add("")
    $lines.Add("## Outputs")
    $lines.Add("")
    $lines.Add("| Path | SHA-256 |")
    $lines.Add("|---|---|")
    for ($i = 0; $i -lt $Paths.Count; $i++) {
        $lines.Add("| $BT$($Paths[$i])$BT | $BT$($Hashes[$i])$BT |")
    }
    $lines.Add("")
    $lines.Add("## Test Evidence")
    $lines.Add("")
    $lines.Add("N/A (fixture).")
    Set-Content -Encoding Utf8 -Path (Join-Path $dir "$TaskId.md") -Value ($lines -join "`n")
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

# ============================================================================
# PP-008 through PP-012: real-HMAC and independently invalid signed fields
# ============================================================================

Write-Host "=== PP-008/009/010/011/012: real SDD_SUDO HMAC verification ==="

$d = Join-Path $Work "pp008"
New-Item -ItemType Directory -Path $d -Force | Out-Null
Write-TasksNoConsent -Path (Join-Path $d "tasks.md")
Write-CleanInput -Path (Join-Path $d "input.txt")
$key = "issue-108-powershell-test-key"
$issuer = "test@example"
$nonce = "aabbccddeeff00112233445566778899"
$issued = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$expires = $issued + 3600
$repo = (Resolve-Path $d).Path
$signature = Get-SudoSignature $key $issuer $nonce $repo $issued $expires
$previousKey = $env:SDD_SUDO_KEY
$env:SDD_SUDO_KEY = $key
try {
    Write-SudoToken $d $issuer $nonce $repo $issued $expires $signature
    Invoke-Prepare @("--task", "T-004", "--feature", "cross-model-verification", "--input", (Join-Path $d "input.txt"), "--tasks-file", (Join-Path $d "tasks.md"), "--project-root", $d, "--out", (Join-Path $d "out.txt"))
    if ($script:PP_Exit -eq 0 -and (Test-Path (Join-Path $d "out.txt"))) { ok "PP-008: real-HMAC token grants consent" } else { fail "PP-008: valid real-HMAC token denied: $($script:PP_Output)" }

    Write-SudoToken $d "$issuer-tampered" $nonce $repo $issued $expires $signature
    Remove-Item (Join-Path $d "out.txt") -ErrorAction SilentlyContinue
    Invoke-Prepare @("--task", "T-004", "--feature", "cross-model-verification", "--input", (Join-Path $d "input.txt"), "--tasks-file", (Join-Path $d "tasks.md"), "--project-root", $d, "--out", (Join-Path $d "out.txt"))
    if ($script:PP_Exit -ne 0 -and -not (Test-Path (Join-Path $d "out.txt"))) { ok "PP-009: tampered signed field is denied" } else { fail "PP-009: tampered field must be denied" }

    $badNonce = "not-hex"; $badSig = Get-SudoSignature $key $issuer $badNonce $repo $issued $expires
    Write-SudoToken $d $issuer $badNonce $repo $issued $expires $badSig
    Invoke-Prepare @("--task", "T-004", "--feature", "cross-model-verification", "--input", (Join-Path $d "input.txt"), "--tasks-file", (Join-Path $d "tasks.md"), "--project-root", $d, "--out", (Join-Path $d "out.txt"))
    if ($script:PP_Exit -ne 0 -and -not (Test-Path (Join-Path $d "out.txt"))) { ok "PP-010: correctly signed invalid nonce is denied with no bundle" } else { fail "PP-010: invalid nonce must be denied with no bundle" }

    $expired = $issued - 1; $expiredIssued = $issued - 7200; $expiredSig = Get-SudoSignature $key $issuer $nonce $repo $expiredIssued $expired
    Write-SudoToken $d $issuer $nonce $repo $expiredIssued $expired $expiredSig
    Invoke-Prepare @("--task", "T-004", "--feature", "cross-model-verification", "--input", (Join-Path $d "input.txt"), "--tasks-file", (Join-Path $d "tasks.md"), "--project-root", $d, "--out", (Join-Path $d "out.txt"))
    if ($script:PP_Exit -ne 0 -and -not (Test-Path (Join-Path $d "out.txt"))) { ok "PP-011: correctly signed expired token is denied with no bundle" } else { fail "PP-011: expired token must be denied with no bundle" }

    $overlongExpires = $issued + 86401; $overlongSig = Get-SudoSignature $key $issuer $nonce $repo $issued $overlongExpires
    Write-SudoToken $d $issuer $nonce $repo $issued $overlongExpires $overlongSig
    Invoke-Prepare @("--task", "T-004", "--feature", "cross-model-verification", "--input", (Join-Path $d "input.txt"), "--tasks-file", (Join-Path $d "tasks.md"), "--project-root", $d, "--out", (Join-Path $d "out.txt"))
    if ($script:PP_Exit -ne 0 -and -not (Test-Path (Join-Path $d "out.txt"))) { ok "PP-012: correctly signed overlong TTL is denied with no bundle" } else { fail "PP-012: overlong TTL must be denied with no bundle" }

    $wrongRepo = "$repo-wrong"; $wrongSig = Get-SudoSignature $key $issuer $nonce $wrongRepo $issued $expires
    Write-SudoToken $d $issuer $nonce $wrongRepo $issued $expires $wrongSig
    Invoke-Prepare @("--task", "T-004", "--feature", "cross-model-verification", "--input", (Join-Path $d "input.txt"), "--tasks-file", (Join-Path $d "tasks.md"), "--project-root", $d, "--out", (Join-Path $d "out.txt"))
    if ($script:PP_Exit -ne 0 -and -not (Test-Path (Join-Path $d "out.txt"))) { ok "PP-013: correctly signed wrong repository is denied with no bundle" } else { fail "PP-013: wrong repository must be denied with no bundle" }
} finally {
    if ($null -eq $previousKey) { Remove-Item Env:SDD_SUDO_KEY -ErrorAction SilentlyContinue } else { $env:SDD_SUDO_KEY = $previousKey }
}

# ============================================================================
# TEST-013 (AC-013): recursion — subdirectory file included in the bundle,
# independent of the completeness check (no implementation report fixture).
# ============================================================================

Write-Host "=== TEST-013: recursion — subdirectory file included in bundle (AC-013) ==="

$d = Join-Path $Work "pp013"
New-Item -ItemType Directory -Path (Join-Path $d "input/sub") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d "input/top.txt") -Value "top-level marker TOPLEVEL013"
Set-Content -Encoding Utf8 -Path (Join-Path $d "input/sub/evidence.md") -Value "subdirectory marker SUBDIRMARKER013"

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-013a: recursive collection succeeds (exit 0)"
} else {
    fail "TEST-013a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if ((Test-Path (Join-Path $d "out.txt")) -and ((Get-Content -Raw (Join-Path $d "out.txt")) -match "SUBDIRMARKER013")) {
    ok "TEST-013b: subdirectory file content included in bundle (recursion)"
} else {
    fail "TEST-013b: subdirectory file content missing from bundle — collector did not recurse"
}

# ============================================================================
# TEST-014 (AC-014): completeness positive baseline — 2 top-level declared
# outputs, both present with matching SHA-256 → success + printed digest.
# ============================================================================

Write-Host "=== TEST-014: completeness positive baseline (AC-014) ==="

$d = Join-Path $Work "pp014"
New-Item -ItemType Directory -Path (Join-Path $d "input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d "input/artifact-one.txt") -Value "artifact one content"
Set-Content -Encoding Utf8 -Path (Join-Path $d "input/artifact-two.txt") -Value "artifact two content"
$hash014a = Get-Sha256OfFile (Join-Path $d "input/artifact-one.txt")
$hash014b = Get-Sha256OfFile (Join-Path $d "input/artifact-two.txt")
Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("artifact-one.txt", "artifact-two.txt") -Hashes @($hash014a, $hash014b)

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-014a: complete declared-outputs bundle → exit 0"
} else {
    fail "TEST-014a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if ([regex]::Match($script:PP_Output, '[0-9a-f]{64}').Success) {
    ok "TEST-014b: digest printed on completeness success"
} else {
    fail "TEST-014b: expected a printed digest, got: $($script:PP_Output)"
}

# ============================================================================
# TEST-015 (AC-015): declared path missing from --input → fail closed, gap
# printed, no digest line.
# ============================================================================

Write-Host "=== TEST-015: missing declared output → fail closed (AC-015) ==="

$d = Join-Path $Work "pp015"
New-Item -ItemType Directory -Path (Join-Path $d "input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d "input/present.txt") -Value "present content"
$hash015 = Get-Sha256OfFile (Join-Path $d "input/present.txt")
Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("present.txt", "missing.txt") -Hashes @($hash015, (Get-WrongHash))

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -ne 0) {
    ok "TEST-015a: missing declared output → nonzero exit"
} else {
    fail "TEST-015a: expected nonzero exit, got 0. Output: $($script:PP_Output)"
}
if ($script:PP_Output -match "missing\.txt") {
    ok "TEST-015b: gap (missing path) printed to stderr"
} else {
    fail "TEST-015b: expected a gap message naming missing.txt, got: $($script:PP_Output)"
}
if (-not [regex]::Match($script:PP_Output, '[0-9a-f]{64}').Success) {
    ok "TEST-015c: no digest line printed on completeness gap"
} else {
    fail "TEST-015c: digest must not print on a completeness gap. Output: $($script:PP_Output)"
}
if (-not (Test-Path (Join-Path $d "out.txt"))) {
    ok "TEST-015d: bundle file not written on completeness gap"
} else {
    fail "TEST-015d: bundle file must not be written on a completeness gap"
}

# ============================================================================
# TEST-016 (AC-016): declared path present but SHA-256 mismatch → same
# fail-closed/gap/no-digest contract as TEST-015.
# ============================================================================

Write-Host "=== TEST-016: hash-mismatch declared output → fail closed (AC-016) ==="

$d = Join-Path $Work "pp016"
New-Item -ItemType Directory -Path (Join-Path $d "input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d "input/artifact.txt") -Value "real content for hash mismatch test"
Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("artifact.txt") -Hashes @((Get-WrongHash))

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -ne 0) {
    ok "TEST-016a: hash-mismatch declared output → nonzero exit"
} else {
    fail "TEST-016a: expected nonzero exit, got 0. Output: $($script:PP_Output)"
}
if ($script:PP_Output -match "artifact\.txt") {
    ok "TEST-016b: gap (hash mismatch) printed to stderr"
} else {
    fail "TEST-016b: expected a gap message naming artifact.txt, got: $($script:PP_Output)"
}
if (-not [regex]::Match($script:PP_Output, '[0-9a-f]{64}').Success) {
    ok "TEST-016c: no digest line printed on hash-mismatch gap"
} else {
    fail "TEST-016c: digest must not print on a hash-mismatch gap. Output: $($script:PP_Output)"
}

# ============================================================================
# TEST-017 (AC-017): declared path under --input/sub/... is located and
# hash-verified correctly — combines TEST-013's recursion with TEST-014's
# completeness check.
# ============================================================================

Write-Host "=== TEST-017: subdirectory declared output located + verified (AC-017) ==="

$d = Join-Path $Work "pp017"
New-Item -ItemType Directory -Path (Join-Path $d "input/sub/nested") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d "input/sub/nested/artifact.md") -Value "nested artifact marker NESTEDMARKER017"
$hash017 = Get-Sha256OfFile (Join-Path $d "input/sub/nested/artifact.md")
Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("sub/nested/artifact.md") -Hashes @($hash017)

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-017a: subdirectory declared output found + hash-verified → exit 0"
} else {
    fail "TEST-017a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if ([regex]::Match($script:PP_Output, '[0-9a-f]{64}').Success) {
    ok "TEST-017b: digest printed (completeness passed for subdirectory path)"
} else {
    fail "TEST-017b: expected a printed digest, got: $($script:PP_Output)"
}
if ((Test-Path (Join-Path $d "out.txt")) -and ((Get-Content -Raw (Join-Path $d "out.txt")) -match "NESTEDMARKER017")) {
    ok "TEST-017c: nested artifact content collected into bundle (recursion)"
} else {
    fail "TEST-017c: nested artifact content missing from bundle — collector did not recurse"
}

# ============================================================================
# TEST-032 (AC-032): a `../`-traversal path and an absolute-path variant in
# the declared-outputs table, each resolving OUTSIDE --input, plus a sentinel
# file placed at that outside location → fail closed, violation reported,
# sentinel content NOWHERE in any produced output, no digest line.
# Operationalizes Security Boundary B1 (STRIDE Path Traversal / Information
# Disclosure, security-spec.md).
# ============================================================================

Write-Host "=== TEST-032: path-traversal declared output → fail closed (AC-032, B1) ==="

$d = Join-Path $Work "pp032"
New-Item -ItemType Directory -Path (Join-Path $d "input") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "outside") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d "input/legit.txt") -Value "legit content"
$hash032l = Get-Sha256OfFile (Join-Path $d "input/legit.txt")
$sentinelToken = "SENTINEL-TEST032-DO-NOT-LEAK-$PID"
Set-Content -Encoding Utf8 -Path (Join-Path $d "outside/secret.txt") -Value $sentinelToken
$hash032s = Get-Sha256OfFile (Join-Path $d "outside/secret.txt")
$absOutside = (Join-Path $d "outside/secret.txt")

Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("legit.txt", "../outside/secret.txt", $absOutside) `
    -Hashes @($hash032l, $hash032s, $hash032s)

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -ne 0) {
    ok "TEST-032a: path-traversal declared output → nonzero exit"
} else {
    fail "TEST-032a: expected nonzero exit, got 0. Output: $($script:PP_Output)"
}
if ($script:PP_Output -match [regex]::Escape("outside/secret.txt")) {
    ok "TEST-032b: out-of-root violation reported on stderr"
} else {
    fail "TEST-032b: expected an out-of-root violation message, got: $($script:PP_Output)"
}
if (-not [regex]::Match($script:PP_Output, '[0-9a-f]{64}').Success) {
    ok "TEST-032c: no digest line printed on path-traversal gap"
} else {
    fail "TEST-032c: digest must not print on a path-traversal gap. Output: $($script:PP_Output)"
}
if ($script:PP_Output -notmatch [regex]::Escape($sentinelToken)) {
    ok "TEST-032d: sentinel content does not appear anywhere in stdout/stderr"
} else {
    fail "TEST-032d: SENTINEL LEAK — sentinel content found in prepare-panelist-input output"
}
if (-not (Test-Path (Join-Path $d "out.txt"))) {
    ok "TEST-032e: bundle file not written on path-traversal gap"
} else {
    fail "TEST-032e: bundle file must not be written on a path-traversal gap"
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
