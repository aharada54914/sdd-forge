#!/usr/bin/env pwsh
# tests/cli-hook-enforcement.ps1  (B2)
#
# Verifies that the SDD hook guard blocks an agent self-approval through the EXACT
# command line each CLI's hook config uses, with the real CLI toolchain present on
# the runner. pwsh runs on all GitHub runners (Windows/macOS/Linux), so a single
# cross-platform script covers every OS in the matrix.
#
# Deterministic and secret-free: it drives the guard exactly as Claude Code (node
# .js), Codex CLI (sh .sh / pwsh .ps1), and Copilot CLI (--emit copilot JSON)
# invoke it, then asserts a self-approval Edit is DENIED and a benign Edit ALLOWED.
# Exits non-zero on any failure.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scripts  = Join-Path $repoRoot 'plugins/sdd-quality-loop/scripts'
$hooksDir = Join-Path $repoRoot 'plugins/sdd-quality-loop/hooks'
$pass = 0; $fail = 0
function ok($m)  { Write-Host "ok: $m";   $script:pass++ }
function bad($m) { Write-Host "FAIL: $m"; $script:fail++ }

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("cli-hook-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
    $tasks = Join-Path $work 'tasks.md'
    Set-Content -Path $tasks -Encoding Utf8NoBOM -Value "## T-001`nApproval: Draft`nStatus: Planned"
    $tasksFwd    = ($tasks -replace '\\', '/')
    $selfApprove = '{"tool_name":"Edit","tool_input":{"file_path":"' + $tasksFwd + '","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'
    $benign      = '{"tool_name":"Edit","tool_input":{"file_path":"' + ($work -replace '\\', '/') + '/src.js","old_string":"a","new_string":"b"}}'

    # --- which CLIs are actually installed on this runner (informational) ---
    foreach ($cli in 'claude', 'codex', 'copilot') {
        if (Get-Command $cli -ErrorAction SilentlyContinue) {
            ok "CLI present on PATH: $cli"
        } else {
            Write-Host "info: CLI not on PATH (its hook command is still exercised directly): $cli"
        }
    }

    # --- Claude Code hook form: node sdd-hook-guard.js --emit exit ---
    $js = Join-Path $scripts 'sdd-hook-guard.js'
    if (Get-Command node -ErrorAction SilentlyContinue) {
        $selfApprove | & node $js --emit exit *> $null; $dc = $LASTEXITCODE
        if ($dc -eq 2) { ok 'claude-code (node --emit exit): self-approval DENIED (exit 2)' }
        else { bad "claude-code (node): self-approval expected exit 2, got $dc" }
        $benign | & node $js --emit exit *> $null; $ac = $LASTEXITCODE
        if ($ac -eq 0) { ok 'claude-code (node --emit exit): benign edit ALLOWED (exit 0)' }
        else { bad "claude-code (node): benign expected exit 0, got $ac" }
    } else {
        bad 'node not found: Claude Code hook (.js) cannot be exercised'
    }

    # --- Codex/Copilot hook form on Windows: pwsh sdd-hook-guard.ps1 -Emit exit ---
    $ps1 = Join-Path $scripts 'sdd-hook-guard.ps1'
    $selfApprove | & pwsh -NoProfile -File $ps1 -Emit exit *> $null; $dc = $LASTEXITCODE
    if ($dc -eq 2) { ok 'codex/copilot (pwsh .ps1 -Emit exit): self-approval DENIED (exit 2)' }
    else { bad "codex/copilot (.ps1 -Emit exit): self-approval expected exit 2, got $dc" }

    # --- Copilot JSON form: .ps1 -Emit copilot => permissionDecision deny/allow ---
    $denyJson = ($selfApprove | & pwsh -NoProfile -File $ps1 -Emit copilot | Out-String)
    if ($denyJson -match '"permissionDecision"\s*:\s*"deny"') { ok 'copilot (.ps1 -Emit copilot): self-approval => deny' }
    else { bad "copilot (.ps1 -Emit copilot): expected deny, got: $denyJson" }
    $allowJson = ($benign | & pwsh -NoProfile -File $ps1 -Emit copilot | Out-String)
    if ($allowJson -match '"permissionDecision"\s*:\s*"allow"') { ok 'copilot (.ps1 -Emit copilot): benign => allow' }
    else { bad "copilot (.ps1 -Emit copilot): expected allow, got: $allowJson" }

    # --- POSIX hook form (non-Windows): sh sdd-hook-guard.sh --emit exit / copilot ---
    if ($IsLinux -or $IsMacOS) {
        $sh = Join-Path $scripts 'sdd-hook-guard.sh'
        $selfApprove | & sh $sh --emit exit *> $null; $dc = $LASTEXITCODE
        if ($dc -eq 2) { ok 'codex (sh .sh --emit exit): self-approval DENIED (exit 2)' }
        else { bad "codex (sh .sh --emit exit): self-approval expected exit 2, got $dc" }
        $denyShJson = ($selfApprove | & sh $sh --emit copilot | Out-String)
        if ($denyShJson -match '"permissionDecision"\s*:\s*"deny"') { ok 'copilot (sh .sh --emit copilot): self-approval => deny' }
        else { bad "copilot (sh .sh --emit copilot): expected deny, got: $denyShJson" }
    }

    # --- config-drift: the hook configs must reference exactly these invocations ---
    $claudeCfg  = Get-Content (Join-Path $hooksDir 'claude-hooks.json') -Raw
    $codexCfg   = Get-Content (Join-Path $hooksDir 'hooks.json') -Raw
    $copilotCfg = Get-Content (Join-Path $hooksDir 'copilot-hooks.json') -Raw
    if ($claudeCfg -match 'sdd-hook-guard\.js' -and $claudeCfg -match '"--emit"\s*,\s*"exit"') {
        ok 'drift: claude-hooks.json invokes node sdd-hook-guard.js --emit exit'
    } else { bad 'drift: claude-hooks.json no longer invokes node sdd-hook-guard.js --emit exit' }
    if ($codexCfg -match 'sdd-hook-guard\.sh.*--emit exit') {
        ok 'drift: hooks.json invokes sdd-hook-guard.sh --emit exit'
    } else { bad 'drift: hooks.json no longer invokes sdd-hook-guard.sh --emit exit' }
    if ($copilotCfg -match 'sdd-hook-guard\.sh.*--emit copilot') {
        ok 'drift: copilot-hooks.json invokes sdd-hook-guard.sh --emit copilot'
    } else { bad 'drift: copilot-hooks.json no longer invokes sdd-hook-guard.sh --emit copilot' }

} finally {
    if (Test-Path $work) { Remove-Item $work -Recurse -Force }
}

Write-Host ''
Write-Host "CLI hook enforcement: $pass passed, $fail failed."
if ($fail -gt 0) { exit 1 }
Write-Host 'cli-hook-enforcement passed.'
