#!/usr/bin/env python3
"""Synthetic Git/CLI regressions; never issue real approvals or release evidence."""
import copy
import contextlib
import io
import hashlib
import importlib.util
import json
import os
import re
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
    git('init', '-q'); git('config', 'core.autocrlf', 'false')
    # 2026-10-21: no detached auto maintenance may outlive fixture cleanup (.git deletion).
    git('config', 'maintenance.auto', 'false'); git('config', 'gc.auto', '0')
    git('add', '.')
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
                       lambda r:r.update(authorization_checked=True), lambda r:r.pop('trusted_tooling_sha256'),
                       lambda r:r.update(trusted_tooling_sha256='invalid'), lambda r:r['operations'].pop(),
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

    def test_manual_contract_accepts_repository_ancestor_alias(self):
        with tempfile.TemporaryDirectory(prefix='a9-root-alias-') as raw:
            alias = Path(raw).resolve() / 'repo'
            try:
                alias.symlink_to(self.root.resolve(), target_is_directory=True)
            except OSError:
                self.skipTest('symlink privilege unavailable')
            for contract in (alias / self.contract.relative_to(self.root), self.contract.resolve()):
                with self.subTest(contract_form='alias' if contract.is_relative_to(alias) else 'canonical'):
                    record = observer.collect(alias, self.base, self.head, 'fixture', contract)
                    self.assertEqual(record['result'], 'PASS')
                    self.assertEqual(record['artifacts']['verification_contract'], self.record['artifacts']['verification_contract'])

    def test_manual_contract_under_aliased_root_rejects_internal_symlink(self):
        with tempfile.TemporaryDirectory(prefix='a9-root-alias-negative-') as raw:
            alias = Path(raw).resolve() / 'repo'
            internal = self.root / 'untracked-contract-alias'
            try:
                alias.symlink_to(self.root.resolve(), target_is_directory=True)
                internal.symlink_to(self.contract.parent.resolve(), target_is_directory=True)
            except OSError:
                self.skipTest('symlink privilege unavailable')
            try:
                with self.assertRaisesRegex(ValueError, 'symlinks and reparse points'):
                    observer.collect(alias, self.base, self.head, 'fixture', alias / internal.name / self.contract.name)
            finally:
                internal.unlink()

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

    def test_trusted_validator_failure_does_not_expose_private_diagnostic(self):
        error = observer.evidence.ValidatorError('schema-discovery-failed', 'PRIVATE_SENTINEL')
        with patch.object(observer.evidence, 'validate_document', side_effect=error):
            self.assertEqual(self.check(self.record), ['advisory observation rejected: ValidatorError'])

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


