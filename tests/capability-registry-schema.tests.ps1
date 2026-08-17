param(
  [switch]$RedCheck
)
# Schema-conformance suite for contracts/capability-registry.schema.json
# (T-001, REQ-001) -- PowerShell twin of capability-registry-schema.tests.sh.
# Re-implements the schema's rules independently (does not interpret the
# schema file generically), matching the repository's established
# workflow-state-registry.tests.ps1 convention.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$instancePath = Join-Path $root 'contracts/capability-registry.json'
$schemaPath = Join-Path $root 'contracts/capability-registry.schema.json'
$fixturesDir = Join-Path $root 'tests/fixtures/capability-registry'

function Fail([string]$Message) {
  [Console]::Error.WriteLine("not ok: $Message")
  exit 1
}

function Get-Keys($obj) {
  # NOTE: PowerShell unrolls an empty array crossing a function-return
  # boundary into $null, not @() -- the unary comma operator suppresses
  # that unrolling so callers reliably see an array (possibly empty).
  if ($obj -is [System.Management.Automation.PSCustomObject]) {
    $names = @($obj.PSObject.Properties | ForEach-Object { $_.Name })
    return , $names
  }
  return , @()
}

function Test-IsObject($v) {
  return ($v -is [System.Management.Automation.PSCustomObject])
}

function Test-IsArray($v) {
  if ($null -eq $v) { return $false }
  return ($v -is [System.Array])
}

function Test-KeysWithin($obj, [string[]]$Allowed) {
  foreach ($k in (Get-Keys $obj)) {
    if ($Allowed -notcontains $k) { return $false }
  }
  return $true
}

function Test-HasAll($obj, [string[]]$Required) {
  $keys = Get-Keys $obj
  foreach ($r in $Required) {
    if ($keys -notcontains $r) { return $false }
  }
  return $true
}

function Test-StringArray($arr, [bool]$RequireNonEmpty, [bool]$RequireUnique) {
  if (-not (Test-IsArray $arr)) { return $false }
  foreach ($item in $arr) {
    if (-not ($item -is [string])) { return $false }
    if ($RequireNonEmpty -and $item.Length -eq 0) { return $false }
  }
  if ($RequireUnique) {
    $unique = @($arr | Select-Object -Unique)
    if ($unique.Count -ne @($arr).Count) { return $false }
  }
  return $true
}

$AllowedFields = @('artifact_kinds', 'runtime_classes', 'characteristics.pii',
  'characteristics.ui', 'characteristics.auto_update',
  'characteristics.local_persistence', 'distribution_channels',
  'data_classification')
$AllowedOperators = @('equals', 'not_equals', 'contains', 'in', 'exists')

function Test-Predicate($p) {
  if (-not (Test-IsObject $p)) { return $false }
  $keys = Get-Keys $p
  if ($keys.Count -eq 1 -and $keys[0] -eq 'all') {
    if (-not (Test-IsArray $p.all)) { return $false }
    foreach ($child in $p.all) { if (-not (Test-Predicate $child)) { return $false } }
    return $true
  }
  if ($keys.Count -eq 1 -and $keys[0] -eq 'any') {
    if (-not (Test-IsArray $p.any)) { return $false }
    foreach ($child in $p.any) { if (-not (Test-Predicate $child)) { return $false } }
    return $true
  }
  if ($keys.Count -eq 1 -and $keys[0] -eq 'not') {
    return (Test-Predicate $p.not)
  }
  if ((Test-KeysWithin $p @('scope', 'field', 'operator', 'value')) -and
      (Test-HasAll $p @('scope', 'field', 'operator'))) {
    if ($p.scope -ne 'affected_component') { return $false }
    if ($AllowedFields -notcontains $p.field) { return $false }
    if ($AllowedOperators -notcontains $p.operator) { return $false }
    if ($p.operator -ne 'exists') {
      if (-not (Test-HasAll $p @('value'))) { return $false }
    }
    return $true
  }
  return $false
}

