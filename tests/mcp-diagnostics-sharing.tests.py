"""Standalone MCP copies must match their canonical mechanism; stale checks never write."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('sync_mcp_diagnostics', ROOT / 'scripts/sync-mcp-diagnostics.py')
assert SPEC is not None and SPEC.loader is not None
sync = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sync)


class DiagnosticsSharingTests(unittest.TestCase):
    def test_current_copies_are_fresh(self):
        self.assertEqual(sync.synchronize(ROOT, check=True), [])

    def test_stale_missing_and_update_do_not_touch_policy(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root / 'mcp/shared/diagnostics-core.ts'
            source.parent.mkdir(parents=True)
            source.write_bytes('// UTF-8 日本語\n'.encode('utf-8'))
            for package in sync.PACKAGES:
                directory = root / f'mcp/{package}/src'
                directory.mkdir(parents=True)
                (directory / 'diagnostics.ts').write_bytes(b'provider policy\n')
            target = root / 'mcp/ci-mcp/src/diagnostics-core.ts'
            target.write_bytes(b'stale\n')
            self.assertEqual(len(sync.synchronize(root, check=True)), 2)
            self.assertEqual(target.read_bytes(), b'stale\n')
            self.assertFalse((root / 'mcp/local-env-mcp/src/diagnostics-core.ts').exists())
            self.assertEqual(len(sync.synchronize(root, check=False)), 2)
            self.assertEqual(sync.synchronize(root, check=True), [])
            for package in sync.PACKAGES:
                directory = root / f'mcp/{package}/src'
                self.assertEqual((directory / 'diagnostics.ts').read_bytes(), b'provider policy\n')
                self.assertEqual((directory / 'diagnostics-core.ts').read_bytes(),
                                 sync.HEADER.encode('utf-8') + source.read_bytes())


if __name__ == '__main__':
    unittest.main()
