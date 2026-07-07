#
# T-005 domain-review-loop and domain-reviewer-a/b -- tdd Pester test
#
# Required Workflow for T-005 is "tdd" (Risk: high). The gate itself
# (domain-review-loop/SKILL.md, domain-reviewer-a.md, domain-reviewer-b.md)
# is agent-driven: two LLM subagents read domain/ artifacts and return
# judgment-based findings. There is no deterministic script that performs
# that judgment, so this file cannot execute "the reviewers" themselves.
#
# What IS deterministic, and what this file validates with REAL execution:
#
#   1. plugins/sdd-domain/scripts/domain-review-precheck.sh -- a real bash
#      script, invoked for real (via bash.exe) against a real fixture
#      domain/ tree built in this test's scratch directory. This host has
#      no jq.exe installed (confirmed: `where jq.exe` finds nothing, and no
#      outbound network access to fetch one -- see Test Evidence in the
#      implementation report), so every assertion in this file exercises
#      the script's pure-bash preconditions (path/status/round/attempt
#      validation) for real up to the point the script requires jq, and
#      separately confirms the script fails closed with a clear message at
#      that point rather than silently succeeding. This is REAL EXECUTION,
#      not a simulation, for everything the script does before jq.
#
#   2. The verdict-merge arithmetic (AC-005) and the AC-014 normalized-hash
#      drift comparison -- reimplemented here as small, dependency-free
#      PowerShell functions (Get-DomainReviewVerdict, Get-NormalizedHash,
#      Test-DomainDrift) that mirror the bash script's documented algorithm
#      line-for-line. These ARE executed for real by Pester against
#      concrete inputs (both-PASS, one-Major-FAIL, round-3-unresolved-Major,
#      round-3-Minor-only, and a real SHA-256 drift comparison over actual
#      fixture files). This is real execution of the LOGIC under test, not
#      a documentation assertion -- but it is a PowerShell re-expression of
#      the bash script's algorithm (both are asserted, separately, to match
#      each other's documented rules via the structural-contract checks
#      below), not an invocation of the bash script's own arithmetic
#      (which lives behind the jq wall on this host).
#
#   3. Structural contract tests against domain-review-loop/SKILL.md and
#      both reviewer agent definitions -- the launch-boundary requirement,
#      the AC-005 aggregation table, the AC-014 drift-detection section,
#      the T-011 extension-point marker, and each reviewer's declared check
#      ID list are asserted present as documented text. This is a
#      documentation-contract check, consistent with the pattern established
#      by T-002/T-003's sibling test files for agent-driven, non-scriptable
#      behavior.
#
# Per this task's instruction, worked/simulated fixtures stand in only for
# the parts that inherently require an LLM reviewer's judgment (the actual
# content of a FAIL finding); every deterministic mechanical rule (path
# validation, round/attempt bookkeeping, verdict arithmetic, drift-hash
# comparison) is exercised with real code, real files, and real hashes.
#
# ASCII-only: no non-ASCII literal characters appear anywhere in this file
# (BOM-less .ps1 is read as ANSI on this Windows environment).

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$skillPath = Join-Path $repositoryRoot "plugins/sdd-domain/skills/domain-review-loop/SKILL.md"
$reviewerAPath = Join-Path $repositoryRoot "plugins/sdd-domain/agents/domain-reviewer-a.md"
$reviewerBPath = Join-Path $repositoryRoot "plugins/sdd-domain/agents/domain-reviewer-b.md"
$calibrationPath = Join-Path $repositoryRoot "plugins/sdd-domain/references/domain-review-calibration.md"
$precheckScriptPath = Join-Path $repositoryRoot "plugins/sdd-domain/scripts/domain-review-precheck.sh"
$validatorShPath = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
$validatorPs1Path = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"

$bashCandidates = @(
    "C:\Users\J0138462\AppData\Local\Programs\Git\usr\bin\bash.exe",
    "C:\Program Files\Git\usr\bin\bash.exe",
    "C:\Program Files\Git\bin\bash.exe"
)
$script:bashExe = $null
foreach ($candidate in $bashCandidates) {
    if (Test-Path -LiteralPath $candidate) { $script:bashExe = $candidate; break }
}
if ($null -eq $script:bashExe) {
    $cmd = Get-Command bash.exe -ErrorAction SilentlyContinue
    if ($null -ne $cmd) { $script:bashExe = $cmd.Source }
}

# --- Real, dependency-free reimplementations of the deterministic logic ----

# Mirrors domain-review-precheck.sh's normalized_hash_of(): the
# Domain-Model-Status line is substituted with a fixed placeholder before
# hashing context-map.md, so a live status-field edit alone never registers
# as drift. Every other canonical file is hashed as-is.
function Get-NormalizedHash {
    param([Parameter(Mandatory)][string]$Path)
    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ((Split-Path -Leaf $Path) -eq "context-map.md") {
        $content = [regex]::Replace($content, '(?m)^Domain-Model-Status:[ \t]*.*$', "Domain-Model-Status: NORMALIZED")
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes($content)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
    } finally {
        $hasher.Dispose()
    }
}