function Test-Gate($g) {
  if (-not (Test-IsObject $g)) { return $false }
  if (-not (Test-KeysWithin $g @('id', 'stage', 'blocking', 'implementation_ref'))) { return $false }
  if (-not (Test-HasAll $g @('id', 'stage', 'blocking'))) { return $false }
  if (-not ($g.id -is [string] -and $g.id -match '^[a-z0-9][a-z0-9-]*$')) { return $false }
  if (@('implementation', 'artifact', 'promotion') -notcontains $g.stage) { return $false }
  if (-not ($g.blocking -is [bool])) { return $false }
  if (Test-HasAll $g @('implementation_ref')) {
    if (-not ($g.implementation_ref -is [string] -and $g.implementation_ref.Length -gt 0)) { return $false }
  }
  if ($g.stage -eq 'implementation') {
    if (-not (Test-HasAll $g @('implementation_ref'))) { return $false }
  }
  return $true
}

function Test-ConditionalFacet($cf) {
  if (-not (Test-IsObject $cf)) { return $false }
  if (-not (Test-KeysWithin $cf @('facet', 'when'))) { return $false }
  if (-not (Test-HasAll $cf @('facet', 'when'))) { return $false }
  if (-not ($cf.facet -is [string])) { return $false }
  return (Test-Predicate $cf.when)
}

function Test-LitePolicy($lp) {
  if (-not (Test-IsObject $lp)) { return $false }
  if (-not (Test-KeysWithin $lp @('eligible', 'upgrade_reasons'))) { return $false }
  if (-not (Test-HasAll $lp @('eligible'))) { return $false }
  if (-not ($lp.eligible -is [bool])) { return $false }
  if (Test-HasAll $lp @('upgrade_reasons')) {
    if (-not (Test-StringArray $lp.upgrade_reasons $true $false)) { return $false }
  }
  return $true
}

function Test-DeliveryStrategy($ds) {
  if (-not (Test-IsObject $ds)) { return $false }
  if (-not (Test-KeysWithin $ds @('kind'))) { return $false }
  if (-not (Test-HasAll $ds @('kind'))) { return $false }
  return ($ds.kind -is [string] -and $ds.kind.Length -gt 0)
}

function Test-Capability($c) {
  if (-not (Test-IsObject $c)) { return $false }
  $allowed = @('id', 'trigger', 'required_facets', 'conditional_facets',
    'review_check_ids', 'gate_ids', 'lite_policy', 'minimum_enforcement', 'delivery_strategy')
  $required = @('id', 'trigger', 'required_facets', 'conditional_facets',
    'review_check_ids', 'gate_ids', 'delivery_strategy')
  if (-not (Test-KeysWithin $c $allowed)) { return $false }
  if (-not (Test-HasAll $c $required)) { return $false }
  if (-not ($c.id -is [string] -and $c.id -match '^[a-z0-9][a-z0-9-]*$')) { return $false }
  if (-not (Test-Predicate $c.trigger)) { return $false }
  if (-not (Test-StringArray $c.required_facets $false $true)) { return $false }
  if (-not (Test-IsArray $c.conditional_facets)) { return $false }
  foreach ($cf in $c.conditional_facets) { if (-not (Test-ConditionalFacet $cf)) { return $false } }
  if (-not (Test-StringArray $c.review_check_ids $true $true)) { return $false }
  if (-not (Test-StringArray $c.gate_ids $false $true)) { return $false }
  if (Test-HasAll $c @('lite_policy')) {
    if (-not (Test-LitePolicy $c.lite_policy)) { return $false }
  }
  if (Test-HasAll $c @('minimum_enforcement')) {
    if ($c.minimum_enforcement -ne 'required') { return $false }
  }
  return (Test-DeliveryStrategy $c.delivery_strategy)
}

