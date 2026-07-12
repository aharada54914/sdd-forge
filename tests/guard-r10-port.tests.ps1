$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# TEST-001 / TEST-002 / TEST-003 (AC-001, AC-002, AC-003): cross-runtime decision
# parity for the R-10 protected-gate-file denial, the Impl-Review-Status forgery
# denial, and the read-only short-circuit. Drives all three guard twins
# (.ps1 / .py / .js) on a shared corpus and asserts DECISION EQUALITY
# (.ps1 == .py == .js) AND the expected exit code for every scenario, per the
# PowerShell Parity Note in security-spec.md (decisions, not message bytes).
#
# Guard paths are parameterized via environment variables. All three default to
# the LIVE twins (the T-001/T-002 fixes were human-applied via the human-copy
# procedure), so this suite doubles as the CI parity regression registered in
# tests/run-all.sh:
#   GUARD_PS1  default: live plugins/.../sdd-hook-guard.ps1
#   GUARD_PY   default: live plugins/.../sdd-hook-guard.py
#   GUARD_JS   default: live plugins/.../sdd-hook-guard.js
# Point GUARD_PS1 at a staged human-copy or historical .ps1 to reproduce the
# RED (no R-10 port -> diverges) / GREEN (ported -> converges) differential.

$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Get-EnvOrDefault {
    param([string]$Name, [string]$Default)
    $v = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrEmpty($v)) { return $Default }
    return $v
}

$guardPs1 = Get-EnvOrDefault "GUARD_PS1" (Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1")
$guardPy  = Get-EnvOrDefault "GUARD_PY"  (Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/sdd-hook-guard.py")
$guardJs  = Get-EnvOrDefault "GUARD_JS"  (Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/sdd-hook-guard.js")

Write-Host "guard-r10-port.tests.ps1"
Write-Host "  PS1: $guardPs1"
Write-Host "  PY : $guardPy"
Write-Host "  JS : $guardJs"

# Runtime availability (all three are required for a decision-parity assertion).
foreach ($rt in @(@("pwsh", "pwsh"), @("python3", "python3"), @("node", "node"))) {
    if (-not (Get-Command $rt[0] -ErrorAction SilentlyContinue)) {
        Write-Host "SKIP: guard-r10-port.tests.ps1 requires $($rt[1]) (not found)"
        exit 0
    }
}
foreach ($g in @($guardPs1, $guardPy, $guardJs)) {
    if (-not (Test-Path -LiteralPath $g)) {
        Write-Host "FAIL: guard not found: $g"
        exit 1
    }
}

# Isolated working directory: kill-switch / sudo / impl-review verdict lookups all
# resolve relative to this clean root, keeping the corpus deterministic.
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-r10-port-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $workDir | Out-Null

# Impl-Review-Status forgery fixtures (design.md targets + verdict artifacts).
New-Item -ItemType Directory -Path (Join-Path $workDir "specs/feat-noverdict") | Out-Null
New-Item -ItemType File      -Path (Join-Path $workDir "specs/feat-noverdict/design.md") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $workDir "specs/feat-pass") | Out-Null
New-Item -ItemType File      -Path (Join-Path $workDir "specs/feat-pass/design.md") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $workDir "reports/impl-review/feat-pass/attempt-1/round-1") -Force | Out-Null
Set-Content -Path (Join-Path $workDir "reports/impl-review/feat-pass/attempt-1/round-1/integrated-verdict.json") -Value '{"verdict":"PASS"}' -NoNewline
New-Item -ItemType Directory -Path (Join-Path $workDir "specs/feat-fail") | Out-Null
New-Item -ItemType File      -Path (Join-Path $workDir "specs/feat-fail/design.md") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $workDir "reports/impl-review/feat-fail/attempt-1/round-1") -Force | Out-Null
Set-Content -Path (Join-Path $workDir "reports/impl-review/feat-fail/attempt-1/round-1/integrated-verdict.json") -Value '{"verdict":"FAIL"}' -NoNewline

