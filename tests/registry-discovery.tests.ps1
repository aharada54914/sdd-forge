# TDD suite for the Registry discovery contract + vendoring step
# (T-003, REQ-005, ADR-0029; numbered ADR-0025 until the 2026-08-11 renumber) -- PowerShell twin.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$realDiscovery = Join-Path $root 'plugins/sdd-quality-loop/scripts/registry_discovery.py'
$realVendor = Join-Path $root 'plugins/sdd-quality-loop/scripts/vendor-capability-registry.py'
$fixturesDir = Join-Path $root 'tests/fixtures/capability-registry'

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $workDir | Out-Null

$script:PassCount = 0
$script:FailCount = 0
function Ok([string]$Message) { $script:PassCount++; Write-Host "ok: $Message" }
function Fail([string]$Message) { $script:FailCount++; [Console]::Error.WriteLine("not ok: $Message") }

function Get-PythonCmd {
  $cmd = Get-Command python3 -ErrorAction SilentlyContinue
  if (-not $cmd) { $cmd = Get-Command python -ErrorAction SilentlyContinue }
  return $cmd.Source
}
$pythonExe = Get-PythonCmd

function New-Layout {
  param(
    [string]$Name,
    [string]$RegMode,
    [string]$SchemaMode,
    [string]$CatalogMode,
    [switch]$UseSymlink
  )
  $base = Join-Path $workDir "layout-$Name"
  $scriptsDir = Join-Path $base 'plugins/sdd-quality-loop/scripts'
  New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
  $contractsDir = Join-Path $base 'plugins/sdd-quality-loop/contracts'

  if ($UseSymlink) {
    $realBase = Join-Path $workDir "real-$Name"
    $realScripts = Join-Path $realBase 'plugins/sdd-quality-loop/scripts'
    New-Item -ItemType Directory -Path $realScripts -Force | Out-Null
    Copy-Item -LiteralPath $realDiscovery -Destination (Join-Path $realScripts 'registry_discovery.py')
    $entry = Join-Path $scriptsDir 'registry_discovery.py'
    New-Item -ItemType SymbolicLink -Path $entry -Target (Join-Path $realScripts 'registry_discovery.py') -ErrorAction Stop | Out-Null
    $contractsDir = Join-Path $realBase 'plugins/sdd-quality-loop/contracts'
  } else {
    Copy-Item -LiteralPath $realDiscovery -Destination (Join-Path $scriptsDir 'registry_discovery.py')
    $entry = Join-Path $scriptsDir 'registry_discovery.py'
  }

  if ($RegMode -ne 'missing' -or $SchemaMode -ne 'missing' -or $CatalogMode -ne 'missing') {
    New-Item -ItemType Directory -Path $contractsDir -Force | Out-Null
  }

  switch ($RegMode) {
    'valid' { Copy-Item -LiteralPath (Join-Path $fixturesDir 'registry-discovery-registry-valid.json') -Destination (Join-Path $contractsDir 'capability-registry.json') }
    'bad' { Copy-Item -LiteralPath (Join-Path $fixturesDir 'registry-discovery-registry-bad-schema.json') -Destination (Join-Path $contractsDir 'capability-registry.json') }
  }
  switch ($SchemaMode) {
    'valid' { Copy-Item -LiteralPath (Join-Path $fixturesDir 'registry-discovery-schemafile-valid.json') -Destination (Join-Path $contractsDir 'capability-registry.schema.json') }
    'bad-id' { Copy-Item -LiteralPath (Join-Path $fixturesDir 'registry-discovery-schemafile-bad-id.json') -Destination (Join-Path $contractsDir 'capability-registry.schema.json') }
    'missing-schema-key' { Copy-Item -LiteralPath (Join-Path $fixturesDir 'registry-discovery-schemafile-missing-schema-key.json') -Destination (Join-Path $contractsDir 'capability-registry.schema.json') }
  }
  switch ($CatalogMode) {
    'valid' { Copy-Item -LiteralPath (Join-Path $fixturesDir 'registry-discovery-catalog-valid.json') -Destination (Join-Path $contractsDir 'lite-upgrade-reason-catalog.json') }
    'bad' { Copy-Item -LiteralPath (Join-Path $fixturesDir 'registry-discovery-catalog-bad-schema.json') -Destination (Join-Path $contractsDir 'lite-upgrade-reason-catalog.json') }
  }

  return $entry
}

