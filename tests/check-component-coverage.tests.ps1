# tests/check-component-coverage.tests.ps1 - PowerShell twin of
# tests/check-component-coverage.tests.sh (epic-191-a3-path-ownership
# T-004). See the bash twin for the full TEST-NNN/AC-NNN mapping.
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPs1 = Join-Path $repoRoot "plugins/sdd-quality-loop/scripts/check-component-coverage.ps1"
$resolverPs1 = Join-Path $repoRoot "plugins/sdd-quality-loop/scripts/resolve-component-paths.ps1"
$fixtures = Join-Path $repoRoot "tests/fixtures/check-component-coverage"
$powerShell = (Get-Process -Id $PID).Path

$script:passCount = 0
$script:failCount = 0
function Ok([string]$Name) { Write-Output "ok: $Name"; $script:passCount++ }
function Fail([string]$Name) { Write-Output "FAIL: $Name"; $script:failCount++ }

function Invoke-Gate {
    param([string]$ConfigPath, [string]$FacetManifest, [string]$ChangedPathsFile, [string]$ProviderBindings)
    $gateArgs = @("-Config", $ConfigPath, "-ChangedPathsFile", $ChangedPathsFile)
    if ($FacetManifest) { $gateArgs += @("-FacetManifest", $FacetManifest) }
    if ($ProviderBindings) { $gateArgs += @("-ProviderBindings", $ProviderBindings) }
    $out = & $powerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPs1 @gateArgs 2>&1 | Out-String -Width 4096
    return @{ Output = $out; ExitCode = $LASTEXITCODE }
}

function Invoke-Diagnose {
    param([string]$ConfigPath, [string]$ChangedPathsFile)
    $out = & $powerShell -NoProfile -ExecutionPolicy Bypass -File $resolverPs1 -Config $ConfigPath -ChangedPathsFile $ChangedPathsFile -Diagnose 2>&1 | Out-String -Width 4096
    return @{ Output = $out; ExitCode = $LASTEXITCODE }
}

# ============================================================================
# TEST-026/027: applicability derivation, disabled-legacy truthful record
# ============================================================================
Write-Output "=== TEST-026/027: applicability derivation, disabled-legacy ==="
$r = Invoke-Gate (Join-Path $fixtures "config-disabled-legacy.yaml") (Join-Path $fixtures "facet-manifest-full.json") (Join-Path $fixtures "changed-paths-clean.txt") $null
$obj = $r.Output | ConvertFrom-Json
if ($obj.state -eq "not-applicable (disabled-legacy)" -and $obj.manifest_status -eq "not-consulted") {
    Ok "TEST-026.1: a present Facet Manifest under disabled-legacy still records disabled-legacy"
} else {
    Fail "TEST-026.1: expected disabled-legacy/not-consulted, got state=$($obj.state) manifest_status=$($obj.manifest_status)"
}
if ($obj.fail_conditions.Count -eq 0 -and $obj.schema -eq "check-component-coverage-verdict/v1") {
    Ok "TEST-027.1: disabled-legacy performs zero Fail-condition evaluation and emits a real, schema-tagged record"
} else {
    Fail "TEST-027.1: expected fail_conditions empty and correct schema"
}
if ($r.ExitCode -eq 0) { Ok "TEST-027.2: disabled-legacy exits 0" } else { Fail "TEST-027.2: expected exit 0, got $($r.ExitCode)" }

# ============================================================================
# TEST-028: manifest-required hard error
# ============================================================================
Write-Output "=== TEST-028: manifest-required hard error ==="
$r = Invoke-Gate (Join-Path $fixtures "config-advisory.yaml") (Join-Path $fixtures "does-not-exist.json") (Join-Path $fixtures "changed-paths-clean.txt") $null
if ($r.ExitCode -eq 2 -and ($r.Output | ConvertFrom-Json).error) {
    Ok "TEST-028.1: a missing Facet Manifest in advisory state is a hard error (exit 2)"
} else {
    Fail "TEST-028.1: expected exit 2 + error field, got exit=$($r.ExitCode)"
}
$r = Invoke-Gate (Join-Path $fixtures "config-advisory.yaml") "" (Join-Path $fixtures "changed-paths-clean.txt") $null
if ($r.ExitCode -eq 2) { Ok "TEST-028.2: -FacetManifest omitted entirely is also a hard error" } else { Fail "TEST-028.2: expected exit 2, got $($r.ExitCode)" }

