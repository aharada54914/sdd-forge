$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($args.Count -eq 0) { $Mode = 'check' }
elseif ($args.Count -eq 1 -and $args[0] -eq '--write-candidate') { $Mode = 'write-candidate' }
else { [Console]::Error.WriteLine('Usage: capture-golden-baseline.ps1 [--write-candidate]'); exit 2 }

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Program = @'
from __future__ import annotations
import hashlib, io, json, os, shutil, struct, subprocess, sys, tarfile, tempfile
from pathlib import Path

PRE_CAPABILITY_SHA="50b20364e996432cb06061df03ffb4d173c27fa6"
SCHEMA_VERSION="golden-baseline-manifest/v1"
BASELINE_RELATIVE=Path("specs/epic-195-a7-compatibility/verification/golden-baseline")
TARGETS=(("deterministic-script-output","targets/deterministic-script-output.bin","raw stdout/stderr byte-tuple"),("exit-code","targets/exit-code.txt","status integer"),("stdout-stderr","targets/stdout-stderr.bin","raw stdout/stderr byte-tuple"),("template-copy-result","targets/template-copy-result.sha256","filesystem manifest (path -> sha256)"),("schema-validator-result","targets/schema-validator-result.txt","status integer"),("install-result","targets/install-result.sha256","filesystem manifest"),("uninstall-result","targets/uninstall-result.sha256","filesystem manifest"),("generated-directory-listing","targets/generated-directory-listing.txt","filesystem listing"),("plugin-manifest","targets/plugin-manifest.sha256","filesystem manifest (path -> sha256)"))

def sha256(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def fixed_environment(home):
    env={k:v for k,v in os.environ.items() if not k.upper().startswith("SDD_")}
    env.update({"TZ":"UTC","LC_ALL":"C","HOME":str(home)})
    return env
def run(command,cwd,environment): return subprocess.run(command,cwd=cwd,env=environment,stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=False)
def extract_snapshot(repo,destination,environment):
    archive=run(["git","-C",str(repo),"archive","--format=tar",PRE_CAPABILITY_SHA],repo,environment)
    if archive.returncode: raise RuntimeError("cannot archive pinned commit: "+archive.stderr.decode("utf-8","replace").strip())
    destination.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(archive.stdout),mode="r:") as bundle:
        for member in bundle.getmembers():
            relative=Path(member.name)
            if relative.is_absolute() or ".." in relative.parts: raise RuntimeError("pinned archive contains an unsafe path")
            target=destination/relative
            if member.isdir(): target.mkdir(parents=True,exist_ok=True); continue
            if not member.isfile(): raise RuntimeError("pinned archive contains an unsupported entry type")
            target.parent.mkdir(parents=True,exist_ok=True); source=bundle.extractfile(member)
            if source is None: raise RuntimeError("pinned archive entry cannot be read")
            target.write_bytes(source.read()); target.chmod(member.mode & 0o777)
def filesystem_manifest(root):
    if not root.exists(): return b""
    return "".join(f"{sha256(path)}  {path.relative_to(root).as_posix()}\n" for path in sorted(item for item in root.rglob("*") if item.is_file())).encode()
def directory_listing(root):
    if not root.exists(): return b""
    return "".join(path.relative_to(root).as_posix()+("/" if path.is_dir() else "")+"\n" for path in sorted(root.rglob("*"))).encode()
def raw_tuple(stdout,stderr): return struct.pack(">Q",len(stdout))+stdout+struct.pack(">Q",len(stderr))+stderr
def write_target(destination,relative,content):
    path=destination/relative; path.parent.mkdir(parents=True,exist_ok=True); path.write_bytes(content)
def initialize_git_snapshot(snapshot,environment):
    for command in (["git","init","-q"],["git","config","core.autocrlf","false"],["git","config","core.hooksPath",str(snapshot/".empty-hooks")],["git","add","-A"]):
        result=run(command,snapshot,environment)
        if result.returncode: raise RuntimeError("cannot initialize pinned snapshot: "+result.stderr.decode("utf-8","replace").strip())
def capture_install_state(snapshot,workspace,environment):
    install_root=workspace/"install-root"
    if os.name=="nt":
        shell=shutil.which("pwsh") or shutil.which("powershell")
        if shell is None: raise RuntimeError("PowerShell is required to capture install state on Windows")
        install=[shell,"-NoProfile","-File",str(snapshot/"install.ps1"),"-SourceDirectory",str(snapshot),"-InstallRoot",str(install_root),"-Target","FilesOnly","-SkipAgentInstall","-SkipMcp"]
        uninstall=[shell,"-NoProfile","-File",str(snapshot/"uninstall.ps1"),"-InstallRoot",str(install_root),"-Target","FilesOnly","-SkipAgentUninstall","-SkipMcpUninstall"]
    else:
        install=["bash",str(snapshot/"install.sh"),"--source-directory",str(snapshot),"--install-root",str(install_root),"--target","FilesOnly","--skip-agent-install","--skip-mcp"]
        uninstall=["bash",str(snapshot/"uninstall.sh"),"--install-root",str(install_root),"--target","FilesOnly","--skip-agent-uninstall","--skip-mcp-uninstall"]
    result=run(install,snapshot,environment)
    if result.returncode: raise RuntimeError("pinned install failed: "+result.stderr.decode("utf-8","replace").strip())
    installed=filesystem_manifest(install_root); result=run(uninstall,snapshot,environment)
    if result.returncode: raise RuntimeError("pinned uninstall failed: "+result.stderr.decode("utf-8","replace").strip())
    return installed,filesystem_manifest(install_root)
