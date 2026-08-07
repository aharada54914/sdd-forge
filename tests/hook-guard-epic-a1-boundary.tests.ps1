# T-010 (epic-189-a1-project-context, REQ-008, AC-023): TEST-023 --
# protected-write full-matrix deny, PowerShell lane.
#
# PowerShell twin of tests/hook-guard-epic-a1-boundary.tests.sh. The .sh lane
# drives sdd-hook-guard.py; this lane drives sdd-hook-guard.ps1, so the 96-cell
# claim is proven against BOTH guard runtimes rather than one.
#
# WHAT THIS PROVES
#   A write attempt against EACH of the four basenames REQ-007 registered,
#   through EVERY ONE of design.md Test Strategy item 8's 12 mutation
#   surfaces, is DENIED -- including under an ACTIVE, fixture-signed
#   SDD_SUDO token. 4 x 12 x 2 = 96 independent assertions.
#
# HOW THE GUARD IS DRIVEN (no agent in the loop, CI-reproducible)
#   Each cell pipes a synthetic hook payload on stdin to the real guard
#   entry point and reads its exit status (0 = allow, 2 = deny) -- the same
#   mechanism tests/guard-r10-port.tests.ps1 already uses.
#
# WHY THE ASSERTIONS CANNOT PASS VACUOUSLY
#   PRE-*  the four basenames really are in the LIVE inventory, the stripped
#          fixture really lacks them, and the fixture SDD_SUDO token really
#          is ACTIVE (probed with an approval-increase payload that only an
#          active token allows). Without that last check, "sudo does not
#          bypass" would pass trivially against an inactive token.
#   MUT-*  the same 48 payloads against a throwaway copy whose inventory has
#          exactly the four entries removed must be ALLOWED.
#   BASE-* the same 48 payloads against an UNMODIFIED throwaway copy must
#          still be DENIED, so MUT-* cannot pass because copying broke it.
#
# RED MODE
#   $env:SDD_T010_SIMULATE_PRE_APPLY = "1" runs the AC-023 block against the
#   stripped (pre-REQ-007-application) inventory; all 96 cells then FAIL.
#
# SUPPLEMENTARY
#   The R-10 pre-filter assertion (SUPP-*, explicitly OUTSIDE AC-023's 96 per
#   the 2026-08-03 ruling) is asserted in the .sh twin, which can import the
#   Python guard module and call _command_references_protected_path directly.
#   The PowerShell counterpart (Test-CommandReferencesProtectedPath) cannot be
#   invoked in isolation because dot-sourcing sdd-hook-guard.ps1 executes its
#   main decision flow. The gap that assertion covers is recorded in
#   reports/notes/epic-189-a1-carryover-items.md.
#
# Every scratch mutation happens under a temp directory; the repository
# working tree is never modified. ASCII-only source (AC-015 house rule).

$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptsRel = "plugins/sdd-quality-loop/scripts"
$liveScripts = Join-Path $repositoryRoot $scriptsRel
$liveGuard = Join-Path $liveScripts "sdd-hook-guard.ps1"
$invRel = Join-Path "generated" "guard-invariants.generated.ps1"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("hook-guard-epic-a1-boundary-" + [System.Guid]::NewGuid().ToString("N").Substring(0, 12))
New-Item -ItemType Directory -Path $work -Force | Out-Null

$basenames = @(
    "sdd/project-context.approval.json",
    "sdd/provider-bindings.approval.json",
    "sdd/approver-registry.yaml",
    "sdd/.hook-canary-sentinel"
)
$surfaces = @("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12")
$sudoKey = "t010-fixture-key-not-a-real-secret"

$script:Passed = 0
$script:Failed = 0
function Pass([string]$m) { $script:Passed++; Write-Host "PASS: $m" }
function Fail([string]$m) { $script:Failed++; Write-Host "FAIL: $m" }

