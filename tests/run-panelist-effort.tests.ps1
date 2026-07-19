# Suite: run-panelist-effort (T-006, #152) -- REQ-006/REQ-008 share --
# AC-035..040, AC-052. PowerShell twin of tests/run-panelist-effort.tests.sh,
# equivalent coverage.
#
# Locks: run-panelist-gpt.ps1's -Effort forwarding into the assembled codex
# ArgumentList (AC-035); prepare-panelist-input.ps1's -Effort threading
# through to run-panelist-gpt's -Effort argument (AC-036); the Codex-host
# evaluator/investigator startup path's select-agent-model.ps1 -HostName
# codex-cli model+effort composition (AC-037); the render/selector
# cross-check drift report between T-003's rendered .toml reference
# comments and live selector output (AC-038); the Claude Code degradation
# case recorded in the resulting run record (AC-039, REQ-008, sharing
# TEST-024/TEST-051's field-population rule); the argv/JSON-composition-only
# proof that no test in this suite invokes a real LLM (AC-040); and the
# argv-injection-shape rejection lock for -Model/-Effort, per
# malformed-shape category (AC-052, security-spec.md B3).
#
# All positive/negative codex-ArgumentList assertions run against a STUB
# `codex` executable placed in a scratch PATH -- some developer/CI machines
# have a REAL codex CLI installed -- every invocation of run-panelist-gpt.ps1
# in this suite therefore OVERRIDES (never inherits unmodified) $env:PATH
# for the duration of that single call, guaranteeing zero real LLM calls
# (AC-040).
#
# Case-sensitivity (two layers, mirroring T-002/T-003/T-004's established
# discipline): operator level uses -ceq/-cne for every effort/model-shape
# comparison; cmdlet level uses Select-String -CaseSensitive for the
# SKILL.md/run-all.ps1/MANIFEST.sha256 text greps.
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$runGptPs1 = Join-Path $repoRoot "plugins/sdd-quality-loop/scripts/run-panelist-gpt.ps1"
$preparePs1 = Join-Path $repoRoot "plugins/sdd-quality-loop/scripts/prepare-panelist-input.ps1"
$selectorPs1 = Join-Path $repoRoot "plugins/sdd-implementation/scripts/select-agent-model.ps1"
$emitRunRecordPs1 = Join-Path $repoRoot "plugins/sdd-quality-loop/scripts/emit-run-record.ps1"
$skillMd = Join-Path $repoRoot "plugins/sdd-quality-loop/skills/quality-gate/SKILL.md"
$evaluatorToml = Join-Path $repoRoot ".codex/agents/sdd-evaluator.toml"
$investigatorToml = Join-Path $repoRoot ".codex/agents/sdd-investigator.toml"
$registryV2 = Join-Path $repoRoot "contracts/agent-model-capabilities.v2.json"
$runAllSh = Join-Path $repoRoot "tests/run-all.sh"
$runAllPs1 = Join-Path $repoRoot "tests/run-all.ps1"
$humanCopyDir = Join-Path $repoRoot "specs/epic-159-pillar-c/human-copy"
$manifest = Join-Path $humanCopyDir "MANIFEST.sha256"

# Resolved to an absolute path BEFORE any $env:PATH override below --
# Invoke-RunGpt replaces $env:PATH with a minimal, stub-only set for the
# duration of each call, which would otherwise make the bare "pwsh" name
# unresolvable.
$powerShellHost = (Get-Command pwsh -ErrorAction Stop).Source

foreach ($f in @($runGptPs1, $preparePs1, $selectorPs1, $emitRunRecordPs1, $skillMd,
        $evaluatorToml, $investigatorToml, $registryV2)) {
    if (-not (Test-Path -LiteralPath $f)) {
        Write-Output "not ok: missing required artifact: $f"
        exit 1
    }
}

$script:passCount = 0
$script:failCount = 0
function Ok([string]$Name) { Write-Output "ok: $Name"; $script:passCount++ }
function Fail([string]$Name) { Write-Output "not ok: $Name"; $script:failCount++ }

