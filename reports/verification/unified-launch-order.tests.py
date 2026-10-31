"""Orchestration order only; no model process or canonical ledger is touched."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import uuid

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('launcher', ROOT / 'plugins/sdd-review-loop/scripts/launch-impl-review.py')
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class LaunchOrderTests(unittest.TestCase):
    def exercise(self, failure=None):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            session = str(uuid.uuid4())
            relative = 'reports/impl-review/demo/attempt-1/round-1/precheck-result.json'
            paths = [relative, 'invocation.json', 'bin',
                     'reports/verification/a7-nontty-impl-read-guard-probe-20261006.py',
                     'plugins/sdd-review-loop/agents/impl-reviewer-a.md']
            for name in paths:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('---\nname: impl-reviewer-a\n---\nRead only.')
            data = {'stage': 'impl', 'feature': 'demo', 'role': 'impl-reviewer-a',
                    'host_session_id': session, 'allowed_input_manifest': [{'path': relative}]}
            output = (root / relative).parent / ('launch-' + session)
            native = root / '.claude/projects' / (session + '.jsonl')
            native.parent.mkdir(parents=True)
            native.write_text('{}')
            events = []

            def run(_root, command, destination, prompt=None):
                event = destination.name
                events.append(event)
                if failure == event:
                    raise ValueError('injected failure')
                if event == 'native.jsonl':
                    if failure == 'drift':
                        (root / 'bin').write_text('changed')
                    return json.dumps({'admitted_read_executed': True,
                        'control_reads_executed': True,
                        'source_invocation_sha256': launcher.transport.sha(root / 'invocation.json') if failure != 'wrong-proof' else 'wrong',
                        'admitted_paths': [relative],
                        'outside_read_pretool_denied': True,
                        'chained_bash_pretool_denied': True, 'ordered_hashes_verified': 4})
                if event == 'preview-after.txt' and failure == 'receipt':
                    return 'different'
                destination.write_text('receipt')
                return 'receipt'

            def command(*args):
                if failure == 'unsupported-cli':
                    raise ValueError('unsupported CLI flag')
                return ['fake-claude']

            def preflight(*args):
                if failure == 'input':
                    raise ValueError('missing input')

            with patch.object(launcher.transport, 'manifest', return_value=(data, {})), \
                 patch.object(launcher.transport, 'preflight', side_effect=preflight), \
                 patch.object(launcher.transport, 'launch_policy', return_value=(b'{}', {})), \
                 patch.object(launcher.transport, 'receipt_control', return_value={'exact_permission_rules': []}), \
                 patch.object(launcher.transport, 'claude_command', side_effect=command), \
                 patch.object(launcher.transport, 'expected_prompt', return_value=b'prompt'), \
                 patch.object(launcher.transport, 'postflight', return_value={'delivery': 'ok'}), \
                 patch.object(launcher.shutil, 'which', return_value=str(root / 'bin')), \
                 patch.object(launcher, 'run', side_effect=run), \
                 patch.object(Path, 'home', return_value=root):
                if failure:
                    with self.assertRaises(ValueError):
                        launcher.launch(root, root / 'invocation.json', output)
                else:
                    self.assertEqual(launcher.launch(root, root / 'invocation.json', output), {'delivery': 'ok'})
                    with self.assertRaises(FileExistsError):
                        launcher.launch(root, root / 'invocation.json', output)
            return events

    def test_success_order_and_no_replay(self):
        self.assertEqual(self.exercise(), ['verify-before.txt', 'preview.txt', 'native.jsonl',
            'verify-after.txt', 'preview-after.txt', 'reserved.txt', 'wrapper.json'])

    def test_failures_before_reservation(self):
        for failure in ('input', 'unsupported-cli', 'verify-before.txt', 'preview.txt',
                        'native.jsonl', 'drift', 'wrong-proof', 'verify-after.txt', 'preview-after.txt', 'receipt'):
            with self.subTest(failure=failure):
                events = self.exercise(failure)
                self.assertNotIn('reserved.txt', events)
                self.assertNotIn('wrapper.json', events)

    def test_reservation_failure_never_launches(self):
        self.assertNotIn('wrapper.json', self.exercise('reserved.txt'))

    def test_conditional_input_is_not_silently_skipped(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'domain').mkdir()
            (root / 'domain/context-map.md').write_text('Domain-Model-Status: Approved')
            with self.assertRaisesRegex(ValueError, 'unsupported conditional dependency'):
                launcher.required_dependencies(root, {'allowed_input_manifest': []})
            with self.assertRaisesRegex(ValueError, 'unsupported conditional dependency'):
                launcher.required_dependencies(root, {
                    'allowed_input_manifest': [{'path': 'domain/context-map.md'}]})


if __name__ == '__main__':
    unittest.main()
