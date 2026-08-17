# T-009 (epic-189-a1-project-context, REQ-007): acceptance checks for the
# STAGED guard-invariants registration batch under
# specs/epic-189-a1-project-context/human-copy/.
#
# PowerShell parity port of tests/guard-invariants-epic-a1.tests.sh. See
# that file's header for the full TEST-021/TEST-021-MUT/TEST-022/TEST-038/
# TEST-HARDEN <-> AC mapping.
#
# Deliberate implementation DIVERGENCE from the .sh twin (a variant axis,
# not duplication): where the .sh suite reads the staged generator's
# EPIC_A1_TARGETS / PHASE2_TARGETS / BASELINE_SUFFIXES by IMPORTING the
# module and reading the live objects, this suite reads the same constants
# by PARSING the module SOURCE textually. A defect that survives one
# reading (for example a constant assembled at import time that does not
# match the literal a reviewer sees, or a literal a reviewer sees that is
# shadowed by a later assignment) is caught by the other. The manifest,
# JSON, MANIFEST.sha256 and Markdown parsing below are likewise native
# PowerShell rather than a call into the .sh suite's helpers.
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Work = Join-Path ([IO.Path]::GetTempPath()) ("guard-invariants-epic-a1-test-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null

try {

$Stage = Join-Path $Root 'specs/epic-189-a1-project-context/human-copy'
$ManifestMd = Join-Path $Stage 'PROTECTED-MANIFEST.md'
$ManifestSha = Join-Path $Stage 'MANIFEST.sha256'
$LoopRel = 'plugins/sdd-quality-loop'
$StagedLoop = Join-Path $Stage $LoopRel
$StagedJson = Join-Path $StagedLoop 'references/guard-invariants.json'
$StagedGen = Join-Path $StagedLoop 'scripts/generate-guard-invariants.py'
$StagedGenDir = Join-Path $StagedLoop 'scripts/generated'
$LiveLoop = Join-Path $Root $LoopRel
$LiveJson = Join-Path $LiveLoop 'references/guard-invariants.json'
$LiveGen = Join-Path $LiveLoop 'scripts/generate-guard-invariants.py'
$LiveGenDir = Join-Path $LiveLoop 'scripts/generated'

# The six LIVE files' digests as recorded BEFORE T-009's agent commit
# (implementation report T-009.md, "Live-file baseline"). See TEST-022.
$PreApply = @{
    'guard-invariants.json'              = 'fde0a57e33fb6b1a21e11af120cbf946e14ce53d0313d77c14e22538dfd422ad'
    'generate-guard-invariants.py'       = '827d154754599f6231445fad6056c17700bb371e72f01346b56d0147ce4facc7'
    'guard_invariants.py'                = '121818ba4c6d60c4abb081a652ef5b7e22c1fae8ee2d1efefa50fddddde115ad'
    'guard-invariants.generated.js'      = '16c05a8c56cd2b1befd33c8ac405916123da551876e5de56b6f4b1989d82a1d6'
    'guard-invariants.generated.ps1'     = '52de1d386b94787898dc02dc47c1bbb25ecc57f1d713b8a9ea417e61c7281b1b'
    'guard-invariants.generated.sh'      = '30eaddedbc5837d0684f13fdedd67aab66a2e0f471d35fd376196727ac17ca88'
}

$script:PassCount = 0
$script:FailCount = 0
function Test-Pass([string]$Label) { $script:PassCount++; Write-Output "PASS: $Label" }
function Test-Fail([string]$Label, [string]$Detail = '') { $script:FailCount++; Write-Output "FAIL: ${Label}: $Detail" }
function Assert-True([bool]$Condition, [string]$Label, [string]$Detail = '') {
    if ($Condition) { Test-Pass $Label } else { Test-Fail $Label $Detail }
}
function Assert-Eq($Actual, $Expected, [string]$Label) {
    if ($Actual -eq $Expected) { Test-Pass $Label } else { Test-Fail $Label "expected [$Expected], got [$Actual]" }
}
function Assert-SeqEq([string[]]$Actual, [string[]]$Expected, [string]$Label) {
    $a = ($Actual -join "`n")
    $e = ($Expected -join "`n")
    if ($a -eq $e) { Test-Pass $Label } else { Test-Fail $Label "sequences differ" }
}
function Get-Sha256([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }

# Keep a human-copy STAGING area free of interpreter by-products; see the
# .sh twin's note.
$env:PYTHONDONTWRITEBYTECODE = '1'

function Get-PythonExe {
    foreach ($name in @('python3', 'python')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $cmd) { return $cmd.Source }
    }
    throw 'no python3/python interpreter available'
}
$Python = Get-PythonExe

# Run a generator with --check as a REAL child process, returning its exit code.
function Invoke-Check([string]$GeneratorPath) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Python
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    [void]$psi.ArgumentList.Add($GeneratorPath)
    [void]$psi.ArgumentList.Add('--check')
    $proc = [System.Diagnostics.Process]::Start($psi)
    [void]$proc.StandardOutput.ReadToEnd()
    $script:LastCheckErr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return $proc.ExitCode
}

# Parse a Python tuple-of-string-literals constant from module SOURCE text.
function Get-PyTupleConstant([string]$SourcePath, [string]$Name) {
    $text = [IO.File]::ReadAllText($SourcePath)
    $pattern = "(?ms)^$([regex]::Escape($Name)) = \($`r?`n(.*?)^\)`r?$"
    $m = [regex]::Match($text, $pattern)
    if (-not $m.Success) { return $null }
    $values = New-Object System.Collections.Generic.List[string]
    foreach ($line in $m.Groups[1].Value -split "`r?`n") {
        $lm = [regex]::Match($line, '^\s*"([^"]+)",\s*$')
        if ($lm.Success) { $values.Add($lm.Groups[1].Value) }
    }
    return , $values.ToArray()
}

# ---------------------------------------------------------------------------
# Canonical source: parse PROTECTED-MANIFEST.md
# ---------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $ManifestMd -PathType Leaf)) {
    Test-Fail 'manifest: PROTECTED-MANIFEST.md exists'
    Write-Output "PASS: $script:PassCount"
    Write-Output "FAIL: $script:FailCount"
    exit 1
}
Test-Pass 'manifest: PROTECTED-MANIFEST.md exists'

