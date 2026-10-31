"""Human-operated candidate; NOT an authorization or a guard bypass.

Default/--check is read-only. --apply requires separate scoped human authority.
No review, reservation, lifecycle change, installation or Git commit is performed.
On any refusal stop; never retry with another executor or disabled guard.
"""
import hashlib
import json
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path.home() / '.codex/worktrees/a8-release-sync-oct01/sdd-forge'
HEAD = '495c88d67af44530687ecea3ce9fb0a90a336539'
PATCH = 'reports/verification/a8-blocked-continuation-v3-20261005.patch'
PATCH_HASH = '5d9463812a38d4a85f26e82fc10c4f194f4a4f95f04b13b45831bfd5ac4d803b'
PINS = {
    'plugins/sdd-review-loop/scripts/impl-review-precheck.sh': (
        '9c79ab9c9cc821a7a4a36df713633063321a34573f320c7b235d5761db89f621',
        '8a9a8833b9acae777276fe67dd00b8b74a60890146674aaef57134714d2a136a'),
    'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1': (
        '72e03cfad7d35f8eb444fdd8db82b2aab705bdc33882e3dd4750d4a8017a47c4',
        '6d066329e1675c77c06e780a842400514ec7d0d788b04cdeb8e854fff9c00cba'),
    'plugins/sdd-quality-loop/scripts/check-workflow-state.sh': (
        '001f6962590b7d9dc9a831d8d90d7171174cca6d890e94b376881ab0193bd85f',
        'f621d2e2f2a468fadf378d28b398c7ff3f531847d0ec39c1ce9af6fd60b4b647'),
    'plugins/sdd-quality-loop/scripts/check-workflow-state.ps1': (
        '13351170ba1284d2fa1eb0d096d6e5faf506e3ce0a3a22a3cb81d09b10a028db',
        '7f189e25938644825f7f24295a91b99f06ba8d41c2216814af351b6bf3342993'),
}


def stop(message):
    raise SystemExit('STOP: ' + message)


def read_regular(relative):
    path = ROOT / relative
    if path.resolve() != path or not stat.S_ISREG(path.lstat().st_mode):
        stop('unsafe path: ' + relative)
    return path.read_bytes()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def git(*args):
    result = subprocess.run(['rtk', 'proxy', 'git', *args], cwd=ROOT,
                            capture_output=True, text=True)
    if result.returncode:
        sys.stdout.write(result.stdout)
        sys.stderr.write(result.stderr)
        stop('Git operation rejected or failed; do not bypass or retry blindly')
    return result.stdout.strip()


if sys.argv[1:] not in ([], ['--check'], ['--apply']):
    stop('usage: human-apply.py [--check|--apply]')
if ROOT != EXPECTED_ROOT.resolve() or Path(git('rev-parse', '--show-toplevel')).resolve() != ROOT:
    stop('owning checkout mismatch')
if git('rev-parse', 'HEAD') != HEAD:
    stop('HEAD mismatch; do not update pins to force application')
patch_bytes = read_regular(PATCH)
if digest(patch_bytes) != PATCH_HASH:
    stop('candidate patch hash mismatch')
originals = {name: read_regular(name) for name in PINS}
for name, data in originals.items():
    if digest(data) != PINS[name][0]:
        stop('pre-apply hash mismatch: ' + name)
git('apply', '--check', PATCH)
if sys.argv[1:] != ['--apply']:
    print('READ-ONLY CHECK OK; NOT APPLIED; no authorization inferred')
    raise SystemExit(0)

# Backup every original byte before the first target write; never auto-restore.
backup = Path(tempfile.mkdtemp(prefix='a8-blocked-v3-backup-', dir=ROOT / 'reports/verification'))
for name, data in originals.items():
    target = backup / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    target.chmod((ROOT / name).stat().st_mode & 0o777)
    if digest(target.read_bytes()) != PINS[name][0]:
        stop('backup readback mismatch: ' + name)
(backup / 'manifest.json').write_text(json.dumps({'head': HEAD, 'patch_sha256': PATCH_HASH,
                                               'files': PINS}, indent=2) + '\n')
print('Backup: ' + str(backup), flush=True)
for name, data in originals.items():
    if read_regular(name) != data:
        stop('target changed after backup: ' + name)
if read_regular(PATCH) != patch_bytes:
    stop('patch changed after backup')
git('apply', '--check', PATCH)
git('apply', PATCH)
for name, (_, expected_after) in PINS.items():
    observed = digest(read_regular(name))
    if observed != expected_after:
        stop('post-apply readback mismatch; preserve backup and investigate: ' + name)
    print(name + ' SHA256 ' + observed)
print('Applied once; four-file readback matches. Post-apply behavior NOT VERIFIED.')
print('No formal gate, reservation, approval, installation or Done transition performed.')
