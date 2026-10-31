# Suite: effort-policy-flip (T-007, epic-159-pillar-c, #155) -- REQ-007 /
# AC-041..046. PowerShell twin of tests/effort-policy-flip.tests.sh,
# equivalent coverage (see that file's header for the full design rationale:
# TEST-041 is the only case whose outcome depends on the flip itself;
# TEST-044's real Codex-host smoke SKIPs cleanly unless the operator opts in
# via SDD_ALLOW_REAL_CODEX_SMOKE=1; this suite is NOT registered in
# tests/run-all.ps1 -- T-007's own Planned Files list does not include it,
# unlike T-001/T-003/T-005/T-006).
#
# Case-sensitivity: every string comparison uses -ceq/-cne (schema strings,
# effort tokens, and model names are case-sensitive contract values).
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$selectorPs = Join-Path $repoRoot "plugins/sdd-implementation/scripts/select-agent-model.ps1"
$v2RegistryPath = Join-Path $repoRoot "contracts/agent-model-capabilities.v2.json"
$userGuide = Join-Path $repoRoot "USERGUIDE.md"
$capMatrix = Join-Path $repoRoot "docs/agent-capability-matrix.md"
$changelogPath = Join-Path $repoRoot "CHANGELOG.md"

$script:passCount = 0
$script:failCount = 0
$script:skipCount = 0
function Ok([string]$Name) { Write-Output "ok: $Name"; $script:passCount++ }
function Fail([string]$Name) { Write-Output "not ok: $Name"; $script:failCount++ }
function Skip([string]$Name) { Write-Output "skip: $Name"; $script:skipCount++ }