# ============================================================================
# TEST-029: --diagnose never Gate-invoked
# ============================================================================
Write-Output "=== TEST-029: -Diagnose never Gate-invoked ==="
$r = Invoke-Diagnose (Join-Path $fixtures "config-advisory.yaml") (Join-Path $fixtures "changed-paths-fail1.txt")
$obj = $r.Output | ConvertFrom-Json
if ($obj.schema -eq "resolve-component-paths-diagnose/v1") {
    Ok "TEST-029.1: -Diagnose emits its own distinct schema, never the Gate's verdict schema"
} else {
    Fail "TEST-029.1: expected resolve-component-paths-diagnose/v1, got $($obj.schema)"
}
$skillText = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "plugins/sdd-quality-loop/skills/quality-gate/SKILL.md")
if ($skillText -notmatch "resolve-component-paths --diagnose|resolve-component-paths\.(sh|ps1) --?[Dd]iagnose") {
    Ok "TEST-029.2: quality-gate/SKILL.md's ## Process never invokes -Diagnose"
} else {
    Fail "TEST-029.2: -Diagnose must never appear in quality-gate/SKILL.md's Process"
}

# ============================================================================
# TEST-030: one fixture per Fail-1..6, identical advisory/required
# ============================================================================
Write-Output "=== TEST-030: one fixture per Fail-1..6, identical advisory/required ==="
function Test-FailIdentical {
    param([string]$Label, [string]$CfgAdv, [string]$CfgReq, [string]$Fm, [string]$Cpf, [string]$Pb, [string]$FailId)
    $rAdv = Invoke-Gate $CfgAdv $Fm $Cpf $Pb
    $rReq = Invoke-Gate $CfgReq $Fm $Cpf $Pb
    $objAdv = $rAdv.Output | ConvertFrom-Json
    $objReq = $rReq.Output | ConvertFrom-Json
    $tAdv = ($objAdv.fail_conditions | Where-Object { $_.id -eq $FailId }).triggered
    $tReq = ($objReq.fail_conditions | Where-Object { $_.id -eq $FailId }).triggered
    if ($tAdv -eq $true -and $tReq -eq $true) {
        Ok "TEST-030 ($Label): $FailId triggers identically in advisory and required"
    } else {
        Fail "TEST-030 ($Label): expected both true, got advisory=$tAdv required=$tReq"
    }
}
Test-FailIdentical "Fail-1" (Join-Path $fixtures "config-advisory.yaml") (Join-Path $fixtures "config-required.yaml") (Join-Path $fixtures "facet-manifest-full.json") (Join-Path $fixtures "changed-paths-fail1.txt") $null "Fail-1"
Test-FailIdentical "Fail-2" (Join-Path $fixtures "config-advisory.yaml") (Join-Path $fixtures "config-required.yaml") (Join-Path $fixtures "facet-manifest-desktop-only.json") (Join-Path $fixtures "changed-paths-fail2.txt") $null "Fail-2"
Test-FailIdentical "Fail-3" (Join-Path $fixtures "config-overlap.yaml") (Join-Path $fixtures "config-overlap-required.yaml") (Join-Path $fixtures "facet-manifest-full.json") (Join-Path $fixtures "changed-paths-fail3.txt") $null "Fail-3"
Test-FailIdentical "Fail-4" (Join-Path $fixtures "config-advisory.yaml") (Join-Path $fixtures "config-required.yaml") (Join-Path $fixtures "facet-manifest-desktop-only.json") (Join-Path $fixtures "changed-paths-fail4.txt") $null "Fail-4"
Test-FailIdentical "Fail-5" (Join-Path $fixtures "config-advisory.yaml") (Join-Path $fixtures "config-required.yaml") (Join-Path $fixtures "facet-manifest-full.json") (Join-Path $fixtures "changed-paths-fail5.txt") $null "Fail-5"
Test-FailIdentical "Fail-6" (Join-Path $fixtures "config-advisory.yaml") (Join-Path $fixtures "config-required.yaml") (Join-Path $fixtures "facet-manifest-full.json") (Join-Path $fixtures "changed-paths-fail6.txt") (Join-Path $fixtures "provider-bindings-match.json") "Fail-6"

# ============================================================================
# TEST-031: Fail-2/Fail-4 mutual exclusivity
# ============================================================================
Write-Output "=== TEST-031: Fail-2/Fail-4 mutual exclusivity ==="
$r = Invoke-Gate (Join-Path $fixtures "config-advisory.yaml") (Join-Path $fixtures "facet-manifest-desktop-only.json") (Join-Path $fixtures "changed-paths-fail2.txt") $null
$obj = $r.Output | ConvertFrom-Json
$f2 = ($obj.fail_conditions | Where-Object { $_.id -eq "Fail-2" }).triggered
$f4 = ($obj.fail_conditions | Where-Object { $_.id -eq "Fail-4" }).triggered
if ($f2 -eq $true -and $f4 -eq $false) { Ok "TEST-031.1: an EXCLUSIVE-owner mismatch triggers Fail-2 only" } else { Fail "TEST-031.1: expected Fail-2=true Fail-4=false, got $f2/$f4" }
$r = Invoke-Gate (Join-Path $fixtures "config-advisory.yaml") (Join-Path $fixtures "facet-manifest-desktop-only.json") (Join-Path $fixtures "changed-paths-fail4.txt") $null
$obj = $r.Output | ConvertFrom-Json
$f2 = ($obj.fail_conditions | Where-Object { $_.id -eq "Fail-2" }).triggered
$f4 = ($obj.fail_conditions | Where-Object { $_.id -eq "Fail-4" }).triggered
if ($f2 -eq $false -and $f4 -eq $true) { Ok "TEST-031.2: a bounded shared_paths shortfall triggers Fail-4 only" } else { Fail "TEST-031.2: expected Fail-2=false Fail-4=true, got $f2/$f4" }

