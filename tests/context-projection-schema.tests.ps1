# context-projection-schema.tests.ps1 — PowerShell twin of
# context-projection-schema.tests.sh (REQ-003/REQ-006, design.md Test
# Strategy item 4). See the .sh suite's own header comment for the full
# rationale (why every fixture is a hand-authored, already-re-keyed
# instance rather than a raw project-context.yaml array-shaped source; why
# there is no YAML/canonicalizer step at all for this validator).
#
# Deliberately does not rely on $ErrorActionPreference = 'Stop' aborting the
# whole script on a missing schema/validator file during a genuine RED run
# (RT-20260817-003 expected_fix item 3): every schema-introspection block
# below is wrapped in its own try/catch, matching the .sh suite's own
# per-assertion guard discipline, so a RED run records one FAIL per affected
# fixture instead of terminating early.
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Validator = Join-Path $RepoRoot 'plugins/sdd-quality-loop/scripts/validate-context-projection.py'
$Schema = Join-Path $RepoRoot 'contracts/context-projection.schema.json'
$Fixtures = Join-Path $RepoRoot 'tests/fixtures/facet-manifest/context-projection'

$script:Pass = 0
$script:Fail = 0

function Get-Python {
    $py = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
    if (-not $py) { throw 'context-projection-schema.tests.ps1: no python3/python on PATH' }
    return $py.Path
}
$Python = Get-Python

function Invoke-Validator([string]$FixturePath) {
    try {
        $out = & $Python $Validator --projection $FixturePath 2>&1
        return @{ Out = ($out -join "`n"); Code = $LASTEXITCODE }
    } catch {
        return @{ Out = $_.Exception.Message; Code = 2 }
    }
}

function Expect-Valid([string]$Fixture, [string]$Name) {
    $path = Join-Path $Fixtures $Fixture
    $r = Invoke-Validator $path
    if ($r.Code -eq 0 -and [string]::IsNullOrEmpty($r.Out)) {
        Write-Host "ok: $Name`: $Fixture valid (exit 0, no diagnostics)"
        $script:Pass++
    } else {
        Write-Host "FAIL: $Name`: $Fixture expected valid, got exit=$($r.Code) output=[$($r.Out)]"
        $script:Fail++
    }
}

function Expect-Invalid([string]$Fixture, [string]$Name, [string]$Needle) {
    $path = Join-Path $Fixtures $Fixture
    $r = Invoke-Validator $path
    if ($r.Code -ne 0 -and $r.Out.Contains($Needle)) {
        Write-Host "ok: $Name`: $Fixture invalid as expected (contains '$Needle')"
        $script:Pass++
    } else {
        Write-Host "FAIL: $Name`: $Fixture expected invalid containing '$Needle', got exit=$($r.Code) output=[$($r.Out)]"
        $script:Fail++
    }
}

# --- schema existence -------------------------------------------------------
if (Test-Path $Schema) {
    Write-Host 'ok: contracts/context-projection.schema.json exists'; $script:Pass++
} else {
    Write-Host 'FAIL: contracts/context-projection.schema.json is missing'; $script:Fail++
}

$SchemaJson = $null
if (Test-Path $Schema) {
    try { $SchemaJson = Get-Content $Schema -Raw | ConvertFrom-Json } catch { $SchemaJson = $null }
}

if ($SchemaJson -and $SchemaJson.'$schema' -eq 'http://json-schema.org/draft-07/schema#') {
    Write-Host 'ok: $schema is draft-07'; $script:Pass++
} else {
    $got = if ($SchemaJson) { $SchemaJson.'$schema' } else { '' }
    Write-Host "FAIL: `$schema expected draft-07, got '$got'"; $script:Fail++
}

$ExpectedSchemaId = 'https://github.com/aharada54914/sdd-forge/contracts/context-projection.schema.json'
if ($SchemaJson -and $SchemaJson.'$id' -ceq $ExpectedSchemaId) {
    Write-Host "ok: `$id exact match ($($SchemaJson.'$id'))"; $script:Pass++
} else {
    $got = if ($SchemaJson) { $SchemaJson.'$id' } else { '' }
    Write-Host "FAIL: `$id expected '$ExpectedSchemaId', got '$got'"; $script:Fail++
}

