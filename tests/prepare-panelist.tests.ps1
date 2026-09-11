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

# ── TEST-051..055 helpers (per-file elision) ─────────────────────────────────

# Write a deterministic filler file with exactly $Count lines, each of the
# form "<Prefix> line NNNN filler filler filler filler". Used to build
# oversized evidence-log/spec-doc/source-file fixtures with byte counts
# computable independently of the elision code under test.
function Write-FillerLines {
    param([string]$Path, [int]$Count, [string]$Prefix)
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
    $lines = 1..$Count | ForEach-Object { "{0} line {1:D4} filler filler filler filler" -f $Prefix, $_ }
    Set-Content -Encoding Utf8 -Path $Path -Value ($lines -join "`n")
}

# ── TEST-057..062 helpers (contract-declared evidence) ──────────────────────

# Write a minimal <TaskId>.contract.json fixture at
# <SpecDir>/verification/<TaskId>.contract.json. $Checks is an array of
# hashtables, each with Id/Evidence/RedEvidence/GreenEvidence keys (any of
# the latter three may be "" -- a real contract carries mostly-empty
# evidence fields on unrequired/waived checks, which is the norm this
# fixture reproduces). The outer @() around the ForEach-Object pipeline
# forces a JSON array even for a single check (PowerShell would otherwise
# unwrap a one-element pipeline result to a scalar).
function Write-PpiContract {
    param([string]$SpecDir, [string]$TaskId, [object[]]$Checks)
    $verifDir = Join-Path $SpecDir "verification"
    New-Item -ItemType Directory -Path $verifDir -Force | Out-Null
    $contract = [ordered]@{
        task_id = $TaskId
        checks  = @($Checks | ForEach-Object {
            [ordered]@{
                id             = $_.Id
                evidence       = $_.Evidence
                red_evidence   = $_.RedEvidence
                green_evidence = $_.GreenEvidence
            }
        })
    }
    $json = $contract | ConvertTo-Json -Depth 10
    Set-Content -Encoding Utf8 -Path (Join-Path $verifDir "$TaskId.contract.json") -Value $json
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
    # Windows Git defaults core.autocrlf=true, which rewrites CRLF to LF at
    # checkin. Declared-output hashes are taken from working-tree bytes, so a
    # normalized blob can never match them and the stale-vs-fatal
    # classification (Test-DeclaredOutputAtDeclarationCommit) degrades every
    # stale declaration into a fatal mismatch. Pin it off so blobs are
    # byte-identical to the working tree on every platform.
    & git -C $Root config core.autocrlf false
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
# TEST-013 (AC-013, redefined for task-scoped composition): a file under the
# REVIEWED TASK'S OWN specs/<feature>/verification/<task_id>/ directory is
# recursed into and included in the bundle -- independent of the --input
# argument, which the composed bundle no longer walks at all in directory
# mode. A marker planted ONLY under --input (an unrelated directory) must
# NOT appear, proving the whole-directory walk of --input is gone (this is
# also the property the "reintroduce whole-directory walk" mutation trips).
# ============================================================================

Write-Host "=== TEST-013: task's own verification/<task_id>/ recursed; --input directory NOT walked (AC-013) ==="

$d = Join-Path $Work "pp013"
New-Item -ItemType Directory -Path (Join-Path $d "specs/cross-model-verification/verification/T-004/sub") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "other-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d "specs/cross-model-verification/verification/T-004/top.txt") `
    -Value "own-task top-level marker OWNTASKTOPLEVEL013"
Set-Content -Encoding Utf8 -Path (Join-Path $d "specs/cross-model-verification/verification/T-004/sub/evidence.md") `
    -Value "own-task subdirectory marker SUBDIRMARKER013"
Set-Content -Encoding Utf8 -Path (Join-Path $d "other-input/unrelated.txt") `
    -Value "input-only marker INPUTONLYMARKER013"

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "other-input"),
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
    ok "TEST-013b: task's own verification/<task_id>/sub/ content included in bundle (recursion)"
} else {
    fail "TEST-013b: task's own verification subdirectory content missing from bundle — collector did not recurse"
}
if ((Test-Path (Join-Path $d "out.txt")) -and (-not ((Get-Content -Raw (Join-Path $d "out.txt")) -match "INPUTONLYMARKER013"))) {
    ok "TEST-013c: content planted only under --input is NOT in the bundle (no whole-directory walk of --input)"
} else {
    fail "TEST-013c: INPUTONLYMARKER013 leaked into the bundle -- --input directory is still being walked wholesale"
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

# ============================================================================
# TEST-045: cross-task isolation -- a feature with two tasks, each with its
# own verification/<task_id>/ evidence directory. T-001's bundle carries
# T-001's own evidence and NOT T-002's -- the core epic-195 defect (a
# panelist reviewing one task received every OTHER task's evidence too).
# ============================================================================

Write-Host "=== TEST-045: cross-task isolation -- T-001 bundle excludes T-002's evidence ==="

$d = Join-Path $Work "pp045"
New-Item -ItemType Directory -Path (Join-Path $d "specs/cross-model-verification/verification/T-001") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "specs/cross-model-verification/verification/T-002") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-001"
Set-Content -Encoding Utf8 -Path (Join-Path $d "specs/cross-model-verification/verification/T-001/evidence.log") `
    -Value "T-001 own evidence marker T001MARKER045"
Set-Content -Encoding Utf8 -Path (Join-Path $d "specs/cross-model-verification/verification/T-002/evidence.log") `
    -Value "T-002 own evidence marker T002MARKER045"

Invoke-Prepare @(
    "--task", "T-001", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "empty-input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-045a: exit 0"
} else {
    fail "TEST-045a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if ((Test-Path (Join-Path $d "out.txt")) -and ((Get-Content -Raw (Join-Path $d "out.txt")) -match "T001MARKER045")) {
    ok "TEST-045b: T-001's own evidence present in T-001's bundle"
} else {
    fail "TEST-045b: T-001's own evidence missing from its bundle"
}
if ((Test-Path (Join-Path $d "out.txt")) -and (-not ((Get-Content -Raw (Join-Path $d "out.txt")) -match "T002MARKER045"))) {
    ok "TEST-045c: T-002's evidence is NOT in T-001's bundle (cross-task isolation)"
} else {
    fail "TEST-045c: T-002's evidence leaked into T-001's bundle -- cross-task isolation broken"
}

# ============================================================================
# TEST-046: a file named in the reviewed task's Outputs table, living OUTSIDE
# specs/ entirely (a plugin source file -- exactly the shape both epic-195
# panelists said was missing), has its CURRENT content appear in the bundle
# -- not just verified by the completeness check, actually included.
# ============================================================================

Write-Host "=== TEST-046: Outputs-declared source file content appears in bundle ==="

$d = Join-Path $Work "pp046"
New-Item -ItemType Directory -Path (Join-Path $d "specs/cross-model-verification") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "plugins/some-plugin/scripts") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d "plugins/some-plugin/scripts/do-thing.sh") `
    -Value "source file marker SOURCEFILEMARKER046"
$hash046 = Get-Sha256OfFile (Join-Path $d "plugins/some-plugin/scripts/do-thing.sh")
Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("plugins/some-plugin/scripts/do-thing.sh") -Hashes @($hash046)

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "empty-input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-046a: exit 0"
} else {
    fail "TEST-046a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if ((Test-Path (Join-Path $d "out.txt")) -and ((Get-Content -Raw (Join-Path $d "out.txt")) -match "SOURCEFILEMARKER046")) {
    ok "TEST-046b: declared output's current content is in the bundle"
} else {
    fail "TEST-046b: declared output was verified but its content never made it into the bundle"
}

# ============================================================================
# TEST-047: the panel's own artifacts remain excluded under the new
# task-scoped composition -- both as siblings of verification/<task_id>/
# (never read by any composition step) and as a stray file INSIDE
# verification/<task_id>/ (excluded by the same panel-artifact filters the
# old whole-directory walk applied, now scoped to the task's own directory).
# ============================================================================

Write-Host "=== TEST-047: panel's own artifacts excluded from the task-scoped bundle ==="

$d = Join-Path $Work "pp047"
New-Item -ItemType Directory -Path (Join-Path $d "specs/cross-model-verification/verification/T-004") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d "specs/cross-model-verification/verification/T-004/evidence.log") `
    -Value "legit evidence marker LEGITMARKER047"
Set-Content -Encoding Utf8 -Path (Join-Path $d "specs/cross-model-verification/verification/T-004.panelist-anthropic.verdict.json") `
    -Value "SENTINEL VERDICTMARKER047"
Set-Content -Encoding Utf8 -Path (Join-Path $d "specs/cross-model-verification/verification/T-004.panelist-input.txt") `
    -Value "SENTINEL BUNDLEMARKER047"
