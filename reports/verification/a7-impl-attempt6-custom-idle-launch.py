"""Allocate native idle child without passing orchestrator stdin as a prompt."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path('/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge')
raw = (ROOT / 'plugins/sdd-review-loop/agents/impl-reviewer-a.md').read_bytes()
definition = {'impl-reviewer-a': {
    'description': 'Structural Soundness Reviewer for implementation policy; exact repository role below.',
    'prompt': raw.decode(), 'tools': ['Read', 'Grep', 'Glob', 'Bash'],
    'disallowedTools': ['Write', 'Edit', 'NotebookEdit'], 'model': 'sonnet'}}
print('role_sha256=' + hashlib.sha256(raw).hexdigest(), flush=True)
args = ['rtk', 'proxy', 'claude', '--bg', '--model', 'sonnet',
        '--permission-mode', 'dontAsk', '--tools', 'Read,Grep,Glob,Bash',
        '--disallowedTools', 'Write,Edit,NotebookEdit',
        '--plugin-dir', 'plugins/sdd-review-loop', '--agents', json.dumps(definition),
        '--agent', 'impl-reviewer-a', '--name', 'a7-impl-attempt6-reviewer-a-empty-idle']
raise SystemExit(subprocess.run(args, cwd=ROOT, stdin=subprocess.DEVNULL).returncode)
