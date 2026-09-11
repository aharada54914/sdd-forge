#!/usr/bin/env python3
"""Exercise the repository's required-checks shell body, not a replica.

Accept an optional workflow path for validating a human-applied candidate.
This intentionally supports the current explicit, single-step YAML shape;
structural changes must update this test rather than silently skip checks.
"""
import pathlib
import re
import subprocess
import sys
import unittest

WORKFLOW = pathlib.Path(sys.argv.pop(1)) if len(sys.argv) > 1 else (
    pathlib.Path(__file__).resolve().parents[1] / '.github/workflows/test.yml'
)
REQUIRED = (
    'test', 'installers', 'loops-routing', 'version-gates', 'mcp-tests',
    'local-env-mcp-tests', 'ci-mcp-tests', 'cli-hook-enforcement',
    'posix-regression',
)


class RequiredChecksTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        text = WORKFLOW.read_text(encoding='utf-8')
        cls.workflow = text
        blocks = re.findall(r'^  required-checks:\n((?:^    .*\n|^\s*\n)*)', text, re.M)
        if len(blocks) != 1:
            raise ValueError('expected one required-checks job')
        cls.job = blocks[0]
        needs = re.findall(r'^    needs: \[([^\n]+)\]$', cls.job, re.M)
        if len(needs) != 1:
            raise ValueError('expected one explicit needs list')
        cls.needs = [name.strip() for name in needs[0].split(',')]
        bodies = re.findall(r'^        run: \|\n((?:^          .*\n|^\s*\n)*)', cls.job, re.M)
        if len(bodies) != 1:
            raise ValueError('expected one required-checks shell body')
        cls.body = '\n'.join(line[10:] for line in bodies[0].splitlines())

    def test_dependencies_and_always(self):
        self.assertEqual(len(self.needs), len(set(self.needs)))
        self.assertTrue(set(REQUIRED).issubset(self.needs))
        self.assertIn('    if: always()', self.job.splitlines())

    def test_previously_missing_suites_have_unconditional_steps(self):
        blocks = re.findall(r'^  posix-regression:\n((?:^    .*\n|^\s*\n)*)',
                            self.workflow, re.M)
        self.assertEqual(len(blocks), 1)
        steps = re.split(r'^      - ', blocks[0], flags=re.M)[1:]
        commands = (
            'bash ./tests/guard-dispatch-fallback.tests.sh',
            'bash ./tests/guard-negative-corpus.tests.sh',
            'bash ./tests/deterministic-lane-selfcheck.tests.sh',
            'bash ./tests/workflow-scenarios/workflow-scenarios.tests.sh',
            'bash ./tests/design-system-contract.tests.sh',
            './tests/design-system-contract.tests.ps1',
            'bash ./tests/design-sync-standing-consent.tests.sh',
            './tests/design-sync-standing-consent.tests.ps1',
        )
        for command in commands:
            with self.subTest(command=command):
                matches = [step for step in steps
                           if f'        run: {command}' in step.splitlines()]
                self.assertEqual(len(matches), 1, 'expected one direct CI step')
                self.assertNotRegex(matches[0], r'(?m)^        (if|continue-on-error):')
                shell = 'pwsh' if command.endswith('.ps1') else 'bash'
                self.assertIn(f'        shell: {shell}', matches[0].splitlines())

    def execute_body(self, failed_job=None, result='success'):
        def expand(match):
            name = match[1]
            self.assertIn(name, self.needs)
            return result if name == failed_job else 'success'
        body = re.sub(r'\$\{\{ needs\.([a-z-]+)\.result \}\}', expand, self.body)
        self.assertNotIn('${{', body)
        return subprocess.run(['bash', '-e', '-c', body], capture_output=True,
                              text=True, timeout=10)

    def test_all_success(self):
        run = self.execute_body()
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)

    def test_each_dependency_non_success(self):
        for name in REQUIRED:
            for result in ('failure', 'cancelled', 'skipped', ''):
                with self.subTest(job=name, result=result):
                    run = self.execute_body(name, result)
                    self.assertNotEqual(run.returncode, 0, f'{name}={result!r} was accepted')


if __name__ == '__main__':
    unittest.main(verbosity=2)
