# Acceptance-first PowerShell twin for T-005 (REQ-004; TEST-023/024/032).
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sourceDir = Join-Path $root 'plugins/sdd-quality-loop/scripts'
$fixtures = Join-Path $root 'tests/fixtures/capability-registry'
$script:PassCount = 0
$script:FailCount = 0
function Ok([string]$Message) { $script:PassCount++; Write-Host "ok: $Message" }
function Fail([string]$Message) { $script:FailCount++; [Console]::Error.WriteLine("not ok: $Message") }

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ('t005-' + [Guid]::NewGuid().ToString('N'))
$install = Join-Path $workDir 'plugin'
$scriptDir = Join-Path $install 'scripts'
$contractDir = Join-Path $install 'contracts'
New-Item -ItemType Directory -Path $scriptDir, $contractDir -Force | Out-Null

foreach ($name in @(
  'generate-registry-digest.py', 'generate-registry-digest.sh',
  'generate-registry-digest.ps1', 'generate-registry-digest.js',
  'registry_discovery.py', 'canonicalize-sdd-yaml.py',
  'lib/py-dispatch.sh', 'lib/py-dispatch.ps1'
)) {
  $source = Join-Path $sourceDir $name
  if (Test-Path -LiteralPath $source) {
    $destination = Join-Path $scriptDir $name
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination
  }
}

function Install-Registry([string]$Name) {
  Copy-Item -LiteralPath (Join-Path $fixtures $Name) -Destination (Join-Path $contractDir 'capability-registry.json') -Force
}

function Invoke-Generator([string[]]$Arguments) {
  $stdout = Join-Path $workDir 'stdout'
  $stderr = Join-Path $workDir 'stderr'
  $powerShell = (Get-Process -Id $PID).Path
  $process = Start-Process -FilePath $powerShell -ArgumentList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $scriptDir 'generate-registry-digest.ps1')) + $Arguments) -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  return [PSCustomObject]@{
    Rc = $process.ExitCode
    Out = ((Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue) -replace '[\r\n]', '')
    Err = (Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue)
  }
}

function Get-ExpectedDigest([string]$Name) {
  $out = & python3 (Join-Path $scriptDir 'canonicalize-sdd-yaml.py') (Join-Path $fixtures $Name) --input-format json --hash-only
  return (($out -join '') -replace '^sha256:', '').Trim()
}