Set-Content -Encoding Utf8 -Path (Join-Path $d "specs/cross-model-verification/verification/T-004/stray.verdict.json") `
    -Value "SENTINEL NESTEDVERDICTMARKER047"

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "empty-input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-047a: exit 0"
} else {
    fail "TEST-047a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if ((Test-Path (Join-Path $d "out.txt")) -and ((Get-Content -Raw (Join-Path $d "out.txt")) -match "LEGITMARKER047")) {
    ok "TEST-047b: legitimate evidence still included"
} else {
    fail "TEST-047b: legitimate evidence missing from bundle"
}
if ((Test-Path (Join-Path $d "out.txt")) -and
    (-not ((Get-Content -Raw (Join-Path $d "out.txt")) -match "VERDICTMARKER047|BUNDLEMARKER047"))) {
    ok "TEST-047c: sibling panel artifacts (verification/T-004.*) excluded"
} else {
    fail "TEST-047c: a sibling panel artifact leaked into the bundle"
}
if ((Test-Path (Join-Path $d "out.txt")) -and (-not ((Get-Content -Raw (Join-Path $d "out.txt")) -match "NESTEDVERDICTMARKER047"))) {
    ok "TEST-047d: stray panel artifact inside verification/T-004/ excluded"
} else {
    fail "TEST-047d: a panel artifact nested inside the task's own evidence dir leaked into the bundle"
}

# ============================================================================
# TEST-048: the feature's spec documents (requirements/design/acceptance-
# tests/tasks/traceability/investigation + layer specs when present) are all
# present in the bundle.
# ============================================================================

Write-Host "=== TEST-048: spec documents all present in the bundle ==="

$d = Join-Path $Work "pp048"
$specDir048 = Join-Path $d "specs/cross-model-verification"
New-Item -ItemType Directory -Path (Join-Path $specDir048 "verification/T-004") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $specDir048 "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $specDir048 "requirements.md")    -Value "REQMARKER048"
Set-Content -Encoding Utf8 -Path (Join-Path $specDir048 "design.md")         -Value "DESIGNMARKER048"
Set-Content -Encoding Utf8 -Path (Join-Path $specDir048 "acceptance-tests.md") -Value "ACMARKER048"
Set-Content -Encoding Utf8 -Path (Join-Path $specDir048 "traceability.md")   -Value "TRACEMARKER048"
Set-Content -Encoding Utf8 -Path (Join-Path $specDir048 "investigation.md") -Value "INVESTMARKER048"
Set-Content -Encoding Utf8 -Path (Join-Path $specDir048 "ux-spec.md")       -Value "UXMARKER048"

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "empty-input"),
    "--tasks-file", (Join-Path $specDir048 "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-048a: exit 0"
} else {
    fail "TEST-048a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if (Test-Path (Join-Path $d "out.txt")) {
    $bundleText048 = Get-Content -Raw (Join-Path $d "out.txt")
    $missing048 = @()
    foreach ($marker048 in @("REQMARKER048", "DESIGNMARKER048", "ACMARKER048", "TRACEMARKER048",
            "INVESTMARKER048", "UXMARKER048")) {
        if ($bundleText048 -notmatch $marker048) { $missing048 += $marker048 }
    }
    if ($missing048.Count -eq 0) {
        ok "TEST-048b: every spec document is present in the bundle"
    } else {
        fail "TEST-048b: missing spec document markers: $($missing048 -join ', ')"
    }
    if ($bundleText048 -match "Cross-Model: enabled") {
        ok "TEST-048c: tasks.md itself is present in the bundle"
    } else {
        fail "TEST-048c: tasks.md content missing from the bundle"
    }
} else {
    fail "TEST-048b/c: bundle file not written"
}

# ============================================================================
# TEST-049 (size guard, fail-closed branch): --max-bytes set below the
# sanitized bundle's actual size -> refuses to write a silently-truncated
# bundle, exits nonzero, announces the overage on stderr, prints no digest.
# ============================================================================

Write-Host "=== TEST-049: --max-bytes exceeded -> fail closed, no truncated bundle written ==="

$d = Join-Path $Work "pp049"
$specDir049 = Join-Path $d "specs/cross-model-verification"
New-Item -ItemType Directory -Path $specDir049 -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $specDir049 "tasks.md") -TaskId "T-004"
$lines049 = 1..50 | ForEach-Object { "requirements line $_ filler content filler content filler" }
Set-Content -Encoding Utf8 -Path (Join-Path $specDir049 "requirements.md") -Value ($lines049 -join "`n")

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "empty-input"),
    "--tasks-file", (Join-Path $specDir049 "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt"),
    "--max-bytes", "200"
)

if ($script:PP_Exit -ne 0) {
    ok "TEST-049a: over --max-bytes -> nonzero exit"
} else {
    fail "TEST-049a: expected nonzero exit, got 0. Output: $($script:PP_Output)"
}
if ($script:PP_Output -match "(?i)max-bytes") {
    ok "TEST-049b: overage announced on stderr (mentions --max-bytes)"
} else {
    fail "TEST-049b: expected an announcement mentioning --max-bytes, got: $($script:PP_Output)"
}
if (-not (Test-Path (Join-Path $d "out.txt"))) {
    ok "TEST-049c: bundle file NOT written (fail closed, never truncated)"
} else {
    fail "TEST-049c: bundle file must not be written when --max-bytes is exceeded"
}
if ($script:PP_Output -notmatch "^[0-9a-f]{64}$") {
    ok "TEST-049d: no digest line printed on a size-guard failure"
} else {
    fail "TEST-049d: digest must not print when the size guard fails. Output: $($script:PP_Output)"
}

# ============================================================================
# TEST-050 (size guard, pass-through branch): --max-bytes set generously
# above the bundle's actual size -> the guard does not interfere with an
# otherwise-successful run.
# ============================================================================

Write-Host "=== TEST-050: --max-bytes generous -> guard does not block a normal bundle ==="

$d = Join-Path $Work "pp050"
$specDir050 = Join-Path $d "specs/cross-model-verification"
New-Item -ItemType Directory -Path $specDir050 -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $specDir050 "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $specDir050 "requirements.md") -Value "REQMARKER050"

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "empty-input"),
    "--tasks-file", (Join-Path $specDir050 "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt"),
    "--max-bytes", "1048576"
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-050a: exit 0 under a generous --max-bytes"
} else {
    fail "TEST-050a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if ((Test-Path (Join-Path $d "out.txt")) -and ((Get-Content -Raw (Join-Path $d "out.txt")) -match "REQMARKER050")) {
    ok "TEST-050b: bundle written normally with content intact"
} else {
    fail "TEST-050b: bundle missing or content lost under a generous --max-bytes"
}
if ($script:PP_Output -match "^[0-9a-f]{64}$") {
    ok "TEST-050c: digest printed normally"
} else {
    fail "TEST-050c: expected a printed digest, got: $($script:PP_Output)"
}


# ============================================================================
# TEST-051: a bundle that fits --max-bytes whole is written whole -- no
# elision marker anywhere, even though a single verification-dir file is
# large in absolute terms. Budget-driven elision only activates when the
# composed-and-measured bundle is actually over cap; file size alone is
# never sufficient to trigger it.
# ============================================================================

Write-Host "=== TEST-051: bundle under --max-bytes stays whole, regardless of one file's absolute size ==="

$d = Join-Path $Work "pp051"
$specDir051 = Join-Path $d "specs/cross-model-verification"
New-Item -ItemType Directory -Path (Join-Path $specDir051 "verification/T-004") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $specDir051 "tasks.md") -TaskId "T-004"
Write-FillerLines -Path (Join-Path $specDir051 "verification/T-004/big.log") -Count 500 -Prefix "LOG051"

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "empty-input"),
    "--tasks-file", (Join-Path $specDir051 "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt"),
    "--max-bytes", "1000000"
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-051a: exit 0"
} else {
    fail "TEST-051a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if (Test-Path (Join-Path $d "out.txt")) {
    $bundleText051 = Get-Content -Raw (Join-Path $d "out.txt")
    if ($bundleText051.Contains("LOG051 line 0001 filler filler filler filler") -and
        $bundleText051.Contains("LOG051 line 0500 filler filler filler filler") -and
        $bundleText051.Contains("LOG051 line 0250 filler filler filler filler")) {
        ok "TEST-051b: the file is present whole (first, middle, and last lines all intact)"
    } else {
        fail "TEST-051b: a file was elided even though the whole bundle already fit --max-bytes"
    }
    if (-not ($bundleText051 -match "(?i)elided from the middle")) {
        ok "TEST-051c: no elision marker anywhere in a bundle that never needed one"
    } else {
        fail "TEST-051c: an elision marker appeared even though the bundle already fit --max-bytes"
    }
} else {
    fail "TEST-051b/c: bundle file not written"
}

# ============================================================================
# TEST-052/053: a bundle over --max-bytes elides the LARGEST elidable file
# first and stops as soon as it fits -- the marker is present on that file
# with the exact byte count independently computed from its own bytes, the
# elided bundle still carries that file's own first and last lines while
# genuinely dropping a middle-only line, and a SMALLER elidable file in the
# same bundle that was never the reason for the overage is left completely
# untouched (no marker, every one of its own lines present).
# ============================================================================

Write-Host "=== TEST-052/053: over-cap bundle elides the largest file only, leaves a smaller one whole ==="

$d = Join-Path $Work "pp052"
$specDir052 = Join-Path $d "specs/cross-model-verification"
New-Item -ItemType Directory -Path (Join-Path $specDir052 "verification/T-004") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $specDir052 "tasks.md") -TaskId "T-004"
$big052 = Join-Path $specDir052 "verification/T-004/big.log"
$small052 = Join-Path $specDir052 "verification/T-004/small.log"
Write-FillerLines -Path $big052 -Count 500 -Prefix "BIG052"
Write-FillerLines -Path $small052 -Count 20 -Prefix "SMALL052"

