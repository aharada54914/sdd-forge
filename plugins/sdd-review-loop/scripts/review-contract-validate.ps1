param(
  [Parameter(Mandatory = $true)][string]$Feature,
  [Parameter(Mandatory = $true)][string]$Attempt,
  [Parameter(Mandatory = $true)][string]$Round,
  [Parameter(Mandatory = $true)][ValidateSet('spec', 'impl', 'task')][string]$Stage,
  [Parameter(Mandatory = $true)][string]$ReportRoot,
  [Parameter(Mandatory = $true)][string]$Contract
)

$ErrorActionPreference = 'Stop'
function Fail([string]$Message) { throw "review-contract-validate: $Message" }
function Is-JsonInteger([object]$Value) {
  return $Value -is [System.Int32] -or $Value -is [System.Int64] -or $Value -is [System.Numerics.BigInteger] -or ($Value -is [double] -and -not [double]::IsNaN($Value) -and -not [double]::IsInfinity($Value) -and [Math]::Floor($Value) -eq $Value)
}

if ($Feature -cnotmatch '^[a-z0-9][a-z0-9-]*$') { Fail 'invalid feature slug' }
if ($Stage -cnotmatch '^(spec|impl|task)$') { Fail 'stage must be spec, impl, or task' }
if ($Attempt -notmatch '^[1-9][0-9]*$') { Fail 'attempt must be a positive integer' }
if ($Round -notmatch '^[1-9][0-9]*$') { Fail 'round must be a positive integer' }
if (-not (Test-Path -LiteralPath $Contract -PathType Leaf)) { Fail 'contract does not exist' }

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$reportsRoot = Join-Path $repoRoot 'reports'
$parent = Split-Path -Parent $ReportRoot
if (-not (Test-Path -LiteralPath $parent -PathType Container)) { Fail 'report root parent does not exist' }
$canonicalRoot = Join-Path (Resolve-Path -LiteralPath $parent).Path (Split-Path -Leaf $ReportRoot)
if (-not $canonicalRoot.StartsWith($reportsRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::Ordinal)) { Fail 'report root escapes reports directory' }
if (Test-Path -LiteralPath $ReportRoot) {
  if (-not (Test-Path -LiteralPath $ReportRoot -PathType Container)) { Fail 'report root must be a directory when it exists' }
  if ((Get-Item -LiteralPath $ReportRoot).LinkType) { Fail 'report root must not be a symlink' }
}

$data = Get-Content -LiteralPath $Contract -Raw | ConvertFrom-Json
$expectedProperties = @('attempt', 'feature', 'input_sha256', 'round', 'run_id', 'schema', 'stage', 'verdict')
$actualProperties = @($data.PSObject.Properties.Name | Sort-Object)
if (@(Compare-Object -CaseSensitive -ReferenceObject $expectedProperties -DifferenceObject $actualProperties).Count -ne 0 -or $data.schema -isnot [string] -or $data.schema -cne 'review-contract/v1' -or $data.feature -isnot [string] -or $data.feature -cne $Feature -or -not (Is-JsonInteger $data.attempt) -or $data.attempt.ToString() -ne $Attempt -or -not (Is-JsonInteger $data.round) -or $data.round.ToString() -ne $Round -or $data.stage -isnot [string] -or $data.stage -cne $Stage -or $data.input_sha256 -isnot [string] -or $data.input_sha256 -cnotmatch '^[0-9a-f]{64}$' -or $data.run_id -isnot [string] -or [string]::IsNullOrWhiteSpace($data.run_id) -or $data.verdict -isnot [string] -or $data.verdict -cne 'PASS') { Fail 'contract identity or PASS verdict is invalid' }

# PowerShell 7.5+ may serialize BigInteger values as objects on macOS. Feature
# and stage are already constrained to JSON-safe tokens, and attempt/round are
# canonical positive integer strings, so emit the protocol JSON directly.
Write-Output ('{"schema":"review-contract-validation/v1","feature":"' + $Feature + '","attempt":' + $Attempt + ',"round":' + $Round + ',"stage":"' + $Stage + '","verdict":"PASS"}')
