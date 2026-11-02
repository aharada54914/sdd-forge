# T-002 portable PowerShell coverage for the canonical review-contract foundation.
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$validator = Join-Path $repoRoot 'plugins/sdd-review-loop/scripts/review-contract-validate.ps1'
$fixture = Join-Path $repoRoot 'tests/fixtures/review-contract/utf8-contract.json'
$reportParent = Join-Path $repoRoot 'reports/spec-review'
$reportRoot = Join-Path $reportParent 'utf8-feature'
$reportFile = Join-Path $reportParent 'existing-file'
$createdParent = -not (Test-Path -LiteralPath $reportParent)
$tempContract = [IO.Path]::GetTempFileName()

function Assert-Fails([scriptblock]$Action, [string]$Description) {
  try {
    & $Action
  } catch {
    return
  }
  throw "expected failure: $Description"
}

try {
  if ($createdParent) { New-Item -ItemType Directory -Path $reportParent | Out-Null }

  $rawOutput = @(& $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $fixture) -join [Environment]::NewLine
  $output = $rawOutput | ConvertFrom-Json
  # ConvertFrom-Json may materialize JSON integer tokens as BigInteger-like
  # objects on newer PowerShell/macOS builds. Assert the canonical numeric JSON
  # tokens from the raw protocol output, then parse string fields normally.
  if ($output.schema -cne 'review-contract-validation/v1' -or $output.feature -cne 'utf8-feature' -or $rawOutput -notmatch '"attempt":1(,|})' -or $rawOutput -notmatch '"round":2(,|})' -or $output.stage -cne 'spec' -or $output.verdict -cne 'PASS') {
    throw "unexpected canonical output: $($output | ConvertTo-Json -Compress)"
  }

  if ([IO.Path]::DirectorySeparatorChar -ne '\') {
    [IO.File]::WriteAllText($tempContract, [IO.File]::ReadAllText($fixture))
    foreach ($linkType in @('SymbolicLink', 'HardLink')) {
      $linkPath = $tempContract + '.' + $linkType
      try {
        New-Item -ItemType $linkType -Path $linkPath -Target $tempContract | Out-Null
        $linkedOutput = & $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $linkPath
        if ($linkedOutput -cne $rawOutput) { throw "$linkType contract changed canonical output" }
      } finally { Remove-Item -LiteralPath $linkPath -Force -ErrorAction SilentlyContinue }
    }
  }

  [IO.File]::WriteAllText($tempContract, ('[' + [IO.File]::ReadAllText($fixture) + ']'))
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $tempContract } 'singleton root array must not unwrap to a contract'

  foreach ($case in @(
    @{ Field = 'verdict'; Value = 'pass' },
    @{ Field = 'schema'; Value = 'REVIEW-CONTRACT/v1' },
    @{ Field = 'feature'; Value = 'UTF8-FEATURE' },
    @{ Field = 'stage'; Value = 'SPEC' },
    @{ Field = 'verdict'; Value = @('PASS') },
    @{ Field = 'schema'; Value = @('review-contract/v1') },
    @{ Field = 'feature'; Value = @('utf8-feature') },
    @{ Field = 'stage'; Value = @('spec') }
  )) {
    $inconsistent = Get-Content -LiteralPath $fixture -Raw | ConvertFrom-Json
    $inconsistent.($case.Field) = $case.Value
    $inconsistent | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $tempContract -Encoding utf8
    Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $tempContract } "exact string $($case.Field)"
  }
  $caseChangedProperty = (Get-Content -LiteralPath $fixture -Raw).Replace('"verdict":', '"Verdict":')
  Set-Content -LiteralPath $tempContract -Value $caseChangedProperty -Encoding utf8
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $tempContract } 'exact property names'
  Assert-Fails { & $validator -Feature 'UTF8-FEATURE' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $fixture } 'uppercase feature argument'
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage SPEC -ReportRoot $reportRoot -Contract $fixture } 'uppercase stage argument'

  Assert-Fails { & $validator -Feature '../escape' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $fixture } 'invalid feature slug'
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt 0 -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $fixture } 'nonpositive attempt'
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt '+1' -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $fixture } 'noncanonical attempt'
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt '1.5' -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $fixture } 'fractional attempt'
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt 1 -Round 0 -Stage spec -ReportRoot $reportRoot -Contract $fixture } 'nonpositive round'
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage spec -ReportRoot (Join-Path (Split-Path -Parent $repoRoot) 'unsafe') -Contract $fixture } 'unsafe report root'
  $inconsistent = Get-Content -LiteralPath $fixture -Raw | ConvertFrom-Json
  $inconsistent.feature = 'different-feature'
  $inconsistent | ConvertTo-Json | Set-Content -LiteralPath $tempContract -Encoding utf8
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $tempContract } 'inconsistent contract identity'
  $inconsistent = Get-Content -LiteralPath $fixture -Raw | ConvertFrom-Json
  $inconsistent.attempt = '1'
  $inconsistent | ConvertTo-Json | Set-Content -LiteralPath $tempContract -Encoding utf8
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $tempContract } 'string attempt'
  $inconsistent = Get-Content -LiteralPath $fixture -Raw | ConvertFrom-Json
  $inconsistent.round = '2'
  $inconsistent | ConvertTo-Json | Set-Content -LiteralPath $tempContract -Encoding utf8
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $tempContract } 'string round'
  $inconsistent = Get-Content -LiteralPath $fixture -Raw | ConvertFrom-Json
  $inconsistent.input_sha256 = 'not-a-sha256'
  $inconsistent | ConvertTo-Json | Set-Content -LiteralPath $tempContract -Encoding utf8
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $tempContract } 'invalid contract hash'
  $inconsistent = Get-Content -LiteralPath $fixture -Raw | ConvertFrom-Json
  $inconsistent.run_id = @('not', 'a-string')
  $inconsistent | ConvertTo-Json | Set-Content -LiteralPath $tempContract -Encoding utf8
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $tempContract } 'non-string run id'
  $inconsistent = Get-Content -LiteralPath $fixture -Raw | ConvertFrom-Json
  $inconsistent.run_id = '   '
  $inconsistent | ConvertTo-Json | Set-Content -LiteralPath $tempContract -Encoding utf8
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $tempContract } 'whitespace-only run id'
  $inconsistent = Get-Content -LiteralPath $fixture -Raw | ConvertFrom-Json
  $inconsistent | Add-Member -NotePropertyName unexpected -NotePropertyValue $true
  $inconsistent | ConvertTo-Json | Set-Content -LiteralPath $tempContract -Encoding utf8
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $tempContract } 'undeclared contract property'
  New-Item -ItemType File -Path $reportFile | Out-Null
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportFile -Contract $fixture } 'report root is a regular file'

  if ([IO.Path]::DirectorySeparatorChar -ne '\' -and (Get-Command mkfifo -ErrorAction SilentlyContinue)) {
    . (Join-Path $repoRoot 'plugins/sdd-quality-loop/scripts/lib/native-arguments.ps1')
    $fifoPath = $tempContract + '.fifo'
    try {
      & mkfifo $fifoPath
      if ($LASTEXITCODE -ne 0) { throw 'could not create FIFO fixture' }
      # A timeout throws and fails the suite; only a typed pre-read rejection passes.
      $rejected = Invoke-SddNativeRaw -FileName (Get-Process -Id $PID).Path -Arguments @('-NoProfile', '-File', $validator, '-Feature', 'utf8-feature', '-Attempt', '1', '-Round', '2', '-Stage', 'spec', '-ReportRoot', $reportRoot, '-Contract', $fifoPath) -TimeoutMilliseconds 5000
      if ($rejected.ExitCode -ne 1 -or $rejected.Stdout.Length -ne 0 -or [Text.Encoding]::UTF8.GetString($rejected.Stderr) -notmatch 'contract is not a regular file') { throw 'FIFO did not produce a pre-read regular-file rejection' }
    } finally { Remove-Item -LiteralPath $fifoPath -Force -ErrorAction SilentlyContinue }
  }

  Write-Output 'ok: PowerShell review contract foundation validates canonical input and rejects unsafe inputs'
} finally {
  Remove-Item -LiteralPath $tempContract -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $reportFile -Force -ErrorAction SilentlyContinue
  if ($createdParent -and (Test-Path -LiteralPath $reportParent)) { Remove-Item -LiteralPath $reportParent -Force }
}
