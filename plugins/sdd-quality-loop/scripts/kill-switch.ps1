<#
PreToolUse hook (PowerShell twin of kill-switch.sh): suspend all tool use while
AGENT_STOP exists. A human creates AGENT_STOP at the project root to stop the
agent immediately and deletes it to resume. Exit 2 blocks the tool call.
#>
$ErrorActionPreference = "Stop"

$root = $env:CLAUDE_PROJECT_DIR
if ([string]::IsNullOrEmpty($root)) { $root = "." }

if (Test-Path -LiteralPath (Join-Path $root "AGENT_STOP") -PathType Leaf) {
    [Console]::Error.WriteLine("SDD kill switch: AGENT_STOP exists at the project root. All tool use is suspended until a human deletes the file.")
    exit 2
}
exit 0
