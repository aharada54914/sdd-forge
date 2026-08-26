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
    # cross-model-verify is a DELEGATED skill: it already carries
    # user-invocable: false, so carrying disable-model-invocation as well would
    # leave it reachable by nobody and quality-gate could never call it.
    if ($sc -match "disable-model-invocation") { fail "CL-012c: delegated SKILL.md must not carry disable-model-invocation (reachable by nobody)" }
    else { ok "CL-012c: delegated SKILL.md omits disable-model-invocation (the model may invoke it)" }
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

# Resolved BEFORE any per-test PATH override -- Windows stub .cmd wrappers
# below delegate to this absolute pwsh path (a bare "pwsh" name would be
# unresolvable once PATH is replaced with a stub-only set).
$PowerShellHost = (Get-Command pwsh -ErrorAction Stop).Source

function New-StubCli {
    # Creates a stub executable named $Name in $BinDir. $BodyLines is Unix
    # shell (#!/bin/sh) source used directly on macOS/Linux, and re-executed
    # via a pwsh worker script (parity with run-panelist-effort.tests.ps1's
    # established .cmd-wrapper pattern) on Windows -- same PATH-name
    # contract either way.
    param([string]$BinDir, [string]$Name, [string]$ShBody)
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    if ($IsLinux -or $IsMacOS) {
        $stubPath = Join-Path $BinDir $Name
        Set-Content -NoNewline -Path $stubPath -Value $ShBody
        & chmod +x $stubPath
    } else {
        $workerPs1 = Join-Path $BinDir "$Name-worker.ps1"
        # Translate the handful of sh idioms this suite's stub bodies use
        # into a pwsh equivalent; every stub below sticks to this small,
        # translatable vocabulary on purpose.
        Set-Content -Path $workerPs1 -Value $ShBody
        $stubCmd = Join-Path $BinDir "$Name.cmd"
        Set-Content -Path $stubCmd -Value "@echo off`r`n`"$PowerShellHost`" -NoProfile -File `"$workerPs1`" %*`r`n"
    }
}

function New-TranscriptStub {
    # Creates a stub CLI named $Name that ignores its input and prints
    # $Transcript to stdout verbatim, then exits 0 -- same
    # macOS/Linux-vs-Windows split as New-StubCli, since $Transcript can
    # contain arbitrary multi-line JSON/text that isn't safe to hand
    # through New-StubCli's -ShBody sh-idiom translator.
    param([string]$BinDir, [string]$Name, [string]$Transcript)
    $shBody = "#!/bin/sh`ncat << 'TRANSCRIPT_EOF'`n$Transcript`nTRANSCRIPT_EOF`nexit 0`n"
    New-StubCli -BinDir $BinDir -Name $Name -ShBody $shBody
    if (-not ($IsLinux -or $IsMacOS)) {
        $workerBody = "Write-Output @'`n$Transcript`n'@`nexit 0`n"
        Set-Content -Path (Join-Path $BinDir "$Name-worker.ps1") -Value $workerBody
    }
}

# ============================================================================
# CL-014: run-panelist-gpt — CLI exits 0 but emits no parseable verdict JSON
# -> exit non-zero, no verdict file written (invocation-fix hardening: the
# "silent success" regression class this suite must catch).
# ============================================================================

Write-Host "=== CL-014: run-panelist-gpt unparseable-output hardening ==="

$cl014Bin = Join-Path $Work "cl014-bin"
New-StubCli -BinDir $cl014Bin -Name "codex" -ShBody "#!/bin/sh`nprintf 'usage: codex [OPTIONS]\n'`nexit 0`n"
if (-not ($IsLinux -or $IsMacOS)) {
    Set-Content -Path (Join-Path $cl014Bin "codex-worker.ps1") -Value "Write-Output 'usage: codex [OPTIONS]'`nexit 0`n"
}

$cl014 = Join-Path $Work "cl014"
New-Item -ItemType Directory -Path "$cl014/specs" -Force | Out-Null
Set-Content -Path "$cl014/input.txt" -Value "plain bundle content, no JSON here."
$cl014Path = if ($IsLinux -or $IsMacOS) { "${cl014Bin}:/usr/bin:/bin" } else { "$cl014Bin;C:\Windows\System32" }

