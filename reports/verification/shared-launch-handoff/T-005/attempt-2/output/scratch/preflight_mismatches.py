import importlib.util
from pathlib import Path
import tempfile
import unittest

root = Path(__file__).resolve().parents[1] / 'work'
spec = importlib.util.spec_from_file_location('order', root / 'tests/unified-launch-order.tests.py')
order = importlib.util.module_from_spec(spec)
spec.loader.exec_module(order)
launcher = order.launcher

class PersistedMismatch(unittest.TestCase):
    def test_raw_invocation_pin(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            invocation = root / 'invocation.json'
            invocation.write_text('{}')
            launcher.launch(root, invocation, root / 'output', '0' * 64)

    def test_input_hash(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'requirements.md').write_text('actual input')
            launcher.transport.admitted_raw_hashes(root, {'stage': 'spec',
                'allowed_input_manifest': [{'path': 'requirements.md', 'sha256': '0' * 64}]})

    def test_reserved_identity_receipt(self):
        data = dict(stage='task', role='task-reviewer-a', feature='demo',
                    sequence=2, run_id='fixture-run', host_session_id='fixture-session',
                    previous_record_sha256='a' * 64,
                    allowed_input_manifest=[{'path': 'specs/demo/tasks.md', 'sha256': 'c' * 64}])
        receipt = ('REVIEW_CONTEXT_OK ' + 'b' * 64 + ' sequence=2 previous_record_sha256=' +
                   'a' * 64 + ' pre_append_tip_sequence=1 identity_unique=yes\n')
        launcher.transport.receipt_control(data, receipt)

unittest.main()
