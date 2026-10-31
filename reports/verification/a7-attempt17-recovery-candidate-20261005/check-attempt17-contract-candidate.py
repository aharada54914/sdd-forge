#!/usr/bin/env python3
"""Read-only candidate-helper validation of the non-formal attempt-17 inputs."""
import pathlib
import runpy
from unittest.mock import patch

ROOT = pathlib.Path('/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge')
HERE = pathlib.Path(__file__).resolve().parent
FEATURE = 'epic-195-a7-compatibility'
CONTRACT = HERE / 'fresh-review-contract-attempt17.candidate.json'
INSTALLED_FAILED = ROOT / 'plugins/sdd-review-loop/scripts/failed-last-attempt.py'


def main():
    if HERE.parents[2] != ROOT:
        raise ValueError('wrong owner checkout')
    actual_run_path = runpy.run_path
    recovery = actual_run_path(str(HERE / 'fresh-review-recovery.py.candidate'))
    failed = actual_run_path(str(HERE / 'failed-last-attempt.py.candidate'))

    def candidate_failed_only(path):
        if pathlib.Path(path) == INSTALLED_FAILED:
            return failed
        return actual_run_path(path)

    with patch('runpy.run_path', side_effect=candidate_failed_only):
        result = recovery['validate'](ROOT, FEATURE, 17, CONTRACT)
    rounds = [(item['attempt'], item['round']) for item in result['completed_rounds']]
    if rounds != [(15, 1), (15, 2)]:
        raise ValueError('unexpected completed-round inventory: ' + str(rounds))
    if result['terminal_attempt'] != 7 or result['contract_path'] != CONTRACT.relative_to(ROOT).as_posix():
        raise ValueError('candidate recovery binding mismatch')
    print('PASS candidate helper validates real pinned evidence; completed rounds=' + str(rounds))
    print('PASS contract sha256=' + result['contract_sha256'])
    print('NO_PRECHECK_NO_RESERVATION')


if __name__ == '__main__':
    main()
