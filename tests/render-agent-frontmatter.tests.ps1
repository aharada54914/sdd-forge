# Suite: render-agent-frontmatter (T-003, #151) -- REQ-003 / AC-014..AC-020.
# PowerShell twin of tests/render-agent-frontmatter.tests.sh; see that
# file's header comment for the full design rationale (scratch-mirror-only
# mutation, one-time real production render performed separately).
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$renderPs1 = Join-Path $root 'render-agent-frontmatter.ps1'
$runAllSh = Join-Path $root 'tests/run-all.sh'
$runAllPs1 = Join-Path $root 'tests/run-all.ps1'
$realRegistry = Join-Path $root 'contracts/agent-model-capabilities.v2.json'

# Q15 (owner decision 2026-11-28): the four v1 reviewer definitions retired in
# v2 (ADR-0051 decision 2); an explicit render of one is an input error. The
# protected-target staging checks that used them retired with human-copy.
$retiredTargets = @(
    @('impl-reviewer', 'plugins/sdd-review-loop/agents/impl-reviewer-a.md'),
    @('impl-reviewer', 'plugins/sdd-review-loop/agents/impl-reviewer-b.md'),
    @('task-reviewer', 'plugins/sdd-review-loop/agents/task-reviewer-a.md'),
    @('task-reviewer', 'plugins/sdd-review-loop/agents/task-reviewer-b.md')
)
$unprotectedClaudeRelPaths = @(
    'plugins/sdd-quality-loop/agents/evaluator.md',
    'plugins/sdd-bootstrap/agents/investigator.md',
    'plugins/sdd-review-loop/agents/spec-reviewer-a.md',
    'plugins/sdd-review-loop/agents/spec-reviewer-b.md'
)
$codexRelPaths = @(
    '.codex/agents/sdd-evaluator.toml',
    '.codex/agents/sdd-investigator.toml'
)

$pass = 0
$fail = 0
function Test-Ok([string]$Message) {
    $script:pass++
    Write-Host "ok: $Message"
}
function Test-Bad([string]$Message) {
    $script:fail++
    Write-Host "not ok: $Message"
}

function Get-Sha256OfFile([string]$Path) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes([System.IO.File]::ReadAllText($Path))
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $hash = $sha.ComputeHash($bytes) } finally { $sha.Dispose() }
    return -join ($hash | ForEach-Object { $_.ToString('x2') })
}

function Invoke-Render {
    param(
        [string[]]$RenderArgs
    )
    $psExe = (Get-Process -Id $PID).Path
    $fullArgs = @('-NoProfile', '-File', $renderPs1) + $RenderArgs
    $output = & $psExe @fullArgs 2>&1
    $exitCode = $LASTEXITCODE
    $combined = (($output | ForEach-Object { $_.ToString() }) -join "`n")
    return [pscustomobject]@{ ExitCode = $exitCode; StdOut = $combined; StdErr = ''; Combined = $combined }
}

if (-not (Test-Path $renderPs1)) {
    Write-Host "not ok: render-agent-frontmatter.ps1 does not exist at $renderPs1"
    exit 1
}

$tmp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$tmp = (Resolve-Path $tmp).Path