$runProc14 = Start-Process -FilePath "pwsh" `
    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$ScriptsDir/run-panelist-gpt.ps1",
        "--task", "T-014", "--feature", "feat",
        "--input", "$cl014/input.txt",
        "--spec-root", "$cl014/specs",
        "--digest", "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" `
    -Environment @{ PATH = $cl014Path } `
    -RedirectStandardOutput (Join-Path $Work "run014-stdout.txt") `
    -RedirectStandardError  (Join-Path $Work "run014-stderr.txt") `
    -Wait -PassThru -NoNewWindow
$runErr14 = Get-Content (Join-Path $Work "run014-stderr.txt") -Raw -ErrorAction SilentlyContinue

if ($runProc14.ExitCode -ne 0) {
    ok "CL-014a: codex CLI exits 0 with no parseable JSON -> run-panelist-gpt still exits non-zero (got $($runProc14.ExitCode))"
} else {
    fail "CL-014a: expected non-zero exit when codex produces no parseable verdict, got 0"
}
if ($runErr14 -imatch "no json object found") {
    ok "CL-014b: run-panelist-gpt names the parse failure in its diagnostic"
} else {
    fail "CL-014b: expected a parse-failure diagnostic, got: $runErr14"
}
if (-not (Test-Path "$cl014/specs/feat/verification/T-014.panelist-openai.verdict.json")) {
    ok "CL-014c: no verdict file is written when the CLI output does not parse"
} else {
    fail "CL-014c: a verdict file was written despite unparseable CLI output"
}

# ============================================================================
# CL-015: run-panelist-gemini — same unparseable-output hardening.
# ============================================================================

Write-Host "=== CL-015: run-panelist-gemini unparseable-output hardening ==="

$cl015Bin = Join-Path $Work "cl015-bin"
New-StubCli -BinDir $cl015Bin -Name "gemini" -ShBody "#!/bin/sh`nprintf 'No input provided via stdin.\n'`nexit 0`n"
if (-not ($IsLinux -or $IsMacOS)) {
    Set-Content -Path (Join-Path $cl015Bin "gemini-worker.ps1") -Value "Write-Output 'No input provided via stdin.'`nexit 0`n"
}

$cl015 = Join-Path $Work "cl015"
New-Item -ItemType Directory -Path "$cl015/specs" -Force | Out-Null
Set-Content -Path "$cl015/input.txt" -Value "plain bundle content, no JSON here."
$cl015Path = if ($IsLinux -or $IsMacOS) { "${cl015Bin}:/usr/bin:/bin" } else { "$cl015Bin;C:\Windows\System32" }

$runProc15 = Start-Process -FilePath "pwsh" `
    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$ScriptsDir/run-panelist-gemini.ps1",
        "--task", "T-015", "--feature", "feat",
        "--input", "$cl015/input.txt",
        "--spec-root", "$cl015/specs",
        "--digest", "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" `
    -Environment @{ PATH = $cl015Path } `
    -Wait -PassThru -NoNewWindow

if ($runProc15.ExitCode -ne 0) {
    ok "CL-015a: gemini CLI exits 0 with no parseable JSON -> run-panelist-gemini still exits non-zero (got $($runProc15.ExitCode))"
} else {
    fail "CL-015a: expected non-zero exit when gemini produces no parseable verdict, got 0"
}
if (-not (Test-Path "$cl015/specs/feat/verification/T-015.panelist-google.verdict.json")) {
    ok "CL-015b: no verdict file is written when the CLI output does not parse"
} else {
    fail "CL-015b: a verdict file was written despite unparseable CLI output"
}

# ============================================================================
# CL-016: run-panelist-gemini -- argv/stdin contract: panelist instructions
# go through -p, the sanitized bundle goes on stdin (no duplication).
# ============================================================================

Write-Host "=== CL-016: run-panelist-gemini -p/stdin contract ==="

$cl016Bin = Join-Path $Work "cl016-bin"
$cl016Argv = Join-Path $Work "cl016-argv.txt"
$cl016Stdin = Join-Path $Work "cl016-stdin.txt"
$stubJson16 = '{"schema":"cross-model-verdict/v1","task_id":"T-016","feature":"feat","vendor":"google","model":"stub","verdict":"PASS","findings":[],"blind":true,"input_digest":"' + ("0" * 64) + '","consent":{"kind":"human-flag","ref":"stub"}}'
$shBody16 = "#!/bin/sh`nprintf '%s\n' `"`$@`" > `"$cl016Argv`"`ncat > `"$cl016Stdin`"`nprintf '%s\n' '$stubJson16'`nexit 0`n"
New-StubCli -BinDir $cl016Bin -Name "gemini" -ShBody $shBody16
if (-not ($IsLinux -or $IsMacOS)) {
    $workerBody16 = "`$argvFile = '$cl016Argv'`n`$stdinFile = '$cl016Stdin'`nforeach (`$a in `$args) { Add-Content -LiteralPath `$argvFile -Value `$a }`n[Console]::In.ReadToEnd() | Set-Content -NoNewline -Path `$stdinFile`nWrite-Output '$stubJson16'`nexit 0`n"
    Set-Content -Path (Join-Path $cl016Bin "gemini-worker.ps1") -Value $workerBody16
}

