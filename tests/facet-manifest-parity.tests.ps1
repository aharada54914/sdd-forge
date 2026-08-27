# facet-manifest-parity.tests.ps1 — PowerShell twin of
# facet-manifest-parity.tests.sh (T-005, REQ-006, design.md Test Strategy
# item 6). Behaviourally identical to the bash twin: the same fixture
# enumeration, the same staleness-comparator case table, the same
# installed-layout discovery scratch tree, the same provider-neutrality
# scan. See the bash twin's header for the full TEST-031/032/033/043
# contract this suite implements.
#
# seq0763 Critical remediation: EVERY process invocation in this suite goes
# through Invoke-RawProcess (System.Diagnostics.Process + BaseStream.
# CopyToAsync into a MemoryStream), never Start-Process -RedirectStandard
# Output/-RedirectStandardError. PowerShell's Start-Process redirection
# captures a process's stdout/stderr through a *text*-mode path that
# normalizes line endings on the way into the destination file (CRLF -> LF,
# and a missing trailing newline gets one appended) -- confirmed empirically
# against this exact host: a child process writing the 8 raw bytes
# `A\r\nB\nC\r\n` was captured by Start-Process redirection as the 6 bytes
# `A\nB\nC\n`, silently destroying every CR before this suite's own
# byte-comparison ever ran. That made the entire TEST-031 byte-identical-
# parity contract (and, by construction, the explicit LF-only assertion
# added below) structurally unable to detect a `.ps1` wrapper emitting
# CRLF -- exactly the defect class tasks.md's own T-005 Risk Rationale
# names. Invoke-RawProcess reads the child's stdout/stderr pipes as raw
# bytes with no text-mode translation anywhere in the path.
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Scripts = Join-Path $RepoRoot 'plugins/sdd-quality-loop/scripts'
$FixturesSchema = Join-Path $RepoRoot 'tests/fixtures/facet-manifest/schema'
$FixturesSemantics = Join-Path $RepoRoot 'tests/fixtures/facet-manifest/semantics'
$FixturesSummary = Join-Path $RepoRoot 'tests/fixtures/facet-manifest/capability-summary'
$FixturesProjection = Join-Path $RepoRoot 'tests/fixtures/facet-manifest/context-projection'
$FixturesStaleness = Join-Path $RepoRoot 'tests/fixtures/facet-manifest/staleness'
$FixturesParity = Join-Path $RepoRoot 'tests/fixtures/facet-manifest/parity'
$ProviderTerms = Join-Path $RepoRoot 'plugins/sdd-quality-loop/references/provider-terms.json'

$script:Pass = 0
$script:Fail = 0
function Ok([string]$Message) { $script:Pass++; Write-Host "ok: $Message" }
function Fail([string]$Message) { $script:Fail++; Write-Host "FAIL: $Message" }

# =============================================================================
# Preconditions -- fail loudly rather than silently skipping a runtime.
# =============================================================================
function Get-ToolPath([string]$Name) {
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $command) { return $null }
    return $command.Source
}
$PythonExe = Get-ToolPath 'python3'
if ($null -eq $PythonExe) { $PythonExe = Get-ToolPath 'python' }
$BashExe = Get-ToolPath 'bash'
$PowerShellExe = (Get-Process -Id $PID).Path
if (($null -eq $PythonExe) -or ($null -eq $BashExe)) {
    Write-Host 'facet-manifest-parity: required tool(s) not available: python3/python and/or bash'
    Write-Host '---- summary: pass=0 fail=1 ----'
    exit 1
}

$WorkDir = Join-Path ([System.IO.Path]::GetTempPath()) ('fmparity-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
$WorkDir = (Resolve-Path -LiteralPath $WorkDir).Path

# =============================================================================
# Raw-byte process invocation (see file header for why this replaces
# Start-Process redirection everywhere in this suite).
# =============================================================================
function Invoke-RawProcess {
    param([string]$FileName, [string[]]$Arguments = @(), [string]$WorkingDirectory)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FileName
    foreach ($arg in $Arguments) { $psi.ArgumentList.Add($arg) }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    $outMs = New-Object System.IO.MemoryStream
    $errMs = New-Object System.IO.MemoryStream
    # Both streams are drained concurrently (async), started BEFORE
    # WaitForExit -- reading them sequentially/synchronously risks a
    # classic pipe-buffer deadlock if the child writes enough to one
    # stream to fill its OS pipe buffer while nobody is draining it yet.
    $outTask = $proc.StandardOutput.BaseStream.CopyToAsync($outMs)
    $errTask = $proc.StandardError.BaseStream.CopyToAsync($errMs)
    $proc.WaitForExit()
    $outTask.Wait()
    $errTask.Wait()
    return @{ ExitCode = $proc.ExitCode; StdoutBytes = $outMs.ToArray(); StderrBytes = $errMs.ToArray() }
}

function Get-BytesSha256([byte[]]$Bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($Bytes)
        return -join ($hash | ForEach-Object { $_.ToString('x2') })
    } finally {
        $sha.Dispose()
    }
}

