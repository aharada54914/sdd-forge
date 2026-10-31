$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Run the suite's real receipt parsing and assertions without launching a CLI.
$suitePath = Join-Path $PSScriptRoot 'cross-model.tests.ps1'
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($suitePath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'Cross-model suite parse failed' }
foreach ($name in @('Test-BoundaryTiming', 'Assert-ProcessObservation')) {
    $functions = @($ast.FindAll({ param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $name
    }, $true))
    if ($functions.Count -ne 1) { throw "Expected one suite function: $name" }
    . ([scriptblock]::Create($functions[0].Extent.Text))
}
$phaseReads = @($ast.FindAll({ param($node)
    $node -is [Management.Automation.Language.IfStatementAst] -and
    $node.Clauses[0].Item1.Extent.Text -ceq 'Test-Path -LiteralPath $phaseFile'
}, $true))
if ($phaseReads.Count -ne 1) { throw 'Expected one boundary phase reader' }
$statements = @($phaseReads[0].Parent.Statements)
$first = [array]::IndexOf($statements, $phaseReads[0])
$last = $first
while ($last -lt $statements.Count -and
    -not $statements[$last].Extent.Text.StartsWith('Assert-ProcessObservation -Name "normal', [StringComparison]::Ordinal)) { $last++ }
if ($last -eq $statements.Count) { throw 'Boundary process assertion not found' }
$body = [scriptblock]::Create(($statements[$first..$last].Extent.Text -join "`n"))

$fixture = Join-Path ([IO.Path]::GetTempPath()) ('sdd-empty-phase-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $fixture | Out-Null
try {
    $phaseFile = Join-Path $fixture 'empty.phases'
    New-Item -ItemType File -Path $phaseFile | Out-Null
    function Ok { param([string]$Name) $script:observedPasses.Add($Name) }
    function Fail { param([string]$Name) $script:observedFailures.Add($Name) }
    foreach ($completed in @($false, $true)) {
        $script:observedPasses = [Collections.Generic.List[string]]::new()
        $script:observedFailures = [Collections.Generic.List[string]]::new()
        $runner = @{ Name = 'fixture' }
        $iteration = 1
        $parsedDeadline = [long]2000
        $outputDelayMs = 500
        $waitEnd = $outputEnd = $observedAt = [long]0
        $verdict = Join-Path $fixture "verdict-$completed.json"
        if ($completed) { New-Item -ItemType File -Path $verdict | Out-Null }
        $script:panelistExit = [int](-not $completed)
        $script:panelistOutput = "panelist-process: pid=1 wait_completed=$([int]$completed) observed_at=2000 observed_exited=$([int]$completed) cleanup_kill=$([int](-not $completed))"
        $detail = "exit=$script:panelistExit synthetic empty phase log"
        $messages = @(. $body 6>&1)
        # Reaching this assertion proves the boundary block did not abort.
        $expectedFailures = if ($completed) { 1 } else { 2 }
        if ($waitEnd -ne 0 -or $outputEnd -ne 0 -or $completionTiming -or
            $script:observedFailures.Count -ne $expectedFailures -or
            $script:observedPasses.Count -ne [int]$completed -or
            ($messages | Out-String) -cnotmatch 'runner diagnostic: panelist-process:') {
            throw "Empty phase log must fail missing evidence and continue process checks (completed=$completed)"
        }
        Write-Host "ok: empty phase log reports ordinary FAIL and continues (completed=$completed)"
    }
} catch {
    Write-Host "fail: empty phase regression: $($_.Exception.Message)"
    exit 1
} finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force
}
exit 0
