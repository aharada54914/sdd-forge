param(
  [string]$Manifest,
  [string]$SnapshotRoot,
  [string]$ExpectedTask,
  [string]$EvidenceRoot,
  [string[]]$Batch
)
$ErrorActionPreference = 'Stop'

function Fail([string]$Code, [string]$Message) {
  throw "TASK_INPUT_${Code}: $Message"
}
function Read-Manifest([string]$Path) {
  try {
    $raw = Get-Content -Raw -LiteralPath $Path
    if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) {
      $raw | ConvertFrom-Json -DateKind String
    } else {
      $raw | ConvertFrom-Json
    }
  } catch {
    Fail JSON $_.Exception.Message
  }
}
function Test-RepoPath([object]$Path, [switch]$AllowDirectory) {
  if ($Path -isnot [string] -or [string]::IsNullOrEmpty($Path)) { return $false }
  if ($Path.StartsWith('/', [StringComparison]::Ordinal) -or $Path.Contains('\', [StringComparison]::Ordinal)) { return $false }
  $trimmed = if ($AllowDirectory) { $Path.TrimEnd('/') } else { $Path }
  if ($trimmed.Length -eq 0) { return $false }
  foreach ($part in $trimmed.Split('/')) {
    if ($part -eq '' -or $part -eq '.' -or $part -eq '..') { return $false }
  }
  return $Path -match '^[A-Za-z0-9][A-Za-z0-9._/-]*$'
}
function Get-PropertyNames($Object) {
  @($Object.PSObject.Properties | Select-Object -ExpandProperty Name)
}
function Test-UtcTimestamp($Value) {
  if ($Value -isnot [string] -or $Value -notmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$') { return $false }
  $parsed = [datetime]::MinValue
  $styles = [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal
  if (-not [datetime]::TryParseExact($Value, 'yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$parsed)) {
    return $false
  }
  return $parsed.Kind -eq [DateTimeKind]::Utc -and $parsed.ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture) -ceq $Value
}
function Test-PathOverlap([string]$First, [string]$Second) {
  $firstNormalized = $First.TrimEnd('/')
  $secondNormalized = $Second.TrimEnd('/')
  return $firstNormalized -ceq $secondNormalized -or
    $firstNormalized.StartsWith($secondNormalized + '/', [StringComparison]::Ordinal) -or
    $secondNormalized.StartsWith($firstNormalized + '/', [StringComparison]::Ordinal)
}
function Open-SafeSnapshotInput([string]$Root, [string]$RelativePath) {
  $rootFull = [IO.Path]::GetFullPath($Root)
  if (-not (Test-Path -LiteralPath $rootFull -PathType Container)) { Fail PATH 'snapshot root is missing or unsafe' }
  $rootItem = Get-Item -LiteralPath $rootFull -Force
  if ($rootItem.LinkType -or ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { Fail PATH 'snapshot root is missing or unsafe' }
  $current = $rootFull
  foreach ($part in $RelativePath.Split('/')) {
    $current = Join-Path $current $part
    if (-not (Test-Path -LiteralPath $current)) { Fail PATH "snapshot input missing or unsafe: $RelativePath" }
    $item = Get-Item -LiteralPath $current -Force
    if ($item.LinkType -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      Fail PATH "snapshot input missing or unsafe: $RelativePath"
    }
  }
  $target = [IO.Path]::GetFullPath($current)
  $prefix = $rootFull.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  if (-not $target.StartsWith($prefix, [StringComparison]::Ordinal) -or -not (Test-Path -LiteralPath $target -PathType Leaf)) {
    Fail PATH "snapshot input missing or unsafe: $RelativePath"
  }
  try {
    return [IO.File]::Open($target, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
  } catch {
    Fail PATH "snapshot input missing or unsafe: $RelativePath"
  }
}
function Read-ReloadEvidence($Data, [bool]$BindManifest = $true) {
  $stream = Open-SafeSnapshotInput $EvidenceRoot 'handoffs/reload-evidence.txt'
  try {
    $memory = [IO.MemoryStream]::new()
    try {
      $stream.CopyTo($memory)
      $payload = $memory.ToArray()
    } finally {
      $memory.Dispose()
    }
  } finally {
    $stream.Dispose()
  }
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $actualEvidenceHash = [BitConverter]::ToString($sha.ComputeHash($payload)).Replace('-','').ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
  if ($actualEvidenceHash -cne $Data.handoff_reload_evidence_hash) { Fail HANDOFF 'fallback evidence artifact hash mismatch' }
  try {
    $raw = [Text.UTF8Encoding]::new($false, $true).GetString($payload)
    if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) {
      $evidence = $raw | ConvertFrom-Json -DateKind String
    } else {
      $evidence = $raw | ConvertFrom-Json
    }
  } catch {
    Fail HANDOFF 'fallback evidence artifact is not valid UTF-8 JSON'
  }
  $expectedNames = @('agent_instance_id','fallback_reason','implementation_subagents_available','schema','session_id','task_runs')
  $actualNames = @(Get-PropertyNames $evidence | Sort-Object -CaseSensitive)
  if (($actualNames -join ',') -cne ($expectedNames -join ',')) { Fail HANDOFF 'fallback evidence artifact has invalid fields' }
  if (
    $evidence.schema -cne 'implementation-host-capability/v1' -or
    $evidence.implementation_subagents_available -isnot [bool] -or
    $evidence.implementation_subagents_available -ne $false -or
    $evidence.fallback_reason -cne 'host-does-not-support-implementation-subagents' -or
    $evidence.session_id -cne $Data.session_id -or
    $evidence.agent_instance_id -cne $Data.agent_instance_id
  ) {
    Fail HANDOFF 'fallback evidence does not prove incapable-host identity'
  }
  if ($evidence.task_runs -isnot [System.Array] -or $evidence.task_runs.Count -eq 0) {
    Fail HANDOFF 'fallback evidence task_runs must be non-empty'
  }
  $pairs = @{}
  foreach ($entry in @($evidence.task_runs)) {
    $entryNames = @(Get-PropertyNames $entry | Sort-Object -CaseSensitive)
    if (
      ($entryNames -join ',') -cne 'run_id,task_id' -or
      $entry.task_id -isnot [string] -or $entry.task_id -notmatch '^T-[0-9]{3}$' -or
      $entry.run_id -isnot [string] -or $entry.run_id -notmatch '^[A-Za-z0-9][A-Za-z0-9._:-]*$'
    ) {
      Fail HANDOFF 'fallback evidence contains invalid task/run identity'
    }
    $key = "$($entry.task_id)`n$($entry.run_id)"
    if ($pairs.ContainsKey($key)) { Fail HANDOFF 'fallback evidence contains duplicate task/run identity' }
    $pairs[$key] = $true
  }
  $manifestKey = "$($Data.task_id)`n$($Data.run_id)"
  if ($BindManifest -and -not $pairs.ContainsKey($manifestKey)) { Fail HANDOFF 'fallback evidence does not bind manifest task/run identity' }
  return $evidence
}
function Test-One([string]$Path, [bool]$CheckSnapshot, [bool]$BatchValidation = $false) {
  $data = Read-Manifest $Path
  $required = @('schema','task_id','run_id','session_id','agent_instance_id','model_tier','provider','model','estimated_cost_per_attempt_usd','cost_estimate_source','cost_estimate_timestamp','isolation_mode','fallback_reason','handoff_reload_evidence_hash','allowed_inputs','allowed_outputs')
  $names = @(Get-PropertyNames $data)
  foreach ($name in $names) {
    if ($required -cnotcontains $name) { Fail JSON "unexpected field: $name" }
  }
  foreach ($name in $required) {
    if ($names -cnotcontains $name) {
      if (@('estimated_cost_per_attempt_usd','cost_estimate_source','cost_estimate_timestamp') -ccontains $name) { Fail COST "missing field: $name" }
      if (@('task_id','run_id','session_id','agent_instance_id') -ccontains $name) { Fail IDENTITY "missing field: $name" }
      if (@('model_tier','provider','model') -ccontains $name) { Fail MODEL "missing field: $name" }
      Fail JSON "missing field: $name"
    }
  }
  if ($data.schema -cne 'task-input-manifest/v1') { Fail JSON 'unsupported schema' }
  if ($data.task_id -isnot [string] -or $data.task_id -notmatch '^T-[0-9]{3}$') { Fail IDENTITY 'invalid task_id' }
  if ($ExpectedTask -and $data.task_id -cne $ExpectedTask) { Fail IDENTITY 'task_id does not match expected task' }
  foreach ($field in @('run_id','session_id','agent_instance_id')) {
    if ($data.$field -isnot [string] -or $data.$field -notmatch '^[A-Za-z0-9][A-Za-z0-9._:-]*$') { Fail IDENTITY "invalid $field" }
  }
  if (@('lightweight','standard','strong') -cnotcontains $data.model_tier) { Fail MODEL 'invalid model_tier' }
  foreach ($field in @('provider','model')) {
    if ($data.$field -isnot [string] -or $data.$field -notmatch '^[A-Za-z0-9][A-Za-z0-9._:-]*$') { Fail MODEL "invalid $field" }
  }
  if ($data.estimated_cost_per_attempt_usd -isnot [string] -or $data.estimated_cost_per_attempt_usd -notmatch '^(0|[1-9][0-9]*)(\.[0-9]+)?$') { Fail COST 'invalid estimated_cost_per_attempt_usd' }
  if ($data.cost_estimate_source -isnot [string] -or $data.cost_estimate_source.Length -eq 0) { Fail COST 'missing cost_estimate_source' }
  if (-not (Test-UtcTimestamp $data.cost_estimate_timestamp)) { Fail COST 'invalid cost_estimate_timestamp' }
  if (@('fresh-agent','same-session-file-reload') -cnotcontains $data.isolation_mode) { Fail ISOLATION 'invalid isolation_mode' }
  if ($data.isolation_mode -ceq 'fresh-agent') {
    if ($data.fallback_reason -cne '' -or $data.handoff_reload_evidence_hash -cne '') { Fail ISOLATION 'fresh-agent forbids fallback fields' }
  } else {
    if ($data.fallback_reason -cne 'host-does-not-support-implementation-subagents') { Fail HANDOFF 'same-session fallback requires incapable-host reason' }
    if ($data.handoff_reload_evidence_hash -isnot [string] -or $data.handoff_reload_evidence_hash -notmatch '^[a-f0-9]{64}$') { Fail HANDOFF 'same-session fallback requires handoff_reload_evidence_hash' }
  }
  if ($data.allowed_inputs -isnot [System.Array] -or $data.allowed_inputs.Count -eq 0) { Fail PATH 'allowed_inputs must be non-empty' }
  if ($data.allowed_outputs -isnot [System.Array] -or $data.allowed_outputs.Count -eq 0) { Fail PATH 'allowed_outputs must be non-empty' }
  $seenInputs = @{}
  foreach ($entry in @($data.allowed_inputs)) {
    $entryNames = @(Get-PropertyNames $entry)
    if (($entryNames | Sort-Object -CaseSensitive) -join ',' -cne 'path,sha256') { Fail PATH 'invalid allowed_inputs entry' }
    if (-not (Test-RepoPath $entry.path) -or $entry.path.EndsWith('/', [StringComparison]::Ordinal)) { Fail PATH "invalid input path: $($entry.path)" }
    if ($seenInputs.ContainsKey($entry.path)) { Fail PATH "duplicate input path: $($entry.path)" }
    $seenInputs[$entry.path] = $true
    if ($entry.sha256 -isnot [string] -or $entry.sha256 -notmatch '^[a-f0-9]{64}$') { Fail HASH "invalid sha256 for $($entry.path)" }
    if ($CheckSnapshot) {
      $stream = Open-SafeSnapshotInput $SnapshotRoot $entry.path
      try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
          $actual = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLowerInvariant()
        } finally {
          $sha.Dispose()
        }
      } finally {
        $stream.Dispose()
      }
      if ($actual -cne $entry.sha256) { Fail HASH "snapshot hash mismatch: $($entry.path)" }
    }
  }
  if ($data.isolation_mode -ceq 'same-session-file-reload') {
    $evidenceEntries = @($data.allowed_inputs | Where-Object { $_.path -ceq 'handoffs/reload-evidence.txt' })
    if ($evidenceEntries.Count -ne 1) { Fail HANDOFF 'fallback requires allowed input: handoffs/reload-evidence.txt' }
    if ($evidenceEntries[0].sha256 -cne $data.handoff_reload_evidence_hash) { Fail HANDOFF 'fallback evidence hash does not match allowed input' }
    if ([string]::IsNullOrEmpty($EvidenceRoot)) { Fail HANDOFF 'fallback evidence root is required' }
    Read-ReloadEvidence $data (-not $BatchValidation) | Out-Null
  }
  $seenOutputs = @{}
  foreach ($output in @($data.allowed_outputs)) {
    if (-not (Test-RepoPath $output -AllowDirectory)) { Fail PATH "invalid output path: $output" }
    if ($seenOutputs.ContainsKey($output)) { Fail PATH "duplicate output path: $output" }
    foreach ($inputPath in $seenInputs.Keys) {
      if (Test-PathOverlap $output $inputPath) { Fail PATH "output overlaps input path: $output" }
    }
    foreach ($priorOutput in $seenOutputs.Keys) {
      if (Test-PathOverlap $output $priorOutput) { Fail PATH "output overlaps output path: $output" }
    }
    $seenOutputs[$output] = $true
  }
  return $data
}

if ($Batch -and $Batch.Count -gt 0) {
  $taskIds = @{}
  $runIds = @{}
  $freshSessions = @{}
  $freshAgents = @{}
  $modes = @{}
  $fallbackReasons = @{}
  $fallbackHashes = @{}
  $fallbackSessions = @{}
  $fallbackAgents = @{}
  $expectedPairs = @{}
  foreach ($path in $Batch) {
    $data = Test-One $path $false $true
    $modes[$data.isolation_mode] = $true
    if ($modes.Count -ne 1) { Fail ISOLATION 'batch cannot mix fresh-agent and same-session fallback' }
    foreach ($pair in @(@('task_id',$taskIds), @('run_id',$runIds))) {
      $field = $pair[0]
      $seen = $pair[1]
      if ($seen.ContainsKey($data.$field)) { Fail IDENTITY "duplicate ${field}: $($data.$field)" }
      $seen[$data.$field] = $true
    }
    $expectedPairs["$($data.task_id)`n$($data.run_id)"] = $true
    if ($data.isolation_mode -ceq 'fresh-agent') {
      if ($freshSessions.ContainsKey($data.session_id)) { Fail IDENTITY "duplicate session_id: $($data.session_id)" }
      if ($freshAgents.ContainsKey($data.agent_instance_id)) { Fail IDENTITY "duplicate agent_instance_id: $($data.agent_instance_id)" }
      $freshSessions[$data.session_id] = $true
      $freshAgents[$data.agent_instance_id] = $true
    } else {
      $fallbackReasons[$data.fallback_reason] = $true
      $fallbackHashes[$data.handoff_reload_evidence_hash] = $true
      $fallbackSessions[$data.session_id] = $true
      $fallbackAgents[$data.agent_instance_id] = $true
    }
  }
  if ($modes.ContainsKey('same-session-file-reload')) {
    if ($fallbackReasons.Count -ne 1 -or $fallbackHashes.Count -ne 1) {
      Fail ISOLATION 'fallback batch must share one capability decision and evidence'
    }
    if ($fallbackSessions.Count -ne 1 -or $fallbackAgents.Count -ne 1) {
      Fail IDENTITY 'fallback batch must reuse one physical session and agent'
    }
    $evidence = Read-ReloadEvidence $data
    $actualPairs = @{}
    foreach ($entry in @($evidence.task_runs)) {
      $actualPairs["$($entry.task_id)`n$($entry.run_id)"] = $true
    }
    if ($actualPairs.Count -ne $expectedPairs.Count) { Fail HANDOFF 'fallback evidence task_runs do not match complete batch' }
    foreach ($key in $expectedPairs.Keys) {
      if (-not $actualPairs.ContainsKey($key)) { Fail HANDOFF 'fallback evidence task_runs do not match complete batch' }
    }
  }
} elseif ($Manifest) {
  Test-One $Manifest ([bool]$SnapshotRoot) | Out-Null
} else {
  Fail JSON 'missing -Manifest or -Batch'
}
Write-Output 'TASK_INPUT_OK'