try {
    # --- Build a scratch mirror of the real production targets -----------
    foreach ($rel in ($unprotectedClaudeRelPaths + $codexRelPaths)) {
        $dst = Join-Path $tmp $rel
        $dstDir = Split-Path -Parent $dst
        if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
        Copy-Item -Path (Join-Path $root $rel) -Destination $dst -Force
    }
    $registryDst = Join-Path $tmp 'contracts/agent-model-capabilities.v2.json'
    New-Item -ItemType Directory -Path (Split-Path -Parent $registryDst) -Force | Out-Null
    Copy-Item -Path $realRegistry -Destination $registryDst -Force

    # Reset the scratch mirror to a PRISTINE (pre-render) state regardless
    # of whether the real repository's unprotected targets have already
    # been rendered by this task's own one-time production render (they
    # have, by design -- AC-017's zero-diff proof requires it). This keeps
    # the suite deterministic and independently re-runnable in CI.
    $effortCommentPattern = '^<!-- x-sdd-effort: \S+ -->$'
    foreach ($rel in $unprotectedClaudeRelPaths) {
        $p = Join-Path $tmp $rel
        $lines = Get-Content -Encoding utf8 $p
        $stripped = $lines | Where-Object { $_ -cnotmatch $effortCommentPattern }
        [System.IO.File]::WriteAllText($p, (($stripped -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
    }
    $codexHeaderPattern = '^# x-sdd-(model|effort): \S+$'
    foreach ($rel in $codexRelPaths) {
        $p = Join-Path $tmp $rel
        $lines = @(Get-Content -Encoding utf8 $p)
        $i = 0
        while ($i -lt $lines.Count -and $lines[$i] -cmatch $codexHeaderPattern) { $i++ }
        $rest = if ($i -lt $lines.Count) { $lines[$i..($lines.Count - 1)] } else { @() }
        [System.IO.File]::WriteAllText($p, (($rest -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
    }

    $modelBefore = @{}
    $shaBefore = @{}
    $lineCountBefore = @{}
    foreach ($rel in $unprotectedClaudeRelPaths) {
        $p = Join-Path $tmp $rel
        $line = (Get-Content -Encoding utf8 $p | Where-Object { $_ -cmatch '^model:' } | Select-Object -First 1)
        $modelBefore[$rel] = ($line -replace '^model:\s*', '')
        $shaBefore[$rel] = Get-Sha256OfFile $p
        $lineCountBefore[$rel] = (Get-Content -Encoding utf8 $p).Count
    }
    foreach ($rel in $codexRelPaths) {
        $shaBefore[$rel] = Get-Sha256OfFile (Join-Path $tmp $rel)
    }

    # =======================================================================
    # TEST-016 (AC-016) + TEST-020 (AC-020): --check is read-only, detects
    # drift, exits non-zero -- run BEFORE any render.
    # =======================================================================
    $checkResult = Invoke-Render -RenderArgs @('-Check', '-RepoRoot', $tmp, '-Registry', $registryDst)
    # v2 ships every default target as `model: inherit`, which the renderer
    # excludes (TEST-018); drift detection is proven by the TEST-020 pair below.
    if ($checkResult.ExitCode -eq 0) {
        Test-Ok "TEST-016: --check exits 0 on the shipped default targets (all inherit the caller's model)"
    } else {
        Test-Bad "TEST-016: --check reported drift on the shipped default targets -- $($checkResult.Combined)"
    }
    $defaultOk = $true
    foreach ($rel in ($unprotectedClaudeRelPaths + $codexRelPaths)) {
        if ($checkResult.Combined -cnotmatch ('(?m)^' + [regex]::Escape("OK: $rel") + '\r?$')) { $defaultOk = $false }
        if ($rel -clike '*.md' -and -not ((Get-Content -Encoding utf8 (Join-Path $tmp $rel)) -ccontains 'model: inherit')) { $defaultOk = $false }
    }
    if ($defaultOk) {
        Test-Ok "TEST-016: --check reports OK for every default target, and each Claude target inherits the caller's model"
    } else {
        Test-Bad "TEST-016: unexpected default target status -- $($checkResult.Combined)"
    }

    $noWriteDuringCheck = $true
    foreach ($rel in ($unprotectedClaudeRelPaths + $codexRelPaths)) {
        if ((Get-Sha256OfFile (Join-Path $tmp $rel)) -cne $shaBefore[$rel]) { $noWriteDuringCheck = $false }
    }
    if ($noWriteDuringCheck -and -not (Test-Path (Join-Path $tmp 'specs'))) {
        Test-Ok 'TEST-020: --check performed zero writes (all targets byte-unchanged, no human-copy dir created)'
    } else {
        Test-Bad 'TEST-020: --check wrote something (target hash changed or human-copy dir materialized)'
    }

    # --- TEST-020 mutation-based negative self-check (RED/GREEN pair) ----
    # A protected-position, explicit-model copy of a current role: synced -> OK,
    # its x-sdd-effort value mutated -> DRIFT.
    $mutRel = 'plugins/sdd-review-loop/agents/spec-reviewer-a.md'
    $mutRoot = Join-Path $tmp 'ac020-mutation'
    New-Item -ItemType Directory -Path (Join-Path $mutRoot 'plugins/sdd-review-loop/agents') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $mutRoot 'contracts') -Force | Out-Null
    $mutFile = Join-Path $mutRoot $mutRel
    $explicit = [System.IO.File]::ReadAllText((Join-Path $tmp $mutRel)) -creplace '(?m)^model: inherit$', 'model: fixture-explicit'
    [System.IO.File]::WriteAllText($mutFile, $explicit, (New-Object System.Text.UTF8Encoding($false)))
    if (-not ((Get-Content -Encoding utf8 $mutFile) -ccontains 'model: fixture-explicit')) { Test-Bad 'TEST-020: mutation fixture did not get an explicit model line' }
    Copy-Item -Path $registryDst -Destination (Join-Path $mutRoot 'contracts/agent-model-capabilities.v2.json') -Force
    $mutTargetsPath = Join-Path $mutRoot 'targets.json'
    "[{""role"": ""spec-reviewer"", ""kind"": ""claude"", ""path"": ""$mutRel"", ""protected"": true}]" |
        Out-File -FilePath $mutTargetsPath -Encoding utf8 -NoNewline

    $mutRegistry = Join-Path $mutRoot 'contracts/agent-model-capabilities.v2.json'
    $mutRealShaBefore = Get-Sha256OfFile $mutFile
    Invoke-Render -RenderArgs @('-RepoRoot', $mutRoot, '-TargetsFile', $mutTargetsPath, '-Registry', $mutRegistry) | Out-Null
    # TEST-019 write boundary: a protected target is never written at its real
    # path; the corrected content is staged with a matching MANIFEST.sha256 line.
    $mutStaged = Join-Path $mutRoot (Join-Path 'specs/epic-159-pillar-c/human-copy' $mutRel)
    if ((Get-Sha256OfFile $mutFile) -ceq $mutRealShaBefore) { Test-Ok 'TEST-019: a protected render leaves the real path byte-unchanged' }
    else { Test-Bad 'TEST-019: a protected render wrote the real path' }
    $mutManifest = Join-Path $mutRoot 'specs/epic-159-pillar-c/human-copy/MANIFEST.sha256'
    $stagedOk = (Test-Path -LiteralPath $mutStaged) -and (Test-Path -LiteralPath $mutManifest)
    if ($stagedOk) {
        $stagedLines = @(Get-Content -Encoding utf8 $mutStaged)
        $manifestLines = @(Get-Content -LiteralPath $mutManifest)
        $stagedOk = ($manifestLines -ccontains "$(Get-Sha256OfFile $mutStaged)  $mutRel") -and
            -not ($stagedLines -ccontains 'model: fixture-explicit') -and
            (@($stagedLines | Where-Object { $_ -cmatch '^<!-- x-sdd-effort: [a-z]+ -->$' }).Count -gt 0)
    }
    if ($stagedOk) { Test-Ok 'TEST-019: the corrected content is staged under human-copy/ with a matching MANIFEST.sha256 line' }
    else { Test-Bad 'TEST-019: staged content or its MANIFEST.sha256 line is missing or wrong' }
    Copy-Item -Path $mutStaged -Destination $mutFile -Force

    $green020 = Invoke-Render -RenderArgs @('-Check', '-RepoRoot', $mutRoot, '-TargetsFile', $mutTargetsPath, '-Registry', $mutRegistry)
    if ($green020.ExitCode -eq 0 -and $green020.Combined -cmatch [regex]::Escape("OK: $mutRel")) {
        Test-Ok 'TEST-020 GREEN: --check reports OK (no drift) against a correctly-synced protected-position target'
    } else {
        Test-Bad "TEST-020 GREEN: --check did not report OK against a correctly-synced target -- $($green020.Combined)"
    }

    $mutContent = [System.IO.File]::ReadAllText($mutFile)
    $effortMatch = [regex]::Match($mutContent, '<!-- x-sdd-effort: (\S+) -->')
    if (-not $effortMatch.Success) { Test-Bad 'TEST-020: the synced target carries no x-sdd-effort comment to mutate' }
    $newEffort = if ($effortMatch.Groups[1].Value -ceq 'low') { 'high' } else { 'low' }
    $mutContent = $mutContent.Replace($effortMatch.Value, "<!-- x-sdd-effort: $newEffort -->")
    [System.IO.File]::WriteAllText($mutFile, $mutContent, (New-Object System.Text.UTF8Encoding($false)))

    $red020 = Invoke-Render -RenderArgs @('-Check', '-RepoRoot', $mutRoot, '-TargetsFile', $mutTargetsPath, '-Registry', $mutRegistry)
    if ($red020.ExitCode -ne 0 -and $red020.Combined -cmatch [regex]::Escape("DRIFT: $mutRel")) {
        Test-Ok 'TEST-020 RED (negative self-check): mutating a synced protected-position target x-sdd-effort value turns --check red again'
    } else {
        Test-Bad "TEST-020 RED (negative self-check): mutated target did NOT turn --check red -- $($red020.Combined)"
    }

    # =======================================================================
    # TEST-019 (AC-019): write-target resolution FUNCTION self-check.
    # =======================================================================
    $green019 = $true
    $red019 = $true
    foreach ($rel in $unprotectedClaudeRelPaths) {
        $resolved = (Invoke-Render -RenderArgs @('-ResolveTargetRawPath', $rel, '-ResolveTargetRawProtected', '1')).StdOut.Trim()
        if ($resolved -cne (Join-Path $root (Join-Path 'specs/epic-159-pillar-c/human-copy' $rel))) { $green019 = $false }
        $resolved = (Invoke-Render -RenderArgs @('-ResolveTargetRawPath', $rel, '-ResolveTargetRawProtected', '0')).StdOut.Trim()
        if ($resolved -cne (Join-Path $root $rel)) { $red019 = $false }
    }
    if ($green019) {
        Test-Ok 'TEST-019 GREEN: -ResolveTargetRaw(Protected=1) resolves under specs/epic-159-pillar-c/human-copy/, never the real path'
    } else {
        Test-Bad 'TEST-019 GREEN: -ResolveTargetRaw(Protected=1) resolved a target OUTSIDE human-copy/'
    }
    if ($red019) {
        Test-Ok 'TEST-019 RED: forcing Protected=0 resolves to the REAL path -- the resolution function is live'
    } else {
        Test-Bad 'TEST-019 RED: forcing Protected=0 did NOT resolve to the real path'
    }
    $q15Resolve = $true
    foreach ($entry in $retiredTargets) {
        $r = Invoke-Render -RenderArgs @('-ResolveTargetRole', $entry[0], '-ResolveTargetKind', 'claude', '-ResolveTargetRelPath', $entry[1])
        if ($r.ExitCode -eq 0 -or -not $r.Combined.Contains("role '$($entry[0])' was retired in v2 and cannot be rendered")) { $q15Resolve = $false }
    }
    if ($q15Resolve) { Test-Ok 'Q15: -ResolveTargetRole refuses all four retired reviewer targets' }
    else { Test-Bad 'Q15: -ResolveTargetRole resolved a retired reviewer target' }

    # =======================================================================
    # TEST-014/015/017: real render against the scratch mirror.
    # =======================================================================
    Invoke-Render -RenderArgs @('-RepoRoot', $tmp, '-Registry', $registryDst) | Out-Null

    # Every shipped Claude target inherits the caller's model, so a render
    # leaves it byte-identical (AC-018 exclusion).
    $test014Ok = $true
    foreach ($rel in $unprotectedClaudeRelPaths) {
        if ((Get-Sha256OfFile (Join-Path $tmp $rel)) -cne $shaBefore[$rel]) { $test014Ok = $false }
    }
    if ($test014Ok) {
        Test-Ok 'TEST-014: a render leaves every shipped (inherit) Claude target byte-identical'
    } else {
        Test-Bad "TEST-014: a render changed a shipped Claude target that inherits the caller's model"
    }

    $expectedCodexModel = @{
        '.codex/agents/sdd-evaluator.toml'    = 'openai/gpt-5.2-codex'
        '.codex/agents/sdd-investigator.toml' = 'openai/gpt-5.1-codex-mini'
    }
    $expectedCodexEffort = @{
        '.codex/agents/sdd-evaluator.toml'    = 'high'
        '.codex/agents/sdd-investigator.toml' = 'low'
    }
    $test015Ok = $true
    foreach ($rel in $codexRelPaths) {
        $lines = Get-Content -Encoding utf8 (Join-Path $tmp $rel)
        if ($lines[0] -cne "# x-sdd-model: $($expectedCodexModel[$rel])") { $test015Ok = $false }
        if ($lines[1] -cne "# x-sdd-effort: $($expectedCodexEffort[$rel])") { $test015Ok = $false }
        $content = [System.IO.File]::ReadAllText((Join-Path $tmp $rel))
        foreach ($key in @('name = ', 'description = ', 'sandbox_mode = ', 'developer_instructions = ')) {
            if ($content -cnotmatch [regex]::Escape($key)) { $test015Ok = $false }
        }
    }
    if ($test015Ok) {
        Test-Ok 'TEST-015: Codex .toml targets gain # x-sdd-model:/# x-sdd-effort: header comments; existing TOML keys untouched'
    } else {
        Test-Bad 'TEST-015: Codex .toml render produced an unexpected diff'
    }

    $test017Ok = $true
    foreach ($rel in $unprotectedClaudeRelPaths) {
        $line = (Get-Content -Encoding utf8 (Join-Path $tmp $rel) | Where-Object { $_ -cmatch '^model:' } | Select-Object -First 1)
        $modelAfter = ($line -replace '^model:\s*', '')
        if ($modelAfter -cne $modelBefore[$rel]) { $test017Ok = $false }
    }
    if ($test017Ok) {
        Test-Ok 'TEST-017: render against real production content is a zero-diff no-op on every unprotected target model: value'
    } else {
        Test-Bad 'TEST-017: render against real production content changed a model: value unexpectedly'
    }

    if (-not (Test-Path (Join-Path $tmp 'specs'))) {
        Test-Ok 'TEST-019: a full default render staged nothing under specs/ (no protected default target)'
    } else {
        Test-Bad 'TEST-019: a full default render created a staging directory'
    }

    # =======================================================================
    # TEST-018 (AC-018): exclusion lock.
    # =======================================================================
    $inheritFixture = Join-Path $tmp 'inherit-fixture.md'
    @"
---
name: sdd-panelist-fixture
description: fixture agent with model inherit, for TEST-018.
tools: Read
model: inherit
---

Body text unaffected.
"@ | Out-File -FilePath $inheritFixture -Encoding utf8 -NoNewline
    $inheritShaBefore = Get-Sha256OfFile $inheritFixture
    $inheritTargets = Join-Path $tmp 'inherit-targets.json'
    '[{"role": "sdd-evaluator", "kind": "claude", "path": "inherit-fixture.md", "protected": false}]' |
        Out-File -FilePath $inheritTargets -Encoding utf8 -NoNewline
    Invoke-Render -RenderArgs @('-RepoRoot', $tmp, '-TargetsFile', $inheritTargets, '-Registry', $registryDst) | Out-Null
    $inheritShaAfter = Get-Sha256OfFile $inheritFixture
    if ($inheritShaBefore -ceq $inheritShaAfter) {
        Test-Ok 'TEST-018: a model: inherit agent is byte-unchanged after a render targeting it'
    } else {
        Test-Bad 'TEST-018: a model: inherit agent was modified by render (exclusion not honored)'
    }

    $resolveAbsent = Invoke-Render -RenderArgs @('-ResolveTargetRole', 'domain-reviewer', '-ResolveTargetKind', 'claude', '-ResolveTargetRelPath', 'plugins/sdd-domain/agents/domain-reviewer-a.md')
    if ($resolveAbsent.ExitCode -ne 0 -and $resolveAbsent.Combined -cmatch 'target not found in table') {
        Test-Ok 'TEST-018: a role-map-absent agent (domain-reviewer-a.md) is not present in the built-in TARGETS table'
    } else {
        Test-Bad 'TEST-018: domain-reviewer-a.md unexpectedly resolved in the built-in TARGETS table'
    }

    # =======================================================================
    # TEST-016 continued: --check wired into CI and validate-repository.ps1.
    # =======================================================================
    if ((Test-Path $runAllSh) -and (Select-String -Path (Join-Path $root 'tests/validate-repository.ps1') -Pattern 'render-agent-frontmatter' -Quiet)) {
        Test-Ok 'TEST-016: render-agent-frontmatter --check is wired into tests/validate-repository.ps1'
    } else {
        Test-Bad 'TEST-016: tests/validate-repository.ps1 does not invoke render-agent-frontmatter --check'
    }

    # The staged test.yml candidate check retired with the human-copy procedure.

    # =======================================================================
    # Mis-cased registry fixtures.
    # =======================================================================
    $miscasedRoleRegistry = Join-Path $tmp 'miscased-role-registry.json'
    @'
{
  "schema": "agent-model-capabilities/v2",
  "models": [
    { "name": "anthropic/opus", "canonical_tier": "strong", "supported_efforts": ["high"], "default_effort": "high", "effort_control": { "claude-code": "frontmatter", "codex-cli": "none" } }
  ],
  "risk_effort_matrix": { "low": "low", "medium": "medium", "high": "high", "critical": "high", "escalation_bump": true },
  "role_defaults": {
    "Sdd-Evaluator": { "minimum_tier": "strong", "default_effort": "high" }
  }
}
'@ | Out-File -FilePath $miscasedRoleRegistry -Encoding utf8 -NoNewline

    $miscasedTierRegistry = Join-Path $tmp 'miscased-tier-registry.json'
    @'
{
  "schema": "agent-model-capabilities/v2",
  "models": [
    { "name": "anthropic/opus", "canonical_tier": "Strong", "supported_efforts": ["high"], "default_effort": "high", "effort_control": { "claude-code": "frontmatter", "codex-cli": "none" } }
  ],
  "risk_effort_matrix": { "low": "low", "medium": "medium", "high": "high", "critical": "high", "escalation_bump": true },
  "role_defaults": {
    "sdd-evaluator": { "minimum_tier": "strong", "default_effort": "high" }
  }
}
'@ | Out-File -FilePath $miscasedTierRegistry -Encoding utf8 -NoNewline

    $miscasedTargets = Join-Path $tmp 'miscased-targets.json'
    '[{"role": "sdd-evaluator", "kind": "claude", "path": "plugins/sdd-quality-loop/agents/evaluator.md", "protected": false}]' |
        Out-File -FilePath $miscasedTargets -Encoding utf8 -NoNewline

    $miscasedRole = Invoke-Render -RenderArgs @('-Check', '-RepoRoot', $tmp, '-TargetsFile', $miscasedTargets, '-Registry', $miscasedRoleRegistry)
    if ($miscasedRole.ExitCode -ne 0 -and $miscasedRole.Combined -cmatch "role_defaults missing or incomplete for role 'sdd-evaluator'") {
        Test-Ok "mis-cased fixture: a role_defaults key differing only in case ('Sdd-Evaluator') is rejected, not silently matched to 'sdd-evaluator'"
    } else {
        Test-Bad "mis-cased fixture: a mis-cased role_defaults key was NOT rejected -- $($miscasedRole.Combined)"
    }

    $miscasedTier = Invoke-Render -RenderArgs @('-Check', '-RepoRoot', $tmp, '-TargetsFile', $miscasedTargets, '-Registry', $miscasedTierRegistry)
    if ($miscasedTier.ExitCode -ne 0 -and $miscasedTier.Combined -cmatch "no claude model found for tier 'strong'") {
        Test-Ok "mis-cased fixture: a canonical_tier value differing only in case ('Strong') is rejected, not silently matched to 'strong'"
    } else {
        Test-Bad "mis-cased fixture: a mis-cased canonical_tier value was NOT rejected -- $($miscasedTier.Combined)"
    }

    # =======================================================================
    # The shipped evaluator inherits the caller's model; the override checks
    # render an explicit-model copy of it.
    $explicitEvaluator = Join-Path $tmp 'explicit-evaluator.md'
    $explicitText = [System.IO.File]::ReadAllText((Join-Path $tmp 'plugins/sdd-quality-loop/agents/evaluator.md')) -creplace '(?m)^model: inherit$', 'model: fixture-explicit'
    [System.IO.File]::WriteAllText($explicitEvaluator, $explicitText, (New-Object System.Text.UTF8Encoding($false)))
    $overrideTargets = Join-Path $tmp 'override-targets.json'
    '[{"role": "sdd-evaluator", "kind": "claude", "path": "explicit-evaluator.md", "protected": false}]' |
        Out-File -FilePath $overrideTargets -Encoding utf8 -NoNewline
    $overrideCases = [ordered]@{
        absent = $null
        null = $null
        array = @()
        missing = @{ minimum_tier = 'standard' }
        extra = @{ minimum_tier = 'standard'; default_effort = 'medium'; extra = $true }
        'tier-case' = @{ minimum_tier = 'Standard'; default_effort = 'medium' }
        'effort-case' = @{ minimum_tier = 'standard'; default_effort = 'Medium' }
    }
    foreach ($caseName in $overrideCases.Keys) {
        $registry = Get-Content -LiteralPath $registryDst -Raw | ConvertFrom-Json
        $role = $registry.role_defaults.'sdd-evaluator'
        $role.PSObject.Properties.Remove('claude_frontmatter')
        if ($caseName -cne 'absent') {
            $role | Add-Member -NotePropertyName claude_frontmatter -NotePropertyValue $overrideCases[$caseName]
        }
        $casePath = Join-Path $tmp "override-$caseName.json"
        $registry | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $casePath -Encoding utf8
        $result = Invoke-Render -RenderArgs @('-RepoRoot', $tmp, '-TargetsFile', $overrideTargets, '-Registry', $casePath)
        if ($caseName -ceq 'absent') {
            $content = Get-Content -LiteralPath $explicitEvaluator -Raw
            if ($result.ExitCode -eq 0 -and $content -cmatch '(?m)^model: opus\r?$' -and
                $content -cmatch '(?m)^<!-- x-sdd-effort: high -->\r?$') {
                Test-Ok 'Claude override absent preserves base role defaults'
            } else { Test-Bad 'Claude override absent did not preserve base role defaults' }
        } elseif ($result.ExitCode -ne 0 -and $result.Combined -cmatch 'invalid claude_frontmatter') {
            Test-Ok "Claude override $caseName rejected"
        } else { Test-Bad "Claude override $caseName not rejected correctly: $($result.Combined)" }
    }

    # Self-registration.
    # =======================================================================
    # The runner loads an external inventory; inspect its public list, not its source.
    function Test-PosixRegistration($Entries, $ExitCode) {
        return ($ExitCode -eq 0 -and $Entries -ccontains 'tests/render-agent-frontmatter.tests.sh')
    }
    $posixEntries = @(& bash $runAllSh --list)
    if (Test-PosixRegistration $posixEntries $LASTEXITCODE) {
        Test-Ok 'self-registration: render-agent-frontmatter.tests.sh registered in POSIX inventory'
    } else {
        Test-Bad 'self-registration: render-agent-frontmatter.tests.sh NOT registered in POSIX inventory'
    }
    foreach ($negative in @(
        @{ Entries = @(); ExitCode = 0; Name = 'missing entry' },
        @{ Entries = @('tests/render-agent-frontmatter.tests.sh.bak'); ExitCode = 0; Name = 'near match' },
        @{ Entries = @('tests/Render-agent-frontmatter.tests.sh'); ExitCode = 0; Name = 'case mismatch' },
        @{ Entries = @('tests/render-agent-frontmatter.tests.sh'); ExitCode = 1; Name = 'failed listing' }
    )) {
        if (Test-PosixRegistration $negative.Entries $negative.ExitCode) {
            Test-Bad "self-registration accepts $($negative.Name)"
        } else {
            Test-Ok "self-registration rejects $($negative.Name)"
        }
    }
    if ((Test-Path $runAllPs1) -and (((& (Join-Path $PSScriptRoot 'lib/verification-registration.ps1') $runAllPs1) -split "`n") -ccontains "tests/render-agent-frontmatter.tests.ps1")) {
        Test-Ok 'self-registration: render-agent-frontmatter.tests.ps1 registered in tests/run-all.ps1'
    } else {
        Test-Bad 'self-registration: render-agent-frontmatter.tests.ps1 NOT registered in tests/run-all.ps1'
    }

    # =======================================================================
    # Q15 (owner decision 2026-11-28): see the bash twin. Every retired
    # reviewer render/check is refused, protected or not, alone or mixed with
    # a valid target; mis-cased roles are unknown roles. Nothing is written
    # and nothing is staged.
    # =======================================================================
    $q15Root = Join-Path $tmp 'q15-retired'
    New-Item -ItemType Directory -Path (Join-Path $q15Root 'plugins/sdd-review-loop/agents') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $q15Root 'plugins/sdd-quality-loop/agents') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $q15Root 'contracts') -Force | Out-Null
    Copy-Item -Path $realRegistry -Destination (Join-Path $q15Root 'contracts/agent-model-capabilities.v2.json') -Force
    Copy-Item -Path (Join-Path $tmp 'plugins/sdd-quality-loop/agents/evaluator.md') -Destination (Join-Path $q15Root 'plugins/sdd-quality-loop/agents/evaluator.md') -Force
    $q15Registry = Join-Path $q15Root 'contracts/agent-model-capabilities.v2.json'
    $q15Table = Join-Path $q15Root 'targets.json'
    function Get-Q15State {
        $items = Get-ChildItem -LiteralPath $q15Root -Recurse -File | Where-Object { $_.Name -cne 'targets.json' } | Sort-Object FullName
        return (($items | ForEach-Object { $_.FullName + '=' + (Get-Sha256OfFile $_.FullName) }) -join "`n")
    }
    $q15Ok = $true
    $q15Cases = 0
    foreach ($entry in $retiredTargets) {
        $role = $entry[0]; $rel = $entry[1]
        $name = [System.IO.Path]::GetFileNameWithoutExtension($rel)
        [System.IO.File]::WriteAllText((Join-Path $q15Root $rel), "---`nname: $name`nmodel: opus`n---`nRetired v1 reviewer fixture.`n", (New-Object System.Text.UTF8Encoding($false)))
        $misCased = $role.Substring(0, 1).ToUpperInvariant() + $role.Substring(1)
        $tables = [ordered]@{
            protected = "[{""role"": ""$role"", ""kind"": ""claude"", ""path"": ""$rel"", ""protected"": true}]"
            unprotected = "[{""role"": ""$role"", ""kind"": ""claude"", ""path"": ""$rel"", ""protected"": false}]"
            mixed = "[{""role"": ""sdd-evaluator"", ""kind"": ""claude"", ""path"": ""plugins/sdd-quality-loop/agents/evaluator.md"", ""protected"": false}, {""role"": ""$role"", ""kind"": ""claude"", ""path"": ""$rel"", ""protected"": false}]"
            'mis-cased' = "[{""role"": ""$misCased"", ""kind"": ""claude"", ""path"": ""$rel"", ""protected"": false}]"
        }
        foreach ($variant in $tables.Keys) {
            [System.IO.File]::WriteAllText($q15Table, $tables[$variant])
            $expected = if ($variant -ceq 'mis-cased') { 'role_defaults missing or incomplete' } else { 'was retired in v2 and cannot be rendered' }
            foreach ($mode in @('render', 'check')) {
                $before = Get-Q15State
                $renderArgs = @('-RepoRoot', $q15Root, '-TargetsFile', $q15Table, '-Registry', $q15Registry)
                if ($mode -ceq 'check') { $renderArgs = @('-Check') + $renderArgs }
                $r = Invoke-Render -RenderArgs $renderArgs
                $q15Cases++
                if ($r.ExitCode -eq 0 -or -not $r.Combined.Contains('RENDER_ERROR') -or -not $r.Combined.Contains($expected) -or
                    (Get-Q15State) -cne $before -or (Test-Path (Join-Path $q15Root 'specs'))) {
                    $q15Ok = $false
                    Write-Host "Q15 case failed: $rel $variant $mode exit=$($r.ExitCode) $($r.Combined)"
                }
            }
        }
    }
    if ($q15Ok -and $q15Cases -eq 32) { Test-Ok 'Q15: all 32 retired-reviewer render/check cases are refused with nothing written or staged' }
    else { Test-Bad "Q15: a retired-reviewer render was accepted or wrote something ($q15Cases cases)" }

    # Actual parser controls: PowerShell must not coerce arrays or key casing.
    foreach ($variant in @('schema-array','schema-case','root-array','models-object','role-array','effort-array','name-array','effort-newline','effort-unknown','tier-array','model-newline','model-control')) {
        $bad = [System.IO.File]::ReadAllText($realRegistry) | ConvertFrom-Json
        switch ($variant) {
            'model-newline' { $bad.models[0].name += "`nINJECTED = true" }
            'model-control' { $bad.models[0].name += [char]0 }
            'schema-array' { $bad.schema = @($bad.schema) }
            'schema-case' { $value = $bad.schema; $bad.PSObject.Properties.Remove('schema'); $bad | Add-Member NoteProperty Schema $value }
            'models-object' { $bad.models = $bad.models[0] }
            'role-array' { $bad.role_defaults.'sdd-evaluator' = @($bad.role_defaults.'sdd-evaluator') }
            'effort-newline' { $bad.role_defaults.'sdd-evaluator'.default_effort = "high`nINJECTED" }
            'effort-unknown' { $bad.role_defaults.'sdd-evaluator'.default_effort = 'unrecognized' }
            'tier-array' { $bad.role_defaults.'sdd-evaluator'.minimum_tier = @('strong') }
            'effort-array' { $bad.role_defaults.'sdd-evaluator'.default_effort = @('high') }
            'name-array' { $bad.models[0].name = @($bad.models[0].name) }
        }
        $json = ConvertTo-Json -InputObject $bad -Depth 30
        if ($variant -eq 'root-array') { $json = '[' + $json + ']' }
        $badPath = Join-Path $tmp 'invalid-registry.json'
        [System.IO.File]::WriteAllText($badPath, $json)
        $r = Invoke-Render @('-Check', '-RepoRoot', $root, '-Registry', $badPath)
        if ($r.ExitCode -ne 0 -and $r.Combined -match 'RENDER_ERROR') { Test-Ok "reject registry $variant" }
        else { Test-Bad "reject registry $variant (exit $($r.ExitCode))" }
    }
    foreach ($targetCase in @('protected-string', 'protected-null', 'kind-unknown', 'root-object')) {
        $targetValue = [pscustomobject]@{ role = 'sdd-evaluator'; kind = 'codex'; path = '.codex/agents/sdd-evaluator.toml'; protected = $false }
        switch ($targetCase) {
            'protected-string' { $targetValue.protected = 'false' }
            'protected-null' { $targetValue.protected = $null }
            'kind-unknown' { $targetValue.kind = 'unexpected' }
        }
        $targetJson = ConvertTo-Json -InputObject $targetValue
        if ($targetCase -ne 'root-object') { $targetJson = '[' + $targetJson + ']' }
        $targetPath = Join-Path $tmp 'bad-targets.json'
        [System.IO.File]::WriteAllText($targetPath, $targetJson)
        $r = Invoke-Render @('-Check', '-RepoRoot', $root, '-TargetsFile', $targetPath)
        if ($r.ExitCode -ne 0 -and $r.Combined -match 'RENDER_ERROR') { Test-Ok "reject target $targetCase" }
        else { Test-Bad "reject target $targetCase (exit $($r.ExitCode))" }
    }
    $literalRepo = Join-Path $tmp 'repo[fixture]'
    [System.IO.Directory]::CreateDirectory($literalRepo) | Out-Null
    $literalRegistry = Join-Path $literalRepo 'registry[fixture].json'
    [System.IO.File]::Copy($realRegistry, $literalRegistry)
    $literalTargets = Join-Path $literalRepo 'targets[fixture].json'
    [System.IO.File]::WriteAllText($literalTargets, '[]')
    $r = Invoke-Render @('-Check', '-RepoRoot', $literalRepo, '-Registry', $literalRegistry, '-TargetsFile', $literalTargets)
    if ($r.ExitCode -eq 0 -and $r.Combined -match '0 targets, 0 drift') { Test-Ok 'literal bracket paths for repo, registry and targets' }
    else { Test-Bad "literal bracket paths (exit $($r.ExitCode)): $($r.Combined)" }

} finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

Write-Host ("---- summary: pass=$pass fail=$fail ----")
if ($fail -gt 0) {
    Write-Host "not ok: render-agent-frontmatter suite FAILED ($fail failures)"
    exit 1
}
Write-Host "ok: render-agent-frontmatter suite passed ($pass checks)"
exit 0
