param(
  [Parameter(Mandatory=$true)][string]$Evidence,
  [Parameter(Mandatory=$true)][string]$BlockedState,
  [Parameter(Mandatory=$true)][string]$Tasks,
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$ExpectedTask
)
$ErrorActionPreference = 'Stop'

function Fail([string]$Code, [string]$Message) {
  throw "TERMINAL_RESUME_${Code}: $Message"
}
function Get-Names($Object) {
  @($Object.PSObject.Properties | Select-Object -ExpandProperty Name)
}
function Assert-ExactNames($Object, [string[]]$Names, [string]$Label) {
  $actual = @((Get-Names $Object) | Sort-Object -CaseSensitive)
  $expected = @($Names | Sort-Object -CaseSensitive)
  if (($actual -join ',') -cne ($expected -join ',')) {
    Fail JSON "invalid $Label fields"
  }
}
function Get-SafeRepoFile([string]$RelativePath) {
  if ([string]::IsNullOrEmpty($RelativePath) -or
      [IO.Path]::IsPathRooted($RelativePath) -or $RelativePath.Contains('\')) {
    Fail PATH 'diagnosis path must be repository-relative'
  }
  $parts = @($RelativePath.Split('/'))
  foreach ($part in $parts) {
    if ($part -in @('', '.', '..')) { Fail PATH 'diagnosis path is not canonical' }
  }
  try {
    $resolvedRoot = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).ProviderPath
  } catch {
    Fail PATH 'repository root is missing'
  }
  $rootPrefix = $resolvedRoot.TrimEnd(
    [IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  $current = $resolvedRoot
  for ($index = 0; $index -lt $parts.Count; $index++) {
    $current = Join-Path $current $parts[$index]
    if (-not (Test-Path -LiteralPath $current)) {
      Fail PATH 'diagnosis reference is missing'
    }
    $item = Get-Item -LiteralPath $current -Force
    if ($item.LinkType) { Fail PATH 'diagnosis reference is a symlink' }
    if ($index -lt $parts.Count - 1 -and -not $item.PSIsContainer) {
      Fail PATH 'diagnosis reference is missing'
    }
  }
  $target = [IO.Path]::GetFullPath($current)
  if (-not $target.StartsWith($rootPrefix, [StringComparison]::Ordinal) -or
      -not (Test-Path -LiteralPath $target -PathType Leaf)) {
    Fail PATH 'diagnosis reference escapes repository'
  }
  return $target
}

try {
  $data = Get-Content -Raw -LiteralPath $Evidence |
    ConvertFrom-Json -DateKind String
} catch {
  Fail JSON $_.Exception.Message
}
Assert-ExactNames $data @(
  'schema','task_id','blocked_task_contract_sha256',
  'revised_task_contract_sha256','diagnosis_reference','human_reapproval',
  'blocked_state_reference'
) 'evidence'
if ($data.schema -cne 'terminal-tier-resume/v1') { Fail JSON 'unsupported schema' }
if ($data.task_id -isnot [string] -or $data.task_id -notmatch '^T-[0-9]{3}$') {
  Fail TASK 'invalid task_id'
}
if ($data.task_id -cne $ExpectedTask) { Fail TASK 'task_id does not match expected task' }
foreach ($field in @('blocked_task_contract_sha256','revised_task_contract_sha256')) {
  if ($data.$field -isnot [string] -or $data.$field -notmatch '^[a-f0-9]{64}$') {
    Fail HASH "invalid $field"
  }
}
Assert-ExactNames $data.blocked_state_reference @('path','sha256') 'blocked_state_reference'
if ($data.blocked_state_reference.sha256 -isnot [string] -or
    $data.blocked_state_reference.sha256 -notmatch '^[a-f0-9]{64}$') {
  Fail HASH 'invalid blocked state reference hash'
}
$blockedPath = Get-SafeRepoFile ([string]$data.blocked_state_reference.path)
if ([IO.Path]::GetFullPath($blockedPath) -cne [IO.Path]::GetFullPath($BlockedState)) {
  Fail PATH 'blocked state does not match trusted persisted input'
}
$blockedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $blockedPath).Hash.ToLowerInvariant()
if ($blockedHash -cne $data.blocked_state_reference.sha256) {
  Fail HASH 'blocked state reference hash mismatch'
}
try {
  $blocked = Get-Content -Raw -LiteralPath $blockedPath |
    ConvertFrom-Json -DateKind String
} catch {
  Fail JSON "invalid blocked state: $($_.Exception.Message)"
}
Assert-ExactNames $blocked @(
  'schema','task_id','blocked_task_contract_sha256','tier','failure_class',
  'attempt_number','reason','blocked_at'
) 'blocked state'
if ($blocked.schema -cne 'terminal-tier-blocked-state/v1') {
  Fail JSON 'unsupported blocked state schema'
}
if ($blocked.task_id -cne $ExpectedTask) {
  Fail TASK 'blocked state task_id does not match expected task'
}
if ($blocked.blocked_task_contract_sha256 -cne $data.blocked_task_contract_sha256) {
  Fail HASH 'blocked task contract hash does not match persisted blocked state'
}
if ($blocked.tier -cne 'strong' -or $blocked.reason -cne 'terminal-tier-recurrence') {
  Fail CONTRACT 'blocked state is not a terminal-tier recurrence'
}
$validFailureClasses = @(
  'test','lint','typecheck','build','review-major','review-critical'
)
if ($blocked.failure_class -isnot [string] -or
    $blocked.failure_class -cnotin $validFailureClasses) {
  Fail CONTRACT 'invalid blocked state failure class'
}
if ($blocked.attempt_number -isnot [long] -or $blocked.attempt_number -lt 2) {
  Fail CONTRACT 'invalid blocked state attempt number'
}
if ($blocked.blocked_at -isnot [string] -or
    $blocked.blocked_at -notmatch
      '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$') {
  Fail CONTRACT 'invalid blocked state timestamp'
}
if ($data.blocked_task_contract_sha256 -ceq $data.revised_task_contract_sha256) {
  Fail CONTRACT 'task contract was not revised after terminal blocking'
}
Assert-ExactNames $data.diagnosis_reference @('path','sha256') 'diagnosis_reference'
if ($data.diagnosis_reference.sha256 -isnot [string] -or
    $data.diagnosis_reference.sha256 -notmatch '^[a-f0-9]{64}$') {
  Fail HASH 'invalid diagnosis reference hash'
}
$diagnosisPath = Get-SafeRepoFile ([string]$data.diagnosis_reference.path)
$diagnosisHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $diagnosisPath).Hash.ToLowerInvariant()
if ($diagnosisHash -cne $data.diagnosis_reference.sha256) {
  Fail HASH 'diagnosis reference hash mismatch'
}