function Invoke-Discover {
  param([string]$Entry, [string]$Filename)
  $stderrPath = Join-Path $workDir "stderr-$(Get-Random).log"
  $stdout = & $pythonExe $Entry $Filename 2>$stderrPath
  $rc = $LASTEXITCODE
  $errText = (Get-Content -Raw -LiteralPath $stderrPath -ErrorAction SilentlyContinue)
  Remove-Item -LiteralPath $stderrPath -ErrorAction SilentlyContinue
  return [PSCustomObject]@{ Out = ($stdout -join "`n"); Rc = $rc; Err = $errText }
}

# =====================================================================
# AC-027: three installed-layout fixtures (one per runtime)
# =====================================================================
foreach ($runtime in @('claude-code', 'codex-cli', 'copilot-cli')) {
  $useSymlink = ($runtime -eq 'codex-cli')
  $entry = New-Layout -Name $runtime -RegMode 'valid' -SchemaMode 'valid' -CatalogMode 'valid' -UseSymlink:$useSymlink
  foreach ($filename in @('capability-registry.json', 'capability-registry.schema.json', 'lite-upgrade-reason-catalog.json')) {
    $inv = Invoke-Discover -Entry $entry -Filename $filename
    # Normalize separators before matching: the resolver prints native paths
    # (backslashes on Windows), while the expected literal uses forward
    # slashes. Runs of [\/] collapse to a single '/' so Python-repr doubled
    # backslashes normalize identically.
    $outNormalized = ($inv.Out -replace '[\\/]+', '/')
    if ($inv.Rc -eq 0 -and $outNormalized -match [regex]::Escape("plugins/sdd-quality-loop/contracts/$filename")) {
      Ok "AC-027 installed-layout ($runtime): $filename resolves via packaged copy alone"
    } else {
      Fail "AC-027 installed-layout ($runtime): $filename did not resolve via packaged copy (rc=$($inv.Rc) out=$($inv.Out) err=$($inv.Err))"
    }
  }
}

# =====================================================================
# AC-027: per-artifact version-mismatch fixtures
# =====================================================================
$entry = New-Layout -Name 'mismatch-registry' -RegMode 'bad' -SchemaMode 'valid' -CatalogMode 'valid'
$inv = Invoke-Discover -Entry $entry -Filename 'capability-registry.json'
if ($inv.Rc -ne 0 -and $inv.Err -match 'registry-discovery' -and $inv.Err -match 'capability-registry\.json') {
  Ok 'AC-027 version-mismatch: wrong schema value on the Registry fails closed'
} else {
  Fail "AC-027 version-mismatch: Registry bad-schema did not fail closed as expected (rc=$($inv.Rc) err=$($inv.Err))"
}

$entry = New-Layout -Name 'mismatch-schema-id' -RegMode 'valid' -SchemaMode 'bad-id' -CatalogMode 'valid'
$inv = Invoke-Discover -Entry $entry -Filename 'capability-registry.schema.json'
if ($inv.Rc -ne 0 -and $inv.Err -match 'registry-discovery') {
  Ok "AC-027 version-mismatch: mismatched `$id on the schema file fails closed"
} else {
  Fail "AC-027 version-mismatch: schema-file bad-id did not fail closed as expected (rc=$($inv.Rc) err=$($inv.Err))"
}

$entry = New-Layout -Name 'mismatch-schema-missing-key' -RegMode 'valid' -SchemaMode 'missing-schema-key' -CatalogMode 'valid'
$inv = Invoke-Discover -Entry $entry -Filename 'capability-registry.schema.json'
if ($inv.Rc -ne 0 -and $inv.Err -match 'registry-discovery') {
  Ok "AC-027 version-mismatch: missing `$schema key on the schema file fails closed"
} else {
  Fail "AC-027 version-mismatch: schema-file missing-schema-key did not fail closed as expected (rc=$($inv.Rc) err=$($inv.Err))"
}

