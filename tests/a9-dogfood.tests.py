#!/usr/bin/env python3
"""A9 candidate, scoped overrides and minimal Pack behavioral regressions."""
import copy
import contextlib
import io
import importlib.util
import json
import hashlib
import shutil
import sys
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from types import ModuleType
from typing import Any, NotRequired, TypedDict

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "plugins/sdd-quality-loop/scripts"

def load(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), SCRIPTS / (name + ".py"))
    if spec is None or spec.loader is None:
        raise RuntimeError("Required local module is unavailable")
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
            with self.subTest(missing=name):
                self.assert_rejected(doc)
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
            with self.subTest(field=field, value=value):
                self.assert_rejected(doc)
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
            if change == "scope":
                doc["shared_paths"][0]["characteristic_overrides"][0]["scope"] = "elsewhere/**"
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
            with self.subTest(location=location):
                self.assert_rejected(doc)


class CandidatePackTests(unittest.TestCase):
    def test_candidate_has_complete_nonoverlapping_tracked_ownership(self):
        candidate = ROOT / "specs/epic-197-a9-dogfood/candidate/project-context.yaml"
        doc = OWNERSHIP.parse_minimal_yaml(candidate.read_text())
        self.assertTrue(RESOLVER._project_context_valid(doc, ROOT))
        self.assertEqual(len(doc["components"]), 11)
        paths = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
        result = OWNERSHIP.classify_paths(OWNERSHIP.load_config_dict(doc), [p for p in paths if p])
        self.assertFalse([r for r in result["records"] if r["classification"] in ("UNOWNED", "OVERLAP")])

    def test_candidate_contract_rejects_inventory_classification_and_ownership_drift(self):
        spec = importlib.util.spec_from_file_location("a9_candidate", ROOT / "scripts/validate-a9-candidate.py")
        if spec is None or spec.loader is None:
            raise RuntimeError("Required local module is unavailable")
        checker = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(checker)
        doc = OWNERSHIP.parse_minimal_yaml((ROOT / "specs/epic-197-a9-dogfood/candidate/project-context.yaml").read_text())
        tracked = subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True).splitlines()
        for index in range(11):
            changed = copy.deepcopy(doc)
            del changed["components"][index]
            with self.subTest(missing=index):
                self.assertTrue(checker.validate(changed, tracked)[0])
        self.assertEqual(checker.validate(doc, tracked)[0], [])
        for index in range(11):
            for field in ("artifact_kinds", "runtime_classes", "distribution_channels", "data_classification"):
                changed = copy.deepcopy(doc)
                changed["components"][index][field] = []
                with self.subTest(component=index, field=field):
                    self.assertTrue(checker.validate(changed, tracked)[0])
            changed = copy.deepcopy(doc)
            changed["components"][index]["paths"]["include"] = ["unowned-subtree/**"]
            with self.subTest(owner=index):
                self.assertTrue(checker.validate(changed, tracked)[0])
        for index in (9, 10):
            for classification in (["repository_content", "workflow_evidence"],
                                   ["repository_content", "workflow_evidence", "host_metadata"]):
                changed = copy.deepcopy(doc)
                changed["components"][index]["data_classification"] = classification
                with self.subTest(cloud_component=index, classification=classification):
                    errors, _ = checker.validate(changed, tracked)
                    self.assertIn(changed["components"][index]["id"] + ": classification mismatch: data_classification", errors)
        for replacement in (None, {"pattern": "templates/**", "components": ["sdd-azure-cloud", "sdd-aws-cloud"]},
                            {"pattern": "templates/cloud/**", "classification": "cross-cutting"},
                            {"pattern": "templates/cloud/**", "components": ["sdd-azure-cloud"]}):
            changed = copy.deepcopy(doc)
            changed["shared_paths"] = [entry for entry in changed["shared_paths"] if entry["pattern"] != "templates/cloud/**"]
            if replacement is not None:
                changed["shared_paths"].append(replacement)
            with self.subTest(cloud_templates=replacement):
                self.assertTrue(checker.validate(changed, tracked)[0])
        self.assertTrue(checker.validate(doc, tracked + ["plugins/unapproved/fixture.py"])[0])
        self.assertTrue(checker.validate(doc, tracked + ["templates/unapproved/fixture.yml"])[0])
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
            with self.subTest(kind=kind):
                self.assertEqual(actual, expected)
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


class PullRequestFixture(TypedDict):
    number: int
    head_sha: str
    merge_commit_sha: str
    base_sha: NotRequired[str]
    advisory_observation: NotRequired[dict[str, Any]]
    check_runs: list[dict[str, object]]


class ReleaseCycleFixture(TypedDict):
    schema: str
    base_sha: str
    head_sha: str
    release: dict[str, object]
    required_checks: dict[str, list[str]]
    advisory_check: str
    pull_requests: list[PullRequestFixture]


