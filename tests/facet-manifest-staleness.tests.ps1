# facet-manifest-staleness.tests.ps1 — PowerShell twin of
# facet-manifest-staleness.tests.sh: compare-facet-manifest-staleness.py's
# REQ-004 branch table, REQ-005 version-bump tiers, and the CLI/
# argument-error contract (design.md Test Strategy item 5).
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Comparator = Join-Path $RepoRoot 'plugins/sdd-quality-loop/scripts/compare-facet-manifest-staleness.py'
$Fixtures = Join-Path $RepoRoot 'tests/fixtures/facet-manifest/staleness'

$script:Pass = 0
$script:Fail = 0

function Get-Python {
    $py = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
    if (-not $py) { throw 'facet-manifest-staleness.tests.ps1: no python3/python on PATH' }
    return $py.Path
}
$Python = Get-Python

$StdoutFile = New-TemporaryFile
$StderrFile = New-TemporaryFile

function Invoke-Comparator {
    param([string[]]$CliArgs)
    & $Python $Comparator @CliArgs 1> $StdoutFile.FullName 2> $StderrFile.FullName
    $code = $LASTEXITCODE
    $stdoutText = (Get-Content $StdoutFile.FullName -Raw)
    $stderrText = (Get-Content $StderrFile.FullName -Raw)
    if ($null -eq $stdoutText) { $stdoutText = '' }
    if ($null -eq $stderrText) { $stderrText = '' }
    # Strip the single trailing newline the script itself writes, so a
    # one-line verdict/diagnostic compares equal to its pinned expected
    # string without an extra blank line.
    $stdoutText = $stdoutText -replace "`r?`n$", ''
    $stderrText = $stderrText -replace "`r?`n$", ''
    return @{ Stdout = $stdoutText; Stderr = $stderrText; Code = $code }
}

function Expect-Verdict {
    param(
        [string]$Old, [string]$New, [string]$Status, [string]$Reason, [string]$Name,
        [string[]]$ExtraArgs
    )
    $expectedExit = switch ($Status) {
        'fresh'   { 0 }
        'stale'   { 1 }
        'blocked' { 2 }
        default   { -1 }
    }
    $cliArgs = @('--old-manifest', (Join-Path $Fixtures $Old), '--new-manifest', (Join-Path $Fixtures $New)) + $ExtraArgs
    $r = Invoke-Comparator $cliArgs
    $expectedLine = "facet-manifest-staleness: ${Status}:${Reason}"
    if ($r.Code -eq $expectedExit -and $r.Stdout -ceq $expectedLine -and [string]::IsNullOrEmpty($r.Stderr)) {
        Write-Host "ok: $Name`: $Old vs $New -> ${Status}:${Reason} (exit=$expectedExit, stdout pinned, stderr empty)"
        $script:Pass++
    } else {
        Write-Host "FAIL: $Name`: expected exit=$expectedExit stdout=[$expectedLine] stderr=[], got exit=$($r.Code) stdout=[$($r.Stdout)] stderr=[$($r.Stderr)]"
        $script:Fail++
    }
}

function Expect-Error {
    param(
        [string]$Old, [string]$New, [string]$CheckId, [string]$Needle, [string]$Name,
        [string[]]$ExtraArgs
    )
    $cliArgs = @('--old-manifest', (Join-Path $Fixtures $Old), '--new-manifest', (Join-Path $Fixtures $New)) + $ExtraArgs
    $r = Invoke-Comparator $cliArgs
    $expectedSubstring = "facet-manifest-staleness: ${CheckId}: ${Needle}"
    if ($r.Code -eq 3 -and [string]::IsNullOrEmpty($r.Stdout) -and $r.Stderr.Contains($expectedSubstring)) {
        Write-Host "ok: $Name`: exit=3, stdout empty, stderr contains '$expectedSubstring'"
        $script:Pass++
    } else {
        Write-Host "FAIL: $Name`: expected exit=3 stdout=[] stderr containing '$expectedSubstring', got exit=$($r.Code) stdout=[$($r.Stdout)] stderr=[$($r.Stderr)]"
        $script:Fail++
    }
}

function Check-MissingFlag {
    param([string]$Name, [string]$Needle, [string[]]$CliArgs)
    $r = Invoke-Comparator $CliArgs
    if ($r.Code -eq 3 -and [string]::IsNullOrEmpty($r.Stdout) -and $r.Stderr.Contains($Needle)) {
        Write-Host "ok: $Name`: exit=3, stdout empty, stderr contains '$Needle'"
        $script:Pass++
    } else {
        Write-Host "FAIL: $Name`: expected exit=3 stdout=[] stderr containing '$Needle', got exit=$($r.Code) stdout=[$($r.Stdout)] stderr=[$($r.Stderr)]"
        $script:Fail++
    }
}

