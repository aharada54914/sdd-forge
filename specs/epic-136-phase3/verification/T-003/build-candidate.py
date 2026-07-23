#!/usr/bin/env python3
"""Deterministically transform the live workflow into T-003's staged candidate.

Input : scratchpad/live-workflow-copy.txt (byte copy of the live protected file)
Output: specs/epic-136-phase3/verification/T-003/staged-workflow-candidate.draft.yml

Transformation (design.md ".github/workflows/test.yml (Stream D + Stream A,
ONE shared staged batch)", AC-016/AC-017/AC-020):
  1. every step inside the single `test` job gets a "[deterministic] " name
     prefix. Named steps have their `name:` prefixed; an UNNAMED step
     (`      - uses:` / `      - run:` with no name) is given a name derived
     from its action/command so it, too, carries the prefix (AC-016: EVERY
     step). No new job, no job rename, no step moved.
  2. one documented, currently-empty YAML comment placeholder marking where a
     future LLM-invoking eval lane job would be added.
  3. Stream A's, Stream B's, and Stream D's own new bash-only CI steps appended
     inside the same `test` job (REQ-005: every new suite this feature adds
     gets a staged CI step).
  4. everything outside the `test` job -- including
     `required-checks: needs: [test, cli-hook-enforcement]` -- is copied
     byte-for-byte unchanged.

No draft/banner comment is emitted into the candidate: the candidate is the
byte-exact content intended for the live workflow, so it must contain nothing
that would not belong in the live file. The draft-path rationale lives in the
implementation report and in a sibling README, not in the YAML.
"""
import sys

SRC = ('/private/tmp/claude-501/-Users-jrmag-Projects-active-sdd-forge/'
       '34212325-74b2-4d93-b1da-679455f12b8b/scratchpad/live-workflow-copy.txt')
DST = ('/Users/jrmag/Projects/active/sdd-forge-wt-phase3/specs/epic-136-phase3/'
       'verification/T-003/staged-workflow-candidate.draft.yml')

PREFIX = '[deterministic] '
NAME_LINE = '      - name: '
STEP_START = '      - '        # a step's first line inside a job (6 spaces + "- ")

NEW_STEPS = [
    '      - name: [deterministic] Test guard dispatch fallback suite (bash)',
    '        shell: bash',
    '        run: bash ./tests/guard-dispatch-fallback.tests.sh',
    '      - name: [deterministic] Test guard negative corpus suite (bash)',
    '        shell: bash',
    '        run: bash ./tests/guard-negative-corpus.tests.sh',
    '      - name: [deterministic] Test deterministic-lane self-check suite (bash)',
    '        shell: bash',
    '        run: bash ./tests/deterministic-lane-selfcheck.tests.sh',
]

EVAL_LANE_COMMENT = [
    '      # ---------------------------------------------------------------',
    '      # [deterministic] lane boundary (epic-136 Phase 3, Stream D, #126).',
    '      # Every step above this marker inside the `test` job is',
    '      # deterministic: no step invokes an LLM. A future LLM-invoking eval',
    '      # lane is added as a SEPARATE job, not as a step here -- this',
    '      # placeholder marks where that job would be introduced. It is',
    '      # intentionally empty today: adding the job here would change the',
    "      # job graph and `required-checks`' `needs:` list, which BL-001",
    '      # forbids for this feature (design.md Design Decisions OQ-5).',
    '      # eval-lane: (none yet)',
    '      # ---------------------------------------------------------------',
]


def unnamed_step_name(line):
    """Derive a [deterministic] name for an unnamed `- uses:`/`- run:` step."""
    body = line[len(STEP_START):]
    if body.startswith('uses:'):
        ref = body[len('uses:'):].strip().split('@', 1)[0].split('#', 1)[0].strip()
        base = ref.rsplit('/', 1)[-1] or 'Step'
        return PREFIX + base[:1].upper() + base[1:]
    return PREFIX + 'Step'


def main():
    lines = open(SRC, encoding='utf-8').read().split('\n')
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

    renamed = named_prefixed = unnamed_named = 0
    out = []
    for i, ln in enumerate(lines):
        inside = start <= i < end
        if inside and ln.startswith(NAME_LINE):
            name = ln[len(NAME_LINE):]
            if name.startswith(PREFIX):
                sys.exit(f'line {i+1} already prefixed -- refusing to double-apply')
            if name.strip() == 'Upload test logs':
                out.extend(NEW_STEPS)
                out.extend(EVAL_LANE_COMMENT)
            out.append(NAME_LINE + PREFIX + name)
            named_prefixed += 1
            renamed += 1
        elif inside and ln.startswith(STEP_START) and not ln.startswith(NAME_LINE):
            # Unnamed step: insert a prefixed name line, then demote the
            # original step-start line to a continuation line (8-space indent).
            out.append(NAME_LINE + unnamed_step_name(ln))
            out.append('        ' + ln[len(STEP_START):])
            unnamed_named += 1
            renamed += 1
        else:
            out.append(ln)

    open(DST, 'w', encoding='utf-8').write('\n'.join(out))
    print(f'test job lines: {start+1}..{end} (1-indexed, end exclusive)')
    print(f'named steps prefixed: {named_prefixed}')
    print(f'unnamed steps given a prefixed name: {unnamed_named}')
    print(f'total test-job steps now carrying the prefix: {renamed}')
    print('new steps appended: 3 (Stream A, Stream B, Stream D self-check)')
    print(f'wrote: {DST}')


if __name__ == '__main__':
    main()
