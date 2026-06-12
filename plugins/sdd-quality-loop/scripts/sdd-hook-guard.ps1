<#
Unified cross-runtime PreToolUse guard for the SDD quality loop (PowerShell 5.1+).
Functionally identical to sdd-hook-guard.py. Used on Windows machines without
python3.

Checks:
  1. Kill switch: deny every tool call while AGENT_STOP exists at
     $env:CLAUDE_PROJECT_DIR (fallback: cwd).
  2. Approval guard: deny a tool call that would increase the number of
     "Approval: Approved" occurrences in any path ending with tasks.md.
     Bypassed while a human-enabled SDD_SUDO flag file with an unexpired
     'expires-epoch: <unix-seconds>' line exists at the project root (sudo mode).
     Checks 1 and 3 are never bypassed.
  3. Agent-role guard: deny any tool call that would write a Codex agent role
     file (path matching .codex/agents/[^/]+.toml) without a developer_instructions
     field. Such files are ignored by Codex at startup.

Payloads: Claude/Copilot Edit/Write, Codex apply_patch, Codex Bash/shell.
Output: -Emit exit (default; allow=0, deny=stderr+exit 2) or
        -Emit copilot (always print {"permissionDecision":...} to stdout, exit 0).
Malformed payloads are denied; the guard never throws.
#>
param(
    [string]$Emit = "exit"
)

$ErrorActionPreference = "Stop"

$ApprovalMsg = "SDD deterministic gate: agents must not set 'Approval: Approved' in tasks.md. " +
    "Only a human may approve a task by editing the file directly. " +
    "Leave the task as Draft and ask the human to approve it."
$KillMsg = "SDD kill switch: AGENT_STOP exists at the project root. All tool use is suspended until a human deletes the file."
$AgentRoleMsg = "SDD deterministic gate: refusing to write a Codex agent role file without " +
    "developer_instructions. Files under .codex/agents/ must define " +
    "developer_instructions or Codex ignores them at startup " +
    "('Ignoring malformed agent role definition'). Use the shipped " +
    "sdd-investigator/sdd-evaluator roles instead of creating new ones."

if ($Emit -ne "copilot") { $Emit = "exit" }

function Get-Count {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    return ([regex]::Matches($Text, "Approval:\s*Approved")).Count
}

function Test-TasksMd {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return $false }
    # -match is case-insensitive in PowerShell (intentional: matches JS/py behavior; Windows FS is case-insensitive).
    return ($Path -replace "\\", "/") -match "tasks\.md$"
}

function Test-AgentRolePath {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return $false }
    # Case-insensitive match for .codex/agents/*.toml
    return ($Path -replace "\\", "/").ToLower() -match "\.codex/agents/[^/]+\.toml$"
}

function Test-ShellWritesAgentRole {
    param([string]$Cmd)
    if ([string]::IsNullOrEmpty($Cmd)) { return $false }
    $normalizedCmd = $Cmd -replace "\\", "/"
    if (-not ($normalizedCmd.ToLower() -match "\.codex/agents(?:/|\b)")) { return $false }
    $readOnlyRe = "(?is)^\s*(?:cat|ls|stat|head|tail|grep|rg)\b[^;&|><]*\.codex/agents(?:/|\b)"
    return -not [regex]::IsMatch($normalizedCmd, $readOnlyRe)
}

function Test-PayloadMalformed {
    param($Payload)
    $toolName = ""
    if ($Payload.PSObject.Properties["tool_name"]) { $toolName = ([string]$Payload.tool_name).ToLower() }
    $toolInput = $Payload.tool_input
    if ($null -eq $toolInput) { return $true }
    $targetedCommandTools = @("apply_patch", "bash", "shell", "exec_command", "exec")
    $targetedFileTools = @("edit", "write", "multiedit")
    if ($targetedCommandTools -contains $toolName) {
        if (-not $toolInput.PSObject.Properties["command"] -or -not ($toolInput.command -is [string]) -or [string]::IsNullOrWhiteSpace([string]$toolInput.command)) { return $true }
    }
    if ($targetedFileTools -contains $toolName) {
        if (-not $toolInput.PSObject.Properties["file_path"] -or -not ($toolInput.file_path -is [string]) -or [string]::IsNullOrWhiteSpace([string]$toolInput.file_path)) { return $true }
        if (-not $toolInput.PSObject.Properties["edits"] -and -not $toolInput.PSObject.Properties["new_string"] -and -not $toolInput.PSObject.Properties["content"]) { return $true }
    }
    return $false
}

function Test-HasDeveloperInstructions {
    param([string]$Content)
    if ([string]::IsNullOrEmpty($Content)) { return $false }
    return [regex]::IsMatch($Content, "(^|\n)[ \t]*developer_instructions[ \t]*=")
}

