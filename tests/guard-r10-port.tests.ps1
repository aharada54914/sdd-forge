$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# TEST-001 / TEST-002 / TEST-003 (AC-001, AC-002, AC-003): cross-runtime decision
# parity for the R-10 protected-gate-file denial, the Impl-Review-Status forgery
# denial, and the read-only short-circuit. Drives all three guard twins
# (.ps1 / .py / .js) on a shared corpus and asserts DECISION EQUALITY
# (.ps1 == .py == .js) AND the expected exit code for every scenario, per the
# PowerShell Parity Note in security-spec.md (decisions, not message bytes).
#
# Guard paths are parameterized via environment variables so the same suite
# captures RED (live .ps1 without R-10 -> diverges from the .py/.js twins) and
# GREEN (staged .ps1 with R-10 -> converges):
#   GUARD_PS1  default: live plugins/.../sdd-hook-guard.ps1
#   GUARD_PY   default: staged human-copy/sdd-hook-guard.py (T-002 cwd-fixed)
#   GUARD_JS   default: staged human-copy/sdd-hook-guard.js (T-002 cwd-fixed)
# The .py/.js default to the T-002 staged fixed twins so the corpus is consistent
# across RED and GREEN (only the .ps1 target changes between the two runs).

$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Get-EnvOrDefault {
    param([string]$Name, [string]$Default)
    $v = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrEmpty($v)) { return $Default }
    return $v
}

$guardPs1 = Get-EnvOrDefault "GUARD_PS1" (Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1")
$guardPy  = Get-EnvOrDefault "GUARD_PY"  (Join-Path $repositoryRoot "specs/epic-136-phase1-guards/human-copy/sdd-hook-guard.py")
$guardJs  = Get-EnvOrDefault "GUARD_JS"  (Join-Path $repositoryRoot "specs/epic-136-phase1-guards/human-copy/sdd-hook-guard.js")

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
