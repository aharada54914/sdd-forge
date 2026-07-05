$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$validator = Join-Path $PSScriptRoot "validate-repository.ps1"
$validatorText = [IO.File]::ReadAllText($validator)

foreach ($requiredArtifact in @(
    "plugins/sdd-quality-loop/scripts/check-workflow-state.sh",
    "plugins/sdd-quality-loop/scripts/check-workflow-state.ps1",
    "contracts/workflow-state-registry.schema.json",
    "specs/workflow-state-registry.json"
)) {
    if ($validatorText -notmatch [regex]::Escape('"' + $requiredArtifact + '"')) {
        throw "Repository validation does not require packaged workflow-state artifact: $requiredArtifact"
    }
}
if ($validatorText.IndexOf("check-workflow-state.ps1", [StringComparison]::Ordinal) -gt
    $validatorText.IndexOf('$codexMarketplace =', [StringComparison]::Ordinal)) {
    throw "Workflow-state validation must run before packaging/marketplace validation."
}

$fixture = Join-Path ([IO.Path]::GetTempPath()) "sdd-workflow-state-repository-$([guid]::NewGuid())"
try {
    $fixtureTests = Join-Path $fixture "tests"
    $fixtureScripts = Join-Path $fixture "plugins/sdd-quality-loop/scripts"
    $fixtureContracts = Join-Path $fixture "contracts"
    $specs = Join-Path $fixture "specs"
    foreach ($directory in @($fixtureTests, $fixtureScripts, $fixtureContracts, $specs)) {
        New-Item -ItemType Directory -Force $directory | Out-Null
    }
    Copy-Item -LiteralPath $validator -Destination (Join-Path $fixtureTests "validate-repository.ps1")
    Copy-Item -LiteralPath (Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/check-workflow-state.ps1") `
        -Destination (Join-Path $fixtureScripts "check-workflow-state.ps1")
    Copy-Item -LiteralPath (Join-Path $repositoryRoot "contracts/workflow-state-registry.schema.json") `
        -Destination (Join-Path $fixtureContracts "workflow-state-registry.schema.json")
    $registry = Join-Path $specs "workflow-state-registry.json"
    @'
{
  "schema_version": 1,
  "migration_baseline_commit": "0369c8c96de2eb3179868d1949d66644488f65aa",
  "entries": [
    {
      "feature": "missing-feature",
      "profile": "full"
    }
  ]
}
'@ | Set-Content -NoNewline -Encoding Utf8 $registry

    $fixtureValidator = Join-Path $fixtureTests "validate-repository.ps1"
    $output = & pwsh -NoProfile -File $fixtureValidator 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) {
        throw "Repository validation accepted invalid persisted workflow state."
    }
    if (($output -join "`n") -notmatch "registry-dangling") {
        throw "Repository validation did not fail through workflow-state validation: $($output -join "`n")"
    }
    if (($output -join "`n") -match "Repository validation passed") {
        throw "Repository validation reported packaging success after workflow-state failure."
    }
} finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Workflow-state repository integration tests passed."
