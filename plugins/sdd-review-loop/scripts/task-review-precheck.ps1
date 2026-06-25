param(
  [Parameter(Mandatory = $true)][string]$Feature,
  [Parameter(Mandatory = $true)][string]$Attempt,
  [Parameter(Mandatory = $true)][string]$Round
)

$ErrorActionPreference = 'Stop'
function Fail([string]$Message) { throw "task-review-precheck: $Message" }
function Require-Pass([string]$Root, [string]$Stage, [string]$FeatureName, [string]$RequirementsHash, [string]$AcceptanceHash, [string]$DesignHash) {
  if (-not (Test-Path -LiteralPath $Root -PathType Container) -or (Get-Item -LiteralPath $Root).LinkType) { Fail "missing $Stage predecessor report root" }
  $verdict = Get-ChildItem -LiteralPath $Root -Filter integrated-verdict.json -File -Recurse | Sort-Object FullName | Select-Object -Last 1
  if ($null -eq $verdict) { Fail "missing persisted $Stage PASS verdict" }
  $data = Get-Content -LiteralPath $verdict.FullName -Raw | ConvertFrom-Json
  $validVerdict = $data.feature -eq $FeatureName -and $data.stage -eq $Stage -and $data.verdict -eq 'PASS' -and $data.attempt -gt 0 -and $data.round -gt 0
  if ($Stage -eq 'spec') { $validVerdict = $validVerdict -and $data.schema -eq 'spec-review-integrated-verdict/v1' -and -not [string]::IsNullOrWhiteSpace($data.reviewer_a_run_id) -and -not [string]::IsNullOrWhiteSpace($data.reviewer_b_run_id) -and $data.reviewer_a_run_id -ne $data.reviewer_b_run_id -and -not [string]::IsNullOrWhiteSpace($data.reviewer_a_host_session_id) -and -not [string]::IsNullOrWhiteSpace($data.reviewer_b_host_session_id) -and $data.reviewer_a_host_session_id -ne $data.reviewer_b_host_session_id } else { $validVerdict = $validVerdict -and $data.schema -eq 'integrated-verdict/v1' -and -not [string]::IsNullOrWhiteSpace($data.run_id) }
  if (-not $validVerdict) { Fail "persisted $Stage verdict is not a complete PASS contract" }
  $contractPath = Join-Path $verdict.DirectoryName "$Stage-review-contract.json"
  if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf) -or (Get-Item -LiteralPath $contractPath).LinkType) { Fail "missing persisted $Stage review contract" }
  $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
  if ($contract.schema -ne "$Stage-review-contract/v1" -or $contract.stage -ne $Stage -or $contract.feature -ne $FeatureName -or $contract.verdict -ne 'PASS' -or $contract.attempt -le 0 -or $contract.round -le 0 -or [string]::IsNullOrWhiteSpace($contract.run_id)) { Fail "persisted $Stage contract is incomplete" }
  $reviewers = @($contract.reviewers); $expectedRoles = @("$Stage-reviewer-a", "$Stage-reviewer-b")
  if ($reviewers.Count -ne 2 -or ((@($reviewers.role | Sort-Object) -join ',') -ne (@($expectedRoles | Sort-Object) -join ','))) { Fail "persisted $Stage contract has invalid reviewers" }
  if (@($reviewers.host_session_id | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0 -or @($reviewers.host_session_id | Select-Object -Unique).Count -ne 2) { Fail "persisted $Stage contract does not isolate reviewer sessions" }
  if (@($reviewers.run_id | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0 -or @($reviewers.run_id | Select-Object -Unique).Count -ne 2) { Fail "persisted $Stage contract has invalid reviewer run IDs" }
  $manifest = @($reviewers | ForEach-Object { @($_.allowed_input_manifest) })
  if ($manifest.Count -eq 0 -or @($manifest | Where-Object { [string]::IsNullOrWhiteSpace($_.path) -or $_.path -notlike "specs/$FeatureName/*" -or $_.path -match 'reviewer-' -or $_.sha256 -notmatch '^[0-9a-f]{64}$' }).Count -gt 0) { Fail "persisted $Stage contract has an invalid allowed input manifest" }
  $expected = @(@("specs/$FeatureName/requirements.md", $RequirementsHash), @("specs/$FeatureName/acceptance-tests.md", $AcceptanceHash)); if ($Stage -eq 'impl') { $expected += ,@("specs/$FeatureName/design.md", $DesignHash) }
  foreach ($pair in $expected) { if (@($manifest | Where-Object { $_.path -eq $pair[0] -and $_.sha256 -eq $pair[1] }).Count -eq 0) { Fail "persisted $Stage contract does not match canonical current inputs" } }
  if ($contract.attempt -ne $data.attempt -or $contract.round -ne $data.round -or $contract.verdict -ne $data.verdict) { Fail "persisted $Stage verdict and contract contradict each other" }
  $reviewerByRole = @{}; foreach ($reviewer in $reviewers) { $reviewerByRole[$reviewer.role] = $reviewer }
  if ($Stage -eq 'spec') {
    if ($reviewerByRole['spec-reviewer-a'].run_id -ne $data.reviewer_a_run_id -or $reviewerByRole['spec-reviewer-b'].run_id -ne $data.reviewer_b_run_id -or $reviewerByRole['spec-reviewer-a'].host_session_id -ne $data.reviewer_a_host_session_id -or $reviewerByRole['spec-reviewer-b'].host_session_id -ne $data.reviewer_b_host_session_id) { Fail 'persisted spec verdict and contract reviewer identities contradict each other' }
  } elseif ($contract.run_id -ne $data.run_id) { Fail "persisted $Stage verdict and contract run IDs contradict each other" }
}
if ($Feature -notmatch '^[a-z0-9][a-z0-9-]*$') { Fail 'invalid feature slug' }
if ($Attempt -notmatch '^[1-9][0-9]*$') { Fail 'attempt must be a positive integer' }
if ($Round -notmatch '^[1-9][0-9]*$') { Fail 'round must be a positive integer' }
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path; $spec = Join-Path $root "specs/$Feature"; $report = Join-Path $root "reports/task-review/$Feature/attempt-$Attempt/round-$Round"
if (Test-Path -LiteralPath $report) { Fail 'round destination already exists (replay is forbidden)' }
if (-not (Test-Path -LiteralPath $spec -PathType Container) -or (Get-Item -LiteralPath $spec).LinkType) { Fail 'feature specification directory must be a real directory' }
$requirements = Join-Path $spec 'requirements.md'; $design = Join-Path $spec 'design.md'; $acceptance = Join-Path $spec 'acceptance-tests.md'; $tasks = Join-Path $spec 'tasks.md'
foreach ($path in @($requirements, $design, $acceptance, $tasks)) { if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).LinkType) { Fail "missing required input: $path" } }
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
$tasksHash=(Get-FileHash -LiteralPath $tasks -Algorithm SHA256).Hash.ToLower(); $requirementsHash=(Get-FileHash -LiteralPath $requirements -Algorithm SHA256).Hash.ToLower(); $acceptanceHash=(Get-FileHash -LiteralPath $acceptance -Algorithm SHA256).Hash.ToLower(); $designHash=(Get-FileHash -LiteralPath $design -Algorithm SHA256).Hash.ToLower(); Require-Pass (Join-Path $root "reports/spec-review/$Feature") 'spec' $Feature $requirementsHash $acceptanceHash ''; Require-Pass (Join-Path $root "reports/impl-review/$Feature") 'impl' $Feature $requirementsHash $acceptanceHash $designHash
$riskScript = Join-Path $root 'plugins/sdd-quality-loop/scripts/check-risk.ps1'
if (-not (Test-Path -LiteralPath $riskScript -PathType Leaf)) { Fail 'shared risk gate is missing' }
& $riskScript -TasksPath $tasks
if ($LASTEXITCODE -ne 0) { Fail 'Risk/Required Workflow mismatches must be fixed before creating evidence' }
$mediumTestAfter = (Select-String -LiteralPath $tasks -Pattern '^Risk:\s*medium\s*$' -Quiet) -and (Select-String -LiteralPath $tasks -Pattern '^Required Workflow:\s*test-after\s*$' -Quiet); if ($mediumTestAfter) { Fail 'Risk: medium with Required Workflow: test-after requires acceptance-first before creating evidence' }; $inputHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes("$tasksHash`:$requirementsHash`:$acceptanceHash"))).ToLower()
$base=Join-Path $root 'reports/task-review'; New-Item -ItemType Directory -Path $base -Force | Out-Null; $temporaryContract=[IO.Path]::GetTempFileName()
try { [ordered]@{schema='review-contract/v1';stage='task';feature=$Feature;attempt=[int64]$Attempt;round=[int64]$Round;input_sha256=$inputHash;run_id='task-precheck';verdict='PASS'}|ConvertTo-Json -Compress|Set-Content -LiteralPath $temporaryContract -Encoding utf8NoBOM; & (Join-Path $PSScriptRoot 'review-contract-validate.ps1') -Feature $Feature -Attempt $Attempt -Round $Round -Stage task -ReportRoot (Join-Path $root "reports/task-review/$Feature") -Contract $temporaryContract | Out-Null } finally { Remove-Item -LiteralPath $temporaryContract -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $report | Out-Null
$graph=[ordered]@{schema='dependency-graph/v1';feature=$Feature;attempt=[int64]$Attempt;round=[int64]$Round;nodes=$nodes;edges=$edges;generated_at=[DateTime]::UtcNow.ToString('o')}; $graph|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $report 'dependency-graph.json') -Encoding utf8NoBOM
[ordered]@{schema='task-review-precheck/v1';feature=$Feature;attempt=[int64]$Attempt;round=[int64]$Round;workflow_match_precheck='PASS';blockers_format_valid=$true;tasks_sha256=$tasksHash;requirements_sha256=$requirementsHash;acceptance_sha256=$acceptanceHash;generated_at=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $report 'precheck-result.json') -Encoding utf8NoBOM
Write-Output "task-review-precheck: complete. Output written to $report/"
