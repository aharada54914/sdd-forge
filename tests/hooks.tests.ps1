$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Behavioral tests for the unified cross-runtime PreToolUse guard and kill switch.
# Covers sdd-hook-guard.ps1 directly and sdd-hook-guard.sh when bash+python3 exist.

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$scriptsDir = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts"
$hooksDir = Join-Path $repositoryRoot "plugins/sdd-quality-loop/hooks"
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-hook-tests-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $workDir | Out-Null

$failures = 0
function Assert {
    param([string]$Name, [bool]$Condition)
    if ($Condition) { Write-Host "ok: $Name" }
    else { Write-Host "FAIL: $Name"; $script:failures++ }
}

# Invoke the PowerShell guard with a stdin payload; returns @{Code; Out}.
function Invoke-GuardPs {
    param([string]$Payload, [string]$EmitMode = "exit")
    $outFile = Join-Path $workDir ("out-" + [guid]::NewGuid() + ".txt")
    $Payload | & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "sdd-hook-guard.ps1") -Emit $EmitMode > $outFile 2>$null
    $code = $LASTEXITCODE
    $out = if (Test-Path $outFile) { (Get-Content -Raw -ErrorAction SilentlyContinue $outFile) } else { "" }
    return @{ Code = $code; Out = $out }
}

# Invoke the kill-switch.ps1 hook in a given working directory.
function Invoke-KillSwitchPs {
    param([string]$Cwd)
    Push-Location $Cwd
    try {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "kill-switch.ps1") *> $null
        return $LASTEXITCODE
    } finally { Pop-Location }
}

