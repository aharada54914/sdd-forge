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

# ── TEST-039..044 helpers (declaration-commit fallback for shared/living
# files, drifted after the implementation report was written) ──────────────

function New-PpiGitScratchRepo {
    param([string]$Root)
    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    & git -C $Root init -q
    if ($LASTEXITCODE -ne 0) { throw "prepare-panelist fixture: git init failed: $Root" }
    & git -C $Root config user.email "test@example.invalid"
    & git -C $Root config user.name "Prepare Panelist Test"
    & git -C $Root config commit.gpgsign false
}

function Invoke-PpiGitCommit {
    param([string]$Root, [string]$Message, [string[]]$Paths = @("-A"))
    & git -C $Root add @Paths
    if ($LASTEXITCODE -ne 0) { throw "prepare-panelist fixture: git add failed: $Root" }
    & git -C $Root commit -q -m $Message
    if ($LASTEXITCODE -ne 0) { throw "prepare-panelist fixture: git commit failed: $Root" }
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

# Hermetic consent denial: PP-001 passes no --project-root, so the script
# walks up from CWD and can find an operator's live SDD_SUDO token at the
# real repo root — which ~/.sdd/sudo-key would legitimately verify, granting
# consent and breaking the fixture assumption. A dummy key wins the script's
# key-resolution order, so no real token can ever verify during the fixture;
# SDD_SUDO_SKIP_SIG=0 shields against the skip flag leaking in from the env.
$prevPP001Key     = $env:SDD_SUDO_KEY
$prevPP001SkipSig = $env:SDD_SUDO_SKIP_SIG
$env:SDD_SUDO_KEY      = "0" * 64
$env:SDD_SUDO_SKIP_SIG = "0"
try {
    Invoke-Prepare @(
        "--task", "T-004",
        "--feature", "cross-model-verification",
        "--input", (Join-Path $d "input.txt"),
        "--tasks-file", (Join-Path $d "tasks.md"),
        "--out", $outFile
    )
} finally {
    if ($null -eq $prevPP001Key) { Remove-Item Env:SDD_SUDO_KEY -ErrorAction SilentlyContinue } else { $env:SDD_SUDO_KEY = $prevPP001Key }
    if ($null -eq $prevPP001SkipSig) { Remove-Item Env:SDD_SUDO_SKIP_SIG -ErrorAction SilentlyContinue } else { $env:SDD_SUDO_SKIP_SIG = $prevPP001SkipSig }
}

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

# ============================================================================
# TEST-033: project-root-relative declared output resolves via the
# --project-root fallback when it is absent under --input. Real
# implementation reports declare rows relative to project_root (the same
# convention generate-evidence-bundle/check-evidence-bundle use), not
# --input — this is the exact defect this fix addresses; before the fix
# every such row was reported "missing from bundle" and the check could
# never pass against a real report.
# ============================================================================

Write-Host "=== TEST-033: project-root-relative declared output resolves via fallback ==="

$d = Join-Path $Work "pp033"
New-Item -ItemType Directory -Path (Join-Path $d "input") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "other") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d "other/artifact.txt") -Value "other artifact content"
$hash033 = Get-Sha256OfFile (Join-Path $d "other/artifact.txt")
Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("other/artifact.txt") -Hashes @($hash033)

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-033a: project-root-relative row not present under --input resolves via fallback -> exit 0"
} else {
    fail "TEST-033a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if ([regex]::Match($script:PP_Output, '[0-9a-f]{64}').Success) {
    ok "TEST-033b: digest printed on project-root fallback success"
} else {
    fail "TEST-033b: expected a printed digest, got: $($script:PP_Output)"
}

# ============================================================================
# TEST-035: declared output absent under BOTH --input and --project-root
# still fails closed with the unchanged "missing from bundle" message —
# proves the two-root fallback does not degenerate into accepting anything.
# (TEST-034 is intentionally not added: TEST-014/TEST-017 already cover an
# --input-relative row still resolving under the unchanged first-try path.)
# ============================================================================

