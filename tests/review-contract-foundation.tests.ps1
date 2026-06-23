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

  $output = & $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $fixture | ConvertFrom-Json
  if ($output.schema -ne 'review-contract-validation/v1' -or $output.feature -ne 'utf8-feature' -or $output.attempt -ne 1 -or $output.round -ne 2 -or $output.stage -ne 'spec' -or $output.verdict -ne 'PASS') {
    throw "unexpected canonical output: $($output | ConvertTo-Json -Compress)"
  }

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
  $inconsistent.input_sha256 = 'not-a-sha256'
  $inconsistent | ConvertTo-Json | Set-Content -LiteralPath $tempContract -Encoding utf8
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $tempContract } 'invalid contract hash'
  $inconsistent = Get-Content -LiteralPath $fixture -Raw | ConvertFrom-Json
  $inconsistent.run_id = @('not', 'a-string')
  $inconsistent | ConvertTo-Json | Set-Content -LiteralPath $tempContract -Encoding utf8
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $tempContract } 'non-string run id'
  $inconsistent = Get-Content -LiteralPath $fixture -Raw | ConvertFrom-Json
  $inconsistent | Add-Member -NotePropertyName unexpected -NotePropertyValue $true
  $inconsistent | ConvertTo-Json | Set-Content -LiteralPath $tempContract -Encoding utf8
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportRoot -Contract $tempContract } 'undeclared contract property'
  New-Item -ItemType File -Path $reportFile | Out-Null
  Assert-Fails { & $validator -Feature 'utf8-feature' -Attempt 1 -Round 2 -Stage spec -ReportRoot $reportFile -Contract $fixture } 'report root is a regular file'

  Write-Output 'ok: PowerShell review contract foundation validates canonical input and rejects unsafe inputs'
} finally {
  Remove-Item -LiteralPath $tempContract -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $reportFile -Force -ErrorAction SilentlyContinue
  if ($createdParent -and (Test-Path -LiteralPath $reportParent)) { Remove-Item -LiteralPath $reportParent -Force }
}
