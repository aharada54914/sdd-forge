"""Single reserved first-turn delivery; raw result only, no conversion or retry."""
from pathlib import Path
import json
import runpy
import subprocess

ROOT = Path(__file__).resolve().parents[3]
ROUND = ROOT / 'reports/spec-review/epic-195-a7-compatibility/attempt-22/round-1'
INV = ROOT / 'reports/review-context/epic-195-a7-compatibility-spec-a22r1-a-invocation.json'
transport = runpy.run_path(str(ROOT / 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py'))
data = json.loads(INV.read_bytes())
receipt = ROUND / 'reviewer-a-reservation-receipt.txt'
prompt = transport['expected_prompt'](ROOT, INV, receipt)
control = transport['receipt_control'](data, receipt.read_text())
role = (ROOT / 'plugins/sdd-review-loop/agents/spec-reviewer-a.md').read_text().split('---', 2)[2].lstrip()
roleconfig = {'a7-spec-reviewer-a': {'description': 'Independent pinned specification reviewer A',
    'prompt': role, 'tools': ['Read', 'Grep', 'Glob', 'Bash', 'StructuredOutput'],
    'disallowedTools': ['Write', 'Edit', 'NotebookEdit'], 'model': 'sonnet'}}
schema = {'type': 'object', 'additionalProperties': False, 'properties': {
    'schema': {'type': 'string', 'enum': ['spec-reviewer-a/v1']},
    'stage': {'type': 'string', 'enum': ['spec']},
    'role': {'type': 'string', 'enum': ['spec-reviewer-a']},
    'run_id': {'type': 'string'}, 'host_session_id': {'type': 'string'},
    'allowed_input_manifest': {'type': 'array', 'items': {'type': 'object',
        'properties': {'path': {'type': 'string'}, 'sha256': {'type': 'string'}},
        'required': ['path', 'sha256'], 'additionalProperties': False}},
    'verdict': {'type': 'string', 'enum': ['PASS', 'NEEDS_WORK', 'BLOCKED']},
    'checks': {'type': 'array', 'items': {'type': 'object', 'properties': {
        'id': {'type': 'string'}, 'result': {'type': 'string', 'enum': ['PASS', 'FAIL', 'SKIP']},
        'severity': {'type': 'string', 'enum': ['Critical', 'Major', 'Minor']},
        'finding': {'type': 'string'}},
        'required': ['id', 'result', 'severity', 'finding'], 'additionalProperties': False}}},
    'required': ['schema', 'stage', 'role', 'run_id', 'host_session_id', 'allowed_input_manifest', 'verdict', 'checks']}
files = [str(INV.relative_to(ROOT)), 'plugins/sdd-review-loop/references/review-context-boundary.md'] + [e['path'] for e in data['allowed_input_manifest']]
permissions = ['Read', 'Grep', 'Glob'] + ['Bash(rtk proxy shasum -a 256 -- ' + p + ')' for p in files]
permissions += ['Bash(' + c + ')' for c in control['hash_commands']]
permissions += ['Bash(rtk proxy shasum -a 256)']
names = ['reviewer-a-first-turn.txt', 'reviewer-a-role-config.json',
         'reviewer-a-cli-wrapper.json', 'reviewer-a-cli-stderr.txt', 'reviewer-a-delivery-proof.json']
for name in names:
    if (ROUND / name).exists():
        raise SystemExit('Existing launch output; no duplicate delivery: ' + name)
transcript = Path('/Users/jrmag/.claude/projects/-Users-jrmag--codex-worktrees-a7-t005-intake-sdd-forge') / (data['host_session_id'] + '.jsonl')
if transcript.exists():
    raise SystemExit('Native session already exists; no launch')
for name, content in [('reviewer-a-first-turn.txt', prompt),
        ('reviewer-a-role-config.json', (json.dumps(roleconfig, ensure_ascii=False, indent=2) + '\n').encode())]:
    with (ROUND / name).open('xb') as out:
        out.write(content)
args = ['rtk', 'proxy', 'claude', '-p', '--session-id', data['host_session_id'],
    '--output-format', 'json', '--json-schema', json.dumps(schema), '--model', 'sonnet',
    '--agents', str(ROUND / 'reviewer-a-role-config.json'), '--agent', 'a7-spec-reviewer-a',
    '--tools', 'Read,Grep,Glob,Bash', '--allowedTools', *permissions,
    '--disallowedTools', 'Write', 'Edit', 'NotebookEdit']
print('Launching reserved A21 reviewer A once', flush=True)
with (ROUND / 'reviewer-a-cli-wrapper.json').open('xb') as out, (ROUND / 'reviewer-a-cli-stderr.txt').open('xb') as err:
    result = subprocess.run(args, cwd=ROOT, input=prompt, stdout=out, stderr=err)
print('CLI exit:', result.returncode, flush=True)
if result.returncode:
    raise SystemExit(result.returncode)
proof = transport['postflight'](ROOT, INV, transcript, ROUND / 'reviewer-a-first-turn.txt',
    ROUND / 'reviewer-a-cli-wrapper.json', receipt)
with (ROUND / 'reviewer-a-delivery-proof.json').open('x') as out:
    out.write(json.dumps(proof, indent=2) + '\n')
print(json.dumps(proof), flush=True)
print('Raw result retained for ordinary full validator; no reviewer output adopted yet.', flush=True)
