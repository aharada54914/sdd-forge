# TDD suite for the projection generator (T-006, REQ-005, AC-025/AC-026)
# -- PowerShell twin.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$generatorScript = Join-Path $root 'plugins/sdd-quality-loop/scripts/generate-gate-capabilities.ps1'
$fixturesDir = Join-Path $root 'tests/fixtures/capability-registry'
$stagedWorkflow = Join-Path $root 'specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml'
$stagedManifest = Join-Path $root 'specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256'

$script:PassCount = 0
$script:FailCount = 0
$script:DesignedRedCount = 0
function Ok([string]$Message) { $script:PassCount++; Write-Host "ok: $Message" }
function Fail([string]$Message) { $script:FailCount++; [Console]::Error.WriteLine("not ok: $Message") }
# Established repo pattern for "stays red until a human applies a staged
# candidate" assertions (tests/deterministic-lane-selfcheck.tests.sh
# TEST-020's designed_red(), tests/design-system-contract.tests.sh
# TEST-039). Distinct from FailCount so the summary can tell a genuine
# defect apart from an expected pre-human-copy state; still makes the
# suite's own exit code non-zero (see footer).
function DesignedRed([string]$Message) { $script:DesignedRedCount++; [Console]::Error.WriteLine("DESIGNED-RED (pre-human-copy): $Message") }

# Strict-mode-safe property access: a malformed/empty projection (e.g. a
# stub's `{}` `_generated` object) must not throw a terminating
# property-not-found error under Set-StrictMode -- it must simply read as
# absent, so the RED-path assertions can report "not ok" and the suite can
# keep evaluating every remaining check, exactly like the bash twin's plain
# associative lookups.
function Get-Prop($InputObject, [string]$Name) {
  if ($null -ne $InputObject -and @($InputObject.PSObject.Properties.Match($Name)).Count -gt 0) {
    return $InputObject.$Name
  }
  return $null
}

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("t006-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $workDir 'contracts') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $workDir 'plugins/sdd-quality-loop/scripts/generated') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $fixturesDir 'gate-capabilities-clean-registry.json') -Destination (Join-Path $workDir 'contracts/capability-registry.json')
$outputPath = Join-Path $workDir 'plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json'

function Invoke-Generate {
  param([string[]]$ExtraArgs = @())
  $powerShellExe = (Get-Process -Id $PID).Path
  $allArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $generatorScript, '--repo-root', $workDir) + $ExtraArgs
  $out = & $powerShellExe @allArgs 2>&1
  $rc = $LASTEXITCODE
  return [PSCustomObject]@{ Out = ($out -join "`n"); Rc = $rc }
}

