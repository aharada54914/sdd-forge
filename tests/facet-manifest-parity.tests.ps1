# facet-manifest-parity.tests.ps1 — PowerShell twin of
# facet-manifest-parity.tests.sh (T-005, REQ-006, design.md Test Strategy
# item 6). Behaviourally identical to the bash twin: the same fixture
# enumeration, the same staleness-comparator case table, the same
# installed-layout discovery scratch tree, the same provider-neutrality
# scan. See the bash twin's header for the full TEST-031/032/033/043
# contract this suite implements.
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
$OutDir = Join-Path $WorkDir 'out'
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

# =============================================================================
# TEST-031: generic .py/.sh/.ps1 triple-invocation parity helper.
# =============================================================================
function Get-Sha256([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

$script:CaseN = 0
function Test-Parity {
    param([string]$Label, [string]$Base, [string[]]$Arguments = @())
    $script:CaseN++
    $slot = "c$($script:CaseN)"
    $pyOut = Join-Path $OutDir "$slot.py.out"; $pyErr = Join-Path $OutDir "$slot.py.err"
    $shOut = Join-Path $OutDir "$slot.sh.out"; $shErr = Join-Path $OutDir "$slot.sh.err"
    $ps1Out = Join-Path $OutDir "$slot.ps1.out"; $ps1Err = Join-Path $OutDir "$slot.ps1.err"

    $pyProc = Start-Process -FilePath $PythonExe -ArgumentList (@((Join-Path $Scripts "$Base.py")) + $Arguments) `
      -Wait -PassThru -WorkingDirectory $RepoRoot -RedirectStandardOutput $pyOut -RedirectStandardError $pyErr
    $shProc = Start-Process -FilePath $BashExe -ArgumentList (@((Join-Path $Scripts "$Base.sh")) + $Arguments) `
      -Wait -PassThru -WorkingDirectory $RepoRoot -RedirectStandardOutput $shOut -RedirectStandardError $shErr
    $ps1Proc = Start-Process -FilePath $PowerShellExe `
      -ArgumentList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $Scripts "$Base.ps1")) + $Arguments) `
      -Wait -PassThru -WorkingDirectory $RepoRoot -RedirectStandardOutput $ps1Out -RedirectStandardError $ps1Err

    $problems = @()
    if ($pyProc.ExitCode -ne $shProc.ExitCode) { $problems += "sh-exit:$($shProc.ExitCode)!=py:$($pyProc.ExitCode)" }
    if ($pyProc.ExitCode -ne $ps1Proc.ExitCode) { $problems += "ps1-exit:$($ps1Proc.ExitCode)!=py:$($pyProc.ExitCode)" }
    if ((Get-Sha256 $pyOut) -ne (Get-Sha256 $shOut)) { $problems += 'sh-stdout-diff' }
    if ((Get-Sha256 $pyOut) -ne (Get-Sha256 $ps1Out)) { $problems += 'ps1-stdout-diff' }
    if ((Get-Sha256 $pyErr) -ne (Get-Sha256 $shErr)) { $problems += 'sh-stderr-diff' }
    if ((Get-Sha256 $pyErr) -ne (Get-Sha256 $ps1Err)) { $problems += 'ps1-stderr-diff' }

    if ($problems.Count -eq 0) {
        Ok "$Label (exit=$($pyProc.ExitCode), stdout/stderr byte-identical across .py/.sh/.ps1)"
    } else {
        Fail "$Label -- $($problems -join ' ') (py_rc=$($pyProc.ExitCode) sh_rc=$($shProc.ExitCode) ps1_rc=$($ps1Proc.ExitCode))"
    }
    Remove-Item -Path (Join-Path $OutDir "$slot.*") -Force -ErrorAction SilentlyContinue
}

# --- validate-facet-manifest: every fixture in suites 1-2 -------------------
$FacetManifestFixtures = @(Get-ChildItem -Path $FixturesSchema, $FixturesSemantics -File -Recurse |
    Where-Object { $_.Extension -in '.json', '.yaml', '.bin' } | Sort-Object FullName)
foreach ($fx in $FacetManifestFixtures) {
    Test-Parity -Label "TEST-031 validate-facet-manifest: $($fx.Name)" -Base 'validate-facet-manifest' `
      -Arguments @('--manifest', $fx.FullName)
}

# --- validate-capability-summary: every fixture in suite 3 ------------------
$SummaryFixtures = @(Get-ChildItem -Path $FixturesSummary -File -Recurse |
    Where-Object { $_.Extension -in '.json', '.yaml', '.bin' } | Sort-Object FullName)
foreach ($fx in $SummaryFixtures) {
    Test-Parity -Label "TEST-031 validate-capability-summary: $($fx.Name)" -Base 'validate-capability-summary' `
      -Arguments @('--summary', $fx.FullName)
}

# --- validate-context-projection: every fixture in suite 4 ------------------
$ProjectionFixtures = @(Get-ChildItem -Path $FixturesProjection -File -Recurse |
    Where-Object { $_.Extension -in '.json', '.yaml', '.bin' } | Sort-Object FullName)
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
        'compare-facet-manifest-staleness.py', 'compare-facet-manifest-staleness.sh', 'compare-facet-manifest-staleness.ps1'
    )) {
    $src = Join-Path $Scripts $f
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $Installed "scripts/$f") -Force
    }
}
foreach ($schema in @('facet-manifest.schema.json', 'capability-summary.schema.json', 'context-projection.schema.json')) {
    $src = Join-Path $RepoRoot "contracts/$schema"
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $Installed "contracts/$schema") -Force
    }
}

