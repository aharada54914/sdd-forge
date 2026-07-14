<#
Unified cross-runtime PreToolUse guard for the SDD quality loop (PowerShell 5.1+).
Functionally identical to sdd-hook-guard.py / sdd-hook-guard.js. Used on Windows
machines without python3/node.

Checks:
  1. Kill switch: deny every tool call while AGENT_STOP exists at
     $env:CLAUDE_PROJECT_DIR (fallback: cwd).
  2a. SDD_SUDO C-02 protection: deny any create/edit/delete of the SDD_SUDO flag
      (never bypassed by sudo).
  2a-R10. Enforcement-chain file protection: deny Edit/Write/MultiEdit, shell, or
      apply_patch writes that target a protected gate file (protected-suffix
      table + working-directory-aware shell write-target analysis + read-only
      short-circuit). Never bypassed by sudo.
  2b. Approval guard: deny a tool call that would increase the number of
      "Approval: Approved" occurrences in any path ending with tasks.md.
      Bypassed while a valid, signed, unexpired SDD_SUDO flag exists (sudo mode).
      Checks 1, 2a, 2a-R10, 2c, 2d, 2e are never bypassed.
  2b-2. Domain-model approval guard (same sudo-bypass class as 2b).
  2c. WFI approval guard (never bypassed by sudo).
  2d. Second Approval guard (never bypassed by sudo).
  2e. Impl-Review-Status forgery guard: deny a write that introduces
      "Impl-Review-Status: Passed" to design.md without a PASS / PASS-with-warnings
      integrated-verdict.json for the feature. Never bypassed by sudo.
  3. Agent-role guard: deny any tool call that would write a Codex agent role
     file (.codex/agents/[^/]+.toml) without a developer_instructions field.

Payloads: Claude/Copilot Edit/Write, Codex apply_patch, Codex Bash/shell.
Output: -Emit exit (default; allow=0, deny=stderr+exit 2) or
        -Emit copilot (always print {"permissionDecision":...} to stdout, exit 0).
Malformed payloads are denied; the guard never throws.

ASCII-only source (AC-015): Windows PowerShell 5.1 parses a BOM-less non-ASCII
.ps1 as ANSI, corrupting the bilingual deny reasons. Every non-ASCII byte in the
messages below is therefore written as a \uXXXX escape and reconstructed at load
time by Expand-Unicode, so the runtime message bytes stay identical to the
.py / .js twins while the source file remains pure ASCII with no BOM.
#>
param(
    [string]$Emit = "exit"
)

$ErrorActionPreference = "Stop"

# Reconstruct a message string from an ASCII-safe source literal: every \uXXXX
# escape (4 hex digits) becomes its Unicode character. Keeps this .ps1 ASCII-only
# (AC-015) while preserving the exact bilingual runtime reasons of the twins.
function Expand-Unicode {
    param([string]$S)
    if ([string]::IsNullOrEmpty($S)) { return $S }
    return [regex]::Replace($S, '\\u([0-9A-Fa-f]{4})', {
        param($m)
        [string][char][Convert]::ToInt32($m.Groups[1].Value, 16)
    })
}

