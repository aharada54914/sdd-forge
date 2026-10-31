"""Unreserved diagnostic allocation only; never formal reviewer authority."""
import hashlib
import json
from pathlib import Path
import shlex
import subprocess

ROOT = Path('/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge')
NAME = 'a7-permission-diagnostic-only-20261006'
fixture = 'reports/verification/a7-exact-hash-permission-probe-20261006.txt'
file_hash = hashlib.sha256((ROOT / fixture).read_bytes()).hexdigest()
synthetic_inputs = 'diagnostic/a.txt\t' + 'a' * 64 + '\ndiagnostic/b.txt\t' + 'b' * 64
input_hash = hashlib.sha256(synthetic_inputs.encode()).hexdigest()
synthetic_receipt = '2|impl|impl-reviewer-a|diagnostic-run|diagnostic-session|-|allowed-inputs-v1|' + input_hash
receipt_hash = hashlib.sha256(synthetic_receipt.encode()).hexdigest()
producer1 = 'rtk proxy printf %s ' + shlex.quote(synthetic_inputs)
producer2 = 'rtk proxy printf %s ' + shlex.quote(synthetic_receipt)
sink = 'rtk proxy shasum -a 256'
commands = [sink + ' ' + fixture, producer1 + ' | ' + sink,
            producer2 + ' | ' + sink, 'rtk proxy test -d domain']
rules = ['Bash(' + c + ')' for c in [commands[0], producer1, producer2, sink, commands[3]]]
role = {'description': 'Unreserved custom-host read-only permission diagnostic, never a formal review.',
        'prompt': 'You are a diagnostic agent, not an SDD reviewer. No formal review, reservation, ledger, specification or reviewer-output reads. Execute only the exact supplied synthetic diagnostic commands. Never write any file or use other commands. Before Bash present facts. If the routine Fact-Forcing hook explicitly requests same-operation retry, repeat the facts and retry the identical operation once. On any other policy or permission denial stop; do not switch tools or executors. An ordinary test -d exit 1 means absent and is not permission denial. Report exact observed outputs without claiming formal PASS.',
        'tools': ['Read', 'Grep', 'Glob', 'Bash'],
        'disallowedTools': ['Write', 'Edit', 'NotebookEdit'], 'model': 'sonnet'}
args = ['rtk', 'proxy', 'claude', '--bg', '--model', 'sonnet',
        '--permission-mode', 'dontAsk', '--tools', 'Read,Grep,Glob,Bash',
        '--disallowedTools', 'Write,Edit,NotebookEdit',
        '--allowedTools', *rules,
        '--plugin-dir', 'plugins/sdd-review-loop',
        '--agents', json.dumps({NAME: role}), '--agent', NAME, '--name', NAME]
print(json.dumps({'diagnostic_only': True, 'commands': commands,
                  'expected_file_hash': file_hash, 'expected_input_hash': input_hash,
                  'expected_receipt_hash': receipt_hash,
                  'expected_domain_exists': (ROOT / 'domain').is_dir(),
                  'argv': args}, ensure_ascii=False), flush=True)
raise SystemExit(subprocess.run(args, cwd=ROOT, stdin=subprocess.DEVNULL).returncode)
