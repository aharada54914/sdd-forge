"""Native identity admission fixtures; these are not live review receipts."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    'identity', ROOT / 'plugins/sdd-quality-loop/scripts/initialize-review-identity.py')
IDENTITY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(IDENTITY)
SESSION = '01a1b571-052d-7fa0-8347-cb46ed5d5923'


class CodexIdentityTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.base = Path(temp.name)
        self.root = self.base / 'project'
        self.root.mkdir()
        self.home = self.base / 'codex'
        env = patch.dict(os.environ, CODEX_HOME=str(self.home))
        env.start()
        self.addCleanup(env.stop)
        self.rollout = self.home / 'sessions/2026/11/07' / (
            'rollout-2026-11-07T09-57-25-' + SESSION + '.jsonl')
        self.rollout.parent.mkdir(parents=True)
        self.event = {'type': 'session_meta', 'payload': {
            'id': SESSION, 'cwd': str(self.root), 'originator': 'codex_exec', 'source': 'exec'}}
        self.save()

    def save(self):
        self.rollout.write_text(json.dumps(self.event) + '\n', encoding='utf-8')

    def test_register_original_identity_without_inventing_run_id(self):
        result = IDENTITY.initialize(self.root, self.rollout, 'codex')
        self.assertEqual(result['records'][0]['run_id'], SESSION)
        self.assertEqual(result['records'][0]['host_session_id'], SESSION)
        with self.assertRaises(ValueError):
            IDENTITY.initialize(self.root, self.rollout, 'codex')

    def test_wrong_project_producer_source_and_fork_rejected(self):
        for key, value in [('cwd', str(self.base)), ('originator', 'fabricated'),
                           ('source', 'subagent'), ('forked_from_id', SESSION), ('id', 'fake')]:
            with self.subTest(key=key):
                original = dict(self.event['payload'])
                self.event['payload'][key] = value
                self.save()
                with self.assertRaises(ValueError):
                    IDENTITY.codex_identity(self.root, self.rollout)
                self.event['payload'] = original

    def test_copied_symlink_and_hardlink_sources_rejected(self):
        copy = self.base / self.rollout.name
        copy.write_bytes(self.rollout.read_bytes())
        with self.assertRaises(ValueError):
            IDENTITY.codex_identity(self.root, copy)
        copy.unlink()
        copy.symlink_to(self.rollout)
        with self.assertRaises(ValueError):
            IDENTITY.codex_identity(self.root, copy)
        copy.unlink()
        os.link(self.rollout, copy)
        with self.assertRaises(ValueError):
            IDENTITY.codex_identity(self.root, self.rollout)

    def test_prior_review_history_prevents_reinitialization(self):
        history = self.root / 'reports/spec-review/old.json'
        history.parent.mkdir(parents=True)
        history.write_text('{}', encoding='utf-8')
        with self.assertRaises(ValueError):
            IDENTITY.initialize(self.root, self.rollout, 'codex')
        self.assertFalse((self.root / 'reports/review-context/identity-ledger.json').exists())

    def test_duplicate_or_oversized_metadata_rejected(self):
        for raw in ('{"type":"session_meta","type":"other"}', ' ' * 1048577):
            self.rollout.write_text(raw, encoding='utf-8')
            with self.assertRaises(ValueError):
                IDENTITY.codex_identity(self.root, self.rollout)

    def test_empty_adopt_scaffold_is_not_review_history(self):
        for name in ('implementation', 'quality-gate'):
            path = self.root / 'reports' / name / '.gitkeep'
            path.parent.mkdir(parents=True)
            path.touch()
        IDENTITY.initialize(self.root, self.rollout, 'codex')

    def test_nonempty_scaffold_remains_history(self):
        path = self.root / 'reports/implementation/.gitkeep'
        path.parent.mkdir(parents=True)
        path.write_text('prior evidence', encoding='utf-8')
        with self.assertRaises(ValueError):
            IDENTITY.initialize(self.root, self.rollout, 'codex')


if __name__ == '__main__':
    unittest.main()
