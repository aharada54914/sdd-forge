function Get-ReviewPluginFile([string]$Relative) {
  if ($Relative -cnotmatch '^plugins/(sdd-review-loop|sdd-quality-loop)/(.+)$') { throw "unsupported review asset: $Relative" }
  $package = $Matches[1]; $remainder = $Matches[2]
  $owner = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
  if ((Split-Path -Leaf $owner) -ceq 'sdd-review-loop') {
    return Join-Path (Split-Path -Parent $owner) "$package/$remainder"
  }
  return Join-Path (Split-Path -Parent (Split-Path -Parent $owner)) "$package/$(Split-Path -Leaf $owner)/$remainder"
}

function Get-FixedInputSources {
  param([string]$Root, [string]$Record, [string]$Snapshot, [bool]$VerifyInputs)
  if ([bool]$Record -ne [bool]$Snapshot) { throw 'fixed input record and snapshot must be supplied together' }
  if (-not $Record) { return $null }
  if (-not $VerifyInputs) { throw 'fixed input options require -VerifyInputs' }
  $output = & python3 (Join-Path $PSScriptRoot '../fixed-review-inputs.py') source-map --repo $Root --record $Record --snapshot $Snapshot
  if ($LASTEXITCODE -ne 0) { throw 'fixed review input verification failed' }
  return ($output | ConvertFrom-Json).sources
}

function Get-ReviewInputSource {
  param([string]$Root, [string]$Relative, $Sources)
  if ($null -eq $Sources) { return Join-Path $Root $Relative }
  $entry = @($Sources.PSObject.Properties | Where-Object { $_.Name -ceq $Relative })
  if ($entry.Count -ne 1) { throw "fixed input selection is missing required input: $Relative" }
  return [string]$entry[0].Value
}
