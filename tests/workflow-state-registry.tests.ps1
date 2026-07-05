param(
  [string]$RegistryPath,
  [switch]$SymlinkFixture,
  [ValidateSet('duplicate','dangling','unregistered','symlink')]
  [string]$CoverageFixture
)
$ErrorActionPreference = 'Stop'

function Test-RegisteredPath {
  param([string]$Feature, [string]$SpecsRoot)
  $candidate = Join-Path $SpecsRoot $Feature
  if (-not (Test-Path -LiteralPath $candidate)) {
    throw "workflow-state: ${Feature}: registry-dangling-entry: registered directory is missing"
  }
  $resolvedRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SpecsRoot).Path)
  $item = Get-Item -LiteralPath $candidate -Force
  $resolved = if ($item.LinkType) {
    [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $item.Target).Path)
  } else {
    [IO.Path]::GetFullPath($item.FullName)
  }
  $prefix = $resolvedRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  if (-not $resolved.StartsWith($prefix, [StringComparison]::Ordinal)) {
    throw "workflow-state: ${Feature}: registry-path-escape: registered directory escapes specs root"
  }
}

function Test-RegistryCoverage {
  param($Registry, [string]$SpecsRoot)
  $duplicate = @($Registry.entries.feature | Group-Object -CaseSensitive | Where-Object Count -gt 1 | Select-Object -First 1)
  if ($duplicate.Count -gt 0) {
    throw "workflow-state: $($duplicate[0].Name): registry-duplicate: feature is registered more than once"
  }
  foreach ($feature in $Registry.entries.feature) {
    Test-RegisteredPath -Feature $feature -SpecsRoot $SpecsRoot
  }
  foreach ($directory in Get-ChildItem -LiteralPath $SpecsRoot -Directory -Force) {
    if ($Registry.entries.feature -cnotcontains $directory.Name) {
      throw "workflow-state: $($directory.Name): registry-unregistered-directory: specs directory is not registered"
    }
  }
}

