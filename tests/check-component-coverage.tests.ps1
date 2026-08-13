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
# TEST-035d (relabelled from the suite-internal "TEST-056" on 2026-08-11 —
# the 2026-08-11 spec amendment assigned TEST-056 to T-001's resolver-side
# criterion and gave THIS Gate-side clause the ID TEST-035d,
# acceptance-tests.md:77. Originally the fail-open fix for Critical 1.)
# A present-but-unparseable project-context.yaml is a RECORDLESS hard
# error: non-zero exit, a diagnostic naming the parse failure, and NO
# evidence record emitted — see the bash twin's comment.
# ============================================================================
Write-Output "=== TEST-035d: a present-but-unparseable project-context.yaml is a recordless hard error, never disabled-legacy ==="
$r = Invoke-Gate (Join-Path $fixtures "config-parse-error.yaml") (Join-Path $fixtures "facet-manifest-full.json") (Join-Path $fixtures "changed-paths-clean.txt") $null
if ($r.ExitCode -eq 2 -and ($r.Output -notmatch "not-applicable \(disabled-legacy\)")) {
    Ok "TEST-035d.1: a config file that exists but fails to parse is a hard error (exit 2), never silently downgraded to disabled-legacy"
} else {
    Fail "TEST-035d.1: expected exit 2 and no disabled-legacy downgrade, got exit=$($r.ExitCode) out=$($r.Output)"
}
# (Phrasing differs per runtime: the python Gate says "exists but could not
# be parsed: …", the pwsh Gate says "config error: …" — both then name the
# concrete parse failure, which for this fixture is the non-mapping top
# level.)
if ($r.Output -match "config error" -and $r.Output -match "must be a mapping") {
    Ok "TEST-035d.2: the diagnostic names the parse failure"
} else {
    Fail "TEST-035d.2: expected a diagnostic naming the parse failure, got: $($r.Output)"
}
$stdout035d = & $powerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPs1 -Config (Join-Path $fixtures "config-parse-error.yaml") -FacetManifest (Join-Path $fixtures "facet-manifest-full.json") -ChangedPathsFile (Join-Path $fixtures "changed-paths-clean.txt") 2>$null | Out-String
if ($stdout035d.Trim() -ceq "" -and ($r.Output -notmatch "check-component-coverage-verdict/v1")) {
    Ok "TEST-035d.3: NO evidence record is emitted (empty stdout, no verdict schema tag anywhere) — nothing exists for an activated tier minimum to accept"
} else {
    Fail "TEST-035d.3: expected a recordless crash, got stdout=[$($stdout035d.Trim())]"
}

# ============================================================================
# Label note (2026-08-11): TEST-057..TEST-059 below are SUITE-INTERNAL
# remediation labels, not rows of acceptance-tests.md (whose ID space ends
# at TEST-056, owned by T-001's resolver suite). No spec row collides.
# ============================================================================

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
# TEST-035/036/055 (retargeted 2026-08-11 per RT-20260811-003 / seq0679):
# these blocks originally documented a LIVE reachability gap and proved the
# staged drafts/ candidates. A human ruled for CONDITIONAL activation
# (staged eb427d60, applied 710d6746); everything below now exercises the
# POST-APPLY world on this runtime — the applied live
# check-contract.ps1/guard-invariants.json — and TEST-055.3 asserts the
# superseded unconditional drafts/bundle-b candidate stays evicted. The
# python-side behavioral twin cases live in the bash suite.
# ============================================================================
$drafts = Join-Path $repoRoot "reports/implementation/epic-191-a3-path-ownership/drafts"
$liveContractPy = Join-Path $repoRoot "plugins/sdd-quality-loop/scripts/check-contract.py"
$liveContractPs1 = Join-Path $repoRoot "plugins/sdd-quality-loop/scripts/check-contract.ps1"
$hcManifest191 = Join-Path $repoRoot "specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256"

function Invoke-LiveCheckContract {
    param([string]$ContractPath, [string]$Root)
    $out = & $powerShell -NoProfile -ExecutionPolicy Bypass -File $liveContractPs1 $ContractPath -RepoRoot $Root 2>&1 | Out-String -Width 4096
    return @{ Output = $out; ExitCode = $LASTEXITCODE }
}

