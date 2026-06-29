$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Feature = 'impl-layer-inputs-ps-fixture'
$Spec = Join-Path $Root "specs/$Feature"
$SpecReport = Join-Path $Root "reports/spec-review/$Feature"
$ImplReport = Join-Path $Root "reports/impl-review/$Feature"
$Registry = Join-Path $Root 'specs/workflow-state-registry.json'
$RegistryOriginal = [IO.File]::ReadAllText($Registry)
$LayerFiles = @('ux-spec.md', 'frontend-spec.md', 'infra-spec.md', 'security-spec.md')

function Hash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLower()
}

function Spec-Hash([string]$Path) {
    $normalized = [IO.File]::ReadAllText($Path) -replace '(?m)^Spec-Review-Status:\s*.*$', 'Spec-Review-Status: Pending'
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($normalized)
    ([BitConverter]::ToString([Security.Cryptography.SHA256]::HashData($bytes))).Replace('-', '').ToLower()
}

function Write-Inputs {
    New-Item -ItemType Directory -Force -Path $Spec | Out-Null
    'Spec-Review-Status: Passed' | Set-Content (Join-Path $Spec 'requirements.md') -Encoding utf8NoBOM
    'Impl-Review-Status: Pending' | Set-Content (Join-Path $Spec 'design.md') -Encoding utf8NoBOM
    '# Acceptance' | Set-Content (Join-Path $Spec 'acceptance-tests.md') -Encoding utf8NoBOM
    foreach ($name in $LayerFiles) {
        "# $name" | Set-Content (Join-Path $Spec $name) -Encoding utf8NoBOM
    }
}

