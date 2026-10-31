[CmdletBinding()]
param(
    [string]$CandidatePath,
    [switch]$CaptureGolden
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$expectedCandidatePath = Join-Path $repositoryRoot "specs/epic-136-phase2-gates/human-copy/plugins/sdd-quality-loop/scripts/check-contract.ps1"
if ([string]::IsNullOrWhiteSpace($CandidatePath)) {
    $CandidatePath = $expectedCandidatePath
}

$fixtureRoot = Join-Path $repositoryRoot "tests/fixtures/phase2-contract-path-golden"
$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("phase2-contract-path-" + [guid]::NewGuid().ToString("N"))
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
$script:passed = 0
$script:failed = 0

function Pass([string]$Message) {
    $script:passed++
    Write-Host "ok: $Message"
}

function Fail([string]$Message) {
    $script:failed++
    Write-Host "FAIL: $Message"
}

function Normalize-Lf([AllowNull()][string]$Text) {
    if ($null -eq $Text) {
        return ""
    }
    return (($Text -replace "`r`n", "`n") -replace "`r", "`n")
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-CaseValue([string]$CaseName) {
    switch ($CaseName) {
        "valid"                 { return "evidence/valid.log" }
        "blank"                 { return "" }
        "posix-absolute"        { return "/tmp/phase2-contract-absolute.log" }
        "windows-drive-absolute" { return "C:\\phase2-contract-absolute.log" }
        "unc-absolute"          { return "\\\\server\\share\\phase2-contract-absolute.log" }
        "traversal"             { return "../phase2-contract-escape.log" }
        "unresolvable"          { return "evidence/phase2$([char]0)unresolvable.log" }
        "missing"               { return "evidence/missing.log" }
        "directory"             { return "evidence/directory" }
        "empty"                 { return "evidence/empty.log" }
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

function Assert-ReparsePoint([string]$Name, [string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    $isReparsePoint = (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
    if ($isReparsePoint) {
        Pass "$Name is a FileAttributes.ReparsePoint fixture"
    } else {
        Fail "$Name must be a FileAttributes.ReparsePoint fixture"
    }
}

function New-ReparseFixture([string]$Root, [string]$CaseName) {
    New-FixtureWorkspace $Root
    $outside = Join-Path (Split-Path -Parent $Root) ("phase2-contract-outside-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $outside | Out-Null
    $outsideFile = Join-Path $outside "escape.log"
    Write-Utf8NoBom $outsideFile "outside evidence"

    switch ($CaseName) {
        "intermediate-junction" {
            $junction = Join-Path $Root "evidence/intermediate-junction"
            New-Item -ItemType Junction -Path $junction -Target $outside -ErrorAction Stop | Out-Null
            Assert-ReparsePoint "intermediate junction" $junction
            return [pscustomobject]@{
                Evidence = "evidence/intermediate-junction/escape.log"
                ReparsePath = $junction
            }
        }
        "final-file-reparse" {
            $link = Join-Path $Root "evidence/final-file-reparse.log"
            New-Item -ItemType SymbolicLink -Path $link -Target $outsideFile -ErrorAction Stop | Out-Null
            Assert-ReparsePoint "final file symbolic link" $link
            return [pscustomobject]@{
                Evidence = "evidence/final-file-reparse.log"
                ReparsePath = $link
            }
        }
        default { throw "Unknown reparse fixture case: $CaseName" }
    }
}

function New-Contract([string]$Root, [string]$FieldName, [string]$CaseName, [AllowNull()][string]$EvidenceOverride) {
    $unit = [ordered]@{
        id = "unit-tests"
        required = $true
        passes = $true
        evidence = "evidence/valid.log"
        waiver_reason = ""
        red_evidence = "evidence/red.log"
        green_evidence = "evidence/green.log"
    }
    if ($PSBoundParameters.ContainsKey("EvidenceOverride")) {
        $unit[$FieldName] = $EvidenceOverride
    } else {
        $unit[$FieldName] = Get-CaseValue $CaseName
    }

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

function Quote-Argument([string]$Value) {
    return '"' + $Value.Replace('"', '\"') + '"'
}

function Invoke-Contract([string]$ScriptPath, [string]$ContractPath, [string]$RepoRoot) {
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = Join-Path $PSHOME "powershell.exe"
    $info.Arguments = "-NoProfile -ExecutionPolicy Bypass -File $(Quote-Argument $ScriptPath) $(Quote-Argument $ContractPath) -RepoRoot $(Quote-Argument $RepoRoot)"
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $info
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    return [ordered]@{
        exit = $process.ExitCode
        stdout = Normalize-Lf $stdout
        stderr = Normalize-Lf $stderr
    }
}

function Assert-Equal([string]$Name, $Expected, $Actual) {
    if ($Expected -ceq $Actual) {
        Pass $Name
    } else {
        Fail "$Name expected '$Expected' but got '$Actual'"
    }
}

try {
    if (-not (Test-Path -LiteralPath $CandidatePath -PathType Leaf)) {
        throw "Candidate script not found: $CandidatePath"
    }

    if (-not $CaptureGolden) {
        Assert-Equal "candidate uses the fixed T-003 staging path" `
            ([System.IO.Path]::GetFullPath($expectedCandidatePath)) `
            ([System.IO.Path]::GetFullPath($CandidatePath))
        $source = [System.IO.File]::ReadAllText($CandidatePath, [System.Text.Encoding]::ASCII)
        try {
            [void][ScriptBlock]::Create($source)
            Pass "candidate parses under Windows PowerShell"
        } catch {
            Fail "candidate parse: $($_.Exception.Message)"
        }
        $helperDefinitions = [regex]::Matches($source, '(?mi)^\s*function\s+Test-EvidencePath\b').Count
        Assert-Equal "one structured Test-EvidencePath helper" 1 $helperDefinitions
        foreach ($requiredField in @("IsValid", "ResolvedPath", "Failure")) {
            if ($source.Contains($requiredField)) {
                Pass "candidate contains structured field $requiredField"
            } else {
                Fail "candidate lacks structured field $requiredField"
            }
        }
        $helperReferences = [regex]::Matches($source, '\bTest-EvidencePath\b').Count
        Assert-Equal "helper definition plus three call sites" 4 $helperReferences
        if ($source.Contains("[System.IO.FileAttributes]::ReparsePoint")) {
            Pass "candidate uses the PS5.1 FileAttributes.ReparsePoint check"
        } else {
            Fail "candidate lacks the PS5.1 FileAttributes.ReparsePoint check"
        }
        if ($source -notmatch '\bLinkType\b') {
            Pass "candidate does not depend on LinkType"
        } else {
            Fail "candidate must not depend on LinkType"
        }
    }

    foreach ($field in $fields) {
        foreach ($caseName in $cases) {
            $caseRoot = Join-Path $workRoot ("{0}-{1}" -f $field, $caseName)
            New-FixtureWorkspace $caseRoot
            $contractPath = New-Contract $caseRoot $field $caseName
            $actual = Invoke-Contract $CandidatePath $contractPath $caseRoot
            $fixturePath = Join-Path $fixtureRoot ("{0}/{1}.json" -f $field, $caseName)

            if ($CaptureGolden) {
                $fixture = [ordered]@{
                    schema = "phase2-contract-path-golden/v1"
                    field = $field
                    case = $caseName
                    expected_exit = $actual.exit
                    stdout = $actual.stdout
                    stderr = $actual.stderr
                }
                Write-Utf8NoBom $fixturePath ($fixture | ConvertTo-Json -Depth 4)
                Pass "captured baseline $field/$caseName"
                continue
            }

            if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) {
                Fail "golden fixture missing: $field/$caseName"
                continue
            }
            $expected = Get-Content -Raw -Encoding Utf8 $fixturePath | ConvertFrom-Json
            Assert-Equal "$field/$caseName exit" ([int]$expected.expected_exit) ([int]$actual.exit)
            Assert-Equal "$field/$caseName stdout" (Normalize-Lf ([string]$expected.stdout)) $actual.stdout
            Assert-Equal "$field/$caseName stderr" (Normalize-Lf ([string]$expected.stderr)) $actual.stderr
        }
    }

    if (-not $CaptureGolden) {
        foreach ($field in $fields) {
            foreach ($reparseCase in @("intermediate-junction", "final-file-reparse")) {
                $caseRoot = Join-Path $workRoot ("{0}-{1}" -f $field, $reparseCase)
                $fixture = New-ReparseFixture $caseRoot $reparseCase
                $contractPath = New-Contract $caseRoot $field $reparseCase $fixture.Evidence
                $actual = Invoke-Contract $CandidatePath $contractPath $caseRoot
                $expectedStdout = "Verification contract FAILED for task T-003-FIXTURE:`n - check 'unit-tests' $field path contains a reparse point: $($fixture.Evidence)`n"

                Assert-Equal "$field/$reparseCase exit" 1 $actual.exit
                Assert-Equal "$field/$reparseCase field-specific reparse diagnostic" $expectedStdout $actual.stdout
                Assert-Equal "$field/$reparseCase stderr" "" $actual.stderr
            }
        }

        $liveBaseline = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/check-contract.ps1"
        foreach ($redCase in @("posix-absolute", "windows-drive-absolute", "unc-absolute", "traversal", "unresolvable")) {
            $caseRoot = Join-Path $workRoot ("compound-red-{0}" -f $redCase)
            New-FixtureWorkspace $caseRoot
            $contractPath = New-Contract $caseRoot "red_evidence" $redCase
            $compound = Get-Content -Raw -Encoding Utf8 $contractPath | ConvertFrom-Json
            $unit = $compound.checks | Where-Object { $_.id -eq "unit-tests" } | Select-Object -First 1
            $unit.green_evidence = "evidence/missing.log"
            Write-Utf8NoBom $contractPath ($compound | ConvertTo-Json -Depth 6)
            $baseline = Invoke-Contract $liveBaseline $contractPath $caseRoot
            $actual = Invoke-Contract $CandidatePath $contractPath $caseRoot
            Assert-Equal "red/$redCase plus green failure exit parity" ([int]$baseline.exit) ([int]$actual.exit)
            Assert-Equal "red/$redCase plus green failure stdout parity" $baseline.stdout $actual.stdout
            Assert-Equal "red/$redCase plus green failure stderr parity" $baseline.stderr $actual.stderr
        }
    }
} finally {
    if (Test-Path -LiteralPath $workRoot) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force
    }
}

Write-Host "phase2-contract-path-helper.tests.ps1: $script:passed passed, $script:failed failed"
if ($script:failed -gt 0) {
    exit 1
}
