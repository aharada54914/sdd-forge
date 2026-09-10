#!/usr/bin/env python3
"""Human-terminal-only application; never invoked by the agent."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path('/Users/jrmag/sdd-forge')
HERE = ROOT / 'reports/verification'
TARGETS = (
    'plugins/sdd-review-loop/scripts/spec-review-precheck.sh',
    'plugins/sdd-review-loop/scripts/spec-review-precheck.ps1',
)

def main():
    plan = json.loads((HERE / 'rt003-human-apply-plan.json').read_text())
    if plan['ticket'] != 'RT-20260909-003' or tuple(c['path'] for c in plan['changes']) != TARGETS:
        raise SystemExit('STOP: unexpected application targets')
    for tool in ('bash', 'pwsh', 'jq', 'git', 'sha256sum'):
        if not shutil.which(tool):
            raise SystemExit('STOP: required tool missing: ' + tool)
    prepared = []
    for change in plan['changes']:
        path = ROOT / change['path']
        if path.is_symlink() or path.resolve() != path or not path.is_file():
            raise SystemExit('STOP: target is not a canonical regular file: ' + str(path))
        before = path.read_bytes()
        if hashlib.sha256(before).hexdigest() != change['sha256']:
            raise SystemExit('STOP: source changed; send this output to Codex: ' + str(path))
        old, new = change['old'].encode(), change['new'].encode()
        if before.count(old) != 1:
            raise SystemExit('STOP: replacement is not unique: ' + str(path))
        prepared.append((path, before, before.replace(old, new, 1)))
    backup = Path(tempfile.mkdtemp(prefix='sdd-rt003-backup-'))
    print('バックアップ: ' + str(backup), flush=True)
    for path, before, after in prepared:
        shutil.copy2(path, backup / path.name)
    for path, before, after in prepared:
        if path.read_bytes() != before:
            raise SystemExit('STOP: target changed during application; backup: ' + str(backup))
        path.write_bytes(after)
        print(hashlib.sha256(after).hexdigest() + '  ' + str(path), flush=True)
    commands = (
        ['git', 'diff', '--check', '--', *TARGETS, 'tests/spec-review-loop.tests.sh'],
        ['bash', '-n', str(ROOT / TARGETS[0])],
        ['bash', 'tests/spec-review-loop.tests.sh'],
    )
    for index, command in enumerate(commands, 1):
        print('Check: ' + ' '.join(command), flush=True)
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (backup / ('check-' + str(index) + '.log')).write_bytes(result.stdout)
        print(result.stdout.decode(errors='replace'), end='', flush=True)
        print('Exit: ' + str(result.returncode), flush=True)
        if result.returncode:
            raise SystemExit('STOP: validation failed; send output and backup path to Codex.')
    print('適用・限定回帰検証が終了。正式レビュー・CI・main 統合は未完了です。')
    print('commit/push/merge はしていません。この出力を Codex に送ってください。')

if __name__ == '__main__':
    main()
