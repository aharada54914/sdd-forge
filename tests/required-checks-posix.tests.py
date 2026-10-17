#!/usr/bin/env python3
"""Exercise the repository's required-checks shell body, not a replica.

Accept an optional workflow path for validating a human-applied candidate.
This intentionally supports the current explicit, single-step YAML shape;
structural changes must update this test rather than silently skip checks.
"""
import pathlib
import re
import shutil
import subprocess
import sys
import unittest

WORKFLOW = pathlib.Path(sys.argv.pop(1)) if len(sys.argv) > 1 else (
    pathlib.Path(__file__).resolve().parents[1] / '.github/workflows/test.yml'
)
REQUIRED = (
    'test', 'test-windows-heavy', 'installers', 'loops-routing', 'version-gates',
    'version-gates-windows-bump', 'version-gates-windows-lanes', 'mcp-tests',
    'local-env-mcp-tests', 'ci-mcp-tests', 'cli-hook-enforcement',
    'posix-regression', 'posix-unwired-sharded',
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

    def test_selected_plan_full_suite_runs_on_all_native_platforms(self):
        blocks = re.findall(r'^  test:\n((?:^    .*\n|^\s*\n)*)', self.workflow, re.M)
        self.assertEqual(len(blocks), 1)
        job = blocks[0]
        self.assertIn('    runs-on: ${{ matrix.os }}', job.splitlines())
        platforms = re.findall(r'^        os: \[([^\n]+)\]$', job, re.M)
        self.assertEqual(len(platforms), 1)
        self.assertEqual({item.strip() for item in platforms[0].split(',')},
                         {'windows-latest', 'macos-latest', 'ubuntu-latest'})
        steps = re.split(r'^      - ', job, flags=re.M)[1:]
        suite = 'tests/sdd-domain-multitarget-T-003.tests.py'
        consumers = [step for step in steps if suite in step]
        self.assertEqual(len(consumers), 1, 'the full selected-plan suite needs a direct matrix step')
        step = consumers[0]
        self.assertNotRegex(step, r'(?m)^        (if|continue-on-error):')
        self.assertIn('        shell: pwsh', step.splitlines())
        self.assertIn(f'        run: python -B {suite}', step.splitlines())
        installs = [step for step in steps
                    if 'run: npm ci --prefix mcp/sdd-forge-mcp --ignore-scripts' in step]
        self.assertEqual(len(installs), 1)
        self.assertNotRegex(installs[0], r'(?m)^        (if|continue-on-error):')
        self.assertLess(steps.index(installs[0]), steps.index(consumers[0]))

    def test_transport_dependency_is_pinned_and_installed_first(self):
        job = re.findall(r'^  posix-regression:\n((?:^    .*\n|^\s*\n)*)',
                         self.workflow, re.M)[0]
        steps = re.split(r'^      - ', job, flags=re.M)[1:]
        installs = [step for step in steps if step.startswith('name: Install pinned RTK\n')]
        self.assertEqual(len(installs), 1)
        install = installs[0]
        self.assertNotRegex(install, r'(?m)^        (if|continue-on-error):')
        self.assertIn('shell: bash', install)
        self.assertIn('set -euo pipefail', install)
        self.assertIn('/v0.51.0/rtk-x86_64-unknown-linux-musl.tar.gz', install)
        self.assertIn('5028d3b19a8f0990d30fec9fbb07e32782bc5698e618fb1861aad8a9ccba4eb5', install)
        self.assertLess(install.index('sha256sum --check'), install.index('tar -xzf'))
        self.assertIn('"$GITHUB_PATH"', install)
        consumers = [step for step in steps if 'tests/quality-nontty-transport.tests.py' in step]
        self.assertEqual(len(consumers), 1)
        self.assertLess(steps.index(install), steps.index(consumers[0]))

    def test_domain_finalization_has_its_own_unconditional_native_step(self):
        job = re.findall(r'^  test:\n((?:^    .*\n|^\s*\n)*)', self.workflow, re.M)[0]
        steps = re.split(r'^      - ', job, flags=re.M)[1:]
        consumers = [step for step in steps if 'tests/domain-review-finalize.tests.py' in step]
        self.assertEqual(len(consumers), 1)
        self.assertNotRegex(consumers[0], r'(?m)^        (if|continue-on-error):')
        self.assertIn('        run: python -B tests/domain-review-finalize.tests.py',
                      consumers[0].splitlines())

    def test_each_native_python_failure_propagates_to_the_step(self):
        job = re.findall(r'^  test:\n((?:^    .*\n|^\s*\n)*)', self.workflow, re.M)[0]
        steps = re.split(r'^      - ', job, flags=re.M)[1:]
        executable = "'" + sys.executable.replace("'", "''") + "'"
        for suite in ('tests/concept-test.tests.py', 'tests/domain-review-finalize.tests.py'):
            with self.subTest(suite=suite):
                consumers = [step for step in steps if suite in step]
                self.assertEqual(len(consumers), 1)
                step = consumers[0]
                self.assertIn('        shell: pwsh', step.splitlines())
                body = step.split('        run: ', 1)[1]
                if body.startswith('|\n'):
                    body = '\n'.join(line[10:] for line in body[2:].splitlines())
                body = re.sub(r'python -B (tests/[\w.-]+\.py)',
                              lambda match: f'& {executable} -c "raise SystemExit({23 if match[1] == suite else 0})"',
                              body)
                # GitHub's pwsh wrapper exits with the final native command's
                # status. Exercise the actual step body with one failing suite.
                script = ("$ErrorActionPreference = 'stop'\n"
                          "$PSNativeCommandUseErrorActionPreference = $false\n" + body +
                          "\nif (Test-Path variable:\\LASTEXITCODE) { exit $LASTEXITCODE }\n")
                run = subprocess.run([shutil.which('pwsh') or 'pwsh', '-NoProfile', '-Command', script],
                                     capture_output=True, text=True, timeout=30)
                self.assertEqual(run.returncode, 23, run.stdout + run.stderr)

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
