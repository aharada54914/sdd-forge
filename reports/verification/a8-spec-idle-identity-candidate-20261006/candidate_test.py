"""Isolated patch application and mocked launcher checks, never a host test."""
from pathlib import Path
import hashlib
import importlib.util
import json
import shutil
import subprocess
import tempfile
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
REL = Path('plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md')
BASE = 'b816d5a7f09d458ecd9cab3cf23b7a2f52433ddde3badf80b3ff8d22bf46dad9'
original = (ROOT / REL).read_bytes()
assert hashlib.sha256(original).hexdigest() == BASE
with tempfile.TemporaryDirectory(prefix='a8-idle-candidate-') as temp:
    fixture = Path(temp)
    (fixture / REL).parent.mkdir(parents=True)
    shutil.copyfile(ROOT / REL, fixture / REL)
    subprocess.run(['rtk', 'proxy', 'git', 'apply', '--check', str(HERE / 'candidate.patch')], cwd=fixture, check=True)
    subprocess.run(['rtk', 'proxy', 'git', 'apply', str(HERE / 'candidate.patch')], cwd=fixture, check=True)
    revised = (fixture / REL).read_text()
    assert 'fresh orchestrator-issued per-reviewer run ID' in revised
    assert 'actual host-issued session/thread identity' in revised
    assert 'Both IDs\nremain independently subject to ledger uniqueness' in revised
    # Static retention checks only, not execution of the live lifecycle.
    for invariant in ('Only after successful reservation and `REVIEW_CONTEXT_OK`',
                      'first reviewer turn in exactly that reserved context',
                      'no retry by changing IDs in its receipt',
                      'use a new context for a later permitted attempt',
                      'a same-session fallback, or any guard bypass'):
        assert invariant in revised
    reversed_result = subprocess.run(['rtk', 'proxy', 'git', 'apply', '--reverse', str(HERE / 'candidate.patch')], cwd=fixture)
    assert reversed_result.returncode == 0
    assert (fixture / REL).read_bytes() == original
print('PASS isolated patch apply/reverse and static lifecycle retention')

spec = importlib.util.spec_from_file_location('candidate', HERE / 'idle_launcher_candidate.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
for role in ('spec-reviewer-a', 'spec-reviewer-b'):
    args, digest = module.allocation_args(role)
    assert args[:4] == ['rtk', 'proxy', 'claude', '--bg']
    for option, value in (('--model', 'sonnet'), ('--permission-mode', 'dontAsk'),
                          ('--tools', 'Read,Grep,Glob'),
                          ('--disallowedTools', 'Write,Edit,NotebookEdit'), ('--agent', role)):
        assert args[args.index(option) + 1] == value
    definition = json.loads(args[args.index('--agents') + 1])
    assert definition[role]['tools'] == ['Read', 'Grep', 'Glob']
    raw = (ROOT / ('plugins/sdd-review-loop/agents/' + role + '.md')).read_bytes()
    assert definition[role]['prompt'].encode() == raw
    assert digest == hashlib.sha256(raw).hexdigest()
    for forbidden in ('--session-id', '--resume', '--continue', '--allowedTools',
                      '--dangerously-skip-permissions', '-p', '--print', '--prompt'):
        assert forbidden not in args
    with patch.object(module.subprocess, 'run') as mocked:
        mocked.return_value.returncode = 0
        assert module.allocate(role) == 0
        mocked.assert_called_once_with(args, cwd=ROOT, stdin=subprocess.DEVNULL)
with patch.object(module.subprocess, 'run') as mocked:
    for role in ('impl-reviewer-a', 'default', '../spec-reviewer-a'):
        try:
            module.allocate(role)
        except ValueError:
            pass
        else:
            raise AssertionError('invalid role accepted')
    mocked.assert_not_called()
assert (ROOT / REL).read_bytes() == original
print('PASS two-role argv/source/DEVNULL and three invalid-role negatives; NO native process')