$cl016 = Join-Path $Work "cl016"
New-Item -ItemType Directory -Path "$cl016/specs" -Force | Out-Null
Set-Content -Path "$cl016/input.txt" -Value "sanitized bundle body, no panelist instructions here."
$cl016Path = if ($IsLinux -or $IsMacOS) { "${cl016Bin}:/usr/bin:/bin" } else { "$cl016Bin;C:\Windows\System32" }

Start-Process -FilePath "pwsh" `
    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$ScriptsDir/run-panelist-gemini.ps1",
        "--task", "T-016", "--feature", "feat",
        "--input", "$cl016/input.txt",
        "--spec-root", "$cl016/specs",
        "--digest", ("0" * 64),
        "--model", "gemini-2.0-flash" `
    -Environment @{ PATH = $cl016Path } `
    -Wait -PassThru -NoNewWindow | Out-Null

$argvFlat16 = if (Test-Path $cl016Argv) { ((Get-Content $cl016Argv) -join " ").TrimEnd() } else { "" }
if (($argvFlat16 -like "--model gemini-2.0-flash -p *") -and ($argvFlat16 -match "READ-ONLY")) {
    ok "CL-016a: gemini argv is --model <m> -p <panelist-instructions> (instructions travel via -p, not stdin)"
} else {
    fail "CL-016a: gemini argv did not match the -p contract -- $argvFlat16"
}

$stdinContent16 = [string]$(if (Test-Path $cl016Stdin) { Get-Content -Raw $cl016Stdin } else { "" })
if (($stdinContent16 -match "sanitized bundle body") -and ($stdinContent16 -notmatch "READ-ONLY")) {
    ok "CL-016b: stdin carries only the sanitized bundle (no duplicated panelist instructions)"
} else {
    fail "CL-016b: stdin content did not match the bundle-only contract -- $stdinContent16"
}

# ============================================================================
# CL-017: detect-panel -- CLI resolves but --version fails (e.g. broken
# auth) -> not reported available (liveness probe, not just presence).
# ============================================================================

Write-Host "=== CL-017: detect-panel liveness probe (--version must succeed) ==="

$cl017Bin = Join-Path $Work "cl017-bin"
$shBody17 = (@('#!/bin/sh', 'if [ "$1" = "--version" ]; then', '    exit 1', 'fi', 'exit 0', '') -join "`n")
New-StubCli -BinDir $cl017Bin -Name "gemini" -ShBody $shBody17
if (-not ($IsLinux -or $IsMacOS)) {
    Set-Content -Path (Join-Path $cl017Bin "gemini-worker.ps1") -Value "if (`$args.Count -gt 0 -and `$args[0] -eq '--version') { exit 1 }`nexit 0`n"
}
$cl017Path = if ($IsLinux -or $IsMacOS) { "${cl017Bin}:/usr/bin:/bin" } else { "$cl017Bin;C:\Windows\System32" }

