#
# T-011 cross-model-verify wiring for the domain review gate -- tdd Pester test
#
# Required Workflow for T-011 is "tdd" (Risk: high). Unlike T-005's gate
# (whose reviewers are LLM subagents with no deterministic harness), this
# task's core mechanism -- prepare-panelist-input.sh and check-cross-model.sh
# -- is pure bash/python3, with ZERO dependency on jq (confirmed: `grep -c
# jq` on both scripts returns 0). This host has bash.exe and a real python
# interpreter (see "Environment constraint" below for a PATH-shim caveat),
# so this file achieves REAL, FULL END-TO-END execution of both scripts for
# every fixture in the Done-When list -- a strictly higher evidence bar than
# T-005's precheck-script tests, which were blocked at a jq wall.
#
# What IS real execution in this file:
#
#   1. prepare-panelist-input.sh, invoked for real via bash.exe against a
#      real fixture domain/ tree: (a) consent-denied case (no tasks.md
#      section for the pseudo-feature, no SDD_SUDO) exits 1 with the
#      documented message: this is the REAL confirmation, not a documented
#      assumption, that design.md's Assumptions citation is accurate --
#      domain/ has no tasks.md-mediated consent path; (b) consent-granted
#      case under a test-scaffolding SDD_SUDO token
#      (SDD_SUDO_SKIP_SIG=1, the script's own documented test-only escape
#      hatch -- see prepare-panelist-input.sh's file-header comment) writes
#      a real sanitized bundle and prints a real sha256 digest.
#
#   2. check-cross-model.sh, invoked for real via bash.exe against real,
#      hand-authored panelist verdict JSON fixtures placed on disk by this
#      test: clean two-vendor PASS, single-vendor diversity-FAIL (the
#      observable shape of a panelist-unavailable slot), two-vendor
#      consensus mismatch (one PASS, one NEEDS_WORK), digest mismatch, and
#      zero verdict files (every panelist unavailable). Each produces a
#      real cross-model-aggregate/v1 JSON read back and asserted against.
#
#   3. The "diversity-FAIL / consensus-FAIL / digest-mismatch -> this skill
#      must set requires_human_decision and record panelist-unavailable"
#      translation logic -- reimplemented here as a small, dependency-free
#      PowerShell function (Get-CrossModelGateDecision) that mirrors the
#      documented decision table in domain-review-loop/SKILL.md's "Running
#      the deterministic gate" section line-for-line. This is real execution
#      of the LOGIC under test against the REAL aggregate JSON produced by
#      step 2's real script invocations -- not a simulation of the scripts'
#      own output.
#
# What is DOCUMENTED CONTRACT VALIDATION (structural checks against prose),
# consistent with the pattern established by T-002/T-003/T-005's sibling
# test files for agent-driven, non-scriptable behavior:
#
#   4. Structural assertions against domain-review-loop/SKILL.md's new
#      "Cross-model verification (T-011)" section: the SDD_SUDO-only
#      consent path, the bundle-sanitization discipline (B4 boundary), the
#      panelist-unavailable / vendor-mismatch handling text, and the
#      never-auto-continue boundary lines. Actually invoking two LLM
#      panelist subagents (sdd-panelist-gpt / sdd-panelist-gemini) has no
#      deterministic harness -- there is no script that produces their
#      judgment -- so that part of the pipeline is validated as documented
#      prose only, exactly as T-005 did for domain-reviewer-a/b.
#
# Per this task's instruction, worked/documented fixtures stand in only for
# the parts that inherently require an LLM panelist's judgment (the actual
# content of a panelist verdict's PASS/NEEDS_WORK call); every deterministic
# mechanical step (consent gate, sanitization, digest computation, consensus
# arithmetic, diversity arithmetic, divergence arithmetic) is exercised with
# real code, real files, real bash/python3 execution, and real hashes.
#
# ASCII-only: no non-ASCII literal characters appear anywhere in this file
# (BOM-less .ps1 is read as ANSI on this Windows environment).

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$skillPath = Join-Path $repositoryRoot "plugins/sdd-domain/skills/domain-review-loop/SKILL.md"
$preparePanelistScript = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh"
$checkCrossModelScript = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/check-cross-model.sh"

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

