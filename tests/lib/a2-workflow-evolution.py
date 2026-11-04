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


def planner_projection(block):
    # Existing jobs may add feature steps, but must preserve their live planner
    # references (including step conditions) and job-level execution condition.
    return [line for line in block.splitlines() if not line.lstrip().startswith('#')
            and ('ci-plan' in line or line.startswith('    if:'))]


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
    for name in current.keys() & old.keys():
        if planner_projection(current[name]) != planner_projection(proposed[name]):
            raise ValueError('current candidate changes live planner wiring or job condition')
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
    collector = b'python3 -B tests/verification-ci.py aggregate'
    weakened_aggregate = (aggregate.replace(b'"$RUNNER_TEMP/verification-result.json"',
                                             b'"$RUNNER_TEMP/verification-result.json" || true', 1)
                          if collector in aggregate else
                          aggregate.replace(b'!= "success"', b'== "success"', 1))
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
         candidate.replace(aggregate, aggregate.replace(b', ' + added.encode(), b'', 1), 1)),
        ('aggregate result weakening', archived, manifest, live,
         candidate.replace(aggregate, weakened_aggregate, 1)),
    ]
    if 'ci-plan' in current:
        historical_planned = sorted(name for name in jobs(archived) if name in current
                                    and 'needs: [ci-plan]' in current[name])
        if not historical_planned:
            raise ValueError('planner mutation controls require an existing planned job')
        block = proposed[historical_planned[0]].encode()
        weak_condition = re.sub(rb'^(    if: [^\n]+)', rb'\1 || true', block, count=1, flags=re.M)
        cases.extend([
            ('existing job planner dependency removal', archived, manifest, live,
             candidate.replace(block, block.replace(b'    needs: [ci-plan]\n', b'', 1), 1)),
            ('existing job condition weakening', archived, manifest, live,
             candidate.replace(block, weak_condition, 1)),
        ])
        test_block = proposed['test'].encode()
        without_step_condition = re.sub(rb'^        if: [^\n]*needs\.ci-plan\.outputs[^\n]*\n',
                                        b'', test_block, count=1, flags=re.M)
        cases.append(('existing step planner condition removal', archived, manifest, live,
                      candidate.replace(test_block, without_step_condition, 1)))
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