class PromotionPreflightTests(unittest.TestCase):
    """Synthetic evidence tests: these never authorize a real promotion."""
    fixture_module: ModuleType
    fixture_tmp: tempfile.TemporaryDirectory[str]
    fixture_root: Path
    pr_base: str
    pr_head: str
    observation: dict[str, Any]
    cycle: ReleaseCycleFixture
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("a9_observation_fixture", ROOT / "tests/a9-advisory-evidence.tests.py")
        if spec is None or spec.loader is None:
            raise RuntimeError("Required local module is unavailable")
        cls.fixture_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.fixture_module)
        cls.fixture_tmp = tempfile.TemporaryDirectory(prefix="a9-release-fixture-")
        cls.fixture_root = Path(cls.fixture_tmp.name)
        cls.pr_base, cls.pr_head, contract = cls.fixture_module.fixture(cls.fixture_root)
        cls.observation = cls.fixture_module.observer.collect(cls.fixture_root, cls.pr_base,
            cls.pr_head, "fixture", contract, None)

    @classmethod
    def tearDownClass(cls):
        cls.fixture_tmp.cleanup()

    def setUp(self):
        spec = importlib.util.spec_from_file_location("a9_promotion", ROOT / "scripts/validate-a9-candidate.py")
        if spec is None or spec.loader is None:
            raise RuntimeError("Required local module is unavailable")
        self.checker = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.checker)
        self.baseline = OWNERSHIP.parse_minimal_yaml((ROOT / "specs/epic-197-a9-dogfood/candidate/project-context.yaml").read_text())
        self.candidate = copy.deepcopy(self.baseline)
        self.candidate["workflow"].update(artifact_layout="facet-hybrid", capability_enforcement="required")
        self.tracked = subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True).splitlines()
        folder = ROOT / "specs/epic-197-a9-dogfood/verification/advisory-observation-20261017"
        self.registry = json.loads((ROOT / "contracts/capability-registry.json").read_text())
        self.evidence = json.loads((folder / "resolver-evidence.yaml").read_text())
        self.manifest = json.loads((folder / "facet-manifest.yaml").read_text())
        ownership = OWNERSHIP.classify_paths(OWNERSHIP.load_config_dict(self.baseline), self.tracked)
        for document in (self.evidence, self.manifest):
            document["context_binding"]["full_context_revision"] = OWNERSHIP.canonical_digest(self.baseline)
            document["context_binding"]["ownership_digest"] = ownership["context_binding"]["ownership_digest"]
        self.head = self.pr_head
        self.commit = "c" * 40
        self.cycle = {"schema": "a9-release-cycle/v1", "base_sha": "a" * 40, "head_sha": self.commit,
            "release": {"tag_name": "synthetic-release", "draft": False, "prerelease": False,
                        "published_at": "2026-10-01T00:00:00Z"},
            "required_checks": {"linux": ["tests (ubuntu-latest)"], "macos": ["tests (macos-latest)"],
                                "windows": ["tests (windows-latest)"]},
            "advisory_check": "capability-mode Gate (advisory)",
            "pull_requests": [{"number": 1, "head_sha": self.head, "merge_commit_sha": self.commit,
                "check_runs": [{"id": i + 1, "name": name, "head_sha": self.head,
                    "status": "completed", "conclusion": "success"}
                    for i, name in enumerate(["capability-mode Gate (advisory)", "tests (ubuntu-latest)",
                                              "tests (macos-latest)", "tests (windows-latest)"])]}]}

        self.cycle["pull_requests"][0]["base_sha"] = self.pr_base
        self.cycle["pull_requests"][0]["advisory_observation"] = copy.deepcopy(self.observation)
        self.cycle["pull_requests"][0]["check_runs"][0]["advisory_observation_sha256"] = OWNERSHIP.canonical_digest(self.observation)

    def check(self):
        with patch.object(self.checker, "ROOT", self.fixture_root):
            return self.checker.validate_promotion(self.candidate, self.baseline, self.tracked,
                self.registry, self.evidence, self.manifest, self.cycle, [self.commit])

    def test_green_check_names_without_actual_advisory_observation_reject(self):
        self.cycle["pull_requests"][0].pop("advisory_observation")
        self.assertTrue(self.check(), "green CI names alone are not an executed advisory Gate")

    def test_latest_advisory_check_requires_exact_observation_digest(self):
        check = self.cycle['pull_requests'][0]['check_runs'][0]
        check['advisory_observation_sha256'] = 'sha256:' + '0' * 64
        self.assertTrue(self.check())

    def test_inactive_observation_cannot_count_even_with_rehashed_green_check(self):
        pr = self.cycle['pull_requests'][0]
        pr['advisory_observation']['state'] = 'not_activated'
        pr['check_runs'][0]['advisory_observation_sha256'] = OWNERSHIP.canonical_digest(pr['advisory_observation'])
        self.assertTrue(self.check())

    def test_complete_scoped_preflight(self):
        self.assertEqual(self.check(), [])

    def test_phase2_cli_consumes_real_formats_and_git_without_authorizing(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            root = base / "repo"
            root.mkdir()
            shutil.copytree(ROOT / "contracts", root / "contracts")
            for relative in ("plugins/sdd-quality-loop/scripts", "plugins/sdd-quality-loop/references"):
                shutil.copytree(ROOT / relative, root / relative, ignore=shutil.ignore_patterns("__pycache__"))
            for path in ["plugins/" + name + "/fixture.py" for name in self.checker.PLUGIN_IDS] + ["mcp/fixture.py", "install.sh"]:
                destination = root / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.touch()
            def git(*args):
                return subprocess.check_output(["git", *args], cwd=root, text=True, stderr=subprocess.DEVNULL).strip()
            git("init", "-q")
            git("add", ".")
            git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "base")
            self.cycle["base_sha"] = git("rev-parse", "HEAD")
            (root / "install.sh").write_text("# synthetic release fixture\n")
            git("add", ".")
            git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "release")
            self.cycle["head_sha"] = git("rev-parse", "HEAD")
            self.cycle["pull_requests"][0]["merge_commit_sha"] = self.cycle["head_sha"]
            git("tag", "synthetic-release")
            git("fetch", str(self.fixture_root), self.pr_head)
            tracked = git("ls-files").splitlines()
            ownership = OWNERSHIP.classify_paths(OWNERSHIP.load_config_dict(self.baseline), tracked)
            for document in (self.evidence, self.manifest):
                document["context_binding"]["ownership_digest"] = ownership["context_binding"]["ownership_digest"]
            args = ["validate-a9-candidate.py", "--phase", "phase2"]
            for flag, document in (("candidate", self.candidate), ("baseline", self.baseline),
                                   ("registry", self.registry), ("resolver-evidence", self.evidence),
                                   ("manifest", self.manifest), ("release-evidence", self.cycle)):
                path = base / (flag + ".yaml")
                path.write_text(json.dumps(document))
                args.extend(["--" + flag, str(path)])
            output = io.StringIO()
            with patch.object(self.checker, "ROOT", root), patch.object(sys, "argv", args), contextlib.redirect_stdout(output):
                self.assertEqual(self.checker.main(), 0, output.getvalue())
            result = json.loads(output.getvalue())
            self.assertTrue(result["candidate_valid"])
            self.assertEqual(result["release_cycle_evidence"], "consistency_checked")
            self.assertFalse(result["promotion_authorized"])
            self.assertFalse((root / "sdd").exists())

    def test_rejects_partial_transition_and_unrelated_context_change(self):
        for layout, enforcement in [("legacy-seven-layer", "required"), ("facet-hybrid", "advisory")]:
            with self.subTest(layout=layout):
                self.candidate = copy.deepcopy(self.baseline)
                self.candidate["workflow"].update(artifact_layout=layout, capability_enforcement=enforcement)
                self.assertTrue(self.check())
        self.candidate = copy.deepcopy(self.baseline)
        self.candidate["workflow"].update(artifact_layout="facet-hybrid", capability_enforcement="required")
        self.candidate["shared_paths"].reverse()
        self.assertTrue(self.check())

    def test_rejects_stale_resolver_bindings_and_missing_pack(self):
        original = copy.deepcopy(self.evidence)
        for field in ("full_context_revision", "ownership_digest", "registry_digest"):
            self.evidence = copy.deepcopy(original)
            self.evidence["context_binding"][field] = "sha256:" + "0" * 64
            with self.subTest(field=field):
                self.assertTrue(self.check())
        self.evidence = original
        self.evidence["resolver"]["version"] = "stale"
        self.assertTrue(self.check())
        self.evidence["resolver"]["version"] = RESOLVER.RESOLVER_VERSION
        self.registry["capabilities"] = []
        self.assertTrue(self.check())

    def test_coherent_stale_registry_repin_is_rejected(self):
        original = copy.deepcopy(self.registry)
        for change in (lambda r: r.update(version="stale"),
                       lambda r: r["gates"][0].update(blocking=False)):
            self.registry = copy.deepcopy(original)
            change(self.registry)
            digest = load("validate-resolver-evidence").whole_registry_digest(self.registry)
            for document in (self.evidence, self.manifest):
                document["context_binding"]["registry_digest"] = digest
            self.assertTrue(self.check())

    def test_manifest_cannot_drop_selected_facets_or_change_feature(self):
        original = copy.deepcopy(self.manifest)
        for field, value in (("required_facets", []), ("feature", "another-feature"), ("capabilities", [])):
            self.manifest = copy.deepcopy(original)
            self.manifest[field] = value
            with self.subTest(field=field):
                self.assertTrue(self.check())

    def test_release_roster_must_cover_exact_git_commits(self):
        for mutate in (lambda c: c.update(pull_requests=[]),
                       lambda c: c["pull_requests"].append(copy.deepcopy(c["pull_requests"][0])),
                       lambda c: c["pull_requests"][0].update(merge_commit_sha="d" * 40),
                       lambda c: c["release"].update(draft=True),
                       lambda c: c["release"].update(published_at=None)):
            original = copy.deepcopy(self.cycle)
            mutate(self.cycle)
            self.assertTrue(self.check())
            self.cycle = original

    def test_current_success_on_every_platform_and_gate_required(self):
        original = copy.deepcopy(self.cycle)
        for index in range(4):
            for field, value in (("head_sha", "d" * 40), ("status", "in_progress"),
                                 ("conclusion", "failure"), ("conclusion", "skipped")):
                self.cycle = copy.deepcopy(original)
                self.cycle["pull_requests"][0]["check_runs"][index][field] = value
                with self.subTest(index=index, field=field, value=value):
                    self.assertTrue(self.check())
            self.cycle = copy.deepcopy(original)
            self.cycle["pull_requests"][0]["check_runs"].pop(index)
            self.assertTrue(self.check())
        self.cycle = copy.deepcopy(original)
        self.cycle["required_checks"].pop("macos")
        self.assertTrue(self.check())

    def test_old_green_cannot_hide_latest_failure(self):
        latest = copy.deepcopy(self.cycle["pull_requests"][0]["check_runs"][1])
        latest.update(id=100, conclusion="failure")
        self.cycle["pull_requests"][0]["check_runs"].append(latest)
        self.assertTrue(self.check())
        latest["conclusion"] = "success"
        self.assertEqual(self.check(), [])

    def test_missing_or_malformed_evidence_fails_closed(self):
        malformed: list[object] = [{}, None, [], {"schema": "a9-release-cycle/v1"}]
        for value in malformed:
            with self.subTest(value=value), patch.object(self, "cycle", value):
                self.assertTrue(self.check())