# --- Environment constraint: WindowsApps python3.exe alias stub is broken --
#
# On this host, `python3` on PATH resolves to
# C:\Users\<user>\AppData\Local\Microsoft\WindowsApps\python3.exe, which is
# a Windows Store app-execution-alias stub. It prints "Python" and exits
# nonzero instead of running any script, regardless of caller (confirmed
# identically from a plain shell and from bash.exe launched via
# PowerShell's `&` operator). A real interpreter IS installed at
# C:\Users\<user>\AppData\Local\Programs\Python\Python314\python.exe (or
# discoverable via `py -3` launcher on some hosts); both scripts under test
# unconditionally invoke the bare command name `python3` and provide no
# override. This is a pre-existing, host-level PATH-shadowing defect, not
# something introduced by this task's SKILL.md change -- the same class of
# environment constraint recorded in project memory for `jq`
# (sdd-forge-windows-jq-gate-scripts) and documented by T-005 for the same
# reason.
#
# Workaround for real-execution evidence: build a small shim directory
# containing only a `python3` (no extension; bash's shebangless `command -v
# python3` / direct invocation resolves extension-less names first on
# MSYS/Git-Bash) that is a copy of a real, working python executable, and
# prepend that directory to PATH for the duration of the bash.exe child
# process only. This does not alter the system PATH or any other process.
function Get-WorkingPythonPath {
    $candidates = @(
        "C:\Users\J0138462\AppData\Local\Programs\Python\Python314\python.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    # Fall back to scanning Get-Command for any python*.exe that actually runs.
    $found = Get-Command python.exe -All -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -notmatch 'WindowsApps' } |
        Select-Object -First 1 -ExpandProperty Source
    return $found
}

$script:workingPython = Get-WorkingPythonPath
$script:python3ShimDir = $null
if ($null -ne $script:workingPython) {
    $script:python3ShimDir = Join-Path ([IO.Path]::GetTempPath()) ("t011-py3shim-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $script:python3ShimDir | Out-Null
    Copy-Item -LiteralPath $script:workingPython -Destination (Join-Path $script:python3ShimDir "python3.exe") -Force
}

# --- Helper: invoke a bash script for real, with the python3 shim on PATH --
function Invoke-BashScript {
    param(
        [Parameter(Mandatory)][string]$ScriptPath,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [string[]]$Arguments = @(),
        [hashtable]$EnvVars = @{}
    )
    if ($null -eq $script:bashExe) { throw "bash.exe not found on this host" }

    $driveLetter = $ScriptPath.Substring(0, 1).ToLowerInvariant()
    $rest = $ScriptPath.Substring(2) -replace '\\', '/'
    $unixScriptPath = "/$driveLetter$rest"

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $savedEnv = @{}
    try {
        foreach ($key in $EnvVars.Keys) {
            $savedEnv[$key] = [Environment]::GetEnvironmentVariable($key)
            [Environment]::SetEnvironmentVariable($key, $EnvVars[$key])
        }
        $savedPath = $env:Path
        if ($null -ne $script:python3ShimDir) {
            $env:Path = "$script:python3ShimDir;$env:Path"
        }
        $previousLocation = Get-Location
        Set-Location -LiteralPath $WorkingDirectory
        try {
            $allArgs = @($unixScriptPath) + $Arguments
            $output = & $script:bashExe @allArgs 2>&1
            $exitCode = $LASTEXITCODE
        } finally {
            Set-Location -LiteralPath $previousLocation
            $env:Path = $savedPath
        }
    } finally {
        foreach ($key in $EnvVars.Keys) {
            [Environment]::SetEnvironmentVariable($key, $savedEnv[$key])
        }
        $ErrorActionPreference = $previousPreference
    }
    $textOutput = ($output | ForEach-Object { $_.ToString() }) -join "`n"
    return @{ Output = $textOutput; ExitCode = $exitCode }
}

# --- BOM-less UTF-8 writer -------------------------------------------------
#
# Real bug found while wiring this test file: PowerShell 5.1's
# `Set-Content -Encoding UTF8` always prepends a UTF-8 byte-order-mark
# (confirmed: first three bytes are 0xEF 0xBB 0xBF). prepare-panelist-input.sh
# reads fixture files with `cat` (raw bytes, BOM preserved) and feeds them to
# its python3 sanitizer subprocess. On this host, python3's default stdout
# encoding is the Windows ANSI code page (cp932, Japanese locale), which
# cannot encode the BOM character (U+FEFF) when the sanitizer writes its
# result back out, raising UnicodeEncodeError and making the script exit 2
# ("sanitization failed") even though consent was correctly granted. This is
# a fixture-authoring / host-locale interaction, not a defect in
# prepare-panelist-input.sh itself (a UTF-8-locale CI host would not hit
# this) -- worked around here by writing every fixture file without a BOM,
# via .NET's UTF8Encoding($false) instead of PowerShell's Set-Content.
function Set-Utf8NoBom {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Value)
    [IO.File]::WriteAllText($Path, $Value, (New-Object Text.UTF8Encoding $false))
}

