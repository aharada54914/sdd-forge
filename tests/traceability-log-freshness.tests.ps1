# T-004 (epic-193-a5-capability-resolver) confirmation-panel remediation
# (third recurrence of this exact staleness class -- see this task's own
# implementation report, "Traceability-log staleness, third recurrence").
# PowerShell twin of traceability-log-freshness.tests.sh; see that file's
# own header comment for the full scope-note/rationale disclosure (why a
# machine-readable trailer convention was chosen over parsing free prose).
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Root

$Script:Pass = 0
$Script:Fail = 0

function Test-Ok([string]$Label) {
    $Script:Pass++
    Write-Output "PASS: $Label"
}

function Test-Bad([string]$Label) {
    $Script:Fail++
    Write-Output "FAIL: $Label"
}

$QgDir = 'specs/epic-193-a5-capability-resolver/verification/qg'
$FoundAny = $false

Get-ChildItem -Path $QgDir -Directory -Filter 'T-0*' -ErrorAction SilentlyContinue | ForEach-Object {
    $LogPath = Join-Path $_.FullName 'traceability.log'
    if (-not (Test-Path $LogPath)) { return }
    $Text = Get-Content -Path $LogPath -Raw
    $Match = [regex]::Match($Text, '(?m)^TRACEABILITY-LOG-LIVE-TOTAL:\s*driver=(\S+)\s+result="([^"]*)"')
    if (-not $Match.Success) { return }
    $Script:FoundAny = $true
    $Driver = $Match.Groups[1].Value
    $Expected = $Match.Groups[2].Value
    # The trailer always cites the .sh sibling (this convention's own
    # canonical spelling); this twin swaps to the identical driver's own
    # .ps1 sibling so each runtime independently re-runs ITS OWN
    # dispatcher, never shelling out cross-runtime.
    $DriverPs1 = [regex]::Replace($Driver, '\.tests\.sh$', '.tests.ps1')
    $DriverPath = Join-Path $Root $DriverPs1
    if (-not (Test-Path $DriverPath)) {
        Test-Bad "$LogPath : cited driver's own .ps1 sibling does not exist: $DriverPs1"
        return
    }
    $Output = & pwsh -File $DriverPath 2>$null
    $Actual = ($Output | Select-Object -Last 1)
    if ($Actual -eq $Expected) {
        Test-Ok "$LogPath : cited RESULT ('$Expected') matches a live re-run of $Driver"
    } else {
        Test-Bad "$LogPath : cited RESULT ('$Expected') does NOT match a live re-run of $Driver (got: '$Actual') -- this traceability.log is STALE, re-run and re-cite it"
    }
}

if (-not $FoundAny) {
    Test-Bad "no traceability.log under $QgDir/T-0*/ carries a TRACEABILITY-LOG-LIVE-TOTAL trailer -- this check would be vacuous"
}

Write-Output "RESULT: $Script:Pass passed, $Script:Fail failed"
if ($Script:Fail -ne 0) { exit 1 }
exit 0
