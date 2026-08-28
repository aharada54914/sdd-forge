$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$Builder = Join-Path $Root 'tests/lib/fixture-matrix-builder.ps1'
$PassCount = 0
$FailCount = 0
$FixtureRoots = [System.Collections.Generic.List[string]]::new()
$SeenRoots = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

function Pass([string]$Description) {
    $script:PassCount++
    Write-Host "ok $PassCount - $Description"
}

function Fail([string]$Description) {
    $script:FailCount++
    Write-Host "not ok $FailCount - $Description"
}

function Assert-True([bool]$Condition, [string]$Description) {
    if ($Condition) { Pass $Description } else { Fail $Description }
}

function Get-IndependentPhysicalDirectory([string]$LiteralPath) {
    if ($IsWindows) {
        return (Resolve-Path -LiteralPath $LiteralPath).Path
    }

    Push-Location -LiteralPath $LiteralPath
    try {
        $physicalPath = @(& /bin/pwd -P)
        if ($LASTEXITCODE -ne 0 -or $physicalPath.Count -ne 1) {
            throw "could not independently resolve physical path for $LiteralPath"
        }
        return $physicalPath[0]
    } finally {
        Pop-Location
    }
}

if (-not (Test-Path -LiteralPath $Builder -PathType Leaf)) {
    Fail 'fixture matrix builder exists'
    Write-Output "RESULT: PASS=$PassCount FAIL=$FailCount"
    exit 1
}

. $Builder

$ExpectedPhysicalRepoRoot = Get-IndependentPhysicalDirectory $Root
$ExpectedPhysicalTempRoot = Get-IndependentPhysicalDirectory ([IO.Path]::GetTempPath())
$PathComparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }

function Assert-FixtureRoot([string]$FixtureRoot, [string]$Label) {
    $fixtureLeaf = [IO.Path]::GetFileName($FixtureRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
    $expectedPhysicalRoot = Join-Path $ExpectedPhysicalTempRoot $fixtureLeaf
    Assert-True (Test-Path -LiteralPath $FixtureRoot -PathType Container) "$Label returns an existing directory"
    Assert-True ([string]::Equals($FixtureRoot, $expectedPhysicalRoot, $PathComparison)) "$Label returns a physically normalized root"
    $repositoryPrefix = $ExpectedPhysicalRepoRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $outside = -not ([string]::Equals($FixtureRoot, $ExpectedPhysicalRepoRoot, $PathComparison) -or $FixtureRoot.StartsWith($repositoryPrefix, $PathComparison))
    Assert-True $outside "$Label root is outside the real repository"
    Assert-True ($SeenRoots.Add($FixtureRoot)) "$Label root is fresh"
}

function Assert-Marker([string]$FixtureRoot, [string]$Marker, [string]$Label) {
    $agents = Join-Path $FixtureRoot 'AGENTS.md'
    if ($Marker -ceq 'present') {
        Assert-True (Test-Path -LiteralPath $agents -PathType Leaf) "$Label writes AGENTS marker file"
        $tokens = ([IO.File]::ReadAllText($agents).Trim() -split '\s+')
        Assert-True ($tokens.Count -eq 2 -and $tokens[0] -ceq 'spec_profile:' -and $tokens[1] -ceq 'lite') "$Label writes the lite marker"
    } else {
        Assert-True (-not (Test-Path -LiteralPath $agents)) "$Label omits AGENTS marker file"
    }
}

function Assert-Context([string]$FixtureRoot, [string]$Enforcement, [string]$Validity, [string]$Label) {
    $context = Join-Path $FixtureRoot 'sdd/project-context.yaml'
    $contextExists = Test-Path -LiteralPath $context -PathType Leaf
    Assert-True $contextExists "$Label writes project context"
    if (-not $contextExists) { return }
    $lines = [IO.File]::ReadAllLines($context)
    $syntaxValid = $lines.Count -eq 5 -and
        $lines[0] -cmatch '^schema: sdd-project-context/v[01]$' -and
        $lines[1] -ceq 'workflow:' -and
        $lines[2] -ceq '  spec_profile: full' -and
        $lines[3] -ceq '  artifact_layout: legacy-seven-layer' -and
        $lines[4] -ceq "  capability_enforcement: $Enforcement"
    Assert-True $syntaxValid "$Label is syntactically valid restricted YAML"
    $expectedSchema = if ($Validity -ceq 'PROJECT_CONTEXT_INVALID') { 'schema: sdd-project-context/v0' } else { 'schema: sdd-project-context/v1' }
    Assert-True ($lines[0] -ceq $expectedSchema) "$Label has the expected schema field"
}

function Build-AndCheck(
    [string]$ProjectContext,
    [string]$Marker,
    [string]$Enforcement,
    [string]$Validity,
    [string]$TrackFlag,
    [string]$Label
) {
    try {
        $fixtureRoot = build_fixture $ProjectContext $Marker $Enforcement $Validity $TrackFlag
    } catch {
        Fail "$Label constructs successfully: $($_.Exception.Message)"
        return $null
    }
    if ([string]::IsNullOrEmpty($fixtureRoot)) {
        Fail "$Label constructs successfully"
        return $null
    }
    $FixtureRoots.Add($fixtureRoot)
    Pass "$Label constructs successfully"
    Assert-FixtureRoot $fixtureRoot $Label
    Assert-Marker $fixtureRoot $Marker $Label
    if ($ProjectContext -ceq 'present') {
        Assert-Context $fixtureRoot $Enforcement $Validity $Label
    } else {
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $fixtureRoot 'sdd/project-context.yaml'))) "$Label omits project context"
    }
    return $fixtureRoot
}

