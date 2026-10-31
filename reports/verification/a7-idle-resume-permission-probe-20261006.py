"""Unreserved native probe of stopped idle context plus exact resume permissions."""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path('/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge')
name = 'a7-idle-resume-permission-probe-20261006'
fixture = 'reports/verification/a7-exact-hash-permission-probe-20261006.txt'
role = {
    'description': 'Unreserved idle/resume permission diagnostic.',
    'prompt': 'This is a synthetic diagnostic, not an SDD reviewer. Never read formal inputs, write, reserve, or issue a review verdict. Execute only the exact supplied command. A routine first-Bash hook refusal may be retried identically. Stop after one successful result or any other refusal.',
    'tools': ['Read', 'Grep', 'Glob', 'Bash'],
    'disallowedTools': ['Write', 'Edit', 'NotebookEdit'],
    'model': 'sonnet',
}
common = ['rtk', 'proxy', 'claude', '--bg', '--model', 'sonnet',
          '--permission-mode', 'dontAsk', '--tools', 'Read,Grep,Glob,Bash',
          '--disallowedTools', 'Write,Edit,NotebookEdit',
          '--plugin-dir', 'plugins/sdd-review-loop', '--agents', json.dumps({name: role}),
          '--agent', name, '--name', name]
if sys.argv[1:] == ['allocate']:
    args = common
elif len(sys.argv) == 3 and sys.argv[1] == 'resume':
    session_id = sys.argv[2]
    state = json.loads((Path('/Users/jrmag/.claude/jobs') / session_id[:8] / 'state.json').read_text())
    assert state['sessionId'] == session_id
    assert state['intent'] in ('', None)
    args = common + ['--resume', session_id,
                     '--allowedTools', 'Bash(rtk proxy shasum -a 256 ' + fixture + ')',
                     '--', 'Unreserved resume diagnostic. Hash only this exact file once: rtk proxy shasum -a 256 ' + fixture]
else:
    raise SystemExit('usage: script allocate | resume <native-session-id>')
print(json.dumps({'mode': sys.argv[1], 'argv': args}, ensure_ascii=False), flush=True)
raise SystemExit(subprocess.run(args, cwd=ROOT, stdin=subprocess.DEVNULL).returncode)