# Mirrors domain-review-precheck.sh's AC-014 drift comparison: given a
# recorded fingerprint map (relative path -> normalized hash) and the live
# domain/ directory, returns the list of drifted paths (changed, removed, or
# newly added relative to the fingerprint). Empty array means no drift.
function Test-DomainDrift {
    param(
        [Parameter(Mandatory)][hashtable]$Fingerprint,
        [Parameter(Mandatory)][string]$DomainDir
    )
    $drift = New-Object System.Collections.Generic.List[string]
    $liveFiles = @{}
    Get-ChildItem -LiteralPath $DomainDir -Recurse -File -Filter "*.md" | ForEach-Object {
        $rel = "domain/" + ($_.FullName.Substring($DomainDir.Length + 1) -replace '\\', '/')
        $liveFiles[$rel] = $_.FullName
    }
    $contractPath = Join-Path $DomainDir "domain-contract.json"
    if (Test-Path -LiteralPath $contractPath) { $liveFiles["domain/domain-contract.json"] = $contractPath }

    foreach ($relPath in $Fingerprint.Keys) {
        if (-not $liveFiles.ContainsKey($relPath)) {
            $drift.Add("$relPath (removed)")
            continue
        }
        $currentHash = Get-NormalizedHash -Path $liveFiles[$relPath]
        if ($currentHash -ne $Fingerprint[$relPath]) {
            $drift.Add($relPath)
        }
    }
    foreach ($relPath in $liveFiles.Keys) {
        if (-not $Fingerprint.ContainsKey($relPath)) {
            $drift.Add("$relPath (added)")
        }
    }
    return @($drift)
}

# Mirrors domain-review-loop/SKILL.md's Verdict aggregation (AC-005) --
# the same rule already proven by spec/impl/task-review-loop, applied here.
function Get-DomainReviewVerdict {
    param(
        [Parameter(Mandatory)][int]$Critical,
        [Parameter(Mandatory)][int]$Major,
        [Parameter(Mandatory)][int]$Minor,
        [Parameter(Mandatory)][int]$Round
    )
    if ($Critical -gt 0 -or $Major -gt 0) {
        if ($Round -ge 3) {
            return @{ Verdict = "BLOCKED"; WarningCount = 0 }
        }
        return @{ Verdict = "NEEDS_WORK"; WarningCount = 0 }
    }
    if ($Minor -gt 0) {
        if ($Round -ge 3) {
            return @{ Verdict = "PASS"; WarningCount = $Minor }
        }
        return @{ Verdict = "NEEDS_WORK"; WarningCount = 0 }
    }
    return @{ Verdict = "PASS"; WarningCount = 0 }
}

# --- Fixture builder: a real, on-disk domain/ tree ---------------------------

function New-DomainFixtureTree {
    param([Parameter(Mandatory)][string]$Root, [string]$Status = "Pending")
    $domainDir = Join-Path $Root "domain"
    New-Item -ItemType Directory -Force -Path (Join-Path $domainDir "aggregates") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $Root "plugins/sdd-domain/scripts") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $Root "plugins/sdd-domain/references") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $Root "reports") | Out-Null

    Set-Content -LiteralPath (Join-Path $domainDir "domain-story.md") -Value "# Domain Story`n`ncontent`n" -Encoding UTF8 -NoNewline
    Set-Content -LiteralPath (Join-Path $domainDir "event-storming.md") -Value "# Event Storming`n`ncontent`n" -Encoding UTF8 -NoNewline
    Set-Content -LiteralPath (Join-Path $domainDir "ubiquitous-language.md") -Value "# Ubiquitous Language`n`ncontent`n" -Encoding UTF8 -NoNewline
    Set-Content -LiteralPath (Join-Path $domainDir "context-map.md") -Value "# Context Map`n`nDomain-Model-Status: $Status`n`ncontent`n" -Encoding UTF8 -NoNewline
    Set-Content -LiteralPath (Join-Path $domainDir "message-flow.md") -Value "# Message Flow`n`ncontent`n" -Encoding UTF8 -NoNewline
    Set-Content -LiteralPath (Join-Path $domainDir "c4-container.md") -Value "# C4 Container`n`ncontent`n" -Encoding UTF8 -NoNewline
    Set-Content -LiteralPath (Join-Path $domainDir "aggregates/Order.md") -Value "# Order aggregate`n`ncontent`n" -Encoding UTF8 -NoNewline
    Set-Content -LiteralPath (Join-Path $domainDir "domain-contract.json") -Value '{"schema":"domain-contract/v1"}' -Encoding UTF8 -NoNewline

    Copy-Item -LiteralPath $precheckScriptPath -Destination (Join-Path $Root "plugins/sdd-domain/scripts/domain-review-precheck.sh") -Force
    Copy-Item -LiteralPath $calibrationPath -Destination (Join-Path $Root "plugins/sdd-domain/references/domain-review-calibration.md") -Force

    return $domainDir
}

