"""Reproduce genuine local CLI/compile evidence with explicitly synthetic targets."""
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[6]
OUT = Path(__file__).resolve().parent
IDENTITY = "01a14d9e-7a63-71c2-a07c-aa71d275b9de"


def now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def main():
    spec = importlib.util.spec_from_file_location("azure_native_fixture", ROOT / "tests/cloud-orchestration-routing.tests.py")
    assert spec and spec.loader
    tests = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(tests)
    records = []
    for label, modular in (("native", False), ("modular", True)):
        case = tests.AzureNativePreparation()
        case.setUp()
        try:
            if modular:
                case.install_independent_module()
            case.put("draft-request.json", case.req)
            request_path = "draft-request.json"
            env = {"PATH": os.defpath, "HOME": str(case.root), "CLOUD_WORKSPACE_ROOT": str(case.root),
                   "CLOUD_BICEP_BIN": str(case.binary), "PYTHONDONTWRITEBYTECODE": "1"}
            for phase in ("route", "plan", "validate"):
                output = case.evidence + "/" + phase + ".json"
                cmd = [sys.executable, "-B", str(tests.CLI), phase, "--request", request_path, "--output", output]
                started = now()
                proc = subprocess.run(cmd, cwd=case.root, env=env, capture_output=True, timeout=90)
                ended = now()
                (OUT / (label + "-" + phase + ".stdout.json")).write_bytes(proc.stdout)
                (OUT / (label + "-" + phase + ".stderr.log")).write_bytes(proc.stderr)
                records.append(dict(label=label, command=cmd, cwd=str(case.root), start_utc=started,
                                    end_utc=ended, exit_code=proc.returncode,
                                    classification="native-local-compiler-with-synthetic-target",
                                    stdout_sha256=hashlib.sha256(proc.stdout).hexdigest(),
                                    stderr_sha256=hashlib.sha256(proc.stderr).hexdigest()))
                assert proc.returncode == 0, proc.stdout
                result = tests.load_contracts().parse_artifact(proc.stdout)
                manifest = json.loads((case.root/result["evidence_manifest_path"]).read_bytes())
                if phase == "plan":
                    request_path = manifest["locked_request"]["path"]
            destination = OUT / (label + "-workspace")
            assert not destination.exists(), "Evidence is immutable; choose a new capture directory"
            shutil.copytree(case.root, destination)
        finally:
            case.doCleanups()
    binary = Path("/workspace/.tools/cloud/bicep/0.48.1/bicep")
    tool = subprocess.run([str(binary), "--version"], capture_output=True, timeout=15)
    (OUT / "bicep-version.log").write_bytes(tool.stdout + tool.stderr)
    (OUT / "native-execution.json").write_text(json.dumps(dict(
        run_id=IDENTITY, session_id=IDENTITY, agent_instance_id=IDENTITY,
        classification="Local processes only. Synthetic IDs/policies are not approved live scope.",
        python_version=sys.version, commands=records,
        compiler=dict(path=str(binary), version_stdout=tool.stdout.decode().strip(), version_exit=tool.returncode,
                      sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
                      asset_id=603718396, package="bicep-linux-x64",
                      release_url="https://github.com/Azure/bicep/releases/tag/v0.48.1")), indent=2) + "\n")


if __name__ == "__main__":
    main()
