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

# Risk tier required-id sets (source: plugins/sdd-quality-loop/references/risk-gate-matrix.md)
$RISK_TIERS = @{
    "low"      = @("lint", "typecheck", "build", "placeholder-scan", "task-state-check")
    "medium"   = @("lint", "typecheck", "build", "placeholder-scan", "task-state-check", "unit-tests", "acceptance-tests", "regression")
    "high"     = @("lint", "typecheck", "build", "placeholder-scan", "task-state-check", "unit-tests", "acceptance-tests", "regression", "requirement-traceability")
    "critical" = @("lint", "typecheck", "build", "placeholder-scan", "task-state-check", "unit-tests", "acceptance-tests", "regression", "requirement-traceability")
}

# Stack descriptor (source: risk-gate-matrix.md). Compile-oriented checks are
# toolchain-dependent: on a non-code stack (shell/docs/spec) they may be waived
# (required:false + waiver_reason, enforced by Pass 2/3) instead of forced to
# required:true. Test/trace/placeholder/task-state checks are NEVER waivable this
# way. Absent/empty stack == "code" == legacy behavior (fully backward compatible).
$COMPILE_CHECKS = @("lint", "typecheck", "build")
$KNOWN_STACKS = @("code", "shell", "docs", "spec")
$NONCODE_STACKS = @("shell", "docs", "spec")

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

# Pass 4: risk-tier enforcement (source: plugins/sdd-quality-loop/references/risk-gate-matrix.md)
$risk = ([string]($contract.risk)).Trim()
$stack = ([string]($contract.stack)).Trim()
if (-not $stack) { $stack = "code" }  # absent/empty == code (legacy)
if ($risk) {  # LEGACY mode: if risk is absent or empty string, skip this pass
    # Validate stack value; unknown -> fail and fall back to strictest (code).
    if ($stack -notin $KNOWN_STACKS) {
        $failures += "contract stack is invalid: $stack"
        $stack = "code"
    }
    # Validate risk tier value
    if ($risk -notin $RISK_TIERS.Keys) {
        $failures += "contract risk is invalid: $risk"
    } else {
        # Enforce tier's required-id set
        $requiredIds = $RISK_TIERS[$risk]
        $presentIdSet = $contract.checks | ForEach-Object { $_.id }
        $compileWaivable = ($stack -in $NONCODE_STACKS)

        foreach ($reqId in ($requiredIds | Sort-Object)) {
            if ($reqId -notin $presentIdSet) {
                $failures += "risk $risk requires check '$reqId' present and required:true (missing)"
            } else {
                # Find the check and verify required:true
                $check = $contract.checks | Where-Object { $_.id -eq $reqId } | Select-Object -First 1
                if (-not [bool]$check.required) {
                    # Non-code stack: compile-oriented checks are waivable (required:false).
                    # The waiver_reason itself is enforced by Pass 2/3. Everything else stays mandatory.
                    if ($compileWaivable -and ($reqId -in $COMPILE_CHECKS)) {
                        # accepted as N/A for this stack
                    } else {
                        $failures += "risk $risk requires check '$reqId' to be required:true"
                    }
                }
            }
        }
    }
}

