# Deterministic gate: verify a Default-FAIL verification contract.
# Usage: check-contract.ps1 <path-to-contract.json> [-RepoRoot <path>]
# Fails (exit 1) while any required check has passes=false, or any passing
# check has empty or missing evidence. quality-gate must run this before Done.
param(
    [Parameter(Mandatory)][string]$ContractPath,
    [string]$RepoRoot = "."
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path $ContractPath)) {
    Write-Error "Contract file not found: $ContractPath"
    exit 1
}
$contract = Get-Content -Raw -Encoding Utf8 $ContractPath | ConvertFrom-Json
$failures = @()

foreach ($check in $contract.checks) {
    $id = $check.id
    if ($check.required -and -not $check.passes) {
        $failures += "required check '$id' has passes=false"
        continue
    }
    if ($check.passes) {
        if ([string]::IsNullOrWhiteSpace([string]$check.evidence)) {
            $failures += "check '$id' passes without evidence"
        } elseif (-not (Test-Path (Join-Path $RepoRoot $check.evidence))) {
            $failures += "check '$id' evidence file missing: $($check.evidence)"
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Verification contract FAILED for task $($contract.task_id):"
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}
Write-Host "Verification contract passed for task $($contract.task_id)."
exit 0
