#!/usr/bin/env python3
"""Project only pinned review references into a consumer's canonical input paths."""
import argparse
import os
from pathlib import Path
import stat
import sys

REFERENCES = {
    'spec': ('plugins/sdd-review-loop/references/spec-review-calibration.md',),
    'impl': ('plugins/sdd-review-loop/references/spec-review-calibration.md',
             'plugins/sdd-review-loop/references/reviewer-calibration.md'),
    'task': ('plugins/sdd-review-loop/references/spec-review-calibration.md',
             'plugins/sdd-review-loop/references/reviewer-calibration.md',
             'plugins/sdd-quality-loop/references/risk-gate-matrix.md',
             'plugins/sdd-quality-loop/references/risk-classification-policy.md'),
}


def asset_path(relative):
    _, package, remainder = relative.split('/', 2)
    owner = Path(__file__).resolve().parents[1]
    if owner.name == 'sdd-review-loop':
        return owner.parent / package / remainder
    return owner.parent.parent / package / owner.name / remainder


def check_path(path, directory=False):
    info = path.lstat()
    if stat.S_ISLNK(info.st_mode) or getattr(info, 'st_file_attributes', 0) & 0x400:
        raise ValueError(f'linked review input: {path}')
    if not (stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode)):
        raise ValueError(f'wrong review input type: {path}')


def check_target(root, relative, create=False):
    current = root
    check_path(current, directory=True)
    for component in relative.split('/')[:-1]:
        current = current / component
        if create:
            current.mkdir(exist_ok=True)
        if current.exists() or current.is_symlink():
            check_path(current, directory=True)
        elif not create:
            return
    target = root / relative
    if target.exists() or target.is_symlink():
        check_path(target)


def prepare(root, stage, verify_only):
    # Validate every collision before making any new files. References are data;
    # executable scripts remain in the trusted installation and are never copied.
    pending = []
    for relative in REFERENCES[stage]:
        source = asset_path(relative)
        check_path(source)
        content = source.read_bytes()
        target = root / relative
        check_target(root, relative)
        if target.exists():
            if target.read_bytes() != content:
                raise ValueError(f'review reference differs from installed bytes: {relative}')
        elif verify_only:
            raise ValueError(f'missing projected review reference: {relative}')
        else:
            pending.append((relative, content))
    for relative, content in pending:
        check_target(root, relative, create=True)
        target = root / relative
        # Exclusive creation never replaces an existing project file.
        descriptor = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, 'O_NOFOLLOW', 0), 0o644)
        with os.fdopen(descriptor, 'wb') as stream:
            stream.write(content)
        check_target(root, relative)
        if target.read_bytes() != content:
            raise ValueError(f'projected review reference readback failed: {relative}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True, type=Path)
    parser.add_argument('--stage', required=True, choices=REFERENCES)
    parser.add_argument('--verify-only', action='store_true')
    args = parser.parse_args()
    try:
        root = args.root.absolute()
        check_path(root, directory=True)
        if root.resolve() != root:
            raise ValueError('project root must be canonical')
        prepare(root, args.stage, args.verify_only)
    except (OSError, ValueError) as error:
        print(f'prepare-review-assets: {error}', file=sys.stderr)
        return 1
    print('prepare-review-assets: references match installed bytes')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