$mdLines = [IO.File]::ReadAllLines($ManifestMd)
$loose = @($mdLines | Where-Object { $_ -match '^\| [0-9][0-9] \| ' })
$strictRe = '^\| ([0-9][0-9]) \| ([^|]+) \| ([^|]+) \| `([^`|]+)` \| (concrete|reserved) \|$'
$rows = New-Object System.Collections.Generic.List[psobject]
foreach ($line in $loose) {
    $m = [regex]::Match($line, $strictRe)
    if ($m.Success) {
        $rows.Add([pscustomobject]@{
            Nn     = $m.Groups[1].Value
            Adr    = $m.Groups[3].Value.Trim()
            Path   = $m.Groups[4].Value
            Status = $m.Groups[5].Value
        })
    }
}
Assert-Eq $rows.Count $loose.Count 'manifest: every inventory-shaped row satisfies the normative grammar'

$paths = @($rows | ForEach-Object { $_.Path })
$statuses = @($rows | ForEach-Object { $_.Status })
$adrs = @($rows | ForEach-Object { $_.Adr })

Assert-Eq $rows.Count 28 'manifest: total entry count is 28 (design.md Protected-File Statement)'
Assert-Eq (@($statuses | Where-Object { $_ -eq 'concrete' }).Count) 24 'manifest: concrete entry count is 24'
Assert-Eq (@($statuses | Where-Object { $_ -eq 'reserved' }).Count) 4 'manifest: reserved entry count is 4'
Assert-Eq (@($paths | Sort-Object -Unique).Count) $paths.Count 'manifest: no duplicate paths'
Assert-SeqEq @($rows | ForEach-Object { $_.Nn }) @(1..28 | ForEach-Object { '{0:D2}' -f $_ }) 'manifest: ordinals are contiguous and ascending 01..28'

$badPaths = @($paths | Where-Object {
    $_.StartsWith('/') -or $_.Contains('\') -or (@($_ -split '/') | Where-Object { $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' }).Count -gt 0
})
Assert-Eq $badPaths.Count 0 'manifest: every path is a valid repository-relative path'

foreach ($pair in @(@('concrete', 24), @('reserved', 4), @('total', 28))) {
    $want = "| $($pair[0]) | $($pair[1]) |"
    Assert-True (@($mdLines | Where-Object { $_ -eq $want }).Count -eq 1) "manifest: prose Counts table states $($pair[0])=$($pair[1]), matching the rows"
}

