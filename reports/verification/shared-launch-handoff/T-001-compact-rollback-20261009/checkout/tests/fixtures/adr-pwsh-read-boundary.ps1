# Human-applied test observer. Never copies or rewrites validator code.
param(
    [Parameter(Mandatory=$true)][string]$FixtureRoot,
    [Parameter(Mandatory=$true)][ValidateSet('control','poison','early-poison')][string]$Mode
)
$ErrorActionPreference = 'Stop'
if (Get-Variable -Name AdrBoundaryObserver -Scope Global -ErrorAction SilentlyContinue) { throw 'Observer state already exists' }
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$validator = Join-Path $repo 'plugins/sdd-quality-loop/scripts/check-workflow-state.ps1'
$fixture = [IO.Path]::GetFullPath($FixtureRoot)
if ($fixture -eq $repo -or $fixture.StartsWith($repo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Observer requires isolated fixture DATA outside the repository'
}
function Assert-ObserverFile([string]$Path) {
    $cursor = [IO.Path]::GetFullPath($Path)
    if (-not [IO.File]::Exists($cursor)) { throw 'Observer input is not a file' }
    while ($cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Observer input has a linked component'
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}
$registry = Join-Path $fixture 'specs/workflow-state-registry.json'
$target = Join-Path $fixture 'reports/impl-review/workflow-state-integrity/attempt-1/round-2/precheck-result.json'
$receipt = Join-Path $fixture 'pwsh-boundary-receipt.json'
Assert-ObserverFile $validator
Assert-ObserverFile $registry
Assert-ObserverFile $target
if (Test-Path -LiteralPath $receipt) { throw 'Observer receipt already exists' }
$registryData = Get-Content -LiteralPath $registry -Raw | ConvertFrom-Json
if (@($registryData.entries).Count -ne 1 -or $registryData.entries[0].feature -cne 'workflow-state-integrity') {
    throw 'Observer requires the single-feature fixture registry'
}
$validatorHash = (Get-FileHash -LiteralPath $validator -Algorithm SHA256).Hash
$lines = [IO.File]::ReadAllLines($validator)
$anchor = '    $calibrationRelative = if ($Stage -eq "spec") {'
$locations = @(for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -ceq $anchor) { $i + 1 }
})
if ($locations.Count -ne 1) { throw 'Observer read boundary is not unique' }
$state = @{
    schema = 'adr-pwsh-boundary/v1'; mode = $Mode; hits = 0
    validator = $validator; validator_sha256 = $validatorHash.ToLowerInvariant()
    line = $locations[0]; target = $target; receipt = $receipt
    before = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    after = ''; changed = $false
    completed = $false; observer_ok = $false; child_exit = $null
}
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($receipt, ($state | ConvertTo-Json -Depth 4), $utf8)
if ($Mode -ceq 'early-poison') {
    [IO.File]::WriteAllText($target, '{', $utf8)
    $state.after = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    $state.changed = $state.before -cne $state.after
    [IO.File]::WriteAllText($receipt, ($state | ConvertTo-Json -Depth 4), $utf8)
}
$action = {
    # Read execution context only. Do not alter validator variables/results.
    $state = $global:AdrBoundaryObserver
    if ($Stage -ceq 'impl' -and $Feature -ceq 'workflow-state-integrity') {
        $state.hits++
        if ($state.hits -ne 1) { throw 'Observer boundary repeated' }
        if ($state.mode -ceq 'poison') {
            [IO.File]::WriteAllText($state.target, '{')
        }
        $state.after = (Get-FileHash -LiteralPath $state.target -Algorithm SHA256).Hash.ToLowerInvariant()
        $state.changed = $state.before -cne $state.after
        [IO.File]::WriteAllText($state.receipt, ($state | ConvertTo-Json -Depth 4))
    }
}
$global:AdrBoundaryObserver = $state
$breakpoint = Set-PSBreakpoint -Script $validator -Line $locations[0] -Action $action
$result = 1
try {
    $LASTEXITCODE = $null
    & $validator --registry $registry --feature workflow-state-integrity --opening spec:1:3
    $result = $LASTEXITCODE
    if ($null -eq $result -or $result -isnot [int]) { throw 'Validator exit was not observed' }
} finally {
    Remove-PSBreakpoint -Breakpoint $breakpoint
    Remove-Variable -Name AdrBoundaryObserver -Scope Global
    if ((Get-FileHash -LiteralPath $validator -Algorithm SHA256).Hash -cne $validatorHash) {
        throw 'Original validator changed during observation'
    }
}
# Completion is recorded only after invocation returned and cleanup/hash checks succeeded.
$state.completed = $true
$state.observer_ok = $true
$state.child_exit = $result
[IO.File]::WriteAllText($receipt, ($state | ConvertTo-Json -Depth 4), $utf8)
# The parent test must require exactly one hit for control/poison, zero for
# early-poison, correct before/after digests and the expected child exit.
# Every case, including expected rejection, requires completed/observer_ok=true
# and integer child_exit equal to the actual process exit, never wrapper failure.
# A debugger capability failure or absent receipt is a test failure, not SKIP.
exit $result
