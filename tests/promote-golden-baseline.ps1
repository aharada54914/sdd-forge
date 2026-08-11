$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Keep both authorization guards before root discovery and every candidate or
# canonical filesystem operation. Any non-empty CI value is a refusal.
if (-not [string]::IsNullOrEmpty($env:CI)) {
    [Console]::Error.WriteLine('promote-golden-baseline: promotion is forbidden when CI is non-empty')
    exit 2
}
if ($args.Count -ne 3 -or $args[1] -cne '--approved-by' -or [string]::IsNullOrWhiteSpace([string]$args[2])) {
    [Console]::Error.WriteLine('Usage: promote-golden-baseline.ps1 <candidate-path> --approved-by <human-identifier>')
    exit 2
}

$Candidate = [string]$args[0]
$ApprovedBy = [string]$args[2]
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Program = @'
from __future__ import annotations
import hashlib, json, os, shutil, sys, tempfile
from pathlib import Path
PRE_CAPABILITY_SHA="50b20364e996432cb06061df03ffb4d173c27fa6"
SCHEMA_VERSION="golden-baseline-manifest/v1"
BASELINE_RELATIVE=Path("specs/epic-195-a7-compatibility/verification/golden-baseline")
TARGETS=(("deterministic-script-output","targets/deterministic-script-output.bin","raw stdout/stderr byte-tuple"),("exit-code","targets/exit-code.txt","status integer"),("stdout-stderr","targets/stdout-stderr.bin","raw stdout/stderr byte-tuple"),("template-copy-result","targets/template-copy-result.sha256","filesystem manifest (path -> sha256)"),("schema-validator-result","targets/schema-validator-result.txt","status integer"),("install-result","targets/install-result.sha256","filesystem manifest"),("uninstall-result","targets/uninstall-result.sha256","filesystem manifest"),("generated-directory-listing","targets/generated-directory-listing.txt","filesystem listing"),("plugin-manifest","targets/plugin-manifest.sha256","filesystem manifest (path -> sha256)"))
def sha256(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def inside(path,parent):
    try: path.relative_to(parent); return True
    except ValueError: return False
def validate(repo,candidate,candidate_root):
    if not candidate.is_dir() or candidate.is_symlink() or not inside(candidate,candidate_root): raise ValueError("candidate must be a real directory below the gitignored candidate root")
    if any(item.is_symlink() for item in candidate.rglob("*")): raise ValueError("candidate must not contain symbolic links")
    try: manifest=json.loads((candidate/"manifest.json").read_text(encoding="utf-8"))
    except (OSError,UnicodeDecodeError,json.JSONDecodeError) as exc: raise ValueError("candidate manifest is missing or invalid") from exc
    if set(manifest)!={"capture_scripts","fixed_environment","pre_capability_commit_sha","schema_version","targets"}: raise ValueError("candidate manifest has an invalid field set")
    if manifest["schema_version"]!=SCHEMA_VERSION or manifest["pre_capability_commit_sha"]!=PRE_CAPABILITY_SHA: raise ValueError("candidate manifest identity does not match the contract")
    if manifest["fixed_environment"]!={"LC_ALL":"C","TZ":"UTC","ambient_sdd_variables":[]}: raise ValueError("candidate fixed environment does not match the contract")
    expected_scripts=("tests/capture-golden-baseline.sh","tests/capture-golden-baseline.ps1"); scripts=manifest["capture_scripts"]
    if not isinstance(scripts,list) or [entry.get("path") for entry in scripts if isinstance(entry,dict)]!=list(expected_scripts): raise ValueError("candidate capture-script inventory does not match the contract")
    for entry in scripts:
        if set(entry)!={"path","sha256"} or entry["sha256"]!=sha256(repo/entry["path"]): raise ValueError("candidate capture-script hash does not match the live script")
    targets=manifest["targets"]; expected=[(name,path,capture_format) for name,path,capture_format in TARGETS]
    if not isinstance(targets,list) or [(entry.get("name"),entry.get("path"),entry.get("capture_format")) for entry in targets if isinstance(entry,dict)]!=expected: raise ValueError("candidate target inventory does not match the contract")
    allowed={"manifest.json"}
    for entry in targets:
        if set(entry)!={"capture_format","name","path","sha256"}: raise ValueError("candidate target entry has an invalid field set")
        relative=Path(entry["path"])
        if relative.is_absolute() or ".." in relative.parts: raise ValueError("candidate target path is unsafe")
        target=candidate/relative
        if not target.is_file() or entry["sha256"]!=sha256(target): raise ValueError("candidate target hash does not match its artifact")
        allowed.add(relative.as_posix())
    actual={path.relative_to(candidate).as_posix() for path in candidate.rglob("*") if path.is_file()}
    if actual!=allowed: raise ValueError("candidate contains an undeclared or missing file")
def promote(repo,candidate_argument):
    baseline=(repo/BASELINE_RELATIVE).resolve(); candidate_root=(baseline/"candidate").resolve(); candidate=Path(candidate_argument).expanduser().resolve(); validate(repo,candidate,candidate_root)
    canonical=baseline/"canonical"; stage=Path(tempfile.mkdtemp(prefix=".canonical-stage-",dir=baseline)); backup=baseline/".canonical-backup"
    try:
        shutil.rmtree(stage); shutil.copytree(candidate,stage)
        if backup.exists(): shutil.rmtree(backup)
        if canonical.exists(): os.replace(canonical,backup)
        try: os.replace(stage,canonical)
        except BaseException:
            if backup.exists() and not canonical.exists(): os.replace(backup,canonical)
            raise
        if backup.exists(): shutil.rmtree(backup)
    finally:
        if stage.exists(): shutil.rmtree(stage)
try:
    repository=Path(sys.argv[1]).resolve(); promote(repository,sys.argv[2]); print("golden baseline promoted by "+sys.argv[3])
except (OSError,ValueError) as exc: print("promote-golden-baseline: "+str(exc),file=sys.stderr); raise SystemExit(1)
'@

$Program | & python3 - $Root $Candidate $ApprovedBy
exit $LASTEXITCODE
