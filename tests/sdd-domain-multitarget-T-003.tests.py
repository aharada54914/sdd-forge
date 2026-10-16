#!/usr/bin/env python3
"""T-003 approved-boundary RED cases; all observations are synthetic fixtures."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'plugins/sdd-quality-loop/scripts'
EVALUATOR = SCRIPTS / 'evaluate-selected-plan.py'
sys.dont_write_bytecode = True
sys.path.insert(0, str(SCRIPTS))


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


resolver = load('t003_resolver', ROOT / 'specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-loop/scripts/resolve-project-context.py')
digest = load('t003_digest', SCRIPTS / 'generate-registry-digest.py')
legacy = load('t003_legacy', SCRIPTS / 'check-contract.py')
TARGETS = ('cli-library', 'ui', 'design-only', 'iac-cloud', 'low-code')


def fixture(target):
    registry = {'schema': 'capability-registry/v1', 'gates': [], 'capabilities': []}
    for name in TARGETS:
        registry['gates'].append({'id': name, 'stage': 'implementation', 'blocking': True, 'implementation_ref': 'verifier.py'})
        registry['capabilities'].append({
            'id': name,
            'trigger': {'scope': 'affected_component', 'field': 'artifact_kinds', 'operator': 'contains', 'value': name},
            'required_facets': [name], 'conditional_facets': [], 'review_check_ids': [],
            'gate_ids': [name, 'publish'], 'delivery_strategy': {'kind': 'manual'},
        })
    registry['gates'].append({'id': 'publish', 'stage': 'promotion', 'blocking': True})
    evaluations, warnings = [], []
    resolver._evaluate_capabilities(SCRIPTS, registry, ['component'],
                                    {'component': {'artifact_kinds': [target]}}, evaluations, warnings)
    binding = resolver._assemble_context_binding('sha256:' + '1' * 64, ['component'],
                'sha256:' + '2' * 64, 'sha256:' + digest.canonical_digest(registry), 'sha256:' + '3' * 64)
    manifest = resolver._assemble_facet_manifest('example', ['component'], registry, evaluations,
                binding, {'version': '1.0.0', 'rule_set_revision': 'sha256:' + '4' * 64})
    contract = {'schema': 'verification-contract/v2', 'task_id': 'T-003', 'risk': 'medium',
                'stack': 'spec', 'required_workflow': 'acceptance-first', 'checks': [
                    {'id': cid, 'required': True, 'passes': False, 'evidence': ''}
                    for cid in sorted(legacy.RISK_TIERS['medium'])]}
    return registry, manifest, contract


def passing_fixture(target):
    registry, manifest, contract = fixture(target)
    contract['checks'].append({'id': target, 'required': True})
    for check in contract['checks']:
        check.update(passes=True, evidence='evidence.log', command='fixture-verifier', exit_code=0,
                     started_at='2026-10-16T00:00:00Z', finished_at='2026-10-16T00:00:01Z')
    return registry, manifest, contract


class SelectedPlanTests(unittest.TestCase):
    def evaluate(self, registry, manifest, contract, verifier=True, evaluator=EVALUATOR):
        self.assertTrue(evaluator.is_file(), 'T-003 selected-plan evaluator is not implemented')
        with tempfile.TemporaryDirectory(prefix='t003-') as folder:
            root = Path(folder)
            for name, value in [('registry.json', registry), ('manifest.json', manifest), ('contract.json', contract)]:
                (root / name).write_text(json.dumps(value), encoding='utf-8')
            if verifier:
                (root / 'verifier.py').write_text('pass\n', encoding='utf-8')
            (root / 'evidence.log').write_text('Synthetic fixture verification succeeded.\n', encoding='utf-8')
            result = subprocess.run([sys.executable, str(evaluator), '--repo-root', str(root),
                '--registry', str(root / 'registry.json'), '--facet-manifest', str(root / 'manifest.json'),
                '--contract', str(root / 'contract.json'), '--output', str(root / 'plan.json')],
                capture_output=True, text=True, check=False, cwd=root)
            plan = json.loads((root / 'plan.json').read_text()) if (root / 'plan.json').exists() else None
            hashes = {key: hashlib.sha256((root / name).read_bytes()).hexdigest() for key, name in [
                ('facet_manifest_sha256', 'manifest.json'), ('registry_sha256', 'registry.json'),
                ('verification_contract_sha256', 'contract.json')]}
            return result, plan, hashes

    def assert_blocked(self, result, plan):
        self.assertNotEqual(result.returncode, 0)
        if plan is not None:
            self.assertEqual(plan['verdict'], 'BLOCKED')

    def test_five_target_candidate_selection(self):
        for target in TARGETS:
            with self.subTest(target=target):
                _, manifest, _ = fixture(target)
                self.assertEqual(manifest['capabilities'], [target])
                self.assertEqual(manifest['required_facets'], [target])
                self.assertEqual({g['id'] for g in manifest['resolved_gates']}, {target, 'publish'})

    def test_legacy_fixture_control(self):
        with tempfile.TemporaryDirectory(prefix='t003-control-') as folder:
            root = Path(folder)
            path = root / 'contract.json'
            (root / 'evidence.log').write_text('Synthetic fixture success.\n', encoding='utf-8')
            path.write_text(json.dumps(passing_fixture('ui')[2]), encoding='utf-8')
            task_id, failures = legacy.run(str(path), str(root))
            self.assertEqual(task_id, 'T-003')
            self.assertEqual(failures, [])

    def test_design_selection_is_not_gate_success(self):
        result, plan, _ = self.evaluate(*fixture('design-only'))
        self.assert_blocked(result, plan)
        self.assertIsNotNone(plan)
        self.assertTrue(any(c.get('reason') == 'migration-pending-required' for c in plan['checks']))

    def test_required_success_is_pass(self):
        for target in TARGETS:
            with self.subTest(target=target):
                result, plan, _ = self.evaluate(*passing_fixture(target))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(plan['verdict'], 'PASS')
                self.assertTrue(all(c['result'] == 'passed' for c in plan['checks']))

    def test_standalone_package_schema_and_evaluation(self):
        with tempfile.TemporaryDirectory(prefix='t003-package-') as folder:
            package = Path(folder).resolve()
            self.assertFalse(any((path / '.git').exists() for path in (package, *package.parents)))
            shutil.copytree(SCRIPTS, package / 'scripts', ignore=shutil.ignore_patterns('__pycache__'))
            shutil.copytree(SCRIPTS.parent / 'contracts', package / 'contracts')
            result, plan, _ = self.evaluate(*passing_fixture('ui'),
                evaluator=package / 'scripts' / EVALUATOR.name)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(plan['verdict'], 'PASS')
            name = 'selected-verification-plan.schema.json'
            self.assertEqual((package / 'contracts' / name).read_bytes(),
                             (ROOT / 'contracts' / name).read_bytes())

    def test_required_missing_observation(self):
        for target in TARGETS:
            with self.subTest(target=target):
                result, plan, _ = self.evaluate(*fixture(target))
                self.assert_blocked(result, plan)
                selected = next(c for c in plan['checks'] if c['id'] == target)
                self.assertEqual(selected['result'], 'not-run')
                self.assertEqual(selected['obligation'], 'required')

    def test_packaged_schema_identity_is_required(self):
        for name in ('selected-verification-plan.schema.json', 'capability-registry.schema.json'):
            for field in ('$id', '$schema'):
                with self.subTest(schema=name, field=field), tempfile.TemporaryDirectory(prefix='t003-schema-') as folder:
                    package = Path(folder)
                    shutil.copytree(SCRIPTS, package / 'scripts', ignore=shutil.ignore_patterns('__pycache__'))
                    shutil.copytree(SCRIPTS.parent / 'contracts', package / 'contracts')
                    target = package / 'contracts' / name
                    document = json.loads(target.read_text())
                    if field == '$id':
                        document[field] = 'https://invalid.example/wrong-schema'
                    else:
                        del document[field]
                    target.write_text(json.dumps(document))
                    result, plan, _ = self.evaluate(*passing_fixture('ui'),
                        evaluator=package / 'scripts' / EVALUATOR.name)
                    self.assert_blocked(result, plan)
                    self.assertIn('schema-identity-invalid', result.stderr)

    def test_output_identity_and_bindings(self):
        _, plan, hashes = self.evaluate(*fixture('cli-library'))
        self.assertEqual(plan['schema'], 'selected-verification-plan/v1')
        self.assertEqual((plan['feature'], plan['task_id']), ('example', 'T-003'))
        self.assertEqual(plan['bindings'], hashes)

    def test_legacy_required_not_removed(self):
        _, plan, _ = self.evaluate(*fixture('design-only'))
        checks = {c['id']: c for c in plan['checks']}
        for cid in legacy.RISK_TIERS['medium']:
            self.assertEqual(checks[cid]['obligation'], 'required')
            self.assertTrue(checks[cid]['blocking'])
            self.assertEqual(checks[cid]['applicability'], 'applicable')
            self.assertIn('legacy-contract', checks[cid]['sources'])

    def test_implementation_only_keeps_foundation_stages(self):
        args = fixture('iac-cloud')
        before = copy.deepcopy(args[1])
        _, plan, _ = self.evaluate(*args)
        self.assertEqual(args[1], before)
        self.assertIn('promotion', {g['stage'] for g in before['resolved_gates']})
        self.assertEqual({c['stage'] for c in plan['checks']}, {'implementation'})
        self.assertNotIn('publish', {c['id'] for c in plan['checks']})

    def test_registry_digest_mismatch(self):
        registry, manifest, contract = passing_fixture('ui')
        manifest['context_binding']['registry_digest'] = 'sha256:' + '0' * 64
        result, plan, _ = self.evaluate(registry, manifest, contract)
        self.assert_blocked(result, plan)

    def test_registry_projection_mismatch(self):
        registry, manifest, contract = passing_fixture('ui')
        manifest['resolved_gates'][0]['blocking'] = False
        result, plan, _ = self.evaluate(registry, manifest, contract)
        self.assert_blocked(result, plan)

    def test_duplicate_gate(self):
        registry, manifest, contract = passing_fixture('ui')
        manifest['resolved_gates'].append(copy.deepcopy(manifest['resolved_gates'][0]))
        result, plan, _ = self.evaluate(registry, manifest, contract)
        self.assert_blocked(result, plan)

    def test_evidence_escape(self):
        registry, manifest, contract = passing_fixture('low-code')
        contract['checks'][0].update(passes=True, evidence='../outside.txt')
        result, plan, _ = self.evaluate(registry, manifest, contract)
        self.assert_blocked(result, plan)

    def test_optional_unselected_na_and_selected_not_run(self):
        for target in TARGETS:
            with self.subTest(target=target):
                registry, manifest, contract = passing_fixture(target)
                contract['checks'].append({'id': 'optional-extra', 'required': False,
                    'passes': False, 'waiver_reason': 'Not selected by this target.'})
                result, plan, _ = self.evaluate(registry, manifest, contract)
                self.assertEqual(result.returncode, 0, result.stderr)
                extra = next(c for c in plan['checks'] if c['id'] == 'optional-extra')
                self.assertEqual((extra['obligation'], extra['applicability'], extra['result'], extra['reason']),
                    ('optional', 'not-applicable', 'not-applicable', 'legacy-optional-not-selected'))
                # A selected optional verifier is applicable even without observations.
                registry['gates'][TARGETS.index(target)]['blocking'] = False
                manifest['resolved_gates'] = sorted([
                    {k: g[k] for k in ('id', 'stage', 'blocking')}
                    for g in registry['gates'] if g['id'] in (target, 'publish')], key=lambda g: g['id'])
                manifest['context_binding']['registry_digest'] = 'sha256:' + digest.canonical_digest(registry)
                contract['checks'] = [c for c in contract['checks'] if c['id'] != target]
                result, plan, _ = self.evaluate(registry, manifest, contract)
                self.assertEqual(result.returncode, 0, result.stderr)
                selected = next(c for c in plan['checks'] if c['id'] == target)
                self.assertEqual((selected['obligation'], selected['applicability'], selected['result']),
                    ('optional', 'applicable', 'not-run'))

    def test_required_execution_states(self):
        for mutation, expected in (({'exit_code': None}, 'unknown'),
                ({'command': None}, 'not-run'), ({'passes': False, 'exit_code': 1}, 'failed'),
                ({'passes': True, 'exit_code': 1}, 'unknown'),
                ({'passes': False, 'exit_code': 0}, 'unknown')):
            with self.subTest(mutation=mutation):
                registry, manifest, contract = passing_fixture('ui')
                contract['checks'][-1].update(mutation)
                result, plan, _ = self.evaluate(registry, manifest, contract)
                self.assertNotEqual(result.returncode, 0)
                selected = next(c for c in plan['checks'] if c['id'] == 'ui')
                self.assertEqual(selected['result'], expected)
                self.assertEqual(plan['verdict'], 'NEEDS_WORK' if expected == 'failed' else 'BLOCKED')

    def test_verifier_unavailable(self):
        result, plan, _ = self.evaluate(*passing_fixture('ui'), verifier=False)
        self.assert_blocked(result, plan)
        selected = next(c for c in plan['checks'] if c['id'] == 'ui')
        self.assertEqual((selected['result'], selected['reason']), ('unavailable', 'migration-pending-required'))

    def test_required_cannot_be_downgraded_or_disappear(self):
        for mutation in ('downgrade', 'remove'):
            registry, manifest, contract = passing_fixture('design-only')
            for check in contract['checks']:
                if check['id'] == 'unit-tests':
                    check.update(required=False, passes=False, waiver_reason='target-unselected')
            if mutation == 'remove':
                contract['checks'] = [c for c in contract['checks'] if c['id'] != 'unit-tests']
            result, plan, _ = self.evaluate(registry, manifest, contract)
            self.assert_blocked(result, plan)
            row = next(c for c in plan['checks'] if c['id'] == 'unit-tests')
            self.assertEqual((row['obligation'], row['applicability']), ('required', 'applicable'))
            self.assertEqual(row['reason'], 'migration-pending-required')

    def test_nonimplementation_observation_cannot_be_relabelled(self):
        for stage in ('artifact', 'promotion'):
            registry, manifest, contract = passing_fixture('ui')
            registry['gates'][-1]['stage'] = stage
            next(g for g in manifest['resolved_gates'] if g['id'] == 'publish')['stage'] = stage
            manifest['context_binding']['registry_digest'] = 'sha256:' + digest.canonical_digest(registry)
            contract['checks'].append(dict(contract['checks'][-1], id='publish'))
            result, plan, _ = self.evaluate(registry, manifest, contract)
            self.assert_blocked(result, plan)
            self.assertIn('nonimplementation-observation', result.stderr)

    def test_manifest_cannot_drop_selected_registry_gate(self):
        registry, manifest, contract = passing_fixture('ui')
        manifest['resolved_gates'] = [g for g in manifest['resolved_gates'] if g['id'] != 'ui']
        result, plan, _ = self.evaluate(registry, manifest, contract)
        self.assert_blocked(result, plan)

    def test_persisted_field_mismatches_rejected(self):
        _, expected, _ = self.evaluate(*passing_fixture('ui'))
        evaluator = load('t003_evaluator', EVALUATOR)
        mutations = [(['schema'], 'selected-verification-plan/v0'), (['feature'], 'other'),
            (['task_id'], 'T-999'), (['verdict'], 'BLOCKED')]
        mutations += [(['bindings', key], '0' * 64) for key in expected['bindings']]
        mutations += [(['checks', 0, key], value) for key, value in {
            'id': 'other', 'sources': ['registry'], 'stage': 'promotion',
            'obligation': 'optional', 'blocking': False, 'applicability': 'not-applicable',
            'result': 'not-run', 'reason': 'legacy-optional-not-selected',
            'evidence_path': 'other.log'}.items()]
        self.assertEqual(evaluator.validate_plan(expected, expected), [])
        for path, value in mutations:
            with self.subTest(path=path):
                changed = copy.deepcopy(expected)
                node = changed
                for key in path[:-1]:
                    node = node[key]
                node[path[-1]] = value
                self.assertTrue(evaluator.validate_plan(changed, expected))

    def test_quality_gate_and_both_runners_invoke_evaluator(self):
        skill = (ROOT / 'plugins/sdd-quality-loop/skills/quality-gate/SKILL.md').read_text()
        self.assertIn('evaluate-selected-plan.py', skill)
        self.assertIn('--facet-manifest', skill)
        for name in ('run-all.sh', 'run-all.ps1'):
            self.assertIn('sdd-domain-multitarget-T-003.tests.py', (ROOT / 'tests' / name).read_text())


if __name__ == '__main__':
    unittest.main(verbosity=2)
