#!/usr/bin/env python3
"""Replay the existing F2 response with a real F5/F6 Context/Resolver invocation.

This is the offline recorded-response seam, not a new live-model capture.
Human Markdown and machine Resolver outputs are checked independently.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def exercise(state, runtime):
    spec = importlib.util.spec_from_file_location("structural_resolver_fixture", ROOT / "tests/resolve-project-context-block-check.py")
    driver = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(driver)
    response = json.loads((ROOT / "tests/fixtures/structural-fixture-corpus/f2-lite.json").read_text(encoding="utf-8"))
    expected_paths = {"requirements.md", "design.md", "tasks.md"}
    if response["fixture_state"] != "F2" or {a["path"] for a in response["artifacts"]} != expected_paths or len(response["artifacts"]) != 3:
        raise ValueError("recorded Lite response must contain exactly the three human artifacts")
    enforcement = {"F5": "advisory", "F6": "required"}[state]
    with tempfile.TemporaryDirectory(prefix="structural-context-lite-") as directory:
        repo = Path(directory).resolve()
        subprocess.run(["git", "init", "-q", str(repo)], check=True)
        # install_scripts() in the older generic fixture driver reads a staged
        # archive. These assertions must execute today's product in both twins.
        scripts = repo / "plugins/sdd-quality-loop/scripts"
        scripts.mkdir(parents=True)
        for name in ("resolve-project-context.py", "resolve-project-context.sh", "resolve-project-context.ps1",
                     "canonicalize-sdd-yaml.py"):
            shutil.copy2(ROOT / "plugins/sdd-quality-loop/scripts" / name, scripts / name)
        (repo / "contracts").mkdir()
        shutil.copy2(ROOT / "contracts/project-context.schema.json", repo / "contracts/project-context.schema.json")
        registry = ROOT / "contracts/capability-registry.json"
        driver.install_t003_dependencies(repo, scripts, ROOT, registry_capabilities_path=registry)
        for gate in json.loads(registry.read_text(encoding="utf-8"))["gates"]:
            destination = repo / gate["implementation_ref"]
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / gate["implementation_ref"], destination)
        # This change is deliberately unmatched by Pack predicates, so the Lite
        # track remains eligible in both enforcement modes. No risk downgrade.
        (repo / "project-context.yaml").write_text(
            "schema: sdd-project-context/v1\nworkflow:\n  spec_profile: lite\n"
            "  artifact_layout: lite-three-file\n  capability_enforcement: " + enforcement +
            "\ncomponents:\n  - id: app\n    artifact_kinds:\n      - other\n"
            "    paths:\n      include:\n        - app/**\n", encoding="utf-8")
        feature = repo / "specs/team-coffee-orders"
        feature.mkdir(parents=True)
        originals = {}
        for artifact in response["artifacts"]:
            data = artifact["content"].encode("utf-8")
            (feature / artifact["path"]).write_bytes(data)
            originals[artifact["path"]] = data
        source = driver.git_commit_all(repo, "synthetic recorded-response baseline")
        (repo / "app").mkdir()
        (repo / "app/change.txt").write_text("synthetic change\n", encoding="utf-8")
        target = driver.git_commit_all(repo, "synthetic Context-present change")
        args = driver.launcher_args(runtime, scripts) + ["--config", "project-context.yaml",
            "--source-rev", source, "--target-rev", target, "--feature", "team-coffee-orders"]
        result = subprocess.run(args, cwd=repo, text=True, capture_output=True)
        if result.returncode:
            raise ValueError("real Context-present Resolver failed: " + result.stderr)
        evidence = json.loads((feature / "resolver-evidence.yaml").read_text(encoding="utf-8"))
        summary = json.loads((feature / "capability-summary.yaml").read_text(encoding="utf-8"))
        if evidence["state"] != enforcement or evidence["diagnostics"]:
            raise ValueError("Resolver must observe the requested advisory/required Context state")
        if summary != {"schema": "sdd-capability-summary/v1", "feature": "team-coffee-orders",
                       "track": "lite", "capabilities": [], "required_lite_checks": [], "full_upgrade_required": False}:
            raise ValueError("Context-present response did not preserve the eligible Lite track")
        if {p.name for p in feature.iterdir()} != expected_paths | {"resolver-evidence.yaml", "capability-summary.yaml"}:
            raise ValueError("unexpected human or machine artifact in the Lite output")
        if (scripts / "generated/project-context.resolved.json").exists():
            raise ValueError("Lite publication must not emit the Full Context Projection")
        for name, data in originals.items():
            if (feature / name).read_bytes() != data:
                raise ValueError("Context processing altered recorded human Markdown")
        response["fixture_state"] = state
        response["injection_source_fixture"] = "F2"
        response["observed_context_state"] = evidence["state"]
        response["artifacts"] = [{"path": name, "content": (feature / name).read_text(encoding="utf-8")}
                                 for name in sorted(expected_paths)]
        return response


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", choices=("F5", "F6"), required=True)
    parser.add_argument("--runtime", choices=("sh", "ps1"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = exercise(args.state, args.runtime)
    args.output.write_text(json.dumps(output, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
