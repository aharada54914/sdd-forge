"""Offline T-006 numeric-fix checks; never launches cloud tools or repository suite."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[5]
EVIDENCE = Path(__file__).resolve().parent
SCRATCH = Path('/tmp/cloud-T006-alarm-01a14ec8')
SOURCE = Path('plugins/sdd-aws-cloud/scripts/aws_observation.py')
TEST = Path('tests/cloud-orchestration-verification.tests.py')
PYTHON = '/tmp/cloud-quality-python/bin/python'
GUARD = (
    "import runpy,sys; from unittest.mock import patch; "
    "path=sys.argv.pop(1); "
    "guard=patch('urllib.request.OpenerDirector.open', "
    "side_effect=AssertionError('LIVE_NETWORK_FORBIDDEN_IN_SCOPED_CHECK')); "
    "guard.start(); runpy.run_path(path,run_name='__main__')"
)
FOCUSED = ['AlarmNumericCases', 'EntryPreflight.test_live_network_is_forbidden_before_transport']


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(name: str, command: list[str], *, cwd: Path = ROOT, expected: int = 0) -> None:
    env = dict(os.environ)
    env['MYPYPATH'] = 'plugins/sdd-quality-loop/scripts:plugins/sdd-azure-cloud/scripts:plugins/sdd-aws-cloud/scripts'
    start = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    result = subprocess.run(command, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=300)
    (EVIDENCE / (name + '.log')).write_bytes(result.stdout)
    record = dict(command=command, cwd=str(cwd), started_at=start, exit_code=result.returncode,
                  expected_exit_code=expected, source_sha256=digest(cwd / SOURCE), test_sha256=digest(cwd / TEST))
    (EVIDENCE / (name + '.json')).write_text(json.dumps(record, indent=2) + '\n')
    print(name, result.returncode, flush=True)
    if result.returncode != expected:
        raise RuntimeError(f'{name}: unexpected exit {result.returncode}')
    if expected == 1 and (b'AssertionError' not in result.stdout or b'ERROR:' in result.stdout):
        raise RuntimeError(f'{name}: not an assertion-only sensitivity failure')


def tests(name: str, cwd: Path, focused: bool = True, expected: int = 0) -> None:
    run(name, [sys.executable, '-B', '-c', GUARD, str(TEST), *(FOCUSED if focused else [])], cwd=cwd, expected=expected)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--rollback', action='store_true')
    args = parser.parse_args()
    if not args.rollback:
        tests('green-verification', ROOT, focused=False)
        run('green-contracts', [sys.executable, '-B', '-c', GUARD, 'tests/cloud-orchestration-contracts.tests.py'])
        surfaces = [str(SOURCE), str(TEST), str(EVIDENCE.relative_to(ROOT) / 'verify-scoped.py')]
        run('ruff', [PYTHON, '-m', 'ruff', 'check', '--config', 'tests/shared-launch-python/pyproject.toml', *surfaces])
        run('mypy', [PYTHON, '-m', 'mypy', '--config-file', 'tests/shared-launch-python/pyproject.toml', *surfaces])
        return
    checkout = SCRATCH / 'rollback'
    if not checkout.exists():
        result = subprocess.run(['git', 'worktree', 'add', '--detach', str(checkout), 'HEAD'], cwd=ROOT, capture_output=True, check=True)
        (EVIDENCE / 'rollback-create.log').write_bytes(result.stdout + result.stderr)
    for snapshot in ('initial', 'supplemental'):
        for path in (SCRATCH / snapshot).rglob('*'):
            if path.is_file():
                target = checkout / path.relative_to(SCRATCH / snapshot)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(path, target)
    tests('rollback-entry-baseline', checkout, focused=False)
    shutil.copyfile(ROOT / TEST, checkout / TEST)
    shutil.copyfile(ROOT / SOURCE, checkout / SOURCE)
    tests('rollback-candidate', checkout)
    shutil.copyfile(SCRATCH / 'initial' / SOURCE, checkout / SOURCE)
    tests('rollback-restored-regression', checkout, expected=1)
    shutil.copyfile(SCRATCH / 'initial' / TEST, checkout / TEST)
    tests('rollback-restored-baseline', checkout, focused=False)
    shutil.copyfile(ROOT / TEST, checkout / TEST)
    shutil.copyfile(ROOT / SOURCE, checkout / SOURCE)
    tests('rollback-reapplied', checkout)
    green = (ROOT / SOURCE).read_text()
    mutations = {
        'accept-any-threshold': ('not zero_threshold(alarm.get("Threshold"))', 'False'),
        'binary-underflow': ('number = Decimal(value)', 'number = Decimal(str(float(value)))'),
        'permissive-decimal-lexemes': (
            'if not isinstance(value, str) or not re.fullmatch(\n        r"[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?", value\n    ):',
            'if not isinstance(value, str):',
        ),
    }
    try:
        for name, (old, new) in mutations.items():
            if green.count(old) != 1:
                raise RuntimeError(f'{name}: mutation anchor mismatch')
            (checkout / SOURCE).write_text(green.replace(old, new))
            tests('sensitivity-' + name, checkout, expected=1)
    finally:
        (checkout / SOURCE).write_text(green)
    tests('sensitivity-final-control', checkout)


if __name__ == '__main__':
    main()
