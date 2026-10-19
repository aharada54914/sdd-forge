#!/usr/bin/env python3
"""Revision-bound planning fixtures; none are hosted execution evidence."""
import copy
import hashlib
import importlib.util
import io
import json
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

    def test_mandatory_identity_and_optional_revision_failures(self):
        for values in (dict(run_id=''), dict(run_id='0'), dict(run_attempt=0),
                       dict(api_head_sha=''), dict(tested_revision='f' * 40),
                       dict(event='PUSH')):
            with self.subTest(values=values), self.assertRaises(ValueError):
                self.plan(**values)
        for optional_values in (dict(base=None), dict(base='e' * 40), dict(head='d' * 40),
                       dict(head=self.base), dict(api_head_sha=self.base)):
            with self.subTest(values=optional_values):
                self.assertEqual(self.plan(**optional_values)['mode'], 'full')

    def test_merge_parents_and_api_head_are_separate(self):
        self.git('checkout', '-qb', 'base-side', self.base)
        self.write('base-side.txt', 'base side')
        new_base = self.commit('base side')
        self.git('merge', '--no-ff', '-m', 'merge', self.head)
        merge = self.git('rev-parse', 'HEAD')
        p = self.plan(base=new_base, tested_revision=merge)
        self.assertEqual(p['api_head_sha'], self.head)
        self.assertEqual(p['tested_revision'], merge)
        self.assertEqual(p['merge_base_revision'], self.base)
        self.assertEqual(self.plan(tested_revision=merge)['mode'], 'full')

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

    def test_selection_executes_trusted_checkout_not_caller_imports(self):
        with patch.object(IMPACT, 'workflow_module', side_effect=AssertionError('caller imported')):
            p = self.plan()
        self.assertEqual(p['mode'], 'affected')
        (self.root / 'tests/verification-workflow.py').write_text('raise RuntimeError("PR import")')
        self.head = self.commit('PR-controlled planner import')
        self.assertEqual(self.plan()['mode'], 'full')

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

if __name__ == '__main__':
    unittest.main()
