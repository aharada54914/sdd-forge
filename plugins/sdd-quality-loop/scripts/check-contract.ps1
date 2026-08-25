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
$contractRaw = Get-Content -Raw -Encoding Utf8 $ContractPath
$contract = $contractRaw | ConvertFrom-Json

# gate seq 854: DateTimeKind is not a sound proxy for the python master's
# pattern. ConvertFrom-Json maps a LOWERCASE `z` to Kind=Utc, so
# `2026-08-24T10:00:00z` was accepted on this runtime and rejected by
# check-contract.py -- and any string the coercion cannot parse at all
# (`2026-13-01T00:00:00Z`) never reached the Kind branch in the first place.
# System.Text.Json does not coerce, so the RAW text is recoverable here and the
# master's regex can be applied byte-for-byte on both runtimes. (TryGetProperty
# cannot be called from PowerShell -- JsonElement is a struct and its `out`
# parameter will not bind -- hence the enumeration.)
function Get-RawCheckTimestamp {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Json,
        [Parameter(Mandatory = $true)][int]$Index,
        [Parameter(Mandatory = $true)][string]$Field
    )
    $absent = @{ Present = $false; IsString = $false; Text = '' }
    try {
        $document = [System.Text.Json.JsonDocument]::Parse($Json)
    } catch {
        return $absent
    }
    try {
        $checks = $null
        foreach ($property in $document.RootElement.EnumerateObject()) {
            if ($property.Name -ceq 'checks') { $checks = $property.Value }
        }
        if ($null -eq $checks -or
            $checks.ValueKind -ne [System.Text.Json.JsonValueKind]::Array -or
            $Index -ge $checks.GetArrayLength()) {
            return $absent
        }
        foreach ($property in $checks[$Index].EnumerateObject()) {
            if ($property.Name -ceq $Field) {
                # JSON null is ABSENT, not "present but wrong": the field is
                # optional and the template ships it as null.
                if ($property.Value.ValueKind -eq [System.Text.Json.JsonValueKind]::Null) {
                    return $absent
                }
                if ($property.Value.ValueKind -ne [System.Text.Json.JsonValueKind]::String) {
                    return @{ Present = $true; IsString = $false; Text = '' }
                }
                return @{ Present = $true; IsString = $true; Text = $property.Value.GetString() }
            }
        }
        return $absent
    } finally {
        $document.Dispose()
    }
}
$failures = @()

$BASELINE_IDS = @("lint", "typecheck", "unit-tests", "build", "placeholder-scan", "task-state-check")

# Risk tier required-id sets (source: plugins/sdd-quality-loop/references/risk-gate-matrix.md)
$RISK_TIERS = @{
    "low"      = @("lint", "typecheck", "build", "placeholder-scan", "task-state-check")
    "medium"   = @("lint", "typecheck", "build", "placeholder-scan", "task-state-check", "unit-tests", "acceptance-tests", "regression")
    "high"     = @("lint", "typecheck", "build", "placeholder-scan", "task-state-check", "unit-tests", "acceptance-tests", "regression", "requirement-traceability", "check-component-coverage")
    "critical" = @("lint", "typecheck", "build", "placeholder-scan", "task-state-check", "unit-tests", "acceptance-tests", "regression", "requirement-traceability", "check-component-coverage")
}

# Stack descriptor (source: risk-gate-matrix.md). Compile-oriented checks are
# toolchain-dependent: on a non-code stack (shell/docs/spec) they may be waived
# (required:false + waiver_reason, enforced by Pass 2/3) instead of forced to
# required:true. Test/trace/placeholder/task-state checks are NEVER waivable this
# way. Absent/empty stack == "code" == legacy behavior (fully backward compatible).
$COMPILE_CHECKS = @("lint", "typecheck", "build")
$KNOWN_STACKS = @("code", "shell", "docs", "spec")
$NONCODE_STACKS = @("shell", "docs", "spec")

# epic-191-a3-path-ownership T-004 (REQ-004, AC-055, INV-017/INV-018): the
# check-component-coverage evidence producer-digest is independently
# recomputed over this literal sibling file, never trusted from the
# evidence record itself.
$PRODUCER_DIGEST_CHECK_ID = "check-component-coverage"
$PRODUCER_DIGEST_SCRIPT_NAME = "check-component-coverage.py"