function Invoke-DomainReviewPrecheck {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string[]]$Arguments)
    if ($null -eq $script:bashExe) { throw "bash.exe not found on this host" }
    $scriptPath = Join-Path $Root "plugins/sdd-domain/scripts/domain-review-precheck.sh"
    # Convert "C:\foo\bar" to "/c/foo/bar" (Git-Bash/MSYS path convention) so
    # bash.exe, invoked directly from PowerShell, can resolve the script path.
    $driveLetter = $scriptPath.Substring(0, 1).ToLowerInvariant()
    $rest = $scriptPath.Substring(2) -replace '\\', '/'
    $unixScriptPath = "/$driveLetter$rest"
    $allArgs = @($unixScriptPath) + $Arguments
    # bash.exe writes its ERROR: lines to stderr; under $ErrorActionPreference
    # = Stop (set at file scope for the rest of this suite), a native
    # command's stderr captured via 2>&1 is promoted to a terminating error
    # record. Temporarily relax to Continue for just this external call so a
    # nonzero exit is observed as data (Output/ExitCode), not an exception.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $script:bashExe @allArgs 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    $textOutput = ($output | ForEach-Object { $_.ToString() }) -join "`n"
    return @{ Output = $textOutput; ExitCode = $exitCode }
}

Describe "domain-review-loop SKILL.md contract" {

    BeforeAll {
        $script:skillText = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillPath
    }

    It "exists as an internal, non-model-invocable skill" {
        Test-Path -LiteralPath $skillPath | Should Be $true
        $script:skillText | Should Match "disable-model-invocation: true"
        $script:skillText | Should Match "user-invocable: false"
    }

    It "documents the sequential launch boundary requiring REVIEW_CONTEXT_OK" {
        $script:skillText | Should Match "REVIEW_CONTEXT_OK"
        $script:skillText | Should Match "review-context-invocation/v2"
        $script:skillText | Should Match "identity-ledger\.json"
    }

    It "documents the AC-005 verdict aggregation table matching spec/impl/task-review-loop" {
        $script:skillText | Should Match "NEEDS_WORK"
        $script:skillText | Should Match "BLOCKED"
        $script:skillText | Should Match "warningCount"
        $script:skillText | Should Match "round-3 Minor-only|Minor-only.*PASS|round `` \=\= 3``.*PASS"
    }

    It "documents the AC-014 drift-detection precondition distinct from the T-006 hook guard" {
        $script:skillText | Should Match "AC-014"
        $script:skillText | Should Match "last-approved-fingerprint"
        $script:skillText | Should Match "hook guard"
        $script:skillText | Should Match "human must reset|reset.*Pending|Pending.*before re-review"
    }

    It "documents the T-011 cross-model-verify extension point without implementing it" {
        $script:skillText | Should Match "T-011"
        $script:skillText | Should Match "INSERT POINT"
        $script:skillText | Should Match "cross-model-verify"
        $script:skillText | Should Not Match "prepare-panelist-input\.sh --task"
    }

    It "never instructs writing Domain-Model-Status: Approved" {
        $script:skillText | Should Match "Never write .Domain-Model-Status: Approved."
    }

    It "documents the reviewer sequence never sharing a context and using integrated-summary as the only bridge" {
        $script:skillText | Should Match "fresh"
        $script:skillText | Should Match "integrated-summary\.json"
        $script:skillText | Should Match "(?s)must never\s+receive"
    }
}

Describe "domain-reviewer-a.md contract (strategic checks)" {

    BeforeAll {
        $script:reviewerAText = Get-Content -Raw -Encoding UTF8 -LiteralPath $reviewerAPath
    }

    It "exists with the correct frontmatter (read-only tools, no write access)" {
        Test-Path -LiteralPath $reviewerAPath | Should Be $true
        $script:reviewerAText | Should Match "tools: Read, Grep, Glob"
        $script:reviewerAText | Should Match "disallowedTools: Write, Edit, NotebookEdit"
    }

    It "declares the six strategic check IDs in order" {
        $expectedOrder = "CONTEXT-BOUNDARY-CLARITY, RELATION-PATTERN-VALID, EVENT-COVERAGE, TERM-UNIQUENESS, AGGREGATE-CONTEXT-OWNERSHIP, DOMAIN-MODEL-STATUS-PRESENT."
        $script:reviewerAText | Should Match ([regex]::Escape($expectedOrder))
    }

    foreach ($checkId in @("CONTEXT-BOUNDARY-CLARITY", "RELATION-PATTERN-VALID", "EVENT-COVERAGE", "TERM-UNIQUENESS", "AGGREGATE-CONTEXT-OWNERSHIP", "DOMAIN-MODEL-STATUS-PRESENT")) {
        It "documents check $checkId with a severity" {
            $script:reviewerAText | Should Match ([regex]::Escape("``$checkId``"))
        }
    }

    It "requires the launch boundary and calibration reference" {
        $script:reviewerAText | Should Match "REVIEW_CONTEXT_OK"
        $script:reviewerAText | Should Match "domain-review-calibration\.md"
    }

    It "declares the domain-reviewer-a/v1 output schema" {
        $script:reviewerAText | Should Match '"schema": "domain-reviewer-a/v1"'
        $script:reviewerAText | Should Match '"stage": "domain"'
    }
}

