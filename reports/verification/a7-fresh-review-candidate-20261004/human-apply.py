#!/usr/bin/env python3
"""Human-only hash-bound apply/restore. Default dry-run does not write files."""
import argparse
import hashlib
import json
import os
import pathlib
import shutil
import stat
import subprocess
import tempfile

ROOT = pathlib.Path('/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge')
PACKAGE = ROOT / 'reports/verification/a7-fresh-review-candidate-20261004'
HEAD = 'd64cffcb22b114779202847be33e41700c4ba11f'
TARGETS = [
    {
        "target": "plugins/sdd-review-loop/scripts/spec-review-precheck.sh",
        "candidate": "spec-review-precheck.sh.candidate",
        "before": "486966e2f2aaa176ed0b8ca6b5418649d7fb24d3b7ee9b7a2a04a240fc6016e1",
        "after": "7c540cb425de6ee430689d0d4bb02ba6068c0c9dee7401c8d6e5dd8b1a1f24d6"
    },
    {
        "target": "plugins/sdd-review-loop/scripts/spec-review-precheck.ps1",
        "candidate": "spec-review-precheck.ps1.candidate",
        "before": "145795e1c7e7fda82224e961f8c869c08b633f94fb9ff43e065dc42e43cc2250",
        "after": "294956150a5bcfafc2d500e35aa9d6d247e5470162431dd5eb45a965ebb52528"
    },
    {
        "target": "plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md",
        "candidate": "SKILL.md.candidate",
        "before": "bda27737bc7074d1f802aad52b69bde0eed47d20e256554acf0341180f515c24",
        "after": "8828e5103b669e39385f60720d2cc6a02e40f14d6e1e7758d3c07a94dfbfa7d4"
    },
    {
        "target": "plugins/sdd-review-loop/scripts/fresh-review-recovery.py",
        "candidate": "fresh-review-recovery.py.candidate",
        "before": "446cc12db071ebd8c80a30a83a91e47b9d7d2ba377dd8db3d0bfe1f740113e16",
        "after": "b45adc1a7cb445819ce98f58aeb42db630cc4f32b36e0b950279404c3a8528f0"
    },
    {
        "target": "specs/epic-195-a7-compatibility/verification/spec-review-fresh-recovery.fixture.py",
        "candidate": "spec-review-fresh-recovery.fixture.py.candidate",
        "before": "ddb788633808ad5eaf5168542bb8b7751aa3e92c3f5194fd892825e27edcaa2e",
        "after": "b42bef4065a3c40f95eb5d96e3b1c76201086fad1e568cf0f76c408bdcd6dd11"
    }
]


def check(condition, message):
    if not condition:
        raise SystemExit(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def regular(path):
    check(path.is_file() and path.resolve() == path and not path.is_symlink(),
          'STOP: non-regular or redirected path: ' + str(path))


def verify(which):
    for item in TARGETS:
        target = ROOT / item['target']
        regular(target)
        check(sha(target) == item[which],
              'STOP: target hash mismatch (already applied, restored or edited): ' + item['target'])


def payloads():
    data = {}
    for item in TARGETS:
        path = PACKAGE / item['candidate']
        regular(path)
        content = path.read_bytes()
        check(hashlib.sha256(content).hexdigest() == item['after'],
              'STOP: candidate hash mismatch: ' + item['candidate'])
        data[item['target']] = content
    return data


def replace(path, content):
    mode = stat.S_IMODE(path.stat().st_mode)
    fd, temporary = tempfile.mkstemp(prefix='.a7-fresh-apply-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--apply', action='store_true')
    mode.add_argument('--restore', type=pathlib.Path)
    parser.add_argument('--expect-runner-sha256')
    args = parser.parse_args()
    regular(pathlib.Path(__file__).absolute())
    check(ROOT.resolve() == ROOT and PACKAGE.resolve() == PACKAGE, 'STOP: redirected owner/package')
    current = subprocess.check_output(['rtk', 'proxy', 'git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
    check(current == HEAD, 'STOP: owner HEAD changed')
    if args.apply or args.restore:
        check(args.expect_runner_sha256 and sha(pathlib.Path(__file__).absolute()) == args.expect_runner_sha256,
              'STOP: supply the reviewed runner SHA-256')
    if not args.apply and not args.restore:
        verify('before')
        payloads()
        print('DRY RUN OK: 5 exact targets; no writes; no candidate execution; NOT VERIFIED')
        return
    lock = PACKAGE / '.human-apply.lock'
    try:
        lock.mkdir()
    except FileExistsError:
        raise SystemExit('STOP: apply lock exists; inspect incomplete execution, do not retry')
    completed = False
    try:
        if args.apply:
            verify('before')
            data = payloads()
            backup = pathlib.Path(tempfile.mkdtemp(prefix='backup-', dir=PACKAGE))
            for item in TARGETS:
                destination = backup / item['target']
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / item['target'], destination)
                check(sha(destination) == item['before'], 'STOP: backup readback mismatch')
            receipt = {'schema': 'a7-fresh-review-human-apply/v1', 'owner': str(ROOT),
                       'head': HEAD, 'runner_sha256': sha(pathlib.Path(__file__).absolute()),
                       'targets': TARGETS}
            (backup / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
            print('Backup: ' + str(backup), flush=True)
            verify('before')
            for item in TARGETS:
                target = ROOT / item['target']
                check(sha(target) == item['before'], 'STOP: concurrent target edit')
                replace(target, data[item['target']])
                check(sha(target) == item['after'], 'STOP: applied readback mismatch')
            verify('after')
            print('Applied once: 5 targets. NOT VERIFIED. No review, reservation or status update.')
        else:
            backup = args.restore.absolute()
            check(backup.parent == PACKAGE and backup.name.startswith('backup-') and
                  backup.resolve() == backup, 'STOP: not an exact package backup directory')
            regular(backup / 'receipt.json')
            receipt = json.loads((backup / 'receipt.json').read_text())
            check(receipt.get('owner') == str(ROOT) and receipt.get('head') == HEAD and
                  receipt.get('targets') == TARGETS, 'STOP: backup receipt mismatch')
            # Permit a partial apply only if every target is still an exact before
            # or after image; never overwrite a concurrent user edit.
            for item in TARGETS:
                source = backup / item['target']
                regular(source)
                regular(ROOT / item['target'])
                check(sha(source) == item['before'], 'STOP: backup hash mismatch')
                check(sha(ROOT / item['target']) in (item['before'], item['after']),
                      'STOP: target changed after apply; manual reconciliation required')
            for item in TARGETS:
                replace(ROOT / item['target'], (backup / item['target']).read_bytes())
            verify('before')
            print('Restored exact pre-apply bytes: 5 targets. Backup retained.')
        completed = True
    finally:
        # Backup survives errors; restore admits only exact before/after images.
        lock.rmdir()


if __name__ == '__main__':
    main()
