param(
  [Parameter(Mandatory=$true)][ValidateSet('low','medium','high','critical')][string]$Risk,
  [string[]]$Candidate = @(),
  [string]$FailureClass,
  [string]$FailureHistory = '',
  [ValidateSet('','lightweight','standard','strong')][string]$PreviousTier = '',
  [int]$ConsecutiveFailures = 0,
  [string]$Registry = "",
  [string]$CandidatesFile = "",
  [ValidateSet('','lightweight','standard','strong')][string]$RequiredTier = '',
  [ValidateSet('','lightweight','standard','strong')][string]$MinimumTier = '',
  [switch]$Json,
  [string]$XhighReason = '',
  [int]$AttemptNumber = 0,
  [string]$DeterministicRuntimeCommand = 'pwsh'
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($DeterministicRuntimeCommand) -or
    -not (Get-Command $DeterministicRuntimeCommand -ErrorAction SilentlyContinue)) {
  Write-Output 'BLOCKED deterministic-runtime-unavailable'
  exit 0
}
if (-not $Registry) {
  $Registry = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path `
    'contracts/agent-model-capabilities.json'
}

$matrix = @{
  low = @{ lightweight = 1; standard = 1; strong = 1 }
  medium = @{ lightweight = 2; standard = 1; strong = 1 }
  high = @{ lightweight = 3; standard = 2; strong = 1 }
  critical = @{ lightweight = 3; standard = 2; strong = 1 }
}
$tierRank = @{ lightweight = 0; standard = 1; strong = 2 }
$effortRank = @{ '' = 0; low = 0; medium = 1; high = 2; xhigh = 3 }
$validFailureClasses = @('test','lint','typecheck','build','review-major','review-critical')
$costPattern = '^(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$'
function Convert-CandidateCost($Value) {
  if ($Value -isnot [string] -or $Value -cnotmatch $costPattern) {
    throw 'cost'
  }
  return [decimal]::Parse(
    $Value, [Globalization.NumberStyles]::AllowDecimalPoint,
    [Globalization.CultureInfo]::InvariantCulture)
}
if ($FailureClass -and $FailureClass -cnotin $validFailureClasses) {
  throw 'MODEL_SELECTION_ERROR: invalid failure class'
}
if ($FailureHistory) {
  $history = @($FailureHistory.Split(','))
  if (@($history | Where-Object { $_ -cnotin $validFailureClasses }).Count -gt 0) {
    throw 'MODEL_SELECTION_ERROR: invalid failure history'
  }
  $FailureClass = $history[-1]
  $ConsecutiveFailures = if ($history.Count -ge 2 -and
    $history[-1] -ceq $history[-2]) { 2 } else { 1 }
}
if ($ConsecutiveFailures -lt 0) {
  throw 'MODEL_SELECTION_ERROR: invalid recurrence'
}
if ($AttemptNumber -lt 0) {
  throw 'MODEL_SELECTION_ERROR: invalid attempt number'
}
if ($ConsecutiveFailures -ge 2 -and -not $FailureClass) {
  throw 'MODEL_SELECTION_ERROR: recurrence requires a failure class'
}
$escalationTier = ''
if ($ConsecutiveFailures -ge 2) {
  if (-not $PreviousTier) {
    throw 'MODEL_SELECTION_ERROR: recurrence requires a previous tier'
  }
  if ($AttemptNumber -lt 1) {
    throw 'MODEL_SELECTION_ERROR: recurrence requires an attempt number'
  }
  if ($PreviousTier -ceq 'strong') {
    if ($Json) {
      [ordered]@{
        status = 'BLOCKED'
        reason = 'terminal-tier-recurrence'
        escalation = [ordered]@{
          prior_tier = $PreviousTier
          next_tier = $null
          failure_class = $FailureClass
          attempt_number = $AttemptNumber
          reason = 'terminal-tier-recurrence'
        }
      } | ConvertTo-Json -Compress -Depth 3
    } else {
      Write-Output (
        'BLOCKED terminal-tier-recurrence ' +
        "prior_tier=$PreviousTier next_tier=null " +
        "failure_class=$FailureClass attempt_number=$AttemptNumber " +
        'reason=terminal-tier-recurrence')
    }
    exit 0
  }
  $escalationTier = if ($PreviousTier -ceq 'lightweight') { 'standard' } else { 'strong' }
}
$availableNames = [Collections.Generic.List[string]]::new()
if ($CandidatesFile) {
  try {
    $capabilities = Get-Content -Raw -LiteralPath $Registry | ConvertFrom-Json
    $candidateData = Get-Content -Raw -LiteralPath $CandidatesFile |
      ConvertFrom-Json -NoEnumerate -DateKind String
    if ($capabilities.schema -cne 'agent-model-capabilities/v1') { throw 'schema' }
    if ($candidateData -isnot [Array]) { throw 'candidate-root' }
    $registered = @{}
    foreach ($model in @($capabilities.models)) {
      if (-not $tierRank.ContainsKey([string]$model.canonical_tier)) { throw 'tier' }
      $registered[[string]$model.name] = $model
    }
    $parsed = foreach ($item in @($candidateData)) {
      $name = [string]$item.name
      if (-not $registered.ContainsKey($name)) { throw 'model' }
      $definition = $registered[$name]
      $effort = [string]$item.effort
      if ($effort -notin @($definition.efforts) -or $item.available -isnot [bool]) {
        throw 'candidate'
      }
      $cost = Convert-CandidateCost $item.cost
      if ([bool]$item.available) {
        [void]$availableNames.Add($name)
        [pscustomobject]@{
          Name = $name
          Tier = [string]$definition.canonical_tier
          Cost = $cost
          Effort = $effort
        }
      }
    }
  } catch {
    throw 'MODEL_SELECTION_ERROR: invalid capability candidates'
  }
} else {
  $parsed = foreach ($item in $Candidate) {
    $parts = $item.Split(':')
    if ($parts.Count -ne 3) { throw "MODEL_SELECTION_ERROR: invalid candidate" }
    if (-not $tierRank.ContainsKey($parts[1])) { throw "MODEL_SELECTION_ERROR: invalid tier" }
    [void]$availableNames.Add($parts[0])
    [pscustomobject]@{
      Name = $parts[0]
      Tier = $parts[1]
      Cost = Convert-CandidateCost $parts[2]
      Effort = ''
    }
  }
}
$eligible = @($parsed | Where-Object {
  (-not $escalationTier -or $_.Tier -ceq $escalationTier) -and
  (-not $RequiredTier -or $_.Tier -ceq $RequiredTier) -and
  (-not $MinimumTier -or $tierRank[$_.Tier] -ge $tierRank[$MinimumTier]) -and
  ($_.Effort -cne 'xhigh' -or [bool]$XhighReason)
})
if ($eligible.Count -eq 0) {
  Write-Output 'BLOCKED model-tier-unavailable'
  exit 0
}
$winner = $null
foreach ($eligibleCandidate in $eligible) {
  if ($null -eq $winner) {
    $winner = $eligibleCandidate
    continue
  }
  $candidateRanks = @(
    $matrix[$Risk][$eligibleCandidate.Tier],
    $tierRank[$eligibleCandidate.Tier],
    $effortRank[$eligibleCandidate.Effort],
    $eligibleCandidate.Cost
  )
  $winnerRanks = @(
    $matrix[$Risk][$winner.Tier],
    $tierRank[$winner.Tier],
    $effortRank[$winner.Effort],
    $winner.Cost
  )
  $replaceWinner = $false
  for ($index = 0; $index -lt $candidateRanks.Count; $index++) {
    if ($candidateRanks[$index] -lt $winnerRanks[$index]) {
      $replaceWinner = $true
      break
    }
    if ($candidateRanks[$index] -gt $winnerRanks[$index]) { break }
    if ($index -eq $candidateRanks.Count - 1 -and
        [StringComparer]::Ordinal.Compare($eligibleCandidate.Name, $winner.Name) -lt 0) {
      $replaceWinner = $true
    }
  }
  if ($replaceWinner) { $winner = $eligibleCandidate }
}
if ($Json) {
  [ordered]@{
    model = $winner.Name
    canonical_tier = $winner.Tier
    effort = if ($winner.Effort) { $winner.Effort } else { $null }
    estimated_cost_per_attempt_usd = $winner.Cost.ToString(
      [Globalization.CultureInfo]::InvariantCulture)
    available_candidates = @($availableNames | Sort-Object -Unique)
    xhigh_reason = if ($winner.Effort -ceq 'xhigh') { $XhighReason } else { $null }
    escalation = if ($escalationTier) {
      [ordered]@{
        prior_tier = $PreviousTier
        next_tier = $escalationTier
        failure_class = $FailureClass
        attempt_number = $AttemptNumber
        reason = 'same-classified-failure-twice'
      }
    } else { $null }
  } | ConvertTo-Json -Compress
} else {
  $suffix = if ($escalationTier) {
    " prior_tier=$PreviousTier next_tier=$escalationTier" +
      " failure_class=$FailureClass attempt_number=$AttemptNumber" +
      ' reason=same-classified-failure-twice'
  } else { '' }
  Write-Output "$($winner.Name) $($winner.Tier)$suffix"
}