try {

# ---------------------------------------------------------------------------
# Fixtures: guard trees (pristine copy / stripped copy)
# ---------------------------------------------------------------------------

$pristineDir = Join-Path $work "guard-pristine"
$strippedDir = Join-Path $work "guard-stripped"
Copy-Item -Path $liveScripts -Destination $pristineDir -Recurse -Force
Copy-Item -Path $liveScripts -Destination $strippedDir -Recurse -Force
foreach ($d in @($pristineDir, $strippedDir)) {
    $pc = Join-Path $d "__pycache__"
    if (Test-Path -LiteralPath $pc) { Remove-Item -LiteralPath $pc -Recurse -Force }
}

$strippedInv = Join-Path $strippedDir $invRel
$invText = [System.IO.File]::ReadAllText($strippedInv)
foreach ($bn in $basenames) {
    $needle = "'" + $bn + "', "
    if (-not $invText.Contains($needle)) {
        Fail "fixture: entry absent from generated PowerShell inventory: $bn"
        Write-Host "PASS: $script:Passed"
        Write-Host "FAIL: $script:Failed"
        exit 1
    }
    $invText = $invText.Replace($needle, "")
}
[System.IO.File]::WriteAllText($strippedInv, $invText)

# ---------------------------------------------------------------------------
# Fixtures: project roots (no sudo / active signed sudo token)
# ---------------------------------------------------------------------------

$projPlain = Join-Path $work "proj-plain"
$projSudo = Join-Path $work "proj-sudo"
foreach ($p in @($projPlain, $projSudo)) {
    New-Item -ItemType Directory -Path (Join-Path $p "sdd") -Force | Out-Null
}

# The guard binds the token to the canonical real path of the directory that
# holds SDD_SUDO, so resolve symlinks (macOS /var -> /private/var) the same way.
function Resolve-RealPath([string]$path) {
    $item = Get-Item -LiteralPath $path -Force
    $target = $item.ResolveLinkTarget($true)
    if ($null -ne $target) { return $target.FullName }
    return $item.FullName
}

$sudoRepo = Resolve-RealPath $projSudo
$issuer = "t010-fixture@ci"
$nonce = "b" * 64
$issued = [int][double]::Parse((Get-Date -UFormat %s)) - 60
$expires = $issued + 3660
$canonical = ($issuer, $nonce, $sudoRepo, "$issued", "$expires") -join "`n"
$hmac = New-Object System.Security.Cryptography.HMACSHA256
$hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($sudoKey)
$sigBytes = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($canonical))
$sig = -join ($sigBytes | ForEach-Object { $_.ToString("x2") })
$flag = @(
    "enabled-by: human via /sdd-sudo",
    "enabled-at: 2026-08-03T00:00:00Z",
    "issuer: $issuer",
    "nonce: $nonce",
    "repo: $sudoRepo",
    "issued-epoch: $issued",
    "expires-epoch: $expires",
    "duration: 1h",
    "sig: $sig",
    ""
) -join "`n"
[System.IO.File]::WriteAllText((Join-Path $projSudo "SDD_SUDO"), $flag)

# ---------------------------------------------------------------------------
# Payload construction: design.md Test Strategy item 8's 12 surface rows
# ---------------------------------------------------------------------------