function Test-NoCrBytes([byte[]]$Bytes) {
    foreach ($b in $Bytes) { if ($b -eq 13) { return $false } }
    return $true
}

# =============================================================================
# TEST-031: generic .py/.sh/.ps1 triple-invocation parity helper.
# =============================================================================
$script:CaseN = 0
function Test-Parity {
    param([string]$Label, [string]$Base, [string[]]$Arguments = @())
    $script:CaseN++

    $pyArgs = @((Join-Path $Scripts "$Base.py")) + $Arguments
    $shArgs = @((Join-Path $Scripts "$Base.sh")) + $Arguments
    $ps1Args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $Scripts "$Base.ps1")) + $Arguments

    $pyResult = Invoke-RawProcess -FileName $PythonExe -Arguments $pyArgs -WorkingDirectory $RepoRoot
    $shResult = Invoke-RawProcess -FileName $BashExe -Arguments $shArgs -WorkingDirectory $RepoRoot
    $ps1Result = Invoke-RawProcess -FileName $PowerShellExe -Arguments $ps1Args -WorkingDirectory $RepoRoot

    $problems = @()
    if ($pyResult.ExitCode -ne $shResult.ExitCode) { $problems += "sh-exit:$($shResult.ExitCode)!=py:$($pyResult.ExitCode)" }
    if ($pyResult.ExitCode -ne $ps1Result.ExitCode) { $problems += "ps1-exit:$($ps1Result.ExitCode)!=py:$($pyResult.ExitCode)" }
    if ((Get-BytesSha256 $pyResult.StdoutBytes) -ne (Get-BytesSha256 $shResult.StdoutBytes)) { $problems += 'sh-stdout-diff' }
    if ((Get-BytesSha256 $pyResult.StdoutBytes) -ne (Get-BytesSha256 $ps1Result.StdoutBytes)) { $problems += 'ps1-stdout-diff' }
    if ((Get-BytesSha256 $pyResult.StderrBytes) -ne (Get-BytesSha256 $shResult.StderrBytes)) { $problems += 'sh-stderr-diff' }
    if ((Get-BytesSha256 $pyResult.StderrBytes) -ne (Get-BytesSha256 $ps1Result.StderrBytes)) { $problems += 'ps1-stderr-diff' }

    if ($problems.Count -eq 0) {
        Ok "$Label (exit=$($pyResult.ExitCode), stdout/stderr byte-identical across .py/.sh/.ps1)"
    } else {
        Fail "$Label -- $($problems -join ' ') (py_rc=$($pyResult.ExitCode) sh_rc=$($shResult.ExitCode) ps1_rc=$($ps1Result.ExitCode))"
    }

    # Explicit LF-only assertion (seq0763 Critical remediation), SEPARATE
    # from the byte-parity assertion above: none of the six captured
    # buffers may contain a raw CR (0x0D) byte -- design.md's diagnostic-
    # determinism contract and AC-031's own "the .ps1 wrapper's own output
    # stays LF-only on Windows" clause, checked directly. (A CR-for-CR
    # triple that all three runtimes agreed on would still pass the
    # byte-parity check above while violating this contract -- this
    # assertion is not redundant with it.)
    $crHits = @()
    if (-not (Test-NoCrBytes $pyResult.StdoutBytes)) { $crHits += 'py-stdout' }
    if (-not (Test-NoCrBytes $pyResult.StderrBytes)) { $crHits += 'py-stderr' }
    if (-not (Test-NoCrBytes $shResult.StdoutBytes)) { $crHits += 'sh-stdout' }
    if (-not (Test-NoCrBytes $shResult.StderrBytes)) { $crHits += 'sh-stderr' }
    if (-not (Test-NoCrBytes $ps1Result.StdoutBytes)) { $crHits += 'ps1-stdout' }
    if (-not (Test-NoCrBytes $ps1Result.StderrBytes)) { $crHits += 'ps1-stderr' }
    if ($crHits.Count -eq 0) {
        Ok "$Label (LF-only: no CR byte in any of .py/.sh/.ps1 stdout/stderr)"
    } else {
        Fail "$Label -- CR byte(s) found in: $($crHits -join ' ')"
    }
}

