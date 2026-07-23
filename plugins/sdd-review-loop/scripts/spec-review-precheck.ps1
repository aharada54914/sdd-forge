# Usage: spec-review-precheck.ps1 -Feature <slug> -Attempt <n> -Round <n> [-EditSummary <text>] [-Reset]
# Full-parity PowerShell port of spec-review-precheck.sh (Issue #174,
# epic-159-pillar-a2 T-004). Validates a specification-review transition
# before any reviewer receives input or evidence is written. The
# orchestrating skill owns reviewer invocation and status mutation; this
# script owns deterministic preconditions and provenance, including the
# own-stage prior-round/reset contract re-validation the .sh original
# implements (validate_contract / validate_reviewer_output).
# tests/lib/loop-driver.ps1 invokes this script positionally
# (feature attempt round [--edit-summary=<text>]), so -EditSummary also
# accepts the raw --edit-summary=<text> token and strips the prefix itself,
# mirroring domain-review-precheck.ps1's translation idiom (T-003, INV-016).

param(
  [Parameter(Mandatory = $true, Position = 0)][string]$Feature,
  [Parameter(Mandatory = $true, Position = 1)][string]$Attempt,
  [Parameter(Mandatory = $true, Position = 2)][string]$Round,
  [Parameter(Position = 3)][string]$EditSummary = '',
  [switch]$Reset
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
  [Console]::Error.WriteLine("ERROR: spec-review-precheck: $Message")
  exit 1
}

function Test-OrdinalEqual([object]$Left, [object]$Right) {
  return [string]::Equals([string]$Left, [string]$Right, [StringComparison]::Ordinal)
}

function Get-Sha256File([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLower()
}

function Get-Sha256Text([string]$Text) {
  return [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))
  ).ToLower()
}

function Test-IsSymlink([string]$Path) {
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
  if ($null -eq $item) { return $false }
  return [bool]$item.LinkType
}

function Test-RealDirectory([string]$Path) {
  return (Test-Path -LiteralPath $Path -PathType Container) -and -not (Test-IsSymlink $Path)
}

function Get-CanonicalDir([string]$Path) {
  return (Resolve-Path -LiteralPath $Path).Path
}

function Test-IsSha256([object]$Value) {
  return ($Value -is [string]) -and ($Value -match '^[0-9a-fA-F]{64}$')
}

function Test-NonEmptyString([object]$Value) {
  return ($Value -is [string]) -and ($Value -match '\S')
}

# ConvertFrom-Json (PowerShell 6+) auto-coerces ISO-8601-looking JSON string
# values (e.g. "generated_at": "2026-06-23T00:00:00Z") into [DateTime], unlike
# jq which never performs implicit type coercion (the .sh original's
# `type == "string"` check on this field always sees a plain string). A
# [DateTime] here is evidence the underlying JSON value WAS a string, so both
# representations satisfy the original's intent.
function Test-IsStringLike([object]$Value) {
  return ($Value -is [string]) -or ($Value -is [DateTime])
}

function Test-IsJsonNumberGte0([object]$Value) {
  if ($Value -is [int64] -or $Value -is [int32] -or $Value -is [System.Numerics.BigInteger]) { return ([int64]$Value -ge 0) }
  if ($Value -is [double]) {
    if ([double]::IsNaN($Value) -or [double]::IsInfinity($Value)) { return $false }
    return ($Value -ge 0)
  }
  return $false
}

function Test-JsonIntegerEquals([object]$Value, [int64]$Expected) {
  if ($Value -is [int64] -or $Value -is [int32] -or $Value -is [System.Numerics.BigInteger]) { return ([int64]$Value -eq $Expected) }
  if ($Value -is [double]) {
    if ([double]::IsNaN($Value) -or [double]::IsInfinity($Value)) { return $false }
    if ([Math]::Floor($Value) -ne $Value) { return $false }
    return ([int64]$Value -eq $Expected)
  }
  return $false
}

function Test-KeysExact([object]$Obj, [string[]]$ExpectedKeys) {
  if ($null -eq $Obj -or $Obj -isnot [System.Management.Automation.PSCustomObject]) { return $false }
  $actual = @($Obj.PSObject.Properties.Name | Sort-Object)
  $expected = @($ExpectedKeys | Sort-Object)
  if ($actual.Count -ne $expected.Count) { return $false }
  for ($i = 0; $i -lt $actual.Count; $i++) {
    if (-not (Test-OrdinalEqual $actual[$i] $expected[$i])) { return $false }
  }
  return $true
}

