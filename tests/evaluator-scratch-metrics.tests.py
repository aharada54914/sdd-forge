"""Count reserved evaluator identities, not copies of invocation files."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "scripts/measure-evaluator-scratch-isolation.py"
SPEC = importlib.util.spec_from_file_location("scratch_metrics", SOURCE)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class MetricsTests(unittest.TestCase):
    def test_reserved_identity_is_counted_once_and_pending_is_excluded(self):
        with tempfile.TemporaryDirectory(prefix="scratch-metrics-") as directory:
            root = Path(directory)
            context = root / "reports/review-context"
            context.mkdir(parents=True)
            report = root / "reports/implementation/f/T-001.md"
            report.parent.mkdir(parents=True)
            report.write_text("- **Scratch Root**: /tmp/implementation\n")
            invocation = dict(schema="review-context-invocation/v2", stage="quality",
                              role="sdd-evaluator", feature="f", task_id="T-001",
                              run_id="reserved", host_session_id="session", scratch_root="/tmp/evaluator")
            ledger = dict(schema="review-identity-ledger/v1", records=[dict(
                stage="quality", role="sdd-evaluator", run_id="reserved", host_session_id="session")])
            (context / "identity-ledger.json").write_text(json.dumps(ledger))
            for name in ("caller.json", "snapshot.json"):
                (context / name).write_text(json.dumps(invocation))
            pending = dict(invocation, run_id="pending", host_session_id="pending-session")
            (context / "pending.json").write_text(json.dumps(pending))
            self.assertEqual(MODULE.measure(root, None)["metrics"], {
                "evaluator_scratch_declared": 1,
                "evaluator_scratch_auditable": 1,
                "evaluator_scratch_shared_with_implementation": 0,
            })


if __name__ == "__main__":
    unittest.main()
