"""Capture one normal reservation and one fresh native reviewer execution."""
import hashlib
import importlib.util
import json
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parents[3]
out = root / 'reports/spec-review/epic-195-a7-compatibility/attempt-19/round-1'
inv = root / 'reports/review-context/epic-195-a7-compatibility-spec-a19r1-a-invocation.json'
session = 'da097895-8e92-4519-bf20-fc4b5f29ac5c'
native = pathlib.Path('/Users/jrmag/.claude/projects/-Users-jrmag--codex-worktrees-a7-t005-intake-sdd-forge') / (session + '.jsonl')
spec = importlib.util.spec_from_file_location('transport', root / 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py')
transport = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transport)

def save(name, data):
    with (out / name).open('xb') as handle:
        handle.write(data)

pre = transport.preflight(root, inv, native)
pre_bytes = (json.dumps(pre, sort_keys=True) + '\n').encode()
save('reviewer-a-nontty-preflight.json', pre_bytes)
proposal = dict(kind='claude-nontty-caller-proposal', host_id=session, host_session_id=session,
                role='spec-reviewer-a', feature='epic-195-a7-compatibility', attempt=19, round=1,
                review_turn_started=False, preflight_result_path=str((out / 'reviewer-a-nontty-preflight.json').relative_to(root)),
                preflight_result_sha256=hashlib.sha256(pre_bytes).hexdigest(), preflight_result='PREFLIGHT_OK')
save('reviewer-a-host-allocation.json', (json.dumps(proposal, indent=2) + '\n').encode())
old = out.parent.parent / 'attempt-18/round-1/reviewer-a-role-config.json'
role_bytes = old.read_bytes()
role = json.loads(role_bytes)['a7-spec-reviewer-a']
assert role['prompt'].strip() == (root / 'plugins/sdd-review-loop/agents/spec-reviewer-a.md').read_text().split('---', 2)[2].strip()
save('reviewer-a-role-config.json', role_bytes)
reserved = subprocess.run(['rtk', 'proxy', 'bash', 'plugins/sdd-quality-loop/scripts/validate-review-context-set.sh', str(inv.relative_to(root)), '.', '--reserve'], cwd=root, capture_output=True)
save('reviewer-a-reservation-stderr.txt', reserved.stderr)
save('reviewer-a-reservation-receipt.txt', reserved.stdout)
print(reserved.stdout.decode(), flush=True)
if reserved.returncode:
    raise SystemExit(reserved.returncode)
prompt = transport.expected_prompt(root, inv, out / 'reviewer-a-reservation-receipt.txt')
save('reviewer-a-first-turn.txt', prompt)
args = ['rtk', 'proxy', 'claude', '-p', '--session-id', session, '--output-format', 'json', '--model', 'sonnet',
        '--agents', str(out / 'reviewer-a-role-config.json'), '--agent', 'a7-spec-reviewer-a',
        '--tools', 'Read,Grep,Glob,Bash', '--allowedTools', 'Read', 'Grep', 'Glob',
        'Bash(rtk proxy sha256sum -- *)', 'Bash(rtk proxy shasum -a 256 -- *)',
        '--disallowedTools', 'Write', 'Edit', 'NotebookEdit']
result = subprocess.run(args, cwd=root, input=prompt, capture_output=True)
save('reviewer-a-cli-wrapper.json', result.stdout)
save('reviewer-a-cli-stderr.txt', result.stderr)
print('CLI_EXIT', result.returncode, flush=True)
if result.returncode:
    raise SystemExit(result.returncode)
proof = transport.postflight(root, inv, native, out / 'reviewer-a-first-turn.txt', out / 'reviewer-a-cli-wrapper.json', out / 'reviewer-a-reservation-receipt.txt')
save('reviewer-a-delivery-proof.json', (json.dumps(proof, sort_keys=True) + '\n').encode())
print(json.dumps(proof), flush=True)
