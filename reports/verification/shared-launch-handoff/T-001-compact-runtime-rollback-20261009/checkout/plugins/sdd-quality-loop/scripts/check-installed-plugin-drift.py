#!/usr/bin/env python3
"""Read-only comparison of an installed SDD plugin cache with this source tree."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
from typing import Iterable

SCHEMA = "installed-plugin-drift-report/v1"
CURRENT_BEGIN = "# >>> {name} (managed by sdd-forge installer; do not edit by hand) >>>"
CURRENT_END = "# <<< {name} <<<"
PRIOR_BEGIN_RE = re.compile(
    r"^# >>> ([A-Za-z0-9._-]+) \(managed by .*sdd-forge installer.*\) >>>$"
)
PRIOR_END_RE = re.compile(r"^# <<< ([A-Za-z0-9._-]+)(?: .*?)? <<<$")


def sha256(data: bytes) -> str:
    return "sha256:" + hashlib.sha256(data).hexdigest()


def kind_and_bytes(path: Path) -> tuple[str, bytes] | None:
    try:
        mode = path.lstat().st_mode
    except FileNotFoundError:
        return None
    if stat.S_ISLNK(mode):
        return "symlink", os.readlink(path).encode("utf-8")
    if stat.S_ISREG(mode):
        return "file", path.read_bytes()
    if stat.S_ISDIR(mode):
        return "directory", b"directory\n"
    return "other", f"mode:{stat.S_IFMT(mode):o}\n".encode()


def relative_nodes(root: Path) -> dict[str, Path]:
    if not root.is_dir():
        return {}
    result: dict[str, Path] = {}
    for parent, directories, files in os.walk(root, followlinks=False):
        parent_path = Path(parent)
        for name in directories + files:
            path = parent_path / name
            if path.is_dir() and not path.is_symlink():
                continue
            result[path.relative_to(root).as_posix()] = path
    return result


def tracked_plugin_nodes(repo_root: Path) -> dict[str, Path]:
    """Return the Git-index surface the installer itself stages and copies."""
    result = subprocess.run(
        ["git", "-C", str(repo_root), "ls-files", "-z", "--", "plugins"],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False,
    )
    if result.returncode != 0:
        return relative_nodes(repo_root / "plugins")
    nodes: dict[str, Path] = {}
    for raw in result.stdout.split(b"\0"):
        if not raw:
            continue
        repo_relative = os.fsdecode(raw)
        plugin_relative = Path(repo_relative).relative_to("plugins").as_posix()
        nodes[plugin_relative] = repo_root / repo_relative
    return nodes


def entry(surface: str, source_ref: str, installed_ref: str, change_type: str,
          installed_data: bytes | None, repo_data: bytes | None) -> dict[str, object]:
    return {
        "surface": surface,
        "source_ref": source_ref,
        "installed_ref": installed_ref,
        "change_type": change_type,
        "installed_sha256": None if installed_data is None else sha256(installed_data),
        "repo_sha256": None if repo_data is None else sha256(repo_data),
    }


def compare_file_sets(repo_root: Path, installed_root: Path, source_prefix: str,
                      installed_prefix: str) -> list[dict[str, object]]:
    source = tracked_plugin_nodes(repo_root)
    installed = relative_nodes(installed_root)
    diverged: list[dict[str, object]] = []
    for rel in sorted(set(source) | set(installed)):
        source_node = kind_and_bytes(source[rel]) if rel in source else None
        installed_node = kind_and_bytes(installed[rel]) if rel in installed else None
        source_ref = f"{source_prefix}/{rel}"
        installed_ref = f"{installed_prefix}/{rel}"
        if installed_node is None:
            diverged.append(entry("file", source_ref, installed_ref, "added",
                                  None, source_node[1] if source_node else None))
        elif source_node is None:
            diverged.append(entry("file", source_ref, installed_ref, "removed",
                                  installed_node[1], None))
        elif installed_node[0] != source_node[0]:
            diverged.append(entry("file", source_ref, installed_ref, "type-changed",
                                  installed_node[1], source_node[1]))
        elif installed_node[1] != source_node[1]:
            diverged.append(entry("file", source_ref, installed_ref, "modified",
                                  installed_node[1], source_node[1]))
    return diverged


def compare_agents(repo_root: Path, codex_home: Path) -> list[dict[str, object]]:
    source_dir = repo_root / ".codex" / "agents"
    installed_dir = codex_home / "agents"
    source = {path.name: path for path in source_dir.glob("sdd-*.toml")}
    installed = ({path.name: path for path in installed_dir.glob("sdd-*.toml")}
                 if installed_dir.is_dir() else {})
    diverged: list[dict[str, object]] = []
    for name in sorted(set(source) | set(installed)):
        source_node = kind_and_bytes(source[name]) if name in source else None
        installed_node = kind_and_bytes(installed[name]) if name in installed else None
        source_ref = f".codex/agents/{name}"
        installed_ref = f"$SDD_CODEX_HOME/agents/{name}" if os.environ.get("SDD_CODEX_HOME") else f"~/.codex/agents/{name}"
        if installed_node is None:
            diverged.append(entry("file", source_ref, installed_ref, "added",
                                  None, source_node[1] if source_node else None))
        elif source_node is None:
            diverged.append(entry("file", source_ref, installed_ref, "removed",
                                  installed_node[1], None))
        elif installed_node[0] != source_node[0]:
            diverged.append(entry("file", source_ref, installed_ref, "type-changed",
                                  installed_node[1], source_node[1]))
        elif installed_node[1] != source_node[1]:
            diverged.append(entry("file", source_ref, installed_ref, "modified",
                                  installed_node[1], source_node[1]))
    return diverged


def expected_block(name: str, install_root: Path) -> bytes:
    entry_point = (install_root / "mcp" / name / "dist" / "index.js").resolve().as_posix()
    lines = [
        CURRENT_BEGIN.format(name=name),
        f"[mcp_servers.{name}]",
        'command = "node"',
        f'args = ["{entry_point}"]',
        CURRENT_END.format(name=name),
    ]
    return (os.linesep.join(lines) + os.linesep).encode("utf-8")


def extract_regions(config: bytes) -> dict[str, tuple[bytes, bool]]:
    lines = config.splitlines(keepends=True)
    regions: dict[str, tuple[bytes, bool]] = {}
    index = 0
    while index < len(lines):
        line_text = lines[index].rstrip(b"\r\n").decode("utf-8", errors="replace")
        match = PRIOR_BEGIN_RE.match(line_text)
        if not match:
            index += 1
            continue
        name = match.group(1)
        end_index = index + 1
        while end_index < len(lines):
            end_text = lines[end_index].rstrip(b"\r\n").decode("utf-8", errors="replace")
            end_match = PRIOR_END_RE.match(end_text)
            if end_match and end_match.group(1) == name:
                block = b"".join(lines[index:end_index + 1])
                current = (line_text == CURRENT_BEGIN.format(name=name)
                           and end_text == CURRENT_END.format(name=name))
                regions[name] = (block, current)
                index = end_index + 1
                break
            end_index += 1
        else:
            index += 1
    return regions


def selected_mcps(install_root: Path) -> Iterable[str]:
    mcp_root = install_root / "mcp"
    if not mcp_root.is_dir():
        return ()
    return tuple(sorted(path.name for path in mcp_root.iterdir()
                        if path.is_dir() and (path / "dist" / "index.js").is_file()))


def compare_regions(install_root: Path, codex_home: Path) -> list[dict[str, object]]:
    config_path = codex_home / "config.toml"
    regions = extract_regions(config_path.read_bytes()) if config_path.is_file() else {}
    expected_names = set(selected_mcps(install_root))
    installed_ref_prefix = ("$SDD_CODEX_HOME/config.toml" if os.environ.get("SDD_CODEX_HOME")
                            else "~/.codex/config.toml")
    diverged: list[dict[str, object]] = []
    for name in sorted(expected_names | set(regions)):
        source_ref = f"install.sh#register_codex_mcp/{name}"
        installed_ref = f"{installed_ref_prefix}#{name}"
        expected = expected_block(name, install_root) if name in expected_names else None
        actual, current = regions.get(name, (None, False))
        if name not in expected_names:
            diverged.append(entry("delimited-region", source_ref, installed_ref,
                                  "added", actual, None))
        elif actual is None:
            diverged.append(entry("delimited-region", source_ref, installed_ref,
                                  "removed", None, expected))
        elif not current:
            diverged.append(entry("delimited-region", source_ref, installed_ref,
                                  "type-changed", actual, expected))
        elif actual != expected:
            diverged.append(entry("delimited-region", source_ref, installed_ref,
                                  "modified", actual, expected))
    return diverged


def build_report(mode: str, install_root: Path) -> tuple[dict[str, object], int]:
    resolved_root = install_root.expanduser().resolve()
    report: dict[str, object] = {
        "schema": SCHEMA,
        "mode": mode,
        "install_root": str(resolved_root),
        "state": "not_installed",
        "diverged": [],
    }
    if not resolved_root.is_dir():
        return report, 0 if mode == "preflight" else 1

    repo_root = Path(__file__).resolve().parents[3]
    codex_home_value = os.environ.get("SDD_CODEX_HOME")
    codex_home = (Path(codex_home_value).expanduser().resolve() if codex_home_value
                  else (Path.home() / ".codex").resolve())
    diverged = compare_file_sets(repo_root, resolved_root / "plugins",
                                 "plugins", "plugins")
    diverged.extend(compare_agents(repo_root, codex_home))
    diverged.extend(compare_regions(resolved_root, codex_home))
    diverged.sort(key=lambda row: (str(row["surface"]), str(row["source_ref"]),
                                   str(row["installed_ref"])))
    report["diverged"] = diverged
    report["state"] = "installed_drifted" if diverged else "installed_synced"
    return report, 1 if diverged else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install-root", required=True)
    parser.add_argument("--mode", choices=("preflight", "verify"), default="preflight")
    args = parser.parse_args()
    report, exit_code = build_report(args.mode, Path(args.install_root))
    json.dump(report, sys.stdout, sort_keys=True, separators=(",", ":"))
    sys.stdout.write("\n")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
