#!/usr/bin/env python3
"""Revision-bound planning fixtures; none are hosted execution evidence."""
import copy
import hashlib
import importlib.util
import io
import inspect
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from typing import Any

ROOT = Path(__file__).resolve().parents[1]


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tests' / filename)
    assert spec and spec.loader
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


IMPACT = module('impact', 'verification-impact.py')
W = module('workflow', 'verification-workflow.py')


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'),
                                     ensure_ascii=False, allow_nan=False).encode()).hexdigest()


def sample_plan():
    return dict(schema='verification-ci-plan/v1', mode='full', reason='event-full',
                event='push', run_id='123', planning_attempt=1, api_head_sha='a' * 40,
                tested_revision='b' * 40, base_revision=None, pr_head_revision=None,
                merge_base_revision=None, catalog_sha256='c' * 64, workflow_sha256='d' * 64,
                trusted_planner_sha256='e' * 64, changed_path_count=None, groups=['test'],
                obligations=[dict(id='test:fixture', job='test', matrix={'os': 'ubuntu-latest'},
                                  runner='ubuntu-latest', step='fixture', command_sha256='f' * 64,
                                  suites=['tests/a.tests.py'], receipt_required=False)],
                omissions=[], activation_evidence=[])


class WireTests(unittest.TestCase):
    def test_deep_json_is_a_typed_input_failure_without_flat_or_integer_limits(self):
        good = {'flat': list(range(3001)), 'seconds': 10 ** 400}
        self.assertEqual(IMPACT.strict_json(IMPACT.canonical(good)), good)
        raw = b'{"nested":' + b'[' * 10000 + b'0' + b']' * 10000 + b'}'
        self.assertLess(len(raw), 32 * 1024 * 1024)
        for payload in (raw, raw.decode('utf-8')):
            with self.subTest(input_type=type(payload).__name__), self.assertRaises(ValueError):
                IMPACT.strict_json(payload)
        self.assertEqual(IMPACT.strict_json(b'{"valid":true}'), {'valid': True})

    def signed(self, plan):
        plan = copy.deepcopy(plan)
        plan['plan_sha256'] = digest({k: v for k, v in plan.items() if k != 'plan_sha256'})
        return plan

    def test_every_persisted_field_matches_independent_counterpart(self):
        expected = self.signed(sample_plan())
        IMPACT.validate_plan(expected, expected=expected)
        changes = dict(schema='verification-ci-plan/v2', mode='affected', reason='force-full',
                       event='release', run_id='124', planning_attempt=2,
                       api_head_sha='c' * 40, tested_revision='d' * 40,
                       base_revision='e' * 40, pr_head_revision='f' * 40,
                       merge_base_revision='0' * 40, catalog_sha256='1' * 64,
                       workflow_sha256='2' * 64, trusted_planner_sha256=None,
                       changed_path_count=1, groups=['other'], obligations=[],
                       omissions=[{'id': 'unexpected', 'reason': 'unrelated'}],
                       activation_evidence=[dict(category='docs', path='proof.json',
                                                sha256='3' * 64, rule_sha256='4' * 64,
                                                baseline_revision='5' * 40)])
        self.assertEqual(set(changes), set(expected) - {'plan_sha256'})
        for field, value in changes.items():
            with self.subTest(field=field):
                bad = self.signed({**expected, field: value})
                with self.assertRaises(ValueError):
                    IMPACT.validate_plan(bad, expected=expected)
        with self.assertRaises(ValueError):
            IMPACT.validate_plan({**expected, 'plan_sha256': '0' * 64}, expected=expected)

    def test_every_obligation_field_mismatch_and_guard_sensitivity(self):
        expected = self.signed(sample_plan())
        changes = dict(id='other', job='other', matrix={'os': 'macos-latest'},
                       runner='macos-latest', step='other', command_sha256='0' * 64,
                       suites=['tests/b.tests.py'], receipt_required=True)
        for field, value in changes.items():
            with self.subTest(field=field):
                bad = copy.deepcopy(expected)
                bad['obligations'][0][field] = value
                bad = self.signed(bad)
                IMPACT.validate_plan(expected, expected=expected)
                with self.assertRaises(ValueError):
                    IMPACT.validate_plan(bad, expected=expected)
        # Sensitivity: replacing the boundary with a no-op really loses rejection.
        with patch.object(IMPACT, 'validate_plan', return_value=None):
            with self.assertRaises(AssertionError):
                with self.assertRaises(ValueError):
                    IMPACT.validate_plan(bad, expected=expected)

    def test_omission_and_activation_field_pairs(self):
        expected = sample_plan()
        expected.update(mode='affected', reason='classified-change', event='pull_request',
                        base_revision='1' * 40, pr_head_revision='a' * 40,
                        merge_base_revision='1' * 40, changed_path_count=1,
                        omissions=[{'id': 'optional:build', 'reason': 'unrelated-category'}],
                        activation_evidence=[dict(category='guide', path='proof.json',
                                                  sha256='2' * 64, rule_sha256='3' * 64,
                                                  baseline_revision='4' * 40)])
        expected = self.signed(expected)
        IMPACT.validate_plan(expected, expected=expected)
        for container, field, value in (
            ('omissions', 'id', 'other'), ('omissions', 'reason', ''),
            ('activation_evidence', 'category', 'other'),
            ('activation_evidence', 'path', '../escape'),
            ('activation_evidence', 'sha256', '5' * 64),
            ('activation_evidence', 'rule_sha256', '6' * 64),
            ('activation_evidence', 'baseline_revision', '7' * 40),
        ):
            with self.subTest(container=container, field=field):
                bad = copy.deepcopy(expected)
                bad[container][0][field] = value
                with self.assertRaises(ValueError):
                    IMPACT.validate_plan(self.signed(bad), expected=expected)
        for field in ('omissions', 'activation_evidence'):
            bad = copy.deepcopy(expected)
            bad[field].append(bad[field][0])
            with self.assertRaises(ValueError):
                IMPACT.validate_plan(self.signed(bad))

    def test_affected_reason_rejected_without_expected_counterpart(self):
        plan = sample_plan()
        plan.update(mode='affected', reason='classified-change', event='pull_request',
                    base_revision='1' * 40, pr_head_revision='a' * 40,
                    merge_base_revision='1' * 40, changed_path_count=1,
                    activation_evidence=[dict(category='guide', path='proof.json',
                                              sha256='2' * 64, rule_sha256='3' * 64,
                                              baseline_revision='4' * 40)])
        IMPACT.validate_plan(self.signed(plan))
        for reason in ('force-full', 'event-full', 'diff-unavailable',
                       'base-planner-unavailable', 'binding-invalid', 'unknown-path',
                       'shared-change', 'unproven-category', 'input-invalid'):
            with self.subTest(reason=reason), self.assertRaises(ValueError):
                IMPACT.validate_plan(self.signed({**plan, 'reason': reason}))

    def test_fixed_condition_outputs_and_collision_rejection(self):
        plan = self.signed(sample_plan())
        self.assertEqual(IMPACT.condition_outputs(plan, ['test', 'optional-group']),
                         {'run_test': 'true', 'run_optional_group': 'false'})
        for groups in (['test', 'test'], ['test', 'bad\nkey'], ['test', 'a-b', 'a_b']):
            with self.assertRaises(ValueError):
                IMPACT.condition_outputs(plan, groups)

    def test_strict_json_schema_and_duplicate_unsafe_inputs(self):
        good = self.signed(sample_plan())
        IMPACT.validate_plan(good)
        for text in ('{"x":1,"x":2}', '{"x":NaN}', '{"x":Infinity}', '[]', '{} {}'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                IMPACT.strict_json(text)
        for mutate in (
            lambda p: p.update(extra=True),
            lambda p: p.update(planning_attempt=True),
            lambda p: p.update(run_id='0'),
            lambda p: p['obligations'].append(p['obligations'][0]),
            lambda p: p['obligations'][0].update(suites=['../escape']),
            lambda p: p['obligations'][0].update(suites=['/absolute']),
            lambda p: p['obligations'][0].update(suites=['tests//a.tests.py']),
            lambda p: p['obligations'][0].update(suites=['tests/a.tests.py'] * 2),
            lambda p: p.update(groups=['test', 'test']),
            lambda p: p.update(omissions=[{'id': 'test:fixture', 'reason': ''}]),
        ):
            bad = copy.deepcopy(good)
            mutate(bad)
            with self.assertRaises(ValueError):
                IMPACT.validate_plan(self.signed(bad))
        schema = json.loads((ROOT / 'contracts/verification-ci-plan.schema.json').read_text())
        self.assertEqual(set(schema['required']), set(good))
        self.assertIs(schema['additionalProperties'], False)


class GitFixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'subject'
        self.root.mkdir()
        self.trusted = Path(self.temp.name) / 'trusted'
        self.git('init', '-q')
        self.git('config', 'user.name', 'Fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.suites = ['tests/a.tests.py', 'tests/b.tests.py', 'tests/c.tests.py', 'tests/d.tests.py']
        for path in self.suites:
            self.write(path, 'print("fixture")\n')
        self.catalog: dict[str, Any] = dict(schema='verification-catalog/v1',
                            suites=[dict(path=p, runtime='python') for p in self.suites],
                            profiles={'fixture': self.suites},
                            impact=dict(schema='verification-impact-rules/v1', categories=[],
                                        dependencies={self.suites[0]: [self.suites[1]],
                                                      self.suites[2]: [self.suites[3]]}))
        self.workflow: dict[str, Any] = {'jobs': {
            'test': {'runs-on': 'ubuntu-latest', 'steps': [
                {'name': 'a', 'run': 'python3 tests/a.tests.py'},
                {'name': 'bc', 'run': 'python3 tests/b.tests.py\npython3 tests/c.tests.py'},
                {'name': 'd', 'run': 'python3 tests/d.tests.py'},
                {'name': 'integrity', 'run': 'git diff --exit-code'}]},
            'optional': {'runs-on': 'ubuntu-latest', 'steps': [
                {'name': 'build', 'run': 'npm run build'}]}}}
        self.write('tests/verification-catalog.json', json.dumps(self.catalog))
        self.write('.github/workflows/test.yml', json.dumps(self.workflow))
        for p in ('tests/verification-impact.py', 'tests/verification-workflow.py', 'tests/verification.py'):
            self.write(p, (ROOT / p).read_text())
        self.write('docs/guide.txt', 'old\n')
        self.base = self.commit('base')
        self.git('clone', '-q', '--no-hardlinks', str(self.root), str(self.trusted))
        self.write('docs/guide.txt', 'new\n')
        self.head = self.commit('head')

    def write(self, path, text):
        p = self.root / path
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.root, check=True,
                              capture_output=True, text=True).stdout.strip()

    def commit(self, message):
        self.git('add', '.')
        self.git('commit', '-qm', message)
        return self.git('rev-parse', 'HEAD')

    def plan(self, **kwargs):
        args = dict(root=self.root, trusted_root=self.trusted, event='pull_request',
                    run_id='123', run_attempt=1, api_head_sha=self.head,
                    tested_revision=self.head, base=self.base, head=self.head, force_full='false')
        args.update(kwargs)
        return IMPACT.make_plan(**args)


class PlanningTests(GitFixture):
    def test_bound_full_and_event_force_precedence(self):
        p = self.plan()
        self.assertEqual(p['mode'], 'full')
        self.assertEqual(p['changed_path_count'], 1)
        self.assertEqual(p['pr_head_revision'], self.head)
        self.assertEqual(p['base_revision'], self.base)
        self.assertEqual(p['merge_base_revision'], self.base)
        self.assertTrue(p['trusted_planner_sha256'])
        for event in ('push', 'merge_group', 'workflow_dispatch', 'release'):
            p = self.plan(event=event)
            self.assertEqual((p['mode'], p['reason']), ('full', 'event-full'))
            self.assertFalse(p['omissions'])
        for force in (None, '', 'true', 'False', 'FALSE', 'unexpected'):
            self.assertEqual(self.plan(force_full=force)['reason'], 'force-full')

    def test_mandatory_identity_failures(self):
        for values in (dict(run_id=''), dict(run_id='0'), dict(run_attempt=0),
                       dict(api_head_sha=''), dict(tested_revision='f' * 40),
                       dict(event='PUSH')):
            with self.subTest(values=values), self.assertRaises(ValueError):
                self.plan(**values)
    def test_complete_nul_diff_rename_case_type_newlines_and_3001(self):
        self.git('checkout', '-q', self.base)
        self.write('Old.txt', 'old')
        self.write('type.txt', 'regular')
        start = self.commit('start')
        (self.root / 'Old.txt').rename(self.root / 'old.txt')
        (self.root / 'type.txt').unlink()
        (self.root / 'type.txt').symlink_to('old.txt')
        (self.root / 'docs/guide.txt').unlink()
        names = {'space name', 'tab\tname', 'line\nname', '$(touch forbidden);.txt'}
        for name in names:
            self.write(name, 'data')
        for n in range(3001):
            self.write(f'many/{n:04}.txt', str(n))
        end = self.commit('changes')
        paths, status = IMPACT.changed_paths(self.root, start, end)
        self.assertEqual(status, 'diff-available')
        self.assertEqual(paths, names | {'Old.txt', 'old.txt', 'type.txt', 'docs/guide.txt'} |
                         {f'many/{n:04}.txt' for n in range(3001)})
        self.assertFalse((self.root / 'forbidden').exists())
        plan = self.plan(base=start, head=end, api_head_sha=end, tested_revision=end)
        self.assertEqual(plan['changed_path_count'], len(paths))

    def test_shared_unknown_empty_and_untrusted_source(self):
        for path in ('tests/verification-impact.py', 'tests/verification-catalog.json',
                     '.github/workflows/test.yml', 'install.sh', 'contracts/example.json',
                     'AGENTS.md', 'plugins/example/SKILL.md', 'human-copy/example.md',
                     'reports/bound.json', 'unknown.txt'):
            self.git('checkout', '-q', self.head)
            self.write(path, (self.root / path).read_text() + '\n' if (self.root / path).exists() else 'data')
            revision = self.commit('shared')
            self.assertEqual(self.plan(head=revision, api_head_sha=revision,
                                       tested_revision=revision)['mode'], 'full')
        self.git('checkout', '-q', self.base)
        self.assertEqual(self.plan(head=self.base, api_head_sha=self.base,
                                   tested_revision=self.base)['mode'], 'full')
        (self.trusted / 'tests/verification.py').write_text('raise RuntimeError("untrusted")')
        self.assertEqual(self.plan(head=self.base, api_head_sha=self.base,
                                   tested_revision=self.base)['mode'], 'full')

    def test_obligation_inventory_exact_commands_os_and_non_suite(self):
        rows = W.plan_obligations(self.workflow, self.catalog)
        self.assertEqual(len(rows), 5)
        by_step = {r['step']: r for r in rows}
        self.assertEqual(by_step['bc']['suites'], self.suites[1:3])
        self.assertEqual(by_step['build']['suites'], [])
        command = dict(run='python3 tests/a.tests.py', shell='bash', env={})
        self.assertEqual(by_step['a']['command_sha256'], digest(command))
        modified = copy.deepcopy(self.workflow)
        modified['jobs']['test']['steps'][0]['run'] += ' --wrong'
        other = W.plan_obligations(modified, self.catalog)
        self.assertNotEqual(rows[0]['command_sha256'], other[0]['command_sha256'])
        self.assertEqual(other[0]['suites'], [])

    def test_continue_on_error_rejects_unproven_workload_exemptions(self):
        value: Any
        for level in ('job', 'step'):
            for value in ('${{ false }}', '${{ true }}', '${{ matrix.experimental }}',
                          'false', 'true', None, 0, 1, {}, []):
                with self.subTest(level=level, value=value):
                    workflow = copy.deepcopy(self.workflow)
                    job = workflow['jobs']['optional']
                    target = job if level == 'job' else job['steps'][0]
                    target['continue-on-error'] = value
                    with self.assertRaisesRegex(ValueError, 'continue-on-error'):
                        W.plan_obligations(workflow, self.catalog)
        for job_value, step_value in ((False, False), (True, False),
                                      (False, True), (True, True)):
            workflow = copy.deepcopy(self.workflow)
            job = workflow['jobs']['optional']
            job['continue-on-error'] = job_value
            job['steps'][0]['continue-on-error'] = step_value
            rows = W.plan_obligations(workflow, self.catalog)
            self.assertEqual(any(row['step'] == 'build' for row in rows),
                             not (job_value or step_value))
        # A proven optional job must not mask an unsupported step value.
        workflow['jobs']['optional']['steps'][0]['continue-on-error'] = '${{ false }}'
        with self.assertRaisesRegex(ValueError, 'continue-on-error'):
            W.plan_obligations(workflow, self.catalog)

    def test_continue_on_error_cli_fails_without_partial_outputs(self):
        self.workflow['jobs']['optional']['steps'][0]['continue-on-error'] = '${{ false }}'
        self.write('.github/workflows/test.yml', json.dumps(self.workflow))
        revision = self.commit('unsupported continue-on-error')
        output = Path(self.temp.name) / 'plan.json'
        github_output = Path(self.temp.name) / 'github-output'
        command = [sys.executable, '-B', str(ROOT / 'tests/verification-impact.py'), '--plan',
                   '--root', str(self.root), '--trusted-root', str(self.trusted),
                   '--event', 'push', '--run-id', '123', '--run-attempt', '1',
                   '--api-head-sha', revision, '--tested-revision', revision,
                   '--output', str(output), '--github-output', str(github_output)]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual(result.stdout, '')
        self.assertEqual(json.loads(result.stderr)['reason'], 'input-invalid')
        self.assertFalse(output.exists())
        self.assertFalse(github_output.exists())

    def test_control_verifier_is_not_its_own_completed_workload(self):
        live = W.load_workflow(ROOT / '.github/workflows/test.yml', ROOT)
        catalog = json.loads((ROOT / 'tests/verification-catalog.json').read_text())
        workload = W.plan_obligations(live, catalog)
        controls = W.control_dispositions(live, catalog)
        self.assertEqual(len(controls), 1)
        self.assertEqual(controls[0]['job'], 'required-checks')
        self.assertEqual(controls[0]['disposition'], 'orchestration-verifier')
        self.assertNotIn('required-checks', {r['job'] for r in workload})
        self.assertEqual({r['runner'] for r in workload if r['job'] == 'test'},
                         {'ubuntu-latest', 'macos-latest', 'windows-latest'})
        aggregate = 'python3 -B tests/verification-ci.py aggregate --root . --plan plan.json --observations observations --run-id "$GITHUB_RUN_ID" --api-head-sha "$API_HEAD_SHA"'
        future = copy.deepcopy(live)
        future['jobs']['required-checks']['steps'][0]['run'] = aggregate
        self.assertEqual(len(W.control_dispositions(future, catalog)), 1)
        for mutate in (
            lambda w: w['jobs']['required-checks']['steps'].append(
                {'name': 'hidden tests', 'run': 'python3 tests/verification-impact.tests.py'}),
            lambda w: w['jobs']['required-checks']['steps'][0].update(
                run=aggregate + '\npython3 tests/verification-impact.tests.py'),
            lambda w: w['jobs']['required-checks'].update(name='other'),
            lambda w: w['jobs']['required-checks'].update(**{'continue-on-error': True}),
        ):
            bad = copy.deepcopy(live)
            mutate(bad)
            with self.assertRaises(ValueError):
                W.plan_obligations(bad, catalog)
        copied = copy.deepcopy(live)
        copied['jobs']['arbitrary'] = copied['jobs'].pop('required-checks')
        self.assertIn('arbitrary', {r['job'] for r in W.plan_obligations(copied, catalog)})
        self.assertEqual(W.control_dispositions(copied, catalog), [])

    def test_full_inventory_runner_matrix_shards_and_opaque_body(self):
        workflow = {'jobs': {'test': {'runs-on': '${{ matrix.os }}', 'strategy': {
            'matrix': {'os': ['ubuntu-latest', 'macos-latest', 'windows-latest']}}, 'steps': [
                {'name': 'posix', 'if': "runner.os == 'Linux' || runner.os == 'macOS'",
                 'run': 'python3 tests/a.tests.py'},
                {'name': 'opaque', 'run': 'if true; then python3 tests/b.tests.py; fi'}]},
            'shards': {'runs-on': 'ubuntu-latest', 'strategy': {'matrix': {'shard': [0, 1]}},
                       'steps': [{'name': 'partition', 'shell': 'bash', 'run':
                           'bash ./tests/run-ci-unwired.sh --shard-index "${{ matrix.shard }}" --shard-count 2 --receipt "receipt.json"'}]}}}
        self.catalog['profiles']['ci-posix-fallback'] = self.suites
        rows = W.plan_obligations(workflow, self.catalog, weights=dict.fromkeys(self.suites, 1))
        posix = [r for r in rows if r['step'] == 'posix']
        self.assertEqual({r['runner'] for r in posix}, {'ubuntu-latest', 'macos-latest'})
        shards = [r for r in rows if r['step'] == 'partition']
        self.assertEqual(sorted(s for r in shards for s in r['suites']), self.suites)
        self.assertTrue(all(r['receipt_required'] for r in shards))
        self.assertTrue(all(not r['suites'] for r in rows if r['step'] == 'opaque'))

    def test_dependency_and_indivisible_step_fixed_point(self):
        obligations = W.plan_obligations(self.workflow, self.catalog)
        selected = IMPACT.dependency_closure({self.suites[0]}, set(), self.catalog, obligations)
        self.assertEqual(selected, set(self.suites))
        self.catalog['impact']['dependencies'][self.suites[0]] = ['tests/missing.tests.py']
        with self.assertRaises(ValueError):
            IMPACT.dependency_closure({self.suites[0]}, set(), self.catalog, obligations)

    def test_union_fixture_generator_case_and_unknown_syntax_boundaries(self):
        obligations = W.plan_obligations(self.workflow, self.catalog)
        categories = [dict(id='fixture', paths=['fixtures/Shared.txt'], prefixes=[],
                           suites=[self.suites[0]], groups=[], active=False, evidence=None),
                      dict(id='generator', paths=['generator/input.txt'], prefixes=[],
                           suites=[], groups=['optional'], active=False, evidence=None)]
        self.assertTrue(IMPACT.category_matches(categories[0], 'fixtures/Shared.txt'))
        self.assertFalse(IMPACT.category_matches(categories[0], 'fixtures/shared.txt'))
        selected = IMPACT.selected_obligations(categories, self.catalog, self.workflow, obligations)
        self.assertEqual({s for row in selected for s in row['suites']}, set(self.suites))
        self.assertIn('optional', {row['job'] for row in selected})
        self.catalog['impact']['categories'] = categories
        self.catalog['impact']['non_suite_steps'] = [dict(job='optional', step='build', kind='build')]
        self.workflow['jobs']['optional']['steps'][0]['if'] = 'unknown(expression)'
        selected = IMPACT.selected_obligations(categories[:1], self.catalog, self.workflow, obligations)
        self.assertIn('optional', {row['job'] for row in selected})
        self.workflow['jobs']['optional']['steps'][0]['run'] = 'if true; then npm run build; fi'
        with self.assertRaises(ValueError):
            IMPACT.rules(self.catalog, self.workflow)
        for condition in ('unknown(expression)', "matrix.missing == 'no'"):
            self.workflow['jobs']['optional']['steps'][0]['if'] = condition
            self.assertIn('optional', {row['job'] for row in W.plan_obligations(self.workflow, self.catalog)})

    def test_definition_hash_excludes_proof_pointers_not_command_definitions(self):
        category = dict(id='guide', paths=['docs/guide.txt'], prefixes=[],
                        suites=[self.suites[0]], groups=[], active=False, evidence=None)
        self.catalog['impact']['categories'] = [category]
        original = IMPACT.rule_digest(self.catalog, self.workflow)
        category['active'] = True
        category['evidence'] = {'path': 'proof.json', 'sha256': '0' * 64,
                                'rule_sha256': '1' * 64, 'baseline_revision': '2' * 40}
        self.assertEqual(IMPACT.rule_digest(self.catalog, self.workflow), original)
        self.write('docs/guide.txt', 'ordinary product edit')
        self.assertEqual(IMPACT.rule_digest(self.catalog, self.workflow), original)
        category['suites'] = [self.suites[1]]
        self.assertNotEqual(IMPACT.rule_digest(self.catalog, self.workflow), original)

    def test_timeout_boundaries_have_sanitized_typed_diagnostics(self):
        argv = ['--plan', '--root', str(self.root), '--trusted-root', str(self.trusted),
                '--event', 'pull_request', '--run-id', '123', '--run-attempt', '1',
                '--api-head-sha', self.head, '--tested-revision', self.head,
                '--base', self.base, '--head', self.head, '--force-full', 'false']
        real_run = subprocess.run
        secret = 'fixture-private-command-and-environment'
        for timeout in (120, 20):
            calls = []

            def run(*args, **kwargs):
                if kwargs.get('timeout') == timeout:
                    calls.append(timeout)
                    raise subprocess.TimeoutExpired(secret, timeout, output=secret, stderr=secret)
                return real_run(*args, **kwargs)

            # YAML case executes the actual existing loader, not a mocked exception boundary.
            def yaml_plan(**kwargs):
                return W.load_workflow(ROOT / '.github/workflows/test.yml')

            stderr, stdout = io.StringIO(), io.StringIO()
            with self.subTest(timeout=timeout), patch.object(subprocess, 'run', side_effect=run), \
                    patch.object(sys, 'stderr', stderr), patch.object(sys, 'stdout', stdout):
                if timeout == 20:
                    with patch.object(IMPACT, 'make_plan', side_effect=yaml_plan):
                        code = IMPACT.plan_main(argv)
                else:
                    code = IMPACT.plan_main(argv)
                self.assertEqual(calls, [timeout])
                self.assertEqual(code, 2)
                self.assertEqual(stdout.getvalue(), '')
                self.assertEqual(json.loads(stderr.getvalue()), {
                    'schema': 'verification-ci-error/v1', 'reason': 'input-invalid',
                    'message': 'Planning subprocess timed out; verify local dependencies and retry.'})
                self.assertNotIn(secret, stderr.getvalue())
                self.assertNotIn('Traceback', stderr.getvalue())

    def test_cli_explicit_plan_and_create_only_output(self):
        output = Path(self.temp.name) / 'plan.json'
        github_output = Path(self.temp.name) / 'github-output'
        command = [sys.executable, '-B', str(ROOT / 'tests/verification-impact.py'), '--plan',
                   '--root', str(self.root), '--trusted-root', str(self.trusted),
                   '--event', 'push', '--run-id', '123', '--run-attempt', '1',
                   '--api-head-sha', self.head, '--tested-revision', self.head,
                   '--output', str(output), '--github-output', str(github_output)]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), json.loads(output.read_text()))
        self.assertEqual(github_output.read_text(), 'run_optional=true\nrun_test=true\n')
        self.assertEqual(subprocess.run(command, capture_output=True).returncode, 2)
        duplicate = subprocess.run(command + ['--run-id', '124'], capture_output=True, text=True)
        self.assertEqual(duplicate.returncode, 2)
        self.assertEqual(json.loads(duplicate.stderr)['schema'], 'verification-ci-error/v1')