Write-Host "=== TEST-035: declared output missing under both roots -> fail closed ==="

$d = Join-Path $Work "pp035"
New-Item -ItemType Directory -Path (Join-Path $d "input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("nowhere.txt") -Hashes @((Get-WrongHash))

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -ne 0) {
    ok "TEST-035a: missing under both roots -> nonzero exit"
} else {
    fail "TEST-035a: expected nonzero exit, got 0. Output: $($script:PP_Output)"
}
if ($script:PP_Output -match [regex]::Escape("declared output missing from bundle: nowhere.txt")) {
    ok "TEST-035b: unchanged 'missing from bundle' message text"
} else {
    fail "TEST-035b: expected unchanged missing-from-bundle message, got: $($script:PP_Output)"
}
if (-not [regex]::Match($script:PP_Output, '[0-9a-f]{64}').Success) {
    ok "TEST-035c: no digest line printed"
} else {
    fail "TEST-035c: digest must not print. Output: $($script:PP_Output)"
}
if (-not (Test-Path (Join-Path $d "out.txt"))) {
    ok "TEST-035d: bundle file not written"
} else {
    fail "TEST-035d: bundle file must not be written"
}

# ============================================================================
# TEST-036: hash mismatch on a row resolved via the --project-root fallback
# still fails closed (mirrors TEST-016's --input-root case, for the NEW
# fallback root).
# ============================================================================

Write-Host "=== TEST-036: hash-mismatch on project-root-fallback row -> fail closed ==="

$d = Join-Path $Work "pp036"
New-Item -ItemType Directory -Path (Join-Path $d "input") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "other") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d "other/artifact.txt") -Value "real other content for hash mismatch"
Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("other/artifact.txt") -Hashes @((Get-WrongHash))

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -ne 0) {
    ok "TEST-036a: hash-mismatch on project-root fallback row -> nonzero exit"
} else {
    fail "TEST-036a: expected nonzero exit, got 0. Output: $($script:PP_Output)"
}
if ($script:PP_Output -match [regex]::Escape("declared output hash mismatch: other/artifact.txt")) {
    ok "TEST-036b: unchanged 'hash mismatch' message text"
} else {
    fail "TEST-036b: expected hash-mismatch message, got: $($script:PP_Output)"
}
if (-not (Test-Path (Join-Path $d "out.txt"))) {
    ok "TEST-036c: bundle file not written on project-root-fallback hash mismatch"
} else {
    fail "TEST-036c: bundle file must not be written on a hash-mismatch gap"
}

# ============================================================================
# TEST-037: a row that would escape --input via a symlinked component is
# still rejected — containment holds for the --input root even though a
# --project-root fallback now exists.
# ============================================================================

Write-Host "=== TEST-037: symlink-escape under --input root -> fail closed (containment) ==="

$d = Join-Path $Work "pp037"
New-Item -ItemType Directory -Path (Join-Path $d "input") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "outside") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
$sentinel037 = "SENTINEL-TEST037-DO-NOT-LEAK-$PID"
Set-Content -Encoding Utf8 -Path (Join-Path $d "outside/secret.txt") -Value $sentinel037
$hash037 = Get-Sha256OfFile (Join-Path $d "outside/secret.txt")
$symlink037Created = $true
try {
    New-Item -ItemType SymbolicLink -Path (Join-Path $d "input/linkdir") -Target (Join-Path $d "outside") -ErrorAction Stop | Out-Null
} catch {
    $symlink037Created = $false
}

