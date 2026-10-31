"""Local blind collection only; never computes consensus or changes task status."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent / "attempt-2"
OUT.mkdir(exist_ok=True)
VERIFY = ROOT / "specs/epic-196-a8-integration/verification"
BUNDLE = VERIFY / "T-004.panelist-input.txt"
DIGEST = "3dc43bd2241d3e746a9cacdb6de3dcdb331f8d9b507b95c3d294cf1c9cfb181a"
body = BUNDLE.read_bytes()
assert hashlib.sha256(b"\n".join(body.split(b"\n")[8:])).hexdigest() == DIGEST
assert not list(VERIFY.glob("T-004.panelist-*.verdict.json")), "Preserve prior verdicts"
assert not (OUT / "launch.json").exists(), "Do not overwrite collection records"
env = dict(os.environ)
for key in ("SDD_EVIDENCE_KEY", "SDD_SUDO_KEY", "SDD_SUDO_KEY_FILE"):
    env.pop(key, None)
assert not env.get("CI"), "Collection is local only"
env["SDD_PANELIST_CODEX_CMD"] = os.environ.get("SDD_PANELIST_CODEX_CMD", "/Applications/ChatGPT.app/Contents/Resources/codex")
env["SDD_PANELIST_TIMEOUT"] = "1200"
scratch = Path(tempfile.mkdtemp(prefix="a8-t004-blind-"))
role = (
    "You are an independent read-only Anthropic Sonnet panelist. Review ONLY the "
    "sanitized bundle supplied in your prompt for correctness, completeness, and "
    "adherence to its requirements/design. No tools, outside context, peer verdicts, "
    "or primary evaluator input are permitted. The task's own implementation report "
    "is an author claim to verify, not independent proof. Return exactly one bare "
    "JSON object with schema='cross-model-verdict/v1', task_id='T-004', "
    "feature='epic-196-a8-integration', vendor='anthropic', model=your actual model "
    "identifier, verdict='PASS' or 'NEEDS_WORK', findings=[{severity:'Critical' or "
    "'Major' or 'Minor',ref:'path:line or section',note:'issue'}], blind=true, "
    "input_digest copied from bundle header, consent={kind:'human-flag', "
    "ref:'tasks.md T-004 Cross-Model: enabled'}. No code edits or task approval."
)
agents = {"blind-panelist": {"description": "Independent blind read-only review; the complete sanitized task bundle is already supplied in this agent's system instructions",
                           "prompt": role + "\n\n## Sanitized Input Bundle\n\n" + body.decode(), "tools": [], "model": "sonnet"}}
agents_file = scratch / "agents.json"
agents_file.write_text(json.dumps(agents))
claude = ["/Users/jrmag/.local/bin/claude", "--print", "--model", "sonnet",
          "--output-format", "stream-json", "--verbose", "--forward-subagent-text",
          "--include-hook-events", "--no-session-persistence", "--tools", "Agent",
          "--allowedTools", "Agent", "--permission-mode", "dontAsk",
          "--strict-mcp-config", "--mcp-config", '{"mcpServers":{}}',
          "--disable-slash-commands", "--agents", str(agents_file),
          "--system-prompt", "You are only a blind review dispatcher. Invoke the "
          "Agent tool exactly once with subagent_type blind-panelist. Its system "
          "instructions already contain the full sanitized bundle. Send only the "
          "instruction to review that bundle and return the specified JSON. "
          "Do not review it yourself, supply any other context, or add findings. "
          "Return the agent's JSON unchanged. No other tool or repository access."]
gpt = ["bash", str(ROOT / "plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh"),
       "--task", "T-004", "--feature", "epic-196-a8-integration",
       "--input", str(BUNDLE), "--spec-root", str(ROOT / "specs"), "--digest", DIGEST]
(OUT / "launch.json").write_text(json.dumps({"started": time.time(),
    "bundle_sha256": hashlib.sha256(body).hexdigest(), "input_digest": DIGEST,
    "cwd": str(scratch), "gpt": gpt, "claude": claude,
    "keys_unset": ["SDD_EVIDENCE_KEY", "SDD_SUDO_KEY", "SDD_SUDO_KEY_FILE"],
    "hooks_disabled": False, "permission_bypass": False}, indent=2) + "\n")
with (OUT / "gpt.log").open("wb") as gout, (OUT / "claude.jsonl").open("wb") as cout:
    gp = subprocess.Popen(gpt, cwd=scratch, env=env, stdout=gout, stderr=subprocess.STDOUT)
    cp = subprocess.Popen(claude, cwd=scratch, env=env, stdin=subprocess.PIPE,
                          stdout=cout, stderr=subprocess.STDOUT)
    cp.stdin.write(b"Invoke the fresh blind-panelist Agent now. Its complete sanitized bundle is already present in its agent definition. Return its JSON unchanged.\n")
    cp.stdin.close()
    print(json.dumps({"gpt_pid": gp.pid, "claude_pid": cp.pid, "scratch": str(scratch)}), flush=True)
    deadline = time.monotonic() + 1250
    while gp.poll() is None or cp.poll() is None:
        if time.monotonic() > deadline:
            for p in (gp, cp):
                if p.poll() is None:
                    p.terminate()
            break
        time.sleep(1)
    results = {"gpt_exit": gp.wait(), "claude_exit": cp.wait(), "finished": time.time()}
(OUT / "completion.json").write_text(json.dumps(results, indent=2) + "\n")
print(json.dumps(results), flush=True)