# --- top-level required set --------------------------------------------------
$ExpectedRequired = @('schema', 'source_sha256', 'workflow', 'components', 'shared_paths')
if ($SchemaJson) {
    $ActualRequired = @($SchemaJson.required)
} else {
    $ActualRequired = @()
}
$RequiredMatches = ($ActualRequired.Count -eq $ExpectedRequired.Count)
if ($RequiredMatches) {
    for ($i = 0; $i -lt $ExpectedRequired.Count; $i++) {
        if ([string]$ActualRequired[$i] -cne $ExpectedRequired[$i]) { $RequiredMatches = $false; break }
    }
}
if ($RequiredMatches) {
    Write-Host "ok: top-level 'required' is exactly the five-field set (AC-015)"; $script:Pass++
} else {
    Write-Host "FAIL: top-level 'required' expected $($ExpectedRequired -join ','), got $($ActualRequired -join ',')"; $script:Fail++
}

# --- workflow sub-object required set ---------------------------------------
$ExpectedWorkflowRequired = @('spec_profile', 'artifact_layout', 'capability_enforcement')
if ($SchemaJson -and $SchemaJson.properties.workflow) {
    $ActualWorkflowRequired = @($SchemaJson.properties.workflow.required)
} else {
    $ActualWorkflowRequired = @()
}
$WorkflowRequiredMatches = ($ActualWorkflowRequired.Count -eq $ExpectedWorkflowRequired.Count)
if ($WorkflowRequiredMatches) {
    for ($i = 0; $i -lt $ExpectedWorkflowRequired.Count; $i++) {
        if ([string]$ActualWorkflowRequired[$i] -cne $ExpectedWorkflowRequired[$i]) { $WorkflowRequiredMatches = $false; break }
    }
}
if ($WorkflowRequiredMatches) {
    Write-Host 'ok: workflow.required is exactly the three-field set'; $script:Pass++
} else {
    Write-Host "FAIL: workflow.required expected $($ExpectedWorkflowRequired -join ','), got $($ActualWorkflowRequired -join ',')"; $script:Fail++
}

# --- Field Requirement Matrix: top-level required fields --------------------
$TopFieldMap = [ordered]@{
    'schema'          = 'schema'
    'source-sha256'   = 'source_sha256'
    'workflow'        = 'workflow'
    'components'      = 'components'
    'shared-paths'    = 'shared_paths'
}
foreach ($slug in $TopFieldMap.Keys) {
    $fieldJson = $TopFieldMap[$slug]
    Expect-Invalid "required-missing-$slug.json" 'top-level required' "missing required property '$fieldJson'"
}

# --- Field Requirement Matrix: workflow sub-object required fields ---------
$WfFieldMap = [ordered]@{
    'spec-profile'            = 'spec_profile'
    'artifact-layout'         = 'artifact_layout'
    'capability-enforcement'  = 'capability_enforcement'
}
foreach ($slug in $WfFieldMap.Keys) {
    $fieldJson = $WfFieldMap[$slug]
    Expect-Invalid "workflow-missing-$slug.json" 'workflow required' "/workflow/$fieldJson`: missing required property '$fieldJson'"
}

# --- enum branches -----------------------------------------------------------
Expect-Invalid 'workflow-spec-profile-invalid.json' 'spec_profile enum' "/workflow/spec_profile: expected one of ['full', 'lite']"
Expect-Invalid 'workflow-artifact-layout-invalid.json' 'artifact_layout enum' "/workflow/artifact_layout: expected one of ['lite-three-file', 'legacy-seven-layer', 'facet-hybrid', 'facet-native']"
Expect-Invalid 'workflow-capability-enforcement-invalid.json' 'capability_enforcement enum' "/workflow/capability_enforcement: expected one of ['advisory', 'required']"

# --- schema const branch -----------------------------------------------------
Expect-Invalid 'schema-invalid-const.json' 'schema const' "/schema: expected const 'sdd-context-projection/v1'"