function Test-StrictSchema($schemaRoot) {
  if (-not (Test-IsObject $schemaRoot)) { return $false }
  if (-not (Test-KeysWithin $schemaRoot @('schema', 'gates', 'capabilities'))) { return $false }
  if (-not (Test-HasAll $schemaRoot @('schema', 'gates', 'capabilities'))) { return $false }
  if ($schemaRoot.schema -ne 'capability-registry/v1') { return $false }
  if (-not (Test-IsArray $schemaRoot.gates)) { return $false }
  foreach ($g in $schemaRoot.gates) { if (-not (Test-Gate $g)) { return $false } }
  if (-not (Test-IsArray $schemaRoot.capabilities)) { return $false }
  foreach ($c in $schemaRoot.capabilities) { if (-not (Test-Capability $c)) { return $false } }
  return $true
}

# Deliberately weak stand-in schema, used only to produce RED evidence: it
# proves the reject fixtures are not vacuously malformed JSON.
function Test-PermissiveSchema($schemaRoot) {
  if (-not (Test-IsObject $schemaRoot)) { return $false }
  if (-not (Test-HasAll $schemaRoot @('schema', 'gates', 'capabilities'))) { return $false }
  if (-not (Test-IsArray $schemaRoot.gates)) { return $false }
  if (-not (Test-IsArray $schemaRoot.capabilities)) { return $false }
  return $true
}

function Test-NoKeyAnywhere($node, [string]$Forbidden) {
  if (Test-IsObject $node) {
    foreach ($k in (Get-Keys $node)) {
      if ($k -eq $Forbidden) { return $false }
      if (-not (Test-NoKeyAnywhere $node.$k $Forbidden)) { return $false }
    }
    return $true
  } elseif (Test-IsArray $node) {
    foreach ($item in $node) { if (-not (Test-NoKeyAnywhere $item $Forbidden)) { return $false } }
    return $true
  }
  return $true
}

function Get-AcceptFixtures {
  return , @(Get-ChildItem -Path $fixturesDir -Filter 'schema-accept-*.json' | Sort-Object Name)
}

function Get-RejectFixtures {
  return , @(Get-ChildItem -Path $fixturesDir -Filter 'schema-reject-*.json' | Sort-Object Name)
}

if ($RedCheck) {
  $count = 0
  foreach ($fixture in (Get-RejectFixtures)) {
    $data = Get-Content -Raw -LiteralPath $fixture.FullName | ConvertFrom-Json
    if (-not (Test-PermissiveSchema $data)) {
      Fail "RED precondition violated: $($fixture.Name) is rejected even by the permissive stand-in schema"
    }
    Write-Host "RED: $($fixture.Name) wrongly accepted by permissive schema (expected)"
    $count++
  }
  if ($count -eq 0) { Fail 'no reject fixtures found for RED check' }
  Write-Host "RED check complete: $count reject fixtures pass under the permissive schema."
  exit 0
}

if (-not (Test-Path -LiteralPath $schemaPath)) { Fail 'schema missing' }
if (-not (Test-Path -LiteralPath $instancePath)) { Fail 'instance missing' }

$instance = Get-Content -Raw -LiteralPath $instancePath | ConvertFrom-Json
if (-not (Test-StrictSchema $instance)) { Fail 'canonical capability-registry.json fails strict schema check' }

$schemaDoc = Get-Content -Raw -LiteralPath $schemaPath | ConvertFrom-Json
$schemaTopKeys = Get-Keys $schemaDoc
if ($schemaTopKeys -notcontains '$schema' -or $schemaTopKeys -notcontains '$id' -or $schemaTopKeys -notcontains 'definitions') {
  Fail 'schema file missing $schema/$id/definitions conventions'
}
if ($schemaDoc.'$schema' -ne 'http://json-schema.org/draft-07/schema#') {
  Fail 'schema file does not declare draft-07'
}
if (-not ($schemaDoc.'$id' -match 'capability-registry\.schema\.json$')) {
  Fail 'schema file $id does not match capability-registry.schema.json convention'
}
if ((Get-Keys $schemaDoc.definitions) -notcontains 'predicate') {
  Fail 'schema file missing definitions.predicate (AC-006 shared predicate location)'
}
if (-not (Test-NoKeyAnywhere $schemaDoc 'conditions')) {
  Fail "schema file defines a forbidden top-level 'conditions' field (AC-006)"
}