if (-not $symlink037Created) {
    ok "TEST-037: symlink creation unsupported/unprivileged on this host — skip (runs where symlinks are permitted)"
} else {
    Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
        -Paths @("linkdir/secret.txt") -Hashes @($hash037)

    Invoke-Prepare @(
        "--task", "T-004", "--feature", "cross-model-verification",
        "--input", (Join-Path $d "input"),
        "--tasks-file", (Join-Path $d "tasks.md"),
        "--project-root", $d,
        "--out", (Join-Path $d "out.txt")
    )

    if ($script:PP_Exit -ne 0) {
        ok "TEST-037a: symlink escape under --input -> nonzero exit"
    } else {
        fail "TEST-037a: expected nonzero exit, got 0. Output: $($script:PP_Output)"
    }
    if (-not [regex]::Match($script:PP_Output, '[0-9a-f]{64}').Success) {
        ok "TEST-037b: no digest line printed"
    } else {
        fail "TEST-037b: digest must not print. Output: $($script:PP_Output)"
    }
    if ($script:PP_Output -notmatch [regex]::Escape($sentinel037)) {
        ok "TEST-037c: sentinel content does not appear in output"
    } else {
        fail "TEST-037c: SENTINEL LEAK via --input symlink escape"
    }
    if (-not (Test-Path (Join-Path $d "out.txt"))) {
        ok "TEST-037d: bundle file not written"
    } else {
        fail "TEST-037d: bundle file must not be written"
    }
}

# ============================================================================
# TEST-038: a row absent under --input but reachable ONLY via a symlinked
# component under --project-root must still be rejected by the fallback's
# OWN containment guard — proves the project-root retry independently
# re-applies the symlink component-walk rather than skipping it.
# ============================================================================

Write-Host "=== TEST-038: symlink-escape under --project-root fallback -> fail closed ==="

$d = Join-Path $Work "pp038"
New-Item -ItemType Directory -Path (Join-Path $d "input") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "outside") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
$sentinel038 = "SENTINEL-TEST038-DO-NOT-LEAK-$PID"
Set-Content -Encoding Utf8 -Path (Join-Path $d "outside/secret.txt") -Value $sentinel038
$hash038 = Get-Sha256OfFile (Join-Path $d "outside/secret.txt")
$symlink038Created = $true
try {
    New-Item -ItemType SymbolicLink -Path (Join-Path $d "linkdir") -Target (Join-Path $d "outside") -ErrorAction Stop | Out-Null
} catch {
    $symlink038Created = $false
}

if (-not $symlink038Created) {
    ok "TEST-038: symlink creation unsupported/unprivileged on this host — skip (runs where symlinks are permitted)"
} else {
    Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
        -Paths @("linkdir/secret.txt") -Hashes @($hash038)

    Invoke-Prepare @(
        "--task", "T-004", "--feature", "cross-model-verification",
        "--input", (Join-Path $d "input"),
        "--tasks-file", (Join-Path $d "tasks.md"),
        "--project-root", $d,
        "--out", (Join-Path $d "out.txt")
    )

    if ($script:PP_Exit -ne 0) {
        ok "TEST-038a: symlink escape under --project-root fallback -> nonzero exit"
    } else {
        fail "TEST-038a: expected nonzero exit, got 0. Output: $($script:PP_Output)"
    }
    if (-not [regex]::Match($script:PP_Output, '[0-9a-f]{64}').Success) {
        ok "TEST-038b: no digest line printed"
    } else {
        fail "TEST-038b: digest must not print. Output: $($script:PP_Output)"
    }
    if ($script:PP_Output -notmatch [regex]::Escape($sentinel038)) {
        ok "TEST-038c: sentinel content does not appear in output"
    } else {
        fail "TEST-038c: SENTINEL LEAK via --project-root symlink escape"
    }
    if (-not (Test-Path (Join-Path $d "out.txt"))) {
        ok "TEST-038d: bundle file not written"
    } else {
        fail "TEST-038d: bundle file must not be written"
    }
}

