#!/usr/bin/env python3
"""Actual sealed full scans, same-process reuse and invalidation controls."""
import base64
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('workflow_session', ROOT / 'plugins/sdd-quality-loop/scripts/workflow-state-session.py')
session = importlib.util.module_from_spec(spec)
spec.loader.exec_module(session)


@unittest.skipUnless(sys.platform == 'linux' and shutil.which('bwrap'), 'Linux bubblewrap profile required')
class WorkflowSession(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        probe = subprocess.run(['/usr/bin/bwrap', '--unshare-all', '--ro-bind', '/', '/', '--', '/usr/bin/true'],
                               capture_output=True, timeout=10)
        help_text = subprocess.run(['/usr/bin/bwrap', '--help'], capture_output=True, timeout=10).stdout
        if probe.returncode or b'--ro-bind-data' not in help_text:
            raise unittest.SkipTest('Host does not admit the sealed Linux sandbox profile')

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        feature = self.root / 'specs/sample'
        feature.mkdir(parents=True)
        (feature / 'requirements.md').write_text('Spec-Review-Status: Pending\n')
        (feature / 'design.md').write_text('Impl-Review-Status: Pending\n')
        (feature / 'acceptance-tests.md').write_text('# Acceptance\n')
        self.registry = self.root / 'specs/workflow-state-registry.json'
        self.registry.write_text(json.dumps(dict(schema_version=1,
            migration_baseline_commit='0369c8c96de2eb3179868d1949d66644488f65aa', entries=[dict(feature='sample', profile='full')])))
        self.full_calls = 0
        self.actual_execute = session.runner()

    def execute(self, argv, *args, **kwargs):
        command = argv[argv.index('--') + 1:]
        if command[:2] == ['/usr/bin/bash', str(session.GATE)]:
            self.full_calls += 1
        return self.actual_execute(argv, *args, **kwargs)

    def test_actual_full_scan_reused_for_distinct_requests_only_in_same_process(self):
        with patch.object(session, 'runner', return_value=self.execute):
            result = session.batch(self.registry, ['sample/T-001', 'sample/T-002'])
            self.assertTrue(result['complete'])
            self.assertEqual(1, self.full_calls)
            first, second = result['results']
            self.assertTrue(first['executed'])
            self.assertFalse(second['executed'])
            self.assertEqual(first['run_id'], second['run_id'])
            self.assertEqual(b'workflow-state: ok\n', base64.b64decode(first['stdout']))
            session.batch(self.registry, ['sample/T-003'])
            self.assertEqual(2, self.full_calls)

    def test_immutable_bytes_survive_host_changes_and_seals_deny_writes(self):
        snapshot = session.capture(self.registry)
        snapshot.seal()
        self.addCleanup(snapshot.close)
        source = self.root / 'specs/sample/requirements.md'
        old = source.read_bytes()
        source.write_bytes(b'changed while copied inputs exist')
        for path, _, descriptor in snapshot.descriptors:
            if path == source:
                with self.assertRaises(PermissionError):
                    os.write(descriptor, b'X')
        result = self.actual_execute(snapshot.command(self.registry, ['/usr/bin/cat', str(source)]), '/', 10, 4096,
                                     input_fds=[fd for _, _, fd in snapshot.descriptors])
        self.assertEqual((result[0], result[1], result[4]), (0, old, True))

    def test_audit_checks_admitted_gate_bytes_across_parent_alias_race(self):
        with tempfile.TemporaryDirectory() as directory:
            outside = Path(directory)
            good, bad = outside / 'good', outside / 'bad'
            good.mkdir()
            bad.mkdir()
            (good / 'check-workflow-state.sh').write_bytes(session.GATE.read_bytes())
            (bad / 'check-workflow-state.sh').write_text('#!/bin/bash\necho FORGED_CHECKER_SUCCESS\nexit 0\n')
            alias = outside / 'selected'
            alias.symlink_to(good, target_is_directory=True)
            gate = alias / 'check-workflow-state.sh'
            read = session.stable_file
            count = 0
            def swap(path, *args, **kwargs):
                nonlocal count
                if Path(path) == gate:
                    count += 1
                    if count % 2:
                        alias.unlink()
                        alias.symlink_to(good, target_is_directory=True)
                        result = read(path, *args, **kwargs)
                        alias.unlink()
                        alias.symlink_to(bad, target_is_directory=True)
                        return result
                return read(path, *args, **kwargs)
            with patch.object(session, 'GATE', gate), patch.object(session, 'stable_file', side_effect=swap):
                with self.assertRaisesRegex(session.Ineligible, 'gate-dependency-audit-required'):
                    session.batch(self.registry, ['one', 'two'])

    def test_process_owner_rejects_unsealed_descriptor_before_execution(self):
        descriptor = os.memfd_create('unsealed-fixture', os.MFD_CLOEXEC | os.MFD_ALLOW_SEALING)
        try:
            result = self.actual_execute(['/usr/bin/bash', '-c', 'echo MUST_NOT_RUN'], '/', 10, 4096,
                                         input_fds=[descriptor])
            self.assertEqual(result[0], 125)
            self.assertEqual(result[1], b'')
            self.assertEqual(result[3], 'unsealed-input-fd')
        finally:
            os.close(descriptor)

    def test_aba_during_actual_execution_blocks_instead_of_reusing_success(self):
        source = self.root / 'specs/sample/requirements.md'
        original = source.read_bytes()
        def execute(argv, *args, **kwargs):
            result = self.execute(argv, *args, **kwargs)
            if self.full_calls:
                source.write_bytes(b'changed')
                source.write_bytes(original)
            return result
        with patch.object(session, 'runner', return_value=execute):
            with self.assertRaisesRegex(session.Ineligible, 'input-changed-during-execution'):
                session.batch(self.registry, ['one', 'two'])
        self.assertEqual(1, self.full_calls)

    def test_changed_input_between_requests_reexecutes_and_invalidates_earlier_binding(self):
        actual_capture = session.capture
        calls = 0
        def capture(registry):
            nonlocal calls
            calls += 1
            if calls == 3:
                (self.root / 'untracked.txt').write_text('new input')
            return actual_capture(registry)
        with patch.object(session, 'capture', side_effect=capture), patch.object(session, 'runner', return_value=self.execute):
            with self.assertRaisesRegex(session.Ineligible, 'batch-inputs-changed'):
                session.batch(self.registry, ['one', 'two'])
        self.assertEqual(2, self.full_calls)

    def test_source_directory_environment_and_gate_audit_are_bound(self):
        original = session.capture(self.registry).key(self.registry)
        source = self.root / 'extra.txt'
        source.write_text('new')
        self.assertNotEqual(original, session.capture(self.registry).key(self.registry))
        first = session.capture(self.registry).key(self.registry)
        source.rename(self.root / 'moved.txt')
        self.assertNotEqual(first, session.capture(self.registry).key(self.registry))
        (self.root / 'moved.txt').unlink()
        with patch.dict(os.environ, {'WORKFLOW_TEST_SEED': 'different'}):
            self.assertNotEqual(original, session.capture(self.registry).key(self.registry))
        with patch.object(session, 'AUDITED_GATE_SHA256', '0' * 64):
            with self.assertRaisesRegex(session.Ineligible, 'gate-dependency-audit-required'):
                session.capture(self.registry)
        (self.root / 'link').symlink_to(self.root / 'specs')
        with self.assertRaisesRegex(session.Ineligible, 'symlink-or-special-file'):
            session.capture(self.registry)

    def test_invalid_full_state_is_not_cached_and_matches_normal_checker(self):
        (self.root / 'specs/sample/design.md').write_text('Impl-Review-Status: Passed\n')
        normal = subprocess.run(['/usr/bin/bash', str(session.GATE), '--registry', str(self.registry)], capture_output=True)
        with patch.object(session, 'runner', return_value=self.execute):
            result = session.batch(self.registry, ['one', 'two'])
        self.assertFalse(result['complete'])
        self.assertEqual(self.full_calls, 2)
        for row in result['results']:
            self.assertEqual(row['exit_code'], normal.returncode)
            self.assertEqual(base64.b64decode(row['stderr']), normal.stderr)

    def test_cli_batch_has_full_scope_and_no_imported_pass_field(self):
        request = self.root / 'requests.json'
        request.write_text(json.dumps(dict(schema='workflow-state-batch/v1', requests=['one', 'two'])))
        result = subprocess.run(['/usr/bin/bash', str(session.GATE), '--registry', str(self.registry), '--batch', str(request)], capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        self.assertEqual([r['executed'] for r in json.loads(result.stdout)['results']], [True, False])
        request.write_text(json.dumps(dict(schema='workflow-state-batch/v1', requests=['one'], passed=True)))
        result = subprocess.run(['/usr/bin/bash', str(session.GATE), '--registry', str(self.registry), '--batch', str(request)], capture_output=True)
        self.assertEqual(result.returncode, 2)
        self.assertFalse(json.loads(result.stdout)['complete'])


if __name__ == '__main__':
    unittest.main()
