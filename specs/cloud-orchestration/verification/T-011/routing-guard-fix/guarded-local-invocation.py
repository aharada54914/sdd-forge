"""Fixture integration: real guard admission followed by the unchanged installed CLI."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[5]
EVIDENCE = Path(__file__).resolve().parent


def main() -> None:
    spec = importlib.util.spec_from_file_location("routing", ROOT / "tests/cloud-orchestration-routing.tests.py")
    assert spec and spec.loader
    routing = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(routing)
    installed = routing.BootstrapInstalled
    installed.setUpClass()
    checks: list[dict] = []
    scripts = ROOT / "plugins/sdd-quality-loop/scripts"
    guards = {
        "python": [sys.executable, str(scripts / "sdd-hook-guard.py")],
        "node": [shutil.which("node") or "node", str(scripts / "sdd-hook-guard.js")],
        "bash": ["bash", str(scripts / "sdd-hook-guard.sh")],
        "powershell": ["/workspace/.tools/sdd-forge-dev/bin/pwsh", "-NoProfile", "-File", str(scripts / "sdd-hook-guard.ps1")],
    }
    test = installed()
    try:
        for provider in ("azure", "aws"):
            for bootstrap in (False, True):
                for phase in ("route", "prepare", "apply"):
                    case = test.fixture(provider)
                    case.put("request.json", case.req)
                    request = case.root / "request.json"
                    before = request.read_bytes()
                    plugin = installed.install / "plugins" / ("sdd-" + provider + "-cloud")
                    cli = installed.install / "plugins/sdd-bootstrap/scripts/cloud-routing.py" if bootstrap else plugin / "scripts/cloud.py"
                    args = ["python3", "-B", str(cli)]
                    if bootstrap:
                        args += ["--provider", provider, "--plugin-root", str(plugin)]
                    args += [phase, "--request", str(request), "--output", case.evidence + "/guarded.json"]
                    command = ("CLOUD_WORKSPACE_ROOT=" + shlex.quote(str(case.root)) + " "
                               "CLOUD_SHARED_RUNTIME_ROOT=" + shlex.quote(str(plugin / "runtime/scripts")) + " " + shlex.join(args))
                    payload = json.dumps({"cwd": str(case.root), "tool_name": "bash", "tool_input": {"command": command}})
                    env = {"PATH": os.defpath, "HOME": str(case.root), "CLAUDE_PROJECT_DIR": str(case.root)}
                    decisions = {}
                    for runtime, invocation in guards.items():
                        decision = subprocess.run(invocation + ["--emit", "copilot"], input=payload, text=True,
                                                  capture_output=True, cwd=case.root, env=env, timeout=30)
                        assert decision.returncode == 0, decision.stderr
                        decisions[runtime] = json.loads(decision.stdout)["permissionDecision"]
                        assert decisions[runtime] == "allow", decision.stdout
                    result = subprocess.run(["bash", "-c", command], capture_output=True, text=True,
                                            cwd=case.root, env=env, timeout=30)
                    expected = 0 if phase == "route" else 2
                    assert result.returncode == expected, result.stderr + result.stdout
                    envelope = case.contracts.parse_artifact(result.stdout.encode())
                    assert envelope["state"] == ("ROUTED" if phase == "route" else "BLOCKED")
                    if phase != "route":
                        assert envelope["error_code"] == "OPERATION_UNIMPLEMENTED"
                    assert request.read_bytes() == before
                    checks.append(dict(provider=provider,entry="bootstrap" if bootstrap else "direct",
                                       operation=phase,guard_decisions=decisions,exit_code=result.returncode,
                                       state=envelope["state"],error_code=envelope["error_code"],
                                       request_sha256=hashlib.sha256(before).hexdigest()))
    finally:
        test.doCleanups()
        installed.doClassCleanups()
    (EVIDENCE / "guarded-local-invocation.json").write_text(json.dumps(dict(
        classification="local fixture; actual installed subprocesses; no model host or cloud execution",
        checks=checks), indent=2) + "\n")
    print(f"{len(checks)} guarded installed CLI calls passed; canonical requests unchanged")


if __name__ == "__main__":
    main()
