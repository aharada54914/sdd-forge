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
$WfiApprovalMsg = "SDD deterministic gate: agents must not set 'Status: Approved' in a " +
    "docs/workflow-improvements/WFI-*.md file. Only a human may approve a Workflow " +
    "Improvement; this is never bypassed by sudo. Leave it as Draft and ask the human to approve it."
$SddSudoWriteMsg = "SDD deterministic gate: agents must not create, edit, or delete the " +
    "SDD_SUDO flag file. Only a human may manage sudo mode."
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

function Test-WfiPath {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return $false }
    $normalized = ($Path -replace "\\", "/").ToLower()
    return ($normalized -match "workflow-improvements/" -and $normalized.EndsWith(".md"))
}

function Get-WfiCount {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    return ([regex]::Matches($Text, "Status:\s*Approved")).Count
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

function Resolve-ProjectRoot {
    $envRoot = $env:CLAUDE_PROJECT_DIR
    if (-not [string]::IsNullOrEmpty($envRoot)) {
        return @{ SudoRoot = $envRoot; Bases = @($envRoot, ".") }
    }
    # Walk up to 20 levels; find git root.
    $current = (Get-Location).Path
    for ($i = 0; $i -lt 20; $i++) {
        $gitCandidate = Join-Path $current ".git"
        try {
            if (Test-Path -LiteralPath $gitCandidate) {
                return @{ SudoRoot = $current; Bases = @($current, ".") }
            }
        } catch { }
        $parent = Split-Path -Parent $current
        # Stop at the filesystem root: Split-Path -Parent "/" (POSIX) and
        # "C:\" (Windows) both return an empty string, which would otherwise
        # leave $current empty and make Join-Path throw under -ErrorAction Stop.
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }
        $current = $parent
    }
    return @{ SudoRoot = "."; Bases = @(".") }
}