$passCount = 0
$failCount = 0

# Run one guard twin with a payload; returns the process exit code (deny=2/allow=0).
# All twins read the PAYLOAD env var first, so no stdin plumbing is needed. cwd and
# CLAUDE_PROJECT_DIR are pinned to $workDir so relative lookups are deterministic.
function Invoke-GuardExit {
    param([string]$Runtime, [string]$GuardPath, [string]$Payload)
    $savedDirCwd = [System.IO.Directory]::GetCurrentDirectory()
    $savedLoc = (Get-Location).Path
    $savedProjDir = $env:CLAUDE_PROJECT_DIR
    try {
        [System.IO.Directory]::SetCurrentDirectory($workDir)
        Set-Location -LiteralPath $workDir
        $env:CLAUDE_PROJECT_DIR = $workDir
        $env:PAYLOAD = $Payload
        switch ($Runtime) {
            "ps1" { & pwsh -NoProfile -ExecutionPolicy Bypass -File $GuardPath -Emit exit *> $null }
            "py"  { & python3 $GuardPath --emit exit *> $null }
            "js"  { & node $GuardPath --emit exit *> $null }
        }
        return $LASTEXITCODE
    } finally {
        Remove-Item Env:PAYLOAD -ErrorAction SilentlyContinue
        if ($null -eq $savedProjDir) { Remove-Item Env:CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $savedProjDir }
        [System.IO.Directory]::SetCurrentDirectory($savedDirCwd)
        Set-Location -LiteralPath $savedLoc
    }
}

# Assert .ps1 == .py == .js == expected for one scenario.
function Assert-Parity {
    param([string]$Name, [int]$Expected, [string]$Payload)
    $ps1 = Invoke-GuardExit "ps1" $guardPs1 $Payload
    $py  = Invoke-GuardExit "py"  $guardPy  $Payload
    $js  = Invoke-GuardExit "js"  $guardJs  $Payload
    if ($ps1 -eq $Expected -and $py -eq $Expected -and $js -eq $Expected) {
        Write-Host "ok: $Name (all exit $Expected)"
        $script:passCount++
    } else {
        Write-Host "FAIL: $Name expected=$Expected ps1=$ps1 py=$py js=$js"
        $script:failCount++
    }
}

# Run one guard twin in copilot emit mode; returns @(permissionDecision, exitCode).
# Copilot mode always exits 0 and reports the decision as JSON on stdout, so the
# parity assertion is on the decision string, not the exit code.
function Invoke-GuardCopilot {
    param([string]$Runtime, [string]$GuardPath, [string]$Payload)
    $savedDirCwd = [System.IO.Directory]::GetCurrentDirectory()
    $savedLoc = (Get-Location).Path
    $savedProjDir = $env:CLAUDE_PROJECT_DIR
    try {
        [System.IO.Directory]::SetCurrentDirectory($workDir)
        Set-Location -LiteralPath $workDir
        $env:CLAUDE_PROJECT_DIR = $workDir
        $env:PAYLOAD = $Payload
        $out = ""
        switch ($Runtime) {
            "ps1" { $out = & pwsh -NoProfile -ExecutionPolicy Bypass -File $GuardPath -Emit copilot 2>$null }
            "py"  { $out = & python3 $GuardPath --emit copilot 2>$null }
            "js"  { $out = & node $GuardPath --emit copilot 2>$null }
        }
        $code = $LASTEXITCODE
        $decision = "parse-error"
        try {
            $obj = ($out | Out-String).Trim() | ConvertFrom-Json
            if ($null -ne $obj.permissionDecision) { $decision = [string]$obj.permissionDecision }
        } catch { }
        return ,@($decision, $code)
    } finally {
        Remove-Item Env:PAYLOAD -ErrorAction SilentlyContinue
        if ($null -eq $savedProjDir) { Remove-Item Env:CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_PROJECT_DIR = $savedProjDir }
        [System.IO.Directory]::SetCurrentDirectory($savedDirCwd)
        Set-Location -LiteralPath $savedLoc
    }
}