# Pass 5: Red→Green evidence enforcement (only when required_workflow == "tdd")
$requiredWorkflow = ([string]($contract.required_workflow)).Trim()
if ($requiredWorkflow -eq "tdd") {
    # TDD test-check ids that require red_evidence and green_evidence when required=true
    $tddTestIds = @("unit-tests", "acceptance-tests")

    foreach ($check in $contract.checks) {
        $id = $check.id
        $required = $check.required

        # Only enforce red/green for test-type checks that are required:true
        if ($id -in $tddTestIds -and $required) {
            $redEvidence = ([string]($check.red_evidence)).Trim()
            $greenEvidence = ([string]($check.green_evidence)).Trim()

            # Rule 2a: must not be empty/missing
            if ([string]::IsNullOrWhiteSpace($redEvidence)) {
                $failures += "check '$id' required_workflow tdd needs non-empty red_evidence"
                continue
            }
            if ([string]::IsNullOrWhiteSpace($greenEvidence)) {
                $failures += "check '$id' required_workflow tdd needs non-empty green_evidence"
                continue
            }

            # Rule 2b: validate red_evidence path (same as evidence in Pass 2)
            # Reject absolute POSIX paths
            if ($redEvidence.StartsWith("/")) {
                $failures += "check '$id' red_evidence is an absolute path: $redEvidence"
                continue
            }
            # Reject Windows drive paths and UNC
            if (($redEvidence.Length -ge 2 -and $redEvidence[1] -eq ':') -or $redEvidence.StartsWith("\\")) {
                $failures += "check '$id' red_evidence is an absolute path: $redEvidence"
                continue
            }

            # Check for traversal outside root
            try {
                $joinedRed = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($absRoot, $redEvidence))
            } catch {
                $failures += "check '$id' red_evidence path could not be resolved: $redEvidence"
                continue
            }
            $sep = [System.IO.Path]::DirectorySeparatorChar
            if (-not ($joinedRed.StartsWith($absRoot + $sep) -or $joinedRed -eq $absRoot)) {
                $failures += "check '$id' red_evidence path escapes repo root: $redEvidence"
                continue
            }

            # File must exist, be regular file (not directory), and have size > 0
            if (-not (Test-Path -LiteralPath $joinedRed)) {
                $failures += "check '$id' red_evidence file missing: $redEvidence"
            } elseif ((Test-Path -LiteralPath $joinedRed -PathType Container)) {
                $failures += "check '$id' red_evidence is not a regular file: $redEvidence"
            } else {
                $fileInfo = Get-Item -LiteralPath $joinedRed -ErrorAction SilentlyContinue
                if ($fileInfo -and $fileInfo.Length -eq 0) {
                    $failures += "check '$id' red_evidence file is empty: $redEvidence"
                }
            }

            # Rule 2b: validate green_evidence path (same as evidence in Pass 2)
            # Reject absolute POSIX paths
            if ($greenEvidence.StartsWith("/")) {
                $failures += "check '$id' green_evidence is an absolute path: $greenEvidence"
                continue
            }
            # Reject Windows drive paths and UNC
            if (($greenEvidence.Length -ge 2 -and $greenEvidence[1] -eq ':') -or $greenEvidence.StartsWith("\\")) {
                $failures += "check '$id' green_evidence is an absolute path: $greenEvidence"
                continue
            }

            # Check for traversal outside root
            try {
                $joinedGreen = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($absRoot, $greenEvidence))
            } catch {
                $failures += "check '$id' green_evidence path could not be resolved: $greenEvidence"
                continue
            }
            if (-not ($joinedGreen.StartsWith($absRoot + $sep) -or $joinedGreen -eq $absRoot)) {
                $failures += "check '$id' green_evidence path escapes repo root: $greenEvidence"
                continue
            }

            # File must exist, be regular file (not directory), and have size > 0
            if (-not (Test-Path -LiteralPath $joinedGreen)) {
                $failures += "check '$id' green_evidence file missing: $greenEvidence"
            } elseif ((Test-Path -LiteralPath $joinedGreen -PathType Container)) {
                $failures += "check '$id' green_evidence is not a regular file: $greenEvidence"
            } else {
                $fileInfo = Get-Item -LiteralPath $joinedGreen -ErrorAction SilentlyContinue
                if ($fileInfo -and $fileInfo.Length -eq 0) {
                    $failures += "check '$id' green_evidence file is empty: $greenEvidence"
                }
            }
        }
    }
}

# Pass 5b: Risk→Workflow consistency (only when BOTH risk AND required_workflow are present)
if ($risk -and $requiredWorkflow) {  # Enforce only if both fields are present and non-empty
    if ($risk -in @("high", "critical")) {
        if ($requiredWorkflow -ne "tdd") {
            $failures += "risk $risk requires required_workflow: tdd (got '$requiredWorkflow')"
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