function Emit-Decision {
    param([string]$Decision, [string]$Reason)
    if ($Emit -eq "copilot") {
        if ($Decision -eq "deny" -and $Reason) {
            $obj = [ordered]@{ permissionDecision = $Decision; permissionDecisionReason = $Reason }
        } else {
            $obj = [ordered]@{ permissionDecision = $Decision }
        }
        [Console]::Out.Write(($obj | ConvertTo-Json -Compress))
        exit 0
    }
    if ($Decision -eq "deny") {
        if ($Reason) { [Console]::Error.WriteLine($Reason) }
        exit 2
    }
    exit 0
}

function Test-KillSwitch {
    $root = $env:CLAUDE_PROJECT_DIR
    if ([string]::IsNullOrEmpty($root)) { $root = "." }
    foreach ($base in @($root, ".")) {
        try {
            if (Test-Path -LiteralPath (Join-Path $base "AGENT_STOP") -PathType Leaf) { return $true }
        } catch { }
    }
    return $false
}

function Test-SudoActive {
    $root = $env:CLAUDE_PROJECT_DIR
    if ([string]::IsNullOrEmpty($root)) { $root = "." }
    foreach ($base in @($root, ".")) {
        try {
            $flag = Join-Path $base "SDD_SUDO"
            if (-not (Test-Path -LiteralPath $flag -PathType Leaf)) { continue }
            $m = [regex]::Match((Get-Content -Raw -Encoding Utf8 -LiteralPath $flag), "(^|\n)[ \t]*expires-epoch:[ \t]*(\d+)")
            if ($m.Success) {
                $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                if ([int64]$m.Groups[2].Value -gt $now) { return $true }
            }
        } catch { }
    }
    return $false
}

function Test-PatchIncreases {
    param([string]$Patch)
    $currentIsTasks = $false
    $added = 0
    $removed = 0
    foreach ($line in ($Patch -split "`n")) {
        $line = $line -replace "`r$", ""
        $m = [regex]::Match($line, "^\*\*\* (Update|Add|Delete) File: (.+)$")
        if ($m.Success) {
            $currentIsTasks = Test-TasksMd ($m.Groups[2].Value.Trim())
            continue
        }
        if ($line.StartsWith("*** End Patch") -or $line.StartsWith("*** Begin Patch")) { continue }
        if (-not $currentIsTasks) { continue }
        if ($line.StartsWith("+") -and -not $line.StartsWith("+++")) {
            $added += Get-Count $line.Substring(1)
        } elseif ($line.StartsWith("-") -and -not $line.StartsWith("---")) {
            $removed += Get-Count $line.Substring(1)
        }
    }
    return (($added - $removed) -gt 0)
}

function Test-PatchWritesInvalidAgentRole {
    param([string]$Patch)
    $currentIsAgentRole = $false
    $currentOp = $null
    $bodyLines = @()
    foreach ($line in ($Patch -split "`n")) {
        $line = $line -replace "`r$", ""
        $m = [regex]::Match($line, "^\*\*\* (Update|Add|Delete) File: (.+)$")
        if ($m.Success) {
            # Flush previous Add File section if it targeted an agent role.
            if ($currentOp -eq "Add" -and $currentIsAgentRole -and -not (Test-HasDeveloperInstructions ($bodyLines -join "`n"))) {
                return $true
            }
            $bodyLines = @()
            $currentOp = $m.Groups[1].Value
            $filePath = $m.Groups[2].Value.Trim()
            $currentIsAgentRole = Test-AgentRolePath $filePath
            if ($currentIsAgentRole -and ($currentOp -eq "Update" -or $currentOp -eq "Delete")) {
                return $true
            }
            continue
        }
        if ($line.StartsWith("*** End Patch") -or $line.StartsWith("*** Begin Patch")) { continue }
        if ($currentOp -eq "Add" -and $currentIsAgentRole -and $line.StartsWith("+") -and -not $line.StartsWith("+++")) {
            $bodyLines += $line.Substring(1)
        }
    }
    # Flush final section.
    if ($currentOp -eq "Add" -and $currentIsAgentRole -and -not (Test-HasDeveloperInstructions ($bodyLines -join "`n"))) {
        return $true
    }
    return $false
}

function Test-ShellWritesInvalidAgentRole {
    param([string]$Cmd)
    return Test-ShellWritesAgentRole $Cmd
}

function Test-AgentRoleInvalid {
    param($Payload)
    $toolInput = $Payload.tool_input
    if ($null -eq $toolInput) { return $false }
    $toolName = ""
    if ($Payload.PSObject.Properties["tool_name"]) { $toolName = ([string]$Payload.tool_name).ToLower() }

    $command = $null
    if ($toolInput.PSObject.Properties["command"]) { $command = [string]$toolInput.command }

    # Codex apply_patch: check Add File sections for agent role paths.
    if ($toolName -eq "apply_patch" -or ($command -and $command.Contains("*** Begin Patch"))) {
        return Test-PatchWritesInvalidAgentRole $command
    }

    # Write-style tools: full-file writes with file_path.
    $filePath = [string]$toolInput.file_path
    if ((Test-AgentRolePath $filePath) -and $toolInput.PSObject.Properties["content"]) {
        $content = [string]$toolInput.content
        if (-not (Test-HasDeveloperInstructions $content)) { return $true }
    }

    return $false
}

