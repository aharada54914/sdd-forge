"""Non-reserving host-neutral admission checks; no real identity ledger writes."""
import importlib.util
import os
import subprocess
import sys
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'plugins/sdd-review-loop/scripts/preflight-host-review.py'
spec = importlib.util.spec_from_file_location('host_review_preflight', SCRIPT)
preflight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preflight)
launcher = preflight.load_module('review_launcher_test', SCRIPT.with_name('launch-impl-review.py'))
RECEIPT = ('REVIEW_CONTEXT_OK ' + 'a' * 64 + ' sequence=2 '
           'previous_record_sha256=' + 'b' * 64 +
           ' pre_append_tip_sequence=1 identity_unique=yes\n')


class HostReviewPreflightTests(unittest.TestCase):
    def fixture(self, stage='spec', role=None, scratch=False):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        role = role or ('sdd-evaluator' if stage == 'quality' else stage + '-reviewer-a')
        if stage == 'quality':
            names = ['specs/demo/' + name for name in
                     ('requirements.md', 'design.md', 'acceptance-tests.md',
                      'tasks.md', 'traceability.md')]
            names += ['plugins/sdd-quality-loop/references/quality-gate-calibration.md',
                      'reports/implementation/demo/T-001.md']
        else:
            names = ['specs/demo/requirements.md', 'specs/demo/acceptance-tests.md',
                     'plugins/sdd-review-loop/references/spec-review-calibration.md',
                     f'reports/{stage}-review/demo/attempt-1/round-1/precheck-result.json']
        for name in names:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(name)
        if stage != 'quality':
            (root / names[-1]).write_text(json.dumps({
                'schema': stage + '-review-precheck/v1', 'feature': 'demo',
                'attempt': 1, 'round': 1, 'investigation_sha256': None}))
        entries = [{'path': name, 'sha256': preflight.sha(root / name)} for name in names]
        data = {'schema': 'review-context-invocation/v2', 'stage': stage,
                'role': role, 'feature': 'demo', 'read_only': True,
                'allowed_input_manifest': entries}
        if stage == 'quality':
            data['task_id'] = 'T-001'
        if scratch:
            scratch_root = root.parent / (root.name + '-scratch')
            scratch_root.mkdir()
            self.addCleanup(lambda: __import__('shutil').rmtree(scratch_root))
            for name in names:
                path = scratch_root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes((root / name).read_bytes())
            data['scratch_root'] = str(scratch_root)
        invocation = root / 'invocation.json'
        invocation.write_text(json.dumps(data))
        ledger = root / 'ledger.json'
        ledger.write_text('unchanged')
        return root, invocation, data, ledger

    def run_preflight(self, root, invocation, *, cli=None, flags=(), subcommands=(),
                      runtime='bash', projection=False, response=None,
                      fixed_input_record=None, fixed_input_snapshot=None):
        calls = []
        def run(command, **kwargs):
            calls.append(command)
            if command[-1] == '--help':
                return SimpleNamespace(returncode=0, stdout='--model MODEL\n--agent AGENT\n', stderr='')
            return response or SimpleNamespace(returncode=0, stdout=RECEIPT, stderr='')
        with patch.object(preflight, 'load_module', return_value=launcher), \
             patch.object(launcher, 'verify_inputs_before_output'), \
             patch.object(preflight.subprocess, 'run', side_effect=run):
            count = preflight.preflight(root, invocation, preflight.sha(invocation),
                                        cli, flags, subcommands, runtime, projection,
                                        fixed_input_record=fixed_input_record,
                                        fixed_input_snapshot=fixed_input_snapshot)
        return count, calls

    def test_fixed_binding_reaches_required_input_selection(self):
        root, invocation, data, ledger = self.fixture('impl')
        record, snapshot = root / 'fixed.json', root / 'snapshot'
        binding = {'approval_reference': 'reports/review-context/fixed-approvals/a.json',
                   'inventory': {'inputs': []}, 'snapshot': str(snapshot)}
        admitted = {entry['path'] for entry in data['allowed_input_manifest']}
        with patch.object(launcher.transport, 'fixed_input_binding', return_value=binding) as verify, \
             patch.object(launcher, 'required_input_paths', return_value=admitted) as required:
            self.run_preflight(root, invocation, fixed_input_record=record,
                               fixed_input_snapshot=snapshot)
        verify.assert_called_once_with(root.resolve(), data, record, snapshot)
        self.assertIs(required.call_args.kwargs['fixed_inputs'], binding)
        self.assertEqual(ledger.read_text(), 'unchanged')

    def test_unpaired_fixed_binding_stops_before_validator(self):
        root, invocation, _, ledger = self.fixture()
        with patch.object(preflight.subprocess, 'run') as run:
            with self.assertRaisesRegex(ValueError, 'must be paired'):
                preflight.preflight(root, invocation, preflight.sha(invocation),
                                    fixed_input_record=root / 'fixed.json')
        run.assert_not_called()
        self.assertEqual(ledger.read_text(), 'unchanged')

    def test_spec_and_quality_normal_preview_never_reserve(self):
        for stage in ('spec', 'quality'):
            with self.subTest(stage=stage):
                root, invocation, data, ledger = self.fixture(stage)
                count, calls = self.run_preflight(root, invocation)
                self.assertEqual(count, len(data['allowed_input_manifest']))
                self.assertEqual(len(calls), 1)
                self.assertNotIn('--reserve', calls[0])
                self.assertEqual(ledger.read_text(), 'unchanged')

    def test_impl_and_task_use_stage_precheck_before_preview(self):
        for stage in ('impl', 'task'):
            with self.subTest(stage=stage):
                root, invocation, data, ledger = self.fixture(stage)
                admitted = {entry['path'] for entry in data['allowed_input_manifest']}
                with patch.object(launcher, 'required_input_paths', return_value=admitted) as required:
                    count, calls = self.run_preflight(root, invocation)
                self.assertEqual(count, len(admitted))
                self.assertEqual(required.call_args.args[1]['stage'], stage)
                self.assertEqual(len(calls), 1)
                self.assertNotIn('--reserve', calls[0])
                self.assertEqual(ledger.read_text(), 'unchanged')

    def test_powershell_selects_existing_precheck_and_validator(self):
        root, invocation, _, ledger = self.fixture('spec')
        with patch.object(preflight, 'load_module', return_value=launcher), \
             patch.object(launcher, 'verify_inputs_before_output') as verify, \
             patch.object(preflight.subprocess, 'run', return_value=SimpleNamespace(
                 returncode=0, stdout=RECEIPT, stderr='')) as run:
            preflight.preflight(root, invocation, preflight.sha(invocation), runtime='powershell')
        self.assertEqual(verify.call_args.kwargs['runtime'], 'powershell')
        calls = [call.args[0] for call in run.call_args_list]
        command = calls[0][2:] if calls[0][:2] == ['rtk', 'proxy'] else calls[0]
        self.assertEqual(command[:3], ['pwsh', '-NoProfile', '-File'])
        self.assertEqual(Path(command[3]), ROOT / 'plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1')
        self.assertEqual(ledger.read_text(), 'unchanged')

    def test_cli_help_flags_and_unsupported_argument(self):
        root, invocation, _, ledger = self.fixture()
        cli = root / 'host-cli'
        cli.write_text('fixture')
        count, calls = self.run_preflight(root, invocation, cli=cli,
                                          flags=['--model'], subcommands=['exec'])
        self.assertEqual(count, 4)
        self.assertEqual(calls[0], ['rtk', 'proxy', str(cli), 'exec', '--help'])
        with self.assertRaisesRegex(ValueError, 'unsupported CLI argument'):
            self.run_preflight(root, invocation, cli=cli, flags=['--unsupported'])
        with self.assertRaisesRegex(ValueError, 'unsafe CLI help subcommand'):
            self.run_preflight(root, invocation, cli=cli, subcommands=['exec; echo bad'])
        self.assertEqual(ledger.read_text(), 'unchanged')

    def test_nonobject_and_scratch_alias_reject(self):
        root, invocation, data, ledger = self.fixture('quality', scratch=True)
        invocation.write_text('[]')
        with self.assertRaisesRegex(ValueError, 'JSON object'):
            self.run_preflight(root, invocation)
        data['scratch_root'] = str(root / 'alias')
        (root / 'alias').symlink_to(root.parent / (root.name + '-scratch'))
        invocation.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, 'invalid scratch root'):
            self.run_preflight(root, invocation)
        self.assertEqual(ledger.read_text(), 'unchanged')

    def test_pin_missing_input_outside_and_changed_scratch_reject(self):
        root, invocation, data, ledger = self.fixture('quality', scratch=True)
        with self.assertRaisesRegex(ValueError, 'caller invocation pin mismatch'):
            preflight.preflight(root, invocation, '0' * 64)
        (root / data['allowed_input_manifest'][0]['path']).unlink()
        with self.assertRaises(ValueError):
            self.run_preflight(root, invocation)
        (root / data['allowed_input_manifest'][0]['path']).write_text('restored')
        data['allowed_input_manifest'].append({'path': '../outside', 'sha256': '0' * 64})
        invocation.write_text(json.dumps(data))
        with self.assertRaises(ValueError):
            self.run_preflight(root, invocation)
        data['allowed_input_manifest'].pop()
        invocation.write_text(json.dumps(data))
        scratch = Path(data['scratch_root']) / data['allowed_input_manifest'][1]['path']
        scratch.write_text('changed')
        self.run_preflight(root, invocation)
        with self.assertRaisesRegex(ValueError, 'scratch input missing or changed'):
            self.run_preflight(root, invocation, projection=True)
        self.assertEqual(ledger.read_text(), 'unchanged')

    def test_canonical_preview_rejection_and_all_callers_wired(self):
        root, invocation, _, ledger = self.fixture()
        with self.assertRaisesRegex(ValueError, 'canonical preview rejected'):
            self.run_preflight(root, invocation,
                response=SimpleNamespace(returncode=1, stdout='', stderr='rejected'))
        self.assertEqual(ledger.read_text(), 'unchanged')
        # 2026-11-28 owner decision (ADR-0051 decision 2): the callers this test
        # also required -- the spec/impl/task review loops and the quality-gate
        # skill -- retired with the three-loop review. No v2 skill launches this
        # preflight; the script's own admission behaviour is still tested here.



# ProtectedEntrypointTests retired (2026-11-28 owner decision, ADR-0051
# decision 1): it proved that the v1 hard-lock guard (sdd-hook-guard.* with
# guard-invariants.json and its generated projections) denied agent writes to
# review entrypoints, and that the v1 CI job registered the transport suite.
# v2 replaced the hard locks with the soft guard (tests/v2-soft-guard.test.mjs)
# and CI registration with tests/verification-catalog.json.


if __name__ == '__main__':
    unittest.main()