# --- Fixture builder: a real, on-disk domain/ tree + project root markers --
function New-DomainCrossModelFixtureRoot {
    param([Parameter(Mandatory)][string]$Root)
    $domainDir = Join-Path $Root "domain"
    New-Item -ItemType Directory -Force -Path (Join-Path $domainDir "aggregates") | Out-Null
    Set-Utf8NoBom -Path (Join-Path $Root "AGENTS.md") -Value "# fixture project"

    Set-Utf8NoBom -Path (Join-Path $domainDir "domain-story.md") -Value "# Domain Story`n`ncontent about OrderContext`n"
    Set-Utf8NoBom -Path (Join-Path $domainDir "event-storming.md") -Value "# Event Storming`n`nOrderPlaced event`n"
    Set-Utf8NoBom -Path (Join-Path $domainDir "ubiquitous-language.md") -Value "# Ubiquitous Language`n`nOrder term, forbidden order-item`n"
    Set-Utf8NoBom -Path (Join-Path $domainDir "context-map.md") -Value "# Context Map`n`nDomain-Model-Status: Reviewed`n`nOrdering context`n"
    Set-Utf8NoBom -Path (Join-Path $domainDir "message-flow.md") -Value "# Message Flow`n`nPlaceOrder command`n"
    Set-Utf8NoBom -Path (Join-Path $domainDir "c4-container.md") -Value "# C4 Container`n`nWeb app`n"
    Set-Utf8NoBom -Path (Join-Path $domainDir "aggregates/Order.md") -Value "# Order aggregate`n`nRoot: Order`n"
    Set-Utf8NoBom -Path (Join-Path $domainDir "domain-contract.json") -Value '{"schema":"domain-contract/v1"}'

    return $domainDir
}

function New-SudoTokenFile {
    param([Parameter(Mandatory)][string]$Root)
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $expires = $now + 3600
    $repoCanonical = (Get-Item -LiteralPath $Root).FullName.TrimEnd('\')
    # Convert to the same forward-slash form the sh script's `pwd -P` under
    # Git Bash would produce is not required: prepare-panelist-input.sh's
    # repo-binding check re-resolves both sides via `cd ... && pwd -P`, so a
    # native Windows path here round-trips correctly through bash's cd/pwd.
    $lines = @(
        "enabled-by: human via /sdd-sudo",
        "enabled-at: test-fixture",
        "issuer: test@fixture-host",
        "nonce: 0123456789abcdef0123456789abcdef",
        "repo: $repoCanonical",
        "issued-epoch: $now",
        "expires-epoch: $expires",
        "duration: 1h",
        "sig: 0000000000000000000000000000000000000000000000000000000000000000"
    )
    Set-Utf8NoBom -Path (Join-Path $Root "SDD_SUDO") -Value (($lines -join "`n") + "`n")
}

function New-PanelistVerdict {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Vendor,
        [Parameter(Mandatory)][string]$Model,
        [Parameter(Mandatory)][string]$Verdict,
        [Parameter(Mandatory)][string]$InputDigest,
        [array]$Findings = @()
    )
    $obj = [ordered]@{
        schema       = "cross-model-verdict/v1"
        task_id      = "DM-001"
        feature      = "sdd-domain-model"
        vendor       = $Vendor
        model        = $Model
        verdict      = $Verdict
        findings     = $Findings
        blind        = $true
        input_digest = $InputDigest
        consent      = @{ kind = "sudo"; ref = "SDD_SUDO" }
    }
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    Set-Utf8NoBom -Path $Path -Value ($obj | ConvertTo-Json -Depth 6)
}

# --- Real, dependency-free reimplementation of domain-review-loop's decision
# table from the "Running the deterministic gate" section of SKILL.md -----
function Get-CrossModelGateDecision {
    param(
        [Parameter(Mandatory)][int]$ExitCode,
        [Parameter(Mandatory)][string]$Result,
        [int]$VendorsDistinct = 0,
        [int]$NonAnthropicCount = 0
    )
    if ($ExitCode -eq 0 -and $Result -eq "PASS") {
        return @{ RequiresHumanDecision = $false; PanelistUnavailable = $false; Proceed = $true }
    }
    if ($Result -eq "FAIL" -and ($VendorsDistinct -lt 2 -or $NonAnthropicCount -lt 1)) {
        # Diversity-check failure shape == a configured panelist slot did not
        # produce a usable verdict (offline, errored, or never invoked).
        return @{ RequiresHumanDecision = $true; PanelistUnavailable = $true; Proceed = $false }
    }
    # Any other FAIL/NEEDS_HUMAN (consensus mismatch, digest mismatch,
    # evaluator divergence) is a vendor mismatch, not an availability gap.
    return @{ RequiresHumanDecision = $true; PanelistUnavailable = $false; Proceed = $false }
}