function Invoke-Installed {
    param([string]$Kind, [string]$Base, [string]$OutPrefix, [string[]]$Arguments = @())
    $outFile = "$OutPrefix.out"; $errFile = "$OutPrefix.err"
    switch ($Kind) {
        'py' { $proc = Start-Process -FilePath $PythonExe -ArgumentList (@((Join-Path $Installed "scripts/$Base.py")) + $Arguments) -Wait -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile }
        'sh' { $proc = Start-Process -FilePath $BashExe -ArgumentList (@((Join-Path $Installed "scripts/$Base.sh")) + $Arguments) -Wait -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile }
        'ps1' { $proc = Start-Process -FilePath $PowerShellExe -ArgumentList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $Installed "scripts/$Base.ps1")) + $Arguments) -Wait -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile }
        default { throw "unknown kind: $Kind" }
    }
    return $proc.ExitCode
}

function Assert-InstalledOk {
    param([string]$Label, [string]$Kind, [string]$Base, [string[]]$Arguments = @())
    $outp = Join-Path $OutDir "disc-$Base-$Kind"
    $rc = Invoke-Installed -Kind $Kind -Base $Base -OutPrefix $outp -Arguments $Arguments
    $out = Get-Content -LiteralPath "$outp.out" -Raw
    $err = Get-Content -LiteralPath "$outp.err" -Raw
    if ($null -eq $out) { $out = '' }
    if ($null -eq $err) { $err = '' }
    if ($rc -eq 0 -and [string]::IsNullOrEmpty($out) -and [string]::IsNullOrEmpty($err)) {
        Ok $Label
    } else {
        Fail "$Label -- expected exit=0 no output, got exit=$rc stdout=[$out] stderr=[$err]"
    }
}