# --- validate-facet-manifest: every fixture in suites 1-2 -------------------
$FacetManifestFixtures = @(Get-ChildItem -Path $FixturesSchema, $FixturesSemantics -File -Recurse |
    Where-Object { $_.Extension -in '.json', '.yaml', '.bin' } | Sort-Object FullName)
# seq0763 Minor-2: minimum-fixture-count non-vacuity guard -- if this glob
# silently returned zero (a fixture directory renamed/emptied out from
# under this suite), the loop below would run zero times and the suite
# would stay green with fewer assertions, not fail. 50 is comfortably below
# the 62 fixtures present as of this task's own authoring, so a routine
# future fixture addition/removal within that margin does not need this
# suite edited, but a directory going empty or nearly empty does trip it.
if ($FacetManifestFixtures.Count -ge 50) {
    Ok "TEST-031 non-vacuity guard: facet-manifest schema+semantics fixture count is $($FacetManifestFixtures.Count) (>= 50 expected)"
} else {
    Fail "TEST-031 non-vacuity guard: facet-manifest schema+semantics fixture count is $($FacetManifestFixtures.Count), expected >= 50 -- the suite may have silently shrunk"
}
foreach ($fx in $FacetManifestFixtures) {
    Test-Parity -Label "TEST-031 validate-facet-manifest: $($fx.Name)" -Base 'validate-facet-manifest' `
      -Arguments @('--manifest', $fx.FullName)
}

# --- validate-capability-summary: every fixture in suite 3 ------------------
$SummaryFixtures = @(Get-ChildItem -Path $FixturesSummary -File -Recurse |
    Where-Object { $_.Extension -in '.json', '.yaml', '.bin' } | Sort-Object FullName)
if ($SummaryFixtures.Count -ge 10) {
    Ok "TEST-031 non-vacuity guard: capability-summary fixture count is $($SummaryFixtures.Count) (>= 10 expected)"
} else {
    Fail "TEST-031 non-vacuity guard: capability-summary fixture count is $($SummaryFixtures.Count), expected >= 10 -- the suite may have silently shrunk"
}
foreach ($fx in $SummaryFixtures) {
    Test-Parity -Label "TEST-031 validate-capability-summary: $($fx.Name)" -Base 'validate-capability-summary' `
      -Arguments @('--summary', $fx.FullName)
}

# --- validate-context-projection: every fixture in suite 4 ------------------
$ProjectionFixtures = @(Get-ChildItem -Path $FixturesProjection -File -Recurse |
    Where-Object { $_.Extension -in '.json', '.yaml', '.bin' } | Sort-Object FullName)
