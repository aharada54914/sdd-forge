# Native Windows qualification; the selected engine must also host children.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repositoryRoot 'plugins/sdd-quality-loop/scripts/lib/native-arguments.ps1')

$expected = $env:SDD_EXPECTED_POWERSHELL
if ($expected -notin @('5.1', '7.6')) { throw 'Expected PowerShell version must be 5.1 or 7.6' }
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'Native Windows is required' }
if (-not [Environment]::Is64BitProcess) { throw 'A 64-bit PowerShell host is required' }
if (('{0}.{1}' -f $PSVersionTable.PSVersion.Major, $PSVersionTable.PSVersion.Minor) -cne $expected) {
    throw 'Unexpected parent PowerShell version'
}
$edition = if ($expected -eq '5.1') { 'Desktop' } else { 'Core' }
if ($PSVersionTable.PSEdition -cne $edition) { throw 'Unexpected PowerShell edition' }
$hostPath = (Get-Process -Id $PID).Path
$identityCode = @'
[pscustomobject]@{
    version = $PSVersionTable.PSVersion.ToString()
    edition = $PSVersionTable.PSEdition
    executable = (Get-Process -Id $PID).Path
    windows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
    bits = [IntPtr]::Size * 8
    clr = [Environment]::Version.ToString()
} | ConvertTo-Json -Compress
'@
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($identityCode))
Write-Host "Native identity probe: $hostPath ($($PSVersionTable.PSVersion))"
$child = Invoke-SddNativeRaw -FileName $hostPath -Arguments @('-NoProfile', '-NonInteractive', '-EncodedCommand', $encoded)
if ($child.ExitCode -ne 0) { throw 'Child runtime probe failed' }
$identity = [Text.Encoding]::UTF8.GetString($child.Stdout) | ConvertFrom-Json
if ($identity.version -cne $PSVersionTable.PSVersion.ToString() -or
    $identity.edition -cne $edition -or $identity.executable -ine $hostPath -or
    -not $identity.windows -or $identity.bits -ne 64) { throw 'Child runtime does not match its parent' }
$revision = & git -C $repositoryRoot rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Unable to identify tested commit' }
$receipt = [ordered]@{
    schema = 'windows-powershell-runtime/v1'
    revision = $revision
    workflow_revision = $env:GITHUB_SHA
    expected = $expected
    parent = @{ version = $PSVersionTable.PSVersion.ToString(); edition = $edition; executable = $hostPath }
    child = $identity
    os = [Environment]::OSVersion.VersionString
    image = $env:ImageVersion
}
if ($env:GITHUB_SHA -and $revision -cne $env:GITHUB_SHA) { throw 'Checkout does not match the workflow revision' }
$json = $receipt | ConvertTo-Json -Depth 5
Write-Host $json
if ($env:SDD_POWERSHELL_RECEIPT) {
    [IO.File]::WriteAllText($env:SDD_POWERSHELL_RECEIPT, $json, [Text.UTF8Encoding]::new($false))
}

