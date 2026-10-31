"""Contract experiment only; does not modify or replace the production validator."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "a8_fixture", ROOT / "tests/fixtures/live-host-proof/run_cases.py")
F = importlib.util.module_from_spec(spec)
spec.loader.exec_module(F)
V = F.load_validator_module()
CONSUMERS = {
    "sdd-bootstrap": "plugins/sdd-bootstrap/skills/bootstrap/SKILL.md",
    "sdd-bootstrap-interviewer": "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md",
    "lite-gate": "plugins/sdd-lite/skills/lite-gate/SKILL.md",
    "lite-spec": "plugins/sdd-lite/skills/lite-spec/SKILL.md",
    "sdd-ship": "plugins/sdd-ship/skills/ship/SKILL.md",
}
FIELDS = {"consumer", "raw_tool_request_ref", "raw_tool_request_sha256",
          "raw_tool_result_ref", "raw_tool_result_sha256"}


def inventory_check(record, fixture):
    if record["schema"] != "live-host-verification-record/v2" or record["verdict"] != "PASS":
        raise ValueError("not v2 completed evidence")
    inventory = record.get("consumer_inventory")
    if not isinstance(inventory, dict) or set(inventory) != {
            "upstream_epic_a1_commit", "upstream_epic_a1_path_blob_ids", "observations"}:
        raise ValueError("inventory fields")
    if inventory["upstream_epic_a1_commit"] != F.T008_A1_COMMIT or inventory[
            "upstream_epic_a1_path_blob_ids"] != F.T008_CONSUMER_PATHS:
        raise ValueError("source identity")
    observations = inventory["observations"]
    if not isinstance(observations, list) or len(observations) != len(CONSUMERS):
        raise ValueError("consumer count")
    if any(not isinstance(item, dict) or set(item) != FIELDS for item in observations):
        raise ValueError("observation fields")
    names = [item["consumer"] for item in observations]
    if any(not isinstance(name, str) for name in names) or set(names) != set(CONSUMERS):
        raise ValueError("consumer membership")
    for kind in ("request", "result"):
        refs = [item[f"raw_tool_{kind}_ref"] for item in observations]
        if any(not isinstance(ref, str) for ref in refs) or len(set(refs)) != len(refs):
            raise ValueError("sampled capture reused")
        for item in observations:
            ref = item[f"raw_tool_{kind}_ref"]
            observed = V.file_digest(V.safe_repo_file(fixture.root, ref))
            if observed != item[f"raw_tool_{kind}_sha256"]:
                raise ValueError("capture digest")


class InventoryExperiment(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="a8-inventory-prototype-")
        self.addCleanup(self.tmp.cleanup)
        self.fixture = F.Fixture(self.tmp.name)

    def candidate(self, cell):
        record = self.fixture.load_record(cell)
        record["schema"] = "live-host-verification-record/v2"
        inventory = {"upstream_epic_a1_commit": F.T008_A1_COMMIT,
                     "upstream_epic_a1_path_blob_ids": dict(F.T008_CONSUMER_PATHS),
                     "observations": []}
        for consumer in CONSUMERS:
            item = {"consumer": consumer}
            for kind in ("request", "result"):
                ref = f"tests/hook-activation-live-proof/raw/{cell}-{consumer}-{kind}.txt"
                data = f"synthetic contract experiment {cell} {consumer} {kind}".encode()
                (self.fixture.root / ref).write_bytes(data)
                item[f"raw_tool_{kind}_ref"] = ref
                item[f"raw_tool_{kind}_sha256"] = F.sha256_bytes(data)
            inventory["observations"].append(item)
        record["consumer_inventory"] = inventory
        F.sign_record(record)
        return record

    def test_red_current_validator_discharges_without_consumer_inventory(self):
        result = F.invoke(self.fixture)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("discharged", result.stdout)
        self.assertNotIn("consumer_inventory", self.fixture.load_record())
        print("RED reproduced: current validator discharges AC-015 fixtures without AC-016 observations")

    def test_source_inventory_matches_actual_git_objects(self):
        self.assertEqual(set(CONSUMERS.values()), set(F.T008_CONSUMER_PATHS))
        for path, blob in F.T008_CONSUMER_PATHS.items():
            self.assertEqual(F.git_blob_at_commit(F.T008_A1_COMMIT, path), blob)

    def test_complete_each_cell_and_existing_signatures(self):
        registry = json.loads(self.fixture.registry.read_text())
        for cell in F.CELLS:
            with self.subTest(cell=cell):
                record = self.candidate(cell)
                inventory_check(record, self.fixture)
                V.validate_signatures(record, registry, cell)

    def test_rejection_matrix(self):
        for cell in F.CELLS:
            original = self.candidate(cell)
            def changed(kind):
                record = copy.deepcopy(original)
                inv = record["consumer_inventory"]
                obs = inv["observations"]
                if kind == "missing": obs.pop()
                elif kind == "duplicate": obs[-1] = copy.deepcopy(obs[0])
                elif kind == "unknown": obs[0]["consumer"] = "unknown"
                elif kind == "commit": inv["upstream_epic_a1_commit"] = "0" * 40
                elif kind == "blob": inv["upstream_epic_a1_path_blob_ids"][next(iter(CONSUMERS.values()))] = "0" * 40
                elif kind == "digest": obs[0]["raw_tool_result_sha256"] = "sha256:" + "0" * 64
                elif kind == "path": obs[0]["raw_tool_request_ref"] = "../outside"
                elif kind == "absent": obs[0]["raw_tool_result_ref"] += ".missing"
                elif kind == "sample":
                    for key in ("raw_tool_request_ref", "raw_tool_request_sha256"):
                        obs[1][key] = obs[0][key]
                elif kind == "skip": record["verdict"] = "SKIP"
                elif kind == "v1": record["schema"] = "live-host-verification-record/v1"
                elif kind == "extra": obs[0]["unbound"] = True
                return record
            for kind in ("missing", "duplicate", "unknown", "commit", "blob", "digest",
                         "path", "absent", "sample", "skip", "v1", "extra"):
                with self.subTest(cell=cell, mutation=kind):
                    with self.assertRaises((ValueError, V.ValidationError)):
                        inventory_check(changed(kind), self.fixture)

    def test_inventory_mutation_breaks_existing_two_signature_target(self):
        registry = json.loads(self.fixture.registry.read_text())
        for cell in F.CELLS:
            record = self.candidate(cell)
            record["consumer_inventory"]["observations"].reverse()
            inventory_check(record, self.fixture)
            with self.subTest(cell=cell):
                with self.assertRaises(V.ValidationError) as caught:
                    V.validate_signatures(record, registry, cell)
                self.assertEqual(caught.exception.code, "ERR_SIGNATURE_INVALID")


if __name__ == "__main__":
    unittest.main(verbosity=2)
