<#
PreToolUse hook (PowerShell twin of kill-switch.sh): suspend all tool use while
AGENT_STOP exists. A human creates AGENT_STOP at the project root to stop the
agent immediately and deletes it to resume. Exit 2 blocks the tool call.
Checks both CLAUDE_PROJECT_DIR (if set) and cwd, matching sdd-hook-guard.js semantics.
#>
$ErrorActionPreference = "Stop"

# C-08: walk parents up to git root checking for AGENT_STOP.
$bases = @()
$envRoot = $env:CLAUDE_PROJECT_DIR
if (-not [string]::IsNullOrEmpty($envRoot)) {
    $bases = @($envRoot, ".")
} else {
    # Walk up to 20 levels; check every directory up to and including git root.
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
        # Stop at the filesystem root: Split-Path -Parent "/" (POSIX) and
        # "C:\" (Windows) both return an empty string, which would otherwise
        # leave $current empty and make Join-Path throw under -ErrorAction Stop.
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }
        $current = $parent
    }
    if (-not $gitRootFound -and "." -notin $bases) {
        $bases += "."
    }
}

foreach ($base in $bases) {
    try {
        if (Test-Path -LiteralPath (Join-Path $base "AGENT_STOP") -PathType Leaf) {
            [Console]::Error.WriteLine("SDD kill switch: AGENT_STOP exists at the project root. All tool use is suspended until a human deletes the file.")
            exit 2
        }
    } catch { }
}
exit 0