function Test-ApprovalIncreases {
    param($Payload)
    $toolInput = $Payload.tool_input
    if ($null -eq $toolInput) { return $false }
    $toolName = ""
    if ($Payload.PSObject.Properties["tool_name"]) { $toolName = ([string]$Payload.tool_name).ToLower() }

    $command = $null
    if ($toolInput.PSObject.Properties["command"]) { $command = [string]$toolInput.command }

    # Codex apply_patch: raw patch envelope in tool_input.command.
    if ($toolName -eq "apply_patch" -or ($command -and $command.Contains("*** Begin Patch"))) {
        return Test-PatchIncreases $command
    }

    # Codex Bash/shell: conservative heuristic.
    if (@("bash", "shell", "exec_command", "exec") -contains $toolName -and $command) {
        # Case-insensitive tasks.md check (intentional: matches JS/py behavior).
        if ($command.ToLower().Contains("tasks.md") -and [regex]::IsMatch($command, "Approval:\s*Approved")) {
            return $true
        }
        return $false
    }

    # Claude / Copilot Edit / Write.
    $filePath = [string]$toolInput.file_path
    if (-not (Test-TasksMd $filePath)) { return $false }

    $old = 0
    $new = 0
    if ($toolInput.PSObject.Properties["edits"] -and $null -ne $toolInput.edits) {
        foreach ($edit in $toolInput.edits) {
            $old += Get-Count ([string]$edit.old_string)
            $new += Get-Count ([string]$edit.new_string)
        }
    } elseif ($toolInput.PSObject.Properties["new_string"]) {
        $old = Get-Count ([string]$toolInput.old_string)
        $new = Get-Count ([string]$toolInput.new_string)
    } elseif ($toolInput.PSObject.Properties["content"]) {
        if (Test-Path -LiteralPath $filePath) {
            $old = Get-Count (Get-Content -Raw -Encoding Utf8 -LiteralPath $filePath)
        }
        $new = Get-Count ([string]$toolInput.content)
    } else {
        return $false
    }
    return ($new -gt $old)
}

# --- Check 1: kill switch (runs regardless of payload validity) ---
if (Test-KillSwitch) { Emit-Decision "deny" $KillMsg }

# --- Read payload ---
$raw = $env:PAYLOAD
if ($null -eq $raw) {
    try { $raw = [Console]::In.ReadToEnd() } catch { $raw = "" }
}

if ([string]::IsNullOrWhiteSpace($raw)) { Emit-Decision "deny" "SDD deterministic gate: malformed hook payload." }

try {
    $payload = $raw | ConvertFrom-Json
} catch {
    Emit-Decision "deny" "SDD deterministic gate: malformed hook payload."
}

try {
    if ($null -eq $payload -or -not $payload.PSObject.Properties["tool_name"] -or -not ($payload.tool_name -is [string]) -or -not $payload.PSObject.Properties["tool_input"] -or $null -eq $payload.tool_input -or ($payload.tool_input -isnot [psobject] -and $payload.tool_input -isnot [System.Collections.IDictionary])) {
        Emit-Decision "deny" "SDD deterministic gate: malformed hook payload."
    }
    if (Test-PayloadMalformed $payload) { Emit-Decision "deny" "SDD deterministic gate: malformed hook payload." }
    if ((Test-ApprovalIncreases $payload) -and -not (Test-SudoActive)) { Emit-Decision "deny" $ApprovalMsg }
} catch {
    Emit-Decision "deny" "SDD deterministic gate: approval guard failed closed."
}

# Check 3: agent-role guard.
try {
    $toolInput = $payload.tool_input
    $toolName = ""
    if ($payload.PSObject.Properties["tool_name"]) { $toolName = ([string]$payload.tool_name).ToLower() }

    # Write-style tools and apply_patch.
    if (Test-AgentRoleInvalid $payload) { Emit-Decision "deny" $AgentRoleMsg }

    # Bash/shell tools.
    $command = $null
    if ($toolInput.PSObject.Properties["command"]) { $command = [string]$toolInput.command }
    if (@("bash", "shell", "exec_command", "exec") -contains $toolName -and $command) {
        if (Test-ShellWritesInvalidAgentRole $command) { Emit-Decision "deny" $AgentRoleMsg }
    }
} catch {
    Emit-Decision "deny" "SDD deterministic gate: agent-role guard failed closed."
}

Emit-Decision "allow" $null
