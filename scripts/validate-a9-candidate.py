#!/usr/bin/env python3
"""Validate A9 candidates and optional release/CI consistency; never authorize activation."""
import argparse
from datetime import datetime, timezone
import importlib.util
import json
import re
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


spec = importlib.util.spec_from_file_location("a9_observer", ROOT / "scripts/observe-a9-advisory.py")
if spec is None or spec.loader is None:
    raise RuntimeError("A9 observation validator is unavailable")
OBSERVER = importlib.util.module_from_spec(spec)
spec.loader.exec_module(OBSERVER)

OWNERSHIP = load("resolve-component-paths")
RESOLVER = load("resolve-project-context")
PLUGIN_IDS = {"sdd-bootstrap", "sdd-review-loop", "sdd-implementation", "sdd-quality-loop",
              "sdd-ship", "sdd-lite", "sdd-domain"}


def validate(document, tracked_paths, phase="phase1"):
    errors = []
    if not RESOLVER._project_context_valid(document, ROOT):
        return ["Context schema or scoped characteristic validation failed"], None
    expected = {"phase1": {"spec_profile": "full", "artifact_layout": "legacy-seven-layer",
                           "capability_enforcement": "advisory"},
                "phase2": {"spec_profile": "full", "artifact_layout": "facet-hybrid",
                           "capability_enforcement": "required"}}[phase]
    if document["workflow"] != expected:
        errors.append("candidate must use the exact " + phase + " workflow tuple")
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


def validate_release_cycle(cycle, commits):
    """Check trusted exports against Git; this does not authenticate GitHub exports."""
    try:
        if cycle["schema"] != "a9-release-cycle/v1":
            raise ValueError("unknown release evidence schema")
        for field in ("base_sha", "head_sha"):
            if not isinstance(cycle[field], str) or not re.fullmatch(r"[0-9a-f]{40}", cycle[field]):
                raise ValueError("release boundaries must be full commit IDs")
        if cycle["base_sha"] == cycle["head_sha"] or not commits or commits[0] != cycle["head_sha"]:
            raise ValueError("release cycle must contain the bounded Git history")
        release = cycle["release"]
        if release["draft"] is not False or release["prerelease"] is not False or not release["tag_name"]:
            raise ValueError("a published final release is required")
        published = datetime.fromisoformat(release["published_at"].replace("Z", "+00:00"))
        if published.tzinfo is None or published > datetime.now(timezone.utc):
            raise ValueError("release publication needs a past, timezone-qualified timestamp")
        lanes = cycle["required_checks"]
        if set(lanes) != {"linux", "macos", "windows"}:
            raise ValueError("required checks must cover all three platforms")
        for names in lanes.values():
            if not isinstance(names, list) or not names or any(not isinstance(n, str) or not n.strip() for n in names):
                raise ValueError("each platform needs named CI checks")
        all_names = [name for names in lanes.values() for name in names]
        if len(set(all_names)) != len(all_names):
            raise ValueError("platform checks must be distinct")
        gate = cycle["advisory_check"]
        if not isinstance(gate, str) or not gate.strip() or gate in all_names:
            raise ValueError("the advisory Gate needs a distinct check name")
        required = set(all_names) | {gate}
        prs = cycle["pull_requests"]
        numbers = [pr["number"] for pr in prs]
        merges = [pr["merge_commit_sha"] for pr in prs]
        if (not prs or any(type(n) is not int or n <= 0 for n in numbers)
                or len(set(numbers)) != len(numbers) or len(set(merges)) != len(merges)
                or set(merges) != set(commits)):
            raise ValueError("PR roster must cover every first-parent release commit exactly once")
        for pr in prs:
            if not isinstance(pr["head_sha"], str) or not re.fullmatch(r"[0-9a-f]{40}", pr["head_sha"]):
                raise ValueError("PR head must be a full commit ID")
            latest, ids = {}, set()
            for check in pr["check_runs"]:
                if type(check["id"]) is not int or check["id"] <= 0 or check["id"] in ids:
                    raise ValueError("check run IDs must be unique positive integers")
                ids.add(check["id"])
                if check["head_sha"] != pr["head_sha"]:
                    raise ValueError("CI evidence must reference the PR's final head")
                name = check["name"]
                if not isinstance(name, str) or not name.strip():
                    raise ValueError("check run needs a name")
                if name not in latest or check["id"] > latest[name]["id"]:
                    latest[name] = check
            if not required <= latest.keys():
                raise ValueError("advisory Gate or required platform CI is missing")
            if any(c["status"] != "completed" or c["conclusion"] != "success" for c in latest.values()):
                raise ValueError("latest recorded checks must all complete successfully")
            observation = pr["advisory_observation"]
            if latest[gate]["advisory_observation_sha256"] != OWNERSHIP.canonical_digest(observation):
                raise ValueError("latest advisory check does not bind the collected observation")
            diagnostics = OBSERVER.validate_observation(observation, pr["head_sha"], pr["base_sha"], ROOT)
            if diagnostics:
                raise ValueError("; ".join(diagnostics))
    except (KeyError, TypeError, ValueError, AttributeError) as exc:
        return ["release/CI evidence rejected: " + str(exc)]
    return []


