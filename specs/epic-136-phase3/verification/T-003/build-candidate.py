#!/usr/bin/env python3
"""Deterministically transform the live workflow into T-003's staged candidate.

Input : scratchpad/live-workflow-copy.txt (byte copy of the live protected file)
Output: specs/epic-136-phase3/verification/T-003/staged-workflow-candidate.draft.yml

Transformation (design.md ".github/workflows/test.yml (Stream D + Stream A,
ONE shared staged batch)", AC-016/AC-017/AC-020):
  1. every step name inside the single `test` job gains a "[deterministic] "
     prefix (GitHub Actions native `name:` convention -- NO new job, NO job
     rename, NO step moved)
  2. one documented, currently-empty YAML comment placeholder marking where a
     future LLM-invoking eval lane job would be added
  3. Stream A's and Stream B's new bash-only CI steps appended inside the same
     `test` job, immediately before the trailing "Upload test logs" step
  4. everything outside the `test` job -- including
     `required-checks: needs: [test, cli-hook-enforcement]` -- is copied
     byte-for-byte unchanged
"""
import sys

SRC = ('/private/tmp/claude-501/-Users-jrmag-Projects-active-sdd-forge/'
       '34212325-74b2-4d93-b1da-679455f12b8b/scratchpad/live-workflow-copy.txt')
DST = ('/Users/jrmag/Projects/active/sdd-forge-wt-phase3/specs/epic-136-phase3/'
       'verification/T-003/staged-workflow-candidate.draft.yml')

PREFIX = '[deterministic] '
STEP_INDENT = '      - name: '

# design.md's exact new-step block (Stream A + Stream B), with the
# [deterministic] prefix applied for AC-016 consistency ("every test-job step").
NEW_STEPS = [
    '      - name: [deterministic] Test guard dispatch fallback suite (bash)',
    '        shell: bash',
    '        run: bash ./tests/guard-dispatch-fallback.tests.sh',
    '      - name: [deterministic] Test guard negative corpus suite (bash)',
    '        shell: bash',
    '        run: bash ./tests/guard-negative-corpus.tests.sh',
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

HEADER_NOTE = [
    '# ==========================================================================',
    '# STAGED CANDIDATE (DRAFT) -- epic-136 Phase 3, T-003 / issue #126',
    '#',
    '# This file is the byte-exact content intended for the human-copy staging',
    '# path under specs/epic-136-phase3/human-copy/ and, after that, for the',
    '# live protected workflow file itself.',
    '#',
    '# It lives at this NON-protected draft path because sdd-hook-guard denies',
    '# every agent write whose path ends with the protected workflow suffix --',
    '# including the human-copy staging path (suffix match, no human-copy',
    '# carve-out). Placing this content at the human-copy path is therefore a',
    '# HUMAN action, exactly like applying it to the live file afterwards.',
    '# See reports/implementation/epic-136-phase3/T-003.md for the full',
    '# discovery record and the remaining human-action checklist.',
    '#',
    '# Human application (two copies, both human-performed):',
    '#   1. this draft            -> specs/epic-136-phase3/human-copy/...',
    '#   2. human-copy candidate  -> the live workflow file',
    '# Verify with specs/epic-136-phase3/human-copy/MANIFEST.sha256 after step 1.',
    '# ==========================================================================',
]


def main():
    lines = open(SRC, encoding='utf-8').read().split('\n')
    # Locate the single `test` job: from its `  test:` key to the next
    # top-level job key at the same indentation.
    start = None
    end = None
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

    renamed = 0
    out = list(HEADER_NOTE)
    for i, ln in enumerate(lines):
        if start <= i < end and ln.startswith(STEP_INDENT):
            name = ln[len(STEP_INDENT):]
            if name.startswith(PREFIX):
                sys.exit(f'line {i+1} already prefixed -- refusing to double-apply')
            # Insert the new steps + lane comment immediately before the
            # trailing "Upload test logs" step, keeping them inside `test`.
            if name.strip() == 'Upload test logs':
                out.extend(NEW_STEPS)
                out.extend(EVAL_LANE_COMMENT)
            out.append(STEP_INDENT + PREFIX + name)
            renamed += 1
        else:
            out.append(ln)

    open(DST, 'w', encoding='utf-8').write('\n'.join(out))
    print(f'test job lines: {start+1}..{end} (1-indexed, end exclusive)')
    print(f'steps renamed with the [deterministic] prefix: {renamed}')
    print('new steps appended: 2 (Stream A, Stream B)')
    print(f'wrote: {DST}')


if __name__ == '__main__':
    main()
