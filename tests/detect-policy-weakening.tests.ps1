# T-005 (epic-189-a1-project-context, REQ-006): acceptance checks for
# plugins/sdd-quality-loop/scripts/detect-policy-weakening.py and its
# .sh/.ps1 dispatcher wrappers, plus the wiring-completion proof against
# generate-approval-sidecar.py (T-003's seam).
#
# PowerShell parity port of tests/detect-policy-weakening.tests.sh. See
# that file's header for the TEST-016/017/018/030/031/046 <-> AC mapping
# and the WIRING / TEST-HARDEN sections.
#
# Every invocation below runs the wrapper (or python3/python directly for
# the seam carry-forward fixtures) as a REAL CHILD PROCESS via
# [System.Diagnostics.Process], never PowerShell's own `&` call operator
# (detect-policy-weakening.ps1/generate-approval-sidecar.ps1 themselves
# call `exit $LASTEXITCODE`/return, which would terminate THIS test
# session if invoked in-process; raw stream capture also avoids
# PowerShell's success-pipeline byte mangling, mirroring
# canonicalize-sdd-yaml.tests.ps1's own rationale).
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Work = Join-Path ([IO.Path]::GetTempPath()) ("detect-policy-weakening-test-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null

$DetectPs1 = Join-Path $Root 'plugins/sdd-quality-loop/scripts/detect-policy-weakening.ps1'
$GenPs1 = Join-Path $Root 'plugins/sdd-quality-loop/scripts/generate-approval-sidecar.ps1'
# The SAME PowerShell binary currently running this suite, matching
# tests/run-all.ps1's own convention.
$PowerShellExe = (Get-Process -Id $PID).Path

$PythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $PythonCmd) { $PythonCmd = Get-Command python -ErrorAction SilentlyContinue }
if (-not $PythonCmd) {
  Write-Output 'FAIL: no python3/python interpreter available'
  exit 1
}
$PythonExe = $PythonCmd.Source

$script:PassCount = 0
$script:FailCount = 0

function Test-Pass([string]$Label) {
  $script:PassCount++
  Write-Output "PASS: $Label"
}

function Test-Fail([string]$Label, [string]$Detail = '') {
  $script:FailCount++
  Write-Output "FAIL: ${Label}: $Detail"
}

function Assert-Eq($Actual, $Expected, [string]$Label) {
  if ($Actual -eq $Expected) {
    Test-Pass $Label
  } else {
    Test-Fail $Label "got '$Actual', want '$Expected'"
  }
}

# Invoke-ChildProcess: runs $Exe with $ArgList as a real child process,
# optional environment overrides/removals, returning
# @{ ExitCode; StdoutPath; StderrPath }. Byte-exact raw stream capture (no
# Start-Process file-redirection artifact -- see canonicalize-sdd-yaml.tests.ps1).
function Invoke-ChildProcess {
  param(
    [Parameter(Mandatory)][string]$Exe,
    [string[]]$ArgList = @(),
    [hashtable]$EnvSet = @{},
    [string[]]$EnvUnset = @()
  )
  $outPath = Join-Path $Work ([Guid]::NewGuid().ToString('N') + '.out')
  $errPath = Join-Path $Work ([Guid]::NewGuid().ToString('N') + '.err')

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $Exe
  foreach ($a in $ArgList) { $psi.ArgumentList.Add($a) }
  # Explicit: propagate the CALLER's current logical location (Push-Location
  # changes it) rather than relying on ambient [Environment]::CurrentDirectory
  # syncing, which the sibling suites found unreliable across pwsh hosts.
  $psi.WorkingDirectory = (Get-Location).Path
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  foreach ($k in $EnvSet.Keys) { $psi.EnvironmentVariables[$k] = $EnvSet[$k] }
  foreach ($k in $EnvUnset) { $psi.EnvironmentVariables.Remove($k) | Out-Null }

  $proc = [System.Diagnostics.Process]::Start($psi)
  $stdoutStream = [System.IO.MemoryStream]::new()
  $stderrStream = [System.IO.MemoryStream]::new()
  $copyOutTask = $proc.StandardOutput.BaseStream.CopyToAsync($stdoutStream)
  $copyErrTask = $proc.StandardError.BaseStream.CopyToAsync($stderrStream)
  $proc.WaitForExit()
  $copyOutTask.GetAwaiter().GetResult()
  $copyErrTask.GetAwaiter().GetResult()
  [System.IO.File]::WriteAllBytes($outPath, $stdoutStream.ToArray())
  [System.IO.File]::WriteAllBytes($errPath, $stderrStream.ToArray())

  return @{ ExitCode = $proc.ExitCode; StdoutPath = $outPath; StderrPath = $errPath }
}

