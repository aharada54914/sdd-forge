"""Preserve A2's historical workflow while checking its current replacement."""
import argparse
import hashlib
from pathlib import Path
import re

# Applied historical bytes at 2ea0e0ba; never regenerate this pin from live CI.
ARCHIVE_SHA256 = 'a005484044dbfecf0e72ea6df834e270e392a2879adb551604a012e9d9e22fd5'
RELATIVE = '.github/workflows/test.yml'


def jobs(raw):
    text = raw.decode('utf-8')
    if text.count('\njobs:\n') != 1:
        raise ValueError('expected one explicit jobs mapping')
    text = text.split('\njobs:\n', 1)[1]
    matches = list(re.finditer(r'^  ([a-zA-Z_][a-zA-Z0-9_-]*):\s*$', text, re.M))
    names = [match[1] for match in matches]
    if not names or len(set(names)) != len(names):
        raise ValueError('job keys must be nonempty and unique')
    return {match[1]: text[match.start():matches[index + 1].start() if index + 1 < len(matches)
                          else len(text)].rstrip() for index, match in enumerate(matches)}


def validate(archived, manifest, live, candidate):
    digest = hashlib.sha256(archived).hexdigest()
    rows = [line.split('  ', 1) for line in manifest.decode('utf-8').splitlines() if line]
    workflow_rows = [row for row in rows if len(row) == 2 and row[1] == RELATIVE]
    if digest != ARCHIVE_SHA256 or workflow_rows != [[digest, RELATIVE]]:
        raise ValueError('historical workflow differs from pinned bytes or its manifest')
    old, current, proposed = jobs(archived), jobs(live), jobs(candidate)
    if not old.keys() <= current.keys():
        raise ValueError('live workflow drops historical jobs')
    if not current.keys() <= proposed.keys():
        raise ValueError('current candidate drops live jobs')
    # Every post-archive job needs its actual current definition, not just its name.
    for name in (current.keys() - old.keys()) | {'required-checks'}:
        # A comment at job-key indentation belongs to neither executable job.
        # Preserve every nested line, including shell-body comments and spacing.
        actual = '\n'.join(line for line in current[name].splitlines() if not line.startswith('  #')).rstrip()
        replacement = '\n'.join(line for line in proposed[name].splitlines() if not line.startswith('  #')).rstrip()
        if replacement != actual:
            raise ValueError('current candidate changes a new job or required aggregation')


def self_test(archived, manifest, live, candidate):
    validate(archived, manifest, live, candidate)
    current = jobs(live)
    additions = sorted(current.keys() - jobs(archived).keys())
    if not additions:
        raise ValueError('workflow mutation controls require a real added job')
    added = additions[0]
    proposed = jobs(candidate)
    new_block = proposed[added].encode()
    aggregate = proposed['required-checks'].encode()
    removed_dependency = re.sub(rb'(?m)^      - ' + re.escape(added.encode()) + rb'\r?\n', b'', aggregate)
    if removed_dependency == aggregate:
        removed_dependency = aggregate.replace(b', ' + added.encode(), b'', 1)
    weakened_result = aggregate.replace(b'!= "success"', b'== "success"', 1)
    if weakened_result == aggregate:
        weakened_result = aggregate.replace(b'verification-ci.py aggregate', b'verification-ci.py collect', 1)
    # Commentary at job indentation may move or change without altering CI.
    for comments in (b'', b'  # Different wording\n', b'  # First line\n  # Second line\n'):
        changed = re.sub(rb'^  #[^\n]*\n?', b'', candidate, flags=re.M)
        changed = changed.replace(b'    name:', comments + b'    name:', 1)
        changed = changed.replace(b'  required-checks:\n', b'  required-checks:\n' + comments, 1)
        validate(archived, manifest, live, changed)
    changed_archive = archived + b'\n# synthetic historical mutation\n'
    changed_manifest = manifest.replace(ARCHIVE_SHA256.encode(), hashlib.sha256(changed_archive).hexdigest().encode())
    cases = [
        ('historical bytes', changed_archive, manifest, live, candidate),
        ('coherently rehashed archive', changed_archive, changed_manifest, live, candidate),
        ('manifest binding', archived, manifest.replace(ARCHIVE_SHA256.encode(), b'0' * 64), live, candidate),
        ('historical job removal', archived, manifest, live.replace(current['test'].encode(), b'', 1), candidate),
        ('new job removal', archived, manifest, live, candidate.replace(new_block, b'', 1)),
        ('unknown future job omission', archived, manifest,
         live + b'\n  synthetic-future-job:\n    runs-on: ubuntu-latest\n    steps: []\n', candidate),
        ('new job change', archived, manifest, live, candidate.replace(new_block, new_block + b'\n    if: false', 1)),
        ('new job permission change', archived, manifest, live,
         candidate.replace(new_block, new_block.replace(b'contents: read', b'contents: write', 1), 1)),
        ('new job execution change', archived, manifest, live,
         candidate.replace(new_block, new_block.replace(b'run: |', b'run: echo bypassed\n        ignored: |', 1), 1)),
        ('aggregate dependency removal', archived, manifest, live,
         candidate.replace(aggregate, removed_dependency, 1)),
        ('aggregate result weakening', archived, manifest, live,
         candidate.replace(aggregate, weakened_result, 1)),
    ]
    for label, old, index, actual, proposed in cases:
        if (old, index, actual, proposed) == (archived, manifest, live, candidate):
            raise AssertionError('mutation did not change input: ' + label)
        try:
            validate(old, index, actual, proposed)
        except ValueError:
            continue
        raise AssertionError('workflow mutation was accepted: ' + label)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    base = args.root / 'specs/epic-190-a2-capability-registry'
    try:
        inputs = ((base / 'human-copy' / RELATIVE).read_bytes(),
                  (base / 'human-copy/MANIFEST.sha256').read_bytes(),
                  (args.root / RELATIVE).read_bytes(),
                  (base / 'drafts/human-copy-candidate' / (RELATIVE + '.candidate')).read_bytes())
        (self_test if args.self_test else validate)(*inputs)
    except (ValueError, OSError, KeyError, AssertionError) as exc:
        parser.exit(1, str(exc) + '\n')
    print('historical workflow preserved; current candidate retains live jobs and aggregation')
