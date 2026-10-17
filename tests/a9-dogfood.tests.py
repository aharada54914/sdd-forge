#!/usr/bin/env python3
"""A9 candidate, scoped overrides and minimal Pack behavioral regressions."""
import copy
import importlib.util
import json
import hashlib
import shutil
import sys
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "plugins/sdd-quality-loop/scripts"

def load(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), SCRIPTS / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

OWNERSHIP = load("resolve-component-paths")
RESOLVER = load("resolve-project-context")
APPROVAL = load("validate-approval-sidecar")
PREDICATE = load("evaluate-predicate")


def context():
    return {"schema": "sdd-project-context/v1", "workflow": {
        "spec_profile": "full", "artifact_layout": "legacy-seven-layer",
        "capability_enforcement": "advisory"}, "components": [{
        "id": "mcp", "paths": {"include": ["mcp/**"]},
        "characteristic_overrides": [{"scope": "mcp/ci-mcp",
            "characteristic": "credential_bearing", "value": True,
            "rationale": "CI metadata access consumes a read-only token."}]}],
        "shared_paths": [{"pattern": ".github/**", "classification": "cross-cutting",
            "characteristic_overrides": [{"scope": ".github/**", "characteristic": "release_write",
                "value": True, "rationale": "The release workflow publishes release artifacts."}]}]}