Assert-ExactNames $data.human_reapproval @('authority','timestamp') 'human_reapproval'
if ($data.human_reapproval.authority -isnot [string] -or
    $data.human_reapproval.authority -notmatch '^[A-Za-z0-9][A-Za-z0-9._:@ -]{1,127}$') {
  Fail APPROVAL 'invalid human reapproval authority'
}
$approvalTimestamp = if ($data.human_reapproval.timestamp -is [string] -and
          $data.human_reapproval.timestamp -match
          '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$') {
  $data.human_reapproval.timestamp
} else {
  Fail APPROVAL 'invalid human reapproval timestamp'
}

$tasksText = Get-Content -Raw -LiteralPath $Tasks
$escapedTask = [regex]::Escape($ExpectedTask)
$match = [regex]::Match(
  $tasksText, "(?ms)^## $escapedTask\b.*?(?=^## T-[0-9]{3}\b|\z)")
if (-not $match.Success) { Fail TASK 'task section is missing' }
$section = $match.Value
$sectionContract = $section.TrimEnd([char[]]"`r`n")
$sectionHash = [Convert]::ToHexString(
  [Security.Cryptography.SHA256]::HashData(
    [Text.UTF8Encoding]::new($false).GetBytes($sectionContract))).ToLowerInvariant()
if ($sectionHash -cne $data.revised_task_contract_sha256) {
  Fail HASH 'revised task contract hash does not match the task section'
}
if ($section -notmatch '(?m)^Approval: Approved(?:\b| \()') {
  Fail APPROVAL 'task is not explicitly reapproved'
}
if ($section -notmatch '(?m)^Status: (?:Planned|In Progress)$') {
  Fail APPROVAL 'reapproved task is not eligible to resume'
}
if (-not $section.Contains(
    "Diagnosis Reference: $($data.diagnosis_reference.path)",
    [StringComparison]::Ordinal)) {
  Fail DIAGNOSIS 'tasks.md does not record the diagnosis reference'
}
$expectedReapproval = "Terminal Reapproval: $($data.human_reapproval.authority) @ $approvalTimestamp"
if (-not $section.Contains($expectedReapproval, [StringComparison]::Ordinal)) {
  Fail APPROVAL 'tasks.md does not record matching terminal reapproval'
}
Write-Output 'TERMINAL_RESUME_OK'