# ---------------------------------------------------------------------------
# TEST-038: reservation inventory and ADR-0019 item 3 category coverage
# ---------------------------------------------------------------------------

foreach ($slug in @('canonicalizer', 'hash-generator', 'approval-validator', 'policy-weakening-detector', 'resolver', 'generated-projection')) {
    Assert-True ($adrs -contains $slug) "TEST-038: ADR-0019 item 3 category represented: $slug"
}
Assert-Eq (@($adrs | Where-Object { $_ -ne 'beyond-item-3' }).Count) 20 'TEST-038: 20 entries fall under an ADR-0019 item 3 category'
Assert-Eq (@($adrs | Where-Object { $_ -eq 'beyond-item-3' }).Count) 8 'TEST-038: 8 entries are deliberate beyond-item-3 extensions (6 data + 2 publisher)'

$resolverRows = @($rows | Where-Object { $_.Adr -eq 'resolver' } | ForEach-Object { "$($_.Path)`t$($_.Status)" })
Assert-SeqEq $resolverRows @(
    "plugins/sdd-quality-loop/scripts/resolve-project-context.py`treserved",
    "plugins/sdd-quality-loop/scripts/resolve-project-context.sh`treserved",
    "plugins/sdd-quality-loop/scripts/resolve-project-context.ps1`treserved"
) 'TEST-038: resolver reservation is exactly the three resolve-project-context paths'

$projectionRows = @($rows | Where-Object { $_.Adr -eq 'generated-projection' } | ForEach-Object { "$($_.Path)`t$($_.Status)" })
Assert-SeqEq $projectionRows @(
    "plugins/sdd-quality-loop/scripts/generated/project-context.resolved.json`treserved"
) 'TEST-038: generated-projection reservation is exactly the resolved-projection path'

foreach ($p in @(
    'plugins/sdd-quality-loop/scripts/apply-human-copy.sh',
    'plugins/sdd-quality-loop/scripts/apply-human-copy.ps1',
    'sdd/.approved-context/project-context.approved.yaml',
    'sdd/.approved-context/provider-bindings.approved.yaml')) {
    $row = @($rows | Where-Object { $_.Path -eq $p })
    Assert-True (($row.Count -eq 1) -and ($row[0].Status -eq 'concrete')) "TEST-038: $p is a concrete entry"
}

# ---------------------------------------------------------------------------
# TEST-021: staged candidates re-derived from the manifest
# ---------------------------------------------------------------------------

foreach ($f in @($StagedJson, $StagedGen)) {
    Assert-True (Test-Path -LiteralPath $f -PathType Leaf) "staged: candidate exists: $(Split-Path -Leaf $f)"
}
$generatedNames = @('guard_invariants.py', 'guard-invariants.generated.js', 'guard-invariants.generated.ps1', 'guard-invariants.generated.sh')
foreach ($o in $generatedNames) {
    Assert-True (Test-Path -LiteralPath (Join-Path $StagedGenDir $o) -PathType Leaf) "staged: generated output exists: $o"
}

if (-not (Test-Path -LiteralPath $StagedJson -PathType Leaf) -or -not (Test-Path -LiteralPath $StagedGen -PathType Leaf)) {
    Write-Output "PASS: $script:PassCount"
    Write-Output "FAIL: $script:FailCount"
    exit 1
}

$stagedData = Get-Content -Raw -LiteralPath $StagedJson | ConvertFrom-Json
$liveData = Get-Content -Raw -LiteralPath $LiveJson | ConvertFrom-Json

Assert-SeqEq @($stagedData.epic_a1_targets) $paths 'TEST-021: staged JSON epic_a1_targets equals the manifest exactly (ordered)'
# Two allowed states, mirroring TEST-022: BEFORE the human apply the staged
# list is the live list plus the 28 manifest paths; AFTER it, the live list
# IS the staged list. Anything else fails closed. A one-sided "live + 28"
# assertion is correct only until the batch is legitimately applied.
$stagedProtected = @($stagedData.protected_gate_suffixes)
$liveProtected = @($liveData.protected_gate_suffixes)
$stagedJoined = $stagedProtected -join "`n"
if ($stagedJoined -eq (($liveProtected + $paths) -join "`n")) {
    Test-Pass 'TEST-021: staged protected_gate_suffixes is the live list plus the 28 manifest paths (pre-apply)'
} elseif ($stagedJoined -eq ($liveProtected -join "`n")) {
    Test-Pass 'TEST-021: staged protected_gate_suffixes equals the live list (human apply landed)'
} else {
    Test-Fail 'TEST-021: staged protected_gate_suffixes is neither live-plus-manifest nor live itself' 'sequences differ'
}