function Test-ManifestArrayValid([object]$Manifest) {
  if ($null -eq $Manifest) { return $false }
  $arr = @($Manifest)
  if ($arr.Count -eq 0) { return $false }
  foreach ($entry in $arr) {
    if (-not (Test-KeysExact $entry @('path', 'sha256'))) { return $false }
    if ($entry.path -isnot [string]) { return $false }
    if (-not (Test-IsSha256 $entry.sha256)) { return $false }
  }
  return $true
}

function Test-ManifestArraysEqual([array]$Actual, [array]$Expected) {
  if ($Actual.Count -ne $Expected.Count) { return $false }
  for ($i = 0; $i -lt $Actual.Count; $i++) {
    if (-not (Test-OrdinalEqual $Actual[$i].path $Expected[$i].path)) { return $false }
    if (-not (Test-OrdinalEqual $Actual[$i].sha256 $Expected[$i].sha256)) { return $false }
  }
  return $true
}

function Test-ChecksArrayValid([object]$Checks) {
  if ($null -eq $Checks) { return $false }
  $arr = @($Checks)
  if ($arr.Count -eq 0) { return $false }
  foreach ($c in $arr) {
    if (-not (Test-KeysExact $c @('finding', 'id', 'result', 'severity'))) { return $false }
    if (-not (Test-NonEmptyString $c.id)) { return $false }
    if (@('PASS', 'FAIL', 'SKIP') -cnotcontains $c.result) { return $false }
    if (@('Critical', 'Major', 'Minor') -cnotcontains $c.severity) { return $false }
    if ($c.finding -isnot [string]) { return $false }
  }
  return $true
}

# --- Argument normalization (mirrors domain-review-precheck.ps1's argv loop,
# which itself mirrors spec-review-precheck.sh's --edit-summary=/--reset
# parsing loop at lines 23-30). ---
if ($EditSummary -cmatch '^--edit-summary=(.*)$') { $EditSummary = $Matches[1] }
if (Test-OrdinalEqual $EditSummary '--reset') { $EditSummary = ''; $Reset = $true }

if ($Feature -cnotmatch '^[a-z0-9][a-z0-9-]*$') { Fail 'invalid feature slug' }
if ($Attempt -notmatch '^[1-9][0-9]*$') { Fail 'attempt must be a positive integer' }
if ($Round -notmatch '^[1-9][0-9]*$') { Fail 'round must be a positive integer' }
$attemptInt = [int64]$Attempt
$roundInt = [int64]$Round
if ($roundInt -gt 3) { Fail 'round must be between 1 and 3' }
if (-not ([string]::IsNullOrEmpty($EditSummary)) -and $roundInt -le 1) { Fail '--edit-summary is valid only after round 1' }
if ($roundInt -gt 1) {
  if ([string]::IsNullOrEmpty(($EditSummary -replace '\s', ''))) { Fail 'rounds 2 and 3 require a non-empty --edit-summary' }
}
if ($Reset) {
  if (-not ($attemptInt -gt 1 -and $roundInt -eq 1)) { Fail '--reset starts only attempt N+1 round 1' }
} else {
  if (-not ($attemptInt -eq 1 -or $roundInt -gt 1)) { Fail 'a new attempt requires --reset' }
}

$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$specsRoot = Join-Path $root 'specs'
$reportsRoot = Join-Path $root 'reports'
$reportsBase = Join-Path $reportsRoot 'spec-review'
$specDir = Join-Path $root "specs/$Feature"
$requirements = Join-Path $specDir 'requirements.md'
$acceptance = Join-Path $specDir 'acceptance-tests.md'
$calibration = Join-Path $root 'plugins/sdd-review-loop/references/spec-review-calibration.md'
$reportRoot = Join-Path $reportsBase $Feature
$reportDir = Join-Path $reportRoot (Join-Path "attempt-$attemptInt" "round-$roundInt")

