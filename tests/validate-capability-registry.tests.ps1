# TDD suite for the Registry validator (T-004, REQ-003, nine checks a-i)
# -- PowerShell twin.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$validatorScript = Join-Path $root 'plugins/sdd-quality-loop/scripts/validate-capability-registry.ps1'
$fixturesDir = Join-Path $root 'tests/fixtures/capability-registry'
$identityRepo = Join-Path $fixturesDir 'identity-bidirectional-repo'

$script:PassCount = 0
$script:FailCount = 0
function Ok([string]$Message) { $script:PassCount++; Write-Host "ok: $Message" }
function Fail([string]$Message) { $script:FailCount++; [Console]::Error.WriteLine("not ok: $Message") }

function Invoke-Validate {
  param([string]$Fixture, [string[]]$ExtraArgs = @())
  $powerShellExe = (Get-Process -Id $PID).Path
  $fixturePath = Join-Path $fixturesDir "$Fixture.json"
  $allArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $validatorScript, '--registry', $fixturePath) + $ExtraArgs
  $out = & $powerShellExe @allArgs 2>&1
  $rc = $LASTEXITCODE
  return [PSCustomObject]@{ Out = ($out -join "`n"); Rc = $rc }
}

function Assert-Contains([string]$Name, $Invocation, [string]$Needle) {
  if ($Invocation.Rc -ne 0 -and $Invocation.Out -match [regex]::Escape($Needle)) {
    Ok $Name
  } else {
    Fail "$Name`: expected non-zero exit + diagnostic containing '$Needle' -- actual (rc=$($Invocation.Rc)): $($Invocation.Out)"
  }
}

function Assert-NotContains([string]$Name, $Invocation, [string]$Needle) {
  if ($Invocation.Out -notmatch [regex]::Escape($Needle)) {
    Ok $Name
  } else {
    Fail "$Name`: unexpectedly found '$Needle' -- actual: $($Invocation.Out)"
  }
}

# =====================================================================
# TEST-028: structural placement (this suite's own setup assertion, AC-028)
# =====================================================================
if (-not (Test-Path -LiteralPath (Join-Path $root 'plugins/sdd-capability'))) {
  Ok 'TEST-028: plugins/sdd-capability/ does not exist'
} else {
  Fail 'TEST-028: plugins/sdd-capability/ unexpectedly exists'
}
$placementFiles = @(
  'plugins/sdd-quality-loop/scripts/evaluate-predicate.py',
  'plugins/sdd-quality-loop/scripts/registry_discovery.py',
  'plugins/sdd-quality-loop/scripts/vendor-capability-registry.py',
  'plugins/sdd-quality-loop/scripts/validate-capability-registry.py',
  'plugins/sdd-quality-loop/references/provider-terms.json'
)
$placementOk = $true
foreach ($f in $placementFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $f))) {
    $placementOk = $false
    Fail "TEST-028: expected REQ-002..005 file missing under plugins/sdd-quality-loop/: $f"
  }
}
if ($placementOk) { Ok 'TEST-028: every REQ-002..005 script/reference file lives under plugins/sdd-quality-loop/' }

# =====================================================================
# TEST-014 (a): Gate-ID uniqueness
# =====================================================================
$inv = Invoke-Validate -Fixture 'validate-registry-dup-gate-id'
Assert-Contains 'TEST-014: gate-id-duplicate detected' $inv 'registry: gate-id-duplicate: dup-gate'

# =====================================================================
# TEST-015 (b): stage-completeness
# =====================================================================
$inv = Invoke-Validate -Fixture 'validate-registry-missing-impl-ref'
Assert-Contains 'TEST-015: implementation-ref-missing (field absent) detected' $inv 'registry: implementation-ref-missing: no-ref-gate'

$inv = Invoke-Validate -Fixture 'validate-registry-impl-ref-nonexistent-path'
Assert-Contains 'TEST-015: implementation-ref-missing (path does not exist) detected' $inv 'registry: implementation-ref-missing: bad-path-gate'

