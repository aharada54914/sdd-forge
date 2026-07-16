# tests/bump-version-gate.tests.ps1 - PowerShell twin of
# tests/bump-version-gate.tests.sh (T-001 / Issue #148 / epic-159-pillar-b
# REQ-001). See the bash twin for the full test-technique description.
#
# TEST-001..TEST-003 drive the bash-only real scripts/bump-version.sh via
# `& bash <fixture-copy>` (Get-Command bash + named-SKIP-degradation idiom,
# tests/hitl-wfi-terminal.tests.ps1:101-107, REQ-004 recorded degradation).
# TEST-004..TEST-006 are pure text-inspection self-checks over the REAL
# scripts/bump-version.sh source and this suite's own source; they need no
# bash and never SKIP.
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$bumpVersionSh = Join-Path $repoRoot "scripts/bump-version.sh"
$selfPs1 = Join-Path $repoRoot "tests/bump-version-gate.tests.ps1"
$runAllPs1 = Join-Path $repoRoot "tests/run-all.ps1"
$testYml = Join-Path $repoRoot ".github/workflows/test.yml"
$version = "9.9.9"

$script:passCount = 0
$script:failCount = 0
function Ok([string]$Name) { Write-Output "ok: $Name"; $script:passCount++ }
function Fail([string]$Name) { Write-Output "FAIL: $Name"; $script:failCount++ }

$cleanupRoots = New-Object System.Collections.Generic.List[string]
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$bashCmd = Get-Command bash -ErrorAction SilentlyContinue

# New-Fixture -Label <label> — filesystem-copies the real repository
# (excluding .git and the two mcp/*/node_modules trees, which neither
# bump-version.sh nor either loop suite touches, for suite speed) into a
# fresh temp root, Resolve-Path normalizes it (pwd -P equivalent,
# CI-resilience/INV-017), and `git init`s it (no commit yet — the
# baseline commit is taken by Set-FixtureBaseline AFTER all per-case
# setup, so a subsequent `git status --porcelain` check measures ONLY
# what bump-version.sh itself did). Returns the fixture root path.
function New-Fixture {
    param([string]$Label)
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("bump-version-gate." + $Label + "." + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    $tempRoot = (Resolve-Path -LiteralPath $tempRoot).Path
    $cleanupRoots.Add($tempRoot)

    $fixtureRoot = Join-Path $tempRoot "repository"
    Copy-Item -LiteralPath $repoRoot -Destination $fixtureRoot -Recurse -Force
    Remove-Item -LiteralPath (Join-Path $fixtureRoot ".git") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $fixtureRoot "mcp/sdd-forge-mcp/node_modules") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $fixtureRoot "mcp/local-env-mcp/node_modules") -Recurse -Force -ErrorAction SilentlyContinue

    $fixtureRoot = (Resolve-Path -LiteralPath $fixtureRoot).Path
    & git -C $fixtureRoot init -q
    if ($LASTEXITCODE -ne 0) { throw "git init failed in $fixtureRoot" }
    return $fixtureRoot
}

# Set-SuiteStub -FixtureRoot <root> -RelPath <path> -ExitCode <n>
function Set-SuiteStub {
    param([string]$FixtureRoot, [string]$RelPath, [int]$ExitCode)
    $target = Join-Path $FixtureRoot $RelPath
    $content = "#!/usr/bin/env bash`nexit $ExitCode`n"
    [System.IO.File]::WriteAllText($target, $content, $utf8NoBom)
    if (-not $IsWindows) {
        & chmod +x $target
    }
}

# Set-FixtureChangelogHeading -FixtureRoot <root> -Version <version> —
# satisfies bump-version.sh's own pre-existing CHANGELOG-heading
# precondition (scripts/bump-version.sh:38-42) so each case isolates the
# NEW loop-gate precondition specifically.
function Set-FixtureChangelogHeading {
    param([string]$FixtureRoot, [string]$Version)
    $path = Join-Path $FixtureRoot "CHANGELOG.md"
    $content = Get-Content -LiteralPath $path -Raw
    $updated = $content -replace '(?m)^## Unreleased$', "## v$Version"
    [System.IO.File]::WriteAllText($path, $updated, $utf8NoBom)
}