$acceptFixtures = Get-AcceptFixtures
$acceptCount = 0
foreach ($fixture in $acceptFixtures) {
  $data = Get-Content -Raw -LiteralPath $fixture.FullName | ConvertFrom-Json
  if (-not (Test-StrictSchema $data)) { Fail "$($fixture.Name) unexpectedly rejected by strict schema check" }
  $acceptCount++
}
if ($acceptCount -lt 6) { Fail "expected at least 6 accept fixtures, found $acceptCount" }

$rejectFixtures = Get-RejectFixtures
$rejectCount = 0
foreach ($fixture in $rejectFixtures) {
  $data = Get-Content -Raw -LiteralPath $fixture.FullName | ConvertFrom-Json
  if (Test-StrictSchema $data) { Fail "$($fixture.Name) unexpectedly accepted by strict schema check" }
  $rejectCount++
}
if ($rejectCount -lt 16) { Fail "expected at least 16 reject fixtures, found $rejectCount" }

$runAllSh = Get-Content -Raw -LiteralPath (Join-Path $root 'tests/run-all.sh')
if ($runAllSh -notmatch [regex]::Escape('tests/capability-registry-schema.tests.sh')) {
  Fail 'suite not registered in tests/run-all.sh'
}
$runAllPs1 = Get-Content -Raw -LiteralPath (Join-Path $root 'tests/run-all.ps1')
if ($runAllPs1 -notmatch [regex]::Escape('tests/capability-registry-schema.tests.ps1')) {
  Fail 'suite not registered in tests/run-all.ps1'
}

$humanCopyDir = Join-Path $root 'specs/epic-190-a2-capability-registry/human-copy'
$stagedWorkflow = Join-Path $humanCopyDir '.github/workflows/test.yml'
$stagedManifest = Join-Path $humanCopyDir 'MANIFEST.sha256'
if (-not (Test-Path -LiteralPath $stagedWorkflow)) { Fail 'human-copy: staged .github/workflows/test.yml candidate missing' }
if (-not (Test-Path -LiteralPath $stagedManifest)) { Fail 'human-copy: MANIFEST.sha256 missing' }
$stagedWorkflowText = Get-Content -Raw -LiteralPath $stagedWorkflow
if ($stagedWorkflowText -notmatch [regex]::Escape('tests/capability-registry-schema.tests.sh')) {
  Fail "human-copy: staged workflow candidate omits this suite's bash CI step"
}
if ($stagedWorkflowText -notmatch [regex]::Escape('tests/capability-registry-schema.tests.ps1')) {
  Fail "human-copy: staged workflow candidate omits this suite's pwsh CI step"
}
$stagedHash = (Get-FileHash -LiteralPath $stagedWorkflow -Algorithm SHA256).Hash.ToLowerInvariant()
# NOTE: Get-Content returns a scalar string (not an array) for a one-line
# file, which would silently turn -match into a boolean test instead of a
# per-line filter -- @() forces array context so -match filters lines.
$manifestLines = @(Get-Content -LiteralPath $stagedManifest)
$manifestLine = @($manifestLines -match 'workflows/test\.yml')
if ($manifestLine.Count -eq 0) { Fail 'human-copy: MANIFEST.sha256 has no entry for the staged workflow candidate' }
$manifestHash = ($manifestLine[0] -split '\s+')[0].ToLowerInvariant()
if ($stagedHash -ne $manifestHash) {
  Fail "human-copy: staged workflow candidate sha256 does not match its MANIFEST.sha256 entry"
}

Write-Host "capability-registry-schema: $acceptCount accept + $rejectCount reject fixtures pass; canonical instance valid."
exit 0