# ============================================================================
# TEST-032: Fail-5 Gate-level reachability
# ============================================================================
Write-Output "=== TEST-032: Fail-5 Gate-level reachability ==="
$r = Invoke-Gate (Join-Path $fixtures "config-advisory.yaml") (Join-Path $fixtures "facet-manifest-full.json") (Join-Path $fixtures "changed-paths-fail5.txt") $null
$obj = $r.Output | ConvertFrom-Json
$f5 = ($obj.fail_conditions | Where-Object { $_.id -eq "Fail-5" }).triggered
if ($f5 -eq $true) { Ok "TEST-032.1: an EXCLUDED_MATCH path reaches the Gate as a Fail-5 trigger" } else { Fail "TEST-032.1: expected Fail-5 triggered" }

# ============================================================================
# TEST-033/034: Fail-6 adapter_paths rule
# ============================================================================
Write-Output "=== TEST-033/034: Fail-6 adapter_paths rule ==="
$r = Invoke-Gate (Join-Path $fixtures "config-advisory.yaml") (Join-Path $fixtures "facet-manifest-full.json") (Join-Path $fixtures "changed-paths-fail6.txt") (Join-Path $fixtures "provider-bindings-match.json")
$obj = $r.Output | ConvertFrom-Json
$f6 = ($obj.fail_conditions | Where-Object { $_.id -eq "Fail-6" }).triggered
if ($f6 -eq $true) { Ok "TEST-033.1: an adapter_paths glob match triggers Fail-6" } else { Fail "TEST-033.1: expected Fail-6 triggered" }

$r = Invoke-Gate (Join-Path $fixtures "config-advisory.yaml") (Join-Path $fixtures "facet-manifest-full.json") (Join-Path $fixtures "changed-paths-fail6.txt") (Join-Path $fixtures "provider-bindings-no-adapter.json")
$obj = $r.Output | ConvertFrom-Json
$f6 = ($obj.fail_conditions | Where-Object { $_.id -eq "Fail-6" }).triggered
if ($f6 -eq $false -and $obj.warnings -match "evaluation not possible") {
    Ok "TEST-033.2: a binding lacking adapter_paths is WARN 'evaluation not possible'"
} else {
    Fail "TEST-033.2: expected Fail-6=false + WARN"
}

$r = Invoke-Gate (Join-Path $fixtures "config-advisory.yaml") (Join-Path $fixtures "facet-manifest-full.json") (Join-Path $fixtures "changed-paths-fail6.txt") (Join-Path $fixtures "does-not-exist-bindings.json")
$obj = $r.Output | ConvertFrom-Json
$f6detail = ($obj.fail_conditions | Where-Object { $_.id -eq "Fail-6" }).detail.status
if ($f6detail -eq "not-applicable (provider-bindings absent)") { Ok "TEST-034.1: absent provider-bindings records Fail-6 N/A with a WARN" } else { Fail "TEST-034.1: expected N/A status, got $f6detail" }

# ============================================================================
# TEST-046: contracts/** bounded-shared out-of-enumeration Fail-4
# ============================================================================
Write-Output "=== TEST-046: contracts/** bounded-shared Fail-4 fixture ==="
$paths046 = Join-Path ([IO.Path]::GetTempPath()) ("rcp-046." + [Guid]::NewGuid().ToString("N") + ".txt")
"contracts/schema.json" | Set-Content -LiteralPath $paths046 -Encoding utf8 -NoNewline
$r = Invoke-Gate (Join-Path $fixtures "config-contracts-fail4.yaml") (Join-Path $fixtures "facet-manifest-contracts-partial.json") $paths046 $null
$obj = $r.Output | ConvertFrom-Json
$f4entry = $obj.fail_conditions | Where-Object { $_.id -eq "Fail-4" }
$missing = @($f4entry.detail.missing_bounded_shared_owners | Sort-Object)
if ($f4entry.triggered -eq $true -and ($missing -join ",") -eq "backend") {
    Ok "TEST-046.1: contracts/** bounded-shared with an out-of-enumeration component (backend) missing triggers Fail-4"
} else {
    Fail "TEST-046.1: expected Fail-4 triggered with missing=[backend], got $($f4entry.triggered)/$($missing -join ',')"
}
Remove-Item -Force -LiteralPath $paths046 -ErrorAction SilentlyContinue

