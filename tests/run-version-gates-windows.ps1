# Run the Windows-only version-gate suites in independent lanes.
# Each lane remains sequential so a suite's own fixture assumptions are
# unchanged; the lanes run concurrently to reduce wall-clock time.
param(
    [ValidateSet('all', 'governance', 'capability', 'ownership', 'lite')]
    [string]$Lane = 'all'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$pwshPath = (Get-Command pwsh -ErrorAction Stop).Source

$lanes = [ordered]@{
    governance = @(
        'release-loop-gate.tests.ps1',
        'model-freshness-check.tests.ps1',
        'project-context-schema.tests.ps1',
        'approver-registry-schema.tests.ps1',
        'canonicalize-sdd-yaml.tests.ps1',
        'generate-approval-sidecar.tests.ps1',
        'detect-policy-weakening.tests.ps1',
        'validate-approval-sidecar.tests.ps1',
        'apply-human-copy.tests.ps1',
        'check-hook-activation-handshake.tests.ps1',
        'guard-invariants-epic-a1.tests.ps1'
    )
    capability = @(
        'hook-guard-epic-a1-boundary.tests.ps1',
        'plugin-contracts-track-selection.tests.ps1',
        'ship-track-selection-migration.tests.ps1',
        'capability-registry-schema.tests.ps1',
        'evaluate-predicate.tests.ps1',
        'registry-discovery.tests.ps1',
        'validate-capability-registry.tests.ps1',
        'generate-registry-digest.tests.ps1',
        'generate-gate-capabilities.tests.ps1',
        'capability-registry-parity.tests.ps1'
    )
    ownership = @(
        'component-path-resolver.tests.ps1',
        'component-path-diff-basis.tests.ps1',
        'ownership-digest.tests.ps1',
        'check-component-coverage.tests.ps1',
        'component-path-ownership-parity.tests.ps1'
    )
    lite = @(
        'human-copy-runner-contract.tests.ps1',
        'check-risk-upgrade-byte-identical.tests.ps1',
        'check-risk-upgrade-capability-merge.tests.ps1',
        'check-risk-upgrade-fragment-fail-closed.tests.ps1',
        'check-risk-upgrade-ineligible-no-reasons.tests.ps1',
        'lite-spec-capability-block.tests.ps1',
        'lite-gate-summary-consumption.tests.ps1',
        'lite-gate-summary-absent.tests.ps1',
        'lite-gate-summary-invalid.tests.ps1',
        'lite-gate-full-upgrade-backstop.tests.ps1',
        'lite-gate-summary-absent-active-enforcement.tests.ps1'
    )
}

function Invoke-Lane([string]$Name) {
    Write-Output "=== Windows version-gates lane: $Name ==="
    foreach ($suite in $lanes[$Name]) {
        $path = Join-Path $repoRoot "tests/$suite"
        Write-Output "--- $suite ---"
        & $pwshPath -NoProfile -NonInteractive -File $path
        if ($LASTEXITCODE -ne 0) {
            throw "Windows version-gates suite failed: $suite (exit $LASTEXITCODE)"
        }
    }
    Write-Output "=== Windows version-gates lane passed: $Name ==="
}

if ($Lane -ne 'all') {
    Invoke-Lane $Lane
    exit 0
}

$runnerTemp = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$logRoot = Join-Path $runnerTemp 'version-gates-windows-lanes'
$processes = @{}
$logs = @{}
$launchError = $null
$deadline = [DateTime]::UtcNow.AddMinutes(35)
try {
    foreach ($name in $lanes.Keys) {
        $stdout = "$logRoot-$name.out"
        $stderr = "$logRoot-$name.err"
        $logs[$name] = @{ stdout = $stdout; stderr = $stderr }
        $processes[$name] = Start-Process -FilePath $pwshPath `
            -ArgumentList @('-NoProfile', '-NonInteractive', '-File', $PSCommandPath, '-Lane', $name) `
            -WorkingDirectory $repoRoot `
            -RedirectStandardOutput $stdout `
            -RedirectStandardError $stderr `
            -PassThru
    }
    while (@($processes.Values | Where-Object { -not $_.HasExited }).Count -gt 0) {
        if ([DateTime]::UtcNow -ge $deadline) {
            throw 'Windows version-gates lanes timed out after 35 minutes'
        }
        Start-Sleep -Seconds 1
    }
} catch {
    $launchError = $_
} finally {
    foreach ($process in $processes.Values) {
        if (-not $process.HasExited) {
            try { $process.Kill($true) } catch { $process.Kill() }
            $process.WaitForExit()
        }
    }
}

$failed = @()
foreach ($name in $lanes.Keys) {
    Write-Output "=== Windows version-gates output: $name ==="
    $stdout = $logs[$name].stdout
    $stderr = $logs[$name].stderr
    if (Test-Path -LiteralPath $stdout) { Get-Content -LiteralPath $stdout }
    if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr }
    $process = $processes[$name]
    if ($launchError -or -not $process -or $process.ExitCode -ne 0) {
        $exit = if ($process) { $process.ExitCode } else { 'not-started' }
        $failed += "$name (exit $exit)"
    }
}
if ($launchError) { throw $launchError }
if ($failed.Count -gt 0) {
    throw "Windows version-gates failed: $($failed -join ', ')"
}
Write-Output 'All Windows version-gates lanes passed.'
