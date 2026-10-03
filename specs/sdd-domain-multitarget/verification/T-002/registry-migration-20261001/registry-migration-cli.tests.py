#!/usr/bin/env python3
"""RT-20260930-001: real resolver CLI and persisted migration evidence."""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
SOURCE = ROOT / "plugins/sdd-quality-loop/scripts/resolve-project-context.py"
REGISTRY = ROOT / "contracts/capability-registry.json"
spec = importlib.util.spec_from_file_location("resolver_block_driver", ROOT / "tests/resolve-project-context-block-check.py")
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)


def exercise(profile, artifact_kinds, pii, resolver=SOURCE, malformed=False, legacy_unaffected=False, registry=REGISTRY):
    with tempfile.TemporaryDirectory(prefix="registry-migration-cli-") as temp:
        repo = Path(temp).resolve()
        subprocess.run(["git", "init", "-q", str(repo)], check=True)
        scripts = driver.install_scripts(repo)
        shutil.copy2(resolver, scripts / "resolve-project-context.py")
        driver.install_t003_dependencies(repo, scripts, HERE, registry_capabilities_path=registry)
        for gate in json.loads(registry.read_text(encoding="utf-8"))["gates"]:
            ref = gate["implementation_ref"]
            destination = repo / ref
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / ref, destination)
        config = repo / "project-context.yaml"
        kinds = "\n".join(f"      - {kind}" for kind in artifact_kinds)
        if malformed:
            kinds = "      - [not, a, string]"
        context = (
            "schema: sdd-project-context/v1\nworkflow:\n"
            f"  spec_profile: {profile}\n"
            f"  artifact_layout: {'lite-three-file' if profile == 'lite' else 'facet-hybrid'}\n"
            "  capability_enforcement: required\n"
            "components:\n  - id: app\n"
            f"    artifact_kinds:\n{kinds}\n"
            f"    characteristics:\n      pii: {str(pii).lower()}\n"
            "    paths:\n      include:\n        - app/**\n"
        )
        if legacy_unaffected:
            context += (
                "  - id: archive\n    artifact_kinds:\n"
                "      - durable_workflow\n    paths:\n"
                "      include:\n        - archive/**\n"
            )
        config.write_text(context, encoding="utf-8")
        (repo / "README.md").write_text("base\n", encoding="utf-8")
        base = driver.git_commit_all(repo, "baseline")
        (repo / "app").mkdir()
        (repo / "app/file.txt").write_text("target\n", encoding="utf-8")
        target = driver.git_commit_all(repo, "target")
        result = subprocess.run(
            [sys.executable, str(scripts / "resolve-project-context.py"),
             "--config", "project-context.yaml", "--source-rev", base,
             "--target-rev", target, "--feature", "example-feature"],
            cwd=repo, capture_output=True, text=True,
        )
        feature = repo / "specs/example-feature"
        evidence_path = feature / "resolver-evidence.yaml"
        evidence = json.loads(evidence_path.read_text(encoding="utf-8")) if evidence_path.exists() else None
        published = {name: (feature / name).exists() for name in ("facet-manifest.yaml", "capability-summary.yaml")}
        published["context-projection"] = (scripts / "generated/project-context.resolved.json").exists()
        summary_path = feature / ("capability-summary.yaml" if profile == "lite" else "facet-manifest.yaml")
        summary = json.loads(summary_path.read_text(encoding="utf-8")) if summary_path.exists() else None
        return result, evidence, published, summary


class MigrationCLI(unittest.TestCase):
    def test_custom_registry_retains_declared_obligations(self):
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
        capability = json.loads((HERE / "fixture/capability-registry.fixture.json").read_text(encoding="utf-8"))["capabilities"][0]
        capability["gate_ids"] = ["check-contract"]
        registry["capabilities"] = [capability]
        with tempfile.TemporaryDirectory(prefix="registry-migration-retained-") as temp:
            path = Path(temp) / "capability-registry.json"
            path.write_text(json.dumps(registry), encoding="utf-8")
            result, evidence, published, manifest = exercise("full", ["durable_workflow"], True, registry=path)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(evidence["diagnostics"], [])
        self.assertNotIn("durable-workflow-content-migration/2026-10-01-v1", result.stderr)
        self.assertTrue(published["facet-manifest.yaml"])
        self.assertEqual(manifest["required_facets"], ["data-spec"])
        self.assertEqual(manifest["capabilities"], ["durable-workflow"])
        self.assertEqual(manifest["conditional_facets"], [{
            "applied": True, "facet": "pii-handling-spec",
            "evidence": [{"operator": "equals", "outcome": "match", "path": "characteristics.pii"}],
        }])
        self.assertEqual(manifest["resolved_gates"], [{
            "id": "check-contract", "stage": "implementation", "blocking": True,
        }])

    def test_legacy_affected_full_and_lite_pii_both_values_block_before_publication(self):
        for profile in ("full", "lite"):
            for pii in (False, True):
                with self.subTest(profile=profile, pii=pii):
                    result, evidence, published, _ = exercise(profile, ["durable_workflow"], pii)
                    self.assertEqual(result.returncode, 1, result.stderr)
                    self.assertIn("registry-validation-failed", result.stderr)
                    self.assertIn("durable-workflow-content-migration/2026-10-01-v1", result.stderr)
                    self.assertIsNotNone(evidence, result.stderr)
                    self.assertEqual(
                        [diagnostic["id"] for diagnostic in evidence["diagnostics"]],
                        ["registry-validation-failed"],
                    )
                    self.assertIn(
                        "durable-workflow-content-migration/2026-10-01-v1",
                        evidence["diagnostics"][0]["detail"],
                    )
                    self.assertFalse(any(published.values()), published)

    def test_unaffected_and_unrelated_cli_are_not_migration_blocked(self):
        for kinds in (["other"], ["cli_tool"]):
            with self.subTest(kinds=kinds):
                result, evidence, published, _ = exercise("full", kinds, False)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn("durable-workflow-content-migration/2026-10-01-v1", result.stderr)
                self.assertNotIn("registry-validation-failed", result.stderr)
                self.assertEqual(evidence["diagnostics"], [])
                self.assertTrue(published["facet-manifest.yaml"])
                self.assertTrue(published["context-projection"])

    def test_invalid_input_keeps_existing_block(self):
        result, evidence, published, _ = exercise("full", ["other"], False, malformed=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("canonicalizer-invocation-failed", result.stderr)
        self.assertFalse(any(published.values()))

    def test_legacy_on_unaffected_component_does_not_block(self):
        result, evidence, published, _ = exercise(
            "full", ["other"], False, legacy_unaffected=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(evidence["diagnostics"], [])
        self.assertTrue(published["facet-manifest.yaml"])

    def test_unaffected_lite_keeps_lite_publication_contract(self):
        result, evidence, published, summary = exercise(
            "lite", ["other"], False, legacy_unaffected=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(evidence["diagnostics"], [])
        self.assertEqual(evidence["capability_evaluations"], [])
        self.assertEqual(summary, {
            "schema": "sdd-capability-summary/v1",
            "feature": "example-feature",
            "track": "lite",
            "capabilities": [],
            "required_lite_checks": [],
            "full_upgrade_required": False,
        })
        self.assertEqual(published, {
            "facet-manifest.yaml": False,
            "capability-summary.yaml": True,
            "context-projection": False,
        })


if __name__ == "__main__":
    unittest.main(verbosity=2)
