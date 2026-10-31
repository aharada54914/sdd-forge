#!/usr/bin/env python3
"""RT-20260930-001 registry migration: registration, fixture, and data-only baseline checks.

The legacy-context comparison uses the production resolver with retained
pre-migration versus candidate registry data. The separate CLI suite checks the
candidate resolver's scoped BLOCKED behavior.
"""
import importlib.util
import json
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
REAL_SCRIPTS = ROOT / "plugins/sdd-quality-loop/scripts"
CANDIDATE_REGISTRY = HERE / "candidate/capability-registry.candidate.json"
FIXTURE_REGISTRY = HERE / "fixture/capability-registry.fixture.json"
FIXTURE_ROOT = HERE / "fixture"
CANONICAL_REGISTRY = ROOT / "contracts/capability-registry.json"
FOUR_REGISTRATION_CANDIDATE = (
    ROOT / "specs/sdd-domain-multitarget/human-copy/T-002-registry/contracts/capability-registry.json"
)


def _load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


VALIDATOR = _load_module("validate_capability_registry", REAL_SCRIPTS / "validate-capability-registry.py")
RESOLVER = _load_module("resolve_project_context", REAL_SCRIPTS / "resolve-project-context.py")


def _run_validator(registry_path: Path, repo_root: Path):
    return VALIDATOR.run(str(registry_path), repo_root)


class FourRegistrationsStayBlocking(unittest.TestCase):
    """The four prior gate registrations remain unchanged and blocking."""

    def test_candidate_retains_four_prior_registrations_unchanged(self):
        prior = json.loads(FOUR_REGISTRATION_CANDIDATE.read_text(encoding="utf-8"))
        candidate = json.loads(CANDIDATE_REGISTRY.read_text(encoding="utf-8"))
        recovered_ids = (
            "check-component-coverage",
            "check-contract",
            "check-criterion-freeze",
            "check-hook-activation-handshake",
        )
        prior_by_id = {g["id"]: g for g in prior["gates"]}
        candidate_by_id = {g["id"]: g for g in candidate["gates"]}
        for gate_id in recovered_ids:
            with self.subTest(gate=gate_id):
                self.assertEqual(candidate_by_id[gate_id], prior_by_id[gate_id])
                self.assertTrue(candidate_by_id[gate_id]["blocking"])
                self.assertTrue((ROOT / candidate_by_id[gate_id]["implementation_ref"]).is_file())


class ProductionRegistryValidatesWithoutPhantomGate(unittest.TestCase):
    """The data-only candidate validates without the phantom gate."""

    def test_candidate_has_no_durable_workflow_or_migration_gate(self):
        candidate = json.loads(CANDIDATE_REGISTRY.read_text(encoding="utf-8"))
        self.assertEqual(candidate["capabilities"], [])
        self.assertNotIn(
            "check-update-migration", {g["id"] for g in candidate["gates"]},
        )

    def test_candidate_validates_clean_against_real_repository(self):
        diagnostics = _run_validator(CANDIDATE_REGISTRY, ROOT)
        self.assertEqual(diagnostics, [])

    def test_pre_migration_registry_keeps_missing_implementation_failure(self):
        diagnostics = _run_validator(FOUR_REGISTRATION_CANDIDATE, ROOT)
        self.assertIn(
            "registry: implementation-ref-missing: check-update-migration "
            "(path does not exist: plugins/sdd-quality-loop/scripts/check-update-migration.py)",
            diagnostics,
        )

    def test_applied_canonical_registry_matches_candidate_and_validates(self):
        self.assertEqual(CANONICAL_REGISTRY.read_bytes(), CANDIDATE_REGISTRY.read_bytes())
        self.assertEqual(_run_validator(CANONICAL_REGISTRY, ROOT), [])