function Test-SudoActive {
    # C-02/C-08: True if valid, unexpired SDD_SUDO flag exists at project root only.
    # Validates: not a symlink, has issued-epoch, expires-epoch in future, TTL <= 86400s.
    $proj = Resolve-ProjectRoot
    $sudoRoot = $proj.SudoRoot
    try {
        $flag = Join-Path $sudoRoot "SDD_SUDO"
        # Check if path exists and is a file (but not symlink on Windows we can't easily check, skip for now).
        if (-not (Test-Path -LiteralPath $flag -PathType Leaf)) { return $false }
        $content = Get-Content -Raw -Encoding Utf8 -LiteralPath $flag
        $mExp = [regex]::Match($content, "(^|\n)[ \t]*expires-epoch:[ \t]*(\d+)")
        $mIss = [regex]::Match($content, "(^|\n)[ \t]*issued-epoch:[ \t]*(\d+)")
        if (-not $mExp.Success -or -not $mIss.Success) { return $false }
        $expires = [int64]$mExp.Groups[2].Value
        $issued = [int64]$mIss.Groups[2].Value
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        # C-02: issued-epoch <= now < expires-epoch AND TTL <= 86400
        if ($issued -gt $now) { return $false }
        if ($expires -le $now) { return $false }
        if (($expires - $issued) -gt 86400) { return $false }
        return $true
    } catch { }
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

function Test-WfiPatchIncreases {
    param([string]$Patch)
    $currentIsWfi = $false
    $added = 0
    $removed = 0
    foreach ($line in ($Patch -split "`n")) {
        $line = $line -replace "`r$", ""
        $m = [regex]::Match($line, "^\*\*\* (Update|Add|Delete) File: (.+)$")
        if ($m.Success) {
            $currentIsWfi = Test-WfiPath ($m.Groups[2].Value.Trim())
            continue
        }
        if ($line.StartsWith("*** End Patch") -or $line.StartsWith("*** Begin Patch")) { continue }
        if (-not $currentIsWfi) { continue }
        if ($line.StartsWith("+") -and -not $line.StartsWith("+++")) {
            $added += Get-WfiCount $line.Substring(1)
        } elseif ($line.StartsWith("-") -and -not $line.StartsWith("---")) {
            $removed += Get-WfiCount $line.Substring(1)
        }
    }
    return (($added - $removed) -gt 0)
}

function Test-WfiWriteContentIncreases {
    param([string]$FilePath, [string]$NewContent)
    $oldContent = ""
    if (Test-Path -LiteralPath $FilePath) {
        $oldContent = Get-Content -Raw -Encoding Utf8 -LiteralPath $FilePath
    }
    return ((Get-WfiCount $NewContent) -gt (Get-WfiCount $oldContent))
}

function Test-WfiApprovalIncreases {
    param($Payload)
    $toolInput = $Payload.tool_input
    if ($null -eq $toolInput) { return $false }
    $toolName = ""
    if ($Payload.PSObject.Properties["tool_name"]) { $toolName = ([string]$Payload.tool_name).ToLower() }

    $command = $null
    if ($toolInput.PSObject.Properties["command"]) { $command = [string]$toolInput.command }

    if ($toolName -eq "apply_patch" -or ($command -and $command.Contains("*** Begin Patch"))) {
        return Test-WfiPatchIncreases $command
    }

    if (@("bash", "shell", "exec_command", "exec") -contains $toolName -and $command) {
        if ($command.ToLower().Contains("workflow-improvements/") -and [regex]::IsMatch($command, "Status:\s*Approved")) {
            return $true
        }
        return $false
    }

    $filePath = [string]$toolInput.file_path
    if (-not (Test-WfiPath $filePath)) { return $false }

    if ($toolInput.PSObject.Properties["edits"] -and $null -ne $toolInput.edits) {
        foreach ($edit in $toolInput.edits) {
            if ((Get-WfiCount ([string]$edit.new_string)) -gt 0) {
                return $true
            }
        }
        return $false
    } elseif ($toolInput.PSObject.Properties["new_string"]) {
        return (Get-WfiCount ([string]$toolInput.new_string)) -gt 0
    } elseif ($toolInput.PSObject.Properties["content"]) {
        return Test-WfiWriteContentIncreases $filePath ([string]$toolInput.content)
    } else {
        return $false
    }
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

function Test-TargetPathIsSddSudo {
    param([string]$FilePath)
    # C-02: Return True if file_path ends with 'SDD_SUDO' (case-insensitive).
    if ([string]::IsNullOrEmpty($FilePath)) { return $false }
    $normalized = ($FilePath -replace "\\", "/").ToLower()
    return $normalized.EndsWith("sdd_sudo")
}

function Test-ShellTargetsSddSudo {
    param([string]$Cmd)
    # C-02: Return True if shell command targets SDD_SUDO file for write/delete.
    if ([string]::IsNullOrEmpty($Cmd)) { return $false }
    # Check if SDD_SUDO appears in the command (case-insensitive).
    if (-not $Cmd.ToLower().Contains("sdd_sudo")) { return $false }
    # Check if there's a write operator or destructive verb.
    $writeRe = "(?:>|>>|\btee\b|\btouch\b|\bcp\b|\bmv\b|\brm\b|\bSet-Content\b|\bOut-File\b|\bNew-Item\b|\bRemove-Item\b)"
    return [regex]::IsMatch($Cmd, $writeRe, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
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

function Test-WriteContentIncreases {
    param([string]$FilePath, [string]$NewContent)
    # C-03 Write: deny any net increase in Approved markers (file-wide), or a
    # per-task Draft->Approved swap that keeps the file-wide total constant.
    $oldContent = ""
    if (Test-Path -LiteralPath $FilePath) {
        $oldContent = Get-Content -Raw -Encoding Utf8 -LiteralPath $FilePath
    }

    # File-wide guard: any net increase in total Approved markers is a deny.
    # Catches headerless approvals, brand-new files, and bulk additions.
    if ((Get-Count $NewContent) -gt (Get-Count $oldContent)) { return $true }

    # Task-section guard: catch a per-task swap with a constant file-wide total.
    # Extract task sections from old and new content.
    $taskRegex = "^##\s+(T-\S+)"
    $oldTasks = @{}
    $newTasks = @{}

    $oldMatches = [regex]::Matches($oldContent, $taskRegex, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    $oldSplit = [regex]::Split($oldContent, $taskRegex)
    for ($i = 1; $i -lt $oldSplit.Count; $i += 2) {
        $taskId = $oldSplit[$i]
        $section = if ($i + 1 -lt $oldSplit.Count) { $oldSplit[$i + 1] } else { "" }
        if ($taskId) { $oldTasks[$taskId] = Get-Count $section }
    }

    $newMatches = [regex]::Matches($NewContent, $taskRegex, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    $newSplit = [regex]::Split($NewContent, $taskRegex)
    for ($i = 1; $i -lt $newSplit.Count; $i += 2) {
        $taskId = $newSplit[$i]
        $section = if ($i + 1 -lt $newSplit.Count) { $newSplit[$i + 1] } else { "" }
        if ($taskId) { $newTasks[$taskId] = Get-Count $section }
    }

    # Check for transitions: Draft → Approved or new Approved tasks.
    foreach ($taskId in $newTasks.Keys) {
        $newCount = $newTasks[$taskId]
        if ($newCount -gt 0) {
            $oldCount = if ($oldTasks.ContainsKey($taskId)) { $oldTasks[$taskId] } else { 0 }
            if ($newCount -gt $oldCount) {
                return $true
            }
        }
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

    if ($toolInput.PSObject.Properties["edits"] -and $null -ne $toolInput.edits) {
        # C-03: any Approved added in any new_string is a deny, regardless of deletions.
        foreach ($edit in $toolInput.edits) {
            if ((Get-Count ([string]$edit.new_string)) -gt 0) {
                return $true
            }
        }
        return $false
    } elseif ($toolInput.PSObject.Properties["new_string"]) {
        # C-03: any Approved in new_string is a deny (don't subtract old).
        return (Get-Count ([string]$toolInput.new_string)) -gt 0
    } elseif ($toolInput.PSObject.Properties["content"]) {
        # C-03 Write: task-section-level comparison.
        return Test-WriteContentIncreases $filePath ([string]$toolInput.content)
    } else {
        return $false
    }
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

    # Check 2a: C-02 SDD_SUDO write/delete protection (never bypassed by sudo).
    $toolName = ""
    if ($payload.PSObject.Properties["tool_name"]) { $toolName = ([string]$payload.tool_name).ToLower() }
    $toolInput = $payload.tool_input
    $filePath = [string]$toolInput.file_path

    # File tools: Edit, Write, MultiEdit targeting SDD_SUDO.
    if (@("edit", "write", "multiedit") -contains $toolName) {
        if (Test-TargetPathIsSddSudo $filePath) { Emit-Decision "deny" $SddSudoWriteMsg }
    }

    # Shell commands targeting SDD_SUDO.
    $command = $null
    if ($toolInput.PSObject.Properties["command"]) { $command = [string]$toolInput.command }
    if (@("bash", "shell", "exec_command", "exec") -contains $toolName -and $command) {
        if (Test-ShellTargetsSddSudo $command) { Emit-Decision "deny" $SddSudoWriteMsg }
    }

    # apply_patch: check for SDD_SUDO targets.
    if ($toolName -eq "apply_patch" -or ($command -and $command.Contains("*** Begin Patch"))) {
        foreach ($line in ($command -split "`n")) {
            $m = [regex]::Match($line, "^\*\*\* (Update|Add|Delete) File: (.+)$")
            if ($m.Success) {
                if (Test-TargetPathIsSddSudo $m.Groups[2].Value.Trim()) { Emit-Decision "deny" $SddSudoWriteMsg }
            }
        }
    }

    # Check 2b: Approval guard (bypassed by valid sudo).
    if ((Test-ApprovalIncreases $payload) -and -not (Test-SudoActive)) { Emit-Decision "deny" $ApprovalMsg }

    # Check 2c: WFI approval guard (NEVER bypassed by sudo).
    if (Test-WfiApprovalIncreases $payload) { Emit-Decision "deny" $WfiApprovalMsg }
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