class RequestAndWorkflowTests(unittest.TestCase):
    def request_fixture(self, root, poison=False):
        base, head, contract = fixture(root)
        if poison:
            (root/'plugins/sdd-quality-loop/scripts/resolve-project-context.py').write_text(
                "raise RuntimeError('PR_SOURCE_EXECUTED')")
            doc = json.loads(contract.read_text())
            for check in doc['checks']:
                check['command'] = "python -c \"open('CONTRACT_COMMAND_EXECUTED','w').write('bad')\""
            contract.write_text(json.dumps(doc))
        request = root / 'sdd/a9-advisory-request.json'
        request.write_text(json.dumps({'schema': 'a9-advisory-request/v1', 'feature': 'fixture',
            'verification_contract': contract.relative_to(root).as_posix()}))
        observer.git(root, 'add', '.')
        observer.git(root, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                     '-c', 'commit.gpgsign=false', 'commit', '-qm', 'explicit synthetic request')
        return base, observer.git(root, 'rev-parse', 'HEAD').decode().strip(), contract

    def invoke_request(self, root, base, head, output, expected=None, tooling=ROOT):
        extra = [] if expected is None else ['--expected-observation-sha256', expected]
        return subprocess.run([sys.executable, str(tooling/'scripts/observe-a9-advisory.py'),
            '--repo-root', str(root), '--base-sha', base, '--head-sha', head,
            '--request', 'sdd/a9-advisory-request.json', '--output', str(output), *extra],
            capture_output=True, text=True)

    def test_exact_head_request_executes_real_consumers_and_keeps_raw_output_private(self):
        with tempfile.TemporaryDirectory(prefix='a9-request-') as raw:
            root = Path(raw)/'repo'; root.mkdir(); base, head, contract = self.request_fixture(root, poison=True)
            output = Path(raw)/'private.json'
            result = self.invoke_request(root, base, head, output)
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            summary = json.loads(result.stdout); record = json.loads(output.read_text())
            self.assertEqual(summary['advisory_observation_sha256'], observer.ownership.canonical_digest(record))
            self.assertFalse(summary['authorization_checked'])
            self.assertEqual(record['request']['verification_contract'], contract.relative_to(root).as_posix())
            self.assertNotIn(raw, result.stdout + result.stderr)
            self.assertNotIn('contents', result.stdout)
            self.assertFalse((root/'CONTRACT_COMMAND_EXECUTED').exists())
            self.assertNotIn('PR_SOURCE_EXECUTED', result.stdout + result.stderr)
            if os.name != 'nt': self.assertEqual(output.stat().st_mode & 0o777, 0o600)

    def test_private_reconstruction_matches_whole_observation_across_directories(self):
        with tempfile.TemporaryDirectory(prefix='a9-reconstruction-') as raw:
            directory = Path(raw)
            first = directory/'original'; first.mkdir()
            base, head, _ = self.request_fixture(first)
            second = directory/'independent-checkout'
            # Checkout filters must not alter the committed fixture bytes on Windows.
            observer.git(directory, '-c', 'core.autocrlf=false', 'clone', '--quiet',
                         '--no-hardlinks', str(first), str(second))
            original = directory/'original.json'
            result = self.invoke_request(first, base, head, original)
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            digest = json.loads(result.stdout)['observation_sha256']
            restored = directory/'restored.json'
            result = self.invoke_request(second, base, head, restored, expected=digest)
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            self.assertEqual(restored.read_bytes(), original.read_bytes())
            summary = json.loads(result.stdout)
            self.assertTrue(summary['expected_digest_matched'])
            self.assertFalse(summary['original_ci_authenticated'])
            self.assertFalse(summary['authorization_checked'])
            self.assertNotIn(raw, result.stdout + result.stderr)
            # The complete record, including raw coverage, projection, and tool identity,
            # must agree before any output is published.
            mismatch = directory/'mismatch.json'
            result = self.invoke_request(second, base, head, mismatch, expected='sha256:' + '0'*64)
            self.assertEqual(result.returncode, 1)
            self.assertFalse(mismatch.exists())
            self.assertNotIn(raw, result.stdout + result.stderr)

    def test_changed_trusted_tooling_cannot_reconstruct_original_observation(self):
        with tempfile.TemporaryDirectory(prefix='a9-reconstruction-tooling-') as raw:
            directory = Path(raw)
            root = directory/'repo'; root.mkdir()
            base, head, _ = self.request_fixture(root)
            original = directory/'original.json'
            result = self.invoke_request(root, base, head, original)
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            before = json.loads(original.read_text())
            digest = json.loads(result.stdout)['observation_sha256']
            tooling = directory/'different-trusted-tooling'; tooling.mkdir()
            observer.git(tooling, 'init', '-q')
            for relative in ('plugins', 'contracts'):
                shutil.copytree(ROOT/relative, tooling/relative,
                                ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
            (tooling/'scripts').mkdir()
            shutil.copy2(ROOT/'scripts/observe-a9-advisory.py', tooling/'scripts/observe-a9-advisory.py')
            collector = tooling/'scripts/observe-a9-advisory.py'
            collector.write_bytes(collector.read_bytes() + b'\n# Synthetic tooling version change.\n')
            changed = directory/'changed.json'
            result = self.invoke_request(root, base, head, changed, tooling=tooling)
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            after = json.loads(changed.read_text())
            self.assertEqual(before['artifacts'], after['artifacts'])
            self.assertNotEqual(before['trusted_tooling_sha256'], after['trusted_tooling_sha256'])
            mismatch = directory/'wrong-tooling.json'
            result = self.invoke_request(root, base, head, mismatch, expected=digest, tooling=tooling)
            self.assertEqual(result.returncode, 1)
            self.assertFalse(mismatch.exists())
            self.assertNotIn(raw, result.stdout + result.stderr)

    def test_missing_inputs_are_named_without_paths_and_uncommitted_request_rejects(self):
        with tempfile.TemporaryDirectory(prefix='a9-request-missing-') as raw:
            root = Path(raw)/'repo'; root.mkdir(); base, head, contract = self.request_fixture(root)
            request = root/'sdd/a9-advisory-request.json'; original=request.read_bytes()
            request.unlink()
            result=self.invoke_request(root, base, head, Path(raw)/'absent.json')
            self.assertEqual(result.returncode, 1)
            self.assertEqual(json.loads(result.stdout)['missing_inputs'], ['advisory_request'])
            self.assertNotIn(raw, result.stdout + result.stderr)
            request.write_bytes(original + b' ')
            result=self.invoke_request(root, base, head, Path(raw)/'modified.json')
            self.assertEqual(result.returncode, 1)
            self.assertFalse((Path(raw)/'modified.json').exists())
            request.write_bytes(original)
            original_contract = contract.read_bytes(); contract.unlink()
            result = self.invoke_request(root, base, head, Path(raw)/'no-contract.json')
            self.assertEqual(json.loads(result.stdout)['missing_inputs'], ['verification_contract'])
            contract.write_bytes(original_contract)
            contract.with_name('evidence.log').unlink()
            result = self.invoke_request(root, base, head, Path(raw)/'no-proof.json')
            self.assertEqual(json.loads(result.stdout)['missing_inputs'], ['verification_evidence'])

    def test_optional_advisory_finding_is_preserved_without_blocking_delivery(self):
        with tempfile.TemporaryDirectory(prefix='a9-advisory-finding-') as raw:
            root=Path(raw);base,head,contract=self.request_fixture(root)
            registry_path=root/'contracts/capability-registry.json'
            registry=json.loads(registry_path.read_text())
            next(gate for gate in registry['gates'] if gate['id']=='check-installed-plugin-drift')['blocking']=False
            next(cap for cap in registry['capabilities'] if cap['id']=='cli-library')['gate_ids'].append('check-installed-plugin-drift')
            registry_path.write_text(json.dumps(registry))
            doc=json.loads(contract.read_text())
            finding=copy.deepcopy(doc['checks'][0])
            finding.update(id='check-installed-plugin-drift',required=False,passes=False,exit_code=1,
                waiver_reason='Advisory finding retained for triage; Registry marks this check nonblocking.')
            doc['checks'].append(finding);contract.write_text(json.dumps(doc))
            observer.git(root,'add','.')
            observer.git(root,'-c','user.name=Fixture','-c','user.email=fixture@example.invalid',
                         '-c','commit.gpgsign=false','commit','-qm','synthetic optional finding')
            head=observer.git(root,'rev-parse','HEAD').decode().strip()
            record=observer.collect(root,base,head,'fixture',contract)
            self.assertEqual(record['state'],'advisory')
            self.assertEqual(record['result'],'PASS')
            plan=observer.document(record['artifacts']['selected_plan'])
            actual=next(check for check in plan['checks'] if check['id']=='check-installed-plugin-drift')
            self.assertEqual(actual['result'],'failed')
            self.assertFalse(actual['blocking'])
            self.assertEqual(observer.validate_observation(record,head,base,root),[])

    def test_required_phase_executes_but_cannot_count_as_advisory_cycle(self):
        with tempfile.TemporaryDirectory(prefix='a9-required-phase-') as raw:
            root=Path(raw)/'repo';root.mkdir();base, head, contract=self.request_fixture(root)
            context=root/'sdd/project-context.yaml'
            value=observer.document(observer.artifact(context.read_bytes()))
            value['workflow'].update(artifact_layout='facet-hybrid', capability_enforcement='required')
            data=context.read_bytes().replace(b'legacy-seven-layer', b'facet-hybrid').replace(b'capability_enforcement: "advisory"', b'capability_enforcement: "required"')
            context.write_bytes(data)
            (root/'sdd/.approved-context/project-context.approved.yaml').write_bytes(data)
            approval=root/'sdd/project-context.approval.json'
            doc=json.loads(approval.read_text());doc['context_sha256']=observer.ownership.canonical_digest(value)
            approval.write_text(json.dumps(doc))
            observer.git(root, 'add', '.')
            observer.git(root, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                         '-c', 'commit.gpgsign=false', 'commit', '-qm', 'synthetic required phase')
            head=observer.git(root, 'rev-parse', 'HEAD').decode().strip()
            result=self.invoke_request(root,base,head,Path(raw)/'required.json')
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            record=json.loads((Path(raw)/'required.json').read_text())
            self.assertEqual(record['state'],'required')
            self.assertEqual(record['schema'],'a9-required-observation/v1')
            self.assertTrue(observer.validate_observation(record,head,base,root))
            self.assertEqual(observer.validate_observation(record,head,base,root,expected_state='required'),[])
            self.assertNotIn('advisory_observation_sha256',json.loads(result.stdout))
            (root/'unowned-required-fixture.txt').write_text('must block required coverage')
            observer.git(root,'add','unowned-required-fixture.txt')
            observer.git(root,'-c','user.name=Fixture','-c','user.email=fixture@example.invalid',
                         '-c','commit.gpgsign=false','commit','-qm','synthetic required coverage failure')
            failing_head=observer.git(root,'rev-parse','HEAD').decode().strip()
            failed=self.invoke_request(root,base,failing_head,Path(raw)/'failed-required.json')
            self.assertEqual(failed.returncode,1)
            self.assertFalse((Path(raw)/'failed-required.json').exists())

    def test_active_context_removal_and_mixed_tuple_fail_closed(self):
        for mode in ('missing', 'mixed', 'malformed'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory(prefix='a9-active-negative-') as raw:
                root=Path(raw)/'repo';root.mkdir();base,head,contract=self.request_fixture(root)
                context=root/'sdd/project-context.yaml'
                if mode=='missing': context.unlink()
                elif mode=='mixed':
                    context.write_bytes(context.read_bytes().replace(b'capability_enforcement: "advisory"',
                                                                   b'capability_enforcement: "required"'))
                else: context.write_text('malformed: [')
                observer.git(root,'add','sdd/project-context.yaml')
                observer.git(root,'-c','user.name=Fixture','-c','user.email=fixture@example.invalid',
                             '-c','commit.gpgsign=false','commit','-qm','synthetic invalid activation')
                head=observer.git(root,'rev-parse','HEAD').decode().strip()
                result=self.invoke_request(root,base,head,Path(raw)/'rejected.json')
                self.assertEqual(result.returncode,1)
                self.assertNotIn('NOT_RUN',result.stdout+result.stderr)
                self.assertFalse((Path(raw)/'rejected.json').exists())

    def test_diverged_pr_base_uses_actual_merge_base_changed_paths(self):
        with tempfile.TemporaryDirectory(prefix='a9-diverged-base-') as raw:
            root=Path(raw); base, head, contract=self.request_fixture(root)
            observer.git(root, 'checkout', '--detach', base)
            (root/'plugins/sdd-ship/base-only.txt').write_text('base-only change')
            observer.git(root, 'add', '.')
            observer.git(root, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                         '-c', 'commit.gpgsign=false', 'commit', '-qm', 'base moved forward')
            moved=observer.git(root, 'rev-parse', 'HEAD').decode().strip()
            observer.git(root, 'checkout', '--detach', head)
            record=observer.collect(root, moved, head, 'fixture', contract)
            self.assertEqual(observer.validate_observation(record, head, moved, root), [])
            manifest=observer.document(record['artifacts']['facet_manifest'])
            self.assertNotIn('sdd-ship', manifest['affected_components'])

    def workflow_body(self, name):
        text=(ROOT/'.github/workflows/test.yml').read_text()
        match=re.search(r'^      - name: '+re.escape(name)+r'\n(?:(?!^      - |^  [a-z]).*\n)*?        run: \|\n((?:^          .*\n|^\s*\n)*)',text,re.M)
        self.assertIsNotNone(match, name)
        return '\n'.join(line[10:] for line in match[1].splitlines())

    def run_workflow_body(self, body, root, env):
        bash = 'bash'
        if sys.platform == 'win32':
            # PATH may select the Windows WSL launcher instead of Git Bash.
            git = shutil.which('git')
            candidates = (() if git is None else
                          (Path(git).parent / 'bash.exe', Path(git).parent.parent / 'bin/bash.exe'))
            bash = next((str(path) for path in candidates if path.is_file()), None)
            if bash is None:
                raise RuntimeError('Git for Windows Bash is required')
        # The Ubuntu workflow uses python3; native Windows may expose a Store alias.
        # Bind that command to this test's real interpreter, leaving the body intact.
        prelude = 'python3() { "$A9_TEST_PYTHON" "$@"; }\n'
        return subprocess.run([bash, '--noprofile', '--norc', '-e', '-c', prelude + body], cwd=root,
                              capture_output=True, text=True,
                              env={**os.environ, **env, 'A9_TEST_PYTHON': Path(sys.executable).as_posix()})

    def test_workflow_body_uses_installed_git_bash_and_current_python(self):
        with tempfile.TemporaryDirectory(prefix='a9-workflow-runtime-') as raw:
            root = Path(raw)
            git = root / 'Git install/cmd/git.exe'
            git.parent.mkdir(parents=True)
            git.touch()
            bash = root / 'Git install/bin/bash.exe'
            bash.parent.mkdir()
            bash.touch()
            with patch.object(sys, 'platform', 'win32'), \
                    patch.object(shutil, 'which', return_value=str(git)), \
                    patch.object(subprocess, 'run') as run:
                self.run_workflow_body('python3 -c "import sys"', root, {})
            command = run.call_args.args[0]
            self.assertEqual(Path(command[0]), bash)
            self.assertEqual(run.call_args.kwargs['env']['A9_TEST_PYTHON'], Path(sys.executable).as_posix())
            self.assertIn('python3() { "$A9_TEST_PYTHON" "$@"; }', command[-1])
            self.assertTrue(command[-1].endswith('python3 -c "import sys"'))

    def test_workflow_python3_executes_current_interpreter(self):
        with tempfile.TemporaryDirectory() as raw:
            result = self.run_workflow_body(
                "python3 -c 'import json, sys; print(json.dumps(sys.executable))'", Path(raw), {})
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertTrue(Path(json.loads(result.stdout)).samefile(sys.executable))

    def test_missing_git_bash_fails_without_falling_back_to_wsl(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            with patch.object(sys, 'platform', 'win32'), \
                    patch.object(shutil, 'which', return_value=str(root / 'cmd/git.exe')):
                with self.assertRaisesRegex(RuntimeError, 'Git for Windows Bash is required'):
                    self.run_workflow_body('exit 0', root, {})

    def test_actual_detection_body_never_calls_unactivated_or_removed_context_success(self):
        body=self.workflow_body('Detect advisory activation without executing repository code')
        for existing, event, active in (((), 'pull_request', 'false'), (('trusted',), 'pull_request', 'true'),
                (('subject',), 'pull_request', 'true'), (('trusted','subject'), 'push', 'false')):
            with self.subTest(existing=existing,event=event), tempfile.TemporaryDirectory() as raw:
                root=Path(raw)
                for directory in existing:
                    path=root/directory/'sdd/project-context.yaml';path.parent.mkdir(parents=True);path.write_text('DATA ONLY')
                output=root/'outputs'
                result=self.run_workflow_body(body,root,
                    {'A9_EVENT_NAME':event,'GITHUB_OUTPUT':str(output)})
                self.assertEqual(result.returncode,0,result.stderr)
                self.assertEqual(output.read_text(),'active='+active+'\n')
                self.assertFalse(json.loads(result.stdout)['advisory_observed'])

    def test_actual_collection_body_missing_trusted_tool_fails_without_using_pr_code(self):
        body=self.workflow_body('Collect actual advisory consumers with explicit request')
        with tempfile.TemporaryDirectory() as raw:
            root=Path(raw); subject=root/'subject/scripts';subject.mkdir(parents=True)
            (subject/'observe-a9-advisory.py').write_text("raise RuntimeError('PR_CODE_MUST_NOT_RUN')")
            result=self.run_workflow_body(body,root,{'RUNNER_TEMP':raw})
            self.assertEqual(result.returncode,1)
            self.assertEqual(json.loads(result.stdout)['missing_inputs'],['trusted_collector'])
            self.assertNotIn('PR_CODE_MUST_NOT_RUN', result.stdout+result.stderr)

    def test_release_git_failures_remain_captured_for_public_callers(self):
        with tempfile.TemporaryDirectory(prefix='a9-private-release-git-') as raw:
            code = """import importlib.util, pathlib, sys
spec=importlib.util.spec_from_file_location('candidate', sys.argv[1])
checker=importlib.util.module_from_spec(spec);spec.loader.exec_module(checker)
checker.ROOT=pathlib.Path(sys.argv[2])
try:
    checker.release_commits({'base_sha':'a'*40,'head_sha':'b'*40,'release':{'tag_name':'fixture'}})
except Exception as exc:
    print(type(exc).__name__)
"""
            result=subprocess.run([sys.executable,'-c',code,str(ROOT/'scripts/validate-a9-candidate.py'),raw],
                                  capture_output=True,text=True)
            self.assertEqual(result.returncode,0)
            self.assertEqual(result.stdout.strip(),'CalledProcessError')
            self.assertEqual(result.stderr,'')
            self.assertNotIn(raw,result.stdout+result.stderr)

if __name__ == '__main__':
    unittest.main()
