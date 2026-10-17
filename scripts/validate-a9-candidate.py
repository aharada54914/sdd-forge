#!/usr/bin/env python3
"""Validate A9's unpublished Context and tracked ownership; never activate it."""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "plugins/sdd-quality-loop/scripts"


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), SCRIPTS / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


OWNERSHIP = load("resolve-component-paths")
RESOLVER = load("resolve-project-context")
PLUGIN_IDS = {"sdd-bootstrap", "sdd-review-loop", "sdd-implementation", "sdd-quality-loop",
              "sdd-ship", "sdd-lite", "sdd-domain"}


def validate(document, tracked_paths):
    errors = []
    if not RESOLVER._project_context_valid(document, ROOT):
        return ["Context schema or scoped characteristic validation failed"], None
    if document["workflow"] != {"spec_profile": "full", "artifact_layout": "legacy-seven-layer",
                                "capability_enforcement": "advisory"}:
        errors.append("candidate must retain the full/legacy-seven-layer/advisory phase-1 tuple")
    components = document.get("components", [])
    identities = [c["id"] for c in components]
    if len(identities) != 9 or set(identities) != PLUGIN_IDS | {"mcp", "installer"}:
        errors.append("candidate must contain exactly the nine approved components")
    overrides = []
    for component in components:
        identity = component["id"]
        if identity in PLUGIN_IDS:
            expected = (["plugin_package"], ["host_cli_plugin"], ["github_release", "multi_runtime_plugin_install"],
                        ["repository_content"] + (["workflow_evidence"] if identity != "sdd-bootstrap" else []) +
                        (["credential_material"] if identity == "sdd-quality-loop" else []))
        elif identity == "mcp":
            expected = (["mcp_server"], ["local_mcp_server"], ["github_release", "multi_runtime_plugin_install"],
                        ["repository_content", "host_metadata", "ci_metadata", "credential_material"])
        elif identity == "installer":
            expected = (["installer_script"], ["shell_installer"], ["github_release"],
                        ["repository_content", "host_configuration"])
        else:
            continue
        expected_include = ["plugins/" + identity + "/**"] if identity in PLUGIN_IDS else ["mcp/**"] if identity == "mcp" else None
        paths = component.get("paths", {})
        if expected_include is not None and paths != {"include": expected_include}:
            errors.append(identity + ": ownership must retain its exact component subtree")
        if identity == "installer" and any("*" in path for path in paths.get("include", [])):
            errors.append("installer ownership must use exact paths")
        overrides.extend((identity, item["scope"], item["characteristic"], item["value"])
                         for item in component.get("characteristic_overrides", []))
        for field, value in zip(("artifact_kinds", "runtime_classes", "distribution_channels", "data_classification"), expected):
            if component.get(field) != value:
                errors.append(identity + ": classification mismatch: " + field)
        for field in ("platform_targets", "characteristics", "provider_binding_ids"):
            if field in component:
                errors.append(identity + ": field needs a separate classification decision: " + field)
    growing = {"specs/**", "tests/**", "contracts/**", "docs/**", "reports/**", "marketplaces/**", ".github/**"}
    shared = document.get("shared_paths", [])
    if not growing <= {entry["pattern"] for entry in shared if entry.get("classification") == "cross-cutting"}:
        errors.append("all seven approved growing paths must remain cross-cutting")
    for entry in shared:
        if "*" in entry["pattern"] and entry["pattern"] not in growing:
            errors.append("unapproved broad shared rule: " + entry["pattern"])
        overrides.extend((entry["pattern"], item["scope"], item["characteristic"], item["value"])
                         for item in entry.get("characteristic_overrides", []))
    if sorted(overrides) != sorted([("mcp", "mcp/ci-mcp", "credential_bearing", True),
                                    (".github/**", ".github/**", "release_write", True)]):
        errors.append("candidate must preserve exactly the CI credential and release-write overrides")
    try:
        config = OWNERSHIP.load_config_dict(document)
        ownership = OWNERSHIP.classify_paths(config, tracked_paths)
    except ValueError as exc:
        return errors + [str(exc)], None
    for record in ownership["records"]:
        if record["classification"] in ("UNOWNED", "OVERLAP"):
            errors.append(record["classification"] + ": " + record["raw_path"])
    used = {owner for record in ownership["records"] for owner in record["owning_components"]}
    for identity in sorted(set(identities) - used):
        errors.append("component has no tracked paths: " + identity)
    return errors, ownership


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, default=ROOT / "specs/epic-197-a9-dogfood/candidate/project-context.yaml")
    args = parser.parse_args()
    try:
        document = OWNERSHIP.parse_minimal_yaml(args.candidate.read_text(encoding="utf-8"))
        paths = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode("utf-8").split("\0")
        errors, ownership = validate(document, [path for path in paths if path])
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print("candidate validation failed: " + type(exc).__name__, file=sys.stderr)
        return 1
    print(json.dumps({"candidate_valid": not errors, "diagnostics": errors,
                      "ownership_digest": ownership["context_binding"]["ownership_digest"] if ownership else None,
                      "live_activation": "not_attempted", "signed_approval": "not_issued",
                      "release_cycle_evidence": "not_collected"}, sort_keys=True))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
