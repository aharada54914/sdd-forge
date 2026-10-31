"""Non-reserving host-neutral admission checks; no real identity ledger writes."""
import hashlib
import importlib.util
import os
import re
import shutil
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



QUALITY_SCRIPTS = 'plugins/sdd-quality-loop/scripts/'
CANONICAL = 'plugins/sdd-quality-loop/references/guard-invariants.json'
GENERATOR = QUALITY_SCRIPTS + 'generate-guard-invariants.py'
WORKFLOW = '.github/workflows/test.yml'
ENTRYPOINTS = (
    'plugins/sdd-review-loop/scripts/launch-impl-review.py',
    'plugins/sdd-review-loop/scripts/preflight-host-review.py',
    'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py',
    'plugins/sdd-review-loop/scripts/probe-nontty-review.py',
    'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs',
    QUALITY_SCRIPTS + 'preflight-evaluator-delivery.py',
)
PROJECTIONS = tuple(QUALITY_SCRIPTS + 'generated/' + name for name in (
    'guard_invariants.py', 'guard-invariants.generated.js',
    'guard-invariants.generated.ps1', 'guard-invariants.generated.sh'))
GUARDS = tuple(QUALITY_SCRIPTS + 'sdd-hook-guard.' + ext
               for ext in ('py', 'js', 'ps1', 'sh'))
FIXTURE_INPUTS = ENTRYPOINTS + PROJECTIONS + GUARDS + (CANONICAL, GENERATOR, WORKFLOW)
# Pin all unrelated keys and memberships to the admitted T-003 baseline.
UNRELATED_SHA256 = '8a4f78310312882d4780d30d4f3a491b63507036647f2c28695ad2555c12c883'
TRANSPORT_RUN = re.compile(
    r'^        run: python3 -B tests/quality-nontty-transport[.]tests[.]py[ \t]*$',
    re.MULTILINE)


class ProtectedEntrypointTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        for name in FIXTURE_INPUTS:
            source = ROOT / name
            self.assertTrue(source.is_file(), f'missing admitted fixture input: {name}')
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.read_bytes())
        self.env = dict(os.environ, CLAUDE_PROJECT_DIR=str(self.root),
                        PYTHONDONTWRITEBYTECODE='1')
        self.env.pop('PAYLOAD', None)

    def run_command(self, command, payload=None):
        return subprocess.run(command, cwd=self.root, env=self.env,
                              input=payload, capture_output=True, text=True, timeout=60)

    def check_generator(self, expected=0, diagnostic=''):
        result = self.run_command([sys.executable, '-B', str(self.root / GENERATOR), '--check'])
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        self.assertIn(diagnostic, result.stderr)

    def assert_denied(self, result):
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn('agents must not modify gate scripts', result.stderr,
                      'expected enforcement-chain denial, not a broken fixture')

    def check_entrypoint(self, index):
        target = self.root / ENTRYPOINTS[index]
        self.assertTrue(target.is_file(), f'missing entrypoint: {ENTRYPOINTS[index]}')
        commands = {
            'Python': [sys.executable, '-B', str(self.root / GUARDS[0]), '--emit', 'exit'],
            'Node': ['node', str(self.root / GUARDS[1]), '--emit', 'exit'],
            'PowerShell': ['pwsh', '-NoProfile', '-File', str(self.root / GUARDS[2]), '-Emit', 'exit'],
            'Bash': ['bash', str(self.root / GUARDS[3]), '--emit', 'exit'],
        }
        for runtime, command in commands.items():
            with self.subTest(runtime=runtime, entrypoint=ENTRYPOINTS[index]):
                if not shutil.which(command[0]):
                    self.skipTest(f'NOT RUN: {runtime} runtime unavailable')
                # Read and unrelated-write controls reject fail-closed fixture errors.
                for tool, path in (('Read', target), ('Write', self.root / 'ordinary.txt')):
                    result = self.run_command(command, json.dumps({
                        'tool_name': tool, 'tool_input': {'file_path': str(path), 'content': 'fixture'}}))
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                result = self.run_command(command, json.dumps({
                    'tool_name': 'Write', 'tool_input': {'file_path': str(target), 'content': 'fixture'}}))
                self.assert_denied(result)

    def test_011a_launch_impl_review(self):
        self.check_entrypoint(0)

    def test_011b_preflight_host_review(self):
        self.check_entrypoint(1)

    def test_011c_validate_nontty_spec_launch(self):
        self.check_entrypoint(2)

    def test_011d_probe_nontty_review(self):
        self.check_entrypoint(3)

    def test_011e_nontty_impl_pretool_guard(self):
        self.check_entrypoint(4)

    def test_011f_preflight_evaluator_delivery(self):
        self.check_entrypoint(5)

    def check_mutation(self, name, mutated, diagnostic):
        target = self.root / name
        before = target.read_bytes()
        self.check_generator()
        self.assertNotEqual(before, mutated)
        try:
            target.write_bytes(mutated)
            self.check_generator(1, diagnostic)
        finally:
            target.write_bytes(before)
        self.assertEqual(target.read_bytes(), before)
        self.check_generator()

    def test_012a_canonical_only_addition(self):
        data = json.loads((self.root / CANONICAL).read_bytes())
        data['protected_gate_suffixes'].append('plugins/sdd-review-loop/scripts/t003-extra.py')
        self.check_mutation(CANONICAL, (json.dumps(data) + '\n').encode(),
                            'exact baseline/inventory union')

    def test_012b_generator_only_addition(self):
        before = (self.root / GENERATOR).read_bytes()
        marker = b'BASELINE_SUFFIXES = ('
        self.assertEqual(before.count(marker), 1)
        mutated = before.replace(marker, marker +
            b'\n    "plugins/sdd-review-loop/scripts/t003-extra.py",', 1)
        self.check_mutation(GENERATOR, mutated, 'exact baseline/inventory union')

    def test_012c_each_stale_projection(self):
        for name in PROJECTIONS:
            with self.subTest(projection=name):
                self.check_mutation(name, (self.root / name).read_bytes() + b'\n',
                                    str(self.root / name))

    def assert_unrelated_unchanged(self, data):
        unrelated = dict(data)
        unrelated['protected_gate_suffixes'] = [
            path for path in data['protected_gate_suffixes'] if path not in ENTRYPOINTS]
        digest = hashlib.sha256(json.dumps(unrelated, sort_keys=True,
                               separators=(',', ':')).encode()).hexdigest()
        self.assertEqual(digest, UNRELATED_SHA256, 'unrelated invariant keys or membership changed')

    def test_012d_unrelated_membership_unchanged(self):
        data = json.loads((self.root / CANONICAL).read_bytes())
        self.assert_unrelated_unchanged(data)
        for path in ENTRYPOINTS + (
                'plugins/sdd-review-loop/scripts/review-hash-normalization.ps1',
                QUALITY_SCRIPTS + 'review-conditional-inputs.py'):
            self.assertEqual(data['protected_gate_suffixes'].count(path), 1, path)
        mutated = json.loads(json.dumps(data))
        mutated['protected_gate_suffixes'].pop(0)
        with self.assertRaisesRegex(AssertionError, 'unrelated invariant keys or membership changed'):
            self.assert_unrelated_unchanged(mutated)
        mutated = dict(data, sudo_signature_hex_length=-1)
        with self.assertRaisesRegex(AssertionError, 'unrelated invariant keys or membership changed'):
            self.assert_unrelated_unchanged(mutated)
        self.assert_unrelated_unchanged(data)

    def assert_transport_registered(self):
        workflow = (self.root / WORKFLOW).read_text()
        job = re.search(r'(?ms)^  posix-regression:\n(.*?)(?=^  [\w-]+:|\Z)', workflow)
        self.assertIsNotNone(job, 'CI POSIX regression job missing')
        # The current workflow uses a single-line run step, not a display-name match.
        self.assertEqual(len(TRANSPORT_RUN.findall(job.group(1))), 1,
                         'CI transport registration missing or duplicated')

    def test_013_ci_transport_registration(self):
        self.assert_transport_registered()
        target = self.root / WORKFLOW
        before = target.read_bytes()
        mutated, count = TRANSPORT_RUN.subn('', before.decode())
        self.assertEqual(count, 1)
        try:
            target.write_text(mutated)
            self.check_generator()  # Generation does not check CI registration.
            with self.assertRaisesRegex(AssertionError, 'CI transport registration missing'):
                self.assert_transport_registered()
            target.write_text(mutated + '\n# run: python3 -B tests/quality-nontty-transport.tests.py\n')
            with self.assertRaisesRegex(AssertionError, 'CI transport registration missing'):
                self.assert_transport_registered()
        finally:
            target.write_bytes(before)
        self.assertEqual(target.read_bytes(), before)
        self.assert_transport_registered()

    def test_broken_projection_is_not_protection_evidence(self):
        (self.root / PROJECTIONS[0]).unlink()
        result = self.run_command(
            [sys.executable, '-B', str(self.root / GUARDS[0]), '--emit', 'exit'],
            json.dumps({'tool_name': 'Write', 'tool_input': {
                'file_path': str(self.root / ENTRYPOINTS[0]), 'content': 'fixture'}}))
        with self.assertRaisesRegex(AssertionError, 'expected enforcement-chain denial'):
            self.assert_denied(result)


if __name__ == '__main__':
    unittest.main()
