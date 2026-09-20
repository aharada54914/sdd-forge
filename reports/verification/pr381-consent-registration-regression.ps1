$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$source = Get-Content -Raw (Join-Path $root 'tests/design-sync-standing-consent.tests.ps1')
$start = $source.IndexOf('if ($registrationExit -eq 0')
if ($start -lt 0) { throw 'Registration predicate not found' }
$end = $source.IndexOf('# --- REQ-001', $start)
if ($end -lt 0) { throw 'Registration predicate boundary not found' }
$predicate = [scriptblock]::Create($source.Substring($start, $end - $start))
function Test-Pass([string]$label) { $script:accepted = $true }
function Test-Fail([string]$label) { $script:accepted = $false }
$target = 'tests/design-sync-standing-consent.tests.sh'
$cases = @(
    @{ Name = 'exact registration'; Lines = @($target); Code = 0; Ps = $true; Want = $true },
    @{ Name = 'missing registration'; Lines = @('tests/other.tests.sh'); Code = 0; Ps = $true; Want = $false },
    @{ Name = 'case mismatch'; Lines = @($target.ToUpperInvariant()); Code = 0; Ps = $true; Want = $false },
    @{ Name = 'prefix mismatch'; Lines = @('prefix/' + $target); Code = 0; Ps = $true; Want = $false },
    @{ Name = 'suffix mismatch'; Lines = @($target + '.disabled'); Code = 0; Ps = $true; Want = $false },
    @{ Name = 'failed listing with matching output'; Lines = @($target); Code = 1; Ps = $true; Want = $false },
    @{ Name = 'missing PowerShell registration'; Lines = @($target); Code = 0; Ps = $false; Want = $false }
)
foreach ($case in $cases) {
    $registeredSuites = $case.Lines
    $registrationExit = $case.Code
    $runAllPs1Text = if ($case.Ps) { 'tests/design-sync-standing-consent.tests.ps1' } else { '' }
    $script:accepted = $null
    . $predicate
    if ($script:accepted -ne $case.Want) { throw "Unexpected verdict: $($case.Name)" }
    Write-Output "PASS: $($case.Name)"
}