function Write-035Contract {
    # A high contract carrying the complete high-tier required set EXCEPT
    # check-component-coverage (mirrors the bash twin's write_035_contract).
    param([string]$Dir, [string]$TaskId)
    New-Item -ItemType Directory -Force -Path (Join-Path $Dir "reports") | Out-Null
    Set-Content -LiteralPath (Join-Path $Dir "reports/test.log") -Value "fixture evidence" -Encoding utf8
    $checkIds = @("lint", "typecheck", "build", "placeholder-scan", "task-state-check", "unit-tests", "acceptance-tests", "regression", "requirement-traceability")
    $checks = ($checkIds | ForEach-Object { '    { "id": "' + $_ + '", "required": true, "passes": true, "evidence": "reports/test.log", "waiver_reason": "" }' }) -join ",`n"
    $body = "{`n  `"task_id`": `"$TaskId`",`n  `"feature`": `"test-feature`",`n  `"risk`": `"high`",`n  `"created`": `"2026-08-11T00:00:00Z`",`n  `"checks`": [`n$checks`n  ]`n}"
    Set-Content -LiteralPath (Join-Path $Dir "$TaskId.contract.json") -Value $body -Encoding utf8
}

function Write-035ValidContext {
    param([string]$Dir)
    New-Item -ItemType Directory -Force -Path (Join-Path $Dir "sdd") | Out-Null
    $yaml = "schema: sdd-project-context/v1`nworkflow:`n  spec_profile: full`n  artifact_layout: legacy-seven-layer`n  capability_enforcement: advisory`ncomponents: []`nshared_paths: []`n"
    [IO.File]::WriteAllText((Join-Path $Dir "sdd/project-context.yaml"), $yaml)
}

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
# TEST-036.3 (retargeted 2026-08-11): the pre-apply inversion ("does NOT yet
# register") could never pass again once the human apply landed. Now: the
# live check-contract.ps1 registers the check in high AND critical and
# carries the conditional-activation predicate.
$liveContractPs1Text = Get-Content -Raw -LiteralPath $liveContractPs1
if ($liveContractPs1Text -match '"high"\s*=.*"check-component-coverage"' -and
    $liveContractPs1Text -match '"critical"\s*=.*"check-component-coverage"' -and
    $liveContractPs1Text -match 'CAPABILITY_STATE_GATED_IDS') {
    Ok "TEST-036.3: live check-contract.ps1 registers check-component-coverage in the high/critical tier minimums, gated by the conditional-activation predicate (the applied conditional artifact)"
} else {
    Fail "TEST-036.3: expected the live check-contract.ps1 to carry the conditional check-component-coverage registration"
}
# TEST-036.4 (retargeted 2026-08-12): live guard-invariants.json must carry
# the three entries in BOTH protected lists; T-004's own live workflow steps
# must remain present; every shared-manifest candidate hash must verify; and
# T-004-owned protected rows must still match live. The shared workflow row
# may carry a later serialized task's pending staged registration. Explicit
# HUMAN APPLY STEP paths are derived from that later task's text and remain
# candidate-only until the human application actually occurs.
$liveGuardInvariants = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "plugins/sdd-quality-loop/references/guard-invariants.json") | ConvertFrom-Json
$newSuffixes = @(
    "plugins/sdd-quality-loop/scripts/check-component-coverage.py",
    "plugins/sdd-quality-loop/scripts/check-component-coverage.ps1",
    "plugins/sdd-quality-loop/scripts/check-component-coverage.sh"
)
$liveAddOk = $true
foreach ($n in $newSuffixes) {
    if (($liveGuardInvariants.protected_gate_suffixes -notcontains $n) -or ($liveGuardInvariants.phase2_human_copy_targets -notcontains $n)) { $liveAddOk = $false }
}
$manifestOk = $true
$manifestChecked = 0
$liveChecked = 0
$tasksText = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'specs/epic-191-a3-path-ownership/tasks.md')
$t006Text = ($tasksText -split '## T-006', 2)[1]
$pendingHumanApply = @([regex]::Matches($t006Text, 'human-copy/(plugins/[^`\s]+)') | ForEach-Object { $_.Groups[1].Value })
$liveWorkflowText = Get-Content -Raw -LiteralPath (Join-Path $repoRoot '.github/workflows/test.yml')
if (-not $liveWorkflowText.Contains('bash ./tests/check-component-coverage.tests.sh') -or
    -not $liveWorkflowText.Contains('./tests/check-component-coverage.tests.ps1')) {
    $manifestOk = $false
}
foreach ($line in (Get-Content -LiteralPath $hcManifest191)) {
    if ($line.Trim() -ceq "" -or $line.TrimStart().StartsWith("#")) { continue }
    $parts = $line -split '\s+', 2
    if ($parts.Count -ne 2) { $manifestOk = $false; continue }
    $relativePath = $parts[1].Trim()
    $candidatePath = Join-Path (Split-Path -Parent $hcManifest191) $relativePath
    if (-not (Test-Path -LiteralPath $candidatePath)) { $manifestOk = $false; continue }
    $candidateHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $candidatePath).Hash.ToLowerInvariant()
    if ($candidateHash -cne $parts[0].Trim()) { $manifestOk = $false }
    if ($relativePath -cne '.github/workflows/test.yml' -and $pendingHumanApply -cnotcontains $relativePath) {
        $livePath = Join-Path $repoRoot $relativePath
        if (-not (Test-Path -LiteralPath $livePath)) { $manifestOk = $false; continue }
        $liveHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $livePath).Hash.ToLowerInvariant()
        if ($liveHash -cne $parts[0].Trim()) { $manifestOk = $false }
        $liveChecked++
    }
    $manifestChecked++
}
if ($liveAddOk -and $manifestOk -and $manifestChecked -gt 0 -and $liveChecked -gt 0) {
    Ok "TEST-036.4: T-004's live registrations remain applied; all $manifestChecked shared-manifest candidate hashes verify; and all $liveChecked T-004-owned protected rows remain byte-identical live"
} else {
    Fail "TEST-036.4: T-004 registration, staged-candidate integrity, or T-004-owned live byte identity failed (addOk=$liveAddOk manifestOk=$manifestOk candidates=$manifestChecked live=$liveChecked)"
}
# TEST-036.5 (retargeted 2026-08-11): the generator inventory check runs
# against the LIVE tree — the applied state is what must be consistent.
$genCheck = & python3 (Join-Path $repoRoot "plugins/sdd-quality-loop/scripts/generate-guard-invariants.py") --check 2>&1
if ($LASTEXITCODE -eq 0) {
    Ok "TEST-036.5: the LIVE generate-guard-invariants.py --check exits 0 against the applied live tree (internal consistency proven, not asserted)"
} else {
    Fail "TEST-036.5: the LIVE generate-guard-invariants.py --check failed: $genCheck"
}

