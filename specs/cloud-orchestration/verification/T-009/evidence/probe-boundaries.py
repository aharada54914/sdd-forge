"""Offline diagnostics only; NOT a cloud-profile implementation or native proof."""
from __future__ import annotations

import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from types import ModuleType
from typing import Any

ROOT = Path(__file__).resolve().parents[5]
SCRIPTS = ROOT / "plugins/sdd-quality-loop/scripts"
sys.path.insert(0, str(SCRIPTS))
sys.dont_write_bytecode = True


def load(name: str, path: Path) -> ModuleType:
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def main() -> None:
    verification = load("t009_verification_fixture", ROOT / "tests/cloud-orchestration-verification.tests.py")
    selected = load("t009_selected_fixture", ROOT / "tests/sdd-domain-multitarget-T-003.tests.py")
    reducer = load("t009_reducer", SCRIPTS / "cloud_verification.py")
    result: dict[str, Any] = {"classification": "synthetic-offline-diagnostics", "versions": [], "provenance": []}
    case = verification.reducer_case()
    reduced = reducer.reduce(*case, now="2026-10-18T06:01:01Z")
    assert reduced["overall_result"] == "PASS" and reduced["evidence_complete"] is False
    result["provenance"].append({"case": "matched synthetic collection", "overall_result": reduced["overall_result"], "evidence_complete": reduced["evidence_complete"]})
    native_claim = copy.deepcopy(case)
    native_claim[4]["classification"] = "native"
    for record in native_claim[5]:
        observation = json.loads(record["observation_bytes"])
        payload = json.loads(record["payload_bytes"])
        observation["classification"] = "native"
        payload["context_sha256"] = reducer.digest(reducer.encode(native_claim[4]))
        record["payload_bytes"] = reducer.encode(payload)
        observation["result"]["sha256"] = reducer.digest(record["payload_bytes"])
        record["observation_bytes"] = reducer.encode(observation)
    try:
        reducer.reduce(*native_claim, now="2026-10-18T06:01:01Z")
    except ValueError as error:
        assert str(error) == "COLLECTOR_PROVENANCE_REQUIRED", str(error)
        result["provenance"].append({"case": "self-consistent native labels with default untrusted caller", "rejected": str(error)})
    else:
        raise AssertionError("Untrusted native labels accepted")
    # Sensitivity demonstration ONLY: an unsafe reader could assert this boolean.
    # No authenticated provider transport has run, regardless of returned fields.
    unsafe = reducer.reduce(*native_claim, now="2026-10-18T06:01:01Z", trusted_native=True)
    assert unsafe["evidence_complete"] is True
    result["provenance"].append({"case": "deliberately unsafe trust assertion on same forged fixture", "returned_evidence_complete": unsafe["evidence_complete"], "native_evidence": False, "meaning": "Saved labels/hashes cannot authorize trusted_native=True"})
    registry, manifest, baseline = selected.passing_fixture("iac-cloud")
    variants = [
        ("absent schema (legacy)", None, None),
        ("current v2", "verification-contract/v2", None),
        ("explicit v1 (not recognized by current parser)", "verification-contract/v1", None),
        ("prospective v3 (not implemented)", "verification-contract/v3", None),
        ("unknown version", "verification-contract/v999", None),
        ("cloud reducer output is not a legacy contract", "cloud-verification/v1", None),
        ("v2 with unknown cloud discriminator", "verification-contract/v2", {"profile": "unregistered-cloud-profile"}),
        ("v2 with unknown field", "verification-contract/v2", {"unknown_field": "diagnostic"}),
    ]
    with tempfile.TemporaryDirectory(prefix="boundary-", dir=os.environ["TMPDIR"]) as temp:
        root = Path(temp)
        (root / "evidence.log").write_text("Synthetic legacy fixture; not cloud evidence.\n")
        (root / "verifier.py").write_text("# Synthetic verifier existence fixture, never executed.\n")
        for label, version, extra in variants:
            contract = copy.deepcopy(baseline)
            if version is None:
                contract.pop("schema", None)
            else:
                contract["schema"] = version
            if extra:
                contract.update(extra)
            path = root / "contract.json"
            path.write_text(json.dumps(contract))
            commands = {
                "python": [sys.executable, "-B", str(SCRIPTS / "check-contract.py"), str(path), str(root)],
                "posix": ["sh", str(SCRIPTS / "check-contract.sh"), str(path), str(root)],
                "powershell": ["/workspace/.tools/sdd-forge-dev/bin/pwsh", "-NoProfile", "-File", str(SCRIPTS / "check-contract.ps1"), "-ContractPath", str(path), "-RepoRoot", str(root)],
            }
            for consumer, cmd in commands.items():
                proc = subprocess.run(cmd, capture_output=True, text=True, timeout=30, env={"PATH": os.defpath, "HOME": temp, "TMPDIR": temp})
                result["versions"].append(dict(case=label, consumer=consumer, command=cmd, exit_code=proc.returncode, stdout=proc.stdout, stderr=proc.stderr))
            proc, plan, _ = selected.SelectedPlanTests().evaluate(registry, manifest, contract)
            result["versions"].append(dict(case=label, consumer="selected-plan CLI (existing fixture helper)", exit_code=proc.returncode, stdout=proc.stdout, stderr=proc.stderr, verdict=plan["verdict"] if plan else None, check_ids=[c["id"] for c in plan["checks"]] if plan else []))
    result["legacy_sets"] = {"baseline": sorted(selected.legacy.BASELINE_IDS), "risk_tiers": {key: sorted(value) for key, value in selected.legacy.RISK_TIERS.items()}, "stacks": sorted(selected.legacy.KNOWN_STACKS)}
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
