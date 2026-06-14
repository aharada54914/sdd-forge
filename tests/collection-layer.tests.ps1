# collection-layer.tests.ps1 — offline tests for T-005 collection layer (pwsh)
# Tests detect-panel graceful-degrade and runner presence/format.
# No real CLI invocations; no network access.
# Style: mirrors cross-model.tests.ps1 (ok/fail counters, temp dirs, exits 1 on failure)
$ErrorActionPreference = "Stop"

$RepoRoot   = Split-Path $PSScriptRoot -Parent
$ScriptsDir = Join-Path $RepoRoot "plugins/sdd-quality-loop/scripts"
$Pass = 0
$Fail = 0

function ok   { param($msg) Write-Host "ok: $msg";   $script:Pass++ }
function fail { param($msg) Write-Host "FAIL: $msg"; $script:Fail++ }

$Work = [System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName()
New-Item -ItemType Directory -Path $Work -Force | Out-Null

try {

# ============================================================================
# CL-001: detect-panel — no CLIs in PATH → exit 1, warning on stderr
# ============================================================================

Write-Host "=== CL-001: detect-panel graceful degrade (no CLIs) ==="

# Strip PATH to something that has no codex/gemini/openai
$minPath = "C:\Windows\System32;C:\Windows"
if ($IsLinux -or $IsMacOS) { $minPath = "/usr/bin:/bin" }

$dpProc = Start-Process -FilePath "pwsh" `
    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$ScriptsDir/detect-panel.ps1" `
    -Environment @{ PATH = $minPath } `
    -RedirectStandardOutput (Join-Path $Work "dp001-stdout.txt") `
    -RedirectStandardError  (Join-Path $Work "dp001-stderr.txt") `
    -Wait -PassThru -NoNewWindow
$dpStderr = Get-Content (Join-Path $Work "dp001-stderr.txt") -Raw -ErrorAction SilentlyContinue

if ($dpProc.ExitCode -eq 1) {
    ok "CL-001a: no CLIs in PATH -> exit 1 (graceful degrade)"
} else {
    fail "CL-001a: expected exit 1, got $($dpProc.ExitCode)"
}

if ($dpStderr -imatch "warning|no non-anthropic|not found") {
    ok "CL-001b: warning message emitted to stderr"
} else {
    fail "CL-001b: expected warning, got: $dpStderr"
}

if ($dpStderr -imatch "codex|gemini") {
    ok "CL-001c: warning names missing CLIs"
} else {
    fail "CL-001c: warning should mention codex or gemini, got: $dpStderr"
}

# ============================================================================
# CL-002: detect-panel -Quiet — suppresses warning
# ============================================================================

Write-Host "=== CL-002: detect-panel -Quiet suppresses warning ==="

$dpProc2 = Start-Process -FilePath "pwsh" `
    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$ScriptsDir/detect-panel.ps1", "-Quiet" `
    -Environment @{ PATH = $minPath } `
    -RedirectStandardOutput (Join-Path $Work "dp002-stdout.txt") `
    -RedirectStandardError  (Join-Path $Work "dp002-stderr.txt") `
    -Wait -PassThru -NoNewWindow
$dpStdout2 = Get-Content (Join-Path $Work "dp002-stdout.txt") -Raw -ErrorAction SilentlyContinue
$dpStderr2 = Get-Content (Join-Path $Work "dp002-stderr.txt") -Raw -ErrorAction SilentlyContinue

if ($dpProc2.ExitCode -eq 1) {
    ok "CL-002a: -Quiet still exits 1 on no CLIs"
} else {
    fail "CL-002a: expected exit 1, got $($dpProc2.ExitCode)"
}

if ([string]::IsNullOrWhiteSpace($dpStdout2) -and [string]::IsNullOrWhiteSpace($dpStderr2)) {
    ok "CL-002b: -Quiet produces no output"
} else {
    fail "CL-002b: -Quiet should produce no output; stdout='$dpStdout2' stderr='$dpStderr2'"
}

# ============================================================================
# CL-003: detect-panel — stub codex in PATH → exit 0, 'gpt' slug
# ============================================================================

Write-Host "=== CL-003: detect-panel detects stub codex ==="

$stubBin3 = Join-Path $Work "stub3"
New-Item -ItemType Directory -Path $stubBin3 -Force | Out-Null
# Create a stub codex script
$stubCodex = Join-Path $stubBin3 "codex.ps1"
Set-Content -Path $stubCodex -Value "exit 0"
# Also create a wrapper cmd for PATH detection
$stubCodexCmd = Join-Path $stubBin3 "codex"
if ($IsLinux -or $IsMacOS) {
    Set-Content -Path $stubCodexCmd -Value "#!/bin/sh`nexit 0"
    & chmod +x $stubCodexCmd
}

$testPath3 = if ($IsLinux -or $IsMacOS) { "${stubBin3}:/usr/bin:/bin" } else { "$stubBin3;C:\Windows\System32" }
$dpProc3 = Start-Process -FilePath "pwsh" `
    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$ScriptsDir/detect-panel.ps1" `
    -Environment @{ PATH = $testPath3 } `
    -RedirectStandardOutput (Join-Path $Work "dp003-stdout.txt") `
    -RedirectStandardError  (Join-Path $Work "dp003-stderr.txt") `
    -Wait -PassThru -NoNewWindow
$dpOut3 = Get-Content (Join-Path $Work "dp003-stdout.txt") -Raw -ErrorAction SilentlyContinue

if ($dpProc3.ExitCode -eq 0) {
    ok "CL-003a: codex stub in PATH -> exit 0"
} else {
    fail "CL-003a: expected exit 0 with codex stub, got $($dpProc3.ExitCode)"
}

if ($dpOut3 -match "(?m)^gpt$") {
    ok "CL-003b: 'gpt' slug emitted"
} else {
    fail "CL-003b: expected 'gpt' slug, got: $dpOut3"
}

# ============================================================================
# CL-007: runner scripts are present
# ============================================================================

Write-Host "=== CL-007: runner scripts present ==="

$scripts = @(
    "detect-panel.sh", "detect-panel.ps1",
    "run-panelist-gpt.sh", "run-panelist-gpt.ps1",
    "run-panelist-gemini.sh", "run-panelist-gemini.ps1"
)
foreach ($s in $scripts) {
    $p = Join-Path $ScriptsDir $s
    if (Test-Path $p) {
        ok "CL-007: $s present"
    } else {
        fail "CL-007: $s MISSING at $p"
    }
}

# ============================================================================
# CL-008: run-panelist-gpt graceful degrade (no codex)
# ============================================================================

Write-Host "=== CL-008: run-panelist-gpt graceful degrade (no codex) ==="

$cl008 = Join-Path $Work "cl008"
New-Item -ItemType Directory -Path "$cl008/specs/feat/verification" -Force | Out-Null
$digest = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
Set-Content -Path "$cl008/input.txt" -Value "# Panelist Input Bundle`n# task_id: T-005`n# feature: feat`n# input_digest: $digest`n# consent: human-flag`n`ntest"

$runProc8 = Start-Process -FilePath "pwsh" `
    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$ScriptsDir/run-panelist-gpt.ps1",
        "--task", "T-005", "--feature", "feat",
        "--input", "$cl008/input.txt",
        "--spec-root", "$cl008/specs" `
    -Environment @{ PATH = $minPath } `
    -RedirectStandardOutput (Join-Path $Work "run008-stdout.txt") `
    -RedirectStandardError  (Join-Path $Work "run008-stderr.txt") `
    -Wait -PassThru -NoNewWindow
$runErr8 = Get-Content (Join-Path $Work "run008-stderr.txt") -Raw -ErrorAction SilentlyContinue

if ($runProc8.ExitCode -eq 1) {
    ok "CL-008a: run-panelist-gpt no CLI -> exit 1 (graceful degrade)"
} else {
    fail "CL-008a: expected exit 1 for absent codex, got $($runProc8.ExitCode)"
}

if ($runErr8 -imatch "not found|graceful|degrade|codex") {
    ok "CL-008b: run-panelist-gpt emits informative message"
} else {
    fail "CL-008b: expected informative message, got: $runErr8"
}

# ============================================================================
# CL-009: run-panelist-gemini graceful degrade (no gemini)
# ============================================================================

Write-Host "=== CL-009: run-panelist-gemini graceful degrade (no gemini) ==="

$cl009 = Join-Path $Work "cl009"
New-Item -ItemType Directory -Path "$cl009/specs/feat/verification" -Force | Out-Null
Copy-Item "$cl008/input.txt" "$cl009/input.txt"

$runProc9 = Start-Process -FilePath "pwsh" `
    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$ScriptsDir/run-panelist-gemini.ps1",
        "--task", "T-005", "--feature", "feat",
        "--input", "$cl009/input.txt",
        "--spec-root", "$cl009/specs" `
    -Environment @{ PATH = $minPath } `
    -RedirectStandardOutput (Join-Path $Work "run009-stdout.txt") `
    -RedirectStandardError  (Join-Path $Work "run009-stderr.txt") `
    -Wait -PassThru -NoNewWindow
$runErr9 = Get-Content (Join-Path $Work "run009-stderr.txt") -Raw -ErrorAction SilentlyContinue

if ($runProc9.ExitCode -eq 1) {
    ok "CL-009a: run-panelist-gemini no CLI -> exit 1 (graceful degrade)"
} else {
    fail "CL-009a: expected exit 1 for absent gemini, got $($runProc9.ExitCode)"
}

if ($runErr9 -imatch "not found|graceful|degrade|gemini") {
    ok "CL-009b: run-panelist-gemini emits informative message"
} else {
    fail "CL-009b: expected informative message, got: $runErr9"
}

# ============================================================================
# CL-010: runner required arg validation → exit 2
# ============================================================================

Write-Host "=== CL-010: runner required arg validation ==="

foreach ($runner in @("run-panelist-gpt.ps1", "run-panelist-gemini.ps1")) {
    $rProc = Start-Process -FilePath "pwsh" `
        -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$ScriptsDir/$runner",
            "--feature", "feat", "--input", "nul" `
        -RedirectStandardOutput (Join-Path $Work "rval-stdout.txt") `
        -RedirectStandardError  (Join-Path $Work "rval-stderr.txt") `
        -Wait -PassThru -NoNewWindow
    if ($rProc.ExitCode -eq 2) {
        ok "CL-010: $runner missing --task -> exit 2"
    } else {
        fail "CL-010: $runner missing --task should exit 2, got $($rProc.ExitCode)"
    }
}

# ============================================================================
# CL-011: TOML agent files have developer_instructions
# ============================================================================

Write-Host "=== CL-011: TOML agent files contain developer_instructions ==="

foreach ($toml in @(
    (Join-Path $RepoRoot ".codex/agents/sdd-panelist-gpt.toml"),
    (Join-Path $RepoRoot ".codex/agents/sdd-panelist-gemini.toml")
)) {
    if (-not (Test-Path $toml)) {
        fail "CL-011: $(Split-Path $toml -Leaf) not found"
        continue
    }
    $content = Get-Content $toml -Raw
    if ($content -match "developer_instructions") {
        ok "CL-011: $(Split-Path $toml -Leaf) has developer_instructions"
    } else {
        fail "CL-011: $(Split-Path $toml -Leaf) missing developer_instructions"
    }
}

# ============================================================================
# CL-012: SKILL.md present with required frontmatter
# ============================================================================

Write-Host "=== CL-012: SKILL.md present with required frontmatter ==="

$skill = Join-Path $RepoRoot "plugins/sdd-quality-loop/skills/cross-model-verify/SKILL.md"
if (Test-Path $skill) {
    ok "CL-012a: SKILL.md present"
    $sc = Get-Content $skill -Raw
    if ($sc -match "name: cross-model-verify") { ok "CL-012b: SKILL.md has name frontmatter" }
    else { fail "CL-012b: SKILL.md missing name frontmatter" }
    if ($sc -match "disable-model-invocation: true") { ok "CL-012c: SKILL.md has disable-model-invocation: true" }
    else { fail "CL-012c: SKILL.md missing disable-model-invocation: true" }
    if ($sc -imatch "blind" -and $sc -imatch "parallel") { ok "CL-012d: SKILL.md mentions blind and parallel" }
    else { fail "CL-012d: SKILL.md should document blind/parallel isolation" }
} else {
    fail "CL-012a: SKILL.md not found at $skill"
}

# ============================================================================
# CL-013: panelist agent .md files have disallowedTools
# ============================================================================

Write-Host "=== CL-013: panelist agent .md files have disallowedTools ==="

foreach ($agent in @(
    (Join-Path $RepoRoot "plugins/sdd-quality-loop/agents/panelist-gpt.md"),
    (Join-Path $RepoRoot "plugins/sdd-quality-loop/agents/panelist-gemini.md")
)) {
    if (-not (Test-Path $agent)) {
        fail "CL-013: $(Split-Path $agent -Leaf) not found"
        continue
    }
    $ac = Get-Content $agent -Raw
    if ($ac -match "disallowedTools:.*Write" -or $ac -match "disallowedTools: Write") {
        ok "CL-013: $(Split-Path $agent -Leaf) has disallowedTools with Write"
    } else {
        fail "CL-013: $(Split-Path $agent -Leaf) missing disallowedTools: Write"
    }
}

} finally {
    Remove-Item -Recurse -Force $Work -ErrorAction SilentlyContinue
}

# ============================================================================
# Summary
# ============================================================================

Write-Host ""
Write-Host "Results: $Pass passed, $Fail failed"
if ($Fail -gt 0) { exit 1 }
exit 0
