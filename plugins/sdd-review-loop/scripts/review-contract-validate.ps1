param(
  [Parameter(Mandatory = $true)][string]$Feature,
  [Parameter(Mandatory = $true)][string]$Attempt,
  [Parameter(Mandatory = $true)][string]$Round,
  [Parameter(Mandatory = $true)][ValidateSet('spec', 'impl', 'task')][string]$Stage,
  [Parameter(Mandatory = $true)][string]$ReportRoot,
  [Parameter(Mandatory = $true)][string]$Contract,
  [string]$RepositoryRoot = ''
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
# Leaf includes POSIX FIFOs; inspect the physical file before opening it.
$contractItem = Get-Item -LiteralPath $Contract -Force
if ([IO.Path]::DirectorySeparatorChar -ne '\' -and ($contractItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
  $contractItem = Get-Item -LiteralPath $contractItem.ResolveLinkTarget($true).FullName -Force
}
$regularContract = $contractItem -is [IO.FileInfo] -and -not ($contractItem.Attributes -band [IO.FileAttributes]::Device)
if ([IO.Path]::DirectorySeparatorChar -ne '\') {
  $unix = $contractItem.PSObject.Properties['UnixStat']
  $regularContract = $regularContract -and $null -ne $unix -and $null -ne $unix.Value -and [string]$unix.Value.ItemType -ceq 'File'
}
if (-not $regularContract) { Fail 'contract is not a regular file' }

if (-not $RepositoryRoot) {
  $pluginRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
  $RepositoryRoot = (Get-Location).Path
  if ($pluginRoot.Replace('\', '/') -cmatch '/plugins/sdd-review-loop$' -and (Test-Path -LiteralPath (Join-Path $pluginRoot '../../.git'))) {
    $RepositoryRoot = (Resolve-Path -LiteralPath (Join-Path $pluginRoot '../..')).Path
  }
}
$repoRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$reportsRoot = Join-Path $repoRoot 'reports'
$parent = Split-Path -Parent $ReportRoot
if (-not (Test-Path -LiteralPath $parent -PathType Container)) { Fail 'report root parent does not exist' }
$leaf = [IO.Path]::GetFileName($ReportRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
if ($leaf -in @('.', '..')) { Fail 'report root must name a child directory' }
$canonicalRoot = Join-Path (Resolve-Path -LiteralPath $parent).Path $leaf
if (-not $canonicalRoot.StartsWith($reportsRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::Ordinal)) { Fail 'report root escapes reports directory' }
# Resolve-Path preserves symlink ancestors. Follow them before containment;
# an internal link remains valid, while a link outside reports cannot authorize it.
function Get-PhysicalDirectory([string]$Path, [int]$Depth = 0) {
  if ($Depth -gt 64) { Fail 'report root symlink resolution exceeded its limit' }
  $item = Get-Item -LiteralPath $Path -Force
  if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    if ($item.PSObject.Methods['ResolveLinkTarget']) {
      $resolvedTarget = $item.ResolveLinkTarget($true)
      if ($null -eq $resolvedTarget) { Fail 'report root symlink target is unavailable' }
      $target = $resolvedTarget.FullName
    } else {
      # Windows PowerShell 5.1 exposes Target but lacks the .NET link API.
      $target = [string]@($item.Target)[0]
      if ([string]::IsNullOrEmpty($target)) { Fail 'report root symlink target is unavailable' }
      if ($target.StartsWith('\??\') -or $target.StartsWith('\\?\')) {
        $target = $target.Substring(4)
        if ($target.StartsWith('UNC\', [StringComparison]::OrdinalIgnoreCase)) { $target = '\\' + $target.Substring(4) }
      }
      if (-not [IO.Path]::IsPathRooted($target)) { $target = Join-Path $item.Parent.FullName $target }
    }
    return Get-PhysicalDirectory $target ($Depth + 1)
  }
  if ($null -eq $item.Parent) { return $item.FullName }
  $physicalParent = Get-PhysicalDirectory $item.Parent.FullName $Depth
  return Join-Path $physicalParent $item.Name
}
if ((Get-Item -LiteralPath $reportsRoot).Attributes -band [IO.FileAttributes]::ReparsePoint) { Fail 'reports directory must not be a symlink' }
$physicalReports = Get-PhysicalDirectory $reportsRoot
$physicalRoot = Join-Path (Get-PhysicalDirectory $parent) $leaf
if (-not $physicalRoot.StartsWith($physicalReports + [IO.Path]::DirectorySeparatorChar, [StringComparison]::Ordinal)) { Fail 'report root escapes reports directory' }
if (Test-Path -LiteralPath $ReportRoot) {
  if (-not (Test-Path -LiteralPath $ReportRoot -PathType Container)) { Fail 'report root must be a directory when it exists' }
  if ((Get-Item -LiteralPath $ReportRoot).LinkType) { Fail 'report root must not be a symlink' }
}

$contractText = Get-Content -LiteralPath $Contract -Raw
if ($contractText.TrimStart() -notmatch '^\{') { Fail 'contract must be a JSON object' }
$data = $contractText | ConvertFrom-Json
if ($data -isnot [Management.Automation.PSCustomObject]) { Fail 'contract must be a JSON object' }
$expectedProperties = @('attempt', 'feature', 'input_sha256', 'round', 'run_id', 'schema', 'stage', 'verdict')
$actualProperties = @($data.PSObject.Properties.Name | Sort-Object)
if (@(Compare-Object -CaseSensitive -ReferenceObject $expectedProperties -DifferenceObject $actualProperties).Count -ne 0 -or $data.schema -isnot [string] -or $data.schema -cne 'review-contract/v1' -or $data.feature -isnot [string] -or $data.feature -cne $Feature -or -not (Is-JsonInteger $data.attempt) -or $data.attempt.ToString() -ne $Attempt -or -not (Is-JsonInteger $data.round) -or $data.round.ToString() -ne $Round -or $data.stage -isnot [string] -or $data.stage -cne $Stage -or $data.input_sha256 -isnot [string] -or $data.input_sha256 -cnotmatch '^[0-9a-f]{64}$' -or $data.run_id -isnot [string] -or [string]::IsNullOrWhiteSpace($data.run_id) -or $data.verdict -isnot [string] -or $data.verdict -cne 'PASS') { Fail 'contract identity or PASS verdict is invalid' }

# PowerShell 7.5+ may serialize BigInteger values as objects on macOS. Feature
# and stage are already constrained to JSON-safe tokens, and attempt/round are
# canonical positive integer strings, so emit the protocol JSON directly.
Write-Output ('{"schema":"review-contract-validation/v1","feature":"' + $Feature + '","attempt":' + $Attempt + ',"round":' + $Round + ',"stage":"' + $Stage + '","verdict":"PASS"}')
