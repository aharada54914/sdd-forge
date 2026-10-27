# Usage: spec-review-precheck.ps1 -Feature <slug> -Attempt <n> -Round <n> [-EditSummary <text>] [-Reset] [-RecoverInterrupted <record>]
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
  [switch]$Reset,
  [switch]$VerifyInputs,
  [string]$FixedInputRecord = '',
  [string]$FixedInputSnapshot = '',
  [Parameter(ValueFromRemainingArguments=$true, Position=4)][string[]]$AdditionalArguments
)

$ErrorActionPreference = 'Stop'
# Validate saved provenance only; publication eligibility is deliberately not replayed.
function Assert-SavedRecoveryReference([string]$Repository, [string]$PrecheckPath) {
  function Assert-UniqueJsonMembers([System.Text.Json.JsonElement]$Element) {
    if ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) {
      $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($property in $Element.EnumerateObject()) {
        if (-not $names.Add($property.Name)) { throw 'duplicate JSON member' }
        Assert-UniqueJsonMembers $property.Value
      }
    } elseif ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
      foreach ($item in $Element.EnumerateArray()) { Assert-UniqueJsonMembers $item }
    }
  }
  $text = [Text.UTF8Encoding]::new($false, $true).GetString([IO.File]::ReadAllBytes($PrecheckPath))
  $document = [System.Text.Json.JsonDocument]::Parse($text)
  try {
    $precheck = $document.RootElement
    Assert-UniqueJsonMembers $precheck
    if ($precheck.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) { throw 'precheck object required' }
    $found = $false
    foreach ($property in $precheck.EnumerateObject()) {
      if ([string]::Equals($property.Name, 'recovery', [StringComparison]::OrdinalIgnoreCase)) {
        if ($property.Name -cne 'recovery') { throw 'mis-cased recovery member' }
        $found = $true; $recovery = $property.Value
      }
    }
    if (-not $found) { return }
    $schema = $precheck.GetProperty('schema')
    if ($schema.ValueKind -ne [System.Text.Json.JsonValueKind]::String -or $schema.GetString() -cne 'spec-review-precheck/v1') { throw 'invalid recovery precheck schema' }
    if ($recovery.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) { throw 'recovery object required' }
    $keys = @($recovery.EnumerateObject() | ForEach-Object { $_.Name })
    if ($keys.Count -ne 2 -or $keys -cnotcontains 'record_path' -or $keys -cnotcontains 'record_sha256') { throw 'closed recovery reference required' }
    $pathElement = $recovery.GetProperty('record_path'); $hashElement = $recovery.GetProperty('record_sha256')
    if ($pathElement.ValueKind -ne [System.Text.Json.JsonValueKind]::String -or $hashElement.ValueKind -ne [System.Text.Json.JsonValueKind]::String) { throw 'recovery reference strings required' }
    $relative = $pathElement.GetString(); $hash = $hashElement.GetString()
    if ($hash -cnotmatch '^[0-9a-f]{64}$') { throw 'invalid recovery digest' }
    if (-not $relative -or $relative -cmatch '[\\\x00-\x1f\x7f:]') { throw 'invalid recovery path' }
    $current = $Repository
    foreach ($part in $relative.Split('/')) {
      if (@('', '.', '..') -ccontains $part) { throw 'noncanonical recovery path' }
      $matches = @([IO.Directory]::EnumerateFileSystemEntries($current) | Where-Object { [string]::Equals([IO.Path]::GetFileName($_), $part, [StringComparison]::Ordinal) })
      if ($matches.Count -ne 1) { throw 'missing or mis-cased recovery path' }
      $current = $matches[0]
      $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
      if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'linked recovery path' }
    }
    if ($item -isnot [IO.FileInfo] -or ($item.Attributes -band [IO.FileAttributes]::Device) -ne 0) { throw 'recovery record is not a regular file' }
    if (-not $IsWindows -and [string]$item.UnixStat.ItemType -cne 'File') { throw 'recovery record is not a regular file' }
    if ((Get-FileHash -LiteralPath $current -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant() -cne $hash) { throw 'saved recovery record changed' }
  } finally { $document.Dispose() }
}


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
  return ($Value -is [string]) -and ($Value -cmatch '^[0-9a-f]{64}$')
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
  $Expected = @($Expected | ForEach-Object {
    [pscustomobject]@{ path = (Get-ManifestLocalPath $_.path ''); sha256 = $_.sha256 }
  } | Sort-Object path)
  if ($Actual.Count -ne $Expected.Count) { return $false }
  for ($i = 0; $i -lt $Actual.Count; $i++) {
    if (-not (Test-OrdinalEqual $Actual[$i].path $Expected[$i].path)) { return $false }
    if (-not (Test-OrdinalEqual $Actual[$i].sha256 $Expected[$i].sha256)) { return $false }
  }
  return $true
}