Describe "Environment: real bash + python3 availability for cross-model scripts" {
    It "bash.exe is available on this host" {
        $script:bashExe | Should Not Be $null
    }
    It "a working (non-WindowsApps-stub) python3 interpreter was located for the shim" {
        $script:workingPython | Should Not Be $null
    }
}

Describe "prepare-panelist-input.sh: real execution, consent gate (design.md Assumptions verification)" {

    BeforeEach {
        $script:fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("t011-consent-" + [Guid]::NewGuid().ToString("N"))
        New-DomainCrossModelFixtureRoot -Root $script:fixtureRoot | Out-Null
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:fixtureRoot) {
            Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force
        }
    }

    It "REAL: denies consent when no tasks.md section and no SDD_SUDO exist (confirms design.md's cited residual risk)" {
        $result = Invoke-BashScript -ScriptPath $preparePanelistScript -WorkingDirectory $script:fixtureRoot -Arguments @(
            "--task", "DM-001", "--feature", "sdd-domain-model", "--input", "domain/",
            "--project-root", $script:fixtureRoot,
            "--out", "reports/domain-review/attempt-1/round-1/cross-model/DM-001.panelist-input.txt"
        )
        $result.ExitCode | Should Be 1
        $result.Output | Should Match "consent denied for DM-001"
        $result.Output | Should Match "no Cross-Model: enabled flag"
        $result.Output | Should Match "no valid SDD_SUDO token"
        (Test-Path -LiteralPath (Join-Path $script:fixtureRoot "reports/domain-review/attempt-1/round-1/cross-model/DM-001.panelist-input.txt")) | Should Be $false
    }

    It "REAL: this confirms domain-review-loop cannot rely on a tasks.md Cross-Model flag -- there is no specs/sdd-domain-model/tasks.md at all" {
        (Test-Path -LiteralPath (Join-Path $script:fixtureRoot "specs/sdd-domain-model/tasks.md")) | Should Be $false
    }

    It "REAL: grants consent and writes a sanitized bundle with a valid SDD_SUDO token (SDD_SUDO_SKIP_SIG test scaffolding)" {
        if ($null -eq $script:workingPython) {
            Set-TestInconclusive "no working python3 interpreter found on this host for the shim"
        }
        New-SudoTokenFile -Root $script:fixtureRoot
        $outRelative = "reports/domain-review/attempt-1/round-1/cross-model/DM-001.panelist-input.txt"
        $result = Invoke-BashScript -ScriptPath $preparePanelistScript -WorkingDirectory $script:fixtureRoot -Arguments @(
            "--task", "DM-001", "--feature", "sdd-domain-model", "--input", "domain/",
            "--project-root", $script:fixtureRoot,
            "--out", $outRelative
        ) -EnvVars @{ SDD_SUDO_SKIP_SIG = "1" }

        $result.ExitCode | Should Be 0
        $result.Output.Trim() | Should Match "^[0-9a-f]{64}$"

        $outPath = Join-Path $script:fixtureRoot $outRelative
        (Test-Path -LiteralPath $outPath) | Should Be $true
        $bundleText = Get-Content -Raw -LiteralPath $outPath
        $bundleText | Should Match "# consent: sudo"
        $bundleText | Should Match "input_digest: [0-9a-f]{64}"
        $bundleText | Should Match "Ordering context"
    }

    It "REAL: the sanitized bundle never contains the literal SDD_SUDO signature value" {
        if ($null -eq $script:workingPython) {
            Set-TestInconclusive "no working python3 interpreter found on this host for the shim"
        }
        New-SudoTokenFile -Root $script:fixtureRoot
        $outRelative = "reports/domain-review/attempt-1/round-1/cross-model/DM-001.panelist-input.txt"
        Invoke-BashScript -ScriptPath $preparePanelistScript -WorkingDirectory $script:fixtureRoot -Arguments @(
            "--task", "DM-001", "--feature", "sdd-domain-model", "--input", "domain/",
            "--project-root", $script:fixtureRoot,
            "--out", $outRelative
        ) -EnvVars @{ SDD_SUDO_SKIP_SIG = "1" } | Out-Null

        $bundleText = Get-Content -Raw -LiteralPath (Join-Path $script:fixtureRoot $outRelative)
        $bundleText | Should Not Match "0000000000000000000000000000000000000000000000000000000000000000"
    }
}