# Apply-state INDEPENDENT, and the stronger of the two.
Assert-SeqEq @($stagedProtected[($stagedProtected.Count - 28)..($stagedProtected.Count - 1)]) $paths 'TEST-021: the staged protected_gate_suffixes tail is exactly the 28 manifest paths, in manifest order'
Assert-Eq (@($stagedProtected | Where-Object { $paths -contains $_ }).Count) 28 'TEST-021: each manifest path occurs exactly once in staged protected_gate_suffixes'

Assert-Eq (@($stagedData.protected_gate_suffixes | Sort-Object -Unique).Count) (@($stagedData.protected_gate_suffixes).Count) 'TEST-021: staged protected_gate_suffixes has no duplicates'

$stagedEpicConst = Get-PyTupleConstant $StagedGen 'EPIC_A1_TARGETS'
Assert-True ($null -ne $stagedEpicConst) 'TEST-021: staged generator declares an EPIC_A1_TARGETS tuple'
if ($null -ne $stagedEpicConst) {
    Assert-SeqEq $stagedEpicConst $paths 'TEST-021: staged generator EPIC_A1_TARGETS equals the manifest exactly (ordered)'
}

foreach ($name in @('PHASE2_TARGETS', 'BASELINE_SUFFIXES')) {
    $liveConst = Get-PyTupleConstant $LiveGen $name
    $stagedConst = Get-PyTupleConstant $StagedGen $name
    Assert-True ($null -ne $liveConst -and $null -ne $stagedConst) "TEST-021: $name is parseable in both live and staged generators"
    if ($null -ne $liveConst -and $null -ne $stagedConst) {
        Assert-SeqEq $stagedConst $liveConst "TEST-021: frozen constant untouched in the staged generator: $name"
    }
}

# REQUIRED_TOP_LEVEL: parsed as a set literal from source.
function Get-PySetConstant([string]$SourcePath, [string]$Name) {
    $text = [IO.File]::ReadAllText($SourcePath)
    $m = [regex]::Match($text, "(?ms)^$([regex]::Escape($Name)) = \{`r?`n(.*?)^\}`r?$")
    if (-not $m.Success) { return $null }
    $values = New-Object System.Collections.Generic.List[string]
    foreach ($line in $m.Groups[1].Value -split "`r?`n") {
        $lm = [regex]::Match($line, '^\s*"([^"]+)",\s*$')
        if ($lm.Success) { $values.Add($lm.Groups[1].Value) }
    }
    return , $values.ToArray()
}
$liveTop = Get-PySetConstant $LiveGen 'REQUIRED_TOP_LEVEL'
$stagedTop = Get-PySetConstant $StagedGen 'REQUIRED_TOP_LEVEL'
Assert-True ($null -ne $liveTop -and $null -ne $stagedTop) 'TEST-021: REQUIRED_TOP_LEVEL is parseable in both generators'
if ($null -ne $liveTop -and $null -ne $stagedTop) {
    $added = @($stagedTop | Where-Object { $liveTop -notcontains $_ })
    $removed = @($liveTop | Where-Object { $stagedTop -notcontains $_ })
    # Apply-state independent: the staged generator always requires the key.
    Assert-True ($stagedTop -contains 'epic_a1_targets') 'TEST-021: staged REQUIRED_TOP_LEVEL requires epic_a1_targets'
    # Two allowed states: pre-apply the staged generator adds the key relative
    # to live; post-apply live already has it, so the delta is legitimately
    # empty.
    if (($added.Count -eq 1) -and ($added[0] -eq 'epic_a1_targets')) {
        Test-Pass 'TEST-021: staged REQUIRED_TOP_LEVEL adds exactly epic_a1_targets (pre-apply)'
    } elseif ($added.Count -eq 0) {
        Test-Pass 'TEST-021: staged REQUIRED_TOP_LEVEL matches live, which already requires it (human apply landed)'
    } else {
        Test-Fail 'TEST-021: staged REQUIRED_TOP_LEVEL adds an unexpected key set' ($added -join ',')
    }
    Assert-Eq $removed.Count 0 'TEST-021: staged REQUIRED_TOP_LEVEL removes no existing key'

    $jsonKeys = @($stagedData.PSObject.Properties.Name | Sort-Object)
    Assert-SeqEq $jsonKeys @($stagedTop | Sort-Object) 'TEST-021: staged JSON top-level key set equals the staged generator''s REQUIRED_TOP_LEVEL'
}