$dpProc17 = Start-Process -FilePath "pwsh" `
    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$ScriptsDir/detect-panel.ps1", "-Quiet" `
    -Environment @{ PATH = $cl017Path } `
    -RedirectStandardOutput (Join-Path $Work "dp017-stdout.txt") `
    -Wait -PassThru -NoNewWindow
# [string](...) coercion matters here: Get-Content -Raw on a zero-byte
# file (the expected "nothing reported" case) yields a value that compares
# -eq $null but is NOT a plain scalar $null -- -notmatch/-match treat it
# as an empty collection (filter semantics, empty-array result) rather
# than running the boolean scalar match, so an un-coerced comparison is
# vacuously true/false regardless of content. Coercing to [string] forces
# scalar boolean match semantics.
$dpOut17 = [string](Get-Content (Join-Path $Work "dp017-stdout.txt") -Raw -ErrorAction SilentlyContinue)

if ($dpOut17 -notmatch "(?m)^gemini$") {
    ok "CL-017: a gemini CLI present in PATH but failing --version is NOT reported available"
} else {
    fail "CL-017: detect-panel reported 'gemini' available despite --version failing -- $dpOut17"
}

# ============================================================================
# CL-018: detect-panel -- a codex resolving to codex-sync is never reported
# available, even though it answers exit 0/--version.
# ============================================================================

Write-Host "=== CL-018: detect-panel codex-sync avoidance ==="

if ($IsLinux -or $IsMacOS) {
    $cl018Bin = Join-Path $Work "cl018-bin"
    New-Item -ItemType Directory -Path $cl018Bin -Force | Out-Null
    $codexSyncPath = Join-Path $cl018Bin "codex-sync"
    Set-Content -NoNewline -Path $codexSyncPath -Value "#!/bin/sh`nexit 0`n"
    & chmod +x $codexSyncPath
    & ln -s $codexSyncPath (Join-Path $cl018Bin "codex")
    $cl018Path = "${cl018Bin}:/usr/bin:/bin"

    $dpProc18 = Start-Process -FilePath "pwsh" `
        -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$ScriptsDir/detect-panel.ps1", "-Quiet" `
        -Environment @{ PATH = $cl018Path } `
        -RedirectStandardOutput (Join-Path $Work "dp018-stdout.txt") `
        -Wait -PassThru -NoNewWindow
    $dpOut18 = [string](Get-Content (Join-Path $Work "dp018-stdout.txt") -Raw -ErrorAction SilentlyContinue)

    if ($dpOut18 -notmatch "(?m)^gpt$") {
        ok "CL-018: a codex resolving to codex-sync is NOT reported as an available 'gpt' panelist"
    } else {
        fail "CL-018: detect-panel reported 'gpt' available via a codex-sync-resolved codex -- $dpOut18"
    }
} else {
    # Windows: codex-sync avoidance is exercised via $env:SDD_PANELIST_CODEX_CMD
    # resolution in the runner scripts themselves (Resolve-CodexCommand);
    # a filesystem-symlink repro is POSIX-specific, mirrored here as a
    # visible skip rather than a false pass on an unexercised path.
    ok "CL-018: skipped on Windows (symlink-based repro is POSIX-specific; detect-panel.ps1's codex-sync string match is exercised on macOS/Linux above)"
}

# ============================================================================
# CL-019: run-panelist-gpt -- `codex exec` echoes the whole prompt (including
# the JSON schema *example*, which is deliberately not valid JSON) before
# the real verdict. This is the actual bug reproduced verbatim: a greedy
# '\{[\s\S]*\}' regex spans from the example's '{' to the real verdict's
# final '}', which fails to parse. Assert on the EXTRACTED CONTENT, not
# merely exit 0, so a revert to "first object wins" cannot pass silently.
# ============================================================================

Write-Host "=== CL-019: run-panelist-gpt extracts the real verdict, not an echoed distractor ==="

$transcript19 = @'
OpenAI Codex v0.147.0
--------
workdir: /tmp/scratch
model: gpt-5.6-sol
--------
user
## Output Format

Return ONLY a JSON object in this exact schema (no markdown, no prose):

