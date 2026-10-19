#!/usr/bin/env python3
"""Revision-bound planning fixtures; none are hosted execution evidence."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tests' / filename)
    assert spec and spec.loader
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


I = module('impact', 'verification-impact.py')
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
        I.validate_plan(expected, expected=expected)
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
                    I.validate_plan(bad, expected=expected)
        with self.assertRaises(ValueError):
            I.validate_plan({**expected, 'plan_sha256': '0' * 64}, expected=expected)

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
                I.validate_plan(expected, expected=expected)
                with self.assertRaises(ValueError):
                    I.validate_plan(bad, expected=expected)
        # Sensitivity: replacing the boundary with a no-op really loses rejection.
        with patch.object(I, 'validate_plan', return_value=None):
            with self.assertRaises(AssertionError):
                with self.assertRaises(ValueError):
                    I.validate_plan(bad, expected=expected)

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
        I.validate_plan(expected, expected=expected)
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
                    I.validate_plan(self.signed(bad), expected=expected)
        for field in ('omissions', 'activation_evidence'):
            bad = copy.deepcopy(expected)
            bad[field].append(bad[field][0])
            with self.assertRaises(ValueError):
                I.validate_plan(self.signed(bad))

    def test_fixed_condition_outputs_and_collision_rejection(self):
        plan = self.signed(sample_plan())
        self.assertEqual(I.condition_outputs(plan, ['test', 'optional-group']),
                         {'run_test': 'true', 'run_optional_group': 'false'})
        for groups in (['test', 'test'], ['test', 'bad\nkey'], ['test', 'a-b', 'a_b']):
            with self.assertRaises(ValueError):
                I.condition_outputs(plan, groups)

    def test_strict_json_schema_and_duplicate_unsafe_inputs(self):
        good = self.signed(sample_plan())
        I.validate_plan(good)
        for text in ('{"x":1,"x":2}', '{"x":NaN}', '{"x":Infinity}', '[]', '{} {}'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                I.strict_json(text)
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
                I.validate_plan(self.signed(bad))
        schema = json.loads((ROOT / 'contracts/verification-ci-plan.schema.json').read_text())
        self.assertEqual(set(schema['required']), set(good))
        self.assertIs(schema['additionalProperties'], False)


class PlanningTests(unittest.TestCase):
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
        self.catalog = dict(schema='verification-catalog/v1',
                            suites=[dict(path=p, runtime='python') for p in self.suites],
                            profiles={'fixture': self.suites},
                            impact=dict(schema='verification-impact-rules/v1', categories=[],
                                        dependencies={self.suites[0]: [self.suites[1]],
                                                      self.suites[2]: [self.suites[3]]}))
        self.workflow = {'jobs': {
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
        return I.make_plan(**args)

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
        for values in (dict(base=None), dict(base='e' * 40), dict(head='d' * 40),
                       dict(head=self.base), dict(api_head_sha=self.base)):
            with self.subTest(values=values):
                self.assertEqual(self.plan(**values)['mode'], 'full')

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
        paths, status = I.changed_paths(self.root, start, end)
        self.assertEqual(status, 'diff-available')
        self.assertEqual(paths, names | {'Old.txt', 'old.txt', 'type.txt', 'docs/guide.txt'} |
                         {f'many/{n:04}.txt' for n in range(3001)})
        self.assertFalse((self.root / 'forbidden').exists())

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

    def test_dependency_and_indivisible_step_fixed_point(self):
        obligations = W.plan_obligations(self.workflow, self.catalog)
        selected = I.dependency_closure({self.suites[0]}, set(), self.catalog, obligations)
        self.assertEqual(selected, set(self.suites))
        self.catalog['impact']['dependencies'][self.suites[0]] = ['tests/missing.tests.py']
        with self.assertRaises(ValueError):
            I.dependency_closure({self.suites[0]}, set(), self.catalog, obligations)

    def test_definition_hash_excludes_proof_pointers_not_command_definitions(self):
        category = dict(id='guide', paths=['docs/guide.txt'], prefixes=[],
                        suites=[self.suites[0]], groups=[], active=False, evidence=None)
        self.catalog['impact']['categories'] = [category]
        original = I.rule_digest(self.catalog, self.workflow)
        category['active'] = True
        category['evidence'] = {'path': 'proof.json', 'sha256': '0' * 64}
        self.assertEqual(I.rule_digest(self.catalog, self.workflow), original)
        self.write('docs/guide.txt', 'ordinary product edit')
        self.assertEqual(I.rule_digest(self.catalog, self.workflow), original)
        category['suites'] = [self.suites[1]]
        self.assertNotEqual(I.rule_digest(self.catalog, self.workflow), original)

    def test_cli_explicit_plan_and_create_only_output(self):
        output = Path(self.temp.name) / 'plan.json'
        command = [sys.executable, '-B', str(ROOT / 'tests/verification-impact.py'), '--plan',
                   '--root', str(self.root), '--trusted-root', str(self.trusted),
                   '--event', 'push', '--run-id', '123', '--run-attempt', '1',
                   '--api-head-sha', self.head, '--tested-revision', self.head,
                   '--output', str(output)]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), json.loads(output.read_text()))
        self.assertEqual(subprocess.run(command, capture_output=True).returncode, 2)


if __name__ == '__main__':
    unittest.main()
