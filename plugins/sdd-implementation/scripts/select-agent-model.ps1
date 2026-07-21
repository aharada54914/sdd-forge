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
  [string]$DeterministicRuntimeCommand = 'pwsh',
  [ValidateSet('welded','matrix')][string]$EffortPolicy = 'matrix',
  [ValidateSet('','low','medium','high','xhigh')][string]$RequestedEffort = '',
  [string]$Role = '',
  # Named HostName, not Host: `$Host` is a PowerShell read-only automatic
  # variable (the host program), so a `-Host` parameter would collide with
  # it (design.md API/Contract Plan T-002; the bash twin keeps `--host`
  # since bash has no such reserved name).
  [ValidateSet('claude-code','codex-cli')][string]$HostName = 'claude-code'
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

# REQ-002 (T-002, epic-159-pillar-c, #150): v2-only effort vocabulary and
# resolution helpers. $EffortOrder is a SEPARATE ordinal from $effortRank
# above (which is part of the byte-unmodified v1 sort key and maps both ''
# and 'low' to 0 — never reused for v2 clamp/bump arithmetic, where '' is
# never a valid member). Every comparison is case-sensitive (-ceq/-cnotin)
# per this repository's established mis-cased-value hazard guard.
$EffortValues = @('low','medium','high','xhigh')
$EffortOrder = @('low','medium','high','xhigh')
function Get-EffortRank([string]$Value) {
  $index = [Array]::IndexOf($EffortOrder, $Value)
  if ($index -lt 0) { throw "MODEL_SELECTION_ERROR: invalid effort value: $Value" }
  return $index
}
function Get-ClampedEffort([string]$Value, [string[]]$Supported) {
  # Clamp `Value` to the nearest member of `Supported` (AC-009).
  $ranks = @($Supported | ForEach-Object { Get-EffortRank $_ } | Sort-Object)
  $target = Get-EffortRank $Value
  if ($ranks -ccontains $target) { return $EffortOrder[$target] }
  if ($target -lt $ranks[0]) { return $EffortOrder[$ranks[0]] }
  if ($target -gt $ranks[-1]) { return $EffortOrder[$ranks[-1]] }
  $below = ($ranks | Where-Object { $_ -lt $target } | Measure-Object -Maximum).Maximum
  $above = ($ranks | Where-Object { $_ -gt $target } | Measure-Object -Minimum).Minimum
  if (($target - $below) -le ($above - $target)) { return $EffortOrder[$below] }
  return $EffortOrder[$above]
}
function Get-BumpedEffort([string]$Value) {
  $index = [Math]::Min((Get-EffortRank $Value) + 1, $EffortOrder.Count - 1)
  return $EffortOrder[$index]
}
function Test-HasProperty($Object, [string]$Name) {
  if ($null -eq $Object) { return $false }
  return [bool]($Object.PSObject.Properties.Name -ccontains $Name)
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

# `$parsed` items carry SortEffort/FinalEffort/Source. SortEffort feeds the
# EXISTING, byte-unmodified sort-key tiebreak (`$effortRank[$_.SortEffort]`,
# below) exactly as it always has: for v1 and legacy-positional candidates
# it IS the declared/only effort concept, so SortEffort -ceq FinalEffort
# there always and Source stays $null (v1/legacy passenger, never observed
# in output). For v2, SortEffort stays the CANDIDATES-FILE-declared value
# (or '' if the candidate omitted it) so the existing tiebreak keeps its
# original meaning; FinalEffort is the REQ-002 policy-resolved value used
# for the xhigh eligibility gate and for JSON/text reporting, since
# design.md requires that gate to run "computed AFTER the bump, not before
# it".
$availableNames = [Collections.Generic.List[string]]::new()
$v2Active = $false
$hostControlMap = [System.Collections.Generic.Dictionary[string,object]]::new(
  [System.StringComparer]::Ordinal)
if ($CandidatesFile) {
  try {
    $capabilities = Get-Content -Raw -LiteralPath $Registry | ConvertFrom-Json -NoEnumerate
    $candidateData = Get-Content -Raw -LiteralPath $CandidatesFile |
      ConvertFrom-Json -NoEnumerate -DateKind String
    if ($candidateData -isnot [Array]) { throw 'candidate-root' }
    $schema = [string]$capabilities.schema
    if ($schema -ceq 'agent-model-capabilities/v1') {
      # EXISTING, byte-unmodified v1 path (AC-006): only the emitted
      # object shape below is widened (two trailing fields that always
      # mirror Effort, never observed by v1 output).
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
        if ($effort -cnotin @($definition.efforts) -or $item.available -isnot [bool]) {
          throw 'candidate'
        }
        $cost = Convert-CandidateCost $item.cost
        if ([bool]$item.available) {
          [void]$availableNames.Add($name)
          [pscustomobject]@{
            Name = $name
            Tier = [string]$definition.canonical_tier
            Cost = $cost
            SortEffort = $effort
            FinalEffort = $effort
            Source = $null
          }
        }
      }
    } elseif ($schema -ceq 'agent-model-capabilities/v2') {
      # Case-sensitivity guard, layer 1: every v2 field/value comparison
      # below uses -ceq/-cne/-cin/-cnotin/-ccontains, and every dictionary
      # keyed by untrusted registry/candidate strings (model name, risk
      # key) is an ORDINAL (case-sensitive) .NET Dictionary rather than a
      # bare `@{}` literal — PowerShell's `@{}` hashtable does
      # case-INSENSITIVE string-key lookups by default, which would let a
      # mis-cased registry value (e.g. risk key "Low" or model name
      # "Anthropic/Haiku") silently alias a correctly-cased one instead of
      # being rejected. `$RecognizedRiskKeys` guards the SAME hazard for
      # the risk_effort_matrix key-recognition gate below.
      $v2Active = $true
      $RecognizedRiskKeys = @('low','medium','high','critical')
      $RecognizedTiers = @('lightweight','standard','strong')
      $riskMatrix = [System.Collections.Generic.Dictionary[string,string]]::new(
        [System.StringComparer]::Ordinal)
      $escalationBumpEnabled = $false
      if (Test-HasProperty $capabilities 'risk_effort_matrix') {
        $riskMatrixRaw = $capabilities.risk_effort_matrix
        if ($riskMatrixRaw -isnot [System.Management.Automation.PSCustomObject]) { throw 'risk-matrix' }
        foreach ($property in $riskMatrixRaw.PSObject.Properties) {
          if ($property.Name -ceq 'escalation_bump') {
            if ($property.Value -isnot [bool]) { throw 'escalation-bump' }
            $escalationBumpEnabled = [bool]$property.Value
            continue
          }
          if ($RecognizedRiskKeys -cnotcontains $property.Name) { continue }
          if ($property.Value -isnot [string] -or $property.Value -cnotin $EffortValues) {
            throw 'risk-matrix-value'
          }
          $riskMatrix[$property.Name] = [string]$property.Value
        }
      }
      $roleDefaults = $null
      if (Test-HasProperty $capabilities 'role_defaults') {
        $roleDefaults = $capabilities.role_defaults
      }
      $registered = [System.Collections.Generic.Dictionary[string,object]]::new(
        [System.StringComparer]::Ordinal)
      foreach ($model in @($capabilities.models)) {
        if ($RecognizedTiers -cnotcontains [string]$model.canonical_tier) { continue }
        $supported = $model.supported_efforts
        if ($supported -isnot [Array] -or @($supported).Count -eq 0 -or
            @(@($supported) | Where-Object {
              $_ -isnot [string] -or $_ -cnotin $EffortValues
            }).Count -gt 0) {
          throw 'supported-efforts'
        }
        $defaultEffort = [string]$model.default_effort
        if ($defaultEffort -cnotin @($supported)) { throw 'default-effort' }
        $control = $model.effort_control
        if ($control -isnot [System.Management.Automation.PSCustomObject]) { throw 'effort-control' }
        foreach ($hostKey in @('claude-code','codex-cli')) {
          if ((Test-HasProperty $control $hostKey) -and
              ([string]$control.$hostKey) -cnotin @('flag','frontmatter','none')) {
            throw 'effort-control-value'
          }
        }
        $registered[[string]$model.name] = $model
      }
      $roleMinTier = $null
      $roleDefaultEffort = $null
      if ($Role -and $roleDefaults -and (Test-HasProperty $roleDefaults $Role)) {
        $roleEntry = $roleDefaults.$Role
        if ($roleEntry -is [System.Management.Automation.PSCustomObject]) {
          if ((Test-HasProperty $roleEntry 'minimum_tier') -and
              ($RecognizedTiers -ccontains [string]$roleEntry.minimum_tier)) {
            $roleMinTier = [string]$roleEntry.minimum_tier
          }
          if ((Test-HasProperty $roleEntry 'default_effort') -and
              ([string]$roleEntry.default_effort) -cin $EffortValues) {
            $roleDefaultEffort = [string]$roleEntry.default_effort
          }
        }
      }
      if (-not $MinimumTier -and $roleMinTier) {
        $MinimumTier = $roleMinTier
        if ($RecognizedTiers -cnotcontains $MinimumTier) { throw 'minimum-tier' }
      }
      $parsed = foreach ($item in @($candidateData)) {
        $name = [string]$item.name
        if (-not $registered.ContainsKey($name)) { throw 'model' }
        $definition = $registered[$name]
        $supported = @($definition.supported_efforts)
        if ($item.available -isnot [bool]) { throw 'candidate' }
        $cost = Convert-CandidateCost $item.cost
        $declaredEffort = $null
        if ((Test-HasProperty $item 'effort') -and $null -ne $item.effort) {
          $declaredEffort = [string]$item.effort
          if ($declaredEffort -cnotin $supported) { throw 'candidate-effort' }
        }
        $sortEffort = if ($null -ne $declaredEffort) { $declaredEffort } else { '' }
        if ($RequestedEffort) {
          $baseEffort = $RequestedEffort
          $source = 'requested'
        } elseif ($EffortPolicy -ceq 'welded') {
          $baseEffort = if ($null -ne $declaredEffort) { $declaredEffort } else { [string]$definition.default_effort }
          $source = 'welded'
        } elseif ($riskMatrix.ContainsKey($Risk)) {
          $baseEffort = $riskMatrix[$Risk]
          $source = 'risk-matrix'
        } elseif ($roleDefaultEffort) {
          $baseEffort = $roleDefaultEffort
          $source = 'role-default'
        } else {
          $baseEffort = [string]$definition.default_effort
          $source = 'model-default'
        }
        $finalEffort = Get-ClampedEffort $baseEffort $supported
        if ($source -ceq 'risk-matrix' -and $escalationTier -and $escalationBumpEnabled) {
          $finalEffort = Get-ClampedEffort (Get-BumpedEffort $finalEffort) $supported
        }
        if ([bool]$item.available) {
          [void]$availableNames.Add($name)
          $hostControlMap[$name] = $definition.effort_control
          [pscustomobject]@{
            Name = $name
            Tier = [string]$definition.canonical_tier
            Cost = $cost
            SortEffort = $sortEffort
            FinalEffort = $finalEffort
            Source = $source
          }
        }
      }
    } else {
      throw 'schema'
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
      SortEffort = ''
      FinalEffort = ''
      Source = $null
    }
  }
}
$eligible = @($parsed | Where-Object {
  (-not $escalationTier -or $_.Tier -ceq $escalationTier) -and
  (-not $RequiredTier -or $_.Tier -ceq $RequiredTier) -and
  (-not $MinimumTier -or $tierRank[$_.Tier] -ge $tierRank[$MinimumTier]) -and
  ($_.FinalEffort -cne 'xhigh' -or [bool]$XhighReason)
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
    $effortRank[$eligibleCandidate.SortEffort],
    $eligibleCandidate.Cost
  )
  $winnerRanks = @(
    $matrix[$Risk][$winner.Tier],
    $tierRank[$winner.Tier],
    $effortRank[$winner.SortEffort],
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
  $output = [ordered]@{
    model = $winner.Name
    canonical_tier = $winner.Tier
    effort = if ($winner.FinalEffort) { $winner.FinalEffort } else { $null }
    estimated_cost_per_attempt_usd = $winner.Cost.ToString(
      [Globalization.CultureInfo]::InvariantCulture)
    available_candidates = @($availableNames | Sort-Object -Unique)
    xhigh_reason = if ($winner.FinalEffort -ceq 'xhigh') { $XhighReason } else { $null }
    escalation = if ($escalationTier) {
      [ordered]@{
        prior_tier = $PreviousTier
        next_tier = $escalationTier
        failure_class = $FailureClass
        attempt_number = $AttemptNumber
        reason = 'same-classified-failure-twice'
      }
    } else { $null }
  }
  if ($v2Active) {
    $output.effort_source = $winner.Source
    $control = $null
    [void]$hostControlMap.TryGetValue($winner.Name, [ref]$control)
    $output.effort_control = if ($control -and (Test-HasProperty $control $HostName)) {
      [string]$control.$HostName
    } else { $null }
  }
  $output | ConvertTo-Json -Compress
} else {
  $suffix = if ($escalationTier) {
    " prior_tier=$PreviousTier next_tier=$escalationTier" +
      " failure_class=$FailureClass attempt_number=$AttemptNumber" +
      ' reason=same-classified-failure-twice'
  } else { '' }
  Write-Output "$($winner.Name) $($winner.Tier)$suffix"
}
