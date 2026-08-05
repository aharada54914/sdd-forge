# facet-manifest-semantics.tests.ps1 — PowerShell twin of
# facet-manifest-semantics.tests.sh (design.md Test Strategy item 2).
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Validator = Join-Path $RepoRoot 'plugins/sdd-quality-loop/scripts/validate-facet-manifest.py'
$Fixtures = Join-Path $RepoRoot 'tests/fixtures/facet-manifest/semantics'

$script:Pass = 0
$script:Fail = 0

function Get-Python {
    $py = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
    if (-not $py) { throw 'facet-manifest-semantics.tests.ps1: no python3/python on PATH' }
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

# TEST-028
Expect-Invalid 'resolved-gate-id-duplicate.json' 'TEST-028' 'facet-manifest: resolved-gate-id-duplicate:'
Expect-Invalid 'facet-classification-conflict.json' 'TEST-028' 'facet-manifest: facet-classification-conflict:'
Expect-Invalid 'conditional-facet-duplicate.json' 'TEST-028' 'facet-manifest: conditional-facet-duplicate:'
Expect-Invalid 'affected-components-not-sorted.json' 'TEST-028' 'facet-manifest: array-not-stable-sorted:'
Expect-Valid 'fully-clean.json' 'TEST-028 negative proof'

# AC-047
Expect-Invalid 'conditional-facet-duplicate.json' 'AC-047' 'duplicate conditional_facets facet'

# array-not-stable-sorted remaining scope
Expect-Invalid 'required-facets-not-sorted.json' 'array-not-stable-sorted' 'facet-manifest: array-not-stable-sorted: /required_facets:'
Expect-Invalid 'capabilities-not-sorted.json' 'array-not-stable-sorted' 'facet-manifest: array-not-stable-sorted: /capabilities:'
Expect-Invalid 'upgrade-reasons-not-sorted.json' 'array-not-stable-sorted / AC-048 semantic half' 'facet-manifest: array-not-stable-sorted: /lite_eligibility/upgrade_reasons:'
Expect-Invalid 'conditional-facets-not-sorted.json' 'array-not-stable-sorted' 'facet-manifest: array-not-stable-sorted: /conditional_facets:'
Expect-Invalid 'resolved-gates-not-sorted.json' 'array-not-stable-sorted' 'facet-manifest: array-not-stable-sorted: /resolved_gates:'

# determinism: single-diagnostic fixture -> exactly one line
$multi = Invoke-Validator 'resolved-gate-id-duplicate.json'
$lineCount = ($multi.Out -split "`n").Count
if ($lineCount -eq 1) {
    Write-Host 'ok: determinism: single-diagnostic fixture emits exactly one line'; $script:Pass++
} else {
    Write-Host "FAIL: determinism: unexpected line count ($lineCount) for resolved-gate-id-duplicate.json: [$($multi.Out)]"; $script:Fail++
}

# self-registration
$runAll = Get-Content (Join-Path $RepoRoot 'tests/run-all.ps1') -Raw
if ($runAll.Contains('tests/facet-manifest-semantics.tests.ps1')) {
    Write-Host 'ok: self-registration: tests/run-all.ps1 lists this suite'; $script:Pass++
} else {
    Write-Host 'FAIL: self-registration: tests/run-all.ps1 does not list tests/facet-manifest-semantics.tests.ps1'; $script:Fail++
}

Write-Host ''
Write-Host "facet-manifest-semantics: $($script:Pass) passed, $($script:Fail) failed"
if ($script:Fail -ne 0) { exit 1 }
exit 0
