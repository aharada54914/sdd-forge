#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
case "$#:${1:-}" in
  0:) mode=check ;;
  1:--write-candidate) mode=write-candidate ;;
  *) printf 'Usage: %s [--write-candidate]\n' "$0" >&2; exit 2 ;;
esac

exec python3 - "$ROOT" "$mode" <<'PY'
from __future__ import annotations

import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile

PRE_CAPABILITY_SHA = "50b20364e996432cb06061df03ffb4d173c27fa6"
SCHEMA_VERSION = "golden-baseline-manifest/v1"
BASELINE_RELATIVE = Path("specs/epic-195-a7-compatibility/verification/golden-baseline")
TARGETS = (
    ("deterministic-script-output", "targets/deterministic-script-output.bin", "raw stdout/stderr byte-tuple"),
    ("exit-code", "targets/exit-code.txt", "status integer"),
    ("stdout-stderr", "targets/stdout-stderr.bin", "raw stdout/stderr byte-tuple"),
    ("template-copy-result", "targets/template-copy-result.sha256", "filesystem manifest (path -> sha256)"),
    ("schema-validator-result", "targets/schema-validator-result.txt", "status integer"),
    ("install-result", "targets/install-result.sha256", "filesystem manifest"),
    ("uninstall-result", "targets/uninstall-result.sha256", "filesystem manifest"),
    ("generated-directory-listing", "targets/generated-directory-listing.txt", "filesystem listing"),
    ("plugin-manifest", "targets/plugin-manifest.sha256", "filesystem manifest (path -> sha256)"),
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fixed_environment(home: Path) -> dict[str, str]:
    environment = {
        key: value
        for key, value in os.environ.items()
        if not key.upper().startswith("SDD_")
    }
    environment.update({"TZ": "UTC", "LC_ALL": "C", "HOME": str(home)})
    return environment


def run(command: list[str], *, cwd: Path, environment: dict[str, str]) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(command, cwd=cwd, env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)


def extract_snapshot(repo: Path, destination: Path, environment: dict[str, str]) -> None:
    archive = run(["git", "-C", str(repo), "archive", "--format=tar", PRE_CAPABILITY_SHA], cwd=repo, environment=environment)
    if archive.returncode != 0:
        raise RuntimeError(f"cannot archive pinned commit: {archive.stderr.decode('utf-8', 'replace').strip()}")
    destination.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(archive.stdout), mode="r:") as bundle:
        for member in bundle.getmembers():
            relative = Path(member.name)
            if relative.is_absolute() or ".." in relative.parts:
                raise RuntimeError("pinned archive contains an unsafe path")
            target = destination / relative
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            if not member.isfile():
                raise RuntimeError("pinned archive contains an unsupported entry type")
            target.parent.mkdir(parents=True, exist_ok=True)
            source = bundle.extractfile(member)
            if source is None:
                raise RuntimeError("pinned archive entry cannot be read")
            target.write_bytes(source.read())
            target.chmod(member.mode & 0o777)


def filesystem_manifest(root: Path) -> bytes:
    if not root.exists():
        return b""
    lines = []
    for path in sorted(item for item in root.rglob("*") if item.is_file()):
        lines.append(f"{sha256(path)}  {path.relative_to(root).as_posix()}\n")
    return "".join(lines).encode("utf-8")


def directory_listing(root: Path) -> bytes:
    if not root.exists():
        return b""
    lines = []
    for path in sorted(root.rglob("*")):
        suffix = "/" if path.is_dir() else ""
        lines.append(path.relative_to(root).as_posix() + suffix + "\n")
    return "".join(lines).encode("utf-8")


def raw_tuple(stdout: bytes, stderr: bytes) -> bytes:
    return struct.pack(">Q", len(stdout)) + stdout + struct.pack(">Q", len(stderr)) + stderr


def write_target(destination: Path, relative: str, content: bytes) -> None:
    path = destination / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)


def initialize_git_snapshot(snapshot: Path, environment: dict[str, str]) -> None:
    for command in (
        ["git", "init", "-q"],
        ["git", "config", "core.autocrlf", "false"],
        ["git", "config", "core.hooksPath", str(snapshot / ".empty-hooks")],
        ["git", "add", "-A"],
    ):
        result = run(command, cwd=snapshot, environment=environment)
        if result.returncode != 0:
            raise RuntimeError(f"cannot initialize pinned snapshot: {result.stderr.decode('utf-8', 'replace').strip()}")


