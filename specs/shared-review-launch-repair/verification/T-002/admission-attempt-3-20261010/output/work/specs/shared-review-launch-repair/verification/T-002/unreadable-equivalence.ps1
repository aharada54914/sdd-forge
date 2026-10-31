param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$FixtureDirectory)
$ErrorActionPreference = 'Stop'
. (Join-Path $Root 'tests/review-hash-normalization.tests.ps1')
[void][IO.Directory]::CreateDirectory($FixtureDirectory)
$path = Join-Path $FixtureDirectory 'existing-regular-file.md'
[IO.File]::WriteAllText($path, "Spec-Review-Status: Passed`n", [Text.UTF8Encoding]::new($false))
if (-not [IO.File]::Exists($path)) { throw 'fixture is not an existing file' }
$before = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
$stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try {
  $errors = @()
  foreach ($function in @('Get-BaselineReviewedHash', 'Get-ReviewedHash')) {
    $failure = $null
    try { [void](& $function $path 'Spec-Review-Status' 'Pending') }
    catch { $failure = $_.Exception.GetBaseException() }
    if ($null -eq $failure) { throw "$function unexpectedly read the exclusively locked regular file" }
    $errors += $failure.GetType().FullName
    Write-Output "$function rejected existing unreadable regular file: $($failure.GetType().FullName)"
  }
  if ($errors[0] -cne $errors[1]) { throw 'read-failure exception types differ' }
} finally { $stream.Dispose() }
if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $before) { throw 'fixture bytes changed' }
Assert-Equal (Get-ReviewedHash $path 'Spec-Review-Status' 'Pending') (Get-BaselineReviewedHash $path 'Spec-Review-Status' 'Pending') 'post-release recovery'
Write-Output 'ok: existing regular file denied identically under exclusive FileStream lock; reads recover after release; bytes unchanged'