function Get-ManifestLocalPath([string]$Path, [string]$RecordedRoot) {
  $pathValue = $Path.Replace('\', '/')
  $localRoot = $root.Replace('\', '/').TrimEnd('/')
  $aliasRoot = $localRoot -creplace '^/private/var/', '/var/'
  if ($localRoot.StartsWith('/var/', [StringComparison]::Ordinal)) { $aliasRoot = '/private' + $localRoot }
  foreach ($prefix in @($localRoot, $aliasRoot, $RecordedRoot)) {
    if ($prefix -and $pathValue.StartsWith($prefix + '/', [StringComparison]::Ordinal)) {
      return ($localRoot + '/' + $pathValue.Substring($prefix.Length + 1))
    }
  }
  if ($pathValue -cmatch '^(/|[A-Za-z]:/)') { return '' }
  return ($localRoot + '/' + $pathValue)
}

function Get-ManifestRecordedRoot([object]$Contract) {
  $roots = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($reviewer in @($Contract.reviewers)) {
    foreach ($entry in @($reviewer.allowed_input_manifest)) {
      if ($entry.path -isnot [string]) { return '__INVALID__' }
      $pathValue = $entry.path.Replace('\', '/')
      if ($pathValue -cnotmatch '^(/|[A-Za-z]:/)' -or (Get-ManifestLocalPath $pathValue '') -cne '') { continue }
      $candidates = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach ($match in [regex]::Matches($pathValue, '(?=/(?:specs|reports|plugins|domain)/)')) {
        $suffix = $pathValue.Substring($match.Index + 1)
        if ($suffix -cmatch '^specs/[a-z0-9][a-z0-9-]*/[^/]+$' -or
            $suffix -ceq 'domain/context-map.md' -or $suffix -ceq 'domain/domain-contract.json' -or
            $suffix -cmatch '^reports/(spec|impl|task)-review/[a-z0-9][a-z0-9-]*/attempt-[1-9][0-9]*/round-[1-9][0-9]*/[^/]+$' -or
            $suffix -cmatch '^plugins/[a-z0-9][a-z0-9-]*/references/[^/]+$') {
          [void]$candidates.Add($pathValue.Substring(0, $match.Index))
        }
      }
      if ($candidates.Count -ne 1) { return '__INVALID__' }
      foreach ($candidate in $candidates) { [void]$roots.Add($candidate) }
    }
  }
  if ($roots.Count -gt 1) { return '__INVALID__' }
  foreach ($recorded in $roots) { return $recorded }
  return ''
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
$RecoverInterrupted = ''
# Preserve exact spelling for this new option; normal named-parameter binding is
# case-insensitive and would otherwise accept aliases/prefixes before validation.
if ($AdditionalArguments.Count -gt 0) {
  if ($AdditionalArguments.Count -eq 1 -and $AdditionalArguments[0] -cmatch '^--edit-summary=(.*)$' -and -not $EditSummary) {
    $EditSummary = $Matches[1]
  } elseif ($AdditionalArguments.Count -eq 2 -and $AdditionalArguments[0] -ceq '-RecoverInterrupted' -and -not [string]::IsNullOrEmpty($AdditionalArguments[1])) {
    $RecoverInterrupted = $AdditionalArguments[1]
  } else { Fail 'unknown, duplicate or mis-cased recovery option' }
}
if ($EditSummary -cmatch '^--edit-summary=(.*)$') { $EditSummary = $Matches[1] }
if (Test-OrdinalEqual $EditSummary '--reset') { $EditSummary = ''; $Reset = $true }

if ($Feature -cnotmatch '^[a-z0-9][a-z0-9-]*$') { Fail 'invalid feature slug' }
if ($Attempt -notmatch '^[1-9][0-9]*$') { Fail 'attempt must be a positive integer' }
if ($Round -notmatch '^[1-9][0-9]*$') { Fail 'round must be a positive integer' }
$attemptInt = [int64]$Attempt
$roundInt = [int64]$Round
if ($roundInt -gt 3) { Fail 'round must be between 1 and 3' }
if (-not ([string]::IsNullOrEmpty($EditSummary)) -and $roundInt -le 1) { Fail '--edit-summary is valid only after round 1' }
if ($RecoverInterrupted) {
  if ($Reset -or $VerifyInputs -or $EditSummary -or $FixedInputRecord -or $FixedInputSnapshot) { Fail 'recovery cannot be combined with other transition options' }
  if ($attemptInt -le 1 -or $roundInt -ne 1) { Fail 'recovery starts only attempt N+1 round 1' }
}
if ($VerifyInputs -and ($EditSummary -or $Reset)) { Fail '-VerifyInputs cannot be combined with transition options' }
if (-not $VerifyInputs -and $roundInt -gt 1) {
  if ([string]::IsNullOrEmpty(($EditSummary -replace '\s', ''))) { Fail 'rounds 2 and 3 require a non-empty --edit-summary' }
}
if ($VerifyInputs) {
  # Verify a persisted round without changing its inputs or evidence.
} elseif ($RecoverInterrupted) {
  # Explicit recovery has its own source predicate, never the reset verdict rule.
} elseif ($Reset) {
  if (-not ($attemptInt -gt 1 -and $roundInt -eq 1)) { Fail '--reset starts only attempt N+1 round 1' }
} else {
  if (-not ($attemptInt -eq 1 -or $roundInt -gt 1)) { Fail 'a new attempt requires --reset' }
}

$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
. (Join-Path $PSScriptRoot 'lib/fixed-input-source.ps1')
$fixedSources = Get-FixedInputSources $root $FixedInputRecord $FixedInputSnapshot ([bool]$VerifyInputs)
$specsRoot = Join-Path $root 'specs'
$reportsRoot = Join-Path $root 'reports'
$reportsBase = Join-Path $reportsRoot 'spec-review'
$specDir = Join-Path $root "specs/$Feature"
$requirements = Join-Path $specDir 'requirements.md'
$acceptance = Join-Path $specDir 'acceptance-tests.md'
$calibration = Join-Path $root 'plugins/sdd-review-loop/references/spec-review-calibration.md'
$investigation = Join-Path $specDir 'investigation.md'
if ($null -ne $fixedSources) {
  $requirements = Get-ReviewInputSource $root "specs/$Feature/requirements.md" $fixedSources
  $acceptance = Get-ReviewInputSource $root "specs/$Feature/acceptance-tests.md" $fixedSources
  $calibration = Get-ReviewInputSource $root 'plugins/sdd-review-loop/references/spec-review-calibration.md' $fixedSources
  $specDir = Split-Path -Parent $requirements
  $specsRoot = Split-Path -Parent $specDir
  $investigation = Join-Path $specDir 'investigation.md'
}
$reportRoot = Join-Path $reportsBase $Feature
$reportDir = Join-Path $reportRoot (Join-Path "attempt-$attemptInt" "round-$roundInt")

if (-not (Test-RealDirectory $specsRoot)) { Fail 'specs root must be a real directory' }
if (-not (Test-OrdinalEqual (Get-CanonicalDir $specsRoot) $specsRoot)) { Fail 'specs root escapes repository' }
if (-not (Test-RealDirectory $specDir)) { Fail 'feature specification directory must not be a symlink' }
if (-not (Test-OrdinalEqual (Get-CanonicalDir $specDir) $specDir)) { Fail 'feature specification directory escapes repository' }
if (-not (Test-Path -LiteralPath $requirements -PathType Leaf) -or (Test-IsSymlink $requirements)) { Fail 'requirements.md must be a regular non-symlink file' }
if (-not (Test-Path -LiteralPath $acceptance -PathType Leaf) -or (Test-IsSymlink $acceptance)) { Fail 'acceptance-tests.md must be a regular non-symlink file' }
if ((Test-Path -LiteralPath $investigation) -or (Test-IsSymlink $investigation)) {
  if (-not (Test-Path -LiteralPath $investigation -PathType Leaf) -or (Test-IsSymlink $investigation)) { Fail 'investigation.md must be a regular non-symlink file' }
}
if (-not (Test-Path -LiteralPath $calibration -PathType Leaf) -or (Test-IsSymlink $calibration)) { Fail 'spec review calibration reference must be a regular non-symlink file' }
if (-not (Test-RealDirectory $reportsRoot)) { Fail 'reports root must be a real directory' }
if (-not (Test-OrdinalEqual (Get-CanonicalDir $reportsRoot) $reportsRoot)) { Fail 'reports root escapes repository' }
if (Test-Path -LiteralPath $reportsBase) {
  if (-not (Test-RealDirectory $reportsBase)) { Fail 'spec-review report base must not be a symlink' }
  if (-not (Test-OrdinalEqual (Get-CanonicalDir $reportsBase) $reportsBase)) { Fail 'spec-review report base escapes reports root' }
}

$statusMatch = Select-String -LiteralPath $requirements -CaseSensitive -Pattern '^Spec-Review-Status:\s*(.*)$' | Select-Object -First 1
$status = if ($statusMatch) { ($statusMatch.Matches[0].Groups[1].Value -replace '\s', '') } else { '' }
if ($VerifyInputs) {
  # Saved status is checked against the precheck below.
} elseif ($Reset) {
  if (-not (Test-OrdinalEqual $status 'Pending') -and -not (Test-OrdinalEqual $status 'Passed')) { Fail 'requirements.md must declare a resettable Spec-Review-Status' }
} else {
  if (-not (Test-OrdinalEqual $status 'Pending')) { Fail 'requirements.md must declare Spec-Review-Status: Pending' }
}
if (Test-IsSymlink $reportRoot) { Fail 'report root must not be a symlink' }
if (-not $VerifyInputs -and (Test-Path -LiteralPath $reportDir)) { Fail 'round destination already exists (replay is forbidden)' }

$requirementsSha = Get-Sha256File $requirements
$acceptanceSha = Get-Sha256File $acceptance
$calibrationSha = Get-Sha256File $calibration
$investigationSha = if (Test-Path -LiteralPath $investigation -PathType Leaf) { Get-Sha256File $investigation } else { '' }
$inputSha = if ([string]::IsNullOrEmpty($investigationSha)) { Get-Sha256Text "${requirementsSha}:${acceptanceSha}" } else { Get-Sha256Text "${requirementsSha}:${acceptanceSha}:${investigationSha}" }

if ($VerifyInputs) {
  $attemptDir = Join-Path $reportRoot "attempt-$attemptInt"
  $precheckPath = Join-Path $reportDir 'precheck-result.json'
  if (-not (Test-RealDirectory $reportRoot) -or -not (Test-OrdinalEqual (Get-CanonicalDir $reportRoot) $reportRoot)) { Fail 'report root is missing or substituted' }
  if (-not (Test-RealDirectory $attemptDir) -or -not (Test-OrdinalEqual (Get-CanonicalDir $attemptDir) $attemptDir)) { Fail 'attempt directory is missing or substituted' }
  if (-not (Test-RealDirectory $reportDir) -or -not (Test-OrdinalEqual (Get-CanonicalDir $reportDir) $reportDir)) { Fail 'round directory is missing or substituted' }
  if (-not (Test-Path -LiteralPath $precheckPath -PathType Leaf) -or (Test-IsSymlink $precheckPath)) { Fail 'precheck evidence is missing or substituted' }
  Assert-SavedRecoveryReference $root $precheckPath
  try { $precheck = Get-Content -LiteralPath $precheckPath -Raw | ConvertFrom-Json } catch { Fail 'precheck evidence is not valid JSON' }
  $baseKeys = @('acceptance_sha256','attempt','calibration_sha256','edit_summary','feature','generated_at','input_sha256','investigation_sha256','requirements_sha256','reset','round','schema','spec_review_status_field','stage')
  if (@($precheck.PSObject.Properties.Name) -ccontains 'recovery') { $baseKeys += 'recovery' }
  if (-not (Test-KeysExact $precheck $baseKeys)) { Fail 'precheck evidence has invalid fields' }
  $investigationMatches = if ($investigationSha) { Test-OrdinalEqual $precheck.investigation_sha256 $investigationSha } else { $null -eq $precheck.investigation_sha256 }
  if (-not (Test-OrdinalEqual $precheck.schema 'spec-review-precheck/v1') -or
      -not (Test-OrdinalEqual $precheck.stage 'spec') -or
      -not (Test-OrdinalEqual $precheck.feature $Feature) -or
      -not (Test-JsonIntegerEquals $precheck.attempt $attemptInt) -or
      -not (Test-JsonIntegerEquals $precheck.round $roundInt) -or
      -not (Test-OrdinalEqual $precheck.spec_review_status_field $status) -or
      -not (Test-OrdinalEqual $precheck.requirements_sha256 $requirementsSha) -or
      -not (Test-OrdinalEqual $precheck.acceptance_sha256 $acceptanceSha) -or
      -not (Test-OrdinalEqual $precheck.calibration_sha256 $calibrationSha) -or
      -not $investigationMatches -or
      -not (Test-OrdinalEqual $precheck.input_sha256 $inputSha) -or
      $precheck.edit_summary -isnot [string] -or $precheck.reset -isnot [bool] -or
      -not (Test-IsStringLike $precheck.generated_at)) {
    Fail 'review inputs or precheck identity changed after precheck'
  }
  Write-Output 'spec-review-precheck: inputs verified for reviewer invocation.'
  exit 0
}

# --- validate_reviewer_output translation ----------------------------------
function Test-ValidateReviewerOutput(
  [string]$OutputPath,
  [string]$Role,
  [array]$ExpectedManifestSorted,
  [string]$RunId,
  [string]$HostSessionId,
  [string]$RecordedRoot
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

  $actualManifest = @($data.allowed_input_manifest | ForEach-Object {
    [pscustomobject]@{ path = (Get-ManifestLocalPath $_.path $RecordedRoot); sha256 = $_.sha256 }
  } | Sort-Object path)
  if (-not (Test-ManifestArraysEqual $actualManifest $ExpectedManifestSorted)) { return $false }

  $expectedIds = $null
  switch ($Role) {
    'spec-reviewer-a' { $expectedIds = @('REQ-TESTABILITY', 'GOAL-AC-TRACE', 'AC-OBSERVABLE', 'SCOPE-BOUNDARY', 'CONSTRAINTS-EXPLICIT', 'RISK-VALIDATION-SURFACE', 'DOMAIN-CONFORMANCE') }
    'spec-reviewer-b' { $expectedIds = @('AMBIGUITY', 'CONTRADICTION', 'EDGE-CASE-COVERAGE', 'ASSUMPTIONS-RESOLVABLE', 'APPROVAL-BOUNDARY', 'DOWNSTREAM-READINESS', 'DOMAIN-CONFORMANCE') }
    default { return $false }
  }
  $actualIds = @($data.checks | ForEach-Object { $_.id })
  if (($actualIds -join ',') -cne ($expectedIds -join ',')) { return $false }

  # Verdict/finding coherence is checked, not derived. The role documents are
  # authoritative on the verdict choice (epic-191-a3 a2r1 escalation,
  # 2026-08-11): review-context-boundary.md defines BLOCKED as a launch or
  # boundary failure -- the review could not be validly conducted -- and no
  # role document states a severity-to-verdict formula. A reviewer that
  # conducted its review and recorded at least one FAIL, of any severity, has
  # earned the choice between NEEDS_WORK and BLOCKED; content severity and
  # procedural blockage are different questions. The previous rule here
  # mechanically forced FAIL/Critical to BLOCKED and rejected a persisted
  # NEEDS_WORK verbatim record, deadlocking every subsequent round and reset
  # of the same attempt chain.
  #
  # Narrowed, not removed. The two shapes that are incoherent on any reading
  # are still rejected: a declared PASS carrying any FAIL, and a declared
  # NEEDS_WORK or BLOCKED carrying none.
  $anyFail = @($data.checks | Where-Object { $_.result -ceq 'FAIL' })
  if ($anyFail.Count -gt 0) {
    return ((Test-OrdinalEqual $data.verdict 'NEEDS_WORK') -or (Test-OrdinalEqual $data.verdict 'BLOCKED'))
  }
  return (Test-OrdinalEqual $data.verdict 'PASS')
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
  $recordedRoot = Get-ManifestRecordedRoot $contract
  if ($recordedRoot -ceq '__INVALID__') { return $false }
  foreach ($reviewer in @($contract.reviewers)) {
    if (-not (Test-ManifestArrayValid $reviewer.allowed_input_manifest)) { return $false }
    foreach ($entry in @($reviewer.allowed_input_manifest)) {
      $entry.path = Get-ManifestLocalPath $entry.path $recordedRoot
    }
  }
  $precheck = $null
  try { $precheck = Get-Content -LiteralPath $PrecheckPath -Raw | ConvertFrom-Json } catch { return $false }
  $investigationPath = Get-ManifestLocalPath (Join-Path $specDir 'investigation.md') ''
  $contractManifestInvestigationHashes = @()
  foreach ($reviewer in @($contract.reviewers)) {
    foreach ($entry in @($reviewer.allowed_input_manifest)) {
      if (Test-OrdinalEqual $entry.path $investigationPath) { $contractManifestInvestigationHashes += [string]$entry.sha256 }
    }
  }
  $uniqueContractManifestInvestigationHashes = @($contractManifestInvestigationHashes | Select-Object -Unique)
  $contractManifestInvestigationHash = if ($uniqueContractManifestInvestigationHashes.Count -eq 1) { $uniqueContractManifestInvestigationHashes[0] } else { '' }
  $priorInvestigationSha = if ($null -eq $precheck.investigation_sha256) { '' } else { [string]$precheck.investigation_sha256 }
  $legacyContractKeys = @('acceptance_sha256', 'attempt', 'feature', 'requirements_sha256', 'reviewers', 'round', 'run_id', 'schema', 'stage', 'verdict', 'warningCount')
  $investigationContractKeys = @('acceptance_sha256', 'attempt', 'feature', 'investigation_sha256', 'requirements_sha256', 'reviewers', 'round', 'run_id', 'schema', 'stage', 'verdict', 'warningCount')
  if ([string]::IsNullOrEmpty($priorInvestigationSha)) {
    if (-not (Test-KeysExact $contract $legacyContractKeys) -and
        (-not (Test-KeysExact $contract $investigationContractKeys) -or $null -ne $contract.investigation_sha256)) { return $false }
  } else {
    if (Test-KeysExact $contract $investigationContractKeys) {
      if (-not (Test-OrdinalEqual $contract.investigation_sha256 $priorInvestigationSha)) { return $false }
    } elseif (Test-KeysExact $contract $legacyContractKeys) {
      if (-not [string]::IsNullOrEmpty($contractManifestInvestigationHash) -and
          -not (Test-OrdinalEqual $contractManifestInvestigationHash $priorInvestigationSha)) { return $false }
    } else { return $false }
  }
  if (-not (Test-OrdinalEqual $contract.schema 'spec-review-contract/v1')) { return $false }
  if (-not (Test-OrdinalEqual $contract.stage 'spec')) { return $false }
  if (-not (Test-OrdinalEqual $contract.feature $Feature)) { return $false }
  if (-not (Test-JsonIntegerEquals $contract.attempt $ExpectedAttempt)) { return $false }
  if (-not (Test-JsonIntegerEquals $contract.round $ExpectedRound)) { return $false }
  if (-not (Test-OrdinalEqual $contract.verdict $ExpectedVerdict)) { return $false }
  if (-not (Test-IsSha256 $contract.requirements_sha256)) { return $false }
  if (-not (Test-IsSha256 $contract.acceptance_sha256)) { return $false }
  if ($null -ne $contract.investigation_sha256 -and -not (Test-IsSha256 $contract.investigation_sha256)) { return $false }
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

  if (-not (Test-OrdinalEqual $precheck.schema 'spec-review-precheck/v1')) { return $false }
  if (-not (Test-OrdinalEqual $precheck.stage 'spec')) { return $false }
  if (-not (Test-OrdinalEqual $precheck.feature $Feature)) { return $false }
  if (-not (Test-JsonIntegerEquals $precheck.attempt $ExpectedAttempt)) { return $false }
  if (-not (Test-JsonIntegerEquals $precheck.round $ExpectedRound)) { return $false }
  if (-not (Test-OrdinalEqual $precheck.requirements_sha256 $contract.requirements_sha256)) { return $false }
  if (-not (Test-OrdinalEqual $precheck.acceptance_sha256 $contract.acceptance_sha256)) { return $false }
  if (-not ($null -eq $precheck.calibration_sha256 -or (Test-IsSha256 $precheck.calibration_sha256))) { return $false }
  if (-not ($null -eq $precheck.investigation_sha256 -or (Test-IsSha256 $precheck.investigation_sha256))) { return $false }
  $contractInvestigationHash = if ($null -eq $contract.investigation_sha256) { $contractManifestInvestigationHash } else { [string]$contract.investigation_sha256 }
  $precheckInvestigationHash = if ($null -eq $precheck.investigation_sha256) { '' } else { [string]$precheck.investigation_sha256 }
  if (-not [string]::IsNullOrEmpty($precheckInvestigationHash) -and -not [string]::IsNullOrEmpty($contractInvestigationHash) -and -not (Test-OrdinalEqual $contractInvestigationHash $precheckInvestigationHash)) { return $false }

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
      if (Test-OrdinalEqual $entry.path (Get-ManifestLocalPath $calibration '')) { $calibrationHashes += [string]$entry.sha256 }
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
  # investigation.md is derived from the contract, exactly like $calibrationHash
  # above -- never from the live working tree. Every other entry in this expected
  # manifest already comes from an immutable source: requirements/acceptance from
  # the contract's own top-level fields, precheck-result.json from a frozen round
  # artifact, calibration from the manifest itself. investigation.md was the lone
  # outlier, and it is the single worst file to read live: by design it is the
  # document that accumulates the amendment record ACROSS stages, so it grows
  # after a round is sealed as a matter of course. Reading it live compared
  # today's bytes against the correctly-pinned ones, mismatched, and refused
  # -Reset with 'previous terminal contract is invalid' -- permanently, since
  # nothing can un-grow the file (reproduced on epic-195). A sealed contract is
  # evidence about the past; validating it against the present is a category
  # error. The live-vs-pinned question belongs to check-workflow-state.ps1, which
  # asks it deliberately and carries the amendment-record growth tolerance for
  # exactly this file.
  #
  # Same discipline as calibration: every reviewer that pinned the file must have
  # pinned the SAME bytes (the unique set must collapse to one value), and that
  # value must be a well-formed digest. A contract in which reviewer A and
  # reviewer B disagree about what they read is not a valid contract. Absent from
  # the manifest entirely means the reviewers declared they did not read it,
  # which is legal, so nothing is expected. There is no cross-check against
  # precheck-result.json here because the precheck schema records no
  # investigation_sha256 field -- unlike calibration_sha256 -- so the 'if the
  # precheck records it' clause has nothing to compare against.
  $investigationHashes = @()
  foreach ($reviewer in $reviewers) {
    foreach ($entry in @($reviewer.allowed_input_manifest)) {
      if (Test-OrdinalEqual $entry.path $investigationPath) { $investigationHashes += [string]$entry.sha256 }
    }
  }
  $uniqueInvestigationHashes = @($investigationHashes | Select-Object -Unique)
  if ($uniqueInvestigationHashes.Count -gt 1) { return $false }
  if ($uniqueInvestigationHashes.Count -eq 1) {
    $investigationHash = $uniqueInvestigationHashes[0]
    if (-not (Test-IsSha256 $investigationHash)) { return $false }
    if (-not [string]::IsNullOrEmpty($contractInvestigationHash) -and -not (Test-OrdinalEqual $contractInvestigationHash $investigationHash)) { return $false }
    $expectedAList.Add([pscustomobject]@{ path = $investigationPath; sha256 = $investigationHash })
  }
  $researchConditionals = @($reviewers | Where-Object { Test-OrdinalEqual $_.role 'spec-reviewer-a' } |
    ForEach-Object { $_.allowed_input_manifest } | ForEach-Object {
      $local = (Get-ManifestLocalPath ([string]$_.path) '').Replace('\', '/')
      $prefix = $root.Replace('\', '/').TrimEnd('/') + '/'
      $relative = if ($local.StartsWith($prefix, [StringComparison]::Ordinal)) { $local.Substring($prefix.Length) } else { '' }
      if ($relative -cmatch ('^specs/' + [Regex]::Escape($Feature) + '/research/(review-input\.json|relations\.json|records/research-evidence\.json)$') -or
          $relative -cmatch '^docs/adr/[0-9]{4}-[a-z0-9-]+\.md$') { $relative }
    })
  foreach ($relative in @('domain/context-map.md', 'domain/domain-contract.json') + $researchConditionals) {
    $conditionalPath = Get-ManifestLocalPath $relative ''
    $entries = @($reviewers | Where-Object { Test-OrdinalEqual $_.role 'spec-reviewer-a' } |
      ForEach-Object { $_.allowed_input_manifest } |
      Where-Object { Test-OrdinalEqual $_.path $conditionalPath })
    if ($entries.Count -gt 1) { return $false }
    if ($entries.Count -eq 1) {
      if (-not (Test-IsSha256 $entries[0].sha256)) { return $false }
      $expectedAList.Add([pscustomobject]@{ path = $conditionalPath; sha256 = $entries[0].sha256 })
    }
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

  if (-not (Test-ValidateReviewerOutput $reviewerAPath 'spec-reviewer-a' $expectedA $aRun $aSession $recordedRoot)) { return $false }
  if (-not (Test-ValidateReviewerOutput $reviewerBPath 'spec-reviewer-b' $expectedB $bRun $bSession $recordedRoot)) { return $false }

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

# The orchestrator establishes human origin; these predicates check content only.
function Assert-Recovery([bool]$Condition, [string]$Reason) {
  if (-not $Condition) { throw "interrupted recovery: $Reason" }
}

function Get-RecoveryText([string]$Path) {
  return [Text.UTF8Encoding]::new($false, $true).GetString([IO.File]::ReadAllBytes($Path))
}

function Get-RecoveryLines([string]$Path) {
  $reader = [IO.StringReader]::new((Get-RecoveryText $Path))
  $lines = [Collections.Generic.List[string]]::new()
  try { while ($null -ne ($line = $reader.ReadLine())) { $lines.Add($line) } }
  finally { $reader.Dispose() }
  return ,($lines.ToArray())
}

function ConvertFrom-RecoveryElement([System.Text.Json.JsonElement]$Element) {
  switch ($Element.ValueKind) {
    Object {
      $value = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
      foreach ($property in $Element.EnumerateObject()) {
        Assert-Recovery (-not $value.ContainsKey($property.Name)) 'duplicate JSON member'
        $value.Add($property.Name, (ConvertFrom-RecoveryElement $property.Value))
      }
      return $value
    }
    Array {
      $value = [Collections.Generic.List[object]]::new()
      foreach ($item in $Element.EnumerateArray()) { $value.Add((ConvertFrom-RecoveryElement $item)) }
      return ,($value.ToArray())
    }
    String { return $Element.GetString() }
    Number {
      $text = $Element.GetRawText()
      if ($text -cmatch '[.eE]') {
        $value = $Element.GetDouble()
        Assert-Recovery (-not [double]::IsNaN($value) -and -not [double]::IsInfinity($value)) 'JSON number overflow'
        return $value
      }
      [long]$integer = 0
      if ($Element.TryGetInt64([ref]$integer)) { return $integer }
      return [System.Numerics.BigInteger]::Parse($text, [Globalization.CultureInfo]::InvariantCulture)
    }
    True { return $true }
    False { return $false }
    Null { return $null }
    default { throw 'unsupported JSON token' }
  }
}

function Read-RecoveryJson([string]$Path) {
  $text = Get-RecoveryText $Path
  $document = [System.Text.Json.JsonDocument]::Parse($text)
  try { return ConvertFrom-RecoveryElement $document.RootElement } finally { $document.Dispose() }
}

function Assert-RecoveryKeys($Object, [string[]]$Keys) {
  Assert-Recovery ($Object -is [Collections.IDictionary]) 'closed record object type'
  Assert-Recovery ($Object.Count -eq $Keys.Count) 'closed record field count'
  foreach ($key in $Object.Keys) { Assert-Recovery ($Keys -ccontains $key) 'closed record member' }
}

function Test-RecoveryInteger($Value) {
  return ($Value -is [long] -or $Value -is [int]) -and $Value -gt 0
}

function Get-RecoveryPath($Path, [switch]$Directory) {
  Assert-Recovery ($Path -is [string] -and $Path.Length -gt 0 -and $Path -cnotmatch '[\\\x00-\x1f\x7f:]') 'invalid reference path'
  $current = $root
  foreach ($part in $Path.Split('/')) {
    Assert-Recovery (@('', '.', '..') -cnotcontains $part) 'noncanonical reference path'
    $parent = $current; $current = Join-Path $current $part
    $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
    Assert-Recovery (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'linked reference component'
    $matched = @([IO.Directory]::EnumerateFileSystemEntries($parent) | Where-Object { [string]::Equals([IO.Path]::GetFileName($_), $part, [StringComparison]::Ordinal) })
    Assert-Recovery ($matched.Count -eq 1) 'reference case differs from directory entry'
  }
  Assert-Recovery ((Test-Path -LiteralPath $current -PathType Container) -eq [bool]$Directory) 'reference type'
  if (-not $Directory) { Assert-Recovery (Test-Path -LiteralPath $current -PathType Leaf) 'reference not a file' }
  return $current
}

function Assert-RecoveryReference($Reference) {
  Assert-RecoveryKeys $Reference @('path', 'sha256')
  Assert-Recovery (Test-IsSha256 $Reference.sha256) 'reference SHA256 format'
  $path = Get-RecoveryPath $Reference.path
  Assert-Recovery ((Get-Sha256File $path) -ceq $Reference.sha256) 'reference SHA256 mismatch'
}

function Assert-RecoveryReferences($References, [int]$Count) {
  Assert-Recovery ($References -is [array] -and $References.Count -eq $Count) 'reference inventory size'
  $previous = $null
  foreach ($reference in $References) {
    Assert-RecoveryReference $reference
    if ($null -ne $previous) { Assert-Recovery ([StringComparer]::Ordinal.Compare($previous, $reference.path) -lt 0) 'reference order or duplicate' }
    $previous = $reference.path
  }
}

function ConvertTo-RecoveryCanonical($Value) {
  if ($null -eq $Value) { return 'null' }
  if ($Value -is [string]) {
    $builder = [Text.StringBuilder]::new(); [void]$builder.Append('"')
    foreach ($character in $Value.ToCharArray()) {
      $code = [int]$character
      $escape = switch ($code) { 34 { '\"' } 92 { '\\' } 8 { '\b' } 9 { '\t' } 10 { '\n' } 12 { '\f' } 13 { '\r' } default { $null } }
      if ($null -ne $escape) { [void]$builder.Append($escape) }
      elseif ($code -lt 32 -or $code -ge 127) { [void]$builder.Append(('\u{0:x4}' -f $code)) }
      else { [void]$builder.Append($character) }
    }
    [void]$builder.Append('"'); return $builder.ToString()
  }
  if ($Value -is [Collections.IDictionary]) {
    [string[]]$keys = @($Value.Keys); [Array]::Sort($keys, [StringComparer]::Ordinal)
    return '{' + ((@($keys | ForEach-Object { (ConvertTo-RecoveryCanonical $_) + ':' + (ConvertTo-RecoveryCanonical $Value[$_]) })) -join ',') + '}'
  }
  if ($Value -is [array]) { return '[' + ((@($Value | ForEach-Object { ConvertTo-RecoveryCanonical $_ })) -join ',') + ']' }
  if ($Value -is [bool]) { if ($Value) { return 'true' } else { return 'false' } }
  return $Value.ToString([Globalization.CultureInfo]::InvariantCulture)
}

function Get-RecoveryRelative($Path) {
  Assert-Recovery ($Path -is [string]) 'invocation path type'
  $value = $Path.Replace('\', '/')
  $prefix = $root.Replace('\', '/').TrimEnd('/') + '/'
  if ($value.StartsWith($prefix, [StringComparison]::Ordinal)) { $value = $value.Substring($prefix.Length) }
  Assert-Recovery ($value -cmatch '^[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*\z' -and @($value.Split('/') | Where-Object { $_ -ceq '.' -or $_ -ceq '..' }).Count -eq 0) 'ambiguous invocation path'
  $sourcePrecheck = "$source/precheck-result.json"
  if ($value.Equals($sourcePrecheck, [StringComparison]::OrdinalIgnoreCase) -or $value.EndsWith('/' + $sourcePrecheck, [StringComparison]::OrdinalIgnoreCase)) {
    Assert-Recovery ($value -ceq $sourcePrecheck) 'ambiguous source invocation path'
  }
  return $value
}

function Get-RecoveryInputBinding($Inputs) {
  return Get-Sha256Text ((@($Inputs | ForEach-Object { $_.path + "`t" + $_.sha256 })) -join "`n")
}

function Test-InterruptedRecovery([string]$RecordPath) {
  try {
    $relativeRecord = $RecordPath
    if ([IO.Path]::IsPathRooted($RecordPath)) { $relativeRecord = [IO.Path]::GetRelativePath($root, $RecordPath).Replace('\', '/') }
    $data = Read-RecoveryJson (Get-RecoveryPath $relativeRecord)
    Assert-RecoveryKeys $data @('schema','feature','source','target','authorization','previous_contract','interrupted_precheck','pinned_inputs','interrupted_artifacts','reviewer_a')
    Assert-Recovery ($data.schema -is [string] -and $data.schema -ceq 'spec-review-interrupted-recovery/v1') 'recovery schema'
    Assert-Recovery ($data.feature -is [string] -and $data.feature -cmatch '^[a-z0-9][a-z0-9-]*$' -and $data.feature -ceq $Feature) 'recovery feature'
    foreach ($side in @('source','target')) {
      Assert-RecoveryKeys $data[$side] @('attempt','round')
      foreach ($value in $data[$side].Values) { Assert-Recovery (Test-RecoveryInteger $value) 'recovery integer type' }
    }
    $n = $data.source.attempt; $r = $data.source.round
    Assert-Recovery ($r -in @(2,3) -and $data.target.attempt -eq $attemptInt -and $data.target.round -eq $roundInt -and $attemptInt -eq $n+1 -and $roundInt -eq 1) 'source/target transition'
    $report = "reports/spec-review/$Feature"; $source = "$report/attempt-$n/round-$r"; $prior = "$report/attempt-$n/round-$($r-1)"
    $attemptDirectory = Get-RecoveryPath "$report/attempt-$n" -Directory
    $rounds = @([IO.Directory]::EnumerateFileSystemEntries($attemptDirectory) | ForEach-Object { $name=[IO.Path]::GetFileName($_); if ($name -cmatch '^round-([1-3])$') { [int]$Matches[1] } })
    Assert-Recovery ($rounds.Count -gt 0 -and ($rounds | Measure-Object -Maximum).Maximum -eq $r) 'source is not latest round'
    $statusLines = @((Get-RecoveryLines (Get-RecoveryPath "specs/$Feature/requirements.md")) | Where-Object { $_.StartsWith('Spec-Review-Status:',[StringComparison]::Ordinal) })
    Assert-Recovery ($statusLines.Count -eq 1 -and $statusLines[0] -ceq 'Spec-Review-Status: Pending') 'source status is not exactly Pending'
    foreach ($slot in @('authorization','previous_contract','interrupted_precheck')) { Assert-RecoveryReference $data[$slot] }
    Assert-Recovery ($data.previous_contract.path -ceq "$prior/spec-review-contract.json") 'prior contract canonical path'
    Assert-Recovery ($data.interrupted_precheck.path -ceq "$source/precheck-result.json") 'source precheck canonical path'
    Assert-RecoveryReferences $data.pinned_inputs 4; Assert-RecoveryReferences $data.interrupted_artifacts 6
    $calibrationRelative = 'plugins/sdd-review-loop/references/spec-review-calibration.md'
    $expectedInputs = @("specs/$Feature/requirements.md","specs/$Feature/acceptance-tests.md","specs/$Feature/investigation.md",$calibrationRelative)
    $pins = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    foreach ($pin in $data.pinned_inputs) { Assert-Recovery ($expectedInputs -ccontains $pin.path) 'canonical input path'; $pins.Add($pin.path,$pin.sha256) }
    $localNames = @('precheck-result.json','reviewer-a.json','reviewer-a-reservation.txt','reviewer-a-host-receipt.json','spec-review-report.md')
    $invocationPath = "reports/review-context/$Feature-spec-a${n}r${r}-a-invocation.json"
    $expectedInventory = @($localNames | ForEach-Object { "$source/$_" }) + @($invocationPath)
    $inventory = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    foreach ($pin in $data.interrupted_artifacts) { Assert-Recovery ($expectedInventory -ccontains $pin.path) 'canonical interrupted inventory'; $inventory.Add($pin.path,$pin.sha256) }
    $sourceDirectory = Get-RecoveryPath $source -Directory
    $entries = @([IO.Directory]::EnumerateFileSystemEntries($sourceDirectory))
    Assert-Recovery ($entries.Count -eq 5) 'unexpected interrupted source entry'
    foreach ($entry in $entries) { Assert-Recovery ($localNames -ccontains [IO.Path]::GetFileName($entry)) 'unexpected interrupted source filename' }
    Assert-Recovery ($data.interrupted_precheck.sha256 -ceq $inventory["$source/precheck-result.json"]) 'repeated precheck pin'
    $a = $data.reviewer_a
    Assert-RecoveryKeys $a @('invocation','sequence','stage','role','run_id','host_session_id','record_sha256')
    Assert-Recovery ((Test-RecoveryInteger $a.sequence) -and $a.stage -is [string] -and $a.stage -ceq 'spec' -and $a.role -is [string] -and $a.role -ceq 'spec-reviewer-a') 'reviewer identity shape'
    Assert-Recovery ((Test-NonEmptyString $a.run_id) -and (Test-NonEmptyString $a.host_session_id) -and (Test-IsSha256 $a.record_sha256)) 'reviewer identity values'
    Assert-RecoveryReference $a.invocation
    Assert-Recovery ($a.invocation.path -ceq $invocationPath -and $a.invocation.sha256 -ceq $inventory[$invocationPath]) 'repeated invocation pin'
    $body = [ordered]@{}; foreach ($key in $data.Keys) { if ($key -cne 'authorization') { $body[$key]=$data[$key] } }
    $expected = [ordered]@{'Feature'=$Feature;'Source Attempt'=[string]$n;'Source Round'=[string]$r;'Target Attempt'=[string]$attemptInt;'Target Round'='1';'Maximum Rounds'='3';'Decision'='Authorize interrupted A-before-B recovery';'Recovery Binding SHA256'=(Get-Sha256Text (ConvertTo-RecoveryCanonical $body))}
    $lines = Get-RecoveryLines (Get-RecoveryPath $data.authorization.path)
    foreach ($key in $expected.Keys) {
      $bound = @($lines | Where-Object { $_.StartsWith($key+':',[StringComparison]::Ordinal) })
      Assert-Recovery ($bound.Count -eq 1 -and $bound[0] -ceq ($key+': '+$expected[$key])) "authorization binding $key"
    }
    $pre = Read-RecoveryJson (Get-RecoveryPath "$source/precheck-result.json")
    foreach ($key in @('schema','stage','feature','spec_review_status_field','requirements_sha256','acceptance_sha256','investigation_sha256','calibration_sha256','input_sha256')) {
      Assert-Recovery ($pre[$key] -is [string]) 'interrupted precheck string type'
    }
    Assert-Recovery ($pre.schema -ceq 'spec-review-precheck/v1' -and $pre.stage -ceq 'spec' -and $pre.feature -ceq $Feature -and (Test-RecoveryInteger $pre.attempt) -and $pre.attempt -eq $n -and (Test-RecoveryInteger $pre.round) -and $pre.round -eq $r -and $pre.spec_review_status_field -ceq 'Pending') 'interrupted precheck identity'
    $hashes = @()
    foreach ($pair in @(@('requirements.md','requirements_sha256'),@('acceptance-tests.md','acceptance_sha256'),@('investigation.md','investigation_sha256'))) {
      $pin = $pins["specs/$Feature/$($pair[0])"]
      Assert-Recovery ($pre[$pair[1]] -ceq $pin) 'interrupted precheck input pin'; $hashes += $pin
    }
    Assert-Recovery ($pre.calibration_sha256 -ceq $pins[$calibrationRelative] -and $pre.input_sha256 -ceq (Get-Sha256Text ($hashes -join ':'))) 'interrupted precheck composite/calibration pin'
    $inv = Read-RecoveryJson (Get-RecoveryPath $invocationPath)
    Assert-Recovery ($inv.feature -is [string] -and $inv.feature -ceq $Feature) 'invocation feature'
    foreach ($key in @('sequence','stage','role','run_id','host_session_id')) {
      Assert-Recovery ($inv[$key].GetType() -eq $a[$key].GetType() -and $inv[$key] -ceq $a[$key]) 'invocation identity mismatch'
    }
    Assert-Recovery ($inv.allowed_input_manifest -is [array] -and $inv.allowed_input_manifest.Count -eq 5) 'invocation input manifest'
    $expectedManifest = [Collections.Generic.Dictionary[string,string]]::new($pins, [StringComparer]::Ordinal)
    $expectedManifest.Add($data.interrupted_precheck.path,$data.interrupted_precheck.sha256)
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($pin in $inv.allowed_input_manifest) {
      $path = Get-RecoveryRelative $pin.path
      Assert-Recovery ($seen.Add($path) -and $expectedManifest.ContainsKey($path) -and $expectedManifest[$path] -ceq $pin.sha256) 'invocation repeated input pins'
    }
    $raw = Read-RecoveryJson (Get-RecoveryPath "$source/reviewer-a.json")
    $hostReceipt = Read-RecoveryJson (Get-RecoveryPath "$source/reviewer-a-host-receipt.json")
    Assert-Recovery ($hostReceipt.review_execution_started -is [bool] -and -not $hostReceipt.review_execution_started -and $hostReceipt.sessionId -is [string] -and $hostReceipt.sessionId -ceq $a.host_session_id -and $hostReceipt.threadId -is [string] -and $hostReceipt.threadId -ceq $a.host_session_id) 'interruption host receipt'
    foreach ($key in @('schema','stage','role','run_id','host_session_id','verdict')) { Assert-Recovery ($raw[$key] -is [string]) 'interruption raw string type' }
    Assert-Recovery ($raw.schema -ceq 'spec-reviewer-a/v1' -and $raw.stage -ceq 'spec' -and $raw.role -ceq 'spec-reviewer-a' -and $raw.run_id -ceq $a.run_id -and $raw.host_session_id -ceq $a.host_session_id -and $raw.verdict -ceq 'BLOCKED') 'interruption raw identity/verdict'
    Assert-Recovery ((ConvertTo-RecoveryCanonical $raw.allowed_input_manifest) -ceq (ConvertTo-RecoveryCanonical $inv.allowed_input_manifest)) 'raw repeated input pins'
    Assert-Recovery ($raw.checks -is [array] -and $raw.checks.Count -gt 0) 'interruption diagnostic checks'
    foreach ($check in $raw.checks) {
      Assert-Recovery ($check.id -is [string] -and $check.result -is [string] -and $check.severity -is [string] -and $check.finding -is [string]) 'interruption diagnostic shape'
      $skip = $check.id -ceq 'DOMAIN-CONFORMANCE' -and $check.result -ceq 'SKIP' -and $check.finding.StartsWith('Explicit skip condition supplied:',[StringComparison]::Ordinal)
      $blocked = $check.result -ceq 'FAIL' -and $check.finding.StartsWith('Review blocked before substantive reading',[StringComparison]::Ordinal) -and ($check.finding.Contains('denied') -or $check.finding.Contains('unreadable'))
      Assert-Recovery ($skip -or $blocked) 'completed substantive reviewer output'
    }
    $reportText = Get-RecoveryText (Get-RecoveryPath "$source/spec-review-report.md")
    Assert-Recovery (($reportText -split '\r?\n') -ccontains 'Execution: BLOCKED before substantive review') 'source diagnostic execution'
    Assert-Recovery ($reportText.Contains('Reviewer B was not launched') -and $reportText -cnotmatch '(?m)^(?:VERDICT|Verdict|Integrated Verdict):') 'source diagnostic report'
    $ledger = Read-RecoveryJson (Get-RecoveryPath 'reports/review-context/identity-ledger.json')
    Assert-Recovery ($ledger.records -is [array]) 'ledger records'
    $matches = @($ledger.records | Where-Object { $_.run_id -ceq $a.run_id -and $_.host_session_id -ceq $a.host_session_id })
    Assert-Recovery ($matches.Count -eq 1) 'persisted A identity missing or duplicated'
    $persisted = $matches[0]
    foreach ($key in @('sequence','stage','role','run_id','host_session_id','record_sha256')) { Assert-Recovery ($persisted[$key].GetType() -eq $a[$key].GetType() -and $persisted[$key] -ceq $a[$key]) 'persisted A identity mismatch' }
    Assert-Recovery ($persisted.allowed_inputs_sha256 -ceq (Get-RecoveryInputBinding $inv.allowed_input_manifest)) 'persisted A input binding missing or changed'
    $receipt = Get-RecoveryLines (Get-RecoveryPath "$source/reviewer-a-reservation.txt")
    $expectedReceipt = "REVIEW_CONTEXT_OK $($a.record_sha256) sequence=$($a.sequence) previous_record_sha256=$($persisted.previous_record_sha256) pre_append_tip_sequence=$($a.sequence-1) identity_unique=yes"
    Assert-Recovery ($receipt.Count -eq 1 -and $receipt[0] -ceq $expectedReceipt) 'A reservation receipt facts'
    $invocations = @()
    foreach ($path in [IO.Directory]::EnumerateFileSystemEntries((Get-RecoveryPath 'reports/review-context' -Directory))) {
      $name = [IO.Path]::GetFileName($path)
      if (-not $name.EndsWith('-invocation.json',[StringComparison]::Ordinal)) { continue }
      if ($name.StartsWith("$Feature-spec-a${n}r${r}-",[StringComparison]::Ordinal)) {
        Assert-Recovery ($name -ceq [IO.Path]::GetFileName($invocationPath)) 'another canonical source launch'
      }
      $candidate = Read-RecoveryJson (Get-RecoveryPath "reports/review-context/$name")
      Assert-Recovery ($candidate.allowed_input_manifest -is [array]) 'invocation correlation inputs'
      $sourcePins = @($candidate.allowed_input_manifest | Where-Object { (Get-RecoveryRelative $_.path) -ceq "$source/precheck-result.json" })
      if ($sourcePins.Count -gt 0) {
        Assert-Recovery ($name -ceq [IO.Path]::GetFileName($invocationPath) -and (ConvertTo-RecoveryCanonical $candidate) -ceq (ConvertTo-RecoveryCanonical $inv)) 'another source invocation'
      }
      $invocations += ,$candidate
    }
    foreach ($other in $ledger.records) {
      if ($other.stage -cne 'spec' -or $other.run_id -ceq $a.run_id) { continue }
      $related = @($invocations | Where-Object { $_.run_id -ceq $other.run_id -and $_.host_session_id -ceq $other.host_session_id })
      Assert-Recovery ($related.Count -eq 1) 'ambiguous later spec reservation'
      $candidate = $related[0]
      Assert-Recovery ($other.allowed_inputs_sha256 -ceq (Get-RecoveryInputBinding $candidate.allowed_input_manifest)) 'uncorrelated later input binding'
      Assert-Recovery ($candidate.feature -is [string]) 'later spec feature type'
      $precheckPattern = '^reports/spec-review/' + [regex]::Escape($candidate.feature) + '/attempt-[1-9][0-9]*/round-[1-9][0-9]*/precheck-result\.json\z'
      $precheckPins = @($candidate.allowed_input_manifest | Where-Object { (Get-RecoveryRelative $_.path) -cmatch $precheckPattern })
      Assert-Recovery ($precheckPins.Count -eq 1) 'ambiguous later spec precheck'
      foreach ($pin in $candidate.allowed_input_manifest) { Assert-Recovery ((Get-RecoveryRelative $pin.path) -cne "$source/precheck-result.json") 'source reviewer already reserved' }
    }
    if (-not (Test-ValidateContract (Join-Path $root "$prior/spec-review-contract.json") $n ($r-1) NEEDS_WORK (Join-Path $root "$prior/precheck-result.json"))) { return $false }
    $rawManifest = @($inv.allowed_input_manifest | ForEach-Object { [pscustomobject]@{path=(Get-ManifestLocalPath $_.path '');sha256=$_.sha256} } | Sort-Object path)
    if (-not (Test-ValidateReviewerOutput (Join-Path $root "$source/reviewer-a.json") 'spec-reviewer-a' $rawManifest $a.run_id $a.host_session_id '')) { return $false }
    & (Join-Path $root 'plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1') -Manifest (Join-Path $root $invocationPath) -RepositoryRoot $root | Out-Null
    return $LASTEXITCODE -eq 0
  } catch { [Console]::Error.WriteLine($_.Exception.Message); return $false }
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
  $priorInvestigationSha = if ($null -eq $priorData.investigation_sha256) { '' } else { [string]$priorData.investigation_sha256 }
  if ([string]::IsNullOrEmpty($priorInvestigationSha)) {
    $priorRecordedRoot = Get-ManifestRecordedRoot $priorData
    $manifestInvestigationHashes = @()
    foreach ($reviewer in @($priorData.reviewers)) {
      foreach ($entry in @($reviewer.allowed_input_manifest)) {
        if (Test-OrdinalEqual (Get-ManifestLocalPath $entry.path $priorRecordedRoot) (Get-ManifestLocalPath $investigation '')) { $manifestInvestigationHashes += [string]$entry.sha256 }
      }
    }
    $uniqueManifestInvestigationHashes = @($manifestInvestigationHashes | Select-Object -Unique)
    if ($uniqueManifestInvestigationHashes.Count -eq 1) { $priorInvestigationSha = $uniqueManifestInvestigationHashes[0] }
  }
  if ((Test-OrdinalEqual $requirementsSha $priorRequirementsSha) -and (Test-OrdinalEqual $acceptanceSha $priorAcceptanceSha) -and (Test-OrdinalEqual $investigationSha $priorInvestigationSha)) {
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

$recoveryPath = ''; $recoverySha = ''
if ($RecoverInterrupted) {
  $recoveryPath = Get-RecoveryRelative $RecoverInterrupted
  if (-not (Test-InterruptedRecovery $recoveryPath)) { Fail 'interrupted recovery admission failed' }
  $recoverySha = Get-Sha256File (Join-Path $root $recoveryPath)
}

# Only after every pure validation succeeds may this script acquire a lock or
# create an evidence path. New-Item -ErrorAction Stop on the lock directory
# makes concurrent writers fail deterministically.
if ($recoveryPath) {
  # Recovery uses existing source parents, never creates them through a changed ancestor.
  foreach ($ancestor in @($reportsRoot,$reportsBase,$reportRoot)) {
    if (-not (Test-RealDirectory $ancestor) -or (Get-CanonicalDir $ancestor) -cne $ancestor) { Fail 'recovery report parent must remain a real contained directory' }
  }
} else {
New-Item -ItemType Directory -Path $reportsBase -Force | Out-Null
if ((Test-IsSymlink $reportsBase) -or -not (Test-OrdinalEqual (Get-CanonicalDir $reportsBase) $reportsBase)) { Fail 'spec-review report base escapes reports root' }
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
if (Test-IsSymlink $reportRoot) { Fail 'report root must not be a symlink' }
if (-not (Test-OrdinalEqual (Get-CanonicalDir $reportRoot) $reportRoot)) { Fail 'report root escapes report base' }
}
$lockDir = Join-Path $reportRoot '.spec-review.lock'
try {
  New-Item -ItemType Directory -Path $lockDir -ErrorAction Stop | Out-Null
} catch {
  Fail 'another specification review transition holds the lock'
}
try {
  if ($recoveryPath) {
    if (-not (Test-InterruptedRecovery $recoveryPath)) { Fail 'interrupted recovery changed before locked publication' }
    if ((Get-Sha256File (Join-Path $root $recoveryPath)) -cne $recoverySha -or (Get-Sha256File $requirements) -cne $requirementsSha -or (Get-Sha256File $acceptance) -cne $acceptanceSha -or (Get-Sha256File $investigation) -cne $investigationSha -or (Get-Sha256File $calibration) -cne $calibrationSha) { Fail 'recovery pins changed before locked publication' }
    foreach ($ancestor in @($reportsRoot,$reportsBase,$reportRoot,(Split-Path -Parent $reportDir))) {
      if (Test-IsSymlink $ancestor) { Fail 'recovery output ancestor is a symlink' }
      if (Test-Path -LiteralPath $ancestor) {
        if (-not (Test-RealDirectory $ancestor) -or (Get-CanonicalDir $ancestor) -cne $ancestor) { Fail 'recovery output ancestor escapes repository' }
      }
    }
    if ((Test-Path -LiteralPath $reportDir) -or (Test-IsSymlink $reportDir)) { Fail 'round destination already exists (replay is forbidden)' }
    New-Item -ItemType Directory -Path (Split-Path -Parent $reportDir) -Force | Out-Null
    New-Item -ItemType Directory -Path $reportDir -ErrorAction Stop | Out-Null
  } else {
    if (Test-Path -LiteralPath $reportDir) { Fail 'round destination already exists (replay is forbidden)' }
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
  }

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
    $inputSha = if ([string]::IsNullOrEmpty($investigationSha)) { Get-Sha256Text "${requirementsSha}:${acceptanceSha}" } else { Get-Sha256Text "${requirementsSha}:${acceptanceSha}:${investigationSha}" }
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
    investigation_sha256      = if ([string]::IsNullOrEmpty($investigationSha)) { $null } else { $investigationSha }
    calibration_sha256        = $calibrationSha
    input_sha256              = $inputSha
    edit_summary              = $EditSummary
    reset                     = [bool]$Reset
    generated_at              = $generatedAt
  }
  $precheckOutput = Join-Path $reportDir 'precheck-result.json'
  if ($recoveryPath) {
    $result.recovery = [ordered]@{record_path=$recoveryPath;record_sha256=$recoverySha}
    $precheckOutput = Join-Path $reportDir '.precheck-result.json.pending'
  }
  $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $precheckOutput -Encoding utf8NoBOM
  if ($recoveryPath) {
    [IO.File]::WriteAllText((Join-Path $reportDir 'spec-review-report.md'), '')
    [IO.File]::Move($precheckOutput,(Join-Path $reportDir 'precheck-result.json'))
  }

  Write-Output "spec-review-precheck: complete. Output written to $reportDir/"
} finally {
  Remove-Item -LiteralPath $lockDir -Recurse -Force -ErrorAction SilentlyContinue
}