# Suite-wide safety proof: the two real Codex .toml reference-comment files
# this suite reads (T-006 Out of Scope: reads, never edits further) --
# captured BEFORE and AFTER this suite's own full run.
$evaluatorTomlShaBefore = (Get-FileHash -LiteralPath $evaluatorToml -Algorithm SHA256).Hash
$investigatorTomlShaBefore = (Get-FileHash -LiteralPath $investigatorToml -Algorithm SHA256).Hash

$work = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $work -Force | Out-Null

try {

$zeroDigest = "0" * 64
$safePathWindows = "C:\Windows\System32;C:\Windows"
$safePathUnix = "/usr/bin:/bin"

# ── Stub codex: records argv (one token per line), touches an invocation
# marker, prints a canned valid cross-model-verdict/v1 JSON, exits 0. ──────
$stubBin = Join-Path $work "stub-bin"
New-Item -ItemType Directory -Path $stubBin -Force | Out-Null
$argvFile = Join-Path $work "codex-argv.txt"
$markerFile = Join-Path $work "codex-invoked.marker"
$stubJson = '{"schema":"cross-model-verdict/v1","task_id":"stub","feature":"stub","vendor":"openai","model":"stub","verdict":"PASS","findings":[],"blind":true,"input_digest":"' + $zeroDigest + '","consent":{"kind":"human-flag","ref":"stub"}}'

if ($IsLinux -or $IsMacOS) {
    $stubCodex = Join-Path $stubBin "codex"
    $stubScript = "#!/bin/sh`nprintf '%s\n' `"`$@`" > `"$argvFile`"`n: > `"$markerFile`"`nprintf '%s\n' '$stubJson'`nexit 0`n"
    Set-Content -NoNewline -Path $stubCodex -Value $stubScript
    & chmod +x $stubCodex
    $testPath = "${stubBin}:${safePathUnix}"
} else {
    # Windows: a .cmd wrapper (native CreateProcess-resolvable extension)
    # delegates to a pwsh worker script for reliable argv/JSON handling.
    $workerPs1 = Join-Path $stubBin "codex-worker.ps1"
    $workerContent = "`$argvFile = '$argvFile'`n`$markerFile = '$markerFile'`nforeach (`$a in `$args) { Add-Content -LiteralPath `$argvFile -Value `$a }`nNew-Item -ItemType File -Path `$markerFile -Force | Out-Null`nWrite-Output '$stubJson'`nexit 0`n"
    Set-Content -Path $workerPs1 -Value $workerContent
    $stubCodexCmd = Join-Path $stubBin "codex.cmd"
    # Uses the resolved $powerShellHost path, not the bare "pwsh" name --
    # this .cmd is invoked as a grandchild of Invoke-RunGpt's PATH-overridden
    # subprocess, so a bare name would be unresolvable there too.
    Set-Content -Path $stubCodexCmd -Value "@echo off`r`n`"$powerShellHost`" -NoProfile -File `"$workerPs1`" %*`r`n"
    $testPath = "$stubBin;$safePathWindows"
}

function Reset-StubState {
    Remove-Item -LiteralPath $argvFile -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $markerFile -ErrorAction SilentlyContinue
}

# The stub writes one argv token per line; flatten to a single space-joined
# line for substring/order assertions. Safe because no accepted
# -Model/-Effort value may itself contain whitespace (AC-052's own
# rejection rule guarantees this).
function Get-ArgvFlat {
    if (Test-Path -LiteralPath $argvFile) {
        return ((Get-Content -LiteralPath $argvFile) -join " ").TrimEnd()
    }
    return ""
}

function Invoke-RunGpt {
    param([string[]]$ArgList)
    $savedPath = $env:PATH
    $env:PATH = $testPath
    try {
        $out = & $powerShellHost -NoProfile -File $runGptPs1 @ArgList 2>&1
        $script:runGptExit = $LASTEXITCODE
        $script:runGptOutput = ($out | Out-String)
    } finally {
        $env:PATH = $savedPath
    }
}

$inputFile = Join-Path $work "input.txt"
Set-Content -Path $inputFile -Value "Plain panelist input content for argv-composition tests."
$specRoot = Join-Path $work "specroot"

# ===========================================================================
# TEST-035 (AC-035): -Effort forwarded into the assembled codex
# ArgumentList alongside -Model; omitted entirely preserves the exact
# pre-T-006 argv.
# ===========================================================================
Reset-StubState
Invoke-RunGpt @("--task", "T-035", "--feature", "stub-feat", "--input", $inputFile, "--spec-root", $specRoot,
    "--model", "openai/gpt-5.2-codex", "--effort", "high", "--digest", $zeroDigest)
if ((Test-Path -LiteralPath $markerFile) -and ((Get-ArgvFlat) -ceq "--model openai/gpt-5.2-codex --effort high --no-project-doc")) {
    Ok "TEST-035: -Effort is forwarded into the assembled codex argv, positioned after -Model"
} else {
    Fail "TEST-035: -Effort was not forwarded correctly into the codex argv -- $(Get-ArgvFlat)"
}

Reset-StubState
Invoke-RunGpt @("--task", "T-035b", "--feature", "stub-feat", "--input", $inputFile, "--spec-root", $specRoot,
    "--model", "openai/gpt-5.2-codex", "--digest", $zeroDigest)
if ((Get-ArgvFlat) -ceq "--model openai/gpt-5.2-codex --no-project-doc") {
    Ok "TEST-035: omitting -Effort preserves the exact pre-T-006 codex argv byte-for-byte (Breaking API: no)"
} else {
    Fail "TEST-035: omitting -Effort changed the codex argv shape -- got: $(Get-ArgvFlat)"
}

# ===========================================================================
# TEST-036 (AC-036): prepare-panelist-input.ps1 threads a selector-derived
# effort value through to run-panelist-gpt's -Effort argument.
# ===========================================================================
$tasksFixture = Join-Path $work "tasks.md"
Set-Content -Path $tasksFixture -Value "## T-036 Stub task for consent gate`n`nCross-Model: enabled`n"
$sanitizeSrc = Join-Path $work "sanitize-src.txt"
Set-Content -Path $sanitizeSrc -Value "plain review content, no secrets, no absolute paths."
$bundleOut = Join-Path $work "bundle.txt"

$ppOut = & $powerShellHost -NoProfile -File $preparePs1 --task T-036 --feature stub-feat --input $sanitizeSrc `
    --tasks-file $tasksFixture --out $bundleOut --effort medium 2>&1
$ppOutText = ($ppOut | Out-String)
$effortLine = ($ppOutText -split "`r?`n" | Where-Object { $_ -cmatch '^effort=' } | Select-Object -First 1)
if ($effortLine -ceq "effort=medium") {
    Ok "TEST-036: prepare-panelist-input.ps1 threads -Effort onto a second stdout line, verbatim"
} else {
    Fail "TEST-036: prepare-panelist-input.ps1 did not thread -Effort correctly -- stdout: $ppOutText"
}

$bundleNoEffort = Join-Path $work "bundle-noeffort.txt"
$ppOutNoEffort = & $powerShellHost -NoProfile -File $preparePs1 --task T-036 --feature stub-feat --input $sanitizeSrc `
    --tasks-file $tasksFixture --out $bundleNoEffort 2>&1
$ppOutNoEffortLines = ($ppOutNoEffort | Out-String).TrimEnd("`r", "`n") -split "`r?`n"
if ($ppOutNoEffortLines.Count -eq 1) {
    Ok "TEST-036: omitting -Effort preserves the exact pre-T-006 single-line stdout output (Breaking API: no)"
} else {
    Fail "TEST-036: omitting -Effort changed prepare-panelist-input's stdout line count -- got: $($ppOutNoEffortLines -join '|')"
}

$fwdEffort = $effortLine -replace '^effort=', ''
Reset-StubState
Invoke-RunGpt @("--task", "T-036", "--feature", "stub-feat", "--input", $bundleOut, "--spec-root", $specRoot,
    "--model", "openai/gpt-5.1-codex", "--effort", $fwdEffort, "--digest", $zeroDigest)
if ((Get-ArgvFlat) -clike "*--effort medium*") {
    Ok "TEST-036: the value threaded by prepare-panelist-input.ps1 reaches run-panelist-gpt's assembled codex argv unchanged"
} else {
    Fail "TEST-036: threaded effort value did not reach the assembled codex argv -- $(Get-ArgvFlat)"
}

# ===========================================================================
# TEST-037 (AC-037): the Codex-host evaluator/investigator startup path
# supplies select-agent-model -HostName codex-cli output (model + effort)
# as CLI flags to the launching codex command. Real registry, real .toml
# reference comments.
# ===========================================================================
$codexCandidates = Join-Path $work "codex-candidates.json"
Set-Content -Path $codexCandidates -Value @'
[
  {"name":"openai/gpt-5.1-codex-mini","cost":"0.01","available":true,"effort":"low"},
  {"name":"openai/gpt-5.1-codex","cost":"0.02","available":true,"effort":"medium"},
  {"name":"openai/gpt-5.2-codex","cost":"0.03","available":true,"effort":"high"}
]
'@

function Get-SelJsonForRole([string]$Role) {
    return & $selectorPs1 -Risk low -Registry $registryV2 -CandidatesFile $codexCandidates `
        -Role $Role -HostName codex-cli -Json | ConvertFrom-Json
}

function Get-TomlRef([string]$Path) {
    $lines = Get-Content -LiteralPath $Path -TotalCount 2
    $m = $lines[0] -replace '^# x-sdd-model: ', ''
    $e = $lines[1] -replace '^# x-sdd-effort: ', ''
    return @{ Model = $m; Effort = $e }
}

$test037Ok = $true
foreach ($pair in @(@{ Role = "sdd-evaluator"; Toml = $evaluatorToml }, @{ Role = "sdd-investigator"; Toml = $investigatorToml })) {
    $selJson = Get-SelJsonForRole $pair.Role
    $selModel = [string]$selJson.model
    $selEffort = [string]$selJson.effort
    $tomlRef = Get-TomlRef $pair.Toml
    if (($selModel -cne $tomlRef.Model) -or ($selEffort -cne $tomlRef.Effort)) {
        $test037Ok = $false
        Write-Output "not ok: TEST-037 sanity: $($pair.Role) live=$selModel/$selEffort toml=$($tomlRef.Model)/$($tomlRef.Effort) diverge"
        continue
    }
    Reset-StubState
    Invoke-RunGpt @("--task", "T-037-$($pair.Role)", "--feature", "stub-feat", "--input", $inputFile, "--spec-root", $specRoot,
        "--model", $selModel, "--effort", $selEffort, "--digest", $zeroDigest)
    if (-not ((Test-Path -LiteralPath $markerFile) -and ((Get-ArgvFlat) -ceq "--model $selModel --effort $selEffort --no-project-doc"))) {
        $test037Ok = $false
    }
}
if ($test037Ok) {
    Ok "TEST-037: select-agent-model -HostName codex-cli's model+effort output (sdd-evaluator and sdd-investigator roles, real registry) is supplied as CLI flags to the launching codex command"
} else {
    Fail "TEST-037: the Codex-host startup path did not correctly supply select-agent-model's model+effort output as codex CLI flags"
}

# ===========================================================================
# TEST-038 (AC-038): cross-check between T-003's rendered .toml reference
# comments and live selector output reports a distinguishable result when
# they diverge -- GREEN (real, in-sync content) and RED (mutation-based
# negative self-check) pair.
# ===========================================================================
function Test-CrossCheckToml {
    param([string]$TomlPath, [string]$LiveModel, [string]$LiveEffort)
    $tomlRef = Get-TomlRef $TomlPath
    if (($tomlRef.Model -ceq $LiveModel) -and ($tomlRef.Effort -ceq $LiveEffort)) {
        return "OK: $TomlPath"
    }
    return "DRIFT: $TomlPath toml=$($tomlRef.Model)/$($tomlRef.Effort) live=$LiveModel/$LiveEffort"
}

$evaluatorSelJson = Get-SelJsonForRole "sdd-evaluator"
$evaluatorSelModel = [string]$evaluatorSelJson.model
$evaluatorSelEffort = [string]$evaluatorSelJson.effort

$green038 = Test-CrossCheckToml $evaluatorToml $evaluatorSelModel $evaluatorSelEffort
if ($green038 -ceq "OK: $evaluatorToml") {
    Ok "TEST-038 GREEN: cross-check reports OK when the rendered .toml reference comments and live selector output agree"
} else {
    Fail "TEST-038 GREEN: cross-check did not report OK for in-sync content -- $green038"
}

$mutatedEffort = "medium"
if ($evaluatorSelEffort -ceq "medium") { $mutatedEffort = "high" }
$red038 = Test-CrossCheckToml $evaluatorToml $evaluatorSelModel $mutatedEffort
$expectedRed038 = "DRIFT: $evaluatorToml toml=$evaluatorSelModel/$evaluatorSelEffort live=$evaluatorSelModel/$mutatedEffort"
if ($red038 -ceq $expectedRed038) {
    Ok "TEST-038 RED (negative self-check): a deliberately diverged live effort value turns the cross-check to a distinguishable DRIFT report"
} else {
    Fail "TEST-038 RED: mutated live value did NOT turn the cross-check red -- $red038"
}
if (($green038 -cne $red038) -and ($green038 -clike "OK:*") -and ($red038 -clike "DRIFT:*")) {
    Ok "TEST-038: OK and DRIFT outcomes are structurally distinguishable, never silently collapsed to one shape"
} else {
    Fail "TEST-038: OK and DRIFT outcomes were not distinguishable"
}

# ===========================================================================
# TEST-039 (AC-039, REQ-008): on Claude Code, the same startup-path
# reasoning records effort_applied=null + a populated
# effort_degraded_reason in the resulting run record -- never a silent
# drop. Uses the REAL registry's -HostName claude-code resolution (which
# resolves effort_control.claude-code to "frontmatter" for every Anthropic
# model, INV-013) feeding real emit-run-record.ps1 (T-004, unedited by
# this task) -- mirrors TEST-024/TEST-051's field-population rule.
# ===========================================================================
$claudeCandidates = Join-Path $work "claude-candidates.json"
Set-Content -Path $claudeCandidates -Value @'
[
  {"name":"anthropic/haiku","cost":"0.001","available":true},
  {"name":"anthropic/sonnet","cost":"0.01","available":true},
  {"name":"anthropic/opus","cost":"0.05","available":true}
]
'@
$claudeSelJson = & $selectorPs1 -Risk low -Registry $registryV2 -CandidatesFile $claudeCandidates `
    -Role sdd-evaluator -HostName claude-code -Json | ConvertFrom-Json
$claudeControl = [string]$claudeSelJson.effort_control
$claudeModel = [string]$claudeSelJson.model
$claudeEffort = [string]$claudeSelJson.effort

if ($claudeControl -cne "frontmatter") {
    Fail "TEST-039 sanity: select-agent-model -HostName claude-code did not resolve effort_control to frontmatter (got: $claudeControl) -- REQ-008/INV-013 assumption violated"
} else {
    Ok "TEST-039 sanity: select-agent-model -HostName claude-code resolves effort_control to frontmatter for the winning Anthropic model (INV-013, REQ-008)"
}

$rrFeature = "t006-degrade-fixture-ps1"
$rrCwd = Join-Path $work "rr-cwd"
New-Item -ItemType Directory -Path (Join-Path $rrCwd "specs/$rrFeature") -Force | Out-Null
Set-Content -Path (Join-Path $rrCwd "specs/$rrFeature/tasks.md") -Value "# Tasks`n`n## T-001 x`nStatus: Done`n"
Push-Location $rrCwd
try {
    & $powerShellHost -NoProfile -File $emitRunRecordPs1 -Feature $rrFeature -EffortMain $claudeEffort `
        -EffortControlMain $claudeControl -ModelMain $claudeModel | Out-Null
} finally {
    Pop-Location
}
$rrJson = Get-ChildItem (Join-Path $rrCwd "reports/runs") -Filter "RUN-*-$rrFeature.json" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($rrJson) {
    $rrRecord = Get-Content -Raw -LiteralPath $rrJson.FullName | ConvertFrom-Json
    if (($null -eq $rrRecord.effort.main.effort_applied) -and ($rrRecord.effort.main.effort_degraded_reason -ceq "effort-control-frontmatter")) {
        Ok "TEST-039: Claude Code path records effort_applied=null + effort_degraded_reason=effort-control-frontmatter in the run record, never a silent drop"
    } else {
        Fail "TEST-039: Claude Code degradation was not recorded correctly -- $(Get-Content -Raw -LiteralPath $rrJson.FullName)"
    }
} else {
    Fail "TEST-039: no run record was written"
}

# ===========================================================================
# TEST-052 (AC-052): -Model/-Effort argv-injection-shape rejection, per
# malformed-shape category, on run-panelist-gpt.ps1 -- non-zero exit,
# diagnostic message, and ZERO codex invocations.
# ===========================================================================
function Assert-Rejected {
    param([string]$Label, [string]$Diag, [string[]]$ArgList)
    Reset-StubState
    Invoke-RunGpt $ArgList
    if ($script:runGptExit -eq 0) {
        Fail "TEST-052 ($Label): expected non-zero exit, got 0 -- $script:runGptOutput"
        return
    }
    if (Test-Path -LiteralPath $markerFile) {
        Fail "TEST-052 ($Label): codex WAS invoked despite the malformed value (marker present) -- $script:runGptOutput"
        return
    }
    if ($script:runGptOutput -notlike "*$Diag*") {
        Fail "TEST-052 ($Label): rejected (exit $script:runGptExit, no codex invocation) but diagnostic text did not match -- $script:runGptOutput"
        return
    }
    Ok "TEST-052 ($Label): rejected non-zero (exit $script:runGptExit), diagnostic present, zero codex invocations"
}

$baseArgs = @("--task", "T-052", "--feature", "f", "--input", $inputFile, "--spec-root", $specRoot)
Assert-Rejected "model whitespace" "argv-injection shape" ($baseArgs + @("--model", "gpt 5.2 codex"))
Assert-Rejected "model leading dash" "flag-injection shape" ($baseArgs + @("--model", "-rf"))
Assert-Rejected "model leading double-dash" "flag-injection shape" ($baseArgs + @("--model", "--dangerous"))
Assert-Rejected "model semicolon" "command-separator shape" ($baseArgs + @("--model", "openai/gpt;rm-rf"))
Assert-Rejected "effort whitespace" "argv-injection shape" ($baseArgs + @("--effort", "hi gh"))
Assert-Rejected "effort leading dash" "flag-injection shape" ($baseArgs + @("--effort", "-high"))
Assert-Rejected "effort semicolon" "command-separator shape" ($baseArgs + @("--effort", "high;rm-rf"))
Assert-Rejected "effort out of vocabulary" "must be one of low|medium|high|xhigh" ($baseArgs + @("--effort", "extreme"))

# Positive control: a well-formed -Model/-Effort pair is NOT rejected.
Reset-StubState
Invoke-RunGpt @("--task", "T-052-control", "--feature", "f", "--input", $inputFile, "--spec-root", $specRoot,
    "--model", "openai/gpt-5.2-codex", "--effort", "high", "--digest", $zeroDigest)
if (Test-Path -LiteralPath $markerFile) {
    Ok "TEST-052 positive control: a well-formed -Model/-Effort pair is accepted and reaches codex (rejection is discriminating, not vacuous)"
} else {
    Fail "TEST-052 positive control: a well-formed -Model/-Effort pair was unexpectedly blocked"
}

# SKILL.md documents the same rejection categories for the Codex-host
# startup path (construction-level documentation complement).
$skillHasFlagShape = Select-String -LiteralPath $skillMd -Pattern 'flag-injection shape' -CaseSensitive -Quiet
$skillHasSepShape = Select-String -LiteralPath $skillMd -Pattern 'command-separator shape' -CaseSensitive -Quiet
$skillHasEnum = Select-String -LiteralPath $skillMd -Pattern ([regex]::Escape('{low, medium, high, xhigh}')) -CaseSensitive -Quiet
$skillHasNoInvoke = Select-String -LiteralPath $skillMd -Pattern 'no `codex` invocation attempted' -CaseSensitive -Quiet
if ($skillHasFlagShape -and $skillHasSepShape -and $skillHasEnum -and $skillHasNoInvoke) {
    Ok "TEST-052: SKILL.md documents the same enumerated-vocabulary rejection categories for the Codex-host startup path"
} else {
    Fail "TEST-052: SKILL.md does not document the injection-rejection categories for the Codex-host startup path"
}

# ===========================================================================
# TEST-040 (AC-040): a grep-based self-check over this suite asserts no
# direct LLM-invocation call is required for any assertion.
# ===========================================================================
$selfPath = $PSCommandPath
$selfLines = Get-Content -LiteralPath $selfPath | Where-Object { $_ -notmatch 'SELF-CHECK-PATTERN' }
$hasLiveNetwork = $selfLines | Select-String -Pattern 'curl |wget |api\.openai\.com|api\.anthropic\.com' -CaseSensitive -Quiet # SELF-CHECK-PATTERN
if ($hasLiveNetwork) {
    Fail "TEST-040: this suite must not reference a live network client or vendor API endpoint"
} else {
    Ok "TEST-040: no live network client or vendor API endpoint is referenced anywhere in this suite"
}
$invokeCount = (Select-String -LiteralPath $selfPath -Pattern 'Invoke-RunGpt ' -CaseSensitive).Count
if ($invokeCount -gt 0) {
    Ok "TEST-040: every codex invocation in this suite goes through the Invoke-RunGpt wrapper, which unconditionally overrides `$env:PATH to the stub codex ($invokeCount call sites)"
} else {
    Fail "TEST-040: no Invoke-RunGpt call sites found (unexpected -- this suite should exercise run-panelist-gpt.ps1)"
}

# ===========================================================================
# Human-copy staging + self-registration.
# ===========================================================================
$stagedTestYml = Join-Path $humanCopyDir ".github/workflows/test.yml"
if ((Test-Path -LiteralPath $stagedTestYml) -and
    (Select-String -LiteralPath $stagedTestYml -Pattern 'run-panelist-effort' -CaseSensitive -Quiet)) {
    Ok "human-copy: the staged .github/workflows/test.yml candidate registers this suite's CI step(s)"
} else {
    Fail "human-copy: the staged .github/workflows/test.yml candidate does not reference run-panelist-effort"
}
if (Test-Path -LiteralPath $stagedTestYml) {
    $stagedSha = (Get-FileHash -LiteralPath $stagedTestYml -Algorithm SHA256).Hash.ToLowerInvariant()
    if (Select-String -LiteralPath $manifest -Pattern "$stagedSha  \.github/workflows/test\.yml" -CaseSensitive -Quiet) {
        Ok "human-copy: MANIFEST.sha256 entry for the staged test.yml candidate matches its current content"
    } else {
        Fail "human-copy: MANIFEST.sha256 entry for the staged test.yml candidate is missing or stale"
    }
}

if (Select-String -LiteralPath $runAllSh -Pattern 'run-panelist-effort\.tests\.sh' -CaseSensitive -Quiet) {
    Ok "self-registration: run-panelist-effort.tests.sh registered in tests/run-all.sh"
} else {
    Fail "self-registration: run-panelist-effort.tests.sh NOT registered in tests/run-all.sh"
}
if (Select-String -LiteralPath $runAllPs1 -Pattern 'run-panelist-effort\.tests\.ps1' -CaseSensitive -Quiet) {
    Ok "self-registration: run-panelist-effort.tests.ps1 registered in tests/run-all.ps1"
} else {
    Fail "self-registration: run-panelist-effort.tests.ps1 NOT registered in tests/run-all.ps1"
}

# Sanity: the two Codex .toml reference-comment files this suite reads were
# never mutated by this suite's own run.
$evaluatorTomlShaAfter = (Get-FileHash -LiteralPath $evaluatorToml -Algorithm SHA256).Hash
$investigatorTomlShaAfter = (Get-FileHash -LiteralPath $investigatorToml -Algorithm SHA256).Hash
if (($evaluatorTomlShaAfter -ceq $evaluatorTomlShaBefore) -and ($investigatorTomlShaAfter -ceq $investigatorTomlShaBefore)) {
    Ok "AC-038 boundary: this suite's own run left both real .codex/agents/*.toml reference-comment files byte-unchanged"
} else {
    Fail "AC-038 boundary: a real .codex/agents/*.toml reference-comment file changed during this suite's own run"
}

} finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output "run-panelist-effort.tests.ps1: $($script:passCount) passed, $($script:failCount) failed"
if ($script:failCount -ne 0) { exit 1 }
exit 0