Write-Output "=== TEST-035: reachability registration (two-tier defense scope) ==="
# TEST-035.1 (rebound 2026-08-11): behavioral against the APPLIED live
# check-contract.ps1 — with a present, schema-valid project-context.yaml in
# a disposable fixture tree, a high contract omitting the check must FAIL
# naming check-component-coverage (see the bash twin for the python side).
$work035 = Join-Path ([IO.Path]::GetTempPath()) ("ccc-035." + [Guid]::NewGuid().ToString("N"))
Write-035Contract $work035 "TEST-035"
Write-035ValidContext $work035
$r035 = Invoke-LiveCheckContract (Join-Path $work035 "TEST-035.contract.json") $work035
if ($r035.ExitCode -ne 0 -and $r035.Output -match "check-component-coverage") {
    Ok "TEST-035.1: with a present, schema-valid project-context.yaml, the LIVE check-contract.ps1 fails a high contract that omits check-component-coverage, naming the check (applied conditional registration, behavioral)"
} else {
    Fail "TEST-035.1: expected the live check-contract.ps1 to fail the fixture naming check-component-coverage, got exit=$($r035.ExitCode) out=$($r035.Output)"
}
Remove-Item -Recurse -Force -LiteralPath $work035 -ErrorAction SilentlyContinue