def validate_promotion(candidate, baseline, tracked_paths, registry, evidence, manifest, cycle, commits):
    """Read-only transition/evidence consistency preflight, never an authorization."""
    errors, _ = validate(candidate, tracked_paths, "phase2")
    baseline_errors, ownership = validate(baseline, tracked_paths)
    errors.extend("baseline: " + item for item in baseline_errors)
    if {k: v for k, v in candidate.items() if k != "workflow"} != {k: v for k, v in baseline.items() if k != "workflow"}:
        errors.append("promotion must only change the workflow tuple")
    try:
        if not {"developer-tooling", "cli-library"} <= {c["id"] for c in registry["capabilities"]}:
            errors.append("both initial Pack capabilities are required")
        if load("validate-facet-manifest").validate_document(manifest):
            errors.append("existing Facet Manifest validator rejected the manifest")
        validator = load("validate-resolver-evidence")
        current_registry_path = ROOT / "contracts/capability-registry.json"
        current_registry = read_document(current_registry_path)
        if validator.whole_registry_digest(registry) != validator.whole_registry_digest(current_registry):
            errors.append("supplied Registry does not match the current canonical Registry")
        registry_schema = read_document(ROOT / "contracts/capability-registry.schema.json")
        if not RESOLVER._draft7_conforms(registry, registry_schema):
            errors.append("Registry schema validation failed")
        if load("validate-capability-registry").run(str(current_registry_path), ROOT):
            errors.append("current canonical Registry semantic validation failed")
        if validator.validate_document(evidence, registry, "promotion registry", manifest, None):
            errors.append("existing Resolver Evidence validator rejected the evidence")
        if evidence["state"] != "advisory" or evidence["diagnostics"]:
            errors.append("the baseline Resolver observation must be clean advisory evidence")
        expected = {"full_context_revision": OWNERSHIP.canonical_digest(baseline),
                    "ownership_digest": ownership["context_binding"]["ownership_digest"]}
        if any(evidence["context_binding"][k] != value for k, value in expected.items()):
            errors.append("Resolver observation is stale for the baseline Context or tracked ownership")
        if manifest["context_binding"] != evidence["context_binding"] or manifest["resolver"] != evidence["resolver"]:
            errors.append("Manifest and Resolver observation must share exact bindings")
        expected_manifest = RESOLVER._assemble_facet_manifest(evidence["feature"], manifest["affected_components"],
            registry, evidence["capability_evaluations"], evidence["context_binding"], evidence["resolver"])
        if manifest != expected_manifest:
            errors.append("Manifest does not match the observed capability selection")
        if evidence["resolver"] != RESOLVER._resolver_block():
            errors.append("Resolver observation uses a stale runtime version or rule set")
    except (KeyError, TypeError, ValueError) as exc:
        errors.append("Pack/Resolver evidence rejected: " + str(exc))
    errors.extend(validate_release_cycle(cycle, commits))
    return errors


