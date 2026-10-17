#!/usr/bin/env python3
"""Exercise the same Git-backed input contract through the Bash consumers."""
import importlib.util
from pathlib import Path
import shutil
import subprocess
import unittest

source = Path(__file__).with_name('fixed-review-precheck-ps.tests.py')
spec = importlib.util.spec_from_file_location('fixed_precheck_cases', source)
cases = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cases)


@unittest.skipUnless(shutil.which('bash') and shutil.which('jq'), 'bash/jq unavailable')
class FixedBashPrechecks(cases.FixedPowerShellPrechecks):
    __unittest_skip__ = False

    def run_check(self, argv, expected):
        result = subprocess.run(argv, cwd=Path(argv[1]).parents[3], capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, expected, result.stdout + result.stderr)
        return result

    def fixture(self, stage, **kwargs):
        repo, snapshot, report, _, flags = super().fixture(stage, **kwargs)
        argv = ['bash', str(repo / 'plugins/sdd-review-loop/scripts' /
                           (stage + '-review-precheck.sh')), 'example', '1', '1', '--verify-inputs']
        return repo, snapshot, report, argv, ['--fixed-input-record', flags[1],
                                            '--fixed-input-snapshot', flags[3]]

    def test_pair_and_verify_only_options(self):
        for stage in ('spec', 'impl', 'task'):
            with self.subTest(stage=stage):
                _, _, _, argv, flags = self.fixture(stage)
                self.run_check(argv + flags[:2], False)
                self.run_check(argv + flags[2:], False)
                self.run_check([arg for arg in argv if arg != '--verify-inputs'] + flags, False)

    def test_git_investigation_cannot_be_omitted(self):
        _, _, _, argv, flags = self.fixture('spec', omitted='investigation.md')
        result = self.run_check(argv + flags, False)
        self.assertIn('required source absent', result.stderr)


if __name__ == '__main__':
    unittest.main()
