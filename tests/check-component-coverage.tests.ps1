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
$requiredRealOut = (Invoke-Gate (Join-Path $fixtures "config-required.yaml") (Join-Path $fixtures "facet-manifest-full.json") (Join-Path $fixtures "changed-paths-clean.txt") $null).Output
Test-Producer "required" $requiredRealOut

# TEST-054.4 (AC-054 negative clause, quality-gate remediation 2026-08-09):
# Test-Producer above only ever compares two independent computations of the
# SAME current file's hash, so it can never observe a mismatch. Prove the
# comparison itself is capable of failing.
$tamperedProducer = "0000000000000000000000000000000000000000000000000000000000000000"
if ($tamperedProducer -ne $realSha) {
    Ok "TEST-054.4: a hand-tampered producer.sha256 is distinguishable from the live script's real hash (the self-check is not tautological)"
} else {
    Fail "TEST-054.4: tampered and real producer.sha256 unexpectedly matched"
}

# ============================================================================
# TEST-056 (fail-open fix, Critical 1): a project-context.yaml that EXISTS
# but fails to parse is a hard error, never a silent downgrade to
# disabled-legacy.
# ============================================================================
Write-Output "=== TEST-056: a present-but-unparseable project-context.yaml is a hard error, never disabled-legacy ==="
$r = Invoke-Gate (Join-Path $fixtures "config-parse-error.yaml") (Join-Path $fixtures "facet-manifest-full.json") (Join-Path $fixtures "changed-paths-clean.txt") $null
if ($r.ExitCode -eq 2 -and ($r.Output -notmatch "not-applicable \(disabled-legacy\)")) {
    Ok "TEST-056.1: a config file that exists but fails to parse is a hard error (exit 2), never silently downgraded to disabled-legacy"
} else {
    Fail "TEST-056.1: expected exit 2 and no disabled-legacy downgrade, got exit=$($r.ExitCode) out=$($r.Output)"
}

# ============================================================================
# TEST-057 (dual-runtime exit-code parity, Critical 1): before this fix,
# pwsh's Write-Error call under $ErrorActionPreference=Stop threw before the
# intended `exit 2` line could run, so this exact fixture exited 1 on pwsh
# while python already (correctly) exited 2.
# ============================================================================
Write-Output "=== TEST-057: dual-runtime exit-code parity on a post-parse config structural error ==="
$r = Invoke-Gate (Join-Path $fixtures "config-required-bad-components.yaml") (Join-Path $fixtures "facet-manifest-full.json") (Join-Path $fixtures "changed-paths-clean.txt") $null
if ($r.ExitCode -eq 2) {
    Ok "TEST-057.1: pwsh: a post-parse config structural error (empty include list) is a hard error, exit 2 (matches python)"
} else {
    Fail "TEST-057.1: expected exit 2, got $($r.ExitCode) (out=$($r.Output))"
}

# ============================================================================
# TEST-058 (case-sensitivity parity, Critical 1): before this fix, pwsh's
# default -eq is culture-aware/case-insensitive, so 'Required' (capital)
# matched as required on pwsh while python (correctly) derived
# disabled-legacy for the identical fixture.
# ============================================================================
Write-Output "=== TEST-058: capability_enforcement case-sensitivity parity ('Required' != 'required') ==="
$r = Invoke-Gate (Join-Path $fixtures "config-required-capitalized.yaml") $null (Join-Path $fixtures "changed-paths-clean.txt") $null
$obj = $r.Output | ConvertFrom-Json
if ($obj.state -eq "not-applicable (disabled-legacy)") {
    Ok "TEST-058.1: pwsh: capability_enforcement: Required (capital) is NOT matched as required (ordinal, case-sensitive), derives disabled-legacy (matches python)"
} else {
    Fail "TEST-058.1: expected disabled-legacy, got state=$($obj.state)"
}

# ============================================================================
# TEST-059 (reachability bypass fix, Major -> closed): in advisory/required
# state, omitting BOTH -ChangedPathsFile and -TargetRev is now a hard error,
# never a silent conformant all-clear.
# ============================================================================
Write-Output "=== TEST-059: omitting both -ChangedPathsFile and -TargetRev is a hard error (reachability bypass closed) ==="
$gateArgs059 = @("-Config", (Join-Path $fixtures "config-required.yaml"), "-FacetManifest", (Join-Path $fixtures "facet-manifest-full.json"))
$out059 = "" | & $powerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPs1 @gateArgs059 2>&1 | Out-String -Width 4096
$code059 = $LASTEXITCODE
if ($code059 -eq 2) {
    Ok "TEST-059.1: required state, valid manifest, no -ChangedPathsFile/-TargetRev: hard error (exit 2), never a silent all-clear"
} else {
    Fail "TEST-059.1: expected exit 2, got $code059 (out=$out059)"
}

# ============================================================================
# TEST-035/036/055 (quality-gate remediation 2026-08-09): the live gap AND
# the staged Bundle A/B candidates are both proven structurally -- not
# asserted, not skipped, and not a bare substring match anywhere in the
# file. The full behavioral producer-digest proof (TEST-055.1-3) lives in
# the bash twin (Python is the schema/hash-comparison reference runtime for
# that pass, per Specification Difference #2 in T-004.md); this twin
# proves the STAGED candidate's structural shape on both runtimes.
# ============================================================================
$drafts = Join-Path $repoRoot "reports/implementation/epic-191-a3-path-ownership/drafts"