{
  "schema": "cross-model-verdict/v1",
  "task_id": "<task_id>",
  "feature": "<feature>",
  "vendor": "openai",
  "model": "<model>",
  "verdict": "PASS" | "NEEDS_WORK",
  "findings": [
    { "severity": "Critical" | "Major" | "Minor", "ref": "<file:line or section>", "note": "<description>" }
  ],
  "blind": true,
  "input_digest": "<digest-from-bundle-header>",
  "consent": { "kind": "<consent-kind>", "ref": "<ref>" }
}

some other distractor object elsewhere in the echoed bundle: {"unrelated": true, "count": 2}

codex
{"schema":"cross-model-verdict/v1","task_id":"T-019","feature":"feat","vendor":"openai","model":"stub-model","verdict":"NEEDS_WORK","findings":[{"severity":"Major","ref":"x","note":"y"}],"blind":true,"input_digest":"a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2","consent":{"kind":"human-flag","ref":"stub"}}
hook: Stop
tokens used
193326
{"schema":"cross-model-verdict/v1","task_id":"T-019","feature":"feat","vendor":"openai","model":"stub-model","verdict":"NEEDS_WORK","findings":[{"severity":"Major","ref":"x","note":"y"}],"blind":true,"input_digest":"a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2","consent":{"kind":"human-flag","ref":"stub"}}
'@

$cl019Bin = Join-Path $Work "cl019-bin"
New-TranscriptStub -BinDir $cl019Bin -Name "codex" -Transcript $transcript19

$cl019 = Join-Path $Work "cl019"
New-Item -ItemType Directory -Path "$cl019/specs" -Force | Out-Null
Set-Content -Path "$cl019/input.txt" -Value "bundle content"
$cl019Path = if ($IsLinux -or $IsMacOS) { "${cl019Bin}:/usr/bin:/bin" } else { "$cl019Bin;C:\Windows\System32" }

$runProc19 = Start-Process -FilePath "pwsh" `
    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$ScriptsDir/run-panelist-gpt.ps1",
        "--task", "T-019", "--feature", "feat",
        "--input", "$cl019/input.txt",
        "--spec-root", "$cl019/specs",
        "--digest", "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" `
    -Environment @{ PATH = $cl019Path } `
    -RedirectStandardOutput (Join-Path $Work "run019-stdout.txt") `
    -RedirectStandardError  (Join-Path $Work "run019-stderr.txt") `
    -Wait -PassThru -NoNewWindow
$cl019Out = "$cl019/specs/feat/verification/T-019.panelist-openai.verdict.json"

if ($runProc19.ExitCode -eq 0 -and (Test-Path $cl019Out)) {
    ok "CL-019a: run-panelist-gpt exits 0 and writes a verdict file despite echoed distractor objects"
} else {
    fail "CL-019a: expected exit 0 and a written verdict file, got exit $($runProc19.ExitCode)"
}
$cl019Content = [string]$(if (Test-Path $cl019Out) { Get-Content -Raw $cl019Out } else { "" })
if (($cl019Content -match '"verdict"\s*:\s*"NEEDS_WORK"') -and ($cl019Content -match '"note"\s*:\s*"y"')) {
    ok "CL-019b: the extracted verdict is the REAL one (NEEDS_WORK/note=y), not the mangled schema example or the unrelated distractor"
} else {
    fail "CL-019b: extracted verdict did not match the real payload -- $cl019Content"
}

# ============================================================================
# CL-020: run-panelist-gpt -- a verdict wrapped in a ```json Markdown code
# fence is still extracted (models fence their replies constantly,
# regardless of what the prompt asks for).
# ============================================================================

Write-Host "=== CL-020: run-panelist-gpt extracts a fenced verdict ==="

$transcript20 = @'
codex
```json
{"schema":"cross-model-verdict/v1","task_id":"T-020","feature":"feat","vendor":"openai","model":"stub-model","verdict":"PASS","findings":[],"blind":true,"input_digest":"a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2","consent":{"kind":"human-flag","ref":"stub"}}
```
'@

$cl020Bin = Join-Path $Work "cl020-bin"
New-TranscriptStub -BinDir $cl020Bin -Name "codex" -Transcript $transcript20

$cl020 = Join-Path $Work "cl020"
New-Item -ItemType Directory -Path "$cl020/specs" -Force | Out-Null
Set-Content -Path "$cl020/input.txt" -Value "bundle content"
$cl020Path = if ($IsLinux -or $IsMacOS) { "${cl020Bin}:/usr/bin:/bin" } else { "$cl020Bin;C:\Windows\System32" }

