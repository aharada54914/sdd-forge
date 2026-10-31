"""Extract real child output and validate collection, without running consensus."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
VERIFY = HERE.parent
run = HERE / "attempt-2"
launch = json.loads((run / "launch.json").read_text())
bundle = (VERIFY / "T-004.panelist-input.txt").read_bytes()
assert hashlib.sha256(bundle).hexdigest() == launch["bundle_sha256"]
agents = json.loads((Path(launch["cwd"]) / "agents.json").read_text())
agent = agents["blind-panelist"]
assert agent["tools"] == [] and agent["model"] == "sonnet"
assert agent["prompt"].split("\n\n## Sanitized Input Bundle\n\n", 1)[1].encode() == bundle
records = []
for line in (run / "claude.jsonl").read_text().splitlines():
    try:
        records.append(json.loads(line))
    except json.JSONDecodeError:
        pass
calls = [c for r in records if r.get("type") == "assistant"
         for c in r.get("message", {}).get("content", []) if c.get("type") == "tool_use"]
assert len(calls) == 1 and calls[0]["name"] == "Agent"
assert calls[0]["input"]["subagent_type"] == "blind-panelist"

def parse_verdict(text):
    text = text.strip()
    if text.startswith("```json\n") and text.endswith("\n```"):
        text = text[8:-4]
    try:
        value = json.loads(text)
    except (json.JSONDecodeError, TypeError):
        return None
    return value if isinstance(value, dict) and value.get("schema") == "cross-model-verdict/v1" else None

child = [parse_verdict(c.get("text", "")) for r in records
         if r.get("type") == "assistant" and r.get("parent_tool_use_id") == calls[0]["id"]
         for c in r.get("message", {}).get("content", []) if c.get("type") == "text"]
child = [v for v in child if v is not None]
assert len(child) == 1, "Require actual forwarded child verdict, not dispatcher invention"
last = [r for r in records if r.get("type") == "result"][-1]
assert last["is_error"] is False and last["subagent_stats"]["completed"] == 1
assert parse_verdict(last["result"]) == child[0]
anthropic = child[0]
openai = json.loads((VERIFY / "T-004.panelist-openai.verdict.json").read_text())
for vendor, verdict in (("anthropic", anthropic), ("openai", openai)):
    for field, expected in (("schema", "cross-model-verdict/v1"), ("task_id", "T-004"),
                            ("feature", "epic-196-a8-integration"), ("vendor", vendor),
                            ("blind", True), ("input_digest", launch["input_digest"])):
        assert verdict[field] == expected, (vendor, field)
    assert verdict["verdict"] in ("PASS", "NEEDS_WORK")
    assert isinstance(verdict["model"], str) and verdict["model"]
    assert verdict["consent"]["kind"] == "human-flag" and verdict["consent"]["ref"]
    assert isinstance(verdict["findings"], list)
    for finding in verdict["findings"]:
        assert finding["severity"] in ("Critical", "Major", "Minor")
        assert finding["ref"] and finding["note"]
assert anthropic["model"] in last["modelUsage"]
target = VERIFY / "T-004.panelist-anthropic.verdict.json"
with target.open("x") as stream:
    stream.write(json.dumps(anthropic, indent=2, ensure_ascii=False) + "\n")
summary = {"collection_validation": "PASS", "input_digest": launch["input_digest"],
           "bundle_sha256": launch["bundle_sha256"], "agent_input_bytes_exact": True,
           "actual_agent_call_count": 1, "child_tools": [],
           "anthropic_runtime_model": anthropic["model"],
           "openai_self_reported_model": openai["model"],
           "openai_runtime_model_note": "Existing official runner deletes its raw successful transcript; model field is panelist self-report, not an independently retained runtime identifier.",
           "verdicts": [{"vendor": v["vendor"], "verdict": v["verdict"], "findings": len(v["findings"])} for v in (anthropic, openai)],
           "consensus_gate_run": False, "primary_evaluator_supplied": False}
(run / "validation.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary, indent=2))