if ($SymlinkFixture) {
  $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("sdd-registry-" + [guid]::NewGuid())
  try {
    $specsRoot = New-Item -ItemType Directory -Path (Join-Path $fixtureRoot specs) -Force
    $outside = New-Item -ItemType Directory -Path (Join-Path $fixtureRoot outside) -Force
    New-Item -ItemType SymbolicLink -Path (Join-Path $specsRoot.FullName escape) -Target $outside.FullName | Out-Null
    Test-RegisteredPath -Feature escape -SpecsRoot $specsRoot.FullName
    throw 'not ok: escaping symlink unexpectedly accepted'
  } finally {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$registryPath = if ($RegistryPath) { $RegistryPath } else { Join-Path $root 'specs/workflow-state-registry.json' }
$schemaPath = Join-Path $root 'contracts/workflow-state-registry.schema.json'
$retrospectivePath = Join-Path $root 'specs/uninstall-workflow/retrospective.md'
$baseline = '0369c8c96de2eb3179868d1949d66644488f65aa'

if ($CoverageFixture) {
  $canonical = Get-Content -Raw -LiteralPath (Join-Path $root 'specs/workflow-state-registry.json') | ConvertFrom-Json
  $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("sdd-coverage-" + [guid]::NewGuid())
  try {
    switch ($CoverageFixture) {
      'duplicate' {
        $canonical.entries = @($canonical.entries) + @($canonical.entries | Where-Object feature -CEQ 'workflow-state-integrity')
        Test-RegistryCoverage -Registry $canonical -SpecsRoot (Join-Path $root specs)
      }
      'dangling' {
        $canonical.entries = @($canonical.entries) + [pscustomobject]@{feature='ghost-feature';profile='full'}
        Test-RegistryCoverage -Registry $canonical -SpecsRoot (Join-Path $root specs)
      }
      'unregistered' {
        $canonical.entries = @($canonical.entries | Where-Object feature -CNE 'workflow-state-integrity')
        Test-RegistryCoverage -Registry $canonical -SpecsRoot (Join-Path $root specs)
      }
      'symlink' {
        $specsRoot = New-Item -ItemType Directory -Path (Join-Path $fixtureRoot specs) -Force
        $outside = New-Item -ItemType Directory -Path (Join-Path $fixtureRoot outside) -Force
        New-Item -ItemType SymbolicLink -Path (Join-Path $specsRoot.FullName escape) -Target $outside.FullName | Out-Null
        $fixtureRegistry = [pscustomobject]@{entries=@([pscustomobject]@{feature='escape';profile='full'})}
        Test-RegistryCoverage -Registry $fixtureRegistry -SpecsRoot $specsRoot.FullName
      }
    }
    throw "not ok: $CoverageFixture coverage fixture unexpectedly accepted"
  } finally {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

foreach ($path in @($registryPath, $schemaPath, $retrospectivePath)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "not ok: missing $path" }
}
$raw = Get-Content -Raw -LiteralPath $registryPath
if (-not (Test-Json -Json $raw -SchemaFile $schemaPath)) { throw 'not ok: canonical registry fails JSON schema' }
$registry = $raw | ConvertFrom-Json
$features = @($registry.entries.feature | Sort-Object -CaseSensitive)
$expected = @('agent-cost-context-isolation','bootstrap-interviewer-enhancement','claude-workflow-compatibility','cross-model-verification','p0-hardening','risk-adaptive-layer','sdd-diagnose','sdd-forge-refactor','sdd-lite','uninstall-workflow','workflow-state-integrity')
if ($registry.schema_version -ne 1 -or $registry.migration_baseline_commit -cne $baseline -or ($features -join ',') -cne ($expected -join ',')) {
  throw 'not ok: canonical registry metadata or coverage is invalid'
}
if (@($registry.entries.feature | Sort-Object -Unique).Count -ne $registry.entries.Count) { throw 'not ok: duplicate registry feature' }
$directories = @(Get-ChildItem -LiteralPath (Join-Path $root specs) -Directory | Where-Object { -not $_.LinkType } | Select-Object -ExpandProperty Name | Sort-Object -CaseSensitive)
if (($directories -join ',') -cne ($features -join ',')) { throw 'not ok: registry does not exactly cover specs directories' }
Test-RegistryCoverage -Registry $registry -SpecsRoot (Join-Path $root specs)
foreach ($fixture in Get-ChildItem -LiteralPath (Join-Path $root 'tests/fixtures/workflow-state') -Filter 'invalid-registry-*.json') {
  if (Test-Json -Json (Get-Content -Raw -LiteralPath $fixture.FullName) -SchemaFile $schemaPath -ErrorAction SilentlyContinue) {
    throw "not ok: $($fixture.Name) unexpectedly passes schema"
  }
}
foreach ($fixture in @('duplicate','dangling','unregistered')) {
  $diagnostic = ''
  try { & $PSCommandPath -CoverageFixture $fixture 2>&1 | Out-Null } catch { $diagnostic = $_.Exception.Message }
  if (-not $diagnostic.StartsWith('workflow-state:', [StringComparison]::Ordinal)) {
    throw "not ok: $fixture fixture did not reach coverage validation"
  }
}
$symlinkDiagnostic = ''
try {
  & $PSCommandPath -CoverageFixture symlink 2>&1 | Out-Null
} catch {
  $symlinkDiagnostic = $_.Exception.Message
}
if (-not $symlinkDiagnostic.StartsWith('workflow-state: escape: registry-path-escape:', [StringComparison]::Ordinal)) {
  throw 'not ok: escaping symlink was not rejected with registry-path-escape'
}
$retrospective = Get-Content -Raw -LiteralPath $retrospectivePath
foreach ($needle in @('277a79d','uninstall.sh','uninstall.ps1','uninstall.tests.sh','uninstall.tests.ps1','provenance is unavailable')) {
  if (-not $retrospective.Contains($needle, [StringComparison]::OrdinalIgnoreCase)) { throw "not ok: retrospective omits $needle" }
}
Write-Output 'ok: PowerShell validates workflow-state registry and migration records'