# Design decision: no fifth generated-file consumer for EPIC_A1_TARGETS.
$leak = @($generatedNames | Where-Object {
    $p = Join-Path $StagedGenDir $_
    (Test-Path -LiteralPath $p -PathType Leaf) -and ([IO.File]::ReadAllText($p).Contains('EPIC_A1'))
})
Assert-Eq $leak.Count 0 'TEST-021: no EPIC_A1 projection is emitted into the generated outputs (design decision)'

foreach ($o in @('guard_invariants.py', 'guard-invariants.generated.js', 'guard-invariants.generated.ps1')) {
    $p = Join-Path $StagedGenDir $o
    if (Test-Path -LiteralPath $p -PathType Leaf) {
        $text = [IO.File]::ReadAllText($p)
        $missing = @($paths | Where-Object { -not $text.Contains($_) })
        Assert-Eq $missing.Count 0 "TEST-021: all 28 manifest paths are projected into $o"
    } else {
        Test-Fail "TEST-021: all 28 manifest paths are projected into $o" 'output missing'
    }
}

# ---------------------------------------------------------------------------
# TEST-021: staged-tree --check
# ---------------------------------------------------------------------------

Assert-Eq (Invoke-Check $StagedGen) 0 'TEST-021: staged-tree generate-guard-invariants.py --check passes'

$anchored = (Resolve-Path (Join-Path (Split-Path -Parent (Split-Path -Parent $StagedGen)) 'references/guard-invariants.json')).Path
Assert-Eq $anchored (Resolve-Path $StagedJson).Path 'TEST-021: the staged generator anchors on the STAGED canonical JSON, never the live one'

function New-StageCopy([string]$Name) {
    $dest = Join-Path $Work $Name
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Copy-Item -LiteralPath $StagedLoop -Destination $dest -Recurse -Force
    return (Join-Path $dest 'sdd-quality-loop/scripts/generate-guard-invariants.py')
}

# TEST-021-MUT: detection power, on throwaway copies only.
#
# Each case asserts the PRISTINE copy passes --check BEFORE mutating it.
# Without that baseline the mutation assertion is vacuous whenever the
# staged tree is already broken (exactly the Red state), and a test that
# cannot distinguish "the mutation was detected" from "everything was
# already failing" has no detection power at all.
function Assert-MutBaseline([string]$GeneratorPath, [string]$Case) {
    Assert-Eq (Invoke-Check $GeneratorPath) 0 "TEST-021-MUT: pristine copy passes --check before mutation ($Case)"
}

$mut1Gen = New-StageCopy 'mut1'
Assert-MutBaseline $mut1Gen 'dropped JSON entry'
$mut1Json = Join-Path (Split-Path -Parent (Split-Path -Parent $mut1Gen)) 'references/guard-invariants.json'
$mut1Data = Get-Content -Raw -LiteralPath $mut1Json | ConvertFrom-Json
$trimmed = @($mut1Data.protected_gate_suffixes)
$mut1Data.protected_gate_suffixes = @($trimmed[0..($trimmed.Count - 2)])
[IO.File]::WriteAllText($mut1Json, ($mut1Data | ConvertTo-Json -Depth 10))
Assert-True ((Invoke-Check $mut1Gen) -ne 0) 'TEST-021-MUT: --check rejects a dropped protected_gate_suffixes entry'

$mut2Gen = New-StageCopy 'mut2'
Assert-MutBaseline $mut2Gen 'dropped EPIC_A1_TARGETS entry'
$mut2Text = [IO.File]::ReadAllText($mut2Gen)
$mut2Match = [regex]::Match($mut2Text, "(?ms)^EPIC_A1_TARGETS = \($`r?`n(.*?)^\)`r?$")
if ($mut2Match.Success) {
    $bodyLines = @($mut2Match.Groups[1].Value -split "`r?`n" | Where-Object { $_ -match '^\s*"' })
    $kept = $bodyLines[0..($bodyLines.Count - 2)] -join "`n"
    [IO.File]::WriteAllText($mut2Gen, $mut2Text.Replace($mut2Match.Value, "EPIC_A1_TARGETS = (`n$kept`n)"))
    Assert-True ((Invoke-Check $mut2Gen) -ne 0) 'TEST-021-MUT: --check rejects a dropped EPIC_A1_TARGETS entry'
} else {
    Test-Fail 'TEST-021-MUT: --check rejects a dropped EPIC_A1_TARGETS entry' 'EPIC_A1_TARGETS not parseable'
}

