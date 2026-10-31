"""Test combined helper only in disposable trees; never apply owner originals."""
from pathlib import Path
import contextlib
import hashlib
import io
import json
import subprocess
import sys
import tempfile
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
PINS = json.loads((HERE / 'pins.json').read_text())
PATCH = str((HERE / 'candidate.patch').relative_to(ROOT))
source = (HERE / 'human_apply.py').read_text()
real_run = subprocess.run
sha = lambda b: hashlib.sha256(b).hexdigest()
new = next(k for k, v in PINS.items() if v[0] is None)
old = next(k for k, v in PINS.items() if v[0] is not None)
output = []
for case in ('check', 'patch', 'preimage', 'head', 'symlink', 'hardlink', 'new-exists', 'nonTTY', 'confirmation', 'apply-reapply'):
    with tempfile.TemporaryDirectory(prefix='a8-combined-human-test-') as temp:
        fixture = Path(temp).resolve()
        for name, (pre, post) in PINS.items():
            if pre is not None:
                target = fixture / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / name).read_bytes())
        candidate = fixture / PATCH
        candidate.parent.mkdir(parents=True, exist_ok=True)
        candidate.write_bytes((HERE / 'candidate.patch').read_bytes())
        if case == 'patch':
            candidate.write_bytes(candidate.read_bytes() + b'changed')
        if case == 'preimage':
            (fixture / old).write_bytes(b'changed')
        if case in ('symlink', 'hardlink'):
            alternate = fixture / 'alternate'
            (fixture / old).rename(alternate)
            if case == 'symlink':
                (fixture / old).symlink_to(alternate)
            else:
                (fixture / old).hardlink_to(alternate)
        if case == 'new-exists':
            (fixture / new).write_bytes(b'already exists')
        def snapshot():
            return {str(p.relative_to(fixture)): p.read_bytes() for p in fixture.rglob('*') if p.is_file()}
        before = snapshot()
        modified = source.replace('ROOT = Path(__file__).resolve().parents[3]', 'ROOT = Path(' + repr(str(fixture)) + ')')
        modified = modified.replace("EXPECTED_ROOT = Path.home() / '.codex/worktrees/a8-release-sync-oct01/sdd-forge'", 'EXPECTED_ROOT = ROOT')
        def run(args, **kwargs):
            if args[3:5] == ['rev-parse', '--show-toplevel']:
                return subprocess.CompletedProcess(args, 0, str(fixture), '')
            if args[3:5] == ['rev-parse', 'HEAD']:
                return subprocess.CompletedProcess(args, 0, 'wrong' if case == 'head' else '495c88d67af44530687ecea3ce9fb0a90a336539', '')
            assert args[:4] == ['rtk', 'proxy', 'git', 'apply']
            return real_run(args, **kwargs)
        def invoke(mode):
            log = io.StringIO()
            with contextlib.redirect_stdout(log), patch.object(sys, 'argv', ['human_apply.py', mode]), patch.object(subprocess, 'run', run), patch.object(sys.stdin, 'isatty', return_value=case != 'nonTTY'), patch('builtins.input', return_value='wrong' if case == 'confirmation' else 'APPLY A8 COMBINED CONTRACT'):
                try:
                    exec(compile(modified, 'human_apply.py', 'exec'), {'__name__': '__main__', '__file__': str(candidate.parent / 'human_apply.py')})
                except SystemExit as exc:
                    return exc.code
            return 0
        code = invoke('--check' if case in ('check', 'patch', 'preimage', 'head', 'symlink', 'hardlink', 'new-exists') else '--apply')
        if case in ('check', 'apply-reapply'):
            assert code == 0, (case, code)
        else:
            assert isinstance(code, str) and code.startswith('STOP:'), (case, code)
        if case == 'apply-reapply':
            for name, (_, expected) in PINS.items():
                assert sha((fixture / name).read_bytes()) == expected
            backups = list((fixture / 'reports/verification').glob('a8-combined-launch-backup-*'))
            assert len(backups) == 1
            manifest = json.loads((backups[0] / 'manifest.json').read_text())
            assert manifest['files'] == PINS
            for name, (pre, _) in PINS.items():
                if pre is not None:
                    assert sha((backups[0] / name).read_bytes()) == pre
                else:
                    assert not (backups[0] / name).exists()
            after = snapshot()
            assert str(invoke('--apply')).startswith('STOP:')
            assert snapshot() == after
        else:
            assert snapshot() == before
        output.append('PASS ' + case)
for name, (pre, _) in PINS.items():
    assert (sha((ROOT / name).read_bytes()) if pre is not None else (ROOT / name).exists()) == (pre if pre is not None else False)
output.append('PASS owner original hashes and new-file absence unchanged')
(HERE / 'helper-test.stdout.txt').write_text('\n'.join(output) + '\n')
print('\n'.join(output))
