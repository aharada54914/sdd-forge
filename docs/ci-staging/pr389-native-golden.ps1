[CmdletBinding()]
param(
    [string]$RepositoryRoot = "/Users/jrmag/.local/share/sdd-forge-consolidation-wave1-20260905",
    [string]$PwshPath = "/opt/homebrew/bin/pwsh"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$fields = @("evidence", "red_evidence", "green_evidence")
$cases = @(
    "valid",
    "blank",
    "posix-absolute",
    "windows-drive-absolute",
    "unc-absolute",
    "traversal",
    "unresolvable",
    "missing",
    "directory",
    "empty"
)

$fixtureRoot = Join-Path $RepositoryRoot "tests/fixtures/phase2-contract-path-golden"
$liveChecker = Join-Path $RepositoryRoot "plugins/sdd-quality-loop/scripts/check-contract.ps1"

function Normalize-Lf([AllowNull()][string]$Text) {
    if ($null -eq $Text) { return "" }
    return (($Text -replace "`r`n", "`n") -replace "`r", "`n")
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-CaseValue([string]$CaseName) {
    switch ($CaseName) {
        "valid" { return "evidence/valid.log" }
        "blank" { return "" }
        "posix-absolute" { return "/tmp/phase2-contract-absolute.log" }
        "windows-drive-absolute" { return "C:\\phase2-contract-absolute.log" }
        "unc-absolute" { return "\\\\server\\share\\phase2-contract-absolute.log" }
        "traversal" { return "../phase2-contract-escape.log" }
        "unresolvable" { return "evidence/phase2$([char]0)unresolvable.log" }
        "missing" { return "evidence/missing.log" }
        "directory" { return "evidence/directory" }
        "empty" { return "evidence/empty.log" }
        default { throw "Unknown case: $CaseName" }
    }
}

function New-FixtureWorkspace([string]$Root) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Root "evidence/directory") | Out-Null
    Write-Utf8NoBom (Join-Path $Root "evidence/valid.log") "valid evidence"
    Write-Utf8NoBom (Join-Path $Root "evidence/red.log") "valid red evidence"
    Write-Utf8NoBom (Join-Path $Root "evidence/green.log") "valid green evidence"
    [System.IO.File]::WriteAllBytes((Join-Path $Root "evidence/empty.log"), [byte[]]@())
}

function New-Contract([string]$Root, [string]$FieldName, [string]$CaseName) {
    $unit = [ordered]@{
        id = "unit-tests"
        required = $true
        passes = $true
        evidence = "evidence/valid.log"
        waiver_reason = ""
        red_evidence = "evidence/red.log"
        green_evidence = "evidence/green.log"
    }
    $unit[$FieldName] = Get-CaseValue $CaseName

    $checks = @()
    foreach ($id in @("lint", "typecheck", "build", "placeholder-scan", "task-state-check")) {
        $checks += [ordered]@{
            id = $id
            required = $true
            passes = $true
            evidence = "evidence/valid.log"
            waiver_reason = ""
        }
    }
    $checks += $unit

    $contract = [ordered]@{
        task_id = "T-003-FIXTURE"
        feature = "epic-136-phase2-gates"
        required_workflow = "tdd"
        checks = $checks
    }

    $contractPath = Join-Path $Root ("contract-{0}-{1}.json" -f $FieldName, $CaseName)
    Write-Utf8NoBom $contractPath ($contract | ConvertTo-Json -Depth 6)
    return $contractPath
}

function Invoke-CheckerCaptured([string]$ScriptPath, [string]$ContractPath, [string]$RepoRoot, [string]$TempRoot) {
    $p = New-Object System.Diagnostics.ProcessStartInfo
    $p.FileName = $PwshPath
    $p.Arguments = @(
        "-NoLogo"
        "-NoProfile"
        "-ExecutionPolicy"
        "Bypass"
        "-File"
        $ScriptPath
        $ContractPath
        "-RepoRoot"
        $RepoRoot
    ) -join " "
    $p.UseShellExecute = $false
    $p.RedirectStandardOutput = $true
    $p.RedirectStandardError = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $p
    [void]$proc.Start()
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return [ordered]@{
        exit = $proc.ExitCode
        stdout = Normalize-Lf $stdout
        stderr = Normalize-Lf $stderr
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pr389-native-golden-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
$passed = 0
$failed = 0

try {
    if (-not (Test-Path -LiteralPath $liveChecker -PathType Leaf)) {
        throw "Live checker not found: $liveChecker"
    }
    if (-not (Test-Path -LiteralPath $fixtureRoot -PathType Container)) {
        throw "Fixture root not found: $fixtureRoot"
    }
    if (-not (Test-Path -LiteralPath $PwshPath -PathType Leaf)) {
        throw "pwsh not found: $PwshPath"
    }

    Write-Host "repo-root: $RepositoryRoot"
    Write-Host "pwsh: $PwshPath"
    Write-Host "live-checker: $liveChecker"

    foreach ($field in $fields) {
        foreach ($case in $cases) {
            $caseRoot = Join-Path $tempRoot ("{0}-{1}" -f $field, $case)
            New-FixtureWorkspace $caseRoot
            $contractPath = New-Contract $caseRoot $field $case
            $actual = Invoke-CheckerCaptured $liveChecker $contractPath $caseRoot $tempRoot
            $fixturePath = Join-Path $fixtureRoot ("{0}/{1}.json" -f $field, $case)
            if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) {
                $failed++
                Write-Host "FAIL $field/$case missing fixture"
                continue
            }

            $expected = Get-Content -Raw -Encoding Utf8 $fixturePath | ConvertFrom-Json
            $expectedStdout = Normalize-Lf ([string]$expected.stdout)
            $expectedStderr = Normalize-Lf ([string]$expected.stderr)
            $ok = $true
            if ([int]$expected.expected_exit -ne [int]$actual.exit) { $ok = $false }
            if ($expectedStdout -cne $actual.stdout) { $ok = $false }
            if ($expectedStderr -cne $actual.stderr) { $ok = $false }

            if ($ok) {
                $passed++
                Write-Host "ok $field/$case"
            } else {
                $failed++
                Write-Host "FAIL $field/$case"
                Write-Host "  expected exit=$($expected.expected_exit)"
                Write-Host "  actual   exit=$($actual.exit)"
                if ($expectedStdout -cne $actual.stdout) {
                    Write-Host "  stdout mismatch"
                }
                if ($expectedStderr -cne $actual.stderr) {
                    Write-Host "  stderr mismatch"
                }
            }
        }
    }
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

Write-Host "pr389-native-golden.ps1: $passed passed, $failed failed"
if ($failed -gt 0) { exit 1 }