if (-not (Test-RealDirectory $specsRoot)) { Fail 'specs root must be a real directory' }
if (-not (Test-OrdinalEqual (Get-CanonicalDir $specsRoot) $specsRoot)) { Fail 'specs root escapes repository' }
if (-not (Test-RealDirectory $specDir)) { Fail 'feature specification directory must not be a symlink' }
if (-not (Test-OrdinalEqual (Get-CanonicalDir $specDir) $specDir)) { Fail 'feature specification directory escapes repository' }
if (-not (Test-Path -LiteralPath $requirements -PathType Leaf) -or (Test-IsSymlink $requirements)) { Fail 'requirements.md must be a regular non-symlink file' }
if (-not (Test-Path -LiteralPath $acceptance -PathType Leaf) -or (Test-IsSymlink $acceptance)) { Fail 'acceptance-tests.md must be a regular non-symlink file' }
if (-not (Test-Path -LiteralPath $calibration -PathType Leaf) -or (Test-IsSymlink $calibration)) { Fail 'spec review calibration reference must be a regular non-symlink file' }
if (-not (Test-RealDirectory $reportsRoot)) { Fail 'reports root must be a real directory' }
if (-not (Test-OrdinalEqual (Get-CanonicalDir $reportsRoot) $reportsRoot)) { Fail 'reports root escapes repository' }
if (Test-Path -LiteralPath $reportsBase) {
  if (-not (Test-RealDirectory $reportsBase)) { Fail 'spec-review report base must not be a symlink' }
  if (-not (Test-OrdinalEqual (Get-CanonicalDir $reportsBase) $reportsBase)) { Fail 'spec-review report base escapes reports root' }
}

$statusMatch = Select-String -LiteralPath $requirements -CaseSensitive -Pattern '^Spec-Review-Status:\s*(.*)$' | Select-Object -First 1
$status = if ($statusMatch) { ($statusMatch.Matches[0].Groups[1].Value -replace '\s', '') } else { '' }
if ($Reset) {
  if (-not (Test-OrdinalEqual $status 'Pending') -and -not (Test-OrdinalEqual $status 'Passed')) { Fail 'requirements.md must declare a resettable Spec-Review-Status' }
} else {
  if (-not (Test-OrdinalEqual $status 'Pending')) { Fail 'requirements.md must declare Spec-Review-Status: Pending' }
}
if (Test-IsSymlink $reportRoot) { Fail 'report root must not be a symlink' }
if (Test-Path -LiteralPath $reportDir) { Fail 'round destination already exists (replay is forbidden)' }

$requirementsSha = Get-Sha256File $requirements
$acceptanceSha = Get-Sha256File $acceptance
$calibrationSha = Get-Sha256File $calibration
$inputSha = Get-Sha256Text "${requirementsSha}:${acceptanceSha}"

# --- validate_reviewer_output translation ----------------------------------
function Test-ValidateReviewerOutput(
  [string]$OutputPath,
  [string]$Role,
  [array]$ExpectedManifestSorted,
  [string]$RunId,
  [string]$HostSessionId
) {
  if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf) -or (Test-IsSymlink $OutputPath)) { return $false }
  $data = $null
  try { $data = Get-Content -LiteralPath $OutputPath -Raw | ConvertFrom-Json } catch { return $false }
  if (-not (Test-KeysExact $data @('allowed_input_manifest', 'checks', 'host_session_id', 'role', 'run_id', 'schema', 'stage', 'verdict'))) { return $false }
  if (-not (Test-OrdinalEqual $data.schema "$Role/v1")) { return $false }
  if (-not (Test-OrdinalEqual $data.stage 'spec')) { return $false }
  if (-not (Test-OrdinalEqual $data.role $Role)) { return $false }
  if (-not (Test-OrdinalEqual $data.run_id $RunId)) { return $false }
  if (-not (Test-OrdinalEqual $data.host_session_id $HostSessionId)) { return $false }
  if (-not (Test-ManifestArrayValid $data.allowed_input_manifest)) { return $false }
  if (-not (Test-ChecksArrayValid $data.checks)) { return $false }
  if (@('PASS', 'NEEDS_WORK', 'BLOCKED') -cnotcontains $data.verdict) { return $false }

  $actualManifest = @($data.allowed_input_manifest | Sort-Object path)
  if (-not (Test-ManifestArraysEqual $actualManifest $ExpectedManifestSorted)) { return $false }

  $expectedIds = $null
  switch ($Role) {
    'spec-reviewer-a' { $expectedIds = @('REQ-TESTABILITY', 'GOAL-AC-TRACE', 'AC-OBSERVABLE', 'SCOPE-BOUNDARY', 'CONSTRAINTS-EXPLICIT', 'RISK-VALIDATION-SURFACE') }
    'spec-reviewer-b' { $expectedIds = @('AMBIGUITY', 'CONTRADICTION', 'EDGE-CASE-COVERAGE', 'ASSUMPTIONS-RESOLVABLE', 'APPROVAL-BOUNDARY', 'DOWNSTREAM-READINESS') }
    default { return $false }
  }
  $actualIds = @($data.checks | ForEach-Object { $_.id })
  if (($actualIds -join ',') -cne ($expectedIds -join ',')) { return $false }

  $criticalFail = @($data.checks | Where-Object { $_.result -ceq 'FAIL' -and $_.severity -ceq 'Critical' })
  $anyFail = @($data.checks | Where-Object { $_.result -ceq 'FAIL' })
  $expectedVerdict = if ($criticalFail.Count -gt 0) { 'BLOCKED' } elseif ($anyFail.Count -gt 0) { 'NEEDS_WORK' } else { 'PASS' }
  return (Test-OrdinalEqual $data.verdict $expectedVerdict)
}

