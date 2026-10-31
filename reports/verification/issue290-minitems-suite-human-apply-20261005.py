"""Pinned two-test human application. Default is read-only validation."""
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / 'reports/verification/issue290-minitems-registered-suite-20261005.patch'
PATCH_SHA = '6ccccf575c8900830239766f0725ad9ea076ebf3c02acf8dde6cd8af546f8079'
PINS = {
    'tests/validate-approval-sidecar.tests.sh': ('72511d69f5407e5f186beb3b32ebb8c5a0fa47b94807f319341f04429dad43e6', 'b39767190ee83d88f17055f67f273db35535e14395e203b84533e54f83c89bc8'),
    'tests/validate-approval-sidecar.tests.ps1': ('a8ed8ee80504e1ff75fbe38c1f33e8a3e614b0c38906f38a88a2d6e19fa7eb09', '75dede41bdb9aeeec9fdfb5965107897ea19febf4b4eab089313d49d13f7c366'),
}

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def verify():
    if digest(PATCH) != PATCH_SHA:
        raise SystemExit('STOP: patch drift')
    for path, (before, _) in PINS.items():
        if (ROOT / path).is_symlink() or digest(ROOT / path) != before:
            raise SystemExit('STOP: source drift: ' + path)

if sys.argv[1:] not in ([], ['--check'], ['--apply-human']):
    raise SystemExit('Usage: --check | --apply-human')
verify()
command = ['patch', '--batch', '--forward', '-p1', '-i', str(PATCH)]
subprocess.run(command + ['--dry-run'], cwd=ROOT, check=True)
if sys.argv[1:] != ['--apply-human']:
    print('READY: exact source and patch pins; dry-run only; originals unchanged')
    raise SystemExit(0)
if not sys.stdin.isatty() or input('Type APPLY-ISSUE290-MINITEMS-SUITES: ') != 'APPLY-ISSUE290-MINITEMS-SUITES':
    raise SystemExit('STOP: human confirmation required')
backup = Path(tempfile.mkdtemp(prefix='issue290-minitems-suite-backup-'))
verify()
for path in PINS:
    target = backup / path
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / path, target)
verify()
print('Backup:', backup, flush=True)
subprocess.run(command, cwd=ROOT, check=True)
for path, (_, after) in PINS.items():
    if digest(ROOT / path) != after:
        raise SystemExit('STOP: readback mismatch; preserve backup: ' + str(backup))
print('Applied once, readback verified. Owner regression and formal gates still required.')