$ApprovalMsg = Expand-Unicode 'SDD\u6c7a\u5b9a\u8ad6\u30b2\u30fc\u30c8: \u30a8\u30fc\u30b8\u30a7\u30f3\u30c8\u306f tasks.md \u306b ''Approval: Approved'' \u3092\u8a2d\u5b9a\u3067\u304d\u307e\u305b\u3093\u3002\u30bf\u30b9\u30af\u306e\u627f\u8a8d\u306f\u3001\u30d5\u30a1\u30a4\u30eb\u3092\u76f4\u63a5\u7de8\u96c6\u3059\u308b\u4eba\u9593\u306e\u307f\u304c\u884c\u3048\u307e\u3059\u3002\u30bf\u30b9\u30af\u306f Draft \u306e\u307e\u307e\u306b\u3057\u3001\u4eba\u9593\u306b\u627f\u8a8d\u3092\u4f9d\u983c\u3057\u3066\u304f\u3060\u3055\u3044\u3002\u000a[EN] SDD deterministic gate: agents must not set ''Approval: Approved'' in tasks.md. Only a human may approve a task by editing the file directly. Leave the task as Draft and ask the human to approve it.'
$WfiApprovalMsg = Expand-Unicode 'SDD\u6c7a\u5b9a\u8ad6\u30b2\u30fc\u30c8: \u30a8\u30fc\u30b8\u30a7\u30f3\u30c8\u306f docs/workflow-improvements/WFI-*.md \u30d5\u30a1\u30a4\u30eb\u306b ''Status: Approved'' \u3092\u8a2d\u5b9a\u3067\u304d\u307e\u305b\u3093\u3002Workflow Improvement \u306e\u627f\u8a8d\u306f\u4eba\u9593\u306e\u307f\u304c\u884c\u3048\u3001sudo \u3067\u3082\u30d0\u30a4\u30d1\u30b9\u3055\u308c\u307e\u305b\u3093\u3002Draft \u306e\u307e\u307e\u306b\u3057\u3001\u4eba\u9593\u306b\u627f\u8a8d\u3092\u4f9d\u983c\u3057\u3066\u304f\u3060\u3055\u3044\u3002\u000a[EN] SDD deterministic gate: agents must not set ''Status: Approved'' in a docs/workflow-improvements/WFI-*.md file. Only a human may approve a Workflow Improvement; this is never bypassed by sudo. Leave it as Draft and ask the human to approve it.'
$SecondApprovalMsg = Expand-Unicode 'SDD\u6c7a\u5b9a\u8ad6\u30b2\u30fc\u30c8: \u30a8\u30fc\u30b8\u30a7\u30f3\u30c8\u306f tasks.md \u306b ''Second Approval: Approved'' \u3092\u8a2d\u5b9a\u3067\u304d\u307e\u305b\u3093\u3002\u7b2c\u4e8c\u627f\u8a8d\u306f\uff08Workflow Improvement \u3068\u540c\u69d8\u306b\uff09\u72ec\u7acb\u3057\u305f\u4eba\u9593\u306e\u5224\u65ad\u3067\u3042\u308a\u3001sudo \u3067\u3082\u30d0\u30a4\u30d1\u30b9\u3055\u308c\u307e\u305b\u3093\u3002\u7b2c\u4e8c\u306e\u4eba\u9593\u306e\u627f\u8a8d\u8005\u304c\u8a18\u9332\u3059\u308b\u307e\u3067\u6b8b\u3057\u3066\u304f\u3060\u3055\u3044\u3002\u000a[EN] SDD deterministic gate: agents must not set ''Second Approval: Approved'' in tasks.md. A second approval is an independent human judgment (like a Workflow Improvement) and is never bypassed by sudo. Leave it for a second human approver to record.'
$DomainModelApprovalMsg = Expand-Unicode 'SDD\u6c7a\u5b9a\u8ad6\u30b2\u30fc\u30c8: \u30a8\u30fc\u30b8\u30a7\u30f3\u30c8\u306f domain/context-map.md \u306b ''Domain-Model-Status: Approved'' \u3092\u8a2d\u5b9a\u3067\u304d\u307e\u305b\u3093\u3002\u30c9\u30e1\u30a4\u30f3\u30e2\u30c7\u30eb\u306e\u627f\u8a8d\u306f\u3001\u30d5\u30a1\u30a4\u30eb\u3092\u76f4\u63a5\u7de8\u96c6\u3059\u308b\u4eba\u9593\u306e\u307f\u304c\u884c\u3048\u307e\u3059\u3002\u30b9\u30c6\u30fc\u30bf\u30b9\u306f Pending/Reviewed \u306e\u307e\u307e\u306b\u3057\u3001\u4eba\u9593\u306b\u627f\u8a8d\u3092\u4f9d\u983c\u3057\u3066\u304f\u3060\u3055\u3044\u3002\u000a[EN] SDD deterministic gate: agents must not set ''Domain-Model-Status: Approved'' in domain/context-map.md. Only a human may approve the domain model by editing the file directly. Leave the status as Pending/Reviewed and ask the human to approve it.'
$SddSudoWriteMsg = Expand-Unicode 'SDD\u6c7a\u5b9a\u8ad6\u30b2\u30fc\u30c8: \u30a8\u30fc\u30b8\u30a7\u30f3\u30c8\u306f SDD_SUDO \u30d5\u30e9\u30b0\u30d5\u30a1\u30a4\u30eb\u306e\u4f5c\u6210\u30fb\u7de8\u96c6\u30fb\u524a\u9664\u3092\u884c\u3048\u307e\u305b\u3093\u3002sudo \u30e2\u30fc\u30c9\u306e\u7ba1\u7406\u306f\u4eba\u9593\u306e\u307f\u304c\u884c\u3048\u307e\u3059\u3002\u000a[EN] SDD deterministic gate: agents must not create, edit, or delete the SDD_SUDO flag file. Only a human may manage sudo mode.'
$KillMsg = Expand-Unicode 'SDD\u30ad\u30eb\u30b9\u30a4\u30c3\u30c1: \u30d7\u30ed\u30b8\u30a7\u30af\u30c8\u30eb\u30fc\u30c8\u306b AGENT_STOP \u304c\u5b58\u5728\u3057\u307e\u3059\u3002\u4eba\u9593\u304c\u3053\u306e\u30d5\u30a1\u30a4\u30eb\u3092\u524a\u9664\u3059\u308b\u307e\u3067\u3001\u3059\u3079\u3066\u306e\u30c4\u30fc\u30eb\u4f7f\u7528\u304c\u505c\u6b62\u3055\u308c\u307e\u3059\u3002\u000a[EN] SDD kill switch: AGENT_STOP exists at the project root. All tool use is suspended until a human deletes the file.'
$AgentRoleMsg = Expand-Unicode 'SDD\u6c7a\u5b9a\u8ad6\u30b2\u30fc\u30c8: developer_instructions \u306e\u7121\u3044 Codex \u30a8\u30fc\u30b8\u30a7\u30f3\u30c8\u30ed\u30fc\u30eb\u30d5\u30a1\u30a4\u30eb\u306e\u66f8\u304d\u8fbc\u307f\u3092\u62d2\u5426\u3057\u307e\u3057\u305f\u3002.codex/agents/ \u914d\u4e0b\u306e\u30d5\u30a1\u30a4\u30eb\u306f developer_instructions \u3092\u5b9a\u7fa9\u3059\u308b\u5fc5\u8981\u304c\u3042\u308a\u3001\u7121\u3044\u5834\u5408 Codex \u306f\u8d77\u52d5\u6642\u306b\u3053\u308c\u3092\u7121\u8996\u3057\u307e\u3059\uff08''Ignoring malformed agent role definition''\uff09\u3002\u65b0\u898f\u4f5c\u6210\u305b\u305a\u3001\u540c\u68b1\u306e sdd-investigator / sdd-evaluator \u30ed\u30fc\u30eb\u3092\u4f7f\u7528\u3057\u3066\u304f\u3060\u3055\u3044\u3002\u000a[EN] SDD deterministic gate: refusing to write a Codex agent role file without developer_instructions. Files under .codex/agents/ must define developer_instructions or Codex ignores them at startup (''Ignoring malformed agent role definition''). Use the shipped sdd-investigator/sdd-evaluator roles instead of creating new ones.'
$GateProtectMsg = Expand-Unicode 'SDD\u6c7a\u5b9a\u8ad6\u30b2\u30fc\u30c8: \u30a8\u30fc\u30b8\u30a7\u30f3\u30c8\u306f\u30b2\u30fc\u30c8\u30b9\u30af\u30ea\u30d7\u30c8\u30fb\u30d5\u30c3\u30af\u8a2d\u5b9a\u30fb\u30c6\u30b9\u30c8\u30d5\u30a1\u30a4\u30eb\u3092\u66f8\u304d\u63db\u3048\u3089\u308c\u307e\u305b\u3093\u3002\u3053\u308c\u3089\u306e\u30d5\u30a1\u30a4\u30eb\u306f\u5f37\u5236\u30c1\u30a7\u30fc\u30f3\u306e\u4e00\u90e8\u3067\u3059\u3002sudo \u3067\u3082\u30d0\u30a4\u30d1\u30b9\u3067\u304d\u307e\u305b\u3093\u3002\u000a[EN] SDD deterministic gate: agents must not modify gate scripts, hook configuration, or critical test files. These are part of the enforcement chain and cannot be bypassed by sudo.'
$ImplReviewStatusMsg = Expand-Unicode 'SDD\u6c7a\u5b9a\u8ad6\u30b2\u30fc\u30c8: \u30a8\u30fc\u30b8\u30a7\u30f3\u30c8\u306f impl-review-loop \u306e PASS \u5224\u5b9a\u306a\u3057\u306b design.md \u306b ''Impl-Review-Status: Passed'' \u3092\u66f8\u304d\u8fbc\u3081\u307e\u305b\u3093\u3002impl-review-loop \u3092\u5b9f\u884c\u3057\u3001integrated-verdict.json \u304c PASS \u307e\u305f\u306f PASS-with-warnings \u3092\u8fd4\u3059\u307e\u3067\u5f85\u3063\u3066\u304f\u3060\u3055\u3044\u3002\u000a[EN] SDD deterministic gate: agents must not write ''Impl-Review-Status: Passed'' in design.md without a valid integrated-verdict.json with verdict PASS or PASS-with-warnings from impl-review-loop. Run impl-review-loop and wait for it to return PASS or PASS-with-warnings.'
$MalformedMsg = Expand-Unicode 'SDD\u6c7a\u5b9a\u8ad6\u30b2\u30fc\u30c8: \u30d5\u30c3\u30af\u306e\u30da\u30a4\u30ed\u30fc\u30c9\u304c\u4e0d\u6b63\u3067\u3059\u3002\u000a[EN] SDD deterministic gate: malformed hook payload.'
$ApprovalFailClosedMsg = Expand-Unicode 'SDD\u6c7a\u5b9a\u8ad6\u30b2\u30fc\u30c8: \u627f\u8a8d\u30ac\u30fc\u30c9\u304c\u30d5\u30a7\u30a4\u30eb\u30af\u30ed\u30fc\u30ba\u3057\u307e\u3057\u305f\u3002\u000a[EN] SDD deterministic gate: approval guard failed closed.'
$AgentRoleFailClosedMsg = Expand-Unicode 'SDD\u6c7a\u5b9a\u8ad6\u30b2\u30fc\u30c8: \u30a8\u30fc\u30b8\u30a7\u30f3\u30c8\u30ed\u30fc\u30eb\u30ac\u30fc\u30c9\u304c\u30d5\u30a7\u30a4\u30eb\u30af\u30ed\u30fc\u30ba\u3057\u307e\u3057\u305f\u3002\u000a[EN] SDD deterministic gate: agent-role guard failed closed.'

