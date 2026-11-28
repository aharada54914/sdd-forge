"""MCP packages must import mcp/shared/diagnostics-core.ts directly with zero copies or Python sync scripts (ADR-0055)."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
PACKAGES = ('local-env-mcp', 'ci-mcp')


class DiagnosticsSharingTests(unittest.TestCase):
    def test_python_sync_script_and_copied_cores_are_removed(self):
        self.assertFalse((ROOT / 'mcp/shared/sync-diagnostics.py').exists())
        self.assertTrue((ROOT / 'mcp/shared/diagnostics-core.ts').is_file())
        for package in PACKAGES:
            self.assertFalse(
                (ROOT / f'mcp/{package}/src/diagnostics-core.ts').exists(),
                f'duplicated diagnostics-core.ts must be removed from mcp/{package}',
            )

    def test_mcp_packages_import_shared_diagnostics_core_directly(self):
        for package in PACKAGES:
            diag = (ROOT / f'mcp/{package}/src/diagnostics.ts').read_text(encoding='utf-8')
            self.assertIn('../../shared/diagnostics-core.js', diag)
            self.assertNotIn('./diagnostics-core.js', diag)


if __name__ == '__main__':
    unittest.main()