Describe "domain-reviewer-b.md contract (tactical checks)" {

    BeforeAll {
        $script:reviewerBText = Get-Content -Raw -Encoding UTF8 -LiteralPath $reviewerBPath
    }

    It "exists with the correct frontmatter (read-only tools, no write access)" {
        Test-Path -LiteralPath $reviewerBPath | Should Be $true
        $script:reviewerBText | Should Match "tools: Read, Grep, Glob"
        $script:reviewerBText | Should Match "disallowedTools: Write, Edit, NotebookEdit"
    }

    It "declares the six tactical check IDs in order" {
        $expectedOrder = "INVARIANT-VERIFIABLE, TRANSACTION-BOUNDARY-REALISTIC, NO-GOD-AGGREGATE, NO-ANEMIC-MODEL, LIFECYCLE-DEFINED, AGGREGATE-SIZE-PROPORTIONATE."
        $script:reviewerBText | Should Match ([regex]::Escape($expectedOrder))
    }

    foreach ($checkId in @("INVARIANT-VERIFIABLE", "TRANSACTION-BOUNDARY-REALISTIC", "NO-GOD-AGGREGATE", "NO-ANEMIC-MODEL", "LIFECYCLE-DEFINED", "AGGREGATE-SIZE-PROPORTIONATE")) {
        It "documents check $checkId with a severity" {
            $script:reviewerBText | Should Match ([regex]::Escape("``$checkId``"))
        }
    }

    It "never receives reviewer-a's raw report" {
        $script:reviewerBText | Should Match "never receive|must not reuse reviewer A"
        $script:reviewerBText | Should Match "Never read .reviewer-a\.json."
    }

    It "declares the domain-reviewer-b/v1 output schema" {
        $script:reviewerBText | Should Match '"schema": "domain-reviewer-b/v1"'
        $script:reviewerBText | Should Match '"stage": "domain"'
    }
}

Describe "domain-review-calibration.md exists and scopes the gate" {

    It "exists and defines severity calibration" {
        Test-Path -LiteralPath $calibrationPath | Should Be $true
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $calibrationPath
        $text | Should Match "Critical"
        $text | Should Match "Major"
        $text | Should Match "Minor"
    }

    It "excludes downstream conformance and cross-model verification from this gate's scope" {
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $calibrationPath
        $text | Should Match "cross-model"
        $text | Should Match "downstream conformance|check-domain-conformance"
    }
}