if ($ProjectionFixtures.Count -ge 20) {
    Ok "TEST-031 non-vacuity guard: context-projection fixture count is $($ProjectionFixtures.Count) (>= 20 expected)"
} else {
    Fail "TEST-031 non-vacuity guard: context-projection fixture count is $($ProjectionFixtures.Count), expected >= 20 -- the suite may have silently shrunk"
}
foreach ($fx in $ProjectionFixtures) {
    Test-Parity -Label "TEST-031 validate-context-projection: $($fx.Name)" -Base 'validate-context-projection' `
      -Arguments @('--projection', $fx.FullName)
}

# --- compare-facet-manifest-staleness: every distinct (old, new, flags)
# invocation suite 5 exercises. --------------------------------------------
$StalenessCases = @(
    @('base-old.json', 'registry-digest-only-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'none'),
    @('base-old.json', 'gate-blocking-change-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'none'),
    @('base-old.json', 'evidence-change-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'none'),
    @('minimum-enforcement-old.json', 'minimum-enforcement-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'none'),
    @('base-old.json', 'projection-digest-only-new.json', 'weakened', 'not-weakened', 'not-weakened', 'none'),
    @('base-old.json', 'registry-digest-only-new.json', 'not-weakened', 'indeterminate', 'not-weakened', 'none'),
    @('base-old.json', 'no-axis-change-semantic-differs-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'none'),
    @('base-old.json', 'ownership-digest-only-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'none'),
    @('base-old.json', 'ownership-digest-only-new.json', 'not-weakened', 'not-weakened', 'indeterminate', 'none'),
    @('base-old.json', 'multi-axis-mixed-verdict-new.json', 'not-weakened', 'not-weakened', 'weakened', 'none'),
    @('base-old.json', 'multi-axis-mixed-verdict-new.json', 'not-weakened', 'indeterminate', 'weakened', 'none'),
    @('base-old.json', 'patch-bump-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'patch'),
    @('base-old.json', 'minor-bump-changed-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'minor'),
    @('base-old.json', 'minor-bump-unchanged-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'minor'),
    @('base-old.json', 'major-bump-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'major'),
    @('base-old.json', 'major-bump-block-new.json', 'weakened', 'not-weakened', 'not-weakened', 'major'),
    @('base-old.json', 'minor-rule-set-bump-changed-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'minor-rule-set'),
    @('base-old.json', 'major-bump-semantic-changed-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'major'),
    @('base-old.json', 'feature-change-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'none'),
    @('base-old.json', 'affected-components-change-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'none'),
    @('base-old.json', 'required-facets-change-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'none'),
    @('base-old.json', 'lite-eligibility-change-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'none'),
    @('base-old.json', 'multi-component-bump-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'minor'),
    @('schema-invalid-manifest.json', 'registry-digest-only-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'none'),
    @('base-old.json', 'schema-invalid-manifest.json', 'not-weakened', 'not-weakened', 'not-weakened', 'none'),
    @('base-old.json', 'minor-bump-changed-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'patch'),
    @('base-old.json', 'major-bump-new.json', 'not-weakened', 'not-weakened', 'not-weakened', 'patch'),
    @('manifest-non-utf8-bytes.bin', 'base-old.json', 'not-weakened', 'not-weakened', 'not-weakened', 'none')
)
if ($StalenessCases.Count -ge 20) {
    Ok "TEST-031 non-vacuity guard: compare-facet-manifest-staleness case-table length is $($StalenessCases.Count) (>= 20 expected)"
} else {
    Fail "TEST-031 non-vacuity guard: compare-facet-manifest-staleness case-table length is $($StalenessCases.Count), expected >= 20 -- the case table may have silently shrunk"
}
foreach ($c in $StalenessCases) {
    $old, $new, $proj, $reg, $own, $bump = $c
    Test-Parity -Label "TEST-031 compare-facet-manifest-staleness: $old vs $new ($proj/$reg/$own/$bump)" `
      -Base 'compare-facet-manifest-staleness' -Arguments @(
        '--old-manifest', (Join-Path $FixturesStaleness $old),
        '--new-manifest', (Join-Path $FixturesStaleness $new),
        '--projection-weakening', $proj, '--registry-weakening', $reg, '--ownership-weakening', $own,
        '--resolver-version-bump', $bump)
}

Test-Parity -Label 'TEST-031 compare-facet-manifest-staleness: nonexistent --old-manifest path' `
  -Base 'compare-facet-manifest-staleness' -Arguments @(
    '--old-manifest', (Join-Path $FixturesStaleness 'does-not-exist.json'),
    '--new-manifest', (Join-Path $FixturesStaleness 'base-old.json'),
    '--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened',
    '--resolver-version-bump', 'none')

Test-Parity -Label 'TEST-031 compare-facet-manifest-staleness: missing --resolver-version-bump (exit-3 diagnostic channel)' `
  -Base 'compare-facet-manifest-staleness' -Arguments @(
    '--old-manifest', (Join-Path $FixturesStaleness 'base-old.json'),
    '--new-manifest', (Join-Path $FixturesStaleness 'registry-digest-only-new.json'),
    '--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened')

Test-Parity -Label 'TEST-031 compare-facet-manifest-staleness: out-of-enum --registry-weakening (exit-3 diagnostic channel)' `
  -Base 'compare-facet-manifest-staleness' -Arguments @(
    '--old-manifest', (Join-Path $FixturesStaleness 'base-old.json'),
    '--new-manifest', (Join-Path $FixturesStaleness 'registry-digest-only-new.json'),
    '--projection-weakening', 'not-weakened', '--registry-weakening', 'bogus', '--ownership-weakening', 'not-weakened',
    '--resolver-version-bump', 'none')

# --- Windows-style path argument (AC-031 trailing clause). -----------------
$WinPath = (Get-Content -LiteralPath (Join-Path $FixturesParity 'windows-style-path.txt') -Raw).TrimEnd("`r", "`n")
Test-Parity -Label 'TEST-031 validate-facet-manifest: Windows-style backslash path argument' `
  -Base 'validate-facet-manifest' -Arguments @('--manifest', $WinPath)