def build_capture(repo,destination):
    with tempfile.TemporaryDirectory(prefix="sdd-golden-source-") as temporary:
        workspace=Path(temporary); home=workspace/"home"; home.mkdir(); environment=fixed_environment(home); snapshot=workspace/"snapshot"
        extract_snapshot(repo,snapshot,environment); initialize_git_snapshot(snapshot,environment)
        generated=run([sys.executable,str(snapshot/"plugins/sdd-quality-loop/scripts/generate-guard-invariants.py"),"--check"],snapshot,environment); pair=raw_tuple(generated.stdout,generated.stderr)
        write_target(destination,TARGETS[0][1],pair); write_target(destination,TARGETS[1][1],f"{generated.returncode}\n".encode("ascii")); write_target(destination,TARGETS[2][1],pair)
        copied=workspace/"template-copy"; copied.mkdir()
        for source in sorted(snapshot.glob("plugins/*/templates")): shutil.copytree(source,copied/source.parent.name)
        write_target(destination,TARGETS[3][1],filesystem_manifest(copied))
        status=0
        try:
            for schema in sorted((snapshot/"contracts").glob("*.schema.json")): json.loads(schema.read_text(encoding="utf-8"))
        except (OSError,UnicodeDecodeError,json.JSONDecodeError): status=1
        write_target(destination,TARGETS[4][1],f"{status}\n".encode("ascii"))
        installed,uninstalled=capture_install_state(snapshot,workspace,environment); write_target(destination,TARGETS[5][1],installed); write_target(destination,TARGETS[6][1],uninstalled)
        write_target(destination,TARGETS[7][1],directory_listing(snapshot/"plugins/sdd-quality-loop/scripts/generated"))
        plugin_files=workspace/"plugin-manifests"; plugin_files.mkdir()
        for source in sorted(snapshot.glob("plugins/*/.*-plugin/plugin.json")):
            target=plugin_files/source.relative_to(snapshot); target.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(source,target)
        write_target(destination,TARGETS[8][1],filesystem_manifest(plugin_files))
    scripts=[]
    for relative in ("tests/capture-golden-baseline.sh","tests/capture-golden-baseline.ps1"):
        path=repo/relative
        if not path.is_file(): raise RuntimeError("capture twin is missing: "+relative)
        scripts.append({"path":relative,"sha256":sha256(path)})
    targets=[{"name":name,"path":relative,"capture_format":capture_format,"sha256":sha256(destination/relative)} for name,relative,capture_format in TARGETS]
    manifest={"capture_scripts":scripts,"fixed_environment":{"LC_ALL":"C","TZ":"UTC","ambient_sdd_variables":[]},"pre_capability_commit_sha":PRE_CAPABILITY_SHA,"schema_version":SCHEMA_VERSION,"targets":targets}
    (destination/"manifest.json").write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n",encoding="utf-8",newline="\n")
def snapshot(path): return {item.relative_to(path).as_posix():item.read_bytes() for item in sorted(path.rglob("*")) if item.is_file()} if path.is_dir() else {}
def main():
    repo=Path(sys.argv[1]).resolve(); mode=sys.argv[2]; baseline=repo/BASELINE_RELATIVE; canonical=baseline/"canonical"
    with tempfile.TemporaryDirectory(prefix="sdd-golden-capture-") as temporary:
        fresh=Path(temporary)/"capture"; fresh.mkdir(); build_capture(repo,fresh)
        if mode=="check":
            if snapshot(fresh)!=snapshot(canonical): print("golden baseline drift detected",file=sys.stderr); return 1
            print("golden baseline matches canonical"); return 0
        candidate=baseline/"candidate"/"current"; candidate.parent.mkdir(parents=True,exist_ok=True)
        if candidate.exists(): shutil.rmtree(candidate)
        shutil.copytree(fresh,candidate); print("golden baseline candidate written: "+candidate.relative_to(repo).as_posix()); return 0
try: raise SystemExit(main())
except (OSError,RuntimeError,subprocess.SubprocessError) as exc: print("capture-golden-baseline: "+str(exc),file=sys.stderr); raise SystemExit(1)
'@

$Program | & python3 - $Root $Mode
exit $LASTEXITCODE