class OverrideTests(unittest.TestCase):
    def assert_rejected(self, doc):
        self.assertFalse(RESOLVER._project_context_valid(doc, ROOT))
        with self.assertRaises(ValueError):
            OWNERSHIP.validate_characteristic_overrides(doc)

    def test_approved_overrides_are_accepted(self):
        self.assertTrue(RESOLVER._project_context_valid(context(), ROOT))
        OWNERSHIP.validate_characteristic_overrides(context())

    def test_approval_admission_checks_scope_before_signatures(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "context.yaml"
            candidate = (ROOT / "specs/epic-197-a9-dogfood/candidate/project-context.yaml").read_text()
            path.write_text(candidate)
            info = {"schema_filename": "project-context.schema.json", "array_field": "components", "dup_category": "DUPLICATE_COMPONENT_ID"}
            APPROVAL._validate_content(path, info)
            path.write_text(candidate.replace('scope: "mcp/ci-mcp"', 'scope: "outside/service"'))
            with self.assertRaises(APPROVAL.ValidateApprovalSidecarError) as caught:
                APPROVAL._validate_content(path, info)
            self.assertEqual(caught.exception.category, "CONTENT_SCHEMA_VIOLATION")

    def test_context_without_overrides_stays_valid(self):
        doc = context()
        del doc["components"][0]["characteristic_overrides"]
        del doc["shared_paths"][0]["characteristic_overrides"]
        self.assertTrue(RESOLVER._project_context_valid(doc, ROOT))

    def test_exact_override_fields(self):
        for name in ("scope", "characteristic", "value", "rationale"):
            doc = context()
            del doc["components"][0]["characteristic_overrides"][0][name]
            with self.subTest(missing=name): self.assert_rejected(doc)
        doc = context()
        doc["components"][0]["characteristic_overrides"][0]["extra"] = True
        self.assert_rejected(doc)

    def test_invalid_override_values(self):
        for field, value in [("characteristic", "pii"), ("characteristic", "Credential_bearing"),
                             ("value", False), ("value", 1), ("scope", "mcp-other/service"),
                             ("scope", "mcp/../outside"), ("scope", "/mcp/ci-mcp"),
                             ("scope", "mcp/*"), ("scope", "mcp/bad\x00name"), ("rationale", ""), ("rationale", "two\nlines"), ("rationale", "trailing\n")]:
            doc = context()
            doc["components"][0]["characteristic_overrides"][0][field] = value
            with self.subTest(field=field, value=value): self.assert_rejected(doc)
        doc = context()
        doc["shared_paths"][0]["characteristic_overrides"][0]["value"] = False
        self.assert_rejected(doc)

    def test_excluded_scope_rejected(self):
        doc = context()
        doc["components"][0]["paths"]["exclude"] = ["mcp/ci-mcp/**"]
        self.assert_rejected(doc)

    def test_shared_override_requires_cross_cutting_owner_and_exact_scope(self):
        for change in ("scope", "bounded"):
            doc = context()
            if change == "scope": doc["shared_paths"][0]["characteristic_overrides"][0]["scope"] = "elsewhere/**"
            else:
                del doc["shared_paths"][0]["classification"]
                doc["shared_paths"][0]["components"] = ["mcp"]
            self.assert_rejected(doc)

    def test_misplaced_override_rejected(self):
        for location in ("top", "workflow", "paths", "characteristics"):
            doc = context()
            override = doc["components"][0].pop("characteristic_overrides")
            target = doc if location == "top" else doc["workflow"] if location == "workflow" else doc["components"][0].setdefault(location, {})
            target["characteristic_overrides"] = override
            with self.subTest(location=location): self.assert_rejected(doc)


class CandidatePackTests(unittest.TestCase):
    def test_candidate_has_complete_nonoverlapping_tracked_ownership(self):
        candidate = ROOT / "specs/epic-197-a9-dogfood/candidate/project-context.yaml"
        doc = OWNERSHIP.parse_minimal_yaml(candidate.read_text())
        self.assertTrue(RESOLVER._project_context_valid(doc, ROOT))
        self.assertEqual(len(doc["components"]), 9)
        paths = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
        result = OWNERSHIP.classify_paths(OWNERSHIP.load_config_dict(doc), [p for p in paths if p])
        self.assertFalse([r for r in result["records"] if r["classification"] in ("UNOWNED", "OVERLAP")])

    def test_candidate_contract_rejects_inventory_classification_and_ownership_drift(self):
        spec = importlib.util.spec_from_file_location("a9_candidate", ROOT / "scripts/validate-a9-candidate.py")
        checker = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(checker)
        doc = OWNERSHIP.parse_minimal_yaml((ROOT / "specs/epic-197-a9-dogfood/candidate/project-context.yaml").read_text())
        tracked = subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True).splitlines()
        for index in range(9):
            changed = copy.deepcopy(doc)
            del changed["components"][index]
            with self.subTest(missing=index): self.assertTrue(checker.validate(changed, tracked)[0])
        for field in ("artifact_kinds", "runtime_classes", "distribution_channels", "data_classification"):
            changed = copy.deepcopy(doc)
            changed["components"][0][field] = []
            with self.subTest(field=field): self.assertTrue(checker.validate(changed, tracked)[0])
        changed = copy.deepcopy(doc)
        changed["components"][0]["paths"]["include"] = ["**"]
        self.assertTrue(checker.validate(changed, tracked)[0])
        changed = copy.deepcopy(doc)
        changed["components"][7].pop("characteristic_overrides")
        self.assertTrue(checker.validate(changed, tracked)[0])
        self.assertTrue(checker.validate(doc, tracked + ["new-unclassified-root.txt"])[0])

    def test_pack_matches_artifact_kind_and_preserves_policy(self):
        registry = json.loads((ROOT / "contracts/capability-registry.json").read_text())
        caps = {c["id"]: c for c in registry["capabilities"]}
        self.assertTrue({"developer-tooling", "cli-library"} <= caps.keys())
        for kind, expected in [("plugin_package", {"developer-tooling", "cli-library"}),
                               ("mcp_server", {"developer-tooling"}), ("installer_script", {"developer-tooling"}),
                               ("unknown", set()), ("PLUGIN_PACKAGE", set()), ("MCP_SERVER", set()), ("INSTALLER_SCRIPT", set())]:
            actual = {name for name in ("developer-tooling", "cli-library")
                      if PREDICATE.run_evaluate(caps[name]["trigger"], {"artifact_kinds": [kind]})["result"]}
            with self.subTest(kind=kind): self.assertEqual(actual, expected)
        for name in ("developer-tooling", "cli-library"):
            cap = caps[name]
            self.assertEqual(cap["gate_ids"], [])
            self.assertEqual(cap["conditional_facets"], [])
            self.assertEqual(cap["lite_policy"], {"eligible": True})
            self.assertEqual(cap["delivery_strategy"], {"kind": "human-copy"})
            self.assertNotIn("minimum_enforcement", cap)
            self.assertEqual(cap["required_facets"], [name + "-spec"])
            suffix = "distribution" if name == "developer-tooling" else "contract"
            self.assertEqual(cap["review_check_ids"], [name + "-" + suffix + "-compatibility"])


