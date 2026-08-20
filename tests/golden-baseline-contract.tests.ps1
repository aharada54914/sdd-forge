$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Capture = if ($env:GOLDEN_CAPTURE_UNDER_TEST) { $env:GOLDEN_CAPTURE_UNDER_TEST } else { Join-Path $Root 'tests/capture-golden-baseline.ps1' }
$Promote = if ($env:GOLDEN_PROMOTE_UNDER_TEST) { $env:GOLDEN_PROMOTE_UNDER_TEST } else { Join-Path $Root 'tests/promote-golden-baseline.ps1' }
$BaselineRoot = Join-Path $Root 'specs/epic-195-a7-compatibility/verification/golden-baseline'
$Canonical = Join-Path $BaselineRoot 'canonical'
$Candidate = Join-Path $BaselineRoot 'candidate/current'
$Work = Join-Path ([IO.Path]::GetTempPath()) ("golden-baseline-contract-" + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($Work) | Out-Null
$Pass = 0
$Fail = 0

function Ok([string]$Message) { $script:Pass++; Write-Host "ok: $Message" }
function Fail([string]$Message) { $script:Fail++; Write-Host "FAIL: $Message" }
function Get-TreeHash([string]$Path) {
    $output = & python3 -c @'
import hashlib, pathlib, sys
root = pathlib.Path(sys.argv[1])
h = hashlib.sha256()
if root.is_dir():
    for path in sorted(p for p in root.rglob("*") if p.is_file()):
        h.update(path.relative_to(root).as_posix().encode() + b"\0" + path.read_bytes() + b"\0")
print(h.hexdigest())
'@ $Path
    if ($LASTEXITCODE -ne 0) { throw 'tree hash failed' }
    return ($output | Select-Object -Last 1).Trim()
}
function Invoke-GuardCase([string]$Name, [string]$Script, [string[]]$Arguments, [string]$CiValue, [bool]$SetCi) {
    $Touched = Join-Path $Work "$Name.touched"
    $OldCi = $env:CI
    $OldTouch = $env:GOLDEN_TEST_TOUCH_PATH
    try {
        if ($SetCi) { $env:CI = $CiValue } else { Remove-Item Env:CI -ErrorAction SilentlyContinue }
        $env:GOLDEN_TEST_TOUCH_PATH = $Touched
        & $Script @Arguments *> (Join-Path $Work "$Name.log")
        $rc = $LASTEXITCODE
    } finally {
        if ($null -eq $OldCi) { Remove-Item Env:CI -ErrorAction SilentlyContinue } else { $env:CI = $OldCi }
        if ($null -eq $OldTouch) { Remove-Item Env:GOLDEN_TEST_TOUCH_PATH -ErrorAction SilentlyContinue } else { $env:GOLDEN_TEST_TOUCH_PATH = $OldTouch }
    }
    if ($rc -ne 0 -and -not (Test-Path -LiteralPath $Touched)) { Ok "$Name refuses with no file touched" }
    else { Fail "$Name must refuse with non-zero status and no file touched (status=$rc touched=$(Test-Path -LiteralPath $Touched))" }
}

try {
    if ($args.Count -eq 1 -and $args[0] -eq '--red') {
        $Permissive = Join-Path $Work 'permissive-promote.ps1'
        [IO.File]::WriteAllText($Permissive, @'
[IO.File]::WriteAllText($env:GOLDEN_TEST_TOUCH_PATH, 'touched')
exit 0
'@, [Text.UTF8Encoding]::new($false))
        Invoke-GuardCase 'CI-set' $Permissive @((Join-Path $Work 'candidate'), '--approved-by', 'human') 'false' $true
        Invoke-GuardCase 'approved-by-omitted' $Permissive @((Join-Path $Work 'candidate')) '' $false
        Write-Host "$Pass passed, $Fail failed"
        if ($Fail -ne 0) { exit 1 }
        exit 0
    }

    if ((Test-Path -LiteralPath $Capture -PathType Leaf) -and (Test-Path -LiteralPath $Promote -PathType Leaf)) { Ok 'capture and promote commands exist' }
    else { Fail 'capture and promote commands must exist' }

    $Before = Get-TreeHash $Canonical
    $OldTz, $OldLc, $OldSdd = $env:TZ, $env:LC_ALL, $env:SDD_BASELINE_SENTINEL
    try {
        $env:TZ = 'Pacific/Honolulu'; $env:LC_ALL = 'C'; $env:SDD_BASELINE_SENTINEL = 'must-not-leak'
        & $Capture *> (Join-Path $Work 'default.log'); $DefaultRc = $LASTEXITCODE
        & $Capture --write-candidate *> (Join-Path $Work 'candidate.log'); $CandidateRc = $LASTEXITCODE
    } finally {
        $env:TZ = $OldTz; $env:LC_ALL = $OldLc; $env:SDD_BASELINE_SENTINEL = $OldSdd
    }
    if ($DefaultRc -eq 0 -and (Get-TreeHash $Canonical) -eq $Before) { Ok 'default capture matches canonical and is read-only' }
    else { Fail 'default capture must match canonical without changing it' }
    $CandidateMatches = (Get-TreeHash $Canonical) -eq (Get-TreeHash $Candidate)
    if ($CandidateRc -eq 0 -and $CandidateMatches -and (Get-TreeHash $Canonical) -eq $Before) { Ok 'write-candidate writes an exact candidate without changing canonical' }
    else { Fail 'write-candidate must write only an exact candidate' }

    & python3 -c @'
import hashlib, json, pathlib, sys
root, candidate = map(pathlib.Path, sys.argv[1:])
m = json.loads((candidate / "manifest.json").read_text())
expected = [("deterministic-script-output", "raw stdout/stderr byte-tuple"), ("exit-code", "status integer"), ("stdout-stderr", "raw stdout/stderr byte-tuple"), ("template-copy-result", "filesystem manifest (path -> sha256)"), ("schema-validator-result", "status integer"), ("install-result", "filesystem manifest"), ("uninstall-result", "filesystem manifest"), ("generated-directory-listing", "filesystem manifest"), ("plugin-manifest", "filesystem manifest (path -> sha256)")]
assert m["schema_version"] == "golden-baseline-manifest/v1"
assert m["pre_capability_commit_sha"] == "50b20364e996432cb06061df03ffb4d173c27fa6"
assert m["fixed_environment"] == {"LC_ALL":"C", "TZ":"UTC", "ambient_sdd_variables":[]}
assert [(x["name"], x["capture_format"]) for x in m["targets"]] == expected
for group in (m["capture_scripts"], m["targets"]):
    for item in group:
        p = (root if group is m["capture_scripts"] else candidate) / item["path"]
        assert hashlib.sha256(p.read_bytes()).hexdigest() == item["sha256"]
'@ $Root $Candidate
    if ($LASTEXITCODE -eq 0) { Ok 'manifest records the pinned SHA, fixed environment, and every target/script hash' }
    else { Fail 'manifest shape or a recorded hash is invalid' }

    Invoke-GuardCase 'CI-set' $Promote @($Candidate, '--approved-by', 'human') 'false' $true
    Invoke-GuardCase 'approved-by-omitted' $Promote @($Candidate) '' $false

    $Clone = Join-Path $Work 'repo'
    & git clone -q --shared $Root $Clone
    if ($LASTEXITCODE -eq 0) {
        Copy-Item (Join-Path $Root 'tests/capture-golden-baseline.sh') (Join-Path $Clone 'tests/')
        Copy-Item (Join-Path $Root 'tests/capture-golden-baseline.ps1') (Join-Path $Clone 'tests/')
        Copy-Item (Join-Path $Root 'tests/promote-golden-baseline.sh') (Join-Path $Clone 'tests/')
        Copy-Item (Join-Path $Root 'tests/promote-golden-baseline.ps1') (Join-Path $Clone 'tests/')
        $CloneBaseline = Join-Path $Clone 'specs/epic-195-a7-compatibility/verification/golden-baseline'
        [IO.Directory]::CreateDirectory($CloneBaseline) | Out-Null
        $CloneCanonical = Join-Path $CloneBaseline 'canonical'
        Remove-Item -LiteralPath $CloneCanonical -Recurse -Force
        Copy-Item $Canonical $CloneCanonical -Recurse
        $CloneCapture = Join-Path $Clone 'tests/capture-golden-baseline.ps1'
        $ClonePromote = Join-Path $Clone 'tests/promote-golden-baseline.ps1'
        Add-Content (Join-Path $CloneBaseline 'canonical/targets/exit-code.txt') 'drift'
        & $CloneCapture *> (Join-Path $Work 'drift.log'); $DriftRc = $LASTEXITCODE
        if ($DriftRc -ne 0) { Ok 'default capture exits non-zero on drift' } else { Fail 'default capture must reject drift' }
        & $CloneCapture --write-candidate *> (Join-Path $Work 'clone-candidate.log'); $WriteRc = $LASTEXITCODE
        $OldCi = $env:CI
        try { Remove-Item Env:CI -ErrorAction SilentlyContinue; & $ClonePromote (Join-Path $CloneBaseline 'candidate/current') --approved-by test-human *> (Join-Path $Work 'promote.log'); $PromoteRc = $LASTEXITCODE }
        finally { if ($null -ne $OldCi) { $env:CI = $OldCi } }
        & $CloneCapture *> (Join-Path $Work 'post-promote.log'); $MatchRc = $LASTEXITCODE
        if ($WriteRc -eq 0 -and $PromoteRc -eq 0 -and $MatchRc -eq 0) { Ok 'guarded promotion copies candidate to canonical' }
        else { Fail 'guarded promotion must restore a matching canonical baseline' }
        $CloneManifest = Join-Path $CloneBaseline 'canonical/manifest.json'
        & python3 -c @'
import json, pathlib, sys
p=pathlib.Path(sys.argv[1]); d=json.loads(p.read_text()); d["pre_capability_commit_sha"]="0"*40; d["fixed_environment"]={"TZ":"bad","LC_ALL":"bad","ambient_sdd_variables":["SDD_X"]}; d["capture_scripts"][0]["sha256"]="0"*64
for target in d["targets"]: target["sha256"]="0"*64
p.write_text(json.dumps(d, indent=2, sort_keys=True)+"\n")
'@ $CloneManifest
        & $CloneCapture *> (Join-Path $Work 'manifest-mismatch.log'); $MismatchRc = $LASTEXITCODE
        if ($MismatchRc -ne 0) { Ok 'manifest/counterpart mismatches fail closed' } else { Fail 'manifest/counterpart mismatches must fail' }
    } else { Fail 'disposable repository setup must succeed' }

    if ((Get-Content -LiteralPath (Join-Path $BaselineRoot '.gitignore') -Raw).Trim() -eq 'candidate/') { Ok 'candidate output is gitignored' }
    else { Fail 'candidate/ must be gitignored' }

    Write-Host "$Pass passed, $Fail failed"
    if ($Fail -ne 0) { exit 1 }
    exit 0
} finally {
    if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force }
}