class ProofTests(GitFixture):
    def setUp(self):
        super().setUp()
        self.git('checkout', '-q', self.base)
        self.catalog['impact']['categories'] = [dict(
            id='guide', paths=['docs/guide.txt'], prefixes=[], suites=[self.suites[0]],
            groups=[], active=False, evidence=None)]
        # Declared build command is omittable; opaque integrity stays mandatory.
        self.catalog['impact']['non_suite_steps'] = [
            dict(job='optional', step='build', kind='build')]
        self.write('tests/verification-catalog.json', json.dumps(self.catalog))
        self.baseline = self.commit('inactive category definition')
        self.rule = IMPACT.rule_digest(self.catalog, self.workflow)
        self.full = IMPACT.make_plan(self.root, self.root, 'push', '123', 1,
                                     self.baseline, self.baseline)
        self.full_result = self.result(self.full, False)
        self.git('checkout', '-qb', 'mutation')
        self.write('docs/guide.txt', 'deliberate broken input')
        mutation_revision = self.commit('mutation fixture')
        mutation_plan = IMPACT.make_plan(self.root, self.root, 'push', '124', 1,
                                         mutation_revision, mutation_revision)
        mutation_result = self.result(mutation_plan, True)
        subprocess.run(['git', '-C', str(self.trusted), 'fetch', '-q', str(self.root), mutation_revision], check=True)
        self.git('checkout', '-q', self.baseline)
        self.proof = dict(schema='verification-ci-activation/v1', category='guide',
                          rule_sha256=self.rule, baseline_revision=self.baseline,
                          full_plan=self.ref('proof/full-plan.json', self.full),
                          full_result=self.ref('proof/full-result.json', self.full_result),
                          consumer_inventory=self.ref('proof/consumers.json', dict(
                              schema='verification-ci-consumers/v1', baseline_revision=self.baseline,
                              rule_sha256=self.rule, consumers=[dict(
                                  input='docs/guide.txt', suites=[self.suites[0]], groups=[],
                                  sources=[dict(path='docs/guide.txt', sha256=hashlib.sha256(b'old\n').hexdigest())])])),
                          mutation_evidence=self.ref('proof/mutations.json', dict(
                              schema='verification-ci-mutations/v1', baseline_revision=self.baseline,
                              rule_sha256=self.rule, cases=[dict(input='docs/guide.txt',
                                  plan=self.ref('proof/mutation-plan.json', mutation_plan),
                                  result=self.ref('proof/mutation-result.json', mutation_result))])))
        self.activate()

    def result(self, plan, failing):
        return dict(schema='verification-ci-result/v1', status='FAIL' if failing else 'PASS',
                    reason='execution-failed' if failing else 'verified', run_id=plan['run_id'],
                    api_head_sha=plan['api_head_sha'], tested_revision=plan['tested_revision'],
                    plan_sha256=plan['plan_sha256'], results=[dict(
                        obligation_id=o['id'], status='FAIL' if failing and o['step'] == 'a' else 'PASS',
                        reason='execution-failed' if failing and o['step'] == 'a' else 'verified',
                        job_id=n + 1, source_attempt=1) for n, o in enumerate(plan['obligations'])])

    def ref(self, path, value):
        text = json.dumps(value, sort_keys=True) + '\n'
        self.write(path, text)
        return dict(path=path, sha256=hashlib.sha256(text.encode()).hexdigest())

    def activate(self):
        ref = self.ref('proof/activation.json', self.proof)
        self.catalog['impact']['categories'][0].update(active=True, evidence={
            **ref, 'rule_sha256': self.rule, 'baseline_revision': self.baseline})
        self.write('tests/verification-catalog.json', json.dumps(self.catalog))
        self.base = self.commit('reviewed fixture proof; not hosted evidence')
        subprocess.run(['git', '-C', str(self.trusted), 'fetch', '-q', str(self.root), self.base], check=True)
        subprocess.run(['git', '-C', str(self.trusted), 'checkout', '-q', self.base], check=True)
        self.write('docs/guide.txt', 'ordinary product change')
        self.head = self.commit('classified change')

    def verified_merge(self):
        original_base = self.base
        self.git('checkout', '-qb', 'base-side', original_base)
        self.git('commit', '--allow-empty', '-qm', 'advance exact trusted base')
        self.base = self.git('rev-parse', 'HEAD')
        self.git('merge', '--no-ff', '-m', 'verified tested merge', self.head)
        merge = self.git('rev-parse', 'HEAD')
        self.assertEqual(self.git('show', '-s', '--format=%P', merge).split(),
                         [self.base, self.head])
        subprocess.run(['git', '-C', str(self.trusted), 'fetch', '-q',
                        str(self.root), self.base], check=True)
        subprocess.run(['git', '-C', str(self.trusted), 'checkout', '-q', self.base], check=True)
        return original_base, merge

    def test_optional_revision_rejections_have_binding_specific_reasons(self):
        control = self.plan()
        self.assertEqual((control['mode'], control['reason']), ('affected', 'classified-change'))
        self.assertTrue(control['omissions'])
        for values, reason in (
                (dict(base=None), 'base-planner-unavailable'),
                (dict(base='e' * 40), 'base-planner-unavailable'),
                (dict(head='d' * 40), 'diff-unavailable'),
                (dict(head=None), 'diff-unavailable'),
                (dict(head=self.base), 'binding-invalid'),
                (dict(api_head_sha=self.base), 'binding-invalid')):
            with self.subTest(values=values):
                plan = self.plan(**values)
                self.assertEqual((plan['mode'], plan['reason']), ('full', reason))
                self.assertEqual(plan['omissions'], [])
                self.assertEqual(len(plan['obligations']), len(self.full['obligations']))
                if reason != 'base-planner-unavailable':
                    self.assertTrue(plan['trusted_planner_sha256'])

    def test_verified_merge_binds_exact_base_head_and_tested_revision(self):
        original_base, merge = self.verified_merge()
        plan = self.plan(tested_revision=merge)
        self.assertEqual((plan['mode'], plan['reason']), ('affected', 'classified-change'))
        self.assertTrue(plan['trusted_planner_sha256'])
        self.assertTrue(plan['omissions'])
        self.assertEqual(plan['api_head_sha'], self.head)
        self.assertEqual(plan['pr_head_revision'], self.head)
        self.assertEqual(plan['tested_revision'], merge)
        self.assertEqual(plan['base_revision'], self.base)
        self.assertEqual(plan['merge_base_revision'], original_base)
        self.assertNotEqual(plan['api_head_sha'], plan['tested_revision'])
        for values in (dict(api_head_sha=merge),
                       dict(head=self.base, api_head_sha=self.base)):
            with self.subTest(values=values):
                rejected = self.plan(tested_revision=merge, **values)
                self.assertEqual((rejected['mode'], rejected['reason']),
                                 ('full', 'binding-invalid'))
                self.assertTrue(rejected['trusted_planner_sha256'])
                self.assertFalse(rejected['omissions'])
        with self.assertRaises(ValueError):
            self.plan(tested_revision=self.head)
        # Keep the old base genuinely trusted so the parent mismatch is isolated.
        subprocess.run(['git', '-C', str(self.trusted), 'checkout', '-q', original_base], check=True)
        rejected = self.plan(base=original_base, tested_revision=merge)
        self.assertEqual((rejected['mode'], rejected['reason']), ('full', 'binding-invalid'))
        self.assertTrue(rejected['trusted_planner_sha256'])
        self.assertFalse(rejected['omissions'])

    def test_revision_guards_detect_real_source_mutations(self):
        original_base, merge = self.verified_merge()
        arguments = [self.root, 'pull_request', self.head, merge, self.base, self.head]
        matched = IMPACT.revision_inputs(*arguments)
        self.assertIsNone(matched[2])
        self.assertEqual(matched[1], {'docs/guide.txt'})
        source = inspect.getsource(IMPACT.revision_inputs)
        for guard, index, value in (
                ('    if api_head != head:\n', 2, merge),
                ('        if parents != [base, head]:\n', 4, original_base)):
            with self.subTest(guard=guard.strip()):
                bad = list(arguments)
                bad[index] = value
                self.assertEqual(IMPACT.revision_inputs(*bad)[2], 'binding-invalid')
                self.assertEqual(source.count(guard), 1)
                namespace = dict(IMPACT.__dict__)
                changed = source.replace(guard, guard[:len(guard) - len(guard.lstrip())] + 'if False:\n')
                exec(compile(changed, '<isolated-revision-guard-mutation>', 'exec'), namespace)
                # Removing this exact guard loses the specific rejection.
                self.assertIsNone(namespace['revision_inputs'](*bad)[2])
                self.assertEqual(namespace['revision_inputs'](*arguments), matched)

    def test_selection_executes_trusted_checkout_not_caller_imports(self):
        with patch.object(IMPACT, 'workflow_module', side_effect=AssertionError('caller imported')):
            p = self.plan()
        self.assertEqual(p['mode'], 'affected')
        (self.root / 'tests/verification-workflow.py').write_text('raise RuntimeError("PR import")')
        self.head = self.commit('PR-controlled planner import')
        self.assertEqual(self.plan()['mode'], 'full')

    def test_changed_base_definition_invalidates_activation(self):
        original_base = self.base
        build = {'name': 'offline-proof-regression', 'private': True, 'scripts': {
            'build': 'node -e \'process.exit(require("fs").readFileSync("docs/guide.txt","utf8") === "old\\n" ? 0 : 1)\''}}
        for path, content in (
                ('package.json', json.dumps(build)),
                ('tests/new-consumer.py', 'print("new dependency")\n'),
                ('unknown-definition.data', 'new dependency\n')):
            with self.subTest(path=path):
                self.git('checkout', '-q', original_base)
                self.write(path, content)
                self.base = self.commit('changed definition after proof')
                if path == 'package.json':
                    before = subprocess.run(['npm', 'run', 'build', '--offline'], cwd=self.root,
                                            capture_output=True)
                    self.assertEqual(before.returncode, 0)
                subprocess.run(['git', '-C', str(self.trusted), 'fetch', '-q', str(self.root), self.base], check=True)
                subprocess.run(['git', '-C', str(self.trusted), 'checkout', '-q', self.base], check=True)
                self.write('docs/guide.txt', 'ordinary product change')
                self.head = self.commit('later classified edit')
                if path == 'package.json':
                    after = subprocess.run(['npm', 'run', 'build', '--offline'], cwd=self.root,
                                           capture_output=True)
                    self.assertNotEqual(after.returncode, 0)
                self.assertEqual(self.plan()['mode'], 'full')

    def test_ordinary_base_input_change_preserves_activation(self):
        self.git('checkout', '-q', self.base)
        self.write('docs/guide.txt', 'ordinary change in base')
        self.base = self.commit('ordinary base input change')
        subprocess.run(['git', '-C', str(self.trusted), 'fetch', '-q', str(self.root), self.base], check=True)
        subprocess.run(['git', '-C', str(self.trusted), 'checkout', '-q', self.base], check=True)
        self.write('docs/guide.txt', 'later ordinary change')
        self.head = self.commit('ordinary head input change')
        self.assertEqual(self.plan()['mode'], 'affected')

    def test_supporting_records_are_bound_and_cannot_hide_definitions(self):
        original_base = self.base
        original_proof = copy.deepcopy(self.proof)
        for kind in ('valid', 'wrong-hash', 'duplicate', 'definition', 'executable', 'outside'):
            with self.subTest(kind=kind):
                self.git('checkout', '-q', original_base)
                self.proof = copy.deepcopy(original_proof)
                path = {'definition': 'reports/verification/proof/package.json',
                        'executable': 'reports/verification/proof/helper.py',
                        'outside': 'runtime/config.json'}.get(kind, 'reports/verification/proof/job.json')
                ref = self.ref(path, {'observed': 'fixture, not hosted'})
                if kind == 'wrong-hash':
                    ref['sha256'] = '0' * 64
                self.proof['supporting_evidence'] = [ref, ref] if kind == 'duplicate' else [ref]
                self.activate()
                self.assertEqual(self.plan()['mode'], 'affected' if kind == 'valid' else 'full')

    def test_positive_affected_dependency_partition_and_bound_proof(self):
        p = self.plan()
        self.assertEqual(p['mode'], 'affected')
        self.assertEqual({s for o in p['obligations'] for s in o['suites']}, set(self.suites))
        self.assertEqual(len(p['omissions']), 1)
        self.assertTrue(all(o['reason'] for o in p['omissions']))
        self.assertEqual(p['activation_evidence'][0]['rule_sha256'], self.rule)
        self.assertEqual(p['activation_evidence'][0]['baseline_revision'], self.baseline)
        self.assertEqual(p['groups'], ['test'])
        self.assertEqual(len(p['obligations']) + len(p['omissions']), len(self.full['obligations']))

    def test_required_dependency_deletion_invalidates_activated_definition(self):
        control = self.plan()
        self.assertEqual((control['mode'], control['reason']), ('affected', 'classified-change'))
        self.assertEqual({s for row in control['obligations'] for s in row['suites']}, set(self.suites))
        self.assertTrue(control['omissions'])
        category = self.catalog['impact']['categories'][0]
        IMPACT.validate_activation(category, self.rule, self.root, self.base,
                                   self.catalog, self.workflow, self.full['obligations'])
        self.git('checkout', '-q', self.base)
        del self.catalog['impact']['dependencies'][self.suites[0]]
        # Every reference remains valid; only a required edge has disappeared.
        self.assertTrue(all(key in self.suites and set(deps).issubset(self.suites)
                            for key, deps in self.catalog['impact']['dependencies'].items()))
        changed_rule = IMPACT.rule_digest(self.catalog, self.workflow)
        self.assertNotEqual(changed_rule, self.rule)
        with self.assertRaisesRegex(ValueError, 'activation definition mismatch'):
            IMPACT.validate_activation(category, changed_rule, self.root, self.base,
                                       self.catalog, self.workflow, self.full['obligations'])
        self.write('tests/verification-catalog.json', json.dumps(self.catalog))
        self.base = self.commit('delete required dependency without updating proof')
        subprocess.run(['git', '-C', str(self.trusted), 'fetch', '-q', str(self.root), self.base], check=True)
        subprocess.run(['git', '-C', str(self.trusted), 'checkout', '-q', self.base], check=True)
        self.write('docs/guide.txt', 'later classified edit')
        self.head = self.commit('edit after dependency deletion')
        rejected = self.plan()
        self.assertEqual((rejected['mode'], rejected['reason']), ('full', 'unproven-category'))
        self.assertTrue(rejected['trusted_planner_sha256'])
        self.assertFalse(rejected['omissions'])
        self.assertFalse(rejected['activation_evidence'])
        self.assertEqual(rejected['obligations'], self.full['obligations'])

    def test_proof_fields_and_references_must_match(self):
        category = self.catalog['impact']['categories'][0]
        expected = IMPACT.validate_activation(category, self.rule, self.root, self.base,
                                              self.catalog, self.workflow, self.full['obligations'])
        self.assertEqual(expected['category'], 'guide')
        for key in self.proof:
            with self.subTest(field=key):
                bad = copy.deepcopy(self.proof)
                bad[key] = 'mismatch' if isinstance(bad[key], str) else {'path': '../escape', 'sha256': '0' * 64}
                with patch.object(IMPACT, 'read_reference', return_value=bad):
                    with self.assertRaises(ValueError):
                        IMPACT.validate_activation(category, self.rule, self.root, self.base,
                                                   self.catalog, self.workflow, self.full['obligations'])
        for key in ('path', 'sha256', 'rule_sha256', 'baseline_revision'):
            bad_category = copy.deepcopy(category)
            bad_category['evidence'][key] = 'wrong'
            with self.subTest(reference=key), self.assertRaises(ValueError):
                IMPACT.validate_activation(bad_category, self.rule, self.root, self.base,
                                           self.catalog, self.workflow, self.full['obligations'])

    def test_full_result_and_consumer_mutation_records_are_not_success_flags(self):
        category = self.catalog['impact']['categories'][0]
        real_reader = IMPACT.read_reference
        for path, mutate in (
            ('proof/full-result.json', lambda d: d.update(results=[])),
            ('proof/full-result.json', lambda d: d.update(plan_sha256='0' * 64)),
            ('proof/full-result.json', lambda d: d['results'][0].update(status='FAIL')),
            ('proof/consumers.json', lambda d: d.update(consumers=[])),
            ('proof/consumers.json', lambda d: d['consumers'][0]['sources'][0].update(sha256='0' * 64)),
            ('proof/mutations.json', lambda d: d.update(cases=[])),
            ('proof/mutation-result.json', lambda d: d.update(status='PASS')),
            ('proof/mutation-result.json', lambda d: d['results'][-1].update(status='FAIL')),
        ):
            def reader(root, revision, reference):
                value = real_reader(root, revision, reference)
                if reference['path'] == path:
                    mutate(value)
                return value
            with self.subTest(path=path), patch.object(IMPACT, 'read_reference', side_effect=reader):
                with self.assertRaises(ValueError):
                    IMPACT.validate_activation(category, self.rule, self.root, self.base,
                                               self.catalog, self.workflow, self.full['obligations'])

    def test_all_proof_payload_fields_and_sensitivity(self):
        category = self.catalog['impact']['categories'][0]
        real_reader = IMPACT.read_reference
        arguments = (category, self.rule, self.root, self.base, self.catalog,
                     self.workflow, self.full['obligations'])
        IMPACT.validate_activation(*arguments)

        def leaves(value, trail=()):
            if isinstance(value, dict):
                for key, child in value.items():
                    yield from leaves(child, trail + (key,))
            elif isinstance(value, list) and value:
                for index, child in enumerate(value):
                    yield from leaves(child, trail + (index,))
            else:
                yield trail, value

        total = 0
        for path in ('proof/activation.json', 'proof/full-plan.json', 'proof/full-result.json',
                     'proof/consumers.json', 'proof/mutations.json', 'proof/mutation-plan.json',
                     'proof/mutation-result.json'):
            payload = json.loads((self.root / path).read_text())
            for trail, value in leaves(payload):
                def reader(root, revision, reference):
                    record = real_reader(root, revision, reference)
                    if reference['path'] == path:
                        parent = record
                        for key in trail[:-1]:
                            parent = parent[key]
                        parent[trail[-1]] = ('mismatch' if isinstance(value, str) else
                                            not value if type(value) is bool else
                                            -1 if type(value) is int else ['unexpected'])
                    return record
                with self.subTest(path=path, field=trail):
                    with patch.object(IMPACT, 'read_reference', side_effect=reader):
                        with self.assertRaises(ValueError):
                            IMPACT.validate_activation(*arguments)
                    # Each negative assertion is sensitive to removal of the boundary.
                    with patch.object(IMPACT, 'validate_activation', return_value=None):
                        with self.assertRaises(AssertionError):
                            with self.assertRaises(ValueError):
                                IMPACT.validate_activation(*arguments)
                    total += 1
        self.assertGreater(total, 100)

    def test_inactive_corrupt_proof_shared_and_opaque_changes_never_omit(self):
        for field, value in (('active', False), ('evidence', None)):
            self.git('checkout', '-q', self.base)
            self.catalog['impact']['categories'][0][field] = value
            self.write('tests/verification-catalog.json', json.dumps(self.catalog))
            base = self.commit('unproven category')
            subprocess.run(['git', '-C', str(self.trusted), 'fetch', '-q', str(self.root), base], check=True)
            subprocess.run(['git', '-C', str(self.trusted), 'checkout', '-q', base], check=True)
            self.write('docs/guide.txt', 'changed')
            head = self.commit('change')
            self.assertEqual(self.plan(base=base, head=head, api_head_sha=head, tested_revision=head)['mode'], 'full')