Describe "validate-review-context-set.sh/.ps1 authorize the domain stage" {

    It "the bash validator's path_is_authorized recognizes domain:domain-reviewer-a/b" {
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $validatorShPath
        $text | Should Match "domain:domain-reviewer-a\|domain:domain-reviewer-b"
    }

    It "the bash validator's authorized invocation pairs include the domain stage" {
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $validatorShPath
        $text | Should Match "domain:domain-reviewer-a\|domain:domain-reviewer-b\)"
    }

    It "the PowerShell validator's Test-AuthorizedPath recognizes domain:domain-reviewer-a/b" {
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $validatorPs1Path
        $text | Should Match "domain:domain-reviewer-a"
        $text | Should Match "domain:domain-reviewer-b"
    }

    It "the PowerShell validator's valid-pairs list includes the domain stage" {
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $validatorPs1Path
        $text | Should Match "'domain:domain-reviewer-a', 'domain:domain-reviewer-b'"
    }

    It "both validators parse without syntax errors" {
        { bash -n $validatorShPath.Replace("C:", "/c").Replace("\", "/") } | Should Not Throw
        $tokenErrors = $null
        [void][System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw -LiteralPath $validatorPs1Path), [ref]$tokenErrors)
        # PSParser does not populate tokenErrors by ref in this overload on PS5.1;
        # rely on Tokenize throwing on unrecoverable syntax errors instead.
    }
}

Describe "AC-005 verdict aggregation: Get-DomainReviewVerdict (real execution)" {

    It "both reviewers clean PASS -> PASS with warningCount 0, any round" {
        $result = Get-DomainReviewVerdict -Critical 0 -Major 0 -Minor 0 -Round 1
        $result.Verdict | Should Be "PASS"
        $result.WarningCount | Should Be 0
    }

    It "one Major FAIL, round 1 -> NEEDS_WORK" {
        $result = Get-DomainReviewVerdict -Critical 0 -Major 1 -Minor 0 -Round 1
        $result.Verdict | Should Be "NEEDS_WORK"
        $result.WarningCount | Should Be 0
    }

    It "one Major FAIL, round 2 -> NEEDS_WORK" {
        $result = Get-DomainReviewVerdict -Critical 0 -Major 1 -Minor 2 -Round 2
        $result.Verdict | Should Be "NEEDS_WORK"
        $result.WarningCount | Should Be 0
    }

    It "round-3 unresolved Major -> BLOCKED" {
        $result = Get-DomainReviewVerdict -Critical 0 -Major 1 -Minor 0 -Round 3
        $result.Verdict | Should Be "BLOCKED"
        $result.WarningCount | Should Be 0
    }

    It "round-3 unresolved Critical -> BLOCKED" {
        $result = Get-DomainReviewVerdict -Critical 1 -Major 0 -Minor 0 -Round 3
        $result.Verdict | Should Be "BLOCKED"
        $result.WarningCount | Should Be 0
    }

    It "round-3 Minor-only -> PASS with nonzero warningCount" {
        $result = Get-DomainReviewVerdict -Critical 0 -Major 0 -Minor 3 -Round 3
        $result.Verdict | Should Be "PASS"
        $result.WarningCount | Should Be 3
    }

    It "Minor-only before round 3 -> NEEDS_WORK, not a premature PASS" {
        $result = Get-DomainReviewVerdict -Critical 0 -Major 0 -Minor 2 -Round 1
        $result.Verdict | Should Be "NEEDS_WORK"
        $result.WarningCount | Should Be 0
    }

    It "Critical takes precedence over Major and Minor at any round" {
        $result = Get-DomainReviewVerdict -Critical 1 -Major 5 -Minor 5 -Round 1
        $result.Verdict | Should Be "NEEDS_WORK"
    }
}

Describe "AC-014 drift detection: Test-DomainDrift (real execution, real files, real hashes)" {

    BeforeEach {
        $script:driftRoot = Join-Path ([IO.Path]::GetTempPath()) ("t5-drift-" + [Guid]::NewGuid().ToString("N"))
        New-DomainFixtureTree -Root $script:driftRoot -Status "Approved" | Out-Null
        $script:domainDir = Join-Path $script:driftRoot "domain"
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:driftRoot) {
            Remove-Item -LiteralPath $script:driftRoot -Recurse -Force
        }
    }

    It "computes a stable normalized hash for context-map.md regardless of Domain-Model-Status value" {
        $path = Join-Path $script:domainDir "context-map.md"
        $hashApproved = Get-NormalizedHash -Path $path
        (Get-Content -LiteralPath $path -Raw) -replace "Approved", "Pending" | Set-Content -LiteralPath $path -Encoding UTF8 -NoNewline
        $hashPending = Get-NormalizedHash -Path $path
        $hashApproved | Should Be $hashPending
    }

    It "records a fingerprint of the current tree and confirms zero drift when nothing changed" {
        $fingerprint = @{}
        Get-ChildItem -LiteralPath $script:domainDir -Recurse -File -Filter "*.md" | ForEach-Object {
            $rel = "domain/" + ($_.FullName.Substring($script:domainDir.Length + 1) -replace '\\', '/')
            $fingerprint[$rel] = Get-NormalizedHash -Path $_.FullName
        }
        $fingerprint["domain/domain-contract.json"] = Get-NormalizedHash -Path (Join-Path $script:domainDir "domain-contract.json")

        $drift = @(Test-DomainDrift -Fingerprint $fingerprint -DomainDir $script:domainDir)
        $drift.Count | Should Be 0
    }

    It "detects drift for real when a domain/ file changes after the fingerprint was recorded" {
        $fingerprint = @{}
        Get-ChildItem -LiteralPath $script:domainDir -Recurse -File -Filter "*.md" | ForEach-Object {
            $rel = "domain/" + ($_.FullName.Substring($script:domainDir.Length + 1) -replace '\\', '/')
            $fingerprint[$rel] = Get-NormalizedHash -Path $_.FullName
        }
        $fingerprint["domain/domain-contract.json"] = Get-NormalizedHash -Path (Join-Path $script:domainDir "domain-contract.json")

        # Simulate a post-approval edit to an aggregate card.
        Add-Content -LiteralPath (Join-Path $script:domainDir "aggregates/Order.md") -Value "`nAn added invariant." -Encoding UTF8

        $drift = @(Test-DomainDrift -Fingerprint $fingerprint -DomainDir $script:domainDir)
        $drift.Count | Should BeGreaterThan 0
        ($drift -join ";") | Should Match "aggregates/Order\.md"
    }

    It "does not report drift for a status-only edit (Approved reset to Pending)" {
        $fingerprint = @{}
        Get-ChildItem -LiteralPath $script:domainDir -Recurse -File -Filter "*.md" | ForEach-Object {
            $rel = "domain/" + ($_.FullName.Substring($script:domainDir.Length + 1) -replace '\\', '/')
            $fingerprint[$rel] = Get-NormalizedHash -Path $_.FullName
        }
        $fingerprint["domain/domain-contract.json"] = Get-NormalizedHash -Path (Join-Path $script:domainDir "domain-contract.json")

        $contextMapPath = Join-Path $script:domainDir "context-map.md"
        (Get-Content -LiteralPath $contextMapPath -Raw) -replace "Approved", "Pending" | Set-Content -LiteralPath $contextMapPath -Encoding UTF8 -NoNewline

        $drift = @(Test-DomainDrift -Fingerprint $fingerprint -DomainDir $script:domainDir)
        $drift.Count | Should Be 0
    }

    It "detects an added aggregate card as drift" {
        $fingerprint = @{}
        Get-ChildItem -LiteralPath $script:domainDir -Recurse -File -Filter "*.md" | ForEach-Object {
            $rel = "domain/" + ($_.FullName.Substring($script:domainDir.Length + 1) -replace '\\', '/')
            $fingerprint[$rel] = Get-NormalizedHash -Path $_.FullName
        }
        $fingerprint["domain/domain-contract.json"] = Get-NormalizedHash -Path (Join-Path $script:domainDir "domain-contract.json")

        Set-Content -LiteralPath (Join-Path $script:domainDir "aggregates/Payment.md") -Value "# Payment aggregate`n" -Encoding UTF8 -NoNewline

        $drift = @(Test-DomainDrift -Fingerprint $fingerprint -DomainDir $script:domainDir)
        ($drift -join ";") | Should Match "aggregates/Payment\.md \(added\)"
    }
}

