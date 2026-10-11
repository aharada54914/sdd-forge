$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $PSScriptRoot 'run-all.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'run-all.ps1 syntax invalid' }
$loops = @($ast.FindAll({ param($node)
    $node -is [System.Management.Automation.Language.ForEachStatementAst] -and
    $node.Condition.Extent.Text.Contains('tests/quality-nontty-transport.tests.py')
}, $true))
if ($loops.Count -ne 1) { throw 'expected exactly one Python suite loop' }
$loop = [scriptblock]::Create($loops[0].Extent.Text)

function Get-Command {
    param($Name, $ErrorAction)
    $script:lookups += $Name
    if ($Name -ceq $script:available) { [pscustomobject]@{ Source = 'Invoke-FixturePython' } }
}
function Invoke-FixturePython {
    param([switch]$B, $Path)
    if (-not $B -or -not $Path.EndsWith('.tests.py')) { throw 'Python arguments changed' }
    $script:calls++
    $global:LASTEXITCODE = $script:code
}

foreach ($case in @(
    @{ Available = 'python3'; Code = 0; Failures = 0; Calls = 4; Lookups = 4 },
    @{ Available = 'python'; Code = 0; Failures = 0; Calls = 4; Lookups = 8 },
    @{ Available = ''; Code = 0; Failures = 4; Calls = 0; Lookups = 8 },
    @{ Available = 'python3'; Code = 9; Failures = 4; Calls = 4; Lookups = 4 }
)) {
    $script:available = $case.Available
    $script:code = $case.Code
    $script:calls = 0
    $script:lookups = @()
    $failed = @()
    . $loop
    if ($failed.Count -ne $case.Failures -or $script:calls -ne $case.Calls -or
        $script:lookups.Count -ne $case.Lookups) { throw "Python runner case failed: $($case.Available)/$($case.Code)" }
}
Write-Host 'PASS: Python runner preference, fallback, missing runtime, and failing suites (4 cases)'
