"""Persist whitelisted runtime provenance only; never copy account metadata."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
source = Path("/Users/jrmag/.codex/sessions/2026/10/04/rollout-2026-10-04T21-17-27-01a106d8-fc9e-7c32-a79d-f3350a828e2e.jsonl")
rows = [json.loads(line) for line in source.read_text().splitlines()]
meta = rows[0]["payload"]
assert meta["cwd"] == "/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/tmp.vWUJRNMIZw"
turns = [r["payload"] for r in rows if r["type"] == "turn_context"]
assert turns and all(t["model"] == "gpt-6.1-sol" for t in turns)
calls = [r["payload"] for r in rows if r["type"] == "response_item"
         and r["payload"].get("type") in ("function_call", "custom_tool_call")]
report = {"source": "Codex persisted exec session metadata and turn_context",
          "session_id": meta["id"], "cli_version": meta["cli_version"],
          "model_provider": meta["model_provider"], "runtime_model": turns[0]["model"],
          "sandbox_policy": turns[0]["sandbox_policy"],
          "approval_policy": turns[0]["approval_policy"],
          "tool_calls": [{"name": c.get("name"), "type": c["type"]} for c in calls],
          "verdict_model_unmodified": "GPT-6",
          "verdict_model_note": "Panelist self-report retained without editorial normalization; precise runtime model is recorded above."}
assert not calls, "Investigate any access beyond the supplied bundle"
(HERE / "attempt-2/runtime-provenance.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
