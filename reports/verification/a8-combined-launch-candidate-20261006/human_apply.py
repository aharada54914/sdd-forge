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
PATCH = 'reports/verification/a8-combined-launch-candidate-20261006/candidate.patch'
PATCH_HASH = '37a711d5131e29f3ecdafaac983c2593f3559146cba5abc671473358a56027ea'
PINS = {'plugins/sdd-quality-loop/scripts/validate-review-context-set.sh': ('011f1d9c068e7b2f033f02bbae0fd15cf3a9c9c2c7f409c963fc1d9e941fc09b', '96cda1dde7dda85bd1fa16891f471fd8b3297b29c244bb22a4a040f6b33ca696'), 'plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1': ('e8424eb27598222fe527ffaaa296cd287a4c52f850ed05b91e98023c8c4e7925', '60695bb6c49820d13d9795ee6b4adc0127b415deb410b6b4144dee0c2b91f4c6'), 'plugins/sdd-review-loop/agents/spec-reviewer-a.md': ('a2df15daa4b42c582b507f17d094df14cc369c512e7ed6ac314fb24cfd85a34d', '14a4e3aed4787df3e109d558e13491055f0555c12413eb0977553a5d27abaab7'), 'plugins/sdd-review-loop/agents/spec-reviewer-b.md': ('992a2e8ec18512e83d1813f369e84d40ef3ec0e1d38b43fea19dbd361b34ccd6', 'df8f332a3db9364a219f96602b59d196c9cffece5e69411a1db4fe4d15e278b5'), 'plugins/sdd-review-loop/references/review-context-boundary.md': ('07f7834c17561b3b69093f91b32c7c5d4d655e9bc21bf2ff8bec6322fb02152a', 'a7661082974595f8172d30b42d73705cf089e3dc909cb69bf5f3808716f398dd'), 'plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md': ('b816d5a7f09d458ecd9cab3cf23b7a2f52433ddde3badf80b3ff8d22bf46dad9', '350e3acf3bae6be1020f4900bb1202f0b3b8ba8350b10cf197f9946cfd1cf582'), 'tests/review-context-boundary.tests.sh': ('34eb70012271e5f7f697a0c640fe1a4ce0f547f2ae92569beb5a532cba2e96ca', '4b0b00e4b57ffb5ca6d786db08616adff1ac121e49644d2c23b8f38a74297087'), 'plugins/sdd-quality-loop/scripts/reviewer-receipt.py': (None, '08785f133567ed2fc24084332819f75d56e94e0afb6dfb33fa3b5cc2a2866b1b')}


def stop(message):
    raise SystemExit('STOP: ' + message)


def read_regular(relative, absent=False):
    path = ROOT / relative
    if path.resolve() != path:
        stop('unsafe path: ' + relative)
    if absent:
        if path.exists() or path.is_symlink():
            stop('expected absent target: ' + relative)
        return None
    if not stat.S_ISREG(path.lstat().st_mode) or path.stat().st_nlink != 1:
        stop('unsafe path: ' + relative)
    return path.read_bytes()


def digest(data):
    return hashlib.sha256(data).hexdigest() if data is not None else None


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
originals = {name: read_regular(name, PINS[name][0] is None) for name in PINS}
for name, data in originals.items():
    if digest(data) != PINS[name][0]:
        stop('pre-apply hash mismatch: ' + name)
git('apply', '--check', PATCH)
if sys.argv[1:] != ['--apply']:
    print('READ-ONLY CHECK OK; NOT APPLIED; no authorization inferred')
    raise SystemExit(0)

if not sys.stdin.isatty():
    stop('human application requires an interactive terminal')
if input('Type APPLY A8 COMBINED CONTRACT to apply the reviewed eight-target patch: ') != 'APPLY A8 COMBINED CONTRACT':
    stop('confirmation mismatch')

# Backup every original byte before the first target write; never auto-restore.
backup = Path(tempfile.mkdtemp(prefix='a8-combined-launch-backup-', dir=ROOT / 'reports/verification'))
for name, data in originals.items():
    if data is None:
        continue  # Absence is recorded in the backup manifest.
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
    if read_regular(name, data is None) != data:
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
print('Applied once; eight-target readback matches. Post-apply behavior NOT VERIFIED.')
print('No formal gate, reservation, approval, installation or Done transition performed.')