# Assert copilot-mode parity: every twin prints permissionDecision == expected
# and exits 0.
function Assert-CopilotParity {
    param([string]$Name, [string]$Expected, [string]$Payload)
    $ps1 = Invoke-GuardCopilot "ps1" $guardPs1 $Payload
    $py  = Invoke-GuardCopilot "py"  $guardPy  $Payload
    $js  = Invoke-GuardCopilot "js"  $guardJs  $Payload
    $decisionsOk = ($ps1[0] -eq $Expected -and $py[0] -eq $Expected -and $js[0] -eq $Expected)
    $exitsOk = ($ps1[1] -eq 0 -and $py[1] -eq 0 -and $js[1] -eq 0)
    if ($decisionsOk -and $exitsOk) {
        Write-Host "ok: $Name (all $Expected, exit 0)"
        $script:passCount++
    } else {
        Write-Host "FAIL: $Name expected=$Expected ps1=$($ps1[0])/$($ps1[1]) py=$($py[0])/$($py[1]) js=$($js[0])/$($js[1])"
        $script:failCount++
    }
}

# --- Corpus (payloads live inside this file so the runner's command line never
#     pairs a protected path with a write verb) ---

# R-10 protected-table writes via file tools (deny 2) -- one per suffix class.
Assert-Parity "r10 file-write: sdd-hook-guard.py"          2 '{"tool_name":"write","tool_input":{"file_path":"plugins/sdd-quality-loop/scripts/sdd-hook-guard.py","content":"x"}}'
Assert-Parity "r10 file-write: .claude/settings.json"      2 '{"tool_name":"write","tool_input":{"file_path":".claude/settings.json","content":"x"}}'
Assert-Parity "r10 file-write: tests/gates.tests.sh"       2 '{"tool_name":"write","tool_input":{"file_path":"tests/gates.tests.sh","content":"x"}}'
Assert-Parity "r10 edit: ship/SKILL.md"                    2 '{"tool_name":"edit","tool_input":{"file_path":"plugins/sdd-ship/skills/ship/SKILL.md","old_string":"a","new_string":"b"}}'
Assert-Parity "r10 file-write: impl-review-loop SKILL.md"  2 '{"tool_name":"write","tool_input":{"file_path":"plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md","content":"x"}}'
Assert-Parity "r10 multiedit: check-contract.ps1"          2 '{"tool_name":"multiedit","tool_input":{"file_path":"plugins/sdd-quality-loop/scripts/check-contract.ps1","edits":[{"old_string":"a","new_string":"b"}]}}'
Assert-Parity "r10 file-write: claude-hooks.json"          2 '{"tool_name":"write","tool_input":{"file_path":"plugins/sdd-quality-loop/hooks/claude-hooks.json","content":"x"}}'
Assert-Parity "r10 apply_patch: sdd-hook-guard.py"         2 '{"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n*** Update File: plugins/sdd-quality-loop/scripts/sdd-hook-guard.py\n+x\n*** End Patch"}}'
Assert-Parity "r10 file-write: ../ traversal to guard"     2 '{"tool_name":"write","tool_input":{"file_path":"foo/../plugins/sdd-quality-loop/scripts/sdd-hook-guard.py","content":"x"}}'