$mut3Gen = New-StageCopy 'mut3'
Assert-MutBaseline $mut3Gen 'stale generated output'
$mut3Out = Join-Path (Split-Path -Parent $mut3Gen) 'generated/guard_invariants.py'
[IO.File]::AppendAllText($mut3Out, "stale`n")
Assert-True ((Invoke-Check $mut3Gen) -ne 0) 'TEST-021-MUT: --check rejects a stale generated output'

# ---------------------------------------------------------------------------
# TEST-022: LIVE files are untouched by this task's agent commit
# ---------------------------------------------------------------------------

function Assert-LiveUnchanged([string]$LivePath, [string]$StagedPath, [string]$BaselineKey, [string]$Label) {
    if (-not (Test-Path -LiteralPath $LivePath -PathType Leaf)) {
        Test-Fail "TEST-022: live $Label present" 'missing'
        return
    }
    $actual = Get-Sha256 $LivePath
    if ($actual -eq $PreApply[$BaselineKey]) {
        Test-Pass "TEST-022: live $Label is at the pre-apply baseline (agent commit changed nothing)"
    } elseif ((Test-Path -LiteralPath $StagedPath -PathType Leaf) -and ($actual -eq (Get-Sha256 $StagedPath))) {
        Test-Pass "TEST-022: live $Label equals this batch's reviewed staged candidate (human apply landed)"
    } else {
        Test-Fail "TEST-022: live $Label is neither the pre-apply baseline nor the staged candidate" "got $actual"
    }
}

Assert-LiveUnchanged $LiveJson $StagedJson 'guard-invariants.json' 'guard-invariants.json'
Assert-LiveUnchanged $LiveGen $StagedGen 'generate-guard-invariants.py' 'generate-guard-invariants.py'
foreach ($o in $generatedNames) {
    Assert-LiveUnchanged (Join-Path $LiveGenDir $o) (Join-Path $StagedGenDir $o) $o "generated/$o"
}

# ---------------------------------------------------------------------------
# TEST-HARDEN: staging integrity
# ---------------------------------------------------------------------------