# =====================================================================
# TEST-016/TEST-017 (c): Gate implementation identity, bidirectional
# =====================================================================
$inv = Invoke-Validate -Fixture 'validate-registry-identity-bidirectional' -ExtraArgs @('--repo-root', $identityRepo)
Assert-Contains 'TEST-016/017: unregistered check-*.py master flagged' $inv 'registry: unregistered-script: plugins/sdd-quality-loop/scripts/check-unregistered.py'
Assert-NotContains 'TEST-017(i): a properly-referenced master is not flagged' $inv 'check-registered.py'
Assert-NotContains 'TEST-017(ii): a script outside the scan root is never flagged' $inv 'check-outside.py'
Assert-NotContains 'TEST-017(iv): a non-check-* script under the scan root is never scanned' $inv 'emit-run-record.py'

# RT-20260723-001 remedy: TEST-016's three previously-missing assertions.
$inv = Invoke-Validate -Fixture 'validate-registry-identity-non-py-ref' -ExtraArgs @('--repo-root', $identityRepo)
Assert-Contains 'TEST-016(1): a non-.py implementation_ref does not register its .py master' $inv 'registry: unregistered-script: plugins/sdd-quality-loop/scripts/check-registered.py'

$inv = Invoke-Validate -Fixture 'validate-registry-identity-symlink' -ExtraArgs @('--repo-root', $identityRepo)
Assert-NotContains 'TEST-016(2): a gate referencing a symlinked entry point correctly registers the real master' $inv 'check-registered.py'

$inv = Invoke-Validate -Fixture 'validate-registry-identity-collision' -ExtraArgs @('--repo-root', $identityRepo)
Assert-Contains 'TEST-016(3): two gates resolving to the identical master are a gate-implementation-collision' $inv 'registry: gate-implementation-collision:'
Assert-Contains 'TEST-016(3): collision diagnostic names both colliding gate ids' $inv "'collision-gate-a', 'collision-gate-b'"

# =====================================================================
# TEST-018 (e): defense-in-depth stage-missing re-assertion
# =====================================================================
$inv = Invoke-Validate -Fixture 'validate-registry-stage-missing'
Assert-Contains 'TEST-018: stage-missing re-asserted independent of schema' $inv 'registry: stage-missing: no-stage-gate'

# =====================================================================
# TEST-019 (d): no Pack-owned Gate definitions
# =====================================================================
$inv = Invoke-Validate -Fixture 'validate-registry-identity-bidirectional' -ExtraArgs @('--repo-root', $identityRepo)
Assert-Contains 'TEST-019: pack-owned gates.yaml detected repository-wide' $inv 'registry: pack-owns-gate-definition: capability-packs/some-pack/gates.yaml'

# =====================================================================
# TEST-020 (g): Provider-name contamination + clean-fixture false-positive check
# =====================================================================
$inv = Invoke-Validate -Fixture 'validate-registry-provider-name'
Assert-Contains 'TEST-020: provider-name-detected fires on a real provider term' $inv 'registry: provider-name-detected:'

$inv = Invoke-Validate -Fixture 'validate-registry-provider-clean'
Assert-NotContains 'TEST-020: provider-neutral vocabulary (durable_workflow) is not a false positive' $inv 'provider-name-detected'

# =====================================================================
# TEST-021 (f): referential integrity
# =====================================================================
$inv = Invoke-Validate -Fixture 'validate-registry-dangling-gate-ref'
Assert-Contains 'TEST-021: dangling-gate-reference detected' $inv 'registry: dangling-gate-reference: dangling-cap -> nonexistent-gate-id'

# =====================================================================
# TEST-022 (h): lite-upgrade-reason-catalog conformance, fail-closed
# =====================================================================
$inv = Invoke-Validate -Fixture 'validate-registry-unknown-upgrade-reason'
Assert-Contains 'TEST-022: unknown-upgrade-reason fails closed against the real catalog' $inv "registry: unknown-upgrade-reason: bad-reason-cap -> 'not_a_real_reason'"

# =====================================================================
# TEST-039 (i): Capability-ID uniqueness, independent of (a); combined-duplicate fixture
# =====================================================================
$inv = Invoke-Validate -Fixture 'validate-registry-dup-capability-id'
Assert-Contains 'TEST-039: capability-id-duplicate detected' $inv 'registry: capability-id-duplicate: dup-cap'

