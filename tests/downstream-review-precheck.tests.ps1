# T-006 PowerShell entry-point coverage and semantic parity with shell fields.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$feature = 'downstream-precheck-ps-fixture'; $spec = Join-Path $root "specs/$feature"
$specReport = Join-Path $root "reports/spec-review/$feature"; $implReport = Join-Path $root "reports/impl-review/$feature"; $taskReport = Join-Path $root "reports/task-review/$feature"
$registry = Join-Path $root 'specs/workflow-state-registry.json'
$registryOriginal = [IO.File]::ReadAllText($registry)
function Assert-Fails([scriptblock]$Action, [string]$Message) { try { & $Action } catch { return }; throw "not ok: $Message" }
function Write-PassArtifacts([string]$Stage, [string]$Directory, [int64]$Attempt = 1) {
  $req = (Get-FileHash (Join-Path $spec requirements.md) -Algorithm SHA256).Hash.ToLower(); $acc = (Get-FileHash (Join-Path $spec acceptance-tests.md) -Algorithm SHA256).Hash.ToLower(); $designHash = (Get-FileHash (Join-Path $spec design.md) -Algorithm SHA256).Hash.ToLower()
  $calibrationPath = if ($Stage -eq 'spec') { 'plugins/sdd-review-loop/references/spec-review-calibration.md' } else { 'plugins/sdd-review-loop/references/reviewer-calibration.md' }
  $calibration = (Get-FileHash (Join-Path $root $calibrationPath) -Algorithm SHA256).Hash.ToLower()
  '{}' | Set-Content (Join-Path $Directory precheck-result.json) -Encoding utf8NoBOM
  '{}' | Set-Content (Join-Path $Directory integrated-summary.json) -Encoding utf8NoBOM
  $precheck = (Get-FileHash (Join-Path $Directory precheck-result.json) -Algorithm SHA256).Hash.ToLower()
  $summary = (Get-FileHash (Join-Path $Directory integrated-summary.json) -Algorithm SHA256).Hash.ToLower()
  $verdict = if ($Stage -eq 'spec') { [ordered]@{schema='spec-review-integrated-verdict/v1';stage='spec';feature=$feature;attempt=$Attempt;round=1;reviewer_a_run_id='run-a';reviewer_b_run_id='run-b';reviewer_a_host_session_id='session-a';reviewer_b_host_session_id='session-b';finding_counts=@{critical=0;major=0;minor=0};verdict='PASS';warningCount=0} } else { [ordered]@{schema='integrated-verdict/v1';stage=$Stage;feature=$feature;attempt=$Attempt;round=1;run_id="$Stage-orchestrator";verdict='PASS'} }
  $verdict | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $Directory integrated-verdict.json) -Encoding utf8NoBOM
  $manifestA=@(@{path="specs/$feature/requirements.md";sha256=$req},@{path="specs/$feature/acceptance-tests.md";sha256=$acc})
  if ($Stage -eq 'impl') { $manifestA += @{path="specs/$feature/design.md";sha256=$designHash} }
  $manifestA += @{path=$calibrationPath;sha256=$calibration},@{path="reports/$Stage-review/$feature/attempt-$Attempt/round-1/precheck-result.json";sha256=$precheck}
  $manifestB = @($manifestA | ForEach-Object { @{path=$_.path;sha256=$_.sha256} })
  $manifestB += @{path="reports/$Stage-review/$feature/attempt-$Attempt/round-1/integrated-summary.json";sha256=$summary}
  [ordered]@{schema="$Stage-review-contract/v1";stage=$Stage;feature=$feature;attempt=$Attempt;round=1;run_id="$Stage-orchestrator";verdict='PASS';requirements_sha256=$req;acceptance_sha256=$acc;design_sha256=$designHash;reviewers=@(@{role="$Stage-reviewer-a";run_id='run-a';host_session_id='session-a';allowed_input_manifest=$manifestA},@{role="$Stage-reviewer-b";run_id='run-b';host_session_id='session-b';allowed_input_manifest=$manifestB})} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $Directory "$Stage-review-contract.json") -Encoding utf8NoBOM
}
try {
  foreach ($precheck in @('impl-review-precheck.ps1','task-review-precheck.ps1')) {
    $precheckContent = [IO.File]::ReadAllText((Join-Path $root "plugins/sdd-review-loop/scripts/$precheck"))
    if ($precheckContent -notmatch 'check-workflow-state\.ps1[\s\S]*--feature\s+\$Feature') {
      throw "not ok: $precheck must invoke scoped workflow-state validation"
    }
  }
  $registryData = $registryOriginal | ConvertFrom-Json
  $registryData.entries = @($registryData.entries) + [pscustomobject]@{feature=$feature;profile='lite'}
  $registryData | ConvertTo-Json -Depth 8 | Set-Content $registry -Encoding utf8NoBOM
  New-Item -ItemType Directory -Path $spec -Force | Out-Null
  "Spec-Review-Status: Pending" | Set-Content (Join-Path $spec requirements.md) -Encoding utf8NoBOM
  "Impl-Review-Status: Pending" | Set-Content (Join-Path $spec design.md) -Encoding utf8NoBOM
  '# Acceptance' | Set-Content (Join-Path $spec acceptance-tests.md) -Encoding utf8NoBOM
  @('Task-Review-Status: Pending','',"## T-001 First",'Risk: low','Risk Rationale: fixture','Required Workflow: test-after','### Blockers','None','',"## T-002 Second",'Risk: low','Risk Rationale: fixture','Required Workflow: test-after','### Blockers','T-001') | Set-Content (Join-Path $spec tasks.md) -Encoding utf8NoBOM
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
  $wrongPathVerdict = Get-Content "$specReport/attempt-1/round-1/integrated-verdict.json" -Raw | ConvertFrom-Json
  $wrongPathContract = Get-Content "$specReport/attempt-1/round-1/spec-review-contract.json" -Raw | ConvertFrom-Json
  $wrongPathVerdict.attempt = 99; $wrongPathVerdict.round = 77; $wrongPathContract.attempt = 99; $wrongPathContract.round = 77
  $wrongPathVerdict | ConvertTo-Json -Depth 6 | Set-Content "$specReport/attempt-1/round-1/integrated-verdict.json" -Encoding utf8NoBOM
  $wrongPathContract | ConvertTo-Json -Depth 6 | Set-Content "$specReport/attempt-1/round-1/spec-review-contract.json" -Encoding utf8NoBOM
  Assert-Fails { & (Join-Path $root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 } 'impl must reject attempt round path mismatch'; if (Test-Path $implReport) { throw 'not ok: path mismatch created evidence' }
  Write-PassArtifacts spec "$specReport/attempt-1/round-1"
  $absoluteContract = Get-Content "$specReport/attempt-1/round-1/spec-review-contract.json" -Raw | ConvertFrom-Json
  foreach ($reviewer in $absoluteContract.reviewers) {
    foreach ($entry in $reviewer.allowed_input_manifest) {
      $entry.path = Join-Path $root $entry.path
    }
  }
  $absoluteContract | ConvertTo-Json -Depth 6 | Set-Content "$specReport/attempt-1/round-1/spec-review-contract.json" -Encoding utf8NoBOM
  & (Join-Path $root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 | Out-Null
  Remove-Item $implReport -Recurse -Force
  foreach ($missingCase in @(
    @{ Label = 'reviewer missing precheck'; Suffix = '/precheck-result.json'; Reviewer = 0 },
    @{ Label = 'reviewer B missing integrated summary'; Suffix = '/integrated-summary.json'; Reviewer = 1 }
  )) {
    Write-PassArtifacts spec "$specReport/attempt-1/round-1"
    $missingContract = Get-Content "$specReport/attempt-1/round-1/spec-review-contract.json" -Raw | ConvertFrom-Json
    $missingContract.reviewers[$missingCase.Reviewer].allowed_input_manifest = @($missingContract.reviewers[$missingCase.Reviewer].allowed_input_manifest | Where-Object { -not $_.path.EndsWith($missingCase.Suffix, [StringComparison]::Ordinal) })
    $missingContract | ConvertTo-Json -Depth 6 | Set-Content "$specReport/attempt-1/round-1/spec-review-contract.json" -Encoding utf8NoBOM
    Assert-Fails { & (Join-Path $root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 } "impl must reject $($missingCase.Label)"
    if (Test-Path $implReport) { throw "not ok: $($missingCase.Label) created evidence" }
  }
  Write-PassArtifacts spec "$specReport/attempt-1/round-1"
  $caseChangedContract = Get-Content "$specReport/attempt-1/round-1/spec-review-contract.json" -Raw | ConvertFrom-Json
  ($caseChangedContract.reviewers[0].allowed_input_manifest | Where-Object { $_.path.EndsWith('/requirements.md', [StringComparison]::Ordinal) }).path = "SPECS/$($feature.ToUpperInvariant())/REQUIREMENTS.MD"
  $caseChangedContract | ConvertTo-Json -Depth 6 | Set-Content "$specReport/attempt-1/round-1/spec-review-contract.json" -Encoding utf8NoBOM
  Assert-Fails { & (Join-Path $root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 } 'impl must reject case-changed canonical manifest path'; if (Test-Path $implReport) { throw 'not ok: case-changed path created evidence' }
  Write-PassArtifacts spec "$specReport/attempt-1/round-1"
  $duplicateContract = Get-Content "$specReport/attempt-1/round-1/spec-review-contract.json" -Raw | ConvertFrom-Json
  $requirementsEntry = $duplicateContract.reviewers[0].allowed_input_manifest | Where-Object { $_.path.EndsWith('/requirements.md', [StringComparison]::Ordinal) } | Select-Object -First 1
  $duplicateContract.reviewers[0].allowed_input_manifest += [pscustomobject]@{path=$requirementsEntry.path;sha256=('0' * 64)}
  $duplicateContract | ConvertTo-Json -Depth 6 | Set-Content "$specReport/attempt-1/round-1/spec-review-contract.json" -Encoding utf8NoBOM
  Assert-Fails { & (Join-Path $root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 } 'impl must reject duplicate manifest path with forged hash'; if (Test-Path $implReport) { throw 'not ok: duplicate manifest path created evidence' }
  Remove-Item $specReport -Recurse -Force
  New-Item -ItemType Directory -Path "$specReport/attempt-9/round-1","$specReport/attempt-10/round-1" -Force | Out-Null
  Write-PassArtifacts spec "$specReport/attempt-9/round-1" 9
  Write-PassArtifacts spec "$specReport/attempt-10/round-1" 10
  $latestVerdict = Get-Content "$specReport/attempt-10/round-1/integrated-verdict.json" -Raw | ConvertFrom-Json
  $latestVerdict.verdict = 'NEEDS_WORK'
  $latestVerdict | ConvertTo-Json -Depth 6 | Set-Content "$specReport/attempt-10/round-1/integrated-verdict.json" -Encoding utf8NoBOM
  Assert-Fails { & (Join-Path $root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 } 'impl must select the numerically latest predecessor generation'; if (Test-Path $implReport) { throw 'not ok: stale lexicographic predecessor created evidence' }
  Remove-Item $specReport -Recurse -Force
  New-Item -ItemType Directory -Path "$specReport/attempt-1/round-1" -Force | Out-Null
  foreach ($badCase in @(
    @{ Label = 'traversal manifest'; Path = "specs/$feature/../escape.md" },
    @{ Label = 'escaping absolute manifest'; Path = '/tmp/sdd-forge-escape.md' },
    @{ Label = 'arbitrary report artifact'; Path = "reports/spec-review/$feature/attempt-1/round-1/reviewer-a.json" },
    @{ Label = 'reviewer-role manifest violation'; Path = "reports/spec-review/$feature/attempt-1/round-1/integrated-summary.json" }
  )) {
    Write-PassArtifacts spec "$specReport/attempt-1/round-1"
    $badContract = Get-Content "$specReport/attempt-1/round-1/spec-review-contract.json" -Raw | ConvertFrom-Json
    $badContract.reviewers[0].allowed_input_manifest += [pscustomobject]@{ path = $badCase.Path; sha256 = ('0' * 64) }
    $badContract | ConvertTo-Json -Depth 6 | Set-Content "$specReport/attempt-1/round-1/spec-review-contract.json" -Encoding utf8NoBOM
    Assert-Fails { & (Join-Path $root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 } "impl must reject $($badCase.Label)"
    if (Test-Path $implReport) { throw "not ok: $($badCase.Label) created evidence" }
  }
  Write-PassArtifacts spec "$specReport/attempt-1/round-1"
  & (Join-Path $root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 | Out-Null
  if (-not (Test-Path "$implReport/attempt-1/round-1/precheck-result.json")) { throw 'not ok: valid impl did not write precheck' }
  'Impl-Review-Status: Passed' | Set-Content (Join-Path $spec design.md) -Encoding utf8NoBOM
  Write-PassArtifacts impl "$implReport/attempt-1/round-1"
  & (Join-Path $root 'plugins/sdd-review-loop/scripts/task-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 | Out-Null
  $graph = Get-Content "$taskReport/attempt-1/round-1/dependency-graph.json" -Raw | ConvertFrom-Json
  if ($graph.edges.Count -ne 1 -or $graph.edges[0].from -ne 'T-002' -or $graph.edges[0].to -ne 'T-001') { throw 'not ok: PowerShell task graph lost declared edge' }
  Remove-Item $taskReport -Recurse -Force
  $implContract = Get-Content "$implReport/attempt-1/round-1/impl-review-contract.json" -Raw | ConvertFrom-Json
  foreach ($reviewer in $implContract.reviewers) { $reviewer.allowed_input_manifest = @($reviewer.allowed_input_manifest | Where-Object { $_.path -ne 'plugins/sdd-review-loop/references/reviewer-calibration.md' }) }
  $implContract | ConvertTo-Json -Depth 6 | Set-Content "$implReport/attempt-1/round-1/impl-review-contract.json" -Encoding utf8NoBOM
  Assert-Fails { & (Join-Path $root 'plugins/sdd-review-loop/scripts/task-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 } 'task must reject missing impl calibration manifest'; if (Test-Path $taskReport) { throw 'not ok: missing calibration created task evidence' }
  Write-PassArtifacts impl "$implReport/attempt-1/round-1"
  $contradictoryImplVerdict = Get-Content "$implReport/attempt-1/round-1/integrated-verdict.json" -Raw | ConvertFrom-Json
  $contradictoryImplVerdict.run_id = 'contradictory-impl-run'
  $contradictoryImplVerdict | ConvertTo-Json -Depth 4 | Set-Content "$implReport/attempt-1/round-1/integrated-verdict.json" -Encoding utf8NoBOM
  Assert-Fails { & (Join-Path $root 'plugins/sdd-review-loop/scripts/task-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 } 'task must reject contradictory impl verdict and contract'; if (Test-Path $taskReport) { throw 'not ok: contradictory predecessor created task evidence' }
  Write-PassArtifacts impl "$implReport/attempt-1/round-1"
  (Get-Content (Join-Path $spec tasks.md) -Raw).Replace('Risk: low','Risk: medium') | Set-Content (Join-Path $spec tasks.md) -Encoding utf8NoBOM
  & (Join-Path $root 'plugins/sdd-review-loop/scripts/task-review-precheck.ps1') -Feature $feature -Attempt 1 -Round 1 | Out-Null
  if (-not (Test-Path $taskReport)) { throw 'not ok: canonical risk policy rejected medium test-after' }
  Remove-Item $taskReport -Recurse -Force
  # AC coverage: design.md must name every AC-NNN that requirements.md states,
  # except criteria the requirements table itself scopes Global. Mirrors the
  # shell coverage in tests/downstream-review-precheck.tests.sh: the epic-136
  # history (reviewer rounds burned on deterministic work) and the narrow
  # Global-scope exception (human ruling, 2026-08-24). The child-process runs
  # below mirror the shell ac_run helper: they capture stdout, stderr, and the
  # exit code together, because the assertions need the refusal text, the NOTE
  # text, and the pass/fail outcome from the same invocation.
  $psExe = (Get-Process -Id $PID).Path
  $implPrecheckPath = Join-Path $root 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1'
  function Invoke-AcRun {
    $command = "try { & '$implPrecheckPath' -Feature '$feature' -Attempt 1 -Round 1 } catch { [Console]::Error.WriteLine([string]`$_.Exception.Message); exit 1 }"
    $lines = & $psExe -NoProfile -Command $command 2>&1 | ForEach-Object { $_.ToString() }
    return ($lines -join "`n")
  }
  function Reset-AcFixture([string[]]$RequirementsExtra) {
    Remove-Item -LiteralPath $spec, $specReport, $implReport -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $spec -Force | Out-Null
    (@('Spec-Review-Status: Passed') + $RequirementsExtra) | Set-Content (Join-Path $spec requirements.md) -Encoding utf8NoBOM
    'Impl-Review-Status: Pending' | Set-Content (Join-Path $spec design.md) -Encoding utf8NoBOM
    '# Acceptance' | Set-Content (Join-Path $spec acceptance-tests.md) -Encoding utf8NoBOM
    @('Task-Review-Status: Pending', '', '## T-001 First', 'Risk: low', 'Risk Rationale: fixture', 'Required Workflow: test-after', '### Blockers', 'None') | Set-Content (Join-Path $spec tasks.md) -Encoding utf8NoBOM
    New-Item -ItemType Directory -Path "$specReport/attempt-1/round-1" -Force | Out-Null
    Write-PassArtifacts spec "$specReport/attempt-1/round-1"
  }

  # absent -> refused, and refused before any evidence is written
  Reset-AcFixture @('', '#### AC-001', '', 'fixture criterion')
  $acOut = Invoke-AcRun
  if ($LASTEXITCODE -eq 0 -or $acOut -notmatch 'never names these acceptance criteria: AC-001') { throw "not ok: impl precheck must refuse a design.md that never names AC-001 (got: $acOut)" }
  if (Test-Path $implReport) { throw 'not ok: AC-coverage refusal must fail closed before creating round evidence' }

  # named -> accepted, proving the refusal above was the AC check and not some
  # unrelated fixture failure that would make this case vacuous
  Add-Content (Join-Path $spec design.md) 'Covers AC-001 in the plan.'
  Write-PassArtifacts spec "$specReport/attempt-1/round-1"   # re-pin: design.md changed
  $acOut = Invoke-AcRun
  if ($LASTEXITCODE -ne 0 -or $acOut -match 'never names these acceptance criteria') { throw "not ok: impl precheck must accept a design.md that names AC-001 (got: $acOut)" }
  if (-not (Test-Path "$implReport/attempt-1/round-1/precheck-result.json")) { throw "not ok: impl precheck should have produced round evidence once AC-001 is named (got: $acOut)" }

  # The narrow Global-scope exception (human ruling, 2026-08-24), and the half
  # of it that matters just as much: the exception must not become a loophole.
  # Both halves are asserted from ONE run, so neither can pass by accident: a
  # one-sided test would let a blanket loosening through. The '-' trace cell in
  # the AC-004 row stands in for the shell fixture's em-dash, which the ps1
  # ASCII gate forbids in this file; the annotated '(Global)' spelling never
  # reads the trace cell, so the substitution changes nothing the gate sees.
  Reset-AcFixture @(
    '',
    '| AC-ID | Requirement | Criterion |',
    '|---|---|---|',
    '| AC-002 | REQ-001 | Behaviour this design must plan for. |',
    '| AC-003 | Global | This package''s own registration commit creates no file outside its spec directory. |',
    '| AC-004 (Global) | - | check-sdd-structure.sh exits 0 after this package''s registration commit. |'
  )
  $acOut = Invoke-AcRun
  $acError = (($acOut -split "`n") | Where-Object { $_ -match 'never names these acceptance criteria' }) -join "`n"
  if ($LASTEXITCODE -eq 0 -or -not $acError) { throw "not ok: a REQ-traced AC missing from design.md must still be refused (got: $acOut)" }
  if ($acError -notmatch 'AC-002') { throw "not ok: the refusal must name the REQ-traced AC-002 (got: $acError)" }
  if ($acError -match 'AC-003') { throw "not ok: a criterion the requirements table scopes Global must not be demanded of design.md (got: $acError)" }
  if ($acError -match 'AC-004') { throw "not ok: the (Global) spelling must be read as Global scope too (got: $acError)" }
  if ($acOut -notmatch 'scopes Global[\s\S]*AC-003 AC-004') { throw "not ok: an exercised exception must be reported, naming the excused criteria (got: $acOut)" }
  if (Test-Path $implReport) { throw 'not ok: AC-coverage refusal must fail closed before creating round evidence' }
  # The diagnostic must assert only what this script evaluates. It consults no
  # testability or traceability attribute anywhere, and never did.
  if ($acOut -match 'testable and traceable') { throw "not ok: the AC-coverage diagnostic claims a predicate this script never evaluates (got: $acOut)" }

  # Naming only the REQ-traced criterion clears the gate: proof the two Global
  # rows were genuinely excused and were not merely riding on some other failure.
  Add-Content (Join-Path $spec design.md) 'Covers AC-002 in the plan.'
  Write-PassArtifacts spec "$specReport/attempt-1/round-1"   # re-pin: design.md changed
  $acOut = Invoke-AcRun
  if ($LASTEXITCODE -ne 0 -or $acOut -match 'never names these acceptance criteria') { throw "not ok: Global-scoped criteria must not be demanded of design.md (got: $acOut)" }
  if (-not (Test-Path "$implReport/attempt-1/round-1/precheck-result.json")) { throw "not ok: impl precheck should have produced round evidence once AC-002 is named (got: $acOut)" }
  Remove-Item $implReport -Recurse -Force
  Write-Output 'ok: PowerShell downstream prechecks fail closed and preserve graph semantics'
} finally {
  [IO.File]::WriteAllText($registry, $registryOriginal)
  Remove-Item -LiteralPath $spec,$specReport,$implReport,$taskReport -Recurse -Force -ErrorAction SilentlyContinue
}