# --- validate_contract translation ------------------------------------------
# Own-stage prior-round / reset contract re-validation: spec is the first
# stage in the review chain, so (unlike impl/task's Require-Pass, which
# validates a PREDECESSOR stage's persisted PASS) this validates THIS
# stage's own prior-round (or reset-target terminal-round) evidence set in
# full: contract, precheck-result.json, integrated-summary.json,
# reviewer-a.json, reviewer-b.json, integrated-verdict.json.
function Test-ValidateContract(
  [string]$ContractPath,
  [int64]$ExpectedAttempt,
  [int64]$ExpectedRound,
  [string]$ExpectedVerdict,
  [string]$PrecheckPath
) {
  if (-not (Test-Path -LiteralPath $ContractPath -PathType Leaf) -or (Test-IsSymlink $ContractPath)) { return $false }
  if (-not (Test-Path -LiteralPath $PrecheckPath -PathType Leaf) -or (Test-IsSymlink $PrecheckPath)) { return $false }

  $contract = $null
  try { $contract = Get-Content -LiteralPath $ContractPath -Raw | ConvertFrom-Json } catch { return $false }
  if (-not (Test-KeysExact $contract @('acceptance_sha256', 'attempt', 'feature', 'requirements_sha256', 'reviewers', 'round', 'run_id', 'schema', 'stage', 'verdict', 'warningCount'))) { return $false }
  if (-not (Test-OrdinalEqual $contract.schema 'spec-review-contract/v1')) { return $false }
  if (-not (Test-OrdinalEqual $contract.stage 'spec')) { return $false }
  if (-not (Test-OrdinalEqual $contract.feature $Feature)) { return $false }
  if (-not (Test-JsonIntegerEquals $contract.attempt $ExpectedAttempt)) { return $false }
  if (-not (Test-JsonIntegerEquals $contract.round $ExpectedRound)) { return $false }
  if (-not (Test-OrdinalEqual $contract.verdict $ExpectedVerdict)) { return $false }
  if (-not (Test-IsSha256 $contract.requirements_sha256)) { return $false }
  if (-not (Test-IsSha256 $contract.acceptance_sha256)) { return $false }
  if (-not (Test-NonEmptyString $contract.run_id)) { return $false }
  if (-not (Test-IsJsonNumberGte0 $contract.warningCount)) { return $false }

  $reviewers = @($contract.reviewers)
  if ($reviewers.Count -ne 2) { return $false }
  $roles = @($reviewers | ForEach-Object { $_.role } | Sort-Object)
  if (-not ((Test-OrdinalEqual $roles[0] 'spec-reviewer-a') -and (Test-OrdinalEqual $roles[1] 'spec-reviewer-b'))) { return $false }
  $sessionIds = @($reviewers | ForEach-Object { $_.host_session_id })
  if (@($sessionIds | Where-Object { -not (Test-NonEmptyString $_) }).Count -gt 0) { return $false }
  if (@($sessionIds | Select-Object -Unique).Count -ne 2) { return $false }
  foreach ($reviewer in $reviewers) {
    if (-not (Test-NonEmptyString $reviewer.run_id)) { return $false }
    if (-not (Test-ManifestArrayValid $reviewer.allowed_input_manifest)) { return $false }
  }

  $precheck = $null
  try { $precheck = Get-Content -LiteralPath $PrecheckPath -Raw | ConvertFrom-Json } catch { return $false }
  if (-not (Test-OrdinalEqual $precheck.schema 'spec-review-precheck/v1')) { return $false }
  if (-not (Test-OrdinalEqual $precheck.stage 'spec')) { return $false }
  if (-not (Test-OrdinalEqual $precheck.feature $Feature)) { return $false }
  if (-not (Test-JsonIntegerEquals $precheck.attempt $ExpectedAttempt)) { return $false }
  if (-not (Test-JsonIntegerEquals $precheck.round $ExpectedRound)) { return $false }
  if (-not (Test-OrdinalEqual $precheck.requirements_sha256 $contract.requirements_sha256)) { return $false }
  if (-not (Test-OrdinalEqual $precheck.acceptance_sha256 $contract.acceptance_sha256)) { return $false }
  if (-not ($null -eq $precheck.calibration_sha256 -or (Test-IsSha256 $precheck.calibration_sha256))) { return $false }

  $roundDir = Split-Path -Parent $ContractPath
  $summaryPath = Join-Path $roundDir 'integrated-summary.json'
  if (-not (Test-Path -LiteralPath $summaryPath -PathType Leaf) -or (Test-IsSymlink $summaryPath)) { return $false }
  $summary = $null
  try { $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json } catch { return $false }
  if (-not (Test-KeysExact $summary @('attempt', 'generated_at', 'reviewer_a_checks', 'reviewer_a_fail_count', 'reviewer_a_pass_count', 'reviewer_a_skip_count', 'round', 'schema'))) { return $false }
  if (-not (Test-OrdinalEqual $summary.schema 'integrated-summary/v1')) { return $false }
  if (-not (Test-JsonIntegerEquals $summary.attempt $ExpectedAttempt)) { return $false }
  if (-not (Test-JsonIntegerEquals $summary.round $ExpectedRound)) { return $false }
  $summaryChecks = @($summary.reviewer_a_checks)
  foreach ($c in $summaryChecks) {
    if (-not (Test-KeysExact $c @('id', 'result', 'severity'))) { return $false }
    if (-not (Test-NonEmptyString $c.id)) { return $false }
    if (@('PASS', 'FAIL', 'SKIP') -cnotcontains $c.result) { return $false }
    if (@('Critical', 'Major', 'Minor') -cnotcontains $c.severity) { return $false }
  }
  if (-not (Test-IsJsonNumberGte0 $summary.reviewer_a_fail_count)) { return $false }
  if (-not (Test-IsJsonNumberGte0 $summary.reviewer_a_pass_count)) { return $false }
  if (-not (Test-IsJsonNumberGte0 $summary.reviewer_a_skip_count)) { return $false }
  if (-not (Test-IsStringLike $summary.generated_at)) { return $false }

  $requirementsHash = [string]$contract.requirements_sha256
  $acceptanceHash = [string]$contract.acceptance_sha256

  $calibrationHashes = @()
  foreach ($reviewer in $reviewers) {
    foreach ($entry in @($reviewer.allowed_input_manifest)) {
      if (Test-OrdinalEqual $entry.path $calibration) { $calibrationHashes += [string]$entry.sha256 }
    }
  }
  $uniqueCalibrationHashes = @($calibrationHashes | Select-Object -Unique)
  if ($uniqueCalibrationHashes.Count -ne 1) { return $false }
  $calibrationHash = $uniqueCalibrationHashes[0]
  if (-not (Test-IsSha256 $calibrationHash)) { return $false }
  if (-not ($null -eq $precheck.calibration_sha256)) {
    if (-not (Test-OrdinalEqual $precheck.calibration_sha256 $calibrationHash)) { return $false }
  }

  $precheckFileHash = Get-Sha256File $PrecheckPath
  $expectedAList = [Collections.Generic.List[object]]::new()
  $expectedAList.Add([pscustomobject]@{ path = $requirements; sha256 = $requirementsHash })
  $expectedAList.Add([pscustomobject]@{ path = $acceptance; sha256 = $acceptanceHash })
  $expectedAList.Add([pscustomobject]@{ path = $PrecheckPath; sha256 = $precheckFileHash })
  $expectedAList.Add([pscustomobject]@{ path = $calibration; sha256 = $calibrationHash })
  $investigationPath = Join-Path $specDir 'investigation.md'
  if ((Test-Path -LiteralPath $investigationPath -PathType Leaf) -and -not (Test-IsSymlink $investigationPath)) {
    $expectedAList.Add([pscustomobject]@{ path = $investigationPath; sha256 = (Get-Sha256File $investigationPath) })
  }
  $expectedA = @($expectedAList | Sort-Object path)
  $expectedBList = [Collections.Generic.List[object]]::new()
  foreach ($e in $expectedA) { $expectedBList.Add($e) }
  $expectedBList.Add([pscustomobject]@{ path = $summaryPath; sha256 = (Get-Sha256File $summaryPath) })
  $expectedB = @($expectedBList | Sort-Object path)

  $reviewerAContractEntry = @($reviewers | Where-Object { Test-OrdinalEqual $_.role 'spec-reviewer-a' })
  $reviewerBContractEntry = @($reviewers | Where-Object { Test-OrdinalEqual $_.role 'spec-reviewer-b' })
  if ($reviewerAContractEntry.Count -ne 1 -or $reviewerBContractEntry.Count -ne 1) { return $false }
  $reviewerA = $reviewerAContractEntry[0]
  $reviewerB = $reviewerBContractEntry[0]

  $actualA = @($reviewerA.allowed_input_manifest | Sort-Object path)
  $actualB = @($reviewerB.allowed_input_manifest | Sort-Object path)
  if (-not (Test-ManifestArraysEqual $actualA $expectedA)) { return $false }
  if (-not (Test-ManifestArraysEqual $actualB $expectedB)) { return $false }

  $reviewerAPath = Join-Path $roundDir 'reviewer-a.json'
  $reviewerBPath = Join-Path $roundDir 'reviewer-b.json'
  $aRun = [string]$reviewerA.run_id
  $aSession = [string]$reviewerA.host_session_id
  $bRun = [string]$reviewerB.run_id
  $bSession = [string]$reviewerB.host_session_id

  if (-not (Test-ValidateReviewerOutput $reviewerAPath 'spec-reviewer-a' $expectedA $aRun $aSession)) { return $false }
  if (-not (Test-ValidateReviewerOutput $reviewerBPath 'spec-reviewer-b' $expectedB $bRun $bSession)) { return $false }

  $reviewerAData = Get-Content -LiteralPath $reviewerAPath -Raw | ConvertFrom-Json
  $reviewerAChecks = @($reviewerAData.checks)
  if ($reviewerAChecks.Count -ne $summaryChecks.Count) { return $false }
  for ($i = 0; $i -lt $reviewerAChecks.Count; $i++) {
    if (-not (Test-OrdinalEqual $reviewerAChecks[$i].id $summaryChecks[$i].id)) { return $false }
    if (-not (Test-OrdinalEqual $reviewerAChecks[$i].result $summaryChecks[$i].result)) { return $false }
    if (-not (Test-OrdinalEqual $reviewerAChecks[$i].severity $summaryChecks[$i].severity)) { return $false }
  }
  $reviewerAFailCount = @($reviewerAChecks | Where-Object { $_.result -ceq 'FAIL' }).Count
  $reviewerAPassCount = @($reviewerAChecks | Where-Object { $_.result -ceq 'PASS' }).Count
  $reviewerASkipCount = @($reviewerAChecks | Where-Object { $_.result -ceq 'SKIP' }).Count
  if (-not (Test-JsonIntegerEquals $summary.reviewer_a_fail_count $reviewerAFailCount)) { return $false }
  if (-not (Test-JsonIntegerEquals $summary.reviewer_a_pass_count $reviewerAPassCount)) { return $false }
  if (-not (Test-JsonIntegerEquals $summary.reviewer_a_skip_count $reviewerASkipCount)) { return $false }

  $reviewerBData = Get-Content -LiteralPath $reviewerBPath -Raw | ConvertFrom-Json
  $reviewerBChecks = @($reviewerBData.checks)
  $allChecks = @($reviewerAChecks) + @($reviewerBChecks)
  $critical = @($allChecks | Where-Object { $_.result -ceq 'FAIL' -and $_.severity -ceq 'Critical' }).Count
  $major = @($allChecks | Where-Object { $_.result -ceq 'FAIL' -and $_.severity -ceq 'Major' }).Count
  $minor = @($allChecks | Where-Object { $_.result -ceq 'FAIL' -and $_.severity -ceq 'Minor' }).Count

  if ($critical -gt 0 -or $major -gt 0) {
    $expectedMerged = if ($ExpectedRound -eq 3) { 'BLOCKED' } else { 'NEEDS_WORK' }
    $expectedWarning = 0
  } elseif ($minor -gt 0) {
    if ($ExpectedRound -eq 3) { $expectedMerged = 'PASS'; $expectedWarning = $minor } else { $expectedMerged = 'NEEDS_WORK'; $expectedWarning = 0 }
  } else {
    $expectedMerged = 'PASS'; $expectedWarning = 0
  }
  if (-not (Test-OrdinalEqual $expectedMerged $ExpectedVerdict)) { return $false }

  $integratedVerdictPath = Join-Path $roundDir 'integrated-verdict.json'
  if (-not (Test-Path -LiteralPath $integratedVerdictPath -PathType Leaf) -or (Test-IsSymlink $integratedVerdictPath)) { return $false }
  $verdictData = $null
  try { $verdictData = Get-Content -LiteralPath $integratedVerdictPath -Raw | ConvertFrom-Json } catch { return $false }
  if (-not (Test-KeysExact $verdictData @('attempt', 'feature', 'finding_counts', 'reviewer_a_host_session_id', 'reviewer_a_run_id', 'reviewer_b_host_session_id', 'reviewer_b_run_id', 'round', 'schema', 'stage', 'verdict', 'warningCount'))) { return $false }
  if (-not (Test-OrdinalEqual $verdictData.schema 'spec-review-integrated-verdict/v1')) { return $false }
  if (-not (Test-OrdinalEqual $verdictData.stage 'spec')) { return $false }
  if (-not (Test-OrdinalEqual $verdictData.feature $Feature)) { return $false }
  if (-not (Test-JsonIntegerEquals $verdictData.attempt $ExpectedAttempt)) { return $false }
  if (-not (Test-JsonIntegerEquals $verdictData.round $ExpectedRound)) { return $false }
  if (-not (Test-OrdinalEqual $verdictData.verdict $expectedMerged)) { return $false }
  if (-not (Test-JsonIntegerEquals $verdictData.warningCount $expectedWarning)) { return $false }
  if (-not (Test-OrdinalEqual $verdictData.reviewer_a_run_id $aRun)) { return $false }
  if (-not (Test-OrdinalEqual $verdictData.reviewer_b_run_id $bRun)) { return $false }
  if (-not (Test-OrdinalEqual $verdictData.reviewer_a_host_session_id $aSession)) { return $false }
  if (-not (Test-OrdinalEqual $verdictData.reviewer_b_host_session_id $bSession)) { return $false }
  if (-not (Test-KeysExact $verdictData.finding_counts @('critical', 'major', 'minor'))) { return $false }
  if (-not (Test-JsonIntegerEquals $verdictData.finding_counts.critical $critical)) { return $false }
  if (-not (Test-JsonIntegerEquals $verdictData.finding_counts.major $major)) { return $false }
  if (-not (Test-JsonIntegerEquals $verdictData.finding_counts.minor $minor)) { return $false }

  if (-not (Test-OrdinalEqual $contract.verdict $expectedMerged)) { return $false }
  if (-not (Test-JsonIntegerEquals $contract.warningCount $expectedWarning)) { return $false }

  return $true
}