$total052 = [System.Text.Encoding]::UTF8.GetByteCount((Get-Content -Raw -Encoding Utf8 -LiteralPath $big052))
$lines052 = Get-Content -Encoding Utf8 -LiteralPath $big052
$headText052 = ($lines052[0..39] -join "`n")
$tailText052 = ($lines052[($lines052.Count - 40)..($lines052.Count - 1)] -join "`n")
$headBytes052 = [System.Text.Encoding]::UTF8.GetByteCount($headText052)
$tailBytes052 = [System.Text.Encoding]::UTF8.GetByteCount($tailText052)
$expectedElided052 = $total052 - $headBytes052 - $tailBytes052
# --max-bytes 15000 sits strictly between (a) the whole bundle's real size
# (big.log 22,500B + small.log 940B + overhead, ~23,900B -- confirmed over
# cap) and (b) that same bundle with ONLY big.log elided (~5,150B -- under
# cap) -- so eliding big.log alone must be enough; small.log should never
# be touched.

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "empty-input"),
    "--tasks-file", (Join-Path $specDir052 "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt"),
    "--max-bytes", "15000"
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-052a: exit 0 (eliding the largest file alone let the bundle fit)"
} else {
    fail "TEST-052a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
$expectedMarker052 = "$expectedElided052 bytes elided from the middle of specs/cross-model-verification/verification/T-004/big.log (original size $total052 bytes"
if (Test-Path (Join-Path $d "out.txt")) {
    $bundleText052 = Get-Content -Raw (Join-Path $d "out.txt")
    if ($bundleText052.Contains($expectedMarker052)) {
        ok "TEST-052b: elision marker present on the largest file with the exact independently-computed byte count"
    } else {
        fail "TEST-052b: expected marker containing '$expectedMarker052' not found in bundle"
    }
    $markerCount052 = ([regex]::Matches($bundleText052, "elided from the middle")).Count
    if ($markerCount052 -eq 1) {
        ok "TEST-052c: exactly one elision marker -- the smaller file was never a candidate that needed cutting"
    } else {
        fail "TEST-052c: expected exactly one elision marker (largest file only), found $markerCount052"
    }
    if ($bundleText052.Contains("BIG052 line 0001 filler filler filler filler")) {
        ok "TEST-053a: elided bundle still contains the largest file's first line"
    } else {
        fail "TEST-053a: largest file's first line missing from the elided bundle"
    }
    if ($bundleText052.Contains("BIG052 line 0500 filler filler filler filler")) {
        ok "TEST-053b: elided bundle still contains the largest file's last line"
    } else {
        fail "TEST-053b: largest file's last line missing from the elided bundle"
    }
    if (-not $bundleText052.Contains("BIG052 line 0250 filler filler filler filler")) {
        ok "TEST-053c: a middle-only line of the largest file is genuinely dropped"
    } else {
        fail "TEST-053c: a middle line of the largest file survived -- elision did not actually remove the middle"
    }
    $missingSmall052 = @()
    foreach ($line052 in @("0001", "0010", "0020")) {
        if (-not $bundleText052.Contains("SMALL052 line $line052 filler filler filler filler")) { $missingSmall052 += $line052 }
    }
    if ($missingSmall052.Count -eq 0) {
        ok "TEST-053d: the smaller file is left completely whole (it was never the file that needed cutting)"
    } else {
        fail "TEST-053d: the smaller file lost line(s): $($missingSmall052 -join ', ') -- it should never have been elided"
    }
} else {
    fail "TEST-052b/TEST-053: bundle file not written"
}

# ============================================================================
# TEST-054: elision is scoped to the task's own verification/<task_id>/
# evidence directory only -- a spec document (step 1) and an Outputs-
# declared source file living outside specs/ (step 5) are never elided,
# however large, because truncating either would gut the bundle's own
# claims or their supporting source rather than trim incidental log noise.
# ============================================================================

Write-Host "=== TEST-054: spec documents and Outputs-declared source files are never elided ==="

$d = Join-Path $Work "pp054"
$specDir054 = Join-Path $d "specs/cross-model-verification"
New-Item -ItemType Directory -Path (Join-Path $specDir054 "verification/T-004") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "plugins/some-plugin/scripts") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $specDir054 "tasks.md") -TaskId "T-004"
# Both fixture files (~63,000 bytes each) are deliberately sized ABOVE the
# 50,000-byte per-file elision threshold (--max-bytes 200000 / 4) -- proving
# these call sites stay whole because they are scoped out, not merely
# because they never crossed the threshold in the first place.
Write-FillerLines -Path (Join-Path $specDir054 "requirements.md") -Count 1400 -Prefix "REQ054"
Write-FillerLines -Path (Join-Path $d "plugins/some-plugin/scripts/big-thing.sh") -Count 1400 -Prefix "SRC054"
$hash054 = Get-Sha256OfFile (Join-Path $d "plugins/some-plugin/scripts/big-thing.sh")
Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("plugins/some-plugin/scripts/big-thing.sh") -Hashes @($hash054)

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "empty-input"),
    "--tasks-file", (Join-Path $specDir054 "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt"),
    "--max-bytes", "200000"
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-054a: exit 0"
} else {
    fail "TEST-054a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if (Test-Path (Join-Path $d "out.txt")) {
    $bundleText054 = Get-Content -Raw (Join-Path $d "out.txt")
    if ($bundleText054.Contains("REQ054 line 0001 filler filler filler filler") -and
        $bundleText054.Contains("REQ054 line 1400 filler filler filler filler") -and
        $bundleText054.Contains("REQ054 line 0700 filler filler filler filler")) {
        ok "TEST-054b: spec document (requirements.md) present whole, including a middle line"
    } else {
        fail "TEST-054b: requirements.md was elided even though it exceeds the per-file threshold"
    }
    if ($bundleText054.Contains("SRC054 line 0001 filler filler filler filler") -and
        $bundleText054.Contains("SRC054 line 1400 filler filler filler filler") -and
        $bundleText054.Contains("SRC054 line 0700 filler filler filler filler")) {
        ok "TEST-054c: Outputs-declared source file present whole, including a middle line"
    } else {
        fail "TEST-054c: the declared-output source file was elided even though it exceeds the per-file threshold"
    }
    if (-not ($bundleText054 -match "(?i)elided from the middle")) {
        ok "TEST-054d: no elision marker anywhere in a bundle whose only oversized files are scoped out"
    } else {
        fail "TEST-054d: an elision marker leaked into a bundle whose oversized files should never be elided"
    }
} else {
    fail "TEST-054b/c/d: bundle file not written"
}

# ============================================================================
# TEST-055: eliding every elidable candidate to its own head/tail/marker
# floor does not guarantee the whole bundle now fits (the degenerate case
# named in the task brief) -- when it still does not, the --max-bytes
# guard still fails closed exactly as TEST-049, never silently shipping a
# bundle that even full elision could not bring under the cap.
# ============================================================================

Write-Host "=== TEST-055: still over --max-bytes after exhausting every elidable candidate -> fail closed ==="

$d = Join-Path $Work "pp055"
$specDir055 = Join-Path $d "specs/cross-model-verification"
New-Item -ItemType Directory -Path (Join-Path $specDir055 "verification/T-004") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $specDir055 "tasks.md") -TaskId "T-004"
Write-FillerLines -Path (Join-Path $specDir055 "verification/T-004/run-all-sh.log") -Count 500 -Prefix "LOG055"

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "empty-input"),
    "--tasks-file", (Join-Path $specDir055 "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt"),
    "--max-bytes", "2000"
)

if ($script:PP_Exit -ne 0) {
    ok "TEST-055a: over --max-bytes even after exhausting the elidable set -> nonzero exit"
} else {
    fail "TEST-055a: expected nonzero exit, got 0. Output: $($script:PP_Output)"
}
if ($script:PP_Output -match "(?i)max-bytes") {
    ok "TEST-055b: overage announced on stderr (mentions --max-bytes)"
} else {
    fail "TEST-055b: expected an announcement mentioning --max-bytes, got: $($script:PP_Output)"
}
if (-not (Test-Path (Join-Path $d "out.txt"))) {
    ok "TEST-055c: bundle file NOT written (fail closed, elision is not a truncation loophole)"
} else {
    fail "TEST-055c: bundle file must not be written when still over --max-bytes after elision"
}
if ($script:PP_Output -notmatch "^[0-9a-f]{64}$") {
    ok "TEST-055d: no digest line printed on a size-guard failure"
} else {
    fail "TEST-055d: digest must not print when the size guard fails. Output: $($script:PP_Output)"
}

# ============================================================================
# TEST-056: the SAME over-cap bundle (TEST-052/053's own fixture) comes
# back byte-for-byte whole under a larger --max-bytes -- elision is a
# property of whether the bundle needs it under the cap actually supplied,
# never a property baked into a file for being "big enough" in isolation.
# ============================================================================

Write-Host "=== TEST-056: same bundle, larger --max-bytes -> comes back whole ==="

$d = Join-Path $Work "pp056"
$specDir056 = Join-Path $d "specs/cross-model-verification"
New-Item -ItemType Directory -Path (Join-Path $specDir056 "verification/T-004") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $specDir056 "tasks.md") -TaskId "T-004"
Write-FillerLines -Path (Join-Path $specDir056 "verification/T-004/big.log") -Count 500 -Prefix "BIG056"
Write-FillerLines -Path (Join-Path $specDir056 "verification/T-004/small.log") -Count 20 -Prefix "SMALL056"

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "empty-input"),
    "--tasks-file", (Join-Path $specDir056 "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt"),
    "--max-bytes", "1000000"
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-056a: exit 0 under a generous --max-bytes"
} else {
    fail "TEST-056a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if (Test-Path (Join-Path $d "out.txt")) {
    $bundleText056 = Get-Content -Raw (Join-Path $d "out.txt")
    if (-not ($bundleText056 -match "(?i)elided from the middle")) {
        ok "TEST-056b: no elision marker anywhere once the bundle fits without cutting anything"
    } else {
        fail "TEST-056b: an elision marker survived into a bundle that fits --max-bytes whole"
    }
    if ($bundleText056.Contains("BIG056 line 0250 filler filler filler filler")) {
        ok "TEST-056c: the larger file's middle line is present -- the same file TEST-052/053 elides at a tighter cap comes back whole here"
    } else {
        fail "TEST-056c: the larger file's middle line is missing even though this bundle fits whole"
    }
} else {
    fail "TEST-056b/c: bundle file not written"
}

