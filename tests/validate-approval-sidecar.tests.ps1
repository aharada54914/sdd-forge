# T-006 (epic-189-a1-project-context, REQ-005): acceptance checks for
# plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py and its
# .sh/.ps1 dispatcher wrappers.
#
# PowerShell parity port of tests/validate-approval-sidecar.tests.sh. See
# that file's header for the TEST-014/015/019/020/043/046, AC-045
# PRODUCTION discharge, and OBLIGATION 1/2/4b <-> AC mapping and rationale.
#
# Every invocation below runs the wrapper as a REAL CHILD PROCESS via
# [System.Diagnostics.Process], never PowerShell's own `&` call operator
# (validate-approval-sidecar.ps1/generate-approval-sidecar.ps1 themselves
# call `exit $proc.ExitCode`, which would terminate THIS test session if
# invoked in-process; raw stream capture also avoids PowerShell's
# success-pipeline byte mangling, mirroring the sibling suites' own
# rationale).
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Work = Join-Path ([IO.Path]::GetTempPath()) ("validate-approval-sidecar-test-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null

$ValSh = Join-Path $Root 'plugins/sdd-quality-loop/scripts/validate-approval-sidecar.sh'
$ValPy = Join-Path $Root 'plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py'
$ValPs1 = Join-Path $Root 'plugins/sdd-quality-loop/scripts/validate-approval-sidecar.ps1'
$GenPs1 = Join-Path $Root 'plugins/sdd-quality-loop/scripts/generate-approval-sidecar.ps1'
$GenPy = Join-Path $Root 'plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py'
$CanonPy = Join-Path $Root 'plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py'
$HookGuardPy = Join-Path $Root 'plugins/sdd-quality-loop/scripts/sdd-hook-guard.py'
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

$TestKey = 'test-context-key-epic189-t006'

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

function Invoke-Val {
  param([string[]]$ArgList = @(), [hashtable]$EnvSet = @{}, [string[]]$EnvUnset = @())
  return Invoke-ChildProcess -Exe $PowerShellExe `
    -ArgList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ValPs1) + $ArgList) `
    -EnvSet $EnvSet -EnvUnset $EnvUnset
}

function Invoke-Gen {
  param([string[]]$ArgList = @(), [hashtable]$EnvSet = @{})
  return Invoke-ChildProcess -Exe $PowerShellExe `
    -ArgList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $GenPs1) + $ArgList) `
    -EnvSet $EnvSet
}

function Invoke-Py {
  param([string[]]$ArgList = @())
  return Invoke-ChildProcess -Exe $PythonExe -ArgList $ArgList
}

function Get-ErrText($Result) {
  return (Get-Content -Raw -LiteralPath $Result.StderrPath -ErrorAction SilentlyContinue)
}

function Get-OutText($Result) {
  return (Get-Content -Raw -LiteralPath $Result.StdoutPath -ErrorAction SilentlyContinue)
}

# ---------------------------------------------------------------------------
# sign_fixture.py -- see tests/validate-approval-sidecar.tests.sh's own
# header comment for the rationale (independent HMAC/hash computation,
# never via generate-approval-sidecar.py's internals).
# ---------------------------------------------------------------------------

$SignFixture = Join-Path $Work 'sign_fixture.py'
Set-Content -LiteralPath $SignFixture -NoNewline -Encoding utf8 -Value @'
import hashlib
import hmac
import json
import os
import subprocess
import sys
import tempfile

canon_py, content_path, key_file, template_path, output_path = sys.argv[1:6]
override_hash = sys.argv[6] if len(sys.argv) > 6 else None

with open(template_path, "r", encoding="utf-8") as f:
    obj = json.load(f)

if override_hash:
    obj["context_sha256"] = override_hash
elif content_path != "NONE":
    proc = subprocess.run(
        [sys.executable, canon_py, content_path, "--input-format", "yaml", "--hash-only"],
        capture_output=True, check=True,
    )
    obj["context_sha256"] = proc.stdout.decode("ascii").strip()

obj.pop("hmac", None)
tmp_fd, tmp_path = tempfile.mkstemp()
with os.fdopen(tmp_fd, "w", encoding="utf-8") as f:
    json.dump(obj, f)
proc = subprocess.run(
    [sys.executable, canon_py, tmp_path, "--input-format", "json"],
    capture_output=True, check=True,
)
os.unlink(tmp_path)
preimage = proc.stdout

if key_file != "NONE":
    with open(key_file, "rb") as f:
        key = f.read()
    obj["hmac"] = hmac.new(key, preimage, hashlib.sha256).hexdigest()
else:
    obj["hmac"] = "0" * 64

with open(output_path, "w", encoding="utf-8") as f:
    json.dump(obj, f, indent=2, sort_keys=True)
    f.write("\n")
'@

function New-SignedFixture([string]$ContentPath, [string]$KeyFile, [string]$TemplatePath, [string]$OutputPath, [string]$HashOverride = '') {
  $argList = @($CanonPy, $ContentPath, $KeyFile, $TemplatePath, $OutputPath)
  if ($HashOverride) { $argList += $HashOverride }
  $r = Invoke-Py -ArgList (@($SignFixture) + $argList)
  if ($r.ExitCode -ne 0) {
    throw "sign_fixture.py failed (exit $($r.ExitCode)): $(Get-ErrText $r)"
  }
}

function New-Template([string]$OutPath, [string]$Approver, [string]$SecondJson, [string]$EffectiveJson, [string]$PredecessorJson, [string]$VerdictJson, [int]$Epoch) {
  $body = @"
{
  "schema": "sdd-project-context-approval/v1",
  "context_sha256": "sha256:0000000000000000000000000000000000000000000000000000000000000000",
  "primary_approval": {"status": "Approved", "approver": "$Approver", "approved_at": "2026-01-01T00:00:00Z"},
  "second_approval": $SecondJson,
  "effective_at": $EffectiveJson,
  "predecessor_context_sha256": $PredecessorJson,
  $VerdictJson,
  "approval_epoch": $Epoch
}
"@
  Set-Content -LiteralPath $OutPath -NoNewline -Encoding utf8 -Value $body
}

$KeyFile = Join-Path $Work 'context-key'
Set-Content -LiteralPath $KeyFile -NoNewline -Encoding utf8 -Value $TestKey

# ---------------------------------------------------------------------------
# Content, registry fixtures.
# ---------------------------------------------------------------------------

$ContentValid = Join-Path $Work 'project-context.yaml'
Set-Content -LiteralPath $ContentValid -NoNewline -Encoding utf8 -Value @'
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: required
'@

$ContentOther = Join-Path $Work 'project-context-other.yaml'
Set-Content -LiteralPath $ContentOther -NoNewline -Encoding utf8 -Value @'
schema: sdd-project-context/v1
workflow:
  spec_profile: lite
  artifact_layout: lite-three-file
  capability_enforcement: advisory
'@

$ContentDupComponent = Join-Path $Work 'project-context-dup.yaml'
Set-Content -LiteralPath $ContentDupComponent -NoNewline -Encoding utf8 -Value @'
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: required
components:
  - id: dup-id
  - id: dup-id
'@

New-Item -ItemType Directory -Path (Join-Path $Work 'sdd') -Force | Out-Null
$RegistryValid = Join-Path $Work 'sdd/approver-registry.yaml'
Set-Content -LiteralPath $RegistryValid -NoNewline -Encoding utf8 -Value @'
schema: sdd-approver-registry/v1
approvers:
  - id: alice
    name: Alice Example
  - id: bob
    name: Bob Example
'@

$RegistryEmpty = Join-Path $Work 'registry-empty.yaml'
Set-Content -LiteralPath $RegistryEmpty -NoNewline -Encoding utf8 -Value @'
schema: sdd-approver-registry/v1
approvers: []
'@

$RegistryDup = Join-Path $Work 'registry-dup.yaml'
Set-Content -LiteralPath $RegistryDup -NoNewline -Encoding utf8 -Value @'
schema: sdd-approver-registry/v1
approvers:
  - id: dup-approver
    name: First
  - id: dup-approver
    name: Second
'@

$RegistryMalformed = Join-Path $Work 'registry-malformed.yaml'
Set-Content -LiteralPath $RegistryMalformed -NoNewline -Encoding utf8 -Value @'
schema: sdd-approver-registry/v1
approvers: not-an-array
'@

try {

# ---------------------------------------------------------------------------
# TEST-015: positive proof -- AC-015.
# ---------------------------------------------------------------------------

$T015Tpl = Join-Path $Work 't015_tpl.json'
New-Template -OutPath $T015Tpl -Approver 'alice' -SecondJson 'null' -EffectiveJson 'null' -PredecessorJson 'null' -VerdictJson '"weakening_verdict": null' -Epoch 1
$T015Sidecar = Join-Path $Work 't015_sidecar.json'
New-SignedFixture -ContentPath $ContentValid -KeyFile $KeyFile -TemplatePath $T015Tpl -OutputPath $T015Sidecar

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--content', $ContentValid, '--sidecar', $T015Sidecar, '--approver-registry', $RegistryValid) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 0 -and (Get-OutText $r) -match 'VALID') {
  Test-Pass 'TEST-015 positive fixture (correct hash/HMAC/registered approver/null effective_at) validates PASS'
} else {
  Test-Fail 'TEST-015 positive fixture validates PASS' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

$T015bTpl = Join-Path $Work 't015b_tpl.json'
New-Template -OutPath $T015bTpl -Approver 'alice' -SecondJson '{"status": "Approved", "approver": "bob", "approved_at": "2026-01-01T00:05:00Z"}' -EffectiveJson '"2020-01-01T00:00:00Z"' -PredecessorJson 'null' -VerdictJson '"weakening_verdict": null' -Epoch 1
$T015bSidecar = Join-Path $Work 't015b_sidecar.json'
New-SignedFixture -ContentPath $ContentValid -KeyFile $KeyFile -TemplatePath $T015bTpl -OutputPath $T015bSidecar

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--content', $ContentValid, '--sidecar', $T015bSidecar, '--approver-registry', $RegistryValid) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 0) {
  Test-Pass 'TEST-015 positive fixture (two distinct registered approvers, elapsed effective_at) validates PASS'
} else {
  Test-Fail 'TEST-015 positive fixture (two distinct approvers) validates PASS' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

# ---------------------------------------------------------------------------
# TEST-014: six independent rejection fixtures -- AC-014.
# ---------------------------------------------------------------------------

# (1) content-schema violation (duplicate components[].id).
$T014aTpl = Join-Path $Work 't014a_tpl.json'
New-Template -OutPath $T014aTpl -Approver 'alice' -SecondJson 'null' -EffectiveJson 'null' -PredecessorJson 'null' -VerdictJson '"weakening_verdict": null' -Epoch 1
$T014aSidecar = Join-Path $Work 't014a_sidecar.json'
New-SignedFixture -ContentPath $ContentDupComponent -KeyFile $KeyFile -TemplatePath $T014aTpl -OutputPath $T014aSidecar

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--content', $ContentDupComponent, '--sidecar', $T014aSidecar, '--approver-registry', $RegistryValid) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 33 -and (Get-ErrText $r) -match 'DUPLICATE_COMPONENT_ID') {
  Test-Pass 'TEST-014 (1) content-schema violation (duplicate components[].id) rejected (DUPLICATE_COMPONENT_ID)'
} else {
  Test-Fail 'TEST-014 (1) content-schema violation rejected' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

# (2) hash mismatch.
$T014bTpl = Join-Path $Work 't014b_tpl.json'
New-Template -OutPath $T014bTpl -Approver 'alice' -SecondJson 'null' -EffectiveJson 'null' -PredecessorJson 'null' -VerdictJson '"weakening_verdict": null' -Epoch 1
$T014bSidecar = Join-Path $Work 't014b_sidecar.json'
New-SignedFixture -ContentPath $ContentOther -KeyFile $KeyFile -TemplatePath $T014bTpl -OutputPath $T014bSidecar

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--content', $ContentValid, '--sidecar', $T014bSidecar, '--approver-registry', $RegistryValid) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 39 -and (Get-ErrText $r) -match 'HASH_MISMATCH') {
  Test-Pass 'TEST-014 (2) hash mismatch rejected (HASH_MISMATCH)'
} else {
  Test-Fail 'TEST-014 (2) hash mismatch rejected' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

# (3) HMAC mismatch (signed under a different key).
$T014cTpl = Join-Path $Work 't014c_tpl.json'
New-Template -OutPath $T014cTpl -Approver 'alice' -SecondJson 'null' -EffectiveJson 'null' -PredecessorJson 'null' -VerdictJson '"weakening_verdict": null' -Epoch 1
$T014cSidecar = Join-Path $Work 't014c_sidecar.json'
$WrongKeyFile = Join-Path $Work 'wrong-key'
Set-Content -LiteralPath $WrongKeyFile -NoNewline -Encoding utf8 -Value 'a-different-key-entirely'
New-SignedFixture -ContentPath $ContentValid -KeyFile $WrongKeyFile -TemplatePath $T014cTpl -OutputPath $T014cSidecar

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--content', $ContentValid, '--sidecar', $T014cSidecar, '--approver-registry', $RegistryValid) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 40 -and (Get-ErrText $r) -match 'HMAC_MISMATCH') {
  Test-Pass 'TEST-014 (3) HMAC mismatch (context_sha256 matches; hmac signed under a different key) rejected (HMAC_MISMATCH)'
} else {
  Test-Fail 'TEST-014 (3) HMAC mismatch rejected' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

# (4) unregistered approver.
$T014dTpl = Join-Path $Work 't014d_tpl.json'
New-Template -OutPath $T014dTpl -Approver 'mallory' -SecondJson 'null' -EffectiveJson 'null' -PredecessorJson 'null' -VerdictJson '"weakening_verdict": null' -Epoch 1
$T014dSidecar = Join-Path $Work 't014d_sidecar.json'
New-SignedFixture -ContentPath $ContentValid -KeyFile $KeyFile -TemplatePath $T014dTpl -OutputPath $T014dSidecar

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--content', $ContentValid, '--sidecar', $T014dSidecar, '--approver-registry', $RegistryValid) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 41 -and (Get-ErrText $r) -match 'UNREGISTERED_APPROVER') {
  Test-Pass 'TEST-014 (4) unregistered approver id rejected (UNREGISTERED_APPROVER)'
} else {
  Test-Fail 'TEST-014 (4) unregistered approver id rejected' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

# (5) duplicate approver identity (hand-signed; T-003 itself refuses to
# PRODUCE this shape).
$T014eTpl = Join-Path $Work 't014e_tpl.json'
New-Template -OutPath $T014eTpl -Approver 'alice' -SecondJson '{"status": "Approved", "approver": "alice", "approved_at": "2026-01-01T00:05:00Z"}' -EffectiveJson 'null' -PredecessorJson 'null' -VerdictJson '"weakening_verdict": null' -Epoch 1
$T014eSidecar = Join-Path $Work 't014e_sidecar.json'
New-SignedFixture -ContentPath $ContentValid -KeyFile $KeyFile -TemplatePath $T014eTpl -OutputPath $T014eSidecar

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--content', $ContentValid, '--sidecar', $T014eSidecar, '--approver-registry', $RegistryValid) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 10 -and (Get-ErrText $r) -match 'DUPLICATE_APPROVER_IDENTITY') {
  Test-Pass 'TEST-014 (5) duplicate approver identity (primary == second) rejected (DUPLICATE_APPROVER_IDENTITY)'
} else {
  Test-Fail 'TEST-014 (5) duplicate approver identity rejected' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

# (6) future effective_at.
$T014fTpl = Join-Path $Work 't014f_tpl.json'
New-Template -OutPath $T014fTpl -Approver 'alice' -SecondJson 'null' -EffectiveJson '"2099-01-01T00:00:00Z"' -PredecessorJson 'null' -VerdictJson '"weakening_verdict": null' -Epoch 1
$T014fSidecar = Join-Path $Work 't014f_sidecar.json'
New-SignedFixture -ContentPath $ContentValid -KeyFile $KeyFile -TemplatePath $T014fTpl -OutputPath $T014fSidecar

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--content', $ContentValid, '--sidecar', $T014fSidecar, '--approver-registry', $RegistryValid) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 42 -and (Get-ErrText $r) -match 'EFFECTIVE_AT_NOT_YET_REACHED') {
  Test-Pass 'TEST-014 (6) future effective_at rejected (EFFECTIVE_AT_NOT_YET_REACHED)'
} else {
  Test-Fail 'TEST-014 (6) future effective_at rejected' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

# ---------------------------------------------------------------------------
# TEST-020: cooldown enforcement (generation + validation) -- AC-020.
# ---------------------------------------------------------------------------

$NoSuchLive = Join-Path $Work 'no-such-live-sidecar.json'
$StageT020Future = Join-Path $Work 'stage-t020-future'
Push-Location $Work
try {
  $r = Invoke-Gen -ArgList @('--schema', 'sdd-project-context-approval/v1', '--content', $ContentValid, '--approver', 'alice', '--status', 'Approved', '--effective-at', '2099-06-01T00:00:00Z', '--live-sidecar', $NoSuchLive, '--stage-dir', $StageT020Future) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey }
} finally { Pop-Location }
$T020Future = Join-Path $StageT020Future 'project-context.approval.json'

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--content', $ContentValid, '--sidecar', $T020Future, '--approver-registry', $RegistryValid) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 42 -and (Get-ErrText $r) -match 'EFFECTIVE_AT_NOT_YET_REACHED') {
  Test-Pass 'TEST-020 validator rejects applying a cooldown sidecar before its effective_at'
} else {
  Test-Fail 'TEST-020 validator rejects a cooldown sidecar before effective_at' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

$StageT020Past = Join-Path $Work 'stage-t020-past'
Push-Location $Work
try {
  $r = Invoke-Gen -ArgList @('--schema', 'sdd-project-context-approval/v1', '--content', $ContentValid, '--approver', 'alice', '--status', 'Approved', '--effective-at', '2020-01-01T00:00:00Z', '--live-sidecar', $NoSuchLive, '--stage-dir', $StageT020Past) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey }
} finally { Pop-Location }
$T020Past = Join-Path $StageT020Past 'project-context.approval.json'

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--content', $ContentValid, '--sidecar', $T020Past, '--approver-registry', $RegistryValid) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 0) {
  Test-Pass 'TEST-020 validator accepts applying a cooldown sidecar after its effective_at has elapsed'
} else {
  Test-Fail 'TEST-020 validator accepts a cooldown sidecar after effective_at' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

# ---------------------------------------------------------------------------
# TEST-019: two-person enforcement, incl. same-identity refusal -- AC-019.
# See tests/validate-approval-sidecar.tests.sh's own "TEST-019 discharge
# note" header comment for the full rationale.
# ---------------------------------------------------------------------------

$T019 = Join-Path $Work 't019'
New-Item -ItemType Directory -Path (Join-Path $T019 'sdd/.approved-context') -Force | Out-Null
Copy-Item -LiteralPath $ContentValid -Destination (Join-Path $T019 'baseline.yaml')
Copy-Item -LiteralPath $ContentOther -Destination (Join-Path $T019 'candidate.yaml')
Copy-Item -LiteralPath (Join-Path $T019 'baseline.yaml') -Destination (Join-Path $T019 'sdd/.approved-context/project-context.approved.yaml')
Copy-Item -LiteralPath $RegistryValid -Destination (Join-Path $T019 'sdd/approver-registry.yaml')
Set-Content -LiteralPath (Join-Path $T019 'live-sidecar.json') -NoNewline -Encoding utf8 -Value '{"schema": "sdd-project-context-approval/v1", "context_sha256": "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", "approval_epoch": 1}'

Push-Location $T019
try {
  $r = Invoke-Gen -ArgList @('--schema', 'sdd-project-context-approval/v1', '--content', 'candidate.yaml', '--approver', 'alice', '--status', 'Approved', '--live-sidecar', 'live-sidecar.json', '--stage-dir', 'stage-solo') -EnvSet @{ SDD_CONTEXT_KEY = $TestKey }
} finally { Pop-Location }
if ($r.ExitCode -eq 0) {
  Test-Pass 'TEST-019 (a) [discharge note] generate-approval-sidecar.py currently SIGNS a solo-approved two-person-required transition (documented T-003 gap, not this task''s to fix)'
} else {
  Test-Fail 'TEST-019 (a) [discharge note] generator''s documented current behavior (sign, exit 0) changed unexpectedly' "exit $($r.ExitCode); $(Get-ErrText $r)"
}
$T019Solo = Join-Path $T019 'stage-solo/project-context.approval.json'
$SoloCheck = Join-Path $Work 'solo_check.py'
Set-Content -LiteralPath $SoloCheck -NoNewline -Encoding utf8 -Value @'
import json, sys
d = json.load(open(sys.argv[1]))
assert d["weakening_verdict"]["two_person_required"] is True
assert d["weakening_verdict"]["policy_weakening"] is True
assert d["second_approval"] is None
'@
$rc = Invoke-Py -ArgList @($SoloCheck, $T019Solo)
if ((Test-Path -LiteralPath $T019Solo) -and $rc.ExitCode -eq 0) {
  Test-Pass 'TEST-019 (a) the signed solo sidecar carries a two_person_required:true verdict with second_approval: null (the exact underapproved shape)'
} else {
  Test-Fail 'TEST-019 (a) signed solo sidecar carries the expected underapproved shape' (Get-ErrText $rc)
}

Push-Location $T019
try { $r = Invoke-Val -ArgList @('--content', 'candidate.yaml', '--sidecar', 'stage-solo/project-context.approval.json', '--approver-registry', 'sdd/approver-registry.yaml') -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 43 -and (Get-ErrText $r) -match 'WEAKENING_PROVENANCE_UNDERAPPROVED') {
  Test-Pass 'TEST-019 (a) validate-approval-sidecar.py REJECTS the solo-approved two-person-required sidecar (WEAKENING_PROVENANCE_UNDERAPPROVED) -- the canonical enforcement point (obligation 4b)'
} else {
  Test-Fail 'TEST-019 (a) validator rejects the solo-approved two-person-required sidecar' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

Push-Location $T019
try {
  $r = Invoke-Gen -ArgList @('--schema', 'sdd-project-context-approval/v1', '--content', 'candidate.yaml', '--approver', 'alice', '--second-approver', 'bob', '--status', 'Approved', '--live-sidecar', 'live-sidecar.json', '--stage-dir', 'stage-two') -EnvSet @{ SDD_CONTEXT_KEY = $TestKey }
} finally { Pop-Location }
if ($r.ExitCode -eq 0) {
  Test-Pass 'TEST-019 (b) generate-approval-sidecar.py signs successfully with two DISTINCT registered approver ids'
} else {
  Test-Fail 'TEST-019 (b) generator signs with two distinct approvers' "exit $($r.ExitCode); $(Get-ErrText $r)"
}
Push-Location $T019
try { $r = Invoke-Val -ArgList @('--content', 'candidate.yaml', '--sidecar', 'stage-two/project-context.approval.json', '--approver-registry', 'sdd/approver-registry.yaml') -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 0) {
  Test-Pass 'TEST-019 (b) validate-approval-sidecar.py accepts the two-distinct-approver sidecar'
} else {
  Test-Fail 'TEST-019 (b) validator accepts the two-distinct-approver sidecar' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

Push-Location $T019
try {
  $r = Invoke-Gen -ArgList @('--schema', 'sdd-project-context-approval/v1', '--content', 'candidate.yaml', '--approver', 'alice', '--second-approver', 'alice', '--status', 'Approved', '--live-sidecar', 'live-sidecar.json', '--stage-dir', 'stage-dup') -EnvSet @{ SDD_CONTEXT_KEY = $TestKey }
} finally { Pop-Location }
if ($r.ExitCode -eq 10 -and (Get-ErrText $r) -match 'DUPLICATE_APPROVER_IDENTITY') {
  Test-Pass 'TEST-019 (c) generate-approval-sidecar.py refuses to sign when second_approval.approver == primary_approval.approver (DUPLICATE_APPROVER_IDENTITY)'
} else {
  Test-Fail 'TEST-019 (c) generator refuses same-identity signing' "exit $($r.ExitCode); $(Get-ErrText $r)"
}
if (Test-Path -LiteralPath (Join-Path $T019 'stage-dup')) {
  Test-Fail 'TEST-019 (c) same-identity refusal writes NO staged artifact'
} else {
  Test-Pass 'TEST-019 (c) same-identity refusal writes NO staged artifact'
}

# ---------------------------------------------------------------------------
# TEST-046: zero-identity structural fail-closed-validating consequence
# (structural half) -- AC-046.
# ---------------------------------------------------------------------------

$T046Tpl = Join-Path $Work 't046_tpl.json'
New-Template -OutPath $T046Tpl -Approver 'alice' -SecondJson 'null' -EffectiveJson 'null' -PredecessorJson 'null' -VerdictJson '"weakening_verdict": null' -Epoch 1
$T046Sidecar = Join-Path $Work 't046_sidecar.json'
New-SignedFixture -ContentPath $ContentValid -KeyFile $KeyFile -TemplatePath $T046Tpl -OutputPath $T046Sidecar

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--content', $ContentValid, '--sidecar', $T046Sidecar, '--approver-registry', $RegistryEmpty) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 41 -and (Get-ErrText $r) -match 'UNREGISTERED_APPROVER') {
  Test-Pass 'TEST-046 validate-approval-sidecar.py refuses to validate against a zero-entry approvers:[] registry (no id can ever resolve, UNREGISTERED_APPROVER)'
} else {
  Test-Fail 'TEST-046 validator refuses to validate against a zero-entry registry' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

# ---------------------------------------------------------------------------
# AC-045 PRODUCTION discharge.
# ---------------------------------------------------------------------------

$T045Tpl = Join-Path $Work 't045_tpl.json'
New-Template -OutPath $T045Tpl -Approver 'dup-approver' -SecondJson 'null' -EffectiveJson 'null' -PredecessorJson 'null' -VerdictJson '"weakening_verdict": null' -Epoch 1
$T045Sidecar = Join-Path $Work 't045_sidecar.json'
New-SignedFixture -ContentPath $ContentValid -KeyFile $KeyFile -TemplatePath $T045Tpl -OutputPath $T045Sidecar

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--content', $ContentValid, '--sidecar', $T045Sidecar, '--approver-registry', $RegistryDup) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 36 -and (Get-ErrText $r) -match 'DUPLICATE_APPROVER_REGISTRY_ID') {
  Test-Pass 'AC-045 PRODUCTION discharge: validate-approval-sidecar.py rejects a duplicate-id approver-registry.yaml (DUPLICATE_APPROVER_REGISTRY_ID)'
} else {
  Test-Fail 'AC-045 PRODUCTION discharge: rejects duplicate-id registry' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

# ---------------------------------------------------------------------------
# OBLIGATION 2: non-bootstrap null-verdict rejected.
# ---------------------------------------------------------------------------

$TObl2Tpl = Join-Path $Work 't_obl2_tpl.json'
New-Template -OutPath $TObl2Tpl -Approver 'alice' -SecondJson 'null' -EffectiveJson 'null' -PredecessorJson '"sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"' -VerdictJson '"weakening_verdict": null' -Epoch 2
$TObl2Sidecar = Join-Path $Work 't_obl2_sidecar.json'
New-SignedFixture -ContentPath $ContentValid -KeyFile $KeyFile -TemplatePath $TObl2Tpl -OutputPath $TObl2Sidecar

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--content', $ContentValid, '--sidecar', $TObl2Sidecar, '--approver-registry', $RegistryValid) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 46 -and (Get-ErrText $r) -match 'WEAKENING_VERDICT_MISSING') {
  Test-Pass 'OBLIGATION 2 a non-bootstrap sidecar (predecessor_context_sha256 present) with weakening_verdict: null is rejected (WEAKENING_VERDICT_MISSING)'
} else {
  Test-Fail 'OBLIGATION 2 non-bootstrap null-verdict rejected' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--verify-provenance', '--sidecar', $TObl2Sidecar) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 46 -and (Get-ErrText $r) -match 'WEAKENING_VERDICT_MISSING') {
  Test-Pass 'OBLIGATION 2 --verify-provenance also rejects a non-bootstrap null-verdict sidecar (WEAKENING_VERDICT_MISSING)'
} else {
  Test-Fail 'OBLIGATION 2 --verify-provenance rejects non-bootstrap null-verdict' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

# ---------------------------------------------------------------------------
# TEST-043: post-publish provenance re-provability + underapproval
# rejection via --verify-provenance -- AC-043.
# ---------------------------------------------------------------------------

$T043 = Join-Path $Work 't043'
New-Item -ItemType Directory -Path (Join-Path $T043 'sdd/.approved-context') -Force | Out-Null
Copy-Item -LiteralPath $ContentValid -Destination (Join-Path $T043 'baseline.yaml')
Copy-Item -LiteralPath $ContentOther -Destination (Join-Path $T043 'candidate.yaml')
Copy-Item -LiteralPath (Join-Path $T043 'baseline.yaml') -Destination (Join-Path $T043 'sdd/.approved-context/project-context.approved.yaml')
Copy-Item -LiteralPath $RegistryValid -Destination (Join-Path $T043 'sdd/approver-registry.yaml')
Set-Content -LiteralPath (Join-Path $T043 'live-sidecar.json') -NoNewline -Encoding utf8 -Value '{"schema": "sdd-project-context-approval/v1", "context_sha256": "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", "approval_epoch": 1}'

Push-Location $T043
try {
  $r = Invoke-Gen -ArgList @('--schema', 'sdd-project-context-approval/v1', '--content', 'candidate.yaml', '--approver', 'alice', '--second-approver', 'bob', '--status', 'Approved', '--live-sidecar', 'live-sidecar.json', '--stage-dir', 'stage-approved') -EnvSet @{ SDD_CONTEXT_KEY = $TestKey }
} finally { Pop-Location }
$T043Approved = Join-Path $T043 'stage-approved/project-context.approval.json'

Push-Location $T043
try {
  $r = Invoke-Gen -ArgList @('--schema', 'sdd-project-context-approval/v1', '--content', 'candidate.yaml', '--approver', 'alice', '--status', 'Approved', '--live-sidecar', 'live-sidecar.json', '--stage-dir', 'stage-solo') -EnvSet @{ SDD_CONTEXT_KEY = $TestKey }
} finally { Pop-Location }
$T043Solo = Join-Path $T043 'stage-solo/project-context.approval.json'

$T043Post = Join-Path $Work 't043-postpublish'
New-Item -ItemType Directory -Path $T043Post -Force | Out-Null
Copy-Item -LiteralPath $T043Approved -Destination (Join-Path $T043Post 'approved.json')
Copy-Item -LiteralPath $T043Solo -Destination (Join-Path $T043Post 'solo.json')

Push-Location $T043Post
try { $r = Invoke-Val -ArgList @('--verify-provenance', '--sidecar', 'approved.json') -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 0) {
  Test-Pass 'TEST-043 --verify-provenance PASSES a correctly-two-person-approved weakening sidecar after its predecessor anchor is gone'
} else {
  Test-Fail 'TEST-043 --verify-provenance passes a correctly-approved sidecar post-publish' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

Push-Location $T043Post
try { $r = Invoke-Val -ArgList @('--verify-provenance', '--sidecar', 'solo.json') -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 43 -and (Get-ErrText $r) -match 'WEAKENING_PROVENANCE_UNDERAPPROVED') {
  Test-Pass 'TEST-043 --verify-provenance FAILS an underapproved (solo) weakening sidecar after its predecessor anchor is gone (WEAKENING_PROVENANCE_UNDERAPPROVED)'
} else {
  Test-Fail 'TEST-043 --verify-provenance fails an underapproved sidecar post-publish' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

$T043BootstrapTpl = Join-Path $Work 't043_bootstrap_tpl.json'
New-Template -OutPath $T043BootstrapTpl -Approver 'alice' -SecondJson 'null' -EffectiveJson 'null' -PredecessorJson 'null' -VerdictJson '"weakening_verdict": null' -Epoch 1
$T043Bootstrap = Join-Path $Work 't043_bootstrap_sidecar.json'
New-SignedFixture -ContentPath $ContentValid -KeyFile $KeyFile -TemplatePath $T043BootstrapTpl -OutputPath $T043Bootstrap

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--verify-provenance', '--sidecar', $T043Bootstrap) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 0) {
  Test-Pass 'TEST-043 --verify-provenance PASSES the bootstrap case (approval_epoch:1, weakening_verdict: null) with no second-approval requirement implied'
} else {
  Test-Fail 'TEST-043 --verify-provenance passes the bootstrap case' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

$T043InProgress = Join-Path $Work 't043-inprogress'
New-Item -ItemType Directory -Path (Join-Path $T043InProgress 'sdd/.staging/some-nonce') -Force | Out-Null
Copy-Item -LiteralPath $T043Approved -Destination (Join-Path $T043InProgress 'sidecar.json')
Set-Content -LiteralPath (Join-Path $T043InProgress 'sdd/.staging/some-nonce/TRANSACTION.json') -NoNewline -Encoding utf8 -Value @'
{
  "nonce": "some-nonce",
  "status": "in-progress",
  "targets": [
    {"live_path": "sidecar.json", "pre_hash": "ABSENT", "post_hash": "deadbeef"}
  ]
}
'@
Push-Location $T043InProgress
try { $r = Invoke-Val -ArgList @('--verify-provenance', '--sidecar', 'sidecar.json') -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 21 -and (Get-ErrText $r) -match 'HUMAN_COPY_PUBLISH_IN_PROGRESS') {
  Test-Pass 'TEST-043 a live TRANSACTION.json naming the sidecar path fails closed (HUMAN_COPY_PUBLISH_IN_PROGRESS)'
} else {
  Test-Fail 'TEST-043 a live TRANSACTION.json naming the sidecar path fails closed' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

$T043InProgress2 = Join-Path $Work 't043-inprogress2'
New-Item -ItemType Directory -Path (Join-Path $T043InProgress2 'sdd/.staging/some-nonce') -Force | Out-Null
Copy-Item -LiteralPath $ContentValid -Destination (Join-Path $T043InProgress2 'project-context.yaml')
Copy-Item -LiteralPath $RegistryValid -Destination (Join-Path $T043InProgress2 'registry.yaml')
Copy-Item -LiteralPath $T015Sidecar -Destination (Join-Path $T043InProgress2 'sidecar.json')
Set-Content -LiteralPath (Join-Path $T043InProgress2 'sdd/.staging/some-nonce/TRANSACTION.json') -NoNewline -Encoding utf8 -Value @'
{
  "nonce": "some-nonce",
  "status": "in-progress",
  "targets": [
    {"live_path": "project-context.yaml", "pre_hash": "ABSENT", "post_hash": "deadbeef"}
  ]
}
'@
Push-Location $T043InProgress2
try { $r = Invoke-Val -ArgList @('--content', 'project-context.yaml', '--sidecar', 'sidecar.json', '--approver-registry', 'registry.yaml') -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 21 -and (Get-ErrText $r) -match 'HUMAN_COPY_PUBLISH_IN_PROGRESS') {
  Test-Pass 'TEST-043 standard validation path: a live TRANSACTION.json naming the content path fails closed (HUMAN_COPY_PUBLISH_IN_PROGRESS)'
} else {
  Test-Fail 'TEST-043 standard validation path fails closed on a live journal naming --content' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

# ---------------------------------------------------------------------------
# SEQ0355 REMEDY (quality-gate seq0355 Major finding): gate (5)'s
# `second_id == primary_id` clause (validate-approval-sidecar.py:678) was
# UNREACHABLE-in-coverage on the standard path (gate (3)'s
# DUPLICATE_APPROVER_IDENTITY always intercepts a same-identity sidecar
# first) and had NO assertion at all under --verify-provenance. See
# tests/validate-approval-sidecar.tests.sh's own "SEQ0355 REMEDY" comment
# for the full rationale. This fixture pins BOTH halves: (a)
# --verify-provenance rejects on the duplicate-identity clause
# specifically; (b) the standard path is pinned to STILL exit via gate (3)
# first for this SAME fixture, never reaching gate (5).
# ---------------------------------------------------------------------------

$VerdictTwoPersonRequired = '"weakening_verdict": {
    "policy_weakening": true,
    "categories": {
      "capability_enforcement_weakened": "weakened",
      "capability_removed": "n/a",
      "component_path_narrowed": "not_weakened",
      "public_distribution_descoped": "n/a",
      "criticality_lowered": "n/a",
      "provider_allowlist_widened": "n/a",
      "production_write_path_changed": "n/a",
      "required_gate_removed": "n/a",
      "spec_profile_full_to_lite": "not_weakened"
    },
    "two_person_required": true,
    "cooldown_hours": null
  }'

$TDupidVerdictTpl = Join-Path $Work 't_dupid_verdict_tpl.json'
New-Template -OutPath $TDupidVerdictTpl -Approver 'alice' -SecondJson '{"status": "Approved", "approver": "alice", "approved_at": "2026-01-01T00:05:00Z"}' -EffectiveJson 'null' -PredecessorJson 'null' -VerdictJson $VerdictTwoPersonRequired -Epoch 1
$TDupidVerdictSidecar = Join-Path $Work 't_dupid_verdict_sidecar.json'
New-SignedFixture -ContentPath $ContentValid -KeyFile $KeyFile -TemplatePath $TDupidVerdictTpl -OutputPath $TDupidVerdictSidecar

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--verify-provenance', '--sidecar', $TDupidVerdictSidecar) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 43 -and (Get-ErrText $r) -match 'WEAKENING_PROVENANCE_UNDERAPPROVED') {
  Test-Pass 'SEQ0355 REMEDY (a) --verify-provenance rejects a two-person-required sidecar whose second_approval.approver duplicates primary_approval.approver (WEAKENING_PROVENANCE_UNDERAPPROVED, gate 5''s duplicate clause)'
} else {
  Test-Fail 'SEQ0355 REMEDY (a) --verify-provenance rejects duplicate-identity two-person-required sidecar' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--content', $ContentValid, '--sidecar', $TDupidVerdictSidecar, '--approver-registry', $RegistryValid) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 10 -and (Get-ErrText $r) -match 'DUPLICATE_APPROVER_IDENTITY') {
  Test-Pass 'SEQ0355 REMEDY (b) the SAME fixture on the standard path is intercepted by gate 3 (DUPLICATE_APPROVER_IDENTITY), never reaching gate 5 -- the two-path split is pinned'
} else {
  Test-Fail 'SEQ0355 REMEDY (b) standard path intercepted by gate 3 for the same fixture' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

# ---------------------------------------------------------------------------
# APPROVER_REGISTRY_SCHEMA_VIOLATION.
# ---------------------------------------------------------------------------

$TMalregTpl = Join-Path $Work 't_malreg_tpl.json'
New-Template -OutPath $TMalregTpl -Approver 'alice' -SecondJson 'null' -EffectiveJson 'null' -PredecessorJson 'null' -VerdictJson '"weakening_verdict": null' -Epoch 1
$TMalregSidecar = Join-Path $Work 't_malreg_sidecar.json'
New-SignedFixture -ContentPath $ContentValid -KeyFile $KeyFile -TemplatePath $TMalregTpl -OutputPath $TMalregSidecar

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--content', $ContentValid, '--sidecar', $TMalregSidecar, '--approver-registry', $RegistryMalformed) -EnvSet @{ SDD_CONTEXT_KEY = $TestKey } } finally { Pop-Location }
if ($r.ExitCode -eq 35 -and (Get-ErrText $r) -match 'APPROVER_REGISTRY_SCHEMA_VIOLATION') {
  Test-Pass 'TEST-HARDEN a malformed (non-array approvers) registry is rejected (APPROVER_REGISTRY_SCHEMA_VIOLATION)'
} else {
  Test-Fail 'TEST-HARDEN malformed registry rejected' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

# ---------------------------------------------------------------------------
# TEST-HARDEN: no resolvable SDD_CONTEXT_KEY.
# ---------------------------------------------------------------------------

$FakeHomeNoKey = Join-Path $Work 'fake-home-nokey'
New-Item -ItemType Directory -Path $FakeHomeNoKey -Force | Out-Null
Push-Location $Work
try {
  $r = Invoke-Val -ArgList @('--content', $ContentValid, '--sidecar', $T015Sidecar, '--approver-registry', $RegistryValid) -EnvSet @{ HOME = $FakeHomeNoKey } -EnvUnset @('SDD_CONTEXT_KEY', 'SDD_CONTEXT_KEY_FILE')
} finally { Pop-Location }
if ($r.ExitCode -eq 11 -and (Get-ErrText $r) -match 'NO_CONTEXT_KEY') {
  Test-Pass 'TEST-HARDEN no resolvable SDD_CONTEXT_KEY: exit 11/NO_CONTEXT_KEY, never a skip'
} else {
  Test-Fail 'TEST-HARDEN no resolvable SDD_CONTEXT_KEY' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

# ---------------------------------------------------------------------------
# TEST-HARDEN: usage errors, never a traceback.
# ---------------------------------------------------------------------------

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--sidecar', $T015Sidecar) } finally { Pop-Location }
if ($r.ExitCode -eq 2 -and (Get-ErrText $r) -notmatch 'Traceback') {
  Test-Pass 'TEST-HARDEN missing --content (without --verify-provenance) is a clean usage error, never a traceback'
} else {
  Test-Fail 'TEST-HARDEN missing --content usage error' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

Push-Location $Work
try { $r = Invoke-Val -ArgList @('--content', $ContentValid, '--sidecar', $T015Sidecar, '--verify-provenance') } finally { Pop-Location }
if ($r.ExitCode -eq 2) {
  Test-Pass 'TEST-HARDEN --content combined with --verify-provenance is a clean usage error'
} else {
  Test-Fail 'TEST-HARDEN --content + --verify-provenance usage error' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

$NoSuchSidecar = Join-Path $Work 'no-such-file.json'
Push-Location $Work
try { $r = Invoke-Val -ArgList @('--content', $ContentValid, '--sidecar', $NoSuchSidecar, '--approver-registry', $RegistryValid) } finally { Pop-Location }
if ($r.ExitCode -eq 37 -and (Get-ErrText $r) -match 'SIDECAR_UNREADABLE' -and (Get-ErrText $r) -notmatch 'Traceback') {
  Test-Pass 'TEST-HARDEN a missing --sidecar file is rejected cleanly (SIDECAR_UNREADABLE), never a traceback'
} else {
  Test-Fail 'TEST-HARDEN missing --sidecar file' "exit $($r.ExitCode); $(Get-ErrText $r)"
}

# ---------------------------------------------------------------------------
# OBLIGATION 1: executable key-parity proof (AC-013-style 4-case matrix).
# ---------------------------------------------------------------------------

$Parity = Join-Path $Work 'key_parity.py'
Set-Content -LiteralPath $Parity -NoNewline -Encoding utf8 -Value @'
import importlib.util
import os
import sys

VAL_PATH, GEN_PATH, GUARD_PATH, CASE = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
ARG = sys.argv[5:]


def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


val = _load("_val_approval_sidecar", VAL_PATH)
gen = _load("_gen_approval_sidecar", GEN_PATH)
guard = _load("_sdd_hook_guard", GUARD_PATH)

if CASE == "env":
    os.environ["SDD_CONTEXT_KEY"] = "byte-parity-value"
    os.environ["SDD_SUDO_KEY"] = "byte-parity-value"
elif CASE == "file":
    (path,) = ARG
    os.environ.pop("SDD_CONTEXT_KEY", None)
    os.environ.pop("SDD_SUDO_KEY", None)
    os.environ["SDD_CONTEXT_KEY_FILE"] = path
    os.environ["SDD_SUDO_KEY_FILE"] = path
elif CASE == "home":
    (home,) = ARG
    for var in ("SDD_CONTEXT_KEY", "SDD_SUDO_KEY", "SDD_CONTEXT_KEY_FILE", "SDD_SUDO_KEY_FILE"):
        os.environ.pop(var, None)
    os.environ["HOME"] = home
elif CASE == "none":
    for var in ("SDD_CONTEXT_KEY", "SDD_SUDO_KEY", "SDD_CONTEXT_KEY_FILE", "SDD_SUDO_KEY_FILE"):
        os.environ.pop(var, None)
    os.environ["HOME"] = ARG[0]
else:
    raise SystemExit("unknown case")

a = val.resolve_context_key()
b = gen.resolve_context_key()
c = guard._resolve_sudo_key()

if a == b == c:
    sys.exit(0)
sys.stderr.write("MISMATCH: validator=%r generator=%r guard=%r\n" % (a, b, c))
sys.exit(1)
'@

$r = Invoke-Py -ArgList @($Parity, $ValPy, $GenPy, $HookGuardPy, 'env')
if ($r.ExitCode -eq 0) {
  Test-Pass 'OBLIGATION 1 (TEST-013-style) case 1/4 (env var): validate-approval-sidecar.py''s resolve_context_key() matches generate-approval-sidecar.py''s AND sdd-hook-guard.py''s _resolve_sudo_key byte-for-byte'
} else {
  Test-Fail 'OBLIGATION 1 case 1/4 (env var) key-resolution byte-parity' (Get-ErrText $r)
}

$T013KeyFile = Join-Path $Work 't013_keyfile'
[System.IO.File]::WriteAllBytes($T013KeyFile, [byte[]](0xEF, 0xBB, 0xBF) + [System.Text.Encoding]::UTF8.GetBytes("  byte-parity-file-value  `r`n"))
$r = Invoke-Py -ArgList @($Parity, $ValPy, $GenPy, $HookGuardPy, 'file', $T013KeyFile)
if ($r.ExitCode -eq 0) {
  Test-Pass 'OBLIGATION 1 (TEST-013-style) case 2/4 (env-file, BOM+whitespace-stripped): identical key bytes across all three resolvers'
} else {
  Test-Fail 'OBLIGATION 1 case 2/4 (env-file) key-resolution byte-parity' (Get-ErrText $r)
}

$FakeHomeParity = Join-Path $Work 'fake-home-parity'
New-Item -ItemType Directory -Path (Join-Path $FakeHomeParity '.sdd') -Force | Out-Null
$homeKeyBytes = [byte[]](0xEF, 0xBB, 0xBF) + [System.Text.Encoding]::UTF8.GetBytes("  byte-parity-home-value  `r`n")
[System.IO.File]::WriteAllBytes((Join-Path $FakeHomeParity '.sdd/context-key'), $homeKeyBytes)
[System.IO.File]::WriteAllBytes((Join-Path $FakeHomeParity '.sdd/sudo-key'), $homeKeyBytes)
$r = Invoke-Py -ArgList @($Parity, $ValPy, $GenPy, $HookGuardPy, 'home', $FakeHomeParity)
if ($r.ExitCode -eq 0) {
  Test-Pass 'OBLIGATION 1 (TEST-013-style) case 3/4 (home-path, BOM+whitespace-stripped): identical key bytes across all three resolvers'
} else {
  Test-Fail 'OBLIGATION 1 case 3/4 (home-path) key-resolution byte-parity' (Get-ErrText $r)
}

$FakeHomeEmpty = Join-Path $Work 'fake-home-parity-empty'
New-Item -ItemType Directory -Path $FakeHomeEmpty -Force | Out-Null
$r = Invoke-Py -ArgList @($Parity, $ValPy, $GenPy, $HookGuardPy, 'none', $FakeHomeEmpty)
if ($r.ExitCode -eq 0) {
  Test-Pass 'OBLIGATION 1 (TEST-013-style) case 4/4 (none resolvable): all three resolvers return None'
} else {
  Test-Fail 'OBLIGATION 1 case 4/4 (none resolvable) key-resolution byte-parity' (Get-ErrText $r)
}

# ---------------------------------------------------------------------------
# Self-registration.
# ---------------------------------------------------------------------------

$RunAllSh = Get-Content -Raw -LiteralPath (Join-Path $Root 'tests/run-all.sh')
if ($RunAllSh -match 'validate-approval-sidecar\.tests\.sh') {
  Test-Pass 'self-registration: tests/validate-approval-sidecar.tests.sh registered in tests/run-all.sh'
} else {
  Test-Fail 'self-registration: tests/validate-approval-sidecar.tests.sh registered in tests/run-all.sh'
}
$RunAllPs1 = Get-Content -Raw -LiteralPath (Join-Path $Root 'tests/run-all.ps1')
if ($RunAllPs1 -match 'validate-approval-sidecar\.tests\.ps1') {
  Test-Pass 'self-registration: tests/validate-approval-sidecar.tests.ps1 registered in tests/run-all.ps1'
} else {
  Test-Fail 'self-registration: tests/validate-approval-sidecar.tests.ps1 registered in tests/run-all.ps1'
}

Write-Output "PASS: $script:PassCount"
Write-Output "FAIL: $script:FailCount"
if ($script:FailCount -gt 0) { exit 1 } else { exit 0 }
}
finally {
  Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}