if ($roundInt -gt 1) {
  $priorDir = Join-Path $reportRoot (Join-Path "attempt-$attemptInt" "round-$($roundInt - 1)")
  $priorContract = Join-Path $priorDir 'spec-review-contract.json'
  if (-not (Test-Path -LiteralPath $priorContract -PathType Leaf)) { Fail 'prior round contract is required' }
  if (-not (Test-ValidateContract -ContractPath $priorContract -ExpectedAttempt $attemptInt -ExpectedRound ($roundInt - 1) -ExpectedVerdict 'NEEDS_WORK' -PrecheckPath (Join-Path $priorDir 'precheck-result.json'))) {
    Fail 'prior round contract is malformed or does not require work'
  }
  $priorData = Get-Content -LiteralPath $priorContract -Raw | ConvertFrom-Json
  $priorRequirementsSha = [string]$priorData.requirements_sha256
  $priorAcceptanceSha = [string]$priorData.acceptance_sha256
  if ((Test-OrdinalEqual $requirementsSha $priorRequirementsSha) -and (Test-OrdinalEqual $acceptanceSha $priorAcceptanceSha)) {
    Fail 'reviewed inputs are unchanged from the prior round'
  }
}

if ($Reset) {
  $previousAttempt = Join-Path $reportRoot "attempt-$($attemptInt - 1)"
  if (-not (Test-RealDirectory $previousAttempt)) { Fail 'previous attempt is required before reset' }
  $roundDirs = @(Get-ChildItem -LiteralPath $previousAttempt -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -cmatch '^round-[1-3]$' })
  $previousRoundNumbers = @($roundDirs | ForEach-Object { [int]($_.Name -replace '^round-', '') } | Sort-Object)
  if ($previousRoundNumbers.Count -eq 0) { Fail 'previous attempt has no terminal round' }
  $previousRound = $previousRoundNumbers[-1]
  $previousDir = Join-Path $previousAttempt "round-$previousRound"
  $previousContractPath = Join-Path $previousDir 'spec-review-contract.json'
  $previousVerdict = $null
  if (Test-Path -LiteralPath $previousContractPath -PathType Leaf) {
    try { $previousVerdict = (Get-Content -LiteralPath $previousContractPath -Raw | ConvertFrom-Json).verdict } catch { $previousVerdict = $null }
  }
  if (-not (Test-OrdinalEqual $previousVerdict 'PASS') -and -not (Test-OrdinalEqual $previousVerdict 'BLOCKED')) { Fail 'reset requires a terminal PASS or BLOCKED contract' }
  if (-not (Test-ValidateContract -ContractPath $previousContractPath -ExpectedAttempt ($attemptInt - 1) -ExpectedRound $previousRound -ExpectedVerdict $previousVerdict -PrecheckPath (Join-Path $previousDir 'precheck-result.json'))) {
    Fail 'previous terminal contract is invalid'
  }
}