def capture_install_state(snapshot: Path, workspace: Path, environment: dict[str, str]) -> tuple[bytes, bytes]:
    install_root = workspace / "install-root"
    if os.name == "nt":
        shell = shutil.which("pwsh") or shutil.which("powershell")
        if shell is None:
            raise RuntimeError("PowerShell is required to capture install state on Windows")
        install_command = [shell, "-NoProfile", "-File", str(snapshot / "install.ps1"), "-SourceDirectory", str(snapshot), "-InstallRoot", str(install_root), "-Target", "FilesOnly", "-SkipAgentInstall", "-SkipMcp"]
        uninstall_command = [shell, "-NoProfile", "-File", str(snapshot / "uninstall.ps1"), "-InstallRoot", str(install_root), "-Target", "FilesOnly", "-SkipAgentUninstall", "-SkipMcpUninstall"]
    else:
        install_command = ["bash", str(snapshot / "install.sh"), "--source-directory", str(snapshot), "--install-root", str(install_root), "--target", "FilesOnly", "--skip-agent-install", "--skip-mcp"]
        uninstall_command = ["bash", str(snapshot / "uninstall.sh"), "--install-root", str(install_root), "--target", "FilesOnly", "--skip-agent-uninstall", "--skip-mcp-uninstall"]
    installed = run(install_command, cwd=snapshot, environment=environment)
    if installed.returncode != 0:
        raise RuntimeError(f"pinned install failed: {installed.stderr.decode('utf-8', 'replace').strip()}")
    install_manifest = filesystem_manifest(install_root)
    uninstalled = run(uninstall_command, cwd=snapshot, environment=environment)
    if uninstalled.returncode != 0:
        raise RuntimeError(f"pinned uninstall failed: {uninstalled.stderr.decode('utf-8', 'replace').strip()}")
    return install_manifest, filesystem_manifest(install_root)


def build_capture(repo: Path, destination: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="sdd-golden-source-") as temporary:
        workspace = Path(temporary)
        home = workspace / "home"
        home.mkdir()
        environment = fixed_environment(home)
        snapshot = workspace / "snapshot"
        extract_snapshot(repo, snapshot, environment)
        initialize_git_snapshot(snapshot, environment)

        generator = snapshot / "plugins/sdd-quality-loop/scripts/generate-guard-invariants.py"
        generated = run([sys.executable, str(generator), "--check"], cwd=snapshot, environment=environment)
        tuple_value = raw_tuple(generated.stdout, generated.stderr)
        write_target(destination, TARGETS[0][1], tuple_value)
        write_target(destination, TARGETS[1][1], f"{generated.returncode}\n".encode("ascii"))
        write_target(destination, TARGETS[2][1], tuple_value)

        copied_templates = workspace / "template-copy"
        copied_templates.mkdir()
        for source in sorted(snapshot.glob("plugins/*/templates")):
            shutil.copytree(source, copied_templates / source.parent.name)
        write_target(destination, TARGETS[3][1], filesystem_manifest(copied_templates))

        schema_status = 0
        try:
            for schema in sorted((snapshot / "contracts").glob("*.schema.json")):
                json.loads(schema.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError):
            schema_status = 1
        write_target(destination, TARGETS[4][1], f"{schema_status}\n".encode("ascii"))

        install_manifest, uninstall_manifest = capture_install_state(snapshot, workspace, environment)
        write_target(destination, TARGETS[5][1], install_manifest)
        write_target(destination, TARGETS[6][1], uninstall_manifest)
        write_target(destination, TARGETS[7][1], directory_listing(snapshot / "plugins/sdd-quality-loop/scripts/generated"))

        plugin_files = workspace / "plugin-manifests"
        plugin_files.mkdir()
        for source in sorted(snapshot.glob("plugins/*/.*-plugin/plugin.json")):
            relative = source.relative_to(snapshot)
            target = plugin_files / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
        write_target(destination, TARGETS[8][1], filesystem_manifest(plugin_files))

    scripts = []
    for relative in ("tests/capture-golden-baseline.sh", "tests/capture-golden-baseline.ps1"):
        path = repo / relative
        if not path.is_file():
            raise RuntimeError(f"capture twin is missing: {relative}")
        scripts.append({"path": relative, "sha256": sha256(path)})
    targets = [
        {"name": name, "path": relative, "capture_format": capture_format, "sha256": sha256(destination / relative)}
        for name, relative, capture_format in TARGETS
    ]
    manifest = {
        "capture_scripts": scripts,
        "fixed_environment": {"LC_ALL": "C", "TZ": "UTC", "ambient_sdd_variables": []},
        "pre_capability_commit_sha": PRE_CAPABILITY_SHA,
        "schema_version": SCHEMA_VERSION,
        "targets": targets,
    }
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")


def snapshot(path: Path) -> dict[str, bytes]:
    if not path.is_dir():
        return {}
    return {item.relative_to(path).as_posix(): item.read_bytes() for item in sorted(path.rglob("*")) if item.is_file()}


def main() -> int:
    repo = Path(sys.argv[1]).resolve()
    mode = sys.argv[2]
    baseline = repo / BASELINE_RELATIVE
    canonical = baseline / "canonical"
    with tempfile.TemporaryDirectory(prefix="sdd-golden-capture-") as temporary:
        fresh = Path(temporary) / "capture"
        fresh.mkdir()
        build_capture(repo, fresh)
        if mode == "check":
            if snapshot(fresh) != snapshot(canonical):
                print("golden baseline drift detected", file=sys.stderr)
                return 1
            print("golden baseline matches canonical")
            return 0
        candidate = baseline / "candidate" / "current"
        candidate.parent.mkdir(parents=True, exist_ok=True)
        if candidate.exists():
            shutil.rmtree(candidate)
        shutil.copytree(fresh, candidate)
        print(f"golden baseline candidate written: {candidate.relative_to(repo).as_posix()}")
        return 0


try:
    raise SystemExit(main())
except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
    print(f"capture-golden-baseline: {exc}", file=sys.stderr)
    raise SystemExit(1)
PY
