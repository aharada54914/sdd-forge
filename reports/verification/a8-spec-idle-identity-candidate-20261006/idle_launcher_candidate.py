"""Candidate adaptation of A7's empty native child helper; no main/auto-launch.

Not an approval or receipt validator. Never call allocate before sanctioned
contract application and launch authority. CLI acceptance alone is insufficient.
"""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path('/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge')


def allocation_args(role):
    if role not in ('spec-reviewer-a', 'spec-reviewer-b'):
        raise ValueError('only independent spec reviewer roles are supported')
    raw = (ROOT / ('plugins/sdd-review-loop/agents/' + role + '.md')).read_bytes()
    definition = {role: {
        'description': 'Independent specification reviewer; exact repository role below.',
        'prompt': raw.decode(), 'tools': ['Read', 'Grep', 'Glob'],
        'disallowedTools': ['Write', 'Edit', 'NotebookEdit'], 'model': 'sonnet'}}
    args = ['rtk', 'proxy', 'claude', '--bg', '--model', 'sonnet',
            '--permission-mode', 'dontAsk', '--tools', 'Read,Grep,Glob',
            '--disallowedTools', 'Write,Edit,NotebookEdit',
            '--plugin-dir', 'plugins/sdd-review-loop', '--agents', json.dumps(definition),
            '--agent', role, '--name', 'a8-spec-attempt4-' + role + '-empty-idle']
    return args, hashlib.sha256(raw).hexdigest()


def allocate(role):
    args, role_sha256 = allocation_args(role)
    print('role_sha256=' + role_sha256, flush=True)
    return subprocess.run(args, cwd=ROOT, stdin=subprocess.DEVNULL).returncode
