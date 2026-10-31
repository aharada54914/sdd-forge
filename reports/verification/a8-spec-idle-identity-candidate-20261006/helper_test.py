"""Human-helper branches in disposable directories; production owner never applied."""
from pathlib import Path
import hashlib
import subprocess
import sys
import tempfile
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
REL = 'plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md'
PATCH = 'reports/verification/a8-spec-idle-identity-candidate-20261006/candidate.patch'
source = (HERE / 'human_apply.py').read_text()
real_run = subprocess.run
for case in ('check', 'patch', 'preimage', 'head', 'symlink', 'nonTTY', 'confirmation', 'apply'):
    with tempfile.TemporaryDirectory(prefix='a8-idle-human-fixture-') as temp:
        fixture = Path(temp).resolve()
        target = fixture / REL
        target.parent.mkdir(parents=True)
        original = (ROOT / REL).read_bytes()
        target.write_bytes(original)
        candidate = fixture / PATCH
        candidate.parent.mkdir(parents=True)
        candidate.write_bytes((HERE / 'candidate.patch').read_bytes())
        if case == 'patch':
            candidate.write_bytes(candidate.read_bytes() + b'corrupt')
        if case == 'preimage':
            target.write_bytes(original + b'changed')
        if case == 'symlink':
            alternate = fixture / 'alternate'
            target.rename(alternate)
            target.symlink_to(alternate)
        before = target.read_bytes()
        # Test-only root substitution; the actual helper retains fixed owner pins.
        modified = source.replace('ROOT = Path(__file__).resolve().parents[3]', 'ROOT = Path(' + repr(str(fixture)) + ')')
        modified = modified.replace("EXPECTED_ROOT = Path.home() / '.codex/worktrees/a8-release-sync-oct01/sdd-forge'", 'EXPECTED_ROOT = ROOT')
        def run(args, **kwargs):
            if args[3:5] == ['rev-parse', '--show-toplevel']:
                return subprocess.CompletedProcess(args, 0, str(fixture), '')
            if args[3:5] == ['rev-parse', 'HEAD']:
                head = 'wrong' if case == 'head' else '495c88d67af44530687ecea3ce9fb0a90a336539'
                return subprocess.CompletedProcess(args, 0, head, '')
            assert args[:4] == ['rtk', 'proxy', 'git', 'apply']
            return real_run(args, **kwargs)
        mode = '--check' if case in ('check', 'patch', 'preimage', 'head', 'symlink') else '--apply'
        try:
            with patch.object(sys, 'argv', ['human_apply.py', mode]), patch.object(subprocess, 'run', run), patch.object(sys.stdin, 'isatty', return_value=case != 'nonTTY'), patch('builtins.input', return_value='wrong' if case == 'confirmation' else 'APPLY A8 IDLE CONTRACT'):
                exec(compile(modified, 'human_apply.py', 'exec'), {'__name__': '__main__', '__file__': str(candidate.parent / 'human_apply.py')})
        except SystemExit as exc:
            if case == 'check':
                assert exc.code == 0
            else:
                assert case != 'apply' and str(exc).startswith('STOP:'), (case, exc)
        else:
            assert case == 'apply'
        if case == 'apply':
            assert hashlib.sha256(target.read_bytes()).hexdigest() == '96df5aa6fb219b7c231ad10381de33cedc3d6827a3d5a45e88c73dac25513d45'
            backups = list((fixture / 'reports/verification').glob('a8-spec-idle-backup-*'))
            assert len(backups) == 1 and (backups[0] / REL).read_bytes() == original
        else:
            assert target.read_bytes() == before
        print('PASS fixture ' + case)
