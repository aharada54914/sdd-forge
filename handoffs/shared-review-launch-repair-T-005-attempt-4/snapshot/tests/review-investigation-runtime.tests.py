"""Runtime discovery controls; validator behavior is covered by the main driver."""
import os
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch


driver = runpy.run_path(str(Path(__file__).with_name("review-investigation-completeness.tests.py")))


class RuntimeDiscoveryTests(unittest.TestCase):
    def discover(self, executable):
        self.assertIn("available_runtimes", driver, "driver must discover optional runtimes")
        with tempfile.TemporaryDirectory(prefix="sdd-runtime-discovery-") as directory:
            if executable is not None:
                candidate = Path(directory) / "pwsh"
                candidate.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
                candidate.chmod(0o700 if executable else 0o600)
            with patch.dict(os.environ, {"PATH": directory}):
                return driver["available_runtimes"]()

    def test_missing_pwsh_retains_bash(self):
        self.assertEqual(self.discover(None), ("bash",))

    def test_present_pwsh_keeps_both_runtimes(self):
        self.assertEqual(self.discover(True), ("bash", "pwsh"))

    def test_nonexecutable_pwsh_is_unavailable(self):
        self.assertEqual(self.discover(False), ("bash",))


if __name__ == "__main__":
    unittest.main()