$runProc20 = Start-Process -FilePath "pwsh" `
    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$ScriptsDir/run-panelist-gpt.ps1",
        "--task", "T-020", "--feature", "feat",
        "--input", "$cl020/input.txt",
        "--spec-root", "$cl020/specs",
        "--digest", "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" `
    -Environment @{ PATH = $cl020Path } `
    -Wait -PassThru -NoNewWindow
$cl020Out = "$cl020/specs/feat/verification/T-020.panelist-openai.verdict.json"
$cl020Content = [string]$(if (Test-Path $cl020Out) { Get-Content -Raw $cl020Out } else { "" })

if ($runProc20.ExitCode -eq 0 -and ($cl020Content -match '"verdict"\s*:\s*"PASS"')) {
    ok "CL-020: a ``````json-fenced verdict is extracted"
} else {
    fail "CL-020: expected the fenced verdict to be extracted, got exit $($runProc20.ExitCode) -- $cl020Content"
}

# ============================================================================
# CL-021: run-panelist-gpt -- output contains parseable JSON objects, but
# none carries "schema": "cross-model-verdict/v1" -> exit non-zero, no
# verdict file written (a stray object must never be mistaken for a
# verdict).
# ============================================================================

Write-Host "=== CL-021: run-panelist-gpt rejects output with no schema-matching object ==="

$transcript21 = @'
codex
preamble text with {"schema": "cross-model-verdict/v0", "task_id": "T-021"} and also {"other": "thing", "count": 1}
'@

$cl021Bin = Join-Path $Work "cl021-bin"
New-TranscriptStub -BinDir $cl021Bin -Name "codex" -Transcript $transcript21

$cl021 = Join-Path $Work "cl021"
New-Item -ItemType Directory -Path "$cl021/specs" -Force | Out-Null
Set-Content -Path "$cl021/input.txt" -Value "bundle content"
$cl021Path = if ($IsLinux -or $IsMacOS) { "${cl021Bin}:/usr/bin:/bin" } else { "$cl021Bin;C:\Windows\System32" }

$runProc21 = Start-Process -FilePath "pwsh" `
    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$ScriptsDir/run-panelist-gpt.ps1",
        "--task", "T-021", "--feature", "feat",
        "--input", "$cl021/input.txt",
        "--spec-root", "$cl021/specs",
        "--digest", "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" `
    -Environment @{ PATH = $cl021Path } `
    -RedirectStandardError (Join-Path $Work "run021-stderr.txt") `
    -Wait -PassThru -NoNewWindow
$runErr21 = [string](Get-Content (Join-Path $Work "run021-stderr.txt") -Raw -ErrorAction SilentlyContinue)

if ($runProc21.ExitCode -ne 0) {
    ok "CL-021a: no schema-matching candidate -> non-zero exit (got $($runProc21.ExitCode))"
} else {
    fail "CL-021a: expected non-zero exit when no candidate carries the verdict schema, got 0"
}
if ($runErr21 -imatch "candidate") {
    ok "CL-021b: diagnostic reports candidate objects were considered and rejected"
} else {
    fail "CL-021b: expected a candidate-aware diagnostic, got: $runErr21"
}
if (-not (Test-Path "$cl021/specs/feat/verification/T-021.panelist-openai.verdict.json")) {
    ok "CL-021c: no verdict file is written when no candidate matches the schema"
} else {
    fail "CL-021c: a verdict file was written despite no schema-matching candidate"
}

# ============================================================================
# CL-022: run-panelist-gpt -- a '}' inside a JSON string value (a finding's
# note) must not truncate the object early. Proven by round-tripping the
# full note text through to the written verdict file.
# ============================================================================

Write-Host "=== CL-022: run-panelist-gpt does not truncate on a '}' inside a string literal ==="

$transcript22 = @'
codex
{"schema":"cross-model-verdict/v1","task_id":"T-022","feature":"feat","vendor":"openai","model":"stub-model","verdict":"PASS","findings":[{"severity":"Minor","ref":"x","note":"contains a closing brace } inside a string, must not truncate here"}],"blind":true,"input_digest":"a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2","consent":{"kind":"human-flag","ref":"stub"}}
'@

$cl022Bin = Join-Path $Work "cl022-bin"
New-TranscriptStub -BinDir $cl022Bin -Name "codex" -Transcript $transcript22

$cl022 = Join-Path $Work "cl022"
New-Item -ItemType Directory -Path "$cl022/specs" -Force | Out-Null
Set-Content -Path "$cl022/input.txt" -Value "bundle content"
$cl022Path = if ($IsLinux -or $IsMacOS) { "${cl022Bin}:/usr/bin:/bin" } else { "$cl022Bin;C:\Windows\System32" }

$runProc22 = Start-Process -FilePath "pwsh" `
    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$ScriptsDir/run-panelist-gpt.ps1",
        "--task", "T-022", "--feature", "feat",
        "--input", "$cl022/input.txt",
        "--spec-root", "$cl022/specs",
        "--digest", "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" `
    -Environment @{ PATH = $cl022Path } `
    -Wait -PassThru -NoNewWindow