# ============================================================================
# TEST-052/053: blocking behavior
# ============================================================================
Write-Output "=== TEST-052/053: blocking behavior ==="
$r = Invoke-Gate (Join-Path $fixtures "config-advisory.yaml") (Join-Path $fixtures "facet-manifest-full.json") (Join-Path $fixtures "changed-paths-fail1.txt") $null
if ($r.ExitCode -eq 0) { Ok "TEST-052.1: advisory exits 0 despite a Fail-condition trigger" } else { Fail "TEST-052.1: expected exit 0, got $($r.ExitCode)" }
$r = Invoke-Gate (Join-Path $fixtures "config-required.yaml") (Join-Path $fixtures "facet-manifest-full.json") (Join-Path $fixtures "changed-paths-fail1.txt") $null
if ($r.ExitCode -eq 1) { Ok "TEST-053.1: required exits non-zero (1) when a Fail condition triggers" } else { Fail "TEST-053.1: expected exit 1, got $($r.ExitCode)" }
$r = Invoke-Gate (Join-Path $fixtures "config-required.yaml") (Join-Path $fixtures "facet-manifest-full.json") (Join-Path $fixtures "changed-paths-clean.txt") $null
if ($r.ExitCode -eq 0) { Ok "TEST-053.2: required exits 0 when no Fail condition triggers" } else { Fail "TEST-053.2: expected exit 0, got $($r.ExitCode)" }

# ============================================================================
# TEST-054: evidence producer binding across all three states
# ============================================================================
Write-Output "=== TEST-054: evidence producer binding across all three states ==="
$realSha = (Get-FileHash -LiteralPath (Join-Path $repoRoot "plugins/sdd-quality-loop/scripts/check-component-coverage.py") -Algorithm SHA256).Hash.ToLower()
function Test-Producer {
    param([string]$Label, [string]$Output)
    $obj = $Output | ConvertFrom-Json
    if ($obj.schema -eq "check-component-coverage-verdict/v1" -and $obj.check_id -eq "check-component-coverage" -and $obj.producer.sha256 -eq $realSha) {
        Ok "TEST-054 ($Label): evidence carries schema, check_id, and a live-computed producer.sha256 matching the real script"
    } else {
        Fail "TEST-054 ($Label): schema=$($obj.schema) check_id=$($obj.check_id) sha=$($obj.producer.sha256) real=$realSha"
    }
}
Test-Producer "disabled-legacy" (Invoke-Gate (Join-Path $fixtures "config-disabled-legacy.yaml") $null (Join-Path $fixtures "changed-paths-clean.txt") $null).Output
Test-Producer "advisory" (Invoke-Gate (Join-Path $fixtures "config-advisory.yaml") (Join-Path $fixtures "facet-manifest-full.json") (Join-Path $fixtures "changed-paths-clean.txt") $null).Output
Test-Producer "required" (Invoke-Gate (Join-Path $fixtures "config-required.yaml") (Join-Path $fixtures "facet-manifest-full.json") (Join-Path $fixtures "changed-paths-clean.txt") $null).Output

# ============================================================================
# TEST-035/036/055 — staged-candidate-only (see the bash twin's header)
# ============================================================================
Write-Output "=== TEST-035/036/055: staged-candidate-only verification ==="
$matrixText = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "plugins/sdd-quality-loop/references/risk-gate-matrix.md")
if ($matrixText -match "check-component-coverage") { Ok "TEST-036.1 (partial): registered in the UNPROTECTED risk-gate-matrix.md required-check-set" } else { Fail "TEST-036.1: expected check-component-coverage in risk-gate-matrix.md" }
if ($skillText -match "check-component-coverage") { Ok "TEST-036.2 (partial): documented in quality-gate/SKILL.md's ## Process" } else { Fail "TEST-036.2: expected check-component-coverage documented in quality-gate/SKILL.md" }

Write-Output "=== registration self-check ==="
$runAllSh = Join-Path $repoRoot "tests/run-all.sh"
$runAllPs1 = Join-Path $repoRoot "tests/run-all.ps1"
if ((Select-String -LiteralPath $runAllSh -Pattern "check-component-coverage" -Quiet) -and (Select-String -LiteralPath $runAllPs1 -Pattern "check-component-coverage" -Quiet)) {
    Ok "check-component-coverage suite self-registers in run-all.sh and .ps1"
} else {
    Fail "check-component-coverage missing from run-all.sh/.ps1 registration"
}

# ============================================================================
# Summary
# ============================================================================
Write-Output ""
Write-Output "check-component-coverage.tests.ps1: $($script:passCount) passed, $($script:failCount) failed"
if ($script:failCount -ne 0) { exit 1 }
exit 0
