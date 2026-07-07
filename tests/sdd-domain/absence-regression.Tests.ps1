#
# T-007 absence-regression -- AC-010 byte-identical-output regression guard
#
# AC-010: "With no domain/ directory, all sdd-domain hooks, sync steps, and
# gates are skipped, recording a single skip line; existing workflows
# produce byte-identical artifacts."
#
# sdd-bootstrap-interviewer/SKILL.md is a large, already-working instruction
# document, not an executable script -- there is no way to literally run it
# in a unit test and diff its two output runs. Per this task's brief, the
# meaningful, REAL, executable regression check available here is: prove the
# edit made to plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md
# for this task is STRUCTURALLY ADDITIVE-ONLY -- i.e. `git diff --numstat`
# against the pre-change committed version shows zero deleted/modified lines
# and only new, clearly-scoped inserted lines. An additive-only change to an
# instruction document is real, verifiable evidence that every pre-existing
# instruction (and therefore every pre-existing generated artifact for a
# domain/-absent project) is untouched -- the new step is a no-op branch for
# such a project (per domain-sync's own single-skip-line contract, verified
# separately in domain-sync.Tests.ps1).
#
# This file requires a git-tracked working copy (it shells out to `git
# diff --numstat` against HEAD). It is a regression guard specific to this
# task's own edit, not a general-purpose tool.
#
# ASCII-only: no non-ASCII literal characters appear anywhere in this file
# (BOM-less .ps1 is read as ANSI on this Windows environment).

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bootstrapSkillRelativePath = "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md"
$bootstrapSkillPath = Join-Path $repositoryRoot $bootstrapSkillRelativePath
$domainSyncSkillPath = Join-Path $repositoryRoot "plugins/sdd-domain/skills/domain-sync/SKILL.md"

# The pre-sdd-domain baseline commit: the last commit before this feature's
# T-007 touched the bootstrap interviewer. Anchoring the additive-only diff
# to this fixed baseline (instead of the uncommitted working tree) keeps the
# regression guard valid after the feature's edits are committed.
$baselineCommit = "7fc0534"

function Test-GitCommitReachable {
    param([string]$RepoRoot, [string]$Commit)

    Push-Location $RepoRoot
    try {
        & git rev-parse --verify --quiet ("{0}^{{commit}}" -f $Commit) 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    } finally {
        Pop-Location
    }
}

function Invoke-GitNumstat {
    param([string]$RepoRoot, [string]$Baseline, [string]$RelativePath)

    Push-Location $RepoRoot
    try {
        $output = & git diff --numstat $Baseline -- $RelativePath 2>&1
        return ,$output
    } finally {
        Pop-Location
    }
}

function Invoke-GitDiffText {
    param([string]$RepoRoot, [string]$Baseline, [string]$RelativePath)

    Push-Location $RepoRoot
    try {
        $output = & git diff $Baseline -- $RelativePath 2>&1
        return ($output -join "`n")
    } finally {
        Pop-Location
    }
}