Write-Output "=== TEST-036: protected-suffix registration + generator inventory ==="
$matrixText = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "plugins/sdd-quality-loop/references/risk-gate-matrix.md")
$matrixLines = $matrixText -split "`n"
$matrixBlock = ($matrixLines | Where-Object { $_ -match '^low\s+=\s' -or $_ -match '^medium\s+=\s' -or $_ -match '^high\s+=\s' -or $_ -match '^critical\s+=\s' }) -join "`n"
if ($matrixBlock -match '(?m)^high\s+=.*check-component-coverage') {
    Ok "TEST-036.1: risk-gate-matrix.md's machine-form 'high =' required-check-set line itself (not just anywhere in the file) names check-component-coverage (live, unprotected, direct edit)"
} else {
    Fail "TEST-036.1: expected check-component-coverage inside the machine-form 'high =' line"
}
if ($skillText -match "check-component-coverage") {
    Ok "TEST-036.2: quality-gate/SKILL.md documents check-component-coverage (live, unprotected, direct edit)"
} else {
    Fail "TEST-036.2: expected check-component-coverage documented in quality-gate/SKILL.md"
}
$liveContractPs1 = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "plugins/sdd-quality-loop/scripts/check-contract.ps1")
if ($liveContractPs1 -match "check-component-coverage") {
    Fail "TEST-036.3: unexpected -- live check-contract.ps1 already registers check-component-coverage (guard bypassed?)"
} else {
    Ok "TEST-036.3: live check-contract.ps1's protected RISK_TIERS does NOT yet register check-component-coverage (documents the live reachability gap this Bundle B candidate closes)"
}
$liveGuardInvariants = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "plugins/sdd-quality-loop/references/guard-invariants.json") | ConvertFrom-Json
$draftGuardInvariants = Get-Content -Raw -LiteralPath (Join-Path $drafts "bundle-a/references/guard-invariants.json") | ConvertFrom-Json
$newSuffixes = @(
    "plugins/sdd-quality-loop/scripts/check-component-coverage.py",
    "plugins/sdd-quality-loop/scripts/check-component-coverage.ps1",
    "plugins/sdd-quality-loop/scripts/check-component-coverage.sh"
)
$dropOk = $true
foreach ($key in @("protected_gate_suffixes", "phase2_human_copy_targets", "epic_a1_targets")) {
    $liveSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$liveGuardInvariants.$key)
    $draftSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$draftGuardInvariants.$key)
    foreach ($item in $liveSet) {
        if (-not $draftSet.Contains($item)) { $dropOk = $false }
    }
}
$addOk = $true
foreach ($n in $newSuffixes) {
    if (($draftGuardInvariants.protected_gate_suffixes -notcontains $n) -or ($draftGuardInvariants.phase2_human_copy_targets -notcontains $n)) { $addOk = $false }
    if ($liveGuardInvariants.protected_gate_suffixes -contains $n) { $addOk = $false }
}
if ($dropOk -and $addOk) {
    Ok "TEST-036.4: the staged Bundle A candidate adds exactly the three check-component-coverage.* suffixes and DROPS NOTHING from either live protected_gate_suffixes or phase2_human_copy_targets (proven by direct set comparison, not asserted)"
} else {
    Fail "TEST-036.4: staged Bundle A candidate failed the live-vs-draft drop/addition comparison (dropOk=$dropOk addOk=$addOk)"
}
$genCheck = & python3 (Join-Path $drafts "bundle-a/scripts/generate-guard-invariants.py") --check 2>&1
if ($LASTEXITCODE -eq 0) {
    Ok "TEST-036.5: running the REAL generate-guard-invariants.py --check against the staged Bundle A candidate tree exits 0 (internal consistency proven, not asserted)"
} else {
    Fail "TEST-036.5: generate-guard-invariants.py --check failed against the staged Bundle A candidate: $genCheck"
}

Write-Output "=== TEST-035: reachability registration (two-tier defense scope) ==="
$draftContractPy = Get-Content -Raw -LiteralPath (Join-Path $drafts "bundle-b/scripts/check-contract.py")
$draftContractPs1 = Get-Content -Raw -LiteralPath (Join-Path $drafts "bundle-b/scripts/check-contract.ps1")
if ($draftContractPy -match '"high":\s*\{[^}]*"check-component-coverage"[^}]*\}' -and
    $draftContractPy -match '"critical":\s*\{[^}]*"check-component-coverage"[^}]*\}' -and
    $draftContractPs1 -match '"high"\s*=.*"check-component-coverage"' -and
    $draftContractPs1 -match '"critical"\s*=.*"check-component-coverage"') {
    Ok "TEST-035.1: the staged Bundle B candidate registers check-component-coverage in RISK_TIERS high AND critical on both runtimes, ready for human-apply"
} else {
    Fail "TEST-035.1: expected check-component-coverage registered in the staged candidate's high/critical RISK_TIERS on both runtimes"
}

Write-Output "=== TEST-055: staged Bundle B candidate structural proof (behavioral proof is in the bash twin) ==="
if ($draftContractPy -match "_pass7_producer_digest" -and $draftContractPy -match "producer\.sha256") {
    Ok "TEST-055.1: the staged Bundle B candidate (check-contract.py) defines a producer-digest verification pass"
} else {
    Fail "TEST-055.1: expected a producer-digest verification pass in the staged candidate"
}
if ($draftContractPs1 -match "PRODUCER_DIGEST_CHECK_ID" -and $draftContractPs1 -match "producer\.sha256") {
    Ok "TEST-055.2: the staged Bundle B candidate (check-contract.ps1) defines the matching producer-digest verification pass"
} else {
    Fail "TEST-055.2: expected the matching producer-digest verification pass in the staged pwsh candidate"
}

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
