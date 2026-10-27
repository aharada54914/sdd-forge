#!/usr/bin/env python3
"""Negative/control coverage for golden artifact graders and passive comparison."""
import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location('golden', Path(__file__).with_name('golden-eval.py'))
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
NAMES = sorted(p.name for p in M.CASES.iterdir() if (p / 'case.json').is_file())


class GoldenTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def good(self, name, target):
        prepared = M.prepare(name, target)
        data = M.case(name)
        for rel in data.get('absent', []):
            (target / rel).unlink()
        for rel, value in data['expected'].items():
            (target / rel).write_bytes(M.encoded(value))
        return prepared

    def test_all_registered_controls_and_bad_outputs(self):
        self.assertEqual(set(NAMES), {'unrun-pass', 'wrong-routing', 'weak-cleanup',
                                     'overbroad-validation', 'stale-skill',
                                     'bundled-audit-readiness', 'cancelled-result-fencing'})
        for name in NAMES:
            with self.subTest(name=name):
                out = self.root / name
                self.good(name, out)
                self.assertTrue(M.grade(name, out)['pass'])
                data = M.case(name)
                if data['expected']:
                    path = out / next(iter(data['expected']))
                    path.write_text('{}')
                else:
                    (out / data['absent'][0]).write_text('not cleaned')
                self.assertFalse(M.grade(name, out)['pass'])

    def test_claimed_pass_is_not_artifact_evidence(self):
        out = self.root / 'out'
        M.prepare('unrun-pass', out)
        (out / 'PASS').write_text('PASS')
        self.assertFalse(M.grade('unrun-pass', out)['pass'])

    def test_source_mutation_fails(self):
        out = self.root / 'out'
        self.good('stale-skill', out)
        (out / 'pending/SKILL.md').write_text('overwrite')
        self.assertFalse(M.grade('stale-skill', out)['pass'])

    def test_cleanup_cannot_remove_retained_evidence(self):
        out = self.root / 'out'
        self.good('weak-cleanup', out)
        (out / 'retained/evidence.txt').unlink()
        self.assertFalse(M.grade('weak-cleanup', out)['pass'])

    def test_symlink_artifact_rejected(self):
        out = self.root / 'out'
        self.good('unrun-pass', out)
        outside = self.root / 'correct.json'
        path = out / 'assessment.json'
        path.rename(outside)
        path.symlink_to(outside)
        self.assertFalse(M.grade('unrun-pass', out)['pass'])

    def test_duplicate_json_rejected(self):
        out = self.root / 'out'
        self.good('wrong-routing', out)
        (out / 'route.json').write_text('{"category":"wrong","category":"measurement","meta_change":true}')
        self.assertFalse(M.grade('wrong-routing', out)['pass'])

    def test_json_string_cannot_impersonate_object(self):
        out = self.root / 'out'
        self.good('wrong-routing', out)
        expected = M.case('wrong-routing')['expected']['route.json']
        (out / 'route.json').write_text(json.dumps(M.encoded(expected).decode()))
        self.assertFalse(M.grade('wrong-routing', out)['pass'])

    def test_no_metadata_or_rubric_in_candidate(self):
        out = self.root / 'out'
        M.prepare('unrun-pass', out)
        self.assertEqual({p.name for p in out.iterdir()}, {'input.md', 'audit.json', 'output-contract.schema.json'})
        contract = json.loads((out / 'output-contract.schema.json').read_text())
        self.assertEqual(contract['properties']['process_status']['enum'], ['complete', 'incomplete'])
        self.assertNotIn('invalid JSON detected', json.dumps(contract))
        self.assertNotIn('tuning', (out / 'input.md').read_text())
        with self.assertRaises(ValueError):
            M.prepare('unrun-pass', out)

    def manifest(self):
        conditions = dict(model='fixed-model/version', effort='fixed', host='fixture-host/version', tool_permissions='fixture-only')
        data = dict(schema='golden-comparison/v1', cases=['unrun-pass'], repetitions=3,
                    timeout_seconds=10, total_seconds_limit=60, conditions=conditions,
                    case_sha256={}, input_sha256={}, runs=[],
                    variants={v: dict(framework_revision='fixture-'+v,config_sha256='a'*64,adapter_version='fixture-v1') for v in ('A','B')})
        for n in range(1, 4):
            for variant in ('A', 'B') if n % 2 else ('B', 'A'):
                rel = f'{variant}-{n}'
                prepared = self.good('unrun-pass', self.root / rel)
                data['case_sha256']['unrun-pass'] = prepared['case_sha256']
                data['input_sha256']['unrun-pass'] = prepared['initial_tree_sha256']
                trace = self.root / (rel + '.trace.json')
                trace.write_text(json.dumps({'fixture': True, 'note': 'synthetic test data, not real model execution', 'artifacts': ['assessment.json']}))
                data['runs'].append(dict(case='unrun-pass',variant=variant,repetition=n,
                    trace=trace.name,trace_sha256=M.digest(trace.read_bytes()),
                    seconds=n,status='completed',conditions=conditions,
                    input_sha256=prepared['initial_tree_sha256'], output=rel,
                    output_sha256=M.snapshot(self.root / rel), safety_violation=False,
                    required_regression=False, tokens=None, tokens_unavailable_reason='not observed',
                    cost=None, cost_unavailable_reason='not observed'))
        return data

    def compare(self, data):
        path = self.root / 'experiment.json'
        path.write_text(json.dumps(data))
        return M.compare(path)

    def test_comparison_denominators_medians_and_no_promotion(self):
        result = self.compare(self.manifest())
        self.assertEqual(result['groups']['A']['k'], 3)
        self.assertFalse(result['adoption_eligible'])
        self.assertTrue(result['mechanical_criteria_satisfied'])
        self.assertEqual(result['groups']['B']['median_seconds'], 2)
        self.assertEqual(result['adoption_decision'], 'pending-human')
        self.assertIsNone(result['groups']['A']['p95'])

    def test_missing_and_duplicate_trials_rejected(self):
        data = self.manifest()
        for changed in (dict(data, runs=data['runs'][:-1]), dict(data, runs=data['runs'] + [data['runs'][0]])):
            with self.assertRaises(ValueError):
                self.compare(changed)

    def test_interrupted_and_unrun_retained(self):
        data = self.manifest()
        data['runs'][0]['status'] = 'interrupted'
        data['runs'][1]['status'] = 'not-run'
        data['runs'][1]['seconds'] = 0
        result = self.compare(data)
        self.assertEqual(result['groups']['A']['n'], 3)
        self.assertEqual(result['groups']['A']['k'], 2)
        self.assertEqual(result['groups']['B']['n'], 3)
        self.assertFalse(result['mechanical_criteria_satisfied'])

    def test_each_safety_violation_or_regression_refuses(self):
        data = self.manifest()
        for key in ('safety_violation', 'required_regression'):
            altered = copy.deepcopy(data)
            altered['runs'][0][key] = True
            self.assertFalse(self.compare(altered)['mechanical_criteria_satisfied'])

    def test_budget_and_timeout_refuse(self):
        data = self.manifest()
        self.assertFalse(self.compare(dict(data, total_seconds_limit=1))['mechanical_criteria_satisfied'])
        self.assertFalse(self.compare(dict(data, timeout_seconds=1))['mechanical_criteria_satisfied'])

    def test_stale_rubric_and_output_refused(self):
        data = self.manifest()
        altered = copy.deepcopy(data)
        altered['case_sha256']['unrun-pass'] = '0' * 64
        with self.assertRaises(ValueError):
            self.compare(altered)
        (self.root / data['runs'][0]['output'] / 'assessment.json').write_text('{}')
        with self.assertRaises(ValueError):
            self.compare(data)

    def test_conditions_input_and_unknown_metrics_required(self):
        data = self.manifest()
        for field, value in [('conditions', {}), ('input_sha256','bad'), ('cost_unavailable_reason','')]:
            altered = copy.deepcopy(data)
            altered['runs'][0][field] = value
            with self.assertRaises(ValueError):
                self.compare(altered)

    def test_tool_trace_missing_or_tampered_rejected(self):
        data = self.manifest()
        trace = self.root / data['runs'][0]['trace']
        trace.write_text('changed')
        with self.assertRaises(ValueError):
            self.compare(data)
        trace.unlink()
        with self.assertRaises(ValueError):
            self.compare(data)

    def test_malformed_objects_rejected(self):
        for value in ([], None, 'text'):
            with self.assertRaises(ValueError):
                self.compare(value)
        data = self.manifest()
        for field, value in [('runs', [None]), ('case_sha256', []), ('input_sha256', [])]:
            with self.assertRaises(ValueError):
                self.compare(dict(data, **{field: value}))

    def test_ancestor_symlink_output_rejected(self):
        data = self.manifest()
        link = self.root / 'linked'
        link.symlink_to(self.root, target_is_directory=True)
        data['runs'][0]['output'] = 'linked/' + data['runs'][0]['output']
        with self.assertRaises(ValueError):
            self.compare(data)

    def test_boolean_or_nonfinite_duration_rejected(self):
        data = self.manifest()
        for value in (True, float('nan'), -1):
            altered = copy.deepcopy(data)
            altered['runs'][0]['seconds'] = value
            with self.assertRaises(ValueError):
                self.compare(altered)


if __name__ == '__main__':
    unittest.main()