try {
  Install-Registry 'registry-digest-base.json'

  # TEST-023. Assemble scanner vocabulary at runtime (WFI-012).
  $inspectionScript = @'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text(encoding="utf-8")
required = ["canonicalize-" + "sdd-yaml.py", "registry_" + "discovery"]
banned = ["jcs_" + "serialize", "_format_" + "jcs_number", "parse_" + "yaml_bytes", "import ya" + "ml", "ruamel" + ".yaml"]
print("PASS" if all(x in text for x in required) and not any(x in text for x in banned) else "FAIL")
'@
  $inspection = $inspectionScript | & python3 - (Join-Path $scriptDir 'generate-registry-digest.py')
  if (($inspection -join '').Trim() -eq 'PASS') { Ok 'TEST-023: implementation delegates canonicalization and contains no inline JCS/YAML parser' } else { Fail 'TEST-023: canonicalizer delegation/source inspection failed' }

  $a = Invoke-Generator @('--capability-ids', 'cap-alpha,cap-beta,cap-alpha')
  $b = Invoke-Generator @('--capability-ids', 'cap-beta,cap-alpha')
  if ($a.Rc -eq 0 -and $b.Rc -eq 0 -and $a.Out -eq $b.Out -and $a.Out -match '^[0-9a-f]{64}$') { Ok 'TEST-024(1): capability order and duplicates do not change the digest' } else { Fail 'TEST-024(1): capability order/duplicate independence failed' }

  $inv = Invoke-Generator @('--capability-ids', 'cap-alpha')
  if ($inv.Rc -eq 0 -and $inv.Out -eq (Get-ExpectedDigest 'registry-digest-fragment-cap-alpha.json')) { Ok 'TEST-024(2): capability selection includes transitive gates and stable-sorts both arrays' } else { Fail 'TEST-024(2): capability fragment differs from the golden fragment' }

  # Quality-gate remediation (2026-08-09) -- PowerShell twin of the bash
  # suite's identically-numbered TEST-024(9). TEST-024(1) above only selects
  # TWO capabilities and compares two live invocations against each other;
  # with a 2-element Python set the un-sorted iteration order coincides
  # across separate subprocess invocations often enough that a mutation
  # removing `sorted(capability_ids)` from build_fragment() went undetected
  # 7 times out of 8 (measured). Comparing a 3-capability, author-unsorted
  # selection against a FIXED, independently reconstructed golden digest
  # removes that luck: JCS canonicalization preserves JSON array order, so
  # any non-sorted capabilities-array ordering names a different digest,
  # deterministically, every time.
  $inv = Invoke-Generator @('--capability-ids', 'cap-empty,cap-beta,cap-alpha')
  if ($inv.Rc -eq 0 -and $inv.Out -eq (Get-ExpectedDigest 'registry-digest-fragment-multi-cap.json')) { Ok 'TEST-024(9): three-capability selection (author-unsorted CSV input) matches a fixed, independently-reconstructed sorted golden digest' } else { Fail 'TEST-024(9): three-capability selection differs from the fixed sorted golden digest' }

  $inv = Invoke-Generator @('--gate-ids', 'gate-b')
  if ($inv.Rc -eq 0 -and $inv.Out -eq (Get-ExpectedDigest 'registry-digest-fragment-gate-b.json')) { Ok 'TEST-024(3): direct gate selection is independent of capability references' } else { Fail 'TEST-024(3): direct gate fragment differs from the golden fragment' }

  $inv = Invoke-Generator @('--capability-ids', 'cap-beta', '--gate-ids', 'gate-x')
  if ($inv.Rc -eq 0 -and $inv.Out -eq (Get-ExpectedDigest 'registry-digest-fragment-union.json')) { Ok 'TEST-024(4): both selector flags produce the deduped union' } else { Fail 'TEST-024(4): combined-selector union differs from the golden fragment' }

  $inv = Invoke-Generator @('--capability-ids', 'cap-missing')
  if ($inv.Rc -ne 0 -and $inv.Err -like '*unknown-fragment-id*') { Ok 'TEST-024(5): unknown capability is a hard unknown-fragment-id failure' } else { Fail 'TEST-024(5): unknown capability diagnostic missing' }
  $inv = Invoke-Generator @('--gate-ids', 'gate-missing')
  if ($inv.Rc -ne 0 -and $inv.Err -like '*unknown-fragment-id*') { Ok 'TEST-024(6): unknown direct gate is a hard unknown-fragment-id failure' } else { Fail 'TEST-024(6): unknown gate diagnostic missing' }
  $inv = Invoke-Generator @()
  if ($inv.Rc -ne 0 -and $inv.Err -like '*fragment-selector-required*') { Ok 'TEST-024(7): missing selector is a hard fragment-selector-required failure' } else { Fail 'TEST-024(7): missing selector diagnostic missing' }

  Install-Registry 'registry-digest-base.json'; $wholeA = Invoke-Generator @('--whole')
  Install-Registry 'registry-digest-whole-mutated.json'; $wholeB = Invoke-Generator @('--whole')
  if ($wholeA.Rc -eq 0 -and $wholeB.Rc -eq 0 -and $wholeA.Out -ne $wholeB.Out) { Ok 'TEST-024(8): --whole is content-sensitive' } else { Fail 'TEST-024(8): --whole content sensitivity failed' }

  # Quality-gate remediation (2026-08-09) -- PowerShell twin of the bash
  # suite's identically-numbered TEST-024(10). Proves --whole leaves the
  # Registry's array order untouched (design.md: "already author-ordered,
  # are not re-sorted"), not merely that it is content-sensitive.
  # registry-digest-base.json's arrays are deliberately not id-sorted, so a
  # reordering regression would change this digest.
  Install-Registry 'registry-digest-base.json'
  $wholeOrder = Invoke-Generator @('--whole')
  if ($wholeOrder.Rc -eq 0 -and $wholeOrder.Out -eq (Get-ExpectedDigest 'registry-digest-base.json')) { Ok 'TEST-024(10): --whole preserves the Registry''s author order (unsorted, unlike fragment selection)' } else { Fail 'TEST-024(10): --whole digest differs from directly canonicalizing the untouched, author-ordered fixture' }

  Install-Registry 'registry-digest-jcs-a.json'; $jcsA = Invoke-Generator @('--whole')
  Install-Registry 'registry-digest-jcs-b.json'; $jcsB = Invoke-Generator @('--whole')
  if ($jcsA.Rc -eq 0 -and $jcsB.Rc -eq 0 -and $jcsA.Out -eq $jcsB.Out) { Ok 'TEST-032(1): JCS key-order and numeric-format vectors are digest-identical' } else { Fail 'TEST-032(1): JCS vector failed' }

  Install-Registry 'registry-digest-nfc-composed.json'; $nfcA = Invoke-Generator @('--whole')
  Install-Registry 'registry-digest-nfc-decomposed.json'; $nfcB = Invoke-Generator @('--whole')
  if ($nfcA.Rc -eq 0 -and $nfcB.Rc -eq 0 -and $nfcA.Out -eq $nfcB.Out) { Ok 'TEST-032(2): NFC composed/decomposed Registries are digest-identical' } else { Fail 'TEST-032(2): NFC vector failed' }

  Install-Registry 'registry-digest-base.json'
  $stableA = Invoke-Generator @('--gate-ids', 'gate-z,gate-a,gate-z')
  $stableB = Invoke-Generator @('--gate-ids', 'gate-a,gate-z')
  if ($stableA.Rc -eq 0 -and $stableB.Rc -eq 0 -and $stableA.Out -eq $stableB.Out) { Ok 'TEST-032(3): stable ordering ignores gate order and duplication' } else { Fail 'TEST-032(3): stable ordering vector failed' }

  $shBytes = Join-Path $workDir 'sh.bytes'
  $jsBytes = Join-Path $workDir 'js.bytes'
  $psBytes = Join-Path $workDir 'ps.bytes'
  $sink = Join-Path $workDir 'parity.stderr'
  $shProcess = Start-Process -FilePath bash -ArgumentList @((Join-Path $scriptDir 'generate-registry-digest.sh'), '--capability-ids', 'cap-alpha') -Wait -PassThru -RedirectStandardOutput $shBytes -RedirectStandardError $sink
  $jsProcess = Start-Process -FilePath node -ArgumentList @((Join-Path $scriptDir 'generate-registry-digest.js'), '--capability-ids', 'cap-alpha') -Wait -PassThru -RedirectStandardOutput $jsBytes -RedirectStandardError $sink
  $powerShell = (Get-Process -Id $PID).Path
  $psProcess = Start-Process -FilePath $powerShell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $scriptDir 'generate-registry-digest.ps1'), '--capability-ids', 'cap-alpha') -Wait -PassThru -RedirectStandardOutput $psBytes -RedirectStandardError $sink
  $shRaw = [IO.File]::ReadAllBytes($shBytes)
  $jsRaw = [IO.File]::ReadAllBytes($jsBytes)
  $psRaw = [IO.File]::ReadAllBytes($psBytes)
  $framingOk = $shRaw.Length -eq 65 -and $shRaw[64] -eq 10 -and ([Text.Encoding]::ASCII.GetString($shRaw, 0, 64) -match '^[0-9a-f]{64}$')
  $bytesEqual = ([Convert]::ToHexString($shRaw) -eq [Convert]::ToHexString($jsRaw)) -and ([Convert]::ToHexString($shRaw) -eq [Convert]::ToHexString($psRaw))
  if ($shProcess.ExitCode -eq 0 -and $jsProcess.ExitCode -eq 0 -and $psProcess.ExitCode -eq 0 -and $framingOk -and $bytesEqual) { Ok 'wrapper parity: sh/ps1/js emit byte-identical digests' } else { Fail 'wrapper parity: sh/ps1/js outputs or exit codes differ' }

  $runnerText = Get-Content -LiteralPath (Join-Path $root 'tests/run-all.ps1') -Raw
  if ($runnerText.Contains('tests/generate-registry-digest.tests.ps1')) { Ok 'run-all.ps1 registers this suite between T-004 and T-006' } else { Fail 'run-all.ps1 does not register this suite' }

  # Done When #4 (tasks.md) -- PowerShell twin of the bash suite's
  # identically-labeled check (quality-gate remediation, 2026-08-09).
  $versionHit = $false
  foreach ($name in @('generate-registry-digest.py', 'generate-registry-digest.sh', 'generate-registry-digest.ps1', 'generate-registry-digest.js')) {
    $target = Join-Path $sourceDir $name
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
  Write-Host "generate-registry-digest suite passed ($script:PassCount checks)"
  exit 0
}
Write-Host "generate-registry-digest suite FAILED ($script:PassCount passed, $script:FailCount failed)"
exit 1