# epic-191-a3-path-ownership T-004 follow-up (REQ-004, INV-018): tier-minimum
# ids that are only required once the project has declared a capability-
# enforcement posture at all.
#
# check-component-coverage derives one of three states from
# `workflow.capability_enforcement` in sdd/project-context.yaml (ADR-0016 §4).
# In `disabled-legacy` -- which Get-DerivedState returns when that file is
# ABSENT -- the gate evaluates zero Fail conditions, consults no Facet
# Manifest, and exits 0 unconditionally: it is structurally incapable of
# asserting anything. Requiring it in the tier minimum while it is inert
# demands a `passes:true` entry for a check that can never say anything but
# "not-applicable", which is exactly the fabricated-pass footgun
# requirements.md warns about. So the REQUIREMENT is gated on the same
# project state the GATE itself reads, and activates precisely when the gate
# becomes capable of asserting something.
#
# The predicate is file PRESENCE, not a re-derivation of the three-way state,
# and that is deliberate:
#   * contracts/project-context.schema.json makes `capability_enforcement`
#     REQUIRED with enum ["advisory","required"], so every schema-conformant
#     config yields advisory|required -- never disabled-legacy. Presence is
#     therefore EXACTLY equivalent to `Get-DerivedState -ne "disabled-legacy"`
#     for any conformant config.
#   * The only divergence is a malformed/non-conformant config, where this
#     predicate still REQUIRES the check (fail-closed). Get-DerivedState
#     either throws (present-but-unparseable) or returns disabled-legacy
#     (parses but lacks the field); over-requiring there is the safe
#     direction.
#   * It duplicates no YAML parsing into this file -- notably it avoids
#     dot-sourcing resolve-component-paths.ps1 purely to reach
#     ConvertFrom-MinimalYaml. A parser that threw and was caught would
#     silently conclude "disabled-legacy", turning the tier minimum OFF
#     permanently and undetectably. This predicate has no such failure mode:
#     the only way it reads "inactive" is the file genuinely not existing,
#     which is the intended inactive condition.
#
# Kept byte-for-byte in step with check-contract.py's PROJECT_CONTEXT_REL_PATH
# / CAPABILITY_STATE_GATED_IDS.
$PROJECT_CONTEXT_REL_PATH = "sdd/project-context.yaml"
$CAPABILITY_STATE_GATED_IDS = @("check-component-coverage")

# Resolve repo root to an absolute path for traversal checks
$absRoot = (Resolve-Path $RepoRoot).Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar, '/')

function Test-CapabilityEnforcementDeclared {
    # True iff this project declares a capability-enforcement posture, i.e.
    # sdd/project-context.yaml exists relative to the repo root. Mirrors the
    # file-absence branch of check-component-coverage.ps1's Get-DerivedState.
    #
    # The relative path is joined segment-by-segment from the shared constant
    # rather than passed to Join-Path whole, so the separator is the host's
    # own on every platform. Join-Path is called one segment at a time because
    # its multi-argument form is PowerShell 6+ only and this repository's
    # scripts must also run under Windows PowerShell 5.1.
    param([Parameter(Mandatory)][string]$Root)
    $p = $Root
    foreach ($seg in ($PROJECT_CONTEXT_REL_PATH -split '/')) { $p = Join-Path $p $seg }
    return (Test-Path -LiteralPath $p -PathType Leaf)
}

function Test-PathContainsReparsePoint {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$TrustedRoot
    )

    # The runner's parent directories may themselves be symlinks (notably
    # macOS /var and hosted workspace mounts). They are outside the trust
    # boundary; inspect only components introduced below the trusted repo
    # root. This keeps the guard fail-closed for in-repo junctions/symlinks
    # without rejecting a legitimate symlinked workspace location.
    $rootFull = [System.IO.Path]::GetFullPath($TrustedRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar, '/')
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    $separator = [System.IO.Path]::DirectorySeparatorChar
    if (-not ($pathFull.StartsWith($rootFull + $separator) -or $pathFull -eq $rootFull)) {
        return $false
    }

    $current = $rootFull
    $relativePath = $pathFull.Substring($rootFull.Length)
    foreach ($component in ($relativePath -split '[\\/]+')) {
        if ([string]::IsNullOrEmpty($component)) {
            continue
        }

        $current = [System.IO.Path]::Combine($current, $component)
        try {
            $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
        } catch {
            # Preserve the existing missing-file diagnostic when traversal
            # reaches a component that does not exist.
            return $false
        }

        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            return $true
        }
    }
    return $false
}

