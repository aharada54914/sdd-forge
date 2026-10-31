#!/usr/bin/env python3
"""Issue 423 bounded prerequisite repair: register real gate masters.

Missing implementations are exercised using the retained pre-migration registry.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest


ROOT = Path(__file__).resolve().parents[4]
REGISTRY = ROOT / "contracts/capability-registry.json"
STAGING = ROOT / "specs/sdd-domain-multitarget/human-copy/T-002-registry"
VERIFY_CANDIDATE = "--candidate" in sys.argv
if VERIFY_CANDIDATE:
    sys.argv.remove("--candidate")
    REGISTRY = STAGING / "contracts/capability-registry.json"
SCRIPT_ROOT = "plugins/sdd-quality-loop/scripts"
RECOVERED_IDS = (
    "check-component-coverage",
    "check-contract",
    "check-criterion-freeze",
    "check-hook-activation-handshake",
)


class RegistryRegistrationTests(unittest.TestCase):
    @unittest.skipUnless(VERIFY_CANDIDATE, "candidate-only check; canonical RED remains separate")
    def test_candidate_is_exact_hash_bound_additive_repair(self):
        proposal = json.loads((Path(__file__).parent / "registry-registration-candidate.json").read_text())
        head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=True)
        self.assertEqual(head.stdout.strip(), proposal["base_head"])
        source = ROOT / proposal["canonical"]
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), proposal["expected_canonical_sha256"])
        baseline = json.loads(source.read_text())
        candidate = json.loads(REGISTRY.read_text())
        expected = dict(baseline)
        expected["gates"] = baseline["gates"] + proposal["add_gates"]
        self.assertEqual(candidate, expected)
        self.assertEqual(len(candidate["gates"]), len(baseline["gates"]) + 4)
        for line in (STAGING / "BASELINE.sha256").read_text().splitlines():
            digest, path = line.split("  ", 1)
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), digest, path)

    @unittest.skipUnless(VERIFY_CANDIDATE, "candidate-only check; canonical RED remains separate")
    def test_candidate_vendor_projection_and_manifests_are_consistent(self):
        vendor = STAGING / "plugins/sdd-quality-loop/contracts/capability-registry.json"
        self.assertEqual(vendor.read_bytes(), REGISTRY.read_bytes())
        spec = importlib.util.spec_from_file_location(
            "registry_projection", ROOT / SCRIPT_ROOT / "generate-gate-capabilities.py",
        )
        projection = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(projection)
        data, digest = projection.load_registry(REGISTRY)
        expected = projection.render(projection.build_projection(data, digest))
        actual = STAGING / SCRIPT_ROOT / "generated/gate-capabilities.json"
        self.assertEqual(actual.read_bytes(), expected)
        for name in ("CANONICAL.MANIFEST.sha256", "DERIVED.MANIFEST.sha256"):
            for line in (STAGING / name).read_text().splitlines():
                digest, path = line.split("  ", 1)
                self.assertEqual(hashlib.sha256((STAGING / path).read_bytes()).hexdigest(), digest, path)

    def test_existing_gate_masters_have_one_blocking_implementation_registration(self):
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
        for gate_id in RECOVERED_IDS:
            with self.subTest(gate=gate_id):
                expected = {
                    "id": gate_id,
                    "stage": "implementation",
                    "blocking": True,
                    "implementation_ref": f"{SCRIPT_ROOT}/{gate_id}.py",
                }
                self.assertTrue((ROOT / expected["implementation_ref"]).is_file())
                self.assertEqual(
                    [gate for gate in registry["gates"] if gate.get("id") == gate_id],
                    [expected],
                )

    def test_dispatch_keeps_missing_implementation_fail_closed(self):
        result = subprocess.run(
            ["bash", f"{SCRIPT_ROOT}/validate-capability-registry.sh", "--registry",
             str(STAGING / "contracts/capability-registry.json")],
            cwd=ROOT, capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertEqual(
            result.stdout.splitlines(),
            [
                "registry: implementation-ref-missing: check-update-migration "
                "(path does not exist: plugins/sdd-quality-loop/scripts/check-update-migration.py)"
            ],
        )
        self.assertEqual(result.stderr, "")

    def test_applied_canonical_registry_validates(self):
        result = subprocess.run(
            ["bash", f"{SCRIPT_ROOT}/validate-capability-registry.sh", "--registry",
             str(ROOT / "contracts/capability-registry.json")],
            cwd=ROOT, capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