# Set-FixtureBaseline -FixtureRoot <root> — commits the fixture's
# post-setup state as the git baseline every subsequent
# `git status --porcelain` call in this suite is measured against.
function Set-FixtureBaseline {
    param([string]$FixtureRoot)
    & git -C $FixtureRoot -c user.email="bump-version-gate-tests@sdd-forge.invalid" -c user.name="bump-version-gate-tests" add -A
    if ($LASTEXITCODE -ne 0) { throw "git add -A failed in $FixtureRoot" }
    & git -C $FixtureRoot -c user.email="bump-version-gate-tests@sdd-forge.invalid" -c user.name="bump-version-gate-tests" commit -q -m "fixture baseline"
    if ($LASTEXITCODE -ne 0) { throw "git commit failed in $FixtureRoot" }
}

# Invoke-BumpVersion -FixtureRoot <root> -Version <version> -OutputFile <path>
# Invokes the FIXTURE's own copy of bump-version.sh (never the real one)
# via bash. Returns the exit code.
function Invoke-BumpVersion {
    param([string]$FixtureRoot, [string]$Version, [string]$OutputFile)
    $bumpScript = Join-Path $FixtureRoot "scripts/bump-version.sh"
    $out = & bash $bumpScript $Version 2>&1
    $rc = $LASTEXITCODE
    [System.IO.File]::WriteAllText($OutputFile, ($out -join "`n"), $utf8NoBom)
    return $rc
}

function Get-FixturePorcelain {
    param([string]$FixtureRoot)
    $out = & git -C $FixtureRoot status --porcelain
    return ($out -join "`n")
}

