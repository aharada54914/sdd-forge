#!/usr/bin/env python3
"""Persisted conditional pins: runtime parity without rewriting live evidence."""
import copy
import hashlib
import json
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
FEATURE = "workflow-state-integrity"
DOMAIN = ["domain/context-map.md", "domain/domain-contract.json"]
DS = ["design-system/design-tokens.json", "design-system/design-system.md",
      "design-system/ui-patterns.md"]


class ConditionalHistoryTests(unittest.TestCase):
    def test_adr_extended_persisted_pins(self):
        source = (ROOT / "tests/workflow-state.tests.sh").read_text()
        helper = re.search(r"^make_full_fixture\(\) \{\n.*?^\}", source, re.M | re.S).group()
        with tempfile.TemporaryDirectory(prefix="conditional-adr-history-") as tmp:
            tmp = Path(tmp)
            driver = f"set -eu\nROOT={shlex.quote(str(ROOT))}\nTMP={shlex.quote(str(tmp))}\n"
            result = subprocess.run(["bash"], input=driver + helper + "\nmake_full_fixture base\n",
                                    text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            base = Path(result.stdout.strip())
            for mode, valid in (("legacy", True), ("both", True), ("one-sided", False),
                                ("hash-mismatch", False), ("output-only", False),
                                ("unknown", False), ("stale", False), ("missing", False)):
                with self.subTest(case=mode):
                    target = tmp / mode
                    shutil.copytree(base, target)
                    for path in target.joinpath("reports").rglob("*.json"):
                        path.write_text(path.read_text().replace(str(base), str(target)))
                    stage = target / f"reports/impl-review/{FEATURE}/attempt-1/round-2"
                    def read(name):
                        return json.loads((stage / name).read_text())
                    def save(name, value):
                        (stage / name).write_text(json.dumps(value))
                    adr = "docs/adr/0002-repository-workflow-state-integrity.md"
                    (target / "docs/adr").mkdir(parents=True, exist_ok=True)
                    shutil.copy2(ROOT / adr, target / adr)
                    adr_pin = {"path": adr, "sha256": hashlib.sha256((target / adr).read_bytes()).hexdigest()}
                    precheck = read("precheck-result.json")
                    precheck["adr_inputs"] = [adr_pin]
                    precheck["layer_sha256"] = {}
                    material = ":".join(precheck[k] for k in
                                        ("design_sha256", "requirements_sha256", "acceptance_sha256"))
                    precheck["input_sha256"] = hashlib.sha256(
                        (material + ":adr_inputs/v1:" + json.dumps([adr_pin], separators=(",", ":"))).encode()).hexdigest()
                    save("precheck-result.json", precheck)
                    contract = read("impl-review-contract.json")
                    contract["adr_inputs"] = [adr_pin]
                    contract["layer_sha256"] = {}
                    summary = read("integrated-summary.json")
                    for role in ("a", "b"):
                        review = read(f"reviewer-{role}.json")
                        if role == "a":
                            review["checks"].append({"id": "DESIGN-SYSTEM-CONFORMANCE",
                                                     "result": "SKIP", "severity": "Minor",
                                                     "finding": "Synthetic fixture"})
                        review["checks"].append({"id": "DOMAIN-CONFORMANCE", "result": "SKIP",
                                                 "severity": "Minor", "finding": "Synthetic fixture"})
                        if role == "a":
                            summary["reviewer_a_check_ids"] = [c["id"] for c in review["checks"]]
                            for result_name in ("pass", "fail", "skip"):
                                summary[f"reviewer_a_{result_name}_count"] = sum(
                                    c["result"] == result_name.upper() for c in review["checks"])
                        save(f"reviewer-{role}.json", review)
                    save("integrated-summary.json", summary)
                    hashes = {
                        "precheck-result.json": hashlib.sha256((stage / "precheck-result.json").read_bytes()).hexdigest(),
                        "integrated-summary.json": hashlib.sha256((stage / "integrated-summary.json").read_bytes()).hexdigest(),
                    }
                    for path in DOMAIN + DS:
                        file = target / path
                        file.parent.mkdir(parents=True, exist_ok=True)
                        file.write_text("historical fixture bytes\n")
                    paths = [] if mode == "legacy" else DOMAIN + DS
                    if mode == "unknown":
                        paths = ["domain/other.md"]
                        (target / paths[0]).write_text("historical fixture bytes\n")
                    pins = [{"path": p, "sha256": hashlib.sha256((target / p).read_bytes()).hexdigest()}
                            for p in paths]
                    for reviewer in contract["reviewers"]:
                        role = reviewer["role"][-1]
                        review = read(f"reviewer-{role}.json")
                        for manifest in (review["allowed_input_manifest"], reviewer["allowed_input_manifest"]):
                            for entry in manifest:
                                name = entry["path"].rsplit("/", 1)[-1]
                                if name in hashes and entry["path"].startswith(
                                        f"reports/impl-review/{FEATURE}/attempt-1/round-2/"):
                                    entry["sha256"] = hashes[name]
                        additions = copy.deepcopy(pins)
                        if mode == "one-sided" and role == "b":
                            additions = []
                        if mode == "hash-mismatch" and role == "b":
                            additions[0]["sha256"] = "0" * 64
                        reviewer["allowed_input_manifest"] += [copy.deepcopy(adr_pin)] + copy.deepcopy(additions)
                        review["allowed_input_manifest"] += [copy.deepcopy(adr_pin)]
                        if mode != "output-only":
                            review["allowed_input_manifest"] += copy.deepcopy(additions)
                        save(f"reviewer-{role}.json", review)
                    save("impl-review-contract.json", contract)
                    if mode == "stale":
                        (target / DOMAIN[0]).write_text("changed\n")
                    if mode == "missing":
                        (target / DOMAIN[0]).unlink()
                    scripts = ROOT / "plugins/sdd-quality-loop/scripts"
                    for runtime, command in (("bash", ["bash", str(scripts / "check-workflow-state.sh")]),
                                             ("pwsh", ["pwsh", "-NoProfile", "-File", str(scripts / "check-workflow-state.ps1")])):
                        result = subprocess.run(command + ["--registry", str(target / "specs/workflow-state-registry.json")],
                                                text=True, capture_output=True)
                        output = result.stdout + result.stderr
                        self.assertEqual(result.returncode == 0, valid, f"{mode}/{runtime}: {output}")
                        if not valid:
                            self.assertIn(": stage-provenance:", output)
                        print(f"ok: adr-{mode}/{runtime}", flush=True)

    def test_persisted_twins(self):
        source = (ROOT / "tests/workflow-state.tests.sh").read_text()
        helper = re.search(r"^make_full_fixture\(\) \{\n.*?^\}", source, re.M | re.S).group()
        with tempfile.TemporaryDirectory(prefix="conditional-history-") as tmp:
            tmp = Path(tmp)
            driver = f"set -eu\nROOT={shlex.quote(str(ROOT))}\nTMP={shlex.quote(str(tmp))}\n"
            result = subprocess.run(["bash"], input=driver + helper + "\nmake_full_fixture base\n",
                                    text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            base = Path(result.stdout.strip())
            cases = [("legacy", "spec", [], True), ("spec-domain", "spec", DOMAIN, True),
                     ("impl-all", "impl", DOMAIN + DS, True),
                     ("absolute", "impl", DOMAIN + DS, True)]
            cases += [(mode, "impl", DOMAIN + DS, False) for mode in
                      ("one-sided", "hash-mismatch", "duplicate", "stale", "missing", "unknown", "traversal", "miscased")]
            cases += [("wrong-stage-spec", "spec", DS, False),
                      ("wrong-stage-task", "task", DOMAIN, False)]
            for mode, stage, paths, valid in cases:
                with self.subTest(case=mode):
                    target = tmp / mode
                    shutil.copytree(base, target)
                    for path in target.joinpath("reports").rglob("*.json"):
                        path.write_text(path.read_text().replace(str(base), str(target)))
                    # Presence does not retroactively add required pins to historical evidence.
                    for rel in DOMAIN + DS:
                        path = target / rel
                        path.parent.mkdir(parents=True, exist_ok=True)
                        path.write_text("historical fixture bytes\n")
                    if mode == "unknown":
                        paths = ["domain/other.md"]
                        (target / paths[0]).write_text("historical fixture bytes\n")
                    if mode == "traversal":
                        paths = ["domain/../domain/context-map.md"]
                    if mode == "miscased":
                        paths = ["domain/Context-map.md"]
                        (target / paths[0]).write_text("historical fixture bytes\n")
                    pins = [{"path": p, "sha256": hashlib.sha256((target / p).read_bytes()).hexdigest()}
                            for p in paths]
                    directories = (target / f"reports/{stage}-review/{FEATURE}").glob("attempt-*/round-*")
                    directory = max(directories, key=lambda p: (int(p.parent.name[8:]), int(p.name[6:])))
                    contract_path = directory / f"{stage}-review-contract.json"
                    contract = json.loads(contract_path.read_text())
                    for reviewer in contract["reviewers"]:
                        role = reviewer["role"][-1]
                        additions = copy.deepcopy(pins)
                        if mode == "one-sided" and role == "b":
                            additions = []
                        if mode == "hash-mismatch" and role == "b":
                            additions[0]["sha256"] = "0" * 64
                        if mode == "duplicate":
                            additions += copy.deepcopy(additions[:1])
                        reviewer["allowed_input_manifest"] += additions
                        output_path = directory / f"reviewer-{role}.json"
                        output = json.loads(output_path.read_text())
                        if stage == "task":
                            manifest = output["manifest"] if role == "a" else output["manifest"]["allowed_inputs"]
                        else:
                            manifest = output["allowed_input_manifest"]
                        manifest += copy.deepcopy(additions)
                        output_path.write_text(json.dumps(output))
                    contract_path.write_text(json.dumps(contract))
                    if mode == "absolute":
                        # All historical paths share a former checkout root.
                        for path in [contract_path, directory / "reviewer-a.json", directory / "reviewer-b.json"]:
                            data = json.loads(path.read_text())
                            def relocate(obj):
                                if isinstance(obj, dict):
                                    if "path" in obj:
                                        obj["path"] = "/historical/checkout/" + obj["path"].removeprefix(str(target) + "/")
                                    for value in obj.values():
                                        relocate(value)
                                elif isinstance(obj, list):
                                    for value in obj:
                                        relocate(value)
                            relocate(data)
                            path.write_text(json.dumps(data))
                    if mode == "stale":
                        (target / DOMAIN[0]).write_text("changed\n")
                    if mode == "missing":
                        (target / DOMAIN[0]).unlink()
                    scripts = ROOT / "plugins/sdd-quality-loop/scripts"
                    for runtime, command in [("bash", ["bash", str(scripts / "check-workflow-state.sh")]),
                                             ("pwsh", ["pwsh", "-NoProfile", "-File", str(scripts / "check-workflow-state.ps1")])]:
                        result = subprocess.run(command + ["--registry", str(target / "specs/workflow-state-registry.json")],
                                                text=True, capture_output=True)
                        output = result.stdout + result.stderr
                        self.assertEqual(result.returncode == 0, valid, f"{mode}/{runtime}: {output}")
                        if not valid:
                            self.assertIn(": stage-provenance:", output)
                        print(f"ok: {mode}/{runtime}", flush=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
