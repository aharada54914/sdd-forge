#!/usr/bin/env python3
"""Behavioral contracts for the executable verification catalog."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import shutil
from unittest.mock import patch
import tempfile
import unittest
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('verification', ROOT / 'tests/verification.py')
assert SPEC and SPEC.loader
V = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V)


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'tests').mkdir()
        self.paths = ['tests/a.tests.py', 'tests/b.tests.py']
        for path in self.paths:
            (self.root / path).write_text('print("fixture")\n')
        self.catalog: dict[str, Any] = {
            'schema': 'verification-catalog/v1',
            'suites': [{'path': p, 'runtime': 'python'} for p in self.paths],
            'profiles': {'test': self.paths.copy()},
        }

    def load(self):
        path = self.root / 'tests/catalog.json'
        path.write_text(json.dumps(self.catalog))
        return V.load_catalog(path, self.root)

    def test_unknown_duplicate_and_missing_entries_fail(self):
        self.load()
        for mutate in (
            lambda: self.catalog['profiles']['test'].append('tests/missing.tests.py'),
            lambda: self.catalog['suites'].append(self.catalog['suites'][0].copy()),
            lambda: self.catalog['profiles']['test'].append(self.paths[0]),
        ):
            original = json.loads(json.dumps(self.catalog))
            mutate()
            with self.assertRaises(ValueError):
                self.load()
            self.catalog = original
        (self.root / self.paths[0]).unlink()
        with self.assertRaises(ValueError):
            self.load()

    def test_new_suite_requires_explicit_registration(self):
        (self.root / 'tests/new.tests.sh').write_text('exit 0\n')
        with self.assertRaisesRegex(ValueError, 'unregistered'):
            self.load()

    def test_unassigned_or_cyclic_delegation_fails(self):
        self.catalog['profiles']['test'] = []
        with self.assertRaises(ValueError):
            self.load()
        for a, b in zip(self.catalog['suites'], reversed(self.paths)):
            a['delegated_to'] = b
        with self.assertRaises(ValueError):
            self.load()

    def test_delegated_suite_requires_registered_executed_parent(self):
        self.catalog['profiles']['test'] = [self.paths[0]]
        self.catalog['suites'][1]['delegated_to'] = self.paths[0]
        self.load()
        self.catalog['suites'][1]['delegated_to'] = 'tests/missing.tests.py'
        with self.assertRaises(ValueError):
            self.load()

    def test_balanced_shards_are_deterministic_disjoint_complete(self):
        paths = ['a', 'b', 'c', 'd', 'e']
        weights = dict(zip(paths, [10, 8, 4, 3, 1]))
        shards = V.shard_suites(paths, 2, weights)
        self.assertEqual(shards, V.shard_suites(paths, 2, weights))
        self.assertEqual(sorted(sum(shards, [])), sorted(paths))
        self.assertFalse(set(shards[0]) & set(shards[1]))
        self.assertLessEqual(abs(sum(weights[p] for p in shards[0]) - sum(weights[p] for p in shards[1])), 2)
        with self.assertRaises(ValueError):
            V.shard_suites(paths, 0, weights)

    def test_failed_suite_does_not_hide_later_results_and_receipt(self):
        (self.root / self.paths[0]).write_text('raise SystemExit(7)\n')
        loaded = self.load()
        receipt, code = V.execute(loaded, self.paths, self.root, 'test')
        self.assertEqual(code, 1)
        self.assertEqual([r['exit_code'] for r in receipt['results']], [7, 0])
        self.assertEqual([r['status'] for r in receipt['results']], ['failed', 'passed'])
        self.assertNotIn(str(self.root), json.dumps(receipt))

    def test_missing_runtime_is_failure_unless_profile_explicitly_optional(self):
        self.catalog['suites'][0].update(runtime='powershell', optional_in=['optional'])
        self.catalog['profiles']['optional'] = self.paths.copy()
        loaded = self.load()
        for profile, expected in [('test', 'failed'), ('optional', 'skipped')]:
            receipt, code = V.execute(loaded, self.paths[:1], self.root, profile, powershell='missing-pwsh-fixture')
            self.assertEqual(receipt['results'][0]['status'], expected)
            self.assertEqual(code, int(profile == 'test'))

    def test_receipt_written_atomically(self):
        path = self.root / 'receipt.json'
        V.write_receipt(path, {'results': []})
        self.assertEqual(json.loads(path.read_text()), {'results': []})
        self.assertEqual(list(self.root.glob('receipt.json.*')), [])

    def test_malformed_runtime_arguments_rejected(self):
        self.catalog['suites'][0]['args'] = '--not-an-array'
        with self.assertRaises(ValueError):
            self.load()

    def test_runtime_metadata_unavailable_does_not_hide_execution(self):
        loaded = self.load()
        with patch.object(V, 'repository_state', return_value=(None, None)):
            receipt, code = V.execute(loaded, self.paths, self.root, 'test')
        self.assertEqual(code, 0)
        self.assertIsNone(receipt['revision'])
        self.assertIsNone(receipt['clean_before'])
        self.assertFalse(receipt['reusable'])

    def test_worktree_changes_are_recorded_without_claiming_reusable_evidence(self):
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        subprocess.run(['git', '-C', str(self.root), 'add', '.'], check=True)
        subprocess.run(['git', '-C', str(self.root), '-c', 'user.name=Fixture', '-c',
                        'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture'], check=True)
        self.assertTrue(V.repository_state(self.root)[1])
        (self.root / self.paths[0]).write_text('print("changed")\n')
        receipt, code = V.execute(self.load(), self.paths, self.root, 'test')
        self.assertEqual(code, 0)
        self.assertFalse(receipt['clean_before'])
        self.assertFalse(receipt['clean_after'])
        self.assertEqual(receipt['revision'], receipt['revision_after'])

    @unittest.skipUnless(shutil.which('pwsh'), 'PowerShell is unavailable')
    def test_native_powershell_failure_and_fresh_process_are_preserved(self):
        paths = ['tests/native-a.tests.ps1', 'tests/native-b.tests.ps1']
        (self.root / paths[0]).write_text('$global:FixtureState = 1; exit 7\n')
        (self.root / paths[1]).write_text('if (Get-Variable FixtureState -ErrorAction SilentlyContinue) { exit 9 }; exit 0\n')
        self.catalog['suites'] += [{'path': p, 'runtime': 'powershell'} for p in paths]
        self.catalog['profiles']['native'] = paths
        receipt, code = V.execute(self.load(), paths, self.root, 'native')
        self.assertEqual(code, 1)
        self.assertEqual([r['exit_code'] for r in receipt['results']], [7, 0])

    def test_cli_direct_suite_and_receipt_are_bound_to_selection(self):
        receipt = self.root / 'actual-receipt.json'
        command = [sys.executable, str(ROOT / 'tests/verification.py'), '--suite',
                   'tests/verification-impact.tests.py', '--run', '--receipt', str(receipt)]
        completed = subprocess.run(command, text=True, capture_output=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        actual = json.loads(receipt.read_text())
        self.assertEqual(actual['selected'], ['tests/verification-impact.tests.py'])
        self.assertEqual([row['status'] for row in actual['results']], ['passed'])
        self.assertNotIn(str(ROOT), json.dumps(actual))
        self.assertFalse(actual['reusable'])

    def test_wrapper_actions_are_position_independent_and_shards_cover_profile(self):
        catalog = V.load_catalog(ROOT / 'tests/verification-catalog.json', ROOT)
        combined = []
        for index in range(4):
            result = subprocess.run(['bash', str(ROOT / 'tests/run-ci-unwired.sh'),
                                     '--shard-index', str(index), '--shard-count', '4', '--list'],
                                    text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            combined.extend(result.stdout.splitlines())
        self.assertEqual(len(combined), len(set(combined)))
        self.assertEqual(set(combined), set(catalog['profiles']['ci-posix-fallback']))
        result = subprocess.run(['bash', str(ROOT / 'tests/run-all.sh'), '--shard-count', '1', '--plan'],
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['selected'], catalog['profiles']['local-posix'])
        result = subprocess.run(['bash', str(ROOT / 'tests/run-ci-unwired.sh'), '--shard-index', '4',
                                 '--shard-count', '4', '--list'], text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)

    def test_planner_is_registered_and_live_categories_are_inactive(self):
        catalog = V.load_catalog(ROOT / 'tests/verification-catalog.json', ROOT)
        suite = 'tests/verification-ci-plan.tests.py'
        self.assertIn(suite, catalog['profiles']['local-posix'])
        self.assertIn(suite, catalog['profiles']['ci-posix-fallback'])
        self.assertTrue(catalog['impact']['categories'])
        for category in catalog['impact']['categories']:
            self.assertIs(category['active'], False)
            self.assertIsNone(category['evidence'])
        spec = importlib.util.spec_from_file_location('planner', ROOT / 'tests/verification-impact.py')
        assert spec and spec.loader
        planner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(planner)
        workflow = planner.read_workflow(ROOT / '.github/workflows/test.yml')
        planner.rules(catalog, workflow)

    def test_real_catalog_and_wrappers_list_exact_same_suites(self):
        catalog = V.load_catalog(ROOT / 'tests/verification-catalog.json', ROOT)
        result = subprocess.run(['bash', str(ROOT / 'tests/run-all.sh'), '--list'], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), catalog['profiles']['local-posix'])
        result = subprocess.run(['bash', str(ROOT / 'tests/run-ci-unwired.sh'), '--list'], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(set(result.stdout.splitlines()), set(catalog['profiles']['ci-posix-fallback']))



class WorkflowIntegrationTests(unittest.TestCase):
    w: Any
    ci: Any
    workflow: dict[str, Any]
    catalog: dict[str, Any]
    """T-003 workflow caller contracts; local checks are not hosted acceptance."""
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('t003_workflow', ROOT / 'tests/verification-workflow.py')
        assert spec and spec.loader
        cls.w = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.w)
        spec = importlib.util.spec_from_file_location('t003_ci', ROOT / 'tests/verification-ci.py')
        assert spec and spec.loader
        cls.ci = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.ci)
        cls.workflow = cls.w.load_workflow(ROOT / '.github/workflows/test.yml')
        cls.catalog = json.loads((ROOT / 'tests/verification-catalog.json').read_text())

    def test_T003_required_verifier_uses_accepted_prepared_shape(self):
        self.assertIs(self.w.verifier_job(self.workflow), True,
                      'workflow must use the accepted exact prepared verifier caller')
        self.assertEqual(len(self.w.control_dispositions(self.workflow, self.catalog)), 4)

    def test_T003_planner_outputs_have_one_declared_producer(self):
        jobs = self.workflow['jobs']
        self.assertTrue('ci-plan' in jobs, 'missing revision-bound planner job')
        job = jobs['ci-plan']
        groups = sorted(set(jobs) - {'required-checks'})
        expected = {'run_' + name.replace('-', '_'): '${{ steps.plan.outputs.run_' + name.replace('-', '_') + ' }}'
                    for name in groups}
        expected['plan_artifact_name'] = '${{ steps.plan.outputs.plan_artifact_name }}'
        self.assertEqual(job['outputs'], expected)
        self.assertEqual(job.get('permissions'), {'contents': 'read'})
        checkouts = [s['with'] for s in job['steps'] if s.get('uses', '').startswith('actions/checkout@')]
        self.assertIn({'ref': '${{ github.sha }}', 'path': 'subject', 'fetch-depth': 0,
                       'persist-credentials': False}, checkouts)
        self.assertTrue(any(c.get('path') == 'trusted' and c.get('ref') == '${{ github.event.pull_request.base.sha }}'
                            and c.get('persist-credentials') is False for c in checkouts))

    def test_T003_all_native_contexts_survive_failed_planner(self):
        job = self.workflow['jobs']['test']
        self.assertEqual(job.get('if'), 'always()')
        self.assertIn('ci-plan', job.get('needs', []))
        self.assertEqual(job['strategy']['matrix']['os'], ['windows-latest', 'macos-latest', 'ubuntu-latest'])
        self.assertNotIn('name', job)
        integrity = [s for s in job['steps'] if 'generate-guard-invariants.py --check' in s.get('run', '')]
        self.assertEqual(len(integrity), 2)
        self.assertTrue(all('needs.ci-plan' not in s.get('if', '') for s in integrity))
        self.assertFalse(job.get('continue-on-error', False))

    def test_T003_all_expanded_job_identities_are_unambiguous(self):
        try:
            jobs = self.ci.expanded_jobs(self.workflow)
        except ValueError as error:
            self.fail('actual collector cannot identify current matrix jobs: ' + str(error))
        self.assertEqual(len(jobs), sum(len(self.w.matrix_rows(j)) for key, j in self.workflow['jobs'].items()
                                        if key != 'required-checks'))
        for os_name in ('ubuntu-latest', 'macos-latest', 'windows-latest'):
            self.assertIn('test (' + os_name + ')', jobs)

    def test_T003_every_existing_runner_persists_a_receipt_and_uploads_it(self):
        obligations = self.w.plan_obligations(self.workflow, self.catalog)
        for obligation in (o for o in obligations if o['receipt_required']):
            with self.subTest(job=obligation['job'], matrix=obligation['matrix'], step=obligation['step']):
                job = self.workflow['jobs'][obligation['job']]
                step = next(s for s in job['steps'] if self.w.expand_matrix(s.get('name', ''), obligation['matrix']) == obligation['step'])
                self.assertIn('--receipt', step['run'], 'stdout-only runner receipt has no artifact producer')
                uploads = [s for s in job['steps'] if s.get('uses', '').startswith('actions/upload-artifact@')
                           and 'verification-receipts-' in s.get('with', {}).get('name', '')]
                self.assertEqual(len(uploads), 1, 'selected runner needs one source-attempt artifact')
                upload = uploads[0]
                runner = {'ubuntu-latest': 'Linux', 'macos-latest': 'macOS', 'windows-latest': 'Windows'}[obligation['runner']]
                outputs = {'run_' + key.replace('-', '_'): 'true' for key in self.workflow['jobs']}
                self.assertTrue(self.receipt_upload_enabled(upload, obligation['matrix'], runner, outputs))
                self.assertIn('github.run_id', upload['with']['name'])
                self.assertIn('github.run_attempt', upload['with']['name'])
                self.assertNotIn('overwrite', upload['with'])

    def receipt_upload_enabled(self, upload, matrix, runner, outputs):
        """Bounded Actions-condition fixture; always() preserves a prior failure's upload."""
        condition = upload.get('if', '').strip()
        if condition.startswith('${{') and condition.endswith('}}'):
            condition = condition[3:-2].strip()
        self.assertTrue(condition == 'always()' or condition.startswith('always() && '),
                        'receipt upload must survive producer failure, with no success()/file-existence escape')
        predicate = condition[len('always()'):].removeprefix(' && ')
        self.assertTrue(not predicate or self.w.condition_supported(predicate), 'unbounded upload predicate')
        return not predicate or self.w.enabled(predicate, matrix, runner, outputs=outputs)

    def receipt_upload_rows(self):
        obligations = self.w.plan_obligations(self.workflow, self.catalog)
        for job_id, job in self.workflow['jobs'].items():
            uploads = [step for step in job['steps'] if step.get('uses', '').startswith('actions/upload-artifact@')
                       and 'verification-receipts-' in step.get('with', {}).get('name', '')]
            if not uploads:
                continue
            self.assertEqual(len(uploads), 1)
            for matrix in self.w.matrix_rows(job):
                runner = {'ubuntu-latest': 'Linux', 'macos-latest': 'macOS', 'windows-latest': 'Windows'}[
                    self.w.expand_matrix(job['runs-on'], matrix)]
                names = {item['step'] for item in obligations if item['job'] == job_id
                         and item['matrix'] == matrix and item['receipt_required']}
                producers = [step for step in job['steps'] if self.w.expand_matrix(step.get('name', ''), matrix) in names]
                yield job_id, job, matrix, runner, producers, uploads[0]

    def assert_receipt_row_policy(self, row, selected, prior_failure, receipt_present):
        job_id, job, matrix, runner, producers, upload = row
        outputs = {} if selected is None else {'run_' + key.replace('-', '_'): selected for key in self.workflow['jobs']}
        job_runs = job.get('if') == 'always()' or self.w.enabled(job.get('if'), matrix, runner, outputs=outputs)
        required = job_runs and any(self.w.enabled(step.get('if'), matrix, runner, outputs=outputs) for step in producers)
        enabled = self.receipt_upload_enabled(upload, matrix, runner, outputs)
        # A predecessor assertion failure may suppress ordinary steps, but never this declared always() upload.
        actual = job_runs and enabled
        self.assertEqual(actual, required, (job_id, matrix, selected, prior_failure))
        self.assertEqual(upload['with'].get('if-no-files-found'), 'error', 'missing required receipts must fail')
        disposition = 'skip' if not actual else 'upload' if receipt_present else 'error'
        self.assertEqual(disposition, 'skip' if not required else 'upload' if receipt_present else 'error')
        return required

    def test_RT015_every_upload_row_matches_selected_receipt_producers(self):
        rows = list(self.receipt_upload_rows())
        self.assertEqual(len({row[0] for row in rows}), 6)
        self.assertEqual(len(rows), 16)
        self.assertEqual(sum(bool(row[4]) for row in rows), 14)
        for row in rows:
            for selected in ('true', 'false', None):
                for failed in (False, True):
                    for present in (False, True):
                        with self.subTest(job=row[0], matrix=row[2], selected=selected,
                                          prior_failure=failed, receipt_present=present):
                            self.assert_receipt_row_policy(row, selected, failed, present)

    def test_RT015_missing_required_receipt_and_hidden_upload_mutations_fail(self):
        import copy
        producer = next(row for row in self.receipt_upload_rows() if row[0] == 'test-windows-heavy' and row[2]['lane'] == 'gates')
        for mutation in ('ignore-missing', 'success-only', 'disabled', 'file-existence'):
            with self.subTest(mutation=mutation):
                row = copy.deepcopy(producer)
                if mutation == 'ignore-missing':
                    row[-1]['with']['if-no-files-found'] = 'ignore'
                else:
                    row[-1]['if'] = {'success-only': 'success()', 'disabled': 'always() && false',
                                     'file-existence': "always() && hashFiles('receipt.json') != ''"}[mutation]
                with self.assertRaises(AssertionError):
                    self.assert_receipt_row_policy(row, 'true', True, False)
        # Stale bytes never authorize upload in a row with no producer or no selected native producer.
        for source in (next(row for row in self.receipt_upload_rows() if row[0] == 'test-windows-heavy' and row[2]['lane'] == 'a9'),
                       next(row for row in self.receipt_upload_rows() if row[0] == 'test')):
            row = copy.deepcopy(source)
            row[-1]['if'] = 'always()'
            selected = 'true' if row[0] == 'test-windows-heavy' else 'false'
            with self.subTest(job=row[0]), self.assertRaises(AssertionError):
                self.assert_receipt_row_policy(row, selected, False, True)

    def test_T003_actual_receipt_identity_body_matches_collector(self):
        for display, expanded in self.ci.expanded_jobs(self.workflow).items():
            job = self.workflow['jobs'][expanded['job']]
            steps = [step for step in job['steps'] if step.get('id') == 'receipt-artifact']
            if not steps:
                continue
            with self.subTest(display=display), tempfile.TemporaryDirectory() as directory:
                step = steps[0]
                output = Path(directory) / 'output'
                env = dict(os.environ, GITHUB_OUTPUT=str(output),
                           RECEIPT_JOB_NAME=self.w.expand_matrix(step['env']['RECEIPT_JOB_NAME'], expanded['matrix']))
                self.assertEqual(env['RECEIPT_JOB_NAME'], display)
                result = subprocess.run(['bash', '-e', '-o', 'pipefail', '-c', step['run']],
                                        env=env, capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr)
                expected = self.ci.P.sha(self.ci.P.canonical({'name': display}))
                self.assertEqual(output.read_text(), 'job_key=' + expected + '\n')

    def test_T003_pr_number_cancellation_and_non_pr_run_groups(self):
        self.assertEqual(self.workflow['concurrency'], {
            'group': '${{ github.workflow }}-${{ github.event_name }}-${{ github.event.pull_request.number || github.run_id }}',
            'cancel-in-progress': "${{ github.event_name == 'pull_request' }}"})
        def group(event, pr, run):
            return ('workflow', event, pr if event == 'pull_request' else run)
        self.assertEqual(group('pull_request', 7, 1), group('pull_request', 7, 2))
        self.assertNotEqual(group('pull_request', 7, 1), group('pull_request', 8, 2))
        for event in ('push', 'merge_group', 'release', 'workflow_dispatch'):
            self.assertNotEqual(group(event, None, 1), group(event, None, 2))

    def test_T003_triggers_and_unproven_categories_remain_conservative(self):
        self.assertEqual(set(self.workflow['on']), {'push', 'pull_request', 'merge_group', 'workflow_dispatch'})
        for value in self.workflow['on'].values():
            if isinstance(value, dict):
                self.assertNotIn('paths', value)
                self.assertNotIn('paths-ignore', value)
        self.assertTrue(all(c['active'] is False and c['evidence'] is None
                            for c in self.catalog['impact']['categories']))
        projection = {key: self.workflow.get(key, {}) for key in ('env', 'defaults')}
        projection['jobs'] = {name: self.workflow['jobs'][name] for name in ('a9-advisory-inputs', 'a9-advisory')}
        self.assertEqual(self.ci.P.sha(self.ci.P.canonical(projection)), self.w.A9_ACTIVATION_PROJECTION)

    def test_T003_measured_cloud_partition_keeps_three_native_obligations(self):
        jobs = self.workflow['jobs']
        self.assertTrue('cloud-native' in jobs, 'measured long cloud work remains serialized in required wrappers')
        cloud = jobs['cloud-native']
        self.assertEqual(cloud['strategy']['matrix']['os'], ['windows-latest', 'macos-latest', 'ubuntu-latest'])
        self.assertIs(cloud['strategy']['fail-fast'], False)
        wanted = '[deterministic] Test cloud suites, installed packages and current multitarget boundaries'
        self.assertFalse(any(s.get('name') == wanted for s in jobs['test']['steps']))
        runs = [s for s in cloud['steps'] if s.get('name') == wanted]
        self.assertEqual(len(runs), 1)
        self.assertEqual(runs[0]['run'], 'python -B tests/verification.py --profile ci-cloud --run --receipt "${{ runner.temp }}/verification-cloud.json"')
        self.assertEqual(runs[0]['shell'], 'pwsh')
        self.assertEqual(runs[0]['env'], {'CLOUD_REQUIRE_NATIVE': "${{ runner.os == 'Linux' && '1' || '0' }}"})
        self.assertIn('cloud-native', jobs['required-checks']['needs'])

    def test_T003_exact_plan_conditions_are_supported(self):
        expression = "needs.ci-plan.outputs.run_cloud_native == 'true'"
        self.assertTrue(self.w.condition_supported(expression), 'bounded planner condition has no interpreter integration')
        for bad in (expression.replace('ci-plan', 'other'), expression.replace("'true'", "'True'"),
                    expression + ' || success()', expression.replace('==', '!=')):
            self.assertFalse(self.w.condition_supported(bad))

    def test_T003_full_and_affected_conditions_use_actual_output_values(self):
        condition = "needs.ci-plan.outputs.run_cloud_native == 'true' && runner.os != 'Windows'"
        for value, expected in [('true', True), ('false', False), ('True', False), ('', False)]:
            with self.subTest(value=value):
                self.assertEqual(self.w.enabled(condition, {}, 'Linux', outputs={'run_cloud_native': value}), expected)
        self.assertFalse(self.w.enabled(condition, {}, 'Windows', outputs={'run_cloud_native': 'true'}))
        self.assertFalse(self.w.enabled(condition, {}, 'Linux', outputs={}))

    def t003_before(self):
        return json.loads((ROOT / 'specs/ci-model-modernization/verification/T-003/integration-dependencies/before-inventory.json').read_text())

    def t003_inventory(self, workflow, obligations, historical):
        from collections import Counter
        import shlex
        result: Counter[Any] = Counter()
        for item in obligations:
            if not item['suites']:
                continue
            job = workflow['jobs'][item['job']]
            step = next(s for s in job['steps'] if self.w.expand_matrix(s.get('name', ''), item['matrix']) == item['step'])
            defaults = {**workflow.get('defaults', {}).get('run', {}), **job.get('defaults', {}).get('run', {})}
            shell = step.get('shell', defaults.get('shell', 'pwsh' if item['runner'] == 'windows-latest' else 'bash'))
            lines = []
            for line in self.w.expand_matrix(step['run'], item['matrix']).splitlines():
                if not line.strip() or line.lstrip().startswith('#'):
                    continue
                argv = shlex.split(line)
                if '--receipt' in argv:
                    index = argv.index('--receipt')
                    del argv[index:index + 2]
                lines.append(tuple(argv))
            # T-004: project onto historical suites only; an obligation carrying only new suites keeps an empty key.
            suites = tuple(s for s in item['suites'] if s in historical)
            result[(item['runner'], shell, suites, tuple(lines))] += 1
        return result

    def test_T003_full_suite_invocation_multiset_preserves_shell_args_and_os(self):
        before = self.t003_before()
        historical = {s for o in before['obligations'] for s in o['suites']}
        expected = self.t003_inventory(before['workflow'], before['obligations'], historical)
        actual = self.t003_inventory(self.workflow, self.w.plan_obligations(self.workflow, self.catalog), historical)
        self.assertEqual(actual, expected)

    def test_T003_suite_projection_rejects_original_obligation_mutations(self):
        import copy
        historical = {s for o in self.t003_before()['obligations'] for s in o['suites']}
        obligations = self.w.plan_obligations(self.workflow, self.catalog)
        baseline = self.t003_inventory(self.workflow, obligations, historical)
        index = next(i for i, o in enumerate(obligations)
                     if o['step'] == 'Test shared review launch and conditional input contracts')
        target = obligations[index]

        def step_of(workflow):
            return next(s for s in workflow['jobs'][target['job']]['steps']
                        if self.w.expand_matrix(s.get('name', ''), target['matrix']) == target['step'])

        def changed(mutate_obligations=None, mutate_workflow=None):
            workflow, items = copy.deepcopy(self.workflow), copy.deepcopy(obligations)
            if mutate_obligations:
                mutate_obligations(items)
            if mutate_workflow:
                mutate_workflow(step_of(workflow))
            return self.t003_inventory(workflow, items, historical)

        added = changed(lambda items: items[index]['suites'].append('tests/model-observation.tests.py'))
        self.assertEqual(added, baseline, 'appending a new suite to an existing obligation must project away')
        mutations = {
            'old-suite-removed': lambda items: items[index]['suites'].pop(0),
            'obligation-deleted': lambda items: items.pop(index),
            'obligation-duplicated': lambda items: items.append(copy.deepcopy(items[index])),
            'os-changed': lambda items: items[index].update(runner='macos-latest'),
            'new-only-obligation': lambda items: items.append({**copy.deepcopy(items[index]),
                                                               'suites': ['tests/model-observation.tests.py']}),
        }
        for name, mutate in mutations.items():
            with self.subTest(mutation=name):
                self.assertNotEqual(changed(mutate), baseline)
        for name, mutate_step in {'shell-changed': lambda step: step.update(shell='pwsh'),
                                  'argv-changed': lambda step: step.update(run=step['run'].rstrip() + ' --changed\n')}.items():
            with self.subTest(mutation=name):
                self.assertNotEqual(changed(mutate_workflow=mutate_step), baseline)

    MODEL_SUITE = 'tests/model-observation.tests.py'
    NATIVE_RUNNERS = ('ubuntu-latest', 'macos-latest', 'windows-latest')

    def model_suite_native_errors(self, obligations):
        from collections import Counter
        carriers = [o for o in obligations if self.MODEL_SUITE in o['suites']]
        errors = []
        if Counter(o['runner'] for o in carriers) != Counter(self.NATIVE_RUNNERS):
            errors.append('expected exactly one obligation per native OS: ' + repr(sorted(o['runner'] for o in carriers)))
        if not all(o['receipt_required'] for o in carriers):
            errors.append('every carrier must be a receipt-producing shared runner')
        return errors

    def test_T004_model_suite_registration_and_dependency(self):
        catalog = V.load_catalog(ROOT / 'tests/verification-catalog.json', ROOT)
        row = catalog['_suites'].get(self.MODEL_SUITE)
        self.assertIsNotNone(row, 'model observation suite is not registered')
        assert row is not None
        self.assertEqual({k: v for k, v in row.items() if k != 'ci_jobs'}, {'path': self.MODEL_SUITE, 'runtime': 'python'})
        self.assertIn('test', row.get('ci_jobs', []))
        for profile in ('local-posix', 'local-powershell'):
            self.assertEqual(catalog['profiles'][profile].count(self.MODEL_SUITE), 1, profile)
        self.assertNotIn(self.MODEL_SUITE, catalog['profiles']['ci-posix-fallback'])
        self.assertEqual(catalog['impact']['dependencies'].get(self.MODEL_SUITE), ['tests/verification-catalog.tests.py'])
        self.assertEqual([e for e in self.w.coverage_errors(self.workflow, catalog) if e.startswith(self.MODEL_SUITE)], [])

    def test_T004_model_suite_runs_once_on_each_native_os(self):
        self.assertEqual(self.model_suite_native_errors(self.w.plan_obligations(self.workflow, self.catalog)), [])

    def test_T004_native_coverage_mutations_fail(self):
        import copy
        base = [{'id': 'fixture-' + r, 'job': 'test', 'matrix': {'os': r}, 'runner': r, 'step': 'fixture',
                 'command_sha256': '0' * 64, 'suites': [self.MODEL_SUITE], 'receipt_required': True}
                for r in self.NATIVE_RUNNERS]
        self.assertEqual(self.model_suite_native_errors(base), [])
        mutations = []
        for index in range(len(base)):
            mutations.append([o for i, o in enumerate(base) if i != index])
            mutations.append(base + [copy.deepcopy(base[index])])
            moved = copy.deepcopy(base)
            moved[index]['runner'] = self.NATIVE_RUNNERS[index - 1]
            mutations.append(moved)
            dropped = copy.deepcopy(base)
            dropped[index]['suites'] = []
            mutations.append(dropped)
            unshared = copy.deepcopy(base)
            unshared[index]['receipt_required'] = False
            mutations.append(unshared)
        for number, mutated in enumerate(mutations):
            with self.subTest(mutation=number):
                self.assertNotEqual(self.model_suite_native_errors(mutated), [])

    def test_T003_unknown_plan_group_and_output_declarations_fail_closed(self):
        import copy
        workflow: dict[str, Any] = {'jobs': {
            'ci-plan': {'runs-on': 'ubuntu-latest', 'outputs': {'run_work': '${{ steps.plan.outputs.run_work }}'},
                        'steps': [{'name': 'plan', 'run': 'echo plan'}]},
            'work': {'runs-on': 'ubuntu-latest', 'if': "needs.ci-plan.outputs.run_missing == 'true'",
                     'steps': [{'name': 'sample', 'run': 'python3 tests/sample.tests.py'}]}}}
        catalog = {'suites': [{'path': 'tests/sample.tests.py', 'runtime': 'python', 'ci_jobs': ['work']}], 'profiles': {}}
        self.assertTrue(self.w.coverage_errors(workflow, catalog))
        workflow['jobs']['work']['if'] = "needs.ci-plan.outputs.run_work == 'true'"
        workflow['jobs']['ci-plan']['outputs']['run_ci_plan'] = '${{ steps.plan.outputs.run_ci_plan }}'
        self.assertEqual(self.w.coverage_errors(workflow, catalog), [], 'declared true group should prove full coverage')
        for mutation in ('wrong-producer', 'missing-output', 'wrong-case', 'group-collision', 'extra-output'):
            with self.subTest(mutation=mutation):
                bad = copy.deepcopy(workflow)
                if mutation == 'wrong-producer':
                    bad['jobs']['work']['if'] = bad['jobs']['work']['if'].replace('ci-plan', 'unrelated')
                elif mutation == 'missing-output':
                    del bad['jobs']['ci-plan']['outputs']['run_work']
                elif mutation == 'wrong-case':
                    bad['jobs']['ci-plan']['outputs']['run_work'] = '${{ steps.plan.outputs.run_Work }}'
                elif mutation == 'extra-output':
                    bad['jobs']['ci-plan']['outputs']['run_undeclared'] = '${{ steps.plan.outputs.run_undeclared }}'
                else:
                    bad['jobs']['work-extra'] = copy.deepcopy(bad['jobs']['work'])
                    bad['jobs']['work_extra'] = copy.deepcopy(bad['jobs']['work'])
                    bad['jobs']['ci-plan']['outputs']['run_work_extra'] = '${{ steps.plan.outputs.run_work_extra }}'
                self.assertTrue(self.w.coverage_errors(bad, catalog))

    def test_RT015_actual_workflow_metadata_condition_admits_full_planning(self):
        outputs = self.w.planner_outputs(self.workflow)
        self.assertEqual(outputs['run_test'], 'true')
        self.assertEqual(self.w.coverage_errors(self.workflow, self.catalog), [])

    def metadata_upload_fixture(self):
        expression = "always() && needs.ci-plan.outputs.run_work == 'true'"
        workflow = {'jobs': {
            'ci-plan': {'runs-on': 'ubuntu-latest', 'outputs': {
                'run_ci_plan': '${{ steps.plan.outputs.run_ci_plan }}',
                'run_work': '${{ steps.plan.outputs.run_work }}'},
                'steps': [{'name': 'plan', 'run': 'echo plan'}]},
            'work': {'runs-on': 'ubuntu-latest', 'steps': [
                {'name': 'assertions', 'run': 'python3 tests/sample.tests.py'},
                {'name': 'metadata', 'if': expression,
                 'uses': 'actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9',
                 'with': {'name': 'verification-receipts-fixture', 'path': 'receipt.json',
                          'if-no-files-found': 'error'}}]}}}
        catalog = {'suites': [{'path': 'tests/sample.tests.py', 'runtime': 'python', 'ci_jobs': ['work']}],
                   'profiles': {}}
        return workflow, catalog

    def test_RT015_pinned_uses_only_metadata_condition_preserves_workload_grammar(self):
        import copy
        workflow, catalog = self.metadata_upload_fixture()
        metadata = workflow['jobs']['work']['steps'][1]
        expression = metadata['if']
        self.assertFalse(self.w.condition_supported(expression))
        self.assertFalse(self.w.enabled(expression, {}, 'Linux', {'run_work': 'true'}))
        before = copy.deepcopy(workflow)
        del before['jobs']['work']['steps'][1]
        for condition in (expression, '${{ ' + expression + ' }}'):
            with self.subTest(condition=condition):
                metadata['if'] = condition
                self.assertEqual(self.w.planner_outputs(workflow), {'run_ci_plan': 'true', 'run_work': 'true'})
                self.assertEqual(self.w.coverage_errors(workflow, catalog), [])
                self.assertEqual(self.w.workflow_coverage(workflow, catalog), self.w.workflow_coverage(before, catalog))
                self.assertEqual(self.w.plan_obligations(workflow, catalog), self.w.plan_obligations(before, catalog))

    def test_RT015_metadata_normalization_rejects_workload_and_condition_mutations(self):
        import copy
        workflow, catalog = self.metadata_upload_fixture()
        expression = workflow['jobs']['work']['steps'][1]['if']
        mutations = ('run-step', 'uses-plus-run', 'job-condition', 'unknown-output', 'or-true',
                     'disabled-guard', 'success-guard', 'double-plan', 'matrix-guard', 'wrong-case',
                     'unpinned-action', 'different-action', 'different-pin', 'missing-action',
                     'undeclared-output', 'group-collision')
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                bad = copy.deepcopy(workflow)
                job = bad['jobs']['work']
                step = job['steps'][1]
                if mutation == 'run-step':
                    step.pop('uses')
                    step['run'] = 'echo hidden workload'
                elif mutation == 'uses-plus-run':
                    step['run'] = 'echo hidden workload'
                elif mutation == 'job-condition':
                    job['if'] = expression
                    step['if'] = 'always()'
                elif mutation == 'unknown-output':
                    step['if'] = expression.replace('run_work', 'run_unknown')
                elif mutation == 'or-true':
                    step['if'] += ' || true'
                elif mutation == 'disabled-guard':
                    step['if'] += ' && false'
                elif mutation == 'success-guard':
                    step['if'] = expression.replace('always()', 'success()')
                elif mutation == 'double-plan':
                    step['if'] += " && needs.ci-plan.outputs.run_ci_plan == 'true'"
                elif mutation == 'matrix-guard':
                    step['if'] += " && matrix.lane == 'gates'"
                elif mutation == 'wrong-case':
                    step['if'] = expression.replace("'true'", "'True'")
                elif mutation == 'unpinned-action':
                    step['uses'] = 'actions/upload-artifact@v4'
                elif mutation == 'different-action':
                    step['uses'] = 'actions/download-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9'
                elif mutation == 'different-pin':
                    step['uses'] = 'actions/upload-artifact@' + '0' * 40
                elif mutation == 'missing-action':
                    step.pop('uses')
                elif mutation == 'undeclared-output':
                    del bad['jobs']['ci-plan']['outputs']['run_work']
                else:
                    bad['jobs']['work-extra'] = copy.deepcopy(job)
                    bad['jobs']['work_extra'] = copy.deepcopy(job)
                with self.assertRaises(ValueError):
                    self.w.planner_outputs(bad)
                self.assertTrue(self.w.coverage_errors(bad, catalog))
        self.assertFalse(self.w.condition_supported(expression), 'generic workload grammar must remain protected')

    def test_T003_dependency_cache_is_archive_only_pinned_and_event_scoped(self):
        caches = [s for j in self.workflow['jobs'].values() for s in j['steps']
                  if s.get('uses', '').startswith('actions/cache@')]
        self.assertTrue(caches, 'no explicit dependency archive cache with event trust separation')
        for cache in caches:
            self.assertEqual(cache['uses'], 'actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9')
            key = cache['with']['key']
            self.assertIn('runner.os', key)
            self.assertIn('github.event_name', key)
            self.assertIn('github.event.pull_request.number', key)
            self.assertNotIn('restore-keys', cache['with'], 'broad restore fallback crosses exact dependency identities')
            if 'pester' in key.lower():
                self.assertIn('4.10.1', key)
                self.assertIn('898210e1a30c52cd46ba317c2278a9324345214213aa2f7d6b7dfa7b98f37ac9', key)
                self.assertRegex(key.lower(), r'(pwsh|powershell)')
                self.assertIn('steps.pester-runtime.outputs.version', key)
                self.assertEqual(cache['with']['path'], '${{ runner.temp }}/pester-package-cache/*.nupkg')
            else:
                self.assertIn('hashFiles(', key)
                self.assertIn('package-lock.json', key)
                self.assertRegex(key.lower(), r'node[-_]?22')
                self.assertIn('steps.node-runtime.outputs.version', key)
                self.assertEqual(cache['with']['path'], '${{ runner.temp }}/npm-cache/_cacache')
            paths = cache['with']['path']
            self.assertNotIn('node_modules', paths)
            self.assertNotIn('verification-', paths)
            self.assertNotIn('.git', paths)
            self.assertNotIn('secrets', paths)
        pester = [s for j in self.workflow['jobs'].values() for s in j['steps']
                  if 'ci-dependency-cache.py pester' in s.get('run', '')]
        self.assertTrue(pester, 'Pester reuse lacks pinned archive integrity validation')
        self.assertTrue(all(s.get('if') is None or 'cache-hit' not in s['if'] for s in pester))

    def test_T003_cache_policy_mutations_reject_evidence_and_cross_event_writes(self):
        import copy
        original = self.workflow
        try:
            for mutation in ('source', 'verdict', 'credentials', 'restore-fallback', 'os', 'runtime', 'lock', 'event', 'pr'):
                with self.subTest(mutation=mutation):
                    self.workflow = copy.deepcopy(original)
                    cache = next(step for step in self.workflow['jobs']['mcp-tests']['steps']
                                 if step.get('uses', '').startswith('actions/cache@'))['with']
                    if mutation in ('source', 'verdict', 'credentials'):
                        cache['path'] = {'source': '${{ github.workspace }}', 'verdict': '${{ runner.temp }}/verification-result.json',
                                         'credentials': '~/.ssh'}[mutation]
                    elif mutation == 'restore-fallback':
                        cache['restore-keys'] = 'npm-trusted-'
                    else:
                        token = {'os': 'runner.os', 'runtime': 'steps.node-runtime.outputs.version',
                                 'lock': 'package-lock.json', 'event': 'github.event_name',
                                 'pr': 'github.event.pull_request.number'}[mutation]
                        cache['key'] = cache['key'].replace(token, 'shared')
                    with self.assertRaises(AssertionError):
                        self.test_T003_dependency_cache_is_archive_only_pinned_and_event_scoped()
        finally:
            self.workflow = original

    NPM_CACHE_BIND_STEP = 'Bind npm cache to actual Node runtime'
    NPM_CACHE_BINDING = 'printf \'npm_config_cache=%s\\n\' "$RUNNER_TEMP/npm-cache" >> "$GITHUB_ENV"'
    MCP_NPM_JOBS = ('mcp-tests', 'local-env-mcp-tests', 'ci-mcp-tests')

    def npm_cache_binding_errors(self, job):
        errors = []
        if any('runner.' in str(value) for value in job.get('env', {}).values()):
            errors.append('job env must not use the runner context')
        steps = job['steps']
        indexes = {
            'bind': [i for i, s in enumerate(steps) if s.get('name') == self.NPM_CACHE_BIND_STEP],
            'cache': [i for i, s in enumerate(steps) if s.get('uses', '').startswith('actions/cache@')],
            'install': [i for i, s in enumerate(steps) if 'npm ci' in s.get('run', '')],
        }
        if any(len(found) != 1 for found in indexes.values()):
            return errors + ['expected exactly one bind, cache and npm install step: ' + repr(indexes)]
        bind, cache, install = (indexes[name][0] for name in ('bind', 'cache', 'install'))
        if self.NPM_CACHE_BINDING not in steps[bind].get('run', '').splitlines():
            errors.append('bind step must export the actual npm cache directory to GITHUB_ENV')
        if not bind < cache < install:
            errors.append('binding must run before actions/cache and npm install')
        if steps[cache]['with']['path'] != '${{ runner.temp }}/npm-cache/_cacache':
            errors.append('cache must consume the bound npm cache directory')
        return errors

    def test_T003_npm_cache_directory_binds_at_runtime_before_cache_and_install(self):
        import copy
        for name in self.MCP_NPM_JOBS:
            with self.subTest(job=name):
                self.assertEqual(self.npm_cache_binding_errors(self.workflow['jobs'][name]), [])

        def move_bind_after(job, kind):
            steps = job['steps']
            bind = next(s for s in steps if s.get('name') == self.NPM_CACHE_BIND_STEP)
            steps.remove(bind)
            if kind == 'cache':
                target = next(i for i, s in enumerate(steps) if s.get('uses', '').startswith('actions/cache@'))
            else:
                target = next(i for i, s in enumerate(steps) if 'npm ci' in s.get('run', ''))
            steps.insert(target + 1, bind)

        def edit_bind_run(job, old, new):
            bind = next(s for s in job['steps'] if s.get('name') == self.NPM_CACHE_BIND_STEP)
            bind['run'] = bind['run'].replace(old, new)

        mutations: dict[str, Callable[..., Any]] = {
            'job-env-runner-context': lambda j: j.setdefault('env', {}).update(
                npm_config_cache='${{ runner.temp }}/npm-cache'),
            'missing-binding': lambda j: edit_bind_run(j, self.NPM_CACHE_BINDING, ':'),
            'mismatched-binding': lambda j: edit_bind_run(j, '/npm-cache"', '/other-cache"'),
            'late-binding-after-cache': lambda j: move_bind_after(j, 'cache'),
            'late-binding-after-install': lambda j: move_bind_after(j, 'install'),
            'cache-path-changed': lambda j: next(
                s for s in j['steps'] if s.get('uses', '').startswith('actions/cache@'))['with'].update(
                    path='${{ runner.temp }}/other-cache/_cacache'),
        }
        for name in self.MCP_NPM_JOBS:
            for mutation, mutate in mutations.items():
                with self.subTest(job=name, mutation=mutation):
                    bad = copy.deepcopy(self.workflow['jobs'][name])
                    mutate(bad)
                    self.assertNotEqual(self.npm_cache_binding_errors(bad), [])

    # T-005 identity suite: additive registration/native-obligation checks; the T-004 checks above stay unchanged.
    IDENTITY_SUITE = 'tests/model-identity.tests.py'
    IDENTITY_PROFILES = ('local-posix', 'local-powershell', 'ci-portable-prechecks')
    IDENTITY_EXCLUDED_PROFILES = ('ci-posix-fallback', 'ci-shared-python')
    IDENTITY_DEPENDENCIES = ('tests/model-observation.tests.py', 'tests/verification-catalog.tests.py')

    def identity_registration_errors(self, catalog):
        """Raw-catalog counterparts for the identity suite row, profiles and impact dependencies."""
        errors = []
        rows = [s for s in catalog['suites'] if s.get('path') == self.IDENTITY_SUITE]
        if len(rows) != 1:
            errors.append('identity suite must be registered exactly once, found %d' % len(rows))
        for row in rows:
            if {k: v for k, v in row.items() if k != 'ci_jobs'} != {'path': self.IDENTITY_SUITE, 'runtime': 'python'}:
                errors.append('identity suite must be a plain python runner row: ' + repr(row))
            jobs = row.get('ci_jobs')
            if not isinstance(jobs, list) or sorted(jobs) != ['test', 'test-windows-heavy']:
                errors.append('identity ci_jobs must be exactly test and test-windows-heavy: ' + repr(jobs))
        for profile in self.IDENTITY_PROFILES:
            count = catalog['profiles'].get(profile, []).count(self.IDENTITY_SUITE)
            if count != 1:
                errors.append('%s must list the identity suite exactly once, found %d' % (profile, count))
        for profile in self.IDENTITY_EXCLUDED_PROFILES:
            if self.IDENTITY_SUITE in catalog['profiles'].get(profile, []):
                errors.append(profile + ' must not carry the identity suite')
        deps = catalog.get('impact', {}).get('dependencies', {}).get(self.IDENTITY_SUITE)
        if (not isinstance(deps, list) or len(deps) != len(set(deps))
                or set(deps) != set(self.IDENTITY_DEPENDENCIES)):
            errors.append('identity dependencies must be exactly observation and catalog tests: ' + repr(deps))
        return errors

    def suite_native_errors(self, obligations, suite):
        from collections import Counter
        carriers = [o for o in obligations if suite in o['suites']]
        errors = []
        if Counter(o['runner'] for o in carriers) != Counter(self.NATIVE_RUNNERS):
            errors.append('expected exactly one obligation per native OS: ' + repr(sorted(o['runner'] for o in carriers)))
        if not all(o['receipt_required'] for o in carriers):
            errors.append('every carrier must be a receipt-producing shared runner')
        return errors

    def test_T005_catalog_counterparts(self):
        import copy
        catalog = V.load_catalog(ROOT / 'tests/verification-catalog.json', ROOT)
        self.assertIn(self.IDENTITY_SUITE, catalog['_suites'], 'model identity suite is not registered')
        self.assertEqual(self.identity_registration_errors(self.catalog), [])
        self.assertEqual([e for e in self.w.coverage_errors(self.workflow, catalog) if e.startswith(self.IDENTITY_SUITE)], [])
        self.assertEqual(catalog['impact']['dependencies'].get(self.MODEL_SUITE), ['tests/verification-catalog.tests.py'])

        def row(data):
            return next(s for s in data['suites'] if s['path'] == self.IDENTITY_SUITE)

        mutations: dict[str, Callable[..., Any]] = {
            'unregistered': lambda c: c['suites'].remove(row(c)),
            'duplicate-row': lambda c: c['suites'].append(copy.deepcopy(row(c))),
            'runtime': lambda c: row(c).update(runtime='bash'),
            'delegated': lambda c: row(c).update(delegated_to=self.MODEL_SUITE),
            'excluded': lambda c: row(c).update(excluded='fixture'),
            'extra-ci-job': lambda c: row(c)['ci_jobs'].append('posix-regression'),
            'dependencies-missing': lambda c: c['impact']['dependencies'].pop(self.IDENTITY_SUITE),
            'dependency-duplicated': lambda c: c['impact']['dependencies'][self.IDENTITY_SUITE].append(
                c['impact']['dependencies'][self.IDENTITY_SUITE][0]),
            'dependency-extra': lambda c: c['impact']['dependencies'][self.IDENTITY_SUITE].append(
                'tests/verification-ci.tests.py'),
        }
        for job in ('test', 'test-windows-heavy'):
            mutations['drop-ci-job-' + job] = lambda c, job=job: row(c)['ci_jobs'].remove(job)
        for dependency in self.IDENTITY_DEPENDENCIES:
            mutations['drop-dependency-' + dependency] = (
                lambda c, dependency=dependency: c['impact']['dependencies'][self.IDENTITY_SUITE].remove(dependency))
        for profile in self.IDENTITY_PROFILES:
            mutations['remove-from-' + profile] = lambda c, profile=profile: c['profiles'][profile].remove(self.IDENTITY_SUITE)
            mutations['duplicate-in-' + profile] = lambda c, profile=profile: c['profiles'][profile].append(self.IDENTITY_SUITE)
        for profile in self.IDENTITY_EXCLUDED_PROFILES:
            mutations['added-to-' + profile] = lambda c, profile=profile: c['profiles'][profile].append(self.IDENTITY_SUITE)
        for name, mutate in mutations.items():
            with self.subTest(mutation=name):
                bad = copy.deepcopy(self.catalog)
                mutate(bad)
                self.assertNotEqual(self.identity_registration_errors(bad), [])

    def test_T005_identity_suite_runs_once_on_each_native_os(self):
        obligations = self.w.plan_obligations(self.workflow, self.catalog)
        self.assertEqual(self.suite_native_errors(obligations, self.IDENTITY_SUITE), [])
        self.assertEqual(self.model_suite_native_errors(obligations), [], 'T-004 observation carriers must remain intact')

    def test_T005_native_coverage_mutations(self):
        import copy
        base = [{'id': 'fixture-' + r, 'job': 'test', 'matrix': {'os': r}, 'runner': r, 'step': 'fixture',
                 'command_sha256': '0' * 64, 'suites': [self.IDENTITY_SUITE], 'receipt_required': True}
                for r in self.NATIVE_RUNNERS]
        self.assertEqual(self.suite_native_errors(base, self.IDENTITY_SUITE), [])
        mutations = {}
        for index, runner in enumerate(self.NATIVE_RUNNERS):
            mutations['missing-' + runner] = [o for i, o in enumerate(base) if i != index]
            mutations['duplicate-' + runner] = base + [copy.deepcopy(base[index])]
            moved = copy.deepcopy(base)
            moved[index]['runner'] = self.NATIVE_RUNNERS[index - 1]
            mutations['wrong-os-' + runner] = moved
            dropped = copy.deepcopy(base)
            dropped[index]['suites'] = [self.MODEL_SUITE]
            mutations['dropped-suite-' + runner] = dropped
            unreceipted = copy.deepcopy(base)
            unreceipted[index]['receipt_required'] = False
            mutations['receipt-disabled-' + runner] = unreceipted
        for name, mutated in mutations.items():
            with self.subTest(mutation=name):
                self.assertNotEqual(self.suite_native_errors(mutated, self.IDENTITY_SUITE), [])
        actual = self.w.plan_obligations(self.workflow, self.catalog)
        self.assertEqual(self.suite_native_errors(actual, self.IDENTITY_SUITE), [])
        bad = copy.deepcopy(self.catalog)
        bad['profiles']['ci-portable-prechecks'].remove(self.IDENTITY_SUITE)
        try:
            errors = self.suite_native_errors(self.w.plan_obligations(self.workflow, bad), self.IDENTITY_SUITE)
        except ValueError as error:
            errors = [str(error)]
        self.assertNotEqual(errors, [], 'dropping the portable carrier must lose native identity coverage')

    def test_T005_identity_registration_projects_away_from_historical_inventory(self):
        import copy
        historical = {s for o in self.t003_before()['obligations'] for s in o['suites']}
        self.assertNotIn(self.IDENTITY_SUITE, historical)
        obligations = self.w.plan_obligations(self.workflow, self.catalog)
        baseline = self.t003_inventory(self.workflow, obligations, historical)
        carriers = [o for o in obligations if self.IDENTITY_SUITE in o['suites']]
        self.assertEqual(len(carriers), len(self.NATIVE_RUNNERS))
        stripped = copy.deepcopy(obligations)
        for item in stripped:
            item['suites'] = [s for s in item['suites'] if s != self.IDENTITY_SUITE]
        self.assertEqual(self.t003_inventory(self.workflow, stripped, historical), baseline,
                         'identity registration must not alter historical invocations')
        extra = copy.deepcopy(obligations) + [{**copy.deepcopy(carriers[0]), 'suites': [self.IDENTITY_SUITE]}]
        self.assertNotEqual(self.t003_inventory(self.workflow, extra, historical), baseline,
                            'a new identity-only obligation must remain visible to the projection')


if __name__ == '__main__':
    unittest.main()
