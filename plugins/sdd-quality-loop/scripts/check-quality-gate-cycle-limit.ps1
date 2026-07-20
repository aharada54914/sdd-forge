# check-quality-gate-cycle-limit.ps1 - deterministic quality-gate cycle
# limit, scoped to the current feature. PowerShell twin of
# check-quality-gate-cycle-limit.sh with identical behaviour. ASCII-only, no
# BOM (Windows PowerShell 5.1 parses BOM-less non-ASCII sources as ANSI).
#
# Contract (internal):
#   check-quality-gate-cycle-limit.ps1 <task-id> <feature> [reports-dir]
#     task-id     : must match ^T-[0-9]{3}$ (else usage error, exit 2)
#     feature     : REQUIRED. Must match ^[a-z0-9][a-z0-9-]*$ (else usage
#                   error, exit 2)
#     reports-dir : directory of quality-gate reports (default reports/quality-gate)
#   Behaviour:
#     count = number of files under reports-dir whose CONTENT references the
#             task id with a WORD-BOUNDARY match (so T-001 does not match
#             T-0010, mirroring issue #111) AND whose OWN content carries an
#             anchored `Feature:` header line naming THIS feature
#             ((?m)^Feature:\s*<feature>\s*$ -- mirrors
#             emit-run-record.ps1's own already-landed anchor). A report
#             carrying the task id under a DIFFERENT feature's Feature:
#             line is never counted (issue #167 / RT-20260712-001). An
#             absent reports-dir counts 0.
#     count 0/1/2 -> print `continue`,       exit 0
#     count >= 3  -> print `Escalate-Human`, exit 1
param(
    [string]$TaskId,
    [string]$Feature,
    [string]$ReportsDir = "reports/quality-gate"
)
$ErrorActionPreference = "Stop"

# Validate the task id shape (case-sensitive, matching the .sh grep). An
# invalid id is a usage error (exit 2), never a silent zero count.
if ($TaskId -cnotmatch '^T-[0-9]{3}$') {
    [Console]::Error.WriteLine('usage: check-quality-gate-cycle-limit.ps1 <task-id> <feature> [reports-dir]')
    [Console]::Error.WriteLine('  task-id must match ^T-[0-9]{3}$ (e.g. T-001)')
    [Console]::Error.WriteLine('  feature must match ^[a-z0-9][a-z0-9-]*$ (e.g. epic-159-pillar-d)')
    [Console]::Error.WriteLine('  reports-dir defaults to reports/quality-gate')
    exit 2
}

# Validate the feature slug shape (case-sensitive); a missing (empty) or
# malformed feature is a usage error too -- feature is a REQUIRED second
# positional (AC-001).
if ($Feature -cnotmatch '^[a-z0-9][a-z0-9-]*$') {
    [Console]::Error.WriteLine('usage: check-quality-gate-cycle-limit.ps1 <task-id> <feature> [reports-dir]')
    [Console]::Error.WriteLine('  task-id must match ^T-[0-9]{3}$ (e.g. T-001)')
    [Console]::Error.WriteLine('  feature must match ^[a-z0-9][a-z0-9-]*$ (e.g. epic-159-pillar-d)')
    [Console]::Error.WriteLine('  reports-dir defaults to reports/quality-gate')
    exit 2
}

# Count gate reports whose CONTENT references this task id AND whose own
# Feature: header line names this feature. The word-boundary regex "\b" +
# [regex]::Escape($TaskId) + "\b" mirrors check-task-state.ps1 and is the
# PowerShell equivalent of the .sh "grep -w -F": it rejects T-0010 when
# counting T-001 (BL-001). The Feature: predicate is applied SECOND, on the
# SAME file, using [regex]::Escape($Feature) and the (?m)^...\s*$ anchor
# shape emit-run-record.ps1 already establishes for its own Feature: read,
# so a different feature's report sharing the same bare task id is never
# counted (issue #167 / RT-20260712-001). Match case-sensitively for parity
# with grep. An absent directory is zero reports (fresh checkout).
$count = 0
if (Test-Path -LiteralPath $ReportsDir -PathType Container) {
    $taskPattern = "\b" + [regex]::Escape($TaskId) + "\b"
    $featurePattern = "(?m)^Feature:\s*" + [regex]::Escape($Feature) + "\s*$"
    $taskMatches = @(Get-ChildItem -LiteralPath $ReportsDir -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { Select-String -LiteralPath $_.FullName -Pattern $taskPattern -CaseSensitive -Quiet })
    $count = @($taskMatches | Where-Object {
        (Get-Content -Raw -Encoding Utf8 -LiteralPath $_.FullName) -match $featurePattern
    }).Count
}

if ($count -ge 3) {
    Write-Output "Escalate-Human"
    exit 1
}

Write-Output "continue"
exit 0
