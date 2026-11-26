"""Exercise ordinary file handling through each revision's public strict-mode CLI."""
import hashlib
import json
import os
import subprocess
import tempfile
from pathlib import Path

BASE = "cc4c4427ddfde62a5cb03deebd5f3b3bdb303d08"
CANDIDATE = "517ac392a19bbdef2ab8a4c3201f307395b8891c"
SOURCE = "plugins/sdd-quality-loop/scripts/v2"
MODULES = ("guardrails-lib.mjs", "v2-pure-lib.mjs", "run-security-gate.mjs")
ADAPTERS = ("builtin-secret-pattern", "builtin-slopsquatting")
MANIFEST = '{"name":"ordinary-example","private":true,"dependencies":{"react":"18.2.0"}}\n'
ROOT = Path(__file__).resolve().parents[5]


def command(args, *, cwd=ROOT, check=True):
    return subprocess.run(["rtk", "proxy", *args], cwd=cwd, capture_output=True, check=check)


def run_revision(revision, sandbox):
    modules = sandbox / "source"
    modules.mkdir(parents=True)
    hashes = {}
    for name in MODULES:
        rel = f"{SOURCE}/{name}"
        data = command(["git", "show", f"{revision}:{rel}"]).stdout
        (modules / name).write_bytes(data)
        hashes[rel] = hashlib.sha256(data).hexdigest()
    fixture = sandbox / "ordinary-project"
    fixture.mkdir()
    command(["git", "init", "-q"], cwd=fixture)
    for subdir in ("deleted", "present", "unreadable", "directory"):
        (fixture / subdir).mkdir()
    for subdir in ("deleted", "present", "unreadable"):
        (fixture / subdir / "package.json").write_text(MANIFEST)
    command(["git", "add", "."], cwd=fixture)
    (fixture / "deleted/package.json").unlink()
    deleted = command(["git", "diff", "--name-only", "--diff-filter=D"], cwd=fixture).stdout.decode().splitlines()
    assert deleted == ["deleted/package.json"], deleted
    (fixture / "directory/package.json").mkdir()
    denied = fixture / "unreadable/package.json"
    denied.chmod(0o000)
    try:
        try:
            denied.read_bytes()
        except PermissionError:
            pass
        else:
            raise RuntimeError("The permission-denied fixture requires an unprivileged user.")
        cases = {"trackedDeletion": deleted, "absent": ["missing/package.json"],
                 "readable": ["present/package.json"], "mixed": [*deleted, "present/package.json"],
                 "directory": ["directory/package.json"], "readDenied": ["unreadable/package.json"]}
        observations = []
        for case, paths in cases.items():
            for adapter in ADAPTERS:
                result = command(["node", str(modules / MODULES[-1]), "--root", str(fixture),
                                  "--files", ",".join(paths), "--adapters", adapter, "--mode", "strict", "--ci"],
                                 check=False)
                public = json.loads(result.stdout)
                read_error = case in ("directory", "readDenied")
                regression = revision == BASE and adapter == ADAPTERS[1] and case in ("trackedDeletion", "absent", "mixed")
                expect_error = read_error or regression
                expected = {"schema": "sdd-security-gate/v1", "mode": "strict", "adaptersRun": [adapter],
                            "status": "TOOL_ERROR" if expect_error else "PASS", "exitCode": 2 if expect_error else 0,
                            "findings": [], "warnings": []}
                if expect_error:
                    code = "UNREADABLE_SCAN_INPUT" if adapter == ADAPTERS[0] else "UNREADABLE_MANIFEST"
                    expected["errors"] = [{"code": code}]
                assert public == expected and not result.stderr and result.returncode == public["exitCode"], (case, public)
                observations.append({"case": case, "files": paths, "processExit": result.returncode,
                                     "stderrBytes": len(result.stderr), "public": public})
        return {"revision": revision, "moduleSHA256": hashes, "gitReportedDeleted": deleted, "observations": observations}
    finally:
        denied.chmod(0o600)


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as directory:
        print(json.dumps({"node": command(["node", "--version"]).stdout.decode().strip(),
                          "git": command(["git", "--version"]).stdout.decode().strip(),
                          "trackedFixtureContent": MANIFEST, "versions": [
                              run_revision(rev, Path(directory) / rev) for rev in (BASE, CANDIDATE)]},
                         indent=2))