# ============================================================================
# TEST-057: a check's "evidence" field naming a path OUTSIDE the reviewed
# task's own verification/<task_id>/ directory (e.g. a shared
# verification/qg/shared/ log, the epic-194 T-001 real-world shape) has its
# CURRENT content included in the bundle -- not just verified to exist, its
# bytes actually appear, closing the gap where a panelist was handed a
# check's passes:false claim with no way to read what it pointed at.
# ============================================================================

Write-Host "=== TEST-057: contract-declared evidence outside verification/<task_id>/ appears in bundle ==="

$d = Join-Path $Work "pp057"
$specDir057 = Join-Path $d "specs/cross-model-verification"
New-Item -ItemType Directory -Path (Join-Path $specDir057 "verification/T-004") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $specDir057 "verification/qg/shared") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $specDir057 "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $specDir057 "verification/qg/shared/regression-057.log") -Value "REGRESSIONMARKER057"
Write-PpiContract -SpecDir $specDir057 -TaskId "T-004" -Checks @(
    @{Id = "regression"; Evidence = "specs/cross-model-verification/verification/qg/shared/regression-057.log"; RedEvidence = ""; GreenEvidence = "" }
)

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "empty-input"),
    "--tasks-file", (Join-Path $specDir057 "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-057a: exit 0"
} else {
    fail "TEST-057a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if (Test-Path (Join-Path $d "out.txt")) {
    $bundleText057 = Get-Content -Raw (Join-Path $d "out.txt")
    if ($bundleText057.Contains("REGRESSIONMARKER057")) {
        ok "TEST-057b: contract-declared evidence content is in the bundle"
    } else {
        fail "TEST-057b: shared verification/qg/ evidence named by the contract never made it into the bundle"
    }
    if ($bundleText057.Contains("# ---- specs/cross-model-verification/verification/qg/shared/regression-057.log ----")) {
        ok "TEST-057c: the path header names the file, so a reviewer can tell which evidence it is"
    } else {
        fail "TEST-057c: expected path header missing"
    }
} else {
    fail "TEST-057b/c: bundle file not written"
}

# ============================================================================
# TEST-058: red_evidence and green_evidence are picked up, not just evidence
# -- a TDD check's contract routinely leaves "evidence" pointing at the same
# thing as "green_evidence" but a check could, in principle, carry only a
# red/green pair; both fields must independently contribute their own path.
# ============================================================================

Write-Host "=== TEST-058: red_evidence and green_evidence are also picked up ==="

$d = Join-Path $Work "pp058"
$specDir058 = Join-Path $d "specs/cross-model-verification"
New-Item -ItemType Directory -Path (Join-Path $specDir058 "verification/T-004") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $specDir058 "verification/qg/shared") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $specDir058 "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $specDir058 "verification/qg/shared/red-058.log") -Value "REDMARKER058"
Set-Content -Encoding Utf8 -Path (Join-Path $specDir058 "verification/qg/shared/green-058.log") -Value "GREENMARKER058"
Write-PpiContract -SpecDir $specDir058 -TaskId "T-004" -Checks @(
    @{Id = "unit-tests"; Evidence = ""; RedEvidence = "specs/cross-model-verification/verification/qg/shared/red-058.log"; GreenEvidence = "specs/cross-model-verification/verification/qg/shared/green-058.log" }
)

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "empty-input"),
    "--tasks-file", (Join-Path $specDir058 "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-058a: exit 0"
} else {
    fail "TEST-058a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if (Test-Path (Join-Path $d "out.txt")) {
    $bundleText058 = Get-Content -Raw (Join-Path $d "out.txt")
    if ($bundleText058.Contains("REDMARKER058")) {
        ok "TEST-058b: red_evidence content is in the bundle"
    } else {
        fail "TEST-058b: red_evidence-declared file never made it into the bundle"
    }
    if ($bundleText058.Contains("GREENMARKER058")) {
        ok "TEST-058c: green_evidence content is in the bundle"
    } else {
        fail "TEST-058c: green_evidence-declared file never made it into the bundle"
    }
} else {
    fail "TEST-058b/c: bundle file not written"
}

# ============================================================================
# TEST-059: dedup -- a contract-declared path already pulled in by the
# reviewed task's own verification/<task_id>/ directory walk (059b), or
# already pulled in by an Outputs-table row (059c), is included exactly
# ONCE, never a second time for being separately named by the contract.
# ============================================================================

Write-Host "=== TEST-059: contract-declared evidence already included elsewhere is not duplicated ==="

$d = Join-Path $Work "pp059"
$specDir059 = Join-Path $d "specs/cross-model-verification"
New-Item -ItemType Directory -Path (Join-Path $specDir059 "verification/T-004") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "plugins/some-plugin/scripts") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $specDir059 "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $specDir059 "verification/T-004/inband-059.log") -Value "INBANDMARKER059"
Set-Content -Encoding Utf8 -Path (Join-Path $d "plugins/some-plugin/scripts/thing-059.sh") -Value "SRCMARKER059"
$hash059 = Get-Sha256OfFile (Join-Path $d "plugins/some-plugin/scripts/thing-059.sh")
Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("plugins/some-plugin/scripts/thing-059.sh") -Hashes @($hash059)
Write-PpiContract -SpecDir $specDir059 -TaskId "T-004" -Checks @(
    @{Id = "already-in-dir"; Evidence = "specs/cross-model-verification/verification/T-004/inband-059.log"; RedEvidence = ""; GreenEvidence = "" },
    @{Id = "already-in-outputs"; Evidence = "plugins/some-plugin/scripts/thing-059.sh"; RedEvidence = ""; GreenEvidence = "" }
)

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "empty-input"),
    "--tasks-file", (Join-Path $specDir059 "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-059a: exit 0"
} else {
    fail "TEST-059a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if (Test-Path (Join-Path $d "out.txt")) {
    $bundleText059 = Get-Content -Raw (Join-Path $d "out.txt")
    $inbandCount059 = ([regex]::Matches($bundleText059, "INBANDMARKER059")).Count
    if ($inbandCount059 -eq 1) {
        ok "TEST-059b: directory-walk file re-declared by the contract appears exactly once"
    } else {
        fail "TEST-059b: expected exactly one occurrence of INBANDMARKER059, found $inbandCount059"
    }
    $srcCount059 = ([regex]::Matches($bundleText059, "SRCMARKER059")).Count
    if ($srcCount059 -eq 1) {
        ok "TEST-059c: Outputs-declared file re-declared by the contract appears exactly once"
    } else {
        fail "TEST-059c: expected exactly one occurrence of SRCMARKER059, found $srcCount059"
    }
} else {
    fail "TEST-059b/c: bundle file not written"
}

# ============================================================================
# TEST-060: empty evidence/red_evidence/green_evidence fields (the norm --
# most checks in a real contract, e.g. a waived lint/typecheck/build check,
# carry "") produce no bundle output and no error. This is the common case
# every other TEST-057..062 fixture deliberately does NOT exercise on its
# own unrequired checks, so it earns a dedicated assertion.
# ============================================================================

Write-Host "=== TEST-060: empty contract evidence fields produce no output and no error ==="

$d = Join-Path $Work "pp060"
$specDir060 = Join-Path $d "specs/cross-model-verification"
New-Item -ItemType Directory -Path (Join-Path $specDir060 "verification/T-004") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $specDir060 "tasks.md") -TaskId "T-004"
Write-PpiContract -SpecDir $specDir060 -TaskId "T-004" -Checks @(
    @{Id = "lint"; Evidence = ""; RedEvidence = ""; GreenEvidence = "" },
    @{Id = "typecheck"; Evidence = ""; RedEvidence = ""; GreenEvidence = "" },
    @{Id = "build"; Evidence = ""; RedEvidence = ""; GreenEvidence = "" }
)

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "empty-input"),
    "--tasks-file", (Join-Path $specDir060 "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-060a: exit 0"
} else {
    fail "TEST-060a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if (Test-Path (Join-Path $d "out.txt")) {
    $bundleText060 = Get-Content -Raw (Join-Path $d "out.txt")
    if (-not ($bundleText060 -match "(?i)contract-declared evidence")) {
        ok "TEST-060b: no contract-declared-evidence section appears when every field is empty"
    } else {
        fail "TEST-060b: a contract-declared-evidence section leaked in for an all-empty-fields contract"
    }
} else {
    fail "TEST-060b: bundle file not written"
}
if ($script:PP_Output -match "^[0-9a-f]{64}$") {
    ok "TEST-060c: normal digest line still printed -- empty fields are not an error"
} else {
    fail "TEST-060c: expected a digest line, got: $($script:PP_Output)"
}

