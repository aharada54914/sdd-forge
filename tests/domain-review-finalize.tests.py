#!/usr/bin/env python3
"""Synthetic regression fixtures for the packaged domain review gate, never live proof."""
import copy
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
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = 'powershell' if os.name == 'nt' else 'bash'
SCRIPT = ROOT / 'plugins/sdd-domain/scripts/finalize-domain-review.py'
A = ['CONTEXT-BOUNDARY-CLARITY', 'RELATION-PATTERN-VALID', 'EVENT-COVERAGE',
     'TERM-UNIQUENESS', 'AGGREGATE-CONTEXT-OWNERSHIP', 'CONCEPT-DISTINCTION-JUSTIFIED',
     'MULTI-ROLE-CONCEPT', 'STAKEHOLDER-PERSPECTIVE-COVERAGE', 'NAME-SEMANTIC-FIT',
     'DOMAIN-MODEL-STATUS-PRESENT']
B = ['INVARIANT-VERIFIABLE', 'TRANSACTION-BOUNDARY-REALISTIC', 'NO-GOD-AGGREGATE',
     'NO-ANEMIC-MODEL', 'LIFECYCLE-DEFINED', 'AGGREGATE-SIZE-PROPORTIONATE']
FILES = ['domain/domain-story.md', 'domain/event-storming.md', 'domain/concept-model.md',
         'domain/ubiquitous-language.md', 'domain/context-map.md', 'domain/message-flow.md',
         'domain/domain-contract.json', 'domain/aggregates/Order.md',
         'plugins/sdd-domain/references/domain-review-calibration.md']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def read(path):
    return json.loads(path.read_bytes())


