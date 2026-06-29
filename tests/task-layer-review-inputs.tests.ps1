$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$WorkRoot = Join-Path ([IO.Path]::GetTempPath()) "sdd-task-layer-ps-$([guid]::NewGuid().ToString('N'))"
$Feature = 'task-layer-inputs-ps-fixture'
$Spec = Join-Path $WorkRoot "specs/$Feature"
$Report = Join-Path $WorkRoot "reports/task-review/$Feature/attempt-1/round-1"
$Registry = Join-Path $WorkRoot 'specs/workflow-state-registry.json'
New-Item -ItemType Directory -Force -Path (Join-Path $WorkRoot 'specs'),(Join-Path $WorkRoot 'plugins') | Out-Null
Copy-Item -Recurse (Join-Path $Root 'plugins/sdd-review-loop'),(Join-Path $Root 'plugins/sdd-quality-loop') (Join-Path $WorkRoot 'plugins')
Copy-Item (Join-Path $Root 'specs/workflow-state-registry.json') $Registry
$RegistryOriginal = [IO.File]::ReadAllText($Registry)
$Layers = @('ux-spec.md', 'frontend-spec.md', 'infra-spec.md', 'security-spec.md')
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLower() }
function Write-Inputs {
  New-Item -ItemType Directory -Force -Path $Spec,$Report | Out-Null
  '# Tasks' | Set-Content (Join-Path $Spec 'tasks.md') -Encoding utf8NoBOM
  "# Requirements`n`n## REQ-001`n`n## REQ-002" | Set-Content (Join-Path $Spec 'requirements.md') -Encoding utf8NoBOM
  '# Acceptance' | Set-Content (Join-Path $Spec 'acceptance-tests.md') -Encoding utf8NoBOM
  '# Design' | Set-Content (Join-Path $Spec 'design.md') -Encoding utf8NoBOM
  foreach ($name in $Layers) { "# $name" | Set-Content (Join-Path $Spec $name) -Encoding utf8NoBOM }
  "| Requirement | Design | Layer Spec |`n|---|---|---|`n| REQ-001 | D | ux-spec.md#journey |`n| REQ-002 | D | N/A — cross-layer only: orchestration |" |
    Set-Content (Join-Path $Spec 'traceability.md') -Encoding utf8NoBOM
}
function Write-Precheck {
  $layerHashes = [ordered]@{}; foreach ($name in $Layers) { $layerHashes[$name] = Hash (Join-Path $Spec $name) }
  [ordered]@{schema='task-review-precheck/v1';feature=$Feature;attempt=1;round=1;
    tasks_sha256=Hash (Join-Path $Spec 'tasks.md');requirements_sha256=Hash (Join-Path $Spec 'requirements.md');
    acceptance_sha256=Hash (Join-Path $Spec 'acceptance-tests.md');design_sha256=Hash (Join-Path $Spec 'design.md');
    traceability_sha256=Hash (Join-Path $Spec 'traceability.md');
    layer_sha256=$layerHashes} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Report 'precheck-result.json') -Encoding utf8NoBOM
}
try {
  $registryData = $RegistryOriginal | ConvertFrom-Json
  $registryData.entries = @($registryData.entries) + [pscustomobject]@{feature=$Feature;profile='full'}
  $registryData | ConvertTo-Json -Depth 10 | Set-Content $Registry -Encoding utf8NoBOM
  Write-Inputs; Write-Precheck
  & (Join-Path $WorkRoot 'plugins/sdd-review-loop/scripts/task-review-precheck.ps1') -Feature $Feature -Attempt 1 -Round 1 -VerifyInputs | Out-Null
  Write-Host 'PASS: PowerShell complete task-review inputs verify'

  foreach ($value in @('', 'N/A', 'ux-spec.md', 'N/A — cross-layer only:')) {
    "| Requirement | Design | Layer Spec |`n|---|---|---|`n| REQ-001 | D | $value |" |
      Set-Content (Join-Path $Spec 'traceability.md') -Encoding utf8NoBOM
    Write-Precheck
    $failed = $false
    try { & (Join-Path $WorkRoot 'plugins/sdd-review-loop/scripts/validate-layer-traceability.ps1') -Path (Join-Path $Spec 'traceability.md') -RequirementsPath (Join-Path $Spec 'requirements.md') } catch { $failed = $true }
    if (-not $failed) { throw "FAIL: invalid Layer Spec accepted: $value" }
    $failed = $false
    try { & (Join-Path $WorkRoot 'plugins/sdd-review-loop/scripts/task-review-precheck.ps1') -Feature $Feature -Attempt 1 -Round 1 -VerifyInputs | Out-Null } catch { $failed = $true }
    if (-not $failed) { throw "FAIL: reviewer-time precheck accepted invalid Layer Spec: $value" }
  }
  Write-Host 'PASS: PowerShell rejects invalid Layer Spec values'

  Write-Inputs
  "| Requirement | Design | Layer Spec |`n|---|---|---|`n| REQ-001 | D | ux-spec.md#journey |" |
    Set-Content (Join-Path $Spec 'traceability.md') -Encoding utf8NoBOM
  $failed = $false
  try { & (Join-Path $WorkRoot 'plugins/sdd-review-loop/scripts/validate-layer-traceability.ps1') -Path (Join-Path $Spec 'traceability.md') -RequirementsPath (Join-Path $Spec 'requirements.md') } catch { $failed = $true }
  if (-not $failed) { throw 'FAIL: omitted requirement row accepted' }
  Write-Host 'PASS: PowerShell rejects omitted applicable requirement row'

  Write-Inputs; Write-Precheck
  $registryData = Get-Content $Registry -Raw | ConvertFrom-Json
  @($registryData.entries | Where-Object feature -eq $Feature)[0].profile = 'lite'
  $registryData | ConvertTo-Json -Depth 10 | Set-Content $Registry -Encoding utf8NoBOM
  Add-Content (Join-Path $Spec 'ux-spec.md') 'tamper'
  $failed = $false
  try { & (Join-Path $WorkRoot 'plugins/sdd-review-loop/scripts/task-review-precheck.ps1') -Feature $Feature -Attempt 1 -Round 1 -VerifyInputs | Out-Null } catch { $failed = $true }
  if (-not $failed) { throw 'FAIL: PowerShell accepted layer tamper' }
  Write-Host 'PASS: PowerShell persisted full manifest rejects tamper after profile downgrade'

  Write-Inputs; Write-Precheck
  Remove-Item (Join-Path $Spec 'infra-spec.md')
  $failed = $false
  try { & (Join-Path $WorkRoot 'plugins/sdd-review-loop/scripts/task-review-precheck.ps1') -Feature $Feature -Attempt 1 -Round 1 -VerifyInputs | Out-Null } catch { $failed = $true }
  if (-not $failed) { throw 'FAIL: PowerShell accepted missing layer' }
  Write-Host 'PASS: PowerShell rejects missing layer'

  Write-Inputs; Write-Precheck
  Add-Content (Join-Path $Spec 'design.md') 'tamper'
  $failed = $false
  try { & (Join-Path $WorkRoot 'plugins/sdd-review-loop/scripts/task-review-precheck.ps1') -Feature $Feature -Attempt 1 -Round 1 -VerifyInputs | Out-Null } catch { $failed = $true }
  if (-not $failed) { throw 'FAIL: PowerShell accepted design tamper' }
  Write-Host 'PASS: PowerShell binds the Phase 1 design input'

  Write-Inputs; Write-Precheck
  $outside = New-TemporaryFile
  Remove-Item (Join-Path $Spec 'security-spec.md')
  try {
    New-Item -ItemType SymbolicLink -Path (Join-Path $Spec 'security-spec.md') -Target $outside.FullName | Out-Null
    $failed = $false
    try { & (Join-Path $WorkRoot 'plugins/sdd-review-loop/scripts/task-review-precheck.ps1') -Feature $Feature -Attempt 1 -Round 1 -VerifyInputs | Out-Null } catch { $failed = $true }
    if (-not $failed) { throw 'FAIL: PowerShell accepted path-substituted layer' }
  } finally {
    Remove-Item -LiteralPath $outside.FullName -Force -ErrorAction SilentlyContinue
  }
  Write-Host 'PASS: PowerShell rejects path-substituted layer'
} finally {
  Remove-Item -LiteralPath $WorkRoot -Recurse -Force -ErrorAction SilentlyContinue
}