# ============================================================================
# TEST-061: a declared-but-missing contract evidence path is a finding, not
# a crash or a silent omission -- the bundle carries a one-line note naming
# the path and stating no file exists there, and the run still exits 0
# (telling the reviewer a contract points at nothing is true and useful;
# refusing to write the whole bundle over it would throw away every OTHER
# check's real evidence over one dangling reference).
# ============================================================================

Write-Host "=== TEST-061: declared-but-missing contract evidence path -> noted, not silently dropped ==="

$d = Join-Path $Work "pp061"
$specDir061 = Join-Path $d "specs/cross-model-verification"
New-Item -ItemType Directory -Path (Join-Path $specDir061 "verification/T-004") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $specDir061 "tasks.md") -TaskId "T-004"
Write-PpiContract -SpecDir $specDir061 -TaskId "T-004" -Checks @(
    @{Id = "regression"; Evidence = "specs/cross-model-verification/verification/qg/shared/nope-061.log"; RedEvidence = ""; GreenEvidence = "" }
)

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "empty-input"),
    "--tasks-file", (Join-Path $specDir061 "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-061a: exit 0 (a dangling contract reference does not fail the whole run)"
} else {
    fail "TEST-061a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if (Test-Path (Join-Path $d "out.txt")) {
    $bundleText061 = Get-Content -Raw (Join-Path $d "out.txt")
    if ($bundleText061.Contains("specs/cross-model-verification/verification/qg/shared/nope-061.log (contract-declared evidence, not found)")) {
        ok "TEST-061b: the bundle names the missing path"
    } else {
        fail "TEST-061b: expected a not-found note naming the missing path"
    }
    # Asserts the invariant this test owns -- the gap is explained in plain
    # language rather than silently dropped -- and stops short of the trailing
    # base clause. WFI-059 changes that clause from "there" to
    # "at <project-root>/<path>" via a staged patch, and the strict assertion
    # on the new wording lives in tests/wfi-059-evidence-path-base.tests.ps1,
    # which is designed-red until a human applies it. Pinning the full string
    # here would turn this whole suite red for the duration and hide unrelated
    # regressions in it; the prefix is what TEST-061 was written to protect.
    if ($bundleText061.Contains("[contract names this evidence path but no file exists")) {
        ok "TEST-061c: the note states plainly that no file exists"
    } else {
        fail "TEST-061c: expected a plain-language explanation of the gap"
    }
} else {
    fail "TEST-061b/c: bundle file not written"
}

# ============================================================================
# TEST-062: a large contract-declared evidence file (living OUTSIDE
# verification/<task_id>/, so only reachable via step 3b, not the directory
# walk) is elided under a tight --max-bytes exactly like a directory-walk
# file would be -- proving it joined the SAME elidable candidate set, not a
# separate always-whole one.
# ============================================================================

Write-Host "=== TEST-062: large contract-declared evidence file is elided under a tight --max-bytes ==="

$d = Join-Path $Work "pp062"
$specDir062 = Join-Path $d "specs/cross-model-verification"
New-Item -ItemType Directory -Path (Join-Path $specDir062 "verification/T-004") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $specDir062 "verification/qg/shared") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $specDir062 "tasks.md") -TaskId "T-004"
$big062 = Join-Path $specDir062 "verification/qg/shared/big-062.log"
Write-FillerLines -Path $big062 -Count 500 -Prefix "BIG062"
Write-PpiContract -SpecDir $specDir062 -TaskId "T-004" -Checks @(
    @{Id = "regression"; Evidence = "specs/cross-model-verification/verification/qg/shared/big-062.log"; RedEvidence = ""; GreenEvidence = "" }
)

$total062 = [System.Text.Encoding]::UTF8.GetByteCount((Get-Content -Raw -Encoding Utf8 -LiteralPath $big062))
$lines062 = Get-Content -Encoding Utf8 -LiteralPath $big062
$headText062 = ($lines062[0..39] -join "`n")
$tailText062 = ($lines062[($lines062.Count - 40)..($lines062.Count - 1)] -join "`n")
$headBytes062 = [System.Text.Encoding]::UTF8.GetByteCount($headText062)
$tailBytes062 = [System.Text.Encoding]::UTF8.GetByteCount($tailText062)
$expectedElided062 = $total062 - $headBytes062 - $tailBytes062

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "empty-input"),
    "--tasks-file", (Join-Path $specDir062 "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt"),
    "--max-bytes", "15000"
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-062a: exit 0 (eliding the contract-declared file alone let the bundle fit)"
} else {
    fail "TEST-062a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
$expectedMarker062 = "$expectedElided062 bytes elided from the middle of specs/cross-model-verification/verification/qg/shared/big-062.log (original size $total062 bytes"
if (Test-Path (Join-Path $d "out.txt")) {
    $bundleText062 = Get-Content -Raw (Join-Path $d "out.txt")
    if ($bundleText062.Contains($expectedMarker062)) {
        ok "TEST-062b: elision marker present on the contract-declared file with the exact independently-computed byte count"
    } else {
        fail "TEST-062b: expected marker containing '$expectedMarker062' not found in bundle"
    }
    if ($bundleText062.Contains("BIG062 line 0001 filler filler filler filler") -and
        $bundleText062.Contains("BIG062 line 0500 filler filler filler filler") -and
        (-not $bundleText062.Contains("BIG062 line 0250 filler filler filler filler"))) {
        ok "TEST-062c: elided bundle keeps first/last lines and genuinely drops a middle line"
    } else {
        fail "TEST-062c: elided bundle's head/tail/middle content does not match expectations"
    }
} else {
    fail "TEST-062b/c: bundle file not written"
}

# ============================================================================
# TEST-063/064: a project-root-relative row whose worktree content has
# DRIFTED (same shape as TEST-039) must put the CURRENT worktree bytes into
# the bundle, not the declaration-commit bytes -- and must say so, IN the
# bundle, where a reviewer will actually see it. TEST-039 only proved the
# gate stays open (exit 0 + a stderr-only notice); it never inspected what
# landed in the bundle file itself. This is the defect this change fixes:
# a panelist judging "the code as it stands" was quietly handed weeks-old
# bytes instead.
# ============================================================================

Write-Host "=== TEST-063/064: drifted row serves CURRENT bytes + in-bundle stale notice ==="

$d = Join-Path $Work "pp063"
New-Item -ItemType Directory -Path (Join-Path $d "input") -Force | Out-Null
New-PpiGitScratchRepo $d
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d "shared.txt") -Value "MARKER_V1_ONLY shared content" -NoNewline
$hash063v1 = Get-Sha256OfFile (Join-Path $d "shared.txt")
Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("shared.txt") -Hashes @($hash063v1)
Invoke-PpiGitCommit -Root $d -Message "declare shared.txt v1"

# A later sibling task drifts the shared file; the report's declared hash
# (v1) is now stale relative to the worktree (v2).
Set-Content -Encoding Utf8 -Path (Join-Path $d "shared.txt") -Value "MARKER_V2_ONLY shared content (drifted)" -NoNewline
Invoke-PpiGitCommit -Root $d -Message "sibling task drifts shared.txt"

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-063a: drifted row still exits 0"
} else {
    fail "TEST-063a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if (Test-Path (Join-Path $d "out.txt")) {
    $bundleText063 = Get-Content -Raw (Join-Path $d "out.txt")
} else {
    $bundleText063 = ""
}
if ($bundleText063.Contains("MARKER_V2_ONLY")) {
    ok "TEST-063b: bundle carries the CURRENT worktree bytes (v2 marker present)"
} else {
    fail "TEST-063b: expected v2 (current worktree) content in the bundle, not found"
}
if (-not $bundleText063.Contains("MARKER_V1_ONLY")) {
    ok "TEST-063c: bundle does NOT carry the declaration-commit (historical) bytes"
} else {
    fail "TEST-063c: found declaration-commit (v1) content in the bundle -- historical bytes leaked into review material"
}
if ($bundleText063.Contains("shared.txt (declared output") -and
    $bundleText063.Contains("implementation report's declared hash for this path is STALE")) {
    ok "TEST-064a: in-bundle notice names shared.txt and states the report's declared hash is stale (found in the bundle FILE, not only stderr)"
} else {
    fail "TEST-064a: expected an in-bundle stale-declaration notice naming shared.txt"
}

# ============================================================================
# TEST-065: a project-root-relative row whose worktree content still
# matches the declared hash produces NO stale-declaration notice anywhere
# in the bundle -- proves the notice is conditioned on an actual mismatch,
# not printed unconditionally on every declared-outputs row.
# ============================================================================

Write-Host "=== TEST-065: undrifted row -> bundle carries content, NO stale notice ==="

$d = Join-Path $Work "pp065"
New-Item -ItemType Directory -Path (Join-Path $d "input") -Force | Out-Null
New-PpiGitScratchRepo $d
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d "stable.txt") -Value "MARKER_STABLE_065 stable content" -NoNewline
$hash065 = Get-Sha256OfFile (Join-Path $d "stable.txt")
Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("stable.txt") -Hashes @($hash065)
Invoke-PpiGitCommit -Root $d -Message "declare stable.txt"

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if (Test-Path (Join-Path $d "out.txt")) {
    $bundleText065 = Get-Content -Raw (Join-Path $d "out.txt")
} else {
    $bundleText065 = ""
}
if ($bundleText065.Contains("MARKER_STABLE_065")) {
    ok "TEST-065a: matching-hash row still carries its content"
} else {
    fail "TEST-065a: expected stable.txt content in the bundle"
}
if (-not $bundleText065.Contains("is STALE")) {
    ok "TEST-065b: no stale-declaration notice for a row whose hash already matched"
} else {
    fail "TEST-065b: a stale notice must not appear when the worktree hash matched directly. Output: $bundleText065"
}