def core():
    spec = importlib.util.spec_from_file_location('domain_finalizer_under_test', SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class Fixture:
    def __init__(self, owner, round_number=1, fail=None, runtime=None, crlf=False):
        self.runtime = runtime or RUNTIME
        self.owner = owner
        temporary = tempfile.TemporaryDirectory(prefix='domain-finalizer-test-')
        owner.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.round_number = round_number
        self.round = self.root / f'reports/domain-review/attempt-1/round-{round_number}'
        self.ledger = self.root / 'reports/review-context/identity-ledger.json'
        self.script = self.root / SCRIPT.relative_to(ROOT)
        shutil.copytree(ROOT / 'plugins/sdd-domain', self.root / 'plugins/sdd-domain')
        quality = self.root / 'plugins/sdd-quality-loop/scripts'
        quality.mkdir(parents=True)
        shutil.copytree(ROOT / 'plugins/sdd-quality-loop/scripts/lib', quality / 'lib')
        for name in ('initialize-review-identity.py', 'validate-review-context-set.sh',
                     'validate-review-context-set.ps1'):
            shutil.copy2(ROOT / 'plugins/sdd-quality-loop/scripts' / name, quality / name)
        for name in FILES:
            path = self.root / name
            if path.exists():
                continue
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('Domain-Model-Status: Pending\n' if name.endswith('context-map.md')
                            else '{"schema":"domain-contract/v1"}\n' if name.endswith('.json')
                            else '# Synthetic domain fixture\n', encoding='utf-8')
        if crlf:
            (self.root / 'domain/context-map.md').write_bytes(b'Domain-Model-Status: Pending\r\n')
        self.env = dict(os.environ, COPILOT_HOME=str(self.root / 'native'))
        events = self.root / 'native/session-state/synthetic-host/events.jsonl'
        save(events, dict(type='session.start', id='synthetic-host-event', parentId=None,
                         data=dict(producer='copilot-agent', version=1, sessionId='synthetic-host',
                                   context=dict(cwd=str(self.root)))))
        events.write_text(json.dumps(read(events)) + '\n', encoding='utf-8')
        self.checked([sys.executable, str(quality / 'initialize-review-identity.py'),
                      '--root', str(self.root), '--copilot-events', str(events)])
        for number in range(1, round_number + 1):
            if number > 1:
                with (self.root / FILES[0]).open('a', encoding='utf-8') as stream:
                    stream.write(f'Round {number} substantive fixture change.\n')
            if self.runtime == 'powershell':
                command = ['pwsh', '-NoProfile', '-File', str(self.root / 'plugins/sdd-domain/scripts/domain-review-precheck.ps1'), '-Attempt', '1', '-Round', str(number)]
                command += ['-EditSummary', 'synthetic fixture edit'] if number > 1 else []
            else:
                command = ['bash', str(self.root / 'plugins/sdd-domain/scripts/domain-review-precheck.sh'), '1', str(number)]
                command += ['--edit-summary=synthetic fixture edit'] if number > 1 else []
            self.checked(command)
        self.paths = FILES + [(self.round / 'precheck-result.json').relative_to(self.root).as_posix()]
        self.reserve('a', self.paths)
        self.output('a', fail if fail and fail[0] == 'a' else None)
        self.before = self.snapshot_inputs()

    def checked(self, command):
        result = subprocess.run(command, cwd=self.root, env=self.env, capture_output=True, text=True, timeout=90)
        self.owner.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def invocation(self, role):
        return self.round / f'reviewer-{role}-invocation.json'

    def reviewer(self, role):
        return self.round / f'reviewer-{role}.json'

    def reserve(self, role, paths):
        prior = read(self.ledger)['records'][-1]
        manifest = dict(schema='review-context-invocation/v2', stage='domain', role=f'domain-reviewer-{role}',
                        feature='sdd-domain-model', input_mode='file-manifest', fallback_mode='none', read_only=True,
                        run_id=f'synthetic-review-{role}', host_session_id=f'synthetic-session-{role}',
                        sequence=prior['sequence'] + 1, previous_record_sha256=prior['record_sha256'],
                        identity_ledger_path='reports/review-context/identity-ledger.json',
                        identity_ledger_sha256=digest(self.ledger),
                        allowed_input_manifest=[dict(path=p, sha256=digest(self.root / p)) for p in paths])
        save(self.invocation(role), manifest)
        validator = self.root / 'plugins/sdd-quality-loop/scripts/validate-review-context-set'
        command = (['pwsh', '-NoProfile', '-File', str(validator.with_suffix('.ps1')), '-Manifest', str(self.invocation(role)), '-RepositoryRoot', str(self.root), '-Reserve']
                   if self.runtime == 'powershell' else ['bash', str(validator.with_suffix('.sh')), str(self.invocation(role)), str(self.root), '--reserve'])
        self.checked(command)

    def output(self, role, fail=None):
        manifest = read(self.invocation(role))
        checks = []
        for identifier in A if role == 'a' else B:
            severity = ('Minor' if identifier in ('STAKEHOLDER-PERSPECTIVE-COVERAGE', 'NAME-SEMANTIC-FIT', 'AGGREGATE-SIZE-PROPORTIONATE')
                        else 'Critical' if identifier in ('AGGREGATE-CONTEXT-OWNERSHIP', 'DOMAIN-MODEL-STATUS-PRESENT', 'INVARIANT-VERIFIABLE') else 'Major')
            checks.append(dict(id=identifier, severity=severity, result='PASS', finding='Private synthetic finding must not enter bridge.'))
        verdict = 'PASS'
        if fail:
            _, identifier, severity = fail
            check = next(c for c in checks if c['id'] == identifier)
            check.update(result='FAIL', severity=severity)
            verdict = ('PASS' if severity == 'Minor' else 'BLOCKED') if self.round_number == 3 else 'NEEDS_WORK'
        save(self.reviewer(role), dict(schema=f'domain-reviewer-{role}/v1', stage='domain', role=f'domain-reviewer-{role}',
                                      run_id=manifest['run_id'], host_session_id=manifest['host_session_id'],
                                      allowed_input_manifest=manifest['allowed_input_manifest'], verdict=verdict, checks=checks))

    def run(self, mode='finalize', runtime=None, wrapper=False):
        runtime = runtime or self.runtime
        command = [sys.executable, str(self.script)]
        if wrapper:
            command = (['bash', str(self.script.with_suffix('.sh'))] if runtime == 'bash'
                       else ['pwsh', '-NoProfile', '-File', str(self.script.with_suffix('.ps1'))])
        return subprocess.run(command + ['--root', str(self.root), '--attempt', '1', '--round', str(self.round_number),
                                         '--mode', mode, '--runtime', runtime], cwd=self.root, env=self.env,
                              capture_output=True, text=True, timeout=90)

    def prepare_b(self, fail=None):
        self.owner.assert_success(self.run('summary'))
        self.reserve('b', self.paths + [(self.round / 'integrated-summary.json').relative_to(self.root).as_posix()])
        self.output('b', fail)

    def snapshot_inputs(self):
        return {p: (self.root / p).read_bytes() for p in FILES}


class DomainFinalizerTests(unittest.TestCase):
    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def assert_blocked(self, fixture, mode='finalize'):
        result = fixture.run(mode)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((fixture.round / 'domain-review-contract.json').exists())
        self.assertFalse((fixture.round / 'report.md').exists())
        self.assertEqual(fixture.snapshot_inputs(), fixture.before)

    def test_product_entrypoints_exist(self):
        for suffix in ('.py', '.sh', '.ps1'):
            self.assertTrue(SCRIPT.with_suffix(suffix).is_file(), 'missing packaged finalizer ' + suffix)

    def test_clean_gate_and_readonly_verify_through_both_wrappers(self):
        for runtime in (('powershell',) if os.name == 'nt' else ('bash', 'powershell')):
            with self.subTest(runtime=runtime):
                f = Fixture(self)
                f.prepare_b()
                self.assert_success(f.run(runtime=runtime, wrapper=True))
                contract = read(f.round / 'domain-review-contract.json')
                self.assertEqual((contract['verdict'], contract['warningCount']), ('PASS', 0))
                self.assertIs(contract['cross_model_required'], True)
                self.assertEqual(contract['human_approval'], 'Pending')
                self.assertEqual([r['role'] for r in contract['reviewers']], ['domain-reviewer-a', 'domain-reviewer-b'])
                self.assertEqual((f.root / 'domain/context-map.md').read_text(), 'Domain-Model-Status: Pending\n')
                before = {p.name: p.read_bytes() for p in f.round.iterdir() if p.is_file()}
                ledger = f.ledger.read_bytes()
                self.assert_success(f.run('verify', runtime=runtime))
                self.assertEqual(before, {p.name: p.read_bytes() for p in f.round.iterdir() if p.is_file()})
                self.assertEqual(f.ledger.read_bytes(), ledger)
                self.assertEqual(f.snapshot_inputs(), f.before)
                self.assertNotEqual(f.run().returncode, 0)
                self.assertEqual(before, {p.name: p.read_bytes() for p in f.round.iterdir() if p.is_file()})

    def test_crlf_inputs_match_the_actual_powershell_precheck(self):
        runtimes = ('powershell',) if os.name == 'nt' else ('bash', 'powershell')
        precheck_digests = []
        for runtime in runtimes:
            with self.subTest(runtime=runtime):
                f = Fixture(self, runtime=runtime, crlf=True)
                f.prepare_b()
                self.assert_success(f.run())
                for verifier in runtimes:
                    self.assert_success(f.run('verify', runtime=verifier))
                self.assertEqual(f.snapshot_inputs(), f.before)
                precheck_digests.append(read(f.round / 'precheck-result.json')['input_sha256'])
        self.assertEqual(len(set(precheck_digests)), 1)

    def test_bridge_is_derived_and_does_not_leak_findings(self):
        f = Fixture(self)
        self.assert_success(f.run('summary'))
        bridge = read(f.round / 'integrated-summary.json')
        self.assertEqual(bridge['counts'], dict(PASS=10, FAIL=0, SKIP=0))
        self.assertEqual([c['id'] for c in bridge['checks']], A)
        self.assertNotIn('Private synthetic finding', json.dumps(bridge))
        self.assertNotEqual(f.run('summary').returncode, 0)

    def test_round_verdict_and_warning_arithmetic(self):
        cases = [(1, ('a', A[0], 'Major'), 'NEEDS_WORK', 0),
                 (3, ('a', A[0], 'Major'), 'BLOCKED', 0),
                 (1, ('a', A[7], 'Minor'), 'NEEDS_WORK', 0),
                 (3, ('a', A[7], 'Minor'), 'PASS', 1)]
        for number, failure, expected, warning in cases:
            with self.subTest(round=number, severity=failure[2]):
                f = Fixture(self, number, failure)
                f.prepare_b()
                self.assert_success(f.run())
                contract = read(f.round / 'domain-review-contract.json')
                self.assertEqual((contract['verdict'], contract['warningCount']), (expected, warning))

    def test_invalid_reviewer_output_never_publishes(self):
        mutations = [lambda d: d.update(host_session_id='wrong-session'),
                     lambda d: d.update(stage='impl'),
                     lambda d: d.update(verdict='BLOCKED'),
                     lambda d: d.update(unexpected=True),
                     lambda d: d['checks'].pop(),
                     lambda d: d['checks'].reverse(),
                     lambda d: d['checks'][0].update(severity='Minor'),
                     lambda d: d['checks'].append(copy.deepcopy(d['checks'][0])),
                     lambda d: d['checks'][0].update(result='SKIP'),
                     lambda d: d['allowed_input_manifest'][0].update(sha256='0' * 64)]
        for mutate in mutations:
            with self.subTest(mutation=mutate):
                f = Fixture(self)
                f.prepare_b()
                document = read(f.reviewer('b'))
                mutate(document)
                save(f.reviewer('b'), document)
                self.assert_blocked(f)

    def test_summary_leak_or_semantic_tamper_is_rejected_even_when_b_pins_it(self):
        for field in ('finding', 'counts', 'numeric-alias', 'encoding'):
            with self.subTest(field=field):
                f = Fixture(self)
                self.assert_success(f.run('summary'))
                path = f.round / 'integrated-summary.json'
                bridge = read(path)
                if field == 'finding':
                    bridge['checks'][0]['finding'] = 'leaked raw finding'
                elif field == 'counts':
                    bridge['counts']['FAIL'] = 99
                elif field == 'numeric-alias':
                    bridge['checks'][0]['counts']['PASS'] = True
                save(path, bridge)
                if field == 'encoding':
                    path.write_text(json.dumps(bridge) + '\n', encoding='utf-8')
                f.reserve('b', f.paths + [path.relative_to(f.root).as_posix()])
                f.output('b')
                self.assert_blocked(f)

    def test_missing_canonical_input_is_rejected_before_summary(self):
        f = Fixture(self)
        for path in (f.invocation('a'), f.reviewer('a')):
            document = read(path)
            document['allowed_input_manifest'] = [p for p in document['allowed_input_manifest'] if p['path'] != 'domain/concept-model.md']
            save(path, document)
        self.assert_blocked(f, 'summary')

    def test_unreserved_b_cannot_pass_as_a_prospective_valid_reservation(self):
        f = Fixture(self)
        f.prepare_b()
        ledger = read(f.ledger)
        ledger['records'].pop()
        save(f.ledger, ledger)
        self.assert_blocked(f)

    def test_changed_input_and_rebound_current_hashes_do_not_replace_precheck(self):
        f = Fixture(self)
        f.prepare_b()
        target = f.root / 'domain/domain-story.md'
        target.write_text('Changed substantive domain content.\n', encoding='utf-8')
        f.before = f.snapshot_inputs()
        for role in ('a', 'b'):
            for path in (f.invocation(role), f.reviewer(role)):
                document = read(path)
                next(e for e in document['allowed_input_manifest'] if e['path'] == 'domain/domain-story.md')['sha256'] = digest(target)
                save(path, document)
        self.assert_blocked(f)

    def test_linked_output_and_existing_lock_cannot_publish(self):
        for kind in ('symlink', 'lock'):
            with self.subTest(kind=kind):
                f = Fixture(self)
                f.prepare_b()
                if kind == 'lock':
                    (f.root / 'reports/domain-review/.domain-review.lock').mkdir()
                else:
                    outside = f.root / 'untouched.json'
                    outside.write_text('sentinel')
                    try:
                        (f.round / 'integrated-verdict.json').symlink_to(outside)
                    except OSError:
                        self.skipTest('host cannot create symlink fixtures')
                self.assert_blocked(f)
                if kind == 'symlink':
                    self.assertEqual(outside.read_text(), 'sentinel')

    def test_persisted_reservation_must_bind_the_input_set(self):
        f = Fixture(self)
        f.prepare_b()
        ledger = read(f.ledger)
        ledger['records'][-1].pop('allowed_inputs_sha256')
        save(f.ledger, ledger)
        self.assert_blocked(f)

    def test_evidence_or_aggregate_changes_between_validation_and_publish_fail(self):
        module = core()
        for target in ('evidence', 'aggregate'):
            with self.subTest(target=target):
                f = Fixture(self)
                f.prepare_b()
                review = module.Review(f.root, 1, 1, RUNTIME)
                outputs = review.derive()
                if target == 'evidence':
                    f.reviewer('b').write_bytes(f.reviewer('b').read_bytes() + b' ')
                else:
                    (f.root / 'domain/aggregates/Late.md').write_text('New unreviewed aggregate')
                with self.assertRaisesRegex(module.Invalid, 'changed during finalization'):
                    review.publish(outputs)
                self.assertFalse((f.round / 'domain-review-contract.json').exists())
                self.assertFalse((f.round / 'integrated-verdict.json').exists())

    def test_publish_rolls_back_on_failure_and_never_exposes_contract_early(self):
        f = Fixture(self)
        f.prepare_b()
        module = core()
        review = module.Review(f.root, 1, 1, RUNTIME)
        outputs = review.derive()
        self.assertEqual(list(outputs)[-1], 'domain-review-contract.json')
        original = os.link
        published = []

        def fail_second(source, destination):
            published.append(destination.name)
            if len(published) == 2:
                raise OSError('synthetic publication failure')
            return original(source, destination)

        with mock.patch.object(module.os, 'link', side_effect=fail_second):
            with self.assertRaises(OSError):
                review.publish(outputs)
        self.assertEqual(published, ['integrated-verdict.json', 'report.md'])
        self.assertFalse(any((f.round / name).exists() for name in outputs))
        self.assertFalse(list(f.round.glob('.finalize-*')))
        self.assert_success(f.run())

    def test_mutation_during_publication_removes_partial_outputs(self):
        f = Fixture(self)
        f.prepare_b()
        module = core()
        review = module.Review(f.root, 1, 1, RUNTIME)
        outputs = review.derive()
        original = os.link

        def change_after_first_link(source, destination):
            original(source, destination)
            if destination.name == 'integrated-verdict.json':
                f.reviewer('a').write_bytes(f.reviewer('a').read_bytes() + b' ')

        with mock.patch.object(module.os, 'link', side_effect=change_after_first_link):
            with self.assertRaisesRegex(module.Invalid, 'changed during finalization'):
                review.publish(outputs)
        self.assertFalse(any((f.round / name).exists() for name in outputs))
        self.assertFalse(list(f.round.glob('.finalize-*')))

    @unittest.skipUnless(os.name == 'nt', 'real Windows junction requires Windows')
    def test_windows_junction_evidence_parent_is_rejected(self):
        f = Fixture(self)
        f.prepare_b()
        original = f.round
        target = f.root / 'junction-target'
        original.rename(target)
        result = subprocess.run(['cmd', '/c', 'mklink', '/J', str(original), str(target)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        try:
            self.assertNotEqual(f.run().returncode, 0)
            self.assertFalse((target / 'domain-review-contract.json').exists())
        finally:
            os.rmdir(original)
            target.rename(original)

    def test_duplicate_json_keys_fail_closed(self):
        f = Fixture(self)
        f.prepare_b()
        path = f.reviewer('b')
        original = path.read_text()
        path.write_text(original.replace('"stage": "domain",', '"stage": "domain", "stage": "domain",', 1))
        self.assert_blocked(f)

    def test_verified_artifact_tampering_is_detected_without_repair(self):
        f = Fixture(self)
        f.prepare_b()
        self.assert_success(f.run())
        path = f.round / 'domain-review-contract.json'
        document = read(path)
        document['warningCount'] = 10
        save(path, document)
        before = path.read_bytes()
        self.assertNotEqual(f.run('verify').returncode, 0)
        self.assertEqual(path.read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
