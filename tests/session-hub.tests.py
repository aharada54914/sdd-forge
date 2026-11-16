"""Register the dependency-free HTTP/worker integration suite in the existing runner."""
from pathlib import Path
import shutil
import subprocess
import unittest


class HubIntegration(unittest.TestCase):
    def test_http_and_worker_journeys(self):
        node = shutil.which('node')
        self.assertIsNotNone(node, 'Node is required for the session hub integration suite')
        result = subprocess.run([node, '--test', 'tests/session-hub.tests.mjs'],
                                cwd=Path(__file__).resolve().parents[1], timeout=60)
        self.assertEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main()
