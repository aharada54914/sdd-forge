# TDD suite for the projection generator (T-006, REQ-005, AC-025/AC-026)
# -- PowerShell twin.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$generatorScript = Join-Path $root 'plugins/sdd-quality-loop/scripts/generate-gate-capabilities.ps1'
$fixturesDir = Join-Path $root 'tests/fixtures/capability-registry'

$script:PassCount = 0
$script:FailCount = 0
function Ok([string]$Message) { $script:PassCount++; Write-Host "ok: $Message" }
function Fail([string]$Message) { $script:FailCount++; [Console]::Error.WriteLine("not ok: $Message") }

# Strict-mode-safe property access: a malformed/empty projection (e.g. a
# stub's `{}` `_generated` object) must not throw a terminating
# property-not-found error under Set-StrictMode -- it must simply read as
# absent, so the RED-path assertions can report "not ok" and the suite can
# keep evaluating every remaining check, exactly like the bash twin's plain
# associative lookups.
function Get-Prop($InputObject, [string]$Name) {
  if ($null -ne $InputObject -and @($InputObject.PSObject.Properties.Match($Name)).Count -gt 0) {
    return $InputObject.$Name
  }
  return $null
}

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("t006-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $workDir 'contracts') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $workDir 'plugins/sdd-quality-loop/scripts/generated') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $fixturesDir 'gate-capabilities-clean-registry.json') -Destination (Join-Path $workDir 'contracts/capability-registry.json')
$outputPath = Join-Path $workDir 'plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json'

function Invoke-Generate {
  param([string[]]$ExtraArgs = @())
  $powerShellExe = (Get-Process -Id $PID).Path
  $allArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $generatorScript, '--repo-root', $workDir) + $ExtraArgs
  $out = & $powerShellExe @allArgs 2>&1
  $rc = $LASTEXITCODE
  return [PSCustomObject]@{ Out = ($out -join "`n"); Rc = $rc }
}