class PromotionGitBoundaryTests(unittest.TestCase):
    def test_real_git_release_boundary_and_tag_binding(self):
        spec = importlib.util.spec_from_file_location("a9_git_boundary", ROOT / "scripts/validate-a9-candidate.py")
        if spec is None or spec.loader is None:
            raise RuntimeError("Required local module is unavailable")
        checker = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(checker)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(["git", *args], cwd=root, text=True, stderr=subprocess.DEVNULL).strip()
            git("init", "-q")
            git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "--allow-empty", "-qm", "base")
            base = git("rev-parse", "HEAD")
            git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "--allow-empty", "-qm", "release")
            head = git("rev-parse", "HEAD")
            git("tag", "synthetic-release")
            cycle = {"base_sha": base, "head_sha": head, "release": {"tag_name": "synthetic-release"}}
            with patch.object(checker, "ROOT", root):
                self.assertEqual(checker.release_commits(cycle), [head])
                git("tag", "-f", "synthetic-release", base)
                with self.assertRaises(ValueError):
                    checker.release_commits(cycle)
                cycle["head_sha"] = "--help"
                with self.assertRaises(ValueError):
                    checker.release_commits(cycle)

    def test_reads_real_resolver_json_in_yaml_and_rejects_corrupt_objects(self):
        spec = importlib.util.spec_from_file_location("a9_reader", ROOT / "scripts/validate-a9-candidate.py")
        if spec is None or spec.loader is None:
            raise RuntimeError("Required local module is unavailable")
        checker = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(checker)
        folder = ROOT / "specs/epic-197-a9-dogfood/verification/advisory-observation-20261017"
        for name in ("facet-manifest.yaml", "resolver-evidence.yaml"):
            with self.subTest(name=name):
                self.assertEqual(checker.read_document(folder / name), json.loads((folder / name).read_text()))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "artifact.yaml"
            for content in ('{"schema":"first","schema":"second"}', '{"schema": invalid}'):
                path.write_text(content)
                with self.subTest(content=content), self.assertRaises(ValueError):
                    checker.read_document(path)

    def test_cli_missing_or_duplicate_documents_reject_without_activation(self):
        command = [sys.executable, str(ROOT / "scripts/validate-a9-candidate.py")]
        result = subprocess.run(command + ["--phase", "phase2"], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requires baseline", result.stderr)
        with tempfile.TemporaryDirectory() as directory:
            candidate = Path(directory) / "candidate.json"
            candidate.write_text('{"schema":"first","schema":"second"}')
            result = subprocess.run(command + ["--candidate", str(candidate)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("Traceback", result.stderr)
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(json.loads(result.stdout)["promotion_authorized"])


if __name__ == "__main__":
    unittest.main()