$inv = Invoke-Validate -Fixture 'validate-registry-combined-duplicate'
Assert-Contains 'TEST-039: combined fixture -- gate-id-duplicate surfaces' $inv 'registry: gate-id-duplicate: dup-gate-combo'
Assert-Contains 'TEST-039: combined fixture -- capability-id-duplicate surfaces (neither masks the other)' $inv 'registry: capability-id-duplicate: dup-cap-combo'

# =====================================================================
# Fully-clean fixture: proves a negative
# =====================================================================
$inv = Invoke-Validate -Fixture 'validate-registry-fully-clean'
if ($inv.Rc -eq 0 -and $inv.Out -match 'all 9 checks passed') {
  Ok 'fully-clean fixture: all 9 checks pass on valid input (negative proof)'
} else {
  Fail "fully-clean fixture: expected exit 0 + all-9-checks-passed message -- actual (rc=$($inv.Rc)): $($inv.Out)"
}

# =====================================================================
# Suite/CI registration self-checks
# =====================================================================
$runAllSh = Get-Content -Raw -LiteralPath (Join-Path $root 'tests/run-all.sh')
if ($runAllSh -match [regex]::Escape('tests/validate-capability-registry.tests.sh')) {
  Ok 'self-registration: validate-capability-registry.tests.sh registered in tests/run-all.sh'
} else {
  Fail 'self-registration: validate-capability-registry.tests.sh NOT registered in tests/run-all.sh'
}
$runAllPs1 = Get-Content -Raw -LiteralPath (Join-Path $root 'tests/run-all.ps1')
if ($runAllPs1 -match [regex]::Escape('tests/validate-capability-registry.tests.ps1')) {
  Ok 'self-registration: validate-capability-registry.tests.ps1 registered in tests/run-all.ps1'
} else {
  Fail 'self-registration: validate-capability-registry.tests.ps1 NOT registered in tests/run-all.ps1'
}

$humanCopyDir = Join-Path $root 'specs/epic-190-a2-capability-registry/human-copy'
$stagedWorkflow = Join-Path $humanCopyDir '.github/workflows/test.yml'
$stagedManifest = Join-Path $humanCopyDir 'MANIFEST.sha256'
if (Test-Path -LiteralPath $stagedWorkflow) {
  $stagedText = Get-Content -Raw -LiteralPath $stagedWorkflow
  if (($stagedText -match [regex]::Escape('tests/validate-capability-registry.tests.sh')) -and ($stagedText -match [regex]::Escape('tests/validate-capability-registry.tests.ps1'))) {
    Ok "human-copy: staged workflow candidate registers this suite's CI steps"
  } else {
    Fail "human-copy: staged workflow candidate missing this suite's CI steps"
  }
  if (Test-Path -LiteralPath $stagedManifest) {
    $stagedHash = (Get-FileHash -LiteralPath $stagedWorkflow -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifestLines = @(Get-Content -LiteralPath $stagedManifest)
    $manifestLine = @($manifestLines -match 'workflows/test\.yml')
    if ($manifestLine.Count -gt 0) {
      $manifestHash = ($manifestLine[0] -split '\s+')[0].ToLowerInvariant()
      if ($stagedHash -eq $manifestHash) { Ok 'human-copy: staged workflow candidate sha256 matches MANIFEST.sha256' }
      else { Fail 'human-copy: staged workflow candidate sha256 does not match MANIFEST.sha256' }
    } else {
      Fail 'human-copy: MANIFEST.sha256 has no entry for the staged workflow candidate'
    }
  } else {
    Fail 'human-copy: MANIFEST.sha256 missing'
  }
} else {
  Fail 'human-copy: staged .github/workflows/test.yml candidate missing'
}

Write-Host ("---- summary: pass={0} fail={1} ----" -f $script:PassCount, $script:FailCount)
if ($script:FailCount -eq 0) {
  Write-Host "validate-capability-registry suite passed ($script:PassCount checks)"
  exit 0
} else {
  Write-Host "validate-capability-registry suite FAILED ($script:PassCount passed, $script:FailCount failed)"
  exit 1
}
