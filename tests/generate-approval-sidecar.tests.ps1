# T-003 (epic-189-a1-project-context, REQ-004): acceptance checks for
# contracts/approval-sidecar.schema.json and
# plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py and its
# .sh/.ps1 dispatcher wrappers.
#
# PowerShell parity port of tests/generate-approval-sidecar.tests.sh. See
# that file's header for the TEST-010/011/012/013/034/036 <-> AC mapping.
#
# Every invocation below runs the wrapper (or python3/python directly for
# the --dump-preimage test-only hook) as a REAL CHILD PROCESS via
# [System.Diagnostics.Process], never PowerShell's own `&` call operator
# (generate-approval-sidecar.ps1 itself calls `exit $LASTEXITCODE`, which
# would terminate THIS test session if invoked in-process; raw stream
# capture also avoids PowerShell's success-pipeline byte mangling, mirroring
# canonicalize-sdd-yaml.tests.ps1's own rationale).
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Work = Join-Path ([IO.Path]::GetTempPath()) ("gen-approval-sidecar-test-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Work -Force | Out-Null

$GenSh = Join-Path $Root 'plugins/sdd-quality-loop/scripts/generate-approval-sidecar.sh'
$GenPy = Join-Path $Root 'plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py'
$GenPs1 = Join-Path $Root 'plugins/sdd-quality-loop/scripts/generate-approval-sidecar.ps1'
$SchemaJson = Join-Path $Root 'contracts/approval-sidecar.schema.json'
$HookGuardPy = Join-Path $Root 'plugins/sdd-quality-loop/scripts/sdd-hook-guard.py'
$CanonPy = Join-Path $Root 'plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py'
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

function Get-Sha256Hex([string]$Path) {
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
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
  # syncing, which this suite found unreliable across pwsh hosts.
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

function Invoke-Gen {
  param([string[]]$ArgList = @(), [hashtable]$EnvSet = @{}, [string[]]$EnvUnset = @())
  return Invoke-ChildProcess -Exe $PowerShellExe `
    -ArgList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $GenPs1) + $ArgList) `
    -EnvSet $EnvSet -EnvUnset $EnvUnset
}

function Invoke-Py {
  param([string[]]$ArgList = @())
  return Invoke-ChildProcess -Exe $PythonExe -ArgList $ArgList
}

function Get-PyText([string[]]$ArgList) {
  $r = Invoke-Py $ArgList
  $text = Get-Content -Raw -LiteralPath $r.StdoutPath -ErrorAction SilentlyContinue
  if ($null -eq $text) { return '' }
  return $text.TrimEnd("`r", "`n")
}

function Write-ContentFixture([string]$Path) {
  Set-Content -LiteralPath $Path -NoNewline -Encoding utf8 -Value @"
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: lite-three-file
  capability_enforcement: required
"@
}

try {

# ---------------------------------------------------------------------------
# TEST-010: schema conformance (positive + negative: hmac length/case) --
# AC-010. Purpose-built draft-07 subset validator (no jsonschema dependency
# available -- see tests/generate-approval-sidecar.tests.sh for the shared
# rationale). Ported verbatim from that suite's own embedded validator.
# ---------------------------------------------------------------------------

$Validator = Join-Path $Work 'sidecar_validator.py'
Set-Content -LiteralPath $Validator -NoNewline -Encoding utf8 -Value @'
import json
import re
import sys


def _type_ok(t, instance):
    if t == "object":
        return isinstance(instance, dict)
    if t == "string":
        return isinstance(instance, str)
    if t == "integer":
        return isinstance(instance, int) and not isinstance(instance, bool)
    if t == "number":
        return isinstance(instance, (int, float)) and not isinstance(instance, bool)
    if t == "boolean":
        return isinstance(instance, bool)
    if t == "null":
        return instance is None
    return True


def validate(schema, instance, root):
    if "$ref" in schema:
        ref = schema["$ref"]
        if not ref.startswith("#/definitions/"):
            return False
        target = root["definitions"][ref[len("#/definitions/"):]]
        return validate(target, instance, root)

    if "oneOf" in schema:
        matches = 0
        for sub in schema["oneOf"]:
            try:
                if validate(sub, instance, root):
                    matches += 1
            except Exception:
                pass
        return matches == 1

    if "enum" in schema and instance not in schema["enum"]:
        return False
    if "const" in schema and instance != schema["const"]:
        return False
    if "type" in schema and not _type_ok(schema["type"], instance):
        return False
    if "pattern" in schema:
        if not isinstance(instance, str) or not re.match(schema["pattern"], instance):
            return False
    if "minLength" in schema:
        if not isinstance(instance, str) or len(instance) < schema["minLength"]:
            return False
    if "minimum" in schema:
        if not isinstance(instance, (int, float)) or isinstance(instance, bool) or instance < schema["minimum"]:
            return False

    if schema.get("type") == "object":
        if not isinstance(instance, dict):
            return False
        for req in schema.get("required", []):
            if req not in instance:
                return False
        if schema.get("additionalProperties") is False:
            allowed = set(schema.get("properties", {}).keys())
            if not set(instance.keys()) <= allowed:
                return False
        for key, subschema in schema.get("properties", {}).items():
            if key in instance and not validate(subschema, instance[key], root):
                return False

    return True


def main():
    schema_path, instance_path = sys.argv[1], sys.argv[2]
    with open(schema_path, "r", encoding="utf-8") as f:
        schema = json.load(f)
    with open(instance_path, "r", encoding="utf-8") as f:
        instance = json.load(f)
    ok = validate(schema, instance, schema)
    if not ok:
        print("INVALID", file=sys.stderr)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
'@

$T010Positive = Join-Path $Work 't010_positive.json'
Set-Content -LiteralPath $T010Positive -NoNewline -Encoding utf8 -Value @'
{
  "schema": "sdd-project-context-approval/v1",
  "context_sha256": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "primary_approval": {"status": "Approved", "approver": "alice", "approved_at": "2026-01-01T00:00:00Z"},
  "second_approval": {"status": "Approved", "approver": "bob", "approved_at": "2026-01-01T00:05:00Z"},
  "effective_at": "2026-01-02T00:00:00Z",
  "predecessor_context_sha256": null,
  "weakening_verdict": null,
  "approval_epoch": 1,
  "hmac": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}
'@

$r = Invoke-Py @($Validator, $SchemaJson, $T010Positive)
if ($r.ExitCode -eq 0) {
  Test-Pass 'TEST-010 full-field fixture (non-null second_approval/effective_at) validates'
} else {
  Test-Fail 'TEST-010 full-field fixture (non-null second_approval/effective_at) validates'
}

$T010HmacShort = Join-Path $Work 't010_hmac_short.json'
$mutator = Join-Path $Work 'mutate.py'
Set-Content -LiteralPath $mutator -NoNewline -Encoding utf8 -Value @'
import json
import sys

src, out, dotted, value_json = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
d = json.load(open(src, "r", encoding="utf-8"))
node = d
keys = dotted.split(".")
for k in keys[:-1]:
    node = node[k]
node[keys[-1]] = json.loads(value_json)
json.dump(d, open(out, "w", encoding="utf-8"))
'@

Invoke-Py @($mutator, $T010Positive, $T010HmacShort, 'hmac', ('"' + ('a' * 63) + '"')) | Out-Null
$r = Invoke-Py @($Validator, $SchemaJson, $T010HmacShort)
if ($r.ExitCode -ne 0) {
  Test-Pass 'TEST-010 hmac shorter than 64 hex chars is rejected'
} else {
  Test-Fail 'TEST-010 hmac shorter than 64 hex chars is rejected'
}

$T010HmacUpper = Join-Path $Work 't010_hmac_upper.json'
Invoke-Py @($mutator, $T010Positive, $T010HmacUpper, 'hmac', ('"A' + ('a' * 63) + '"')) | Out-Null
$r = Invoke-Py @($Validator, $SchemaJson, $T010HmacUpper)
if ($r.ExitCode -ne 0) {
  Test-Pass 'TEST-010 hmac containing an uppercase character is rejected'
} else {
  Test-Fail 'TEST-010 hmac containing an uppercase character is rejected'
}

# ---------------------------------------------------------------------------
# TEST-011: staged-signing round-trip + fail-closed proof -- AC-011.
# ---------------------------------------------------------------------------

$Content = Join-Path $Work 'project-context.yaml'
Write-ContentFixture $Content
$Stage1 = Join-Path $Work 'stage-t011'
$LiveAbsent = Join-Path $Work 'no-such-sidecar.json'
$KeyFile = Join-Path $Work 'context-key'
Set-Content -LiteralPath $KeyFile -NoNewline -Encoding utf8 -Value 'test-context-key-epic189-t003'

$r = Invoke-Gen -ArgList @(
  '--schema', 'sdd-project-context-approval/v1',
  '--content', $Content,
  '--approver', 'alice',
  '--status', 'Approved',
  '--second-approver', 'bob',
  '--live-sidecar', $LiveAbsent,
  '--stage-dir', $Stage1
) -EnvSet @{ SDD_CONTEXT_KEY_FILE = $KeyFile } -EnvUnset @('SDD_CONTEXT_KEY')
if ($r.ExitCode -eq 0) {
  Test-Pass 'TEST-011 staged signing succeeds (exit 0)'
} else {
  Test-Fail 'TEST-011 staged signing succeeds (exit 0)' (Get-Content -Raw -LiteralPath $r.StderrPath -ErrorAction SilentlyContinue)
}

$SidecarOut = Join-Path $Stage1 'project-context.approval.json'
$SnapshotOut = Join-Path $Stage1 'project-context.approved.yaml'
$ManifestOut = Join-Path $Stage1 'MANIFEST.sha256'
if ((Test-Path -LiteralPath $SidecarOut) -and (Test-Path -LiteralPath $SnapshotOut) -and (Test-Path -LiteralPath $ManifestOut)) {
  Test-Pass 'TEST-011 all three staged artifacts (sidecar, snapshot, manifest) exist'
} else {
  Test-Fail 'TEST-011 all three staged artifacts (sidecar, snapshot, manifest) exist'
}

$contentBytes = [System.IO.File]::ReadAllBytes($Content)
$snapshotBytes = [System.IO.File]::ReadAllBytes($SnapshotOut)
if ([System.Linq.Enumerable]::SequenceEqual($contentBytes, $snapshotBytes)) {
  Test-Pass 'TEST-011 approved-context snapshot is byte-exact with the live content file'
} else {
  Test-Fail 'TEST-011 approved-context snapshot is byte-exact with the live content file'
}

$sidecarHash = Get-Sha256Hex $SidecarOut
$snapshotHash = Get-Sha256Hex $SnapshotOut
$manifestText = Get-Content -Raw -LiteralPath $ManifestOut
if ($manifestText -match [regex]::Escape("$sidecarHash  project-context.approval.json") -and
    $manifestText -match [regex]::Escape("$snapshotHash  project-context.approved.yaml")) {
  Test-Pass 'TEST-011 MANIFEST.sha256 hashes match the actual staged file hashes'
} else {
  Test-Fail 'TEST-011 MANIFEST.sha256 hashes match the actual staged file hashes' $manifestText
}

$expectedContentSha256 = (Get-PyText @($CanonPy, $Content, '--hash-only')).Trim()
$actualContextSha256 = Get-PyText @('-c', "import json; print(json.load(open(r'$SidecarOut'))['context_sha256'])")
if ($expectedContentSha256 -eq $actualContextSha256) {
  Test-Pass "TEST-011 context_sha256 matches the live content file's independently-recomputed SHA-256"
} else {
  Test-Fail "TEST-011 context_sha256 matches the live content file's independently-recomputed SHA-256" "got $actualContextSha256 want $expectedContentSha256"
}

$T011Reverify = Join-Path $Work 't011_reverify.json'
Invoke-Py @($mutator, $SidecarOut, $T011Reverify, 'hmac', '""') | Out-Null
# hmac key doesn't exist as a dotted single-level removal via mutate.py (it
# sets, not deletes); strip it explicitly instead.
Set-Content -LiteralPath $T011Reverify -NoNewline -Encoding utf8 -Value (Get-PyText @('-c', "import json; d=json.load(open(r'$SidecarOut')); d.pop('hmac', None); print(json.dumps(d))"))
$reverifyPreimage = Join-Path $Work 't011_reverify.preimage'
$r = Invoke-Py @($GenPy, '--dump-preimage', $T011Reverify)
[System.IO.File]::WriteAllBytes($reverifyPreimage, [System.IO.File]::ReadAllBytes($r.StdoutPath))
$recomputedHmac = Get-PyText @('-c', @"
import hmac, hashlib
key = open(r'$KeyFile','rb').read()
data = open(r'$reverifyPreimage','rb').read()
print(hmac.new(key, data, hashlib.sha256).hexdigest())
"@)
$stagedHmac = Get-PyText @('-c', "import json; print(json.load(open(r'$SidecarOut'))['hmac'])")
if ($recomputedHmac -eq $stagedHmac) {
  Test-Pass "TEST-011 staged sidecar's hmac verifies under independent preimage/HMAC re-derivation"
} else {
  Test-Fail "TEST-011 staged sidecar's hmac verifies under independent preimage/HMAC re-derivation" "got $recomputedHmac want $stagedHmac"
}

$Stage2 = Join-Path $Work 'stage-t011-nokey'
$FakeHome = Join-Path $Work 'fake-home-empty'
New-Item -ItemType Directory -Path $FakeHome -Force | Out-Null
$r = Invoke-Gen -ArgList @(
  '--schema', 'sdd-project-context-approval/v1',
  '--content', $Content,
  '--approver', 'alice',
  '--status', 'Approved',
  '--live-sidecar', $LiveAbsent,
  '--stage-dir', $Stage2
) -EnvSet @{ HOME = $FakeHome; USERPROFILE = $FakeHome } -EnvUnset @('SDD_CONTEXT_KEY', 'SDD_CONTEXT_KEY_FILE')
$errText = Get-Content -Raw -LiteralPath $r.StderrPath -ErrorAction SilentlyContinue
if ($r.ExitCode -eq 11 -and $errText -match 'NO_CONTEXT_KEY') {
  Test-Pass 'TEST-011 no resolvable SDD_CONTEXT_KEY: exit 11/NO_CONTEXT_KEY'
} else {
  Test-Fail 'TEST-011 no resolvable SDD_CONTEXT_KEY: exit 11/NO_CONTEXT_KEY' "exit $($r.ExitCode); $errText"
}
if (Test-Path -LiteralPath $Stage2) {
  Test-Fail 'TEST-011 no-key refusal writes NO staged artifact at all'
} else {
  Test-Pass 'TEST-011 no-key refusal writes NO staged artifact at all'
}

# ---------------------------------------------------------------------------
# TEST-012: preimage self-reference exclusion -- AC-012.
# ---------------------------------------------------------------------------

$T012HmacA = Join-Path $Work 't012_hmac_a.json'
$T012HmacB = Join-Path $Work 't012_hmac_b.json'
Invoke-Py @($mutator, $T010Positive, $T012HmacA, 'hmac', ('"' + ('a' * 64) + '"')) | Out-Null
Invoke-Py @($mutator, $T010Positive, $T012HmacB, 'hmac', ('"' + ('b' * 64) + '"')) | Out-Null
$rA = Invoke-Py @($GenPy, '--dump-preimage', $T012HmacA)
$rB = Invoke-Py @($GenPy, '--dump-preimage', $T012HmacB)
$bytesA = [System.IO.File]::ReadAllBytes($rA.StdoutPath)
$bytesB = [System.IO.File]::ReadAllBytes($rB.StdoutPath)
if ([System.Linq.Enumerable]::SequenceEqual($bytesA, $bytesB)) {
  Test-Pass 'TEST-012 two sidecars differing ONLY in hmac produce an identical preimage'
} else {
  Test-Fail 'TEST-012 two sidecars differing ONLY in hmac produce an identical preimage'
}

# ---------------------------------------------------------------------------
# TEST-013: key-resolution byte-parity with sdd-hook-guard.py's
# _resolve_sudo_key -- AC-013 (4-case fixture matrix). See the .sh suite's
# header comment for why resolve_evidence_key is not independently imported.
# ---------------------------------------------------------------------------

$Parity = Join-Path $Work 'key_parity.py'
Set-Content -LiteralPath $Parity -NoNewline -Encoding utf8 -Value @'
import importlib.util
import os
import sys

GEN_PATH, GUARD_PATH, CASE = sys.argv[1], sys.argv[2], sys.argv[3]
ARG = sys.argv[4:]


def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


gen = _load("_gen_approval_sidecar", GEN_PATH)
guard = _load("_sdd_hook_guard", GUARD_PATH)

if CASE == "env":
    os.environ["SDD_CONTEXT_KEY"] = "byte-parity-value"
    os.environ["SDD_SUDO_KEY"] = "byte-parity-value"
    a = gen.resolve_context_key()
    b = guard._resolve_sudo_key()
elif CASE == "file":
    (path,) = ARG
    os.environ.pop("SDD_CONTEXT_KEY", None)
    os.environ.pop("SDD_SUDO_KEY", None)
    os.environ["SDD_CONTEXT_KEY_FILE"] = path
    os.environ["SDD_SUDO_KEY_FILE"] = path
    a = gen.resolve_context_key()
    b = guard._resolve_sudo_key()
elif CASE == "home":
    (home,) = ARG
    for var in ("SDD_CONTEXT_KEY", "SDD_SUDO_KEY", "SDD_CONTEXT_KEY_FILE", "SDD_SUDO_KEY_FILE"):
        os.environ.pop(var, None)
    os.environ["HOME"] = home
    os.environ["USERPROFILE"] = home
    a = gen.resolve_context_key()
    b = guard._resolve_sudo_key()
elif CASE == "none":
    for var in ("SDD_CONTEXT_KEY", "SDD_SUDO_KEY", "SDD_CONTEXT_KEY_FILE", "SDD_SUDO_KEY_FILE"):
        os.environ.pop(var, None)
    os.environ["HOME"] = ARG[0]
    os.environ["USERPROFILE"] = ARG[0]
    a = gen.resolve_context_key()
    b = guard._resolve_sudo_key()
else:
    raise SystemExit("unknown case")

sys.exit(0 if a == b else 1)
'@

$r = Invoke-Py @($Parity, $GenPy, $HookGuardPy, 'env')
if ($r.ExitCode -eq 0) {
  Test-Pass 'TEST-013 case 1/4 (env var): identical key bytes to _resolve_sudo_key'
} else {
  Test-Fail 'TEST-013 case 1/4 (env var): identical key bytes to _resolve_sudo_key'
}

$T013KeyFile = Join-Path $Work 't013_keyfile'
[System.IO.File]::WriteAllBytes($T013KeyFile, [byte[]](0xEF, 0xBB, 0xBF) + [System.Text.Encoding]::UTF8.GetBytes("  byte-parity-file-value  `r`n"))
$r = Invoke-Py @($Parity, $GenPy, $HookGuardPy, 'file', $T013KeyFile)
if ($r.ExitCode -eq 0) {
  Test-Pass 'TEST-013 case 2/4 (env-file, BOM+whitespace-stripped): identical key bytes to _resolve_sudo_key'
} else {
  Test-Fail 'TEST-013 case 2/4 (env-file, BOM+whitespace-stripped): identical key bytes to _resolve_sudo_key'
}

$FakeHomeParity = Join-Path $Work 'fake-home-parity'
New-Item -ItemType Directory -Path (Join-Path $FakeHomeParity '.sdd') -Force | Out-Null
$bomLine = [byte[]](0xEF, 0xBB, 0xBF) + [System.Text.Encoding]::UTF8.GetBytes("  byte-parity-home-value  `r`n")
[System.IO.File]::WriteAllBytes((Join-Path $FakeHomeParity '.sdd/context-key'), $bomLine)
[System.IO.File]::WriteAllBytes((Join-Path $FakeHomeParity '.sdd/sudo-key'), $bomLine)
$r = Invoke-Py @($Parity, $GenPy, $HookGuardPy, 'home', $FakeHomeParity)
if ($r.ExitCode -eq 0) {
  Test-Pass 'TEST-013 case 3/4 (home-path, BOM+whitespace-stripped): identical key bytes to _resolve_sudo_key'
} else {
  Test-Fail 'TEST-013 case 3/4 (home-path, BOM+whitespace-stripped): identical key bytes to _resolve_sudo_key'
}

$FakeHomeEmpty = Join-Path $Work 'fake-home-parity-empty'
New-Item -ItemType Directory -Path $FakeHomeEmpty -Force | Out-Null
$r = Invoke-Py @($Parity, $GenPy, $HookGuardPy, 'none', $FakeHomeEmpty)
if ($r.ExitCode -eq 0) {
  Test-Pass 'TEST-013 case 4/4 (none resolvable): both resolvers return None'
} else {
  Test-Fail 'TEST-013 case 4/4 (none resolvable): both resolvers return None'
}

# ---------------------------------------------------------------------------
# TEST-034: signer staging-only contract + rollback -- AC-034.
# ---------------------------------------------------------------------------

$ProjA = Join-Path $Work 'proj-t034-a'
New-Item -ItemType Directory -Path $ProjA -Force | Out-Null
$ContentA = Join-Path $ProjA 'project-context.yaml'
Write-ContentFixture $ContentA

$LiveB = Join-Path $Work 'live-sidecar-for-t034.json'
Set-Content -LiteralPath $LiveB -NoNewline -Encoding utf8 -Value '{"schema": "sdd-project-context-approval/v1", "context_sha256": "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", "approval_epoch": 1}'
$liveBefore = Get-Sha256Hex $LiveB
Invoke-Gen -ArgList @(
  '--schema', 'sdd-project-context-approval/v1',
  '--content', $ContentA,
  '--approver', 'alice',
  '--status', 'Approved',
  '--live-sidecar', $LiveB,
  '--stage-dir', (Join-Path $Work 'stage-t034-nonbootstrap')
) -EnvSet @{ SDD_CONTEXT_KEY = 'test-context-key-epic189-t003' } | Out-Null
$liveAfter = Get-Sha256Hex $LiveB
if ($liveBefore -eq $liveAfter) {
  Test-Pass 'TEST-034 the live sidecar path is never opened for writing (byte-identical before/after)'
} else {
  Test-Fail 'TEST-034 the live sidecar path is never opened for writing (byte-identical before/after)'
}

$StageFail1 = Join-Path $Work 'stage-t034-fail1'
$r = Invoke-Gen -ArgList @(
  '--schema', 'sdd-project-context-approval/v1',
  '--content', $ContentA,
  '--approver', 'alice',
  '--status', 'Approved',
  '--live-sidecar', (Join-Path $Work 'no-such-sidecar-t034.json'),
  '--stage-dir', $StageFail1,
  '--simulate-mid-write-failure', 'after-sidecar'
) -EnvSet @{ SDD_CONTEXT_KEY = 'test-context-key-epic189-t003' }
if ($r.ExitCode -eq 90 -and -not (Test-Path -LiteralPath $StageFail1)) {
  Test-Pass 'TEST-034 a simulated failure after the sidecar write leaves no partial artifact at the staged path'
} else {
  Test-Fail 'TEST-034 a simulated failure after the sidecar write leaves no partial artifact' "exit $($r.ExitCode)"
}
$strayTmp = Get-ChildItem -LiteralPath $Work -Filter '.tmp-*' -Directory -ErrorAction SilentlyContinue
if (-not $strayTmp) {
  Test-Pass 'TEST-034 no stray temp staging directory remains after a simulated failure'
} else {
  Test-Fail 'TEST-034 no stray temp staging directory remains after a simulated failure'
}

$StageFail2 = Join-Path $Work 'stage-t034-fail2'
$r = Invoke-Gen -ArgList @(
  '--schema', 'sdd-project-context-approval/v1',
  '--content', $ContentA,
  '--approver', 'alice',
  '--status', 'Approved',
  '--live-sidecar', (Join-Path $Work 'no-such-sidecar-t034.json'),
  '--stage-dir', $StageFail2,
  '--simulate-mid-write-failure', 'after-snapshot'
) -EnvSet @{ SDD_CONTEXT_KEY = 'test-context-key-epic189-t003' }
if ($r.ExitCode -eq 90 -and -not (Test-Path -LiteralPath $StageFail2)) {
  Test-Pass 'TEST-034 a simulated failure after the snapshot write leaves no partial artifact at the staged path'
} else {
  Test-Fail 'TEST-034 a simulated failure after the snapshot write leaves no partial artifact' "exit $($r.ExitCode)"
}

$ProjC = Join-Path $Work 'proj-t034-c'
New-Item -ItemType Directory -Path $ProjC -Force | Out-Null
$ContentC = Join-Path $ProjC 'project-context.yaml'
Write-ContentFixture $ContentC
Push-Location $ProjC
try {
  Invoke-Gen -ArgList @(
    '--schema', 'sdd-project-context-approval/v1',
    '--content', 'project-context.yaml',
    '--approver', 'alice',
    '--status', 'Approved',
    '--live-sidecar', 'no-such-sidecar.json',
    '--simulate-mid-write-failure', 'after-sidecar'
  ) -EnvSet @{ SDD_CONTEXT_KEY = 'test-context-key-epic189-t003' } | Out-Null
  $schemaDir = Join-Path $ProjC 'sdd/.staging/sdd-project-context-approval/v1'
  $beforeCount = 0
  if (Test-Path -LiteralPath $schemaDir) {
    $beforeCount = (Get-ChildItem -LiteralPath $schemaDir -Directory -ErrorAction SilentlyContinue | Measure-Object).Count
  }
  $r2 = Invoke-Gen -ArgList @(
    '--schema', 'sdd-project-context-approval/v1',
    '--content', 'project-context.yaml',
    '--approver', 'alice',
    '--status', 'Approved',
    '--live-sidecar', 'no-such-sidecar.json'
  ) -EnvSet @{ SDD_CONTEXT_KEY = 'test-context-key-epic189-t003' }
  $afterCount = 0
  if (Test-Path -LiteralPath $schemaDir) {
    $afterCount = (Get-ChildItem -LiteralPath $schemaDir -Directory -ErrorAction SilentlyContinue | Measure-Object).Count
  }
  if ($r2.ExitCode -eq 0 -and $beforeCount -eq 0 -and $afterCount -eq 1) {
    Test-Pass 'TEST-034 a re-run after a mid-write failure succeeds with a fresh nonce/staging subdirectory'
  } else {
    Test-Fail 'TEST-034 a re-run after a mid-write failure succeeds with a fresh nonce/staging subdirectory' "rc=$($r2.ExitCode) before=$beforeCount after=$afterCount"
  }
} finally {
  Pop-Location
}

# ---------------------------------------------------------------------------
# TEST-036: HMAC golden vector + fifteen one-field-mutated variants -- AC-036.
# ---------------------------------------------------------------------------

$GoldenHmac = '93d361de8a9f97d9ff173b6db8764a606a885440e7534164dd31e1f2826d4b07'
$GoldenKey = Join-Path $Work 't036-key'
Set-Content -LiteralPath $GoldenKey -NoNewline -Encoding utf8 -Value 'test-context-key-epic189-t003'

$T036Golden = Join-Path $Work 't036_golden.json'
Set-Content -LiteralPath $T036Golden -NoNewline -Encoding utf8 -Value @'
{
  "schema": "sdd-project-context-approval/v1",
  "context_sha256": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "primary_approval": {"status": "Approved", "approver": "alice", "approved_at": "2026-01-01T00:00:00Z"},
  "second_approval": {"status": "Approved", "approver": "bob", "approved_at": "2026-01-01T00:05:00Z"},
  "effective_at": "2026-01-02T00:00:00Z",
  "predecessor_context_sha256": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "weakening_verdict": {
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
  },
  "approval_epoch": 2,
  "hmac": "93d361de8a9f97d9ff173b6db8764a606a885440e7534164dd31e1f2826d4b07"
}
'@

function Get-HmacOf([string]$JsonPath) {
  $r = Invoke-Py @($GenPy, '--dump-preimage', $JsonPath)
  $preimagePath = Join-Path $Work ([Guid]::NewGuid().ToString('N') + '.preimage')
  [System.IO.File]::WriteAllBytes($preimagePath, [System.IO.File]::ReadAllBytes($r.StdoutPath))
  return Get-PyText @('-c', @"
import hmac, hashlib
key = open(r'$GoldenKey','rb').read()
data = open(r'$preimagePath','rb').read()
print(hmac.new(key, data, hashlib.sha256).hexdigest())
"@)
}

$goldenHmacActual = Get-HmacOf $T036Golden
if ($goldenHmacActual -eq $GoldenHmac) {
  Test-Pass "TEST-036 golden vector's HMAC matches the hand-verified expected value"
} else {
  Test-Fail "TEST-036 golden vector's HMAC matches the hand-verified expected value" "got $goldenHmacActual want $GoldenHmac"
}

function Test-Mutation([string]$Desc, [string]$Dotted, [string]$ValueJson) {
  $mutPath = Join-Path $Work ([Guid]::NewGuid().ToString('N') + '_mut.json')
  Invoke-Py @($mutator, $T036Golden, $mutPath, $Dotted, $ValueJson) | Out-Null
  $mutatedHmac = Get-HmacOf $mutPath
  if ($mutatedHmac -ne $GoldenHmac) {
    Test-Pass "TEST-036 mutating $Desc changes the HMAC"
  } else {
    Test-Fail "TEST-036 mutating $Desc changes the HMAC" "unchanged: $mutatedHmac"
  }
}

Test-Mutation 'schema' 'schema' '"sdd-provider-bindings-approval/v1"'
Test-Mutation 'context_sha256' 'context_sha256' ('"sha256:' + ('f' * 64) + '"')
Test-Mutation 'primary_approval.status' 'primary_approval.status' '"Rejected"'
Test-Mutation 'primary_approval.approver' 'primary_approval.approver' '"carol"'
Test-Mutation 'primary_approval.approved_at' 'primary_approval.approved_at' '"2027-01-01T00:00:00Z"'
Test-Mutation 'second_approval.status' 'second_approval.status' '"Rejected"'
Test-Mutation 'second_approval.approver' 'second_approval.approver' '"dave"'
Test-Mutation 'second_approval.approved_at' 'second_approval.approved_at' '"2027-01-01T00:05:00Z"'
Test-Mutation 'effective_at' 'effective_at' '"2027-01-02T00:00:00Z"'
Test-Mutation 'predecessor_context_sha256' 'predecessor_context_sha256' ('"sha256:' + ('e' * 64) + '"')
Test-Mutation 'weakening_verdict.policy_weakening' 'weakening_verdict.policy_weakening' 'false'
Test-Mutation 'weakening_verdict.categories.capability_enforcement_weakened' 'weakening_verdict.categories.capability_enforcement_weakened' '"not_weakened"'
Test-Mutation 'weakening_verdict.two_person_required' 'weakening_verdict.two_person_required' 'false'
Test-Mutation 'weakening_verdict.cooldown_hours' 'weakening_verdict.cooldown_hours' '24'
Test-Mutation 'approval_epoch' 'approval_epoch' '3'

# ---------------------------------------------------------------------------
# Provenance seam Done-When (tasks.md T-003): bootstrap signs with
# null/null/epoch=1; non-bootstrap fails closed with
# WEAKENING_DETECTOR_UNAVAILABLE and writes NO staged candidate.
# ---------------------------------------------------------------------------

$StageBoot = Join-Path $Work 'stage-seam-bootstrap'
$r = Invoke-Gen -ArgList @(
  '--schema', 'sdd-project-context-approval/v1',
  '--content', $ContentA,
  '--approver', 'alice',
  '--status', 'Approved',
  '--live-sidecar', (Join-Path $Work 'no-such-sidecar-seam.json'),
  '--stage-dir', $StageBoot
) -EnvSet @{ SDD_CONTEXT_KEY = 'test-context-key-epic189-t003' }
if ($r.ExitCode -eq 0) {
  Test-Pass 'SEAM bootstrap (no live sidecar): signing succeeds'
} else {
  Test-Fail 'SEAM bootstrap (no live sidecar): signing succeeds' "exit $($r.ExitCode)"
}
$bootSidecar = Join-Path $StageBoot 'project-context.approval.json'
$predecessor = Get-PyText @('-c', "import json; print(json.load(open(r'$bootSidecar'))['predecessor_context_sha256'])")
$verdict = Get-PyText @('-c', "import json; print(json.load(open(r'$bootSidecar'))['weakening_verdict'])")
$epoch = Get-PyText @('-c', "import json; print(json.load(open(r'$bootSidecar'))['approval_epoch'])")
if ($predecessor -eq 'None' -and $verdict -eq 'None' -and $epoch -eq '1') {
  Test-Pass 'SEAM bootstrap: predecessor_context_sha256/weakening_verdict = null, approval_epoch = 1'
} else {
  Test-Fail 'SEAM bootstrap: predecessor_context_sha256/weakening_verdict = null, approval_epoch = 1' "predecessor=$predecessor verdict=$verdict epoch=$epoch"
}

$StageNonboot = Join-Path $Work 'stage-seam-nonbootstrap'
$r = Invoke-Gen -ArgList @(
  '--schema', 'sdd-project-context-approval/v1',
  '--content', $ContentA,
  '--approver', 'alice',
  '--status', 'Approved',
  '--live-sidecar', $LiveB,
  '--stage-dir', $StageNonboot
) -EnvSet @{ SDD_CONTEXT_KEY = 'test-context-key-epic189-t003' }
$errText = Get-Content -Raw -LiteralPath $r.StderrPath -ErrorAction SilentlyContinue
if ($r.ExitCode -eq 12 -and $errText -match 'WEAKENING_DETECTOR_UNAVAILABLE') {
  Test-Pass 'SEAM non-bootstrap (live sidecar present): exits non-zero with WEAKENING_DETECTOR_UNAVAILABLE'
} else {
  Test-Fail 'SEAM non-bootstrap (live sidecar present): exits non-zero with WEAKENING_DETECTOR_UNAVAILABLE' "exit $($r.ExitCode); $errText"
}
if (Test-Path -LiteralPath $StageNonboot) {
  Test-Fail 'SEAM non-bootstrap: writes NO staged candidate'
} else {
  Test-Pass 'SEAM non-bootstrap: writes NO staged candidate'
}

# ---------------------------------------------------------------------------
# TEST-HARDEN(a): DUPLICATE_APPROVER_IDENTITY refused before any hashing.
# ---------------------------------------------------------------------------

$StageDup = Join-Path $Work 'stage-dup'
$r = Invoke-Gen -ArgList @(
  '--schema', 'sdd-project-context-approval/v1',
  '--content', $ContentA,
  '--approver', 'alice',
  '--status', 'Approved',
  '--second-approver', 'alice',
  '--live-sidecar', (Join-Path $Work 'no-such-sidecar-dup.json'),
  '--stage-dir', $StageDup
) -EnvSet @{ SDD_CONTEXT_KEY = 'test-context-key-epic189-t003' }
$errText = Get-Content -Raw -LiteralPath $r.StderrPath -ErrorAction SilentlyContinue
if ($r.ExitCode -eq 10 -and $errText -match 'DUPLICATE_APPROVER_IDENTITY') {
  Test-Pass 'TEST-HARDEN(a) identical primary/second approver id refused (DUPLICATE_APPROVER_IDENTITY)'
} else {
  Test-Fail 'TEST-HARDEN(a) identical primary/second approver id refused' "exit $($r.ExitCode); $errText"
}
if (Test-Path -LiteralPath $StageDup) {
  Test-Fail 'TEST-HARDEN(a) DUPLICATE_APPROVER_IDENTITY refusal writes no staged artifact'
} else {
  Test-Pass 'TEST-HARDEN(a) DUPLICATE_APPROVER_IDENTITY refusal writes no staged artifact'
}

# ---------------------------------------------------------------------------
# TEST-HARDEN(b): a hostile field value (an unpaired UTF-16 surrogate) is
# rejected with a documented category, never an uncaught traceback.
#
# Delivered via a JSON file containing a literal \udcff escape in a field
# (--dump-preimage), rather than via CLI argv: this pwsh host's
# [System.Diagnostics.Process] argv marshalling was found to silently
# replace an unpaired surrogate with U+FFFD before the child process ever
# sees it (confirmed empirically -- not a real fix, just an unreliable
# delivery path on this host), whereas a raw JSON file byte-written via
# [System.IO.File]::WriteAllBytes bypasses that layer entirely and reaches
# the SAME `_canonicalize_json_preimage` rejection code path the CLI's
# --approver flow also uses (the .sh suite's TEST-HARDEN(b) exercises that
# CLI argv path directly, which POSIX shells deliver byte-exact).
# ---------------------------------------------------------------------------

$T012HostileJson = Join-Path $Work 't012_hostile.json'
[System.IO.File]::WriteAllBytes($T012HostileJson, [System.Text.Encoding]::ASCII.GetBytes('{"schema":"sdd-project-context-approval/v1","approver":"\udcff"}'))
$r = Invoke-Py @($GenPy, '--dump-preimage', $T012HostileJson)
$errText = Get-Content -Raw -LiteralPath $r.StderrPath -ErrorAction SilentlyContinue
if ($r.ExitCode -eq 14 -and $errText -match 'PREIMAGE_CANONICALIZATION_FAILED' -and $errText -notmatch '(?i)traceback') {
  Test-Pass 'TEST-HARDEN(b) an invalid-UTF-8/unpaired-surrogate field value is rejected (PREIMAGE_CANONICALIZATION_FAILED), never a traceback'
} else {
  Test-Fail 'TEST-HARDEN(b) an invalid-UTF-8/unpaired-surrogate field value is rejected cleanly' "exit $($r.ExitCode); $errText"
}

# ---------------------------------------------------------------------------
# TEST-HARDEN(c): usage errors are rejected cleanly, never a traceback.
# ---------------------------------------------------------------------------

$r = Invoke-Gen -ArgList @('--schema', 'sdd-project-context-approval/v1', '--content', $ContentA, '--approver', 'alice', '--status', 'Approved')
$errText = Get-Content -Raw -LiteralPath $r.StderrPath -ErrorAction SilentlyContinue
if ($r.ExitCode -eq 2 -and $errText -match '(?i)missing required argument' -and $errText -notmatch '(?i)traceback') {
  Test-Pass 'TEST-HARDEN(c) a missing required argument (--live-sidecar) is a clean usage error (exit 2)'
} else {
  Test-Fail 'TEST-HARDEN(c) a missing required argument (--live-sidecar) is a clean usage error' "exit $($r.ExitCode); $errText"
}

$r = Invoke-Gen -ArgList @(
  '--schema', 'sdd-project-context-approval/v1',
  '--content', $ContentA,
  '--approver', 'alice',
  '--status', 'Rejected',
  '--live-sidecar', (Join-Path $Work 'no-such-sidecar-status.json')
)
$errText = Get-Content -Raw -LiteralPath $r.StderrPath -ErrorAction SilentlyContinue
if ($r.ExitCode -eq 2 -and $errText -notmatch '(?i)traceback') {
  Test-Pass 'TEST-HARDEN(c) --status not exactly "Approved" is a clean usage error (exit 2)'
} else {
  Test-Fail 'TEST-HARDEN(c) --status not exactly "Approved" is a clean usage error' "exit $($r.ExitCode); $errText"
}

# ---------------------------------------------------------------------------
# Self-registration (design.md Test Strategy item 11).
# ---------------------------------------------------------------------------

$RunAllSh = Get-Content -Raw -LiteralPath (Join-Path $Root 'tests/run-all.sh')
if ($RunAllSh -match 'generate-approval-sidecar\.tests\.sh') {
  Test-Pass 'self-registration: tests/generate-approval-sidecar.tests.sh registered in tests/run-all.sh'
} else {
  Test-Fail 'self-registration: tests/generate-approval-sidecar.tests.sh registered in tests/run-all.sh'
}
$RunAllPs1 = Get-Content -Raw -LiteralPath (Join-Path $Root 'tests/run-all.ps1')
if ($RunAllPs1 -match 'generate-approval-sidecar\.tests\.ps1') {
  Test-Pass 'self-registration: tests/generate-approval-sidecar.tests.ps1 registered in tests/run-all.ps1'
} else {
  Test-Fail 'self-registration: tests/generate-approval-sidecar.tests.ps1 registered in tests/run-all.ps1'
}

Write-Output "PASS: $script:PassCount"
Write-Output "FAIL: $script:FailCount"
if ($script:FailCount -gt 0) { exit 1 } else { exit 0 }
}
finally {
  Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}