class RenameConsumerTests(GitFixture):
    def test_content_changing_rename_selects_old_and_new_consumers(self):
        self.git('checkout', '-q', self.base)
        old, new = 'docs/old/guide.txt', 'docs/new/moved.txt'
        original = ''.join(f'guide line {n:03}\n' for n in range(40))
        self.write(old, original)
        self.catalog['impact']['dependencies'] = {}
        categories: list[dict[str, Any]] = [
            dict(id=name, paths=[], prefixes=[f'docs/{name}/'], suites=[suite],
                 groups=[], active=False, evidence=None)
            for name, suite in [('old', self.suites[0]), ('new', self.suites[2])]]
        self.catalog['impact']['categories'] = categories
        self.catalog['impact']['non_suite_steps'] = [dict(job='optional', step='build', kind='build')]
        self.workflow['jobs']['test']['steps'] = [
            {'name': name, 'run': f'python3 {suite}'}
            for name, suite in zip('abcd', self.suites)] + [
                {'name': 'integrity', 'run': 'git diff --exit-code'}]
        for category, path in zip(categories, (old, new)):
            self.write(category['suites'][0], 'from pathlib import Path\n'
                       f'p = Path({path!r})\n'
                       'assert not p.exists() or "BROKEN" not in p.read_text()\n')
        self.write('tests/verification-catalog.json', json.dumps(self.catalog))
        self.write('.github/workflows/test.yml', json.dumps(self.workflow))
        baseline = self.commit('distinct rename consumers and independent obligations')
        rule = IMPACT.rule_digest(self.catalog, self.workflow)
        full = IMPACT.make_plan(self.root, self.root, 'push', '123', 1, baseline, baseline)

        def ref(path, value):
            text = json.dumps(value, sort_keys=True) + '\n'
            self.write(path, text)
            return dict(path=path, sha256=hashlib.sha256(text.encode()).hexdigest())

        def result(plan, failed_suite=None):
            return dict(schema='verification-ci-result/v1', status='FAIL' if failed_suite else 'PASS',
                        reason='execution-failed' if failed_suite else 'verified', run_id=plan['run_id'],
                        api_head_sha=plan['api_head_sha'], tested_revision=plan['tested_revision'],
                        plan_sha256=plan['plan_sha256'], results=[dict(
                            obligation_id=row['id'], status='FAIL' if failed_suite in row['suites'] else 'PASS',
                            reason='execution-failed' if failed_suite in row['suites'] else 'verified',
                            job_id=index + 1, source_attempt=1)
                            for index, row in enumerate(plan['obligations'])])

        mutations = []
        for category, path in zip(categories, (old, new)):
            self.git('checkout', '-q', baseline)
            self.write(path, 'BROKEN\n')
            revision = self.commit('local consumer failure fixture')
            execution = subprocess.run(['python3', '-B', category['suites'][0]],
                                       cwd=self.root, capture_output=True)
            self.assertNotEqual(execution.returncode, 0)
            plan = IMPACT.make_plan(self.root, self.root, 'push', '124', 1, revision, revision)
            mutations.append((plan, result(plan, category['suites'][0])))
            subprocess.run(['git', '-C', str(self.trusted), 'fetch', '-q', str(self.root), revision], check=True)
        self.git('checkout', '-q', baseline)
        # Both input namespaces contain their passive protocol fixtures; neither
        # category must trust undeclared changes to the other's input namespace.
        full_ref = ref('docs/old/proof/full-plan.json', full)
        full_result_ref = ref('docs/old/proof/full-result.json', result(full))
        for category, path, (plan, failure) in zip(categories, (old, new), mutations):
            prefix = 'docs/' + category['id'] + '/proof/rename'
            proof = dict(schema='verification-ci-activation/v1', category=category['id'],
                         rule_sha256=rule, baseline_revision=baseline,
                         full_plan=full_ref, full_result=full_result_ref,
                         consumer_inventory=ref(prefix + '-consumers.json', dict(
                             schema='verification-ci-consumers/v1', baseline_revision=baseline,
                             rule_sha256=rule, consumers=[dict(
                                 input=category['prefixes'][0], suites=category['suites'], groups=[],
                                 sources=[dict(path=category['suites'][0], sha256=hashlib.sha256(
                                     (self.root / category['suites'][0]).read_bytes()).hexdigest())])])),
                         mutation_evidence=ref(prefix + '-mutations.json', dict(
                             schema='verification-ci-mutations/v1', baseline_revision=baseline,
                             rule_sha256=rule, cases=[dict(input=path,
                                 plan=ref(prefix + '-plan.json', plan),
                                 result=ref(prefix + '-result.json', failure))])))
            category.update(active=True, evidence={**ref(prefix + '-activation.json', proof),
                                                   'rule_sha256': rule, 'baseline_revision': baseline})
        self.write('tests/verification-catalog.json', json.dumps(self.catalog))
        self.base = self.commit('local activation protocol fixtures, not hosted evidence')
        for category in categories:
            IMPACT.validate_activation(category, rule, self.root, self.base,
                                       self.catalog, self.workflow, full['obligations'])
        subprocess.run(['git', '-C', str(self.trusted), 'fetch', '-q', str(self.root), self.base], check=True)
        subprocess.run(['git', '-C', str(self.trusted), 'checkout', '-q', self.base], check=True)
        for path, expected in [(old, {self.suites[0]}), (new, {self.suites[2]})]:
            self.git('checkout', '-q', self.base)
            self.write(path, original + 'independent control\n')
            self.head = self.commit('matched single-consumer control')
            for category in categories:
                IMPACT.validate_activation(category, rule, self.root, self.head,
                                           self.catalog, self.workflow, full['obligations'])
            control = self.plan()
            self.assertEqual((control['mode'], control['reason']), ('affected', 'classified-change'))
            self.assertEqual({s for row in control['obligations'] for s in row['suites']}, expected)
            self.assertTrue(control['omissions'])
        self.git('checkout', '-q', self.base)
        (self.root / old).rename(self.root / new)
        self.write(new, original.replace('guide line 020', 'changed line 020'))
        self.head = self.commit('rename with content changes')
        self.assertNotEqual((self.root / new).read_text(), original)
        self.assertRegex(self.git('diff', '--name-status', '-M', self.base, self.head),
                         r'^R[0-9]+\tdocs/old/guide\.txt\tdocs/new/moved\.txt$')
        paths, status = IMPACT.changed_paths(self.root, self.base, self.head)
        self.assertEqual((paths, status), ({old, new}, 'diff-available'))
        selected = self.plan()
        self.assertEqual((selected['mode'], selected['reason']), ('affected', 'classified-change'))
        self.assertEqual({s for row in selected['obligations'] for s in row['suites']},
                         {self.suites[0], self.suites[2]})
        self.assertEqual({row['category'] for row in selected['activation_evidence']}, {'old', 'new'})
        self.assertTrue(selected['omissions'])
        command = [sys.executable, '-B', str(self.trusted / 'tests/verification-impact.py'),
                   '--plan', '--root', str(self.root), '--trusted-root', str(self.trusted),
                   '--event', 'pull_request', '--run-id', '123', '--run-attempt', '1',
                   '--api-head-sha', self.head, '--tested-revision', self.head,
                   '--base', self.base, '--head', self.head, '--force-full', 'false']
        independent = []
        for seed in ('0', '1', '2', '3'):
            completed = subprocess.run(command, capture_output=True, check=True,
                                       env={**os.environ, 'PYTHONHASHSEED': seed})
            independent.append(IMPACT.strict_json(completed.stdout))
        print('Independent planning hashes:', [plan['plan_sha256'] for plan in independent])
        for plan in independent:
            self.assertEqual(plan, independent[0])
            IMPACT.validate_plan(plan, expected=selected)



