#!/usr/bin/env python3
"""Synthetic Git/CLI regressions; never issue real approvals or release evidence."""
import copy
import contextlib
import io
import hashlib
import importlib.util
import json
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


observer = load(ROOT / 'scripts/observe-a9-advisory.py', 'observer_test')


def fixture(root):
    for relative in ('plugins', 'contracts'):
        shutil.copytree(ROOT / relative, root / relative, ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
    shutil.copy2(ROOT / '.gitignore', root / '.gitignore')
    config = ROOT / 'specs/epic-197-a9-dogfood/candidate/project-context.yaml'
    for relative in ('sdd/project-context.yaml', 'sdd/.approved-context/project-context.approved.yaml'):
        path = root / relative; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(config.read_bytes())
    context = observer.document(observer.artifact(config.read_bytes()))
    # Deliberately not an authentic approval. The collector must retain authorization_checked:false.
    (root / 'sdd/project-context.approval.json').write_text(json.dumps({
        'schema': 'sdd-project-context-approval/v1',
        'context_sha256': observer.ownership.canonical_digest(context), 'hmac': '0' * 64}))
    directory = root / 'specs/fixture/verification/T-001'; directory.mkdir(parents=True)
    proof = directory / 'evidence.log'; proof.write_bytes(b'Synthetic test observation only.\n')
    contract = {'schema': 'verification-contract/v2', 'task_id': 'T-001', 'risk': 'medium',
                'stack': 'spec', 'required_workflow': 'acceptance-first', 'checks': [
        {'id': name, 'required': True, 'passes': True, 'exit_code': 0,
         'evidence': 'specs/fixture/verification/T-001/evidence.log', 'command': 'synthetic-verifier',
         'started_at': '2026-10-17T00:00:00Z', 'finished_at': '2026-10-17T00:00:01Z'}
        for name in sorted(observer.plans.legacy.RISK_TIERS['medium'])]}
    path = directory / 'contract.json'; path.write_text(json.dumps(contract))
    def git(*args):
        return subprocess.check_output(['git', *args], cwd=root, stderr=subprocess.PIPE).decode().strip()
    git('init', '-q'); git('config', 'core.autocrlf', 'false'); git('add', '.')
    git('-c', 'user.name=Synthetic Fixture', '-c', 'user.email=fixture@example.invalid',
        '-c', 'commit.gpgsign=false', 'commit', '-qm', 'synthetic baseline')
    base = git('rev-parse', 'HEAD')
    changed = root / 'plugins/sdd-bootstrap/fixture.txt'; changed.write_bytes(b'synthetic code change\n')
    git('add', '.'); git('-c', 'user.name=Synthetic Fixture', '-c', 'user.email=fixture@example.invalid',
        '-c', 'commit.gpgsign=false', 'commit', '-qm', 'synthetic PR')
    return base, git('rev-parse', 'HEAD'), path


class ObservationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='a9-observation-fixture-')
        cls.root = Path(cls.temp.name)
        cls.base, cls.head, cls.contract = fixture(cls.root)
        cls.record = observer.collect(cls.root, cls.base, cls.head, 'fixture', cls.contract, cls.root / 'unused')

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def check(self, record):
        return observer.validate_observation(record, self.head, self.base, self.root)

    def test_real_consumers_emit_bound_advisory_without_claiming_authorization(self):
        self.assertEqual(self.check(self.record), [])
        self.assertFalse(self.record['authorization_checked'])
        self.assertEqual(self.record['state'], 'advisory')
        self.assertEqual(self.record['operations'], [{'name': n, 'exit_code': 0} for n in observer.OPERATIONS])
        self.assertEqual(observer.document(self.record['artifacts']['selected_plan'])['verdict'], 'PASS')

    def test_inactive_failed_missing_execution_or_different_head_rejects(self):
        for mutate in (lambda r:r.update(state='not_activated'), lambda r:r.update(result='BLOCKED'),
                       lambda r:r.update(head_sha='a'*40), lambda r:r.update(base_sha='b'*40),
                       lambda r:r.update(authorization_checked=True), lambda r:r['operations'].pop(),
                       lambda r:r['operations'][0].update(exit_code=1)):
            record=copy.deepcopy(self.record); mutate(record)
            with self.subTest(mutation=mutate): self.assertTrue(self.check(record))

    def test_missing_corrupted_rebound_artifacts_reject(self):
        for name in observer.ARTIFACTS:
            record=copy.deepcopy(self.record); record['artifacts'].pop(name)
            with self.subTest(missing=name): self.assertTrue(self.check(record))
            record=copy.deepcopy(self.record); record['artifacts'][name]['contents']+=' '
            with self.subTest(corrupt=name): self.assertTrue(self.check(record))
        record=copy.deepcopy(self.record)
        # Rehashing a changed publication does not make it the committed approved-content input.
        raw=record['artifacts']['context']['contents'].replace('advisory', 'required').encode()
        record['artifacts']['context']=observer.artifact(raw)
        self.assertTrue(self.check(record))

    def test_fake_pass_plan_cannot_hide_failed_required_check(self):
        record=copy.deepcopy(self.record)
        plan=observer.document(record['artifacts']['selected_plan'])
        plan['checks'][0]['result']='failed'
        record['artifacts']['selected_plan']=observer.artifact(json.dumps(plan).encode())
        self.assertTrue(self.check(record))

    def test_required_checks_cannot_be_deleted_or_downgraded(self):
        for mode in ('deleted', 'optional'):
            record = copy.deepcopy(self.record)
            plan = observer.document(record['artifacts']['selected_plan'])
            if mode == 'deleted':
                plan['checks'] = plan['checks'][:1]
            else:
                plan['checks'][0].update(blocking=False, obligation='optional')
            record['artifacts']['selected_plan'] = observer.artifact(json.dumps(plan).encode())
            with self.subTest(mode=mode): self.assertTrue(self.check(record))

    def test_coherently_rehashed_false_ownership_and_projection_are_rejected(self):
        for field in ('ownership_digest', 'projection_sha256', 'dependency_pointers'):
            record = copy.deepcopy(self.record)
            value = ['/components/installer'] if field == 'dependency_pointers' else 'sha256:' + '0' * 64
            record['context_binding'][field] = value
            for name in ('resolver_evidence', 'facet_manifest'):
                doc = observer.document(record['artifacts'][name])
                doc['context_binding'][field] = value
                record['artifacts'][name] = observer.artifact(json.dumps(doc).encode())
            plan = observer.document(record['artifacts']['selected_plan'])
            plan['bindings']['facet_manifest_sha256'] = record['artifacts']['facet_manifest']['sha256']
            record['artifacts']['selected_plan'] = observer.artifact(json.dumps(plan).encode())
            with self.subTest(field=field): self.assertTrue(self.check(record))

    def test_verification_files_missing_tampered_or_traversing_reject(self):
        for mode in ('missing', 'tamper', 'traversal'):
            record = copy.deepcopy(self.record)
            name = next(iter(record['verification_evidence']))
            if mode == 'missing': record['verification_evidence'].pop(name)
            elif mode == 'tamper': record['verification_evidence'][name]['contents'] += 'changed'
            else: record['verification_evidence']['../outside'] = record['verification_evidence'].pop(name)
            with self.subTest(mode=mode): self.assertTrue(self.check(record))

    def test_disabled_coverage_cannot_become_advisory_evidence(self):
        record=copy.deepcopy(self.record)
        coverage=observer.document(record['artifacts']['coverage'])
        coverage['state']='not-applicable (disabled-legacy)'
        record['artifacts']['coverage']=observer.artifact(json.dumps(coverage).encode())
        self.assertTrue(self.check(record))

    def test_collection_rejects_mutated_policy_failed_contract_and_input_symlink(self):
        for mode in ('policy', 'failed-contract', 'symlink'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory(prefix='a9-input-negative-') as raw:
                root = Path(raw); base, head, contract = fixture(root)
                if mode == 'policy':
                    (root / 'sdd/project-context.yaml').write_text('changed')
                elif mode == 'failed-contract':
                    doc = json.loads(contract.read_text())
                    doc['checks'][0].update(passes=False, exit_code=1)
                    contract.write_text(json.dumps(doc))
                    # CI observations may be generated after checkout; keep this
                    # invalid contract untracked so the evaluator sees the failure.
                    untracked = contract.with_name('observed.json')
                    contract.rename(untracked)
                    observer.git(root, 'checkout', '--', str(contract.relative_to(root)))
                    contract = untracked
                else:
                    proof = contract.with_name('evidence.log')
                    target = root / 'private-target'; target.write_bytes(proof.read_bytes())
                    proof.unlink()
                    try: proof.symlink_to(target)
                    except OSError: self.skipTest('symlink privilege unavailable')
                with self.assertRaises((ValueError, OSError)):
                    observer.collect(root, base, head, 'fixture', contract)

    def test_public_cli_diagnostic_does_not_print_private_path_or_error_payload(self):
        output = io.StringIO()
        with tempfile.TemporaryDirectory(prefix='a9-private-diagnostic-') as raw:
            root = Path(raw) / 'repo'; root.mkdir()
            args = ['observe-a9-advisory.py', '--repo-root', str(root), '--contract', str(root/'absent'),
                    '--output', str(Path(raw)/'observation.json'), '--base-sha', 'a'*40,
                    '--head-sha', 'b'*40, '--feature', 'fixture']
            with patch.object(sys, 'argv', args), patch.object(observer, 'collect',
                    side_effect=OSError('PRIVATE_SENTINEL ' + raw)), contextlib.redirect_stderr(output):
                self.assertEqual(observer.main(), 1)
            self.assertEqual(output.getvalue(), 'A9 observation BLOCKED: OSError\n')

    def test_cli_absent_context_is_not_a_successful_gate(self):
        with tempfile.TemporaryDirectory(prefix='a9-inactive-') as raw:
            root=Path(raw)/'repo'; root.mkdir(); subprocess.run(['git','init','-q',str(root)],check=True)
            subprocess.run(['git','-c','user.name=Fixture','-c','user.email=fixture@example.invalid',
                            '-c','commit.gpgsign=false','commit','--allow-empty','-qm','fixture'],cwd=root,check=True)
            head=observer.git(root,'rev-parse','HEAD').decode().strip(); out=Path(raw)/'observation.json'
            result=subprocess.run([sys.executable,str(ROOT/'scripts/observe-a9-advisory.py'),
                '--repo-root',str(root),'--base-sha',head,'--head-sha',head,'--feature','fixture',
                '--contract',str(root/'absent.json'),'--output',str(out)],capture_output=True,text=True)
            self.assertEqual(result.returncode,3,result.stderr)
            self.assertEqual(json.loads(out.read_text())['result'],'NOT_RUN')


if __name__ == '__main__':
    unittest.main()
