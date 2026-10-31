"""Focused executable contract checks for the agent-driven Concept Test skill."""

import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / "plugins/sdd-domain/skills/concept-test/SKILL.md"
SCHEMA = ROOT / "contracts/concept-test.v1.schema.json"
VALIDATOR = ROOT / "plugins/sdd-domain/scripts/validate-domain-contract.sh"
RENDERER = ROOT / "plugins/sdd-quality-loop/scripts/concept_test_render.py"
PROPOSALS = (
    "FITS_EXISTING_CONCEPTS",
    "NEW_CONCEPT_CANDIDATE",
    "RESPONSIBILITY_CONFLICT",
    "REQUIRES_HUMAN_DECISION",
)
RELATIONS = ("same", "different", "undecided")
DECISIONS = ("proceed", "defer-to-domain-update", "rejected")


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def valid_contract():
    return {
        "schema": "domain-contract/v2",
        "meta": {"version": "1.0.0", "status": "Approved", "generated_from": ["domain/context-map.md"]},
        "contexts": [{"name": "order-taking", "description": "Records a purchase promise.", "terms": [
            {"canonical": "Order", "definition": "A purchase promise.", "concept_id": "CONCEPT-ORDER"}
        ], "aggregates": []}],
        "concepts": [{"id": "CONCEPT-ORDER", "name": "Order", "context": "order-taking",
                      "definition": "A recorded purchase promise.", "essence": "What was promised.",
                      "responsibilities": ["record purchase intent"],
                      "must_not_own": ["future shipping promises"],
                      "evidence": ["domain-story:activity-1"]}],
    }


class ConceptTestWorkflow(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.skill = SKILL.read_text(encoding="utf-8")
        cls.schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
        spec = importlib.util.spec_from_file_location("concept_test_render", RENDERER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        cls.render = staticmethod(module.render_concept_test_md)

    def test_skill_has_validation_and_human_boundary(self):
        for clause in (
            "validate-domain-contract.sh", "domain-contract/v2", "every file actually read",
            "Term, not proof", "same", "different", "undecided", "explicit relation confirmation",
            "write no final evidence pair", "Never write under `domain/`", "Do not call the signer",
            "Future-only hypothetical scenarios", "render_concept_test_md",
        ):
            with self.subTest(clause=clause):
                self.assertIn(clause, self.skill)
        self.assertEqual(set(PROPOSALS), set(self.schema["properties"]["proposal"]["enum"]))
        self.assertEqual(set(RELATIONS), set(self.schema["properties"]["relation"]["enum"]))

    def test_validated_v2_worked_fixture_all_proposals_and_relations(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            domain = root / "domain"
            domain.mkdir()
            contract_path = domain / "domain-contract.json"
            contract_path.write_text(json.dumps(valid_contract()), encoding="utf-8")
            feature = root / "specs" / "checkout"
            feature.mkdir(parents=True)
            requirements = feature / "requirements.md"
            requirements.write_text("# Checkout\n\nRecord a present purchase promise.\n", encoding="utf-8")
            before = sha256(contract_path)
            result = subprocess.run(["bash", str(VALIDATOR), str(contract_path)],
                                    cwd=ROOT, text=True, capture_output=True, check=False)
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertEqual("", result.stdout)
            for proposal in PROPOSALS:
                for relation in RELATIONS:
                    for decision in ((None,) if proposal == PROPOSALS[0] else DECISIONS):
                        with self.subTest(proposal=proposal, relation=relation, decision=decision):
                            evidence = {
                                "schema": "sdd-concept-test/v1", "feature": "checkout",
                                "proposal": proposal,
                                "rationale": "CONCEPT-ORDER owns purchase intent; hypothetical shipping does not amend the domain.",
                                "relation": relation, "decision": decision,
                                "inputs": [
                                    {"path": "domain/domain-contract.json", "sha256": sha256(contract_path)},
                                    {"path": "specs/checkout/requirements.md", "sha256": sha256(requirements)},
                                ],
                            }
                            self.assertEqual(set(self.schema["required"]), set(evidence))
                            self.assertIn(evidence["proposal"], self.schema["properties"]["proposal"]["enum"])
                            self.assertIn(evidence["relation"], self.schema["properties"]["relation"]["enum"])
                            for item in evidence["inputs"]:
                                self.assertEqual(sha256(root / item["path"]), item["sha256"])
                            json_path = feature / "concept-test.json"
                            md_path = feature / "concept-test.md"
                            json_path.write_text(json.dumps(evidence, sort_keys=True), encoding="utf-8")
                            md_path.write_bytes(self.render(json.loads(json_path.read_text(encoding="utf-8"))))
                            self.assertEqual(self.render(evidence), md_path.read_bytes())
                            self.assertEqual(before, sha256(contract_path))
            self.assertEqual({"domain-contract.json"}, {p.name for p in domain.iterdir()})

    def test_future_only_requirement_is_not_a_domain_update(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            domain = root / "domain"
            domain.mkdir()
            contract_path = domain / "domain-contract.json"
            contract_path.write_text(json.dumps(valid_contract()), encoding="utf-8")
            feature = root / "specs" / "hypothetical-shipping"
            feature.mkdir(parents=True)
            (feature / "requirements.md").write_text(
                "# Hypothetical shipping\n\nNo present shipping responsibility exists. "
                "A future delivery-date promise would need an ownership decision.\n",
                encoding="utf-8",
            )
            before = sha256(contract_path)
            self.assertEqual(0, subprocess.run(
                ["bash", str(VALIDATOR), str(contract_path)],
                cwd=ROOT, text=True, capture_output=True, check=False,
            ).returncode)
            self.assertIn("Future-only hypothetical scenarios are candidate evidence", self.skill)
            self.assertIn("write no final evidence pair", self.skill)
            self.assertEqual([], list(feature.glob("concept-test.*")))
            self.assertEqual(before, sha256(contract_path))
            self.assertEqual({"domain-contract.json"}, {p.name for p in domain.iterdir()})

    def test_v1_contract_is_rejected_before_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            contract_path = Path(tmp) / "domain-contract.json"
            contract = valid_contract()
            contract["schema"] = "domain-contract/v1"
            contract_path.write_text(json.dumps(contract), encoding="utf-8")
            result = subprocess.run(["bash", str(VALIDATOR), str(contract_path)],
                                    cwd=ROOT, text=True, capture_output=True, check=False)
            self.assertNotEqual(0, result.returncode)
            self.assertEqual("", result.stdout)
            self.assertIn("domain-contract/v2", result.stderr)
            self.assertEqual([contract_path.name], [p.name for p in Path(tmp).iterdir()])


if __name__ == "__main__":
    unittest.main()
