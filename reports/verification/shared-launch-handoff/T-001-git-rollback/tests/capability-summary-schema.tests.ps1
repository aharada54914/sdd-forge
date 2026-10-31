# capability-summary-schema.tests.ps1 — PowerShell twin of
# capability-summary-schema.tests.sh (REQ-002/REQ-006, design.md Test
# Strategy item 3). One fixture, canonicalizer-roundtrip-valid.yaml, is real
# YAML routed through the --summary <path>.yaml branch to exercise the
# actual canonicalize-sdd-yaml subprocess end-to-end (tasks.md External
# Checkout Constraints Done-gating condition, re-verified present at this
# task's implementation-start time).
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Validator = Join-Path $RepoRoot 'plugins/sdd-quality-loop/scripts/validate-capability-summary.py'
$Schema = Join-Path $RepoRoot 'contracts/capability-summary.schema.json'
$Fixtures = Join-Path $RepoRoot 'tests/fixtures/facet-manifest/capability-summary'

$script:Pass = 0
$script:Fail = 0

function Get-Python {
    $py = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
    if (-not $py) { throw 'capability-summary-schema.tests.ps1: no python3/python on PATH' }
    return $py.Path
}
$Python = Get-Python

function Invoke-Validator([string]$FixtureName) {
    $path = Join-Path $Fixtures $FixtureName
    $out = & $Python $Validator --summary $path 2>&1
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

# schema existence
if (Test-Path $Schema) {
    Write-Host 'ok: contracts/capability-summary.schema.json exists'; $script:Pass++
} else {
    Write-Host 'FAIL: contracts/capability-summary.schema.json is missing'; $script:Fail++
}
$SchemaJson = Get-Content $Schema -Raw | ConvertFrom-Json
if ($SchemaJson.'$schema' -eq 'http://json-schema.org/draft-07/schema#') {
    Write-Host 'ok: $schema is draft-07'; $script:Pass++
} else {
    Write-Host "FAIL: `$schema expected draft-07, got '$($SchemaJson.'$schema')'"; $script:Fail++
}
$ExpectedSchemaId = 'https://github.com/aharada54914/sdd-forge/contracts/capability-summary.schema.json'
if ($SchemaJson.'$id' -ceq $ExpectedSchemaId) {
    Write-Host "ok: `$id exact match ($($SchemaJson.'$id'))"; $script:Pass++
} else {
    Write-Host "FAIL: `$id expected '$ExpectedSchemaId', got '$($SchemaJson.'$id')'"; $script:Fail++
}

# TEST-012: Lite-only required-field set (AC-012)
$ExpectedRequired = @('schema','feature','track','capabilities','required_lite_checks','full_upgrade_required')
$ActualRequired = @($SchemaJson.required)
$RequiredMatches = ($ActualRequired.Count -eq $ExpectedRequired.Count)
if ($RequiredMatches) {
    for ($i = 0; $i -lt $ExpectedRequired.Count; $i++) {
        if ([string]$ActualRequired[$i] -cne $ExpectedRequired[$i]) { $RequiredMatches = $false; break }
    }
}
if ($RequiredMatches) {
    Write-Host "ok: TEST-012: top-level 'required' is exactly the six-field Lite-only set"; $script:Pass++
} else {
    Write-Host "FAIL: TEST-012: top-level 'required' expected $($ExpectedRequired -join ','), got $($ActualRequired -join ',')"; $script:Fail++
}
if ($SchemaJson.properties.track.const -ceq 'lite') {
    Write-Host "ok: TEST-012: 'track' is const 'lite' -- no full-track branch in this schema"; $script:Pass++
} else {
    Write-Host "FAIL: TEST-012: 'track' expected const 'lite', got '$($SchemaJson.properties.track.const)'"; $script:Fail++
}

# Field-specific needles (not the generic 'missing required property'
# substring): each fixture below is verified (ad hoc, at suite-authoring
# time) to omit exactly ONE top-level required field.
$ReqFieldMap = [ordered]@{
    'schema'                    = 'schema'
    'feature'                   = 'feature'
    'track'                     = 'track'
    'capabilities'              = 'capabilities'
    'required-lite-checks'      = 'required_lite_checks'
    'full-upgrade-required'     = 'full_upgrade_required'
}
foreach ($slug in $ReqFieldMap.Keys) {
    $fieldJson = $ReqFieldMap[$slug]
    Expect-Invalid "required-missing-$slug.json" 'TEST-012' "missing required property '$fieldJson'"
}

# TEST-013: decision document v2 section 6's own Lite worked example
Expect-Valid 'decision-doc-v2-section6-worked-example.json' 'TEST-013'

# TEST-013 / TEST-029 YAML round-trip: real canonicalize-sdd-yaml subprocess,
# not a pre-canonical JSON fixture (see file header).
Expect-Valid 'canonicalizer-roundtrip-valid.yaml' 'TEST-013 YAML round-trip (real canonicalizer subprocess)'

# TEST-014: additionalProperties: false rejects an extra field
Expect-Invalid 'extra-property-facet-manifest-ref-invalid.json' 'TEST-014' '/facet_manifest_ref: additional property not allowed'

# Regression lock: 'track' const rejects any non-'lite' value, including the
# retired full-track discriminator value itself ("M full Summary").
Expect-Invalid 'track-invalid-value.json' 'TEST-012 regression' "/track: expected const 'lite', got 'full'"

# Regression lock: 'feature' pattern is enforced (design.md's own
# keyword-audit paragraph omits 'pattern' from this schema's keyword list,
# but the schema's own committed JSON block declares feature.pattern -- see
# this task's Specification Differences note).
Expect-Invalid 'feature-invalid-pattern.json' 'feature pattern regression' '/feature: does not match pattern'

# ECMA pattern semantics: trailing-newline feature value rejected. Regression
# lock for this validator's own _ecma_anchor/_compile_pattern pair.
Expect-Invalid 'feature-trailing-newline.json' 'ECMA pattern semantics: trailing-newline feature rejected' '/feature: does not match pattern'

# Diagnostic determinism: multi-diagnostic ordering (check-id, pointer).
# Two simultaneous violations (feature pattern + track const) must appear as
# two exact lines, ordered ascending by JSON Pointer.
$ExpectedLine1 = "capability-summary: schema-invalid: /feature: does not match pattern '^[a-z0-9][a-z0-9-]*`$'"
$ExpectedLine2 = "capability-summary: schema-invalid: /track: expected const 'lite', got 'full'"
$MultiResult = Invoke-Validator 'multi-diagnostic-ordering.json'
$ExpectedMulti = "$ExpectedLine1`n$ExpectedLine2"
if ($MultiResult.Code -ne 0 -and $MultiResult.Out -ceq $ExpectedMulti) {
    Write-Host 'ok: diagnostic determinism: multi-diagnostic-ordering.json emits exactly 2 lines in (check-id, pointer) order'
    $script:Pass++
} else {
    Write-Host "FAIL: diagnostic determinism: expected exit!=0 and exact 2-line output [$ExpectedMulti], got exit=$($MultiResult.Code) output=[$($MultiResult.Out)]"
    $script:Fail++
}

# TEST-029: validate-capability-summary.py exit-0/non-zero contract (AC-029)
$Exit0Result = Invoke-Validator 'decision-doc-v2-section6-worked-example.json'
if ($Exit0Result.Code -eq 0 -and [string]::IsNullOrEmpty($Exit0Result.Out)) {
    Write-Host "ok: TEST-029: validate-capability-summary.py exits 0 on AC-013's own worked-example fixture"
    $script:Pass++
} else {
    Write-Host "FAIL: TEST-029: expected exit 0 with no output on the worked example, got exit=$($Exit0Result.Code) output=[$($Exit0Result.Out)]"
    $script:Fail++
}
$NonzeroResult = Invoke-Validator 'extra-property-facet-manifest-ref-invalid.json'
if ($NonzeroResult.Code -ne 0 -and $NonzeroResult.Out.Contains('capability-summary: schema-invalid:')) {
    Write-Host "ok: TEST-029: validate-capability-summary.py exits non-zero with 'capability-summary: schema-invalid:' on AC-014's fixture"
    $script:Pass++
} else {
    Write-Host "FAIL: TEST-029: expected exit!=0 with 'capability-summary: schema-invalid:', got exit=$($NonzeroResult.Code) output=[$($NonzeroResult.Out)]"
    $script:Fail++
}

# canonicalizer-invocation-failed regression lock: a nonexistent .yaml path
# must surface the validator's own canonicalizer-invocation-failed
# diagnostic (fail-closed YAML parse contract), not a traceback or a silent
# pass. No fixture file needed -- the path is intentionally absent.
$MissingYaml = Join-Path $Fixtures 'does-not-exist.yaml'
$canonOut = & $Python $Validator --summary $MissingYaml 2>&1
$canonOutStr = ($canonOut -join "`n")
if ($LASTEXITCODE -ne 0 -and $canonOutStr.Contains('capability-summary: canonicalizer-invocation-failed:')) {
    Write-Host "ok: canonicalizer-invocation-failed: nonexistent .yaml path fails closed (exit=$LASTEXITCODE, contains diagnostic)"
    $script:Pass++
} else {
    Write-Host "FAIL: canonicalizer-invocation-failed: expected exit!=0 and diagnostic, got exit=$LASTEXITCODE output=[$canonOutStr]"
    $script:Fail++
}

# summary-unreadable regression lock: non-UTF-8 bytes (RT-20260817-004 --
# T-001..T-004 quality-gate lesson: `except (OSError, json.JSONDecodeError)`
# in main()'s --summary .json branch let a non-UTF-8 byte stream leak an
# unhandled Python traceback instead of the 'summary-unreadable'
# diagnostic -- fixed to `except (OSError, ValueError)` (json.JSONDecodeError
# is itself a ValueError subclass, so this still covers it);
# validate-context-projection.py/compare-facet-manifest-staleness.py
# already carried this fix, this suite locks the last gap.
$NonUtf8Summary = Join-Path $Fixtures 'summary-non-utf8-bytes.bin'
$nonUtf8Out = & $Python $Validator --summary $NonUtf8Summary 2>&1
$nonUtf8OutStr = ($nonUtf8Out -join "`n")
if ($LASTEXITCODE -ne 0 -and $nonUtf8OutStr.Contains('capability-summary: summary-unreadable:') -and -not $nonUtf8OutStr.Contains('Traceback')) {
    Write-Host "ok: summary-unreadable: non-UTF-8 byte input fails closed (exit=$LASTEXITCODE, single-line diagnostic, no traceback)"
    $script:Pass++
} else {
    Write-Host "FAIL: summary-unreadable: non-UTF-8 byte input expected exit!=0, diagnostic, no traceback, got exit=$LASTEXITCODE output=[$nonUtf8OutStr]"
    $script:Fail++
}
$nonUtf8LineCount = ($nonUtf8Out | Measure-Object).Count
if ($nonUtf8LineCount -eq 1) {
    Write-Host 'ok: summary-unreadable: non-UTF-8 byte input diagnostic is exactly one line'
    $script:Pass++
} else {
    Write-Host "FAIL: summary-unreadable: non-UTF-8 byte input expected exactly one diagnostic line, got $nonUtf8LineCount`: [$nonUtf8OutStr]"
    $script:Fail++
}

# self-registration
$runAll = Get-Content (Join-Path $RepoRoot 'tests/run-all.ps1') -Raw
if ($runAll.Contains('tests/capability-summary-schema.tests.ps1')) {
    Write-Host 'ok: self-registration: tests/run-all.ps1 lists this suite'; $script:Pass++
} else {
    Write-Host 'FAIL: self-registration: tests/run-all.ps1 does not list tests/capability-summary-schema.tests.ps1'; $script:Fail++
}

Write-Host ''
Write-Host "capability-summary-schema: $($script:Pass) passed, $($script:Fail) failed"
if ($script:Fail -ne 0) { exit 1 }
exit 0