if (Test-Path -LiteralPath $ManifestSha -PathType Leaf) {
    Test-Pass 'staging: MANIFEST.sha256 exists'
    $shaLines = @([IO.File]::ReadAllLines($ManifestSha) | Where-Object { $_ -ne '' })
    $badLines = @($shaLines | Where-Object { $_ -notmatch '^[0-9a-f]{64}  [^ ].*$' })
    Assert-Eq $badLines.Count 0 'staging: every MANIFEST.sha256 line is <64-lowercase-hex><2 spaces><path>'

    # Class lock (2026-08-11 human ruling, RT-20260811-002): the repo-shared
    # .github/workflows/test.yml snapshot is EVICTED from this bundle. The old
    # "present exactly once" assertion (human ruling, 2026-08-04) protected a
    # per-epic snapshot that QG measured as a deletion hazard: applying the
    # stale copy removed 137 lines / 18 named live CI steps. ABSENCE is
    # asserted - not merely unlisted - so a future re-adding fails here
    # instead of rotting silently. The live workflow is the single source of
    # truth; this bundle registers CI steps only via the live file.
    $wfLine = @($shaLines | Where-Object { $_.EndsWith('  .github/workflows/test.yml') })
    Assert-Eq $wfLine.Count 0 'staging: class lock: no repo-shared .github/workflows/test.yml manifest entry (snapshot evicted 2026-08-11)'
    if (-not (Test-Path -LiteralPath (Join-Path $Stage '.github/workflows/test.yml'))) {
        Test-Pass 'staging: class lock: no staged .github/workflows/test.yml snapshot file'
    } else {
        Test-Fail 'staging: class lock: no staged .github/workflows/test.yml snapshot file' 'staged snapshot present'
    }

    $missing = 0
    $mismatched = 0
    foreach ($line in $shaLines) {
        $digest = $line.Substring(0, 64)
        $target = $line.Substring(66)
        $stagedPath = Join-Path $Stage $target
        if (-not (Test-Path -LiteralPath $stagedPath -PathType Leaf)) { $missing++; continue }
        if ((Get-Sha256 $stagedPath) -ne $digest) { $mismatched++ }
    }
    Assert-Eq $missing 0 'staging: every MANIFEST.sha256 entry has staged bytes at <stage>/<path>'
    Assert-Eq $mismatched 0 'staging: every MANIFEST.sha256 digest matches its staged bytes'
    # T-009's invariant is that its own eight entries are never DROPPED, not
    # that the manifest is frozen at eight forever: later tasks in this epic
    # legitimately stage further protected targets (T-012 appended the two
    # migrated track-selection consumers). Pinning the total made this suite
    # fail for the wrong reason the moment that happened. Floor plus
    # uniqueness is asserted instead; every individual entry is already
    # validated against its staged bytes above, and each of T-009's own
    # targets is separately pinned by name below -- and so are T-012's own two,
    # added at quality-gate seq0370 remedy time. Without them the
    # floor+uniqueness+by-name combination was proven to ALL-PASS on a manifest
    # with BOTH T-012 entries dropped, i.e. the suite could not tell a correctly
    # appended 10-entry manifest from one that had silently lost the two
    # migrated track-selection consumers. Each task pins its OWN targets by
    # name; the floor stays a floor so the NEXT task's append never breaks this.
    Assert-True ($shaLines.Count -ge 8) `
        "staging: MANIFEST.sha256 has at least T-009's 8 entries (has $($shaLines.Count))" `
        "only $($shaLines.Count) entries"
    $targets = @($shaLines | ForEach-Object { $_.Substring(66) })
    $dupes = @($targets | Group-Object | Where-Object { $_.Count -gt 1 })
    Assert-Eq $dupes.Count 0 'staging: no MANIFEST.sha256 target path is registered twice'

    foreach ($target in @(
        'specs/epic-189-a1-project-context/human-copy/PROTECTED-MANIFEST.md',
        "$LoopRel/references/guard-invariants.json",
        "$LoopRel/scripts/generate-guard-invariants.py",
        "$LoopRel/scripts/generated/guard_invariants.py",
        "$LoopRel/scripts/generated/guard-invariants.generated.js",
        "$LoopRel/scripts/generated/guard-invariants.generated.ps1",
        "$LoopRel/scripts/generated/guard-invariants.generated.sh",
        'plugins/sdd-ship/skills/ship/SKILL.md',
        'plugins/sdd-lite/skills/lite-spec/SKILL.md')) {
        Assert-True (@($shaLines | Where-Object { $_.EndsWith("  $target") }).Count -eq 1) "staging: MANIFEST.sha256 registers $target"
    }
} else {
    Test-Fail 'staging: MANIFEST.sha256 exists' 'missing'
}

$nested = Join-Path $Stage 'specs/epic-189-a1-project-context/human-copy/PROTECTED-MANIFEST.md'
if (Test-Path -LiteralPath $nested -PathType Leaf) {
    Assert-Eq (Get-Sha256 $nested) (Get-Sha256 $ManifestMd) 'staging: the nested staged PROTECTED-MANIFEST.md copy is byte-identical to the canonical one'
} else {
    Test-Fail 'staging: the nested staged PROTECTED-MANIFEST.md copy exists' 'missing'
}

$runAllSh = [IO.File]::ReadAllText((Join-Path $Root 'tests/run-all.sh'))
$runAllPs1 = [IO.File]::ReadAllText((Join-Path $Root 'tests/run-all.ps1'))
Assert-True ($runAllSh.Contains('tests/guard-invariants-epic-a1.tests.sh')) 'self-registration: tests/guard-invariants-epic-a1.tests.sh registered in tests/run-all.sh'
Assert-True ($runAllPs1.Contains('tests/guard-invariants-epic-a1.tests.ps1')) 'self-registration: tests/guard-invariants-epic-a1.tests.ps1 registered in tests/run-all.ps1'
Assert-True (Test-Path -LiteralPath (Join-Path $Root 'tests/guard-invariants-epic-a1.tests.sh') -PathType Leaf) 'self-registration: tests/guard-invariants-epic-a1.tests.sh twin exists'

Write-Output "PASS: $script:PassCount"
Write-Output "FAIL: $script:FailCount"
if ($script:FailCount -gt 0) { exit 1 } else { exit 0 }
}
finally {
    Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}