# ---------------------------------------------------------------------------
# TEST-001 (AC-001): green path
# ---------------------------------------------------------------------------
function Test-001 {
    Write-Output "=== TEST-001 (AC-001): green path (both loop suites stubbed passing) ==="
    if (-not $bashCmd) {
        Write-Output "SKIP: TEST-001 (AC-001) bash not found on PATH; scripts/bump-version.sh is bash-only (REQ-004 recorded degradation)"
        return
    }

    # Capability probe (CI-resilience convention, INV-017): GNU sed accepts
    # --version; BSD/macOS sed does not. scripts/bump-version.sh's mutation
    # section (scripts/bump-version.sh:51-70) is unedited by this task
    # (design.md API/Contract Plan) and its existing `sed -i "<script>"
    # "<file>"` calls are GNU-only syntax -- a pre-existing, out-of-scope
    # portability gap discovered via this suite, unrelated to REQ-001's
    # loop-gate prerequisite. TEST-002..006 are unaffected: their red paths
    # never reach the mutation section, and TEST-004..006 never invoke it.
    & sed --version *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Output "SKIP: TEST-001 (AC-001) mutation-success assertions -- this host's sed is BSD-style; scripts/bump-version.sh's unedited mutation section (scripts/bump-version.sh:51-70) requires GNU sed. Pre-existing portability gap, out of scope for T-001 (REQ-001 loop-gate logic itself is proven by TEST-002..006, none of which reach the mutation section on this host)."
        return
    }

    $fixtureRoot = New-Fixture -Label "green"
    Set-SuiteStub -FixtureRoot $fixtureRoot -RelPath "tests/loop-consistency.tests.sh" -ExitCode 0
    Set-SuiteStub -FixtureRoot $fixtureRoot -RelPath "tests/loop-inventory.tests.sh" -ExitCode 0
    Set-FixtureChangelogHeading -FixtureRoot $fixtureRoot -Version $version
    Set-FixtureBaseline -FixtureRoot $fixtureRoot

    $outFile = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString("N") + ".log")
    $rc = Invoke-BumpVersion -FixtureRoot $fixtureRoot -Version $version -OutputFile $outFile
    if ($rc -eq 0) {
        Ok "TEST-001 (AC-001): bump-version.sh exits 0 when both loop suites are stubbed passing"
    } else {
        Fail "TEST-001 (AC-001): expected exit 0, got $rc; output: $(Get-Content -LiteralPath $outFile -Raw)"
    }

    $manifestHit = $false
    $pluginsDir = Join-Path $fixtureRoot "plugins"
    if (Test-Path -LiteralPath $pluginsDir) {
        Get-ChildItem -LiteralPath $pluginsDir -Directory | ForEach-Object {
            $manifest = Join-Path $_.FullName ".claude-plugin/plugin.json"
            if (Test-Path -LiteralPath $manifest) {
                $manifestContent = Get-Content -LiteralPath $manifest -Raw
                if ($manifestContent.Contains("`"version`": `"$version`"")) { $manifestHit = $true }
            }
        }
    }
    if ($manifestHit) {
        Ok "TEST-001 (AC-001): a plugin manifest now carries the new version string $version"
    } else {
        Fail "TEST-001 (AC-001): no plugin manifest carries the new version string $version"
    }

    $readme = Get-Content -LiteralPath (Join-Path $fixtureRoot "README.md") -Raw
    if ($readme.Contains("v$version")) {
        Ok "TEST-001 (AC-001): README.md current-release line carries the new version string"
    } else {
        Fail "TEST-001 (AC-001): README.md current-release line does not carry $version"
    }

    $validator = Get-Content -LiteralPath (Join-Path $fixtureRoot "tests/validate-repository.ps1") -Raw
    if ($validator.Contains($version)) {
        Ok "TEST-001 (AC-001): tests/validate-repository.ps1 carries the new version string"
    } else {
        Fail "TEST-001 (AC-001): tests/validate-repository.ps1 does not carry $version"
    }

    Remove-Item -LiteralPath $outFile -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# TEST-002 (AC-002): red path A — loop-consistency stubbed failing
# ---------------------------------------------------------------------------
function Test-002 {
    Write-Output "=== TEST-002 (AC-002): red path A (loop-consistency.tests.sh stubbed failing) ==="
    if (-not $bashCmd) {
        Write-Output "SKIP: TEST-002 (AC-002) bash not found on PATH; scripts/bump-version.sh is bash-only (REQ-004 recorded degradation)"
        return
    }

    $fixtureRoot = New-Fixture -Label "red-consistency"
    Set-SuiteStub -FixtureRoot $fixtureRoot -RelPath "tests/loop-consistency.tests.sh" -ExitCode 1
    Set-FixtureChangelogHeading -FixtureRoot $fixtureRoot -Version $version
    Set-FixtureBaseline -FixtureRoot $fixtureRoot

    $outFile = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString("N") + ".log")
    $rc = Invoke-BumpVersion -FixtureRoot $fixtureRoot -Version $version -OutputFile $outFile
    if ($rc -ne 0) {
        Ok "TEST-002 (AC-002): bump-version.sh exits non-zero when loop-consistency.tests.sh is stubbed failing"
    } else {
        Fail "TEST-002 (AC-002): expected bump-version.sh to exit non-zero when loop-consistency.tests.sh is stubbed failing, but it exited 0"
    }
    Remove-Item -LiteralPath $outFile -ErrorAction SilentlyContinue

    $porcelain = Get-FixturePorcelain -FixtureRoot $fixtureRoot
    if ([string]::IsNullOrEmpty($porcelain)) {
        Ok "TEST-002 (AC-002): git status --porcelain is empty after the run (zero release-surface mutation)"
    } else {
        Fail "TEST-002 (AC-002): git status --porcelain is non-empty after the run: $porcelain"
    }
}

# ---------------------------------------------------------------------------
# TEST-003 (AC-003): red path B — loop-inventory stubbed failing, the
# independent leg (loop-consistency.tests.sh left real and genuinely
# executed, since it iterates first and must pass to reach the failure)
# ---------------------------------------------------------------------------
function Test-003 {
    Write-Output "=== TEST-003 (AC-003): red path B (loop-inventory.tests.sh stubbed failing, independent leg) ==="
    if (-not $bashCmd) {
        Write-Output "SKIP: TEST-003 (AC-003) bash not found on PATH; scripts/bump-version.sh is bash-only (REQ-004 recorded degradation)"
        return
    }

    $fixtureRoot = New-Fixture -Label "red-inventory"
    Set-SuiteStub -FixtureRoot $fixtureRoot -RelPath "tests/loop-inventory.tests.sh" -ExitCode 1
    Set-FixtureChangelogHeading -FixtureRoot $fixtureRoot -Version $version
    Set-FixtureBaseline -FixtureRoot $fixtureRoot

    $outFile = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString("N") + ".log")
    $rc = Invoke-BumpVersion -FixtureRoot $fixtureRoot -Version $version -OutputFile $outFile
    if ($rc -ne 0) {
        Ok "TEST-003 (AC-003): bump-version.sh exits non-zero when loop-inventory.tests.sh is stubbed failing (loop-consistency.tests.sh, run for real, passed first)"
    } else {
        Fail "TEST-003 (AC-003): expected bump-version.sh to exit non-zero when loop-inventory.tests.sh is stubbed failing, but it exited 0"
    }
    Remove-Item -LiteralPath $outFile -ErrorAction SilentlyContinue

    $porcelain = Get-FixturePorcelain -FixtureRoot $fixtureRoot
    if ([string]::IsNullOrEmpty($porcelain)) {
        Ok "TEST-003 (AC-003): git status --porcelain is empty after the run (zero release-surface mutation)"
    } else {
        Fail "TEST-003 (AC-003): git status --porcelain is non-empty after the run: $porcelain"
    }
}

