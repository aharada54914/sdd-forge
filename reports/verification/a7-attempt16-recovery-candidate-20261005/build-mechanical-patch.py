#!/usr/bin/env python3
"""Generate only a candidate patch from owner originals and a temporary copy."""
import difflib
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
TARGETS = (
    'plugins/sdd-review-loop/scripts/fresh-review-recovery.py',
    'plugins/sdd-review-loop/scripts/spec-review-precheck.sh',
    'plugins/sdd-review-loop/scripts/spec-review-precheck.ps1',
    'plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md',
)
NEW = 'plugins/sdd-review-loop/scripts/failed-last-attempt.py'


def delta(rel, old, new):
    lines = list(difflib.unified_diff(old.splitlines(keepends=True),
                                      new.splitlines(keepends=True),
                                      fromfile='a/' + rel if old else '/dev/null',
                                      tofile='b/' + rel))
    if not lines:
        return ''
    heading = 'diff --git a/' + rel + ' b/' + rel + '\n'
    if not old:
        heading += 'new file mode 100644\n'
    return heading + ''.join(lines)


def main():
    if len(sys.argv) != 2:
        raise SystemExit('usage: build-mechanical-patch.py <temporary-copy-root>')
    copy_root = pathlib.Path(sys.argv[1]).resolve()
    pieces = []
    for rel in TARGETS:
        original = ROOT / rel
        candidate = copy_root / rel
        if not original.is_file() or original.is_symlink() or not candidate.is_file():
            raise SystemExit('missing or unsafe candidate copy: ' + rel)
        pieces.append(delta(rel, original.read_text(), candidate.read_text()))
    candidate = copy_root / NEW
    if not candidate.is_file() or candidate.is_symlink():
        raise SystemExit('missing new helper candidate')
    pieces.append(delta(NEW, '', candidate.read_text()))
    output = HERE / 'mechanical-integration.patch'
    output.write_text(''.join(pieces))
    print(output)


if __name__ == '__main__':
    main()
