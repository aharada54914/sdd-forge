# facet-manifest-schema.tests.ps1 — PowerShell twin of
# facet-manifest-schema.tests.sh (REQ-001, design.md Test Strategy item 1).
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Validator = Join-Path $RepoRoot 'plugins/sdd-quality-loop/scripts/validate-facet-manifest.py'
$Schema = Join-Path $RepoRoot 'contracts/facet-manifest.schema.json'
$Fixtures = Join-Path $RepoRoot 'tests/fixtures/facet-manifest/schema'

$script:Pass = 0
$script:Fail = 0

function Get-Python {
    $py = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
    if (-not $py) { throw 'facet-manifest-schema.tests.ps1: no python3/python on PATH' }
    return $py.Path
}
$Python = Get-Python

function Invoke-Validator([string]$FixtureName) {
    $path = Join-Path $Fixtures $FixtureName
    $out = & $Python $Validator --manifest $path 2>&1
    return @{ Out = ($out -join "`n"); Code = $LASTEXITCODE }
}

function Expect-Valid([string]$Fixture, [string]$Name) {
    $r = Invoke-Validator $Fixture
    if ($r.Code -eq 0 -and [string]::IsNullOrEmpty($r.Out)) {
        Write-Host "ok: $Name`: $Fixture valid (exit 0, no diagnostics)"
        $script:Pass++
    } else {
        Write-Host "FAIL: $Name`: $Fixture expected valid, got exit=$($r.Code) output=[$($r.Out)]"
        $script:Fail++
    }
}

function Expect-Invalid([string]$Fixture, [string]$Name, [string]$Needle) {
    $r = Invoke-Validator $Fixture
    if ($r.Code -ne 0 -and $r.Out.Contains($Needle)) {
        Write-Host "ok: $Name`: $Fixture invalid as expected (contains '$Needle')"
        $script:Pass++
    } else {
        Write-Host "FAIL: $Name`: $Fixture expected invalid containing '$Needle', got exit=$($r.Code) output=[$($r.Out)]"
        $script:Fail++
    }
}

# TEST-001
$schemaJson = Get-Content $Schema -Raw | ConvertFrom-Json
if ($schemaJson.'$schema' -eq 'http://json-schema.org/draft-07/schema#') {
    Write-Host 'ok: TEST-001: $schema is draft-07'; $script:Pass++
} else {
    Write-Host "FAIL: TEST-001: `$schema expected draft-07, got '$($schemaJson.'$schema')'"; $script:Fail++
}
if ($schemaJson.'$id') {
    Write-Host "ok: TEST-001: `$id present ($($schemaJson.'$id'))"; $script:Pass++
} else {
    Write-Host 'FAIL: TEST-001: $id missing'; $script:Fail++
}

# TEST-002
Expect-Valid 'valid-base.json' 'TEST-002 positive baseline'
foreach ($field in @('schema','feature','affected-components','required-facets','conditional-facets','resolved-gates','capabilities','lite-eligibility','context-binding','resolver')) {
    Expect-Invalid "required-missing-$field.json" 'TEST-002' 'missing required property'
}

# TEST-003
Expect-Valid 'empty-arrays-valid.json' 'TEST-003'
Expect-Invalid 'duplicate-affected-components.json' 'TEST-003' 'uniqueItems violated'
Expect-Invalid 'duplicate-required-facets.json' 'TEST-003' 'uniqueItems violated'
Expect-Invalid 'duplicate-capabilities.json' 'TEST-003' 'uniqueItems violated'

# TEST-004
Expect-Invalid 'conditional-facet-applied-false-missing-reason.json' 'TEST-004' "missing required property 'reason'"
Expect-Invalid 'conditional-facet-applied-true-with-reason.json' 'TEST-004' "matched a schema under 'not'"
Expect-Valid 'conditional-facet-applied-true-valid.json' 'TEST-004'

# TEST-005
Expect-Invalid 'evidence-invalid-operator.json' 'TEST-005' 'expected one of'
Expect-Invalid 'evidence-warn-missing-reason.json' 'TEST-005' "missing required property 'reason'"
Expect-Valid 'evidence-warn-with-reason-valid.json' 'TEST-005'

# TEST-006
Expect-Invalid 'resolved-gate-invalid-stage.json' 'TEST-006' 'expected one of'
Expect-Valid 'resolved-gate-valid-multi.json' 'TEST-006'