Test-Parity -Label 'TEST-031 compare-facet-manifest-staleness: Windows-style backslash --old-manifest path (exit-3 channel)' `
  -Base 'compare-facet-manifest-staleness' -Arguments @(
    '--old-manifest', $WinPath,
    '--new-manifest', (Join-Path $FixturesStaleness 'base-old.json'),
    '--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened',
    '--resolver-version-bump', 'none')

# =============================================================================
# TEST-032: installed-layout discovery lock.
# =============================================================================
$Installed = Join-Path $WorkDir 'installed'
New-Item -ItemType Directory -Path (Join-Path $Installed 'scripts') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Installed 'contracts') -Force | Out-Null
foreach ($f in @(
        'validate-facet-manifest.py', 'validate-facet-manifest.sh', 'validate-facet-manifest.ps1',
        'validate-capability-summary.py', 'validate-capability-summary.sh', 'validate-capability-summary.ps1',
        'validate-context-projection.py', 'validate-context-projection.sh', 'validate-context-projection.ps1',
        'compare-facet-manifest-staleness.py', 'compare-facet-manifest-staleness.sh', 'compare-facet-manifest-staleness.ps1',
        'lib/py-dispatch.sh', 'lib/py-dispatch.ps1'
    )) {
    $src = Join-Path $Scripts $f
    if (Test-Path -LiteralPath $src) {
        $destination = Join-Path $Installed "scripts/$f"
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $src -Destination $destination -Force
    }
}
foreach ($schema in @('facet-manifest.schema.json', 'capability-summary.schema.json', 'context-projection.schema.json')) {
    $src = Join-Path $RepoRoot "contracts/$schema"
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $Installed "contracts/$schema") -Force
    }
}

function Invoke-Installed {
    param([string]$Kind, [string]$Base, [string[]]$Arguments = @())
    switch ($Kind) {
        'py' { return Invoke-RawProcess -FileName $PythonExe -Arguments (@((Join-Path $Installed "scripts/$Base.py")) + $Arguments) }
        'sh' { return Invoke-RawProcess -FileName $BashExe -Arguments (@((Join-Path $Installed "scripts/$Base.sh")) + $Arguments) }
        'ps1' { return Invoke-RawProcess -FileName $PowerShellExe -Arguments (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $Installed "scripts/$Base.ps1")) + $Arguments) }
        default { throw "unknown kind: $Kind" }
    }
}

function Assert-InstalledOk {
    param([string]$Label, [string]$Kind, [string]$Base, [string[]]$Arguments = @())
    $r = Invoke-Installed -Kind $Kind -Base $Base -Arguments $Arguments
    $outText = [System.Text.Encoding]::UTF8.GetString($r.StdoutBytes)
    $errText = [System.Text.Encoding]::UTF8.GetString($r.StderrBytes)
    if ($r.ExitCode -eq 0 -and [string]::IsNullOrEmpty($outText) -and [string]::IsNullOrEmpty($errText)) {
        Ok $Label
    } else {
        Fail "$Label -- expected exit=0 no output, got exit=$($r.ExitCode) stdout=[$outText] stderr=[$errText]"
    }
}

function Assert-InstalledVerdict {
    param([string]$Label, [string]$Kind, [string]$Base, [string]$ExpectedStdout, [string[]]$Arguments = @())
    $r = Invoke-Installed -Kind $Kind -Base $Base -Arguments $Arguments
    $outText = ([System.Text.Encoding]::UTF8.GetString($r.StdoutBytes)) -replace "`r?`n$", ''
    $errText = [System.Text.Encoding]::UTF8.GetString($r.StderrBytes)
    if ($r.ExitCode -eq 0 -and $outText -ceq $ExpectedStdout -and [string]::IsNullOrEmpty($errText)) {
        Ok $Label
    } else {
        Fail "$Label -- expected exit=0 stdout=[$ExpectedStdout] stderr=[], got exit=$($r.ExitCode) stdout=[$outText] stderr=[$errText]"
    }
}

foreach ($kind in @('py', 'sh', 'ps1')) {
    Assert-InstalledOk -Label "TEST-032 installed-layout discovery: validate-facet-manifest ($kind)" -Kind $kind `
      -Base 'validate-facet-manifest' -Arguments @('--manifest', (Join-Path $FixturesSchema 'valid-base.json'))
    Assert-InstalledOk -Label "TEST-032 installed-layout discovery: validate-capability-summary ($kind)" -Kind $kind `
      -Base 'validate-capability-summary' -Arguments @('--summary', (Join-Path $FixturesSummary 'decision-doc-v2-section6-worked-example.json'))
    Assert-InstalledOk -Label "TEST-032 installed-layout discovery: validate-context-projection ($kind)" -Kind $kind `
      -Base 'validate-context-projection' -Arguments @('--projection', (Join-Path $FixturesProjection 'rekeyed-two-component-non-slug-id.json'))
    Assert-InstalledVerdict -Label "TEST-032 installed-layout discovery: compare-facet-manifest-staleness ($kind)" -Kind $kind `
      -Base 'compare-facet-manifest-staleness' -ExpectedStdout 'facet-manifest-staleness: fresh:metadata-only-refresh' -Arguments @(
        '--old-manifest', (Join-Path $FixturesStaleness 'base-old.json'),
        '--new-manifest', (Join-Path $FixturesStaleness 'registry-digest-only-new.json'),
        '--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened',
        '--resolver-version-bump', 'none')
}

# --- Non-vacuity canary --------------------------------------------------
Rename-Item -LiteralPath (Join-Path $Installed 'contracts') -NewName 'contracts.hidden'
$canaryResult = Invoke-RawProcess -FileName $PythonExe -Arguments @((Join-Path $Installed 'scripts/validate-facet-manifest.py'), '--manifest', (Join-Path $FixturesSchema 'valid-base.json'))
$canaryText = ([System.Text.Encoding]::UTF8.GetString($canaryResult.StdoutBytes)) + ([System.Text.Encoding]::UTF8.GetString($canaryResult.StderrBytes))
Rename-Item -LiteralPath (Join-Path $Installed 'contracts.hidden') -NewName 'contracts'
if ($canaryResult.ExitCode -ne 0 -and $canaryText.Contains('schema-discovery-failed')) {
    Ok 'TEST-032 non-vacuity canary: removing the packaged contracts/ copy makes discovery fail closed (schema-discovery-failed)'
} else {
    Fail "TEST-032 non-vacuity canary: expected exit!=0 with schema-discovery-failed once the packaged copy was hidden, got exit=$($canaryResult.ExitCode) output=[$canaryText]"
}

# =============================================================================
# TEST-033: six-suite registration proof.
# =============================================================================
$SixSuites = @('facet-manifest-schema', 'facet-manifest-semantics', 'capability-summary-schema', 'context-projection-schema', 'facet-manifest-staleness', 'facet-manifest-parity')
$RunAllSh = Get-Content (Join-Path $RepoRoot 'tests/run-all.sh') -Raw
$RunAllPs1 = Get-Content (Join-Path $RepoRoot 'tests/run-all.ps1') -Raw
foreach ($suite in $SixSuites) {
    if ($RunAllSh.Contains("tests/$suite.tests.sh")) {
        Ok "TEST-033: tests/run-all.sh registers tests/$suite.tests.sh"
    } else {
        Fail "TEST-033: tests/run-all.sh does NOT register tests/$suite.tests.sh"
    }
    if ($RunAllPs1.Contains("tests/$suite.tests.ps1")) {
        Ok "TEST-033: tests/run-all.ps1 registers tests/$suite.tests.ps1"
    } else {
        Fail "TEST-033: tests/run-all.ps1 does NOT register tests/$suite.tests.ps1"
    }
}

$StagedWorkflow = Join-Path $RepoRoot 'specs/epic-192-a4-facet-manifest/human-copy/.github/workflows/test.yml'
$StagedManifest = Join-Path $RepoRoot 'specs/epic-192-a4-facet-manifest/human-copy/MANIFEST.sha256'

if (Test-Path -LiteralPath $StagedWorkflow) {
    $stagedText = Get-Content -LiteralPath $StagedWorkflow -Raw
    $stagedMissing = @()
    foreach ($suite in $SixSuites) {
        if (-not $stagedText.Contains("tests/$suite.tests.sh")) { $stagedMissing += "$suite.tests.sh" }
        if (-not $stagedText.Contains("tests/$suite.tests.ps1")) { $stagedMissing += "$suite.tests.ps1" }
    }
    if ($stagedMissing.Count -eq 0) {
        Ok "TEST-033: the staged .github/workflows/test.yml candidate carries all six suites' CI steps"
    } else {
        Fail "TEST-033: staged candidate is missing CI steps for: $($stagedMissing -join ' ')"
    }
} else {
    Fail "TEST-033: staged .github/workflows/test.yml candidate is missing at $StagedWorkflow"
}

if ((Test-Path -LiteralPath $StagedWorkflow) -and (Test-Path -LiteralPath $StagedManifest)) {
    $stagedHash = (Get-FileHash -LiteralPath $StagedWorkflow -Algorithm SHA256).Hash.ToLower()
    $manifestLine = (Get-Content -LiteralPath $StagedManifest | Where-Object { $_ -match 'workflows/test\.yml' } | Select-Object -First 1)
    $manifestHash = if ($manifestLine) { ($manifestLine -split '\s+')[0].ToLower() } else { '' }
    if ($manifestHash -and $stagedHash -eq $manifestHash) {
        Ok 'TEST-033: staged candidate sha256 matches its own MANIFEST.sha256 entry'
    } else {
        Fail "TEST-033: staged candidate sha256 ($stagedHash) does not match MANIFEST.sha256 ($manifestHash)"
    }
} else {
    Fail 'TEST-033: MANIFEST.sha256 or the staged candidate is missing'
}

$GitDirCheck = & git -C $RepoRoot rev-parse --git-dir 2>&1
if ($LASTEXITCODE -eq 0) {
    & git -C $RepoRoot diff --quiet HEAD -- .github/workflows/test.yml 2>$null
    if ($LASTEXITCODE -eq 0) {
        Ok 'TEST-033: the live .github/workflows/test.yml is byte-unchanged relative to its committed state (this task never writes to it)'
    } else {
        Fail 'TEST-033: live .github/workflows/test.yml has an uncommitted modification -- this task must never write to it'
    }
} else {
    Fail "TEST-033: cannot verify the live workflow is unmodified (no git repository resolved at $RepoRoot)"
}

# =============================================================================
# TEST-043: provider-neutrality scan.
#
# seq0763 Major remediation: the earlier revision excluded the WHOLE term
# "lambda" from the four scripts' own source scan, which let a genuine
# contamination string like `LAMBDA_DEPLOY_TARGET = "lambda"` slip through
# undetected -- an unconditional word exclusion drops the allowlist's
# detection power by 1/16 (one of Epic A2's 16 terms), and the exclusion
# itself drifted from what requirements.md/acceptance-tests.md actually
# authorize as the false-positive defense (a CLEAN FIXTURE, not a term
# exclusion). Fixed to IDIOM-level masking: only the exact `key=lambda`
# keyword-argument idiom (the one, sole legitimate occurrence in all four
# scripts -- `sorted(diags, key=lambda d: (d.check_id, d.pointer))`, T-001's
# diagnostic-determinism-contract implementation, reused verbatim by
# T-002/T-003/T-004) is masked out of the text BEFORE scanning; every other
# occurrence of the word "lambda" anywhere in the source -- including a
# quoted string literal like `"lambda"` -- is scanned normally against the
# full, unexcluded 16-term allowlist.
# =============================================================================
$ScanScript = @'
import json
import re
import sys

target_path, terms_path = sys.argv[1], sys.argv[2]
doc = json.load(open(terms_path, encoding="utf-8"))
terms = []
for category_terms in doc.get("categories", {}).values():
    terms.extend(category_terms)
text = open(target_path, encoding="utf-8", errors="replace").read()
# Idiom-level mask: ONLY the `key=lambda` keyword-argument idiom (Python's
# own reserved keyword used as a sort key, never a provider-name reference)
# is removed from the scanned text -- a standalone "lambda" anywhere else
# (e.g. a quoted string literal) is left untouched and fully scannable.
masked = re.sub(r"key\s*=\s*lambda\b", "key=__PY_LAMBDA_KEYWORD_IDIOM__", text)
masked_lower = masked.lower()
hits = []
for term in terms:
    lowered = term.lower()
    if re.search(r"\b" + re.escape(lowered) + r"\b", masked_lower):
        hits.append(term)
print(",".join(hits))
'@

function Get-ScanHits([string]$TargetPath) {
    $result = ($ScanScript | & $PythonExe - $TargetPath $ProviderTerms | Out-String).Trim()
    return $result
}

# seq0763 Minor-1: "the four scripts' source" (security-spec.md) means each
# script's full .py/.sh/.ps1 triple, not the .py master alone -- the .sh/
# .ps1 wrappers are thin forwarders with no `lambda` idiom of their own, so
# they need no masking, but they are still in-scope scan targets.
$ProviderNeutralityTargets = @(
    (Join-Path $RepoRoot 'contracts/facet-manifest.schema.json'),
    (Join-Path $RepoRoot 'contracts/capability-summary.schema.json'),
    (Join-Path $RepoRoot 'contracts/context-projection.schema.json'),
    (Join-Path $Scripts 'validate-facet-manifest.py'), (Join-Path $Scripts 'validate-facet-manifest.sh'), (Join-Path $Scripts 'validate-facet-manifest.ps1'),
    (Join-Path $Scripts 'validate-capability-summary.py'), (Join-Path $Scripts 'validate-capability-summary.sh'), (Join-Path $Scripts 'validate-capability-summary.ps1'),
    (Join-Path $Scripts 'validate-context-projection.py'), (Join-Path $Scripts 'validate-context-projection.sh'), (Join-Path $Scripts 'validate-context-projection.ps1'),
    (Join-Path $Scripts 'compare-facet-manifest-staleness.py'), (Join-Path $Scripts 'compare-facet-manifest-staleness.sh'), (Join-Path $Scripts 'compare-facet-manifest-staleness.ps1')
)
foreach ($target in $ProviderNeutralityTargets) {
    if (Test-Path -LiteralPath $target) {
        $hits = Get-ScanHits $target
        if ([string]::IsNullOrEmpty($hits)) {
            Ok "TEST-043: $(Split-Path $target -Leaf) contains no provider-neutrality-allowlist term"
        } else {
            Fail "TEST-043: $(Split-Path $target -Leaf) contains provider-neutrality-allowlist term(s): $hits"
        }
    } else {
        Fail "TEST-043: scan target missing: $target"
    }
}

$DirtyHits = Get-ScanHits (Join-Path $FixturesParity 'provider-neutrality-dirty.txt')
if (-not [string]::IsNullOrEmpty($DirtyHits)) {
    Ok "TEST-043 non-vacuity canary: the dirty fixture is correctly flagged ($DirtyHits)"
} else {
    Fail 'TEST-043 non-vacuity canary: the dirty fixture (deliberately containing a provider term) was NOT flagged -- the scan is vacuous'
}

# seq0763 Major regression lock: a `NAME = "lambda"  # Lambda ...`-shaped
# assignment (the evaluator's own dirty-fixture pattern) must still be
# flagged even though it is NOT the masked `key=lambda` idiom -- proves the
# idiom-level mask does not over-mask a genuine standalone occurrence.
$LambdaDirtyHits = Get-ScanHits (Join-Path $FixturesParity 'provider-neutrality-lambda-dirty.txt')
if ($LambdaDirtyHits -match '(^|,)lambda(,|$)') {
    Ok "TEST-043 lambda-idiom-mask regression lock: a standalone quoted 'lambda' string-literal assignment (not the key=lambda idiom) is correctly flagged ($LambdaDirtyHits)"
} else {
    Fail "TEST-043 lambda-idiom-mask regression lock: expected 'lambda' to be flagged in the standalone-assignment fixture, got [$LambdaDirtyHits] -- the idiom mask is over-masking"
}