if (-not (Test-Path -LiteralPath $selectorPs)) {
    Write-Output "not ok: select-agent-model.ps1 missing at $selectorPs"
    exit 1
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("effort-policy-flip-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    # --- TEST-041 (AC-041): default (no -EffortPolicy) resolves to matrix
    # post-flip. Same discriminating fixture as the .sh twin: declared
    # effort "xhigh" on openai/gpt-5.2-codex (supported [high, xhigh]);
    # welded keeps "xhigh", matrix (risk low -> clamp) gives "high".
    $cand041Path = Join-Path $tmp "candidates-041.json"
    '[{"name": "openai/gpt-5.2-codex", "cost": "1.0", "available": true, "effort": "xhigh"}]' |
        Set-Content -LiteralPath $cand041Path -Encoding utf8NoBOM

    $out041 = & $selectorPs -Risk low -RequiredTier strong `
        -XhighReason "TEST-041 fixture (effort-policy-flip suite)" `
        -Registry $v2RegistryPath -CandidatesFile $cand041Path -Json | ConvertFrom-Json

    if ($out041.effort_source -ceq "risk-matrix" -and $out041.effort -ceq "high") {
        Ok "TEST-041: no -EffortPolicy flag resolves to matrix post-flip (effort_source=risk-matrix, effort=high)"
    } elseif ($out041.effort_source -ceq "welded" -and $out041.effort -ceq "xhigh") {
        Fail "TEST-041: default still resolves to welded (effort_source=welded, effort=xhigh) -- the flip has not landed yet"
    } else {
        Fail "TEST-041: unexpected default-policy output -- effort_source=$($out041.effort_source) effort=$($out041.effort)"
    }

    $out041b = & $selectorPs -Risk low -RequiredTier strong -EffortPolicy welded `
        -XhighReason "TEST-041b fixture" `
        -Registry $v2RegistryPath -CandidatesFile $cand041Path -Json | ConvertFrom-Json
    if ($out041b.effort -ceq "xhigh") {
        Ok "TEST-041 (welded carve-out, OQ-004): -EffortPolicy welded still reproduces the pre-flip declared value (xhigh) explicitly"
    } else {
        Fail "TEST-041 (welded carve-out): -EffortPolicy welded produced effort=$($out041b.effort), expected xhigh"
    }

    # --- TEST-042 (AC-042): first production role_defaults render is
    # zero-diff. render-agent-frontmatter.sh reads role_defaults directly
    # from the registry (never through select-agent-model), so this is
    # mechanically independent of the flip; still this task's own
    # Done-When item. Invoked via bash (the renderer has no .ps1 twin
    # per T-003's own Planned Files -- render-agent-frontmatter.sh is the
    # sole script, bash-hosted).
    $renderSh = Join-Path $repoRoot "render-agent-frontmatter.sh"
    if (Get-Command bash -ErrorAction SilentlyContinue) {
        & bash $renderSh --check --root $repoRoot 2>&1 | Out-String -OutVariable renderOutVar | Out-Null
        $renderExit = $LASTEXITCODE
        if ($renderExit -eq 0) {
            Ok "TEST-042: first production role_defaults render is zero-diff"
        } else {
            Fail "TEST-042: render-agent-frontmatter --check reported non-zero diff (documented, not silently applied) -- $renderOutVar"
        }
    } else {
        Skip "TEST-042: bash not available to invoke render-agent-frontmatter.sh --check on this host"
    }

    # --- TEST-043 (AC-043): USERGUIDE.md / docs/agent-capability-matrix.md
    # / CHANGELOG.md describe the matrix-default policy ------------------
    # ASCII-only file constraint: the Japanese marker substrings below are
    # built from Unicode char codes rather than embedded literally (repo
    # convention: .ps1 files stay pure ASCII).
    $jpKiteiGa = -join ([char]0x65E2, [char]0x5B9A, [char]0x5024, [char]0x304C)      # kitei-ga
    $jpKiteiWo = -join ([char]0x65E2, [char]0x5B9A, [char]0x5024, [char]0x3092)      # kitei-wo
    $jpNiHenkou = -join ([char]0x306B, [char]0x5909, [char]0x66F4)                    # ni-henkou
    $userGuideMarker = $jpKiteiGa + ' `matrix`'
    $changelogMarker = $jpKiteiWo + ' `matrix` ' + $jpNiHenkou

    $test043Fail = $false
    if ((Test-Path -LiteralPath $userGuide) -and
        (Select-String -LiteralPath $userGuide -SimpleMatch -CaseSensitive $userGuideMarker -Quiet)) {
        Ok "TEST-043: USERGUIDE.md describes the matrix-default effort policy"
    } else {
        Fail "TEST-043: USERGUIDE.md does not describe the matrix-default effort policy"
        $test043Fail = $true
    }
    if ((Test-Path -LiteralPath $capMatrix) -and
        (Select-String -LiteralPath $capMatrix -SimpleMatch -CaseSensitive 'default effort policy is `matrix`' -Quiet)) {
        Ok "TEST-043: docs/agent-capability-matrix.md describes the matrix-default effort policy"
    } else {
        Fail "TEST-043: docs/agent-capability-matrix.md does not describe the matrix-default effort policy"
        $test043Fail = $true
    }
    if ((Test-Path -LiteralPath $changelogPath) -and
        (Select-String -LiteralPath $changelogPath -SimpleMatch -CaseSensitive $changelogMarker -Quiet)) {
        Ok "TEST-043: CHANGELOG.md describes the matrix-default effort policy"
    } else {
        Fail "TEST-043: CHANGELOG.md does not describe the matrix-default effort policy"
        $test043Fail = $true
    }
    if (-not $test043Fail) {
        Ok "TEST-043: all three REQ-009 doc surfaces describe the matrix-default policy"
    }

    # --- TEST-044 (AC-044): real Codex-host smoke -----------------------
    # Scoped to implementation/release-time verification only (design.md
    # Test Strategy point 8); SKIPs unless the operator explicitly opts in.
    # This twin does not re-implement the real-invocation path (the .sh
    # twin is authoritative for it when opted into) -- it SKIPs identically.
    if ($env:SDD_ALLOW_REAL_CODEX_SMOKE -ne "1") {
        Skip "TEST-044: real Codex-host smoke skipped -- SDD_ALLOW_REAL_CODEX_SMOKE not set to 1 (see reports/implementation/epic-159-pillar-c/T-007.md Unresolved Items; the .sh twin is authoritative for the opted-in real-invocation path)"
    } elseif (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
        Skip "TEST-044: real Codex-host smoke skipped -- no 'codex' binary on PATH"
    } else {
        Skip "TEST-044: real Codex-host smoke deferred to the .sh twin even when opted in (single real-invocation path, avoids double LLM spend across both lanes)"
    }

    # --- TEST-045 (AC-045): prerequisite-gate re-run --------------------
    $a3Sha = "2d8c6a561e0f5d2bc29ded4195c057d4cc918f2f"
    $phase1MergeSha = "825d6c6623ba98b6588a3c9942420dd13fceec88"
    Push-Location $repoRoot
    try {
        $implHead = (git rev-parse HEAD).Trim()
        & git merge-base --is-ancestor $a3Sha $implHead
        $a3IsAncestor = ($LASTEXITCODE -eq 0)
        & git merge-base --is-ancestor $phase1MergeSha $implHead
        $phase1IsAncestor = ($LASTEXITCODE -eq 0)
    } finally {
        Pop-Location
    }
    $test045Fail = $false
    if ($a3IsAncestor) {
        Ok "TEST-045: A3 ($a3Sha) is an ancestor of the implementation-time HEAD ($implHead)"
    } else {
        Fail "TEST-045: A3 ($a3Sha) is NOT an ancestor of HEAD -- prerequisite gate BLOCKED"
        $test045Fail = $true
    }
    if ($phase1IsAncestor) {
        Ok "TEST-045: T-001..T-006's Phase 1 merge commit ($phase1MergeSha, PR #185) is an ancestor of the implementation-time HEAD"
    } else {
        Fail "TEST-045: T-001..T-006's Phase 1 merge commit is NOT an ancestor of HEAD -- prerequisite gate BLOCKED"
        $test045Fail = $true
    }
    if (-not $test045Fail) {
        Ok "TEST-045: prerequisite gate satisfied at implementation time (the release-commit re-run is the caller's own job at release time)"
    }

    # --- TEST-046 (AC-046, REQ-009): process-conformance proxy ----------
    Push-Location $repoRoot
    try {
        $branch = (git branch --show-current).Trim()
    } finally {
        Pop-Location
    }
    $test046Fail = $false
    if ($branch -match "t007|T-007|pillar-c-t007") {
        Ok "TEST-046: current branch ($branch) is T-007-scoped, distinct from any T-001..T-006 branch"
    } else {
        Fail "TEST-046: current branch ($branch) does not look T-007-scoped -- cannot confirm PR separation"
        $test046Fail = $true
    }
    $changelogHead = Get-Content -LiteralPath $changelogPath -TotalCount 5
    if ($changelogHead -contains "## Unreleased") {
        Ok "TEST-046: CHANGELOG.md's '## Unreleased' heading is unrenamed -- this implementation session did not itself invoke scripts/bump-version.sh"
    } else {
        Fail "TEST-046: CHANGELOG.md's '## Unreleased' heading is missing/renamed -- a release may have been invoked inside this implementation session"
        $test046Fail = $true
    }
    if (-not $test046Fail) {
        Ok "TEST-046: process-conformance proxy satisfied (full proof is verified by the caller at PR-creation time)"
    }
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "---- summary: pass=$($script:passCount) fail=$($script:failCount) skip=$($script:skipCount) ----"
if ($script:failCount -gt 0) {
    Write-Output "not ok: effort-policy-flip suite FAILED ($($script:failCount) failures, $($script:skipCount) skipped)"
    exit 1
}
Write-Output "ok: effort-policy-flip suite passed ($($script:passCount) checks, $($script:skipCount) skipped)"
exit 0
