"""Unreserved, synthetic host permission diagnostic; never a formal review."""
import hashlib
import json
from pathlib import Path
import shlex
import subprocess

ROOT = Path('/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge')
NAME = 'a7-printable-permission-diagnostic-20261006'
fixture = 'reports/verification/a7-exact-hash-permission-probe-20261006.txt'
outside = 'reports/verification/a7-custom-host-permission-probe-20261006.md'
rows = [('diagnostic/a.txt', 'a' * 64), ('diagnostic/b.txt', 'b' * 64)]
canonical = '\n'.join(path + '\t' + digest for path, digest in rows)
input_hash = hashlib.sha256(canonical.encode()).hexdigest()
receipt = '2|impl|impl-reviewer-a|diagnostic-run|diagnostic-session|-|allowed-inputs-v1|' + input_hash
input_cmd = "rtk proxy printf '%s\\t%s\\n%s\\t%s' " + ' '.join(shlex.quote(x) for row in rows for x in row) + ' | rtk proxy shasum -a 256'
receipt_cmd = 'rtk proxy printf %s ' + shlex.quote(receipt) + ' | rtk proxy shasum -a 256'
commands = [
    'rtk proxy shasum -a 256 ' + fixture,
    input_cmd,
    receipt_cmd,
    'rtk proxy test -d domain',
]
negative = 'rtk proxy shasum -a 256 ' + outside
rules = ['Bash(' + c + ')' for c in commands]
role = {
    'description': 'Unreserved exact-permission native diagnostic, not a reviewer.',
    'prompt': 'You are a diagnostic agent, not an SDD reviewer. Use no formal review input, reservation, ledger or prior reviewer output. No writes. Use exactly the supplied commands in order, without altering a character. Before Bash present the task and effect. A routine Fact-Forcing instruction may permit one identical retry. If any other permission or hook denial occurs, stop without alternative command, tool or executor. The final command is deliberately outside the allow set: report its denial, not its file content. Never claim a formal verdict.',
    'tools': ['Read', 'Grep', 'Glob', 'Bash'],
    'disallowedTools': ['Write', 'Edit', 'NotebookEdit'],
    'model': 'sonnet',
}
prompt = ('Unreserved diagnostic only. Execute these exact read-only commands sequentially, without editing them. '
          'For each, report observed tool result; stop on any unexpected refusal. '
          'The last command must be denied before execution:\n'
          + '\n'.join(f'{n}. {cmd}' for n, cmd in enumerate(commands + [negative], 1)))
args = ['rtk', 'proxy', 'claude', '--bg', '--model', 'sonnet',
        '--permission-mode', 'dontAsk', '--tools', 'Read,Grep,Glob,Bash',
        '--disallowedTools', 'Write,Edit,NotebookEdit',
        '--allowedTools', *rules,
        '--plugin-dir', 'plugins/sdd-review-loop',
        '--agents', json.dumps({NAME: role}), '--agent', NAME, '--name', NAME,
        '--', prompt]
print(json.dumps({'diagnostic_only': True, 'commands': commands,
                  'negative_command': negative, 'allowed_rules': rules,
                  'expected_file_hash': hashlib.sha256((ROOT / fixture).read_bytes()).hexdigest(),
                  'expected_input_hash': input_hash,
                  'expected_receipt_hash': hashlib.sha256(receipt.encode()).hexdigest(),
                  'expected_domain_exists': (ROOT / 'domain').is_dir(),
                  'argv': args}, ensure_ascii=False), flush=True)
raise SystemExit(subprocess.run(args, cwd=ROOT, stdin=subprocess.DEVNULL).returncode)