$DefaultFlags = @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'none')

# =============================================================================
# REQ-004 branch table (TEST-019..024, TEST-039, TEST-040)
# =============================================================================

Expect-Verdict 'base-old.json' 'registry-digest-only-new.json' 'fresh' 'metadata-only-refresh' `
  'TEST-019 digest-only-change not-stale lock' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'none')

Expect-Verdict 'base-old.json' 'gate-blocking-change-new.json' 'stale' 'semantic-output-changed' `
  'TEST-020 same-gate-ID attribute-change stale lock' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'none')

Expect-Verdict 'base-old.json' 'evidence-change-new.json' 'stale' 'semantic-output-changed' `
  'TEST-021 evidence-inclusion lock (reversed)' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'none')

Expect-Verdict 'minimum-enforcement-old.json' 'minimum-enforcement-new.json' 'stale' 'semantic-output-changed' `
  'TEST-022 minimum-enforcement-tightening lock' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'none')

Expect-Verdict 'base-old.json' 'projection-digest-only-new.json' 'blocked' 'policy-weakening-blocked:projection' `
  'TEST-023 Policy-Weakening short-circuit lock' `
  @('--projection-weakening', 'weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'none')

Expect-Verdict 'base-old.json' 'registry-digest-only-new.json' 'blocked' 'weakening-verdict-indeterminate:registry' `
  'TEST-024(1) fail-closed lock (indeterminate)' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'indeterminate', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'none')
Expect-Verdict 'base-old.json' 'registry-digest-only-new.json' 'fresh' 'metadata-only-refresh' `
  'TEST-024(2) forward-compatibility sub-case (not-weakened)' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'none')

Expect-Verdict 'base-old.json' 'no-axis-change-semantic-differs-new.json' 'fresh' 'unchanged' `
  'TEST-039 unchanged-digests WARN-only lock' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'none')

Expect-Verdict 'base-old.json' 'ownership-digest-only-new.json' 'fresh' 'metadata-only-refresh' `
  'TEST-040(1) ownership-axis not-weakened -> not stale' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'none')
Expect-Verdict 'base-old.json' 'ownership-digest-only-new.json' 'blocked' 'weakening-verdict-indeterminate:ownership' `
  'TEST-040(2) ownership-axis indeterminate -> Block' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'indeterminate', '--resolver-version-bump', 'none')

Expect-Verdict 'base-old.json' 'multi-axis-mixed-verdict-new.json' 'blocked' 'policy-weakening-blocked:ownership' `
  'branch-1 all-changed-axes lock (registry not-weakened, ownership weakened)' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'weakened', '--resolver-version-bump', 'none')
Expect-Verdict 'base-old.json' 'multi-axis-mixed-verdict-new.json' 'blocked' 'weakening-verdict-indeterminate:registry' `
  'branch-1 fixed-axis-order precedence lock (registry indeterminate wins over ownership weakened)' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'indeterminate', '--ownership-weakening', 'weakened', '--resolver-version-bump', 'none')

# =============================================================================
# REQ-005 version-bump tiers (TEST-025..027, TEST-045)
# =============================================================================

Expect-Verdict 'base-old.json' 'patch-bump-new.json' 'fresh' 'unchanged' `
  'TEST-025 patch-tier no-op lock' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'patch')

Expect-Verdict 'base-old.json' 'minor-bump-changed-new.json' 'stale' 'semantic-output-changed' `
  'TEST-026(1) minor-tier impact assessment, semantic output changed' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'minor')
Expect-Verdict 'base-old.json' 'minor-bump-unchanged-new.json' 'fresh' 'metadata-only-refresh' `
  'TEST-026(2) minor-tier impact assessment, semantic output unchanged' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'minor')

Expect-Verdict 'base-old.json' 'major-bump-new.json' 'stale' 'major-version-forced' `
  'TEST-027(1) major-tier forced-regardless lock' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'major')
Expect-Verdict 'base-old.json' 'major-bump-block-new.json' 'blocked' 'policy-weakening-blocked:projection' `
  'TEST-027(2) Block precedence over major-tier forced-stale' `
  @('--projection-weakening', 'weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'major')

Expect-Verdict 'base-old.json' 'minor-bump-changed-new.json' 'stale' 'semantic-output-changed' `
  'TEST-045(1) branch-3 fix: minor bump reaches ordinary comparison' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'minor')