function Invoke-Detect {
  param([string[]]$ArgList = @())
  return Invoke-ChildProcess -Exe $PowerShellExe `
    -ArgList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $DetectPs1) + $ArgList)
}

function Invoke-Gen {
  param([string[]]$ArgList = @(), [hashtable]$EnvSet = @{})
  return Invoke-ChildProcess -Exe $PowerShellExe `
    -ArgList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $GenPs1) + $ArgList) `
    -EnvSet $EnvSet
}

function Get-VerdictJson([string]$Path) {
  return (Get-Content -Raw -LiteralPath $Path) | ConvertFrom-Json
}

function Get-ErrText($Result) {
  return (Get-Content -Raw -LiteralPath $Result.StderrPath -ErrorAction SilentlyContinue)
}

function Write-BaselineCap([string]$Path, [string]$CapabilityEnforcement) {
  Set-Content -LiteralPath $Path -NoNewline -Encoding utf8 -Value @"
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: $CapabilityEnforcement
"@
}

try {

# ---------------------------------------------------------------------------
# TEST-016: per-category classification + N/A reporting -- AC-016.
# ---------------------------------------------------------------------------

$T016 = Join-Path $Work 't016'
New-Item -ItemType Directory -Path $T016 -Force | Out-Null

$BaselineCap = Join-Path $T016 'baseline_cap.yaml'
$CandidateCap = Join-Path $T016 'candidate_cap.yaml'
Write-BaselineCap $BaselineCap 'required'
Write-BaselineCap $CandidateCap 'advisory'

$r = Invoke-Detect -ArgList @('--candidate', $CandidateCap, '--approved-context', $BaselineCap)
if ($r.ExitCode -eq 0) {
  Test-Pass 'TEST-016 capability_enforcement_weakened: tool exits 0'
} else {
  Test-Fail 'TEST-016 capability_enforcement_weakened: tool exits 0' "exit $($r.ExitCode); $(Get-ErrText $r)"
}
$v = Get-VerdictJson $r.StdoutPath
Assert-Eq $v.categories.capability_enforcement_weakened 'weakened' `
  'TEST-016 capability_enforcement_weakened classifies ''weakened'' (required -> advisory)'
