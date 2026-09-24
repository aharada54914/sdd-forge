#!/usr/bin/env python3
"""Cross-runtime TEST-022/TEST-023 fixture driver with exact JSON oracles."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parents[3]
HOOKS = Path("plugins/sdd-quality-loop/hooks")
MCP_NAMES = ("sdd-forge-mcp", "local-env-mcp", "ci-mcp")


def digest_bytes(data: bytes) -> str:
    return "sha256:" + hashlib.sha256(data).hexdigest()


def node_bytes(path: Path) -> bytes:
    if path.is_symlink():
        return os.readlink(path).encode("utf-8")
    return path.read_bytes()


def tree_digest(paths: list[Path]) -> str:
    hasher = hashlib.sha256()
    for root in paths:
        hasher.update(("root:" + str(root.resolve()) + "\0").encode())
        if not root.exists() and not root.is_symlink():
            hasher.update(b"missing\0")
            continue
        nodes = [root]
        if root.is_dir():
            nodes.extend(sorted(root.rglob("*"), key=lambda item: item.as_posix()))
        for node in nodes:
            rel = "." if node == root else node.relative_to(root).as_posix()
            if node.is_symlink():
                kind, payload = "link", os.readlink(node).encode()
            elif node.is_dir():
                kind, payload = "dir", b""
            else:
                kind, payload = "file", node.read_bytes()
            hasher.update(f"{rel}\0{kind}\0".encode())
            hasher.update(payload)
            hasher.update(b"\0")
    return hasher.hexdigest()


def current_block(name: str, install_root: Path, *, content_suffix: str = "") -> bytes:
    entry = (install_root / "mcp" / name / "dist" / "index.js").resolve().as_posix()
    lines = [
        f"# >>> {name} (managed by sdd-forge installer; do not edit by hand) >>>",
        f"[mcp_servers.{name}]",
        'command = "node"',
        f'args = ["{entry}"]{content_suffix}',
        f"# <<< {name} <<<",
    ]
    return (os.linesep.join(lines) + os.linesep).encode()


def stale_block(name: str, install_root: Path) -> bytes:
    entry = (install_root / "mcp" / name / "dist" / "index.js").resolve().as_posix()
    lines = [
        f"# >>> {name} (managed by prior sdd-forge installer) >>>",
        f"[mcp_servers.{name}]",
        'command = "node"',
        f'args = ["{entry}"]',
        f"# <<< {name} (prior) <<<",
    ]
    return (os.linesep.join(lines) + os.linesep).encode()


def install_snapshot(root: Path, codex_home: Path) -> None:
    tracked = subprocess.run(
        ["git", "-C", str(REPO), "ls-files", "-z", "--", "plugins"],
        stdout=subprocess.PIPE, check=True,
    ).stdout.split(b"\0")
    for raw in tracked:
        if not raw:
            continue
        relative = Path(os.fsdecode(raw))
        source = REPO / relative
        destination = root / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        if source.is_symlink():
            destination.symlink_to(os.readlink(source))
        else:
            shutil.copy2(source, destination)
    shutil.copytree(REPO / ".codex" / "agents", codex_home / "agents", symlinks=True)
    for name in MCP_NAMES:
        src = REPO / "mcp" / name
        dst = root / "mcp" / name
        (dst / "dist").mkdir(parents=True)
        shutil.copy2(src / "dist" / "index.js", dst / "dist" / "index.js")
        shutil.copy2(src / "package.json", dst / "package.json")
    codex_home.mkdir(parents=True, exist_ok=True)
    (codex_home / "config.toml").write_bytes(b"# user-owned prefix" + os.linesep.encode() + b"".join(
        current_block(name, root) for name in MCP_NAMES
    ))


def command_for(runtime: str, checker: Path, root: Path, mode: str) -> list[str]:
    if checker.suffix == ".py":
        return [sys.executable, str(checker), "--install-root", str(root), "--mode", mode]
    if runtime == "sh":
        return ["bash", str(checker), "--install-root", str(root), "--mode", mode]
    return ["pwsh", "-NoLogo", "-NoProfile", "-File", str(checker),
            "-InstallRoot", str(root), "-Mode", mode]


def invoke(runtime: str, checker: Path, root: Path, codex_home: Path, mode: str) -> tuple[int, dict]:
    protected = [REPO, root, codex_home]
    before = tree_digest(protected)
    env = os.environ.copy()
    env["SDD_CODEX_HOME"] = str(codex_home)
    result = subprocess.run(command_for(runtime, checker, root, mode), cwd=REPO,
                            env=env, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, check=False)
    after = tree_digest(protected)
    if before != after:
        raise AssertionError("checker modified the repository, install root, or Codex home")
    try:
        report = json.loads(result.stdout)
    except Exception as exc:
        raise AssertionError(f"non-JSON stdout: {result.stdout!r}; stderr={result.stderr!r}") from exc
    return result.returncode, report


def assert_contract(report: dict, root: Path, mode: str, state: str) -> None:
    assert report["schema"] == "installed-plugin-drift-report/v1", "schema mismatch"
    assert report["mode"] == mode, "mode mismatch"
    assert report["install_root"] == str(root.resolve()), "install_root mismatch"
    assert report["state"] == state, f"state mismatch: got {report['state']}, expected {state}"
    assert isinstance(report["diverged"], list), "diverged is not an array"
    assert set(report) == {"schema", "mode", "install_root", "state", "diverged"}, "field-set mismatch"


def report_entry(surface: str, source_ref: str, installed_ref: str,
                 change_type: str, installed: bytes | None, repo: bytes | None) -> dict:
    return {
        "surface": surface,
        "source_ref": source_ref,
        "installed_ref": installed_ref,
        "change_type": change_type,
        "installed_sha256": None if installed is None else digest_bytes(installed),
        "repo_sha256": None if repo is None else digest_bytes(repo),
    }


def run_case(label: str, runtime: str, checker: Path, root: Path, codex: Path,
             mode: str, exit_code: int, state: str) -> dict:
    try:
        actual_exit, report = invoke(runtime, checker, root, codex, mode)
        assert_contract(report, root, mode, state)
        assert actual_exit == exit_code, (actual_exit, exit_code)
        print(f"ok {label}")
        return report
    except Exception as exc:
        print(f"not ok {label}: {exc}")
        raise


def contract_mismatch_self_check(root: Path) -> None:
    """Prove every persisted field is guarded by an independently failing oracle."""
    expected_entry = report_entry("file", "plugins/source", "plugins/installed",
                                  "modified", b"installed", b"source")
    valid = {
        "schema": "installed-plugin-drift-report/v1",
        "mode": "verify",
        "install_root": str(root.resolve()),
        "state": "installed_drifted",
        "diverged": [expected_entry],
    }

    def must_fail(label: str, check) -> None:
        try:
            check()
        except (AssertionError, KeyError):
            print(f"ok contract-mismatch-self-check {label}")
            return
        raise AssertionError(f"mismatch oracle did not fail for {label}")

    for field, wrong in (("schema", "wrong/v1"), ("mode", "preflight"),
                         ("install_root", str(root / "wrong")),
                         ("state", "installed_synced")):
        candidate = json.loads(json.dumps(valid))
        candidate[field] = wrong
        must_fail(field, lambda candidate=candidate: assert_contract(
            candidate, root, "verify", "installed_drifted"))
    for field, wrong in (("surface", "delimited-region"),
                         ("source_ref", "plugins/wrong-source"),
                         ("installed_ref", "plugins/wrong-installed"),
                         ("change_type", "removed"),
                         ("installed_sha256", None),
                         ("repo_sha256", None)):
        candidate = json.loads(json.dumps(expected_entry))
        candidate[field] = wrong
        must_fail(field, lambda candidate=candidate: (
            candidate == expected_entry or (_ for _ in ()).throw(AssertionError(field))))


def wrapper_contract_checks(runtime: str, checker: Path, base: Path) -> None:
    invalid = subprocess.run(command_for(runtime, checker, base / "invalid", "Preflight"),
                             cwd=REPO, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             text=True, check=False)
    assert invalid.returncode != 0, "mis-cased mode was accepted"
    print(f"ok wrapper-contract {runtime} rejects mis-cased mode")

    if checker.suffix == ".py":
        command = [sys.executable, str(checker)]
    elif runtime == "sh":
        command = ["bash", str(checker)]
    else:
        command = ["pwsh", "-NoLogo", "-NoProfile", "-File", str(checker)]
    if runtime == "sh":
        env = os.environ.copy()
        env["XDG_DATA_HOME"] = str(base / "xdg")
        default_root = base / "xdg" / "sdd-plugins"
    elif os.name == "nt":
        env = os.environ.copy()
        env["LOCALAPPDATA"] = str(base / "local-app-data")
        default_root = base / "local-app-data" / "sdd-plugins"
    else:
        print("ok wrapper-contract ps1 Windows default deferred to Windows CI")
        return
    codex = base / "default-codex"
    install_snapshot(default_root, codex)
    env["SDD_CODEX_HOME"] = str(codex)
    before = tree_digest([REPO, default_root, codex])
    result = subprocess.run(command, cwd=REPO, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    after = tree_digest([REPO, default_root, codex])
    assert before == after, "default-path invocation wrote to a protected tree"
    report = json.loads(result.stdout)
    assert result.returncode == 0
    assert_contract(report, default_root, "preflight", "installed_synced")
    print(f"ok wrapper-contract {runtime} platform default and preflight default")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime", choices=("sh", "ps1"), required=True)
    parser.add_argument("--checker", type=Path, required=True)
    args = parser.parse_args()
    checker = args.checker.resolve()
    failures: list[str] = []

    with tempfile.TemporaryDirectory(prefix="installed-plugin-drift-") as tmp:
        base = Path(tmp)
        try:
            contract_mismatch_self_check(base / "contract-root")
            wrapper_contract_checks(args.runtime, checker, base / "wrapper-contract")
        except Exception as exc:
            failures.append(f"contract-mismatch-self-check: {exc}")
        missing = base / "not-installed"
        missing_codex = base / "not-installed-codex"
        for mode, expected_exit in (("preflight", 0), ("verify", 1)):
            try:
                report = run_case(f"TEST-023 not_installed {mode}", args.runtime, checker,
                                  missing, missing_codex, mode, expected_exit, "not_installed")
                assert report["diverged"] == []
            except Exception as exc:
                failures.append(f"not_installed/{mode}: {exc}")

        synced = base / "synced"
        synced_codex = base / "synced-codex"
        install_snapshot(synced, synced_codex)
        for mode in ("preflight", "verify"):
            try:
                report = run_case(f"TEST-023 installed_synced {mode}", args.runtime, checker,
                                  synced, synced_codex, mode, 0, "installed_synced")
                assert report["diverged"] == []
            except Exception as exc:
                failures.append(f"installed_synced/{mode}: {exc}")

        drift = base / "drift"
        drift_codex = base / "drift-codex"
        install_snapshot(drift, drift_codex)
        claude = drift / HOOKS / "claude-hooks.json"
        hooks = drift / HOOKS / "hooks.json"
        copilot = drift / HOOKS / "copilot-hooks.json"
        claude.unlink()
        hooks.write_bytes(hooks.read_bytes() + b"\ninstalled-cache-mutation\n")
        copilot.unlink()
        copilot.symlink_to("hooks.json")
        installed_only = drift / "plugins" / "installed-only.txt"
        installed_only.write_bytes(b"installed only\n")
        config = drift_codex / "config.toml"
        legacy = current_block("legacy-mcp", drift)
        config.write_bytes(
            b"# user-owned prefix" + os.linesep.encode()
            + current_block("local-env-mcp", drift, content_suffix=" # drift")
            + stale_block("ci-mcp", drift)
            + legacy
        )
        expected = [
            report_entry("file", (HOOKS / "claude-hooks.json").as_posix(),
                         (HOOKS / "claude-hooks.json").as_posix(), "added", None,
                         (REPO / HOOKS / "claude-hooks.json").read_bytes()),
            report_entry("file", (HOOKS / "copilot-hooks.json").as_posix(),
                         (HOOKS / "copilot-hooks.json").as_posix(), "type-changed",
                         node_bytes(copilot), (REPO / HOOKS / "copilot-hooks.json").read_bytes()),
            report_entry("file", (HOOKS / "hooks.json").as_posix(),
                         (HOOKS / "hooks.json").as_posix(), "modified",
                         hooks.read_bytes(), (REPO / HOOKS / "hooks.json").read_bytes()),
            report_entry("file", "plugins/installed-only.txt", "plugins/installed-only.txt",
                         "removed", installed_only.read_bytes(), None),
            report_entry("delimited-region", "install.sh#register_codex_mcp/ci-mcp",
                         "$SDD_CODEX_HOME/config.toml#ci-mcp", "type-changed",
                         stale_block("ci-mcp", drift), current_block("ci-mcp", drift)),
            report_entry("delimited-region", "install.sh#register_codex_mcp/legacy-mcp",
                         "$SDD_CODEX_HOME/config.toml#legacy-mcp", "added",
                         legacy, None),
            report_entry("delimited-region", "install.sh#register_codex_mcp/local-env-mcp",
                         "$SDD_CODEX_HOME/config.toml#local-env-mcp", "modified",
                         current_block("local-env-mcp", drift, content_suffix=" # drift"),
                         current_block("local-env-mcp", drift)),
            report_entry("delimited-region", "install.sh#register_codex_mcp/sdd-forge-mcp",
                         "$SDD_CODEX_HOME/config.toml#sdd-forge-mcp", "removed",
                         None, current_block("sdd-forge-mcp", drift)),
        ]
        expected.sort(key=lambda row: (row["surface"], row["source_ref"], row["installed_ref"]))
        for mode in ("preflight", "verify"):
            try:
                report = run_case(f"TEST-022 all surfaces and TEST-023 drift {mode}",
                                  args.runtime, checker, drift, drift_codex, mode, 1,
                                  "installed_drifted")
                assert report["diverged"] == expected
                for surface in ("file", "delimited-region"):
                    for change in ("added", "removed", "modified", "type-changed"):
                        assert any(row["surface"] == surface and row["change_type"] == change
                                   for row in report["diverged"])
                        print(f"ok TEST-022 {surface}/{change} exact entry")
            except Exception as exc:
                for surface in ("file", "delimited-region"):
                    for change in ("added", "removed", "modified", "type-changed"):
                        print(f"not ok TEST-022 {surface}/{change} exact entry: {exc}")
                failures.append(f"drift/{mode}: {exc}")

        lifecycle = base / "negative-lifecycle"
        lifecycle_codex = base / "negative-lifecycle-codex"
        install_snapshot(lifecycle, lifecycle_codex)
        try:
            initial = run_case("TEST-022 negative lifecycle initial sync", args.runtime,
                               checker, lifecycle, lifecycle_codex, "verify", 0,
                               "installed_synced")
            assert initial["diverged"] == []
            target = lifecycle / HOOKS / "hooks.json"
            target.write_bytes(target.read_bytes() + b"\npost-install mutation\n")
            report = run_case("TEST-022 negative lifecycle detects later mutation",
                              args.runtime, checker, lifecycle, lifecycle_codex,
                              "verify", 1, "installed_drifted")
            expected_one = report_entry("file", (HOOKS / "hooks.json").as_posix(),
                                        (HOOKS / "hooks.json").as_posix(), "modified",
                                        target.read_bytes(), (REPO / HOOKS / "hooks.json").read_bytes())
            assert report["diverged"] == [expected_one]
        except Exception as exc:
            failures.append(f"negative-lifecycle: {exc}")

    if failures:
        print(f"FAIL {len(failures)} case group(s)")
        for failure in failures:
            print(f"  {failure}")
        return 1
    print("PASS TEST-022 and TEST-023; read-only digest assertions passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