# --- TEST-015: re-keying proof + source-omission normalization (AC-015) ----
Expect-Valid 'rekeyed-two-component-non-slug-id.json' 'TEST-015'
$RekeyFixturePath = Join-Path $Fixtures 'rekeyed-two-component-non-slug-id.json'
$RekeyDoc = Get-Content $RekeyFixturePath -Raw | ConvertFrom-Json
$RekeyComponents = $RekeyDoc.components
$RekeyKeys = @($RekeyComponents.PSObject.Properties.Name)
# -ccontains (case-sensitive) below: PowerShell's default -contains/-eq are
# case-insensitive, which would let a wrong-case key silently pass this
# check (repo convention: default PS comparison operators are
# case-insensitive by default -- verify with -c-prefixed variants when the
# check is meant to be exact).
$RekeyHasNoIdDesktop = -not ($RekeyComponents.'desktop-client'.PSObject.Properties.Name -ccontains 'id')
$RekeyHasNoIdApp = -not ($RekeyComponents.'Desktop/App'.PSObject.Properties.Name -ccontains 'id')
$RekeyKeysMatch = ($RekeyKeys.Count -eq 2) -and ($RekeyKeys -ccontains 'Desktop/App') -and ($RekeyKeys -ccontains 'desktop-client')
if ($RekeyKeysMatch -and $RekeyHasNoIdDesktop -and $RekeyHasNoIdApp) {
    Write-Host "ok: TEST-015: components re-keys to exactly two id-valued keys (incl. non-slug 'Desktop/App'), no 'id' sub-field"
    $script:Pass++
} else {
    Write-Host "FAIL: TEST-015: re-keying shape check failed: keys=$($RekeyKeys -join ',')"
    $script:Fail++
}

Expect-Valid 'source-omission-empty-valid.json' 'TEST-015 (B8 source-omission)'
$OmissionFixturePath = Join-Path $Fixtures 'source-omission-empty-valid.json'
$OmissionDoc = Get-Content $OmissionFixturePath -Raw | ConvertFrom-Json
$OmissionComponentsEmpty = ($OmissionDoc.components.PSObject.Properties.Name.Count -eq 0)
$OmissionSharedPathsEmpty = (@($OmissionDoc.shared_paths).Count -eq 0)
if ($OmissionComponentsEmpty -and $OmissionSharedPathsEmpty) {
    Write-Host 'ok: TEST-015 (B8): source-omission fixture materializes components: {} / shared_paths: []'
    $script:Pass++
} else {
    Write-Host 'FAIL: TEST-015 (B8): components/shared_paths not both empty'
    $script:Fail++
}

# --- TEST-016: end-to-end RFC 6901 pointer resolution (AC-016) -------------
$ArtifactKinds = @($RekeyDoc.components.'desktop-client'.artifact_kinds)
if ($ArtifactKinds.Count -eq 2 -and $ArtifactKinds[0] -eq 'executable' -and $ArtifactKinds[1] -eq 'installer') {
    Write-Host "ok: TEST-016: /components/desktop-client/artifact_kinds resolves to a real value ($($ArtifactKinds -join ','))"
    $script:Pass++
} else {
    Write-Host "FAIL: TEST-016: expected /components/desktop-client/artifact_kinds to resolve to executable,installer, got $($ArtifactKinds -join ',')"
    $script:Fail++
}

# --- TEST-030: validate-context-projection.py exit-0/non-zero contract
# (AC-030) --------------------------------------------------------------
Expect-Valid 'rekeyed-two-component-non-slug-id.json' 'TEST-030'
Expect-Invalid 'components-still-array-shaped.json' 'TEST-030' "/components: expected type 'object', got list"

# --- TEST-042: shared_paths[] oneOf branch (AC-042) -------------------------
Expect-Valid 'shared-path-bounded-valid.json' 'TEST-042 (bounded)'
Expect-Valid 'shared-path-unbounded-valid.json' 'TEST-042 (unbounded)'
Expect-Invalid 'shared-path-both-rejected.json' 'TEST-042 (both)' "/shared_paths/0: expected exactly one 'oneOf' branch to match, 2 matched"
Expect-Invalid 'shared-path-neither-rejected.json' 'TEST-042 (neither)' "/shared_paths/0: expected exactly one 'oneOf' branch to match, 0 matched"

