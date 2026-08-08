# T-008 (epic-189-a1-project-context, REQ-010): acceptance checks for
# plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py and
# its .sh/.ps1 dispatcher wrappers.
#
# PowerShell parity port of tests/check-hook-activation-handshake.tests.sh.
# See that file's header for the full TEST-027/TEST-032/TEST-HARDEN <-> AC
# mapping.
#
# Every invocation below runs check-hook-activation-handshake.ps1 as a REAL
# CHILD PROCESS via [System.Diagnostics.Process] (never PowerShell's own
# `&` call operator: the tool calls `exit $Code` internally, which would
# terminate THIS test session if invoked in-process -- mirroring detect-
# policy-weakening.tests.ps1's / apply-human-copy.tests.ps1's own
# established rationale).
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Work = Join-Path ([IO.Path]::GetTempPath()) ("check-hook-activation-handshake-test-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null

$HhPs1 = Join-Path $Root 'plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.ps1'
# The SAME PowerShell binary currently running this suite, matching
# tests/run-all.ps1's own convention.
$PowerShellExe = (Get-Process -Id $PID).Path

$script:PassCount = 0
$script:FailCount = 0

function Test-Pass([string]$Label) {
    $script:PassCount++
    Write-Output "PASS: $Label"
}

function Test-Fail([string]$Label, [string]$Detail = '') {
    $script:FailCount++
    Write-Output "FAIL: ${Label}: $Detail"
}

function Assert-Eq($Actual, $Expected, [string]$Label) {
    if ($Actual -eq $Expected) {
        Test-Pass $Label
    } else {
        Test-Fail $Label "got '$Actual', want '$Expected'"
    }
}

function Invoke-ChildProcess {
    param(
        [Parameter(Mandatory)][string]$Exe,
        [string[]]$ArgList = @(),
        [Parameter(Mandatory)][string]$WorkingDirectory
    )
    $outPath = Join-Path $Work ([Guid]::NewGuid().ToString('N') + '.out')
    $errPath = Join-Path $Work ([Guid]::NewGuid().ToString('N') + '.err')

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $Exe
    foreach ($a in $ArgList) { $psi.ArgumentList.Add($a) }
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdoutStream = [System.IO.MemoryStream]::new()
    $stderrStream = [System.IO.MemoryStream]::new()
    $copyOutTask = $proc.StandardOutput.BaseStream.CopyToAsync($stdoutStream)
    $copyErrTask = $proc.StandardError.BaseStream.CopyToAsync($stderrStream)
    $proc.WaitForExit()
    $copyOutTask.GetAwaiter().GetResult()
    $copyErrTask.GetAwaiter().GetResult()
    [System.IO.File]::WriteAllBytes($outPath, $stdoutStream.ToArray())
    [System.IO.File]::WriteAllBytes($errPath, $stderrStream.ToArray())

    return @{ ExitCode = $proc.ExitCode; StdoutPath = $outPath; StderrPath = $errPath }
}

function Invoke-Hh {
    param([string]$WorkDir, [string[]]$ArgList = @())
    return Invoke-ChildProcess -Exe $PowerShellExe `
        -ArgList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $HhPs1) + $ArgList) `
        -WorkingDirectory $WorkDir
}

function Get-OutJson($Result) {
    return (Get-Content -Raw -LiteralPath $Result.StdoutPath) | ConvertFrom-Json
}

function Get-ErrText($Result) {
    return (Get-Content -Raw -LiteralPath $Result.StderrPath -ErrorAction SilentlyContinue)
}

function Get-Sha256Hex([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-NoTraceback($Result, [string]$Label) {
    $errText = Get-ErrText $Result
    if ($errText -match '(?i)traceback') {
        Test-Fail "${Label}: no raw traceback on stderr" "FOUND ONE: $errText"
    } else {
        Test-Pass "${Label}: no raw traceback on stderr"
    }
}

$script:FixtureCounter = 0
function New-FixtureDir {
    $script:FixtureCounter++
    $dir = Join-Path $Work "f$script:FixtureCounter"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    return $dir
}

try {

# ---------------------------------------------------------------------------
# TEST-027: per-runtime fail-closed verify-response proof -- AC-027.
# ---------------------------------------------------------------------------

$T027 = New-FixtureDir

# --- claude-code ---------------------------------------------------------

$NonceCc = 'nonce-cc-fixed-001'

$ccDeny = Join-Path $T027 'cc-deny.json'
Set-Content -LiteralPath $ccDeny -NoNewline -Encoding utf8 -Value "{`"nonce`": `"$NonceCc`", `"executed`": false, `"guard_emit_mode`": `"exit`", `"exit_code`": 2}"
$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', $NonceCc, '--recorded-result', 'cc-deny.json', '--runtime', 'claude-code')
Assert-Eq $r.ExitCode 0 'TEST-027 claude-code: a genuine --emit exit deny signature + matching nonce -> exit 0'
$j = Get-OutJson $r
Assert-Eq $j.status 'HOOK_ACTIVE' 'TEST-027 claude-code: HOOK_ACTIVE reported'

$ccWrite = Join-Path $T027 'cc-write.json'
Set-Content -LiteralPath $ccWrite -NoNewline -Encoding utf8 -Value "{`"nonce`": `"$NonceCc`", `"executed`": true}"
$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', $NonceCc, '--recorded-result', 'cc-write.json', '--runtime', 'claude-code')
Assert-Eq $r.ExitCode 63 'TEST-027 claude-code: the write actually executing -> exit 63/WRITE_EXECUTED'
$j = Get-OutJson $r
Assert-Eq $j.status 'CAPABILITY_RUNTIME_UNAVAILABLE' 'TEST-027 claude-code: WRITE_EXECUTED -> CAPABILITY_RUNTIME_UNAVAILABLE'
Assert-Eq $j.reason 'WRITE_EXECUTED' 'TEST-027 claude-code: WRITE_EXECUTED reason reported'

$ccUnrecognized = Join-Path $T027 'cc-unrecognized.json'
Set-Content -LiteralPath $ccUnrecognized -NoNewline -Encoding utf8 -Value "{`"nonce`": `"$NonceCc`", `"executed`": false}"
$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', $NonceCc, '--recorded-result', 'cc-unrecognized.json', '--runtime', 'claude-code')
Assert-Eq $r.ExitCode 64 'TEST-027 claude-code: executed:false with no guard_emit_mode/exit_code -> exit 64/UNRECOGNIZED_RESULT'
$j = Get-OutJson $r
Assert-Eq $j.reason 'UNRECOGNIZED_RESULT' 'TEST-027 claude-code: UNRECOGNIZED_RESULT reason reported'

$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', $NonceCc, '--recorded-result', 'does-not-exist.json', '--runtime', 'claude-code')
Assert-Eq $r.ExitCode 60 'TEST-027 claude-code: a missing recorded-result file -> exit 60/NO_RECORDED_RESULT'
$j = Get-OutJson $r
Assert-Eq $j.reason 'NO_RECORDED_RESULT' 'TEST-027 claude-code: NO_RECORDED_RESULT reason reported'

$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', 'a-different-nonce', '--recorded-result', 'cc-deny.json', '--runtime', 'claude-code')
Assert-Eq $r.ExitCode 62 'TEST-027 claude-code: an otherwise-correct signature with a MISMATCHED nonce -> exit 62/STALE_CHALLENGE_REJECTED'
$j = Get-OutJson $r
Assert-Eq $j.reason 'STALE_CHALLENGE_REJECTED' 'TEST-027 claude-code: STALE_CHALLENGE_REJECTED reason reported (never HOOK_ACTIVE without a fresh nonce match)'

# --- copilot-cli -----------------------------------------------------------

$NonceCp = 'nonce-copilot-fixed-002'

$cpDeny = Join-Path $T027 'cp-deny.json'
Set-Content -LiteralPath $cpDeny -NoNewline -Encoding utf8 -Value "{`"nonce`": `"$NonceCp`", `"executed`": false, `"permissionDecision`": `"deny`"}"
$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', $NonceCp, '--recorded-result', 'cp-deny.json', '--runtime', 'copilot-cli')
Assert-Eq $r.ExitCode 0 'TEST-027 copilot-cli: a genuine --emit copilot deny JSON + matching nonce -> exit 0'
$j = Get-OutJson $r
Assert-Eq $j.status 'HOOK_ACTIVE' 'TEST-027 copilot-cli: HOOK_ACTIVE reported'

$cpWrite = Join-Path $T027 'cp-write.json'
Set-Content -LiteralPath $cpWrite -NoNewline -Encoding utf8 -Value "{`"nonce`": `"$NonceCp`", `"executed`": true}"
$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', $NonceCp, '--recorded-result', 'cp-write.json', '--runtime', 'copilot-cli')
Assert-Eq $r.ExitCode 63 'TEST-027 copilot-cli: the write actually executing -> exit 63/WRITE_EXECUTED'

$cpAbsent = Join-Path $T027 'cp-absent-decision.json'
Set-Content -LiteralPath $cpAbsent -NoNewline -Encoding utf8 -Value "{`"nonce`": `"$NonceCp`", `"executed`": false}"
$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', $NonceCp, '--recorded-result', 'cp-absent-decision.json', '--runtime', 'copilot-cli')
Assert-Eq $r.ExitCode 64 'TEST-027 copilot-cli: an ABSENT permissionDecision -> exit 64/UNRECOGNIZED_RESULT, never HOOK_ACTIVE'

$cpAllow = Join-Path $T027 'cp-allow.json'
Set-Content -LiteralPath $cpAllow -NoNewline -Encoding utf8 -Value "{`"nonce`": `"$NonceCp`", `"executed`": false, `"permissionDecision`": `"allow`"}"
$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', $NonceCp, '--recorded-result', 'cp-allow.json', '--runtime', 'copilot-cli')
Assert-Eq $r.ExitCode 64 "TEST-027 copilot-cli: the well-known 'subagent hook often does not fire' case (permissionDecision: allow) -> exit 64/UNRECOGNIZED_RESULT, not a special case"

$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', $NonceCp, '--recorded-result', 'missing.json', '--runtime', 'copilot-cli')
Assert-Eq $r.ExitCode 60 'TEST-027 copilot-cli: a missing recorded-result file -> exit 60/NO_RECORDED_RESULT'

$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', 'wrong-nonce', '--recorded-result', 'cp-deny.json', '--runtime', 'copilot-cli')
Assert-Eq $r.ExitCode 62 'TEST-027 copilot-cli: a MISMATCHED nonce against an otherwise-correct deny signature -> exit 62/STALE_CHALLENGE_REJECTED'

# --- codex-cli -------------------------------------------------------------

$NonceCx = 'nonce-codex-fixed-003'

$cxDeny = Join-Path $T027 'cx-deny.json'
Set-Content -LiteralPath $cxDeny -NoNewline -Encoding utf8 -Value "{`"nonce`": `"$NonceCx`", `"executed`": false, `"plugin_hooks_enabled`": true, `"denied_by_plugin_hooks`": true}"
$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', $NonceCx, '--recorded-result', 'cx-deny.json', '--runtime', 'codex-cli')
Assert-Eq $r.ExitCode 0 'TEST-027 codex-cli: plugin_hooks_enabled + denied_by_plugin_hooks + matching nonce -> exit 0'
$j = Get-OutJson $r
Assert-Eq $j.status 'HOOK_ACTIVE' 'TEST-027 codex-cli: HOOK_ACTIVE reported'

$cxWrite = Join-Path $T027 'cx-write.json'
Set-Content -LiteralPath $cxWrite -NoNewline -Encoding utf8 -Value "{`"nonce`": `"$NonceCx`", `"executed`": true}"
$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', $NonceCx, '--recorded-result', 'cx-write.json', '--runtime', 'codex-cli')
Assert-Eq $r.ExitCode 63 'TEST-027 codex-cli: the write actually executing -> exit 63/WRITE_EXECUTED'

$cxFlagDisabled = Join-Path $T027 'cx-flag-disabled.json'
Set-Content -LiteralPath $cxFlagDisabled -NoNewline -Encoding utf8 -Value "{`"nonce`": `"$NonceCx`", `"executed`": false, `"plugin_hooks_enabled`": false, `"denied_by_plugin_hooks`": true}"
$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', $NonceCx, '--recorded-result', 'cx-flag-disabled.json', '--runtime', 'codex-cli')
Assert-Eq $r.ExitCode 65 'TEST-027 codex-cli: an unset/false plugin_hooks_enabled -> exit 65/PLUGIN_HOOKS_DISABLED even when denied_by_plugin_hooks claims true (the collapse-into-hook-not-active case, REQ-010)'
$j = Get-OutJson $r
Assert-Eq $j.reason 'PLUGIN_HOOKS_DISABLED' 'TEST-027 codex-cli: PLUGIN_HOOKS_DISABLED reason reported, never HOOK_ACTIVE'

