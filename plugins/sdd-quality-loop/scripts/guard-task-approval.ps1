# PreToolUse hook guard (canonical implementation).
# Blocks any Edit/Write/MultiEdit that increases the number of
# "Approval: Approved" lines in a tasks.md file. Only a human may approve.
# Reads the Claude Code hook JSON payload from stdin. Exit 2 = block.
$ErrorActionPreference = "Stop"

function Get-ApprovedCount {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    return ([regex]::Matches($Text, "Approval:\s*Approved")).Count
}

try {
    $raw = [Console]::In.ReadToEnd()
    $payload = $raw | ConvertFrom-Json
} catch {
    # Unparseable payload: do not block, but leave a trace.
    [Console]::Error.WriteLine("guard-task-approval: could not parse hook payload; skipping check.")
    exit 0
}

$toolInput = $payload.tool_input
if ($null -eq $toolInput) { exit 0 }

$filePath = [string]$toolInput.file_path
if (-not $filePath -or $filePath -notmatch "tasks\.md$") { exit 0 }

$oldCount = 0
$newCount = 0

if ($null -ne $toolInput.PSObject.Properties["edits"]) {
    foreach ($edit in $toolInput.edits) {
        $oldCount += Get-ApprovedCount ([string]$edit.old_string)
        $newCount += Get-ApprovedCount ([string]$edit.new_string)
    }
} elseif ($null -ne $toolInput.PSObject.Properties["new_string"]) {
    $oldCount = Get-ApprovedCount ([string]$toolInput.old_string)
    $newCount = Get-ApprovedCount ([string]$toolInput.new_string)
} elseif ($null -ne $toolInput.PSObject.Properties["content"]) {
    # Write tool: compare against the file currently on disk.
    if (Test-Path $filePath) {
        $oldCount = Get-ApprovedCount (Get-Content -Raw -Encoding Utf8 $filePath)
    }
    $newCount = Get-ApprovedCount ([string]$toolInput.content)
} else {
    exit 0
}

if ($newCount -gt $oldCount) {
    [Console]::Error.WriteLine(
        "SDD deterministic gate: agents must not set 'Approval: Approved' in tasks.md. " +
        "Only a human may approve a task by editing the file directly. " +
        "Leave the task as Draft and ask the human to approve it.")
    exit 2
}
exit 0
