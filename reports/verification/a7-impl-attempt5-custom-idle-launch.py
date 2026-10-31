"""Allocate an unprompted native idle context; never reserve or deliver inputs."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path('/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge')
ROLE = ROOT / 'plugins/sdd-review-loop/agents/impl-reviewer-a.md'
raw = ROLE.read_bytes()
text = raw.decode('utf-8')
assert text.startswith('---\nname: impl-reviewer-a\n')
assert '\ntools: Read, Grep, Glob, Bash\n' in text
assert '\ndisallowedTools: Write, Edit, NotebookEdit\n' in text
assert '\nmodel: sonnet\n' in text
definition = {
    'impl-reviewer-a': {
        'description': 'Structural Soundness Reviewer for implementation policy; exact repository role below.',
        'prompt': text,
        'tools': ['Read', 'Grep', 'Glob', 'Bash'],
        'disallowedTools': ['Write', 'Edit', 'NotebookEdit'],
        'model': 'sonnet',
    }
}
print('role_sha256=' + hashlib.sha256(raw).hexdigest(), flush=True)
print('custom_prompt_equals_full_role=true', flush=True)
command = ['rtk', 'proxy', 'claude', '--bg', '--model', 'sonnet',
           '--permission-mode', 'dontAsk', '--tools', 'Read,Grep,Glob,Bash',
           '--disallowedTools', 'Write,Edit,NotebookEdit',
           '--plugin-dir', 'plugins/sdd-review-loop',
           '--agents', json.dumps(definition), '--agent', 'impl-reviewer-a',
           '--name', 'a7-impl-attempt5-reviewer-a-custom-idle']
raise SystemExit(subprocess.run(command, cwd=ROOT).returncode)
