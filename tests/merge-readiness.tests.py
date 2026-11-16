import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('merge_readiness', ROOT / 'scripts/merge-readiness.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class ReadinessTests(unittest.TestCase):
    def setUp(self):
        self.pr = dict(state='open', draft=False, mergeable=True, mergeable_state='clean',
                       head={'sha':'a' * 40}, base={'sha':'b' * 40})
        self.result = dict(schema='verification-ci-result/v1', status='PASS', reason='verified', run_id='1',
                           api_head_sha='a' * 40, tested_revision='c' * 40, plan_sha256='d' * 64,
                           results=[dict(obligation_id='test', status='PASS', reason='verified', job_id=1, source_attempt=1)])

    def check(self, before=None, after=None, result=None, number=1):
        manifest = dict(repository='owner/repo', event_context={'pr_number':number, 'head_sha':'a' * 40, 'base_sha':'b' * 40})
        with (patch.object(m.ci, 'api_get', side_effect=[(before or self.pr, {}), (after or self.pr, {})]),
              patch.object(m.ci, 'read_json', side_effect=[manifest, {'schema':'test-plan'}]),
              patch.object(m.ci, 'aggregate', return_value=result or self.result) as aggregate):
            value = m.readiness(ROOT, 'owner/repo', 1, '1', Path('plan'), Path('observations'))
            self.assertEqual(aggregate.call_args.args[-1], (before or self.pr)['head']['sha'])
            return value

    def test_ready_requires_actual_aggregator_success(self):
        ready = self.check()
        self.assertEqual(ready['status'], 'ready')
        self.assertEqual(len(ready['evidenceSha256']), 64)
        failed = {**self.result, 'status':'FAIL', 'reason':'execution-failed',
                  'results':[{**self.result['results'][0], 'status':'FAIL', 'reason':'execution-failed'}]}
        self.assertEqual(self.check(result=failed)['status'], 'blocked')

    def test_commit_and_mergeability_changes_invalidate_readiness(self):
        for field, value in [('draft', True), ('mergeable', None), ('mergeable_state', 'blocked'), ('state', 'closed')]:
            with self.subTest(field=field):
                self.assertEqual(self.check(before={**self.pr, field:value})['status'], 'blocked')
                self.assertEqual(self.check(after={**self.pr, field:value})['status'], 'blocked')
        self.assertEqual(self.check(before={**self.pr, 'base':{'sha':'e' * 40}}, after={**self.pr, 'base':{'sha':'e' * 40}})['status'], 'blocked')
        self.assertEqual(self.check(after={**self.pr, 'head':{'sha':'e' * 40}})['status'], 'blocked')
        self.assertEqual(self.check(after={**self.pr, 'base':{'sha':'e' * 40}})['status'], 'blocked')

    def test_evidence_must_identify_same_pr(self):
        with self.assertRaises(ValueError):
            self.check(number=2)
        with patch.object(m.ci, 'api_get', side_effect=ValueError('offline')):
            with self.assertRaises(ValueError):
                m.readiness(ROOT, 'owner/repo', 1, '1', Path('plan'), Path('observations'))


if __name__ == '__main__':
    unittest.main()