# JSON string-body escaping for the path values interpolated into the payload
# literals below. On POSIX every one of those values is a plain path with no
# backslash and no double quote, so this is a byte-for-byte no-op there and the
# .sh-parity payloads are unchanged. On native Windows $absolute is a real
# absolute path ("C:\Users\runneradmin\AppData\Local\Temp\..."), whose
# backslashes the guard's own ConvertFrom-Json would otherwise read as JSON
# escape sequences -- "\U", "\A", "\L", "\T" are invalid escapes, and "\r"/"\t"
# would silently become control characters -- so the payload would arrive
# MALFORMED. That is not a harmless difference: the guard denies malformed
# payloads (sdd-hook-guard.ps1's ConvertFrom-Json catch calls
# Emit-Decision "deny"), so surface 05's AC-023 and BASE-* deny cells would
# have passed VACUOUSLY -- the exact failure mode this suite's header calls out
# -- while every MUT surface-05 cell, which must be ALLOWED after
# de-registration, failed. Escaping keeps all three cell families measuring the
# guard's real path analysis on both platforms.
function ConvertTo-JsonStringBody([string]$value) {
    return $value.Replace('\', '\\').Replace('"', '\"')
}

function Get-Payload([string]$id, [string]$rawTarget, [string]$rawBase, [string]$rawAbsolute) {
    $target = ConvertTo-JsonStringBody $rawTarget
    $base = ConvertTo-JsonStringBody $rawBase
    $absolute = ConvertTo-JsonStringBody $rawAbsolute
    switch ($id) {
        "01" { return '{"tool_name":"Bash","tool_input":{"command":"echo x > ' + $target + '"}}' }
        "02" { return '{"tool_name":"Bash","tool_input":{"command":"echo x >' + $target + '"}}' }
        "03" { return '{"tool_name":"Bash","tool_input":{"command":"cp src.yaml ' + $target + '"}}' }
        "04" { return '{"tool_name":"Bash","tool_input":{"command":"rm ' + $target + '"}}' }
        "05" { return '{"tool_name":"Bash","tool_input":{"command":"cd /tmp && echo x > ' + $absolute + '"}}' }
        "06" { return '{"tool_name":"Bash","tool_input":{"command":"cd sdd && echo x > ' + $base + '"}}' }
        "07" { return '{"tool_name":"Bash","tool_input":{"command":"cd sdd && > ' + $base + '"}}' }
        "08" { return '{"tool_name":"Bash","tool_input":{"command":"cd sdd && echo x >' + $base + '"}}' }
        "09" { return '{"tool_name":"Bash","tool_input":{"command":"cd sdd && cp x.yaml ' + $base + '"}}' }
        "10" { return '{"tool_name":"Bash","tool_input":{"command":"cd sdd && rm ' + $base + '"}}' }
        "11" { return '{"tool_name":"Write","tool_input":{"file_path":"' + $target + '","content":"x"}}' }
        "12" { return '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Update File: ' + $target + '\n+x\n*** End Patch"}}' }
    }
    return "UNKNOWN-SURFACE"
}

function Get-Label([string]$id) {
    switch ($id) {
        "01" { return "detached-redirect" }
        "02" { return "attached-redirect" }
        "03" { return "cp/mv-dest" }
        "04" { return "tee/touch/rm" }
        "05" { return "cwd-absolute" }
        "06" { return "cwd-relative" }
        "07" { return "segment-detached-redirect" }
        "08" { return "segment-attached-redirect" }
        "09" { return "segment-cp/mv-dest" }
        "10" { return "segment-tee/touch/rm" }
        "11" { return "native-Edit/Write/MultiEdit" }
        "12" { return "apply_patch-envelope" }
    }
    return "unknown"
}

function Invoke-GuardExit([string]$guardPath, [string]$projectDir, [string]$payload, [bool]$withSudoKey) {
    $prevRoot = $env:CLAUDE_PROJECT_DIR
    $prevKey = $env:SDD_SUDO_KEY
    $prevLocation = Get-Location
    try {
        $env:CLAUDE_PROJECT_DIR = $projectDir
        if ($withSudoKey) { $env:SDD_SUDO_KEY = $sudoKey } else { Remove-Item Env:\SDD_SUDO_KEY -ErrorAction SilentlyContinue }
        Set-Location -LiteralPath $projectDir
        $payload | & pwsh -NoProfile -ExecutionPolicy Bypass -File $guardPath -Emit exit *> $null
        return $LASTEXITCODE
    } finally {
        Set-Location $prevLocation
        if ($null -ne $prevRoot) { $env:CLAUDE_PROJECT_DIR = $prevRoot } else { Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        if ($null -ne $prevKey) { $env:SDD_SUDO_KEY = $prevKey } else { Remove-Item Env:\SDD_SUDO_KEY -ErrorAction SilentlyContinue }
    }
}

# ---------------------------------------------------------------------------
# PRE-* preflight (not part of AC-023's 96)
# ---------------------------------------------------------------------------

$liveInvText = [System.IO.File]::ReadAllText((Join-Path $liveScripts $invRel))
foreach ($bn in $basenames) {
    if ($liveInvText.Contains("'" + $bn + "'")) {
        Pass "PRE-live-inventory: $bn is registered in the LIVE generated inventory"
    } else {
        Fail "PRE-live-inventory: $bn is MISSING from the LIVE generated inventory (REQ-007 not applied?)"
    }
}
$strippedText = [System.IO.File]::ReadAllText($strippedInv)
foreach ($bn in $basenames) {
    if ($strippedText.Contains("'" + $bn + "'")) {
        Fail "PRE-stripped-fixture: $bn should have been removed from the stripped fixture"
    } else {
        Pass "PRE-stripped-fixture: $bn removed from the stripped fixture inventory"
    }
}

$approvalPayload = '{"tool_name":"Edit","tool_input":{"file_path":"specs/f/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'
$rc = Invoke-GuardExit $liveGuard $projSudo $approvalPayload $true
if ($rc -eq 0) {
    Pass "PRE-sudo-active: fixture SDD_SUDO token is ACTIVE (approval-increase allowed)"
} else {
    Fail "PRE-sudo-active: fixture SDD_SUDO token is NOT active (expected exit 0, got $rc) -- every sudo-lane cell would be vacuous"
}
$rc = Invoke-GuardExit $liveGuard $projPlain $approvalPayload $false
if ($rc -eq 2) {
    Pass "PRE-sudo-inactive: no-token fixture leaves the approval guard enforcing (deny)"
} else {
    Fail "PRE-sudo-inactive: expected exit 2 without a token, got $rc"
}

# ---------------------------------------------------------------------------
# AC-023: the 96 cells (4 basenames x 12 surfaces x 2 sudo states)
# ---------------------------------------------------------------------------

$acGuard = $liveGuard
$acMode = "live post-application inventory"
if ($env:SDD_T010_SIMULATE_PRE_APPLY -eq "1") {
    $acGuard = Join-Path $strippedDir "sdd-hook-guard.ps1"
    $acMode = "SIMULATED PRE-APPLICATION inventory (RED mode)"
}
Write-Host ""
Write-Host "--- AC-023 matrix: $acMode ---"

$acCells = 0
foreach ($bn in $basenames) {
    $base = $bn.Substring($bn.LastIndexOf("/") + 1)
    foreach ($sf in $surfaces) {
        foreach ($lane in @(0, 1)) {
            if ($lane -eq 1) { $proj = $projSudo; $laneLabel = "sudo=ACTIVE" } else { $proj = $projPlain; $laneLabel = "sudo=inactive" }
            $payload = Get-Payload $sf $bn $base (Join-Path $proj $bn)
            $rc = Invoke-GuardExit $acGuard $proj $payload ($lane -eq 1)
            $acCells++
            $desc = "AC-023 [$bn | surface $sf $(Get-Label $sf) | $laneLabel] -> deny"
            if ($rc -eq 2) { Pass $desc } else { Fail "$desc (expected exit 2, got $rc)" }
        }
    }
}
if ($acCells -eq 96) {
    Pass "AC-023 exhaustiveness: all 96 matrix cells executed"
} else {
    Fail "AC-023 exhaustiveness: expected 96 cells, executed $acCells"
}

# ---------------------------------------------------------------------------
# BASE-* / MUT-*: pristine baseline paired with the inventory mutation
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "--- BASE-* pristine copy (must still deny) / MUT-* stripped copy (must allow) ---"
$baseCells = 0
$mutCells = 0
foreach ($bn in $basenames) {
    $base = $bn.Substring($bn.LastIndexOf("/") + 1)
    foreach ($sf in $surfaces) {
        $payload = Get-Payload $sf $bn $base (Join-Path $projPlain $bn)

        $rc = Invoke-GuardExit (Join-Path $pristineDir "sdd-hook-guard.ps1") $projPlain $payload $false
        $baseCells++
        if ($rc -eq 2) {
            Pass "BASE [$bn | surface $sf] pristine copy still denies"
        } else {
            Fail "BASE [$bn | surface $sf] pristine copy expected exit 2, got $rc (copy harness is unfaithful; MUT below would be meaningless)"
        }

        $rc = Invoke-GuardExit (Join-Path $strippedDir "sdd-hook-guard.ps1") $projPlain $payload $false
        $mutCells++
        if ($rc -eq 0) {
            Pass "MUT [$bn | surface $sf] de-registered basename is allowed (assertion has detection power)"
        } else {
            Fail "MUT [$bn | surface $sf] expected exit 0 after de-registration, got $rc (the matching AC-023 cell may be denying for an unrelated reason)"
        }
    }
}
if ($baseCells -eq 48 -and $mutCells -eq 48) {
    Pass "BASE/MUT exhaustiveness: 48 pristine + 48 mutated cells executed"
} else {
    Fail "BASE/MUT exhaustiveness: expected 48/48, executed $baseCells/$mutCells"
}

# ---------------------------------------------------------------------------
# Self-registration
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "--- self-registration ---"
if (Test-Path -LiteralPath (Join-Path $repositoryRoot "tests/hook-guard-epic-a1-boundary.tests.sh")) {
    Pass "self-registration: POSIX twin exists"
} else {
    Fail "self-registration: POSIX twin tests/hook-guard-epic-a1-boundary.tests.sh missing"
}
foreach ($runner in @("run-all.sh", "run-all.ps1")) {
    $runnerPath = Join-Path $repositoryRoot (Join-Path "tests" $runner)
    if ([System.IO.File]::ReadAllText($runnerPath).Contains("hook-guard-epic-a1-boundary.tests")) {
        Pass "self-registration: registered in tests/$runner"
    } else {
        Fail "self-registration: NOT registered in tests/$runner"
    }
}

} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ""
Write-Host "PASS: $script:Passed"
Write-Host "FAIL: $script:Failed"
if ($script:Failed -ne 0) { exit 1 }
exit 0