function Test-EvidencePath {
    param(
        [Parameter(Mandatory)][string]$FieldName,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Evidence,
        [Parameter(Mandatory)][string]$RepoRoot
    )

    # Keep the three original validation orders and diagnostic fragments in one
    # place. StopsCurrentCheck preserves the existing red-evidence behavior:
    # malformed/escaping paths skip green validation, while missing, directory,
    # and empty paths still let the caller collect a green-evidence failure.
    $result = [ordered]@{
        IsValid = $false
        ResolvedPath = $null
        Failure = ""
        StopsCurrentCheck = $false
    }

    if ($Evidence.StartsWith("/")) {
        $result.Failure = "$FieldName is an absolute path: $Evidence"
        $result.StopsCurrentCheck = $true
        return [pscustomobject]$result
    }
    if (($Evidence.Length -ge 2 -and $Evidence[1] -eq ':') -or $Evidence.StartsWith("\\")) {
        $result.Failure = "$FieldName is an absolute path: $Evidence"
        $result.StopsCurrentCheck = $true
        return [pscustomobject]$result
    }

    try {
        $joined = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($RepoRoot, $Evidence))
    } catch {
        $result.Failure = "$FieldName path could not be resolved: $Evidence"
        $result.StopsCurrentCheck = $true
        return [pscustomobject]$result
    }
    $sep = [System.IO.Path]::DirectorySeparatorChar
    if (-not ($joined.StartsWith($RepoRoot + $sep) -or $joined -eq $RepoRoot)) {
        $result.Failure = "$FieldName path escapes repo root: $Evidence"
        $result.StopsCurrentCheck = $true
        return [pscustomobject]$result
    }
    if (Test-PathContainsReparsePoint -Path $joined -TrustedRoot $RepoRoot) {
        $result.Failure = "$FieldName path contains a reparse point: $Evidence"
        $result.StopsCurrentCheck = $true
        return [pscustomobject]$result
    }
    $result.ResolvedPath = $joined
    if (-not (Test-Path -LiteralPath $joined)) {
        $result.Failure = "$FieldName file missing: $Evidence"
    } elseif ((Test-Path -LiteralPath $joined -PathType Container)) {
        $result.Failure = "$FieldName is not a regular file: $Evidence"
    } else {
        $fileInfo = Get-Item -LiteralPath $joined -ErrorAction SilentlyContinue
        if ($fileInfo -and $fileInfo.Length -eq 0) {
            $result.Failure = "$FieldName file is empty: $Evidence"
        } else {
            $result.IsValid = $true
        }
    }
    return [pscustomobject]$result
}

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
$checkIndex = -1
foreach ($check in $contract.checks) {
    # Incremented FIRST: the body has `continue` paths, and the index must stay
    # aligned with the raw JSON array however the body exits.
    $checkIndex++
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

    # Per-check execution record (design.md section 2, WFI-046). Optional --
    # absent or null is valid -- but format-checked when present, with wording
    # byte-identical to the python twin. This twin is an independent
    # implementation, not a delegate, so the rule has to be written here too;
    # shipping it on one runtime only is what gate seq 849 charged.
    $checkProps = $check.PSObject.Properties.Name
    $commandValue = $null
    if ($checkProps -contains 'command') { $commandValue = $check.command }
    if ($null -ne $commandValue) {
        if ($commandValue -isnot [string] -or [string]::IsNullOrWhiteSpace($commandValue)) {
            $failures += "check '$id' has invalid command: expected a non-empty string"
        }
    }
    $exitCodeValue = $null
    if ($checkProps -contains 'exit_code') { $exitCodeValue = $check.exit_code }
    if ($null -ne $exitCodeValue) {
        if ($exitCodeValue -is [bool] -or
            -not ($exitCodeValue -is [int] -or $exitCodeValue -is [long])) {
            $failures += "check '$id' has invalid exit_code: expected an integer"
        }
    }
    foreach ($tsField in @('started_at', 'finished_at')) {
        # Read the RAW text, not the coerced value: the master accepts exactly
        # `YYYY-MM-DDTHH:MM:SS[.fff]Z` with an UPPERCASE Z, and no property of
        # the [datetime] this field becomes can tell `Z` from `z`.
        $tsRaw = Get-RawCheckTimestamp -Json $contractRaw -Index $checkIndex -Field $tsField
        if (-not $tsRaw.Present) { continue }
        if (-not $tsRaw.IsString -or
            $tsRaw.Text -cnotmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?Z$') {
            $failures += "check '$id' has invalid ${tsField}: expected ISO-8601 UTC " +
                "(YYYY-MM-DDTHH:MM:SSZ)"
        }
    }

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

        $evidenceResult = Test-EvidencePath -FieldName "evidence" -Evidence $evidence -RepoRoot $absRoot
        if (-not $evidenceResult.IsValid) {
            $failures += "check '$id' $($evidenceResult.Failure)"
            continue
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

# RT-20260821-007: non-string scalar fields must fail closed with a proper
# diagnostic (a JSON array risk was silently string-coerced here while the
# python twin crashed). Parity with the python twin's early return.
$nonStringFields = @()
foreach ($scalarField in @('risk', 'stack', 'required_workflow', 'spec_revision', 'cross_model')) {
    $scalarProp = $contract.PSObject.Properties[$scalarField]
    if ($scalarProp -and $null -ne $scalarProp.Value -and $scalarProp.Value -isnot [string]) {
        $nonStringFields += $scalarField
    }
}
if ($nonStringFields.Count -gt 0) {
    foreach ($scalarField in $nonStringFields) {
        $failures += "contract $scalarField must be a string"
    }
    Write-Output "Verification contract FAILED for task $($contract.task_id):"
    $failures | ForEach-Object { Write-Output " - $_" }
    exit 1
}

# RT-20260821-005(c): contract schema versioning (parity with the python
# twin). Absent schema = v1 legacy, behavior unchanged; a declared schema
# must be a recognized version.
$contractSchema = ([string]($contract.schema)).Trim()
if ($contractSchema -and $contractSchema -cne 'verification-contract/v2') {
    Write-Output "Verification contract FAILED for task $($contract.task_id):"
    Write-Output " - contract schema is unrecognized: $contractSchema"
    exit 1
}

# Pass 4: risk-tier enforcement (source: plugins/sdd-quality-loop/references/risk-gate-matrix.md)
$risk = ([string]($contract.risk)).Trim()
$stack = ([string]($contract.stack)).Trim()
if (-not $stack) { $stack = "code" }  # absent/empty == code (legacy)
if ($risk) {  # LEGACY mode: if risk is absent or empty string, skip this pass
    # Validate stack value; unknown -> fail and fall back to strictest (code).
    if ($stack -cnotin $KNOWN_STACKS) {
        $failures += "contract stack is invalid: $stack"
        $stack = "code"
    }
    # Validate risk tier value
    if ($risk -cnotin @($RISK_TIERS.Keys)) {
        $failures += "contract risk is invalid: $risk"
    } else {
        # Enforce tier's required-id set. Capability-state-gated ids drop out
        # while the project declares no capability-enforcement posture, so the
        # requirement activates exactly when the corresponding gate stops
        # being inert (see $CAPABILITY_STATE_GATED_IDS).
        # RT-20260821-005(c) / AC-005 contract side (see the python twin's
        # rationale comment): v2 high/critical requires a well-formed
        # spec_revision; v1/absent-schema contracts are exempt.
        if ($contractSchema -ceq 'verification-contract/v2' -and ($risk -cin @('high', 'critical'))) {
            $specRevision = ([string]($contract.spec_revision)).Trim()
            $srOk = ($specRevision.Length -eq 40 -or $specRevision.Length -eq 64) -and
                    ($specRevision -cmatch '\A[0-9a-f]+\z')
            if (-not $srOk) {
                $failures += "risk $risk requires a well-formed spec_revision (40- or 64-hex lowercase) under verification-contract/v2"
            }
        }

        $requiredIds = $RISK_TIERS[$risk]
        if (-not (Test-CapabilityEnforcementDeclared -Root $absRoot)) {
            $requiredIds = @($requiredIds | Where-Object { $CAPABILITY_STATE_GATED_IDS -notcontains $_ })
        }
        $presentIdSet = $contract.checks | ForEach-Object { $_.id }
        $compileWaivable = ($stack -cin $NONCODE_STACKS)

        foreach ($reqId in ($requiredIds | Sort-Object)) {
            if ($reqId -cnotin $presentIdSet) {
                $failures += "risk $risk requires check '$reqId' present and required:true (missing)"
            } else {
                # Find the check and verify required:true
                $check = $contract.checks | Where-Object { $_.id -ceq $reqId } | Select-Object -First 1
                if (-not [bool]$check.required) {
                    # Non-code stack: compile-oriented checks are waivable (required:false).
                    # The waiver_reason itself is enforced by Pass 2/3. Everything else stays mandatory.
                    if ($compileWaivable -and ($reqId -cin $COMPILE_CHECKS)) {
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
if ($requiredWorkflow -ceq "tdd") {
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

            $redResult = Test-EvidencePath -FieldName "red_evidence" -Evidence $redEvidence -RepoRoot $absRoot
            if (-not $redResult.IsValid) {
                $failures += "check '$id' $($redResult.Failure)"
                if ($redResult.StopsCurrentCheck) {
                    continue
                }
            }

            $greenResult = Test-EvidencePath -FieldName "green_evidence" -Evidence $greenEvidence -RepoRoot $absRoot
            if (-not $greenResult.IsValid) {
                $failures += "check '$id' $($greenResult.Failure)"
            }
        }
    }
}

# Pass 5b: Risk→Workflow consistency. RT-20260821-003: an absent, empty, or
# whitespace required_workflow used to disable BOTH this pass and Pass 5, so
# one omitted field silently dropped the Red→Green obligation at
# high/critical tier. The field is now mandatory whenever the tier demands a
# workflow (parity with the python twin).
if ($risk -cin @("high", "critical")) {
    if (-not $requiredWorkflow) {
        $failures += "risk $risk requires required_workflow: tdd (field missing or empty)"
    } elseif ($requiredWorkflow -cne "tdd") {
        $failures += "risk $risk requires required_workflow: tdd (got '$requiredWorkflow')"
    }
}

# Pass 6: cross-model verification descriptor (conditional control, like signature/two-person).
# Enforced ONLY when the contract opts in via `cross_model`. Absent/empty/"legacy" =>
# no enforcement (backward compatible). NOT part of the machine-form RISK_TIERS set.
$crossModel = ([string]($contract.cross_model)).Trim()
if ($crossModel -and $crossModel -ne "legacy") {
    if ($crossModel -notin @("required", "waived")) {
        $failures += "contract cross_model is invalid: $crossModel"
    } else {
        $cmCheck = $contract.checks | Where-Object { $_.id -eq "cross-model-verification" } | Select-Object -First 1
        if ($crossModel -eq "required") {
            if (-not $cmCheck) {
                $failures += "cross_model:required needs a 'cross-model-verification' check present and required:true with evidence"
            } elseif (-not [bool]$cmCheck.required) {
                $failures += "cross_model:required needs 'cross-model-verification' to be required:true"
            }
        } elseif ($crossModel -eq "waived") {
            if (-not $cmCheck) {
                $failures += "cross_model:waived needs a 'cross-model-verification' check present with a non-empty waiver_reason"
            } elseif ([string]::IsNullOrWhiteSpace(([string]($cmCheck.waiver_reason)).Trim())) {
                $failures += "cross_model:waived needs a non-empty waiver_reason on 'cross-model-verification'"
            }
        }
    }
}

# Pass 7: producer-digest verification (epic-191-a3-path-ownership T-004;
# REQ-004, AC-055, INV-017/INV-018). A passing check-component-coverage
# evidence entry must carry a producer.sha256 matching the live, on-disk
# check-component-coverage.py, recomputed independently at verification
# time -- never trusted from the evidence record itself.
foreach ($check in $contract.checks) {
    if ($check.id -ne $PRODUCER_DIGEST_CHECK_ID) { continue }
    if (-not [bool]$check.passes) { continue }
    $evidence = ([string]($check.evidence)).Trim()
    if ([string]::IsNullOrWhiteSpace($evidence)) { continue }
    $evidencePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($absRoot, $evidence))
    if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) {
        $failures += "check '$PRODUCER_DIGEST_CHECK_ID' evidence could not be read for producer-digest verification: $evidence"
        continue
    }
    try {
        $record = Get-Content -Raw -LiteralPath $evidencePath -Encoding utf8 | ConvertFrom-Json
    } catch {
        $failures += "check '$PRODUCER_DIGEST_CHECK_ID' evidence could not be parsed as JSON for producer-digest verification: $evidence"
        continue
    }
    $recordedSha256 = $null
    if ($record.PSObject.Properties.Name -contains "producer") {
        $recordedSha256 = $record.producer.sha256
    }
    if ([string]::IsNullOrWhiteSpace([string]$recordedSha256)) {
        $failures += "check '$PRODUCER_DIGEST_CHECK_ID' evidence is missing producer.sha256"
        continue
    }
    $producerScript = Join-Path $PSScriptRoot $PRODUCER_DIGEST_SCRIPT_NAME
    if (-not (Test-Path -LiteralPath $producerScript -PathType Leaf)) {
        $failures += "check '$PRODUCER_DIGEST_CHECK_ID' producer-digest verification could not read the live script: $producerScript"
        continue
    }
    $bytes = [System.IO.File]::ReadAllBytes($producerScript)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $liveSha256 = (-join (($sha.ComputeHash($bytes)) | ForEach-Object { $_.ToString("x2") }))
    if ([string]$recordedSha256 -ne $liveSha256) {
        $failures += "check '$PRODUCER_DIGEST_CHECK_ID' evidence producer.sha256 ($recordedSha256) does not match the live on-disk $PRODUCER_DIGEST_SCRIPT_NAME ($liveSha256)"
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Verification contract FAILED for task $($contract.task_id):"
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}
Write-Host "Verification contract passed for task $($contract.task_id)."
exit 0