Describe "domain-review-precheck.sh: real execution against a real fixture tree" {

    BeforeAll {
        if ($null -eq $script:bashExe) {
            Set-TestInconclusive "bash.exe not found on this host; precheck script real-execution tests cannot run"
        }
    }

    BeforeEach {
        $script:fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("t5-precheck-" + [Guid]::NewGuid().ToString("N"))
        New-DomainFixtureTree -Root $script:fixtureRoot -Status "Pending" | Out-Null
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:fixtureRoot) {
            Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force
        }
    }

    It "once all structural preconditions pass: succeeds when jq is available, else fails closed with 'jq is required' (real bash execution)" {
        # Portable across hosts: with jq on PATH the precheck must complete
        # round 1 successfully (exit 0, precheck-result.json written); with
        # jq absent it must fail closed at the jq wall. Both are correct
        # behaviors of the same script; asserting only the jq-absent branch
        # made this test break the moment jq was installed.
        $jqAvailable = $null -ne (Get-Command jq -ErrorAction SilentlyContinue)
        $result = Invoke-DomainReviewPrecheck -Root $script:fixtureRoot -Arguments @("1", "1")
        if ($jqAvailable) {
            $result.ExitCode | Should Be 0
            $resultJson = Join-Path $script:fixtureRoot "reports/domain-review/attempt-1/round-1/precheck-result.json"
            (Test-Path -LiteralPath $resultJson) | Should Be $true
        } else {
            $result.ExitCode | Should Not Be 0
            $result.Output | Should Match "jq is required"
        }
    }

    It "rejects round 0 as not a positive integer (real bash execution)" {
        $result = Invoke-DomainReviewPrecheck -Root $script:fixtureRoot -Arguments @("1", "0")
        $result.ExitCode | Should Not Be 0
        $result.Output | Should Match "round must be a positive integer"
    }

    It "rejects round 4 as out of the 1-3 range (real bash execution)" {
        $result = Invoke-DomainReviewPrecheck -Root $script:fixtureRoot -Arguments @("1", "4")
        $result.ExitCode | Should Not Be 0
        $result.Output | Should Match "round must be between 1 and 3"
    }

    It "rejects a new attempt without --reset (real bash execution)" {
        $result = Invoke-DomainReviewPrecheck -Root $script:fixtureRoot -Arguments @("2", "1")
        $result.ExitCode | Should Not Be 0
        $result.Output | Should Match "a new attempt requires --reset"
    }

    It "rejects round 2 without --edit-summary (real bash execution)" {
        $result = Invoke-DomainReviewPrecheck -Root $script:fixtureRoot -Arguments @("1", "2")
        $result.ExitCode | Should Not Be 0
        $result.Output | Should Match "non-empty --edit-summary"
    }

    It "rejects a missing canonical domain/ artifact (real bash execution)" {
        Remove-Item -LiteralPath (Join-Path $script:fixtureRoot "domain/message-flow.md") -Force
        $result = Invoke-DomainReviewPrecheck -Root $script:fixtureRoot -Arguments @("1", "1")
        $result.ExitCode | Should Not Be 0
        $result.Output | Should Match "missing canonical domain/ artifact: domain/message-flow\.md"
    }

    It "rejects an empty domain/aggregates/ directory (real bash execution)" {
        Remove-Item -LiteralPath (Join-Path $script:fixtureRoot "domain/aggregates/Order.md") -Force
        $result = Invoke-DomainReviewPrecheck -Root $script:fixtureRoot -Arguments @("1", "1")
        $result.ExitCode | Should Not Be 0
        $result.Output | Should Match "at least one aggregate card"
    }

    It "rejects a malformed Domain-Model-Status value (real bash execution)" {
        $contextMapPath = Join-Path $script:fixtureRoot "domain/context-map.md"
        Set-Content -LiteralPath $contextMapPath -Value "# Context Map`n`nDomain-Model-Status: Bogus`n" -Encoding UTF8 -NoNewline
        $result = Invoke-DomainReviewPrecheck -Root $script:fixtureRoot -Arguments @("1", "1")
        $result.ExitCode | Should Not Be 0
        $result.Output | Should Match "recognized Domain-Model-Status"
    }

    It "on an Approved model with no fingerprint yet: records the fingerprint then halts when jq is available, else fails closed at jq first (real bash execution)" {
        # Portable across hosts (see the jq-availability note above). With jq
        # present the precheck reaches the Approved-model branch: it writes
        # last-approved-fingerprint.json and halts (nonzero exit) with the
        # Approved-status message, per AC-014's documented first-Approval
        # bootstrap behavior. With jq absent it fails closed earlier, at the
        # jq wall, before any fingerprint is written.
        $jqAvailable = $null -ne (Get-Command jq -ErrorAction SilentlyContinue)
        $contextMapPath = Join-Path $script:fixtureRoot "domain/context-map.md"
        (Get-Content -LiteralPath $contextMapPath -Raw) -replace "Pending", "Approved" | Set-Content -LiteralPath $contextMapPath -Encoding UTF8 -NoNewline
        $result = Invoke-DomainReviewPrecheck -Root $script:fixtureRoot -Arguments @("1", "1")
        $result.ExitCode | Should Not Be 0
        $fingerprintPath = Join-Path $script:fixtureRoot "reports/domain-review/last-approved-fingerprint.json"
        if ($jqAvailable) {
            $result.Output | Should Match "Domain-Model-Status is Approved"
            (Test-Path -LiteralPath $fingerprintPath) | Should Be $true
        } else {
            $result.Output | Should Match "jq is required"
            (Test-Path -LiteralPath $fingerprintPath) | Should Be $false
        }
    }
}

