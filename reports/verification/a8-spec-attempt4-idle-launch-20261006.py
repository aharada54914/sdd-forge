"""Allocate an empty A8 specification reviewer A native child; never send a turn."""

from pathlib import Path
import hashlib
import json
import subprocess


ROOT = Path('/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge')
ROLE = 'spec-reviewer-a'
ROLE_PATH = ROOT / 'plugins/sdd-review-loop/agents/spec-reviewer-a.md'
SETTINGS = ROOT / 'reports/verification/a8-native-exact-calculator-settings-20261006.json'


def main():
    role_bytes = ROLE_PATH.read_bytes()
    settings = json.loads(SETTINGS.read_text())
    expected = (
        'rtk proxy bash plugins/sdd-quality-loop/scripts/validate-review-context-set.sh '
        'reports/review-context/a8-spec-attempt4-round1-spec-reviewer-a.json '
        f'{ROOT} --reviewer-receipt '
        'reports/review-context/a8-spec-attempt4-round1-spec-reviewer-a.json.receipt.txt'
    )
    assert expected in settings['hooks']['PreToolUse'][0]['hooks'][0]['command']
    assert b'model: sonnet' in role_bytes
    assert b'tools: Read, Grep, Glob, Bash' in role_bytes
    definition = {ROLE: {
        'description': 'Independent A8 specification reviewer A; exact repository role source.',
        'prompt': role_bytes.decode('utf-8'),
        'tools': ['Read', 'Grep', 'Glob', 'Bash'],
        'disallowedTools': ['Write', 'Edit', 'NotebookEdit'],
        'model': 'sonnet',
    }}
    args = [
        'rtk', 'proxy', 'claude', '--bg', '--model', 'sonnet',
        '--permission-mode', 'dontAsk', '--tools', 'Read,Grep,Glob,Bash',
        '--disallowedTools', 'Write,Edit,NotebookEdit',
        '--settings', str(SETTINGS), '--plugin-dir', 'plugins/sdd-review-loop',
        '--agents', json.dumps(definition, separators=(',', ':')),
        '--agent', ROLE, '--name', 'a8-spec-attempt4-reviewer-a-empty-idle',
    ]
    print('role_sha256=' + hashlib.sha256(role_bytes).hexdigest(), flush=True)
    print('settings_sha256=' + hashlib.sha256(SETTINGS.read_bytes()).hexdigest(), flush=True)
    return subprocess.run(args, cwd=ROOT, stdin=subprocess.DEVNULL, check=False).returncode


if __name__ == '__main__':
    raise SystemExit(main())
