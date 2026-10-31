"""Unreserved Sonnet probe for exact read-only pipeline component permissions."""
import hashlib
import json
from pathlib import Path
import shlex
import subprocess

ROOT = Path('/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge')
name = 'a7-component-permission-probe-20261006'
fixture = 'reports/verification/a7-exact-hash-permission-probe-20261006.txt'
outside = 'reports/verification/a7-custom-host-permission-probe-20261006.md'
rows = [('diagnostic/a.txt', 'a' * 64), ('diagnostic/b.txt', 'b' * 64)]
payload = '\n'.join(path + '\t' + digest for path, digest in rows)
input_digest = hashlib.sha256(payload.encode()).hexdigest()
receipt = '2|impl|impl-reviewer-a|diagnostic-run|diagnostic-session|-|allowed-inputs-v1|' + input_digest
producer = "rtk proxy printf '%s\\t%s\\n%s\\t%s' " + ' '.join(shlex.quote(value) for row in rows for value in row)
receipt_producer = 'rtk proxy printf %s ' + shlex.quote(receipt)
stdin_hash = 'rtk proxy shasum -a 256'
commands = [
    'rtk proxy shasum -a 256 ' + fixture,
    producer + ' | ' + stdin_hash,
    receipt_producer + ' | ' + stdin_hash,
    'rtk proxy test -d domain',
]
negative = 'rtk proxy shasum -a 256 ' + outside
rules = ['Bash(' + command + ')' for command in (
    commands[0], producer, receipt_producer, stdin_hash, commands[3]
)]
role = {
    'description': 'Unreserved permission diagnostic; no formal review.',
    'prompt': 'Run only the supplied commands exactly, in order. Do not read formal review inputs, write files, reserve identities, or issue a verdict. A routine first-Bash hook refusal may be retried once with identical bytes. Stop on any other refusal; do not change executor or command. The final out-of-scope hash should be denied, then stop.',
    'tools': ['Read', 'Grep', 'Glob', 'Bash'],
    'disallowedTools': ['Write', 'Edit', 'NotebookEdit'],
    'model': 'sonnet',
}
prompt = 'Unreserved exact-permission diagnostic. Execute in order, preserving every command byte. Report each tool result and stop on unexpected refusal:\n' + '\n'.join(f'{index}. {command}' for index, command in enumerate(commands + [negative], 1))
args = ['rtk', 'proxy', 'claude', '--bg', '--model', 'sonnet',
        '--permission-mode', 'dontAsk', '--tools', 'Read,Grep,Glob,Bash',
        '--disallowedTools', 'Write,Edit,NotebookEdit', '--allowedTools', *rules,
        '--plugin-dir', 'plugins/sdd-review-loop', '--agents', json.dumps({name: role}),
        '--agent', name, '--name', name, '--', prompt]
print(json.dumps({'commands': commands, 'negative': negative, 'rules': rules,
                  'expected_input_digest': input_digest,
                  'expected_receipt_digest': hashlib.sha256(receipt.encode()).hexdigest()}, ensure_ascii=False), flush=True)
raise SystemExit(subprocess.run(args, cwd=ROOT, stdin=subprocess.DEVNULL).returncode)