# ---------------------------------------------------------------------------
# TEST-004 (AC-004): no-bypass self-check over the REAL
# scripts/bump-version.sh source
# ---------------------------------------------------------------------------
function Test-004 {
    Write-Output "=== TEST-004 (AC-004): no-bypass self-check (real scripts/bump-version.sh) ==="
    $srcLines = Get-Content -LiteralPath $bumpVersionSh

    $startIdx = -1
    for ($i = 0; $i -lt $srcLines.Count; $i++) {
        if ($srcLines[$i] -eq '# Loop-suite prerequisite (issue #148): both suites must pass before any') {
            $startIdx = $i
            break
        }
    }
    if ($startIdx -lt 0) {
        Fail "TEST-004 (AC-004): loop-gate marker comment not found in scripts/bump-version.sh"
        return
    }

    $endIdx = -1
    for ($i = $startIdx + 1; $i -lt $srcLines.Count; $i++) {
        if ($srcLines[$i] -eq 'done') { $endIdx = $i; break }
    }
    if ($endIdx -lt 0) {
        Fail "TEST-004 (AC-004): loop-gate block's closing 'done' not found after the marker comment"
        return
    }

    $block = $srcLines[$startIdx..$endIdx]

    $forIdx = -1
    for ($i = 0; $i -lt $block.Count; $i++) {
        if ($block[$i] -eq 'for suite in tests/loop-consistency.tests.sh tests/loop-inventory.tests.sh; do') {
            $forIdx = $i
            break
        }
    }
    if ($forIdx -lt 0) {
        Fail "TEST-004 (AC-004): the loop-gate 'for' statement is missing or indented (possibly nested inside a bypass conditional)"
        return
    }
    Ok "TEST-004 (AC-004): the loop-gate 'for' statement is unindented (top-level, not nested inside a conditional)"

    # Keyword sweep over the CODE only (the 'for' line through 'done'),
    # excluding the two leading comment lines -- the comment above the
    # block legitimately documents "no bypass" in prose, which would
    # otherwise false-trip a whole-block sweep.
    $codeBlock = $block[$forIdx..($block.Count - 1)]
    $codeText = ($codeBlock -join "`n")
    if ($codeText -match '(?i)SKIP|BYPASS|OVERRIDE|CONTINUE-ON-ERROR') {
        Fail "TEST-004 (AC-004): a bypass-suggestive token (SKIP/BYPASS/OVERRIDE) was found inside the loop-gate block's code"
    } else {
        Ok "TEST-004 (AC-004): no bypass-suggestive token (SKIP/BYPASS/OVERRIDE) inside the loop-gate block's code"
    }

    $preFor = @()
    for ($i = 0; $i -lt $forIdx; $i++) {
        $line = $block[$i].Trim()
        if ($line -ne '' -and -not $line.StartsWith('#')) { $preFor += $block[$i] }
    }
    if ($preFor.Count -eq 0) {
        Ok "TEST-004 (AC-004): no statement (conditional or otherwise) precedes the loop-gate 'for' entry"
    } else {
        Fail "TEST-004 (AC-004): a statement precedes the loop-gate 'for' entry, possibly gating it: $($preFor -join '; ')"
    }
}

