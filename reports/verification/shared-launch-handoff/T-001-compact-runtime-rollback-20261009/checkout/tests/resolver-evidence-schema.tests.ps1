# resolver-evidence-schema suite (T-001, AC-017/018/019/020) — PowerShell twin.
# Schema-conformance only: every fixture here is a hand-crafted Resolver
# Evidence instance validated directly against
# contracts/resolver-evidence.schema.json via the stdlib-only
# resolver-evidence-schema-check.py validator (python3/python resolution
# only, no native fallback, matching this feature's own dispatch
# convention). No live Registry or resolve-project-context invocation is
# exercised by this suite.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$schema = Join-Path $root 'contracts/resolver-evidence.schema.json'
$check = Join-Path $root 'tests/resolver-evidence-schema-check.py'
$fixtures = Join-Path $root 'tests/fixtures/capability-resolver/resolver-evidence-schema'

function Get-Py {
    if (Get-Command python3 -ErrorAction SilentlyContinue) { return 'python3' }
    if (Get-Command python -ErrorAction SilentlyContinue) { return 'python' }
    throw 'python3/python not found'
}
$py = Get-Py

$script:PassCount = 0
$script:FailCount = 0
function Test-Pass([string]$label) { $script:PassCount++; Write-Host "PASS: $label" }
function Test-Fail([string]$label) { $script:FailCount++; Write-Host "FAIL: $label" }

# TEST-017: contract existence + $id convention.
if (Test-Path $schema) { Test-Pass 'TEST-017 schema file exists' } else { Test-Fail 'TEST-017 schema file exists' }

$schemaJson = $null
try {
    $schemaJson = Get-Content -Raw -Path $schema | ConvertFrom-Json
    Test-Pass 'TEST-017 schema is valid JSON'
} catch {
    Test-Fail 'TEST-017 schema is valid JSON'
}

$schemaUri = $null
$schemaIdValue = $null
if ($schemaJson) {
    if (Get-Member -InputObject $schemaJson -Name '$schema' -ErrorAction SilentlyContinue) { $schemaUri = $schemaJson.'$schema' }
    if (Get-Member -InputObject $schemaJson -Name '$id' -ErrorAction SilentlyContinue) { $schemaIdValue = $schemaJson.'$id' }
}

if ($schemaUri -eq 'http://json-schema.org/draft-07/schema#') {
    Test-Pass 'TEST-017 $schema is draft-07'
} else {
    Test-Fail "TEST-017 `$schema is draft-07 (got: $schemaUri)"
}

$expectedId = 'https://github.com/aharada54914/sdd-forge/contracts/resolver-evidence.schema.json'
if ($schemaIdValue -eq $expectedId) {
    Test-Pass 'TEST-017 $id matches contracts/*.schema.json convention'
} else {
    Test-Fail "TEST-017 `$id matches contracts/*.schema.json convention (got: $schemaIdValue)"
}

# TEST-018/019/020: fixture-driven structural completeness.
Get-ChildItem (Join-Path $fixtures 'valid') -Filter '*.json' | ForEach-Object {
    $name = $_.Name
    & $py $check $schema $_.FullName 'valid' | Out-Null
    if ($LASTEXITCODE -eq 0) { Test-Pass "valid fixture conforms: $name" } else { Test-Fail "valid fixture conforms: $name" }
}

Get-ChildItem (Join-Path $fixtures 'invalid') -Filter '*.json' | ForEach-Object {
    $name = $_.Name
    & $py $check $schema $_.FullName 'invalid' | Out-Null
    if ($LASTEXITCODE -eq 0) { Test-Pass "invalid fixture rejected: $name" } else { Test-Fail "invalid fixture rejected: $name" }
}

# AC-020: always-emit-on-success — clean-success fixture carries diagnostics: [].
$clean = Get-Content -Raw -Path (Join-Path $fixtures 'valid/clean-success.json') | ConvertFrom-Json
if (@($clean.diagnostics).Count -eq 0) {
    Test-Pass 'TEST-020 clean-success fixture has diagnostics: []'
} else {
    Test-Fail 'TEST-020 clean-success fixture has diagnostics: []'
}

# AC-018: exact-set — one matched, one unmatched, exactly two entries.
$exactSet = Get-Content -Raw -Path (Join-Path $fixtures 'valid/exact-set-two-capabilities.json') | ConvertFrom-Json
$caps = @($exactSet.capability_evaluations)
$matchedCount = @($caps | Where-Object { $_.matched -eq $true }).Count
$unmatchedCount = @($caps | Where-Object { $_.matched -eq $false }).Count
if ($caps.Count -eq 2 -and $matchedCount -eq 1 -and $unmatchedCount -eq 1) {
    Test-Pass 'TEST-018 exact-set fixture has exactly one matched and one unmatched entry'
} else {
    Test-Fail "TEST-018 exact-set fixture has exactly one matched and one unmatched entry (got: $($caps.Count) $matchedCount $unmatchedCount)"
}

# AC-018 (M9): zero-affected-component fixture — every trigger_evaluations is [].
$zero = Get-Content -Raw -Path (Join-Path $fixtures 'valid/zero-affected-components.json') | ConvertFrom-Json
$zeroOk = $true
foreach ($c in @($zero.capability_evaluations)) {
    if (@($c.trigger_evaluations).Count -ne 0) { $zeroOk = $false }
}
if ($zeroOk) {
    Test-Pass 'TEST-018 zero-affected-component fixture: every trigger_evaluations is []'
} else {
    Test-Fail 'TEST-018 zero-affected-component fixture: every trigger_evaluations is []'
}

# AC-019: conditional-facet scoping — matched entry carries the key
# (declaration_index-keyed, two entries sharing one facet name), unmatched
# entry omits the key entirely.
$facetFixture = Get-Content -Raw -Path (Join-Path $fixtures 'valid/conditional-facet-scoping.json') | ConvertFrom-Json
$matchedCap = $facetFixture.capability_evaluations | Where-Object { $_.capability_id -eq 'pii-handling' }
$unmatchedCap = $facetFixture.capability_evaluations | Where-Object { $_.capability_id -eq 'payments' }
$facetEntries = @($matchedCap.conditional_facet_evaluations)
$indices = @($facetEntries | ForEach-Object { $_.declaration_index } | Sort-Object)
$sameFacet = (@($facetEntries | ForEach-Object { $_.facet } | Sort-Object -Unique)).Count -eq 1
$unmatchedOmitsKey = -not (Get-Member -InputObject $unmatchedCap -Name 'conditional_facet_evaluations' -ErrorAction SilentlyContinue)
if ($matchedCap.matched -eq $true -and $indices.Count -eq 2 -and $indices[0] -eq 0 -and $indices[1] -eq 1 -and $sameFacet -and $unmatchedOmitsKey) {
    Test-Pass 'TEST-019 conditional-facet scoping: declaration_index-keyed, unmatched entry omits key'
} else {
    Test-Fail 'TEST-019 conditional-facet scoping: declaration_index-keyed, unmatched entry omits key'
}

Write-Host "PASS: $script:PassCount"
Write-Host "FAIL: $script:FailCount"
if ($script:FailCount -gt 0) { exit 1 } else { exit 0 }