# ============================================================================
# TEST-066: a declared row that no longer exists anywhere in the worktree
# (deleted by a later commit) but DID exist with a matching hash at the
# report's own declaration commit. There is no current content to serve --
# silently falling back to the declaration-commit blob here would be the
# exact defect this change fixes, one case further: a reviewer handed a
# file that has been REMOVED, presented as if it still existed. The chosen
# behavior is to serve no content and say so plainly in the bundle, while
# leaving the completeness gate itself unchanged (still exit 0 -- the
# declaration was true when written).
# ============================================================================

Write-Host "=== TEST-066: declared row deleted from worktree -> notice only, no historical content ==="

$d = Join-Path $Work "pp066"
New-Item -ItemType Directory -Path (Join-Path $d "input") -Force | Out-Null
New-PpiGitScratchRepo $d
Write-TasksWithConsent -Path (Join-Path $d "tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d "deleted.txt") -Value "MARKER_DELETED_066 content that will vanish" -NoNewline
$hash066 = Get-Sha256OfFile (Join-Path $d "deleted.txt")
Write-ImplReport -ProjectRoot $d -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("deleted.txt") -Hashes @($hash066)
Invoke-PpiGitCommit -Root $d -Message "declare deleted.txt"

Remove-Item -LiteralPath (Join-Path $d "deleted.txt") -Force
Invoke-PpiGitCommit -Root $d -Message "sibling task deletes deleted.txt"

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d "input"),
    "--tasks-file", (Join-Path $d "tasks.md"),
    "--project-root", $d,
    "--out", (Join-Path $d "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-066a: row deleted from the worktree but true at declaration commit -> gate unchanged, exit 0"
} else {
    fail "TEST-066a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
if (Test-Path (Join-Path $d "out.txt")) {
    $bundleText066 = Get-Content -Raw (Join-Path $d "out.txt")
} else {
    $bundleText066 = ""
}
if (-not $bundleText066.Contains("MARKER_DELETED_066")) {
    ok "TEST-066b: bundle does NOT carry the deleted file's historical bytes"
} else {
    fail "TEST-066b: deleted file's historical content leaked into the bundle"
}
if ($bundleText066.Contains("deleted.txt (declared output") -and
    $bundleText066.Contains("MISSING from the worktree") -and
    $bundleText066.Contains("STALE")) {
    ok "TEST-066c: bundle names deleted.txt and states its declaration is stale/missing"
} else {
    fail "TEST-066c: expected an in-bundle missing/stale notice naming deleted.txt"
}

# ============================================================================
# TEST-067/068/069/070: "## Outputs" row parsing. A panelist reviewing
# epic-193 T-004 found that a declared row carrying a trailing human
# annotation after its hash cell vanished from the bundle with no notice --
# and when that annotation itself named a commit in its own backtick pair
# (a real, unremarkable shape: "extended by `82f6dbf2` after this task's
# own commit"), the row's total backtick count changed too, so the old
# regex's "\| `hash` \|$" end-anchor rejected it outright. Both variants
# are exercised here, plus the "never silent" requirement this repository
# already applies to every other declared-outputs gap: a line that begins
# like a data row but fails to parse must fail the build naming the exact
# line, not vanish, and a table of ordinary plain rows must behave exactly
# as it always has.
# ============================================================================

Write-Host "=== TEST-067: annotated row (no embedded backticks) is parsed and its content included ==="

$d067 = Join-Path $Work "pp067"
New-Item -ItemType Directory -Path (Join-Path $d067 "input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d067 "specs/cross-model-verification/tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d067 "bar.txt") -Value "MARKER_067 plain annotation content" -NoNewline
$hash067 = Get-Sha256OfFile (Join-Path $d067 "bar.txt")
$reportPath067 = Join-Path $d067 "reports/implementation/cross-model-verification/T-004.md"
New-Item -ItemType Directory -Path (Split-Path $reportPath067) -Force | Out-Null
$lines067 = @(
    "# Implementation Report: T-004", "", "## Outputs", "",
    "| Path | SHA-256 |", "|---|---|",
    "| ${BT}bar.txt${BT} | ${BT}$hash067${BT} (drifted — shared file, see note above) |",
    "", "## Test Evidence", "", "N/A (fixture)."
)
Set-Content -Encoding Utf8 -Path $reportPath067 -Value ($lines067 -join "`n")

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d067 "input"),
    "--tasks-file", (Join-Path $d067 "specs/cross-model-verification/tasks.md"),
    "--project-root", $d067,
    "--out", (Join-Path $d067 "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-067a: exit 0"
} else {
    fail "TEST-067a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
$bundleText067 = if (Test-Path (Join-Path $d067 "out.txt")) { Get-Content -Raw (Join-Path $d067 "out.txt") } else { "" }
if ($bundleText067.Contains("MARKER_067")) {
    ok "TEST-067b: annotated row's content made it into the bundle"
} else {
    fail "TEST-067b: expected bar.txt's content in the bundle, not found. Output: $($script:PP_Output)"
}

Write-Host "=== TEST-068: annotated row whose annotation embeds its own backtick-quoted commit hash is parsed and its content included ==="

$d068 = Join-Path $Work "pp068"
New-Item -ItemType Directory -Path (Join-Path $d068 "input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d068 "specs/cross-model-verification/tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d068 "foo.py") -Value "MARKER_068 content behind an embedded-backtick annotation" -NoNewline
$hash068 = Get-Sha256OfFile (Join-Path $d068 "foo.py")
$reportPath068 = Join-Path $d068 "reports/implementation/cross-model-verification/T-004.md"
New-Item -ItemType Directory -Path (Split-Path $reportPath068) -Force | Out-Null
$lines068 = @(
    "# Implementation Report: T-004", "", "## Outputs", "",
    "| Path | SHA-256 |", "|---|---|",
    "| ${BT}foo.py${BT} | ${BT}$hash068${BT} (drifted — extended by ${BT}82f6dbf2${BT} after this task's own commit, see note above) |",
    "", "## Test Evidence", "", "N/A (fixture)."
)
Set-Content -Encoding Utf8 -Path $reportPath068 -Value ($lines068 -join "`n")

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d068 "input"),
    "--tasks-file", (Join-Path $d068 "specs/cross-model-verification/tasks.md"),
    "--project-root", $d068,
    "--out", (Join-Path $d068 "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-068a: exit 0 (real epic-193 T-004 row shape: an embedded backtick pair inside the annotation)"
} else {
    fail "TEST-068a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
$bundleText068 = if (Test-Path (Join-Path $d068 "out.txt")) { Get-Content -Raw (Join-Path $d068 "out.txt") } else { "" }
if ($bundleText068.Contains("MARKER_068")) {
    ok "TEST-068b: the row's content made it into the bundle despite the embedded backtick pair"
} else {
    fail "TEST-068b: expected foo.py's content in the bundle, not found -- this is the exact defect a panelist caught on epic-193 T-004. Output: $($script:PP_Output)"
}

Write-Host "=== TEST-069: a candidate row that fails to parse fails the build, naming the exact line ==="

$d069 = Join-Path $Work "pp069"
New-Item -ItemType Directory -Path (Join-Path $d069 "input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d069 "specs/cross-model-verification/tasks.md") -TaskId "T-004"
$reportPath069 = Join-Path $d069 "reports/implementation/cross-model-verification/T-004.md"
New-Item -ItemType Directory -Path (Split-Path $reportPath069) -Force | Out-Null
$lines069 = @(
    "# Implementation Report: T-004", "", "## Outputs", "",
    "| Path | SHA-256 |", "|---|---|",
    "| ${BT}broken-row-no-closing-backtick-for-hash",
    "", "## Test Evidence", "", "N/A (fixture)."
)
Set-Content -Encoding Utf8 -Path $reportPath069 -Value ($lines069 -join "`n")

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d069 "input"),
    "--tasks-file", (Join-Path $d069 "specs/cross-model-verification/tasks.md"),
    "--project-root", $d069,
    "--out", (Join-Path $d069 "out.txt")
)

if ($script:PP_Exit -ne 0) {
    ok "TEST-069a: unparseable candidate row -> nonzero exit"
} else {
    fail "TEST-069a: expected nonzero exit, got 0. Output: $($script:PP_Output)"
}
if (-not (Test-Path (Join-Path $d069 "out.txt"))) {
    ok "TEST-069b: bundle file NOT written -- the row is never silently skipped into an incomplete bundle"
} else {
    fail "TEST-069b: bundle file must not be written when a declared row could not be parsed"
}
if ($script:PP_Output -match "(?i)could not be parsed" -and
    $script:PP_Output.Contains("broken-row-no-closing-backtick-for-hash")) {
    ok "TEST-069c: the failure names the exact offending line, not a generic message"
} else {
    fail "TEST-069c: expected the offending line quoted in the failure. Output: $($script:PP_Output)"
}

Write-Host "=== TEST-070: a table of ordinary plain rows (no annotation) behaves exactly as before ==="