# R-10 exhaustive protected-table coverage (RT-20260712-002): one write-denial
# fixture for every ProtectedGateSuffixes entry not already covered above, so
# the corpus exercises every protected suffix class rather than a sample
# (requirements.md Risks / design.md Test Strategy #2).
# hook guard twins (self-protection; .py covered above)
Assert-Parity "r10 file-write: sdd-hook-guard.js"          2 '{"tool_name":"write","tool_input":{"file_path":"plugins/sdd-quality-loop/scripts/sdd-hook-guard.js","content":"x"}}'
Assert-Parity "r10 file-write: sdd-hook-guard.ps1"         2 '{"tool_name":"write","tool_input":{"file_path":"plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1","content":"x"}}'
Assert-Parity "r10 edit: sdd-hook-guard.sh"                2 '{"tool_name":"edit","tool_input":{"file_path":"plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh","old_string":"a","new_string":"b"}}'
# kill-switch scripts
Assert-Parity "r10 file-write: kill-switch.js"             2 '{"tool_name":"write","tool_input":{"file_path":"plugins/sdd-quality-loop/scripts/kill-switch.js","content":"x"}}'
Assert-Parity "r10 file-write: kill-switch.sh"             2 '{"tool_name":"write","tool_input":{"file_path":"plugins/sdd-quality-loop/scripts/kill-switch.sh","content":"x"}}'
Assert-Parity "r10 file-write: kill-switch.ps1"            2 '{"tool_name":"write","tool_input":{"file_path":"plugins/sdd-quality-loop/scripts/kill-switch.ps1","content":"x"}}'
# hook registration files (claude-hooks.json covered above)
Assert-Parity "r10 file-write: hooks.json"                 2 '{"tool_name":"write","tool_input":{"file_path":"plugins/sdd-quality-loop/hooks/hooks.json","content":"x"}}'
Assert-Parity "r10 file-write: copilot-hooks.json"         2 '{"tool_name":"write","tool_input":{"file_path":"plugins/sdd-quality-loop/hooks/copilot-hooks.json","content":"x"}}'
# gate scripts (check-contract.ps1 covered above)
Assert-Parity "r10 file-write: check-contract.sh"          2 '{"tool_name":"write","tool_input":{"file_path":"plugins/sdd-quality-loop/scripts/check-contract.sh","content":"x"}}'
Assert-Parity "r10 file-write: check-contract.py"          2 '{"tool_name":"write","tool_input":{"file_path":"plugins/sdd-quality-loop/scripts/check-contract.py","content":"x"}}'
Assert-Parity "r10 file-write: check-evidence-bundle.sh"   2 '{"tool_name":"write","tool_input":{"file_path":"plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh","content":"x"}}'
Assert-Parity "r10 file-write: check-evidence-bundle.ps1"  2 '{"tool_name":"write","tool_input":{"file_path":"plugins/sdd-quality-loop/scripts/check-evidence-bundle.ps1","content":"x"}}'
Assert-Parity "r10 file-write: check-evidence-bundle.py"   2 '{"tool_name":"write","tool_input":{"file_path":"plugins/sdd-quality-loop/scripts/check-evidence-bundle.py","content":"x"}}'
# shared path-validation utility (R-01)
Assert-Parity "r10 file-write: validate_path.py"           2 '{"tool_name":"write","tool_input":{"file_path":"plugins/sdd-quality-loop/scripts/validate_path.py","content":"x"}}'
# Claude Code hook-loading config (settings.json covered above)
Assert-Parity "r10 file-write: settings.local.json"        2 '{"tool_name":"write","tool_input":{"file_path":".claude/settings.local.json","content":"x"}}'
# critical test files (gates.tests.sh covered above)
Assert-Parity "r10 file-write: tests/eval.tests.sh"        2 '{"tool_name":"write","tool_input":{"file_path":"tests/eval.tests.sh","content":"x"}}'
Assert-Parity "r10 file-write: tests/guard-parity.tests.sh" 2 '{"tool_name":"write","tool_input":{"file_path":"tests/guard-parity.tests.sh","content":"x"}}'
Assert-Parity "r10 file-write: tests/constant-parity.tests.sh" 2 '{"tool_name":"write","tool_input":{"file_path":"tests/constant-parity.tests.sh","content":"x"}}'
# review-loop agent role files
Assert-Parity "r10 edit: impl-reviewer-a.md"               2 '{"tool_name":"edit","tool_input":{"file_path":"plugins/sdd-review-loop/agents/impl-reviewer-a.md","old_string":"a","new_string":"b"}}'
Assert-Parity "r10 edit: impl-reviewer-b.md"               2 '{"tool_name":"edit","tool_input":{"file_path":"plugins/sdd-review-loop/agents/impl-reviewer-b.md","old_string":"a","new_string":"b"}}'
Assert-Parity "r10 multiedit: task-reviewer-a.md"          2 '{"tool_name":"multiedit","tool_input":{"file_path":"plugins/sdd-review-loop/agents/task-reviewer-a.md","edits":[{"old_string":"a","new_string":"b"}]}}'
Assert-Parity "r10 multiedit: task-reviewer-b.md"          2 '{"tool_name":"multiedit","tool_input":{"file_path":"plugins/sdd-review-loop/agents/task-reviewer-b.md","edits":[{"old_string":"a","new_string":"b"}]}}'
# review-loop skills (impl-review-loop + ship SKILL.md covered above)
Assert-Parity "r10 file-write: task-review-loop SKILL.md"  2 '{"tool_name":"write","tool_input":{"file_path":"plugins/sdd-review-loop/skills/task-review-loop/SKILL.md","content":"x"}}'

