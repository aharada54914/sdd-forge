param(
  [Parameter(Mandatory = $true)][string]$Feature,
  [Parameter(Mandatory = $true)][string]$Attempt,
  [Parameter(Mandatory = $true)][string]$Round
)

$ErrorActionPreference = 'Stop'
function Fail([string]$Message) { throw "impl-review-precheck: $Message" }
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
  $reviewers = @($contract.reviewers)
  $expectedRoles = @("$Stage-reviewer-a", "$Stage-reviewer-b")
  if ($reviewers.Count -ne 2 -or ((@($reviewers.role | Sort-Object) -join ',') -ne (@($expectedRoles | Sort-Object) -join ','))) { Fail "persisted $Stage contract has invalid reviewers" }
  if (@($reviewers.host_session_id | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0 -or @($reviewers.host_session_id | Select-Object -Unique).Count -ne 2) { Fail "persisted $Stage contract does not isolate reviewer sessions" }
  if (@($reviewers.run_id | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0 -or @($reviewers.run_id | Select-Object -Unique).Count -ne 2) { Fail "persisted $Stage contract has invalid reviewer run IDs" }
  $manifest = @($reviewers | ForEach-Object { @($_.allowed_input_manifest) })
  if ($manifest.Count -eq 0 -or @($manifest | Where-Object { [string]::IsNullOrWhiteSpace($_.path) -or $_.path -notlike "specs/$FeatureName/*" -or $_.path -match 'reviewer-' -or $_.sha256 -notmatch '^[0-9a-f]{64}$' }).Count -gt 0) { Fail "persisted $Stage contract has an invalid allowed input manifest" }
  $expected = @(@("specs/$FeatureName/requirements.md", $RequirementsHash), @("specs/$FeatureName/acceptance-tests.md", $AcceptanceHash))
  if ($Stage -eq 'impl') { $expected += ,@("specs/$FeatureName/design.md", $DesignHash) }
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
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$spec = Join-Path $root "specs/$Feature"
$report = Join-Path $root "reports/impl-review/$Feature/attempt-$Attempt/round-$Round"
if (Test-Path -LiteralPath $report) { Fail 'round destination already exists (replay is forbidden)' }
if (-not (Test-Path -LiteralPath $spec -PathType Container) -or (Get-Item -LiteralPath $spec).LinkType) { Fail 'feature specification directory must be a real directory' }
$requirements = Join-Path $spec 'requirements.md'; $design = Join-Path $spec 'design.md'; $acceptance = Join-Path $spec 'acceptance-tests.md'
foreach ($path in @($requirements, $design, $acceptance)) { if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).LinkType) { Fail "missing required input: $path" } }
$specStatus = (Select-String -LiteralPath $requirements -Pattern '^Spec-Review-Status:\s*(.*)$' | Select-Object -First 1).Matches.Groups[1].Value.Trim()
$implStatus = (Select-String -LiteralPath $design -Pattern '^Impl-Review-Status:\s*(.*)$' | Select-Object -First 1).Matches.Groups[1].Value.Trim()
if ($specStatus -ne 'Passed') { Fail 'requirements.md must declare Spec-Review-Status: Passed' }
if ($implStatus -ne 'Pending') { Fail 'design.md must declare Impl-Review-Status: Pending' }
$designHash = (Get-FileHash -LiteralPath $design -Algorithm SHA256).Hash.ToLower(); $requirementsHash = (Get-FileHash -LiteralPath $requirements -Algorithm SHA256).Hash.ToLower(); $acceptanceHash = (Get-FileHash -LiteralPath $acceptance -Algorithm SHA256).Hash.ToLower()
Require-Pass (Join-Path $root "reports/spec-review/$Feature") 'spec' $Feature $requirementsHash $acceptanceHash ''
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