$d070 = Join-Path $Work "pp070"
New-Item -ItemType Directory -Path (Join-Path $d070 "input") -Force | Out-Null
Set-Content -Encoding Utf8 -Path (Join-Path $d070 "a.txt") -Value "MARKER_070_A first plain file" -NoNewline
Set-Content -Encoding Utf8 -Path (Join-Path $d070 "b.txt") -Value "MARKER_070_B second plain file" -NoNewline
$hash070a = Get-Sha256OfFile (Join-Path $d070 "a.txt")
$hash070b = Get-Sha256OfFile (Join-Path $d070 "b.txt")
Write-TasksWithConsent -Path (Join-Path $d070 "tasks.md") -TaskId "T-004"
Write-ImplReport -ProjectRoot $d070 -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("a.txt", "b.txt") -Hashes @($hash070a, $hash070b)

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d070 "input"),
    "--tasks-file", (Join-Path $d070 "tasks.md"),
    "--project-root", $d070,
    "--out", (Join-Path $d070 "out.txt")
)

$bundleText070 = if (Test-Path (Join-Path $d070 "out.txt")) { Get-Content -Raw (Join-Path $d070 "out.txt") } else { "" }
if ($script:PP_Exit -eq 0 -and $bundleText070.Contains("MARKER_070_A") -and $bundleText070.Contains("MARKER_070_B")) {
    ok "TEST-070a: a table of plain (unannotated) rows still resolves both rows into the bundle, unchanged"
} else {
    fail "TEST-070a: plain-row table regressed. Output: $($script:PP_Output)"
}

# ============================================================================
# TEST-071..076: declared-outputs content as a SECOND elision tier, used
# only once the task's own verification/<task_id>/ evidence and
# contract-declared evidence (tier one, unchanged) are already through
# their own budget loop and the bundle is STILL over --max-bytes. Tier two
# exists because a real epic-193 T-003 bundle was 1,063,236 bytes against
# codex's 1,048,576 cap with every tier-one candidate already fully
# elided, and a 263,703-byte whole-repo CHANGELOG.md -- a declared output --
# was a quarter of it. The ordering (tier one exhausted FIRST, tier two
# only as a last resort) is the substance of this change; TEST-074 below
# is the one that actually asserts the order, not merely the outcome.
# ============================================================================

Write-Host "=== TEST-071: a bundle that fits without tier two carries every declared output whole, no marker anywhere ==="

$d071 = Join-Path $Work "pp071"
$specDir071 = Join-Path $d071 "specs/cross-model-verification"
New-Item -ItemType Directory -Path (Join-Path $specDir071 "verification/T-004") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d071 "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $specDir071 "tasks.md") -TaskId "T-004"
Write-FillerLines -Path (Join-Path $specDir071 "verification/T-004/small-evidence.log") -Count 20 -Prefix "EVID071"
Write-FillerLines -Path (Join-Path $d071 "declared-071.txt") -Count 20 -Prefix "DECL071"
$hash071 = Get-Sha256OfFile (Join-Path $d071 "declared-071.txt")
Write-ImplReport -ProjectRoot $d071 -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("declared-071.txt") -Hashes @($hash071)

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d071 "empty-input"),
    "--tasks-file", (Join-Path $specDir071 "tasks.md"),
    "--project-root", $d071,
    "--out", (Join-Path $d071 "out.txt"),
    "--max-bytes", "1000000"
)

$bundleText071 = if (Test-Path (Join-Path $d071 "out.txt")) { Get-Content -Raw (Join-Path $d071 "out.txt") } else { "" }
if ($script:PP_Exit -eq 0 -and
    $bundleText071.Contains("EVID071 line 0001") -and $bundleText071.Contains("EVID071 line 0020") -and
    $bundleText071.Contains("DECL071 line 0001") -and $bundleText071.Contains("DECL071 line 0020")) {
    ok "TEST-071a: both the tier-one evidence file and the declared output are present whole"
} else {
    fail "TEST-071a: expected both files present whole. Output: $($script:PP_Output)"
}
if (-not $bundleText071.ToLower().Contains("elided from the middle")) {
    ok "TEST-071b: no elision marker anywhere -- this bundle is byte-for-byte what it would be with no elision logic at all"
} else {
    fail "TEST-071b: an elision marker appeared even though the bundle already fit --max-bytes"
}

Write-Host "=== TEST-072: over-cap bundle where tier-one elision alone suffices -> tier two is never touched ==="

$d072 = Join-Path $Work "pp072"
$specDir072 = Join-Path $d072 "specs/cross-model-verification"
New-Item -ItemType Directory -Path (Join-Path $specDir072 "verification/T-004") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d072 "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $specDir072 "tasks.md") -TaskId "T-004"
Write-FillerLines -Path (Join-Path $specDir072 "verification/T-004/big.log") -Count 500 -Prefix "BIGT072"
Write-FillerLines -Path (Join-Path $d072 "small-declared.txt") -Count 20 -Prefix "SMALLT072"
$hash072 = Get-Sha256OfFile (Join-Path $d072 "small-declared.txt")
Write-ImplReport -ProjectRoot $d072 -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("small-declared.txt") -Hashes @($hash072)
# Whole bundle ~24,700B; eliding big.log alone brings it to ~5,600B -- the
# declared output (~920B) was never the reason for the overage and must
# stay untouched.

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d072 "empty-input"),
    "--tasks-file", (Join-Path $specDir072 "tasks.md"),
    "--project-root", $d072,
    "--out", (Join-Path $d072 "out.txt"),
    "--max-bytes", "15000"
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-072a: exit 0 (eliding the tier-one file alone let the bundle fit)"
} else {
    fail "TEST-072a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
$bundleText072 = if (Test-Path (Join-Path $d072 "out.txt")) { Get-Content -Raw (Join-Path $d072 "out.txt") } else { "" }
$markerCount072 = ([regex]::Matches($bundleText072, "elided from the middle")).Count
if ($markerCount072 -eq 1 -and $bundleText072.Contains("big.log")) {
    ok "TEST-072b: exactly one elision marker, on the tier-one file"
} else {
    fail "TEST-072b: expected exactly one elision marker naming big.log. Output: $($script:PP_Output)"
}
if ($bundleText072.Contains("SMALLT072 line 0001") -and $bundleText072.Contains("SMALLT072 line 0020")) {
    ok "TEST-072c: the declared output is left completely whole -- tier two was never touched"
} else {
    fail "TEST-072c: the declared output was cut, or is missing, even though tier one alone was enough"
}

Write-Host "=== TEST-073: over-cap bundle where tier one is exhausted -> tier two elides the largest declared output only ==="

$d073 = Join-Path $Work "pp073"
$specDir073 = Join-Path $d073 "specs/cross-model-verification"
New-Item -ItemType Directory -Path (Join-Path $specDir073 "verification/T-004") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d073 "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $specDir073 "tasks.md") -TaskId "T-004"
# No tier-one candidates at all: verification/T-004/ is empty, no
# contract.json. Tier one's own loop is trivially exhausted (nothing to
# elide), so tier two is reached immediately.
Write-FillerLines -Path (Join-Path $d073 "big-declared.txt") -Count 500 -Prefix "BIGT073"
Write-FillerLines -Path (Join-Path $d073 "small-declared.txt") -Count 20 -Prefix "SMALLT073"
$hash073b = Get-Sha256OfFile (Join-Path $d073 "big-declared.txt")
$hash073s = Get-Sha256OfFile (Join-Path $d073 "small-declared.txt")
Write-ImplReport -ProjectRoot $d073 -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("big-declared.txt", "small-declared.txt") -Hashes @($hash073b, $hash073s)

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d073 "empty-input"),
    "--tasks-file", (Join-Path $specDir073 "tasks.md"),
    "--project-root", $d073,
    "--out", (Join-Path $d073 "out.txt"),
    "--max-bytes", "15000"
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-073a: exit 0 (eliding the largest declared output alone let the bundle fit)"
} else {
    fail "TEST-073a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
$bundleText073 = if (Test-Path (Join-Path $d073 "out.txt")) { Get-Content -Raw (Join-Path $d073 "out.txt") } else { "" }
$markerCount073 = ([regex]::Matches($bundleText073, "elided from the middle")).Count
if ($markerCount073 -eq 1 -and $bundleText073.Contains("big-declared.txt")) {
    ok "TEST-073b: exactly one elision marker, on the largest declared output"
} else {
    fail "TEST-073b: expected exactly one elision marker naming big-declared.txt. Output: $($script:PP_Output)"
}
if ($bundleText073.Contains("SMALLT073 line 0001") -and $bundleText073.Contains("SMALLT073 line 0020")) {
    ok "TEST-073c: the smaller declared output is left completely whole"
} else {
    fail "TEST-073c: the smaller declared output was cut, or is missing, even though it was never the cause of the overage"
}

Write-Host "=== TEST-074 (order-sensitive): tier one is attempted to exhaustion BEFORE tier two, even when tier two's own single candidate is far larger ==="

$d074 = Join-Path $Work "pp074"
$specDir074 = Join-Path $d074 "specs/cross-model-verification"
New-Item -ItemType Directory -Path (Join-Path $specDir074 "verification/T-004") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d074 "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $specDir074 "tasks.md") -TaskId "T-004"
Write-FillerLines -Path (Join-Path $specDir074 "verification/T-004/tiny.log") -Count 100 -Prefix "TINYT074"
Write-FillerLines -Path (Join-Path $d074 "big-declared.txt") -Count 500 -Prefix "BIGT074"
$hash074 = Get-Sha256OfFile (Join-Path $d074 "big-declared.txt")
Write-ImplReport -ProjectRoot $d074 -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("big-declared.txt") -Hashes @($hash074)
# tiny.log (~4,700B) is tier one's ONLY candidate; big-declared.txt
# (~23,000B) dominates the overage and, cut alone, would already bring the
# bundle under --max-bytes 15000. A "declared outputs promoted into tier
# one" bug would sort the combined pool by size, cut big-declared.txt
# first (it is larger), see the bundle already fits, and stop -- leaving
# tiny.log untouched. Correct behavior always finishes tier one's own loop
# (its one candidate) before tier two is ever consulted, regardless of
# whether cutting it alone would have been enough, so BOTH files must
# carry a marker here.

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d074 "empty-input"),
    "--tasks-file", (Join-Path $specDir074 "tasks.md"),
    "--project-root", $d074,
    "--out", (Join-Path $d074 "out.txt"),
    "--max-bytes", "15000"
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-074a: exit 0"
} else {
    fail "TEST-074a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
$bundleText074 = if (Test-Path (Join-Path $d074 "out.txt")) { Get-Content -Raw (Join-Path $d074 "out.txt") } else { "" }
$markerCount074 = ([regex]::Matches($bundleText074, "elided from the middle")).Count
if ($markerCount074 -eq 2) {
    ok "TEST-074b: exactly two elision markers -- tier one's own candidate was cut even though tier two alone would have sufficed"
} else {
    fail "TEST-074b: expected exactly two elision markers (tiny.log AND big-declared.txt). Output: $($script:PP_Output)"
}
if ($bundleText074.Contains("tiny.log") -and $bundleText074.Contains("big-declared.txt")) {
    ok "TEST-074c: both markers name the expected files"
} else {
    fail "TEST-074c: the elision markers did not name both tiny.log and big-declared.txt"
}
if (-not $bundleText074.Contains("TINYT074 line 0050")) {
    ok "TEST-074d: tier one's own (small) candidate genuinely lost a middle line -- it was not skipped just because tier two alone would fit"
} else {
    fail "TEST-074d: tiny.log's middle line survived -- tier one was skipped in favor of cutting only the larger tier-two file"
}

Write-Host "=== TEST-075: both tiers exhausted and still over --max-bytes -> fail closed, unchanged ==="

$d075 = Join-Path $Work "pp075"
$specDir075 = Join-Path $d075 "specs/cross-model-verification"
New-Item -ItemType Directory -Path (Join-Path $specDir075 "verification/T-004") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $d075 "empty-input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $specDir075 "tasks.md") -TaskId "T-004"
Write-FillerLines -Path (Join-Path $d075 "big-declared.txt") -Count 500 -Prefix "BIGT075"
Write-FillerLines -Path (Join-Path $d075 "small-declared.txt") -Count 20 -Prefix "SMALLT075"
$hash075b = Get-Sha256OfFile (Join-Path $d075 "big-declared.txt")
$hash075s = Get-Sha256OfFile (Join-Path $d075 "small-declared.txt")
Write-ImplReport -ProjectRoot $d075 -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("big-declared.txt", "small-declared.txt") -Hashes @($hash075b, $hash075s)

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d075 "empty-input"),
    "--tasks-file", (Join-Path $specDir075 "tasks.md"),
    "--project-root", $d075,
    "--out", (Join-Path $d075 "out.txt"),
    "--max-bytes", "2000"
)