try {
  # =====================================================================
  # TEST-025: generated-header conformance + content correctness
  # =====================================================================
  $inv = Invoke-Generate
  if ($inv.Rc -eq 0) {
    Ok 'TEST-025(1): generator exits 0 against a clean fixture Registry'
  } else {
    Fail "TEST-025(1): generator exited $($inv.Rc): $($inv.Out)"
  }

  $expectedHash = (Get-FileHash -LiteralPath (Join-Path $fixturesDir 'gate-capabilities-clean-expected.json') -Algorithm SHA256).Hash
  $actualHash = if (Test-Path -LiteralPath $outputPath) { (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash } else { $null }
  if ($null -ne $actualHash -and $actualHash -eq $expectedHash) {
    Ok 'TEST-025(2): fresh output is byte-identical to the golden expected projection'
  } else {
    Fail 'TEST-025(2): fresh output diverges from the golden expected projection'
  }

  $data = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
  $gen = Get-Prop $data '_generated'
  $sha256Value = Get-Prop $gen 'sha256'
  $headerOk = (
    (Get-Prop $gen 'source') -eq 'contracts/capability-registry.json' -and
    (Get-Prop $gen 'schema_version') -eq 1 -and
    ($sha256Value -is [string]) -and ($null -ne $sha256Value) -and ($sha256Value.Length -eq 64) -and
    (Get-Prop $gen 'notice') -eq 'This file is generated. Do not edit.'
  )
  if ($headerOk) {
    Ok 'TEST-025(3): _generated block carries source/schema_version/sha256/notice correctly'
  } else {
    Fail 'TEST-025(3): _generated block malformed'
  }

  $rawLines = @(Get-Content -LiteralPath $outputPath)
  $commentLines = @($rawLines | Where-Object { $_ -match '^#' })
  if ($commentLines.Count -eq 0) {
    Ok "TEST-025(4): no comment-line ('# Generated...') convention anywhere in the projection"
  } else {
    Fail "TEST-025(4): unexpected '#'-prefixed line found in the projection"
  }

  $gatesArray = @(Get-Prop $data 'gates')
  $gateIds = @($gatesArray | ForEach-Object { Get-Prop $_ 'id' })
  $stagesOk = @($gatesArray | Where-Object { (Get-Prop $_ 'stage') -ne 'implementation' }).Count -eq 0
  $capMap = Get-Prop $data 'capability_gate_map'
  $mapOk = (
    ((@(Get-Prop $capMap 'first-capability')) -join ',') -eq 'check-alpha-impl,check-zeta-impl' -and
    ((@(Get-Prop $capMap 'second-capability')) -join ',') -eq 'check-alpha-impl' -and
    (@(Get-Prop $capMap 'no-gates-capability')).Count -eq 0 -and
    $stagesOk -and
    (($gateIds -join ',') -eq 'check-alpha-impl,check-zeta-impl')
  )
  if ($mapOk) {
    Ok 'TEST-025(5): capability_gate_map omits the promotion-stage gate (dangling-reference filtering), sorted, empty-array capability preserved'
  } else {
    Fail 'TEST-025(5): capability_gate_map / gates filtering incorrect'
  }

  # =====================================================================
  # TEST-026: drift detection (negative canary) + no-write proof
  # =====================================================================
  $inv = Invoke-Generate -ExtraArgs @('--check')
  if ($inv.Rc -eq 0) {
    Ok 'TEST-026(1): --check exits 0 against a freshly-regenerated, unmutated file'
  } else {
    Fail "TEST-026(1): --check exited $($inv.Rc) against a clean file: $($inv.Out)"
  }

  Copy-Item -LiteralPath (Join-Path $fixturesDir 'gate-capabilities-mutated.json') -Destination $outputPath -Force
  $inv = Invoke-Generate -ExtraArgs @('--check')
  if ($inv.Rc -ne 0 -and $inv.Out -match 'stale') {
    Ok "TEST-026(2): --check exits non-zero with a 'stale' diagnostic against a hand-mutated file"
  } else {
    Fail "TEST-026(2): expected non-zero exit + 'stale' diagnostic -- actual (rc=$($inv.Rc)): $($inv.Out)"
  }

  Invoke-Generate | Out-Null
  $beforeMtime = (Get-Item -LiteralPath $outputPath).LastWriteTimeUtc
  Start-Sleep -Seconds 1
  $inv = Invoke-Generate -ExtraArgs @('--check')
  $afterMtime = (Get-Item -LiteralPath $outputPath).LastWriteTimeUtc
  if ($inv.Rc -eq 0 -and $beforeMtime -eq $afterMtime) {
    Ok 'TEST-026(3): --check performs no filesystem write (mtime unchanged)'
  } else {
    Fail "TEST-026(3): mtime changed across a --check invocation (rc=$($inv.Rc), before=$beforeMtime, after=$afterMtime)"
  }

  # =====================================================================
  # Missing/invalid canonical Registry: fail closed
  # =====================================================================
  $emptyDir = Join-Path ([System.IO.Path]::GetTempPath()) ("t006-empty-" + [System.Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
  $powerShellExe = (Get-Process -Id $PID).Path
  $missingOut = & $powerShellExe -NoProfile -ExecutionPolicy Bypass -File $generatorScript --repo-root $emptyDir 2>&1
  $missingRc = $LASTEXITCODE
  Remove-Item -LiteralPath $emptyDir -Recurse -Force
  if ($missingRc -ne 0 -and ($missingOut -join "`n") -match 'not found') {
    Ok 'TEST-026(4): missing canonical Registry fails closed with a diagnostic'
  } else {
    Fail "TEST-026(4): expected fail-closed on missing Registry -- actual (rc=$missingRc): $missingOut"
  }

  # =====================================================================
  # Suite/CI registration
  # =====================================================================
  $runAllContent = (& (Join-Path $PSScriptRoot 'lib/verification-registration.ps1') (Join-Path $root 'tests/run-all.ps1'))
  if ($runAllContent -match [regex]::Escape('tests/generate-gate-capabilities.tests.ps1')) {
    Ok 'run-all.ps1 registers this suite'
  } else {
    Fail 'run-all.ps1 does not register this suite'
  }

  # PowerShell twin of the bash suite: the checked-in projection and vendored
  # contracts must match their canonical sources (read-only --check, explicit
  # repository root). The staged human-copy/ and CI workflow candidate checks
  # retired with the human-copy procedure and v1 CI layout (2026-11-28 owner
  # decision, ADR-0051 decisions 1 and 4).
  $liveOut = & $powerShellExe -NoProfile -ExecutionPolicy Bypass -File $generatorScript --repo-root $root --check 2>&1 | Out-String
  if ($LASTEXITCODE -eq 0) { Ok 'checked-in gate-capabilities.json matches the canonical Registry' }
  else { Fail "checked-in gate-capabilities.json is stale -- $liveOut" }
  $vendorOut = & $powerShellExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'plugins/sdd-quality-loop/scripts/vendor-capability-registry.ps1') --check 2>&1 | Out-String
  if ($LASTEXITCODE -eq 0) { Ok 'vendored plugin contracts match their canonical sources' }
  else { Fail "vendored plugin contracts drifted -- $vendorOut" }

  # Done When #4 (tasks.md, "Suite registration + structural checks") --
  # PowerShell twin of the bash suite's identically-labeled check
  # (quality-gate remediation, 2026-08-09). Corrected label (quality-gate
  # cycle 3, 2026-08-09): this is Done When item #4, not #3 -- #3 is
  # "Test-registration procedure proof" (TEST-030); #4 is "Suite
  # registration + structural checks", which is where tasks.md's own text
  # places this grep self-check.
  $versionHit = $false
  foreach ($name in @('generate-gate-capabilities.py', 'generate-gate-capabilities.sh', 'generate-gate-capabilities.ps1')) {
    $target = Join-Path $root "plugins/sdd-quality-loop/scripts/$name"
    if ((Test-Path -LiteralPath $target) -and ((Get-Content -LiteralPath $target -Raw) -match '[0-9]+\.[0-9]+\.[0-9]+')) {
      $versionHit = $true
    }
  }
  if (-not $versionHit) { Ok 'Done When #4: no version string was hand-mutated in this task''s production files (grep self-check)' } else { Fail 'Done When #4: a semver-looking version string was found in this task''s production files' }
} finally {
  if (Test-Path -LiteralPath $workDir) { Remove-Item -LiteralPath $workDir -Recurse -Force }
}

Write-Host ("---- summary: pass={0} fail={1} ----" -f $script:PassCount, $script:FailCount)
if ($script:FailCount -eq 0) {
  Write-Host "generate-gate-capabilities suite passed ($script:PassCount checks)"
  exit 0
}
Write-Host "generate-gate-capabilities suite FAILED ($script:PassCount passed, $script:FailCount failed)"
exit 1