# ============================================================================
# TEST-039: a project-root-relative row whose worktree content has DRIFTED
# (a later sibling commit edited the shared file after the implementation
# report was written) is re-checked against the tree as of the report's own
# DECLARATION COMMIT -- the commit that last touched the report itself --
# and, verified there, accepted with a distinct, non-silent stderr notice
# naming the row and exit 0 + a printed digest. Models the real defect this
# feature fixes: CHANGELOG.md/tasks.md-shaped shared, living files.
# ============================================================================

Write-Host "=== TEST-039: worktree-drifted row verified at declaration commit ==="

$d = Join-Path $Work "pp039"
New-Item -ItemType Directory -Path (Join-Path $d "input") -Force | Out-Null
New-PpiGitScratchRepo $d
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d "shared.txt") -Value "shared file v1" -NoNewline
$hash039v1 = Get-Sha256OfFile (Join-Path $d "shared.txt")
Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("shared.txt") -Hashes @($hash039v1)
Invoke-PpiGitCommit -Root $d -Message "declare shared.txt v1"

# A later sibling task edits the shared file; the report itself is
# untouched, so its declaration commit is still the commit above.
Set-Content -Encoding Utf8 -Path (Join-Path $d "shared.txt") -Value "shared file v2 (drifted by a sibling task)" -NoNewline
Invoke-PpiGitCommit -Root $d -Message "sibling task drifts shared.txt"

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-039a: drifted-but-verified-at-declaration-commit row -> exit 0"
} else {
    fail "TEST-039a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if ([regex]::Match($script:PP_Output, '[0-9a-f]{64}').Success) {
    ok "TEST-039b: digest printed"
} else {
    fail "TEST-039b: expected a printed digest, got: $($script:PP_Output)"
}
if (($script:PP_Output -match "declared output verified at declaration commit") -and
    ($script:PP_Output -match [regex]::Escape("shared.txt"))) {
    ok "TEST-039c: distinct drift notice printed, naming shared.txt"
} else {
    fail "TEST-039c: expected a declaration-commit drift notice naming shared.txt, got: $($script:PP_Output)"
}

# ============================================================================
# TEST-040: a project-root-relative row whose worktree content still
# matches the declared hash (never drifted) exits 0 and prints NO drift
# notice -- proves the notice does not become background noise on every
# git-backed report, only on rows the fast path actually had to fall back
# past.
# ============================================================================

Write-Host "=== TEST-040: undrifted project-root row -> exit 0, NO drift notice ==="

$d = Join-Path $Work "pp040"
New-Item -ItemType Directory -Path (Join-Path $d "input") -Force | Out-Null
New-PpiGitScratchRepo $d
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d "stable.txt") -Value "stable content" -NoNewline
$hash040 = Get-Sha256OfFile (Join-Path $d "stable.txt")
Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("stable.txt") -Hashes @($hash040)
Invoke-PpiGitCommit -Root $d -Message "declare stable.txt"

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-040a: undrifted row -> exit 0"
} else {
    fail "TEST-040a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if ($script:PP_Output -notmatch "declared output verified at declaration commit") {
    ok "TEST-040b: no drift notice printed for a row that matched the worktree"
} else {
    fail "TEST-040b: drift notice must not print when the worktree already matches. Output: $($script:PP_Output)"
}

# ============================================================================
# TEST-041: a row mismatched at BOTH the worktree AND the declaration
# commit still fails closed with the unchanged "hash mismatch" message --
# proves the declaration-commit fallback does not degenerate into accepting
# anything just because a commit exists.
# ============================================================================

Write-Host "=== TEST-041: row mismatched at both worktree and declaration commit -> fail closed ==="