# TEST-007
Expect-Invalid 'capability-minimum-enforcement-invalid-value.json' 'TEST-007' "expected const 'required'"
Expect-Valid 'capability-minimum-enforcement-absent-valid.json' 'TEST-007'
Expect-Valid 'capability-minimum-enforcement-aggregate-valid.json' 'TEST-007'

# TEST-008
Expect-Invalid 'lite-eligibility-missing-upgrade-reasons.json' 'TEST-008' "missing required property 'upgrade_reasons'"
Expect-Valid 'lite-eligibility-empty-upgrade-reasons-valid.json' 'TEST-008'

# TEST-009
Expect-Invalid 'context-binding-malformed-digest.json' 'TEST-009' 'does not match pattern'
Expect-Invalid 'context-binding-empty-dependency-pointers.json' 'TEST-009' '< minItems 1'

# TEST-010
Expect-Invalid 'resolver-malformed-semver.json' 'TEST-010' 'does not match pattern'
Expect-Valid 'resolver-valid-semver.json' 'TEST-010'

# TEST-011
Expect-Valid 'decision-doc-v2-section16-worked-example.json' 'TEST-011'

# TEST-017/018
Expect-Invalid 'dependency-pointer-root-not-allowlisted.json' 'TEST-017' 'does not match pattern'
Expect-Invalid 'dependency-pointer-malformed-rfc6901.json' 'TEST-018' 'does not match pattern'
Expect-Valid 'dependency-pointer-all-roots-valid.json' 'TEST-017/018'

Write-Host 'ok: TEST-041: covered by evidence-warn-{missing-reason,with-reason-valid} above'; $script:Pass++

# TEST-048 (schema half)
Expect-Invalid 'upgrade-reasons-duplicate.json' 'TEST-048' 'uniqueItems violated'

# TEST-034: REQ-007 placement regression
$StructCheck = Join-Path $RepoRoot 'scripts/check-sdd-structure.sh'
$Work = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
$Feature = 'facet-manifest-placement-fixture'
New-Item -ItemType Directory -Force -Path (Join-Path $Work "specs/$Feature") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Work 'reports/implementation') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Work 'reports/quality-gate') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Work 'docs/adr') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Work 'docs/review-tickets') | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $Work 'AGENTS.md') | Out-Null
foreach ($name in @('requirements.md','design.md','ux-spec.md','frontend-spec.md','infra-spec.md','security-spec.md','acceptance-tests.md','tasks.md','traceability.md')) {
    New-Item -ItemType File -Force -Path (Join-Path $Work "specs/$Feature/$name") | Out-Null
}
Copy-Item (Join-Path $Fixtures 'valid-base.json') (Join-Path $Work "specs/$Feature/facet-manifest.yaml")
'schema: sdd-capability-summary/v1' | Out-File -Encoding utf8 -FilePath (Join-Path $Work "specs/$Feature/capability-summary.yaml")

$bash = Get-Command bash -ErrorAction SilentlyContinue
if ($bash) {
    $structOut = & $bash.Path $StructCheck $Work $Feature 2>&1
    $structOutStr = ($structOut -join "`n")
    if ($LASTEXITCODE -eq 0 -and $structOutStr.Contains('check-sdd-structure: OK')) {
        Write-Host 'ok: TEST-034: facet-manifest.yaml/capability-summary.yaml alongside specs/<feature>/ files does not break check-sdd-structure.sh'
        $script:Pass++
    } else {
        Write-Host "FAIL: TEST-034: check-sdd-structure.sh regressed: rc=$LASTEXITCODE out=[$structOutStr]"
        $script:Fail++
    }
} else {
    Write-Host 'SKIP: TEST-034: bash not found on PATH; check-sdd-structure.sh is POSIX sh only'
}
Remove-Item -Recurse -Force $Work -ErrorAction SilentlyContinue

# self-registration
$runAll = Get-Content (Join-Path $RepoRoot 'tests/run-all.ps1') -Raw
if ($runAll.Contains('tests/facet-manifest-schema.tests.ps1')) {
    Write-Host 'ok: self-registration: tests/run-all.ps1 lists this suite'; $script:Pass++
} else {
    Write-Host 'FAIL: self-registration: tests/run-all.ps1 does not list tests/facet-manifest-schema.tests.ps1'; $script:Fail++
}

Write-Host ''
Write-Host "facet-manifest-schema: $($script:Pass) passed, $($script:Fail) failed"
if ($script:Fail -ne 0) { exit 1 }
exit 0