function Assert-InstalledVerdict {
    param([string]$Label, [string]$Kind, [string]$Base, [string]$ExpectedStdout, [string[]]$Arguments = @())
    $outp = Join-Path $OutDir "disc-$Base-$Kind"
    $rc = Invoke-Installed -Kind $Kind -Base $Base -OutPrefix $outp -Arguments $Arguments
    $out = (Get-Content -LiteralPath "$outp.out" -Raw)
    $err = Get-Content -LiteralPath "$outp.err" -Raw
    if ($null -eq $out) { $out = '' }
    if ($null -eq $err) { $err = '' }
    $out = $out -replace "`r?`n$", ''
    if ($rc -eq 0 -and $out -ceq $ExpectedStdout -and [string]::IsNullOrEmpty($err)) {
        Ok $Label
    } else {
        Fail "$Label -- expected exit=0 stdout=[$ExpectedStdout] stderr=[], got exit=$rc stdout=[$out] stderr=[$err]"
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
$canaryOut = Join-Path $OutDir 'canary.out'
$canaryProc = Start-Process -FilePath $PythonExe -ArgumentList @((Join-Path $Installed 'scripts/validate-facet-manifest.py'), '--manifest', (Join-Path $FixturesSchema 'valid-base.json')) `
  -Wait -PassThru -RedirectStandardOutput $canaryOut -RedirectStandardError "$canaryOut.err"
$canaryText = (Get-Content -LiteralPath $canaryOut -Raw) + (Get-Content -LiteralPath "$canaryOut.err" -Raw)
Rename-Item -LiteralPath (Join-Path $Installed 'contracts.hidden') -NewName 'contracts'
if ($canaryProc.ExitCode -ne 0 -and $canaryText.Contains('schema-discovery-failed')) {
    Ok 'TEST-032 non-vacuity canary: removing the packaged contracts/ copy makes discovery fail closed (schema-discovery-failed)'
} else {
    Fail "TEST-032 non-vacuity canary: expected exit!=0 with schema-discovery-failed once the packaged copy was hidden, got exit=$($canaryProc.ExitCode) output=[$canaryText]"
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
# =============================================================================
$ScanScript = @'
import json
import re
import sys

target_path, terms_path, excluded_raw = sys.argv[1], sys.argv[2], sys.argv[3]
excluded = {t.strip().lower() for t in excluded_raw.split(",") if t.strip()}
doc = json.load(open(terms_path, encoding="utf-8"))
terms = []
for category_terms in doc.get("categories", {}).values():
    terms.extend(category_terms)
text = open(target_path, encoding="utf-8", errors="replace").read().lower()
hits = []
for term in terms:
    lowered = term.lower()
    if lowered in excluded:
        continue
    if re.search(r"\b" + re.escape(lowered) + r"\b", text):
        hits.append(term)
print(",".join(hits))
'@

function Get-ScanHits([string]$TargetPath, [string]$ExcludedCsv) {
    $result = ($ScanScript | & $PythonExe - $TargetPath $ProviderTerms $ExcludedCsv | Out-String).Trim()
    return $result
}

foreach ($target in @(
        (Join-Path $RepoRoot 'contracts/facet-manifest.schema.json'),
        (Join-Path $RepoRoot 'contracts/capability-summary.schema.json'),
        (Join-Path $RepoRoot 'contracts/context-projection.schema.json')
    )) {
    if (Test-Path -LiteralPath $target) {
        $hits = Get-ScanHits $target ''
        if ([string]::IsNullOrEmpty($hits)) {
            Ok "TEST-043: $(Split-Path $target -Leaf) contains no provider-neutrality-allowlist term"
        } else {
            Fail "TEST-043: $(Split-Path $target -Leaf) contains provider-neutrality-allowlist term(s): $hits"
        }
    } else {
        Fail "TEST-043: scan target missing: $target"
    }
}

# "lambda" excluded from the SOURCE scan only: all four scripts share the
# `sorted(diags, key=lambda d: (d.check_id, d.pointer))` idiom -- Python's
# own reserved keyword, spelled identically to, but semantically unrelated
# to, the AWS Lambda product name (see the bash twin's own comment).
foreach ($target in @(
        (Join-Path $Scripts 'validate-facet-manifest.py'),
        (Join-Path $Scripts 'validate-capability-summary.py'),
        (Join-Path $Scripts 'validate-context-projection.py'),
        (Join-Path $Scripts 'compare-facet-manifest-staleness.py')
    )) {
    if (Test-Path -LiteralPath $target) {
        $hits = Get-ScanHits $target 'lambda'
        if ([string]::IsNullOrEmpty($hits)) {
            Ok "TEST-043: $(Split-Path $target -Leaf) contains no provider-neutrality-allowlist term (Python's own 'lambda' keyword excluded)"
        } else {
            Fail "TEST-043: $(Split-Path $target -Leaf) contains provider-neutrality-allowlist term(s): $hits"
        }
    } else {
        Fail "TEST-043: scan target missing: $target"
    }
}

$DirtyHits = Get-ScanHits (Join-Path $FixturesParity 'provider-neutrality-dirty.txt') ''
if (-not [string]::IsNullOrEmpty($DirtyHits)) {
    Ok "TEST-043 non-vacuity canary: the dirty fixture is correctly flagged ($DirtyHits)"
} else {
    Fail 'TEST-043 non-vacuity canary: the dirty fixture (deliberately containing a provider term) was NOT flagged -- the scan is vacuous'
}

$CleanHits = Get-ScanHits (Join-Path $FixturesParity 'provider-neutrality-clean.txt') ''
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