$d = Join-Path $Work "pp041"
New-Item -ItemType Directory -Path (Join-Path $d "input") -Force | Out-Null
New-PpiGitScratchRepo $d
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d "mismatch.txt") -Value "actual content at report time" -NoNewline
Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("mismatch.txt") -Hashes @((Get-WrongHash))
Invoke-PpiGitCommit -Root $d -Message "declare mismatch.txt with a wrong hash"

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -ne 0) {
    ok "TEST-041a: mismatched at both worktree and declaration commit -> nonzero exit"
} else {
    fail "TEST-041a: expected nonzero exit, got 0. Output: $($script:PP_Output)"
}
if ($script:PP_Output -match [regex]::Escape("declared output hash mismatch: mismatch.txt")) {
    ok "TEST-041b: unchanged 'hash mismatch' message text"
} else {
    fail "TEST-041b: expected unchanged hash-mismatch message, got: $($script:PP_Output)"
}
if ($script:PP_Output -notmatch "declared output verified at declaration commit") {
    ok "TEST-041c: no drift notice printed (declaration commit did not verify either)"
} else {
    fail "TEST-041c: drift notice must not print when the declaration commit also mismatches. Output: $($script:PP_Output)"
}
if (-not (Test-Path (Join-Path $d "out.txt"))) {
    ok "TEST-041d: bundle file not written"
} else {
    fail "TEST-041d: bundle file must not be written"
}

# ============================================================================
# TEST-042: a row absent under both roots, AND absent at the declaration
# commit (a path that was declared but never actually created) still fails
# closed with the unchanged "missing from bundle" message.
# ============================================================================

Write-Host "=== TEST-042: row absent under both roots and at declaration commit -> fail closed ==="

$d = Join-Path $Work "pp042"
New-Item -ItemType Directory -Path (Join-Path $d "input") -Force | Out-Null
New-PpiGitScratchRepo $d
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("never-existed.txt") -Hashes @((Get-WrongHash))
Invoke-PpiGitCommit -Root $d -Message "declare a row for a file that was never created"

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -ne 0) {
    ok "TEST-042a: absent under both roots and at declaration commit -> nonzero exit"
} else {
    fail "TEST-042a: expected nonzero exit, got 0. Output: $($script:PP_Output)"
}
if ($script:PP_Output -match [regex]::Escape("declared output missing from bundle: never-existed.txt")) {
    ok "TEST-042b: unchanged 'missing from bundle' message text"
} else {
    fail "TEST-042b: expected unchanged missing-from-bundle message, got: $($script:PP_Output)"
}
if (-not (Test-Path (Join-Path $d "out.txt"))) {
    ok "TEST-042c: bundle file not written"
} else {
    fail "TEST-042c: bundle file must not be written"
}

# ============================================================================
# TEST-043: the implementation report itself is UNCOMMITTED (added to a git
# repo with other history, but the report file is untracked) -- `git log -1
# -- <report>` finds no commit, so the declaration-commit fallback is inert
# and behaviour is identical to today: unchanged "hash mismatch" gap, no
# invented pass.
# ============================================================================

Write-Host "=== TEST-043: uncommitted implementation report -> declaration-commit fallback inert ==="

$d = Join-Path $Work "pp043"
New-Item -ItemType Directory -Path (Join-Path $d "input") -Force | Out-Null
New-PpiGitScratchRepo $d
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d "unrelated.txt") -Value "unrelated" -NoNewline
Invoke-PpiGitCommit -Root $d -Message "unrelated commit; implementation report not yet committed" -Paths @("unrelated.txt", "tasks.md")

Set-Content -Encoding Utf8 -Path (Join-Path $d "shared.txt") -Value "drifted content" -NoNewline
Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("shared.txt") -Hashes @((Get-WrongHash))
# Deliberately NOT committed -- the report is untracked.

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -ne 0) {
    ok "TEST-043a: uncommitted report -> nonzero exit (no invented pass)"
} else {
    fail "TEST-043a: expected nonzero exit, got 0. Output: $($script:PP_Output)"
}
if ($script:PP_Output -match [regex]::Escape("declared output hash mismatch: shared.txt")) {
    ok "TEST-043b: unchanged 'hash mismatch' message text"
} else {
    fail "TEST-043b: expected unchanged hash-mismatch message, got: $($script:PP_Output)"
}
if ($script:PP_Output -notmatch "declared output verified at declaration commit") {
    ok "TEST-043c: no drift notice printed (report has no declaration commit)"
} else {
    fail "TEST-043c: drift notice must not print without a declaration commit. Output: $($script:PP_Output)"
}