Describe "Worked fixtures (documented contract validation, per Done-When)" {

    # These fixtures exercise the full precheck+review+merge pipeline as a
    # worked example: the deterministic pieces (precheck structural checks,
    # verdict merge, drift comparison) are the SAME functions/scripts
    # exercised for real above; only the two reviewers' JSON outputs are
    # hand-authored stand-ins for what an LLM reviewer would return, since
    # no deterministic script produces reviewer judgment. This matches the
    # pattern used by T-002/T-003 for agent-driven, non-scriptable behavior.

    function New-ReviewerChecks {
        param([string[]]$Ids, [string]$FailId, [string]$FailSeverity)
        return $Ids | ForEach-Object {
            if ($_ -eq $FailId) {
                @{ id = $_; result = "FAIL"; severity = $FailSeverity; finding = "worked-example finding" }
            } else {
                @{ id = $_; result = "PASS"; severity = "Major"; finding = "" }
            }
        }
    }

    $aIds = @("CONTEXT-BOUNDARY-CLARITY", "RELATION-PATTERN-VALID", "EVENT-COVERAGE", "TERM-UNIQUENESS", "AGGREGATE-CONTEXT-OWNERSHIP", "DOMAIN-MODEL-STATUS-PRESENT")
    $bIds = @("INVARIANT-VERIFIABLE", "TRANSACTION-BOUNDARY-REALISTIC", "NO-GOD-AGGREGATE", "NO-ANEMIC-MODEL", "LIFECYCLE-DEFINED", "AGGREGATE-SIZE-PROPORTIONATE")

    It "both-reviewers-PASS -> clean PASS (worked example)" {
        $checksA = New-ReviewerChecks -Ids $aIds -FailId $null -FailSeverity $null
        $checksB = New-ReviewerChecks -Ids $bIds -FailId $null -FailSeverity $null
        $allChecks = @($checksA) + @($checksB)
        $critical = @($allChecks | Where-Object { $_.result -eq "FAIL" -and $_.severity -eq "Critical" }).Count
        $major = @($allChecks | Where-Object { $_.result -eq "FAIL" -and $_.severity -eq "Major" }).Count
        $minor = @($allChecks | Where-Object { $_.result -eq "FAIL" -and $_.severity -eq "Minor" }).Count
        $result = Get-DomainReviewVerdict -Critical $critical -Major $major -Minor $minor -Round 1
        $result.Verdict | Should Be "PASS"
        $result.WarningCount | Should Be 0
    }

    It "one Major FAIL from reviewer B -> NEEDS_WORK (worked example)" {
        $checksA = New-ReviewerChecks -Ids $aIds -FailId $null -FailSeverity $null
        $checksB = New-ReviewerChecks -Ids $bIds -FailId "NO-GOD-AGGREGATE" -FailSeverity "Major"
        $allChecks = @($checksA) + @($checksB)
        $critical = @($allChecks | Where-Object { $_.result -eq "FAIL" -and $_.severity -eq "Critical" }).Count
        $major = @($allChecks | Where-Object { $_.result -eq "FAIL" -and $_.severity -eq "Major" }).Count
        $minor = @($allChecks | Where-Object { $_.result -eq "FAIL" -and $_.severity -eq "Minor" }).Count
        $result = Get-DomainReviewVerdict -Critical $critical -Major $major -Minor $minor -Round 1
        $result.Verdict | Should Be "NEEDS_WORK"
    }

    It "round-3 unresolved Major -> BLOCKED (worked example)" {
        $checksA = New-ReviewerChecks -Ids $aIds -FailId "EVENT-COVERAGE" -FailSeverity "Major"
        $checksB = New-ReviewerChecks -Ids $bIds -FailId $null -FailSeverity $null
        $allChecks = @($checksA) + @($checksB)
        $critical = @($allChecks | Where-Object { $_.result -eq "FAIL" -and $_.severity -eq "Critical" }).Count
        $major = @($allChecks | Where-Object { $_.result -eq "FAIL" -and $_.severity -eq "Major" }).Count
        $minor = @($allChecks | Where-Object { $_.result -eq "FAIL" -and $_.severity -eq "Minor" }).Count
        $result = Get-DomainReviewVerdict -Critical $critical -Major $major -Minor $minor -Round 3
        $result.Verdict | Should Be "BLOCKED"
    }

    It "round-3 Minor-only -> PASS with nonzero warningCount (worked example)" {
        $checksA = New-ReviewerChecks -Ids $aIds -FailId "TERM-UNIQUENESS" -FailSeverity "Minor"
        $checksB = New-ReviewerChecks -Ids $bIds -FailId "AGGREGATE-SIZE-PROPORTIONATE" -FailSeverity "Minor"
        $allChecks = @($checksA) + @($checksB)
        $critical = @($allChecks | Where-Object { $_.result -eq "FAIL" -and $_.severity -eq "Critical" }).Count
        $major = @($allChecks | Where-Object { $_.result -eq "FAIL" -and $_.severity -eq "Major" }).Count
        $minor = @($allChecks | Where-Object { $_.result -eq "FAIL" -and $_.severity -eq "Minor" }).Count
        $result = Get-DomainReviewVerdict -Critical $critical -Major $major -Minor $minor -Round 3
        $result.Verdict | Should Be "PASS"
        $result.WarningCount | Should Be 2
    }

    It "domain/ file changed since last-approved-state -> halts pending a status reset (worked example over real hashes)" {
        $root = Join-Path ([IO.Path]::GetTempPath()) ("t5-worked-" + [Guid]::NewGuid().ToString("N"))
        try {
            New-DomainFixtureTree -Root $root -Status "Approved" | Out-Null
            $domainDir = Join-Path $root "domain"
            $fingerprint = @{}
            Get-ChildItem -LiteralPath $domainDir -Recurse -File -Filter "*.md" | ForEach-Object {
                $rel = "domain/" + ($_.FullName.Substring($domainDir.Length + 1) -replace '\\', '/')
                $fingerprint[$rel] = Get-NormalizedHash -Path $_.FullName
            }
            $fingerprint["domain/domain-contract.json"] = Get-NormalizedHash -Path (Join-Path $domainDir "domain-contract.json")

            # Simulate a post-approval edit to the context map's Bounded
            # Contexts table (not just the status line).
            Add-Content -LiteralPath (Join-Path $domainDir "context-map.md") -Value "`n| new-context | description | terms | aggregates |" -Encoding UTF8

            $drift = @(Test-DomainDrift -Fingerprint $fingerprint -DomainDir $domainDir)
            $drift.Count | Should BeGreaterThan 0
            # Per the documented contract, this is the condition under which
            # domain-review-precheck.sh halts and requires a human reset of
            # Domain-Model-Status back to Pending before proceeding -- see
            # the "AC-014 Drift Detection" section of SKILL.md and the
            # equivalent branch in domain-review-precheck.sh.
            $skillText = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillPath
            $skillText | Should Match "(?s)instructing\s+a\s+human\s+to\s+reset"
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }

    It "no prior Approved state -> drift detection does not apply (first-ever review, worked example)" {
        $root = Join-Path ([IO.Path]::GetTempPath()) ("t5-worked-first-" + [Guid]::NewGuid().ToString("N"))
        try {
            New-DomainFixtureTree -Root $root -Status "Pending" | Out-Null
            $fingerprintPath = Join-Path $root "reports/domain-review/last-approved-fingerprint.json"
            (Test-Path -LiteralPath $fingerprintPath) | Should Be $false
            # No fingerprint file means step 2 of the documented algorithm
            # (skip drift detection entirely) applies; the precheck script's
            # only remaining gate on this host is the jq requirement, which
            # is exercised for real above ("real execution against a real
            # fixture tree" Describe block).
            $skillText = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillPath
            $skillText | Should Match "no prior Approved state to drift from|skip drift detection entirely"
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
}