if ($Emit -ne "copilot") { $Emit = "exit" }

# --- R-10: Enforcement-chain file protection tables (parity with .py/.js) ---
# Files whose write denial is NOT bypassable by sudo. Matched case-insensitively
# against the normalized (forward-slash, .. collapsed) path.
$ProtectedGateSuffixes = @(
    'plugins/sdd-quality-loop/scripts/sdd-hook-guard.js',
    'plugins/sdd-quality-loop/scripts/sdd-hook-guard.py',
    'plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1',
    'plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh',
    'plugins/sdd-quality-loop/scripts/kill-switch.js',
    'plugins/sdd-quality-loop/scripts/kill-switch.sh',
    'plugins/sdd-quality-loop/scripts/kill-switch.ps1',
    'plugins/sdd-quality-loop/hooks/claude-hooks.json',
    'plugins/sdd-quality-loop/hooks/hooks.json',
    'plugins/sdd-quality-loop/hooks/copilot-hooks.json',
    'plugins/sdd-quality-loop/scripts/check-contract.sh',
    'plugins/sdd-quality-loop/scripts/check-contract.ps1',
    'plugins/sdd-quality-loop/scripts/check-contract.py',
    'plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh',
    'plugins/sdd-quality-loop/scripts/check-evidence-bundle.ps1',
    'plugins/sdd-quality-loop/scripts/check-evidence-bundle.py',
    'plugins/sdd-quality-loop/scripts/validate_path.py',
    '.claude/settings.json',
    '.claude/settings.local.json',
    'tests/gates.tests.sh',
    'tests/eval.tests.sh',
    'tests/guard-parity.tests.sh',
    'tests/constant-parity.tests.sh',
    'plugins/sdd-review-loop/agents/impl-reviewer-a.md',
    'plugins/sdd-review-loop/agents/impl-reviewer-b.md',
    'plugins/sdd-review-loop/agents/task-reviewer-a.md',
    'plugins/sdd-review-loop/agents/task-reviewer-b.md',
    'plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md',
    'plugins/sdd-review-loop/skills/task-review-loop/SKILL.md',
    'plugins/sdd-ship/skills/ship/SKILL.md'
)

$ProtectedGatePluginJsonSuffixes = @(
    '/.plugin/plugin.json',
    '/.claude-plugin/plugin.json',
    '/.codex-plugin/plugin.json'
)

# REQ-002 (issue #110): basenames of every protected suffix. The
# working-directory-aware write-target analysis falls back to a basename match
# only when a cd/pushd transition cannot be resolved but a write verb still
# targets a protected basename -- fail closed.
$ProtectedBasenames = New-Object System.Collections.Generic.List[string]
foreach ($s in ($ProtectedGateSuffixes + ($ProtectedGatePluginJsonSuffixes | ForEach-Object { $_.TrimStart('/') }))) {
    $bn = (($s.ToLower()) -replace '\\', '/').Split('/')[-1]
    if (-not $ProtectedBasenames.Contains($bn)) { $ProtectedBasenames.Add($bn) }
}

# Issue #62 / REQ-002: write-target analysis verb sets and token patterns kept
# identical to the .py/.js twins.
$ShellWriteArgCmds     = @('tee', 'touch', 'rm')
$ShellWriteDestCmds    = @('cp', 'mv')
$ShellPsWriteCmds      = @('set-content', 'out-file', 'new-item', 'remove-item')
$ShellIndirectCmds     = @('eval', 'xargs', 'source', 'sh', 'bash', 'zsh', 'dash', 'ksh')
$ShellUnsafeTokenChars = @('$', '`', '(', ')', '{', '}', '*', '?', '[', ']')
$ShellCdCmds           = @('cd', 'pushd')
$ShellRedirectTokenRe  = '^(?:\d*|&)(>>?)([\s\S]*)$'
$ShellFdDupRe          = '^&(?:\d+|-)$'
$ShellCompoundRe       = '&&|\|\||;|\|'
$ShellSudoWriteRe      = "(?:>|>>|\btee\b|\btouch\b|\bcp\b|\bmv\b|\brm\b|\bSet-Content\b|\bOut-File\b|\bNew-Item\b|\bRemove-Item\b)"
$ShellReadOnlyStartRe  = '^\s*(?:cat|ls|test|grep|stat|head|tail|rg)\b'

