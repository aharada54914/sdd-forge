param(
  [Parameter(Mandatory = $true)][string]$Feature,
  [Parameter(Mandatory = $true)][string]$Attempt,
  [Parameter(Mandatory = $true)][string]$Round,
  [switch]$VerifyInputs
)

$ErrorActionPreference = 'Stop'
function Fail([string]$Message) { throw "task-review-precheck: $Message" }
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
    # Contracts persisted by predecessor gates record absolute paths of the
    # checkout that generated them. Relativize against the known repository
    # anchors so evidence stays verifiable from any checkout (issue #61).
    $anchorMatch = [Text.RegularExpressions.Regex]::Match(
      $normalizedPath, '^.*/(?<tail>(specs|reports|plugins)/.+)$')
    if (-not $anchorMatch.Success) { return $null }
    $normalizedPath = $anchorMatch.Groups['tail'].Value
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
    $allowed += "specs/$FeatureName/design.md", "specs/$FeatureName/investigation.md",
      "specs/$FeatureName/ux-spec.md", "specs/$FeatureName/frontend-spec.md",
      "specs/$FeatureName/infra-spec.md", "specs/$FeatureName/security-spec.md"
    if (Test-OrdinalEqual $Role $roleB) { $allowed += "$roundRoot/integrated-summary.json" }
    if ((Test-OrdinalEqual $Role $roleA) -and $Round -gt 1) {
      $allowed += "$attemptRoot/round-$($Round - 1)/integrated-summary.json"
    }
  } elseif (Test-OrdinalEqual $Stage 'task') {
    $allowed += "specs/$FeatureName/tasks.md", "specs/$FeatureName/design.md",
      "specs/$FeatureName/traceability.md",
      "specs/$FeatureName/ux-spec.md", "specs/$FeatureName/frontend-spec.md",
      "specs/$FeatureName/infra-spec.md", "specs/$FeatureName/security-spec.md"
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
  $reviewers = @($contract.reviewers); $expectedRoles = @("$Stage-reviewer-a", "$Stage-reviewer-b")
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
    $contractLayerProperties = if ($null -eq $contract.psobject.Properties['layer_sha256']) { @() } else { @($contract.layer_sha256.psobject.Properties) }
    if ($Stage -eq 'impl' -and $contractLayerProperties.Count -gt 0) {
      foreach ($layer in @('ux-spec.md', 'frontend-spec.md', 'infra-spec.md', 'security-spec.md')) {
        $layerPath = Join-Path $repoRoot "specs/$FeatureName/$layer"
        if (-not (Test-ManifestEntry $reviewer "specs/$FeatureName/$layer" @((Get-FileHash -LiteralPath $layerPath -Algorithm SHA256).Hash.ToLower()))) {
          Fail "persisted impl contract does not bind every reviewer to canonical layer inputs"
        }
      }
    }
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
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path; $spec = Join-Path $root "specs/$Feature"; $report = Join-Path $root "reports/task-review/$Feature/attempt-$Attempt/round-$Round"
if (-not (Test-Path -LiteralPath $spec -PathType Container) -or (Get-Item -LiteralPath $spec).LinkType) { Fail 'feature specification directory must be a real directory' }
$registry = Get-Content -LiteralPath (Join-Path $root 'specs/workflow-state-registry.json') -Raw | ConvertFrom-Json
$profileEntry = @($registry.entries | Where-Object { Test-OrdinalEqual $_.feature $Feature } | Select-Object -Last 1)
$fullProfile = $profileEntry.Count -eq 1 -and (Test-OrdinalEqual $profileEntry[0].profile 'full')
$layerNames = @('ux-spec.md', 'frontend-spec.md', 'infra-spec.md', 'security-spec.md')
$requirements = Join-Path $spec 'requirements.md'; $design = Join-Path $spec 'design.md'; $acceptance = Join-Path $spec 'acceptance-tests.md'; $tasks = Join-Path $spec 'tasks.md'; $traceability = Join-Path $spec 'traceability.md'

if ($VerifyInputs) {
  $precheckPath = Join-Path $report 'precheck-result.json'
  if (-not (Test-Path -LiteralPath $precheckPath -PathType Leaf) -or (Get-Item -LiteralPath $precheckPath).LinkType) { Fail 'precheck evidence is missing or substituted' }
  foreach ($path in @($requirements, $acceptance, $tasks)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).LinkType) { Fail "review input is missing or substituted: $path" }
  }
  $precheck = Get-Content -LiteralPath $precheckPath -Raw | ConvertFrom-Json
  if (-not (Test-OrdinalEqual $precheck.schema 'task-review-precheck/v1') -or
      -not (Test-OrdinalEqual $precheck.feature $Feature) -or
      [int64]$precheck.attempt -ne [int64]$Attempt -or [int64]$precheck.round -ne [int64]$Round -or
      -not (Test-OrdinalEqual $precheck.tasks_sha256 ((Get-FileHash -LiteralPath $tasks -Algorithm SHA256).Hash.ToLower())) -or
      -not (Test-OrdinalEqual $precheck.requirements_sha256 ((Get-FileHash -LiteralPath $requirements -Algorithm SHA256).Hash.ToLower())) -or
      -not (Test-OrdinalEqual $precheck.acceptance_sha256 ((Get-FileHash -LiteralPath $acceptance -Algorithm SHA256).Hash.ToLower()))) {
    Fail 'core review inputs changed after precheck'
  }
  $persistedLayerProperties = if ($null -eq $precheck.psobject.Properties['layer_sha256']) { @() } else { @($precheck.layer_sha256.psobject.Properties) }
  if ($fullProfile -or $persistedLayerProperties.Count -gt 0) {
    if (-not (Test-Path -LiteralPath $design -PathType Leaf) -or (Get-Item -LiteralPath $design).LinkType) { Fail 'design review input is missing or substituted' }
    if (-not (Test-OrdinalEqual $precheck.design_sha256 ((Get-FileHash -LiteralPath $design -Algorithm SHA256).Hash.ToLower()))) { Fail 'design review input changed after precheck' }
    if (-not (Test-Path -LiteralPath $traceability -PathType Leaf) -or (Get-Item -LiteralPath $traceability).LinkType) { Fail 'traceability review input is missing or substituted' }
    if (-not (Test-OrdinalEqual $precheck.traceability_sha256 ((Get-FileHash -LiteralPath $traceability -Algorithm SHA256).Hash.ToLower()))) { Fail 'traceability review input changed after precheck' }
    & (Join-Path $PSScriptRoot 'validate-layer-traceability.ps1') -Path $traceability -RequirementsPath $requirements
    $boundNames = @($precheck.layer_sha256.psobject.Properties.Name)
    if ($boundNames.Count -ne $layerNames.Count -or @($layerNames | Where-Object { $_ -notin $boundNames }).Count -gt 0) { Fail 'precheck layer manifest is incomplete' }
    foreach ($name in $layerNames) {
      $path = Join-Path $spec $name
      if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).LinkType) { Fail "layer review input is missing or substituted: $path" }
      if (-not (Test-OrdinalEqual $precheck.layer_sha256.$name ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower()))) { Fail "layer review input changed after precheck: $path" }
    }
  }
  Write-Output 'task-review-precheck: inputs verified for reviewer invocation.'
  exit 0
}

