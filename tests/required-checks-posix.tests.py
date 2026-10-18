#!/usr/bin/env python3
"""Validate parsed workflow contracts and execute its actual failure boundaries."""
import copy
import importlib.util
import json
import pathlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('workflow_contract', ROOT / 'tests/verification-workflow.py')
WF = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(WF)
WORKFLOW = pathlib.Path(sys.argv.pop(1)) if len(sys.argv) > 1 else ROOT / '.github/workflows/test.yml'
REQUIRED = (
    'test', 'test-windows-heavy', 'installers', 'loops-routing', 'version-gates',
    'version-gates-windows-bump', 'version-gates-windows-lanes', 'mcp-tests',
    'local-env-mcp-tests', 'ci-mcp-tests', 'cli-hook-enforcement',
    'posix-regression', 'posix-unwired-sharded', 'a9-advisory-inputs', 'a9-advisory',
)


def unconditional(step):
    return WF.enabled(step.get('if'), {}, None) and step.get('continue-on-error', False) is False


class RequiredChecksTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = WF.load_workflow(WORKFLOW)
        cls.catalog = json.loads((ROOT / 'tests/verification-catalog.json').read_text())
        cls.job = cls.workflow['jobs']['required-checks']
        cls.needs = cls.job.get('needs', [])
        if isinstance(cls.needs, str):
            cls.needs = [cls.needs]
        bodies = [step['run'] for step in cls.job.get('steps', []) if isinstance(step.get('run'), str)]
        if len(bodies) != 1:
            raise ValueError('expected one required-checks shell body')
        cls.body = bodies[0]

    def consumers(self, job_name, suite):
        job = self.workflow['jobs'][job_name]
        return [step for step in job['steps']
                if suite in WF.step_suites(step, self.catalog, {}, step.get('shell', 'bash'))]

    def test_dependencies_and_always(self):
        self.assertEqual(len(self.needs), len(set(self.needs)))
        self.assertTrue(set(REQUIRED).issubset(self.needs))
        self.assertTrue(set(self.needs).issubset(self.workflow['jobs']))
        self.assertIn(self.job.get('if'), ('always()', '${{ always() }}'))
        self.assertIs(self.job.get('continue-on-error', False), False)
        step = next(step for step in self.job['steps'] if 'run' in step)
        self.assertTrue(unconditional(step))
        self.assertEqual(step.get('shell', 'bash'), 'bash')

    def test_previously_missing_suites_have_unconditional_steps(self):
        suites = (
            'tests/guard-dispatch-fallback.tests.sh',
            'tests/guard-negative-corpus.tests.sh',
            'tests/deterministic-lane-selfcheck.tests.sh',
            'tests/workflow-scenarios/workflow-scenarios.tests.sh',
            'tests/design-system-contract.tests.sh',
            'tests/design-system-contract.tests.ps1',
            'tests/design-sync-standing-consent.tests.sh',
            'tests/design-sync-standing-consent.tests.ps1',
        )
        for suite in suites:
            with self.subTest(suite=suite):
                matches = self.consumers('posix-regression', suite)
                self.assertEqual(len(matches), 1)
                self.assertTrue(unconditional(matches[0]))
                self.assertEqual(matches[0].get('shell'), 'pwsh' if suite.endswith('.ps1') else 'bash')

    def test_selected_plan_full_suite_runs_on_all_native_platforms(self):
        job = self.workflow['jobs']['test']
        platforms = {WF.expand_matrix(job['runs-on'], row) for row in WF.matrix_rows(job)}
        self.assertEqual(platforms, {'windows-latest', 'macos-latest', 'ubuntu-latest'})
        consumers = self.consumers('test', 'tests/sdd-domain-multitarget-T-003.tests.py')
        self.assertEqual(len(consumers), 1)
        self.assertTrue(unconditional(consumers[0]))
        self.assertEqual(consumers[0]['shell'], 'pwsh')
        installs = []
        for step in job['steps']:
            tokens = shlex.split(step.get('run', ''))
            if tokens[:2] == ['npm', 'ci'] and '--prefix' in tokens:
                index = tokens.index('--prefix')
                if tokens[index + 1:index + 2] == ['mcp/sdd-forge-mcp'] and '--ignore-scripts' in tokens:
                    installs.append(step)
        self.assertEqual(len(installs), 1)
        self.assertTrue(unconditional(installs[0]))
        self.assertLess(job['steps'].index(installs[0]), job['steps'].index(consumers[0]))

    def test_transport_dependency_is_pinned_and_installed_first(self):
        steps = self.workflow['jobs']['posix-regression']['steps']
        installs = [step for step in steps if '/v0.51.0/rtk-x86_64-unknown-linux-musl.tar.gz' in step.get('run', '')]
        self.assertEqual(len(installs), 1)
        step = installs[0]
        self.assertTrue(unconditional(step))
        self.assertEqual(step.get('shell'), 'bash')
        body = '\n'.join(line for line in step['run'].splitlines() if not line.lstrip().startswith('#'))
        self.assertIn('set -euo pipefail', body)
        self.assertIn('5028d3b19a8f0990d30fec9fbb07e32782bc5698e618fb1861aad8a9ccba4eb5', body)
        self.assertLess(body.index('sha256sum --check'), body.index('tar -xzf'))
        self.assertIn('"$GITHUB_PATH"', body)
        consumers = self.consumers('posix-regression', 'tests/quality-nontty-transport.tests.py')
        self.assertEqual(len(consumers), 1)
        self.assertLess(steps.index(step), steps.index(consumers[0]))

    def test_domain_finalization_has_its_own_unconditional_native_step(self):
        consumers = self.consumers('test', 'tests/domain-review-finalize.tests.py')
        self.assertEqual(len(consumers), 1)
        self.assertTrue(unconditional(consumers[0]))
        self.assertEqual(consumers[0]['shell'], 'pwsh')
        self.assertEqual(len([line for line in consumers[0]['run'].splitlines() if line.strip()]), 1)

    def test_each_native_python_failure_propagates_to_the_step(self):
        executable = "'" + sys.executable.replace("'", "''") + "'"
        for suite in ('tests/concept-test.tests.py', 'tests/domain-review-finalize.tests.py'):
            with self.subTest(suite=suite):
                consumers = self.consumers('test', suite)
                self.assertEqual(len(consumers), 1)
                step = consumers[0]
                self.assertEqual(step['shell'], 'pwsh')
                body = re.sub(r'python3? (?:-B )?(tests/[\w.-]+\.py)',
                              lambda match: f'& {executable} -c "raise SystemExit({23 if match[1] == suite else 0})"',
                              step['run'])
                script = ("$ErrorActionPreference = 'stop'\n"
                          "$PSNativeCommandUseErrorActionPreference = $false\n" + body +
                          "\nif (Test-Path variable:\\LASTEXITCODE) { exit $LASTEXITCODE }\n")
                run = subprocess.run([shutil.which('pwsh') or 'pwsh', '-NoProfile', '-Command', script],
                                     capture_output=True, text=True, timeout=30)
                self.assertEqual(run.returncode, 23, run.stdout + run.stderr)

    def test_catalog_declared_ci_jobs_have_actual_execution(self):
        self.assertEqual(WF.coverage_errors(self.workflow, self.catalog), [])

    def test_yaml_format_and_step_names_do_not_define_coverage(self):
        changed = copy.deepcopy(self.workflow)
        for job in changed['jobs'].values():
            for step in job.get('steps', []):
                step['name'] = 'arbitrary display name'
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / 'workflow.yml'
            # JSON is YAML's flow-style subset; this also changes all indentation
            # and serializes needs/matrices independently of the source layout.
            path.write_text(json.dumps(changed, indent=3))
            parsed = WF.load_workflow(path)
        self.assertEqual(WF.workflow_coverage(parsed, self.catalog), WF.workflow_coverage(self.workflow, self.catalog))
        self.assertEqual(parsed['jobs']['required-checks']['needs'], self.needs)
        self.assertEqual(parsed['jobs']['required-checks']['steps'][0]['run'], self.body)

    def test_removed_disabled_or_prose_invocations_cannot_prove_coverage(self):
        suite = 'tests/guard-dispatch-fallback.tests.sh'
        catalog = {'suites': [{'path': suite, 'runtime': 'bash', 'ci_jobs': ['fixture']}], 'profiles': {'focused': [suite]}}
        direct = {'run': f'bash ./{suite}', 'shell': 'bash'}
        def workflow(step):
            return {'jobs': {'fixture': {'runs-on': 'ubuntu-latest', 'steps': [step]}}}
        self.assertEqual(WF.coverage_errors(workflow(direct), catalog), [])
        profile = {'run': 'python3 tests/verification.py --profile focused --run', 'shell': 'bash'}
        self.assertEqual(WF.coverage_errors(workflow(profile), catalog), [])
        for step in (
            {'run': 'echo done', 'name': suite},
            {'run': '# bash ' + suite},
            {'run': 'echo bash ' + suite},
            {'run': "cat <<'EOF'\nbash " + suite + '\nEOF'},
            {'run': 'if false; then\nbash ' + suite + '\nfi'},
            dict(direct, **{'if': False}),
            dict(direct, **{'continue-on-error': True}),
            dict(direct, **{'working-directory': 'elsewhere'}),
            {'run': 'python3 tests/verification.py --profile focused --list'},
            {'run': f'bash {suite} --list'},
            {'run': f'bash -n {suite}'},
            {'run': f'\"bash {suite}\"'},
            {'run': 'python3 tests/verification.py --profile missing --run'},
        ):
            with self.subTest(step=step):
                self.assertTrue(WF.coverage_errors(workflow(step), catalog))
        disabled = workflow(direct)
        disabled['jobs']['fixture']['if'] = False
        self.assertTrue(WF.coverage_errors(disabled, catalog))

    def test_matrix_suite_profile_and_condition_coverage(self):
        paths = ['tests/a.tests.py', 'tests/b.tests.py']
        catalog = {'suites': [{'path': path, 'runtime': 'python', 'ci_jobs': ['matrix']} for path in paths],
                   'profiles': {'both': paths}}
        workflow = {'jobs': {'matrix': {'runs-on': 'windows-latest',
                    'strategy': {'matrix': {'include': [{'suite': path} for path in paths]}},
                    'steps': [{'run': 'python tests/verification.py --suite "${{ matrix.suite }}" --run',
                               'shell': 'pwsh'}]}}}
        self.assertEqual(WF.coverage_errors(workflow, catalog), [])
        workflow['jobs']['matrix']['steps'][0]['if'] = "matrix.suite == 'tests/a.tests.py'"
        errors = WF.coverage_errors(workflow, catalog)
        self.assertEqual(len(errors), 1)
        self.assertIn(paths[1], errors[0])
        workflow['jobs']['matrix']['steps'][0]['if'] = 'unknown()'
        self.assertEqual(len(WF.coverage_errors(workflow, catalog)), 2)

    def test_duplicate_yaml_keys_and_wrong_shell_are_not_execution(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / 'workflow.yml'
            path.write_text('jobs: {}\njobs: {}\n')
            with self.assertRaises(ValueError):
                WF.load_workflow(path)
        catalog = {'suites': [{'path': 'tests/a.ps1', 'runtime': 'powershell', 'ci_jobs': ['job']}], 'profiles': {}}
        workflow = {'jobs': {'job': {'runs-on': 'ubuntu-latest', 'steps': [{'run': './tests/a.ps1', 'shell': 'bash'}]}}}
        self.assertTrue(WF.coverage_errors(workflow, catalog))
        workflow['jobs']['job']['steps'][0]['shell'] = 'pwsh'
        self.assertEqual(WF.coverage_errors(workflow, catalog), [])

    def test_powershell_multiline_native_failure_is_not_coverage(self):
        paths = ['tests/a.tests.py', 'tests/b.tests.py']
        catalog = {'suites': [{'path': path, 'runtime': 'python', 'ci_jobs': ['job']} for path in paths],
                   'profiles': {'both': paths}}
        workflow = {'jobs': {'job': {'runs-on': 'windows-latest',
                    'steps': [{'run': '\n'.join('python ' + path for path in paths), 'shell': 'pwsh'}]}}}
        self.assertEqual(len(WF.coverage_errors(workflow, catalog)), 2)
        executable = "'" + sys.executable.replace("'", "''") + "'"
        # Real host semantics reproduce why two individually invoked native
        # processes cannot prove that the first test's failure gates the job.
        body = f'& {executable} -c "raise SystemExit(23)"\n& {executable} -c "raise SystemExit(0)"\nexit $LASTEXITCODE'
        run = subprocess.run([shutil.which('pwsh') or 'pwsh', '-NoProfile', '-Command', body],
                             text=True, capture_output=True, timeout=30)
        self.assertEqual(run.returncode, 0)
        workflow['jobs']['job']['steps'][0]['run'] = 'python tests/verification.py --profile both --run'
        self.assertEqual(WF.coverage_errors(workflow, catalog), [])

    def test_fallback_shards_are_complete_unconditional_and_required(self):
        self.assertEqual(WF.shard_errors(self.workflow), [])
        job_name = 'posix-unwired-sharded'
        mutants = []
        for indices in ([0, 1, 2], [0, 1, 2, 2], [0, 1, 2, 4]):
            value = copy.deepcopy(self.workflow)
            value['jobs'][job_name]['strategy']['matrix']['shard'] = indices
            mutants.append(value)
        for field, setting in (('if', False), ('continue-on-error', True)):
            value = copy.deepcopy(self.workflow)
            value['jobs'][job_name][field] = setting
            mutants.append(value)
        value = copy.deepcopy(self.workflow)
        value['jobs']['required-checks']['needs'].remove(job_name)
        mutants.append(value)
        for mode in ('if', 'continue-on-error', 'count', 'echo'):
            value = copy.deepcopy(self.workflow)
            step = next(step for step in value['jobs'][job_name]['steps']
                        if 'tests/run-ci-unwired.sh' in step.get('run', ''))
            if mode in ('if', 'continue-on-error'):
                step[mode] = False if mode == 'if' else True
            elif mode == 'count':
                step['run'] = step['run'].replace('--shard-count 4', '--shard-count 3')
            else:
                step['run'] = 'echo ' + step['run']
            mutants.append(value)
        for number, value in enumerate(mutants):
            with self.subTest(mutation=number):
                self.assertTrue(WF.shard_errors(value))
        job = self.workflow['jobs'][job_name]
        step = next(step for step in job['steps'] if 'tests/run-ci-unwired.sh' in step.get('run', ''))
        with tempfile.TemporaryDirectory() as directory:
            fail = pathlib.Path(directory) / 'fail.sh'
            fail.write_text('exit 23\n')
            body = WF.expand_matrix(step['run'], {'shard': 0}).replace('./tests/run-ci-unwired.sh', shlex.quote(str(fail)))
            run = subprocess.run(['bash', '-e', '-o', 'pipefail', '-c', body],
                                 capture_output=True, text=True, timeout=10)
            self.assertEqual(run.returncode, 23)

    def execute_body(self, failed_job=None, result='success', active='true'):
        def expand(match):
            name = match[1]
            self.assertIn(name, self.needs)
            return result if name == failed_job else 'success'
        body = re.sub(r'\$\{\{ needs\.([a-z0-9-]+)\.result \}\}', expand, self.body)
        body = body.replace('${{ needs.a9-advisory-inputs.outputs.active }}', active)
        self.assertNotIn('${{', body)
        return subprocess.run(['bash', '-e', '-c', body], capture_output=True,
                              text=True, timeout=10)

    def test_all_success(self):
        run = self.execute_body()
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)

    def test_inactive_advisory_is_skipped_not_success(self):
        self.assertEqual(self.execute_body('a9-advisory', 'skipped', 'false').returncode, 0)
        for active, result in (('false', 'success'), ('false', 'failure'), ('', 'skipped'), ('true', 'skipped')):
            with self.subTest(active=active, result=result):
                self.assertNotEqual(self.execute_body('a9-advisory', result, active).returncode, 0)

    def test_each_dependency_non_success(self):
        for name in self.needs:
            for result in ('failure', 'cancelled', 'skipped', ''):
                with self.subTest(job=name, result=result):
                    run = self.execute_body(name, result)
                    self.assertNotEqual(run.returncode, 0, f'{name}={result!r} was accepted')


if __name__ == '__main__':
    unittest.main(verbosity=2)