try {
  # =====================================================================
  # TEST-025: generated-header conformance + content correctness
  # =====================================================================
  $inv = Invoke-Generate
  if ($inv.Rc -eq 0) {
    Ok 'TEST-025(1): generator exits 0 against a clean fixture Registry'
  } else {
    Fail "TEST-025(1): generator exited $($inv.Rc): $($inv.Out)"
  }

  $expectedHash = (Get-FileHash -LiteralPath (Join-Path $fixturesDir 'gate-capabilities-clean-expected.json') -Algorithm SHA256).Hash
  $actualHash = if (Test-Path -LiteralPath $outputPath) { (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash } else { $null }
  if ($null -ne $actualHash -and $actualHash -eq $expectedHash) {
    Ok 'TEST-025(2): fresh output is byte-identical to the golden expected projection'
  } else {
    Fail 'TEST-025(2): fresh output diverges from the golden expected projection'
  }

  $data = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
  $gen = Get-Prop $data '_generated'
  $sha256Value = Get-Prop $gen 'sha256'
  $headerOk = (
    (Get-Prop $gen 'source') -eq 'contracts/capability-registry.json' -and
    (Get-Prop $gen 'schema_version') -eq 1 -and
    ($sha256Value -is [string]) -and ($null -ne $sha256Value) -and ($sha256Value.Length -eq 64) -and
    (Get-Prop $gen 'notice') -eq 'This file is generated. Do not edit.'
  )
  if ($headerOk) {
    Ok 'TEST-025(3): _generated block carries source/schema_version/sha256/notice correctly'
  } else {
    Fail 'TEST-025(3): _generated block malformed'
  }

  $rawLines = @(Get-Content -LiteralPath $outputPath)
  $commentLines = @($rawLines | Where-Object { $_ -match '^#' })
  if ($commentLines.Count -eq 0) {
    Ok "TEST-025(4): no comment-line ('# Generated...') convention anywhere in the projection"
  } else {
    Fail "TEST-025(4): unexpected '#'-prefixed line found in the projection"
  }

  $gatesArray = @(Get-Prop $data 'gates')
  $gateIds = @($gatesArray | ForEach-Object { Get-Prop $_ 'id' })
  $stagesOk = @($gatesArray | Where-Object { (Get-Prop $_ 'stage') -ne 'implementation' }).Count -eq 0
  $capMap = Get-Prop $data 'capability_gate_map'
  $mapOk = (
    ((@(Get-Prop $capMap 'first-capability')) -join ',') -eq 'check-alpha-impl,check-zeta-impl' -and
    ((@(Get-Prop $capMap 'second-capability')) -join ',') -eq 'check-alpha-impl' -and
    (@(Get-Prop $capMap 'no-gates-capability')).Count -eq 0 -and
    $stagesOk -and
    (($gateIds -join ',') -eq 'check-alpha-impl,check-zeta-impl')
  )
  if ($mapOk) {
    Ok 'TEST-025(5): capability_gate_map omits the promotion-stage gate (dangling-reference filtering), sorted, empty-array capability preserved'
  } else {
    Fail 'TEST-025(5): capability_gate_map / gates filtering incorrect'
  }

  # =====================================================================
  # TEST-026: drift detection (negative canary) + no-write proof
  # =====================================================================
  $inv = Invoke-Generate -ExtraArgs @('--check')
  if ($inv.Rc -eq 0) {
    Ok 'TEST-026(1): --check exits 0 against a freshly-regenerated, unmutated file'
  } else {
    Fail "TEST-026(1): --check exited $($inv.Rc) against a clean file: $($inv.Out)"
  }

  Copy-Item -LiteralPath (Join-Path $fixturesDir 'gate-capabilities-mutated.json') -Destination $outputPath -Force
  $inv = Invoke-Generate -ExtraArgs @('--check')
  if ($inv.Rc -ne 0 -and $inv.Out -match 'stale') {
    Ok "TEST-026(2): --check exits non-zero with a 'stale' diagnostic against a hand-mutated file"
  } else {
    Fail "TEST-026(2): expected non-zero exit + 'stale' diagnostic -- actual (rc=$($inv.Rc)): $($inv.Out)"
  }

  Invoke-Generate | Out-Null
  $beforeMtime = (Get-Item -LiteralPath $outputPath).LastWriteTimeUtc
  Start-Sleep -Seconds 1
  $inv = Invoke-Generate -ExtraArgs @('--check')
  $afterMtime = (Get-Item -LiteralPath $outputPath).LastWriteTimeUtc
  if ($inv.Rc -eq 0 -and $beforeMtime -eq $afterMtime) {
    Ok 'TEST-026(3): --check performs no filesystem write (mtime unchanged)'
  } else {
    Fail "TEST-026(3): mtime changed across a --check invocation (rc=$($inv.Rc), before=$beforeMtime, after=$afterMtime)"
  }

  # =====================================================================
  # Missing/invalid canonical Registry: fail closed
  # =====================================================================
  $emptyDir = Join-Path ([System.IO.Path]::GetTempPath()) ("t006-empty-" + [System.Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
  $powerShellExe = (Get-Process -Id $PID).Path
  $missingOut = & $powerShellExe -NoProfile -ExecutionPolicy Bypass -File $generatorScript --repo-root $emptyDir 2>&1
  $missingRc = $LASTEXITCODE
  Remove-Item -LiteralPath $emptyDir -Recurse -Force
  if ($missingRc -ne 0 -and ($missingOut -join "`n") -match 'not found') {
    Ok 'TEST-026(4): missing canonical Registry fails closed with a diagnostic'
  } else {
    Fail "TEST-026(4): expected fail-closed on missing Registry -- actual (rc=$missingRc): $missingOut"
  }

  # =====================================================================
  # Suite/CI registration
  # =====================================================================
  $runAllContent = Get-Content -LiteralPath (Join-Path $root 'tests/run-all.ps1') -Raw
  if ($runAllContent -match [regex]::Escape('tests/generate-gate-capabilities.tests.ps1')) {
    Ok 'run-all.ps1 registers this suite'
  } else {
    Fail 'run-all.ps1 does not register this suite'
  }

  if (Test-Path -LiteralPath $stagedWorkflow) {
    # Quality-gate cycle 3 remediation (2026-08-09): reviewed per the
    # cycle-2 Critical ("納品スイート自身が旧 staged workflow を ok: 2 件
    # で肯定している" -- an assertion affirming a stale artifact
    # contradicts the DESIGNED-RED checks below). This check previously
    # only grepped for this suite's own two test-invocation step names,
    # which the STALE human-copy/ file already contains -- it now also
    # requires the --check drift-lock step this task's own Scope requires
    # ("adding the --check steps"), so a stale file correctly reports
    # DESIGNED-RED instead of a false "ok".
    $workflowContent = Get-Content -LiteralPath $stagedWorkflow -Raw
    if ($workflowContent -match [regex]::Escape('tests/generate-gate-capabilities.tests.sh') -and
        $workflowContent -match [regex]::Escape('tests/generate-gate-capabilities.tests.ps1') -and
        $workflowContent -match [regex]::Escape('generate-gate-capabilities.py --check')) {
      Ok "human-copy: staged workflow candidate registers this suite's CI steps, including the --check drift-lock step (Scope)"
    } else {
      DesignedRed "human-copy: staged workflow candidate is STALE -- missing this suite's --check drift-lock step and/or predates the current CI job structure -- HUMAN ACTION REQUIRED: replace specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml with specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/.github/workflows/test.yml.candidate (see that directory's README.md), then re-run this suite"
    }

    # RT-20260809-002 item 1 (2026-08-10) -- PowerShell twin of the bash
    # suite's identically-named assertion. See that block's comment for the
    # full rationale: tasks.md Scope assigns TWO --check steps to this task
    # in one sentence, design.md's Deployment / CI Plan and infra-spec.md's
    # CI/CD Sequence both require the vendored-copy drift check as a release
    # gate, and only the projection step existed. Asserted SEPARATELY from
    # the compound check above so deleting either step fails that step's own
    # assertion and only that one.
    if ($workflowContent -match [regex]::Escape('vendor-capability-registry.py --check')) {
      Ok 'human-copy: staged workflow candidate carries the vendoring drift-lock --check step (RT-20260809-002 item 1)'
    } else {
      Fail 'human-copy: staged workflow candidate is missing the vendoring drift-lock --check step (vendor-capability-registry.py --check)'
    }

    if (Test-Path -LiteralPath $stagedManifest) {
      $stagedHash = (Get-FileHash -LiteralPath $stagedWorkflow -Algorithm SHA256).Hash.ToLowerInvariant()
      $manifestLines = @(Get-Content -LiteralPath $stagedManifest)
      $manifestLine = @($manifestLines -match 'workflows/test\.yml')
      if ($manifestLine.Count -gt 0) {
        $manifestHash = ($manifestLine[0] -split '\s+')[0].ToLowerInvariant()
        # NOTE: proves only that the staged file matches its own recorded
        # MANIFEST hash (internal self-consistency), NOT a freshness or
        # completeness proof -- a stale-but-internally-consistent bundle
        # still passes this narrower check by design. See the
        # DESIGNED-RED checks in this block and below for that proof.
        if ($stagedHash -eq $manifestHash) { Ok 'human-copy: staged workflow candidate sha256 matches MANIFEST.sha256 (self-consistency only, not a freshness proof)' }
        else { Fail 'human-copy: staged workflow candidate sha256 does not match MANIFEST.sha256' }
      } else {
        Fail 'human-copy: MANIFEST.sha256 has no entry for the staged workflow candidate'
      }
    } else {
      Fail 'human-copy: MANIFEST.sha256 missing'
    }
  } else {
    Fail 'human-copy: staged .github/workflows/test.yml candidate missing'
  }

  # =====================================================================
  # Quality-gate remediation regression lock (2026-08-09) -- PowerShell twin
  # of the bash suite's identically-named block. See that block's own
  # comment for the full incident record: the human-copy/ bundle was built
  # from a pre-epic-189-a1-merge baseline and would silently drop the
  # epic_a1_targets top-level key plus tests/guard-parity.tests.sh if
  # applied to the current live tree. The regenerated candidate lives at
  # drafts/human-copy-candidate/ (agents may not write under human-copy/),
  # each file named `<target>.candidate` so its path does not match a
  # protected-gate suffix (see that directory's README.md).
  # =====================================================================
  $candidateDir = Join-Path $root 'specs/epic-190-a2-capability-registry/drafts/human-copy-candidate'
  $candidateGuardJson = Join-Path $candidateDir 'plugins/sdd-quality-loop/references/guard-invariants.json.candidate'
  $liveGuardJson = Join-Path $root 'plugins/sdd-quality-loop/references/guard-invariants.json'

  function Get-RemovedEntries([string]$Label, $LiveValues, $CandidateValues) {
    # Set-difference (live - candidate), native PowerShell (no python
    # shell-out -- this suite otherwise parses JSON via ConvertFrom-Json
    # throughout, per this file's own established convention).
    $liveSet = [System.Collections.Generic.HashSet[string]]::new([string[]]@($LiveValues))
    $candidateSet = [System.Collections.Generic.HashSet[string]]::new([string[]]@($CandidateValues))
    $removed = @($liveSet | Where-Object { -not $candidateSet.Contains($_) } | Sort-Object)
    return @($removed | ForEach-Object { "[$Label] $_" })
  }

  function Test-NoRegression([string]$CandidatePath, [string]$LivePath) {
    if (-not (Test-Path -LiteralPath $CandidatePath)) {
      return [PSCustomObject]@{ Rc = 1; Out = "candidate file not found: $CandidatePath" }
    }
    $live = Get-Content -LiteralPath $LivePath -Raw | ConvertFrom-Json
    $candidate = Get-Content -LiteralPath $CandidatePath -Raw | ConvertFrom-Json

    $liveKeys = @($live.PSObject.Properties.Name)
    $candidateKeys = @($candidate.PSObject.Properties.Name)

    $removed = @()
    $removed += Get-RemovedEntries 'top-level keys' $liveKeys $candidateKeys
    $removed += Get-RemovedEntries 'protected_gate_suffixes' @(Get-Prop $live 'protected_gate_suffixes') @(Get-Prop $candidate 'protected_gate_suffixes')
    $removed += Get-RemovedEntries 'phase2_human_copy_targets' @(Get-Prop $live 'phase2_human_copy_targets') @(Get-Prop $candidate 'phase2_human_copy_targets')
    if ($liveKeys -contains 'epic_a1_targets') {
      $removed += Get-RemovedEntries 'epic_a1_targets' @(Get-Prop $live 'epic_a1_targets') @(Get-Prop $candidate 'epic_a1_targets')
    }

    if ($removed.Count -gt 0) {
      $message = "candidate drops $($removed.Count) live-protected entr(y/ies): " + ($removed -join '; ')
      return [PSCustomObject]@{ Rc = 1; Out = $message }
    }
    return [PSCustomObject]@{ Rc = 0; Out = 'candidate is a pure superset of live (0 removals)' }
  }

  $regressionCheck = Test-NoRegression -CandidatePath $candidateGuardJson -LivePath $liveGuardJson
  if ($regressionCheck.Rc -eq 0) {
    Ok 'QG-fix: regenerated guard-invariants candidate drops no live-protected path/key'
  } else {
    Fail "QG-fix: regenerated guard-invariants candidate drops no live-protected path/key -- $($regressionCheck.Out)"
  }

  # =====================================================================
  # Quality-gate cycle 3 remediation (2026-08-09) -- Major finding 5: the
  # regression check above only ever inspects the JSON side of the staged
  # bundle. tasks.md's own Protected Files section warns this is
  # insufficient: "Editing guard-invariants.json alone... is therefore
  # insufficient -- generate-guard-invariants.py itself must be edited in
  # the same staged change so PHASE2_TARGETS gains the identical seven new
  # entries" -- so a JSON-only superset check cannot catch a candidate
  # whose .py sibling was swapped back to a stale/destructive version
  # while the JSON candidate stayed correct. Mutation-verified as part of
  # this remediation (this task's own implementation report, "Quality-gate
  # remediation correction" section): swapping the CANDIDATE .py for the
  # real human-copy/ (pre-epic-189-a1-merge) .py leaves the check below
  # FAILING, where the JSON-only check above alone would have stayed
  # green.
  #
  # Reads the .py sibling's PHASE2_TARGETS / BASELINE_SUFFIXES /
  # EPIC_A1_TARGETS constants by PARSING the module SOURCE TEXT (no python
  # shell-out), matching this file's own established "no python shell-out"
  # convention for candidate/live comparison logic above, and the same
  # textual-parsing technique tests/guard-invariants-epic-a1.tests.ps1
  # already uses for the identical class of constant.
  # =====================================================================
  $livePy = Join-Path $root 'plugins/sdd-quality-loop/scripts/generate-guard-invariants.py'
  $candidatePy = Join-Path $candidateDir 'plugins/sdd-quality-loop/scripts/generate-guard-invariants.py.candidate'
  $humanCopyGuardJson = Join-Path $root 'specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/references/guard-invariants.json'
  $humanCopyPy = Join-Path $root 'specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/scripts/generate-guard-invariants.py'

  function Get-PyTupleConstant([string]$SourcePath, [string]$Name) {
    # Extract a `NAME = ( "a", "b", ... )` python tuple-of-string-literals
    # constant from module SOURCE TEXT. Returns an empty array (never
    # $null) if the constant is absent entirely -- e.g. EPIC_A1_TARGETS in
    # a pre-epic-189-a1-merge generator -- so downstream set-difference
    # logic reads that as "0 entries" (a removal of every live entry, not
    # a script error), and never errors under Set-StrictMode.
    if (-not (Test-Path -LiteralPath $SourcePath)) { return @() }
    $text = [IO.File]::ReadAllText($SourcePath)
    $pattern = "(?ms)^$([regex]::Escape($Name)) = \($`r?`n(.*?)^\)`r?$"
    $m = [regex]::Match($text, $pattern)
    if (-not $m.Success) { return @() }
    $values = New-Object System.Collections.Generic.List[string]
    foreach ($line in $m.Groups[1].Value -split "`r?`n") {
      $lm = [regex]::Match($line, '^\s*"([^"]+)",\s*$')
      if ($lm.Success) { $values.Add($lm.Groups[1].Value) }
    }
    return , $values.ToArray()
  }

  function Test-NoRegressionPy([string]$TargetPath, [string]$LivePath) {
    if (-not (Test-Path -LiteralPath $TargetPath)) {
      return [PSCustomObject]@{ Rc = 1; Out = "script not found: $TargetPath" }
    }
    $removed = @()
    foreach ($attr in @('PHASE2_TARGETS', 'BASELINE_SUFFIXES', 'EPIC_A1_TARGETS')) {
      $liveValues = Get-PyTupleConstant -SourcePath $LivePath -Name $attr
      $targetValues = Get-PyTupleConstant -SourcePath $TargetPath -Name $attr
      $removed += Get-RemovedEntries $attr $liveValues $targetValues
    }
    if ($removed.Count -gt 0) {
      $message = "script drops $($removed.Count) live-protected entr(y/ies): " + ($removed -join '; ')
      return [PSCustomObject]@{ Rc = 1; Out = $message }
    }
    return [PSCustomObject]@{ Rc = 0; Out = 'script tuples are a pure superset of live (0 removals)' }
  }

  $candidatePyCheck = Test-NoRegressionPy -TargetPath $candidatePy -LivePath $livePy
  if ($candidatePyCheck.Rc -eq 0) {
    Ok "QG-fix: regenerated generate-guard-invariants.py candidate's PHASE2_TARGETS/BASELINE_SUFFIXES/EPIC_A1_TARGETS are a pure superset of live (.py, not just JSON)"
  } else {
    Fail "QG-fix: regenerated generate-guard-invariants.py candidate drops live-protected .py tuple entries -- $($candidatePyCheck.Out)"
  }

  # =====================================================================
  # Quality-gate cycle 3 remediation (2026-08-09) -- Critical finding: the
  # ACTUAL trap. tasks.md Done When #2, AC-029(a), and AC-030 all point a
  # human at applying whatever is staged under human-copy/ -- NOT at
  # drafts/human-copy-candidate/. The two checks below inspect that REAL
  # location directly; they are the deterministic gate the cycle-2
  # evaluator asked for ("罠が残置されたまま、決定論的ゲートが無い"). They
  # intentionally FAIL (DESIGNED-RED) for as long as human-copy/ still
  # holds the pre-epic-189-a1-merge bundle, and turn GREEN automatically
  # the moment a human replaces human-copy/'s contents with
  # drafts/human-copy-candidate/'s (that directory's own README.md "Human
  # apply step").
  # =====================================================================
  $humanCopyJsonCheck = Test-NoRegression -CandidatePath $humanCopyGuardJson -LivePath $liveGuardJson
  if ($humanCopyJsonCheck.Rc -eq 0) {
    Ok 'human-copy/ staged guard-invariants.json is a pure superset of live (human apply already landed)'
  } else {
    DesignedRed "human-copy/ staged guard-invariants.json is STALE and would DROP live-protected paths/keys if applied -- $($humanCopyJsonCheck.Out) -- HUMAN ACTION REQUIRED: replace specs/epic-190-a2-capability-registry/human-copy/ with specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/ (see that directory's README.md), then re-run this suite"
  }

  $humanCopyPyCheck = Test-NoRegressionPy -TargetPath $humanCopyPy -LivePath $livePy
  if ($humanCopyPyCheck.Rc -eq 0) {
    Ok 'human-copy/ staged generate-guard-invariants.py is a pure superset of live (human apply already landed)'
  } else {
    DesignedRed "human-copy/ staged generate-guard-invariants.py is STALE (e.g. missing EPIC_A1_TARGETS entirely) and would DROP live-protected .py tuple entries if applied -- $($humanCopyPyCheck.Out) -- HUMAN ACTION REQUIRED: same as above"
  }

  $candidateWorkflow = Join-Path $candidateDir '.github/workflows/test.yml.candidate'
  if (Test-Path -LiteralPath $candidateWorkflow) {
    $candidateWorkflowContent = Get-Content -LiteralPath $candidateWorkflow -Raw
    if ($candidateWorkflowContent -match [regex]::Escape('generate-gate-capabilities.py --check') -and
        $candidateWorkflowContent -match [regex]::Escape('tests/generate-registry-digest.tests.sh') -and
        $candidateWorkflowContent -match [regex]::Escape('tests/generate-registry-digest.tests.ps1')) {
      Ok 'QG-fix: rebuilt CI workflow candidate carries the gate-capabilities --check step and the generate-registry-digest suite'
    } else {
      Fail 'QG-fix: rebuilt CI workflow candidate is missing the gate-capabilities --check step or the generate-registry-digest suite'
    }

    # RT-20260809-002 item 1 (2026-08-10), drafts/ twin -- PowerShell
    # counterpart of the bash suite's identically-named assertion. Kept
    # separate from the compound check immediately above for the same
    # independence reason stated there.
    if ($candidateWorkflowContent -match [regex]::Escape('vendor-capability-registry.py --check')) {
      Ok 'QG-fix: rebuilt CI workflow candidate carries the vendoring drift-lock --check step (RT-20260809-002 item 1)'
    } else {
      Fail 'QG-fix: rebuilt CI workflow candidate is missing the vendoring drift-lock --check step (vendor-capability-registry.py --check)'
    }

    $candidateManifest = Join-Path $candidateDir 'MANIFEST.sha256.candidate'
    if (Test-Path -LiteralPath $candidateManifest) {
      $candidateWorkflowHash = (Get-FileHash -LiteralPath $candidateWorkflow -Algorithm SHA256).Hash.ToLowerInvariant()
      $candidateManifestLines = @(Get-Content -LiteralPath $candidateManifest)
      $candidateManifestLine = @($candidateManifestLines -match 'workflows/test\.yml')
      if ($candidateManifestLine.Count -gt 0) {
        $candidateManifestHash = ($candidateManifestLine[0] -split '\s+')[0].ToLowerInvariant()
        if ($candidateWorkflowHash -eq $candidateManifestHash) { Ok 'QG-fix: rebuilt CI workflow candidate sha256 matches its own MANIFEST.sha256.candidate' }
        else { Fail 'QG-fix: rebuilt CI workflow candidate sha256 does not match its own MANIFEST.sha256.candidate' }
      } else {
        Fail 'QG-fix: MANIFEST.sha256.candidate has no entry for the rebuilt workflow candidate'
      }
    } else {
      Fail 'QG-fix: MANIFEST.sha256.candidate missing'
    }
  } else {
    Fail 'QG-fix: rebuilt .github/workflows/test.yml.candidate missing'
  }

  # =====================================================================
  # Quality-gate cycle 3 remediation (2026-08-09) -- Minor finding 10:
  # PowerShell twin of the bash suite's identically-labeled job-set
  # superset check. See that check's own comment for the full rationale:
  # a substring grep or whole-file hash cannot detect a candidate that
  # silently drops an unrelated live job wholesale. Get-YamlJobKeys uses
  # the same line-based `jobs:`-block parsing tests/deterministic-lane-
  # selfcheck.tests.sh's job_keys() already established in this repository
  # (text markers only, no YAML-parsing dependency).
  # =====================================================================
  $liveWorkflow = Join-Path $root '.github/workflows/test.yml'

  function Get-YamlJobKeys([string]$Path) {
    $lines = [IO.File]::ReadAllLines($Path)
    $inJobs = $false
    $keys = New-Object System.Collections.Generic.List[string]
    foreach ($ln in $lines) {
      if ($ln.TrimEnd() -eq 'jobs:') { $inJobs = $true; continue }
      if ($inJobs) {
        if ($ln.Length -gt 0 -and $ln[0] -ne ' ') { break }
        if ($ln.StartsWith('  ') -and -not $ln.StartsWith('   ') -and $ln.TrimEnd().EndsWith(':')) {
          $keys.Add($ln.Trim().TrimEnd(':'))
        }
      }
    }
    return , $keys.ToArray()
  }

  function Test-JobSuperset([string]$TargetPath, [string]$LivePath) {
    if (-not (Test-Path -LiteralPath $TargetPath)) {
      return [PSCustomObject]@{ Rc = 1; Out = "workflow not found: $TargetPath" }
    }
    $liveJobs = Get-YamlJobKeys $LivePath
    $targetJobsArray = Get-YamlJobKeys $TargetPath
    $targetJobs = [System.Collections.Generic.HashSet[string]]::new([string[]]$targetJobsArray)
    $missing = @($liveJobs | Where-Object { -not $targetJobs.Contains($_) })
    if ($missing.Count -gt 0) {
      return [PSCustomObject]@{ Rc = 1; Out = "candidate drops $($missing.Count) live job(s): $($missing -join ' ')" }
    }
    return [PSCustomObject]@{ Rc = 0; Out = 'candidate carries every live job (0 dropped)' }
  }

  $candidateJobsCheck = Test-JobSuperset -TargetPath $candidateWorkflow -LivePath $liveWorkflow
  if ($candidateJobsCheck.Rc -eq 0) {
    Ok 'QG-fix: rebuilt CI workflow candidate is a job-set superset of live (structural, not just a step-name grep)'
  } else {
    Fail "QG-fix: rebuilt CI workflow candidate drops a live job -- $($candidateJobsCheck.Out)"
  }

  $humanCopyJobsCheck = Test-JobSuperset -TargetPath $stagedWorkflow -LivePath $liveWorkflow
  if ($humanCopyJobsCheck.Rc -eq 0) {
    Ok 'human-copy/ staged workflow is a job-set superset of live (human apply already landed)'
  } else {
    DesignedRed "human-copy/ staged workflow is STALE and would DROP whole live job(s) if applied -- $($humanCopyJobsCheck.Out) -- HUMAN ACTION REQUIRED: replace specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml with specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/.github/workflows/test.yml.candidate (see that directory's README.md), then re-run this suite"
  }

  # Done When #4 (tasks.md, "Suite registration + structural checks") --
  # PowerShell twin of the bash suite's identically-labeled check
  # (quality-gate remediation, 2026-08-09). Corrected label (quality-gate
  # cycle 3, 2026-08-09): this is Done When item #4, not #3 -- #3 is
  # "Test-registration procedure proof" (TEST-030); #4 is "Suite
  # registration + structural checks", which is where tasks.md's own text
  # places this grep self-check.
  $versionHit = $false
  foreach ($name in @('generate-gate-capabilities.py', 'generate-gate-capabilities.sh', 'generate-gate-capabilities.ps1')) {
    $target = Join-Path $root "plugins/sdd-quality-loop/scripts/$name"
    if ((Test-Path -LiteralPath $target) -and ((Get-Content -LiteralPath $target -Raw) -match '[0-9]+\.[0-9]+\.[0-9]+')) {
      $versionHit = $true
    }
  }
  if (-not $versionHit) { Ok 'Done When #4: no version string was hand-mutated in this task''s production files (grep self-check)' } else { Fail 'Done When #4: a semver-looking version string was found in this task''s production files' }
} finally {
  if (Test-Path -LiteralPath $workDir) { Remove-Item -LiteralPath $workDir -Recurse -Force }
}

Write-Host ("---- summary: pass={0} fail={1} designed-red={2} ----" -f $script:PassCount, $script:FailCount, $script:DesignedRedCount)
if ($script:FailCount -eq 0 -and $script:DesignedRedCount -eq 0) {
  Write-Host "generate-gate-capabilities suite passed ($script:PassCount checks)"
  exit 0
} elseif ($script:FailCount -eq 0) {
  Write-Host "generate-gate-capabilities suite is DESIGNED-RED ($script:PassCount passed, $script:DesignedRedCount designed-red pending human apply, 0 genuine failures)"
  Write-Host "HUMAN ACTION REQUIRED: replace specs/epic-190-a2-capability-registry/human-copy/ with specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/ (see that directory's README.md 'Human apply step'), then re-run this suite."
  exit 1
} else {
  Write-Host "generate-gate-capabilities suite FAILED ($script:PassCount passed, $script:FailCount failed, $script:DesignedRedCount designed-red)"
  exit 1
}