if (Test-Path -LiteralPath $report) { Fail 'round destination already exists (replay is forbidden)' }
$powerShellExe = (Get-Process -Id $PID).Path
& $powerShellExe -NoProfile -File (Join-Path $root 'plugins/sdd-quality-loop/scripts/check-workflow-state.ps1') --feature $Feature
if ($LASTEXITCODE -ne 0) { Fail 'canonical workflow-state validation failed' }
foreach ($path in @($requirements, $design, $acceptance, $tasks)) { if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).LinkType) { Fail "missing required input: $path" } }
if ($fullProfile) {
  foreach ($path in @($traceability) + @($layerNames | ForEach-Object { Join-Path $spec $_ })) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).LinkType) { Fail "missing required input: $path" }
  }
}
$specStatus = (Select-String -LiteralPath $requirements -Pattern '^Spec-Review-Status:\s*(.*)$' | Select-Object -First 1).Matches.Groups[1].Value.Trim(); $implStatus = (Select-String -LiteralPath $design -Pattern '^Impl-Review-Status:\s*(.*)$' | Select-Object -First 1).Matches.Groups[1].Value.Trim()
if ($specStatus -ne 'Passed') { Fail 'requirements.md must declare Spec-Review-Status: Passed' }; if ($implStatus -ne 'Passed') { Fail 'design.md must declare Impl-Review-Status: Passed' }
$edges = @(); $nodes = @(); $current = ''; $expectBlockers = $false
foreach ($line in Get-Content -LiteralPath $tasks) {
  if ($line -match '^##\s+(T-[0-9]{3})(\s|$)') { if ($expectBlockers) { Fail "$current Blockers value is missing" }; $current=$Matches[1]; $nodes += $current; $expectBlockers=$false; continue }
  if ($current -and $line -match '^Blockers:\s*(.*)$') {
    $value = $Matches[1].Trim(); if (-not $value -or $value -eq 'None') { $expectBlockers=$false; continue }
    foreach ($target in $value.Split(',')) { if ($target.Trim() -notmatch '^T-[0-9]{3}$') { Fail 'Blockers format is invalid' }; $edges += [ordered]@{from=$current;to=$target.Trim()} }
    $expectBlockers=$false; continue
  }
  if ($line -match '^###\s+Blockers\s*$') { $expectBlockers=$true; continue }
  if ($expectBlockers -and $line.Trim()) { if ($line.Trim() -ne 'None') { foreach ($target in $line.Split(',')) { if ($target.Trim() -notmatch '^T-[0-9]{3}$') { Fail 'Blockers format is invalid' }; $edges += [ordered]@{from=$current;to=$target.Trim()} } }; $expectBlockers=$false }
}
if ($expectBlockers) { Fail "$current Blockers value is missing" }
$inDegree=@{}; foreach($node in $nodes){ $inDegree[$node]=0 }; foreach($edge in $edges){ if(-not $inDegree.ContainsKey($edge.to)){ Fail 'Blockers reference an unknown task' }; $inDegree[$edge.to]++ }
$queue=[Collections.Generic.Queue[string]]::new(); foreach($node in $nodes){ if($inDegree[$node] -eq 0){ $queue.Enqueue($node) } }
$visited=0; while($queue.Count -gt 0){ $node=$queue.Dequeue(); $visited++; foreach($edge in $edges | Where-Object { $_.from -eq $node }){ $inDegree[$edge.to]--; if($inDegree[$edge.to] -eq 0){ $queue.Enqueue($edge.to) } } }
if($visited -ne $nodes.Count){ Fail 'Blockers dependency graph contains a cycle' }
$tasksHash=(Get-FileHash -LiteralPath $tasks -Algorithm SHA256).Hash.ToLower(); $requirementsHash=(Get-FileHash -LiteralPath $requirements -Algorithm SHA256).Hash.ToLower(); $acceptanceHash=(Get-FileHash -LiteralPath $acceptance -Algorithm SHA256).Hash.ToLower(); $designHash=(Get-FileHash -LiteralPath $design -Algorithm SHA256).Hash.ToLower()
$traceabilityHash = ''
$layerHashes = [ordered]@{}
if ($fullProfile) {
  $traceabilityHash = (Get-FileHash -LiteralPath $traceability -Algorithm SHA256).Hash.ToLower()
  foreach ($name in $layerNames) { $layerHashes[$name] = (Get-FileHash -LiteralPath (Join-Path $spec $name) -Algorithm SHA256).Hash.ToLower() }
  & (Join-Path $PSScriptRoot 'validate-layer-traceability.ps1') -Path $traceability -RequirementsPath $requirements
}
$calibration = Join-Path $root 'plugins/sdd-review-loop/references/reviewer-calibration.md'
if (-not (Test-Path -LiteralPath $calibration -PathType Leaf) -or (Get-Item -LiteralPath $calibration).LinkType) { Fail 'plugins/sdd-review-loop/references/reviewer-calibration.md not found' }
$calibrationHash = (Get-FileHash -LiteralPath $calibration -Algorithm SHA256).Hash.ToLower()
$specReviewedRequirementsHash = Get-ReviewedHash $requirements 'Spec-Review-Status' 'Pending'
$implReviewedDesignHash = Get-ReviewedHash $design 'Impl-Review-Status' 'Pending'
Require-Pass (Join-Path $root "reports/spec-review/$Feature") 'spec' $Feature $specReviewedRequirementsHash $acceptanceHash '' $requirementsHash ''
Require-Pass (Join-Path $root "reports/impl-review/$Feature") 'impl' $Feature $requirementsHash $acceptanceHash $implReviewedDesignHash $requirementsHash $designHash
$riskScript = Join-Path $root 'plugins/sdd-quality-loop/scripts/check-risk.ps1'
if (-not (Test-Path -LiteralPath $riskScript -PathType Leaf)) { Fail 'shared risk gate is missing' }
& $riskScript -TasksPath $tasks
if ($LASTEXITCODE -ne 0) { Fail 'Risk/Required Workflow mismatches must be fixed before creating evidence' }
$inputMaterial = if ($fullProfile) {
  $layerJson = $layerHashes | ConvertTo-Json -Compress
  "$tasksHash`:$requirementsHash`:$acceptanceHash`:$designHash`:$traceabilityHash`:$layerJson"
} else {
  "$tasksHash`:$requirementsHash`:$acceptanceHash"
}
$inputHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($inputMaterial))).ToLower()
$base=Join-Path $root 'reports/task-review'; New-Item -ItemType Directory -Path $base -Force | Out-Null; $temporaryContract=[IO.Path]::GetTempFileName()
try { [ordered]@{schema='review-contract/v1';stage='task';feature=$Feature;attempt=[int64]$Attempt;round=[int64]$Round;input_sha256=$inputHash;run_id='task-precheck';verdict='PASS'}|ConvertTo-Json -Compress|Set-Content -LiteralPath $temporaryContract -Encoding utf8NoBOM; & (Join-Path $PSScriptRoot 'review-contract-validate.ps1') -Feature $Feature -Attempt $Attempt -Round $Round -Stage task -ReportRoot (Join-Path $root "reports/task-review/$Feature") -Contract $temporaryContract | Out-Null } finally { Remove-Item -LiteralPath $temporaryContract -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $report | Out-Null
$graph=[ordered]@{schema='dependency-graph/v1';feature=$Feature;attempt=[int64]$Attempt;round=[int64]$Round;nodes=$nodes;edges=$edges;generated_at=[DateTime]::UtcNow.ToString('o')}; $graph|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $report 'dependency-graph.json') -Encoding utf8NoBOM
[ordered]@{schema='task-review-precheck/v1';feature=$Feature;attempt=[int64]$Attempt;round=[int64]$Round;workflow_match_precheck='PASS';blockers_format_valid=$true;tasks_sha256=$tasksHash;requirements_sha256=$requirementsHash;acceptance_sha256=$acceptanceHash;design_sha256=$designHash;traceability_sha256=$traceabilityHash;layer_sha256=$layerHashes;input_sha256=$inputHash;generated_at=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $report 'precheck-result.json') -Encoding utf8NoBOM
Write-Output "task-review-precheck: complete. Output written to $report/"
