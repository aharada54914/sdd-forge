"""One protected target; default is read-only. No alternate route after denial."""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path('/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge')
HERE = Path(__file__).resolve().parent
TARGET = 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py'
BEFORE = '1fa826ac3b8a336c3ee9badadd0002a5078c9a660dff30b83e44b81900a6f075'
AFTER = 'fcebcf252957ec4a0ff47879f5b0096d770fc9a59f30c2130c75c006d9c57abd'
PATCH = HERE / 'transport.candidate.patch'
PATCH_SHA = '376ccf4d0fac0046762bb0ff9f838f65c76da422a14153f31c1ed98ea9e9a15f'

def digest(path):
    if path.is_symlink() or not path.is_file() or path.resolve() != path:
        raise SystemExit('STOP: unsafe or missing path')
    return hashlib.sha256(path.read_bytes()).hexdigest()

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--apply-human', action='store_true')
args = parser.parse_args()
if HERE.parents[2] != ROOT or digest(PATCH) != PATCH_SHA:
    raise SystemExit('STOP: owner or patch mismatch')
target = ROOT / TARGET
current = digest(target)
if current == AFTER:
    raise SystemExit('ALREADY_APPLIED: exact target matches; no writes')
if current != BEFORE:
    raise SystemExit('STOP: original hash mismatch; no writes')
subprocess.run(['rtk', 'proxy', 'git', 'apply', '--check', str(PATCH)], cwd=ROOT, check=True)
print('CHECK_OK: pinned original and patch; applicability only', flush=True)
if args.apply_human:
    backup = Path(tempfile.mkdtemp(prefix='a7-receipt-human-backup-')).resolve()
    original = backup / target.name
    shutil.copy2(target, original)
    if digest(original) != BEFORE or digest(target) != BEFORE or digest(PATCH) != PATCH_SHA:
        raise SystemExit('STOP: backup or inputs changed; no apply')
    print('BACKUP:', original, flush=True)
    subprocess.run(['rtk', 'proxy', 'git', 'apply', str(PATCH)], cwd=ROOT, check=True)
    if digest(target) != AFTER:
        raise SystemExit('STOP: readback mismatch; preserve backup and do not retry')
    print('APPLIED_ONE:', TARGET, AFTER)
    print('Application only; native admission, formal review, CI and merge remain unverified.')