function Write-SpecPass {
    $directory = Join-Path $SpecReport 'attempt-1/round-1'
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $req = Spec-Hash (Join-Path $Spec 'requirements.md')
    $acc = Hash (Join-Path $Spec 'acceptance-tests.md')
    $calibrationPath = 'plugins/sdd-review-loop/references/spec-review-calibration.md'
    $calibration = Hash (Join-Path $Root $calibrationPath)
    [ordered]@{schema='spec-review-precheck/v1';stage='spec';feature=$Feature;attempt=1;round=1;spec_review_status_field='Pending';requirements_sha256=$req;acceptance_sha256=$acc;calibration_sha256=$calibration;input_sha256=$req;edit_summary='';reset=$false;generated_at='2026-06-23T00:00:00Z'} |
        ConvertTo-Json -Depth 5 | Set-Content (Join-Path $directory 'precheck-result.json') -Encoding utf8NoBOM
    $reviewerAIds = @('REQ-TESTABILITY','GOAL-AC-TRACE','AC-OBSERVABLE','SCOPE-BOUNDARY','CONSTRAINTS-EXPLICIT','RISK-VALIDATION-SURFACE')
    $reviewerBIds = @('AMBIGUITY','CONTRADICTION','EDGE-CASE-COVERAGE','ASSUMPTIONS-RESOLVABLE','APPROVAL-BOUNDARY','DOWNSTREAM-READINESS')
    [ordered]@{schema='integrated-summary/v1';attempt=1;round=1;reviewer_a_checks=@($reviewerAIds | ForEach-Object {@{id=$_;result='PASS';severity='Minor'}});reviewer_a_fail_count=0;reviewer_a_pass_count=6;reviewer_a_skip_count=0;generated_at='2026-06-23T00:00:00Z'} |
        ConvertTo-Json -Depth 6 | Set-Content (Join-Path $directory 'integrated-summary.json') -Encoding utf8NoBOM
    $precheck = Hash (Join-Path $directory 'precheck-result.json')
    $summary = Hash (Join-Path $directory 'integrated-summary.json')
    [ordered]@{schema='spec-review-integrated-verdict/v1';stage='spec';feature=$Feature;attempt=1;round=1;reviewer_a_run_id='spec-a';reviewer_b_run_id='spec-b';reviewer_a_host_session_id='session-a';reviewer_b_host_session_id='session-b';finding_counts=@{critical=0;major=0;minor=0};verdict='PASS';warningCount=0} |
        ConvertTo-Json -Depth 5 | Set-Content (Join-Path $directory 'integrated-verdict.json') -Encoding utf8NoBOM
    $manifestA = @(
        @{path="specs/$Feature/requirements.md";sha256=$req},
        @{path="specs/$Feature/acceptance-tests.md";sha256=$acc},
        @{path=$calibrationPath;sha256=$calibration},
        @{path="reports/spec-review/$Feature/attempt-1/round-1/precheck-result.json";sha256=$precheck}
    )
    $manifestB = @($manifestA | ForEach-Object { @{path=$_.path;sha256=$_.sha256} })
    $manifestB += @{path="reports/spec-review/$Feature/attempt-1/round-1/integrated-summary.json";sha256=$summary}
    [ordered]@{schema='spec-reviewer-a/v1';stage='spec';role='spec-reviewer-a';run_id='spec-a';host_session_id='session-a';allowed_input_manifest=$manifestA;verdict='PASS';checks=@($reviewerAIds | ForEach-Object {@{id=$_;result='PASS';severity='Minor';finding='fixture pass'}})} |
        ConvertTo-Json -Depth 7 | Set-Content (Join-Path $directory 'reviewer-a.json') -Encoding utf8NoBOM
    [ordered]@{schema='spec-reviewer-b/v1';stage='spec';role='spec-reviewer-b';run_id='spec-b';host_session_id='session-b';allowed_input_manifest=$manifestB;verdict='PASS';checks=@($reviewerBIds | ForEach-Object {@{id=$_;result='PASS';severity='Minor';finding='fixture pass'}})} |
        ConvertTo-Json -Depth 7 | Set-Content (Join-Path $directory 'reviewer-b.json') -Encoding utf8NoBOM
    [ordered]@{schema='spec-review-contract/v1';stage='spec';feature=$Feature;attempt=1;round=1;run_id='spec-orchestrator';verdict='PASS';warningCount=0;requirements_sha256=$req;acceptance_sha256=$acc;reviewers=@(
        @{role='spec-reviewer-a';run_id='spec-a';host_session_id='session-a';allowed_input_manifest=$manifestA},
        @{role='spec-reviewer-b';run_id='spec-b';host_session_id='session-b';allowed_input_manifest=$manifestB}
    )} | ConvertTo-Json -Depth 7 | Set-Content (Join-Path $directory 'spec-review-contract.json') -Encoding utf8NoBOM
}

