"""Post-implementation differential reproduction, never pre-implementation TDD proof."""
import hashlib
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[5]
BASE = ROOT / 'reports/verification/shared-launch-handoff/T-001-compact-runtime-rollback-20261009/checkout'
source = BASE / 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py'
assert hashlib.sha256(source.read_bytes()).hexdigest() == '18dc0655daf286053ce884809a3aa0d935140d094b3d8521a0592b0d913f0bca'
spec = importlib.util.spec_from_file_location('current_tests', ROOT / 'tests/quality-nontty-transport.tests.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
old_spec = importlib.util.spec_from_file_location('old_transport', source)
old = importlib.util.module_from_spec(old_spec)
old_spec.loader.exec_module(old)
# Adapt only the added fixture-root argument; retain the original behavior.
old_receipt_control = old.receipt_control
old.receipt_control = lambda data, receipt, invocation, root=None: old_receipt_control(data, receipt, invocation)
module.ROOT, module.SOURCE, module.TRANSPORT = BASE, source, old
suite = unittest.TestSuite([module.QualityTransport('test_compact_command_verifies_all_640_inputs_and_rejects_mutations')])
result = unittest.TextTestRunner(verbosity=2).run(suite)
raise SystemExit(0 if result.wasSuccessful() else 1)
