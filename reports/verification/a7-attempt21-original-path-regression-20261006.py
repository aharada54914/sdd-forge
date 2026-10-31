"""Read applied originals; run existing cases in disposable fixtures, without admission."""
from pathlib import Path
import hashlib
import json
import runpy
import shutil
import tempfile

OWNER = Path(__file__).resolve().parents[2]
CANDIDATE = OWNER / 'reports/verification/a7-attempt21-recovery-candidate-20261006'
original_run_path = runpy.run_path
original_copytree = shutil.copytree
FEATURE = 'epic-195-a7-compatibility'


def copy_historical_fixture(src, dst, *args, **kwargs):
    """Pin only disposable current-state copies to this suite's A20 boundary."""
    src, dst = Path(src), Path(dst)
    spec_source = OWNER / 'specs' / FEATURE
    history_source = OWNER / 'reports/spec-review' / FEATURE
    if src in (spec_source, history_source):
        assert dst.resolve().is_relative_to(Path(tempfile.gettempdir()).resolve())
        assert not dst.resolve().is_relative_to(OWNER.resolve())
    if src == history_source:
        assert 'ignore' not in kwargs and not args
        kwargs['ignore'] = lambda directory, names: {
            name for name in names if Path(directory) == history_source
            and name.startswith('attempt-') and name[8:].isdigit()
            and int(name[8:]) > 20}
    result = original_copytree(src, dst, *args, **kwargs)
    if src == spec_source:
        requirements = dst / 'requirements.md'
        content = requirements.read_bytes()
        assert content.count(b'Spec-Review-Status: Passed') + content.count(b'Spec-Review-Status: Pending') == 1
        content = content.replace(b'Spec-Review-Status: Passed', b'Spec-Review-Status: Pending')
        precheck = json.loads((history_source / 'attempt-20/round-2/precheck-result.json').read_bytes())
        assert hashlib.sha256(content).hexdigest() == precheck['requirements_sha256'], 'unrelated current input drift'
        requirements.write_bytes(content)
    return result


def run_original_sources(path, *args, **kwargs):
    path = Path(path)
    if path.parent == CANDIDATE and path.name in ('recovery.tests.py', 'additional.tests.py'):
        source = path.read_text().replace(
            "HERE / (name + '.candidate.py')",
            "OWNER / 'plugins/sdd-review-loop/scripts' / (name + '.py')",
        ).replace(
            "HERE / 'failed-last-attempt.candidate.py'",
            "OWNER / 'plugins/sdd-review-loop/scripts/failed-last-attempt.py'",
        )
        namespace = {'__file__': str(path), '__name__': '__main__'}
        exec(compile(source, str(path), 'exec'), namespace)
        return namespace
    return original_run_path(path, *args, **kwargs)


runpy.run_path = run_original_sources
shutil.copytree = copy_historical_fixture
run_original_sources(CANDIDATE / 'recovery.tests.py')
run_original_sources(CANDIDATE / 'additional.tests.py')