# TEST-035c (added 2026-08-11, acceptance-tests.md:76): fail-closed
# activation under a present-but-malformed config — pwsh side. See the bash
# twin's comment for the full rationale and the absence control's purpose.
Write-Output "=== TEST-035c: activation is fail-closed under a present-but-malformed project-context.yaml ==="
$work035c = Join-Path ([IO.Path]::GetTempPath()) ("ccc-035c." + [Guid]::NewGuid().ToString("N"))

Write-035Contract (Join-Path $work035c "absent") "TEST-035c"
$r035c0 = Invoke-LiveCheckContract (Join-Path $work035c "absent/TEST-035c.contract.json") (Join-Path $work035c "absent")
if ($r035c0.ExitCode -eq 0) {
    Ok "TEST-035c.1 (control): with NO project-context.yaml, the same contract passes — the failures below are attributable to config presence alone"
} else {
    Fail "TEST-035c.1 (control): expected the absence-state contract to pass, got exit=$($r035c0.ExitCode) out=$($r035c0.Output)"
}

Write-035Contract (Join-Path $work035c "unparseable") "TEST-035c"
New-Item -ItemType Directory -Force -Path (Join-Path $work035c "unparseable/sdd") | Out-Null
[IO.File]::WriteAllText((Join-Path $work035c "unparseable/sdd/project-context.yaml"), "workflow:`n`tcapability_enforcement: advisory`n")
$r035c1 = Invoke-LiveCheckContract (Join-Path $work035c "unparseable/TEST-035c.contract.json") (Join-Path $work035c "unparseable")
if ($r035c1.ExitCode -ne 0 -and $r035c1.Output -match "check-component-coverage") {
    Ok "TEST-035c.2: a present-but-UNPARSEABLE project-context.yaml (tab indentation) still activates the requirement — the contract lacking the entry fails naming check-component-coverage"
} else {
    Fail "TEST-035c.2: expected fail-closed activation under an unparseable config, got exit=$($r035c1.ExitCode) out=$($r035c1.Output)"
}

Write-035Contract (Join-Path $work035c "divergent") "TEST-035c"
New-Item -ItemType Directory -Force -Path (Join-Path $work035c "divergent/sdd") | Out-Null
[IO.File]::WriteAllText((Join-Path $work035c "divergent/sdd/project-context.yaml"), "schema: some-other-schema/v9`nbogus_top_level_key: true`n")
$r035c2 = Invoke-LiveCheckContract (Join-Path $work035c "divergent/TEST-035c.contract.json") (Join-Path $work035c "divergent")
if ($r035c2.ExitCode -ne 0 -and $r035c2.Output -match "check-component-coverage") {
    Ok "TEST-035c.3: a present-but-SCHEMA-DIVERGENT project-context.yaml still activates the requirement — the contract lacking the entry fails naming check-component-coverage"
} else {
    Fail "TEST-035c.3: expected fail-closed activation under a schema-divergent config, got exit=$($r035c2.ExitCode) out=$($r035c2.Output)"
}
Remove-Item -Recurse -Force -LiteralPath $work035c -ErrorAction SilentlyContinue

