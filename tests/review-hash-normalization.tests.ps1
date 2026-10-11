$ErrorActionPreference = 'Stop'
$scripts = Join-Path $PSScriptRoot '../plugins/sdd-review-loop/scripts'
$helper = Join-Path $scripts 'review-hash-normalization.ps1'
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('sdd-review-hash-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $scratch)

function Assert-Equal([string]$Actual, [string]$Expected, [string]$Label) {
  if (-not [string]::Equals($Actual, $Expected, [StringComparison]::Ordinal)) {
    throw "$Label`: expected $Expected, got $Actual"
  }
}

# Frozen copy of the pre-extraction recipe, so this test detects output drift.
function Get-BaselineReviewedHash([string]$Path, [string]$StatusField, [string]$ReviewedStatus) {
  $content = [IO.File]::ReadAllText($Path)
  $normalized = [Text.RegularExpressions.Regex]::Replace(
    $content,
    "(?m)^$([Text.RegularExpressions.Regex]::Escape($StatusField)):[^\r\n]*(\r?)$",
    "${StatusField}: $ReviewedStatus`$1"
  )
  return [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($normalized))
  ).ToLower()
}

try {
  foreach ($stage in @('impl', 'task')) {
    $caller = Get-Content -LiteralPath (Join-Path $scripts "$stage-review-precheck.ps1") -Raw
    if ($caller -cnotmatch '\. \(Join-Path \$PSScriptRoot ''review-hash-normalization.ps1''\)' -or
        $caller -cmatch 'function Get-ReviewedHash\(') {
      throw "$stage must load the shared hash recipe, not define its own"
    }
  }

  . $helper
  $cases = @(
    @{name='impl-status-lf'; text="Impl-Review-Status: Passed`nBody: α`n"; field='Impl-Review-Status'; status='Pending'},
    @{name='impl-status-crlf'; text="Impl-Review-Status: Passed`r`nBody: α`r`n"; field='Impl-Review-Status'; status='Pending'},
    @{name='lf'; text="Spec-Review-Status: Passed`nBody: α`n"; field='Spec-Review-Status'; status='Pending'},
    @{name='crlf'; text="Spec-Review-Status: Passed`r`nBody: α`r`n"; field='Spec-Review-Status'; status='Pending'},
    @{name='mixed-lines'; text="Task-Review-Status: Passed`r`nStatus: Done`n"; field='Task-Review-Status'; status='Pending'},
    @{name='mis-cased-key'; text="spec-review-status: Passed`r`n"; field='Spec-Review-Status'; status='Pending'},
    @{name='mis-cased-value'; text="Spec-Review-Status: passed`r`n"; field='Spec-Review-Status'; status='Pending'},
    @{name='escaped-field'; text="SpecXReview-Status: Passed`n"; field='Spec.Review-Status'; status='Pending'},
    @{name='invalid-line'; text=" Spec-Review-Status: Passed`nSpec-Review-Status Passed`n"; field='Spec-Review-Status'; status='Pending'},
    @{name='empty'; text=''; field='Spec-Review-Status'; status='Pending'},
    @{name='missing-field'; text="# Specification`nBody: α`n"; field='Spec-Review-Status'; status='Pending'}
  )
  foreach ($case in $cases) {
    $path = Join-Path $scratch ($case.name + '.md')
    [IO.File]::WriteAllText($path, $case.text, [Text.UTF8Encoding]::new($false))
    $actual = Get-ReviewedHash $path $case.field $case.status
    $baseline = Get-BaselineReviewedHash $path $case.field $case.status
    Assert-Equal $actual $baseline $case.name
    if ($actual -cnotmatch '\A[0-9a-f]{64}\z') { throw "invalid digest: $($case.name)" }
  }
  $misCasedPath = Join-Path $scratch 'mis-cased-key.md'
  $rawHash = (Get-FileHash -LiteralPath $misCasedPath -Algorithm SHA256).Hash.ToLowerInvariant()
  Assert-Equal (Get-ReviewedHash $misCasedPath 'Spec-Review-Status' 'Pending') $rawHash 'mis-cased key must remain raw'

  foreach ($missing in @('', (Join-Path $scratch 'missing.md'))) {
    $oldFailed = $false
    $newFailed = $false
    try { [void](Get-BaselineReviewedHash $missing 'Spec-Review-Status' 'Pending') } catch { $oldFailed = $true }
    try { [void](Get-ReviewedHash $missing 'Spec-Review-Status' 'Pending') } catch { $newFailed = $true }
    if (-not $oldFailed -or -not $newFailed) { throw 'invalid path failure changed' }
  }
  $lockedPath = Join-Path $scratch 'missing-field.md'
  $before = (Get-FileHash -LiteralPath $lockedPath -Algorithm SHA256).Hash
  Assert-Equal (Get-ReviewedHash $lockedPath 'Spec-Review-Status' 'Pending') $before.ToLowerInvariant() 'missing field must remain raw'
  $stream = [IO.File]::Open($lockedPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
  try {
    $failures = @()
    foreach ($function in @('Get-BaselineReviewedHash', 'Get-ReviewedHash')) {
      $failure = $null
      try { [void](& $function $lockedPath 'Spec-Review-Status' 'Pending') }
      catch { $failure = $_.Exception.GetBaseException() }
      if ($null -eq $failure) { throw "$function unexpectedly read the locked file" }
      $failures += $failure.GetType().FullName
    }
    Assert-Equal $failures[0] $failures[1] 'read-failure exception type'
  } finally { $stream.Dispose() }
  Assert-Equal (Get-FileHash -LiteralPath $lockedPath -Algorithm SHA256).Hash $before 'read failure preserves bytes'
  Assert-Equal (Get-ReviewedHash $lockedPath 'Spec-Review-Status' 'Pending') (Get-BaselineReviewedHash $lockedPath 'Spec-Review-Status' 'Pending') 'post-release recovery'
  'ok: shared impl/task reviewed-hash recipe matches baseline for CRLF, case, and invalid inputs'
} finally {
  Remove-Item -LiteralPath $scratch -Recurse -Force
}