$cl022Out = "$cl022/specs/feat/verification/T-022.panelist-openai.verdict.json"
$cl022Content = [string]$(if (Test-Path $cl022Out) { Get-Content -Raw $cl022Out } else { "" })

if (($runProc22.ExitCode -eq 0) -and ($cl022Content -match "must not truncate here") -and ($cl022Content -match '"input_digest"')) {
    ok "CL-022: a '}' inside a string value does not truncate the object -- full note and trailing fields survived"
} else {
    fail "CL-022: expected the full note (through the trailing fields) to survive extraction, got exit $($runProc22.ExitCode) -- $cl022Content"
}

# ============================================================================
# CL-023: run-panelist-gpt -- malformed JSON (a single, unparseable
# candidate) still exits non-zero, and the diagnostic names the candidate
# and its parse error rather than pointing at an unidentifiable span.
# ============================================================================

Write-Host "=== CL-023: run-panelist-gpt reports a useful diagnostic for malformed JSON ==="

$transcript23 = @'
codex
{"schema": "cross-model-verdict/v1", "verdict": }
'@

$cl023Bin = Join-Path $Work "cl023-bin"
New-TranscriptStub -BinDir $cl023Bin -Name "codex" -Transcript $transcript23

$cl023 = Join-Path $Work "cl023"
New-Item -ItemType Directory -Path "$cl023/specs" -Force | Out-Null
Set-Content -Path "$cl023/input.txt" -Value "bundle content"
$cl023Path = if ($IsLinux -or $IsMacOS) { "${cl023Bin}:/usr/bin:/bin" } else { "$cl023Bin;C:\Windows\System32" }

$runProc23 = Start-Process -FilePath "pwsh" `
    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$ScriptsDir/run-panelist-gpt.ps1",
        "--task", "T-023", "--feature", "feat",
        "--input", "$cl023/input.txt",
        "--spec-root", "$cl023/specs",
        "--digest", "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" `
    -Environment @{ PATH = $cl023Path } `
    -RedirectStandardError (Join-Path $Work "run023-stderr.txt") `
    -Wait -PassThru -NoNewWindow
$runErr23 = [string](Get-Content (Join-Path $Work "run023-stderr.txt") -Raw -ErrorAction SilentlyContinue)

if ($runProc23.ExitCode -ne 0) {
    ok "CL-023a: malformed JSON -> non-zero exit (got $($runProc23.ExitCode))"
} else {
    fail "CL-023a: expected non-zero exit for malformed JSON, got 0"
}
if (($runErr23 -imatch "candidate 1") -and ($runErr23 -imatch "parse error")) {
    ok "CL-023b: diagnostic names candidate 1 and its parse error (not just an unidentifiable span)"
} else {
    fail "CL-023b: expected a candidate-numbered parse-error diagnostic, got: $runErr23"
}
if (-not (Test-Path "$cl023/specs/feat/verification/T-023.panelist-openai.verdict.json")) {
    ok "CL-023c: no verdict file is written for malformed JSON"
} else {
    fail "CL-023c: a verdict file was written despite malformed JSON"
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
