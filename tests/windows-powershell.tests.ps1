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
$focused = Invoke-SddNativeRaw -FileName $hostPath -Arguments @(
    '-NoProfile', '-NonInteractive', '-File', (Join-Path $PSScriptRoot 'prepare-panelist.tests.ps1'),
    '-RuntimeBoundariesOnly'
) -TimeoutMilliseconds 120000
Write-Host ([Text.Encoding]::UTF8.GetString($focused.Stdout))
if ($focused.ExitCode -ne 0) {
    throw ('Panelist runtime boundaries failed: ' + [Text.Encoding]::UTF8.GetString($focused.Stderr))
}

$work = Join-Path ([IO.Path]::GetTempPath()) ('sdd native install ' + [guid]::NewGuid())
$installRoot = Join-Path $work 'installed'
New-Item -ItemType Directory -Path $work | Out-Null
try {
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
