"""One unreserved native Sonnet check of impl exact rules and session collision."""
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import uuid


ROOT = Path(__file__).resolve().parents[2]
source = ROOT / 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py'
spec = importlib.util.spec_from_file_location('nontty_transport', source)
transport = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transport)
session = str(uuid.uuid4())
entries = [
    {'path': 'reports/verification/a7-exact-hash-permission-probe-20261006.txt',
     'sha256': '7117325bcf161faf04bee60d4dea0153494cb0b4401a6c21e2478ff50afd00ed'},
    {'path': 'reports/verification/a7-component-permission-native-20261006.md',
     'sha256': hashlib.sha256((ROOT / 'reports/verification/a7-component-permission-native-20261006.md').read_bytes()).hexdigest()},
]
data = {'stage': 'impl', 'role': 'impl-reviewer-a', 'sequence': 2,
        'run_id': session, 'host_session_id': session,
        'previous_record_sha256': 'a' * 64, 'allowed_input_manifest': entries}
inputs = '\n'.join(item['path'] + '\t' + item['sha256'] for item in entries)
input_digest = hashlib.sha256(inputs.encode()).hexdigest()
record = '|'.join(('2', 'impl', 'impl-reviewer-a', session, session,
                   'a' * 64, 'allowed-inputs-v1', input_digest))
record_digest = hashlib.sha256(record.encode()).hexdigest()
receipt = ('REVIEW_CONTEXT_OK ' + record_digest + ' sequence=2 previous_record_sha256=' +
           'a' * 64 + ' pre_append_tip_sequence=1 identity_unique=yes\n')
control = transport.receipt_control(data, receipt)
outside = 'reports/verification/a7-custom-host-permission-probe-20261006.md'
commands = ['rtk proxy shasum -a 256 ' + entries[0]['path'],
            'rtk proxy shasum -a 256 plugins/sdd-review-loop/references/review-context-boundary.md'] + control['hash_commands'] + [
    'rtk proxy test -d domain', 'rtk proxy shasum -a 256 ' + outside]
role_name = 'impl-nontty-permission-diagnostic'
role = {'description': 'Synthetic, unreserved permission check only.',
        'prompt': 'Execute the exact listed commands in order, then stop. A routine first-Bash fact-forcing refusal may be retried once with identical bytes. Stop after the deliberate out-of-scope refusal. Do not read formal review inputs, reserve identities, write files or issue a verdict.',
        'tools': ['Read', 'Grep', 'Glob', 'Bash'],
        'disallowedTools': ['Write', 'Edit', 'NotebookEdit'], 'model': 'sonnet'}
prompt = 'Synthetic unreserved native diagnostic. Execute these exact commands in order, report each result, then stop:\n' + '\n'.join(
    str(i) + '. ' + command for i, command in enumerate(commands, 1))
base = ['rtk', 'proxy', 'claude', '-p', '--session-id', session, '--model', 'sonnet',
        '--permission-mode', 'dontAsk', '--tools', 'Read,Grep,Glob,Bash',
        '--disallowedTools', 'Write,Edit,NotebookEdit', '--allowedTools',
        *control['exact_permission_rules'], '--plugin-dir', 'plugins/sdd-review-loop',
        '--agents', json.dumps({role_name: role}), '--agent', role_name,
        '--output-format', 'json']
print(json.dumps({'session': session, 'expected_input_digest': input_digest,
                  'expected_record_digest': record_digest,
                  'rules': control['exact_permission_rules'], 'commands': commands}), flush=True)
first = subprocess.run(base, input=prompt, text=True, capture_output=True, cwd=ROOT)
print(json.dumps({'first_exit': first.returncode, 'stdout': first.stdout,
                  'stderr': first.stderr}), flush=True)
if first.returncode != 0:
    raise SystemExit(1)
collision = subprocess.run(['rtk', 'proxy', 'claude', '-p', '--session-id', session,
                            '--model', 'sonnet', '--permission-mode', 'dontAsk',
                            '--tools', '', '--output-format', 'json'],
                           input='Synthetic collision check; do not run tools.',
                           text=True, capture_output=True, cwd=ROOT)
print(json.dumps({'collision_exit': collision.returncode,
                  'collision_stdout': collision.stdout,
                  'collision_stderr': collision.stderr}), flush=True)