class A9ConsumerTests(GitFixture):
    """Synthetic Git proofs exercise both actual activation-consumer call sites."""

    ref: Any = ProofTests.ref
    result: Any = ProofTests.result
    activate: Any = ProofTests.activate

    def setUp(self):
        super().setUp()
        self.git('checkout', '-q', self.base)
        live = W.load_workflow(ROOT / '.github/workflows/test.yml')
        self.workflow['env'] = live['env']
        for job in ('a9-advisory-inputs', 'a9-advisory'):
            self.workflow['jobs'][job] = copy.deepcopy(live['jobs'][job])
        self.catalog['impact']['categories'] = [dict(
            id='guide', paths=['docs/guide.txt'], prefixes=[], suites=[self.suites[0]],
            groups=[], active=False, evidence=None)]
        self.catalog['impact']['non_suite_steps'] = [dict(job='optional', step='build', kind='build')]
        self.write('.github/workflows/test.yml', json.dumps(self.workflow))
        self.write('tests/verification-catalog.json', json.dumps(self.catalog))
        self.baseline = self.commit('synthetic A9 baseline')
        self.rule = IMPACT.rule_digest(self.catalog, self.workflow)
        self.full = IMPACT.make_plan(self.root, self.root, 'push', '123', 1,
                                     self.baseline, self.baseline)
        self.full_result = self.skipped_result(self.full, False)
        self.write('docs/guide.txt', 'deliberate broken input')
        self.mutation = self.commit('synthetic A9 mutation')
        self.mutation_plan = IMPACT.make_plan(self.root, self.root, 'push', '124', 1,
                                              self.mutation, self.mutation)
        self.mutation_result = self.skipped_result(self.mutation_plan, True)
        subprocess.run(['git', '-C', str(self.trusted), 'fetch', '-q', str(self.root), self.mutation], check=True)
        self.git('checkout', '-q', self.baseline)
        self.proof = dict(schema='verification-ci-activation/v1', category='guide',
            rule_sha256=self.rule, baseline_revision=self.baseline,
            full_plan=self.ref('proof/full-plan.json', self.full),
            full_result=self.ref('proof/full-result.json', self.full_result),
            consumer_inventory=self.ref('proof/consumers.json', dict(
                schema='verification-ci-consumers/v1', baseline_revision=self.baseline,
                rule_sha256=self.rule, consumers=[dict(input='docs/guide.txt',
                    suites=[self.suites[0]], groups=[], sources=[dict(path='docs/guide.txt',
                    sha256=hashlib.sha256(b'old\n').hexdigest())])])),
            mutation_evidence=self.ref('proof/mutations.json', dict(
                schema='verification-ci-mutations/v1', baseline_revision=self.baseline,
                rule_sha256=self.rule, cases=[dict(input='docs/guide.txt',
                    plan=self.ref('proof/mutation-plan.json', self.mutation_plan),
                    result=self.ref('proof/mutation-result.json', self.mutation_result))])))
        self.activate()

    def skipped_result(self, plan, failing):
        value = self.result(plan, failing)
        ids = {o['id'] for o in plan['obligations'] if o['job'] == 'a9-advisory'}
        for row in value['results']:
            if row['obligation_id'] in ids:
                row.update(status='EXPECTED_SKIP', reason='advisory-inactive',
                           job_id=None, source_attempt=None)
        return value

    def check_proof(self):
        return IMPACT.validate_activation(self.catalog['impact']['categories'][0], self.rule,
            self.root, self.base, self.catalog, self.workflow, self.full['obligations'])

    def check_result(self, value, plan=None, success=True, **context):
        return IMPACT.validate_result_binding(value, plan or self.full, success,
                                              root=self.root, workflow=self.workflow, **context)

    def test_inactive_skip_reaches_both_historical_proof_consumers(self):
        self.assertEqual(self.check_proof()['category'], 'guide')
        self.assertEqual(self.full['omissions'], [])
        self.assertEqual(len(self.full_result['results']), len(self.full['obligations']))
        self.assertEqual(self.plan()['mode'], 'affected')

    def test_inactive_all_pass_rows_cannot_bypass_context_guard(self):
        real_reader = IMPACT.read_reference
        def reader(root, revision, reference):
            value = real_reader(root, revision, reference)
            if reference['path'] in ('proof/full-result.json', 'proof/mutation-result.json'):
                for row in value['results']:
                    if row['status'] == 'EXPECTED_SKIP':
                        row.update(status='PASS', reason='verified', job_id=99, source_attempt=1)
            return value
        with patch.object(IMPACT, 'read_reference', side_effect=reader):
            with self.assertRaises(ValueError):
                self.check_proof()

    def test_skip_cannot_hide_mutation_failure_or_claim_executed_pass(self):
        real_reader = IMPACT.read_reference
        for path, kind in [('proof/full-result.json', 'pass'),
                           ('proof/mutation-result.json', 'pass'),
                           ('proof/mutation-result.json', 'hide-failure')]:
            def reader(root, revision, reference):
                value = real_reader(root, revision, reference)
                if reference['path'] == path:
                    for row in value['results']:
                        if kind == 'pass' and row['status'] == 'EXPECTED_SKIP':
                            row.update(status='PASS', reason='verified', job_id=99, source_attempt=1)
                        elif kind == 'hide-failure' and row['status'] == 'FAIL':
                            row.update(status='EXPECTED_SKIP', reason='advisory-inactive',
                                       job_id=None, source_attempt=None)
                return value
            with self.subTest(path=path, kind=kind), patch.object(IMPACT, 'read_reference', side_effect=reader):
                with self.assertRaises(ValueError):
                    self.check_proof()

    def test_row_fields_no_context_and_normal_records_stay_strict(self):
        ordinary = self.result(self.full, False)
        IMPACT.validate_result_binding(ordinary, self.full, True)
        with self.assertRaises(ValueError):
            IMPACT.validate_result_binding(self.full_result, self.full, True)
        self.check_result(self.full_result)
        index = next(i for i, row in enumerate(self.full_result['results']) if row['status'] == 'EXPECTED_SKIP')
        for field, value in [('reason', 'verified'), ('job_id', 1), ('source_attempt', 1),
                             ('job_id', True), ('status', 'NOT_SELECTED'), ('status', 'SKIP'),
                             ('obligation_id', 'a9-advisory:invented')]:
            bad = copy.deepcopy(self.full_result)
            bad['results'][index][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                self.check_result(bad)
        for index, original in enumerate(self.full_result['results']):
            if original['status'] == 'EXPECTED_SKIP':
                continue
            bad = copy.deepcopy(self.full_result)
            bad['results'][index].update(status='EXPECTED_SKIP', reason='advisory-inactive',
                                        job_id=None, source_attempt=None)
            with self.subTest(non_a9=original['obligation_id']), self.assertRaises(ValueError):
                self.check_result(bad)
        bad = copy.deepcopy(self.full_result)
        bad['results'] = bad['results'][:-1]
        with self.assertRaises(ValueError):
            self.check_result(bad)

    def test_independent_activation_binds_event_revisions_and_lexists(self):
        self.assertIs(W.a9_activation(self.root, self.full, self.workflow), False)
        self.git('checkout', '-q', self.baseline)
        # Presence in either exact tree activates PR A9, including a dangling leaf symlink.
        for kind in ('file', 'symlink', 'directory'):
            with self.subTest(kind=kind):
                self.git('checkout', '-q', self.baseline)
                path = self.root / 'sdd/project-context.yaml'
                path.parent.mkdir(exist_ok=True)
                if kind == 'symlink':
                    path.symlink_to('missing-target')
                elif kind == 'directory':
                    self.write('sdd/project-context.yaml/child', 'data')
                else:
                    self.write('sdd/project-context.yaml', 'data')
                present = self.commit('context presence ' + kind)
                for base, head in [(self.baseline, present), (present, self.baseline)]:
                    plan = copy.deepcopy(self.full)
                    plan.update(event='pull_request', api_head_sha=head, tested_revision=head,
                                base_revision=base, pr_head_revision=head, merge_base_revision=self.baseline)
                    self.assertIs(W.a9_activation(self.root, plan, self.workflow), True)
                    plan['plan_sha256'] = digest({k: v for k, v in plan.items() if k != 'plan_sha256'})
                    with self.assertRaises(ValueError):
                        self.check_result(self.skipped_result(plan, False), plan=plan)
        self.git('checkout', '-q', self.baseline)
        for event in ('push', 'merge_group', 'workflow_dispatch', 'release'):
            plan = {**self.full, 'event': event}
            self.assertIs(W.a9_activation(self.root, plan, self.workflow), False)
        for field, value in [('event', 'unknown'), ('tested_revision', '0' * 40),
                             ('api_head_sha', self.mutation), ('workflow_sha256', '0' * 64)]:
            with self.subTest(field=field), self.assertRaises(ValueError):
                W.a9_activation(self.root, {**self.full, field: value}, self.workflow)
        pr = {**self.full, 'event': 'pull_request'}
        with self.assertRaises(ValueError):
            W.a9_activation(self.root, pr, self.workflow)
        pr.update(base_revision=self.baseline, pr_head_revision=self.baseline,
                  merge_base_revision=self.baseline)
        self.assertIs(W.a9_activation(self.root, pr, self.workflow), False)
        for field in ('base_revision', 'pr_head_revision', 'merge_base_revision'):
            with self.subTest(field=field), self.assertRaises(ValueError):
                W.a9_activation(self.root, {**pr, field: '0' * 40}, self.workflow)

    def test_active_execution_and_exact_merge_context(self):
        self.git('checkout', '-q', self.baseline)
        self.write('sdd/project-context.yaml', 'active')
        head = self.commit('active exact PR head')
        active = {**self.full, 'event': 'pull_request', 'api_head_sha': head,
                  'tested_revision': head, 'pr_head_revision': head,
                  'base_revision': self.baseline, 'merge_base_revision': self.baseline}
        active['plan_sha256'] = digest({k: v for k, v in active.items() if k != 'plan_sha256'})
        self.check_result(self.result(active, False), plan=active)
        with self.assertRaises(ValueError):
            self.check_result(self.skipped_result(active, False), plan=active)
        self.git('checkout', '-q', self.baseline)
        self.git('commit', '--allow-empty', '-qm', 'base advances')
        base = self.git('rev-parse', 'HEAD')
        self.git('merge', '--no-ff', '-qm', 'synthetic tested merge', head)
        merge = self.git('rev-parse', 'HEAD')
        active.update(base_revision=base, tested_revision=merge)
        self.assertIs(W.a9_activation(self.root, active, self.workflow), True)
        with self.assertRaises(ValueError):
            W.a9_activation(self.root, {**active, 'base_revision': self.baseline}, self.workflow)
        wrong = copy.deepcopy(self.full)
        wrong['obligations'][-1]['step'] = 'renamed A9 obligation'
        with self.assertRaises(ValueError):
            self.check_result(self.full_result, plan=wrong)
        for context in ({'root': self.root}, {'workflow': self.workflow},
                        {'root': self.root, 'workflow': {'jobs': {}}}):
            with self.assertRaises(ValueError):
                IMPACT.validate_result_binding(self.full_result, self.full, True, **context)

    def test_ancestor_symlink_unknown_checkout_context_fails_closed(self):
        self.git('checkout', '-q', self.baseline)
        (self.root / 'sdd').symlink_to('outside-or-unknown')
        head = self.commit('unknown ancestor checkout semantics')
        plan = {**self.full, 'event': 'pull_request', 'api_head_sha': head,
                'tested_revision': head, 'base_revision': self.baseline,
                'pr_head_revision': head, 'merge_base_revision': self.baseline}
        with self.assertRaises(ValueError):
            W.a9_activation(self.root, plan, self.workflow)

    def test_same_job_name_and_unknown_workflow_never_grant_exception(self):
        changes = [lambda w: w['jobs']['a9-advisory'].update(**{'if': 'false'}),
                   lambda w: w['jobs']['a9-advisory-inputs']['steps'][-1].update(run='echo active=false'),
                   lambda w: w['jobs']['a9-advisory-inputs']['steps'][0]['with'].update(ref='main'),
                   lambda w: w['jobs']['a9-advisory']['steps'][-1].update(run='echo different workload'),
                   lambda w: w['jobs']['a9-advisory-inputs']['steps'][-1].update(**{'continue-on-error': True}),
                   lambda w: w.update(env={'A9_EVENT_NAME': 'push'}),
                   lambda w: w['jobs'].pop('a9-advisory-inputs')]
        for mutate in changes:
            self.git('checkout', '-q', self.baseline)
            workflow = copy.deepcopy(self.workflow)
            mutate(workflow)
            self.write('.github/workflows/test.yml', json.dumps(workflow))
            revision = self.commit('unknown A9 workflow semantics')
            plan = {**self.full, 'tested_revision': revision, 'api_head_sha': revision,
                    'workflow_sha256': hashlib.sha256((self.root / '.github/workflows/test.yml').read_bytes()).hexdigest()}
            with self.assertRaises(ValueError):
                W.a9_activation(self.root, plan, workflow)

    def test_comparison_schema_expresses_skip_and_executed_counterparts(self):
        schema = json.loads((ROOT / 'contracts/verification-ci-plan.schema.json').read_text())
        row = schema['$defs']['comparisonResult']['properties']['results']['items']
        self.assertEqual(set(row['properties']['status']['enum']), {'PASS', 'FAIL', 'EXPECTED_SKIP'})
        self.assertIn('advisory-inactive', row['properties']['reason']['enum'])
        self.assertEqual(row['properties']['job_id']['type'], ['integer', 'null'])
        self.assertEqual(row['properties']['source_attempt']['type'], ['integer', 'null'])
        self.assertTrue(row['allOf'], 'conditional status/reason/identity pairing is required')



def prepared_verifier(needs):
    """Fixed RT014 caller shape; protocol fixtures, not live workflow wiring."""
    return {'name': 'required-checks', 'runs-on': 'ubuntu-latest', 'if': 'always()',
            'needs': needs, 'timeout-minutes': 5,
            'permissions': {'contents': 'read', 'actions': 'read'}, 'steps': [
        {'name': 'Checkout exact tested revision',
         'uses': 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1',
         'with': {'ref': '${{ github.sha }}', 'fetch-depth': 0, 'persist-credentials': False}},
        {'name': 'Install structural YAML parser', 'shell': 'bash',
         'run': 'npm ci --prefix mcp/sdd-forge-mcp --ignore-scripts'},
        {'name': 'Download original same-run CI plan', 'shell': 'bash',
         'env': {'GH_TOKEN': '${{ github.token }}',
                 'PLAN_ARTIFACT_NAME': '${{ needs.ci-plan.outputs.plan_artifact_name }}'},
         'run': 'gh run download "$GITHUB_RUN_ID" --repo "$GITHUB_REPOSITORY" --name "$PLAN_ARTIFACT_NAME" --dir "$RUNNER_TEMP/verification-plan"'},
        {'name': 'Collect actual same-run execution observations', 'shell': 'bash',
         'env': {'GH_TOKEN': '${{ github.token }}'},
         'run': 'python3 -B tests/verification-ci.py collect --repository "$GITHUB_REPOSITORY" --run-id "$GITHUB_RUN_ID" --output-dir "$RUNNER_TEMP/verification-observations"'},
        {'name': 'Check all required tests passed', 'shell': 'bash',
         'env': {'API_HEAD_SHA': '${{ github.event.pull_request.head.sha || github.sha }}'},
         'run': 'python3 -B tests/verification-ci.py aggregate --root . --plan "$RUNNER_TEMP/verification-plan/plan.json" --observations "$RUNNER_TEMP/verification-observations" --run-id "$GITHUB_RUN_ID" --api-head-sha "$API_HEAD_SHA" --output "$RUNNER_TEMP/verification-result.json"'}]}


class PreparedVerifierTests(unittest.TestCase):
    def setUp(self):
        self.catalog = {'suites': [{'path': 'tests/sample.tests.py', 'runtime': 'python'}], 'profiles': {}}
        self.workflow = {'jobs': {
            'work': {'runs-on': 'ubuntu-latest', 'steps': [
                {'name': 'workload', 'run': 'python3 tests/sample.tests.py'}]},
            'ci-plan': {'runs-on': 'ubuntu-latest', 'steps': [
                {'name': 'Generate revision-bound plan', 'run': ('python3 -B tests/verification-impact.py --plan --root . --trusted-root . '
                        '--event push --run-id "$GITHUB_RUN_ID" --run-attempt "$GITHUB_RUN_ATTEMPT" '
                        '--api-head-sha "$GITHUB_SHA" --tested-revision "$GITHUB_SHA"')}]},
            'required-checks': prepared_verifier(['work', 'ci-plan'])}}

    def test_exact_preparation_is_control_with_all_projection_counterparts(self):
        W.verifier_job(self.workflow)
        obligations, controls = W.plan_inventory(self.workflow, self.catalog)
        self.assertEqual({row['job'] for row in obligations}, {'work', 'ci-plan'})
        self.assertEqual(len(controls), 4)
        self.assertEqual(W.control_dispositions(self.workflow, self.catalog), controls)
        self.assertEqual(W.plan_obligations(self.workflow, self.catalog), obligations)
        for step, row in zip(self.workflow['jobs']['required-checks']['steps'][1:], controls):
            identity = {'job': 'required-checks', 'matrix': {}, 'step': step['name']}
            command = {'run': step['run'], 'shell': 'bash', 'env': step.get('env', {})}
            self.assertEqual(row, {**identity, 'id': 'required-checks:' + digest(identity),
                'runner': 'ubuntu-latest', 'command_sha256': digest(command), 'suites': [],
                'receipt_required': False, 'disposition': 'orchestration-verifier'})
        self.assertTrue(W.aggregate_command(self.workflow['jobs']['required-checks']['steps'][-1]['run']))

    def test_live_workload_and_a9_inventory_survives_preparation(self):
        live = W.load_workflow(ROOT / '.github/workflows/test.yml', ROOT)
        catalog = json.loads((ROOT / 'tests/verification-catalog.json').read_text())
        before = W.plan_obligations(live, catalog)
        a9 = {name: copy.deepcopy(live['jobs'][name]) for name in ('a9-advisory', 'a9-advisory-inputs')}
        live['jobs']['ci-plan'] = self.workflow['jobs']['ci-plan']
        live['jobs']['required-checks'] = prepared_verifier([n for n in live['jobs'] if n != 'required-checks'])
        after, controls = W.plan_inventory(live, catalog)
        self.assertEqual([o for o in after if o['job'] != 'ci-plan'], before)
        self.assertEqual({n: live['jobs'][n] for n in a9}, a9)
        self.assertEqual(len(controls), 4)
        for step, row in zip(live['jobs']['required-checks']['steps'][1:], controls):
            self.assertEqual(row['command_sha256'], digest({'run': step['run'], 'shell': 'bash',
                'env': {**live['env'], **step.get('env', {})}}))
        self.assertEqual({o['runner'] for o in after if o['job'] == 'test'},
                         {'ubuntu-latest', 'macos-latest', 'windows-latest'})

    def test_every_preparation_field_order_and_hidden_work_mutation_is_rejected(self):
        def leaves(value, trail=()):
            if isinstance(value, dict):
                for key, item in value.items():
                    yield from leaves(item, trail + (key,))
            elif isinstance(value, list):
                for index, item in enumerate(value):
                    yield from leaves(item, trail + (index,))
            else:
                yield trail, value
        mutations = []
        for trail, value in leaves(self.workflow['jobs']['required-checks']):
            replacement = not value if isinstance(value, bool) else 1 if isinstance(value, int) else 'unexpected'
            bad = copy.deepcopy(self.workflow)
            target: Any = bad['jobs']['required-checks']
            for key in trail[:-1]:
                target = target[key]
            target[trail[-1]] = replacement
            mutations.append((str(trail), bad))
        # Supplemental typed-boundary checks after the original Red checkpoint.
        for field, values in [('fetch-depth', (False, 0.0, '0')),
                              ('persist-credentials', (0, 0.0, 'false'))]:
            for value in values:
                bad = copy.deepcopy(self.workflow)
                bad['jobs']['required-checks']['steps'][0]['with'][field] = value
                mutations.append((f'typed-checkout-{field}-{type(value).__name__}', bad))
        for value in (True, False, 5.0, '5'):
            bad = copy.deepcopy(self.workflow)
            bad['jobs']['required-checks']['timeout-minutes'] = value
            mutations.append((f'typed-timeout-{type(value).__name__}-{value}', bad))
        for index in range(5):
            for key in self.workflow['jobs']['required-checks']['steps'][index]:
                bad = copy.deepcopy(self.workflow)
                del bad['jobs']['required-checks']['steps'][index][key]
                mutations.append((f'delete-step-{index}-{key}', bad))
            for field, value in [('if', 'false'), ('continue-on-error', True),
                                 ('working-directory', 'other'), ('shell', 'bash -c {0}'),
                                 ('run', 'python3 tests/sample.tests.py'), ('extra', True),
                                 ('env', {'BASH_ENV': 'tests/sample.tests.py'})]:
                bad = copy.deepcopy(self.workflow)
                bad['jobs']['required-checks']['steps'][index][field] = value
                mutations.append((f'step-{index}-{field}', bad))
            for operation in ('duplicate', 'remove'):
                bad = copy.deepcopy(self.workflow)
                steps = bad['jobs']['required-checks']['steps']
                if operation == 'duplicate':
                    steps.insert(index, copy.deepcopy(steps[index]))
                else:
                    del steps[index]
                mutations.append((f'{operation}-{index}', bad))
        for left in range(5):
            for right in range(left + 1, 5):
                bad = copy.deepcopy(self.workflow)
                steps = bad['jobs']['required-checks']['steps']
                steps[left], steps[right] = steps[right], steps[left]
                mutations.append((f'reorder-{left}-{right}', bad))
        for index in range(1, 5):
            import shlex
            original = self.workflow['jobs']['required-checks']['steps'][index]['run']
            args = shlex.split(original)
            for position in range(len(args)):
                bad = copy.deepcopy(self.workflow)
                mutated = args.copy()
                mutated[position] = 'untrusted'
                bad['jobs']['required-checks']['steps'][index]['run'] = shlex.join(mutated)
                mutations.append((f'argv-{index}-{position}', bad))
            for suffix in ('\npython3 tests/sample.tests.py', '; true', ' | cat', ' && true',
                           ' > output', ' $(python3 tests/sample.tests.py)', ' `true`', ' --unexpected'):
                bad = copy.deepcopy(self.workflow)
                bad['jobs']['required-checks']['steps'][index]['run'] += suffix
                mutations.append((f'composed-{index}-{suffix}', bad))
        for scope in ('workflow', 'job', 'step'):
            for name in ('BASH_ENV', 'ENV', 'PYTHONPATH', 'PYTHONHOME', 'NODE_OPTIONS', 'PATH',
                         'GITHUB_RUN_ID', 'GITHUB_REPOSITORY', 'RUNNER_TEMP', 'GH_TOKEN', 'PLAN_ARTIFACT_NAME'):
                bad = copy.deepcopy(self.workflow)
                target = bad if scope == 'workflow' else bad['jobs']['required-checks']
                if scope == 'step':
                    target = target['steps'][1]
                target.setdefault('env', {})[name] = 'untrusted'
                mutations.append((f'env-{scope}-{name}', bad))
        for field, value in [('strategy', {'matrix': {'os': ['ubuntu-latest']}}),
                             ('continue-on-error', True), ('container', 'untrusted'),
                             ('services', {'hidden': {'image': 'untrusted'}}), ('unknown', True),
                             ('defaults', {'run': {'shell': 'bash', 'working-directory': 'other'}}),
                             ('needs', ['work']), ('needs', ['work', 'ci-plan', 'ci-plan']),
                             ('permissions', {'contents': 'write', 'actions': 'read'})]:
            bad = copy.deepcopy(self.workflow)
            bad['jobs']['required-checks'][field] = value
            mutations.append((f'job-{field}', bad))
        for defaults in ({'run': {'shell': 'pwsh'}}, {'run': {'working-directory': 'other'}}):
            bad = copy.deepcopy(self.workflow)
            bad['defaults'] = defaults
            mutations.append(('workflow-defaults', bad))
        bad = copy.deepcopy(self.workflow)
        bad['jobs']['required-checks']['steps'].insert(1, {'uses': 'actions/download-artifact@' + 'a' * 40})
        mutations.append(('extra-action', bad))
        for name, bad in mutations:
            for boundary in ('verifier', 'inventory'):
                with self.subTest(mutation=name, boundary=boundary), self.assertRaises(ValueError):
                    if boundary == 'verifier':
                        W.verifier_job(bad)
                    else:
                        W.plan_inventory(bad, self.catalog)
        self.assertGreater(len(mutations), 150)
        print('RT014 bounded mutation variants:', len(mutations), 'x 2 boundaries')

    def test_old_sole_aggregate_and_arbitrary_job_boundaries_remain(self):
        legacy = copy.deepcopy(self.workflow)
        job = legacy['jobs']['required-checks']
        job['steps'] = [job['steps'][-1]]
        self.assertEqual(len(W.control_dispositions(legacy, self.catalog)), 1)
        for body in ('python3 tests/sample.tests.py', job['steps'][0]['run'] + '\ntrue'):
            bad = copy.deepcopy(legacy)
            bad['jobs']['required-checks']['steps'][0]['run'] = body
            with self.assertRaises(ValueError):
                W.plan_inventory(bad, self.catalog)
        other = copy.deepcopy(self.workflow)
        other['jobs']['arbitrary'] = other['jobs'].pop('required-checks')
        self.assertIn('arbitrary', {o['job'] for o in W.plan_obligations(other, self.catalog)})
        self.assertEqual(W.control_dispositions(other, self.catalog), [])


class PreparedVerifierIntegrationTests(unittest.TestCase):
    def test_actual_collect_aggregate_has_no_control_completion_cycle(self):
        self.exercise_collection(prepared=True)

    def test_predecessor_collector_still_requires_actual_completion(self):
        self.exercise_collection(prepared=False)

    def exercise_collection(self, prepared):
        import contextlib
        import zipfile
        fixtures = module('ci_integration_existing_tests', 'verification-ci.tests.py')
        ci = module('ci_integration_collector', 'verification-ci.py')
        fixture = fixtures.AggregateFixture()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        fixture.workflow['jobs']['ci-plan'] = {'runs-on': 'ubuntu-latest', 'steps': [
            {'name': 'Generate revision-bound plan', 'run': ('python3 -B tests/verification-impact.py --plan --root . --trusted-root . '
                        '--event push --run-id "$GITHUB_RUN_ID" --run-attempt "$GITHUB_RUN_ATTEMPT" '
                        '--api-head-sha "$GITHUB_SHA" --tested-revision "$GITHUB_SHA"')}]}
        control = prepared_verifier(['test', 'ci-plan'])
        if not prepared:
            fixture.workflow['jobs']['collect'] = {'runs-on': 'ubuntu-latest', 'needs': ['test', 'ci-plan'],
                                                   'steps': [copy.deepcopy(control['steps'][3])]}
            control['needs'].append('collect')
            control['steps'] = [control['steps'][-1]]
        fixture.workflow['jobs']['required-checks'] = control
        fixture.write('.github/workflows/test.yml', json.dumps(fixture.workflow))
        fixture.revision = fixture.commit('synthetic RT014 collection topology')
        # Current W must admit the successor before any proof is synthesized.
        fixture.plan = fixtures.P.make_plan(fixture.root, fixture.root, 'push', '123', 1,
                                            fixture.revision, fixture.revision)
        with contextlib.redirect_stdout(io.StringIO()):
            fixture.receipt, code = fixtures.R.execute(fixtures.R.load_catalog(
                fixture.root / 'tests/verification-catalog.json', fixture.root),
                [fixture.suite], fixture.root, 'fixture')
        self.assertEqual(code, 0)
        fixture.api_run.update(head_sha=fixture.revision, status='in_progress', conclusion=None)
        for job in fixture.jobs:
            job['head_sha'] = fixture.revision
        fixture.receipts = [(j['id'], 1, copy.deepcopy(fixture.receipt), 'test',
                             {'os': j['labels'][0]}) for j in fixture.jobs]
        planner_job = copy.deepcopy(fixture.jobs[0])
        planner_job.update(id=199, name='ci-plan')
        planner_job['steps'] = [{**planner_job['steps'][0], 'name': 'Generate revision-bound plan'}]
        fixture.jobs.append(planner_job)
        running = dict(id=200, run_id=123, run_attempt=1, head_sha=fixture.revision,
            name='required-checks' if prepared else 'collect', labels=['ubuntu-latest'],
            runner_id=2000, runner_name='control-runner', status='in_progress', conclusion=None,
            started_at='2026-10-19T10:02:00Z', completed_at=None, steps=[dict(
                name='Collect actual same-run execution observations', number=4 if prepared else 1,
                status='in_progress', conclusion=None, started_at='2026-10-19T10:02:00Z', completed_at=None)])
        fixture.jobs.append(running)
        archives, artifacts = {}, []
        for index, (jid, attempt, receipt, job, matrix) in enumerate(fixture.receipts):
            raw = io.BytesIO()
            with zipfile.ZipFile(raw, 'w') as archive:
                archive.writestr('receipt.json', fixtures.P.canonical(receipt))
            artifacts.append(dict(id=300 + index, name=fixtures.receipt_name('123', attempt, job, matrix),
                expired=False, workflow_run={'id': 123, 'head_sha': fixture.revision}))
            archives[300 + index] = raw.getvalue()
        def request(endpoint):
            if endpoint.endswith('/runs/123'):
                return copy.deepcopy(fixture.api_run), {}
            if '/jobs?' in endpoint:
                return {'total_count': len(fixture.jobs), 'jobs': copy.deepcopy(fixture.jobs)}, {}
            return {'total_count': len(artifacts), 'artifacts': copy.deepcopy(artifacts)}, {}
        def archive_request(endpoint):
            return archives[int(endpoint.split('/artifacts/')[1].split('/')[0])], {}
        destination = fixture.scratch / 'actual-collection'
        with patch.object(ci, 'api_get', side_effect=request), patch.object(ci, 'api_response', side_effect=archive_request):
            ci.collect('owner/repo', '123', destination)
        result = ci.aggregate(fixture.root, fixture.plan, destination, '123', fixture.revision)
        self.assertEqual(len([r for r in result['results'] if r['status'] == 'PASS']), 7)
        if prepared:
            self.assertEqual(result['status'], 'PASS')
            self.assertEqual(len(result['results']), 7)
            self.assertFalse(fixture.plan['omissions'])
            self.assertFalse(any(r['obligation_id'].startswith('required-checks:') for r in result['results']))
        else:
            self.assertEqual(result['status'], 'FAIL')
            failed = [r for r in result['results'] if r['status'] == 'FAIL']
            self.assertEqual(len(failed), 1)
            self.assertTrue(failed[0]['obligation_id'].startswith('collect:'))
            self.assertEqual(failed[0]['reason'], 'evidence-missing')


if __name__ == '__main__':
    unittest.main()
