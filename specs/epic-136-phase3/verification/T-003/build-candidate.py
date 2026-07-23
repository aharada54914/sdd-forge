#!/usr/bin/env python3
"""Deterministically transform the live workflow into T-003's staged candidate.

Usage:
  build-candidate.py [SOURCE] [DEST]

SOURCE defaults to the repository's live .github/workflows/test.yml (read-only),
DEST to specs/epic-136-phase3/verification/T-003/staged-workflow-candidate.draft.yml.
Both are resolved relative to the repository root derived from this file's
location, so the transformation is re-runnable by any reviewer and its output
can be diffed against the committed candidate.

Transformation (design.md ".github/workflows/test.yml (Stream D + Stream A,
ONE shared staged batch)", AC-016/AC-017/AC-020):
  1. every step inside the single `test` job gets a "[deterministic] " name
     prefix. Named steps have their `name:` prefixed; an UNNAMED step
     (`      - uses:` / `      - run:` with no name) is given a name derived
     from its action/command so it, too, carries the prefix (AC-016: EVERY
     step). No new job, no job rename, no step moved.
     The prefixed value is emitted as a DOUBLE-QUOTED YAML scalar: an
     unquoted scalar beginning with `[` opens a YAML flow sequence, which
     makes the whole document unparseable (design.md:348 writes the prefix
     quoted for exactly this reason).
  2. one documented, currently-empty YAML comment placeholder marking where a
     future LLM-invoking eval lane job would be added.
  3. Stream A's, Stream B's, and Stream D's own new bash-only CI steps appended
     inside the same `test` job (REQ-005: every new suite this feature adds
     gets a staged CI step), each separated by a blank line to match the
     surrounding file style.
  4. everything outside the `test` job -- including
     `required-checks: needs: [test, cli-hook-enforcement]` -- is copied
     byte-for-byte unchanged.

No draft/banner comment is emitted into the candidate: the candidate is the
byte-exact content intended for the live workflow, so it must contain nothing
that would not belong in the live file. The draft-path rationale lives in the
implementation report, not in the YAML.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
DEFAULT_SRC = os.path.join(REPO, '.github', 'workflows', 'test.yml')
DEFAULT_DST = os.path.join(
    REPO, 'specs', 'epic-136-phase3', 'verification', 'T-003',
    'staged-workflow-candidate.draft.yml')

PREFIX = '[deterministic] '
NAME_LINE = '      - name: '
STEP_START = '      - '        # a step's first line inside a job (6 spaces + "- ")

NEW_STEPS = [
    '      - name: "[deterministic] Test guard dispatch fallback suite (bash)"',
    '        shell: bash',
    '        run: bash ./tests/guard-dispatch-fallback.tests.sh',
    '',
    '      - name: "[deterministic] Test guard negative corpus suite (bash)"',
    '        shell: bash',
    '        run: bash ./tests/guard-negative-corpus.tests.sh',
    '',
    '      - name: "[deterministic] Test deterministic-lane self-check suite (bash)"',
    '        shell: bash',
    '        run: bash ./tests/deterministic-lane-selfcheck.tests.sh',
    '',
]

EVAL_LANE_COMMENT = [
    '      # ---------------------------------------------------------------',
    '      # [deterministic] lane marker (epic-136 Phase 3, Stream D, #126).',
    '      # Every step in this `test` job is deterministic: no step invokes an',
    '      # LLM. A future LLM-invoking eval lane is added as a SEPARATE job,',
    '      # never as a step here -- this marker records where that job would',
    '      # be introduced. It is intentionally empty today: adding the job',
    "      # here would change the job graph and `required-checks`' `needs:`",
    '      # list, which BL-001 forbids for this feature (design.md Design',
    '      # Decisions OQ-5).',
    '      # eval-lane: (none yet)',
    '      # ---------------------------------------------------------------',
    '',
]


def quoted(name):
    """Emit the prefixed step name as a double-quoted YAML scalar."""
    escaped = name.replace('\\', '\\\\').replace('"', '\\"')
    return '"' + PREFIX + escaped + '"'


def unnamed_step_name(line):
    """Derive a name for an unnamed `- uses:`/`- run:` step."""
    body = line[len(STEP_START):]
    if body.startswith('uses:'):
        ref = body[len('uses:'):].strip().split('@', 1)[0].split('#', 1)[0].strip()
        base = ref.rsplit('/', 1)[-1] or 'Step'
        return base[:1].upper() + base[1:]
    return 'Step'


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC
    dst = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_DST
    lines = open(src, encoding='utf-8').read().split('\n')

    # Locate the single `test` job: from `  test:` to the next 2-space job key.
    start = end = None
    for i, ln in enumerate(lines):
        if ln == '  test:':
            start = i
            continue
        if start is not None and i > start and ln.startswith('  ') \
                and not ln.startswith('   ') and ln.rstrip().endswith(':'):
            end = i
            break
    if start is None or end is None:
        sys.exit('could not locate the test job boundaries')

    named_prefixed = unnamed_named = 0
    out = []
    for i, ln in enumerate(lines):
        inside = start <= i < end
        if inside and ln.startswith(NAME_LINE):
            name = ln[len(NAME_LINE):]
            if name.startswith(PREFIX) or name.startswith('"' + PREFIX):
                sys.exit(f'line {i+1} already prefixed -- refusing to double-apply')
            if name.strip() == 'Upload test logs':
                out.extend(NEW_STEPS)
                out.extend(EVAL_LANE_COMMENT)
            out.append(NAME_LINE + quoted(name))
            named_prefixed += 1
        elif inside and ln.startswith(STEP_START) and not ln.startswith(NAME_LINE):
            # Unnamed step: insert a prefixed name line, then demote the
            # original step-start line to a continuation line (8-space indent).
            out.append(NAME_LINE + quoted(unnamed_step_name(ln)))
            out.append('        ' + ln[len(STEP_START):])
            unnamed_named += 1
        else:
            out.append(ln)

    open(dst, 'w', encoding='utf-8').write('\n'.join(out))
    print(f'source: {src}')
    print(f'test job lines: {start+1}..{end} (1-indexed, end exclusive)')
    print(f'named steps prefixed: {named_prefixed}')
    print(f'unnamed steps given a prefixed name: {unnamed_named}')
    print(f'total test-job steps now carrying the prefix: '
          f'{named_prefixed + unnamed_named}')
    print('new steps appended: 3 (Stream A, Stream B, Stream D self-check)')
    print(f'wrote: {dst}')


if __name__ == '__main__':
    main()
