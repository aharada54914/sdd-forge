param(
  [Parameter(Mandatory = $true)][string]$Feature,
  [Parameter(Mandatory = $true)][string]$Attempt,
  [Parameter(Mandatory = $true)][string]$Round
)

$ErrorActionPreference = 'Stop'
function Fail([string]$Message) { throw "impl-review-precheck: $Message" }
function Test-OrdinalEqual([object]$Left, [object]$Right) {
  return [string]::Equals([string]$Left, [string]$Right, [StringComparison]::Ordinal)
}
function Get-ReviewedHash([string]$Path, [string]$StatusField, [string]$ReviewedStatus) {
  $content = [IO.File]::ReadAllText($Path)
  $normalized = [Text.RegularExpressions.Regex]::Replace(
    $content,
    "(?m)^$([Text.RegularExpressions.Regex]::Escape($StatusField)):[^\r\n]*(\r?)$",
    "${StatusField}: $ReviewedStatus`$1"
  )
  return [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($normalized))
  ).ToLower()
}
function Get-ManifestRelativePath([string]$Path, [string]$RepoRoot) {
  $normalizedPath = $Path.Replace('\', '/')
  $normalizedRoot = $RepoRoot.Replace('\', '/').TrimEnd('/')
  if ($normalizedPath.StartsWith("$normalizedRoot/", [StringComparison]::Ordinal)) {
    $normalizedPath = $normalizedPath.Substring($normalizedRoot.Length + 1)
  } elseif ([IO.Path]::IsPathRooted($Path) -or $normalizedPath -match '^[A-Za-z]:/') {
    return $null
  }
  if ($normalizedPath -match '(^|/)\.\.?(/|$)') { return $null }
  return $normalizedPath
}
function Test-AllowedManifestPath(
  [string]$Role,
  [string]$Path,
  [string]$Stage,
  [string]$FeatureName,
  [int]$Attempt,
  [int]$Round,
  [string]$CalibrationPath
) {
  $roleA = "$Stage-reviewer-a"
  $roleB = "$Stage-reviewer-b"
  $attemptRoot = "reports/$Stage-review/$FeatureName/attempt-$Attempt"
  $roundRoot = "$attemptRoot/round-$Round"
  $allowed = @(
    "specs/$FeatureName/requirements.md",
    "specs/$FeatureName/acceptance-tests.md",
    $CalibrationPath,
    "$roundRoot/precheck-result.json"
  )
  if (Test-OrdinalEqual $Stage 'spec') {
    $allowed += "specs/$FeatureName/investigation.md"
    if (Test-OrdinalEqual $Role $roleB) { $allowed += "$roundRoot/integrated-summary.json" }
  } elseif (Test-OrdinalEqual $Stage 'impl') {
    $allowed += "specs/$FeatureName/design.md", "specs/$FeatureName/investigation.md"
    if (Test-OrdinalEqual $Role $roleB) { $allowed += "$roundRoot/integrated-summary.json" }
    if ((Test-OrdinalEqual $Role $roleA) -and $Round -gt 1) {
      $allowed += "$attemptRoot/round-$($Round - 1)/integrated-summary.json"
    }
  } elseif (Test-OrdinalEqual $Stage 'task') {
    $allowed += "specs/$FeatureName/tasks.md", "specs/$FeatureName/traceability.md"
    if (Test-OrdinalEqual $Role $roleA) { $allowed += "$roundRoot/dependency-graph.json" }
    if (Test-OrdinalEqual $Role $roleB) {
      $allowed += "$roundRoot/integrated-summary.json",
        'plugins/sdd-quality-loop/references/risk-gate-matrix.md',
        'plugins/sdd-quality-loop/references/risk-classification-policy.md'
    }
  }
  $validRole = (Test-OrdinalEqual $Role $roleA) -or (Test-OrdinalEqual $Role $roleB)
  $validPath = @($allowed | Where-Object { Test-OrdinalEqual $_ $Path }).Count -gt 0
  return $validRole -and $validPath
}
function Require-Pass(
  [string]$Root,
  [string]$Stage,
  [string]$FeatureName,
  [string]$RequirementsHash,
  [string]$AcceptanceHash,
  [string]$DesignHash,
  [string]$RequirementsCurrentHash,
  [string]$DesignCurrentHash
) {
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
  if (-not (Test-Path -LiteralPath $Root -PathType Container) -or (Get-Item -LiteralPath $Root).LinkType) { Fail "missing $Stage predecessor report root" }
  $verdictCandidates = @(Get-ChildItem -LiteralPath $Root -Filter integrated-verdict.json -File -Recurse)
  if ($verdictCandidates.Count -eq 0) { Fail "missing persisted $Stage PASS verdict" }
  $canonicalCandidates = foreach ($candidate in $verdictCandidates) {
    $relativeDirectory = [IO.Path]::GetRelativePath($Root, $candidate.DirectoryName).Replace('\', '/')
    $match = [Text.RegularExpressions.Regex]::Match($relativeDirectory, '^attempt-([1-9][0-9]*)/round-([1-9][0-9]*)$')
    if (-not $match.Success) { Fail "persisted $Stage verdict is outside a canonical attempt/round directory" }
    [pscustomobject]@{ File = $candidate; Attempt = [int64]$match.Groups[1].Value; Round = [int64]$match.Groups[2].Value }
  }
  $verdict = ($canonicalCandidates | Sort-Object Attempt, Round | Select-Object -Last 1).File
  $data = Get-Content -LiteralPath $verdict.FullName -Raw | ConvertFrom-Json
  $validVerdict = (Test-OrdinalEqual $data.feature $FeatureName) -and (Test-OrdinalEqual $data.stage $Stage) -and (Test-OrdinalEqual $data.verdict 'PASS') -and $data.attempt -gt 0 -and $data.round -gt 0
  if (Test-OrdinalEqual $Stage 'spec') { $validVerdict = $validVerdict -and (Test-OrdinalEqual $data.schema 'spec-review-integrated-verdict/v1') -and -not [string]::IsNullOrWhiteSpace($data.reviewer_a_run_id) -and -not [string]::IsNullOrWhiteSpace($data.reviewer_b_run_id) -and -not (Test-OrdinalEqual $data.reviewer_a_run_id $data.reviewer_b_run_id) -and -not [string]::IsNullOrWhiteSpace($data.reviewer_a_host_session_id) -and -not [string]::IsNullOrWhiteSpace($data.reviewer_b_host_session_id) -and -not (Test-OrdinalEqual $data.reviewer_a_host_session_id $data.reviewer_b_host_session_id) } else { $validVerdict = $validVerdict -and (Test-OrdinalEqual $data.schema 'integrated-verdict/v1') -and -not [string]::IsNullOrWhiteSpace($data.run_id) }
  if (-not $validVerdict) { Fail "persisted $Stage verdict is not a complete PASS contract" }
  $contractPath = Join-Path $verdict.DirectoryName "$Stage-review-contract.json"
  if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf) -or (Get-Item -LiteralPath $contractPath).LinkType) { Fail "missing persisted $Stage review contract" }
  $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
  if (-not (Test-OrdinalEqual $contract.schema "$Stage-review-contract/v1") -or -not (Test-OrdinalEqual $contract.stage $Stage) -or -not (Test-OrdinalEqual $contract.feature $FeatureName) -or -not (Test-OrdinalEqual $contract.verdict 'PASS') -or $contract.attempt -le 0 -or $contract.round -le 0 -or [string]::IsNullOrWhiteSpace($contract.run_id)) { Fail "persisted $Stage contract is incomplete" }
  $expectedContractDirectory = [IO.Path]::GetFullPath((Join-Path $Root "attempt-$($contract.attempt)/round-$($contract.round)"))
  if (-not (Test-OrdinalEqual ([IO.Path]::GetFullPath($verdict.DirectoryName)) $expectedContractDirectory)) { Fail "persisted $Stage contract attempt/round do not match its report path" }
  $reviewers = @($contract.reviewers)
  $expectedRoles = @("$Stage-reviewer-a", "$Stage-reviewer-b")
  if ($reviewers.Count -ne 2 -or @($expectedRoles | Where-Object { $expectedRole = $_; @($reviewers | Where-Object { Test-OrdinalEqual $_.role $expectedRole }).Count -ne 1 }).Count -gt 0) { Fail "persisted $Stage contract has invalid reviewers" }
  if (@($reviewers.host_session_id | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0 -or @($reviewers.host_session_id | Select-Object -Unique).Count -ne 2) { Fail "persisted $Stage contract does not isolate reviewer sessions" }
  if (@($reviewers.run_id | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0 -or @($reviewers.run_id | Select-Object -Unique).Count -ne 2) { Fail "persisted $Stage contract has invalid reviewer run IDs" }
  $manifest = @($reviewers | ForEach-Object { @($_.allowed_input_manifest) })
  $calibrationPath = if ($Stage -eq 'spec') { 'plugins/sdd-review-loop/references/spec-review-calibration.md' } else { 'plugins/sdd-review-loop/references/reviewer-calibration.md' }
  $calibrationHash = (Get-FileHash -LiteralPath (Join-Path $repoRoot $calibrationPath) -Algorithm SHA256).Hash.ToLower()
  $invalidManifest = @($reviewers | ForEach-Object {
    $role = $_.role
    @($_.allowed_input_manifest) | Where-Object {
      $relativePath = Get-ManifestRelativePath $_.path $repoRoot
      [string]::IsNullOrWhiteSpace($relativePath) -or
        $_.sha256 -notmatch '^[0-9a-f]{64}$' -or
        -not (Test-AllowedManifestPath $role $relativePath $Stage $FeatureName $contract.attempt $contract.round $calibrationPath)
    }
  }).Count -gt 0
  $duplicateManifestPath = $false
  foreach ($reviewer in $reviewers) {
    $seenPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($entry in @($reviewer.allowed_input_manifest)) {
      $relativePath = Get-ManifestRelativePath $entry.path $repoRoot
      if (-not [string]::IsNullOrWhiteSpace($relativePath) -and -not $seenPaths.Add($relativePath)) { $duplicateManifestPath = $true }
    }
  }
  if ($manifest.Count -eq 0 -or $invalidManifest -or $duplicateManifestPath) { Fail "persisted $Stage contract has an invalid allowed input manifest" }
  function Test-ManifestEntry([object]$Reviewer, [string]$ExpectedPath, [string[]]$AllowedHashes) {
    foreach ($entry in @($Reviewer.allowed_input_manifest)) {
      $relativePath = Get-ManifestRelativePath $entry.path $repoRoot
      if (Test-OrdinalEqual $relativePath $ExpectedPath) {
        foreach ($allowedHash in $AllowedHashes) {
          if (Test-OrdinalEqual $entry.sha256 $allowedHash) { return $true }
        }
      }
    }
    return $false
  }
  $expected = @(
    @("specs/$FeatureName/requirements.md", @($RequirementsHash, $RequirementsCurrentHash)),
    @("specs/$FeatureName/acceptance-tests.md", @($AcceptanceHash))
  )
  if ($Stage -eq 'impl') { $expected += ,@("specs/$FeatureName/design.md", @($DesignHash, $DesignCurrentHash)) }
  foreach ($reviewer in $reviewers) {
    foreach ($pair in $expected) {
      if (-not (Test-ManifestEntry $reviewer $pair[0] $pair[1])) { Fail "persisted $Stage contract does not match canonical current inputs for every reviewer" }
    }
    if (-not (Test-ManifestEntry $reviewer $calibrationPath @($calibrationHash))) { Fail "persisted $Stage contract does not match canonical current inputs for every reviewer" }
    $precheckPath = "reports/$Stage-review/$FeatureName/attempt-$($contract.attempt)/round-$($contract.round)/precheck-result.json"
    $precheckHash = (Get-FileHash -LiteralPath (Join-Path $repoRoot $precheckPath) -Algorithm SHA256).Hash.ToLower()
    if (-not (Test-ManifestEntry $reviewer $precheckPath @($precheckHash))) { Fail "persisted $Stage contract does not bind every reviewer to precheck evidence" }
  }
  $reviewerA = @($reviewers | Where-Object { Test-OrdinalEqual $_.role "$Stage-reviewer-a" })[0]
  $reviewerB = @($reviewers | Where-Object { Test-OrdinalEqual $_.role "$Stage-reviewer-b" })[0]
  $summaryPath = "reports/$Stage-review/$FeatureName/attempt-$($contract.attempt)/round-$($contract.round)/integrated-summary.json"
  $summaryHash = (Get-FileHash -LiteralPath (Join-Path $repoRoot $summaryPath) -Algorithm SHA256).Hash.ToLower()
  if (-not (Test-ManifestEntry $reviewerB $summaryPath @($summaryHash))) { Fail "persisted $Stage contract does not bind reviewer B to the integrated summary" }
  if ((Test-OrdinalEqual $Stage 'impl') -and $contract.round -gt 1) {
    $previousSummaryPath = "reports/$Stage-review/$FeatureName/attempt-$($contract.attempt)/round-$($contract.round - 1)/integrated-summary.json"
    $previousSummaryHash = (Get-FileHash -LiteralPath (Join-Path $repoRoot $previousSummaryPath) -Algorithm SHA256).Hash.ToLower()
    if (-not (Test-ManifestEntry $reviewerA $previousSummaryPath @($previousSummaryHash))) { Fail "persisted impl contract does not bind reviewer A to the previous integrated summary" }
  }
  $investigationPath = "specs/$FeatureName/investigation.md"
  if (Test-Path -LiteralPath (Join-Path $repoRoot $investigationPath) -PathType Leaf) {
    $investigationHash = (Get-FileHash -LiteralPath (Join-Path $repoRoot $investigationPath) -Algorithm SHA256).Hash.ToLower()
    foreach ($reviewer in $reviewers) {
      if (-not (Test-ManifestEntry $reviewer $investigationPath @($investigationHash))) { Fail "persisted $Stage contract does not bind every reviewer to investigation.md" }
    }
  }
  if ($contract.attempt -ne $data.attempt -or $contract.round -ne $data.round -or -not (Test-OrdinalEqual $contract.verdict $data.verdict)) { Fail "persisted $Stage verdict and contract contradict each other" }
  if (Test-OrdinalEqual $Stage 'spec') {
    if (-not (Test-OrdinalEqual $reviewerA.run_id $data.reviewer_a_run_id) -or -not (Test-OrdinalEqual $reviewerB.run_id $data.reviewer_b_run_id) -or -not (Test-OrdinalEqual $reviewerA.host_session_id $data.reviewer_a_host_session_id) -or -not (Test-OrdinalEqual $reviewerB.host_session_id $data.reviewer_b_host_session_id)) { Fail 'persisted spec verdict and contract reviewer identities contradict each other' }
  } elseif (-not (Test-OrdinalEqual $contract.run_id $data.run_id)) { Fail "persisted $Stage verdict and contract run IDs contradict each other" }
}
if ($Feature -notmatch '^[a-z0-9][a-z0-9-]*$') { Fail 'invalid feature slug' }
if ($Attempt -notmatch '^[1-9][0-9]*$') { Fail 'attempt must be a positive integer' }
if ($Round -notmatch '^[1-9][0-9]*$') { Fail 'round must be a positive integer' }
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$spec = Join-Path $root "specs/$Feature"
$report = Join-Path $root "reports/impl-review/$Feature/attempt-$Attempt/round-$Round"
if (Test-Path -LiteralPath $report) { Fail 'round destination already exists (replay is forbidden)' }
if (-not (Test-Path -LiteralPath $spec -PathType Container) -or (Get-Item -LiteralPath $spec).LinkType) { Fail 'feature specification directory must be a real directory' }
$powerShellExe = (Get-Process -Id $PID).Path
& $powerShellExe -NoProfile -File (Join-Path $root 'plugins/sdd-quality-loop/scripts/check-workflow-state.ps1') --feature $Feature
if ($LASTEXITCODE -ne 0) { Fail 'canonical workflow-state validation failed' }
$requirements = Join-Path $spec 'requirements.md'; $design = Join-Path $spec 'design.md'; $acceptance = Join-Path $spec 'acceptance-tests.md'
foreach ($path in @($requirements, $design, $acceptance)) { if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).LinkType) { Fail "missing required input: $path" } }
$specStatus = (Select-String -LiteralPath $requirements -Pattern '^Spec-Review-Status:\s*(.*)$' | Select-Object -First 1).Matches.Groups[1].Value.Trim()
$implStatus = (Select-String -LiteralPath $design -Pattern '^Impl-Review-Status:\s*(.*)$' | Select-Object -First 1).Matches.Groups[1].Value.Trim()
if ($specStatus -ne 'Passed') { Fail 'requirements.md must declare Spec-Review-Status: Passed' }
if ($implStatus -ne 'Pending') { Fail 'design.md must declare Impl-Review-Status: Pending' }
$designHash = (Get-FileHash -LiteralPath $design -Algorithm SHA256).Hash.ToLower(); $requirementsHash = (Get-FileHash -LiteralPath $requirements -Algorithm SHA256).Hash.ToLower(); $acceptanceHash = (Get-FileHash -LiteralPath $acceptance -Algorithm SHA256).Hash.ToLower()
$calibration = Join-Path $root 'plugins/sdd-review-loop/references/reviewer-calibration.md'
if (-not (Test-Path -LiteralPath $calibration -PathType Leaf) -or (Get-Item -LiteralPath $calibration).LinkType) { Fail 'plugins/sdd-review-loop/references/reviewer-calibration.md not found' }
$calibrationHash = (Get-FileHash -LiteralPath $calibration -Algorithm SHA256).Hash.ToLower()
$specReviewedRequirementsHash = Get-ReviewedHash $requirements 'Spec-Review-Status' 'Pending'
Require-Pass (Join-Path $root "reports/spec-review/$Feature") 'spec' $Feature $specReviewedRequirementsHash $acceptanceHash '' $requirementsHash ''
$requiredFields = @('## Components', 'Feature Type:', 'Data Entities:', 'Existing Data Affected:', '## Security Boundaries')
$legacyDesign = (@($requiredFields | Where-Object { -not (Select-String -LiteralPath $design -SimpleMatch -Quiet -Pattern $_) }).Count -ge 3)
$designReqDrift = $false
if ([int64]$Round -gt 1) {
  $priorRound = [int64]$Round - 1
  $priorContract = Join-Path $root "reports/impl-review/$Feature/attempt-$Attempt/round-$priorRound/impl-review-contract.json"
  if (Test-Path -LiteralPath $priorContract -PathType Leaf) {
    $prior = Get-Content -LiteralPath $priorContract -Raw | ConvertFrom-Json
    if ($prior.design_sha256 -eq $designHash) { Fail "design.md sha256 is unchanged from round $priorRound" }
    $roundOneContract = Join-Path $root "reports/impl-review/$Feature/attempt-$Attempt/round-1/impl-review-contract.json"
    if (Test-Path -LiteralPath $roundOneContract -PathType Leaf) {
      $roundOne = Get-Content -LiteralPath $roundOneContract -Raw | ConvertFrom-Json
      if ($roundOne.requirements_sha256 -and $roundOne.requirements_sha256 -ne $requirementsHash) { $designReqDrift = $true }
    }
  }
}
$inputHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes("$designHash`:$requirementsHash`:$acceptanceHash"))).ToLower()
$base = Join-Path $root 'reports/impl-review'; New-Item -ItemType Directory -Path $base -Force | Out-Null
$temporaryContract = [IO.Path]::GetTempFileName()
try {
  [ordered]@{schema='review-contract/v1';stage='impl';feature=$Feature;attempt=[int64]$Attempt;round=[int64]$Round;input_sha256=$inputHash;run_id='impl-precheck';verdict='PASS'} | ConvertTo-Json -Compress | Set-Content -LiteralPath $temporaryContract -Encoding utf8NoBOM
  & (Join-Path $PSScriptRoot 'review-contract-validate.ps1') -Feature $Feature -Attempt $Attempt -Round $Round -Stage impl -ReportRoot (Join-Path $root "reports/impl-review/$Feature") -Contract $temporaryContract | Out-Null
} finally { Remove-Item -LiteralPath $temporaryContract -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $report | Out-Null
[ordered]@{schema='impl-review-precheck/v1';feature=$Feature;attempt=[int64]$Attempt;round=[int64]$Round;impl_review_status_field=$implStatus;legacy_design=$legacyDesign;design_req_drift=$designReqDrift;design_sha256=$designHash;requirements_sha256=$requirementsHash;acceptance_sha256=$acceptanceHash;generated_at=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $report 'precheck-result.json') -Encoding utf8NoBOM
Write-Output "impl-review-precheck: complete. Output written to $report/"
