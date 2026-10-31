import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

root = Path(__file__).resolve().parents[1] / 'work'
spec = importlib.util.spec_from_file_location('order', root / 'tests/unified-launch-order.tests.py')
order = importlib.util.module_from_spec(spec)
spec.loader.exec_module(order)

class ActualReservationCoverage(unittest.TestCase):
    def test_reservation_failure_runs_canonical_validator(self):
        with patch.object(subprocess, 'Popen', wraps=subprocess.Popen) as processes:
            order.LaunchOrderTests().test_reservation_failure_never_launches()
        reserves = [call for call in processes.call_args_list
                    if '--reserve' in call.args[0] or '-Reserve' in call.args[0]]
        self.assertGreater(len(reserves), 0,
                           'coverage gap: reservation failure never executes a canonical validator append')

unittest.main()
