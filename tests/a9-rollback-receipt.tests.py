#!/usr/bin/env python3
"""Disposable-key A9 rollback admission and real publisher regressions."""
import base64
import copy
import hashlib
import hmac
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

def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

CORE = load(ROOT / 'scripts/validate-a9-rollback-receipt.py', 'a9_rollback')
CRYPTO = load(ROOT / 'tests/fixtures/live-host-proof/run_cases.py', 'disposable_ed25519')
KEY = 'a9-disposable-test-only-hmac-key'
FIRST = '2026-01-02T00:00:00Z'
EFFECTIVE = '2026-01-03T00:00:00Z'


def encoded(value):
    return (json.dumps(value, sort_keys=True, indent=2) + '\n').encode()


def yaml_lines(value, indent=0):
    prefix = ' ' * indent
    if isinstance(value, dict):
        for key, item in value.items():
            if isinstance(item, (dict, list)) and item:
                yield prefix + key + ':'
                yield from yaml_lines(item, indent + 2)
            else:
                yield prefix + key + ': ' + json.dumps(item)
    else:
        for item in value:
            if isinstance(item, dict):
                lines = list(yaml_lines(item, indent + 2))
                yield prefix + '- ' + lines[0].lstrip()
                yield from lines[1:]
            else:
                yield prefix + '- ' + json.dumps(item)