function Get-Count {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    # Subtract second approvals from primary count to avoid over-counting
    # (since "Second Approval: Approved" contains "Approval: Approved" as a substring)
    $primary = ([regex]::Matches($Text, "Approval:\s*Approved")).Count
    $secondary = ([regex]::Matches($Text, "Second Approval:\s*Approved")).Count
    return ($primary - $secondary)
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

function Test-DomainContextMapPath {
    param([string]$Path)
    # domain/context-map.md is the sdd-domain plugin's approval-line file.
    # Case-insensitive match (matches Test-TasksMd/Test-WfiPath convention).
    if ([string]::IsNullOrEmpty($Path)) { return $false }
    $normalized = ($Path -replace "\\", "/").ToLower()
    return $normalized.EndsWith("domain/context-map.md")
}

function Get-DomainModelCount {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    return ([regex]::Matches($Text, "Domain-Model-Status:\s*Approved")).Count
}

function Get-SecondApprovalCount {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    return ([regex]::Matches($Text, "Second Approval:\s*Approved")).Count
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
    # C-08: walk parents up to git root checking for AGENT_STOP (matches the
    # .py/.js/kill-switch.ps1 twins; a nested cwd without CLAUDE_PROJECT_DIR
    # must still see AGENT_STOP placed at the project root).
    $envRoot = $env:CLAUDE_PROJECT_DIR
    if (-not [string]::IsNullOrEmpty($envRoot)) {
        $bases = @($envRoot, ".")
    } else {
        $bases = @()
        $current = (Get-Location).Path
        $gitRootFound = $null
        for ($i = 0; $i -lt 21; $i++) {
            $bases += $current
            $gitCandidate = Join-Path $current ".git"
            try {
                if (Test-Path -LiteralPath $gitCandidate) {
                    $gitRootFound = $current
                    break
                }
            } catch { }
            $parent = Split-Path -Parent $current
            if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }
            $current = $parent
        }
        if (-not $gitRootFound -and "." -notin $bases) {
            $bases += "."
        }
    }
    foreach ($base in $bases) {
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

function Get-SudoFields {
    param([string]$Content)
    # Parse key: value lines into a hashtable (values stripped).
    $fields = @{}
    foreach ($rawLine in ($Content -split "`n")) {
        $line = $rawLine -replace "`r$", ""
        $colonIdx = $line.IndexOf(":")
        if ($colonIdx -ge 0) {
            $key = $line.Substring(0, $colonIdx).Trim()
            $val = $line.Substring($colonIdx + 1).Trim()
            $fields[$key] = $val
        }
    }
    return $fields
}

function Resolve-SudoKey {
    # C-04: Resolve signing key bytes per priority order. Returns [byte[]] or $null.
    # 1. env SDD_SUDO_KEY
    $envKey = $env:SDD_SUDO_KEY
    if (-not [string]::IsNullOrEmpty($envKey)) {
        return [System.Text.Encoding]::UTF8.GetBytes($envKey)
    }
    # 2. env SDD_SUDO_KEY_FILE
    $envKeyFile = $env:SDD_SUDO_KEY_FILE
    if (-not [string]::IsNullOrEmpty($envKeyFile)) {
        try {
            $raw = (Get-Content -Raw -Encoding Utf8 -LiteralPath $envKeyFile).TrimEnd(" `t`r`n")
            if ($raw.Length -gt 0) {
                return [System.Text.Encoding]::UTF8.GetBytes($raw)
            }
        } catch { }
        return $null
    }
    # 3. <HOME>/.sdd/sudo-key
    $homeDir = $env:HOME
    if ([string]::IsNullOrEmpty($homeDir)) { $homeDir = $env:USERPROFILE }
    if (-not [string]::IsNullOrEmpty($homeDir)) {
        $keyPath = Join-Path $homeDir ".sdd/sudo-key"
        try {
            $raw = (Get-Content -Raw -Encoding Utf8 -LiteralPath $keyPath).TrimEnd(" `t`r`n")
            if ($raw.Length -gt 0) {
                return [System.Text.Encoding]::UTF8.GetBytes($raw)
            }
        } catch { }
    }
    # 4. No key
    return $null
}

function Get-SudoCanonical {
    param([hashtable]$Fields)
    # Canonical string: 5 values joined by LF (no trailing newline).
    $issuer   = if ($Fields.ContainsKey("issuer"))        { $Fields["issuer"] }        else { "" }
    $nonce    = if ($Fields.ContainsKey("nonce"))         { $Fields["nonce"] }         else { "" }
    $repo     = if ($Fields.ContainsKey("repo"))          { $Fields["repo"] }          else { "" }
    $issuedV  = if ($Fields.ContainsKey("issued-epoch"))  { $Fields["issued-epoch"] }  else { "0" }
    $expiresV = if ($Fields.ContainsKey("expires-epoch")) { $Fields["expires-epoch"] } else { "0" }
    $issuedStr  = [string]([int64]$issuedV)
    $expiresStr = [string]([int64]$expiresV)
    return ($issuer, $nonce, $repo, $issuedStr, $expiresStr) -join "`n"
}

function Test-SudoActive {
    # C-02/C-04/C-08: True if valid, signed, unexpired SDD_SUDO flag exists at project root only.
    # Validates: not a symlink, required fields present, nonce format, epoch ranges,
    # repo-binding, and HMAC-SHA256 signature with key resolved from env/file.
    $proj = Resolve-ProjectRoot
    $sudoRoot = $proj.SudoRoot
    try {
        $flag = Join-Path $sudoRoot "SDD_SUDO"
        # Check if path exists and is a file (not symlink).
        if (-not (Test-Path -LiteralPath $flag -PathType Leaf)) { return $false }
        $content = Get-Content -Raw -Encoding Utf8 -LiteralPath $flag

        $fields = Get-SudoFields $content

        # Required fields
        foreach ($req in @("issuer", "nonce", "repo", "issued-epoch", "expires-epoch", "sig")) {
            if (-not $fields.ContainsKey($req) -or [string]::IsNullOrEmpty($fields[$req])) { return $false }
        }

        # Nonce format: >= 32 hex chars
        if (-not [regex]::IsMatch($fields["nonce"], "^[0-9a-fA-F]{32,}$")) { return $false }

        $expires = [int64]$fields["expires-epoch"]
        $issued  = [int64]$fields["issued-epoch"]
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

        # C-02: issued-epoch <= now < expires-epoch AND TTL <= 86400
        if ($issued -gt $now) { return $false }
        if ($expires -le $now) { return $false }
        if (($expires - $issued) -gt 86400) { return $false }

        # Repo-binding: canonical path of the directory holding SDD_SUDO
        $actualRepo = $null
        try {
            $actualRepo = (Resolve-Path -LiteralPath $sudoRoot).Path
        } catch {
            try { $actualRepo = [System.IO.Path]::GetFullPath($sudoRoot) } catch { return $false }
        }
        if ($fields["repo"] -ne $actualRepo) { return $false }

        # Key resolution and HMAC verification
        $keyBytes = Resolve-SudoKey
        if ($null -eq $keyBytes) { return $false }

        $canonical = Get-SudoCanonical $fields
        $canonicalBytes = [System.Text.Encoding]::UTF8.GetBytes($canonical)
        $hmacObj = New-Object System.Security.Cryptography.HMACSHA256(,$keyBytes)
        $macBytes = $hmacObj.ComputeHash($canonicalBytes)
        $hmacObj.Dispose()
        $expectedHex = -join ($macBytes | ForEach-Object { $_.ToString("x2") })
        $sigField = $fields["sig"].ToLower()

        # String comparison (acceptable in ps1 per spec)
        if ($expectedHex -ne $sigField) { return $false }

        return $true
    } catch { }
    return $false
}

# --- R-10 / issue #62 / REQ-002: protected-gate-file write-target analysis ---

function Normalize-PosixPath {
    # Pure-string posix normalization (parity with os.path.normpath /
    # path.posix.normalize): forward slashes, collapse '.', resolve '..'. Does not
    # make the path absolute and does not touch the filesystem.
    param([string]$P)
    if ([string]::IsNullOrEmpty($P)) { return "." }
    $s = $P -replace "\\", "/"
    $isAbs = $s.StartsWith("/")
    $outParts = New-Object System.Collections.Generic.List[string]
    foreach ($seg in ($s -split "/")) {
        if ($seg -eq "" -or $seg -eq ".") { continue }
        if ($seg -eq "..") {
            if ($outParts.Count -gt 0 -and $outParts[$outParts.Count - 1] -ne "..") {
                $outParts.RemoveAt($outParts.Count - 1)
            } elseif (-not $isAbs) {
                $outParts.Add("..")
            }
        } else {
            $outParts.Add($seg)
        }
    }
    $joined = ($outParts -join "/")
    if ($isAbs) { return "/" + $joined }
    if ($joined -eq "") { return "." }
    return $joined
}

function Test-IsProtectedGateFile {
    # R-10: True if file_path matches a protected enforcement-chain file.
    param([string]$FilePath)
    if ([string]::IsNullOrEmpty($FilePath)) { return $false }
    $normalized = (Normalize-PosixPath ($FilePath -replace "\\", "/")).ToLower()
    foreach ($suffix in $ProtectedGateSuffixes) {
        if ($normalized.EndsWith($suffix.ToLower())) { return $true }
    }
    foreach ($suffix in $ProtectedGatePluginJsonSuffixes) {
        $sl = $suffix.ToLower()
        # Match absolute paths (suffix has leading /) AND relative paths (no leading /).
        if ($normalized.EndsWith($sl) -or $normalized.EndsWith($sl.TrimStart("/"))) { return $true }
    }
    return $false
}

function Tokenize-ShellCommand {
    # Issue #62: simple shell tokenizer (same algorithm as the .py/.js twins).
    # Splits on unquoted spaces/tabs; ';', '|', '&' and newlines become separator
    # tokens; single/double quotes group text (quote marks removed); '>&'/'&>'
    # stay attached to their redirect token. Returns @{ Tokens = <list> } where
    # each element is a two-item array @(kind, text) with kind 'word' or 'sep', or
    # $null when the command uses constructs the tokenizer does not model
    # (backslash escapes, unclosed quotes) -- callers must fail closed on $null.
    param([string]$Cmd)
    $tokens = New-Object System.Collections.Generic.List[object]
    $cur = ""
    $pending = $false
    $inSingle = $false
    $inDouble = $false
    $i = 0
    $n = $Cmd.Length
    while ($i -lt $n) {
        $ch = $Cmd.Substring($i, 1)
        if ($inSingle) {
            if ($ch -eq "'") { $inSingle = $false } else { $cur += $ch }
            $i++
            continue
        }
        if ($inDouble) {
            if ($ch -eq '"') { $inDouble = $false }
            elseif ($ch -eq '\') { return $null }
            else { $cur += $ch }
            $i++
            continue
        }
        if ($ch -eq "'") { $inSingle = $true; $pending = $true }
        elseif ($ch -eq '"') { $inDouble = $true; $pending = $true }
        elseif ($ch -eq '\') { return $null }
        elseif ($ch -eq "`n" -or $ch -eq "`r" -or $ch -eq ';' -or $ch -eq '|') {
            if ($pending) { $tokens.Add(@("word", $cur)); $cur = ""; $pending = $false }
            $tokens.Add(@("sep", $ch))
        }
        elseif ($ch -eq '&') {
            if ($pending -and $cur.EndsWith(">")) {
                # 2>&1-style fd duplication stays inside the redirect token.
                $cur += $ch
            } elseif (($i + 1) -lt $n -and $Cmd.Substring($i + 1, 1) -eq '>') {
                # &>-style redirect starts a new token.
                if ($pending) { $tokens.Add(@("word", $cur)) }
                $cur = "&"
                $pending = $true
            } else {
                if ($pending) { $tokens.Add(@("word", $cur)); $cur = "" }
                $pending = $false
                $tokens.Add(@("sep", $ch))
            }
        }
        elseif ($ch -eq ' ' -or $ch -eq "`t") {
            if ($pending) { $tokens.Add(@("word", $cur)); $cur = ""; $pending = $false }
        }
        else {
            $cur += $ch
            $pending = $true
        }
        $i++
    }
    if ($inSingle -or $inDouble) { return $null }
    if ($pending) { $tokens.Add(@("word", $cur)) }
    return @{ Tokens = $tokens }
}

function Get-ShellTokenBasename {
    # Issue #62: lowercased final path component of a token (verb matching).
    param([string]$Tok)
    $t = ($Tok.ToLower()) -replace "\\", "/"
    $idx = $t.LastIndexOf("/")
    if ($idx -eq -1) { return $t }
    return $t.Substring($idx + 1)
}

function Test-HasUnsafeChar {
    param([string]$S)
    foreach ($c in $ShellUnsafeTokenChars) {
        if ($S.Contains($c)) { return $true }
    }
    return $false
}

function Test-SimpleShellCommandIsSafe {
    # Issue #62: check one separator-free simple command. Returns $false when a
    # redirect or write verb in it targets (or may target) a protected gate file.
    param([string[]]$Words)
    $plain = New-Object System.Collections.Generic.List[string]
    $k = 0
    $n = $Words.Count
    while ($k -lt $n) {
        $w = $Words[$k]
        if ($w.Contains(">")) {
            $m = [regex]::Match($w, $ShellRedirectTokenRe)
            if (-not $m.Success) { return $false }
            $rest = $m.Groups[2].Value
            if ($rest -eq "") {
                # Detached target (`> file`): consume and check the next token.
                $k++
                if ($k -ge $n -or $Words[$k].Contains(">")) { return $false }
                if (Test-IsProtectedGateFile $Words[$k]) { return $false }
            } elseif ($rest.StartsWith("&")) {
                # fd duplication (2>&1, >&2, >&-) is harmless; anything else fails closed.
                if (-not [regex]::IsMatch($rest, $ShellFdDupRe)) { return $false }
            } else {
                if (Test-IsProtectedGateFile $rest) { return $false }
            }
        } else {
            $plain.Add($w)
        }
        $k++
    }
    $writeAt = -1
    $writeBase = ""
    for ($idx = 0; $idx -lt $plain.Count; $idx++) {
        $base = Get-ShellTokenBasename $plain[$idx]
        if (($ShellWriteArgCmds -contains $base) -or ($ShellWriteDestCmds -contains $base)) {
            $writeAt = $idx
            $writeBase = $base
            break
        }
    }
    if ($writeAt -lt 0) { return $true }
    $nonFlags = New-Object System.Collections.Generic.List[string]
    for ($j = $writeAt + 1; $j -lt $plain.Count; $j++) {
        if (-not $plain[$j].StartsWith("-")) { $nonFlags.Add($plain[$j]) }
    }
    if ($ShellWriteDestCmds -contains $writeBase) {
        # cp/mv: only the final non-flag argument (the destination) is written;
        # sources are reads. Fewer than two path arguments cannot be judged.
        if ($nonFlags.Count -lt 2) { return $false }
        return (-not (Test-IsProtectedGateFile $nonFlags[$nonFlags.Count - 1]))
    }
    # tee/touch/rm: every non-flag argument is written (or deleted).
    foreach ($a in $nonFlags) {
        if (Test-IsProtectedGateFile $a) { return $false }
    }
    return $true
}

function Test-ShellWriteTargetsAreSafe {
    # Issue #62: $true only when every write verb/redirect in cmd provably targets
    # a non-protected path. Unmodeled constructs (escapes, expansions, globs,
    # subshells, eval/xargs/shell interpreters, PowerShell write verbs) fail closed.
    param([string]$Cmd)
    $res = Tokenize-ShellCommand $Cmd
    if ($null -eq $res) { return $false }
    $tokens = $res.Tokens
    $commands = New-Object System.Collections.Generic.List[object]
    $words = New-Object System.Collections.Generic.List[string]
    foreach ($t in $tokens) {
        if ($t[0] -eq "sep") {
            if ($words.Count -gt 0) { $commands.Add($words.ToArray()); $words = New-Object System.Collections.Generic.List[string] }
        } else {
            $words.Add($t[1])
        }
    }
    if ($words.Count -gt 0) { $commands.Add($words.ToArray()) }
    foreach ($command in $commands) {
        foreach ($w in $command) {
            if (Test-HasUnsafeChar $w) { return $false }
            $base = Get-ShellTokenBasename $w
            if (($ShellIndirectCmds -contains $base) -or ($ShellPsWriteCmds -contains $base)) { return $false }
        }
        if (-not (Test-SimpleShellCommandIsSafe $command)) { return $false }
    }
    return $true
}

function Apply-CdTransition {
    # REQ-002: update the tracked working directory for a cd/pushd segment.
    # Returns @{ Dir; Known }. Unresolvable transitions taint the state
    # (Known=$false): bare cd (home), `cd -`, a `~` argument, or an argument with
    # shell metacharacters. An absolute argument re-anchors even from a tainted state.
    param([string]$CurrentDir, [bool]$CwdKnown, [string[]]$Words)
    $cdArgs = New-Object System.Collections.Generic.List[string]
    for ($j = 1; $j -lt $Words.Count; $j++) {
        if (-not $Words[$j].StartsWith("-")) { $cdArgs.Add($Words[$j]) }
    }
    if ($cdArgs.Count -eq 0) { return @{ Dir = $CurrentDir; Known = $false } }
    $arg = $cdArgs[0]
    if ($arg.StartsWith("~") -or (Test-HasUnsafeChar $arg)) { return @{ Dir = $CurrentDir; Known = $false } }
    if ($arg.StartsWith("/")) { return @{ Dir = (Normalize-PosixPath $arg); Known = $true } }
    if (-not $CwdKnown) { return @{ Dir = $CurrentDir; Known = $false } }
    $joined = if ($CurrentDir) { "$CurrentDir/$arg" } else { $arg }
    return @{ Dir = (Normalize-PosixPath $joined); Known = $true }
}

function Test-CwdWriteTargetIsProtected {
    # REQ-002: $true when a write target resolves to a protected gate file.
    # Absolute targets resolve directly; relative targets resolve against the
    # tracked directory when known, else fail closed on a protected basename.
    # Targets carrying shell metacharacters are left to the substring/issue-#62
    # analysis (return $false here).
    param([string]$CurrentDir, [bool]$CwdKnown, [string]$Target)
    if (Test-HasUnsafeChar $Target) { return $false }
    if ($Target.StartsWith("/")) { return (Test-IsProtectedGateFile $Target) }
    if ($CwdKnown) {
        $resolved = if ($CurrentDir) { "$CurrentDir/$Target" } else { $Target }
        return (Test-IsProtectedGateFile $resolved)
    }
    return ($ProtectedBasenames.Contains((Get-ShellTokenBasename $Target)))
}

function Test-SegmentWriteHitsProtected {
    # REQ-002: $true when a write verb/redirect in one simple command targets a
    # protected gate file, resolved against the tracked working directory. Mirrors
    # the read/write argument semantics of Test-SimpleShellCommandIsSafe.
    param([string[]]$Words, [string]$CurrentDir, [bool]$CwdKnown)
    $plain = New-Object System.Collections.Generic.List[string]
    $k = 0
    $n = $Words.Count
    while ($k -lt $n) {
        $w = $Words[$k]
        if ($w.Contains(">")) {
            $m = [regex]::Match($w, $ShellRedirectTokenRe)
            if (-not $m.Success) { $k++; continue }
            $rest = $m.Groups[2].Value
            if ($rest -eq "") {
                $k++
                if ($k -lt $n -and (-not $Words[$k].Contains(">"))) {
                    if (Test-CwdWriteTargetIsProtected $CurrentDir $CwdKnown $Words[$k]) { return $true }
                }
            } elseif (-not $rest.StartsWith("&")) {
                if (Test-CwdWriteTargetIsProtected $CurrentDir $CwdKnown $rest) { return $true }
            }
        } else {
            $plain.Add($w)
        }
        $k++
    }
    $writeAt = -1
    $writeBase = ""
    for ($idx = 0; $idx -lt $plain.Count; $idx++) {
        $base = Get-ShellTokenBasename $plain[$idx]
        if (($ShellWriteArgCmds -contains $base) -or ($ShellWriteDestCmds -contains $base)) {
            $writeAt = $idx
            $writeBase = $base
            break
        }
    }
    if ($writeAt -lt 0) { return $false }
    $nonFlags = New-Object System.Collections.Generic.List[string]
    for ($j = $writeAt + 1; $j -lt $plain.Count; $j++) {
        if (-not $plain[$j].StartsWith("-")) { $nonFlags.Add($plain[$j]) }
    }
    if ($ShellWriteDestCmds -contains $writeBase) {
        if ($nonFlags.Count -gt 0) {
            return (Test-CwdWriteTargetIsProtected $CurrentDir $CwdKnown $nonFlags[$nonFlags.Count - 1])
        }
        return $false
    }
    foreach ($a in $nonFlags) {
        if (Test-CwdWriteTargetIsProtected $CurrentDir $CwdKnown $a) { return $true }
    }
    return $false
}

function Test-ShellCwdWriteHitsProtected {
    # REQ-002 (issue #110): Working-directory-aware R-10 detection. Tracks
    # cd/pushd transitions across compound-command segments (&&, ||, ;, |) and
    # denies when a write verb or redirect resolves to a protected gate file --
    # closing the `cd <protected-dir> && rm <basename>` bypass of the substring
    # scan. A read-only segment (no write verb/redirect) never produces a hit, so
    # the read-only short-circuit is preserved. Unparseable commands (tokenizer
    # returns $null) yield no hit here; the substring + issue-#62 analysis retains
    # its fail-closed behavior for those.
    param([string]$Cmd)
    $res = Tokenize-ShellCommand $Cmd
    if ($null -eq $res) { return $false }
    $tokens = $res.Tokens
    $segments = New-Object System.Collections.Generic.List[object]
    $words = New-Object System.Collections.Generic.List[string]
    foreach ($t in $tokens) {
        if ($t[0] -eq "sep") {
            if ($words.Count -gt 0) { $segments.Add($words.ToArray()); $words = New-Object System.Collections.Generic.List[string] }
        } else {
            $words.Add($t[1])
        }
    }
    if ($words.Count -gt 0) { $segments.Add($words.ToArray()) }
    $currentDir = ""
    $cwdKnown = $true
    foreach ($seg in $segments) {
        if ($seg.Count -eq 0) { continue }
        $verb = Get-ShellTokenBasename $seg[0]
        if ($ShellCdCmds -contains $verb) {
            $r = Apply-CdTransition $currentDir $cwdKnown $seg
            $currentDir = $r.Dir
            $cwdKnown = $r.Known
            continue
        }
        if ($verb -eq "popd") { $cwdKnown = $false; continue }
        if (Test-SegmentWriteHitsProtected $seg $currentDir $cwdKnown) { return $true }
    }
    return $false
}

function Test-ShellTargetsProtectedGateFile {
    # R-10: Deny shell commands that WRITE to protected gate files. Substring scan
    # (path appears literally in command) combined with write-target analysis
    # (issue #62): a write verb/redirect elsewhere no longer denies read-only
    # access to a protected path. Read-only short-circuit fires only when: no
    # compound operators, command starts with a read-only verb, and no write
    # verb/redirect appears anywhere. REQ-002 (issue #110): a working-directory-
    # aware pass additionally resolves write targets across cd/pushd transitions.
    param([string]$Cmd)
    if ([string]::IsNullOrEmpty($Cmd)) { return $false }
    # REQ-002: cd/pushd-aware resolution catches protected writes that never spell
    # the full protected path literally. Read-only segments never hit, so this is
    # checked before the read-only short-circuit below.
    if (Test-ShellCwdWriteHitsProtected $Cmd) { return $true }
    $cmdLower = $Cmd.ToLower()
    $hasProtectedPath = $false
    foreach ($s in $ProtectedGateSuffixes) {
        if ($cmdLower.Contains($s.ToLower())) { $hasProtectedPath = $true; break }
    }
    if (-not $hasProtectedPath) {
        foreach ($s in $ProtectedGatePluginJsonSuffixes) {
            $sl = $s.ToLower()
            if ($cmdLower.Contains($sl) -or $cmdLower.Contains($sl.TrimStart("/"))) { $hasProtectedPath = $true; break }
        }
    }
    if (-not $hasProtectedPath) { return $false }
    $hasWrite = [regex]::IsMatch($Cmd, $ShellSudoWriteRe, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $hasCompound = [regex]::IsMatch($Cmd, $ShellCompoundRe)
    $isReadOnlyStart = [regex]::IsMatch($Cmd, $ShellReadOnlyStartRe, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ((-not $hasCompound) -and $isReadOnlyStart -and (-not $hasWrite)) { return $false }
    if (-not $hasWrite) { return $false }
    return (-not (Test-ShellWriteTargetsAreSafe $Cmd))
}

function Test-DesignMd {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return $false }
    return (($Path -replace "\\", "/").ToLower()).EndsWith("design.md")
}

function Test-ImplReviewVerdictExists {
    # Check whether a valid integrated-verdict.json with PASS or PASS-with-warnings
    # exists in reports/impl-review/<feature>/ (CWD-relative, ADR-004). Extract the
    # feature from the design.md path (specs/<feature>/design.md).
    param([string]$FilePath)
    if ([string]::IsNullOrEmpty($FilePath)) { return $false }
    $normalized = $FilePath -replace "\\", "/"
    $m = [regex]::Match($normalized, 'specs/([^/]+)/design\.md$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $m.Success) { return $false }
    $feature = $m.Groups[1].Value
    $reportsBase = "reports/impl-review/$feature"
    try {
        if (-not (Test-Path -LiteralPath $reportsBase)) { return $false }
        $attemptDirs = Get-ChildItem -LiteralPath $reportsBase -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "attempt-*" }
        foreach ($ad in $attemptDirs) {
            $roundDirs = Get-ChildItem -LiteralPath $ad.FullName -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "round-*" }
            foreach ($rd in $roundDirs) {
                $verdictPath = Join-Path $rd.FullName "integrated-verdict.json"
                if (Test-Path -LiteralPath $verdictPath) {
                    try {
                        $content = Get-Content -Raw -Encoding Utf8 -LiteralPath $verdictPath
                        $verdict = $content | ConvertFrom-Json
                        if ($verdict.verdict -eq "PASS" -or $verdict.verdict -eq "PASS-with-warnings") { return $true }
                    } catch { }
                }
            }
        }
    } catch { }
    return $false
}

function Test-ImplReviewStatusPassedIncreases {
    # Deny writing 'Impl-Review-Status: Passed' in design.md unless a valid
    # integrated-verdict.json with PASS | PASS-with-warnings exists for the feature.
    param($Payload)
    $toolInput = $Payload.tool_input
    if ($null -eq $toolInput) { return $false }
    $toolName = ""
    if ($Payload.PSObject.Properties["tool_name"]) { $toolName = ([string]$Payload.tool_name).ToLower() }
    $filePath = [string]$toolInput.file_path

    if (-not (@("edit", "write", "multiedit") -contains $toolName)) { return $false }
    if (-not (Test-DesignMd $filePath)) { return $false }

    $newContent = ""
    if ($toolInput.PSObject.Properties["edits"] -and $null -ne $toolInput.edits) {
        foreach ($edit in $toolInput.edits) {
            $ns = [string]$edit.new_string
            if ([regex]::IsMatch($ns, "Impl-Review-Status:\s*Passed")) { $newContent = $ns; break }
        }
    } elseif ($toolInput.PSObject.Properties["new_string"]) {
        $newContent = [string]$toolInput.new_string
    } elseif ($toolInput.PSObject.Properties["content"]) {
        $newContent = [string]$toolInput.content
    }

    if (-not [regex]::IsMatch($newContent, "Impl-Review-Status:\s*Passed")) { return $false }

    $oldContent = ""
    if (Test-Path -LiteralPath $filePath) {
        try { $oldContent = Get-Content -Raw -Encoding Utf8 -LiteralPath $filePath } catch { $oldContent = "" }
    }
    if ($null -eq $oldContent) { $oldContent = "" }
    if ([regex]::IsMatch($oldContent, "Impl-Review-Status:\s*Passed")) { return $false }  # already set; not a new introduction

    return (-not (Test-ImplReviewVerdictExists $filePath))
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

# T-006: domain-model approval guard patch parser. Mirrors Test-PatchIncreases
# EXACTLY (same net-increase counting logic, same sudo-bypass behavior) --
# this is NOT the never-sudo-bypassable Test-WfiPatchIncreases pattern below.
function Test-DomainModelPatchIncreases {
    param([string]$Patch)
    $currentIsDomainContextMap = $false
    $added = 0
    $removed = 0
    foreach ($line in ($Patch -split "`n")) {
        $line = $line -replace "`r$", ""
        $m = [regex]::Match($line, "^\*\*\* (Update|Add|Delete) File: (.+)$")
        if ($m.Success) {
            $currentIsDomainContextMap = Test-DomainContextMapPath ($m.Groups[2].Value.Trim())
            continue
        }
        if ($line.StartsWith("*** End Patch") -or $line.StartsWith("*** Begin Patch")) { continue }
        if (-not $currentIsDomainContextMap) { continue }
        if ($line.StartsWith("+") -and -not $line.StartsWith("+++")) {
            $added += Get-DomainModelCount $line.Substring(1)
        } elseif ($line.StartsWith("-") -and -not $line.StartsWith("---")) {
            $removed += Get-DomainModelCount $line.Substring(1)
        }
    }
    return (($added - $removed) -gt 0)
}

function Test-DomainModelWriteContentIncreases {
    param([string]$FilePath, [string]$NewContent)
    $oldContent = ""
    if (Test-Path -LiteralPath $FilePath) {
        $oldContent = Get-Content -Raw -Encoding Utf8 -LiteralPath $FilePath
    }
    return ((Get-DomainModelCount $NewContent) -gt (Get-DomainModelCount $oldContent))
}

function Test-DomainModelApprovalIncreases {
    param($Payload)
    $toolInput = $Payload.tool_input
    if ($null -eq $toolInput) { return $false }
    $toolName = ""
    if ($Payload.PSObject.Properties["tool_name"]) { $toolName = ([string]$Payload.tool_name).ToLower() }

    $command = $null
    if ($toolInput.PSObject.Properties["command"]) { $command = [string]$toolInput.command }

    # Codex apply_patch: raw patch envelope in tool_input.command.
    if ($toolName -eq "apply_patch" -or ($command -and $command.Contains("*** Begin Patch"))) {
        return Test-DomainModelPatchIncreases $command
    }

    # Codex Bash/shell: conservative heuristic.
    if (@("bash", "shell", "exec_command", "exec") -contains $toolName -and $command) {
        if ($command.ToLower().Contains("domain/context-map.md") -and [regex]::IsMatch($command, "Domain-Model-Status:\s*Approved")) {
            return $true
        }
        return $false
    }

    # Claude / Copilot Edit / Write.
    $filePath = [string]$toolInput.file_path
    if (-not (Test-DomainContextMapPath $filePath)) { return $false }

    if ($toolInput.PSObject.Properties["edits"] -and $null -ne $toolInput.edits) {
        foreach ($edit in $toolInput.edits) {
            if ((Get-DomainModelCount ([string]$edit.new_string)) -gt 0) {
                return $true
            }
        }
        return $false
    } elseif ($toolInput.PSObject.Properties["new_string"]) {
        return (Get-DomainModelCount ([string]$toolInput.new_string)) -gt 0
    } elseif ($toolInput.PSObject.Properties["content"]) {
        return Test-DomainModelWriteContentIncreases $filePath ([string]$toolInput.content)
    } else {
        return $false
    }
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

function Test-SecondApprovalPatchIncreases {
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
            $added += Get-SecondApprovalCount $line.Substring(1)
        } elseif ($line.StartsWith("-") -and -not $line.StartsWith("---")) {
            $removed += Get-SecondApprovalCount $line.Substring(1)
        }
    }
    return (($added - $removed) -gt 0)
}

function Test-SecondApprovalWriteContentIncreases {
    param([string]$FilePath, [string]$NewContent)
    $oldContent = ""
    if (Test-Path -LiteralPath $FilePath) {
        $oldContent = Get-Content -Raw -Encoding Utf8 -LiteralPath $FilePath
    }
    return ((Get-SecondApprovalCount $NewContent) -gt (Get-SecondApprovalCount $oldContent))
}

function Test-SecondApprovalIncreases {
    param($Payload)
    $toolInput = $Payload.tool_input
    if ($null -eq $toolInput) { return $false }
    $toolName = ""
    if ($Payload.PSObject.Properties["tool_name"]) { $toolName = ([string]$Payload.tool_name).ToLower() }

    $command = $null
    if ($toolInput.PSObject.Properties["command"]) { $command = [string]$toolInput.command }

    if ($toolName -eq "apply_patch" -or ($command -and $command.Contains("*** Begin Patch"))) {
        return Test-SecondApprovalPatchIncreases $command
    }

    if (@("bash", "shell", "exec_command", "exec") -contains $toolName -and $command) {
        if ($command.ToLower().Contains("tasks.md") -and [regex]::IsMatch($command, "Second Approval:\s*Approved")) {
            return $true
        }
        return $false
    }

    $filePath = [string]$toolInput.file_path
    if (-not (Test-TasksMd $filePath)) { return $false }

    if ($toolInput.PSObject.Properties["edits"] -and $null -ne $toolInput.edits) {
        foreach ($edit in $toolInput.edits) {
            if ((Get-SecondApprovalCount ([string]$edit.new_string)) -gt 0) {
                return $true
            }
        }
        return $false
    } elseif ($toolInput.PSObject.Properties["new_string"]) {
        return (Get-SecondApprovalCount ([string]$toolInput.new_string)) -gt 0
    } elseif ($toolInput.PSObject.Properties["content"]) {
        return Test-SecondApprovalWriteContentIncreases $filePath ([string]$toolInput.content)
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
    return [regex]::IsMatch($Cmd, $ShellSudoWriteRe, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
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

    # Check for transitions: Draft -> Approved or new Approved tasks.
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

if ([string]::IsNullOrWhiteSpace($raw)) { Emit-Decision "deny" $MalformedMsg }

try {
    $payload = $raw | ConvertFrom-Json
} catch {
    Emit-Decision "deny" $MalformedMsg
}

try {
    if ($null -eq $payload -or -not $payload.PSObject.Properties["tool_name"] -or -not ($payload.tool_name -is [string]) -or -not $payload.PSObject.Properties["tool_input"] -or $null -eq $payload.tool_input -or ($payload.tool_input -isnot [psobject] -and $payload.tool_input -isnot [System.Collections.IDictionary])) {
        Emit-Decision "deny" $MalformedMsg
    }
    if (Test-PayloadMalformed $payload) { Emit-Decision "deny" $MalformedMsg }

    $toolName = ""
    if ($payload.PSObject.Properties["tool_name"]) { $toolName = ([string]$payload.tool_name).ToLower() }
    $toolInput = $payload.tool_input
    $filePath = [string]$toolInput.file_path
    $command = $null
    if ($toolInput.PSObject.Properties["command"]) { $command = [string]$toolInput.command }

    # Check 2a: C-02 SDD_SUDO write/delete protection (never bypassed by sudo).
    # File tools: Edit, Write, MultiEdit targeting SDD_SUDO.
    if (@("edit", "write", "multiedit") -contains $toolName) {
        if (Test-TargetPathIsSddSudo $filePath) { Emit-Decision "deny" $SddSudoWriteMsg }
    }

    # Shell commands targeting SDD_SUDO.
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

    # Check 2a-R10: Enforcement-chain file protection (never bypassed by sudo).
    if (@("edit", "write", "multiedit") -contains $toolName) {
        if (Test-IsProtectedGateFile $filePath) { Emit-Decision "deny" $GateProtectMsg }
    }

    if (@("bash", "shell", "exec_command", "exec") -contains $toolName -and $command) {
        if (Test-ShellTargetsProtectedGateFile $command) { Emit-Decision "deny" $GateProtectMsg }
    }

    if ($toolName -eq "apply_patch" -or ($command -and $command.Contains("*** Begin Patch"))) {
        foreach ($line in ($command -split "`n")) {
            $m = [regex]::Match($line, "^\*\*\* (Update|Add|Delete) File: (.+)$")
            if ($m.Success) {
                if (Test-IsProtectedGateFile $m.Groups[2].Value.Trim()) { Emit-Decision "deny" $GateProtectMsg }
            }
        }
    }

    # Check 2b: Approval guard (bypassed by valid sudo).
    if ((Test-ApprovalIncreases $payload) -and -not (Test-SudoActive)) { Emit-Decision "deny" $ApprovalMsg }

    # Check 2b-2: Domain-model approval guard (bypassed by valid sudo, same
    # class as the tasks.md Approval guard above -- NOT the never-bypassable
    # WFI/Second-Approval pattern below).
    if ((Test-DomainModelApprovalIncreases $payload) -and -not (Test-SudoActive)) { Emit-Decision "deny" $DomainModelApprovalMsg }

    # Check 2c: WFI approval guard (NEVER bypassed by sudo).
    if (Test-WfiApprovalIncreases $payload) { Emit-Decision "deny" $WfiApprovalMsg }

    # Check 2d: Second Approval guard (NEVER bypassed by sudo).
    if (Test-SecondApprovalIncreases $payload) { Emit-Decision "deny" $SecondApprovalMsg }

    # Check 2e: Impl-Review-Status: Passed forgery guard (NEVER bypassed by sudo).
    if (Test-ImplReviewStatusPassedIncreases $payload) { Emit-Decision "deny" $ImplReviewStatusMsg }
} catch {
    Emit-Decision "deny" $ApprovalFailClosedMsg
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
    Emit-Decision "deny" $AgentRoleFailClosedMsg
}

Emit-Decision "allow" $null