class FixtureDemonstratesExampleInIsolation(unittest.TestCase):
    """The illustrative example remains valid only in its isolated fixture."""

    def test_fixture_registry_is_byte_equivalent_capability_content(self):
        fixture = json.loads(FIXTURE_REGISTRY.read_text(encoding="utf-8"))
        canonical = json.loads(FOUR_REGISTRATION_CANDIDATE.read_text(encoding="utf-8"))
        self.assertEqual(fixture["capabilities"], canonical["capabilities"])

    def test_fixture_registry_validates_clean_in_isolated_root(self):
        diagnostics = _run_validator(FIXTURE_REGISTRY, FIXTURE_ROOT)
        self.assertEqual(diagnostics, [])

    def test_fixture_is_never_referenced_from_production_paths(self):
        for referencing in (CANDIDATE_REGISTRY, CANONICAL_REGISTRY):
            text = referencing.read_text(encoding="utf-8")
            self.assertNotIn("registry-migration-20261001/fixture", text)


class LegacySelectedContextObligationGap(unittest.TestCase):
    """Compare the production resolver with canonical and data-only registries.

    The candidate resolver's scoped BLOCKED behavior is tested by the CLI suite.
    """

    LEGACY_COMPONENT_ID = "legacy-workflow-component"
    LEGACY_PROPERTIES = {
        "artifact_kinds": ["durable_workflow"],
        "characteristics": {"pii": False},
    }

    def _evaluate(self, registry_document):
        capability_evaluations = []
        warn_diagnostics = []
        RESOLVER._evaluate_capabilities(
            REAL_SCRIPTS,
            registry_document,
            [self.LEGACY_COMPONENT_ID],
            {self.LEGACY_COMPONENT_ID: self.LEGACY_PROPERTIES},
            capability_evaluations,
            warn_diagnostics,
        )
        matched_ids = sorted(e["capability_id"] for e in capability_evaluations if e["matched"])
        return {
            "matched_ids": matched_ids,
            "required_facets": RESOLVER._required_facets(registry_document, matched_ids),
            "resolved_gates": RESOLVER._resolved_gates(registry_document, matched_ids),
            "lite_eligibility": RESOLVER._lite_eligibility(registry_document, matched_ids),
        }

    def test_pre_migration_registry_preserves_obligations_for_legacy_context(self):
        canonical = json.loads(FOUR_REGISTRATION_CANDIDATE.read_text(encoding="utf-8"))
        result = self._evaluate(canonical)
        self.assertEqual(result["matched_ids"], ["durable-workflow"])
        self.assertEqual(result["required_facets"], ["data-spec"])
        self.assertEqual([g["id"] for g in result["resolved_gates"]], ["check-update-migration"])
        self.assertTrue(result["resolved_gates"][0]["blocking"])
        self.assertFalse(result["lite_eligibility"]["eligible"])

    def test_candidate_silently_drops_obligations_for_identical_legacy_context(self):
        candidate = json.loads(CANDIDATE_REGISTRY.read_text(encoding="utf-8"))
        result = self._evaluate(candidate)
        self.assertEqual(result["matched_ids"], [])
        self.assertEqual(result["required_facets"], [])
        self.assertEqual(result["resolved_gates"], [])
        self.assertTrue(result["lite_eligibility"]["eligible"])
        # Data-only removal drops obligations under the production resolver;
        # registry-migration-cli.tests.py covers the candidate resolver.

    def test_unaffected_valid_context_resolves_normally_under_candidate(self):
        """A context that never selected the retired capability is unaffected."""
        candidate = json.loads(CANDIDATE_REGISTRY.read_text(encoding="utf-8"))
        cli_component_properties = {
            "artifact_kinds": ["cli_tool"],
            "characteristics": {"pii": False},
        }
        capability_evaluations = []
        warn_diagnostics = []
        RESOLVER._evaluate_capabilities(
            REAL_SCRIPTS, candidate, ["cli-component"],
            {"cli-component": cli_component_properties},
            capability_evaluations, warn_diagnostics,
        )
        self.assertEqual(capability_evaluations, [])
        diagnostics = _run_validator(CANDIDATE_REGISTRY, ROOT)
        self.assertEqual(diagnostics, [], "candidate must not document-wide Block unaffected contexts")


if __name__ == "__main__":
    unittest.main(verbosity=2)