Expect-Verdict 'base-old.json' 'minor-rule-set-bump-changed-new.json' 'stale' 'semantic-output-changed' `
  'TEST-045(2) branch-3 fix parity: minor-rule-set bump reaches ordinary comparison' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'minor-rule-set')

# =============================================================================
# TEST-044: CLI contract
# =============================================================================

Check-MissingFlag 'TEST-044 missing --old-manifest' 'the following arguments are required: --old-manifest' `
  @('--new-manifest', (Join-Path $Fixtures 'registry-digest-only-new.json'), '--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'none')

Check-MissingFlag 'TEST-044 missing --new-manifest' 'the following arguments are required: --new-manifest' `
  @('--old-manifest', (Join-Path $Fixtures 'base-old.json'), '--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'none')

Check-MissingFlag 'TEST-044 missing --projection-weakening' 'the following arguments are required: --projection-weakening' `
  @('--old-manifest', (Join-Path $Fixtures 'base-old.json'), '--new-manifest', (Join-Path $Fixtures 'registry-digest-only-new.json'), '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'none')

Check-MissingFlag 'TEST-044 missing --registry-weakening' 'the following arguments are required: --registry-weakening' `
  @('--old-manifest', (Join-Path $Fixtures 'base-old.json'), '--new-manifest', (Join-Path $Fixtures 'registry-digest-only-new.json'), '--projection-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'none')

Check-MissingFlag 'TEST-044 missing --ownership-weakening' 'the following arguments are required: --ownership-weakening' `
  @('--old-manifest', (Join-Path $Fixtures 'base-old.json'), '--new-manifest', (Join-Path $Fixtures 'registry-digest-only-new.json'), '--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--resolver-version-bump', 'none')

Check-MissingFlag 'TEST-044 missing --resolver-version-bump' 'the following arguments are required: --resolver-version-bump' `
  @('--old-manifest', (Join-Path $Fixtures 'base-old.json'), '--new-manifest', (Join-Path $Fixtures 'registry-digest-only-new.json'), '--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened')

Check-MissingFlag 'TEST-044 invalid --projection-weakening enum' "argument --projection-weakening: invalid choice: 'bogus'" `
  @('--old-manifest', (Join-Path $Fixtures 'base-old.json'), '--new-manifest', (Join-Path $Fixtures 'registry-digest-only-new.json'), '--projection-weakening', 'bogus', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'none')

Check-MissingFlag 'TEST-044 invalid --registry-weakening enum' "argument --registry-weakening: invalid choice: 'bogus'" `
  @('--old-manifest', (Join-Path $Fixtures 'base-old.json'), '--new-manifest', (Join-Path $Fixtures 'registry-digest-only-new.json'), '--projection-weakening', 'not-weakened', '--registry-weakening', 'bogus', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'none')

Check-MissingFlag 'TEST-044 invalid --ownership-weakening enum' "argument --ownership-weakening: invalid choice: 'bogus'" `
  @('--old-manifest', (Join-Path $Fixtures 'base-old.json'), '--new-manifest', (Join-Path $Fixtures 'registry-digest-only-new.json'), '--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'bogus', '--resolver-version-bump', 'none')

Check-MissingFlag 'TEST-044 invalid --resolver-version-bump enum' "argument --resolver-version-bump: invalid choice: 'bogus'" `
  @('--old-manifest', (Join-Path $Fixtures 'base-old.json'), '--new-manifest', (Join-Path $Fixtures 'registry-digest-only-new.json'), '--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'bogus')

Expect-Error 'schema-invalid-manifest.json' 'registry-digest-only-new.json' 'schema-invalid' "/old-manifest/schema: missing required property 'schema'" `
  'TEST-044 schema-invalid --old-manifest' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'none')
Expect-Error 'base-old.json' 'schema-invalid-manifest.json' 'schema-invalid' "/new-manifest/schema: missing required property 'schema'" `
  'TEST-044 schema-invalid --new-manifest' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'none')

Write-Host 'ok: TEST-044 exit-0 mapping: proven by TEST-019 above (fresh -> exit 0)'; $script:Pass++
Write-Host 'ok: TEST-044 exit-1 mapping: proven by TEST-020 above (stale -> exit 1)'; $script:Pass++
Write-Host 'ok: TEST-044 exit-2 mapping: proven by TEST-023 above (blocked -> exit 2)'; $script:Pass++

$missing = Invoke-Comparator (@('--old-manifest', (Join-Path $Fixtures 'does-not-exist.json'), '--new-manifest', (Join-Path $Fixtures 'base-old.json')) + $DefaultFlags)
if ($missing.Code -eq 3 -and $missing.Stderr.Contains('facet-manifest-staleness: manifest-unreadable: old-manifest:')) {
    Write-Host 'ok: manifest-unreadable: nonexistent --old-manifest path fails closed (exit=3, diagnostic on stderr)'; $script:Pass++
} else {
    Write-Host "FAIL: manifest-unreadable: expected exit=3 with diagnostic, got exit=$($missing.Code) stderr=[$($missing.Stderr)]"; $script:Fail++
}

$nonutf8 = Invoke-Comparator (@('--old-manifest', (Join-Path $Fixtures 'manifest-non-utf8-bytes.bin'), '--new-manifest', (Join-Path $Fixtures 'base-old.json')) + $DefaultFlags)
if ($nonutf8.Code -eq 3 -and $nonutf8.Stderr.Contains('facet-manifest-staleness: manifest-unreadable: old-manifest:') -and -not $nonutf8.Stderr.Contains('Traceback')) {
    Write-Host 'ok: manifest-unreadable: non-UTF-8 byte input fails closed (exit=3, diagnostic present, no traceback)'; $script:Pass++
} else {
    Write-Host "FAIL: manifest-unreadable: non-UTF-8 byte input expected exit=3, diagnostic, no traceback, got exit=$($nonutf8.Code) stderr=[$($nonutf8.Stderr)]"; $script:Fail++
}

# =============================================================================
# TEST-046: --resolver-version-bump / actual-manifest-diff consistency
# =============================================================================

Expect-Error 'base-old.json' 'minor-bump-changed-new.json' 'resolver-version-bump-inconsistent' `
  "declared 'patch' but the two manifests' own resolver block actually differs at tier 'minor'" `
  'TEST-046 patch declared against an actual minor diff' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'patch')

Expect-Error 'base-old.json' 'minor-rule-set-bump-changed-new.json' 'resolver-version-bump-inconsistent' `
  "declared 'minor' but the two manifests' own resolver block actually differs at tier 'minor-rule-set'" `
  'TEST-046 minor declared against an actual minor-rule-set diff (version unchanged)' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'minor')

Expect-Error 'base-old.json' 'minor-bump-changed-new.json' 'resolver-version-bump-inconsistent' `
  "declared 'minor-rule-set' but the two manifests' own resolver block actually differs at tier 'minor'" `
  'TEST-046 minor-rule-set declared against an actual resolver.version change' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'minor-rule-set')

Expect-Error 'base-old.json' 'registry-digest-only-new.json' 'resolver-version-bump-inconsistent' `
  "declared 'minor-rule-set' but the two manifests' own resolver block actually differs at tier 'none'" `
  'TEST-046 minor-rule-set declared against an unchanged rule_set_revision' `
  @('--projection-weakening', 'not-weakened', '--registry-weakening', 'not-weakened', '--ownership-weakening', 'not-weakened', '--resolver-version-bump', 'minor-rule-set')

Write-Host "ok: TEST-046 positive 'none': proven by TEST-019 above (declared none, actual none, proceeds)"; $script:Pass++
Write-Host "ok: TEST-046 positive 'patch': proven by TEST-025 above (declared patch, actual patch, proceeds)"; $script:Pass++
Write-Host "ok: TEST-046 positive 'minor': proven by TEST-026(1) above (declared minor, actual minor, proceeds)"; $script:Pass++
Write-Host "ok: TEST-046 positive 'minor-rule-set': proven by TEST-045(2) above (declared minor-rule-set, actual minor-rule-set, proceeds)"; $script:Pass++
Write-Host "ok: TEST-046 positive 'major': proven by TEST-027(1) above (declared major, actual major, proceeds)"; $script:Pass++

# =============================================================================
# Suite/CI registration self-check
# =============================================================================
$runAll = Get-Content (Join-Path $RepoRoot 'tests/run-all.ps1') -Raw
if ($runAll.Contains('tests/facet-manifest-staleness.tests.ps1')) {
    Write-Host 'ok: self-registration: tests/run-all.ps1 lists this suite'; $script:Pass++
} else {
    Write-Host 'FAIL: self-registration: tests/run-all.ps1 does not list tests/facet-manifest-staleness.tests.ps1'; $script:Fail++
}

Remove-Item -Force $StdoutFile.FullName, $StderrFile.FullName -ErrorAction SilentlyContinue

Write-Host ''
Write-Host "facet-manifest-staleness: $($script:Pass) passed, $($script:Fail) failed"
if ($script:Fail -ne 0) { exit 1 }
exit 0