# Only after every pure validation succeeds may this script acquire a lock or
# create an evidence path. New-Item -ErrorAction Stop on the lock directory
# makes concurrent writers fail deterministically.
New-Item -ItemType Directory -Path $reportsBase -Force | Out-Null
if ((Test-IsSymlink $reportsBase) -or -not (Test-OrdinalEqual (Get-CanonicalDir $reportsBase) $reportsBase)) { Fail 'spec-review report base escapes reports root' }
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
if (Test-IsSymlink $reportRoot) { Fail 'report root must not be a symlink' }
if (-not (Test-OrdinalEqual (Get-CanonicalDir $reportRoot) $reportRoot)) { Fail 'report root escapes report base' }
$lockDir = Join-Path $reportRoot '.spec-review.lock'
try {
  New-Item -ItemType Directory -Path $lockDir -ErrorAction Stop | Out-Null
} catch {
  Fail 'another specification review transition holds the lock'
}
try {
  if (Test-Path -LiteralPath $reportDir) { Fail 'round destination already exists (replay is forbidden)' }
  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null

  # Exercise the shared portable foundation against the canonical composite
  # input before persisting the gate-specific precheck evidence.
  $foundationContract = Join-Path $reportRoot ".review-contract-$attemptInt-$roundInt-$PID.json"
  try {
    [ordered]@{
      schema       = 'review-contract/v1'
      stage        = 'spec'
      feature      = $Feature
      attempt      = $attemptInt
      round        = $roundInt
      input_sha256 = $inputSha
      run_id       = 'spec-precheck'
      verdict      = 'PASS'
    } | ConvertTo-Json -Compress | Set-Content -LiteralPath $foundationContract -Encoding utf8NoBOM
    & (Join-Path $PSScriptRoot 'review-contract-validate.ps1') -Feature $Feature -Attempt $Attempt -Round $Round -Stage spec -ReportRoot $reportRoot -Contract $foundationContract | Out-Null
  } finally {
    Remove-Item -LiteralPath $foundationContract -Force -ErrorAction SilentlyContinue
  }

  # Reset is the sole exceptional transition that restores Pending. It occurs
  # only after the old evidence and the new destination have both been
  # validated.
  if ($Reset -and (Test-OrdinalEqual $status 'Passed')) {
    $content = [IO.File]::ReadAllText($requirements)
    $normalized = [Text.RegularExpressions.Regex]::Replace(
      $content,
      '(?m)^Spec-Review-Status:[ \t]*Passed[ \t]*(\r?)$',
      'Spec-Review-Status: Pending$1'
    )
    [IO.File]::WriteAllText($requirements, $normalized)
    $status = 'Pending'
    # Recompute the requirements/input hashes against the post-reset file: any
    # persisted precheck-result.json must record the bytes reviewers, contracts,
    # and later contract validation will actually see, never the pre-mutation
    # (Passed) bytes this same invocation just rewrote.
    $requirementsSha = Get-Sha256File $requirements
    $inputSha = Get-Sha256Text "${requirementsSha}:${acceptanceSha}"
  }

  $generatedAt = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
  $result = [ordered]@{
    schema                    = 'spec-review-precheck/v1'
    stage                     = 'spec'
    feature                   = $Feature
    attempt                   = $attemptInt
    round                     = $roundInt
    spec_review_status_field  = $status
    requirements_sha256       = $requirementsSha
    acceptance_sha256         = $acceptanceSha
    calibration_sha256        = $calibrationSha
    input_sha256              = $inputSha
    edit_summary              = $EditSummary
    reset                     = [bool]$Reset
    generated_at              = $generatedAt
  }
  $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $reportDir 'precheck-result.json') -Encoding utf8NoBOM

  Write-Output "spec-review-precheck: complete. Output written to $reportDir/"
} finally {
  Remove-Item -LiteralPath $lockDir -Recurse -Force -ErrorAction SilentlyContinue
}