# --- Regression lock: shared_paths[] items' own top-level 'pattern' is
# still required regardless of which oneOf branch is chosen -----------------
Expect-Invalid 'shared-path-missing-pattern.json' "shared_paths[] required 'pattern'" "/shared_paths/0/pattern: missing required property 'pattern'"

# --- Regression lock: source_sha256 / provider_bindings_sha256 digest
# pattern is enforced (design.md's own keyword-audit paragraph omits
# 'pattern' from this schema's keyword list -- see this task's
# Specification Differences note). ------------------------------------------
Expect-Invalid 'source-sha256-malformed-digest.json' 'source_sha256 pattern regression' '/source_sha256: does not match pattern'
Expect-Invalid 'provider-bindings-sha256-malformed-digest.json' 'provider_bindings_sha256 pattern regression' '/provider_bindings_sha256: does not match pattern'

# --- ECMA pattern semantics: trailing-newline digest value rejected --------
# Regression lock for this validator's own _ecma_anchor/_compile_pattern
# pair (T-001 quality-gate lesson, RT-20260817-003).
Expect-Invalid 'source-sha256-trailing-newline.json' 'ECMA pattern semantics: trailing-newline source_sha256 rejected' '/source_sha256: does not match pattern'

# --- Diagnostic determinism: multi-diagnostic ordering (check-id, pointer) -
$ExpectedLine1 = "context-projection: schema-invalid: /schema: expected const 'sdd-context-projection/v1', got 'sdd-facet-manifest/v1'"
$ExpectedLine2 = "context-projection: schema-invalid: /workflow/capability_enforcement: expected one of ['advisory', 'required'], got 'optional'"
$MultiPath = Join-Path $Fixtures 'multi-diagnostic-ordering.json'
$MultiResult = Invoke-Validator $MultiPath
$ExpectedMulti = "$ExpectedLine1`n$ExpectedLine2"
if ($MultiResult.Code -ne 0 -and $MultiResult.Out -ceq $ExpectedMulti) {
    Write-Host 'ok: diagnostic determinism: multi-diagnostic-ordering.json emits exactly 2 lines in (check-id, pointer) order'
    $script:Pass++
} else {
    Write-Host "FAIL: diagnostic determinism: expected exit!=0 and exact 2-line output [$ExpectedMulti], got exit=$($MultiResult.Code) output=[$($MultiResult.Out)]"
    $script:Fail++
}

# --- projection-unreadable regression lock ----------------------------------
$MissingProjection = Join-Path $Fixtures 'does-not-exist.json'
$CanonResult = Invoke-Validator $MissingProjection
if ($CanonResult.Code -ne 0 -and $CanonResult.Out.Contains('context-projection: projection-unreadable:')) {
    Write-Host "ok: projection-unreadable: nonexistent .json path fails closed (exit=$($CanonResult.Code), contains diagnostic)"
    $script:Pass++
} else {
    Write-Host "FAIL: projection-unreadable: expected exit!=0 and diagnostic, got exit=$($CanonResult.Code) output=[$($CanonResult.Out)]"
    $script:Fail++
}

# --- self-registration -------------------------------------------------------
$RunAllPath = Join-Path $RepoRoot 'tests/run-all.ps1'
if (Test-Path $RunAllPath) {
    $runAll = Get-Content $RunAllPath -Raw
} else {
    $runAll = ''
}
if ($runAll.Contains('tests/context-projection-schema.tests.ps1')) {
    Write-Host 'ok: self-registration: tests/run-all.ps1 lists this suite'; $script:Pass++
} else {
    Write-Host 'FAIL: self-registration: tests/run-all.ps1 does not list tests/context-projection-schema.tests.ps1'; $script:Fail++
}

Write-Host ''
Write-Host "context-projection-schema: $($script:Pass) passed, $($script:Fail) failed"
if ($script:Fail -ne 0) { exit 1 }
exit 0
