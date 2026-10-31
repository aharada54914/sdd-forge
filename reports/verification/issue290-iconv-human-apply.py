"""Human-only application; default is inspection without changes."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path('/Users/jrmag/.codex/worktrees/issue290-concept-phase1/sdd-forge')
TARGET = ROOT / 'plugins/sdd-quality-loop/scripts/validate-review-context-set.sh'
EXPECTED = '8e5e885c026041a4059f0f5462d2c213f6072c0d8cc9e7056ee3713f48450d32'
OLD = b'iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1 ||'
NEW = b'iconv -f UTF-8 -t UTF-8 2>/dev/null | cat >/dev/null ||'


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def check_pipeline(payload):
    return subprocess.run(
        ['rtk', 'proxy', 'bash', '-o', 'pipefail', '-c',
         'iconv -f UTF-8 -t UTF-8 2>/dev/null | cat >/dev/null'],
        input=payload, check=False).returncode


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    if args.self_test:
        require(not args.apply, 'Choose self-test or human application, not both')
        require(check_pipeline('設計文書\n'.encode()) == 0, 'Valid UTF-8 rejected')
        require(check_pipeline(b'\xff') != 0, 'Invalid UTF-8 accepted')
        print('UTF-8 pipeline: valid accepted; invalid rejected. No application.')
        return
    require(not TARGET.is_symlink() and TARGET.is_file(), 'Not a regular target')
    original = TARGET.read_bytes()
    require(hashlib.sha256(original).hexdigest() == EXPECTED, 'Target drift; stopped')
    require(original.count(OLD) == 1, 'Expected exactly one source line')
    updated = original.replace(OLD, NEW, 1)
    print('Before:', EXPECTED)
    print('After:', hashlib.sha256(updated).hexdigest())
    if not args.apply:
        print('Inspection only. Human may invoke --apply; no files changed.')
        return
    design = (ROOT / 'specs/sdd-domain-concept-test/design.md').read_bytes()
    design.decode('utf-8', errors='strict')
    require(check_pipeline(design) == 0 and check_pipeline(b'\xff') != 0,
            'UTF-8 regression check failed')
    backup = Path(tempfile.mkdtemp(prefix='sdd290-iconv-backup-')) / TARGET.name
    shutil.copy2(TARGET, backup)
    print('Backup:', backup, flush=True)
    # Recheck immediately before writing; preserve the existing file mode.
    require(TARGET.read_bytes() == original and not TARGET.is_symlink(), 'Target drift')
    with TARGET.open('wb') as stream:
        stream.write(updated)
        stream.flush()
        os.fsync(stream.fileno())
    require(TARGET.read_bytes() == updated, 'Written bytes mismatch; backup retained')
    subprocess.run(['rtk', 'proxy', 'bash', '-n', str(TARGET)], check=True)
    subprocess.run(['rtk', 'proxy', 'git', '-C', str(ROOT), 'diff', '--check', '--',
                    str(TARGET.relative_to(ROOT))], check=True)
    print('One line applied. Syntax/UTF-8 checks passed. Review/CI/merge pending.')
    print('No reservation, verdict, commit, push or merge performed.')


if __name__ == '__main__':
    main()