# ============================================================================
# TEST-044: a row that escapes --project-root via a symlinked component is
# STILL rejected even when the git history at the declaration commit would,
# byte-for-byte, verify the same relative path -- proves containment (the
# b3f6d1a9 symlink component-walk guard) gates BEFORE the declaration-
# commit fallback is even attempted, so a symlink escape can never be
# laundered through git history.
# ============================================================================

Write-Host "=== TEST-044: symlink-escape under --project-root not bypassed by declaration-commit fallback ==="

$d = Join-Path $Work "pp044"
New-Item -ItemType Directory -Path (Join-Path $d "input") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "linkdir") -Force | Out-Null
New-PpiGitScratchRepo $d
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
$sentinel044 = "SENTINEL-TEST044-DO-NOT-LEAK-$PID"
Set-Content -Encoding Utf8 -Path (Join-Path $d "linkdir/secret.txt") -Value $sentinel044
$hash044 = Get-Sha256OfFile (Join-Path $d "linkdir/secret.txt")
Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("linkdir/secret.txt") -Hashes @($hash044)
Invoke-PpiGitCommit -Root $d -Message "declare linkdir/secret.txt as a plain file"

# A later change replaces linkdir with a symlink pointing outside the
# project root. The content at the same relative path, at the declaration
# commit above, still hash-matches the original declaration -- the
# adversarial shape this test targets: containment must gate before any
# declaration-commit fallback is attempted, or a symlink escape could be
# laundered through history.
Remove-Item -Recurse -Force (Join-Path $d "linkdir")
New-Item -ItemType Directory -Path (Join-Path $d "outside") -Force | Out-Null
Set-Content -Encoding Utf8 -Path (Join-Path $d "outside/secret.txt") -Value $sentinel044
$symlink044Created = $true
try {
    New-Item -ItemType SymbolicLink -Path (Join-Path $d "linkdir") -Target (Join-Path $d "outside") -ErrorAction Stop | Out-Null
} catch {
    $symlink044Created = $false
}

if (-not $symlink044Created) {
    ok "TEST-044: symlink creation unsupported/unprivileged on this host -- skip (runs where symlinks are permitted)"
} else {
    Invoke-Prepare @(
        "--task", "T-004", "--feature", "cross-model-verification",
        "--input", (Join-Path $d "input"),
        "--tasks-file", (Join-Path $d "tasks.md"),
        "--project-root", $d,
        "--out", (Join-Path $d "out.txt")
    )

    if ($script:PP_Exit -ne 0) {
        ok "TEST-044a: symlink escape -> nonzero exit even though declaration-commit content would match"
    } else {
        fail "TEST-044a: expected nonzero exit, got 0. Output: $($script:PP_Output)"
    }
    if ($script:PP_Output -notmatch "declared output verified at declaration commit") {
        ok "TEST-044b: declaration-commit fallback never attempted (no notice) -- containment gates first"
    } else {
        fail "TEST-044b: declaration-commit fallback must not run past a symlink escape. Output: $($script:PP_Output)"
    }
    if ($script:PP_Output -notmatch [regex]::Escape($sentinel044)) {
        ok "TEST-044c: sentinel content does not appear in output"
    } else {
        fail "TEST-044c: SENTINEL LEAK via declaration-commit fallback bypassing symlink containment"
    }
    if (-not (Test-Path (Join-Path $d "out.txt"))) {
        ok "TEST-044d: bundle file not written"
    } else {
        fail "TEST-044d: bundle file must not be written"
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