$entry = New-Layout -Name 'mismatch-catalog' -RegMode 'valid' -SchemaMode 'valid' -CatalogMode 'bad'
$inv = Invoke-Discover -Entry $entry -Filename 'lite-upgrade-reason-catalog.json'
if ($inv.Rc -ne 0 -and $inv.Err -match 'registry-discovery' -and $inv.Err -match 'lite-upgrade-reason-catalog\.json') {
  Ok 'AC-027 version-mismatch: wrong schema value on the catalog fails closed'
} else {
  Fail "AC-027 version-mismatch: catalog bad-schema did not fail closed as expected (rc=$($inv.Rc) err=$($inv.Err))"
}

# =====================================================================
# AC-027: neither-location-resolves fixture
# =====================================================================
$entry = New-Layout -Name 'neither-resolves' -RegMode 'missing' -SchemaMode 'missing' -CatalogMode 'missing'
$inv = Invoke-Discover -Entry $entry -Filename 'capability-registry.json'
# The diagnostic embeds a Python list repr, so Windows paths arrive with
# doubled backslashes; collapse separator runs to '/' before matching.
$errNormalized = ([string]$inv.Err -replace '[\\/]+', '/')
if ($inv.Rc -ne 0 -and $inv.Err -match 'registry-discovery' -and $errNormalized -match [regex]::Escape('plugins/sdd-quality-loop/contracts/capability-registry.json')) {
  Ok 'AC-027 neither-location-resolves: fail-closed diagnostic names the attempted path(s)'
} else {
  Fail "AC-027 neither-location-resolves: expected fail-closed diagnostic naming attempted paths (rc=$($inv.Rc) err=$($inv.Err))"
}

# =====================================================================
# AC-027: vendored-copy-drift fixture
# =====================================================================
$driftRoot = Join-Path $workDir 'drift-repo'
New-Item -ItemType Directory -Path (Join-Path $driftRoot 'contracts') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $driftRoot 'plugins/sdd-quality-loop/scripts') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $driftRoot 'plugins/sdd-quality-loop/contracts') -Force | Out-Null
& git init -q $driftRoot
Copy-Item -LiteralPath (Join-Path $fixturesDir 'registry-discovery-registry-valid.json') -Destination (Join-Path $driftRoot 'contracts/capability-registry.json')
Copy-Item -LiteralPath (Join-Path $fixturesDir 'registry-discovery-schemafile-valid.json') -Destination (Join-Path $driftRoot 'contracts/capability-registry.schema.json')
Copy-Item -LiteralPath (Join-Path $fixturesDir 'registry-discovery-catalog-valid.json') -Destination (Join-Path $driftRoot 'contracts/lite-upgrade-reason-catalog.json')
# epic-192-a4-facet-manifest T-005 extended vendor-capability-registry.py's
# ARTIFACTS with three more schema filenames. That script fails closed when
# a canonical source is missing, so this fixture tree must carry every
# ARTIFACTS entry; otherwise the freshly-vendored assertions below exercise
# the missing-source error path instead of the drift path they test.
foreach ($extra in @('facet-manifest.schema.json', 'capability-summary.schema.json', 'context-projection.schema.json')) {
    Copy-Item -LiteralPath (Join-Path $root "contracts/$extra") -Destination (Join-Path $driftRoot "contracts/$extra")
}
Copy-Item -LiteralPath $realDiscovery -Destination (Join-Path $driftRoot 'plugins/sdd-quality-loop/scripts/registry_discovery.py')
Copy-Item -LiteralPath $realVendor -Destination (Join-Path $driftRoot 'plugins/sdd-quality-loop/scripts/vendor-capability-registry.py')
Copy-Item -LiteralPath (Join-Path $fixturesDir 'registry-discovery-registry-bad-schema.json') -Destination (Join-Path $driftRoot 'plugins/sdd-quality-loop/contracts/capability-registry.json')
Copy-Item -LiteralPath (Join-Path $fixturesDir 'registry-discovery-schemafile-valid.json') -Destination (Join-Path $driftRoot 'plugins/sdd-quality-loop/contracts/capability-registry.schema.json')
Copy-Item -LiteralPath (Join-Path $fixturesDir 'registry-discovery-catalog-valid.json') -Destination (Join-Path $driftRoot 'plugins/sdd-quality-loop/contracts/lite-upgrade-reason-catalog.json')