# ProtectedGatePluginJsonSuffixes branch (distinct matching loop): relative and
# absolute path forms across all three dot-dir entries, plus a non-dot-dir
# negative proving the branch matches the directory component, not the basename.
Assert-Parity "r10 plugin.json: .plugin relative"          2 '{"tool_name":"write","tool_input":{"file_path":"vendor/tool/.plugin/plugin.json","content":"x"}}'
Assert-Parity "r10 plugin.json: .claude-plugin relative"   2 '{"tool_name":"write","tool_input":{"file_path":"plugins/demo/.claude-plugin/plugin.json","content":"x"}}'
Assert-Parity "r10 plugin.json: .codex-plugin absolute"    2 '{"tool_name":"write","tool_input":{"file_path":"/opt/repo/plugins/demo/.codex-plugin/plugin.json","content":"x"}}'
Assert-Parity "allow: src/plugin.json (no plugin dot-dir)" 0 '{"tool_name":"write","tool_input":{"file_path":"src/plugin.json","content":"x"}}'

# R-10 protected writes via Bash, incl. the cwd/pushd forms (deny 2).
Assert-Parity "r10 bash redirect into guard"               2 '{"tool_name":"bash","tool_input":{"command":"echo x > plugins/sdd-quality-loop/scripts/sdd-hook-guard.py"}}'
Assert-Parity "r10 bash cd <dir> && rm <basename>"         2 '{"tool_name":"bash","tool_input":{"command":"cd plugins/sdd-quality-loop/scripts && rm sdd-hook-guard.py"}}'
Assert-Parity "r10 bash pushd <dir> && rm <basename>"      2 '{"tool_name":"bash","tool_input":{"command":"pushd plugins/sdd-quality-loop/scripts && rm sdd-hook-guard.py"}}'
Assert-Parity "r10 bash cp onto guard"                     2 '{"tool_name":"bash","tool_input":{"command":"cp /tmp/x plugins/sdd-quality-loop/scripts/sdd-hook-guard.py"}}'
Assert-Parity "r10 bash compound cat && rm guard"          2 '{"tool_name":"bash","tool_input":{"command":"cat plugins/sdd-quality-loop/scripts/sdd-hook-guard.py && rm plugins/sdd-quality-loop/scripts/sdd-hook-guard.py"}}'

