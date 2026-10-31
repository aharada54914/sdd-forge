"""Launch the reserved A20 reviewer once; capture output without changing verdicts."""
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
ROOT = Path(__file__).resolve().parents[3]
ROUND = ROOT / "reports/spec-review/epic-195-a7-compatibility/attempt-20/round-1"
INV = ROOT / "reports/review-context/epic-195-a7-compatibility-spec-a20r1-b-invocation.json"
spec = importlib.util.spec_from_file_location("transport", ROOT / "plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py")
transport = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transport)
data = json.loads(INV.read_bytes())
receipt = ROUND / "reviewer-b-reservation-receipt.txt"
prompt = transport.expected_prompt(ROOT, INV, receipt)
rolepath = ROOT / "plugins/sdd-review-loop/agents/spec-reviewer-b.md"
role = rolepath.read_text().split("---", 2)[2].lstrip()
roleconfig = {"a7-spec-reviewer-b": {"description": "Independent pinned specification reviewer B", "prompt": role, "tools": ["Read", "Grep", "Glob", "Bash"], "disallowedTools": ["Write", "Edit", "NotebookEdit"], "model": "sonnet"}}
wrapper = ROUND / "reviewer-b-cli-wrapper.json"
promptpath = ROUND / "reviewer-b-first-turn.txt"
rolefile = ROUND / "reviewer-b-role-config.json"
for path in (wrapper, promptpath, rolefile, ROUND / "reviewer-b-cli-stderr.txt"):
    if path.exists():
        raise SystemExit("Existing launch output; refusing duplicate delivery: " + path.name)
promptpath.write_bytes(prompt)
rolefile.write_text(json.dumps(roleconfig, ensure_ascii=False, indent=2) + "\n")
control = transport.receipt_control(data, receipt.read_text())
files = [str(INV.relative_to(ROOT)), "plugins/sdd-review-loop/references/review-context-boundary.md"] + [e["path"] for e in data["allowed_input_manifest"]]
permissions = ["Read", "Grep", "Glob"] + ["Bash(rtk proxy shasum -a 256 -- " + p + ")" for p in files]
permissions += ["Bash(" + c + ")" for c in control["hash_commands"]]
permissions += ["Bash(rtk proxy shasum -a 256)"]
args = ["rtk", "proxy", "claude", "-p", "--session-id", data["host_session_id"], "--output-format", "json", "--model", "sonnet", "--agents", str(rolefile), "--agent", "a7-spec-reviewer-b", "--tools", "Read,Grep,Glob,Bash", "--allowedTools", *permissions, "--disallowedTools", "Write", "Edit", "NotebookEdit"]
print("Launching reserved A20 reviewer B", flush=True)
with wrapper.open("xb") as out, (ROUND / "reviewer-b-cli-stderr.txt").open("xb") as err:
    result = subprocess.run(args, cwd=ROOT, input=prompt, stdout=out, stderr=err)
print("CLI exit:", result.returncode, flush=True)
if result.returncode:
    raise SystemExit(result.returncode)
transcript = Path("/Users/jrmag/.claude/projects/-Users-jrmag--codex-worktrees-a7-t005-intake-sdd-forge") / (data["host_session_id"] + ".jsonl")
proof = transport.postflight(ROOT, INV, transcript, promptpath, wrapper, receipt)
(ROUND / "reviewer-b-delivery-proof.json").write_text(json.dumps(proof, indent=2) + "\n")
print(json.dumps(proof), flush=True)
print(json.loads(wrapper.read_bytes()).get("result"), flush=True)