$vendorScript = Join-Path $driftRoot 'plugins/sdd-quality-loop/scripts/vendor-capability-registry.py'
& $pythonExe $vendorScript --check *> $null
if ($LASTEXITCODE -ne 0) {
  Ok 'AC-027 vendored-copy-drift: --check fails non-zero on a stale vendored copy'
} else {
  Fail 'AC-027 vendored-copy-drift: --check unexpectedly passed against a stale vendored copy'
}

& $pythonExe $vendorScript *> $null
$vendoredFile = Join-Path $driftRoot 'plugins/sdd-quality-loop/contracts/capability-registry.json'
$mtimeBefore = (Get-Item -LiteralPath $vendoredFile).LastWriteTimeUtc
& $pythonExe $vendorScript --check *> $null
$driftCheckRc = $LASTEXITCODE
$mtimeAfter = (Get-Item -LiteralPath $vendoredFile).LastWriteTimeUtc
if ($driftCheckRc -eq 0) {
  Ok 'AC-027 vendored-copy-drift: --check exits zero against a freshly-vendored tree'
} else {
  Fail 'AC-027 vendored-copy-drift: --check unexpectedly failed against a freshly-vendored tree'
}
if ($mtimeBefore -eq $mtimeAfter) {
  Ok 'AC-027 vendored-copy-drift: --check performs no filesystem write (mtime unchanged)'
} else {
  Fail 'AC-027 vendored-copy-drift: --check unexpectedly modified the vendored file (mtime changed)'
}

# =====================================================================
# Suite/CI registration self-checks
# =====================================================================
$runAllSh = Get-Content -Raw -LiteralPath (Join-Path $root 'tests/run-all.sh')
if ($runAllSh -match [regex]::Escape('tests/registry-discovery.tests.sh')) {
  Ok 'self-registration: registry-discovery.tests.sh registered in tests/run-all.sh'
} else {
  Fail 'self-registration: registry-discovery.tests.sh NOT registered in tests/run-all.sh'
}
$runAllPs1 = Get-Content -Raw -LiteralPath (Join-Path $root 'tests/run-all.ps1')
if ($runAllPs1 -match [regex]::Escape('tests/registry-discovery.tests.ps1')) {
  Ok 'self-registration: registry-discovery.tests.ps1 registered in tests/run-all.ps1'
} else {
  Fail 'self-registration: registry-discovery.tests.ps1 NOT registered in tests/run-all.ps1'
}

$humanCopyDir = Join-Path $root 'specs/epic-190-a2-capability-registry/human-copy'
$stagedWorkflow = Join-Path $humanCopyDir '.github/workflows/test.yml'
$stagedManifest = Join-Path $humanCopyDir 'MANIFEST.sha256'
if (Test-Path -LiteralPath $stagedWorkflow) {
  $stagedText = Get-Content -Raw -LiteralPath $stagedWorkflow
  if (($stagedText -match [regex]::Escape('tests/registry-discovery.tests.sh')) -and ($stagedText -match [regex]::Escape('tests/registry-discovery.tests.ps1'))) {
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

Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ("---- summary: pass={0} fail={1} ----" -f $script:PassCount, $script:FailCount)
if ($script:FailCount -eq 0) {
  Write-Host "registry-discovery suite passed ($script:PassCount checks)"
  exit 0
} else {
  Write-Host "registry-discovery suite FAILED ($script:PassCount passed, $script:FailCount failed)"
  exit 1
}
