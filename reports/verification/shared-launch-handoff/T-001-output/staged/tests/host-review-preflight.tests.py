"""Non-reserving host-neutral admission checks; no real identity ledger writes."""
import importlib.util
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
                      runtime='bash', projection=False, response=None):
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
                                        cli, flags, subcommands, runtime, projection)
        return count, calls

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
        self.assertEqual(calls[0][:5], ['rtk', 'proxy', 'pwsh', '-NoProfile', '-File'])
        self.assertTrue(calls[0][5].endswith('validate-review-context-set.ps1'))
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
        paths = [ROOT / path for path in (
            'plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md',
            'plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md',
            'plugins/sdd-review-loop/skills/task-review-loop/SKILL.md',
            'plugins/sdd-quality-loop/skills/quality-gate/SKILL.md')]
        for path in paths:
            with self.subTest(path=path.name):
                content = path.read_text()
                self.assertIn('preflight-host-review.py', content)
                self.assertIn('HOST_REVIEW_PREFLIGHT_OK', content)


if __name__ == '__main__':
    unittest.main()
