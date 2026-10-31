"""Metadata-only registration proposal check; never launches implementation."""
import json
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[3]
HOST = {"gpt-6-astra", "gpt-6-sol", "gpt-6-luna", "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.4-mini"}
registry = json.loads((ROOT / "contracts/agent-model-capabilities.v2.json").read_text())
assert not HOST.intersection(model["name"] for model in registry["models"])
proposal = {"name": "gpt-6-sol", "canonical_tier": "strong", "supported_efforts": ["low", "medium", "high", "xhigh"], "default_effort": "high", "effort_control": {"claude-code": "none", "codex-cli": "flag"}}
# Proposed tier is pending governance approval; this check cannot prove capability.
registry["models"].append(proposal)
assert HOST.intersection(model["name"] for model in registry["models"]) == {"gpt-6-sol"}
assert "high" in proposal["supported_efforts"]
selector = ROOT / "plugins/sdd-implementation/scripts/select-agent-model.sh"
with tempfile.TemporaryDirectory(prefix="issue137-metadata-check-") as directory:
    path = pathlib.Path(directory)
    registered = path / "registry.json"
    registered.write_text(json.dumps(registry))
    candidates = path / "candidates.json"
    def select(items):
        candidates.write_text(json.dumps(items))
        return subprocess.run(["bash", str(selector), "--risk", "high", "--host", "codex-cli", "--registry", str(registered), "--candidates-file", str(candidates), "--json"], capture_output=True, text=True)
    empty = select([])
    assert empty.returncode == 0 and empty.stdout.strip() == "BLOCKED model-tier-unavailable"
    for name in ("unknown-model", "gpt-6-sol"):
        # Cost intentionally absent: neither unknown names nor incomplete launch inputs are accepted.
        result = select([{"name": name, "effort": "high", "available": True}])
        assert result.returncode == 1 and "invalid capability candidates" in result.stderr
    missing = select([{"effort": "high", "available": True}])
    assert missing.returncode == 1 and "invalid capability candidates" in missing.stderr
print("PASS: old intersection empty; proposed exact-name/high metadata valid; empty/missing/unknown/incomplete inputs fail closed. Strong tier and attempt cost remain unapproved; no launch success claimed.")
