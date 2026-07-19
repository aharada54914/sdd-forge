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
$humanCopyDir = Join-Path $root 'specs/epic-159-pillar-c/human-copy'
$manifestPath = Join-Path $humanCopyDir 'MANIFEST.sha256'

$protectedRelPaths = @(
    'plugins/sdd-review-loop/agents/impl-reviewer-a.md',
    'plugins/sdd-review-loop/agents/impl-reviewer-b.md',
    'plugins/sdd-review-loop/agents/task-reviewer-a.md',
    'plugins/sdd-review-loop/agents/task-reviewer-b.md'
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
    # --- Suite-wide safety proof: never touches the LIVE protected files --
    $liveProtectedShaBefore = @{}
    foreach ($rel in $protectedRelPaths) {
        $liveProtectedShaBefore[$rel] = Get-Sha256OfFile (Join-Path $root $rel)
    }

    # --- Build a scratch mirror of the real production targets -----------
    foreach ($rel in ($unprotectedClaudeRelPaths + $protectedRelPaths + $codexRelPaths)) {
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
    foreach ($rel in ($unprotectedClaudeRelPaths + $protectedRelPaths)) {
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
    foreach ($rel in ($unprotectedClaudeRelPaths + $protectedRelPaths)) {
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
    if ($checkResult.ExitCode -ne 0) {
        Test-Ok 'TEST-016: --check exits non-zero when every target still has drift'
    } else {
        Test-Bad 'TEST-016: --check exited 0 despite injected/pre-existing drift'
    }

    $driftAllPresent = $true
    foreach ($rel in ($unprotectedClaudeRelPaths + $codexRelPaths + $protectedRelPaths)) {
        if ($checkResult.Combined -cnotmatch [regex]::Escape("DRIFT: $rel")) {
            $driftAllPresent = $false
        }
    }
    if ($driftAllPresent) {
        Test-Ok 'TEST-016: --check reports DRIFT for every un-rendered target (unprotected and protected)'
    } else {
        Test-Bad "TEST-016: --check did not report DRIFT for every un-rendered target -- $($checkResult.Combined)"
    }

    $noWriteDuringCheck = $true
    foreach ($rel in ($unprotectedClaudeRelPaths + $codexRelPaths + $protectedRelPaths)) {
        if ((Get-Sha256OfFile (Join-Path $tmp $rel)) -cne $shaBefore[$rel]) { $noWriteDuringCheck = $false }
    }
    if ($noWriteDuringCheck -and -not (Test-Path (Join-Path $tmp 'specs'))) {
        Test-Ok 'TEST-020: --check performed zero writes (all targets byte-unchanged, no human-copy dir created)'
    } else {
        Test-Bad 'TEST-020: --check wrote something (target hash changed or human-copy dir materialized)'
    }

    # --- TEST-020 mutation-based negative self-check (RED/GREEN pair) ----
    $mutRoot = Join-Path $tmp 'ac020-mutation'
    New-Item -ItemType Directory -Path (Join-Path $mutRoot 'plugins/sdd-review-loop/agents') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $mutRoot 'contracts') -Force | Out-Null
    Copy-Item -Path (Join-Path $tmp 'plugins/sdd-review-loop/agents/impl-reviewer-a.md') `
        -Destination (Join-Path $mutRoot 'plugins/sdd-review-loop/agents/impl-reviewer-a.md') -Force
    Copy-Item -Path $registryDst -Destination (Join-Path $mutRoot 'contracts/agent-model-capabilities.v2.json') -Force
    $mutTargetsPath = Join-Path $mutRoot 'targets.json'
    '[{"role": "impl-reviewer", "kind": "claude", "path": "plugins/sdd-review-loop/agents/impl-reviewer-a.md", "protected": true}]' |
        Out-File -FilePath $mutTargetsPath -Encoding utf8 -NoNewline

    $mutRegistry = Join-Path $mutRoot 'contracts/agent-model-capabilities.v2.json'
    Invoke-Render -RenderArgs @('-RepoRoot', $mutRoot, '-TargetsFile', $mutTargetsPath, '-Registry', $mutRegistry) | Out-Null
    $stagedMut = Join-Path $mutRoot 'specs/epic-159-pillar-c/human-copy/plugins/sdd-review-loop/agents/impl-reviewer-a.md'
    Copy-Item -Path $stagedMut -Destination (Join-Path $mutRoot 'plugins/sdd-review-loop/agents/impl-reviewer-a.md') -Force

    $green020 = Invoke-Render -RenderArgs @('-Check', '-RepoRoot', $mutRoot, '-TargetsFile', $mutTargetsPath, '-Registry', $mutRegistry)
    if ($green020.ExitCode -eq 0 -and $green020.Combined -cmatch [regex]::Escape('OK: plugins/sdd-review-loop/agents/impl-reviewer-a.md')) {
        Test-Ok 'TEST-020 GREEN: --check reports OK (no drift) against a correctly-synced protected-position target'
    } else {
        Test-Bad "TEST-020 GREEN: --check did not report OK against a correctly-synced target -- $($green020.Combined)"
    }

    $mutFile = Join-Path $mutRoot 'plugins/sdd-review-loop/agents/impl-reviewer-a.md'
    $mutContent = [System.IO.File]::ReadAllText($mutFile)
    $mutContent = $mutContent.Replace('<!-- x-sdd-effort: medium -->', '<!-- x-sdd-effort: high -->')
    [System.IO.File]::WriteAllText($mutFile, $mutContent, (New-Object System.Text.UTF8Encoding($false)))

    $red020 = Invoke-Render -RenderArgs @('-Check', '-RepoRoot', $mutRoot, '-TargetsFile', $mutTargetsPath, '-Registry', $mutRegistry)
    if ($red020.ExitCode -ne 0 -and $red020.Combined -cmatch [regex]::Escape('DRIFT: plugins/sdd-review-loop/agents/impl-reviewer-a.md')) {
        Test-Ok 'TEST-020 RED (negative self-check): mutating a synced protected-position target x-sdd-effort value turns --check red again'
    } else {
        Test-Bad "TEST-020 RED (negative self-check): mutated target did NOT turn --check red -- $($red020.Combined)"
    }

    # =======================================================================
    # TEST-019 (AC-019): write-target resolution FUNCTION self-check.
    # =======================================================================
    $roleForRelpath = @{
        'plugins/sdd-review-loop/agents/impl-reviewer-a.md' = 'impl-reviewer'
        'plugins/sdd-review-loop/agents/impl-reviewer-b.md' = 'impl-reviewer'
        'plugins/sdd-review-loop/agents/task-reviewer-a.md' = 'task-reviewer'
        'plugins/sdd-review-loop/agents/task-reviewer-b.md' = 'task-reviewer'
    }

    $green019 = $true
    foreach ($rel in $protectedRelPaths) {
        $resolved = (Invoke-Render -RenderArgs @('-ResolveTargetRawPath', $rel, '-ResolveTargetRawProtected', '1')).StdOut.Trim()
        $expected = (Join-Path $root (Join-Path 'specs/epic-159-pillar-c/human-copy' $rel))
        if ($resolved -cne $expected) { $green019 = $false }
    }
    if ($green019) {
        Test-Ok 'TEST-019 GREEN: -ResolveTargetRaw(Protected=1) resolves all four protected basenames under specs/epic-159-pillar-c/human-copy/, never the real path'
    } else {
        Test-Bad 'TEST-019 GREEN: -ResolveTargetRaw(Protected=1) resolved at least one protected basename OUTSIDE human-copy/'
    }

    $green019Table = $true
    foreach ($rel in $protectedRelPaths) {
        $role = $roleForRelpath[$rel]
        $resolved = (Invoke-Render -RenderArgs @('-ResolveTargetRole', $role, '-ResolveTargetKind', 'claude', '-ResolveTargetRelPath', $rel)).StdOut.Trim()
        $expected = (Join-Path $root (Join-Path 'specs/epic-159-pillar-c/human-copy' $rel))
        if ($resolved -cne $expected) { $green019Table = $false }
    }
    if ($green019Table) {
        Test-Ok 'TEST-019 GREEN (default table): the shipped TARGETS table resolves all four protected basenames to human-copy/'
    } else {
        Test-Bad 'TEST-019 GREEN (default table): the shipped TARGETS table failed to classify a protected basename correctly'
    }

    $red019 = $true
    foreach ($rel in $protectedRelPaths) {
        $resolved = (Invoke-Render -RenderArgs @('-ResolveTargetRawPath', $rel, '-ResolveTargetRawProtected', '0')).StdOut.Trim()
        $expected = (Join-Path $root $rel)
        if ($resolved -cne $expected) { $red019 = $false }
    }
    if ($red019) {
        Test-Ok 'TEST-019 RED (widened/mis-scoped map): forcing Protected=0 on a protected basename resolves to the REAL path -- proves the resolution function is live'
    } else {
        Test-Bad 'TEST-019 RED (widened/mis-scoped map): forcing Protected=0 did NOT resolve to the real path'
    }

    # =======================================================================
    # TEST-014/015/017: real render against the scratch mirror.
    # =======================================================================
    Invoke-Render -RenderArgs @('-RepoRoot', $tmp, '-Registry', $registryDst) | Out-Null

    $expectedEffort = @{
        'plugins/sdd-quality-loop/agents/evaluator.md'          = 'high'
        'plugins/sdd-bootstrap/agents/investigator.md'          = 'low'
        'plugins/sdd-review-loop/agents/spec-reviewer-a.md'     = 'medium'
        'plugins/sdd-review-loop/agents/spec-reviewer-b.md'     = 'medium'
    }
    $test014Ok = $true
    foreach ($rel in $unprotectedClaudeRelPaths) {
        $p = Join-Path $tmp $rel
        $line = (Get-Content -Encoding utf8 $p | Where-Object { $_ -cmatch '^model:' } | Select-Object -First 1)
        $modelAfter = ($line -replace '^model:\s*', '')
        if ($modelAfter -cne $modelBefore[$rel]) { $test014Ok = $false }
        $content = [System.IO.File]::ReadAllText($p)
        if ($content -cnotmatch [regex]::Escape("<!-- x-sdd-effort: $($expectedEffort[$rel]) -->")) { $test014Ok = $false }
        $afterCount = (Get-Content -Encoding utf8 $p).Count
        if (($afterCount - $lineCountBefore[$rel]) -ne 1) { $test014Ok = $false }
    }
    if ($test014Ok) {
        Test-Ok 'TEST-014: unprotected Claude .md targets keep model: unchanged and gain exactly one x-sdd-effort comment line'
    } else {
        Test-Bad 'TEST-014: unprotected Claude .md render produced an unexpected diff'
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

    $test019WriteOk = $true
    foreach ($rel in $protectedRelPaths) {
        if ((Get-Sha256OfFile (Join-Path $tmp $rel)) -cne $shaBefore[$rel]) { $test019WriteOk = $false }
    }
    if ($test019WriteOk) {
        Test-Ok 'TEST-019: a full render pass left all four protected-position targets byte-unchanged at their real path'
    } else {
        Test-Bad 'TEST-019: a full render pass modified a protected-position target real path'
    }

    $test019StagedOk = $true
    foreach ($rel in $protectedRelPaths) {
        $staged = Join-Path $tmp (Join-Path 'specs/epic-159-pillar-c/human-copy' $rel)
        if (-not (Test-Path $staged)) { $test019StagedOk = $false; continue }
        $content = [System.IO.File]::ReadAllText($staged)
        if ($content -cnotmatch [regex]::Escape('<!-- x-sdd-effort: medium -->')) { $test019StagedOk = $false }
        $stagedSha = Get-Sha256OfFile $staged
        $manifestScratch = Join-Path $tmp 'specs/epic-159-pillar-c/human-copy/MANIFEST.sha256'
        $manifestText = [System.IO.File]::ReadAllText($manifestScratch)
        if ($manifestText -cnotmatch [regex]::Escape("$stagedSha  $rel")) { $test019StagedOk = $false }
    }
    if ($test019StagedOk) {
        Test-Ok 'TEST-019: corrected content for all four protected targets staged under human-copy/ with a matching MANIFEST.sha256 entry'
    } else {
        Test-Bad 'TEST-019: staged protected-target content or its MANIFEST.sha256 entry is missing/incorrect'
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

    $stagedTestYml = Join-Path $humanCopyDir '.github/workflows/test.yml'
    if ((Test-Path $stagedTestYml) -and (Select-String -Path $stagedTestYml -Pattern 'render-agent-frontmatter' -Quiet)) {
        Test-Ok 'TEST-016: the staged .github/workflows/test.yml candidate registers this suite CI step(s)'
    } else {
        Test-Bad 'TEST-016: the staged .github/workflows/test.yml candidate does not reference render-agent-frontmatter'
    }

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
    # Self-registration.
    # =======================================================================
    if (Select-String -Path $runAllSh -Pattern 'render-agent-frontmatter\.tests\.sh' -Quiet) {
        Test-Ok 'self-registration: render-agent-frontmatter.tests.sh registered in tests/run-all.sh'
    } else {
        Test-Bad 'self-registration: render-agent-frontmatter.tests.sh NOT registered in tests/run-all.sh'
    }
    if ((Test-Path $runAllPs1) -and (Select-String -Path $runAllPs1 -Pattern 'render-agent-frontmatter\.tests\.ps1' -Quiet)) {
        Test-Ok 'self-registration: render-agent-frontmatter.tests.ps1 registered in tests/run-all.ps1'
    } else {
        Test-Bad 'self-registration: render-agent-frontmatter.tests.ps1 NOT registered in tests/run-all.ps1'
    }

    # =======================================================================
    # Human-copy staging: five protected real targets.
    # =======================================================================
    $stagedAllRelPaths = $protectedRelPaths + @('.github/workflows/test.yml')
    $humanCopyOk = $true
    foreach ($rel in $stagedAllRelPaths) {
        $staged = Join-Path $humanCopyDir $rel
        if (-not (Test-Path $staged)) { $humanCopyOk = $false; continue }
        $stagedSha = Get-Sha256OfFile $staged
        $manifestText = [System.IO.File]::ReadAllText($manifestPath)
        if ($manifestText -cnotmatch [regex]::Escape("$stagedSha  $rel")) { $humanCopyOk = $false }
    }
    if ($humanCopyOk) {
        Test-Ok 'human-copy: all five staged candidates (four reviewer .md + test.yml) exist with a correct MANIFEST.sha256 entry'
    } else {
        Test-Bad 'human-copy: at least one staged candidate or its MANIFEST.sha256 entry is missing/incorrect'
    }

    $liveProtectedUnchanged = $true
    foreach ($rel in $protectedRelPaths) {
        if ((Get-Sha256OfFile (Join-Path $root $rel)) -cne $liveProtectedShaBefore[$rel]) { $liveProtectedUnchanged = $false }
    }
    if ($liveProtectedUnchanged) {
        Test-Ok 'AC-019/AC-027-style: the four live protected reviewer .md files are byte-unchanged before/after this suite own run'
    } else {
        Test-Bad 'AC-019/AC-027-style: a live protected reviewer .md file CHANGED during this suite own run'
    }
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
