#!/usr/bin/env python3
"""A9 candidate, scoped overrides and minimal Pack behavioral regressions."""
import copy
import importlib.util
import json
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


if __name__ == "__main__":
    unittest.main()