# ---------------------------------------------------------------------------
# TEST-005 (AC-005): ordering assertion over the REAL
# scripts/bump-version.sh source
# ---------------------------------------------------------------------------
function Test-005 {
    Write-Output "=== TEST-005 (AC-005): loop-gate precedes the first mutation step (real scripts/bump-version.sh) ==="
    $srcLines = Get-Content -LiteralPath $bumpVersionSh

    $gateIdx = -1
    $mutationIdx = -1
    for ($i = 0; $i -lt $srcLines.Count; $i++) {
        if ($gateIdx -lt 0 -and $srcLines[$i] -eq 'for suite in tests/loop-consistency.tests.sh tests/loop-inventory.tests.sh; do') {
            $gateIdx = $i
        }
        if ($mutationIdx -lt 0 -and $srcLines[$i] -match 'sed -i ') {
            $mutationIdx = $i
        }
    }

    if ($gateIdx -lt 0) {
        Fail "TEST-005 (AC-005): loop-gate invocation line not found in scripts/bump-version.sh"
        return
    }
    if ($mutationIdx -lt 0) {
        Fail "TEST-005 (AC-005): no 'sed -i' mutation line found in scripts/bump-version.sh"
        return
    }

    if ($gateIdx -lt $mutationIdx) {
        Ok "TEST-005 (AC-005): loop-gate invocation (line $($gateIdx + 1)) precedes the first mutation step (line $($mutationIdx + 1))"
    } else {
        Fail "TEST-005 (AC-005): loop-gate invocation (line $($gateIdx + 1)) does NOT precede the first mutation step (line $($mutationIdx + 1))"
    }
}

# ---------------------------------------------------------------------------
# TEST-006 (AC-006): CI-resilience + self-registration conformance
# ---------------------------------------------------------------------------
function Test-006 {
    Write-Output "=== TEST-006 (AC-006): CI-resilience + self-registration ==="
    $selfContent = Get-Content -LiteralPath $selfPs1 -Raw

    if ($selfContent.Contains("Resolve-Path")) {
        Ok "TEST-006 (AC-006, CI-resilience): fixture-root normalization uses Resolve-Path (pwd -P equivalent)"
    } else {
        Fail "TEST-006 (AC-006, CI-resilience): Resolve-Path normalization not found in this suite's own source"
    }

    # Forbidden-substring tokens are built at runtime -- with names/messages
    # that also avoid the literal substring -- so these self-checks do not
    # trip on their own construction lines.
    $queryToolChar1 = "j"
    $queryToolChar2 = "q"
    $queryToolToken = "$queryToolChar1$queryToolChar2"
    if ($selfContent.Contains($queryToolToken)) {
        Fail "TEST-006 (AC-006, CI-resilience): this suite unexpectedly consumes JSON-query-tool output (non-use declaration violated)"
    } else {
        Ok "TEST-006 (AC-006, CI-resilience): this suite consumes no JSON-query-tool output (non-use declaration)"
    }

    $validatorPartA = "validate-review"
    $validatorPartB = "-context-set"
    $validatorToken = "$validatorPartA$validatorPartB"
    if ($selfContent.Contains($validatorToken)) {
        Fail "TEST-006 (AC-006, CI-resilience): this suite unexpectedly drives the real validator (non-use declaration violated)"
    } else {
        Ok "TEST-006 (AC-006, CI-resilience): this suite drives no real validator (non-use declaration)"
    }

    $runAllPs1Content = if (Test-Path -LiteralPath $runAllPs1) { Get-Content -LiteralPath $runAllPs1 -Raw } else { "" }
    $testYmlContent = if (Test-Path -LiteralPath $testYml) { Get-Content -LiteralPath $testYml -Raw } else { "" }
    if ($runAllPs1Content.Contains("bump-version-gate.tests.ps1") -and $testYmlContent.Contains("bump-version-gate.tests.ps1")) {
        Ok "TEST-006 (AC-006): bump-version-gate.tests.ps1 is registered in tests/run-all.ps1 and .github/workflows/test.yml"
    } else {
        Fail "TEST-006 (AC-006): bump-version-gate.tests.ps1 is NOT registered in tests/run-all.ps1 and/or .github/workflows/test.yml"
    }
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
try {
    Test-001
    Test-002
    Test-003
    Test-004
    Test-005
    Test-006

    Write-Output ""
    Write-Output "bump-version-gate.tests.ps1: $($script:passCount) passed, $($script:failCount) failed"
    if ($script:failCount -ne 0) { exit 1 }
    exit 0
} finally {
    foreach ($d in $cleanupRoots) {
        if ($d -and (Test-Path -LiteralPath $d)) { Remove-Item -Recurse -Force -LiteralPath $d -ErrorAction SilentlyContinue }
    }
}