Assert-Eq $v.policy_weakening $true `
  'TEST-016 capability_enforcement_weakened: overall policy_weakening is True'

foreach ($cat in @('capability_removed', 'public_distribution_descoped', 'criticality_lowered', `
    'provider_allowlist_widened', 'production_write_path_changed', 'required_gate_removed')) {
  Assert-Eq $v.categories.$cat 'n/a' `
    "TEST-016 N/A category '$cat' reported explicitly as n/a, never omitted"
}

$BaselinePath = Join-Path $T016 'baseline_path.yaml'
$CandidatePath = Join-Path $T016 'candidate_path.yaml'
Set-Content -LiteralPath $BaselinePath -NoNewline -Encoding utf8 -Value @"
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: required
components:
  - id: comp-a
    paths:
      include:
        - src/**
      exclude: []
"@
Set-Content -LiteralPath $CandidatePath -NoNewline -Encoding utf8 -Value @"
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: required
components:
  - id: comp-a
    paths:
      include:
        - src/desktop/**
      exclude: []
"@
$r = Invoke-Detect -ArgList @('--candidate', $CandidatePath, '--approved-context', $BaselinePath)
$v = Get-VerdictJson $r.StdoutPath
Assert-Eq $v.categories.component_path_narrowed 'weakened' `
  'TEST-016 component_path_narrowed classifies ''weakened'' (src/** -> src/desktop/**)'
Assert-Eq $v.policy_weakening $true `
  'TEST-016 component_path_narrowed: overall policy_weakening is True'

$BaselineSpec = Join-Path $T016 'baseline_spec.yaml'
$CandidateSpec = Join-Path $T016 'candidate_spec.yaml'
Write-BaselineCap $BaselineSpec 'required'
Set-Content -LiteralPath $CandidateSpec -NoNewline -Encoding utf8 -Value @"
schema: sdd-project-context/v1
workflow:
  spec_profile: lite
  artifact_layout: lite-three-file
  capability_enforcement: required
"@
$r = Invoke-Detect -ArgList @('--candidate', $CandidateSpec, '--approved-context', $BaselineSpec)
$v = Get-VerdictJson $r.StdoutPath
Assert-Eq $v.categories.spec_profile_full_to_lite 'weakened' `
  'TEST-016 spec_profile_full_to_lite classifies ''weakened'' (full -> lite)'
Assert-Eq $v.policy_weakening $true `
  'TEST-016 spec_profile_full_to_lite: overall policy_weakening is True'

# ---------------------------------------------------------------------------
# TEST-017: strengthening-change negative proof -- AC-017.
# ---------------------------------------------------------------------------

$BaselineStrengthen = Join-Path $T016 'baseline_strengthen.yaml'
$CandidateStrengthen = Join-Path $T016 'candidate_strengthen.yaml'
Write-BaselineCap $BaselineStrengthen 'advisory'
Write-BaselineCap $CandidateStrengthen 'required'
$r = Invoke-Detect -ArgList @('--candidate', $CandidateStrengthen, '--approved-context', $BaselineStrengthen)
$v = Get-VerdictJson $r.StdoutPath
Assert-Eq $v.categories.capability_enforcement_weakened 'not_weakened' `
  'TEST-017 a strengthening change (advisory -> required) classifies ''not_weakened'''
Assert-Eq $v.policy_weakening $false `
  'TEST-017 a strengthening change is NOT misclassified as weakening'

# ---------------------------------------------------------------------------
# TEST-018: two-person/cooldown verdict -- AC-018.
# ---------------------------------------------------------------------------

$T018Two = Join-Path $Work 't018-two'
New-Item -ItemType Directory -Path (Join-Path $T018Two 'sdd/.approved-context') -Force | Out-Null
Copy-Item -LiteralPath $BaselineCap -Destination (Join-Path $T018Two 'sdd/.approved-context/project-context.approved.yaml')
Copy-Item -LiteralPath $CandidateCap -Destination (Join-Path $T018Two 'candidate.yaml')
Set-Content -LiteralPath (Join-Path $T018Two 'sdd/approver-registry.yaml') -NoNewline -Encoding utf8 -Value @"
schema: sdd-approver-registry/v1
approvers:
  - id: alice
    name: Alice A
  - id: bob
    name: Bob B
"@
Push-Location $T018Two
try { $r = Invoke-Detect -ArgList @('--candidate', 'candidate.yaml') } finally { Pop-Location }
$v = Get-VerdictJson $r.StdoutPath
Assert-Eq $v.two_person_required $true `
  'TEST-018 a 2-distinct-identity registry emits two_person_required: true'
if ($null -eq $v.cooldown_hours) {
  Test-Pass 'TEST-018 the two-person path emits cooldown_hours: null'
} else {
  Test-Fail 'TEST-018 the two-person path emits cooldown_hours: null' "got '$($v.cooldown_hours)'"
}

$T018One = Join-Path $Work 't018-one'
New-Item -ItemType Directory -Path (Join-Path $T018One 'sdd/.approved-context') -Force | Out-Null
Copy-Item -LiteralPath $BaselineCap -Destination (Join-Path $T018One 'sdd/.approved-context/project-context.approved.yaml')
Copy-Item -LiteralPath $CandidateCap -Destination (Join-Path $T018One 'candidate.yaml')
Set-Content -LiteralPath (Join-Path $T018One 'sdd/approver-registry.yaml') -NoNewline -Encoding utf8 -Value @"
schema: sdd-approver-registry/v1
approvers:
  - id: alice
    name: Alice A
"@
Push-Location $T018One
try { $r = Invoke-Detect -ArgList @('--candidate', 'candidate.yaml') } finally { Pop-Location }
$v = Get-VerdictJson $r.StdoutPath
Assert-Eq $v.two_person_required $false `
  'TEST-018 a 1-identity registry emits two_person_required: false'
Assert-Eq $v.cooldown_hours 24 `
  'TEST-018 a 1-identity registry emits cooldown_hours: 24'

# ---------------------------------------------------------------------------
# TEST-046: zero-identity verdict half -- AC-046.
# ---------------------------------------------------------------------------

$T046 = Join-Path $Work 't046'
New-Item -ItemType Directory -Path (Join-Path $T046 'sdd/.approved-context') -Force | Out-Null
Copy-Item -LiteralPath $BaselineCap -Destination (Join-Path $T046 'sdd/.approved-context/project-context.approved.yaml')
Copy-Item -LiteralPath $CandidateCap -Destination (Join-Path $T046 'candidate.yaml')
Set-Content -LiteralPath (Join-Path $T046 'sdd/approver-registry.yaml') -NoNewline -Encoding utf8 -Value @"
schema: sdd-approver-registry/v1
approvers: []
"@
Push-Location $T046
try { $r = Invoke-Detect -ArgList @('--candidate', 'candidate.yaml') } finally { Pop-Location }
$v = Get-VerdictJson $r.StdoutPath
Assert-Eq $v.two_person_required $false `
  'TEST-046 a zero-entry (approvers: []) registry emits two_person_required: false'
Assert-Eq $v.cooldown_hours 24 `
  'TEST-046 a zero-entry registry emits cooldown_hours: 24, identical to the 1-identity case'

$T046Absent = Join-Path $Work 't046-absent'
New-Item -ItemType Directory -Path (Join-Path $T046Absent 'sdd/.approved-context') -Force | Out-Null
Copy-Item -LiteralPath $BaselineCap -Destination (Join-Path $T046Absent 'sdd/.approved-context/project-context.approved.yaml')
Copy-Item -LiteralPath $CandidateCap -Destination (Join-Path $T046Absent 'candidate.yaml')
Push-Location $T046Absent
try { $r = Invoke-Detect -ArgList @('--candidate', 'candidate.yaml') } finally { Pop-Location }
$v = Get-VerdictJson $r.StdoutPath
Assert-Eq $v.two_person_required $false `
  'TEST-046 a MISSING registry file is treated identically to a zero-entry one (two_person_required: false)'
Assert-Eq $v.cooldown_hours 24 `
  'TEST-046 a MISSING registry file emits cooldown_hours: 24'

# ---------------------------------------------------------------------------
# TEST-031: glob-coverage narrowing algorithm boundary cases -- AC-031.
# ---------------------------------------------------------------------------

function Write-PathsFixture([string]$Path, [string[]]$IncludeLines, [string[]]$ExcludeLines) {
  $lines = @(
    'schema: sdd-project-context/v1',
    'workflow:',
    '  spec_profile: full',
    '  artifact_layout: lite-three-file',
    '  capability_enforcement: required',
    'components:',
    '  - id: comp-a',
    '    paths:'
  ) + $IncludeLines + $ExcludeLines
  Set-Content -LiteralPath $Path -Encoding utf8 -Value $lines
}

$T031 = Join-Path $Work 't031'
New-Item -ItemType Directory -Path $T031 -Force | Out-Null

# (1) pattern removed: baseline [a/**, b/**] -> candidate [a/**] (narrows).
$B1 = Join-Path $T031 'b1.yaml'; $C1 = Join-Path $T031 'c1.yaml'
Write-PathsFixture $B1 @('      include:', '        - a/**', '        - b/**') @('      exclude: []')
Write-PathsFixture $C1 @('      include:', '        - a/**') @('      exclude: []')
$r = Invoke-Detect -ArgList @('--candidate', $C1, '--approved-context', $B1)
$v = Get-VerdictJson $r.StdoutPath
Assert-Eq $v.categories.component_path_narrowed 'weakened' 'TEST-031 (1) an include pattern removed narrows coverage'

# (2) pattern replaced at unchanged count: src/** -> src/desktop/** (narrows).
$B2 = Join-Path $T031 'b2.yaml'; $C2 = Join-Path $T031 'c2.yaml'
Write-PathsFixture $B2 @('      include:', '        - src/**') @('      exclude: []')
Write-PathsFixture $C2 @('      include:', '        - src/desktop/**') @('      exclude: []')
$r = Invoke-Detect -ArgList @('--candidate', $C2, '--approved-context', $B2)
$v = Get-VerdictJson $r.StdoutPath
Assert-Eq $v.categories.component_path_narrowed 'weakened' `
  'TEST-031 (2) an include pattern replaced by a more specific one at unchanged count narrows coverage'

# (3) exclude pattern added: [] -> [src/secret/**] (narrows).
$B3 = Join-Path $T031 'b3.yaml'; $C3 = Join-Path $T031 'c3.yaml'
Write-PathsFixture $B3 @('      include:', '        - src/**') @('      exclude: []')
Write-PathsFixture $C3 @('      include:', '        - src/**') @('      exclude:', '        - src/secret/**')
$r = Invoke-Detect -ArgList @('--candidate', $C3, '--approved-context', $B3)
$v = Get-VerdictJson $r.StdoutPath
Assert-Eq $v.categories.component_path_narrowed 'weakened' 'TEST-031 (3) an exclude pattern added narrows coverage'

# (4) exclude pattern replaced broader: src/secret/deep/** -> src/secret/** (narrows).
$B4 = Join-Path $T031 'b4.yaml'; $C4 = Join-Path $T031 'c4.yaml'
Write-PathsFixture $B4 @('      include:', '        - src/**') @('      exclude:', '        - src/secret/deep/**')
Write-PathsFixture $C4 @('      include:', '        - src/**') @('      exclude:', '        - src/secret/**')
$r = Invoke-Detect -ArgList @('--candidate', $C4, '--approved-context', $B4)
$v = Get-VerdictJson $r.StdoutPath
Assert-Eq $v.categories.component_path_narrowed 'weakened' `
  'TEST-031 (4) an exclude pattern replaced by a broader one narrows coverage'

# (5) pure broadening: [src/**] -> [src/**, docs/**] (does NOT narrow).
$B5 = Join-Path $T031 'b5.yaml'; $C5 = Join-Path $T031 'c5.yaml'
Write-PathsFixture $B5 @('      include:', '        - src/**') @('      exclude: []')
Write-PathsFixture $C5 @('      include:', '        - src/**', '        - docs/**') @('      exclude: []')
$r = Invoke-Detect -ArgList @('--candidate', $C5, '--approved-context', $B5)
$v = Get-VerdictJson $r.StdoutPath
Assert-Eq $v.categories.component_path_narrowed 'not_weakened' `
  'TEST-031 (5) a pure-broadening change (include pattern added, nothing removed) does NOT narrow'
Assert-Eq $v.policy_weakening $false `
  'TEST-031 (5) a pure-broadening change is not classified as policy-weakening'

# (6) whole-component removal/addition (quality-gate seq0353 Major remedy:
# pins the implementer's own extension beyond design.md's five literal
# boundary cases -- a component present in the baseline but ABSENT from
# the candidate is the ultimate narrowing of whatever effective path
# ownership it had, never silently ignored; a component's ADDITION is the
# mirror non-weakening case). Rationale: design.md:882-886 requires this
# algorithm to fail closed toward "review this" rather than fail open
# toward "silently permit a possible narrowing" -- a removed component
# with no assertion pinning it is exactly the fail-open risk that
# guidance forbids on this Risk: high policy-decision surface.
$B6Removed = Join-Path $T031 'b6-removed.yaml'
$C6Removed = Join-Path $T031 'c6-removed.yaml'
Set-Content -LiteralPath $B6Removed -NoNewline -Encoding utf8 -Value @"
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: required
components:
  - id: docs
    paths:
      include:
        - docs/**
      exclude: []
  - id: infra
    paths:
      include:
        - infra/**
      exclude: []
"@
Set-Content -LiteralPath $C6Removed -NoNewline -Encoding utf8 -Value @"
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: required
components:
  - id: infra
    paths:
      include:
        - infra/**
      exclude: []
"@
$r = Invoke-Detect -ArgList @('--candidate', $C6Removed, '--approved-context', $B6Removed)
$v = Get-VerdictJson $r.StdoutPath
Assert-Eq $v.categories.component_path_narrowed 'weakened' `
  'TEST-031 (6a) a whole component removed (docs) narrows coverage (fail-closed extension beyond design.md''s five literal fixtures)'
Assert-Eq $v.policy_weakening $true `
  'TEST-031 (6a) a whole component removed is classified as policy-weakening'

$B6Added = Join-Path $T031 'b6-added.yaml'
$C6Added = Join-Path $T031 'c6-added.yaml'
Set-Content -LiteralPath $B6Added -NoNewline -Encoding utf8 -Value @"
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: required
components:
  - id: infra
    paths:
      include:
        - infra/**
      exclude: []
"@
Set-Content -LiteralPath $C6Added -NoNewline -Encoding utf8 -Value @"
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: required
components:
  - id: infra
    paths:
      include:
        - infra/**
      exclude: []
  - id: docs
    paths:
      include:
        - docs/**
      exclude: []
"@
$r = Invoke-Detect -ArgList @('--candidate', $C6Added, '--approved-context', $B6Added)
$v = Get-VerdictJson $r.StdoutPath
Assert-Eq $v.categories.component_path_narrowed 'not_weakened' `
  'TEST-031 (6b) mirror case: a NEW component added (docs) does NOT narrow (the baseline''s own components are untouched)'
Assert-Eq $v.policy_weakening $false `
  'TEST-031 (6b) a component addition is NOT classified as policy-weakening'

# ---------------------------------------------------------------------------
# TEST-030: approved-context anchor CLI contract -- AC-030.
# ---------------------------------------------------------------------------

# (1) identical-to-anchor candidate classifies false for every category.
$T030Identical = Join-Path $Work 't030-identical'
New-Item -ItemType Directory -Path (Join-Path $T030Identical 'sdd/.approved-context') -Force | Out-Null
Copy-Item -LiteralPath $BaselineCap -Destination (Join-Path $T030Identical 'sdd/.approved-context/project-context.approved.yaml')
Copy-Item -LiteralPath $BaselineCap -Destination (Join-Path $T030Identical 'candidate.yaml')
Push-Location $T030Identical
try { $r = Invoke-Detect -ArgList @('--candidate', 'candidate.yaml') } finally { Pop-Location }
$v = Get-VerdictJson $r.StdoutPath
Assert-Eq $v.policy_weakening $false `
  'TEST-030 (1) a candidate identical to the approved anchor classifies policy_weakening: false'

# (2) genuine diff classifies true, both immediately and after landing as
# ordinary git commits (a new commit alone never moves the anchor).
$GitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($GitCmd) {
  $GitWork = Join-Path $Work 't030-git'
  New-Item -ItemType Directory -Path (Join-Path $GitWork 'sdd/.approved-context') -Force | Out-Null
  Copy-Item -LiteralPath $BaselineCap -Destination (Join-Path $GitWork 'sdd/.approved-context/project-context.approved.yaml')
  Copy-Item -LiteralPath $BaselineCap -Destination (Join-Path $GitWork 'project-context.yaml')
  Push-Location $GitWork
  try {
    & git init -q 2>$null
    & git -c user.email=t@t.example -c user.name=t add -A 2>$null
    & git -c user.email=t@t.example -c user.name=t commit -q -m init 2>$null
    $r = Invoke-Detect -ArgList @('--candidate', 'project-context.yaml')
  } finally { Pop-Location }
  $v = Get-VerdictJson $r.StdoutPath
  Assert-Eq $v.policy_weakening $false `
    'TEST-030 (2a) before any change, candidate matches the anchor: policy_weakening: false'

  Copy-Item -LiteralPath $CandidateCap -Destination (Join-Path $GitWork 'project-context.yaml') -Force
  Push-Location $GitWork
  try { $r = Invoke-Detect -ArgList @('--candidate', 'project-context.yaml') } finally { Pop-Location }
  $v = Get-VerdictJson $r.StdoutPath
  Assert-Eq $v.policy_weakening $true `
    'TEST-030 (2b) a genuine weakening diff classifies true IMMEDIATELY (before any commit)'

  Push-Location $GitWork
  try {
    & git -c user.email=t@t.example -c user.name=t add -A 2>$null
    & git -c user.email=t@t.example -c user.name=t commit -q -m weaken 2>$null
    $r = Invoke-Detect -ArgList @('--candidate', 'project-context.yaml')
  } finally { Pop-Location }
  $v = Get-VerdictJson $r.StdoutPath
  Assert-Eq $v.policy_weakening $true `
    'TEST-030 (2c) the weakening diff STILL classifies true AFTER landing as an ordinary git commit (a commit never moves the anchor)'
} else {
  Write-Output 'SKIP: git not available; TEST-030 (2) git-commit-immutability sub-case skipped'
}

# (3) production call path immune to a caller-supplied override.
$GenSource = Get-Content -Raw -LiteralPath (Join-Path $Root 'plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py')
if ($GenSource -match [regex]::Escape('--approved-context')) {
  Test-Fail 'TEST-030 (3) generate-approval-sidecar.py never passes --approved-context to the detector'
} else {
  Test-Pass 'TEST-030 (3) generate-approval-sidecar.py never passes --approved-context to the detector'
}

# (4) no anchor snapshot exists yet: NO_APPROVED_CONTEXT_ANCHOR, exit 0.
$T030NoAnchor = Join-Path $Work 't030-noanchor'
New-Item -ItemType Directory -Path $T030NoAnchor -Force | Out-Null
Copy-Item -LiteralPath $CandidateCap -Destination (Join-Path $T030NoAnchor 'candidate.yaml')
Push-Location $T030NoAnchor
try { $r = Invoke-Detect -ArgList @('--candidate', 'candidate.yaml') } finally { Pop-Location }
$errText = Get-ErrText $r
if ($r.ExitCode -eq 0 -and $errText -match 'NO_APPROVED_CONTEXT_ANCHOR') {
  Test-Pass 'TEST-030 (4) no approved-context anchor yet: exit 0 with the documented NO_APPROVED_CONTEXT_ANCHOR note'
} else {
  Test-Fail 'TEST-030 (4) no approved-context anchor yet: exit 0 with NO_APPROVED_CONTEXT_ANCHOR' "exit $($r.ExitCode); $errText"
}
$v = Get-VerdictJson $r.StdoutPath
Assert-Eq $v.policy_weakening $false `
  'TEST-030 (4) with no anchor, every category treated as a new addition (policy_weakening: false)'

# (5) a live human-copy transaction journal naming the anchor path fails closed.
$T030InProgress = Join-Path $Work 't030-inprogress'
New-Item -ItemType Directory -Path (Join-Path $T030InProgress 'sdd/.approved-context') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $T030InProgress 'sdd/.staging/some-nonce') -Force | Out-Null
Copy-Item -LiteralPath $BaselineCap -Destination (Join-Path $T030InProgress 'sdd/.approved-context/project-context.approved.yaml')
Copy-Item -LiteralPath $CandidateCap -Destination (Join-Path $T030InProgress 'candidate.yaml')
Set-Content -LiteralPath (Join-Path $T030InProgress 'sdd/.staging/some-nonce/TRANSACTION.json') -NoNewline -Encoding utf8 -Value @'
{
  "nonce": "some-nonce",
  "status": "in-progress",
  "targets": [
    {"live_path": "sdd/.approved-context/project-context.approved.yaml", "pre_hash": "ABSENT", "post_hash": "deadbeef"}
  ]
}
'@
Push-Location $T030InProgress
try { $r = Invoke-Detect -ArgList @('--candidate', 'candidate.yaml') } finally { Pop-Location }
$errText = Get-ErrText $r
if ($r.ExitCode -eq 21 -and $errText -match 'HUMAN_COPY_PUBLISH_IN_PROGRESS') {
  Test-Pass 'TEST-030 (5) a live TRANSACTION.json naming the anchor fails closed (exit 21/HUMAN_COPY_PUBLISH_IN_PROGRESS)'
} else {
  Test-Fail 'TEST-030 (5) a live TRANSACTION.json naming the anchor fails closed' "exit $($r.ExitCode); $errText"
}
$outText = Get-Content -Raw -LiteralPath $r.StdoutPath -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($outText)) {
  Test-Pass 'TEST-030 (5) the in-progress-publish refusal emits no verdict on stdout'
} else {
  Test-Fail 'TEST-030 (5) the in-progress-publish refusal emits no verdict on stdout' $outText
}

# ---------------------------------------------------------------------------
# WIRING: end-to-end proof against generate-approval-sidecar.py.
# ---------------------------------------------------------------------------

$Wiring = Join-Path $Work 'wiring'
New-Item -ItemType Directory -Path (Join-Path $Wiring 'sdd/.approved-context') -Force | Out-Null
Copy-Item -LiteralPath $BaselineCap -Destination (Join-Path $Wiring 'sdd/.approved-context/project-context.approved.yaml')
Copy-Item -LiteralPath $BaselineCap -Destination (Join-Path $Wiring 'project-context.yaml')
Set-Content -LiteralPath (Join-Path $Wiring 'live-sidecar.json') -NoNewline -Encoding utf8 -Value @'
{"schema": "sdd-project-context-approval/v1", "context_sha256": "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", "approval_epoch": 1}
'@
Push-Location $Wiring
try {
  $r = Invoke-Gen -ArgList @(
    '--schema', 'sdd-project-context-approval/v1',
    '--content', 'project-context.yaml',
    '--approver', 'alice',
    '--status', 'Approved',
    '--live-sidecar', 'live-sidecar.json',
    '--stage-dir', 'stage-out'
  ) -EnvSet @{ SDD_CONTEXT_KEY = 'test-context-key-epic189-t005' }
} finally { Pop-Location }
if ($r.ExitCode -eq 0) {
  Test-Pass 'WIRING a non-bootstrap signing fixture succeeds now that the detector is present (exit 0)'
} else {
  Test-Fail 'WIRING a non-bootstrap signing fixture succeeds now that the detector is present' "exit $($r.ExitCode); $(Get-ErrText $r)"
}
$wiringErr = Get-ErrText $r
if ($wiringErr -match 'WEAKENING_DETECTOR_UNAVAILABLE') {
  Test-Fail 'WIRING WEAKENING_DETECTOR_UNAVAILABLE no longer fires for this fixture'
} else {
  Test-Pass 'WIRING WEAKENING_DETECTOR_UNAVAILABLE no longer fires for this fixture'
}
# The published generator stages outputs at their live-path mirror
# (stage-out/sdd/...); older builds used a flat basename. Resolve either.
$StagedSidecar = Join-Path $Wiring 'stage-out/sdd/project-context.approval.json'
if (-not (Test-Path -LiteralPath $StagedSidecar)) {
  $StagedSidecar = Join-Path $Wiring 'stage-out/project-context.approval.json'
}
if (Test-Path -LiteralPath $StagedSidecar) {
  Test-Pass 'WIRING a staged sidecar candidate was written'
} else {
  Test-Fail 'WIRING a staged sidecar candidate was written'
}

# Byte-exact comparison via python's own sort_keys=True JSON dump (both the
# embedded sidecar field and the CLI's own direct output are produced by
# the SAME json.dumps(..., sort_keys=True) call, so a string comparison is
# reliable across runtimes here, unlike PowerShell's own ConvertTo-Json
# key-ordering).
$embeddedVerdict = & $PythonExe -c @"
import json
print(json.dumps(json.load(open(r'$StagedSidecar'))['weakening_verdict'], sort_keys=True))
"@
Push-Location $Wiring
try {
  $directResult = Invoke-Detect -ArgList @('--candidate', 'project-context.yaml')
} finally { Pop-Location }
$directVerdict = & $PythonExe -c @"
import json
print(json.dumps(json.load(open(r'$($directResult.StdoutPath)')), sort_keys=True))
"@
if ($embeddedVerdict -and ($embeddedVerdict -eq $directVerdict)) {
  Test-Pass 'WIRING the sidecar''s embedded weakening_verdict is EXACTLY the in-process-computed verdict'
} else {
  Test-Fail 'WIRING the sidecar''s embedded weakening_verdict is EXACTLY the in-process-computed verdict' "embedded=$embeddedVerdict direct=$directVerdict"
}

# WIRING carry-forward regression (T-003 QG round-2 seq0352 advance
# findings #1/#2/#3), via a substitute scripts directory (a copy of
# generate-approval-sidecar.py alongside a deliberately-bugged
# detect-policy-weakening.py stand-in) so the REAL detector is never
# altered.
$SeamFixtures = Join-Path $Work 'seam-fixtures'
New-Item -ItemType Directory -Path $SeamFixtures -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $Root 'plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py') -Destination (Join-Path $SeamFixtures 'generate-approval-sidecar.py')
Copy-Item -LiteralPath (Join-Path $Root 'plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py') -Destination (Join-Path $SeamFixtures 'canonicalize-sdd-yaml.py')

$SeamProj = Join-Path $Work 'seam-proj'
New-Item -ItemType Directory -Path $SeamProj -Force | Out-Null
Copy-Item -LiteralPath $BaselineCap -Destination (Join-Path $SeamProj 'project-context.yaml')
Copy-Item -LiteralPath (Join-Path $Wiring 'live-sidecar.json') -Destination (Join-Path $SeamProj 'live-sidecar.json')

function Invoke-Seam([string]$Source, [string]$Suffix) {
  Set-Content -LiteralPath (Join-Path $SeamFixtures 'detect-policy-weakening.py') -Encoding utf8 -Value $Source
  return Invoke-ChildProcess -Exe $PythonExe -ArgList @(
    (Join-Path $SeamFixtures 'generate-approval-sidecar.py'),
    '--schema', 'sdd-project-context-approval/v1',
    '--content', (Join-Path $SeamProj 'project-context.yaml'),
    '--approver', 'alice',
    '--status', 'Approved',
    '--live-sidecar', (Join-Path $SeamProj 'live-sidecar.json'),
    '--stage-dir', (Join-Path $SeamProj "stage-$Suffix")
  ) -EnvSet @{ SDD_CONTEXT_KEY = 'test-context-key-epic189-t005' }
}

$r = Invoke-Seam @'
class DetectPolicyWeakeningError(Exception):
    def __init__(self, category, message):
        super().__init__(message)
        self.category = category
        self.message = message


def compute_verdict(candidate_path, approved_context_path=None):
    raise RuntimeError("seam-fixture: unexpected failure")
'@ 'finding1'
$errText = Get-ErrText $r
if ($r.ExitCode -eq 17 -and $errText -match 'WEAKENING_DETECTOR_ERROR' -and $errText -notmatch '(?i)traceback') {
  Test-Pass 'WIRING carry-forward #1: an unexpected compute_verdict() exception surfaces as classified WEAKENING_DETECTOR_ERROR (exit 17), never a raw traceback'
} else {
  Test-Fail 'WIRING carry-forward #1: an unexpected compute_verdict() exception surfaces as classified WEAKENING_DETECTOR_ERROR' "exit $($r.ExitCode); $errText"
}

$r = Invoke-Seam @'
class DetectPolicyWeakeningError(Exception):
    def __init__(self, category, message):
        super().__init__(message)
        self.category = category
        self.message = message


def compute_verdict(candidate_path, approved_context_path=None):
    raise DetectPolicyWeakeningError("CANDIDATE_NOT_SCHEMA_VALID", "seam-fixture: pass-through proof")
'@ 'finding1b'
$errText = Get-ErrText $r
if ($r.ExitCode -eq 20 -and $errText -match 'CANDIDATE_NOT_SCHEMA_VALID' -and $errText -notmatch '(?i)traceback') {
  Test-Pass 'WIRING carry-forward #1b: the detector''s own named category is passed through verbatim (exit 20/CANDIDATE_NOT_SCHEMA_VALID), never collapsed to a generic label'
} else {
  Test-Fail 'WIRING carry-forward #1b: the detector''s own named category is passed through verbatim' "exit $($r.ExitCode); $errText"
}

$r = Invoke-Seam @'
def compute_verdict(candidate_path, approved_context_path=None):
    return {"policy_weakening": True}
'@ 'finding2'
$errText = Get-ErrText $r
if ($r.ExitCode -eq 18 -and $errText -match 'WEAKENING_VERDICT_MALFORMED' -and $errText -notmatch '(?i)traceback') {
  Test-Pass 'WIRING carry-forward #2: a malformed verdict is rejected BEFORE preimage construction (exit 18/WEAKENING_VERDICT_MALFORMED), never a downstream TypeError'
} else {
  Test-Fail 'WIRING carry-forward #2: a malformed verdict is rejected before preimage construction' "exit $($r.ExitCode); $errText"
}

$r = Invoke-Seam @'
def compute_verdict(candidate_path, approved_context_path=None):
    class NotSerializable:
        pass
    return {
        "policy_weakening": True,
        "categories": {
            "capability_enforcement_weakened": "weakened",
            "capability_removed": "n/a",
            "component_path_narrowed": "not_weakened",
            "public_distribution_descoped": "n/a",
            "criticality_lowered": "n/a",
            "provider_allowlist_widened": "n/a",
            "production_write_path_changed": "n/a",
            "required_gate_removed": "n/a",
            "spec_profile_full_to_lite": "not_weakened",
        },
        "two_person_required": False,
        "cooldown_hours": NotSerializable(),
    }
'@ 'finding2b'
$errText = Get-ErrText $r
if ($r.ExitCode -eq 18 -and $errText -match 'WEAKENING_VERDICT_MALFORMED' -and $errText -notmatch '(?i)traceback') {
  Test-Pass 'WIRING carry-forward #2b: a non-serializable cooldown_hours value is rejected as WEAKENING_VERDICT_MALFORMED (exit 18), never an uncaught TypeError'
} else {
  Test-Fail 'WIRING carry-forward #2b: a non-serializable verdict field is rejected cleanly' "exit $($r.ExitCode); $errText"
}

$r = Invoke-Seam @'
def compute_verdict(candidate_path, approved_context_path=None):
    return None
'@ 'finding3'
$errText = Get-ErrText $r
if ($r.ExitCode -eq 18 -and $errText -match 'WEAKENING_VERDICT_MALFORMED' -and $errText -notmatch '(?i)traceback') {
  Test-Pass 'WIRING carry-forward #3: a None verdict for a non-bootstrap transition is refused (exit 18/WEAKENING_VERDICT_MALFORMED), never embedded as weakening_verdict: null'
} else {
  Test-Fail 'WIRING carry-forward #3: a None verdict for a non-bootstrap transition is refused' "exit $($r.ExitCode); $errText"
}
if (Test-Path -LiteralPath (Join-Path $SeamProj 'stage-finding3')) {
  Test-Fail 'WIRING carry-forward #3: the refusal writes no staged candidate'
} else {
  Test-Pass 'WIRING carry-forward #3: the refusal writes no staged candidate'
}

# ---------------------------------------------------------------------------
# TEST-HARDEN(a..e): fail-closed exhaustiveness.
# ---------------------------------------------------------------------------

$r = Invoke-Detect -ArgList @('--candidate', (Join-Path $Work 'does-not-exist.yaml'))
$errText = Get-ErrText $r
if ($r.ExitCode -eq 20 -and $errText -match 'CANDIDATE_NOT_SCHEMA_VALID' -and $errText -notmatch '(?i)traceback') {
  Test-Pass 'TEST-HARDEN(a) a missing --candidate file is rejected cleanly (exit 20/CANDIDATE_NOT_SCHEMA_VALID), never a traceback'
} else {
  Test-Fail 'TEST-HARDEN(a) a missing --candidate file is rejected cleanly' "exit $($r.ExitCode); $errText"
}

$BadSchema = Join-Path $T016 'bad_schema.yaml'
Set-Content -LiteralPath $BadSchema -NoNewline -Encoding utf8 -Value @"
schema: sdd-something-else/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: required
"@
$r = Invoke-Detect -ArgList @('--candidate', $BadSchema, '--approved-context', $BaselineCap)
$errText = Get-ErrText $r
if ($r.ExitCode -eq 20 -and $errText -match 'CANDIDATE_NOT_SCHEMA_VALID' -and $errText -notmatch '(?i)traceback') {
  Test-Pass 'TEST-HARDEN(b) an unrecognized ''schema'' field is rejected cleanly (exit 20/CANDIDATE_NOT_SCHEMA_VALID), never a traceback'
} else {
  Test-Fail 'TEST-HARDEN(b) an unrecognized ''schema'' field is rejected cleanly' "exit $($r.ExitCode); $errText"
}

$CorruptAnchor = Join-Path $T016 'corrupt_anchor.yaml'
Set-Content -LiteralPath $CorruptAnchor -NoNewline -Encoding utf8 -Value @"
schema: sdd-project-context/v1
schema: sdd-project-context/v1
"@
$r = Invoke-Detect -ArgList @('--candidate', $CandidateCap, '--approved-context', $CorruptAnchor)
$errText = Get-ErrText $r
if ($r.ExitCode -eq 22 -and $errText -match 'APPROVED_CONTEXT_ANCHOR_UNREADABLE' -and $errText -notmatch '(?i)traceback') {
  Test-Pass 'TEST-HARDEN(c) a corrupt (out-of-subset) approved-context anchor is rejected cleanly (exit 22/APPROVED_CONTEXT_ANCHOR_UNREADABLE), never a traceback'
} else {
  Test-Fail 'TEST-HARDEN(c) a corrupt approved-context anchor is rejected cleanly' "exit $($r.ExitCode); $errText"
}

$T023BadReg = Join-Path $Work 't023-badreg'
New-Item -ItemType Directory -Path (Join-Path $T023BadReg 'sdd/.approved-context') -Force | Out-Null
Copy-Item -LiteralPath $BaselineCap -Destination (Join-Path $T023BadReg 'sdd/.approved-context/project-context.approved.yaml')
Copy-Item -LiteralPath $CandidateCap -Destination (Join-Path $T023BadReg 'candidate.yaml')
Set-Content -LiteralPath (Join-Path $T023BadReg 'sdd/approver-registry.yaml') -NoNewline -Encoding utf8 -Value '- just_a_list_item'
Push-Location $T023BadReg
try { $r = Invoke-Detect -ArgList @('--candidate', 'candidate.yaml') } finally { Pop-Location }
$errText = Get-ErrText $r
if ($r.ExitCode -eq 23 -and $errText -match 'APPROVER_REGISTRY_UNREADABLE' -and $errText -notmatch '(?i)traceback') {
  Test-Pass 'TEST-HARDEN(d) a malformed (non-object) approver-registry.yaml is rejected cleanly (exit 23/APPROVER_REGISTRY_UNREADABLE), never a traceback'
} else {
  Test-Fail 'TEST-HARDEN(d) a malformed approver-registry.yaml is rejected cleanly' "exit $($r.ExitCode); $errText"
}

$r = Invoke-Detect -ArgList @()
$errText = Get-ErrText $r
if ($r.ExitCode -eq 2 -and $errText -notmatch '(?i)traceback') {
  Test-Pass 'TEST-HARDEN(e) a missing required --candidate argument is a clean usage error (exit 2), never a traceback'
} else {
  Test-Fail 'TEST-HARDEN(e) a missing required --candidate argument is a clean usage error' "exit $($r.ExitCode); $errText"
}

# ---------------------------------------------------------------------------
# Self-registration (design.md Test Strategy item 11).
# ---------------------------------------------------------------------------

$RunAllSh = Get-Content -Raw -LiteralPath (Join-Path $Root 'tests/run-all.sh')
if ($RunAllSh -match 'detect-policy-weakening\.tests\.sh') {
  Test-Pass 'self-registration: tests/detect-policy-weakening.tests.sh registered in tests/run-all.sh'
} else {
  Test-Fail 'self-registration: tests/detect-policy-weakening.tests.sh registered in tests/run-all.sh'
}
$RunAllPs1 = Get-Content -Raw -LiteralPath (Join-Path $Root 'tests/run-all.ps1')
if ($RunAllPs1 -match 'detect-policy-weakening\.tests\.ps1') {
  Test-Pass 'self-registration: tests/detect-policy-weakening.tests.ps1 registered in tests/run-all.ps1'
} else {
  Test-Fail 'self-registration: tests/detect-policy-weakening.tests.ps1 registered in tests/run-all.ps1'
}

Write-Output "PASS: $script:PassCount"
Write-Output "FAIL: $script:FailCount"
if ($script:FailCount -gt 0) { exit 1 } else { exit 0 }
}
finally {
  Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}
