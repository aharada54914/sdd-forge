# Deterministic gate: verify a Default-FAIL verification contract.
# Usage: check-contract.ps1 <path-to-contract.json> [-RepoRoot <path>]
# Fails (exit 1) while any required check has passes=false, or any passing
# check has empty or missing evidence. quality-gate must run this before Done.
# Additional rules enforced:
#  - Duplicate check ids → fail, listing them.
#  - Evidence path safety → fail if absolute (POSIX, Windows drive, UNC) or
#    contains traversal that escapes the repo root.
#  - Waiver enforcement → required:false + passes:false must have non-empty
#    waiver_reason; otherwise operator must run the check or record why it
#    does not apply.
#  - Required-set protection → baseline ids (lint, typecheck, unit-tests, build,
#    placeholder-scan, task-state-check) must be present; if present but
#    required:false, waiver_reason must be non-empty.
param(
    [Parameter(Mandatory)][string]$ContractPath,
    [string]$RepoRoot = "."
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ContractPath)) {
    Write-Error "Contract file not found: $ContractPath"
    exit 1
}
$contract = Get-Content -Raw -Encoding Utf8 $ContractPath | ConvertFrom-Json
$failures = @()

$BASELINE_IDS = @("lint", "typecheck", "unit-tests", "build", "placeholder-scan", "task-state-check")

# Resolve repo root to an absolute path for traversal checks
$absRoot = (Resolve-Path $RepoRoot).Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar, '/')

# Pass 1: duplicate id detection
$seenIds = @{}
foreach ($check in $contract.checks) {
    $id = $check.id
    if ($seenIds.ContainsKey($id)) {
        $failures += "duplicate check id '$id'"
    } else {
        $seenIds[$id] = $true
    }
}

# Pass 2: per-check rules
foreach ($check in $contract.checks) {
    $id = $check.id

    # Type strictness: required and passes must be JSON boolean (not string, number, null)
    $required = $check.required
    if ($null -eq $required -or $required -isnot [bool]) {
        $failures += "check '$id' has invalid type for required: $($required.GetType().Name) (expected bool)"
        continue
    }

    $passes = $check.passes
    if ($null -eq $passes -or $passes -isnot [bool]) {
        $failures += "check '$id' has invalid type for passes: $($passes.GetType().Name) (expected bool)"
        continue
    }

    $evidence = ([string]($check.evidence)).Trim()
    $waiverReason = ([string]($check.waiver_reason)).Trim()

    # Waiver enforcement: required:false + passes:false needs waiver_reason
    if (-not $required -and -not $passes) {
        if ([string]::IsNullOrWhiteSpace($waiverReason)) {
            $failures += "check '$id' is optional and has passes=false but waiver_reason is empty; " +
                "either run the check or record why it does not apply in waiver_reason"
        }
    }

    if ($required -and -not $passes) {
        $failures += "required check '$id' has passes=false"
        continue
    }

    if ($passes) {
        if ([string]::IsNullOrWhiteSpace($evidence)) {
            $failures += "check '$id' passes without evidence"
            continue
        }

        # Evidence path safety: reject absolute POSIX paths
        if ($evidence.StartsWith("/")) {
            $failures += "check '$id' evidence is an absolute path: $evidence"
            continue
        }
        # Reject Windows drive paths (C:\...) and UNC (\\...)
        if (($evidence.Length -ge 2 -and $evidence[1] -eq ':') -or $evidence.StartsWith("\\")) {
            $failures += "check '$id' evidence is an absolute path: $evidence"
            continue
        }

        # Resolve and check for traversal outside root
        try {
            $joined = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($absRoot, $evidence))
        } catch {
            $failures += "check '$id' evidence path could not be resolved: $evidence"
            continue
        }
        $sep = [System.IO.Path]::DirectorySeparatorChar
        if (-not ($joined.StartsWith($absRoot + $sep) -or $joined -eq $absRoot)) {
            $failures += "check '$id' evidence path escapes repo root: $evidence"
            continue
        }

        # Evidence must exist, be a regular file (not directory), and have size > 0
        if (-not (Test-Path -LiteralPath $joined)) {
            $failures += "check '$id' evidence file missing: $evidence"
        } elseif ((Test-Path -LiteralPath $joined -PathType Container)) {
            $failures += "check '$id' evidence is not a regular file: $evidence"
        } else {
            $fileInfo = Get-Item -LiteralPath $joined -ErrorAction SilentlyContinue
            if ($fileInfo -and $fileInfo.Length -eq 0) {
                $failures += "check '$id' evidence file is empty: $evidence"
            }
        }
    }
}

# Pass 3: required-set protection
$presentIds = $contract.checks | ForEach-Object { $_.id }
foreach ($bid in $BASELINE_IDS) {
    if ($bid -notin $presentIds) {
        $failures += "check removed from contract: '$bid' is a required baseline check id"
        continue
    }
    $check = $contract.checks | Where-Object { $_.id -eq $bid } | Select-Object -First 1
    if (-not [bool]$check.required) {
        $waiver = ([string]($check.waiver_reason)).Trim()
        if ([string]::IsNullOrWhiteSpace($waiver)) {
            $failures += "baseline check '$bid' is downgraded to required:false without waiver_reason; " +
                "downgrading a baseline check requires justification recorded in the quality-gate report " +
                "(set a non-empty waiver_reason)"
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