$cxUnrecognized = Join-Path $T027 'cx-unrecognized.json'
Set-Content -LiteralPath $cxUnrecognized -NoNewline -Encoding utf8 -Value "{`"nonce`": `"$NonceCx`", `"executed`": false, `"plugin_hooks_enabled`": true}"
$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', $NonceCx, '--recorded-result', 'cx-unrecognized.json', '--runtime', 'codex-cli')
Assert-Eq $r.ExitCode 64 'TEST-027 codex-cli: plugin_hooks_enabled true but no denied_by_plugin_hooks -> exit 64/UNRECOGNIZED_RESULT'

$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', $NonceCx, '--recorded-result', 'missing.json', '--runtime', 'codex-cli')
Assert-Eq $r.ExitCode 60 'TEST-027 codex-cli: a missing recorded-result file -> exit 60/NO_RECORDED_RESULT'

$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', 'wrong-nonce', '--recorded-result', 'cx-deny.json', '--runtime', 'codex-cli')
Assert-Eq $r.ExitCode 62 'TEST-027 codex-cli: a MISMATCHED nonce against an otherwise-correct deny signature -> exit 62/STALE_CHALLENGE_REJECTED'

# --- runtime-independent evidence malformation (shared code path) --------

$badJson = Join-Path $T027 'bad-json.json'
Set-Content -LiteralPath $badJson -NoNewline -Encoding utf8 -Value '{not valid json'
$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', $NonceCc, '--recorded-result', 'bad-json.json', '--runtime', 'claude-code')
Assert-Eq $r.ExitCode 61 'TEST-027 shared: invalid JSON syntax -> exit 61/RECORDED_RESULT_UNREADABLE'

$arrayTop = Join-Path $T027 'array-toplevel.json'
Set-Content -LiteralPath $arrayTop -NoNewline -Encoding utf8 -Value '[1, 2, 3]'
$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', $NonceCc, '--recorded-result', 'array-toplevel.json', '--runtime', 'claude-code')
Assert-Eq $r.ExitCode 61 'TEST-027 shared: a non-object (JSON array) top level -> exit 61/RECORDED_RESULT_UNREADABLE'

$badUtf8 = Join-Path $T027 'bad-utf8.json'
[System.IO.File]::WriteAllBytes($badUtf8, [byte[]](0xFF, 0xFE, 0x20, 0x6E, 0x6F, 0x74, 0x20, 0x76, 0x61, 0x6C, 0x69, 0x64))
$r = Invoke-Hh -WorkDir $T027 -ArgList @('--verify-response', '--nonce', $NonceCc, '--recorded-result', 'bad-utf8.json', '--runtime', 'claude-code')
Assert-Eq $r.ExitCode 61 'TEST-027 shared: invalid UTF-8 bytes -> exit 61/RECORDED_RESULT_UNREADABLE'

# --- Challenge shape / cross-artifact contract check (AGENTS.md "High-risk
# task preflight", WFI-001): --emit-challenge's own 'schema' and
# 'canary_target' fields are FIXED literals design.md's CLI contract names
# verbatim -- a drift here would silently desynchronize from the guard-
# invariants protected-path registration (T-009) and every future entry
# point's own tool-call template resolution (T-011/T-012), so their exact
# values are asserted directly rather than merely relied upon implicitly.
$Shape = Join-Path $T027 'shape'
New-Item -ItemType Directory -Path (Join-Path $Shape 'sdd') -Force | Out-Null
$r = Invoke-Hh -WorkDir $Shape -ArgList @('--emit-challenge')
$j = Get-OutJson $r
Assert-Eq $j.schema 'sdd-hook-challenge/v1' "TEST-027 challenge shape: 'schema' is the exact literal design.md's CLI contract fixes"
Assert-Eq $j.canary_target 'sdd/.hook-canary-sentinel' "TEST-027 challenge shape: 'canary_target' is the exact literal protected sentinel path design.md's Data Plan registers"
foreach ($rt in @('claude-code', 'codex-cli', 'copilot-cli')) {
  $hasProp = [bool]($j.tool_call_template.PSObject.Properties.Name -contains $rt)
  Assert-Eq $hasProp $true "TEST-027 challenge shape: tool_call_template includes a '$rt' entry"
}

# ---------------------------------------------------------------------------
# TEST-032: sentinel two-branch non-mutation + cleanup-success observation
# + stale-start recovery -- AC-032.
# ---------------------------------------------------------------------------

# (a) hook FIRES: HOOK_ACTIVE, absent-before/absent-after, no cleanup step.
$BranchA = New-FixtureDir
New-Item -ItemType Directory -Path (Join-Path $BranchA 'sdd') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $BranchA 'sdd/project-context.approval.json') -NoNewline -Encoding utf8 -Value 'placeholder project-context sidecar bytes'
Set-Content -LiteralPath (Join-Path $BranchA 'sdd/provider-bindings.approval.json') -NoNewline -Encoding utf8 -Value 'placeholder provider-bindings sidecar bytes'
$HashPcBefore = Get-Sha256Hex (Join-Path $BranchA 'sdd/project-context.approval.json')
$HashPbBefore = Get-Sha256Hex (Join-Path $BranchA 'sdd/provider-bindings.approval.json')

$SentinelA = Join-Path $BranchA 'sdd/.hook-canary-sentinel'
if (Test-Path -LiteralPath $SentinelA) {
  Test-Fail 'TEST-032 (a) precondition: sentinel absent BEFORE the hook-fires branch'
} else {
  Test-Pass 'TEST-032 (a) precondition: sentinel absent BEFORE the hook-fires branch'
}
$NonceA = 'nonce-branch-a-004'
Set-Content -LiteralPath (Join-Path $BranchA 'deny.json') -NoNewline -Encoding utf8 -Value "{`"nonce`": `"$NonceA`", `"executed`": false, `"guard_emit_mode`": `"exit`", `"exit_code`": 2}"
$r = Invoke-Hh -WorkDir $BranchA -ArgList @('--verify-response', '--nonce', $NonceA, '--recorded-result', 'deny.json', '--runtime', 'claude-code')
Assert-Eq $r.ExitCode 0 'TEST-032 (a) hook FIRES: HOOK_ACTIVE'
if (Test-Path -LiteralPath $SentinelA) {
  Test-Fail 'TEST-032 (a) the sentinel is absent-AFTER the hook-fires branch too (never created)'
} else {
  Test-Pass 'TEST-032 (a) the sentinel is absent-AFTER the hook-fires branch too (never created)'
}
$HashPcAfter = Get-Sha256Hex (Join-Path $BranchA 'sdd/project-context.approval.json')
$HashPbAfter = Get-Sha256Hex (Join-Path $BranchA 'sdd/provider-bindings.approval.json')
if ($HashPcBefore -eq $HashPcAfter -and $HashPbBefore -eq $HashPbAfter) {
  Test-Pass 'TEST-032 (a) the live sidecar fixtures are byte-identical before/after (never touched)'
} else {
  Test-Fail 'TEST-032 (a) the live sidecar fixtures are byte-identical before/after'
}

# (b) hook does NOT fire, cleanup SUCCEEDS.
$BranchB = New-FixtureDir
$NonceB = 'nonce-branch-b-005'
Set-Content -LiteralPath (Join-Path $BranchB 'write.json') -NoNewline -Encoding utf8 -Value "{`"nonce`": `"$NonceB`", `"executed`": true}"
$r = Invoke-Hh -WorkDir $BranchB -ArgList @('--verify-response', '--nonce', $NonceB, '--recorded-result', 'write.json', '--runtime', 'claude-code')
Assert-Eq $r.ExitCode 63 'TEST-032 (b) hook does not fire: CAPABILITY_RUNTIME_UNAVAILABLE/WRITE_EXECUTED'
Set-Content -LiteralPath (Join-Path $BranchB 'cleanup-ok.json') -NoNewline -Encoding utf8 -Value "{`"nonce`": `"$NonceB`", `"executed`": true}"
$r = Invoke-Hh -WorkDir $BranchB -ArgList @('--confirm-cleanup', '--nonce', $NonceB, '--recorded-cleanup-result', 'cleanup-ok.json')
Assert-Eq $r.ExitCode 0 'TEST-032 (b) a recorded cleanup delete showing success -> exit 0/SENTINEL_CLEANUP_CONFIRMED'
$j = Get-OutJson $r
Assert-Eq $j.cleanup_status 'SENTINEL_CLEANUP_CONFIRMED' 'TEST-032 (b) cleanup_status is SENTINEL_CLEANUP_CONFIRMED'
Assert-Eq $j.capability_status 'CAPABILITY_RUNTIME_UNAVAILABLE' 'TEST-032 (b) the standing capability_status (from the original probe) is restated alongside the cleanup verdict'

# (c) hook does NOT fire, cleanup FAILS or is unconfirmed -- two independent
# sub-fixtures.
$BranchC1 = New-FixtureDir
$NonceC1 = 'nonce-branch-c1-006'
Set-Content -LiteralPath (Join-Path $BranchC1 'write.json') -NoNewline -Encoding utf8 -Value "{`"nonce`": `"$NonceC1`", `"executed`": true}"
Invoke-Hh -WorkDir $BranchC1 -ArgList @('--verify-response', '--nonce', $NonceC1, '--recorded-result', 'write.json', '--runtime', 'claude-code') | Out-Null
$r = Invoke-Hh -WorkDir $BranchC1 -ArgList @('--confirm-cleanup', '--nonce', $NonceC1, '--recorded-cleanup-result', 'never-recorded.json')
Assert-Eq $r.ExitCode 70 'TEST-032 (c1) no cleanup-result evidence recorded at all -> exit 70/NO_CLEANUP_RESULT'
$j = Get-OutJson $r
Assert-Eq $j.cleanup_status 'SENTINEL_CLEANUP_UNCONFIRMED' 'TEST-032 (c1) cleanup_status is SENTINEL_CLEANUP_UNCONFIRMED'
Assert-Eq $j.capability_status 'CAPABILITY_RUNTIME_UNAVAILABLE' 'TEST-032 (c1) the standing CAPABILITY_RUNTIME_UNAVAILABLE is restated alongside (independent verdicts, never retroactively changed)'

$BranchC2 = New-FixtureDir
$NonceC2 = 'nonce-branch-c2-007'
Set-Content -LiteralPath (Join-Path $BranchC2 'write.json') -NoNewline -Encoding utf8 -Value "{`"nonce`": `"$NonceC2`", `"executed`": true}"
Invoke-Hh -WorkDir $BranchC2 -ArgList @('--verify-response', '--nonce', $NonceC2, '--recorded-result', 'write.json', '--runtime', 'claude-code') | Out-Null
Set-Content -LiteralPath (Join-Path $BranchC2 'cleanup-denied.json') -NoNewline -Encoding utf8 -Value "{`"nonce`": `"$NonceC2`", `"executed`": false}"
$r = Invoke-Hh -WorkDir $BranchC2 -ArgList @('--confirm-cleanup', '--nonce', $NonceC2, '--recorded-cleanup-result', 'cleanup-denied.json')
Assert-Eq $r.ExitCode 72 "TEST-032 (c2) the cleanup delete's own attempt was denied (create-to-delete race) -> exit 72/CLEANUP_DENIED, never a privileged force-delete"
$j = Get-OutJson $r
Assert-Eq $j.reason 'CLEANUP_DENIED' 'TEST-032 (c2) CLEANUP_DENIED reason reported'

$BranchC3 = New-FixtureDir
$NonceC3 = 'nonce-branch-c3-008'
Set-Content -LiteralPath (Join-Path $BranchC3 'cleanup-stale.json') -NoNewline -Encoding utf8 -Value '{"nonce": "a-totally-different-nonce", "executed": true}'
$r = Invoke-Hh -WorkDir $BranchC3 -ArgList @('--confirm-cleanup', '--nonce', $NonceC3, '--recorded-cleanup-result', 'cleanup-stale.json')
Assert-Eq $r.ExitCode 62 'TEST-032 (c3) a cleanup-result with a MISMATCHED nonce is never confirmed -> exit 62/STALE_CHALLENGE_REJECTED'

# --- Stale-start recovery: a SEPARATE fixture. ---------------------------

$StaleStart = New-FixtureDir
New-Item -ItemType Directory -Path (Join-Path $StaleStart 'sdd') -Force | Out-Null
$StaleSentinel = Join-Path $StaleStart 'sdd/.hook-canary-sentinel'
Set-Content -LiteralPath $StaleSentinel -NoNewline -Encoding utf8 -Value 'leftover-from-a-crashed-invocation'
$StaleHashBefore = Get-Sha256Hex $StaleSentinel
$r = Invoke-Hh -WorkDir $StaleStart -ArgList @('--emit-challenge')
Assert-Eq $r.ExitCode 0 'TEST-032 stale-start: --emit-challenge with a pre-existing stale sentinel still exits 0'
$errText = Get-ErrText $r
if ($errText -match 'STALE_SENTINEL_DETECTED') {
  Test-Pass 'TEST-032 stale-start: the pre-existing stale sentinel is reported as a diagnostic (STALE_SENTINEL_DETECTED)'
} else {
  Test-Fail 'TEST-032 stale-start: the pre-existing stale sentinel is reported as a diagnostic (STALE_SENTINEL_DETECTED)' $errText
}
$j = Get-OutJson $r
Assert-Eq $j.schema 'sdd-hook-challenge/v1' 'TEST-032 stale-start: a fresh, valid challenge is still emitted regardless'
$NewNonce = $j.nonce
if ([string]::IsNullOrEmpty($NewNonce)) {
  Test-Fail 'TEST-032 stale-start: the new challenge carries a non-empty nonce'
} else {
  Test-Pass 'TEST-032 stale-start: the new challenge carries a non-empty nonce'
}
if (Test-Path -LiteralPath $StaleSentinel) {
  $StaleHashAfter = Get-Sha256Hex $StaleSentinel
  if ($StaleHashBefore -eq $StaleHashAfter) {
    Test-Pass 'TEST-032 stale-start: the stale sentinel itself is byte-identical before/after --emit-challenge (this script never touches it, only the calling skill does)'
  } else {
    Test-Fail 'TEST-032 stale-start: the stale sentinel itself is left byte-identical (it changed!)'
  }
} else {
  Test-Fail 'TEST-032 stale-start: the stale sentinel is still present after --emit-challenge (this script never deletes it itself)'
}
Set-Content -LiteralPath (Join-Path $StaleStart 'deny.json') -NoNewline -Encoding utf8 -Value "{`"nonce`": `"$NewNonce`", `"executed`": false, `"guard_emit_mode`": `"exit`", `"exit_code`": 2}"
$r = Invoke-Hh -WorkDir $StaleStart -ArgList @('--verify-response', '--nonce', $NewNonce, '--recorded-result', 'deny.json', '--runtime', 'claude-code')
Assert-Eq $r.ExitCode 0 'TEST-032 stale-start: the NEW challenge''s own probe still resolves to HOOK_ACTIVE correctly, regardless of the stale-sentinel condition at start'
$j = Get-OutJson $r
Assert-Eq $j.status 'HOOK_ACTIVE' 'TEST-032 stale-start: HOOK_ACTIVE reported for the new challenge'

# Mirror: --emit-challenge with NO pre-existing sentinel never emits the
# stale diagnostic.
$NoStale = New-FixtureDir
New-Item -ItemType Directory -Path (Join-Path $NoStale 'sdd') -Force | Out-Null
$r = Invoke-Hh -WorkDir $NoStale -ArgList @('--emit-challenge')
Assert-Eq $r.ExitCode 0 'TEST-032 no-stale: --emit-challenge with NO pre-existing sentinel exits 0'
$errText = Get-ErrText $r
if ($errText -match 'STALE_SENTINEL_DETECTED') {
  Test-Fail 'TEST-032 no-stale: no STALE_SENTINEL_DETECTED diagnostic when the sentinel is genuinely absent' $errText
} else {
  Test-Pass 'TEST-032 no-stale: no STALE_SENTINEL_DETECTED diagnostic when the sentinel is genuinely absent'
}

# --- Full-battery non-mutation proof: many invocations, one fixture dir. -

$Battery = New-FixtureDir
New-Item -ItemType Directory -Path (Join-Path $Battery 'sdd') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $Battery 'sdd/project-context.approval.json') -NoNewline -Encoding utf8 -Value 'battery project-context sidecar bytes'
Set-Content -LiteralPath (Join-Path $Battery 'sdd/provider-bindings.approval.json') -NoNewline -Encoding utf8 -Value 'battery provider-bindings sidecar bytes'
Set-Content -LiteralPath (Join-Path $Battery 'sdd/approver-registry.yaml') -NoNewline -Encoding utf8 -Value 'battery approver registry bytes'
$BatteryPcBefore = Get-Sha256Hex (Join-Path $Battery 'sdd/project-context.approval.json')
$BatteryPbBefore = Get-Sha256Hex (Join-Path $Battery 'sdd/provider-bindings.approval.json')
$BatteryRegBefore = Get-Sha256Hex (Join-Path $Battery 'sdd/approver-registry.yaml')

Invoke-Hh -WorkDir $Battery -ArgList @('--emit-challenge') | Out-Null
Set-Content -LiteralPath (Join-Path $Battery 'deny.json') -NoNewline -Encoding utf8 -Value '{"nonce": "battery-nonce", "executed": false, "guard_emit_mode": "exit", "exit_code": 2}'
Invoke-Hh -WorkDir $Battery -ArgList @('--verify-response', '--nonce', 'battery-nonce', '--recorded-result', 'deny.json', '--runtime', 'claude-code') | Out-Null
Set-Content -LiteralPath (Join-Path $Battery 'write.json') -NoNewline -Encoding utf8 -Value '{"nonce": "battery-nonce-2", "executed": true}'
Invoke-Hh -WorkDir $Battery -ArgList @('--verify-response', '--nonce', 'battery-nonce-2', '--recorded-result', 'write.json', '--runtime', 'codex-cli') | Out-Null
Set-Content -LiteralPath (Join-Path $Battery 'cleanup.json') -NoNewline -Encoding utf8 -Value '{"nonce": "battery-nonce-2", "executed": true}'
Invoke-Hh -WorkDir $Battery -ArgList @('--confirm-cleanup', '--nonce', 'battery-nonce-2', '--recorded-cleanup-result', 'cleanup.json') | Out-Null

$BatteryPcAfter = Get-Sha256Hex (Join-Path $Battery 'sdd/project-context.approval.json')
$BatteryPbAfter = Get-Sha256Hex (Join-Path $Battery 'sdd/provider-bindings.approval.json')
$BatteryRegAfter = Get-Sha256Hex (Join-Path $Battery 'sdd/approver-registry.yaml')
if ($BatteryPcBefore -eq $BatteryPcAfter -and $BatteryPbBefore -eq $BatteryPbAfter -and $BatteryRegBefore -eq $BatteryRegAfter) {
  Test-Pass 'TEST-032 battery: all three live sidecar/registry fixtures are byte-identical across a full multi-invocation battery (--emit-challenge, HOOK_ACTIVE, WRITE_EXECUTED, confirm-cleanup)'
} else {
  Test-Fail 'TEST-032 battery: all three live sidecar/registry fixtures are byte-identical across a full multi-invocation battery'
}
$BatterySentinel = Join-Path $Battery 'sdd/.hook-canary-sentinel'
if (Test-Path -LiteralPath $BatterySentinel) {
  Test-Fail 'TEST-032 battery: the sentinel itself was never created by this script across the whole battery (it is absent -- a real host tool call is the only thing that could ever create it, out of this script''s own scope)'
} else {
  Test-Pass 'TEST-032 battery: the sentinel itself was never created by this script across the whole battery'
}

# ---------------------------------------------------------------------------
# TEST-HARDEN(a..n): fail-closed exhaustiveness -- usage errors, hostile
# evidence-file inputs, never an uncaught traceback.
# ---------------------------------------------------------------------------

$THard = New-FixtureDir

$r = Invoke-Hh -WorkDir $THard -ArgList @('--verify-response', '--recorded-result', 'x.json', '--runtime', 'claude-code')
Assert-Eq $r.ExitCode 2 'TEST-HARDEN(a) --verify-response with NO --nonce -> exit 2 usage error'
Assert-NoTraceback $r 'TEST-HARDEN(a)'

$r = Invoke-Hh -WorkDir $THard -ArgList @('--verify-response', '--nonce', 'n', '--runtime', 'claude-code')
Assert-Eq $r.ExitCode 2 'TEST-HARDEN(b) --verify-response with NO --recorded-result -> exit 2 usage error'
Assert-NoTraceback $r 'TEST-HARDEN(b)'

$r = Invoke-Hh -WorkDir $THard -ArgList @('--verify-response', '--nonce', 'n', '--recorded-result', 'x.json')
Assert-Eq $r.ExitCode 2 'TEST-HARDEN(c) --verify-response with NO --runtime -> exit 2 usage error'
Assert-NoTraceback $r 'TEST-HARDEN(c)'

$r = Invoke-Hh -WorkDir $THard -ArgList @('--verify-response', '--nonce', 'n', '--recorded-result', 'x.json', '--runtime', 'not-a-real-runtime')
Assert-Eq $r.ExitCode 2 'TEST-HARDEN(d) an unrecognized --runtime value -> exit 2 usage error'
Assert-NoTraceback $r 'TEST-HARDEN(d)'

$someResult = Join-Path $THard 'some-result.json'
Set-Content -LiteralPath $someResult -NoNewline -Encoding utf8 -Value '{"nonce": "n", "executed": false, "guard_emit_mode": "exit", "exit_code": 2}'
$r = Invoke-Hh -WorkDir $THard -ArgList @('--verify-response', '--nonce', '', '--recorded-result', 'some-result.json', '--runtime', 'claude-code')
Assert-Eq $r.ExitCode 2 'TEST-HARDEN(e) an EMPTY --nonce value -> exit 2 usage error, never accepted as a trivial match'
Assert-NoTraceback $r 'TEST-HARDEN(e)'

$r = Invoke-Hh -WorkDir $THard -ArgList @('--emit-challenge', '--nonce', 'n')
Assert-Eq $r.ExitCode 2 'TEST-HARDEN(f) --emit-challenge combined with --nonce -> exit 2 usage error (takes no other arguments)'
Assert-NoTraceback $r 'TEST-HARDEN(f)'

$r = Invoke-Hh -WorkDir $THard -ArgList @('--confirm-cleanup', '--nonce', 'n', '--recorded-result', 'some-result.json', '--runtime', 'claude-code', '--recorded-cleanup-result', 'some-result.json')
Assert-Eq $r.ExitCode 2 'TEST-HARDEN(g) --confirm-cleanup combined with --recorded-result/--runtime -> exit 2 usage error'
Assert-NoTraceback $r 'TEST-HARDEN(g)'

$r = Invoke-Hh -WorkDir $THard -ArgList @('--verify-response', '--nonce', 'n', '--recorded-result', 'some-result.json', '--runtime', 'claude-code', '--recorded-cleanup-result', 'some-result.json')
Assert-Eq $r.ExitCode 2 'TEST-HARDEN(h) --verify-response combined with --recorded-cleanup-result -> exit 2 usage error'
Assert-NoTraceback $r 'TEST-HARDEN(h)'

$r = Invoke-Hh -WorkDir $THard -ArgList @('--confirm-cleanup', '--nonce', 'n')
Assert-Eq $r.ExitCode 2 'TEST-HARDEN(i) --confirm-cleanup with NO --recorded-cleanup-result -> exit 2 usage error'
Assert-NoTraceback $r 'TEST-HARDEN(i)'

$r = Invoke-Hh -WorkDir $THard -ArgList @()
Assert-Eq $r.ExitCode 2 'TEST-HARDEN(j) no mode flag at all -> exit 2 usage error (argparse''s own required mutually-exclusive-group check)'

$r = Invoke-Hh -WorkDir $THard -ArgList @('--emit-challenge', '--verify-response')
Assert-Eq $r.ExitCode 2 'TEST-HARDEN(k) two mode flags together -> exit 2 usage error (argparse''s own mutually-exclusive-group check)'

# A path with unusual characters (spaces) still resolves correctly (never a
# silent path-splitting bug) -- a positive smoke test, not a rejection.
$WeirdDir = Join-Path $THard 'weird dir name'
New-Item -ItemType Directory -Path $WeirdDir -Force | Out-Null
$WeirdFile = Join-Path $WeirdDir 'evidence with spaces.json'
Set-Content -LiteralPath $WeirdFile -NoNewline -Encoding utf8 -Value '{"nonce": "space-nonce", "executed": false, "guard_emit_mode": "exit", "exit_code": 2}'
$r = Invoke-Hh -WorkDir $THard -ArgList @('--verify-response', '--nonce', 'space-nonce', '--recorded-result', 'weird dir name/evidence with spaces.json', '--runtime', 'claude-code')
Assert-Eq $r.ExitCode 0 'TEST-HARDEN(l) an evidence path containing spaces resolves correctly -> exit 0/HOOK_ACTIVE'
Assert-NoTraceback $r 'TEST-HARDEN(l)'

# A recorded-result whose 'executed' field is present but the wrong TYPE
# (not a boolean) is rejected as unrecognized, never coerced.
$ExecutedWrongType = Join-Path $THard 'executed-wrong-type.json'
Set-Content -LiteralPath $ExecutedWrongType -NoNewline -Encoding utf8 -Value '{"nonce": "n", "executed": "false"}'
$r = Invoke-Hh -WorkDir $THard -ArgList @('--verify-response', '--nonce', 'n', '--recorded-result', 'executed-wrong-type.json', '--runtime', 'claude-code')
Assert-Eq $r.ExitCode 64 "TEST-HARDEN(m) a string 'executed' field (not boolean) -> exit 64/UNRECOGNIZED_RESULT, never coerced to a truthy/falsy denial"
Assert-NoTraceback $r 'TEST-HARDEN(m)'

# A recorded-cleanup-result whose 'executed' field is missing entirely.
$CleanupNoExecuted = Join-Path $THard 'cleanup-no-executed.json'
Set-Content -LiteralPath $CleanupNoExecuted -NoNewline -Encoding utf8 -Value '{"nonce": "n"}'
$r = Invoke-Hh -WorkDir $THard -ArgList @('--confirm-cleanup', '--nonce', 'n', '--recorded-cleanup-result', 'cleanup-no-executed.json')
Assert-Eq $r.ExitCode 71 "TEST-HARDEN(n) a recorded-cleanup-result with no 'executed' field -> exit 71/CLEANUP_RESULT_UNREADABLE"
Assert-NoTraceback $r 'TEST-HARDEN(n)'

# ---------------------------------------------------------------------------
# Self-registration (design.md Test Strategy item 11).
# ---------------------------------------------------------------------------

$RunAllSh = Get-Content -Raw -LiteralPath (Join-Path $Root 'tests/run-all.sh')
if ($RunAllSh -match 'check-hook-activation-handshake\.tests\.sh') {
  Test-Pass 'self-registration: tests/check-hook-activation-handshake.tests.sh registered in tests/run-all.sh'
} else {
  Test-Fail 'self-registration: tests/check-hook-activation-handshake.tests.sh registered in tests/run-all.sh'
}
$RunAllPs1 = Get-Content -Raw -LiteralPath (Join-Path $Root 'tests/run-all.ps1')
if ($RunAllPs1 -match 'check-hook-activation-handshake\.tests\.ps1') {
  Test-Pass 'self-registration: tests/check-hook-activation-handshake.tests.ps1 registered in tests/run-all.ps1'
} else {
  Test-Fail 'self-registration: tests/check-hook-activation-handshake.tests.ps1 registered in tests/run-all.ps1'
}

Write-Output "PASS: $script:PassCount"
Write-Output "FAIL: $script:FailCount"
if ($script:FailCount -gt 0) { exit 1 } else { exit 0 }
}
finally {
  Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}