Describe "check-cross-model.sh: real execution against real panelist verdict fixtures" {

    BeforeEach {
        $script:gateRoot = Join-Path ([IO.Path]::GetTempPath()) ("t011-gate-" + [Guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Force -Path $script:gateRoot | Out-Null
        $script:testDigest = "639d725556c361e12c0a3a1b6c8da234465623e63102916558cdec689d4b516e"
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:gateRoot) {
            Remove-Item -LiteralPath $script:gateRoot -Recurse -Force
        }
    }

    It "REAL: clean two-vendor PASS -> result PASS, requires_human_decision false, exit 0" {
        if ($null -eq $script:workingPython) { Set-TestInconclusive "no working python3 interpreter" }
        $specRoot = "reports/domain-review/attempt-1/round-1"
        $vdir = Join-Path $script:gateRoot "$specRoot/sdd-domain-model/verification"
        New-PanelistVerdict -Path (Join-Path $vdir "DM-001.panelist-openai.verdict.json") -Vendor "openai" -Model "gpt-5.5" -Verdict "PASS" -InputDigest $script:testDigest
        New-PanelistVerdict -Path (Join-Path $vdir "DM-001.panelist-google.verdict.json") -Vendor "google" -Model "gemini-3-pro" -Verdict "PASS" -InputDigest $script:testDigest

        $result = Invoke-BashScript -ScriptPath $checkCrossModelScript -WorkingDirectory $script:gateRoot -Arguments @(
            "--task", "DM-001", "--feature", "sdd-domain-model",
            "--spec-root", $specRoot, "--expect-digest", $script:testDigest
        )
        $result.ExitCode | Should Be 0
        $result.Output | Should Match "consensus PASS"

        $agg = Get-Content -Raw -LiteralPath (Join-Path $vdir "DM-001.cross-model.json") | ConvertFrom-Json
        $agg.result | Should Be "PASS"
        $agg.requires_human_decision | Should Be $false
        $agg.vendors_distinct | Should Be 2

        $decision = Get-CrossModelGateDecision -ExitCode $result.ExitCode -Result $agg.result -VendorsDistinct $agg.vendors_distinct -NonAnthropicCount $agg.non_anthropic_count
        $decision.Proceed | Should Be $true
        $decision.RequiresHumanDecision | Should Be $false
        $decision.PanelistUnavailable | Should Be $false
    }

    It "REAL: only one vendor slot collected -> diversity FAIL, translated to panelist-unavailable + requires_human_decision, no auto-continue" {
        if ($null -eq $script:workingPython) { Set-TestInconclusive "no working python3 interpreter" }
        $specRoot = "reports/domain-review/attempt-1/round-2"
        $vdir = Join-Path $script:gateRoot "$specRoot/sdd-domain-model/verification"
        New-PanelistVerdict -Path (Join-Path $vdir "DM-001.panelist-openai.verdict.json") -Vendor "openai" -Model "gpt-5.5" -Verdict "PASS" -InputDigest $script:testDigest
        # Google/Gemini slot deliberately absent -- simulates panelist-unavailable.

        $result = Invoke-BashScript -ScriptPath $checkCrossModelScript -WorkingDirectory $script:gateRoot -Arguments @(
            "--task", "DM-001", "--feature", "sdd-domain-model",
            "--spec-root", $specRoot, "--expect-digest", $script:testDigest
        )
        $result.ExitCode | Should Be 1
        $result.Output | Should Match "diversity check failed"

        $agg = Get-Content -Raw -LiteralPath (Join-Path $vdir "DM-001.cross-model.json") | ConvertFrom-Json
        $agg.result | Should Be "FAIL"
        $agg.vendors_distinct | Should Be 1

        # The gate script itself does NOT set requires_human_decision for a
        # diversity failure (confirmed above: aggregate has
        # requires_human_decision: false at the script level) -- this is
        # exactly why domain-review-loop's own translation step (documented
        # in SKILL.md) must set it. Real-executed proof of that gap:
        $agg.requires_human_decision | Should Be $false

        $decision = Get-CrossModelGateDecision -ExitCode $result.ExitCode -Result $agg.result -VendorsDistinct $agg.vendors_distinct -NonAnthropicCount $agg.non_anthropic_count
        $decision.Proceed | Should Be $false
        $decision.RequiresHumanDecision | Should Be $true
        $decision.PanelistUnavailable | Should Be $true
    }

    It "REAL: zero verdict files (every panelist unavailable) -> tool error exit 2, no aggregate written" {
        $specRoot = "reports/domain-review/attempt-1/round-3"
        $vdir = Join-Path $script:gateRoot "$specRoot/sdd-domain-model/verification"
        New-Item -ItemType Directory -Force -Path $vdir | Out-Null

        $result = Invoke-BashScript -ScriptPath $checkCrossModelScript -WorkingDirectory $script:gateRoot -Arguments @(
            "--task", "DM-001", "--feature", "sdd-domain-model", "--spec-root", $specRoot
        )
        $result.ExitCode | Should Be 2
        $result.Output | Should Match "no verdict files found"
        (Test-Path -LiteralPath (Join-Path $vdir "DM-001.cross-model.json")) | Should Be $false
    }

    It "REAL: two-vendor consensus mismatch (one PASS, one NEEDS_WORK) -> vendor mismatch, requires_human_decision path" {
        if ($null -eq $script:workingPython) { Set-TestInconclusive "no working python3 interpreter" }
        $specRoot = "reports/domain-review/attempt-1/round-4"
        $vdir = Join-Path $script:gateRoot "$specRoot/sdd-domain-model/verification"
        New-PanelistVerdict -Path (Join-Path $vdir "DM-001.panelist-openai.verdict.json") -Vendor "openai" -Model "gpt-5.5" -Verdict "PASS" -InputDigest $script:testDigest
        New-PanelistVerdict -Path (Join-Path $vdir "DM-001.panelist-google.verdict.json") -Vendor "google" -Model "gemini-3-pro" -Verdict "NEEDS_WORK" -InputDigest $script:testDigest -Findings @(
            @{ severity = "Major"; ref = "domain/context-map.md"; note = "ambiguous relation pattern" }
        )

        $result = Invoke-BashScript -ScriptPath $checkCrossModelScript -WorkingDirectory $script:gateRoot -Arguments @(
            "--task", "DM-001", "--feature", "sdd-domain-model",
            "--spec-root", $specRoot, "--expect-digest", $script:testDigest
        )
        $result.ExitCode | Should Be 1
        $result.Output | Should Match "consensus FAIL"
        $result.Output | Should Match "not all verdicts are PASS"

        $agg = Get-Content -Raw -LiteralPath (Join-Path $vdir "DM-001.cross-model.json") | ConvertFrom-Json
        $agg.result | Should Be "FAIL"
        $agg.all_pass | Should Be $false
        $agg.vendors_distinct | Should Be 2

        $decision = Get-CrossModelGateDecision -ExitCode $result.ExitCode -Result $agg.result -VendorsDistinct $agg.vendors_distinct -NonAnthropicCount $agg.non_anthropic_count
        $decision.Proceed | Should Be $false
        $decision.RequiresHumanDecision | Should Be $true
        $decision.PanelistUnavailable | Should Be $false
    }

    It "REAL: digest mismatch -> vendor-mismatch-class FAIL, requires_human_decision path, no auto-continue" {
        if ($null -eq $script:workingPython) { Set-TestInconclusive "no working python3 interpreter" }
        $specRoot = "reports/domain-review/attempt-1/round-5"
        $vdir = Join-Path $script:gateRoot "$specRoot/sdd-domain-model/verification"
        New-PanelistVerdict -Path (Join-Path $vdir "DM-001.panelist-openai.verdict.json") -Vendor "openai" -Model "gpt-5.5" -Verdict "PASS" -InputDigest $script:testDigest
        New-PanelistVerdict -Path (Join-Path $vdir "DM-001.panelist-google.verdict.json") -Vendor "google" -Model "gemini-3-pro" -Verdict "PASS" -InputDigest $script:testDigest

        $wrongDigest = "0" * 64
        $result = Invoke-BashScript -ScriptPath $checkCrossModelScript -WorkingDirectory $script:gateRoot -Arguments @(
            "--task", "DM-001", "--feature", "sdd-domain-model",
            "--spec-root", $specRoot, "--expect-digest", $wrongDigest
        )
        $result.ExitCode | Should Be 1
        $result.Output | Should Match "input_digest mismatch"

        $agg = Get-Content -Raw -LiteralPath (Join-Path $vdir "DM-001.cross-model.json") | ConvertFrom-Json
        $agg.result | Should Be "FAIL"

        $decision = Get-CrossModelGateDecision -ExitCode $result.ExitCode -Result $agg.result -VendorsDistinct $agg.vendors_distinct -NonAnthropicCount $agg.non_anthropic_count
        $decision.Proceed | Should Be $false
        $decision.RequiresHumanDecision | Should Be $true
    }
}

Describe "Get-CrossModelGateDecision: decision-table unit tests (real execution)" {

    It "clean PASS -> proceed, no human decision required" {
        $d = Get-CrossModelGateDecision -ExitCode 0 -Result "PASS" -VendorsDistinct 2 -NonAnthropicCount 2
        $d.Proceed | Should Be $true
        $d.RequiresHumanDecision | Should Be $false
        $d.PanelistUnavailable | Should Be $false
    }

    It "diversity FAIL with vendors_distinct 0 (nothing collected) -> panelist-unavailable" {
        $d = Get-CrossModelGateDecision -ExitCode 2 -Result "FAIL" -VendorsDistinct 0 -NonAnthropicCount 0
        $d.PanelistUnavailable | Should Be $true
        $d.RequiresHumanDecision | Should Be $true
        $d.Proceed | Should Be $false
    }

    It "diversity FAIL with non_anthropic_count 0 (only anthropic collected) -> panelist-unavailable" {
        $d = Get-CrossModelGateDecision -ExitCode 1 -Result "FAIL" -VendorsDistinct 1 -NonAnthropicCount 0
        $d.PanelistUnavailable | Should Be $true
        $d.RequiresHumanDecision | Should Be $true
    }

    It "consensus FAIL with full diversity -> vendor mismatch, not panelist-unavailable" {
        $d = Get-CrossModelGateDecision -ExitCode 1 -Result "FAIL" -VendorsDistinct 2 -NonAnthropicCount 2
        $d.PanelistUnavailable | Should Be $false
        $d.RequiresHumanDecision | Should Be $true
        $d.Proceed | Should Be $false
    }

    It "NEEDS_HUMAN result (evaluator divergence) -> vendor mismatch path, requires human decision" {
        $d = Get-CrossModelGateDecision -ExitCode 1 -Result "NEEDS_HUMAN" -VendorsDistinct 2 -NonAnthropicCount 2
        $d.RequiresHumanDecision | Should Be $true
        $d.Proceed | Should Be $false
    }
}

Describe "domain-review-loop/SKILL.md: T-011 cross-model section (documented contract)" {

    BeforeAll {
        $script:skillText = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillPath
    }

    It "exists and still declares itself an internal, non-model-invocable skill (T-005 frontmatter untouched)" {
        Test-Path -LiteralPath $skillPath | Should Be $true
        $script:skillText | Should Match "disable-model-invocation: true"
        $script:skillText | Should Match "user-invocable: false"
    }

    It "retains every T-005 structural section untouched (additive-only extension)" {
        $script:skillText | Should Match "REVIEW_CONTEXT_OK"
        $script:skillText | Should Match "AC-014 Drift Detection"
        $script:skillText | Should Match "last-approved-fingerprint"
        $script:skillText | Should Match "Never write .Domain-Model-Status: Approved."
        $script:skillText | Should Match "(?s)must never\s+receive"
    }

    It "documents the T-011 cross-model section header" {
        $script:skillText | Should Match "## Cross-model verification \(T-011\)"
    }

    It "documents that the tasks.md-mediated consent flag cannot apply to domain/ and SDD_SUDO must be used instead" {
        $script:skillText | Should Match "SDD_SUDO"
        $script:skillText | Should Match "Cross-Model: enabled"
        $script:skillText | Should Match "no `.specs/<feature>/tasks.md`. section of its own|no task section named"
    }

    It "cites the exact file:line evidence from design.md's Assumptions for both scripts" {
        $script:skillText | Should Match "prepare-panelist-input\.sh:27-59|prepare-panelist-input\.sh.{0,20}89-95|prepare-panelist-input\.sh.{0,20}96-117"
        $script:skillText | Should Match "check-cross-model\.sh:35"
    }

    It "documents the B4 bundle-sanitization exclusion rule (role/system names only, no real person or customer names)" {
        $script:skillText | Should Match "B4"
        $script:skillText | Should Match "real person names"
        $script:skillText | Should Match "customer-identifying values|customer identifier"
    }

    It "documents prepare-panelist-input.sh and check-cross-model.sh invocation with domain/ as input" {
        $script:skillText | Should Match "prepare-panelist-input\.sh"
        $script:skillText | Should Match "check-cross-model\.sh"
        $script:skillText | Should Match "--input domain/"
    }

    It "documents the panelist verdict path inside the directory check-cross-model.sh actually reads (PR #93 Codex P1 regression)" {
        # check-cross-model.sh line 34 joins <spec-root>/<feature>/verification;
        # with --spec-root <round-dir> and --feature sdd-domain-model the
        # verdicts must be written to .../<round>/sdd-domain-model/verification/
        # -- NOT the bundle's cross-model/ directory, or the gate finds zero
        # verdict files and a PASS round can never complete.
        $script:skillText | Should Match "sdd-domain-model/verification/DM-001\.panelist-<vendor>\.verdict\.json"
    }

    It "documents panelist-unavailable recording and requires_human_decision blocking auto-continuation" {
        $script:skillText | Should Match "panelist-unavailable"
        $script:skillText | Should Match "requires_human_decision"
        $script:skillText | Should Match "Do not auto-continue|do not auto-continue|Never auto-continue"
    }

    It "documents vendor mismatch handling distinctly from panelist-unavailable" {
        $script:skillText | Should Match "vendor mismatch"
        $script:skillText | Should Match "not all verdicts are PASS|Critical finding|input_digest mismatch"
    }

    It "documents that a clean cross-model PASS is required before inviting Domain-Model-Status: Approved" {
        $script:skillText | Should Match "(?s)result:\s*.PASS.[\s\S]{0,200}requires_human_decision:\s*false"
        $script:skillText | Should Match "ready for .Domain-Model-Status:\s*Approved."
    }

    It "documents cross-model verification runs once per review-loop PASS, not per round or on NEEDS_WORK/BLOCKED" {
        $script:skillText | Should Match "(?s)required once\s+per review-loop PASS"
        $script:skillText | Should Match "never runs on .NEEDS_WORK. or .BLOCKED."
    }

    It "never instructs writing Domain-Model-Status: Approved anywhere in the new section (still human-only)" {
        $script:skillText | Should Match "This skill never sets .Domain-Model-Status: Approved. itself"
    }

    It "documents the Boundaries section extension for cross-model never-auto-continue and SDD_SUDO-only consent" {
        $script:skillText | Should Match "Never invoke cross-model-verify through the .Cross-Model: enabled."
        $script:skillText | Should Match "Never auto-continue past a cross-model vendor mismatch"
        $script:skillText | Should Match "Never send an unsanitized .domain/. bundle to a panelist"
    }

    It "still marks the reviewer sequence's own T-011 insert-point note, now pointing at the implemented section" {
        $script:skillText | Should Match "INSERT POINT \(T-011\)"
        $script:skillText | Should Match "implemented below"
    }
}

Describe "Worked example: panelist agent invocation (documented contract validation, per Done-When)" {

    # sdd-panelist-gpt / sdd-panelist-gemini are LLM subagents; there is no
    # deterministic script that produces their PASS/NEEDS_WORK judgment, so
    # this Describe block validates the documented contract only, matching
    # the pattern T-005 used for domain-reviewer-a/b's judgment calls. The
    # deterministic plumbing around their output (verdict file format,
    # consensus arithmetic, digest binding) is exercised for REAL above.

    BeforeAll {
        $script:skillText = Get-Content -Raw -Encoding UTF8 -LiteralPath $skillPath
    }

    It "names the reused panelist agents from sdd-quality-loop" {
        $script:skillText | Should Match "sdd-panelist-gpt"
        $script:skillText | Should Match "sdd-panelist-gemini"
    }

    It "documents blind, parallel, no-cross-talk invocation matching cross-model-verification-policy.md" {
        $script:skillText | Should Match "blind"
        $script:skillText | Should Match "parallel"
        $script:skillText | Should Match "no cross-talk|no visibility into the other panelist"
    }

    It "worked example: a vendor mismatch aggregate (hand-authored, mirrors the REAL fixture above) yields requires_human_decision true" {
        $aggregate = @{
            schema                  = "cross-model-aggregate/v1"
            task_id                 = "DM-001"
            feature                 = "sdd-domain-model"
            vendors_distinct        = 2
            non_anthropic_count     = 2
            all_pass                = $false
            any_critical            = $false
            result                  = "FAIL"
            requires_human_decision = $false
        }
        $decision = Get-CrossModelGateDecision -ExitCode 1 -Result $aggregate.result -VendorsDistinct $aggregate.vendors_distinct -NonAnthropicCount $aggregate.non_anthropic_count
        $decision.RequiresHumanDecision | Should Be $true
        $decision.PanelistUnavailable | Should Be $false
    }

    It "worked example: a panelist-unavailable aggregate (hand-authored, mirrors the REAL fixture above) records the unavailable slot" {
        $aggregate = @{
            vendors_distinct    = 1
            non_anthropic_count = 1
            result              = "FAIL"
        }
        $decision = Get-CrossModelGateDecision -ExitCode 1 -Result $aggregate.result -VendorsDistinct $aggregate.vendors_distinct -NonAnthropicCount $aggregate.non_anthropic_count
        $decision.PanelistUnavailable | Should Be $true
        $decision.RequiresHumanDecision | Should Be $true
    }
}
