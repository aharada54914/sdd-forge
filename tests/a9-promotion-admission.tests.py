#!/usr/bin/env python3
"""Disposable-key promotion admission tests; no real approval or host proof."""
import base64
import copy
from datetime import datetime, timedelta, timezone
import hashlib
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

def load(relative, name):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

CORE = load('scripts/validate-a9-promotion.py', 'promotion')
RF = load('tests/a9-rollback-receipt.tests.py', 'rollback_fixture')
OF = load('tests/a9-advisory-evidence.tests.py', 'observation_fixture')
KEY = RF.KEY

class Fixture:
    def __init__(self, root):
        self.root = Path(root)
        self.stage = 'private/staged'

    def write(self, path, value):
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(value if isinstance(value, bytes) else (('\n'.join(RF.yaml_lines(value)) + '\n') if path.endswith('.yaml') else (json.dumps(value, indent=2) + '\n')).encode())

    def read(self, path): return json.loads((self.root / path).read_text())
    def bind(self, path): return {'path': path, 'sha256': CORE.ROLLBACK.digest((self.root / path).read_bytes())}
    def git(self, *args): return CORE.git(self.root, *args)
    def commit(self, message):
        self.git('add', '-f', '.')
        self.git('-c', 'user.name=Synthetic Fixture', '-c', 'user.email=fixture@example.invalid', '-c', 'commit.gpgsign=false', 'commit', '-qm', message)
        return self.git('rev-parse', 'HEAD')
    def sign(self):
        self.record['bindings'] = {k: self.bind(v['path']) for k, v in self.record['bindings'].items()}
        unsigned = {k: v for k, v in self.record.items() if k != 'signature'}
        seed, public = RF.CRYPTO.KEYS['operator-key']
        self.record['signature'] = base64.b64encode(RF.CRYPTO.sign(seed, public,
            hashlib.sha256(CORE.PROOF.jcs(unsigned) + b':a9-promotion-approved').digest())).decode()
        self.write('private/decision.json', self.record)
    def args(self, *extra): return CORE.parser().parse_args(['--root', str(self.root), '--decision', 'private/decision.json', '--staging-dir', self.stage, *extra])

    def build(self):
        _, _, contract = OF.fixture(self.root)
        proof_fixture = RF.CRYPTO.Fixture(self.root / 'private/proof')
        registry = json.loads(proof_fixture.registry.read_text())
        registry['signers']['operator-key'].update(identity='approver-one', added_at='2026-01-01T00:00:00Z')
        for filename in CORE.PROOF.FILENAMES.values():
            path = proof_fixture.records / filename
            record = json.loads(path.read_text())
            record['operator'] = 'approver-one'
            RF.CRYPTO.sign_record(record)
            path.write_text(json.dumps(record))
        for relative in CORE.PROOF.CONSUMERS.values():
            self.write(relative, (proof_fixture.root / relative).read_bytes())
        references = 'plugins/sdd-review-loop/references/'
        self.write(references + 'a8-expected-hook-config-digests.json', proof_fixture.manifest.read_bytes())
        baseline = CORE.PREFLIGHT.read_document(self.root / CORE.TARGETS[0])
        existing = {x['pattern'] for x in baseline['shared_paths']}
        for path in list(CORE.TARGETS) + [CORE.FIXED['approvers']]:
            if path not in existing:
                baseline['shared_paths'].append({'pattern': path, 'classification': 'cross-cutting'})
        self.write(CORE.TARGETS[0], baseline)
        self.write(CORE.TARGETS[2], baseline)
        proposed = copy.deepcopy(baseline)
        proposed['workflow'] = CORE.NEW
        # Reuse the same real HMAC/Ed25519 fixture generator and publisher as rollback tests.
        rehearsal = RF.Fixture(self.root / 'private/rehearsal')
        rehearsal.write(CORE.FIXED['trusted_signers'], registry)
        rehearsal.write('rollback/before.yaml', proposed)
        rehearsal.before = rehearsal.sidecar('rollback/before.yaml')
        rehearsal.before.update(approval_epoch=1, predecessor_context_sha256=None, weakening_verdict=None, effective_at=None)
        rehearsal.hmac_write('rollback/before.approval.json', rehearsal.before)
        rolled_back = copy.deepcopy(proposed)
        rolled_back['workflow']['capability_enforcement'] = 'advisory'
        rehearsal.write(rehearsal.stage + '/' + CORE.TARGETS[0], rolled_back)
        rehearsal.after['context_sha256'] = CORE.APPROVAL._hash_file_via_canonicalizer(rehearsal.root / rehearsal.stage / CORE.TARGETS[0], 'CONTENT_CANONICALIZATION_FAILED')
        rehearsal.after['predecessor_context_sha256'] = rehearsal.before['context_sha256']
        rehearsal.copy(rehearsal.stage + '/' + CORE.TARGETS[0], rehearsal.stage + '/' + CORE.TARGETS[2])
        rehearsal.copy('rollback/before.yaml', CORE.TARGETS[0])
        rehearsal.copy('rollback/before.yaml', CORE.TARGETS[2])
        rehearsal.copy('rollback/before.approval.json', CORE.TARGETS[1])
        rehearsal.refresh()
        result = RF.CORE.run(rehearsal.args('--apply'))
        rehearsal.attestation(result)
        for name in ('approvers', 'trusted_signers'):
            self.write(CORE.FIXED[name], (rehearsal.root / CORE.FIXED[name]).read_bytes())
        before = {'schema': 'sdd-project-context-approval/v1', 'context_sha256': CORE.PREFLIGHT.OWNERSHIP.canonical_digest(baseline),
                  'primary_approval': {'status': 'Approved', 'approver': 'approver-one', 'approved_at': RF.FIRST},
                  'second_approval': None, 'effective_at': None, 'predecessor_context_sha256': None,
                  'weakening_verdict': None, 'approval_epoch': 1, 'hmac': ''}
        # hmac_write is pure fixture machinery, with a disposable key only.
        rehearsal.root, saved = self.root, rehearsal.root
        rehearsal.hmac_write(CORE.TARGETS[1], before)
        rehearsal.root = saved
        self.write('mcp/fixture.txt', b'synthetic\n')
        self.write('install.sh', b'# synthetic\n')
        for suite in ('compatibility-byte-identical', 'structural-compatibility', 'cross-runtime-handoff'):
            for suffix in ('sh', 'ps1'):
                relative = 'tests/' + suite + '.tests.' + suffix
                self.write(relative, (ROOT / relative).read_bytes())
        self.write('docs/workflow-improvements/WFI-123.md', b'# Workflow Improvement\n\n## WFI-ID\n\nWFI-123\n<!-- Numbering: follow the existing sequence. -->\n\n## Status\n\nStatus: Draft\n\n## Problem Evidence\n\nPR #1 finding-1: synthetic false positive observation.\n')
        # Private evidence must not become part of the release tree.
        ignore = (self.root / '.gitignore').read_bytes() + b'\n/private/\n'
        self.write('.gitignore', ignore)
        # Remove the private rehearsal from index even though commit() uses force for fixtures.
        self.git('add', '-f', 'sdd', 'plugins', 'contracts', 'tests', 'mcp', 'install.sh', '.gitignore', 'specs', 'docs')
        self.git('-c', 'user.name=Synthetic Fixture', '-c', 'user.email=fixture@example.invalid', '-c', 'commit.gpgsign=false', 'commit', '-qm', 'authenticated synthetic phase one')
        base = self.git('rev-parse', 'HEAD')
        self.write('plugins/sdd-bootstrap/fixture.txt', b'synthetic release change\n')
        self.git('add', 'plugins/sdd-bootstrap/fixture.txt')
        self.git('-c', 'user.name=Synthetic Fixture', '-c', 'user.email=fixture@example.invalid', '-c', 'commit.gpgsign=false', 'commit', '-qm', 'synthetic release PR')
        head = self.git('rev-parse', 'HEAD')
        self.git('tag', 'fixture-release')
        observation = OF.observer.collect(self.root, base, head, 'fixture', contract)
        check_names = ['advisory Gate', 'linux', 'macos', 'windows']
        checks = [{'id': i + 1, 'name': name, 'head_sha': head, 'status': 'completed', 'conclusion': 'success'} for i, name in enumerate(check_names)]
        checks[0]['advisory_observation_sha256'] = CORE.PREFLIGHT.OWNERSHIP.canonical_digest(observation)
        cycle = {'schema': 'a9-release-cycle/v1', 'base_sha': base, 'head_sha': head,
                 'release': {'tag_name': 'fixture-release', 'draft': False, 'prerelease': False, 'published_at': RF.FIRST},
                 'required_checks': {p: [p] for p in ('linux', 'macos', 'windows')}, 'advisory_check': 'advisory Gate',
                 'pull_requests': [{'number': 1, 'base_sha': base, 'head_sha': head, 'merge_commit_sha': head,
                                    'check_runs': checks, 'advisory_observation': observation}]}
        self.write('private/release.json', cycle)
        observed = OF.observer.document(observation['artifacts']['resolver_evidence'])
        manifest = OF.observer.document(observation['artifacts']['facet_manifest'])
        owned = CORE.PREFLIGHT.OWNERSHIP.classify_paths(CORE.PREFLIGHT.OWNERSHIP.load_config_dict(baseline), self.git('ls-files').splitlines())
        for item in (observed, manifest):
            item['context_binding']['ownership_digest'] = owned['context_binding']['ownership_digest']
        self.write('private/resolver.json', observed)
        self.write('private/facets.json', manifest)
        self.write(self.stage + '/' + CORE.TARGETS[0], proposed)
        self.write(self.stage + '/' + CORE.TARGETS[2], proposed)
        after = copy.deepcopy(before)
        after.update(context_sha256=CORE.PREFLIGHT.OWNERSHIP.canonical_digest(proposed),
            predecessor_context_sha256=before['context_sha256'], approval_epoch=2)
        after['weakening_verdict'] = copy.deepcopy(rehearsal.after['weakening_verdict'])
        after['weakening_verdict'].update(policy_weakening=False, two_person_required=False, cooldown_hours=None)
        after['weakening_verdict']['categories']['capability_enforcement_weakened'] = 'not_weakened'
        rehearsal.root = self.root
        rehearsal.hmac_write(self.stage + '/' + CORE.TARGETS[1], after)
        rehearsal.root = saved
        self.write(self.stage + '/MANIFEST.sha256', ''.join(self.bind(self.stage + '/' + p)['sha256'] + '  ' + p + '\n' for p in CORE.TARGETS).encode())
        source = {'pr': 1, 'head_sha': head, 'findings': [{'id': 'finding-1', 'kind': 'gate-false-positive', 'severity': 'Minor'}]}
        self.write('private/findings-raw.json', source)
        self.write('private/findings.json', {'schema': 'a9-advisory-findings/v1', 'base_sha': base, 'head_sha': head,
            'observations': [dict(source, source=self.bind('private/findings-raw.json'))],
            'dispositions': [{'pr': 1, 'id': 'finding-1', 'status': 'open', 'wfi': self.bind('docs/workflow-improvements/WFI-123.md')}]})
        compat = {'schema': 'a9-compatibility-observations/v1', 'head_sha': head, 'results': []}
        for platform in ('linux', 'macos', 'windows'):
            for name in ('compatibility-byte-identical', 'structural-compatibility'):
                suite = 'tests/' + name + '.tests.' + ('ps1' if platform == 'windows' else 'sh')
                log = 'private/' + platform + '-' + name + '.log'
                self.write(log, b'Synthetic test log, not real host evidence.\n25 passed, 0 failed\n')
                compat['results'].append({'platform': platform, 'suite': suite, 'source_sha256': self.bind(suite)['sha256'], 'exit_code': 0, 'log': self.bind(log)})
        self.write('private/compat.json', compat)
        one, two = 'a' * 32, 'b' * 32
        logs = {'claude': b'synthetic producer\n', 'codex-consumer': ('HANDOFF-01:' + one).encode(),
                'codex-producer': b'synthetic producer\n', 'copilot': b'synthetic consumer\n'}
        output = ('COPILOT-CONSUMED:' + two + '\n').encode()
        self.write('private/output.txt', output)
        trace = {'schema': 'cross-runtime-handoff-trace/v1', 'result': 'PASS', 'coverage_complete': True,
                 'canary_case': {'present': True, 'result': 'PASS', 'skip_reason': None}, 'steps': []}
        for pair, nonce, refs, observable in [(('claude', 'codex'), one, ['claude', 'codex-consumer'], {'kind': 'stdout_substring', 'expected': 'HANDOFF-01:' + one}),
                (('codex', 'copilot'), two, ['codex-producer', 'copilot'], {'kind': 'generated_file_hash', 'expected': 'sha256:' + CORE.ROLLBACK.digest(output)})]:
            trace['steps'].append({'producer_runtime': pair[0], 'consumer_runtime': pair[1], 'result': 'PASS', 'invocation_mode': 'automated',
                'mutation_nonce': nonce, 'artifact_initial_sha256': 'sha256:' + '0' * 64, 'artifact_final_sha256': 'sha256:' + '1' * 64,
                'evidence_refs': refs, 'consumer_observable': observable})
        proof_output = self.root / 'private/proof-output'
        proof_output.mkdir()
        # Real validator + signatures with disposable test keys, never real host evidence.
        previous_root = CORE.HANDOFF.ROOT
        try:
            CORE.HANDOFF.ROOT = self.root
            proof = CORE.HANDOFF.validate_live_proof(proof_fixture.records, proof_output)
        finally:
            CORE.HANDOFF.ROOT = previous_root
        trace['canary_case']['proof'] = proof
        self.write('private/trace.json', trace)
        for name, raw in logs.items():
            self.write('private/' + name + '.log', raw)
        suite = 'tests/cross-runtime-handoff.tests.sh'
        self.write('private/cross.json', {'schema': 'a9-cross-runtime-observation/v1', 'head_sha': head, 'suite': suite,
            'source_sha256': self.bind(suite)['sha256'], 'exit_code': 0, 'trace': self.bind('private/trace.json'),
            'logs': {name: self.bind('private/' + name + '.log') for name in logs}, 'output': self.bind('private/output.txt'),
            'proof_records_dir': proof_fixture.records.relative_to(self.root).as_posix(),
            'proof_stdout': self.bind('private/proof-output/live-host-proof.stdout.log')})
        paths = dict(CORE.FIXED)
        paths.update(resolver='private/resolver.json', facet_manifest='private/facets.json', release_cycle='private/release.json',
                     findings='private/findings.json', compatibility='private/compat.json', cross_runtime='private/cross.json', manifest=self.stage + '/MANIFEST.sha256')
        paths.update(zip(CORE.CANDIDATE, (self.stage + '/' + p for p in CORE.TARGETS)))
        self.record = {'schema': 'promotion-decision/v1', 'criteria_revision': 'OQ-003/2026-09-02', 'head_sha': head,
            'decided_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'), 'decision': 'promote',
            'bindings': {k: self.bind(v) for k, v in paths.items()},
            'basis': {'context_binding': observed['context_binding'], 'resolver': observed['resolver'], 'affected_components': manifest['affected_components']},
            'old_tuple': CORE.OLD, 'new_tuple': CORE.NEW, 'criteria': CORE.CRITERIA,
            'rollback': {'root': 'private/rehearsal', 'receipt': rehearsal.binding('rollback/authorization.json'),
                         'staging_dir': rehearsal.stage, 'applied_attestation': rehearsal.binding('rollback/applied.json')},
            'signer': 'approver-one', 'signer_key_id': 'operator-key', 'signature': ''}
        self.sign()

class PromotionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.template = tempfile.TemporaryDirectory(prefix='a9-promotion-base-')
        with patch.dict(os.environ, {'SDD_CONTEXT_KEY': KEY}):
            Fixture(cls.template.name).build()
    @classmethod
    def tearDownClass(cls): cls.template.cleanup()
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='a9-promotion-test-')
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name) / 'repo'
        shutil.copytree(self.template.name, root)
        self.f = Fixture(root)
        self.f.record = self.f.read('private/decision.json')
        env = patch.dict(os.environ, {'SDD_CONTEXT_KEY': KEY})
        env.start()
        self.addCleanup(env.stop)
    def rejected(self, *extra):
        with patch.object(CORE.subprocess, 'run', wraps=subprocess.run) as calls:
            with self.assertRaises((CORE.ROLLBACK.Refusal, CORE.APPROVAL.ValidateApprovalSidecarError, CORE.PROOF.ValidationError, ValueError, OSError)):
                CORE.run(self.f.args(*extra))
            self.assertFalse(any('apply-human-copy' in str(c.args) for c in calls.call_args_list))
    def change(self, name, mutate):
        path = self.f.record['bindings'][name]['path']
        doc = self.f.read(path)
        mutate(doc)
        self.f.write(path, doc)
        self.f.sign()

    def test_full_signed_readonly_admission(self):
        before = [(self.f.root / p).read_bytes() for p in CORE.TARGETS]
        result = CORE.run(self.f.args())
        self.assertEqual(result['result'], 'ADMISSIBLE')
        self.assertFalse(result['applied'])
        self.assertEqual(before, [(self.f.root / p).read_bytes() for p in CORE.TARGETS])
    def test_actual_existing_publisher_applies_only_three_bound_files(self):
        result = CORE.run(self.f.args('--apply'))
        self.assertEqual(result['result'], 'APPLIED')
        self.assertFalse(result['post_promotion_feature_verified'])
        self.assertEqual(set(result['post_hashes']), set(CORE.TARGETS))
        for p in CORE.TARGETS:
            self.assertEqual((self.f.root / p).read_bytes(), (self.f.root / self.f.stage / p).read_bytes())
        self.rejected('--apply')
    @unittest.skipUnless(shutil.which('pwsh'), 'PowerShell is unavailable')
    def test_powershell_publisher_applies_identical_three_file_contract(self):
        result = CORE.run(self.f.args('--apply', '--publisher-runtime', 'ps1'))
        self.assertEqual(result['result'], 'APPLIED')
        for path in CORE.TARGETS:
            self.assertEqual((self.f.root / path).read_bytes(), (self.f.root / self.f.stage / path).read_bytes())
    def test_missing_or_forged_decision_does_not_use_valid_context_approval(self):
        self.f.record['signature'] = base64.b64encode(b'x' * 64).decode()
        self.f.write('private/decision.json', self.f.record)
        self.rejected('--apply')
    def test_future_decision_rejected(self):
        self.f.record['decided_at'] = (datetime.now(timezone.utc) + timedelta(days=1)).strftime('%Y-%m-%dT%H:%M:%SZ')
        self.f.sign()
        self.rejected()
    def test_wrong_signer_is_not_hmac_approver(self):
        self.f.record['signer'] = 'another-person'
        self.f.sign()
        self.rejected()
    def test_stale_head_rejected(self):
        self.f.record['head_sha'] = '0' * 40
        self.f.sign()
        self.rejected()
    def test_bound_input_tamper_rejected(self):
        self.f.write('private/compat.json', b'{}')
        self.rejected()
    def test_untriaged_false_positive_rejected(self):
        self.change('findings', lambda d: d['dispositions'].clear())
        self.rejected()
    def test_boolean_disposition_id_is_not_integer_pr_identity(self):
        self.change('findings', lambda d: d['dispositions'][0].update(pr=True))
        self.rejected()
    def test_false_positive_without_wfi_rejected(self):
        self.change('findings', lambda d: d['dispositions'][0].update(wfi=None))
        self.rejected()
    def test_wfi_must_be_committed_and_identify_the_observation(self):
        record = self.f.read('private/findings.json')
        cycle = self.f.read('private/release.json')
        path = 'docs/workflow-improvements/WFI-123.md'
        original = (self.f.root / path).read_bytes()
        for changed in (original.replace(b'WFI-123', b'WFI-999', 1),
                        original.replace(b'WFI-123', b'WFI-123\nWFI-999', 1),
                        original.replace(b'PR #1 finding-1', b'PR #2 another-finding'),
                        original.replace(b'PR #1 finding-1', b'PR #10 finding-10'),
                        original + b'\nUncommitted addition.\n'):
            with self.subTest(changed=changed[-35:]):
                self.f.write(path, changed)
                record['dispositions'][0]['wfi'] = self.f.bind(path)
                with self.assertRaises(CORE.ROLLBACK.Refusal):
                    CORE.findings(CORE.ROLLBACK.Check(self.f.root), record, cycle)
        self.f.write(path, original)
    def test_omitted_observation_rejected(self):
        self.change('findings', lambda d: d['observations'].clear())
        self.rejected()
    def test_findings_cannot_omit_raw_export_items(self):
        self.change('findings', lambda d: d['observations'][0]['findings'].clear())
        self.rejected()
    def test_unresolved_major_rejected(self):
        path = 'private/findings-raw.json'
        raw = self.f.read(path)
        raw['findings'][0]['severity'] = 'Major'
        self.f.write(path, raw)
        def mutate(d): d['observations'][0].update(findings=raw['findings'], source=self.f.bind(path))
        self.change('findings', mutate)
        self.rejected()
    def test_missing_platform_compatibility_rejected(self):
        self.change('compatibility', lambda d: d['results'].pop())
        self.rejected()
    def test_compatibility_skip_or_failure_rejected(self):
        path = self.f.read('private/compat.json')['results'][0]['log']['path']
        self.f.write(path, b'SKIP: missing implementation\n1 passed, 0 failed\n')
        self.change('compatibility', lambda d: d['results'][0].update(log=self.f.bind(path)))
        self.rejected()
    def test_stale_suite_source_rejected(self):
        self.change('compatibility', lambda d: d['results'][0].update(source_sha256='0' * 64))
        self.rejected()
    def test_incomplete_cross_runtime_rejected(self):
        path = 'private/trace.json'
        trace = self.f.read(path)
        trace['coverage_complete'] = False
        self.f.write(path, trace)
        self.change('cross_runtime', lambda d: d.update(trace=self.f.bind(path)))
        self.rejected()
    def test_cross_runtime_output_tamper_rejected(self):
        self.f.write('private/output.txt', b'wrong')
        self.rejected()
    def proof_inputs(self):
        cross = self.f.read('private/cross.json')
        trace = self.f.read('private/trace.json')
        records = self.f.root / cross['proof_records_dir']
        return cross, trace, records
    def verify_proof(self, cross, trace):
        CORE.completed_host_proof(CORE.ROLLBACK.Check(self.f.root), trace, cross, CORE.utc(self.f.record['decided_at']))
    def test_transported_signed_proof_revalidated_without_ledger_write(self):
        cross, trace, records = self.proof_inputs()
        ledger = records / 'nonce-ledger.json'
        before = ledger.read_bytes()
        self.assertNotEqual(trace['canary_case']['proof']['records_dir'], str(records))
        self.verify_proof(cross, trace)
        self.assertEqual(ledger.read_bytes(), before)
    def test_native_fractional_session_time_uses_existing_a8_contract(self):
        cross, trace, records = self.proof_inputs()
        path = records / next(iter(CORE.PROOF.FILENAMES.values()))
        signed = json.loads(path.read_text())
        ended = signed['session_end']
        signed['session_end'] = ended[:-1] + '.123Z'
        RF.CRYPTO.sign_record(signed)
        path.write_text(json.dumps(signed))
        stdout = trace['canary_case']['proof']['stdout']
        trace['canary_case']['proof'] = dict(CORE.HANDOFF.read_only_proof(self.f.root, records), stdout=stdout)
        self.verify_proof(cross, trace)
        with self.assertRaises(CORE.ROLLBACK.Refusal):
            CORE.completed_host_proof(CORE.ROLLBACK.Check(self.f.root), trace, cross, CORE.utc(ended))
    def test_host_proof_must_precede_the_human_decision(self):
        cross, trace, records = self.proof_inputs()
        with self.assertRaises(CORE.ROLLBACK.Refusal):
            CORE.completed_host_proof(CORE.ROLLBACK.Check(self.f.root), trace, cross, CORE.utc(RF.FIRST))
    def test_proof_roster_cannot_claim_discharge_without_exact_inputs(self):
        cross, trace, records = self.proof_inputs()
        for mutate in (lambda p: p['artifacts'].pop(), lambda p: p['artifacts'].append(p['artifacts'][0]),
                       lambda p: p['artifacts'][0].update(sha256='sha256:' + '0' * 64),
                       lambda p: p.update(aggregate='pending')):
            changed = copy.deepcopy(trace)
            mutate(changed['canary_case']['proof'])
            with self.assertRaises(CORE.ROLLBACK.Refusal):
                self.verify_proof(cross, changed)
    def test_unconsumed_or_foreign_nonce_cannot_replay_completed_receipt(self):
        cross, trace, records = self.proof_inputs()
        ledger = records / 'nonce-ledger.json'
        original = ledger.read_bytes()
        for consumed in (None, 'tests/hook-activation-live-proof/another.json'):
            data = json.loads(original)
            data['entries'][0]['consumed_by_record'] = consumed
            ledger.write_text(json.dumps(data))
            before = ledger.read_bytes()
            with self.assertRaises(ValueError):
                self.verify_proof(cross, trace)
            self.assertEqual(ledger.read_bytes(), before)
    def test_current_consumer_drift_invalidates_signed_old_proof(self):
        cross, trace, records = self.proof_inputs()
        relative = next(iter(CORE.PROOF.CONSUMERS.values()))
        self.f.write(relative, (self.f.root / relative).read_bytes() + b'changed consumer\n')
        with self.assertRaises(ValueError):
            self.verify_proof(cross, trace)
    def test_proof_cannot_execute_verifier_from_evidence_checkout(self):
        cross, trace, records = self.proof_inputs()
        relative = 'plugins/sdd-quality-loop/scripts/validate-live-host-proof.py'
        self.f.write(relative, b'raise AssertionError("untrusted code executed")\n')
        with self.assertRaises(CORE.ROLLBACK.Refusal):
            self.verify_proof(cross, trace)
    def test_legacy_pass_claim_without_signed_host_evidence_is_rejected(self):
        cross, trace, records = self.proof_inputs()
        del trace['canary_case']['proof']
        self.f.write('private/trace.json', trace)
        cross['trace'] = self.f.bind('private/trace.json')
        del cross['proof_records_dir']
        del cross['proof_stdout']
        self.f.write('private/cross.json', cross)
        self.f.sign()
        self.rejected('--apply')
    def test_forged_native_proof_is_blocked_with_private_cli_diagnostics(self):
        cross, trace, records = self.proof_inputs()
        path = records / next(iter(CORE.PROOF.FILENAMES.values()))
        data = json.loads(path.read_text())
        data['operator_signature'] = ''
        path.write_text(json.dumps(data))
        result = subprocess.run([sys.executable, str(ROOT / 'scripts/validate-a9-promotion.py'), '--root', str(self.f.root),
            '--decision', 'private/decision.json', '--staging-dir', self.f.stage, '--apply'], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(str(self.f.root), result.stdout + result.stderr)
        self.assertNotIn('Traceback', result.stderr)
        self.assertEqual(json.loads(result.stdout)['result'], 'BLOCKED')
    def test_handoff_output_cannot_substitute_another_nonce_even_with_hash(self):
        cross, trace, records = self.proof_inputs()
        self.f.write('private/output.txt', b'other nonce\n')
        cross['output'] = self.f.bind('private/output.txt')
        trace['steps'][1]['consumer_observable']['expected'] = 'sha256:' + cross['output']['sha256']
        self.f.write('private/trace.json', trace)
        cross['trace'] = self.f.bind('private/trace.json')
        with self.assertRaises(CORE.ROLLBACK.Refusal):
            CORE.cross_runtime(CORE.ROLLBACK.Check(self.f.root), cross, self.f.record['head_sha'], CORE.utc(self.f.record['decided_at']))
    def test_unsigned_rollback_rejected(self):
        self.f.record['rollback']['applied_attestation']['sha256'] = '0' * 64
        self.f.sign()
        self.rejected()
    def test_missing_hmac_approval_rejected(self):
        (self.f.root / self.f.stage / CORE.TARGETS[1]).unlink()
        self.rejected()
    def test_wrong_epoch_even_with_valid_hmac_rejected(self):
        path = self.f.stage + '/' + CORE.TARGETS[1]
        doc = self.f.read(path)
        doc['approval_epoch'] = 9
        unsigned = {k: v for k, v in doc.items() if k != 'hmac'}
        import hmac
        doc['hmac'] = hmac.new(KEY.encode(), CORE.APPROVAL._canonicalize_json_preimage(unsigned), hashlib.sha256).hexdigest()
        self.f.write(path, doc)
        self.f.sign()
        self.rejected()
    def test_live_anchor_drift_rejected(self):
        self.f.write(CORE.TARGETS[2], b'{}')
        self.rejected('--apply')
    def test_extra_publication_target_rejected(self):
        p = self.f.stage + '/MANIFEST.sha256'
        self.f.write(p, (self.f.root / p).read_bytes() + b'0' * 64 + b'  extra.txt\n')
        self.f.sign()
        self.rejected('--apply')
    def test_duplicate_json_and_private_diagnostics(self):
        path = self.f.root / 'private/decision.json'
        path.write_text(path.read_text().replace('"schema":', '"schema":"duplicate", "schema":', 1))
        result = subprocess.run([sys.executable, str(ROOT / 'scripts/validate-a9-promotion.py'), '--root', str(self.f.root), '--decision', 'private/decision.json', '--staging-dir', self.f.stage], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(str(self.f.root), result.stdout + result.stderr)
        self.assertNotIn(KEY, result.stdout + result.stderr)

if __name__ == '__main__':
    unittest.main()