# Read-only shell over protected paths (allow 0) -- short-circuit parity.
Assert-Parity "r10 read-only grep of guard"                0 '{"tool_name":"bash","tool_input":{"command":"grep -n R-10 plugins/sdd-quality-loop/scripts/sdd-hook-guard.py"}}'
Assert-Parity "r10 read-only cat settings"                 0 '{"tool_name":"bash","tool_input":{"command":"cat .claude/settings.json"}}'
Assert-Parity "r10 read-only cp FROM guard to /tmp"        0 '{"tool_name":"bash","tool_input":{"command":"cp plugins/sdd-quality-loop/scripts/sdd-hook-guard.py /tmp/backup.py"}}'

# Impl-Review-Status forgery on design.md (deny without a PASS verdict).
Assert-Parity "impl-review forgery: no verdict -> deny"    2 '{"tool_name":"write","tool_input":{"file_path":"specs/feat-noverdict/design.md","content":"Impl-Review-Status: Passed\n"}}'
Assert-Parity "impl-review: PASS verdict -> allow"         0 '{"tool_name":"write","tool_input":{"file_path":"specs/feat-pass/design.md","content":"Impl-Review-Status: Passed\n"}}'
Assert-Parity "impl-review: FAIL verdict -> deny"          2 '{"tool_name":"write","tool_input":{"file_path":"specs/feat-fail/design.md","content":"Impl-Review-Status: Passed\n"}}'

# Impl-Review-Status forgery via the edit/multiedit payload branches
# (RT-20260712-002: the write branch above left new_string/edits[] untested).
Assert-Parity "impl-review forgery edit: no verdict -> deny"        2 '{"tool_name":"edit","tool_input":{"file_path":"specs/feat-noverdict/design.md","old_string":"a","new_string":"Impl-Review-Status: Passed\n"}}'
Assert-Parity "impl-review forgery multiedit: FAIL verdict -> deny" 2 '{"tool_name":"multiedit","tool_input":{"file_path":"specs/feat-fail/design.md","edits":[{"old_string":"a","new_string":"Impl-Review-Status: Passed\n"}]}}'
Assert-Parity "impl-review edit: PASS verdict -> allow"             0 '{"tool_name":"edit","tool_input":{"file_path":"specs/feat-pass/design.md","old_string":"a","new_string":"Impl-Review-Status: Passed\n"}}'

# Copilot emit mode (RT-20260712-002): the new denials must surface as
# permissionDecision=deny with exit 0 in every twin, and an allow stays allow.
Assert-CopilotParity "copilot-emit: r10 write to guard -> deny" "deny"  '{"tool_name":"write","tool_input":{"file_path":"plugins/sdd-quality-loop/scripts/sdd-hook-guard.py","content":"x"}}'
Assert-CopilotParity "copilot-emit: cd+rm guard -> deny"        "deny"  '{"tool_name":"bash","tool_input":{"command":"cd plugins/sdd-quality-loop/scripts && rm sdd-hook-guard.py"}}'
Assert-CopilotParity "copilot-emit: write src/main.py -> allow" "allow" '{"tool_name":"write","tool_input":{"file_path":"src/main.py","content":"print(1)"}}'

# Non-protected writes (allow 0).
Assert-Parity "allow: write src/main.py"                   0 '{"tool_name":"write","tool_input":{"file_path":"src/main.py","content":"print(1)"}}'
Assert-Parity "allow: edit README.md"                      0 '{"tool_name":"edit","tool_input":{"file_path":"README.md","old_string":"a","new_string":"b"}}'

# Malformed / fail-closed payloads (deny 2).
Assert-Parity "malformed: empty object"                    2 '{}'
Assert-Parity "malformed: write missing file_path"         2 '{"tool_name":"write","tool_input":{"content":"x"}}'
Assert-Parity "malformed: empty payload string"            2 ''

# --- Cleanup + summary ---
try { Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue } catch { }

Write-Host ""
Write-Host "guard-r10-port.tests.ps1: $passCount passed, $failCount failed"
if ($failCount -ne 0) { exit 1 }
exit 0