def read_document(path):
    """Use the same canonical JSON/YAML reader as the Resolver."""
    try:
        # Resolver publications use JSON object bytes even with a .yaml suffix.
        # Select once from the bytes; malformed JSON must never retry as YAML.
        input_format = "json" if path.suffix == ".json" or path.read_bytes().lstrip().startswith(b"{") else "yaml"
        return RESOLVER._canonicalize(str(path), input_format)[1]
    except (RESOLVER.CanonicalizerFailed, RESOLVER.CanonicalizerOutputMalformed) as exc:
        raise ValueError("document canonicalization failed") from exc


def release_commits(cycle):
    # Commit operands are validated before they reach Git; no arbitrary revisions.
    if not isinstance(cycle, dict) or any(not isinstance(cycle.get(k), str) or
            not re.fullmatch(r"[0-9a-f]{40}", cycle[k]) for k in ("base_sha", "head_sha")):
        raise ValueError("invalid release boundaries")
    OBSERVER.git(ROOT, "merge-base", "--is-ancestor", cycle["base_sha"], cycle["head_sha"])
    commits = OBSERVER.git(ROOT, "rev-list", "--first-parent",
        cycle["base_sha"] + ".." + cycle["head_sha"]).decode().splitlines()
    tag = cycle["release"]["tag_name"]
    OBSERVER.git(ROOT, "check-ref-format", "refs/tags/" + tag)
    tag_head = OBSERVER.git(ROOT, "rev-parse", "--verify", "refs/tags/" + tag + "^{commit}").decode().strip()
    if tag_head != cycle["head_sha"]:
        raise ValueError("published release tag does not resolve to the recorded cycle head")
    return commits


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, default=ROOT / "specs/epic-197-a9-dogfood/candidate/project-context-formal-verification.yaml")
    parser.add_argument("--phase", choices=("phase1", "phase2"), default="phase1")
    for name in ("baseline", "registry", "resolver-evidence", "manifest", "release-evidence"):
        parser.add_argument("--" + name, type=Path)
    args = parser.parse_args()
    if args.phase == "phase2" and any(getattr(args, name) is None for name in
            ("baseline", "registry", "resolver_evidence", "manifest", "release_evidence")):
        parser.error("phase2 requires baseline, registry, resolver-evidence, manifest and release-evidence")
    try:
        document = read_document(args.candidate)
        paths = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode("utf-8").split("\0")
        tracked = [path for path in paths if path]
        errors, ownership = validate(document, tracked, args.phase)
        if args.phase == "phase2":
            cycle = read_document(args.release_evidence)
            commits = release_commits(cycle)
            errors = validate_promotion(document, read_document(args.baseline), tracked,
                read_document(args.registry), read_document(args.resolver_evidence),
                read_document(args.manifest), cycle, commits)
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as exc:
        print("candidate validation failed: " + type(exc).__name__, file=sys.stderr)
        return 1
    print(json.dumps({"candidate_valid": not errors, "diagnostics": errors,
                      "ownership_digest": ownership["context_binding"]["ownership_digest"] if ownership else None,
                      "live_activation": "not_attempted", "signed_approval": "not_issued",
                      "release_cycle_evidence": "consistency_checked" if args.phase == "phase2" and not errors else ("not_collected" if args.phase == "phase1" else "not_validated"),
                      "promotion_authorized": False,
                      "preflight_scope": "candidate_transition_and_release_ci_consistency" if args.phase == "phase2" else "phase1_candidate",
                      "unchecked_requirements": ["export authenticity and required-check policy", "approved Phase-1 publication authenticity", "human promotion approval",
                          "false-positive triage and unresolved findings", "signed end-to-end rollback rehearsal",
                          "post-promotion real feature workflow"]}, sort_keys=True))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