try {
    [void](Build-AndCheck absent absent disabled-legacy valid none 'F1')
    [void](Build-AndCheck absent present disabled-legacy valid none 'F2')
    $f3Valid = Build-AndCheck present absent advisory valid none 'F3 valid'
    $f3Invalid = Build-AndCheck present absent advisory PROJECT_CONTEXT_INVALID none 'F3 invalid'
    $f4Valid = Build-AndCheck present absent required valid none 'F4 valid'
    $f4Invalid = Build-AndCheck present absent required PROJECT_CONTEXT_INVALID none 'F4 invalid'

    $comparisons = @(
        [PSCustomObject]@{ Valid = $f3Valid; Invalid = $f3Invalid; Label = 'F3' }
        [PSCustomObject]@{ Valid = $f4Valid; Invalid = $f4Invalid; Label = 'F4' }
    )
    foreach ($comparison in $comparisons) {
        $validContext = Join-Path $comparison.Valid 'sdd/project-context.yaml'
        $invalidContext = Join-Path $comparison.Invalid 'sdd/project-context.yaml'
        if (-not (Test-Path -LiteralPath $validContext -PathType Leaf) -or
            -not (Test-Path -LiteralPath $invalidContext -PathType Leaf)) {
            Fail "$($comparison.Label) invalid YAML differs from valid YAML in exactly the schema field"
            continue
        }
        $validLines = [IO.File]::ReadAllLines($validContext)
        $invalidLines = [IO.File]::ReadAllLines($invalidContext)
        $onlySchemaDiffers = $validLines.Count -eq $invalidLines.Count -and
            $validLines[0] -cne $invalidLines[0] -and
            ([string]::Join("`n", $validLines[1..($validLines.Count - 1)]) -ceq [string]::Join("`n", $invalidLines[1..($invalidLines.Count - 1)]))
        Assert-True $onlySchemaDiffers "$($comparison.Label) invalid YAML differs from valid YAML in exactly the schema field"
    }

    $validatorProbe = @'
import importlib.util
import pathlib
import sys

root, context_path, expected = sys.argv[1:]
validator_path = pathlib.Path(root) / "plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py"
spec = importlib.util.spec_from_file_location("fixture_matrix_named_validator", validator_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
info = module.CONTENT_SCHEMA_INFO["sdd-project-context-approval/v1"]
try:
    module._validate_content(context_path, info)
except module.ValidateApprovalSidecarError as exc:
    if expected == "invalid" and exc.category == "CONTENT_SCHEMA_VIOLATION":
        raise SystemExit(0)
    print(f"unexpected validator failure: {exc.category}: {exc.message}", file=sys.stderr)
    raise SystemExit(1)
if expected == "valid":
    raise SystemExit(0)
print("invalid fixture unexpectedly passed validate-approval-sidecar content validation", file=sys.stderr)
raise SystemExit(1)
'@

    foreach ($validatorCase in @(
        [PSCustomObject]@{ Root = $f3Valid; Expected = 'valid'; Label = 'F3 valid' }
        [PSCustomObject]@{ Root = $f3Invalid; Expected = 'invalid'; Label = 'F3 invalid' }
        [PSCustomObject]@{ Root = $f4Valid; Expected = 'valid'; Label = 'F4 valid' }
        [PSCustomObject]@{ Root = $f4Invalid; Expected = 'invalid'; Label = 'F4 invalid' }
    )) {
        $context = Join-Path $validatorCase.Root 'sdd/project-context.yaml'
        & python3 -c $validatorProbe $Root $context $validatorCase.Expected
        Assert-True ($LASTEXITCODE -eq 0) "$($validatorCase.Label) has the expected validate-approval-sidecar verdict"
    }

    foreach ($trackFlag in @('none', '--full', '--lite')) {
        foreach ($marker in @('present', 'absent')) {
            [void](Build-AndCheck absent $marker disabled-legacy valid $trackFlag "legacy $trackFlag marker-$marker")
        }
    }

    $invalidCases = @(
        @('unknown', 'absent', 'disabled-legacy', 'valid', 'none'),
        @('Present', 'absent', 'disabled-legacy', 'valid', 'none'),
        @('absent', 'unknown', 'disabled-legacy', 'valid', 'none'),
        @('absent', 'absent', 'unknown', 'valid', 'none'),
        @('absent', 'absent', 'disabled-legacy', 'unknown', 'none'),
        @('absent', 'absent', 'disabled-legacy', 'valid', '--unknown'),
        @('absent', 'absent', 'disabled-legacy', 'valid', '--FULL'),
        @('present', 'absent', 'disabled-legacy', 'valid', 'none'),
        @('absent', 'absent', 'disabled-legacy', 'valid', 'none', 'extra')
    )
    foreach ($invalidCase in $invalidCases) {
        $rejected = $false
        try { [void](build_fixture @invalidCase) } catch { $rejected = $true }
        Assert-True $rejected "invalid argument tuple is rejected: $($invalidCase -join ' ')"
    }

    $underArityError = $null
    try { [void](build_fixture absent absent disabled-legacy valid) } catch { $underArityError = $_.Exception.Message }
    Assert-True ($underArityError -ceq 'build_fixture: expected 5 arguments, received 4') 'a missing fifth argument reaches the explicit arity guard'

    $registered = Select-String -LiteralPath (Join-Path $Root 'tests/run-all.sh'), (Join-Path $Root 'tests/run-all.ps1') -SimpleMatch 'fixture-matrix-builder' -CaseSensitive -Quiet
    Assert-True (-not $registered) 'sourced builder is not registered as an independent suite'
} finally {
    foreach ($fixtureRoot in $FixtureRoots) {
        if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
    }
}

Write-Output "RESULT: PASS=$PassCount FAIL=$FailCount"
if ($FailCount -ne 0) { exit 1 }
