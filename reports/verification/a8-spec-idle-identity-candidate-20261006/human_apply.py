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

ROOT = Path(__file__).resolve().parents[3]
EXPECTED_ROOT = Path.home() / '.codex/worktrees/a8-release-sync-oct01/sdd-forge'
HEAD = '495c88d67af44530687ecea3ce9fb0a90a336539'
PATCH = 'reports/verification/a8-spec-idle-identity-candidate-20261006/candidate.patch'
PATCH_HASH = '2dd88a0a4e6eb5b8754a194b118ac8b6b4f6477a560660647a13038ae4cc5d0d'
PINS = {
    'plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md': (
        'b816d5a7f09d458ecd9cab3cf23b7a2f52433ddde3badf80b3ff8d22bf46dad9',
        '96df5aa6fb219b7c231ad10381de33cedc3d6827a3d5a45e88c73dac25513d45'),
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

if not sys.stdin.isatty():
    stop('human application requires an interactive terminal')
if input('Type APPLY A8 IDLE CONTRACT to apply the reviewed one-file patch: ') != 'APPLY A8 IDLE CONTRACT':
    stop('confirmation mismatch')

# Backup every original byte before the first target write; never auto-restore.
backup = Path(tempfile.mkdtemp(prefix='a8-spec-idle-backup-', dir=ROOT / 'reports/verification'))
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
print('Applied once; one-file readback matches. Post-apply behavior NOT VERIFIED.')
print('No formal gate, reservation, approval, installation or Done transition performed.')