# Common product contracts already run in the required PowerShell 7 jobs.
if ($expected -eq '7.6') { exit 0 }
# ZIP extraction uses different .NET implementations on Desktop and Core.
# Core coverage comes from the existing installer suite; only these transport
# boundaries are repeated on Desktop, using this exact native host for children.
$payloadPython = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $payloadPython) { $payloadPython = Get-Command python -ErrorAction Stop }
$previousPwsh = $env:PWSH
try {
    $env:PWSH = $hostPath
    & $payloadPython.Source (Join-Path $PSScriptRoot 'lib/install-payload-check.py') --runtime powershell `
        PayloadChecks.test_tracked_special_names_survive_local_and_archive `
        PayloadChecks.test_windows_zip_metadata_and_containment `
        PayloadChecks.test_windows_zip_directory_link_metadata
    if ($LASTEXITCODE -ne 0) { throw 'Native Windows ZIP boundaries failed.' }
}
finally { $env:PWSH = $previousPwsh }
$focused = Invoke-SddNativeRaw -FileName $hostPath -Arguments @(
    '-NoProfile', '-NonInteractive', '-File', (Join-Path $PSScriptRoot 'prepare-panelist.tests.ps1'),
    '-RuntimeBoundariesOnly'
) -TimeoutMilliseconds 120000
Write-Host ([Text.Encoding]::UTF8.GetString($focused.Stdout))
if ($focused.ExitCode -ne 0) {
    throw ('Panelist runtime boundaries failed: ' + [Text.Encoding]::UTF8.GetString($focused.Stderr))
}

# Only Desktop repeats these transport boundaries: Core already runs the full
# policy/renderer contracts. Pin the test entrypoints to the host checked above.
$previousPolicyPwsh = $env:SDD_TEST_PWSH
$previousPolicyBackend = $env:SDD_TEST_POLICY_BACKEND
try {
    $env:SDD_TEST_PWSH = $hostPath
    $env:SDD_TEST_POLICY_BACKEND = 'powershell'
    & $payloadPython.Source -B (Join-Path $PSScriptRoot 'model-policy.tests.py') PolicySelection.test_wrapper_policy_smoke
    if ($LASTEXITCODE -ne 0) { throw 'Desktop managed selector bridge smoke failed.' }
} finally {
    $env:SDD_TEST_PWSH = $previousPolicyPwsh
    $env:SDD_TEST_POLICY_BACKEND = $previousPolicyBackend
}
$managedScratch = Join-Path ([IO.Path]::GetTempPath()) ('sdd managed Desktop ' + [guid]::NewGuid())
[void][IO.Directory]::CreateDirectory($managedScratch)
$managedTarget = Join-Path $repositoryRoot 'plugins/sdd-quality-loop/agents/evaluator.md'
$managedTargetHash = (Get-FileHash -LiteralPath $managedTarget -Algorithm SHA256).Hash
try {
    $selectorPath = (Join-Path $repositoryRoot 'plugins/sdd-implementation/scripts/select-agent-model.ps1').Replace("'", "''")
    $rendererPath = (Join-Path $repositoryRoot 'render-agent-frontmatter.ps1').Replace("'", "''")
    foreach ($case in @(
        @{ Name = 'empty policy input'; Message = 'Policy input'; Code = "& '$selectorPath' -PolicyInput ''" },
        @{ Name = 'empty managed root'; Message = '--root'; Code = "& '$rendererPath' -RepoRoot '' -ModelControls fixture.json -ModelControlsSha256 $('a' * 64) -RunId fixture-run -SessionId fixture-session -ManagedTarget plugins/sdd-quality-loop/agents/evaluator.md" }
    )) {
        # EncodedCommand preserves explicitly empty script parameters on Desktop;
        # the renderer must then preserve that empty value in its Python argv.
        $code = "Set-Location -LiteralPath '" + $managedScratch.Replace("'", "''") + "'; " + $case.Code + '; exit $LASTEXITCODE'
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
        $boundary = Invoke-SddNativeRaw -FileName $hostPath -Arguments @('-NoProfile', '-NonInteractive', '-EncodedCommand', $encoded)
        $stderr = [Text.Encoding]::UTF8.GetString($boundary.Stderr)
        if ($boundary.ExitCode -ne 2 -or $boundary.Stdout.Length -ne 0) {
            throw "Desktop $($case.Name) did not fail closed: $stderr"
        }
        $errorRecord = $stderr | ConvertFrom-Json
        if ($errorRecord.schema -cne 'model-policy-error/v1' -or $errorRecord.reason -cne 'input-invalid' -or
            -not $errorRecord.message.Contains($case.Message)) {
            throw "Desktop $($case.Name) did not return its typed boundary error: $stderr"
        }
        if (@(Get-ChildItem -LiteralPath $managedScratch -Force).Count -ne 0 -or
            (Get-FileHash -LiteralPath $managedTarget -Algorithm SHA256).Hash -cne $managedTargetHash) {
            throw "Desktop $($case.Name) modified the working directory or managed target"
        }
        Write-Host "ok: Desktop $($case.Name) preserves typed refusal without writes"
    }
} finally {
    Remove-Item -LiteralPath $managedScratch -Recurse -Force
}

$work = Join-Path ([IO.Path]::GetTempPath()) ('sdd native install ' + [guid]::NewGuid())
$installRoot = Join-Path $work 'installed'
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $master = Join-Path $work 'dispatch master.py'
    [IO.File]::WriteAllText($master, @'
import sys
if sys.argv[1:] != ["space atom", 'quote"atom', "trailing\\", ""]:
    raise SystemExit(99)
sys.stdout.buffer.write(b"raw\x00bytes\n")
sys.stderr.buffer.write(b"diagnostic")
raise SystemExit(7)
'@)
    $dispatchCode = @'
. '__DISPATCH__'
Invoke-SddPyDispatch -Master '__MASTER__' -DiagnosticPrefix fixture -Arguments @('space atom', 'quote"atom', 'trailing\', '')
'@
    $dispatchCode = $dispatchCode.Replace('__DISPATCH__', (Join-Path $repositoryRoot 'plugins/sdd-quality-loop/scripts/lib/py-dispatch.ps1').Replace("'", "''")).Replace('__MASTER__', $master.Replace("'", "''"))
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($dispatchCode))
    $dispatch = Invoke-SddNativeRaw -FileName $hostPath -Arguments @('-NoProfile', '-NonInteractive', '-EncodedCommand', $encoded)
    if ($dispatch.ExitCode -ne 7 -or [Convert]::ToBase64String($dispatch.Stdout) -cne 'cmF3AGJ5dGVzCg==' -or
        [Text.Encoding]::UTF8.GetString($dispatch.Stderr) -cne 'diagnostic') { throw "Framework Python dispatch changed argv, raw bytes or exit status (exit=$($dispatch.ExitCode); stdout64=$([Convert]::ToBase64String($dispatch.Stdout)); stderr=$([Text.Encoding]::UTF8.GetString($dispatch.Stderr)))" }
    Write-Host 'ok: Framework Python dispatch preserves argv, raw streams and nonzero status'
    foreach ($attempt in 1..2) {
        $result = Invoke-SddNativeRaw -FileName $hostPath -Arguments @(
            '-NoProfile', '-NonInteractive', '-File', (Join-Path $repositoryRoot 'install.ps1'),
            '-SourceDirectory', $repositoryRoot, '-InstallRoot', $installRoot,
            '-Target', 'FilesOnly', '-SkipMcp', '-SkipAgentInstall', '-SkipPluginInstall'
        ) -TimeoutMilliseconds 120000
        if ($result.ExitCode -ne 0) {
            throw ('FilesOnly install failed: ' + [Text.Encoding]::UTF8.GetString($result.Stderr))
        }
        foreach ($path in @('.agents/plugins/marketplace.json', 'plugins/sdd-bootstrap/.codex-plugin/plugin.json')) {
            if (-not (Test-Path -LiteralPath (Join-Path $installRoot $path))) { throw "Missing installed file: $path" }
        }
        Write-Host "ok: FilesOnly install attempt $attempt uses PowerShell $expected"
    }
    $result = Invoke-SddNativeRaw -FileName $hostPath -Arguments @(
        '-NoProfile', '-NonInteractive', '-File', (Join-Path $repositoryRoot 'uninstall.ps1'),
        '-InstallRoot', $installRoot, '-Target', 'FilesOnly',
        '-SkipMcpUninstall', '-SkipAgentUninstall', '-SkipPluginUninstall'
    ) -TimeoutMilliseconds 120000
    if ($result.ExitCode -ne 0 -or (Test-Path -LiteralPath $installRoot)) { throw 'FilesOnly uninstall failed' }
    Write-Host "ok: FilesOnly uninstall uses PowerShell $expected"
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force
}
