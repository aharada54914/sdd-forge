"""Fixture-only apply tests; owner targets never executed or modified."""
import importlib.util
from pathlib import Path
import shutil
import tempfile

HERE = Path(__file__).resolve().parent
OWNER = HERE.parents[2]

def run(label, mutate=None, apply=False, release=True, reject=None):
    with tempfile.TemporaryDirectory(prefix='a21-human-apply-fixture-') as folder:
        root = Path(folder).resolve()
        here = root / HERE.relative_to(OWNER)
        here.mkdir(parents=True)
        spec = importlib.util.spec_from_file_location('human_apply', HERE / 'human-apply.py')
        helper = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(helper)
        helper.ROOT, helper.HERE, helper.RELEASE_READY = root, here, release
        for name, _, _ in helper.TARGETS:
            rel = helper.target_path(name)
            target = root / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(OWNER / rel, target)
            shutil.copy2(HERE / helper.candidate_path(name).name, helper.candidate_path(name))
        shutil.copy2(HERE / 'candidate.patch', here / 'candidate.patch')
        helper.invoke('git', 'init', '-q')
        if mutate:
            mutate(helper)
        try:
            helper.main(['--apply-human'] if apply else [])
        except RuntimeError as error:
            assert reject and reject in str(error), (label, str(error))
            print('PASS reject', label, str(error))
        else:
            assert not reject, label + ' unexpectedly accepted'
            if apply:
                assert helper.inspect()[2] == 'applied'
                helper.main(['--apply-human'])
            else:
                assert helper.inspect()[2] == 'original'
            print('PASS', label)

run('default inspection only')
run('normal apply and exact no-op', apply=True)
run('unreleased human flag blocked', apply=True, release=False, reject='UNRELEASED')
run('patch mismatch', lambda h: (h.HERE / 'candidate.patch').write_text('changed'), reject='patch hash mismatch')
run('candidate mismatch', lambda h: (h.HERE / 'failed-last-attempt.candidate.py').write_text('changed'), reject='candidate hash mismatch')
run('source mismatch', lambda h: (h.ROOT / 'plugins/sdd-review-loop/scripts/fresh-review-recovery.py').write_text('changed'), reject='source hash mismatch')
run('fourth skill source mismatch', lambda h: (h.ROOT / h.target_path('spec-review-loop.SKILL')).write_text('changed'), reject='source hash mismatch')
def partial(h):
    shutil.copy2(h.HERE / 'failed-last-attempt.candidate.py', h.ROOT / 'plugins/sdd-review-loop/scripts/failed-last-attempt.py')
run('partial application', partial, apply=True, reject='partial application')
def symlink(h):
    target = h.ROOT / 'plugins/sdd-review-loop/scripts/failed-last-attempt.py'
    retained = target.with_suffix('.retained')
    target.rename(retained)
    target.symlink_to(retained)
run('symlink target', symlink, reject='unsafe or missing regular file')
def concurrent(h):
    original = h.shutil.copy2
    def copy(source, destination):
        result = original(source, destination)
        if str(destination).startswith('/private/var/') and 'a7-a21-human-backup-' in str(destination):
            (h.ROOT / 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py').write_text('concurrent change')
        return result
    h.shutil = type('FixtureShutil', (), {'copy2': staticmethod(copy)})
run('mid-backup mismatch', concurrent, apply=True, reject='backup readback mismatch')
print('Owner source/ledger/task untouched; fixture-only checks.')