class ResolverIntegrationTests(unittest.TestCase):
    def run_pipeline(self, changed_paths, *, context_mutation=None, projection_schema_mutation=False, output_ownership_mutation=False):
        """Execute real Git, canonicalization, ownership, Registry and publication."""
        with tempfile.TemporaryDirectory(prefix="a9-resolver-") as directory:
            root = Path(directory)
            for relative in ("contracts", "plugins/sdd-quality-loop/scripts",
                             "plugins/sdd-quality-loop/contracts", "plugins/sdd-quality-loop/references"):
                shutil.copytree(ROOT / relative, root / relative, ignore=shutil.ignore_patterns("__pycache__"))
            shutil.copy2(ROOT / ".gitignore", root / ".gitignore")
            config = OWNERSHIP.parse_minimal_yaml((ROOT / "specs/epic-197-a9-dogfood/candidate/project-context.yaml").read_text())
            if output_ownership_mutation:
                config["shared_paths"] = [entry for entry in config["shared_paths"]
                                          if entry["pattern"] != "plugins/sdd-quality-loop/scripts/generated/project-context.resolved.json"]
            if context_mutation:
                context_mutation(config)
            (root / "sdd").mkdir()
            def yaml_lines(value, indent=0):
                prefix = " " * indent
                if isinstance(value, dict):
                    for key, item in value.items():
                        if isinstance(item, (dict, list)) and item:
                            yield prefix + key + ":"
                            yield from yaml_lines(item, indent + 2)
                        else:
                            yield prefix + key + ": " + json.dumps(item)
                else:
                    for item in value:
                        if isinstance(item, dict):
                            lines = list(yaml_lines(item, indent + 2))
                            yield prefix + "- " + lines[0].lstrip()
                            yield from lines[1:]
                        else:
                            yield prefix + "- " + json.dumps(item)
            (root / "sdd/project-context.yaml").write_text("\n".join(yaml_lines(config)) + "\n", encoding="utf-8")
            (root / "specs/fixture").mkdir(parents=True)
            if projection_schema_mutation:
                for relative in ("contracts", "plugins/sdd-quality-loop/contracts"):
                    schema_path = root / relative / "context-projection.schema.json"
                    schema = json.loads(schema_path.read_text())
                    schema["definitions"]["projectedComponent"]["properties"].pop("characteristic_overrides", None)
                    schema_path.write_text(json.dumps(schema))
            for relative in changed_paths:
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("before\n")
            for command in (["git", "init", "-q"], ["git", "add", "."],
                            ["git", "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                             "-c", "commit.gpgsign=false", "commit", "-qm", "fixture"]):
                subprocess.run(command, cwd=root, check=True, capture_output=True)
            for relative in changed_paths:
                (root / relative).write_text("after\n")
            script = root / "plugins/sdd-quality-loop/scripts/resolve-project-context.py"
            command = [sys.executable, str(script), "--config", "sdd/project-context.yaml",
                       "--source-rev", "HEAD", "--target-rev", "HEAD", "--feature", "fixture"]
            result = subprocess.run(command, cwd=root, capture_output=True, text=True)
            if output_ownership_mutation:
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("post-publication-generation-mismatch", result.stderr)
                self.assertFalse((root / "specs/fixture/facet-manifest.yaml").exists())
                return
            if projection_schema_mutation:
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("output-schema-validation-failed", result.stderr)
                self.assertFalse((root / "specs/fixture/facet-manifest.yaml").exists())
                return
            self.assertEqual(result.returncode, 0, result.stderr)
            evidence = json.loads((root / "specs/fixture/resolver-evidence.yaml").read_text())
            lite = config["workflow"]["spec_profile"] == "lite"
            artifact = json.loads((root / "specs/fixture" / ("capability-summary.yaml" if lite else "facet-manifest.yaml")).read_text())
            binding = evidence["context_binding"]
            projection_path = root / "plugins/sdd-quality-loop/scripts/generated/project-context.resolved.json"
            if lite:
                self.assertEqual(artifact["track"], "lite")
                self.assertEqual(artifact["capabilities"], ["cli-library", "developer-tooling"])
                self.assertFalse(artifact["full_upgrade_required"])
                self.assertFalse(projection_path.exists())
                self.assertFalse((root / "specs/fixture/facet-manifest.yaml").exists())
            else:
                self.assertEqual(binding, artifact["context_binding"])
                projection = json.loads(projection_path.read_text())
                self.assertEqual(projection["workflow"], config["workflow"])
                self.assertEqual(projection["components"]["mcp"]["characteristic_overrides"], config["components"][7]["characteristic_overrides"])
                self.assertEqual(projection["shared_paths"], config["shared_paths"])
                self.assertEqual(binding["projection_sha256"], "sha256:" + hashlib.sha256(projection_path.read_bytes()).hexdigest())
                self.assertEqual(binding["full_context_revision"], projection["source_sha256"])
            expected_ownership = OWNERSHIP.classify_paths(OWNERSHIP.load_config_dict(config), changed_paths)
            self.assertEqual(binding["ownership_digest"], expected_ownership["context_binding"]["ownership_digest"])
            if not lite:
                self.assertEqual(artifact["affected_components"], expected_ownership["affected_components"])
                self.assertEqual(artifact["resolved_gates"], [])
            if not lite:
                for name, tail in [("validate-facet-manifest", ["--manifest", "specs/fixture/facet-manifest.yaml"]),
                                   ("validate-resolver-evidence", ["--evidence", "specs/fixture/resolver-evidence.yaml",
                                    "--manifest", "specs/fixture/facet-manifest.yaml", "--registry", "contracts/capability-registry.json"])]:
                    check = subprocess.run([sys.executable, str(root / "plugins/sdd-quality-loop/scripts" / (name + ".py"))] + tail,
                                           cwd=root, capture_output=True, text=True)
                    self.assertEqual(check.returncode, 0, check.stdout + check.stderr)
            # Re-running against unchanged source must remain stable after output publication.
            second = subprocess.run(command, cwd=root, capture_output=True, text=True)
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertEqual(json.loads((root / "specs/fixture/resolver-evidence.yaml").read_text())["context_binding"], binding)
            return artifact

    def test_real_resolver_pack_matrix_and_stable_publication(self):
        both = ["cli-library", "developer-tooling"]
        cases = [(["plugins/sdd-bootstrap/example.py"], both),
                 (["mcp/ci-mcp/example.py"], ["developer-tooling"]),
                 (["install.sh"], ["developer-tooling"]),
                 (["mcp/ci-mcp/example.py", "plugins/sdd-bootstrap/example.py"], both)]
        for paths, expected in cases:
            with self.subTest(paths=paths):
                artifact = self.run_pipeline(paths)
                self.assertEqual(artifact["capabilities"], expected)
                self.assertEqual(artifact["required_facets"], [item + "-spec" for item in expected])
        for kind in ("unknown", "PLUGIN_PACKAGE"):
            with self.subTest(kind=kind):
                artifact = self.run_pipeline(["plugins/sdd-bootstrap/example.py"],
                    context_mutation=lambda doc: doc["components"][0].update(artifact_kinds=[kind]))
                self.assertEqual(artifact["capabilities"], [])
                self.assertEqual(artifact["required_facets"], [])

    def test_projection_schema_rejects_missing_override_contract(self):
        self.run_pipeline(["plugins/sdd-bootstrap/example.py"], projection_schema_mutation=True)

    def test_json_shaped_yaml_rejects_duplicate_or_malformed_json(self):
        validator = load("validate-facet-manifest")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "facet-manifest.yaml"
            for text in ('{"schema":"first","schema":"second"}', '{"schema": invalid}'):
                with self.subTest(text=text):
                    path.write_text(text)
                    with self.assertRaises(validator.CanonicalizerError):
                        validator.load_manifest(str(path))

    def test_component_owned_projection_cannot_pass_publication(self):
        self.run_pipeline(["plugins/sdd-bootstrap/example.py"], output_ownership_mutation=True)

    def test_full_required_and_lite_advisory_are_preserved(self):
        for profile, layout, enforcement in [("full", "facet-hybrid", "required"),
                                               ("lite", "lite-three-file", "advisory")]:
            with self.subTest(profile=profile):
                self.run_pipeline(["plugins/sdd-bootstrap/example.py"], context_mutation=lambda doc:
                    doc["workflow"].update(spec_profile=profile, artifact_layout=layout, capability_enforcement=enforcement))


if __name__ == "__main__":
    unittest.main()