if ($script:PP_Exit -ne 0) {
    ok "TEST-075a: over --max-bytes even after exhausting BOTH tiers -> nonzero exit"
} else {
    fail "TEST-075a: expected nonzero exit, got 0. Output: $($script:PP_Output)"
}
if (-not (Test-Path (Join-Path $d075 "out.txt"))) {
    ok "TEST-075b: bundle file NOT written -- exhausting both tiers is never a truncation loophole"
} else {
    fail "TEST-075b: bundle file must not be written when still over --max-bytes after both tiers"
}
if ($script:PP_Output -match "(?i)max-bytes" -and
    $script:PP_Output -match "eliding \d+ task-evidence file\(s\) and \d+ declared-output file\(s\)") {
    ok "TEST-075c: the failure names how many candidates each tier contributed, not just an aggregate count"
} else {
    fail "TEST-075c: expected a per-tier elision count in the failure message. Output: $($script:PP_Output)"
}

Write-Host "=== TEST-076: a declared output that is BOTH stale and elided carries both notices, without either clobbering the other ==="

$d076 = Join-Path $Work "pp076"
New-Item -ItemType Directory -Path (Join-Path $d076 "input") -Force | Out-Null
New-PpiGitScratchRepo $d076
Write-TasksWithConsent -Path (Join-Path $d076 "tasks.md") -TaskId "T-004"
Write-FillerLines -Path (Join-Path $d076 "shared-big.txt") -Count 500 -Prefix "V1T076"
$hash076v1 = Get-Sha256OfFile (Join-Path $d076 "shared-big.txt")
Write-ImplReport -ProjectRoot $d076 -Feature "cross-model-verification" -TaskId "T-004" `
    -Paths @("shared-big.txt") -Hashes @($hash076v1)
Invoke-PpiGitCommit -Root $d076 -Message "declare shared-big.txt v1"

# A later sibling task drifts the shared file to a different, still-large
# (same line count, different prefix) body, so the report's declared hash
# is stale AND the current worktree content is still big enough to need
# eliding at a tight --max-bytes.
Write-FillerLines -Path (Join-Path $d076 "shared-big.txt") -Count 500 -Prefix "V2T076"
Invoke-PpiGitCommit -Root $d076 -Message "sibling task drifts shared-big.txt"

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d076 "input"),
    "--tasks-file", (Join-Path $d076 "tasks.md"),
    "--project-root", $d076,
    "--out", (Join-Path $d076 "out.txt"),
    "--max-bytes", "5000"
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-076a: exit 0"
} else {
    fail "TEST-076a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
$bundleText076 = if (Test-Path (Join-Path $d076 "out.txt")) { Get-Content -Raw (Join-Path $d076 "out.txt") } else { "" }
if ($bundleText076.Contains("shared-big.txt (declared output — CURRENT worktree content; implementation report's declared hash for this path is STALE")) {
    ok "TEST-076b: the stale-hash header notice is present"
} else {
    fail "TEST-076b: expected the stale-hash header notice. Output: $($script:PP_Output)"
}
if ($bundleText076.Contains("elided from the middle of shared-big.txt")) {
    ok "TEST-076c: the elision marker is ALSO present -- the stale notice did not suppress eliding an oversized row"
} else {
    fail "TEST-076c: expected an elision marker on shared-big.txt alongside the stale notice"
}
if ($bundleText076.Contains("V2T076 line 0001") -and $bundleText076.Contains("V2T076 line 0500") -and
    (-not $bundleText076.Contains("V1T076"))) {
    ok "TEST-076d: the head/tail shown is the CURRENT (v2) content -- never the historical declaration-commit bytes"
} else {
    fail "TEST-076d: expected only v2 content in the elided head/tail, and no v1 (historical) bytes anywhere. Output: $($script:PP_Output)"
}

# ============================================================================
# TEST-077: a third real annotation shape, found by running this exact fix
# against all seven real epic-193/194/195 corpus bundles rather than
# reasoning from the two shapes a panelist had already reported -- epic-195
# T-005 declares rows like "| `path` (added) | `hash` |", where the
# annotation sits BETWEEN the path cell and the column separator instead
# of after the hash. Row-parsing is only genuinely fixed if both positions
# are tolerated, not just the one a panelist happened to see first.
# ============================================================================

Write-Host "=== TEST-077: annotation sitting between the path cell and the column separator is parsed and its content included ==="

$d077 = Join-Path $Work "pp077"
New-Item -ItemType Directory -Path (Join-Path $d077 "input") -Force | Out-Null
Write-TasksWithConsent -Path (Join-Path $d077 "specs/cross-model-verification/tasks.md") -TaskId "T-004"
Set-Content -Encoding Utf8 -Path (Join-Path $d077 "baz.tests.sh") -Value "MARKER_077 content behind a path-cell annotation" -NoNewline
$hash077 = Get-Sha256OfFile (Join-Path $d077 "baz.tests.sh")
$reportPath077 = Join-Path $d077 "reports/implementation/cross-model-verification/T-004.md"
New-Item -ItemType Directory -Path (Split-Path $reportPath077) -Force | Out-Null
$lines077 = @(
    "# Implementation Report: T-004", "", "## Outputs", "",
    "| Path | SHA-256 |", "|---|---|",
    "| ${BT}baz.tests.sh${BT} (added) | ${BT}$hash077${BT} |",
    "", "## Test Evidence", "", "N/A (fixture)."
)
Set-Content -Encoding Utf8 -Path $reportPath077 -Value ($lines077 -join "`n")

Invoke-Prepare @(
    "--task", "T-004", "--feature", "cross-model-verification",
    "--input", (Join-Path $d077 "input"),
    "--tasks-file", (Join-Path $d077 "specs/cross-model-verification/tasks.md"),
    "--project-root", $d077,
    "--out", (Join-Path $d077 "out.txt")
)

if ($script:PP_Exit -eq 0) {
    ok "TEST-077a: exit 0 (real epic-195 T-005 row shape: annotation between the path cell and the column separator)"
} else {
    fail "TEST-077a: expected exit 0, got $($script:PP_Exit). Output: $($script:PP_Output)"
}
$bundleText077 = if (Test-Path (Join-Path $d077 "out.txt")) { Get-Content -Raw (Join-Path $d077 "out.txt") } else { "" }
if ($bundleText077.Contains("MARKER_077")) {
    ok "TEST-077b: the row's content made it into the bundle despite the path-cell annotation"
} else {
    fail "TEST-077b: expected baz.tests.sh's content in the bundle, not found. Output: $($script:PP_Output)"
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
