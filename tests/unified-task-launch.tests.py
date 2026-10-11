"""Task transport delegates normalization; no native host or ledger is used."""
import importlib.util
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace
import uuid

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('task_transport', ROOT / 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py')
transport = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transport)
order_spec = importlib.util.spec_from_file_location('task_order_fixture', ROOT / 'tests/unified-launch-order.tests.py')
order = importlib.util.module_from_spec(order_spec)
order_spec.loader.exec_module(order)


class TaskOrder(unittest.TestCase):
    def test_task_full_order_and_replay(self):
        fixture = order.LaunchOrderTests()
        self.assertEqual(fixture.exercise(stage='task'), [
            'common-input-preflight', 'precheck-before-output', 'verify-before.txt', 'preview.txt', 'native.jsonl',
            'verify-after.txt', 'preview-after.txt', 'reserved.txt', 'wrapper.json'])

    def test_task_pre_reservation_failures_leave_ledger_unchanged(self):
        fixture = order.LaunchOrderTests()
        for failure in ('input', 'allocation-exists', 'preflight-exists', 'unsupported-cli',
                        'verify-before.txt', 'preview.txt', 'native.jsonl', 'drift',
                        'wrong-proof', 'source-not-read', 'collision-not-rejected',
                        'verify-after.txt', 'preview-after.txt', 'receipt',
                        'missing-required', 'extra-path', 'unsafe-path', 'absolute-path',
                        'duplicate-path', 'case-alias', 'symlink-path',
                        'early-precheck', 'precheck-drift'):
            with self.subTest(failure=failure):
                events = fixture.exercise(failure, stage='task')
                self.assertNotIn('reserved.txt', events)
                self.assertNotIn('wrapper.json', events)

    def test_task_reservation_failure_prevents_launch(self):
        self.assertNotIn('wrapper.json', order.LaunchOrderTests().exercise('reserved.txt', stage='task'))


class TaskOutputIdentity(unittest.TestCase):
    def postflight(self, role, stage, output_role, session='task-session'):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            files = [root / name for name in ('prompt', 'transcript', 'wrapper')]
            for file in files:
                file.write_text('fixture')
            data = dict(stage='task', role=role, host_session_id='task-session')
            output = dict(stage=stage, role=output_role, run_id=session, host_session_id=session)
            with patch.object(transport, 'native_delivery', return_value=(
                    data, {'result': json.dumps(output)}, [])):
                return transport.postflight(root, root / 'invocation', files[1],
                                            files[0], files[2], root / 'receipt')

    def test_canonical_a_and_b_output(self):
        for role, stage, output_role in (
                ('task-reviewer-a', 'task-review', 'reviewer-a'),
                ('task-reviewer-b', 'task', 'task-reviewer-b')):
            with self.subTest(role=role):
                self.assertEqual(self.postflight(role, stage, output_role)['status'], 'DELIVERY_OK')

    def test_cross_role_wrong_stage_and_session_rejected(self):
        for args in (
                ('task-reviewer-a', 'task', 'task-reviewer-b'),
                ('task-reviewer-b', 'task-review', 'reviewer-a'),
                ('task-reviewer-b', 'task-review', 'task-reviewer-b'),
                ('task-reviewer-a', 'task', 'reviewer-a'),
                ('task-reviewer-b', 'task', 'task-reviewer-b', 'other-session')):
            with self.subTest(args=args), self.assertRaisesRegex(ValueError, 'identity mismatch'):
                self.postflight(*args)


class TaskHashes(unittest.TestCase):
    def test_task_receipt_uses_canonical_six_field_record(self):
        session = str(uuid.uuid4())
        data = {'stage': 'task', 'role': 'task-reviewer-b', 'feature': 'demo',
                'sequence': 2, 'run_id': session, 'host_session_id': session,
                'previous_record_sha256': 'a' * 64,
                'allowed_input_manifest': [{'path': 'specs/demo/tasks.md',
                                            'sha256': 'b' * 64}]}
        plain = '|'.join(('2', 'task', 'task-reviewer-b', session, session, 'a' * 64))
        digest = hashlib.sha256(plain.encode()).hexdigest()
        receipt = (f'REVIEW_CONTEXT_OK {digest} sequence=2 '
                   f'previous_record_sha256={"a" * 64} pre_append_tip_sequence=1 '
                   'identity_unique=yes\n')
        self.assertEqual(transport.receipt_control(data, receipt)['record_text'], plain)
        suffixed = plain + '|allowed-inputs-v1|' + 'c' * 64
        stale = receipt.replace(digest, hashlib.sha256(suffixed.encode()).hexdigest())
        with self.assertRaisesRegex(ValueError, 'receipt record hash mismatch'):
            transport.receipt_control(data, stale)

    def fixture(self, root):
        task = root / 'specs/demo/tasks.md'
        task.parent.mkdir(parents=True)
        task.write_text('Approval: Approved\nStatus: In Progress\n')
        precheck = root / 'reports/task-review/demo/attempt-1/round-1/precheck-result.json'
        precheck.parent.mkdir(parents=True)
        precheck.write_text(json.dumps(dict(schema='task-review-precheck/v1', feature='demo',
            attempt=1, round=1, tasks_sha256_form='normalized', tasks_sha256='a' * 64)))
        return dict(stage='task', feature='demo', allowed_input_manifest=[
            dict(path=task.relative_to(root).as_posix(), sha256='a' * 64),
            dict(path=precheck.relative_to(root).as_posix(), sha256=transport.sha(precheck))])

    def test_normalized_delegation_and_raw_observation(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data = self.fixture(root)
            with patch.object(transport.subprocess, 'run', return_value=SimpleNamespace(returncode=0)) as run:
                actual = transport.admitted_raw_hashes(root, data)
            self.assertNotEqual(actual['specs/demo/tasks.md'], 'a' * 64)
            self.assertEqual(run.call_args.args[0][-4:], ['demo', '1', '1', '--verify-inputs'])
            self.assertEqual(data['allowed_input_manifest'][0]['sha256'], 'a' * 64)

    def test_rejects_canonical_failure_and_concurrent_change(self):
        for change in (False, True):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                data = self.fixture(root)
                def verify(*args, **kwargs):
                    if change:
                        (root / 'specs/demo/tasks.md').write_text('changed')
                    return SimpleNamespace(returncode=0 if change else 1)
                with patch.object(transport.subprocess, 'run', side_effect=verify):
                    with self.assertRaises(ValueError):
                        transport.admitted_raw_hashes(root, data)

    def test_other_stage_cannot_normalize(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data = self.fixture(root)
            data['stage'] = 'impl'
            with self.assertRaises(ValueError):
                transport.admitted_raw_hashes(root, data)


if __name__ == '__main__':
    unittest.main()