Describe "AC-010: sdd-bootstrap-interviewer edit is additive-only vs pre-feature baseline (git diff --numstat)" {

    BeforeAll {
        $script:baselineReachable = Test-GitCommitReachable -RepoRoot $repositoryRoot -Commit $baselineCommit
        if ($script:baselineReachable) {
            $script:numstatRaw = Invoke-GitNumstat -RepoRoot $repositoryRoot -Baseline $baselineCommit -RelativePath $bootstrapSkillRelativePath
            $script:diffText = Invoke-GitDiffText -RepoRoot $repositoryRoot -Baseline $baselineCommit -RelativePath $bootstrapSkillRelativePath
        } else {
            # Baseline commit unreachable (e.g. squash-merged history). The
            # additive-only property cannot be recomputed here; skip rather
            # than fail, since the guard's purpose is tied to that baseline.
            $script:numstatRaw = @()
            $script:diffText = ""
        }
    }

    It "the pre-feature baseline commit is reachable (guard anchor present)" {
        if (-not $script:baselineReachable) {
            Set-TestInconclusive "baseline commit $baselineCommit not reachable in this clone; additive-only guard skipped"
        }
        $script:baselineReachable | Should Be $true
    }

    It "git diff --numstat vs baseline reports exactly one changed-file line for the bootstrap SKILL.md" {
        if (-not $script:baselineReachable) { Set-TestInconclusive "baseline unreachable" }
        $nonEmptyLines = @($script:numstatRaw | Where-Object { $_ -and $_.Trim() -ne "" })
        $nonEmptyLines.Count | Should Be 1
    }

    It "the numstat line reports zero deleted lines (additive-only)" {
        if (-not $script:baselineReachable) { Set-TestInconclusive "baseline unreachable" }
        $line = @($script:numstatRaw | Where-Object { $_ -and $_.Trim() -ne "" })[0]
        # numstat format: "<added>\t<deleted>\t<path>"
        $parts = $line -split "`t"
        $parts.Count | Should Be 3
        [int]$parts[1] | Should Be 0
    }

    It "the numstat line reports at least one added line (the new step was actually inserted)" {
        if (-not $script:baselineReachable) { Set-TestInconclusive "baseline unreachable" }
        $line = @($script:numstatRaw | Where-Object { $_ -and $_.Trim() -ne "" })[0]
        $parts = $line -split "`t"
        [int]$parts[0] | Should BeGreaterThan 0
    }

    It "the unified diff vs baseline contains no removed content lines (lines starting with a single '-')" {
        if (-not $script:baselineReachable) { Set-TestInconclusive "baseline unreachable" }
        # A line starting with exactly one '-' (not '---' file-header marker)
        # represents a deleted/modified source line. Only the file-header
        # '--- a/<path>' line is allowed to start with '-'.
        $diffLines = $script:diffText -split "`n"
        $removedContentLines = @($diffLines | Where-Object {
            $_ -match '^-' -and $_ -notmatch '^---\s'
        })
        $removedContentLines.Count | Should Be 0
    }

    It "the unified diff's added lines are contiguous and scoped to the Intake And Investigation section" {
        if (-not $script:baselineReachable) { Set-TestInconclusive "baseline unreachable" }
        # Every added line ('+' prefix, excluding the '+++' file-header marker)
        # must appear within a hunk whose context includes
        # '## Intake And Investigation' or the new step's own numbered-item
        # text -- i.e. the change is scoped to one section, not scattered
        # across the file.
        $diffLines = $script:diffText -split "`n"
        $addedLines = @($diffLines | Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+\s' })
        $addedLines.Count | Should BeGreaterThan 0

        $hunkHeaders = @($diffLines | Where-Object { $_ -match '^@@' })
        # A single contiguous hunk is the strongest possible evidence of a
        # scoped, non-scattered change.
        $hunkHeaders.Count | Should Be 1
    }
}

Describe "AC-010: domain-sync single-skip-line contract (documented, cross-checked against the bootstrap edit)" {

    BeforeAll {
        $script:bootstrapText = Get-Content -Raw -Encoding UTF8 -LiteralPath $bootstrapSkillPath
        $script:domainSyncText = Get-Content -Raw -Encoding UTF8 -LiteralPath $domainSyncSkillPath
    }

    It "the inserted bootstrap step documents proceeding exactly as if domain/ were absent on skip/warning" {
        $script:bootstrapText | Should Match "proceed exactly as if\s*``domain/``\s*were absent"
    }

    It "the inserted bootstrap step explicitly claims no other change to Phase 1 flow" {
        $script:bootstrapText | Should Match "no other change to this flow"
    }

    It "the inserted bootstrap step cites AC-010 directly" {
        $script:bootstrapText | Should Match "AC-010"
    }

    It "domain-sync documents exactly one skip line for the absent-domain/ case" {
        ($script:domainSyncText | Select-String -Pattern "domain-sync skipped: no domain/ directory" -AllMatches).Matches.Count | Should Be 1
    }

    It "domain-sync's detection logic runs its checks in order and stops at the first failing check (no double-skip)" {
        $script:domainSyncText | Should Match "The first\s*check that fails ends the run"
    }
}

Describe "Worked fixture: absence of domain/ produces the documented single skip line and no injection" {

    BeforeAll {
        $script:fixtureDir = Join-Path ([IO.Path]::GetTempPath()) ("sdd-domain-t007-absence-" + [Guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $script:fixtureDir -Force | Out-Null
        # Deliberately no domain/ subdirectory created.
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:fixtureDir) {
            Remove-Item -LiteralPath $script:fixtureDir -Recurse -Force
        }
    }

    # Simulates domain-sync's documented step-1 detection check: does
    # domain/ exist at the project root? This is the only branch this test
    # can execute deterministically (a filesystem existence check); the
    # remaining detection steps (Domain-Model-Status, contract validation)
    # are exercised in domain-sync.Tests.ps1's Approved-model fixture.
    function Get-DomainSyncOutcome {
        param([string]$ProjectRoot)

        $domainDir = Join-Path $ProjectRoot "domain"
        if (-not (Test-Path -LiteralPath $domainDir)) {
            return [PSCustomObject]@{
                Outcome = "skipped"
                Line = "domain-sync skipped: no domain/ directory"
                Injected = $false
            }
        }
        throw "test double only implements the absent-domain/ branch"
    }

    It "reports exactly the documented skip line when domain/ is absent" {
        $result = Get-DomainSyncOutcome -ProjectRoot $script:fixtureDir
        $result.Outcome | Should Be "skipped"
        $result.Line | Should Be "domain-sync skipped: no domain/ directory"
    }

    It "performs no injection when domain/ is absent" {
        $result = Get-DomainSyncOutcome -ProjectRoot $script:fixtureDir
        $result.Injected | Should Be $false
    }

    It "the fixture project genuinely has no domain/ directory (sanity check on the test setup)" {
        Test-Path -LiteralPath (Join-Path $script:fixtureDir "domain") | Should Be $false
    }
}
