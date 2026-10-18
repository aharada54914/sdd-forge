"""Bounded rollback/reapply of final installers in a disposable committed tree."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[5]
EVIDENCE = Path(__file__).resolve().parent / "final-rollback"
EVIDENCE.mkdir(exist_ok=True)
SCRATCH = Path('/tmp/cloud-t007-01a14fbf')
CHECKOUT = SCRATCH / 'rollback-final'
OWNED = ('install.sh', 'install.ps1', 'tests/install-cloud.tests.py')
records: list[dict[str, object]] = []


def command(name: str, args: list[str], cwd: Path) -> None:
    p = subprocess.run(args, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=900)
    (EVIDENCE / (name + '.log')).write_text(p.stdout)
    records.append(dict(name=name, command=args, cwd=str(cwd), exit_code=p.returncode))
    (EVIDENCE / 'rollback-commands.json').write_text(json.dumps(records, indent=2) + '\n')
    if p.returncode:
        raise RuntimeError(f'{name}: exit {p.returncode}; checkout retained for diagnosis')


def commit(name: str, paths: list[str]) -> None:
    command(name + '-stage', ['git', 'add', '--', *paths], CHECKOUT)
    command(name + '-commit', ['git', '-c', 'user.name=Rollback Fixture', '-c', 'user.email=fixture@example.invalid',
                              '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', name], CHECKOUT)


def hashes() -> dict[str, str]:
    return {name: hashlib.sha256((CHECKOUT / name).read_bytes()).hexdigest() for name in OWNED}


def baseline(label: str) -> None:
    command(label + '-bash', ['bash', 'tests/install.tests.sh'], CHECKOUT)
    command(label + '-pwsh', ['/workspace/.tools/sdd-forge-dev/bin/pwsh', '-NoProfile', '-File', 'tests/install.tests.ps1'], CHECKOUT)


def focused(label: str) -> None:
    command(label, [sys.executable, '-B', 'tests/install-cloud.tests.py',
                    'InstalledLifecycle.test_sequential_selections_rebuild_prior_runtime',
                    'InstalledLifecycle.test_prior_runtime_rebuild_failure_preserves_installation'], CHECKOUT)


result: dict[str, object] = dict(classification='offline disposable committed checkout; no cloud or host registration')
try:
    command('rollback-create', ['git', 'worktree', 'add', '--detach', str(CHECKOUT), 'HEAD'], ROOT)
    # Reconstruct dirty/untracked entry candidate dependencies before measuring
    # rollback. Never restore historical approvals, ledgers or review reports.
    snapshot = SCRATCH / 'snapshot/initial'
    copied: list[str] = []
    for path in sorted(snapshot.rglob('*')):
        if not path.is_file():
            continue
        rel = path.relative_to(snapshot)
        if rel.parts[0] in ('specs', 'reports', 'docs'):
            continue
        dest = CHECKOUT / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)
        copied.append(str(rel))
    commit('rollback-entry', copied)
    result['entry'] = hashes()
    baseline('rollback-entry-baseline')
    for name in OWNED:
        shutil.copy2(ROOT / name, CHECKOUT / name)
    commit('rollback-candidate', list(OWNED))
    result['candidate'] = hashes()
    focused('rollback-candidate-focused')
    for name in OWNED:
        shutil.copy2(snapshot / name, CHECKOUT / name)
    commit('rollback-restored', list(OWNED))
    result['restored'] = hashes()
    assert result['entry'] == result['restored']
    baseline('rollback-restored-baseline')
    for name in OWNED:
        shutil.copy2(ROOT / name, CHECKOUT / name)
    commit('rollback-reapplied', list(OWNED))
    result['reapplied'] = hashes()
    assert result['candidate'] == result['reapplied']
    focused('rollback-reapplied-focused')
    result['result'] = 'PASS'
    command('rollback-remove', ['git', 'worktree', 'remove', '--force', str(CHECKOUT)], ROOT)
except Exception as exc:
    result['result'] = 'FAIL'
    result['error'] = str(exc)
    raise
finally:
    (EVIDENCE / 'rollback-result.json').write_text(json.dumps(result, indent=2) + '\n')