class Fixture:
    def __init__(self, root, two=False):
        self.root = Path(root)
        self.stage = 'rollback/staged'
        self.registry = {'schema': 'sdd-approver-registry/v1', 'approvers': [
            {'id': name, 'name': name} for name in (['approver-one', 'approver-two'] if two else ['approver-one'])]}
        self.write('sdd/approver-registry.yaml', self.registry)
        self.write('rollback/request-registry.yaml', self.registry)
        self.context = {'schema': 'sdd-project-context/v1', 'workflow': {
            'spec_profile': 'full', 'artifact_layout': 'facet-native', 'capability_enforcement': 'required'}}
        self.write('rollback/before.yaml', self.context)
        self.before = self.sidecar('rollback/before.yaml')
        self.before.update(approval_epoch=1, predecessor_context_sha256=None, weakening_verdict=None, effective_at=None)
        self.hmac_write('rollback/before.approval.json', self.before)
        self.context['workflow']['capability_enforcement'] = 'advisory'
        self.write(self.stage + '/' + CORE.TARGETS[0], self.context)
        self.after = self.sidecar(self.stage + '/' + CORE.TARGETS[0])
        self.after['predecessor_context_sha256'] = self.before['context_sha256']
        self.after['weakening_verdict'] = {
            'policy_weakening': True, 'two_person_required': two, 'cooldown_hours': None if two else 24,
            'categories': {name: 'n/a' for name in ('capability_removed', 'public_distribution_descoped',
                'criticality_lowered', 'provider_allowlist_widened', 'production_write_path_changed', 'required_gate_removed')}}
        self.after['weakening_verdict']['categories'].update(capability_enforcement_weakened='weakened',
            component_path_narrowed='not_weakened', spec_profile_full_to_lite='not_weakened')
        if two:
            self.after['second_approval'] = {'status': 'Approved', 'approver': 'approver-two', 'approved_at': FIRST}
            self.after['effective_at'] = None
        self.hmac_write(self.stage + '/' + CORE.TARGETS[1], self.after)
        self.copy(self.stage + '/' + CORE.TARGETS[0], self.stage + '/' + CORE.TARGETS[2])
        self.copy('rollback/before.yaml', CORE.TARGETS[0])
        self.copy('rollback/before.yaml', CORE.TARGETS[2])
        self.copy('rollback/before.approval.json', CORE.TARGETS[1])
        self.write('plugins/sdd-review-loop/references/a8-trusted-signers.json', {
            'schema': 'a8-trusted-signers/v1', 'signers': {'operator-key': {
                'identity': 'approver-one', 'role': 'operator', 'added_at': '2026-01-01T00:00:00Z',
                'public_key': base64.b64encode(CRYPTO.KEYS['operator-key'][1]).decode()}}})
        self.record = {'schema': 'a9-rollback-authorization/v1', 'requester': 'requester-fixture',
            'requested_at': '2026-01-01T00:00:00Z', 'application_at': EFFECTIVE,
            'application_result': 'authorized', 'approval_epoch': 2, 'bindings': {},
            'signer': 'approver-one', 'signer_key_id': 'operator-key', 'signature': ''}
        self.refresh()

    def write(self, path, value):
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not isinstance(value, bytes):
            value = ('\n'.join(yaml_lines(value)) + '\n').encode() if path.endswith('.yaml') else encoded(value)
        destination.write_bytes(value)

    def copy(self, source, target):
        self.write(target, (self.root / source).read_bytes())

    def sidecar(self, context):
        return {'schema': 'sdd-project-context-approval/v1',
            'context_sha256': CORE.APPROVAL._hash_file_via_canonicalizer(self.root / context, 'CONTENT_CANONICALIZATION_FAILED'),
            'primary_approval': {'status': 'Approved', 'approver': 'approver-one', 'approved_at': FIRST},
            'second_approval': None, 'effective_at': EFFECTIVE, 'predecessor_context_sha256': None,
            'weakening_verdict': None, 'approval_epoch': 2, 'hmac': ''}

    def hmac_write(self, path, value):
        unsigned = {k: v for k, v in value.items() if k != 'hmac'}
        value['hmac'] = hmac.new(KEY.encode(), CORE.APPROVAL._canonicalize_json_preimage(unsigned), hashlib.sha256).hexdigest()
        self.write(path, value)

    def binding(self, path):
        return {'path': path, 'sha256': CORE.digest((self.root / path).read_bytes())}

    def sign(self, record, domain=b':a9-rollback-authorized'):
        unsigned = {k: v for k, v in record.items() if k != 'signature'}
        seed, public = CRYPTO.KEYS['operator-key']
        record['signature'] = base64.b64encode(CRYPTO.sign(seed, public, hashlib.sha256(CORE.PROOF.jcs(unsigned) + domain).digest())).decode()

    def refresh(self, sign_sidecar=True):
        if sign_sidecar:
            self.hmac_write(self.stage + '/' + CORE.TARGETS[1], self.after)
        manifest = ''.join(self.binding(self.stage + '/' + path)['sha256'] + '  ' + path + '\n' for path in CORE.TARGETS)
        self.write(self.stage + '/MANIFEST.sha256', manifest.encode())
        paths = {'before_context': 'rollback/before.yaml', 'before_approval': 'rollback/before.approval.json',
            'request_registry': 'rollback/request-registry.yaml', 'current_registry': 'sdd/approver-registry.yaml',
            'manifest': self.stage + '/MANIFEST.sha256'}
        paths.update(zip(('candidate_context', 'candidate_approval', 'candidate_snapshot'), (self.stage + '/' + path for path in CORE.TARGETS)))
        self.record['bindings'] = {k: self.binding(v) for k, v in paths.items()}
        self.sign(self.record)
        self.write('rollback/authorization.json', self.record)

    def args(self, *extra):
        return CORE.parser().parse_args(['--root', str(self.root), '--receipt', 'rollback/authorization.json',
            '--staging-dir', self.stage, *extra])

    def attestation(self, result):
        self.write('rollback/application-result.json', result)
        attestation = {'schema': 'a9-rollback-applied/v1', 'authorization': self.binding('rollback/authorization.json'),
            'publisher_result': self.binding('rollback/application-result.json'), 'applied_at': result['applied_at'],
            'signer': 'approver-one', 'signer_key_id': 'operator-key', 'signature': ''}
        self.sign(attestation, b':a9-rollback-applied')
        self.write('rollback/applied.json', attestation)
        return attestation


class RollbackTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='a9-rollback-test-')
        self.addCleanup(self.temp.cleanup)
        self.env = patch.dict(os.environ, {'SDD_CONTEXT_KEY': KEY})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.fixture = Fixture(self.temp.name)

    def rejected(self, reason=None, *extra):
        # Malformed/adversarial inputs must never reach the actual publisher.
        with patch.object(CORE.subprocess, 'run', wraps=subprocess.run) as calls:
            with self.assertRaises((CORE.Refusal, CORE.APPROVAL.ValidateApprovalSidecarError, CORE.PROOF.ValidationError, OSError)) as caught:
                CORE.run(self.fixture.args(*extra))
            self.assertFalse(any('apply-human-copy' in str(call.args) for call in calls.call_args_list))
        if reason:
            self.assertIn(reason, str(caught.exception))

    def test_solo_exact_24_hours_and_plus_one(self):
        for timestamp in (EFFECTIVE, '2026-01-03T00:00:01Z'):
            self.fixture.record['application_at'] = timestamp
            self.fixture.refresh()
            self.assertEqual('ADMISSIBLE', CORE.run(self.fixture.args())['result'])
            self.assertEqual(self.fixture.before['context_sha256'], CORE.APPROVAL._hash_file_via_canonicalizer(self.fixture.root / CORE.TARGETS[0], 'CONTENT_CANONICALIZATION_FAILED'))

    def test_solo_before_24_hours_is_rejected_even_after_wall_clock_deadline(self):
        self.fixture.record['application_at'] = '2026-01-02T23:59:59Z'
        self.fixture.refresh()
        self.rejected('24-hour', '--apply')

    def test_signed_early_effective_at_cannot_shorten_cooldown(self):
        self.fixture.after['effective_at'] = FIRST
        self.fixture.refresh()
        self.rejected('24-hour')

    def test_two_distinct_current_registered_approvals(self):
        self.fixture = Fixture(self.temp.name, two=True)
        self.assertEqual('two-party', CORE.run(self.fixture.args())['branch'])

    def test_current_registry_growth_requires_new_two_person_approval(self):
        self.fixture.registry['approvers'].append({'id': 'approver-two', 'name': 'approver-two'})
        self.fixture.write('sdd/approver-registry.yaml', self.fixture.registry)
        self.fixture.refresh()
        # Existing HMAC validator alone accepts the still-valid solo sidecar:
        # the missing A9 current-cardinality admission is the regression.
        CORE.APPROVAL.run_standard_validation(self.fixture.root / self.fixture.stage / CORE.TARGETS[0],
            self.fixture.root / self.fixture.stage / CORE.TARGETS[1], self.fixture.root / 'sdd/approver-registry.yaml')
        self.rejected('two distinct', '--apply')

    def test_registry_shrink_does_not_reuse_old_two_person_branch(self):
        self.fixture = Fixture(self.temp.name, two=True)
        self.fixture.registry['approvers'].pop()
        self.fixture.write('sdd/approver-registry.yaml', self.fixture.registry)
        self.fixture.refresh()
        self.rejected()

    def test_registry_shrink_accepts_fresh_solo_branch_after_cooldown(self):
        request_registry = copy.deepcopy(self.fixture.registry)
        request_registry['approvers'].append({'id': 'approver-two', 'name': 'approver-two'})
        self.fixture.write('rollback/request-registry.yaml', request_registry)
        self.fixture.refresh()
        self.assertEqual('solo-cooldown', CORE.run(self.fixture.args())['branch'])

    def test_future_application_is_rejected_before_publisher(self):
        self.fixture.record['application_at'] = '2099-01-01T00:00:00Z'
        self.fixture.refresh()
        self.rejected('time ordering', '--apply')

    def test_registry_zero_at_request_or_application(self):
        for path in ('rollback/request-registry.yaml', 'sdd/approver-registry.yaml'):
            self.fixture = Fixture(self.temp.name)
            self.fixture.write(path, {'schema': 'sdd-approver-registry/v1', 'approvers': []})
            self.fixture.refresh()
            self.rejected('zero-identity')

    def test_sole_requester_self_approval_is_rejected(self):
        self.fixture.record['requester'] = 'approver-one'
        self.fixture.refresh()
        self.rejected('self-approval')

    def test_duplicate_or_missing_second_approval(self):
        for second in (None, {'status': 'Approved', 'approver': 'approver-one', 'approved_at': FIRST}):
            self.fixture = Fixture(self.temp.name, two=True)
            self.fixture.after['second_approval'] = second
            self.fixture.refresh()
            self.rejected()

    def test_stale_raw_binding_rejects_current_registry_change(self):
        self.fixture.write('sdd/approver-registry.yaml', encoded(self.fixture.registry) + b' ')
        self.rejected('bound input')

    def test_invalid_ed25519_signature(self):
        self.fixture.record['signature'] = base64.b64encode(bytes(64)).decode()
        self.fixture.write('rollback/authorization.json', self.fixture.record)
        self.rejected('signature')

    def test_trusted_key_identity_role_and_membership(self):
        path = 'plugins/sdd-review-loop/references/a8-trusted-signers.json'
        original = json.loads((self.fixture.root / path).read_bytes())
        for field, value in (('identity', 'another-operator'), ('role', 'reviewer'), ('public_key', base64.b64encode(CRYPTO.KEYS['outsider-key'][1]).decode())):
            document = copy.deepcopy(original)
            document['signers']['operator-key'][field] = value
            self.fixture.write(path, document)
            self.rejected()

    def test_hmac_tamper_and_context_snapshot_mismatch(self):
        self.fixture.after['hmac'] = '0' * 64
        self.fixture.write(self.fixture.stage + '/' + CORE.TARGETS[1], self.fixture.after)
        self.fixture.refresh(sign_sidecar=False)
        self.rejected('HMAC')
        self.fixture.refresh()
        self.fixture.write(self.fixture.stage + '/' + CORE.TARGETS[2], b'wrong')
        self.fixture.refresh()
        self.rejected('snapshot differs')

    def test_predecessor_and_epoch_binding(self):
        for field, value in (('predecessor_context_sha256', 'sha256:' + '0' * 64), ('approval_epoch', 7)):
            self.fixture = Fixture(self.temp.name)
            self.fixture.after[field] = value
            self.fixture.refresh()
            self.rejected()

    def test_unrelated_policy_change_is_not_authorized_by_rollback(self):
        self.fixture.context['workflow']['artifact_layout'] = 'facet-hybrid'
        self.fixture.write(self.fixture.stage + '/' + CORE.TARGETS[0], self.fixture.context)
        self.fixture.copy(self.fixture.stage + '/' + CORE.TARGETS[0], self.fixture.stage + '/' + CORE.TARGETS[2])
        self.fixture.after['context_sha256'] = CORE.APPROVAL._hash_file_via_canonicalizer(self.fixture.root / self.fixture.stage / CORE.TARGETS[0], 'CONTENT_CANONICALIZATION_FAILED')
        self.fixture.refresh()
        self.rejected('beyond enforcement')

    def test_current_anchor_drift_blocks_replay(self):
        self.fixture.write(CORE.TARGETS[2], b'changed')
        self.rejected('live Context', '--apply')

    def test_extra_manifest_target_is_rejected_even_when_signed(self):
        path = self.fixture.stage + '/MANIFEST.sha256'
        self.fixture.write(path, (self.fixture.root / path).read_bytes() + b'0' * 64 + b'  extra.txt\n')
        self.fixture.record['bindings']['manifest'] = self.fixture.binding(path)
        self.fixture.sign(self.fixture.record)
        self.fixture.write('rollback/authorization.json', self.fixture.record)
        self.rejected('exactly the three', '--apply')

    def test_transaction_in_progress_blocks_admission(self):
        self.fixture.write('sdd/.staging/fixture/TRANSACTION.json', {'targets': [{'live_path': CORE.TARGETS[0]}]})
        self.rejected()

    def test_real_publish_and_signed_post_application_verification(self):
        runtime = 'ps1' if os.name == 'nt' else 'sh'
        result = CORE.run(self.fixture.args('--apply', '--publisher-runtime', runtime))
        self.assertEqual('APPLIED', result['result'])
        self.assertNotIn('signature', result)
        self.fixture.attestation(result)
        verified = CORE.run(self.fixture.args('--applied-attestation', 'rollback/applied.json'))
        self.assertEqual('APPLIED_VERIFIED', verified['result'])
        self.assertTrue(verified['signed_application_checked'])
        with self.assertRaises(CORE.Refusal):
            CORE.run(self.fixture.args('--apply'))

    @unittest.skipUnless(shutil.which('pwsh') and os.name != 'nt', 'additional PowerShell runtime unavailable')
    def test_real_powershell_publisher(self):
        result = CORE.run(self.fixture.args('--apply', '--publisher-runtime', 'ps1'))
        self.fixture.attestation(result)
        self.assertEqual('APPLIED_VERIFIED', CORE.run(self.fixture.args('--applied-attestation', 'rollback/applied.json'))['result'])

    def test_unsigned_or_tampered_application_is_not_a_rehearsal_proof(self):
        result = CORE.run(self.fixture.args('--apply'))
        attestation = self.fixture.attestation(result)
        attestation['signature'] = base64.b64encode(bytes(64)).decode()
        self.fixture.write('rollback/applied.json', attestation)
        with self.assertRaises(CORE.Refusal):
            CORE.run(self.fixture.args('--applied-attestation', 'rollback/applied.json'))
        self.fixture.attestation(result)
        self.fixture.write('rollback/application-result.json', encoded(result) + b' ')
        with self.assertRaises(CORE.Refusal):
            CORE.run(self.fixture.args('--applied-attestation', 'rollback/applied.json'))

    def test_post_application_current_bytes_are_verified(self):
        result = CORE.run(self.fixture.args('--apply'))
        self.fixture.attestation(result)
        self.fixture.write(CORE.TARGETS[0], b'changed')
        with self.assertRaises(CORE.Refusal):
            CORE.run(self.fixture.args('--applied-attestation', 'rollback/applied.json'))

    def test_preserved_predecessor_cannot_alias_live_target(self):
        self.fixture.record['bindings']['before_context'] = self.fixture.binding(CORE.TARGETS[2])
        self.fixture.sign(self.fixture.record)
        self.fixture.write('rollback/authorization.json', self.fixture.record)
        self.rejected('preserved outside', '--apply')

    @unittest.skipUnless(os.name == 'nt', 'case-insensitive Windows alias boundary')
    def test_case_alias_cannot_replace_preserved_predecessor(self):
        self.fixture.record['bindings']['before_context'] = self.fixture.binding(CORE.TARGETS[2].upper())
        self.fixture.sign(self.fixture.record)
        self.fixture.write('rollback/authorization.json', self.fixture.record)
        self.rejected('preserved outside', '--apply')

    def test_symlink_input_is_rejected(self):
        path = self.fixture.root / 'rollback/before.yaml'
        original = path.read_bytes()
        path.unlink()
        target = self.fixture.root / 'other-before.yaml'
        target.write_bytes(original)
        try:
            path.symlink_to(target)
        except OSError:
            self.skipTest('symlink privilege unavailable')
        self.rejected('symlink/reparse')

    def test_signature_purpose_cannot_be_reused(self):
        self.fixture.sign(self.fixture.record, b':a9-rollback-applied')
        self.fixture.write('rollback/authorization.json', self.fixture.record)
        self.rejected('signature')

    def test_second_identity_added_after_request_requires_fresh_current_branch(self):
        self.fixture = Fixture(self.temp.name, two=True)
        self.fixture.write('rollback/request-registry.yaml', {'schema': 'sdd-approver-registry/v1',
            'approvers': [{'id': 'approver-one', 'name': 'approver-one'}]})
        self.fixture.refresh()
        self.assertEqual('two-party', CORE.run(self.fixture.args())['branch'])

    def test_solo_request_registry_cannot_claim_missing_primary(self):
        self.fixture.write('rollback/request-registry.yaml', {'schema': 'sdd-approver-registry/v1',
            'approvers': [{'id': 'someone-else', 'name': 'someone-else'}]})
        self.fixture.refresh()
        self.rejected('absent from request-time')

    def test_publisher_receives_only_private_authenticated_snapshot(self):
        original = subprocess.run
        invoked = []
        def run(command, **kwargs):
            if any('apply-human-copy' in str(arg) for arg in command):
                invoked.append(command)
                # Original staging mutation after admission cannot alter the
                # existing publisher's manifest or source copy selection.
                self.fixture.write(self.fixture.stage + '/MANIFEST.sha256', b'malicious manifest')
            return original(command, **kwargs)
        with patch.object(CORE.subprocess, 'run', side_effect=run):
            with self.assertRaisesRegex(CORE.Refusal, 'bound input|input changed'):
                CORE.run(self.fixture.args('--apply'))
        self.assertEqual(1, len(invoked))
        self.assertNotIn(str(self.fixture.root / self.fixture.stage), invoked[0])
        for name, target in zip(('candidate_context', 'candidate_approval', 'candidate_snapshot'), CORE.TARGETS):
            self.assertEqual(self.fixture.record['bindings'][name]['sha256'], CORE.digest((self.fixture.root / target).read_bytes()))

    def test_signed_post_application_receipt_cannot_lie_about_result(self):
        result = CORE.run(self.fixture.args('--apply'))
        result['publisher']['targets'] = [CORE.TARGETS[0]]
        self.fixture.attestation(result)
        with self.assertRaisesRegex(CORE.Refusal, 'publisher targets'):
            CORE.run(self.fixture.args('--applied-attestation', 'rollback/applied.json'))

    def test_malformed_signature_metadata_is_a_controlled_refusal(self):
        self.fixture.record['signer_key_id'] = []
        self.fixture.write('rollback/authorization.json', self.fixture.record)
        self.rejected('signature identity')

    def test_cli_readonly_diagnostics_do_not_include_private_paths(self):
        process = subprocess.run([sys.executable, str(ROOT / 'scripts/validate-a9-rollback-receipt.py'),
            '--root', str(self.fixture.root), '--receipt', 'missing.json', '--staging-dir', self.fixture.stage], capture_output=True, text=True)
        self.assertEqual(1, process.returncode)
        result = json.loads(process.stdout)
        self.assertEqual('BLOCKED', result['result'])
        self.assertNotIn(str(self.fixture.root), process.stdout + process.stderr)


if __name__ == '__main__':
    unittest.main()
