#!/usr/bin/env python3
"""Current-byte candidate preflight; --apply-human is interactive human ONLY.

Never invoke --apply-human through an agent after a protected-write refusal.
The old candidate/helper remain historical evidence, not dependencies.
"""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / 'reports/verification/issue290-role-identity-current-candidate-20261005.patch'
PATCH_SHA = '7dba363a160751b64ece974ba3eefbcf781759593f5c819ab186565c31318f9c'
PINS = {
    'plugins/sdd-review-loop/agents/task-reviewer-a.md': (
        'e114b7a61b673e5230a691df3cc8f338df934b2ecf883fcd1b58206d14bae4a8',
        'ffe19bcd4b58ad4fc6a85dea8f08216bbaff6dd3143764e25509402c472906e5'),
    'plugins/sdd-review-loop/agents/task-reviewer-b.md': (
        '4f0add219de40b025d8bf0b73b5fe048e4d94728de2bd7616da728c930498ae9',
        'e124d91630710804ef51ac8364af3207bfae252106a86d13c9380b171a3a20a2'),
    'plugins/sdd-review-loop/references/review-context-boundary.md': (
        'b537052a70eb52e73cd9add1ab2bb6e19f2b29796efd58bf7df2684b8bd318c1',
        '467255d299b66143911891ec8d92c854b85df602e7633a6f40a7830619d10f89'),
}

def digest(raw):
    return hashlib.sha256(raw).hexdigest()

def read_regular(path):
    if path.is_symlink() or not path.is_file():
        raise RuntimeError(f'not regular: {path}')
    for parent in path.parents:
        if parent.is_symlink():
            raise RuntimeError(f'symlink component: {parent}')
    return path.read_bytes()

def prepare(patch, sources):
    if digest(patch) != PATCH_SHA:
        raise RuntimeError('candidate hash mismatch')
    results = {}
    for section in patch.decode('utf-8').split('diff --git ')[1:]:
        lines = section.splitlines(keepends=True)
        rel = lines[0].split()[0][2:]
        if rel not in PINS or rel in results:
            raise RuntimeError('unexpected/duplicate candidate target')
        raw = sources[rel]
        if digest(raw) != PINS[rel][0]:
            raise RuntimeError(f'original hash mismatch: {rel}')
        hunk = lines[4:]
        before = ''.join(x[1:] for x in hunk if x.startswith((' ', '-'))).encode()
        after = ''.join(x[1:] for x in hunk if x.startswith((' ', '+'))).encode()
        if raw.count(before) != 1:
            raise RuntimeError(f'nonunique hunk: {rel}')
        updated = raw.replace(before, after, 1)
        if digest(updated) != PINS[rel][1]:
            raise RuntimeError(f'after hash mismatch: {rel}')
        results[rel] = updated
    if set(results) != set(PINS):
        raise RuntimeError('incomplete target set')
    return results

def git_check(path):
    subprocess.run(['rtk', 'proxy', 'git', '-C', str(ROOT), 'apply', '--check', str(path)], check=True)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply-human', action='store_true')
    args = parser.parse_args()
    patch = read_regular(PATCH)
    sources = {rel: read_regular(ROOT / rel) for rel in PINS}
    expected = prepare(patch, sources)
    # In-memory fail-closed probes; no mutation of any real target or reservation.
    mutations = [('candidate-byte-drift', patch + b'\n', sources)]
    for rel in PINS:
        mutations.append((f'original-byte-drift:{rel}', patch, {**sources, rel: sources[rel] + b'\n'}))
        mutations.append((f'already-applied:{rel}', patch, {**sources, rel: expected[rel]}))
    for name, changed_patch, changed_sources in mutations:
        try:
            prepare(changed_patch, changed_sources)
        except RuntimeError:
            print(f'negative PASS: {name}')
        else:
            raise RuntimeError(f'negative accepted: {name}')
    git_check(PATCH)
    print(f'candidate SHA-256: {PATCH_SHA}')
    for rel, pins in PINS.items():
        print(f'{rel}: before={pins[0]} after={pins[1]}')
    print(patch.decode('utf-8'), end='')
    if not args.apply_human:
        print('DRY RUN ONLY: no protected original or reservation written')
        return
    if not sys.stdin.isatty():
        raise RuntimeError('human interactive terminal required')
    if input('Type APPLY-ISSUE290-CURRENT to apply these exact three insertions: ') != 'APPLY-ISSUE290-CURRENT':
        raise RuntimeError('confirmation mismatch')
    backup = Path(tempfile.mkdtemp(prefix='issue290-current-role-backup-'))
    print(f'Retained backup: {backup}')
    for rel, raw in sources.items():
        if read_regular(ROOT / rel) != raw:
            raise RuntimeError(f'concurrent change: {rel}')
        target = backup / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, target)
        if read_regular(target) != raw:
            raise RuntimeError(f'backup mismatch: {rel}')
    if read_regular(PATCH) != patch:
        raise RuntimeError('candidate changed after confirmation')
    for rel, raw in sources.items():
        if read_regular(ROOT / rel) != raw:
            raise RuntimeError(f'concurrent change after backup: {rel}')
    git_check(PATCH)
    subprocess.run(['rtk', 'proxy', 'git', '-C', str(ROOT), 'apply', str(PATCH)], check=True)
    for rel, raw in expected.items():
        if read_regular(ROOT / rel) != raw:
            raise RuntimeError(f'after-readback mismatch: {rel}; backup={backup}')
    print('APPLIED AND READ BACK: exact three insertions; formal review NOT RUN')

if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError, UnicodeError) as exc:
        print(f'STOP: {exc}', file=sys.stderr)
        sys.exit(1)
