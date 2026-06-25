# T-006 PowerShell entry-point coverage and semantic parity with shell fields.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$feature = 'downstream-precheck-ps-fixture'; $spec = Join-Path $root "specs/$feature"
$specReport = Join-Path $root "reports/spec-review/$feature"; $implReport = Join-Path $root "reports/impl-review/$feature"; $taskReport = Join-Path $root "reports/task-review/$feature"
function Assert-Fails([scriptblock]$Action, [string]$Message) { try { & $Action } catch { return }; throw "not ok: $Message" }
function Write-PassArtifacts([string]$Stage, [string]$Directory) {
  $req = (Get-FileHash (Join-Path $spec requirements.md) -Algorithm SHA256).Hash.ToLower(); $acc = (Get-FileHash (Join-Path $spec acceptance-tests.md) -Algorithm SHA256).Hash.ToLower(); $designHash = (Get-FileHash (Join-Path $spec design.md) -Algorithm SHA256).Hash.ToLower()
  $verdict = if ($Stage -eq 'spec') { [ordered]@{schema='spec-review-integrated-verdict/v1';stage='spec';feature=$feature;attempt=1;round=1;reviewer_a_run_id='run-a';reviewer_b_run_id='run-b';reviewer_a_host_session_id='session-a';reviewer_b_host_session_id='session-b';finding_counts=@{critical=0;major=0;minor=0};verdict='PASS';warningCount=0} } else { [ordered]@{schema='integrated-verdict/v1';stage=$Stage;feature=$feature;attempt=1;round=1;run_id="$Stage-orchestrator";verdict='PASS'} }
  $verdict | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $Directory integrated-verdict.json) -Encoding utf8NoBOM
  $manifest=@(@{path="specs/$feature/requirements.md";sha256=$req},@{path="specs/$feature/acceptance-tests.md";sha256=$acc},@{path="specs/$feature/design.md";sha256=$designHash})
  [ordered]@{schema="$Stage-review-contract/v1";stage=$Stage;feature=$feature;attempt=1;round=1;run_id="$Stage-orchestrator";verdict='PASS';requirements_sha256=$req;acceptance_sha256=$acc;design_sha256=$designHash;reviewers=@(@{role="$Stage-reviewer-a";run_id='run-a';host_session_id='session-a';allowed_input_manifest=$manifest},@{role="$Stage-reviewer-b";run_id='run-b';host_session_id='session-b';allowed_input_manifest=$manifest})} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $Directory "$Stage-review-contract.json") -Encoding utf8NoBOM
}
try {
  New-Item -ItemType Directory -Path $spec -Force | Out-Null
  "Spec-Review-Status: Pending" | Set-Content (Join-Path $spec requirements.md) -Encoding utf8NoBOM
  "Impl-Review-Status: Pending" | Set-Content (Join-Path $spec design.md) -Encoding utf8NoBOM
  '# Acceptance' | Set-Content (Join-Path $spec acceptance-tests.md) -Encoding utf8NoBOM
  @("## T-001 First",'Risk: low','Risk Rationale: fixture','Required Workflow: test-after','### Blockers','None','',"## T-002 Second",'Risk: low','Risk Rationale: fixture','Required Workflow: test-after','### Blockers','T-001') | Set-Content (Join-Path $spec tasks.md) -Encoding utf8NoBOM
  Assert-Fails { & (Join-Path $root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 } 'impl must reject missing spec predecessor'; if (Test-Path $implReport) { throw 'not ok: failed impl created evidence' }
  Assert-Fails { & (Join-Path $root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature '../unsafe' -Attempt 1 -Round 1 } 'impl must reject invalid slug'
  Assert-Fails { & (Join-Path $root 'plugins/sdd-review-loop/scripts/task-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 0 } 'task must reject nonpositive round'
  'Spec-Review-Status: Passed' | Set-Content (Join-Path $spec requirements.md) -Encoding utf8NoBOM
  New-Item -ItemType Directory -Path "$specReport/attempt-1/round-1" -Force | Out-Null
  Write-PassArtifacts spec "$specReport/attempt-1/round-1"
  Remove-Item "$specReport/attempt-1/round-1/spec-review-contract.json"
  Assert-Fails { & (Join-Path $root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 } 'impl must reject incomplete spec contract'; if (Test-Path $implReport) { throw 'not ok: invalid predecessor created evidence' }
  Write-PassArtifacts spec "$specReport/attempt-1/round-1"
  Add-Content (Join-Path $spec requirements.md) '# stale predecessor input'
  Assert-Fails { & (Join-Path $root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 } 'impl must reject stale predecessor hash'; if (Test-Path $implReport) { throw 'not ok: stale predecessor created evidence' }
  'Spec-Review-Status: Passed' | Set-Content (Join-Path $spec requirements.md) -Encoding utf8NoBOM
  Write-PassArtifacts spec "$specReport/attempt-1/round-1"
  $contradictorySpecVerdict = Get-Content "$specReport/attempt-1/round-1/integrated-verdict.json" -Raw | ConvertFrom-Json
  $contradictorySpecVerdict.attempt = 2; $contradictorySpecVerdict.round = 3; $contradictorySpecVerdict.reviewer_a_run_id = 'contradictory-a-run'; $contradictorySpecVerdict.reviewer_b_run_id = 'contradictory-b-run'; $contradictorySpecVerdict.reviewer_a_host_session_id = 'contradictory-a-session'; $contradictorySpecVerdict.reviewer_b_host_session_id = 'contradictory-b-session'
  $contradictorySpecVerdict | ConvertTo-Json -Depth 4 | Set-Content "$specReport/attempt-1/round-1/integrated-verdict.json" -Encoding utf8NoBOM
  Assert-Fails { & (Join-Path $root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 } 'impl must reject contradictory spec verdict and contract'; if (Test-Path $implReport) { throw 'not ok: contradictory predecessor created evidence' }
  Write-PassArtifacts spec "$specReport/attempt-1/round-1"
  & (Join-Path $root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 | Out-Null
  if (-not (Test-Path "$implReport/attempt-1/round-1/precheck-result.json")) { throw 'not ok: valid impl did not write precheck' }
  'Impl-Review-Status: Passed' | Set-Content (Join-Path $spec design.md) -Encoding utf8NoBOM
  Write-PassArtifacts impl "$implReport/attempt-1/round-1"
  & (Join-Path $root 'plugins/sdd-review-loop/scripts/task-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 | Out-Null
  $graph = Get-Content "$taskReport/attempt-1/round-1/dependency-graph.json" -Raw | ConvertFrom-Json
  if ($graph.edges.Count -ne 1 -or $graph.edges[0].from -ne 'T-002' -or $graph.edges[0].to -ne 'T-001') { throw 'not ok: PowerShell task graph lost declared edge' }
  Remove-Item $taskReport -Recurse -Force
  $contradictoryImplVerdict = Get-Content "$implReport/attempt-1/round-1/integrated-verdict.json" -Raw | ConvertFrom-Json
  $contradictoryImplVerdict.run_id = 'contradictory-impl-run'
  $contradictoryImplVerdict | ConvertTo-Json -Depth 4 | Set-Content "$implReport/attempt-1/round-1/integrated-verdict.json" -Encoding utf8NoBOM
  Assert-Fails { & (Join-Path $root 'plugins/sdd-review-loop/scripts/task-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 } 'task must reject contradictory impl verdict and contract'; if (Test-Path $taskReport) { throw 'not ok: contradictory predecessor created task evidence' }
  Write-PassArtifacts impl "$implReport/attempt-1/round-1"
  (Get-Content (Join-Path $spec tasks.md) -Raw).Replace('Risk: low','Risk: medium') | Set-Content (Join-Path $spec tasks.md) -Encoding utf8NoBOM
  Assert-Fails { & (Join-Path $root 'plugins/sdd-review-loop/scripts/task-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 } 'task must reject medium test-after before evidence'; if (Test-Path $taskReport) { throw 'not ok: workflow mismatch created evidence' }
  Write-Output 'ok: PowerShell downstream prechecks fail closed and preserve graph semantics'
} finally { Remove-Item -LiteralPath $spec,$specReport,$implReport,$taskReport -Recurse -Force -ErrorAction SilentlyContinue }