Push-Location $workDir
try {
    New-Item -ItemType Directory -Path "specs/x" -Force | Out-Null

    # --- Claude Edit payload adding Approval: Approved -> deny ---
    $r = Invoke-GuardPs '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'
    Assert "ps: edit adds approval -> deny (exit 2)" ($r.Code -eq 2)

    # --- status-only change -> allow ---
    $r = Invoke-GuardPs '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Status: Planned","new_string":"Status: In Progress"}}'
    Assert "ps: status-only change -> allow (exit 0)" ($r.Code -eq 0)

    # --- Write content payload: N on disk, N content -> allow; N+1 -> deny ---
    $diskTasks = Join-Path $workDir "specs/x/tasks.md"
    @"
# Tasks
## T-001
Approval: Approved
## T-002
Approval: Draft
"@ | Set-Content -Encoding Utf8 $diskTasks
    # On disk has 1 approval. content with 1 approval -> allow.
    $payloadN = (@{ tool_name = "Write"; tool_input = @{ file_path = $diskTasks; content = "Approval: Approved`nApproval: Draft" } } | ConvertTo-Json -Compress -Depth 5)
    $r = Invoke-GuardPs $payloadN
    Assert "ps: write content same count -> allow" ($r.Code -eq 0)
    # content with 2 approvals -> deny.
    $payloadN1 = (@{ tool_name = "Write"; tool_input = @{ file_path = $diskTasks; content = "Approval: Approved`nApproval: Approved" } } | ConvertTo-Json -Compress -Depth 5)
    $r = Invoke-GuardPs $payloadN1
    Assert "ps: write content extra approval -> deny" ($r.Code -eq 2)

    # --- Codex apply_patch adding Approval: Approved to tasks.md -> deny ---
    $patchDeny = "{`"tool_name`":`"apply_patch`",`"tool_input`":{`"command`":`"*** Begin Patch\n*** Update File: specs/x/tasks.md\n-Approval: Draft\n+Approval: Approved\n*** End Patch`"}}"
    $r = Invoke-GuardPs $patchDeny
    Assert "ps: apply_patch adds approval to tasks.md -> deny" ($r.Code -eq 2)

    # --- apply_patch to another file -> allow ---
    $patchOther = "{`"tool_name`":`"apply_patch`",`"tool_input`":{`"command`":`"*** Begin Patch\n*** Update File: src/a.py\n-x\n+Approval: Approved\n*** End Patch`"}}"
    $r = Invoke-GuardPs $patchOther
    Assert "ps: apply_patch to other file -> allow" ($r.Code -eq 0)

    # --- Codex shell echo Approval >> tasks.md -> deny ---
    $shellDeny = "{`"tool_name`":`"shell`",`"tool_input`":{`"command`":`"echo 'Approval: Approved' >> specs/x/tasks.md`"}}"
    $r = Invoke-GuardPs $shellDeny
    Assert "ps: shell appends approval to tasks.md -> deny" ($r.Code -eq 2)

    # --- copilot emit: allow case -> valid JSON, exit 0 ---
    $r = Invoke-GuardPs '{"tool_name":"Edit","tool_input":{"file_path":"/p/src/a.py","old_string":"a","new_string":"b"}}' "copilot"
    $okJson = $false
    try { $okJson = ((($r.Out | ConvertFrom-Json).permissionDecision) -eq "allow") } catch { }
    Assert "ps: copilot allow -> JSON allow, exit 0" ($r.Code -eq 0 -and $okJson)

    # --- copilot emit: deny case -> valid JSON deny, exit 0 ---
    $r = Invoke-GuardPs '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}' "copilot"
    $okDeny = $false
    try { $okDeny = ((($r.Out | ConvertFrom-Json).permissionDecision) -eq "deny") } catch { }
    Assert "ps: copilot deny -> JSON deny, exit 0" ($r.Code -eq 0 -and $okDeny)

    # --- malformed payload -> allow ---
    $r = Invoke-GuardPs 'this is not json'
    Assert "ps: malformed payload -> allow (exit 0)" ($r.Code -eq 0)

    # --- kill-switch.ps1: AGENT_STOP present -> 2; absent -> 0 ---
    $ksDir = Join-Path $workDir "ks"
    New-Item -ItemType Directory -Path $ksDir -Force | Out-Null
    $env:CLAUDE_PROJECT_DIR = $null
    Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
    Assert "ps: kill-switch absent -> 0" ((Invoke-KillSwitchPs $ksDir) -eq 0)
    "stop" | Set-Content -Encoding Utf8 (Join-Path $ksDir "AGENT_STOP")
    Assert "ps: kill-switch present -> 2" ((Invoke-KillSwitchPs $ksDir) -eq 2)

    # --- POSIX dispatcher via bash+python3 when available ---
    $bash = Get-Command bash -ErrorAction SilentlyContinue
    $py = Get-Command python3 -ErrorAction SilentlyContinue
    if ($bash -and $py) {
        function Invoke-GuardSh {
            param([string]$Payload, [string]$EmitMode = "exit")
            $outFile = Join-Path $workDir ("sh-" + [guid]::NewGuid() + ".txt")
            $Payload | & bash (Join-Path $scriptsDir "sdd-hook-guard.sh") "--emit" $EmitMode > $outFile 2>$null
            $code = $LASTEXITCODE
            $out = if (Test-Path $outFile) { (Get-Content -Raw -ErrorAction SilentlyContinue $outFile) } else { "" }
            return @{ Code = $code; Out = $out }
        }
        $r = Invoke-GuardSh '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}'
        Assert "sh: edit adds approval -> deny (exit 2)" ($r.Code -eq 2)
        $r = Invoke-GuardSh '{"tool_name":"Edit","tool_input":{"file_path":"/p/src/a.py","old_string":"a","new_string":"b"}}'
        Assert "sh: other file -> allow" ($r.Code -eq 0)
        $r = Invoke-GuardSh '{"tool_name":"Edit","tool_input":{"file_path":"/p/specs/x/tasks.md","old_string":"Approval: Draft","new_string":"Approval: Approved"}}' "copilot"
        $okDeny = $false
        try { $okDeny = ((($r.Out | ConvertFrom-Json).permissionDecision) -eq "deny") } catch { }
        Assert "sh: copilot deny -> JSON deny, exit 0" ($r.Code -eq 0 -and $okDeny)
        $r = Invoke-GuardSh 'not json'
        Assert "sh: malformed -> allow" ($r.Code -eq 0)
    } else {
        Write-Host "bash+python3 not both found; skipping POSIX dispatcher tests."
    }

    # --- hooks.json parses; referenced scripts exist; each entry has command_windows ---
    $hooksJson = Get-Content -Raw -Encoding Utf8 (Join-Path $hooksDir "hooks.json") | ConvertFrom-Json
    Assert "hooks.json parses with PreToolUse" ($null -ne $hooksJson.hooks.PreToolUse)
    foreach ($entry in $hooksJson.hooks.PreToolUse) {
        foreach ($h in $entry.hooks) {
            Assert "hooks.json entry has command_windows" ($null -ne $h.command_windows -and $h.command_windows -ne "")
            # Extract the referenced script filename(s) and confirm existence.
            foreach ($scriptName in @("kill-switch.sh", "kill-switch.ps1", "sdd-hook-guard.sh", "sdd-hook-guard.ps1")) {
                if ($h.command -match [regex]::Escape($scriptName) -or $h.command_windows -match [regex]::Escape($scriptName)) {
                    Assert "hooks.json references existing script $scriptName" (Test-Path (Join-Path $scriptsDir $scriptName))
                }
            }
        }
    }

    # --- copilot-hooks.json parses; version 1; preToolUse entries have bash + powershell ---
    $copJson = Get-Content -Raw -Encoding Utf8 (Join-Path $hooksDir "copilot-hooks.json") | ConvertFrom-Json
    Assert "copilot-hooks.json version 1" ($copJson.version -eq 1)
    Assert "copilot-hooks.json has preToolUse" ($null -ne $copJson.hooks.preToolUse)
    foreach ($e in $copJson.hooks.preToolUse) {
        Assert "copilot-hooks.json entry has bash" ($null -ne $e.bash -and $e.bash -ne "")
        Assert "copilot-hooks.json entry has powershell" ($null -ne $e.powershell -and $e.powershell -ne "")
    }

    if ($failures -gt 0) { throw "$failures hook test(s) failed." }
    Write-Host "Hook guard tests passed."
} finally {
    Pop-Location
    Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $workDir -ErrorAction SilentlyContinue
}