$CleanHits = Get-ScanHits (Join-Path $FixturesParity 'provider-neutrality-clean.txt')
if ([string]::IsNullOrEmpty($CleanHits)) {
    Ok 'TEST-043: the clean fixture (this feature''s own provider-neutral vocabulary) produces no false positive'
} else {
    Fail "TEST-043: the clean fixture unexpectedly matched: $CleanHits"
}
if ((Get-Content -LiteralPath (Join-Path $FixturesParity 'provider-neutrality-clean.txt') -Raw).Contains('distribution_channels')) {
    Ok "TEST-043: the clean fixture genuinely contains 'distribution_channels' (the no-hit result above is not vacuous)"
} else {
    Fail "TEST-043: the clean fixture no longer contains 'distribution_channels' -- rewrite it to keep testing the intended vocabulary"
}

# =============================================================================
# Vendored-copy drift gate (Done When).
# =============================================================================
$VendorOut = & $PythonExe (Join-Path $Scripts 'vendor-capability-registry.py') --check 2>&1 | Out-String
$VendorRc = $LASTEXITCODE
if ($VendorRc -eq 0 -and $VendorOut.Contains('no drift')) {
    Ok 'vendor-capability-registry.py --check exits 0 against the clean tree (extended to cover the three new schema filenames)'
} else {
    Fail "vendor-capability-registry.py --check expected exit=0 with 'no drift', got exit=$VendorRc output=[$VendorOut]"
}

# =============================================================================
# Suite/CI self-registration self-check.
# =============================================================================
if ($RunAllPs1.Contains('tests/facet-manifest-parity.tests.ps1')) {
    Ok 'self-registration: tests/run-all.ps1 lists this suite'
} else {
    Fail 'self-registration: tests/run-all.ps1 does not list tests/facet-manifest-parity.tests.ps1'
}

Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue

Write-Host ''
Write-Host "facet-manifest-parity: $($script:Pass) passed, $($script:Fail) failed"
if ($script:Fail -ne 0) { exit 1 }
exit 0