try {
    $registryData = $RegistryOriginal | ConvertFrom-Json
    $registryData.entries = @($registryData.entries) + [pscustomobject]@{feature=$Feature;profile='full'}
    $registryData | ConvertTo-Json -Depth 10 | Set-Content $Registry -Encoding utf8NoBOM
    Write-Inputs
    Write-SpecPass

    & (Join-Path $Root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature $Feature -Attempt 1 -Round 1 | Out-Null
    $precheck = Get-Content (Join-Path $ImplReport 'attempt-1/round-1/precheck-result.json') -Raw | ConvertFrom-Json
    foreach ($name in $LayerFiles) {
        $hashValue = $precheck.layer_sha256.$name
        if ($hashValue -notmatch '^[0-9a-f]{64}$') { throw "FAIL: missing hash for $name" }
    }
    Write-Host 'PASS: PowerShell complete layer input set is hash-bound'

    & (Join-Path $Root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature $Feature -Attempt 1 -Round 1 -VerifyInputs | Out-Null
    $registryData = Get-Content $Registry -Raw | ConvertFrom-Json
    @($registryData.entries | Where-Object feature -eq $Feature)[0].profile = 'lite'
    $registryData | ConvertTo-Json -Depth 10 | Set-Content $Registry -Encoding utf8NoBOM
    Add-Content (Join-Path $Spec 'ux-spec.md') 'post-manifest tamper'
    $tamperFailed = $false
    try {
        & (Join-Path $Root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature $Feature -Attempt 1 -Round 1 -VerifyInputs | Out-Null
    } catch { $tamperFailed = $true }
    if (-not $tamperFailed) { throw 'FAIL: PowerShell accepted tamper after registry profile downgrade' }
    Write-Host 'PASS: PowerShell persisted full manifest rejects tamper after registry profile downgrade'
    $registryData = Get-Content $Registry -Raw | ConvertFrom-Json
    @($registryData.entries | Where-Object feature -eq $Feature)[0].profile = 'full'
    $registryData | ConvertTo-Json -Depth 10 | Set-Content $Registry -Encoding utf8NoBOM
    Write-Inputs

    foreach ($name in $LayerFiles) {
        Remove-Item $ImplReport -Recurse -Force -ErrorAction SilentlyContinue
        Move-Item (Join-Path $Spec $name) (Join-Path $Spec "$name.missing")
        $failed = $false
        try {
            & (Join-Path $Root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature $Feature -Attempt 1 -Round 1 | Out-Null
        } catch { $failed = $true }
        if (-not $failed -or (Test-Path $ImplReport)) { throw "FAIL: PowerShell accepted missing $name" }
        Move-Item (Join-Path $Spec "$name.missing") (Join-Path $Spec $name)
    }
    Write-Host 'PASS: PowerShell rejects every missing layer input'

    Remove-Item $ImplReport -Recurse -Force -ErrorAction SilentlyContinue
    $outside = Join-Path ([IO.Path]::GetTempPath()) "impl-layer-$([guid]::NewGuid()).md"
    '# outside' | Set-Content $outside -Encoding utf8NoBOM
    Remove-Item (Join-Path $Spec 'security-spec.md')
    New-Item -ItemType SymbolicLink -Path (Join-Path $Spec 'security-spec.md') -Target $outside | Out-Null
    $substitutionFailed = $false
    try {
        & (Join-Path $Root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature $Feature -Attempt 1 -Round 1 | Out-Null
    } catch { $substitutionFailed = $true }
    if (-not $substitutionFailed -or (Test-Path $ImplReport)) { throw 'FAIL: PowerShell accepted substituted layer input' }
    Remove-Item (Join-Path $Spec 'security-spec.md') -Force -ErrorAction SilentlyContinue
    Remove-Item $outside -Force -ErrorAction SilentlyContinue
    Write-Host 'PASS: PowerShell rejects path-substituted layer input'

    $registryData = Get-Content $Registry -Raw | ConvertFrom-Json
    @($registryData.entries | Where-Object feature -eq $Feature)[0].profile = 'lite'
    $registryData | ConvertTo-Json -Depth 10 | Set-Content $Registry -Encoding utf8NoBOM
    Remove-Item $ImplReport -Recurse -Force -ErrorAction SilentlyContinue
    Write-Inputs
    & (Join-Path $Root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature $Feature -Attempt 1 -Round 1 | Out-Null
    $legacyPrecheck = Get-Content (Join-Path $ImplReport 'attempt-1/round-1/precheck-result.json') -Raw | ConvertFrom-Json
    $legacyMaterial = "$(Hash (Join-Path $Spec 'design.md')):$(Hash (Join-Path $Spec 'requirements.md')):$(Hash (Join-Path $Spec 'acceptance-tests.md'))"
    $legacyExpected = ([BitConverter]::ToString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($legacyMaterial)))).Replace('-', '').ToLower()
    if (@($legacyPrecheck.layer_sha256.psobject.Properties).Count -ne 0 -or $legacyPrecheck.input_sha256 -ne $legacyExpected) {
        throw 'FAIL: PowerShell legacy-compatible profile changed the historical core-input contract hash'
    }
    Write-Host 'PASS: PowerShell rollback fixture preserves the legacy core-input contract hash'
} finally {
    [IO.File]::WriteAllText($Registry, $RegistryOriginal)
    Remove-Item -LiteralPath $Spec,$SpecReport,$ImplReport -Recurse -Force -ErrorAction SilentlyContinue
}
