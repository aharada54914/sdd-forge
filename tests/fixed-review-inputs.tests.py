#!/usr/bin/env python3
"""Selected Git inputs are independent of mutable checkout contents."""
import importlib.util
import copy
import hashlib
import hmac
import os
import pathlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'plugins/sdd-review-loop/scripts/fixed-review-inputs.py'


class SnapshotTests(unittest.TestCase):
    def test_reviewer_index_preserves_originals_and_rejects_stale_sources(self):
        output = self.root / 'index-snapshot'
        inventory = self.module.materialize(self.repo, self.commit, ['spec.md'], output)
        self.addCleanup(output.chmod, 0o700)
        index = self.module.reviewer_index(self.repo, output, inventory)
        self.assertEqual(index['schema'], 'sdd-fixed-review-index/v1')
        self.assertIsNone(index['verdict'])
        self.assertEqual(index['sources'][0]['sha256'], inventory['inputs'][0]['sha256'])
        self.assertEqual(pathlib.Path(index['sources'][0]['source']).read_text(), 'frozen\n')
        self.assertEqual(index['inventory_sha256'], index['state_reference']['inventory_sha256'])
        (self.repo / 'spec.md').write_text('dirty replacement\n')
        with self.assertRaisesRegex(ValueError, 'stale'):
            self.module.reviewer_index(self.repo, output, inventory)
        (self.repo / 'spec.md').write_text('frozen\n')
        (output / 'spec.md').chmod(0o644)
        (output / 'spec.md').write_text('tampered\n')
        (output / 'spec.md').chmod(0o444)
        with self.assertRaises(ValueError):
            self.module.reviewer_index(self.repo, output, inventory)

    def test_state_and_staleness_validate_inventory_before_git_access(self):
        invalid = [None, {}, {'commit': self.commit, 'inputs': []}]
        for inventory in invalid:
            for operation in (
                lambda: self.module.state_reference(self.repo, inventory),
                lambda: self.module.verify_current_selection(self.repo, self.commit, inventory),
            ):
                with self.subTest(inventory=inventory), patch.object(self.module, 'read_blobs') as read:
                    with self.assertRaises(ValueError):
                        operation()
                    read.assert_not_called()

    def test_signed_approval_is_bound_to_exact_review_scope(self):
        inventory = {'commit': self.commit, 'inputs': [{'path': 'spec.md',
                     'mode': '100644', 'sha256': 'a' * 64}]}
        spec = importlib.util.spec_from_file_location('approval_test_auth',
            SCRIPT.parents[2] / 'sdd-quality-loop/scripts/validate-approval-sidecar.py')
        auth = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(auth)
        key = b'synthetic-test-key-not-a-real-credential'
        document = {'schema': 'sdd-fixed-review-approval/v1', **inventory,
                    'feature': 'demo', 'stage': 'impl', 'task_id': 'T-001',
                    'primary_approval': {'approver': 'fixture-human'},
                    'effective_at': '2020-01-01T00:00:00Z'}
        def sign(value):
            value.pop('hmac', None)
            value['hmac'] = hmac.new(key, auth._canonicalize_json_preimage(value),
                                     hashlib.sha256).hexdigest()
            return value
        def verify(value, registry={'fixture-human'}):
            return self.module.verify_approval(value, inventory, feature='demo',
                stage='impl', task_id='T-001', key=key, registry_ids=registry)
        sign(document)
        verify(document)
        for field, value in [('commit', 'b' * 40), ('feature', 'other'),
                             ('stage', 'task'), ('task_id', 'T-002'),
                             ('inputs', []), ('effective_at', '2999-01-01T00:00:00Z'),
                             ('primary_approval', {'approver': 'fixture-human', 'status': 'Rejected'}),
                             ('primary_approval', {'approver': ''}),
                             ('primary_approval', None)]:
            with self.subTest(field=field):
                changed = copy.deepcopy(document)
                changed[field] = value
                sign(changed)
                with self.assertRaises(Exception):
                    verify(changed)
        changed = copy.deepcopy(document)
        changed['hmac'] = '0' * 64
        with self.assertRaisesRegex(Exception, 'HMAC'):
            verify(changed)
        with self.assertRaisesRegex(Exception, 'registered'):
            verify(document, set())
        for field in document:
            changed = copy.deepcopy(document)
            del changed[field]
            with self.subTest(missing=field), self.assertRaises(ValueError):
                verify(changed)

    def test_task_document_review_state_is_not_lost(self):
        source = ('# Plan\nTask-Review-Status: Passed\n'
                  '## T-001 First\nApproval: Approved\nStatus: Planned\n')
        (self.repo / 'tasks.md').write_text(source)
        self.git('add', 'tasks.md')
        self.git('commit', '-qm', 'document review state')
        commit = self.git('rev-parse', 'HEAD').strip()
        snapshot = self.root / 'document-state'
        inventory = self.module.materialize(self.repo, commit, ['tasks.md'], snapshot)
        self.addCleanup(snapshot.chmod, 0o700)
        fields = self.module.state_reference(self.repo, inventory)['fields']
        self.assertEqual(fields[0], {'path': 'tasks.md', 'line': 2,
                                    'text': 'Task-Review-Status: Passed'})
        self.assertEqual([field['task_id'] for field in fields[1:]], ['T-001', 'T-001'])

    def test_task_state_references_have_unambiguous_task_identity(self):
        source = ('## T-001 First\nApproval: Approved\nStatus: Planned\n'
                  '### Evidence\nExplanatory text\n'
                  '## T-002 Second\nApproval: Draft\nStatus: Planned\n')
        (self.repo / 'tasks.md').write_text(source)
        self.git('add', 'tasks.md')
        self.git('commit', '-qm', 'task identities')
        commit = self.git('rev-parse', 'HEAD').strip()
        snapshot = self.root / 'tasks-snapshot'
        inventory = self.module.materialize(self.repo, commit, ['tasks.md'], snapshot)
        self.addCleanup(snapshot.chmod, 0o700)
        fields = self.module.state_reference(self.repo, inventory)['fields']
        self.assertEqual([field['task_id'] for field in fields],
                         ['T-001', 'T-001', 'T-002', 'T-002'])
        self.assertEqual([field['line'] for field in fields], [2, 3, 7, 8])

    def test_task_state_reference_rejects_duplicate_identity_or_field(self):
        for source in ('## T-001 First\nStatus: Planned\n## T-001 Duplicate\n',
                       '## T-001 First\nApproval: Draft\nApproval: Approved\n',
                       '## T-001 First\nStatus: Planned\n### Evidence\nStatus: Done\n'):
            with self.subTest(source=source):
                (self.repo / 'tasks.md').write_text(source)
                self.git('add', 'tasks.md')
                self.git('commit', '-qm', 'ambiguous task state')
                commit = self.git('rev-parse', 'HEAD').strip()
                blobs = self.module.read_blobs(self.repo, commit, ['tasks.md'])
                import hashlib
                inventory = {'commit': commit, 'inputs': [{
                    'path': 'tasks.md', 'mode': blobs[0][1].decode(),
                    'sha256': hashlib.sha256(blobs[0][2]).hexdigest()}]}
                with self.assertRaisesRegex(ValueError, 'ambiguous task state'):
                    self.module.state_reference(self.repo, inventory)

    def test_task_state_survives_nested_heading(self):
        source = '## T-001 First\n### State\nApproval: Draft\nStatus: Planned\n'
        (self.repo / 'tasks.md').write_text(source)
        self.git('add', 'tasks.md')
        self.git('commit', '-qm', 'nested task state')
        commit = self.git('rev-parse', 'HEAD').strip()
        snapshot = self.root / 'nested-state'
        inventory = self.module.materialize(self.repo, commit, ['tasks.md'], snapshot)
        self.addCleanup(snapshot.chmod, 0o700)
        fields = self.module.state_reference(self.repo, inventory)['fields']
        self.assertEqual([(field['task_id'], field['text']) for field in fields],
                         [('T-001', 'Approval: Draft'), ('T-001', 'Status: Planned')])

    def test_state_reference_uses_git_not_dirty_approval(self):
        source = 'Approval: Draft\nStatus: Planned\nSecond Approval: Pending\n'
        (self.repo / 'spec.md').write_text(source)
        self.git('add', 'spec.md')
        self.git('commit', '-qm', 'state source')
        commit = self.git('rev-parse', 'HEAD').strip()
        snapshot = self.root / 'snapshot'
        inventory = self.module.materialize(self.repo, commit, ['spec.md'], snapshot)
        self.addCleanup(snapshot.chmod, 0o700)
        (self.repo / 'spec.md').write_text('Approval: Approved\nStatus: Done\n')
        reference = self.module.state_reference(self.repo, inventory)
        self.assertEqual(reference['commit'], commit)
        self.assertEqual(reference['fields'], [
            {'path': 'spec.md', 'line': 1, 'text': 'Approval: Draft'},
            {'path': 'spec.md', 'line': 2, 'text': 'Status: Planned'},
            {'path': 'spec.md', 'line': 3, 'text': 'Second Approval: Pending'}])
        inventory['inputs'][0]['sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'state source differs'):
            self.module.state_reference(self.repo, inventory)

    def test_cli_rejects_duplicate_inventory_fields(self):
        output = self.root / 'snapshot'
        record = self.root / 'inventory.json'
        self.module.prepare(self.repo, self.commit, ['spec.md'], output, record)
        self.addCleanup(output.chmod, 0o700)
        original = record.read_text()
        args = ['--repo', str(self.repo), '--commit', self.commit,
                '--input', 'spec.md', '--snapshot', str(output), '--record', str(record)]
        for key, value in [('commit', self.commit), ('path', 'spec.md')]:
            with self.subTest(key=key):
                token = '"' + key + '":"' + value + '"'
                malformed = original.replace(token, token + ',' + token)
                self.assertNotEqual(malformed, original)
                record.write_text(malformed)
                result = subprocess.run(['python3', str(SCRIPT), 'verify', *args],
                                        capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('duplicate', result.stderr)
                self.assertEqual(record.read_text(), malformed)
                self.assertEqual((output / 'spec.md').read_text(), 'frozen\n')

    def test_cli_prepare_and_verify_separate_records(self):
        output = self.root / 'snapshot'
        record = self.root / 'inventory.json'
        args = ['--repo', str(self.repo), '--commit', self.commit,
                '--input', 'spec.md', '--snapshot', str(output), '--record', str(record)]
        result = subprocess.run(['python3', str(SCRIPT), 'prepare', *args], capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.addCleanup(output.chmod, 0o700)
        (self.repo / 'spec.md').write_text('mutable progress is not reviewed input')
        result = subprocess.run(['python3', str(SCRIPT), 'verify', *args], capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        result = subprocess.run(['python3', str(SCRIPT), 'prepare', *args], capture_output=True)
        self.assertNotEqual(result.returncode, 0)

    def test_prepare_rejects_record_inside_snapshot(self):
        output = self.root / 'snapshot'
        with self.assertRaisesRegex(ValueError, 'outside snapshot'):
            self.module.prepare(self.repo, self.commit, ['spec.md'], output, output / 'state.json')
        self.assertFalse(output.exists())

    def test_prepare_preserves_existing_record(self):
        record = self.root / 'inventory.json'
        record.write_text('previous evidence')
        with self.assertRaises(FileExistsError):
            self.module.prepare(self.repo, self.commit, ['spec.md'], self.root / 'snapshot', record)
        self.assertEqual(record.read_text(), 'previous evidence')
        self.assertFalse((self.root / 'snapshot').exists())

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = pathlib.Path(self.tmp.name)
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        self.git('init', '-q')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('config', 'user.name', 'Fixture')
        (self.repo / 'spec.md').write_text('frozen\n')
        (self.repo / 'link').symlink_to('spec.md')
        self.git('add', '.')
        self.git('commit', '-qm', 'fixture')
        self.commit = self.git('rev-parse', 'HEAD').strip()
        spec = importlib.util.spec_from_file_location('fixed_inputs', SCRIPT)
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.repo), *args], text=True)

    def test_reads_commit_not_worktree(self):
        (self.repo / 'spec.md').write_text('unapproved\n')
        output = self.root / 'snapshot'
        inventory = self.module.materialize(self.repo, self.commit, ['spec.md'], output)
        self.assertEqual((output / 'spec.md').read_text(), 'frozen\n')
        self.assertEqual(inventory['commit'], self.commit)
        self.assertEqual((output / 'spec.md').stat().st_mode & 0o777, 0o444)
        self.assertEqual(output.stat().st_mode & 0o777, 0o555)
        output.chmod(0o700)

    def test_invalid_inputs_leave_no_snapshot(self):
        for paths in ([], ['missing'], ['link'], ['../spec.md'], ['./spec.md'],
                      ['spec.md', 'spec.md'], ['spec.md', 'SPEC.md'], ['/spec.md']):
            with self.subTest(paths=paths):
                output = self.root / 'snapshot'
                with self.assertRaises(ValueError):
                    self.module.materialize(self.repo, self.commit, paths, output)
                self.assertFalse(output.exists())

    def test_nested_checkout_keeps_repository_relative_paths(self):
        nested = self.repo / 'nested'
        nested.mkdir()
        (nested / 'spec.md').write_text('different nested bytes\n')
        self.git('add', '.')
        self.git('commit', '-qm', 'nested input')
        commit = self.git('rev-parse', 'HEAD').strip()
        output = self.root / 'snapshot'
        inventory = self.module.materialize(nested, commit, ['spec.md'], output)
        self.addCleanup(output.chmod, 0o700)
        self.assertEqual((output / 'spec.md').read_text(), 'frozen\n')
        self.module.verify_revision(nested, commit, ['spec.md'], output, inventory)
        self.module.verify_revision(self.repo, commit, ['spec.md'], output, inventory)

    def test_requires_fixed_commit(self):
        with self.assertRaises(ValueError):
            self.module.materialize(self.repo, 'HEAD', ['spec.md'], self.root / 'snapshot')

    def test_rejects_unselected_snapshot_entries(self):
        for kind in ('file', 'directory', 'symlink'):
            with self.subTest(kind=kind):
                output = self.root / kind
                inventory = self.module.materialize(self.repo, self.commit, ['spec.md'], output)
                self.addCleanup(output.chmod, 0o700)
                output.chmod(0o700)
                extra = output / 'unselected'
                if kind == 'file':
                    extra.write_text('not admitted')
                elif kind == 'directory':
                    extra.mkdir()
                else:
                    extra.symlink_to(self.repo, target_is_directory=True)
                output.chmod(0o555)
                with self.assertRaises(ValueError):
                    self.module.verify(output, inventory)

    def test_rejects_writable_snapshot_directory(self):
        output = self.root / 'snapshot'
        inventory = self.module.materialize(self.repo, self.commit, ['spec.md'], output)
        output.chmod(0o700)
        with self.assertRaisesRegex(ValueError, 'directory mode'):
            self.module.verify(output, inventory)

    def test_revision_verification_binds_required_selection(self):
        output = self.root / 'snapshot'
        inventory = self.module.materialize(self.repo, self.commit, ['spec.md'], output)
        self.addCleanup(output.chmod, 0o700)
        self.module.verify_revision(self.repo, self.commit, ['spec.md'], output, inventory)
        with self.assertRaises(ValueError):
            self.module.verify_revision(self.repo, self.commit, ['spec.md', 'missing'], output, inventory)

    def test_revision_verification_rejects_self_consistent_substitution(self):
        import hashlib
        output = self.root / 'snapshot'
        inventory = self.module.materialize(self.repo, self.commit, ['spec.md'], output)
        self.addCleanup(output.chmod, 0o700)
        target = output / 'spec.md'
        target.chmod(0o600)
        target.write_bytes(b'substituted')
        target.chmod(0o444)
        inventory['inputs'][0]['sha256'] = hashlib.sha256(b'substituted').hexdigest()
        self.module.verify(output, inventory)
        with self.assertRaisesRegex(ValueError, 'Git revision'):
            self.module.verify_revision(self.repo, self.commit, ['spec.md'], output, inventory)

    def test_revision_verification_rejects_different_commit(self):
        output = self.root / 'snapshot'
        inventory = self.module.materialize(self.repo, self.commit, ['spec.md'], output)
        self.addCleanup(output.chmod, 0o700)
        self.git('commit', '--allow-empty', '-qm', 'different revision')
        inventory['commit'] = self.git('rev-parse', 'HEAD').strip()
        with self.assertRaisesRegex(ValueError, 'Git revision'):
            self.module.verify_revision(self.repo, self.commit, ['spec.md'], output, inventory)

    def test_verify_rejects_changed_missing_and_linked_input(self):
        output = self.root / 'snapshot'
        inventory = self.module.materialize(self.repo, self.commit, ['spec.md'], output)
        self.addCleanup(output.chmod, 0o700)
        self.module.verify(output, inventory)
        output.chmod(0o700)
        target = output / 'spec.md'
        target.chmod(0o600)
        target.write_text('changed')
        with self.assertRaises(ValueError):
            self.module.verify(output, inventory)
        target.unlink()
        with self.assertRaises(ValueError):
            self.module.verify(output, inventory)
        target.symlink_to(self.repo / 'spec.md')
        with self.assertRaises(ValueError):
            self.module.verify(output, inventory)

    def test_verify_ignores_unselected_progress(self):
        output = self.root / 'snapshot'
        inventory = self.module.materialize(self.repo, self.commit, ['spec.md'], output)
        self.addCleanup(output.chmod, 0o700)
        (self.repo / 'progress.json').write_text('{"status":"running"}')
        self.module.verify(output, inventory)

    def test_verify_rejects_traversal_and_duplicate_selection(self):
        output = self.root / 'snapshot'
        inventory = self.module.materialize(self.repo, self.commit, ['spec.md'], output)
        self.addCleanup(output.chmod, 0o700)
        inventory['inputs'].append(dict(inventory['inputs'][0]))
        with self.assertRaises(ValueError):
            self.module.verify(output, inventory)
        inventory['inputs'] = [dict(inventory['inputs'][0], path='../repo/spec.md')]
        with self.assertRaises(ValueError):
            self.module.verify(output, inventory)

    def test_invalid_types_are_rejected_before_output(self):
        for commit, paths in ((None, ['spec.md']), (self.commit, 'spec.md'),
                              (self.commit, [None]), (self.commit, [1])):
            with self.subTest(commit=commit, paths=paths):
                with self.assertRaises(ValueError):
                    self.module.materialize(self.repo, commit, paths, self.root / 'snapshot')
                self.assertFalse((self.root / 'snapshot').exists())

    def test_case_colliding_directories_rejected_before_output(self):
        blob = self.git('rev-parse', self.commit + ':spec.md').strip()
        for name in ('Cards/a.md', 'cards/b.md'):
            self.git('update-index', '--add', '--cacheinfo', '100644', blob, name)
        self.git('commit', '-qm', 'case collision')
        commit = self.git('rev-parse', 'HEAD').strip()
        with self.assertRaisesRegex(ValueError, 'case-colliding'):
            self.module.materialize(self.repo, commit, ['Cards/a.md', 'cards/b.md'],
                                    self.root / 'snapshot')
        self.assertFalse((self.root / 'snapshot').exists())

    def test_git_replace_cannot_substitute_fixed_content(self):
        (self.repo / 'spec.md').write_text('substituted\n')
        self.git('add', 'spec.md')
        self.git('commit', '-qm', 'replacement')
        replacement = self.git('rev-parse', 'HEAD').strip()
        self.git('replace', self.commit, replacement)
        output = self.root / 'snapshot'
        self.module.materialize(self.repo, self.commit, ['spec.md'], output)
        self.addCleanup(output.chmod, 0o700)
        self.assertEqual((output / 'spec.md').read_text(), 'frozen\n')

    def test_verify_rejects_case_colliding_parent_spellings(self):
        import hashlib
        output = self.root / 'snapshot'
        output.mkdir()
        entries = []
        for name in ('Cards/a.md', 'cards/b.md'):
            target = output / name
            target.parent.mkdir(exist_ok=True)
            target.write_bytes(b'input')
            target.chmod(0o444)
            entries.append({'path': name, 'mode': '100644',
                            'sha256': hashlib.sha256(b'input').hexdigest()})
        with self.assertRaisesRegex(ValueError, 'case-colliding'):
            self.module.verify(output, {'commit': self.commit, 'inputs': entries})

    def test_existing_destination_is_preserved(self):
        output = self.root / 'snapshot'
        output.mkdir()
        (output / 'keep').write_text('keep')
        with self.assertRaises(ValueError):
            self.module.materialize(self.repo, self.commit, ['spec.md'], output)
        self.assertEqual((output / 'keep').read_text(), 'keep')

    def test_inherited_git_directory_cannot_redirect_lookup(self):
        other = self.root / 'other'
        subprocess.run(['git', 'init', '-q', str(other)], check=True)
        output = self.root / 'snapshot'
        with patch.dict(os.environ, {'GIT_DIR': str(other / '.git')}):
            self.module.materialize(self.repo, self.commit, ['spec.md'], output)
        self.addCleanup(output.chmod, 0o700)
        self.assertEqual((output / 'spec.md').read_text(), 'frozen\n')

    def test_nested_executable_preserves_bytes_and_inventory(self):
        import hashlib
        script = self.repo / 'nested' / 'probe.sh'
        script.parent.mkdir()
        data = b'#!/bin/sh\nexit 0\n'
        script.write_bytes(data)
        self.git('add', 'nested/probe.sh')
        self.git('update-index', '--chmod=+x', 'nested/probe.sh')
        self.git('commit', '-qm', 'nested executable')
        commit = self.git('rev-parse', 'HEAD').strip()
        output = self.root / 'snapshot'
        inventory = self.module.materialize(self.repo, commit, ['nested/probe.sh'], output)
        self.addCleanup(output.chmod, 0o700)
        self.addCleanup((output / 'nested').chmod, 0o700)
        self.assertEqual((output / 'nested/probe.sh').read_bytes(), data)
        self.assertEqual((output / 'nested/probe.sh').stat().st_mode & 0o777, 0o555)
        self.assertEqual((output / 'nested').stat().st_mode & 0o777, 0o555)
        self.assertEqual(inventory['inputs'], [{'path': 'nested/probe.sh',
            'sha256': hashlib.sha256(data).hexdigest(), 'mode': '100755'}])

    def test_gitlink_is_rejected_before_destination_creation(self):
        self.git('update-index', '--add', '--cacheinfo', '160000', self.commit, 'submodule')
        self.git('commit', '-qm', 'gitlink')
        commit = self.git('rev-parse', 'HEAD').strip()
        output = self.root / 'snapshot'
        with self.assertRaisesRegex(ValueError, 'exact regular file'):
            self.module.materialize(self.repo, commit, ['submodule'], output)
        self.assertFalse(output.exists())


    def test_current_selection_ignores_unrelated_commit(self):
        output = self.root / 'snapshot'
        inventory = self.module.materialize(self.repo, self.commit, ['spec.md'], output)
        self.addCleanup(output.chmod, 0o700)
        (self.repo / 'result.json').write_text('{}')
        self.git('add', 'result.json')
        self.git('commit', '-qm', 'review output')
        self.module.verify_current_selection(self.repo, self.git('rev-parse', 'HEAD').strip(), inventory)

    def test_current_selection_rejects_changed_bytes_and_mode(self):
        output = self.root / 'snapshot'
        inventory = self.module.materialize(self.repo, self.commit, ['spec.md'], output)
        self.addCleanup(output.chmod, 0o700)
        (self.repo / 'spec.md').write_text('changed\n')
        self.git('add', 'spec.md')
        self.git('commit', '-qm', 'changed body')
        with self.assertRaisesRegex(ValueError, 'selected inputs changed'):
            self.module.verify_current_selection(self.repo, self.git('rev-parse', 'HEAD').strip(), inventory)
        (self.repo / 'spec.md').write_text('frozen\n')
        self.git('add', 'spec.md')
        self.git('update-index', '--chmod=+x', 'spec.md')
        self.git('commit', '-qm', 'changed mode')
        with self.assertRaisesRegex(ValueError, 'selected inputs changed'):
            self.module.verify_current_selection(self.repo, self.git('rev-parse', 'HEAD').strip(), inventory)


if __name__ == '__main__':
    unittest.main()
