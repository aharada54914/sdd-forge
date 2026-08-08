#!/usr/bin/env python3
"""T-002 Block-matrix driver shared by the POSIX and PowerShell twins."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/capability-resolver/resolve-project-context-block"
STAGED = (
    ROOT
    / "specs/epic-193-a5-capability-resolver/verification/T-002/staged"
    / "plugins/sdd-quality-loop/scripts"
)
SCHEMA = ROOT / "contracts/resolver-evidence.schema.json"
SCHEMA_CHECK = ROOT / "tests/resolver-evidence-schema-check.py"

CASES = (
    ("disabled-legacy-invocation", "absent", "disabled-legacy-invocation", "sdd/project-context.yaml", "disabled-legacy"),
    ("workflow-combination-invalid-lite", "workflow-combination-invalid/lite-wrong-layout.yaml", "workflow-combination-invalid", "workflow spec_profile/artifact_layout combination is invalid", "advisory"),
    ("workflow-combination-invalid-full", "workflow-combination-invalid/full-lite-layout.yaml", "workflow-combination-invalid", "workflow spec_profile/artifact_layout combination is invalid", "required"),
    ("project-context-validation-failed", "project-context-validation-failed/missing-enforcement.yaml", "project-context-validation-failed", "project context does not conform to contracts/project-context.schema.json", None),
    ("canonicalizer-invocation-failed", "canonicalizer-invocation-failed/project-context.yaml", "canonicalizer-invocation-failed", "canonicalize-sdd-yaml failed while canonicalizing project context", None),
    ("dependency-output-malformed", "dependency-output-malformed/project-context.yaml", "dependency-output-malformed", "canonicalize-sdd-yaml returned malformed JSON while canonicalizing project context", None),
)


class Counts:
    def __init__(self):
        self.passed = 0
        self.failed = 0

    def check(self, condition, label, detail=""):
        if condition:
            self.passed += 1
            print(f"PASS: {label}")
        else:
            self.failed += 1
            suffix = f": {detail}" if detail else ""
            print(f"FAIL: {label}{suffix}")


def copy_inputs(repo, fixture_rel, case_name):
    scripts = repo / "plugins/sdd-quality-loop/scripts"
    scripts.mkdir(parents=True)
    for suffix in ("py", "sh", "ps1"):
        shutil.copy2(STAGED / f"resolve-project-context.{suffix}", scripts)
    shutil.copy2(ROOT / "plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py", scripts)
    contracts = repo / "contracts"
    contracts.mkdir()
    shutil.copy2(ROOT / "contracts/project-context.schema.json", contracts)
    config = repo / "sdd/project-context.yaml"
    config.parent.mkdir()
    if fixture_rel != "absent":
        shutil.copy2(FIXTURES / fixture_rel, config)
    if case_name in ("canonicalizer-invocation-failed", "dependency-output-malformed"):
        shutil.copy2(FIXTURES / case_name / "canonicalize-sdd-yaml.py", scripts / "canonicalize-sdd-yaml.py")


def launcher_args(kind, scripts):
    if kind == "sh":
        return ["sh", str(scripts / "resolve-project-context.sh")]
    return ["pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(scripts / "resolve-project-context.ps1")]


def run_case(kind, case, counts):
    case_name, fixture_rel, expected_id, expected_detail, expected_state = case
    with tempfile.TemporaryDirectory(prefix="resolver-block-") as tmp:
        repo = Path(tmp).resolve()
        subprocess.run(["git", "init", "-q", str(repo)], check=True)
        copy_inputs(repo, fixture_rel, case_name)
        scripts = repo / "plugins/sdd-quality-loop/scripts"
        feature_dir = repo / "specs/example-feature"
        feature_dir.mkdir(parents=True)
        sentinels = {
            feature_dir / "facet-manifest.yaml": b"facet-preimage\n",
            feature_dir / "capability-summary.yaml": b"summary-preimage\n",
            scripts / "generated/project-context.resolved.json": b"projection-preimage\n",
        }
        for path, value in sentinels.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(value)

        spy = repo / "subprocess-spy-fired"
        argv = launcher_args(kind, scripts) + [
            "--config", "sdd/project-context.yaml",
            "--target-rev", "HEAD",
            "--feature", "example-feature",
        ]
        env = os.environ.copy()
        env["PATH"] = str(repo / "spy-bin") + os.pathsep + env.get("PATH", "")
        spy_bin = repo / "spy-bin"
        spy_bin.mkdir()
        for name in ("resolve-component-paths", "validate-capability-registry"):
            path = spy_bin / name
            path.write_text(f"#!/bin/sh\nprintf fired > '{spy}'\nexit 91\n", encoding="utf-8", newline="\n")
            path.chmod(0o755)

        result = subprocess.run(argv, cwd=repo, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        stderr = result.stderr.decode("utf-8", errors="replace")
        stdout = result.stdout.decode("utf-8", errors="replace")
        expected_line = f"capability-resolver: {expected_id}: {expected_detail}\n"
        counts.check(result.returncode == 1, f"{case_name}: exit 1", f"got {result.returncode}")
        counts.check(stdout == "" and stderr == expected_line and "UPSTREAM_SECRET" not in stderr,
                     f"{case_name}: canonical diagnostic only", f"stdout={stdout!r} stderr={stderr!r}")

        evidence_path = feature_dir / "resolver-evidence.yaml"
        evidence = None
        try:
            evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            parse_error = str(exc)
        else:
            parse_error = ""
        expected = {
            "schema": "sdd-resolver-evidence/v1",
            "feature": "example-feature",
            "capability_evaluations": [],
            "diagnostics": [{"id": expected_id, "detail": expected_detail, "severity": "block"}],
        }
        if expected_state is not None:
            expected["state"] = expected_state
        counts.check(evidence == expected, f"{case_name}: exact Resolver Evidence", parse_error or repr(evidence))

        schema_result = subprocess.run(
            [sys.executable, str(SCHEMA_CHECK), str(SCHEMA), str(evidence_path), "valid"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        ) if evidence_path.is_file() else None
        counts.check(schema_result is not None and schema_result.returncode == 0,
                     f"{case_name}: Resolver Evidence schema agreement",
                     "evidence absent" if schema_result is None else schema_result.stderr.decode("utf-8", errors="replace"))
        unchanged = all(path.read_bytes() == value for path, value in sentinels.items())
        counts.check(unchanged, f"{case_name}: no partial live artifact")
        counts.check(not spy.exists(), f"{case_name}: no step-4-or-later subprocess")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--launcher", choices=("sh", "ps1"), required=True)
    args = parser.parse_args()
    counts = Counts()

    required = [STAGED / f"resolve-project-context.{suffix}" for suffix in ("py", "sh", "ps1")]
    if not all(path.is_file() for path in required):
        for case_name, *_ in CASES:
            counts.check(False, f"{case_name}: staged implementation exists", "TDD RED: implementation absent")
    else:
        for case in CASES:
            run_case(args.launcher, case, counts)

    sh_registered = "tests/resolve-project-context-block.tests.sh" in (ROOT / "tests/run-all.sh").read_text(encoding="utf-8")
    ps_registered = "tests/resolve-project-context-block.tests.ps1" in (ROOT / "tests/run-all.ps1").read_text(encoding="utf-8")
    counts.check(sh_registered, "POSIX suite registered in tests/run-all.sh")
    counts.check(ps_registered, "PowerShell suite registered in tests/run-all.ps1")

    print(f"RESULT: {counts.passed} passed, {counts.failed} failed")
    return 1 if counts.failed else 0


if __name__ == "__main__":
    sys.exit(main())