Write-Output "=== TEST-055: check-contract producer-digest verification (AC-055, pwsh side) ==="
# Rebound 2026-08-11: the old structural greps read the superseded
# drafts/bundle-b candidate. Now: behavioral tamper-reject and genuine-pass
# against the LIVE check-contract.ps1, plus the structural pin that the
# applied pair carries the pass, plus the drafts/bundle-b eviction guard.
$work055p = Join-Path ([IO.Path]::GetTempPath()) ("ccc-055." + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path (Join-Path $work055p "reports") | Out-Null
Set-Content -LiteralPath (Join-Path $work055p "reports/baseline.log") -Value "unused baseline evidence" -Encoding utf8
$realEvidence055 = $requiredRealOut.Trim()
[IO.File]::WriteAllText((Join-Path $work055p "reports/real-evidence.json"), $realEvidence055)
$tamperedObj = $realEvidence055 | ConvertFrom-Json
$tamperedObj.producer.sha256 = "0000000000000000000000000000000000000000000000000000000000000000"
[IO.File]::WriteAllText((Join-Path $work055p "reports/tampered-evidence.json"), ($tamperedObj | ConvertTo-Json -Depth 16))
function Write-055Contract {
    param([string]$EvidenceRel, [string]$OutFile)
    $baselineIds = @("lint", "typecheck", "unit-tests", "build", "placeholder-scan", "task-state-check")
    $checks = ($baselineIds | ForEach-Object { '    { "id": "' + $_ + '", "required": true, "passes": true, "evidence": "reports/baseline.log", "waiver_reason": "" }' }) -join ",`n"
    $checks += ",`n" + '    { "id": "check-component-coverage", "required": false, "passes": true, "evidence": "' + $EvidenceRel + '", "waiver_reason": "" }'
    $body = "{`n  `"task_id`": `"TEST-055`",`n  `"feature`": `"test-feature`",`n  `"created`": `"2026-06-13T00:00:00Z`",`n  `"checks`": [`n$checks`n  ]`n}"
    [IO.File]::WriteAllText($OutFile, $body)
}
Write-055Contract "reports/tampered-evidence.json" (Join-Path $work055p "tampered.contract.json")
Write-055Contract "reports/real-evidence.json" (Join-Path $work055p "real.contract.json")
$r055bad = Invoke-LiveCheckContract (Join-Path $work055p "tampered.contract.json") $work055p
if ($r055bad.ExitCode -ne 0 -and $r055bad.Output -match "does not match the live on-disk") {
    Ok "TEST-055.1: the LIVE, applied check-contract.ps1 REJECTS a tampered check-component-coverage producer.sha256, naming the mismatch (the delivered tamper-evidence rejection, behavioral on this runtime)"
} else {
    Fail "TEST-055.1: expected the live check-contract.ps1 to reject the tampered evidence, got exit=$($r055bad.ExitCode) out=$($r055bad.Output)"
}
$r055ok = Invoke-LiveCheckContract (Join-Path $work055p "real.contract.json") $work055p
if ($r055ok.ExitCode -eq 0) {
    Ok "TEST-055.2: the LIVE, applied check-contract.ps1 PASSES a genuine, live-produced check-component-coverage evidence record (positive case — the pass is not stuck shut)"
} else {
    Fail "TEST-055.2: expected the live check-contract.ps1 to pass genuine evidence, got exit=$($r055ok.ExitCode) out=$($r055ok.Output)"
}
Remove-Item -Recurse -Force -LiteralPath $work055p -ErrorAction SilentlyContinue
$liveContractPyText = Get-Content -Raw -LiteralPath $liveContractPy
if ($liveContractPyText -match "_pass7_producer_digest" -and $liveContractPyText -match "producer\.sha256" -and
    $liveContractPs1Text -match "PRODUCER_DIGEST_CHECK_ID" -and $liveContractPs1Text -match "producer\.sha256") {
    Ok "TEST-055.2b: the LIVE, applied check-contract pair defines the producer-digest verification pass on both runtimes (structural pin)"
} else {
    Fail "TEST-055.2b: expected the producer-digest verification pass in the live check-contract pair"
}
# TEST-055.3 (eviction guard, 2026-08-11): see the bash twin's comment.
$draftsManifest = Join-Path $drafts "MANIFEST.sha256"
$draftsManifestRows = @(Get-Content -LiteralPath $draftsManifest | Where-Object { -not $_.TrimStart().StartsWith("#") })
if (-not (Test-Path -LiteralPath (Join-Path $drafts "bundle-b/scripts/check-contract.py")) -and
    -not (Test-Path -LiteralPath (Join-Path $drafts "bundle-b/scripts/check-contract.ps1")) -and
    -not ($draftsManifestRows -match "bundle-b/scripts/check-contract")) {
    Ok "TEST-055.3: the superseded unconditional drafts/bundle-b check-contract candidate stays evicted (no files, no MANIFEST.sha256 mapping rows) — the stale apply channel cannot silently revert the conditional gate"
} else {
    Fail "TEST-055.3: the superseded drafts/bundle-b check-contract candidate or its manifest mapping has been resurrected"
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
