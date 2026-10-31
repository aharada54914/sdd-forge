"""Check exact-name routing and fail-closed inputs; never launch a worker."""
import json
from decimal import Decimal, ROUND_CEILING
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
candidate = json.loads(Path(__file__).with_name("launch-candidates.json").read_text())[0]
registry = json.loads((ROOT / "contracts/agent-model-capabilities.v2.json").read_text())
models = [model for model in registry["models"] if model["name"] == "gpt-6-astra"]
assert len(models) == 1, "exact host model is not registered"
assert models[0] == {
    "name": "gpt-6-astra", "canonical_tier": "strong",
    "supported_efforts": ["low", "medium", "high", "xhigh"],
    "default_effort": "high",
    "effort_control": {"claude-code": "none", "codex-cli": "flag"},
}
estimate = (Decimal(2359194) * 20 + Decimal(13741) * 75) / 1000000
assert Decimal(candidate["cost"]) == estimate.quantize(Decimal(".01"), rounding=ROUND_CEILING)
assert candidate["cost_estimate_source"] and candidate["cost_estimate_timestamp"]

with tempfile.TemporaryDirectory(prefix="issue137-routing-") as directory:
    path = Path(directory) / "candidates.json"
    def select(items):
        path.write_text(json.dumps(items))
        return subprocess.run([
            "bash", str(ROOT / "plugins/sdd-implementation/scripts/select-agent-model.sh"),
            "--risk", "high", "--host", "codex-cli",
            "--registry", str(ROOT / "contracts/agent-model-capabilities.v2.json"),
            "--candidates-file", str(path), "--required-tier", "strong",
            "--effort-policy", "matrix", "--json",
        ], capture_output=True, text=True)
    result = select([candidate])
    assert result.returncode == 0, result.stderr
    selected = json.loads(result.stdout)
    assert (selected["model"], selected["canonical_tier"], selected["effort"], selected["effort_control"]) == (
        "gpt-6-astra", "strong", "high", "flag")
    assert Decimal(selected["estimated_cost_per_attempt_usd"]) == Decimal("48.22")
    for items in ([], [{**candidate, "available": False}]):
        result = select(items)
        assert result.returncode == 0 and result.stdout.strip() == "BLOCKED model-tier-unavailable"
    invalid = [{**candidate, "name": "openai/gpt-6-astra"}, {**candidate, "cost": "NaN"}]
    invalid += [{key: value for key, value in candidate.items() if key != missing}
                for missing in ("name", "cost", "available")]
    for item in invalid:
        result = select([item])
        assert result.returncode == 1 and "invalid capability candidates" in result.stderr
print("PASS: exact host strong/high routing; conditional cost; unavailable and malformed inputs fail closed. No worker/native activation proof.")
