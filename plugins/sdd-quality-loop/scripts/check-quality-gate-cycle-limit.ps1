# check-quality-gate-cycle-limit.ps1 - deterministic quality-gate cycle limit.
# Issue #112 / REQ-003 / AC-006. PowerShell twin of
# check-quality-gate-cycle-limit.sh with identical behaviour. ASCII-only, no
# BOM (Windows PowerShell 5.1 parses BOM-less non-ASCII sources as ANSI).
#
# Contract (internal):
#   check-quality-gate-cycle-limit.ps1 <task-id> [reports-dir]
#     task-id     : must match ^T-[0-9]{3}$ (else usage error, exit 2)
#     reports-dir : directory of quality-gate reports (default reports/quality-gate)
#   Behaviour:
#     count = number of files under reports-dir whose CONTENT references the
#             task id with a WORD-BOUNDARY match (so T-001 does not match
#             T-0010, mirroring issue #111). An absent reports-dir counts 0.
#     count 0/1/2 -> print `continue`,       exit 0
#     count >= 3  -> print `Escalate-Human`, exit 1
param(
    [string]$TaskId,
    [string]$ReportsDir = "reports/quality-gate"
)
$ErrorActionPreference = "Stop"

# Validate the task id shape (case-sensitive, matching the .sh grep). An
# invalid id is a usage error (exit 2), never a silent zero count.
if ($TaskId -cnotmatch '^T-[0-9]{3}$') {
    [Console]::Error.WriteLine('usage: check-quality-gate-cycle-limit.ps1 <task-id> [reports-dir]')
    [Console]::Error.WriteLine('  task-id must match ^T-[0-9]{3}$ (e.g. T-001)')
    [Console]::Error.WriteLine('  reports-dir defaults to reports/quality-gate')
    exit 2
}

# Count gate reports whose CONTENT references this task id. The word-boundary
# regex "\b" + [regex]::Escape($TaskId) + "\b" mirrors check-task-state.ps1
# and is the PowerShell equivalent of the .sh "grep -w -F": it rejects T-0010
# when counting T-001. Match case-sensitively for parity with grep. An absent
# directory is zero reports (fresh checkout).
$count = 0
if (Test-Path -LiteralPath $ReportsDir -PathType Container) {
    $pattern = "\b" + [regex]::Escape($TaskId) + "\b"
    $count = @(Get-ChildItem -LiteralPath $ReportsDir -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { Select-String -LiteralPath $_.FullName -Pattern $pattern -CaseSensitive -Quiet }).Count
}

if ($count -ge 3) {
    Write-Output "Escalate-Human"
    exit 1
}

Write-Output "continue"
exit 0
