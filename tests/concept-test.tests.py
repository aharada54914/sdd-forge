#!/usr/bin/env python3
"""Concept Test acceptance: real signed evidence, stale inputs, and read-only gates."""
import copy
import errno
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import uuid

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'plugins/sdd-domain/scripts/validate-concept-test.py'
GENERATOR = ROOT / 'plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py'
spec = importlib.util.spec_from_file_location('concept', SCRIPT)
concept = importlib.util.module_from_spec(spec)
spec.loader.exec_module(concept)
IDENTITY = ROOT / 'plugins/sdd-quality-loop/scripts/initialize-review-identity.py'
identity_spec = importlib.util.spec_from_file_location('initial_review_identity', IDENTITY)
identity = importlib.util.module_from_spec(identity_spec)
identity_spec.loader.exec_module(identity)
VALIDATOR = ROOT / 'plugins/sdd-quality-loop/scripts/validate-review-context-set'
LEDGER = 'reports/review-context/identity-ledger.json'


def sha(data):
    return hashlib.sha256(data if isinstance(data, bytes) else data.encode()).hexdigest()


def chain(rows, records=()):
    """Independent ledger/v1 producer: rows are (stage, role, run, session, scratch, inputs)."""
    records = [dict(record) for record in records]
    for stage, role, run, session, scratch, inputs in rows:
        previous = records[-1]['record_sha256'] if records else ''
        record = dict(sequence=len(records) + 1, stage=stage, role=role, run_id=run,
                      host_session_id=session, previous_record_sha256=previous)
        text = f"{record['sequence']}|{stage}|{role}|{run}|{session}|{previous}"
        if scratch:
            record['scratch_declaration_sha256'] = scratch
            text += '|scratch-declaration-v1|' + scratch
        if inputs:
            record['allowed_inputs_sha256'] = inputs
            text += '|allowed-inputs-v1|' + inputs
        record['record_sha256'] = sha(text)
        records.append(record)
    return records


class ConceptTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.feature = self.root / 'specs/example'
        self.feature.mkdir(parents=True)
        (self.root / 'domain').mkdir()
        (self.root / 'sdd').mkdir()
        (self.root / 'contracts').mkdir()
        shutil.copyfile(ROOT / 'contracts/domain-contract.v2.schema.json', self.root / 'contracts/domain-contract.v2.schema.json')
        self.env = dict(os.environ, SDD_CONTEXT_KEY='isolated-concept-fixture-key',
                        HOME=str(self.root), USERPROFILE=str(self.root))
        self.env.pop('SDD_CONTEXT_KEY_FILE', None)
        self.write('domain/context-map.md', 'Domain-Model-Status: Approved\n')
        self.write('domain/domain-contract.json', {
            'schema': 'domain-contract/v2',
            'meta': {'version': '1.0.0', 'status': 'Approved', 'generated_from': ['domain/context-map.md']},
            'contexts': [{'name': 'catalog', 'description': 'Catalog', 'terms': [], 'aggregates': []}],
            'concepts': [{'id': 'CONCEPT-BOOK', 'name': 'Book', 'context': 'catalog',
                          'definition': 'A publication', 'essence': 'Published content',
                          'responsibilities': ['Identify publication'], 'evidence': ['domain/context-map.md']}]})
        self.write('specs/example/concept-test-seed.md', 'Find a publication.\n')
        self.write('sdd/approver-registry.yaml', 'schema: sdd-approver-registry/v1\napprovers:\n  - id: fixture\n    name: Synthetic approver\n')
        self.record = {'schema': 'concept-test/v1', 'feature': 'example',
                       'proposal': 'FITS_EXISTING_CONCEPTS', 'rationale': 'Publication identity already exists.',
                       'distinctions': [{'concepts': ['CONCEPT-BOOK'], 'judgment': 'same', 'confirmed': True}],
                       'inputs': [{'path': p, 'sha256': hashlib.sha256((self.root / p).read_bytes()).hexdigest()}
                                  for p in ['domain/domain-contract.json', 'domain/context-map.md',
                                            'specs/example/concept-test-seed.md']]}
        self.save()

    def write(self, path, value):
        # Pin the same bytes before hashing and after Git's text normalization.
        text = value if isinstance(value, str) else json.dumps(value)
        (self.root / path).write_bytes(text.encode('utf-8'))

    def save(self):
        self.write('specs/example/concept-test.json', self.record)
        self.write('specs/example/concept-test.md', '# Concept Test\n\n```json\n' + json.dumps(self.record) + '\n```\n')

    def gate(self, expected=0, env=None, wrapper=None):
        before = {p.relative_to(self.root): p.read_bytes() for p in (self.root / 'domain').rglob('*') if p.is_file()}
        command = wrapper or [sys.executable, str(SCRIPT)]
        result = subprocess.run(command + ['--root', str(self.root), '--feature', 'example'],
                                env=env or self.env, capture_output=True, text=True)
        self.assertEqual(expected, result.returncode, result.stdout + result.stderr)
        self.assertNotIn('Traceback', result.stderr)
        self.assertEqual(before, {p.relative_to(self.root): p.read_bytes() for p in (self.root / 'domain').rglob('*') if p.is_file()})
        return result

    def sign(self):
        with tempfile.TemporaryDirectory() as stage:
            output = Path(stage) / 'candidate'
            result = subprocess.run([sys.executable, str(GENERATOR), '--schema', 'sdd-concept-test-approval/v1',
                                     '--feature', 'example', '--content', str(self.feature / 'concept-test.json'),
                                     '--approver', 'fixture', '--status', 'Approved', '--stage-dir', str(output)],
                                    env=self.env, capture_output=True, text=True)
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            shutil.copyfile(output / 'specs/example/concept-test.approval.json', self.feature / 'concept-test.approval.json')

    def test_no_domain_skips(self):
        shutil.rmtree(self.root / 'domain')
        self.assertEqual('SKIP\n', self.gate().stdout)

    def test_fits_and_dispatchers(self):
        self.assertEqual('CONTINUE\n', self.gate().stdout)
        if os.name != 'nt' and shutil.which('sh'):
            self.gate(wrapper=['sh', str(SCRIPT.with_suffix('.sh'))])
        pwsh = shutil.which('pwsh')
        if pwsh:
            self.gate(wrapper=[pwsh, '-NoProfile', '-File', str(SCRIPT.with_suffix('.ps1'))])

    def test_all_human_decisions_with_real_signature(self):
        for proposal in ['NEW_CONCEPT_CANDIDATE', 'RESPONSIBILITY_CONFLICT', 'REQUIRES_HUMAN_DECISION']:
            for decision, code in [('proceed', 0), ('defer-to-domain-update', 2), ('rejected', 3)]:
                with self.subTest(proposal=proposal, decision=decision):
                    self.record.update(proposal=proposal, decision=decision)
                    self.save()
                    self.sign()
                    self.gate(code)

    def test_missing_or_invalid_evidence(self):
        original = copy.deepcopy(self.record)
        mutations = [lambda d: d.update(proposal='unknown'), lambda d: d.update(decision='unknown'),
                     lambda d: d.update(feature='other'), lambda d: d.update(rationale=''),
                     lambda d: d['distinctions'][0].update(confirmed=False),
                     lambda d: d['distinctions'][0].update(confirmed=1),
                     lambda d: d['distinctions'][0].update(concepts=[]),
                     lambda d: d['distinctions'][0].update(judgment='SAME'),
                     lambda d: d['distinctions'][0].update(concepts=['CONCEPT-MISSING']),
                     lambda d: d['inputs'][0].update(path='../outside'),
                     lambda d: d['inputs'][0].update(sha256='0' * 64),
                     lambda d: d['inputs'].append(d['inputs'][0]),
                     lambda d: d.update(inputs=[]), lambda d: d.update(distinctions=[])]
        for mutation in mutations:
            self.record = copy.deepcopy(original)
            mutation(self.record)
            self.save()
            self.gate(1)
        for proposal in ['NEW_CONCEPT_CANDIDATE', 'RESPONSIBILITY_CONFLICT', 'REQUIRES_HUMAN_DECISION']:
            self.record = dict(original, proposal=proposal)
            self.save()
            self.gate(1)
        self.record = original
        self.save()
        for filename in ['concept-test.json', 'concept-test.md']:
            target = self.feature / filename
            data = target.read_bytes()
            target.unlink()
            self.gate(1)
            target.write_bytes(data)
        self.write('specs/example/concept-test.json', '{"schema":')
        self.gate(1)

    def test_every_md_json_field_difference_blocks(self):
        original = copy.deepcopy(self.record)
        for proposal in ['FITS_EXISTING_CONCEPTS', 'NEW_CONCEPT_CANDIDATE', 'RESPONSIBILITY_CONFLICT', 'REQUIRES_HUMAN_DECISION']:
            self.record = dict(original, proposal=proposal)
            if proposal != 'FITS_EXISTING_CONCEPTS':
                self.record['decision'] = 'proceed'
            self.save()
            for field in self.record:
                with self.subTest(proposal=proposal, field=field):
                    changed = dict(self.record, **{field: None})
                    self.write('specs/example/concept-test.md', '```json\n' + json.dumps(changed) + '\n```\n')
                    self.gate(1)
            self.save()

    def test_markdown_boolean_numeric_mismatch(self):
        changed = copy.deepcopy(self.record)
        changed['distinctions'][0]['confirmed'] = 1
        self.write('specs/example/concept-test.md', '```json\n' + json.dumps(changed) + '\n```\n')
        self.gate(1)

    def test_stale_missing_or_symlinked_input(self):
        target = self.root / 'specs/example/concept-test-seed.md'
        original = target.read_bytes()
        target.write_bytes(original + b'changed')
        self.gate(1)
        target.unlink()
        self.gate(1)
        if os.name != 'nt':
            target.symlink_to(self.root / 'domain/context-map.md')
            self.gate(1)

    def test_approval_cannot_be_faked(self):
        self.record.update(proposal='NEW_CONCEPT_CANDIDATE', decision='proceed')
        self.save()
        self.gate(1)
        self.sign()
        self.gate()
        sidecar = self.feature / 'concept-test.approval.json'
        original = sidecar.read_bytes()
        document = json.loads(original)
        document['hmac'] = '0' * 64
        sidecar.write_text(json.dumps(document))
        self.gate(1)
        sidecar.write_bytes(original)
        self.gate(1, dict(self.env, SDD_CONTEXT_KEY=''))
        self.write('sdd/approver-registry.yaml', 'schema: sdd-approver-registry/v1\napprovers: []\n')
        self.gate(1)

    def test_reachable_gate_and_manifests(self):
        bootstrap = (ROOT / 'plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md').read_text()
        self.assertLess(bootstrap.index('`concept-test`'), bootstrap.index("Run `domain-sync`"))
        self.assertIn('BLOCK, DEFER, and REJECT', bootstrap)
        skill = (ROOT / 'plugins/sdd-domain/skills/concept-test/SKILL.md').read_text()
        self.assertIn('Every\n   nonzero exit stops domain-sync and subsequent generation', skill)
        for directory in ['.claude-plugin', '.codex-plugin', '.plugin']:
            manifest = json.loads((ROOT / 'plugins/sdd-domain' / directory / 'plugin.json').read_bytes())
            paths = manifest['skills']
            paths = paths if isinstance(paths, list) else [paths]
            self.assertTrue(any((ROOT / 'plugins/sdd-domain' / path / 'concept-test/SKILL.md').is_file() for path in paths))

    def test_unapproved_or_dangling_domain_blocks(self):
        path = self.root / 'domain/domain-contract.json'
        original = json.loads(path.read_bytes())
        for document in [dict(original, meta=dict(original['meta'], status='Pending')),
                         dict(original, concepts=[dict(original['concepts'][0], context='missing')])]:
            self.write('domain/domain-contract.json', document)
            self.record['inputs'][0]['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
            self.save()
            self.gate(1)

    def test_review_inputs_pin_all_evidence(self):
        result = concept.conditional.resolve(self.root, 'example', 'spec')
        for stage in ['task', 'quality']:
            self.assertEqual(result['inputs'], concept.conditional.resolve(self.root, 'example', stage)['inputs'])
        expected = {entry['path'] for entry in self.record['inputs']} | {
            'specs/example/concept-test.json', 'specs/example/concept-test.md'}
        self.assertEqual(expected, {item['path'] for item in result['inputs']})
        self.record.update(proposal='RESPONSIBILITY_CONFLICT', decision='proceed')
        self.save()
        self.sign()
        with mock.patch.dict(os.environ, self.env, clear=True):
            result = concept.conditional.resolve(self.root, 'example', 'spec')
        self.assertIn('specs/example/concept-test.approval.json', {item['path'] for item in result['inputs']})
        (self.feature / 'concept-test.md').unlink()
        with self.assertRaises(ValueError):
            concept.conditional.resolve(self.root, 'example', 'spec')

    def test_review_cannot_bypass_gate_or_use_live_approval_for_fixed_revision(self):
        self.write('specs/example/requirements.md', 'Bounded-Context: catalog\n')

        def resolve(stage, revision=None):
            with mock.patch.dict(os.environ, self.env, clear=True):
                return concept.conditional.resolve(self.root, 'example', stage, revision)

        def reject_all(revision=None):
            for stage in ['spec', 'impl', 'task', 'quality']:
                with self.subTest(stage=stage, revision=revision):
                    with self.assertRaises(ValueError):
                        resolve(stage, revision)

        self.record.update(proposal='RESPONSIBILITY_CONFLICT', decision='proceed')
        self.save()
        self.write('specs/example/concept-test.approval.json', {})
        reject_all()
        self.sign()
        for stage in ['spec', 'impl', 'task', 'quality']:
            self.assertIn('sdd/approver-registry.yaml', resolve(stage)['observed'])
        for decision in ['rejected', 'defer-to-domain-update']:
            self.record['decision'] = decision
            self.save()
            self.sign()
            reject_all()
        self.record['decision'] = 'proceed'
        self.save()
        self.sign()
        def git(*args):
            return subprocess.check_output(['git', '-C', str(self.root), *args], text=True).strip()
        git('init', '-q')
        git('config', 'core.autocrlf', 'true')
        git('add', '.')
        git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'Valid approval')
        revision = git('rev-parse', 'HEAD')
        for item in self.record['inputs']:
            committed = subprocess.check_output(['git', '-C', str(self.root), 'show', revision + ':' + item['path']])
            self.assertEqual(item['sha256'], hashlib.sha256(committed).hexdigest(), item['path'])
        self.write('specs/example/concept-test.approval.json', {})
        self.write('sdd/approver-registry.yaml', 'invalid live registry')
        reject_all()
        for stage in ['spec', 'impl', 'task', 'quality']:
            self.assertTrue(resolve(stage, revision)['inputs'])
        git('add', '.')
        git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'Invalid approval')
        invalid_revision = git('rev-parse', 'HEAD')
        git('checkout', revision, '--', 'sdd/approver-registry.yaml', 'specs/example/concept-test.approval.json')
        reject_all(invalid_revision)

    def test_review_rejects_invalid_domain_and_unapproved_v2_without_concept_record(self):
        self.write('specs/example/requirements.md', 'Bounded-Context: catalog\n')
        path = self.root / 'domain/domain-contract.json'
        document = json.loads(path.read_bytes())
        document['concepts'][0]['context'] = 'missing'
        self.write('domain/domain-contract.json', document)
        self.record['inputs'][0]['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
        self.save()
        for stage in ['spec', 'impl', 'task', 'quality']:
            with self.assertRaises(ValueError):
                concept.conditional.resolve(self.root, 'example', stage)
        self.write('domain/context-map.md', 'Domain-Model-Status: Pending\n')
        (self.feature / 'concept-test.json').unlink()
        (self.feature / 'concept-test.md').unlink()
        for stage in ['spec', 'impl', 'task', 'quality']:
            with self.assertRaises(ValueError):
                concept.conditional.resolve(self.root, 'example', stage)


class InitialReviewIdentityTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name).resolve()
        self.root = self.base / 'project'
        self.root.mkdir()
        self.events = self.base / 'native/session-state/fixture-session/events.jsonl'
        self.events.parent.mkdir(parents=True)
        self.native_env = mock.patch.dict(os.environ, COPILOT_HOME=str(self.base / 'native'))
        self.native_env.start()
        self.addCleanup(self.native_env.stop)
        self.event = dict(type='session.start', id='fixture-native-event', parentId=None,
                          data=dict(version=1, producer='copilot-agent', sessionId='fixture-session',
                                    context=dict(cwd=str(self.root))))
        self.save()
        self.ledger = self.root / 'reports/review-context/identity-ledger.json'
        self.lock = self.ledger.with_suffix('.json.lock')

    def save(self):
        self.events.write_text(json.dumps(self.event) + '\n', encoding='utf-8')

    def test_native_record_initializes_one_host_with_valid_hash_and_no_reservation(self):
        document = identity.initialize(self.root, self.events)
        record = document['records'][0]
        self.assertEqual(record['stage'], 'host')
        self.assertEqual(record['role'], 'orchestrator')
        self.assertEqual(record['sequence'], 1)
        self.assertEqual(record['run_id'], self.event['id'])
        self.assertEqual(record['host_session_id'], self.event['data']['sessionId'])
        expected = hashlib.sha256(b'1|host|orchestrator|fixture-native-event|fixture-session|').hexdigest()
        self.assertEqual(record['record_sha256'], expected)
        self.assertEqual(json.loads(self.ledger.read_bytes()), document)
        self.assertFalse(self.lock.exists())
        self.assertEqual(list(self.ledger.parent.iterdir()), [self.ledger])

    def test_existing_valid_or_malformed_ledger_is_never_changed(self):
        identity.initialize(self.root, self.events)
        for before in (self.ledger.read_bytes(), b'not a ledger'):
            with self.subTest(before=before):
                self.ledger.write_bytes(before)
                with self.assertRaises(ValueError):
                    identity.initialize(self.root, self.events)
                self.assertEqual(self.ledger.read_bytes(), before)
                self.assertFalse(self.lock.exists())

    def test_native_source_must_bind_producer_session_and_project(self):
        mutations = [lambda e: e.update(type='session.resume'),
                     lambda e: e.pop('parentId'),
                     lambda e: e['data'].update(producer='caller'),
                     lambda e: e['data'].update(version=True),
                     lambda e: e['data'].update(sessionId='different-session'),
                     lambda e: e.update(id='not an identity'),
                     lambda e: e['data']['context'].update(cwd=str(self.base))]
        original = copy.deepcopy(self.event)
        for mutate in mutations:
            self.event = copy.deepcopy(original)
            mutate(self.event)
            self.save()
            with self.assertRaises((ValueError, OSError)):
                identity.initialize(self.root, self.events)
            self.assertFalse(self.ledger.exists())
        self.events.write_text('{"type":"session.start","type":"session.start"}\n')
        with self.assertRaises(ValueError):
            identity.initialize(self.root, self.events)
        self.events.write_text('x' * 65537)
        with self.assertRaises(ValueError):
            identity.initialize(self.root, self.events)
        self.assertFalse(self.ledger.exists())

    def test_copied_transcript_and_prior_history_are_not_bootstrap_sources(self):
        forged = self.base / 'elsewhere/session-state/fixture-session/events.jsonl'
        forged.parent.mkdir(parents=True)
        shutil.copyfile(self.events, forged)
        with self.assertRaises(ValueError):
            identity.initialize(self.root, forged)
        copied = self.base / 'session-start.json'
        shutil.copyfile(self.events, copied)
        with self.assertRaises(ValueError):
            identity.initialize(self.root, copied)
        for name in ('domain-review', 'implementation', 'review-context'):
            with self.subTest(name=name):
                history = self.root / 'reports' / name / 'prior.json'
                history.parent.mkdir(parents=True, exist_ok=True)
                history.write_text('{}')
                with self.assertRaises(ValueError):
                    identity.initialize(self.root, self.events)
                self.assertFalse(self.ledger.exists())
                self.assertEqual(history.read_text(), '{}')
                self.assertFalse(self.lock.exists())
                history.unlink()

    def test_existing_lock_and_failed_publish_leave_no_partial_ledger(self):
        self.lock.parent.mkdir(parents=True)
        self.lock.mkdir()
        with self.assertRaises(FileExistsError):
            identity.initialize(self.root, self.events)
        self.assertTrue(self.lock.is_dir())
        self.assertFalse(self.ledger.exists())
        self.lock.rmdir()
        self.lock.write_text('another reservation owns this lock')
        with self.assertRaises(FileExistsError):
            identity.initialize(self.root, self.events)
        self.assertEqual(self.lock.read_text(), 'another reservation owns this lock')
        self.lock.unlink()
        with mock.patch.object(identity.os, 'link', side_effect=OSError('simulated publication failure')):
            with self.assertRaises(OSError):
                identity.initialize(self.root, self.events)
        self.assertEqual(list(self.ledger.parent.iterdir()), [])
        with mock.patch.object(identity.os, 'fsync', side_effect=OSError('simulated staging failure')):
            with self.assertRaises(OSError):
                identity.initialize(self.root, self.events)
        self.assertEqual(list(self.ledger.parent.iterdir()), [])

    def test_symlink_native_source_or_destination_is_rejected(self):
        target = self.base / 'outside.jsonl'
        self.events.rename(target)
        try:
            self.events.symlink_to(target)
        except OSError:
            self.skipTest('host does not permit creating test symlinks')
        with self.assertRaises(ValueError):
            identity.initialize(self.root, self.events)
        self.events.unlink()
        target.rename(self.events)
        (self.root / 'reports').symlink_to(self.base, target_is_directory=True)
        with self.assertRaises(ValueError):
            identity.initialize(self.root, self.events)
        self.assertFalse((self.base / 'review-context').exists())

    def test_hardlinked_native_source_and_reparse_metadata_are_rejected(self):
        alias = self.base / 'alias.jsonl'
        os.link(self.events, alias)
        with self.assertRaises(ValueError):
            identity.initialize(self.root, self.events)
        self.assertFalse(self.ledger.exists())
        alias.unlink()
        # Exercise the Windows junction/reparse flag without requiring admin privileges.
        with mock.patch.object(Path, 'lstat', return_value=mock.Mock(st_mode=0o040755, st_file_attributes=0x400)):
            self.assertTrue(identity.redirected(self.events.parent))

    def test_packaged_helper_runs_without_repository_imports(self):
        # Installation copies this self-contained script with the quality plugin.
        installed = self.base / 'installed/plugins/sdd-quality-loop/scripts/initialize-review-identity.py'
        installed.parent.mkdir(parents=True)
        shutil.copyfile(IDENTITY, installed)
        result = subprocess.run([sys.executable, str(installed), '--root', str(self.root),
                                 '--copilot-events', str(self.events)], capture_output=True, text=True,
                                cwd=self.base)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout.strip(), 'REVIEW_HOST_REGISTERED')
        self.assertNotIn('REVIEW_CONTEXT_OK', result.stdout)
        self.assertTrue(self.ledger.is_file())

    def test_fresh_mode_rejects_orphan_receipt_and_append_options(self):
        receipt = self.root / 'reports/review-context/host-registrations' / ('0' * 64 + '.json')
        receipt.parent.mkdir(parents=True)
        receipt.write_text('{}')
        with self.assertRaises(ValueError):
            identity.initialize(self.root, self.events)
        self.assertFalse(self.ledger.exists())
        self.assertFalse(self.lock.exists())
        for extra in (['--check-only'], ['--register-existing'], ['--claude-result', str(self.events)]):
            with self.subTest(extra=extra):
                result = subprocess.run([sys.executable, str(IDENTITY), '--root', str(self.root),
                                         '--copilot-events', str(self.events), *extra], capture_output=True, text=True)
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                self.assertFalse(self.ledger.exists())


class ClaudeHostAppendTests(unittest.TestCase):
    """Synthetic existing-ledger Claude host append; a fixture PASS is never a real registration."""

    def setUp(self):
        # Native project encoding is only observed for [A-Za-z0-9/-]; tempfile names may contain '_'.
        parent = Path(tempfile.gettempdir()).resolve()
        self.base = parent / ('hostappend-' + uuid.uuid4().hex)
        self.base.mkdir(mode=0o700)
        self.addCleanup(shutil.rmtree, self.base, ignore_errors=True)
        self.root = self.base / 'project'
        if os.name == 'nt' or not identity.re.fullmatch(r'(?:/[A-Za-z0-9-]+)+', str(self.root)):
            self.skipTest('Claude native project encoding is only observed on POSIX [A-Za-z0-9/-] roots')
        self.home = self.base / 'home'
        self.home.mkdir()
        environment = mock.patch.dict(os.environ, HOME=str(self.home), USERPROFILE=str(self.home))
        environment.start()
        self.addCleanup(environment.stop)
        os.environ.pop('CLAUDE_CONFIG_DIR', None)
        self.put('specs/example/requirements.md', 'Bounded-Context: sales\n')
        requirement = sha((self.root / 'specs/example/requirements.md').read_bytes())
        self.spec_inputs = [dict(path='specs/example/requirements.md', sha256=requirement)]
        self.records = chain([
            ('host', 'orchestrator', 'copilot-event', 'copilot-session', None, None),
            ('spec', 'spec-reviewer-a', 'spec-run', 'spec-session', None,
             sha('specs/example/requirements.md\t' + requirement)),
            ('impl', 'impl-reviewer-a', 'impl-run', 'impl-session', None, sha('impl')),
            ('task', 'task-reviewer-a', 'task-run', 'task-session', None, None),
            ('quality', 'sdd-evaluator', 'quality-run', 'quality-session', sha('scratch'), sha('quality')),
            ('domain', 'domain-reviewer-a', 'domain-run', 'domain-session', None, sha('domain'))])
        self.save_ledger(self.records)
        self.session, self.result, self.transcript = self.native()

    def put(self, path, text, root=None):
        target = (root or self.root) / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(text if isinstance(text, bytes) else text.encode('utf-8'))
        return target

    def save_ledger(self, records, root=None):
        self.put(LEDGER, json.dumps(dict(schema='review-identity-ledger/v1', records=records), indent=2) + '\n', root)

    def ledger_bytes(self, root=None):
        return ((root or self.root) / LEDGER).read_bytes()

    def lines(self, session, root=None, version='2.1.303'):
        common = dict(sessionId=session, cwd=str(root or self.root), version=version, isSidechain=False,
                      entrypoint='sdk-cli', userType='external')
        return [dict(type='queue-operation', operation='enqueue', sessionId=session),
                dict(type='user', uuid='u1', parentUuid=None, message=dict(role='user', content='prepare'), **common),
                dict(type='attachment', uuid='a0', parentUuid='u1', attachment={}, **common),
                dict(type='assistant', uuid='a1', parentUuid='u1',
                     message=dict(role='assistant', content=[dict(type='text', text='ready')]), **common),
                dict(type='last-prompt', lastPrompt='prepare', sessionId=session)]

    def native(self, root=None, session=None, lines=None, stream=False):
        root = root or self.root
        session = session or str(uuid.uuid4())
        transcript = self.home / '.claude/projects' / str(root).replace('/', '-') / (session + '.jsonl')
        self.write_lines(transcript, lines or self.lines(session, root))
        final = dict(type='result', subtype='success', is_error=False, result='ready', session_id=session,
                     num_turns=1, stop_reason='end_turn', uuid=str(uuid.uuid4()))
        documents = [final]
        if stream:
            documents = [dict(type='system', subtype='init', cwd=str(root), session_id=session,
                              claude_code_version='2.1.303', tools=[]),
                         dict(type='assistant', message=dict(role='assistant', content=[]), session_id=session),
                         final]
        result = self.base / 'capture' / (session + '.json')
        self.write_lines(result, documents)
        return session, result, transcript

    def write_lines(self, path, documents):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(''.join(json.dumps(item) + '\n' for item in documents).encode())

    def register(self, result=None, transcript=None, check_only=False, root=None):
        return identity.register_existing(root or self.root, result or self.result,
                                          transcript or self.transcript, check_only)

    def state(self, root=None):
        folder = (root or self.root) / 'reports/review-context'
        return {path.relative_to(folder).as_posix(): (path.read_bytes() if path.is_file() else None)
                for path in sorted(folder.rglob('*'))} if folder.exists() else None

    def assert_blocked(self, error=identity.Blocked, message=None, **kwargs):
        before = self.state(kwargs.get('root'))
        for check_only in (True, False):
            with self.subTest(check_only=check_only):
                with self.assertRaises(error) as caught:
                    self.register(check_only=check_only, **kwargs)
                if message:
                    self.assertRegex(str(caught.exception), message)
                self.assertEqual(self.state(kwargs.get('root')), before)

    def receipt_path(self, record_hash, root=None):
        return (root or self.root) / 'reports/review-context/host-registrations' / (record_hash + '.json')

    def validator_commands(self, manifest, reserve=False):
        pwsh = shutil.which('pwsh')
        self.assertIsNotNone(pwsh, 'PowerShell required to verify runtime parity')
        return [('bash', ['bash', str(VALIDATOR) + '.sh', str(manifest), str(self.root)] + (['--reserve'] if reserve else [])),
                ('pwsh', [pwsh, '-NoProfile', '-File', str(VALIDATOR) + '.ps1', '-Manifest', str(manifest),
                          '-RepositoryRoot', str(self.root)] + (['-Reserve'] if reserve else []))]

    def spec_manifest(self, run, session, sequence, previous):
        manifest = dict(schema='review-context-invocation/v2', input_mode='file-manifest', fallback_mode='none',
                        read_only=True, stage='spec', role='spec-reviewer-a', feature='example', run_id=run,
                        host_session_id=session, sequence=sequence, identity_ledger_path=LEDGER,
                        identity_ledger_sha256=sha(self.ledger_bytes()), previous_record_sha256=previous,
                        allowed_input_manifest=self.spec_inputs)
        return self.put('invocations/' + run + '.json', json.dumps(manifest))

    def run_validator(self, command):
        return subprocess.run(command, capture_output=True, text=True, timeout=60)

    def test_append_preserves_prefix_and_validators_accept(self):
        before = self.ledger_bytes()
        self.assertEqual('REVIEW_HOST_CHECK_REGISTRABLE', self.register(check_only=True)['outcome'])
        self.assertEqual(self.ledger_bytes(), before)
        status = self.register()
        self.assertEqual('REVIEW_HOST_REGISTERED', status['outcome'])
        document = json.loads(self.ledger_bytes())
        self.assertEqual(document['records'][:-1], self.records)
        host = document['records'][-1]
        self.assertEqual(host, chain([('host', 'orchestrator', self.session, self.session, None, None)],
                                     self.records)[-1])
        self.assertEqual(set(host), {'sequence', 'stage', 'role', 'run_id', 'host_session_id',
                                     'previous_record_sha256', 'record_sha256'})
        receipt = json.loads(self.receipt_path(host['record_sha256']).read_bytes())
        self.assertEqual(receipt['ledger_before_sha256'], sha(before))
        self.assertEqual(receipt['ledger_after_sha256'], sha(self.ledger_bytes()))
        self.assertEqual(receipt['before_record_count'], len(self.records))
        self.assertEqual(receipt['transcript'], dict(
            path='projects/' + str(self.root).replace('/', '-') + '/' + self.session + '.jsonl',
            bytes=len(self.transcript.read_bytes()), sha256=sha(self.transcript.read_bytes())))
        self.assertEqual(receipt['result']['sha256'], sha(self.result.read_bytes()))
        self.assertEqual((receipt['run_id'], receipt['host_session_id'], receipt['cli_version'], receipt['canonical_root']),
                         (self.session, self.session, '2.1.303', str(self.root)))
        self.assertFalse((self.root / LEDGER).with_suffix('.json.lock').exists())
        published = self.ledger_bytes()
        prior = self.spec_manifest('spec-run', 'spec-session', 2, self.records[0]['record_sha256'])
        reuse = self.spec_manifest(self.session, self.session, len(self.records) + 2, host['record_sha256'])
        reviewer = self.spec_manifest('reviewer-run', 'reviewer-session', len(self.records) + 2, host['record_sha256'])
        for (runtime, check), (_, reserve), (_, reused) in zip(self.validator_commands(prior),
                                                                self.validator_commands(reviewer, True),
                                                                self.validator_commands(reuse, True)):
            with self.subTest(runtime=runtime):
                self.put(LEDGER, published)
                result = self.run_validator(check)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                result = self.run_validator(reused)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(self.ledger_bytes(), published)
                result = self.run_validator(reserve)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                records = json.loads(self.ledger_bytes())['records']
                self.assertEqual(records[:-1], document['records'])
                self.assertEqual(records[-1]['previous_record_sha256'], host['record_sha256'])
                result = self.run_validator(check)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                # A later ordinary append leaves the host registration verifiable.
                self.assertEqual('REVIEW_HOST_ALREADY_REGISTERED', self.register()['outcome'])

    def test_stream_json_capture_is_accepted(self):
        session, result, transcript = self.native(stream=True)
        status = self.register(result, transcript)
        self.assertEqual((status['outcome'], status['record']['run_id']), ('REVIEW_HOST_REGISTERED', session))

    def test_validators_reject_tampered_appended_row(self):
        self.register()
        published = json.loads(self.ledger_bytes())
        host = published['records'][-1]
        manifest = self.spec_manifest('reviewer-run', 'reviewer-session', host['sequence'] + 1, host['record_sha256'])
        bound = chain([('host', 'orchestrator', self.session, self.session, None, sha('bound'))], self.records)[-1]
        tampers = [dict(host, sequence=host['sequence'] + 1), dict(host, previous_record_sha256='0' * 64),
                   dict(host, record_sha256='0' * 64), dict(host, run_id='other-run'),
                   dict(host, host_session_id='copilot-session'), bound]
        for tampered in tampers:
            records = published['records'][:-1] + [tampered]
            self.save_ledger(records)
            manifest = self.spec_manifest('reviewer-run', 'reviewer-session', tampered['sequence'] + 1,
                                          tampered['record_sha256'])
            for runtime, command in self.validator_commands(manifest, True):
                with self.subTest(runtime=runtime, tampered=tampered):
                    before = self.ledger_bytes()
                    result = self.run_validator(command)
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(self.ledger_bytes(), before)
            with self.assertRaises(identity.Blocked):
                self.register()

    def test_identity_collisions_block(self):
        rows = [('spec', 'spec-reviewer-b', self.session, 'other-session', None, None),
                ('spec', 'spec-reviewer-b', 'other-run', self.session, None, None),
                ('spec', 'spec-reviewer-b', self.session, self.session, None, None),
                ('host', 'orchestrator', self.session, 'other-session', None, None)]
        for row in rows:
            with self.subTest(row=row):
                self.save_ledger(chain([row], self.records))
                self.assert_blocked(message='collides')
                self.assertFalse(self.receipt_path('x').parent.exists())

    def test_result_shapes_block(self):
        final = json.loads(self.result.read_bytes())
        init = dict(type='system', subtype='init', cwd=str(self.root), session_id=self.session,
                    claude_code_version='2.1.303')
        cases = [b'', b'\n', b'[]\n', json.dumps(dict(final, is_error=True)).encode(),
                 json.dumps(dict(final, subtype='error_during_execution')).encode(),
                 json.dumps({k: v for k, v in final.items() if k != 'result'}).encode(),
                 json.dumps(dict(final, session_id='not-a-native-session')).encode(),
                 json.dumps(dict(final, session_id=str(uuid.uuid4()))).encode(),
                 json.dumps(init).encode() + b'\n',
                 (json.dumps(init) + '\n' + json.dumps(final) + '\n' + json.dumps(final) + '\n').encode(),
                 (json.dumps(dict(init, cwd=str(self.base))) + '\n' + json.dumps(final) + '\n').encode(),
                 (json.dumps(dict(init, claude_code_version='9.9.9')) + '\n' + json.dumps(final) + '\n').encode(),
                 (json.dumps(init) + '\n' + json.dumps(dict(type='assistant', session_id='x')) + '\n' +
                  json.dumps(final) + '\n').encode(),
                 b'{"type":"result","type":"result"}\n', b'{"type": NaN}\n']
        for raw in cases:
            with self.subTest(raw=raw[:60]):
                self.result.write_bytes(raw)
                self.assert_blocked(error=(ValueError, OSError))

    def test_native_binding_mismatches_block(self):
        lines = self.lines(self.session)
        mutations = [lambda l: l[1].update(sessionId=str(uuid.uuid4())),
                     lambda l: l[0].update(sessionId=str(uuid.uuid4())),
                     lambda l: l[3].update(version='9.9.9'),
                     lambda l: [l[1].update(version='2.1.303'), l[3].update(version='2.1.304')],
                     lambda l: l[3].update(isSidechain=True),
                     lambda l: l[3].update(cwd=str(self.base)),
                     lambda l: l[3].update(cwd='project'),
                     lambda l: l.pop(3),
                     lambda l: l.pop(1),
                     lambda l: l[3]['message'].update(role='user'),
                     lambda l: l[2].pop('type')]
        for mutate in mutations:
            changed = copy.deepcopy(lines)
            mutate(changed)
            self.write_lines(self.transcript, changed)
            with self.subTest(mutation=mutations.index(mutate)):
                self.assert_blocked(error=(ValueError, OSError))
        self.write_lines(self.transcript, lines)
        for raw in (self.transcript.read_bytes().rstrip(b'\n'), self.transcript.read_bytes() + b'\n',
                    b'{"type":"user","type":"user"}\n' + self.transcript.read_bytes()):
            self.transcript.write_bytes(raw)
            self.assert_blocked(error=(ValueError, OSError))

    def test_lossy_encoding_other_cwd_blocks(self):
        # '/project-a' and '/project/a' share one encoded directory; recorded cwd decides.
        lossy, other = self.base / 'project-a', self.root / 'a'
        lossy.mkdir()
        other.mkdir()
        self.save_ledger(self.records, lossy)
        self.assertEqual(str(lossy).replace('/', '-'), str(other).replace('/', '-'))
        session, result, transcript = self.native(root=other)
        self.assert_blocked(error=(ValueError, OSError), root=lossy, result=result, transcript=transcript)
        session, result, transcript = self.native(root=lossy)
        self.assertEqual('REVIEW_HOST_REGISTERED', self.register(result, transcript, root=lossy)['outcome'])

    def test_native_location_and_file_safety(self):
        copied = self.base / 'elsewhere' / self.transcript.name
        copied.parent.mkdir()
        shutil.copyfile(self.transcript, copied)
        self.assert_blocked(transcript=copied, message='original Claude native transcript')
        renamed = self.transcript.with_name(str(uuid.uuid4()) + '.jsonl')
        shutil.copyfile(self.transcript, renamed)
        self.assert_blocked(transcript=renamed, message='original Claude native transcript')
        dotted = self.transcript.parent / '..' / self.transcript.parent.name / self.transcript.name
        self.assert_blocked(transcript=dotted)
        with mock.patch.dict(os.environ, CLAUDE_CONFIG_DIR=str(self.home / '.claude')):
            self.assert_blocked(message='custom Claude configuration')
        underscored = self.base / 'under_score'
        underscored.mkdir()
        self.save_ledger(self.records, underscored)
        self.assert_blocked(root=underscored, message='encoding')
        alias = self.base / 'alias.jsonl'
        os.link(self.transcript, alias)
        self.assert_blocked(error=ValueError)
        alias.unlink()
        os.link(self.result, alias)
        self.assert_blocked(error=ValueError)
        alias.unlink()
        target = self.base / 'target.jsonl'
        self.transcript.rename(target)
        self.transcript.symlink_to(target)
        self.assert_blocked(error=ValueError)
        self.transcript.unlink()
        target.rename(self.transcript)
        with mock.patch.object(identity, 'NATIVE_LIMIT', 64):
            self.assert_blocked(message='size limit')
        os.mkfifo(self.base / 'fifo') if hasattr(os, 'mkfifo') else None
        if hasattr(os, 'mkfifo'):
            self.assert_blocked(error=ValueError, result=self.base / 'fifo')
        self.assertEqual('REVIEW_HOST_REGISTERED', self.register()['outcome'])

    def test_native_input_change_during_lock_blocks(self):
        original = identity.existing_directory
        for target, message in ((self.transcript, 'changed during registration'),
                                (self.result, 'changed during registration')):
            raw = target.read_bytes()

            def mutate(*args, target=target):
                with target.open('ab') as stream:
                    stream.write(b'\n')
                return original(*args)
            with self.subTest(target=target.name), mock.patch.object(identity, 'existing_directory', mutate):
                self.assert_blocked(message=message)
            target.write_bytes(raw)
        replaced = self.transcript.with_suffix('.new')

        def swap(*args):
            shutil.copyfile(self.transcript, replaced)
            os.replace(replaced, self.transcript)
            return original(*args)
        with mock.patch.object(identity, 'existing_directory', swap):
            self.assert_blocked(message='replaced')

    def test_idempotent_retry_and_prefix(self):
        host = self.register()['record']
        published = self.ledger_bytes()
        receipt = self.receipt_path(host['record_sha256']).read_bytes()
        for check_only in (True, False):
            self.assertEqual('REVIEW_HOST_ALREADY_REGISTERED', self.register(check_only=check_only)['outcome'])
        resumed = self.transcript.read_bytes() + (json.dumps(self.lines(self.session)[3]) + '\n').encode()
        self.transcript.write_bytes(resumed)
        self.assertEqual('REVIEW_HOST_ALREADY_REGISTERED', self.register()['outcome'])
        self.assertEqual((self.ledger_bytes(), self.receipt_path(host['record_sha256']).read_bytes()),
                         (published, receipt))
        self.transcript.write_bytes(resumed.replace(b'prepare', b'prepark', 1))
        self.assert_blocked(message='does not match')
        self.transcript.write_bytes(resumed[:100])
        self.assert_blocked()
        self.transcript.write_bytes(resumed)
        original_result = self.result.read_bytes()
        self.result.write_bytes(original_result.replace(b'"ready"', b'"other"'))
        self.assert_blocked(message='does not match')
        self.result.write_bytes(original_result)
        self.assertEqual('REVIEW_HOST_ALREADY_REGISTERED', self.register()['outcome'])

    def test_receipt_field_tamper_blocks_retry(self):
        host = self.register()['record']
        path = self.receipt_path(host['record_sha256'])
        original = path.read_bytes()
        document = json.loads(original)
        for key, value in document.items():
            changed = dict(document)
            changed[key] = (value + 1 if type(value) is int else
                            dict(value, sha256='0' * 64) if isinstance(value, dict) else
                            '0' * 64 if key.endswith('sha256') and key != 'record_sha256' else value + 'x')
            with self.subTest(key=key):
                path.write_text(json.dumps(changed, indent=2, sort_keys=True) + '\n')
                self.assert_blocked()
        path.write_text(json.dumps(dict(document, extra=True)))
        self.assert_blocked(message='malformed')
        path.write_bytes(original + b' ')
        self.assert_blocked(message='malformed')
        # Documented limit: the self-digest is not a signature, so a coherent same-UID rewrite
        # of the unverifiable before-hash (digest recomputed) is not detected after publication.
        resealed = identity.sealed(dict(document, ledger_before_sha256='1' * 64))
        path.write_bytes(resealed)
        self.assertEqual('REVIEW_HOST_ALREADY_REGISTERED', self.register()['outcome'])
        path.write_bytes(identity.sealed(dict(document, ledger_after_sha256='1' * 64)))
        self.assert_blocked(message='does not describe')
        path.write_bytes(identity.sealed(dict(document, canonical_root=str(self.base))))
        self.assert_blocked(message='malformed')
        path.write_bytes(original)
        other = self.native()
        receipt_hash = sha(original)
        path.write_bytes(original.replace(b'"before_record_count": 6', b'"before_record_count": 5'))
        self.assert_blocked(message='malformed', result=other[1], transcript=other[2])
        path.write_bytes(original)
        os.link(path, self.base / 'receipt-alias.json')
        self.assert_blocked(error=ValueError, result=other[1], transcript=other[2])
        (self.base / 'receipt-alias.json').unlink()
        self.assertEqual(sha(path.read_bytes()), receipt_hash)
        path.unlink()
        self.assert_blocked(message='no registration receipt')
        path.write_bytes(original)
        (path.parent / 'notes.txt').write_text('unknown')
        self.assert_blocked(message='unknown entry')
        (path.parent / 'notes.txt').unlink()
        self.assertEqual('REVIEW_HOST_ALREADY_REGISTERED', self.register()['outcome'])

    def test_invalid_existing_ledgers_block(self):
        records = self.records
        quality = records[4]
        swapped = dict(quality, record_sha256=sha(
            f"5|quality|sdd-evaluator|quality-run|quality-session|{quality['previous_record_sha256']}"
            f"|allowed-inputs-v1|{quality['allowed_inputs_sha256']}"
            f"|scratch-declaration-v1|{quality['scratch_declaration_sha256']}"))
        bad = [records[:3] + [dict(records[3], sequence=5)] + records[4:],
               [dict(records[0], sequence=True)] + records[1:],
               [dict(records[0], sequence=1.0)] + records[1:],
               records[:2] + [dict(records[2], previous_record_sha256='')] + records[3:],
               records[:-1] + [dict(records[-1], record_sha256='0' * 64)],
               records[:-1] + [dict(records[-1], extra='field')],
               records[:4] + [swapped] + records[5:],
               chain([('host', 'orchestrator', 'h2', 'h2', None, sha('inputs'))], records),
               chain([('host', 'orchestrator', 'h2', 'h2', sha('scratch'), None)], records),
               chain([('spec', 'spec-reviewer-b', 'h2', 'h2', sha('scratch'), None)], records),
               chain([('spec', 'spec-reviewer-b', 'spec-run', 'fresh-session', None, None)], records),
               chain([('spec', 'spec-reviewer-b', 'fresh-run', 'spec-session', None, None)], records),
               chain([('spec', 'bad role', 'h2', 'h2', None, None)], records), []]
        for case in bad:
            with self.subTest(case=bad.index(case)):
                self.save_ledger(case)
                self.assert_blocked(message='ledger')
        for raw in (b'not json', b'{"schema":"review-identity-ledger/v1","records":[],"extra":1}',
                    b'{"schema":"review-identity-ledger/v1","schema":"review-identity-ledger/v1","records":[]}',
                    b'\xef\xbb\xbf' + json.dumps(dict(schema='review-identity-ledger/v1', records=records)).encode()):
            self.put(LEDGER, raw)
            self.assert_blocked(error=(ValueError, OSError))
        (self.root / LEDGER).unlink()
        self.assert_blocked(message='missing')
        shutil.rmtree(self.root / 'reports')
        self.assert_blocked(message='missing')
        self.assertFalse((self.root / 'reports').exists())

    def test_check_only_lock_and_cli_contract(self):
        lock = (self.root / LEDGER).with_suffix('.json.lock')
        lock.mkdir()
        self.assert_blocked(error=identity.Busy)
        self.assertTrue(lock.is_dir())
        lock.rmdir()
        lock.write_text('another reservation owns this lock')
        self.assert_blocked(error=identity.Busy)
        self.assertEqual(lock.read_text(), 'another reservation owns this lock')
        lock.unlink()
        installed = self.base / 'installed/initialize-review-identity.py'
        installed.parent.mkdir()
        shutil.copyfile(IDENTITY, installed)
        base = [sys.executable, str(installed), '--root', str(self.root)]
        native = ['--claude-result', str(self.result), '--claude-transcript', str(self.transcript)]
        for arguments in (native, ['--register-existing', '--claude-result', str(self.result)],
                          ['--register-existing', *native, '--copilot-events', str(self.result)],
                          ['--register-existing', *native, '--run-id', 'chosen'], ['--check-only']):
            with self.subTest(arguments=arguments):
                result = subprocess.run(base + arguments, capture_output=True, text=True, cwd=self.base)
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        before = self.state()
        result = subprocess.run(base + ['--register-existing', *native, '--check-only'],
                                capture_output=True, text=True, cwd=self.base)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertRegex(result.stdout, '^REVIEW_HOST_CHECK_REGISTRABLE sequence=7 record_sha256=[0-9a-f]{64} '
                         f'run_id={self.session} host_session_id={self.session}\n$')
        self.assertEqual(self.state(), before)
        secret = 'body-' + 'marker-' + uuid.uuid4().hex
        lines = self.lines(self.session)
        lines[3]['message']['content'][0]['text'] = secret
        lines[3]['cwd'] = str(self.base)
        self.write_lines(self.transcript, lines)
        result = subprocess.run(base + ['--register-existing', *native], capture_output=True, text=True, cwd=self.base)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, 'REVIEW_HOST_BLOCKED: Claude transcript belongs to another project\n')
        self.assertNotIn(secret, result.stdout + result.stderr)
        self.write_lines(self.transcript, self.lines(self.session))
        result = subprocess.run(base + ['--register-existing', *native], capture_output=True, text=True, cwd=self.base)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(result.stdout.startswith('REVIEW_HOST_REGISTERED sequence=7 '))
        result = subprocess.run(base + ['--register-existing', *native], capture_output=True, text=True, cwd=self.base)
        self.assertTrue(result.stdout.startswith('REVIEW_HOST_ALREADY_REGISTERED sequence=7 '), result.stdout)
        self.assertFalse(lock.exists())

    def test_fault_injection_keeps_prefix(self):
        before = self.state()
        real_fsync = os.fsync

        def file_fsync_fails(descriptor):
            if stat.S_ISREG(os.fstat(descriptor).st_mode):
                raise OSError(errno.EIO, 'simulated file fsync failure')
            return real_fsync(descriptor)
        for patch in (mock.patch.object(identity.os, 'link', side_effect=OSError('simulated link failure')),
                      mock.patch.object(identity.os, 'fsync', file_fsync_fails)):
            with patch, self.assertRaises(OSError):
                self.register()
            # An empty receipt directory may remain; no receipt and no ledger change.
            self.assertEqual({k: v for k, v in self.state().items() if k != 'host-registrations'}, before)
        with mock.patch.object(identity.os, 'replace', side_effect=OSError('simulated replace failure')):
            with self.assertRaises(OSError):
                self.register()
        orphan = self.state()
        self.assertEqual(self.ledger_bytes(), before[LEDGER.split('/', 2)[2]])
        self.assertEqual(len(orphan), len(before) + 2)
        status = self.register(check_only=True)
        self.assertEqual((status['outcome'], status['pending']), ('REVIEW_HOST_CHECK_REGISTRABLE', True))
        self.assertEqual(self.state(), orphan)
        status = self.register()
        self.assertEqual((status['outcome'], status['pending']), ('REVIEW_HOST_REGISTERED', True))
        self.assertEqual(json.loads(self.ledger_bytes())['records'][:-1], self.records)
        self.assertEqual({k: v for k, v in self.state().items() if k.startswith('host-registrations')},
                         {k: v for k, v in orphan.items() if k.startswith('host-registrations')})
        session, result, transcript = self.native()

        def directory_fsync(code):
            def fsync(descriptor):
                if stat.S_ISDIR(os.fstat(descriptor).st_mode):
                    raise OSError(code, 'simulated directory fsync')
                return real_fsync(descriptor)
            return fsync
        with mock.patch.object(identity.os, 'fsync', directory_fsync(errno.EINVAL)):
            self.assertEqual('REVIEW_HOST_REGISTERED', self.register(result, transcript)['outcome'])
        receipts = self.root / 'reports/review-context/host-registrations'
        for failing, expected in ((receipts, ('REVIEW_HOST_REGISTERED', True)),
                                  (receipts.parent, ('REVIEW_HOST_ALREADY_REGISTERED', None))):
            session, result, transcript = self.native()
            ledger_before = self.ledger_bytes()

            def fsync(descriptor, failing=failing):
                if os.path.samestat(os.fstat(descriptor), failing.stat()):
                    raise OSError(errno.EIO, 'simulated directory fsync failure')
                return real_fsync(descriptor)
            with self.subTest(failing=failing.name):
                with mock.patch.object(identity.os, 'fsync', fsync), self.assertRaises(OSError):
                    self.register(result, transcript)
                published = json.loads(self.ledger_bytes())['records'][-1]['run_id'] == session
                # Receipt-directory failure stops before the ledger; ledger-directory failure after it.
                self.assertEqual(published, failing == receipts.parent)
                if not published:
                    self.assertEqual(self.ledger_bytes(), ledger_before)
                status = self.register(result, transcript)
                self.assertEqual((status['outcome'], status.get('pending')), expected)
        with mock.patch.object(identity.os, 'name', 'nt'), mock.patch.object(identity.os, 'open') as opened:
            identity.fsync_directory(self.root)
        opened.assert_not_called()

    def test_unpublished_receipt_retry_and_conflict(self):
        with mock.patch.object(identity.os, 'replace', side_effect=OSError('simulated replace failure')):
            with self.assertRaises(OSError):
                self.register()
        receipts = sorted((self.root / 'reports/review-context/host-registrations').iterdir())
        self.assertEqual(len(receipts), 1)
        orphan = receipts[0].read_bytes()
        receipts[0].write_bytes(orphan.replace(json.loads(orphan)['ledger_before_sha256'].encode(), b'0' * 64))
        self.assert_blocked(message='malformed')
        # Even a coherently resealed before-hash cannot complete: it must equal the current ledger.
        receipts[0].write_bytes(identity.sealed(dict(json.loads(orphan), ledger_before_sha256='0' * 64)))
        self.assert_blocked(error=identity.Unpublished)
        receipts[0].write_bytes(orphan)
        other_session, other_result, other_transcript = self.native()
        self.assert_blocked(error=identity.Unpublished, result=other_result, transcript=other_transcript)
        self.save_ledger(chain([('spec', 'spec-reviewer-b', 'later-run', 'later-session', None, None)], self.records))
        self.assert_blocked(error=identity.Unpublished)
        self.assertEqual(receipts[0].read_bytes(), orphan)

    def test_concurrent_writer_after_receipt_is_unpublished_not_lost(self):
        real_link = os.link
        competing = chain([('spec', 'spec-reviewer-b', 'later-run', 'later-session', None, None)], self.records)

        def link_then_write(source, target):
            real_link(source, target)
            self.save_ledger(competing)
        with mock.patch.object(identity.os, 'link', link_then_write), self.assertRaises(identity.Unpublished):
            self.register()
        self.assertEqual(json.loads(self.ledger_bytes())['records'], competing)
        self.assertEqual(len(list((self.root / 'reports/review-context/host-registrations').iterdir())), 1)
        self.save_ledger(self.records)
        nested = []
        real_receipts = identity.published_receipts
        other = self.native()

        def contend(*args):
            with self.assertRaises(identity.Busy):
                identity.register_existing(self.root, other[1], other[2])
            nested.append(True)
            return real_receipts(*args)
        with mock.patch.object(identity, 'published_receipts', contend):
            self.assertEqual('REVIEW_HOST_REGISTERED', self.register()['outcome'])
        self.assertEqual(nested, [True])
        self.assertEqual(len(json.loads(self.ledger_bytes())['records']), len(self.records) + 1)

    def test_implementation_evidence_collisions_and_broken_references_block(self):
        manifest = lambda run, session: json.dumps(dict(schema='task-input-manifest/v1', task_id='T-001',
                                                        run_id=run, session_id=session))
        report = 'reports/implementation/f/T-001.md'
        spec_manifest = 'specs/f/verification/T-001/task-input-manifest.json'

        def cite(path, digest=None):
            return (f'# Implementation Report: T-001\nRun ID: impl-run\n- **Run ID**: impl-run\n'
                    f'- **Session ID**: impl-session\nInput manifest: `{path}`, SHA-256 '
                    f'`{digest or sha((self.root / path).read_bytes())}`.\n')

        def invocation(**pins):
            return json.dumps(dict(schema='review-context-invocation/v2', stage='quality', role='sdd-evaluator',
                                   run_id='eval-run', host_session_id='eval-session', **pins))
        self.put(spec_manifest, manifest('impl-run', 'impl-session'))
        self.put(report, cite(spec_manifest))
        self.put('handoffs/f-T-001/custom-inputs.json', manifest('impl-run', 'impl-session'))
        self.assertEqual('REVIEW_HOST_CHECK_REGISTRABLE', self.register(check_only=True)['outcome'])
        collisions = [
            (report, f'Run ID: {self.session}\n'), (report, f'- **Session ID**: `{self.session}`\n'),
            ('handoffs/f-T-001/custom-inputs.json', manifest(self.session, 'impl-session')),
            ('reports/implementation/f/T-001.input-manifest.json', manifest('impl-run', self.session))]
        broken = [('reports/implementation/f/T-002.json', '{"run_id":'),
                  ('reports/implementation/f/T-002.json', '{"a":1,"a":2}'),
                  ('handoffs/x/inputs.json', json.dumps(dict(schema='task-input-manifest/v1', run_id='r'))),
                  (report, cite(spec_manifest, '0' * 64)), (report, cite(spec_manifest).replace('`,', ',')),
                  (report, cite('specs/f/verification/T-001/missing.json', '0' * 64)),
                  (report, cite('../outside.json', '0' * 64)),
                  ('reports/quality-gate/f/T-001/eval.json',
                   invocation(implementation_manifest=dict(path=spec_manifest, sha256='0' * 64)))]
        for path, text in collisions + broken:
            with self.subTest(path=path, text=text[:50]):
                previous = (self.root / path).read_bytes() if (self.root / path).exists() else None
                self.put(path, text)
                self.assert_blocked(message='implementation' if (path, text) in collisions else None,
                                    error=identity.Blocked if (path, text) in collisions else (ValueError, OSError))
                if previous is None:
                    (self.root / path).unlink()
                else:
                    self.put(path, previous)
        referenced = 'specs/f/verification/T-001/referenced.json'
        self.put(referenced, manifest('impl-run', self.session))
        pin = dict(path=referenced, sha256=sha((self.root / referenced).read_bytes()))
        self.put('reports/quality-gate/f/T-001/eval.json', invocation(implementation_manifest=pin))
        self.assert_blocked(message='implementation evidence')
        declaration = self.put('specs/f/verification/T-001/delivery.json', json.dumps(dict(
            schema='supplemental-delivery-declaration/v2', implementation_manifest=pin)))
        self.put('reports/quality-gate/f/T-001/eval.json', invocation(supplemental_delivery_declaration=dict(
            path='specs/f/verification/T-001/delivery.json', sha256=sha(declaration.read_bytes()))))
        self.assert_blocked(message='implementation evidence')
        (self.root / 'reports/quality-gate/f/T-001/eval.json').unlink()
        (self.root / 'reports/implementation/f/link.md').symlink_to(self.root / report)
        self.assert_blocked(message='link')
        (self.root / 'reports/implementation/f/link.md').unlink()
        with mock.patch.object(identity, 'EVIDENCE_FILES', 1):
            self.assert_blocked(message='limit')
        self.assertEqual('REVIEW_HOST_REGISTERED', self.register()['outcome'])

    def test_domain_old_round_keeps_host_and_new_round_binds_new_host(self):
        spec = importlib.util.spec_from_file_location('domain_finalize_fixture', ROOT / 'tests/domain-review-finalize.tests.py')
        domain = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(domain)
        base = self.base

        class Directory:
            def __init__(self, prefix):
                self.name = str(base / (prefix + uuid.uuid4().hex))
                os.mkdir(self.name)

            def cleanup(self):
                shutil.rmtree(self.name, ignore_errors=True)
        outputs = ('integrated-verdict.json', 'report.md', 'domain-review-contract.json')
        for runtime in ('bash', 'powershell'):
            with self.subTest(runtime=runtime):
                with mock.patch.object(domain.tempfile, 'TemporaryDirectory', Directory):
                    old = domain.Fixture(self, runtime=runtime)
                    new = domain.Fixture(self, runtime=runtime, reserve=False)
                old.prepare_b()
                self.assert_success(old.run())
                contract = (old.round / 'domain-review-contract.json').read_bytes()
                self.assertEqual(json.loads(contract)['run_id'], 'synthetic-host-event')
                for fixture in (old, new):
                    _, result, transcript = self.native(root=fixture.root)
                    status = self.register(result, transcript, root=fixture.root)
                    self.assertEqual('REVIEW_HOST_REGISTERED', status['outcome'])
                self.assert_success(old.run('verify'))
                for name in outputs:
                    (old.round / name).unlink()
                self.assert_success(old.run())
                self.assertEqual((old.round / 'domain-review-contract.json').read_bytes(), contract)
                new.reserve('a', new.paths)
                new.output('a')
                new.prepare_b()
                self.assert_success(new.run())
                bound = json.loads((new.round / 'domain-review-contract.json').read_bytes())
                self.assertEqual((bound['run_id'], bound['host_session_id']),
                                 (status['record']['run_id'], status['record']['host_session_id']))
                self.assert_success(new.run('verify'))

    def test_root_reproductions_are_refused(self):
        lines = self.lines(self.session)
        lines.insert(2, dict(type='future-record', sessionId=self.session))
        self.write_lines(self.transcript, lines)
        self.assert_blocked(message='unknown native record type')
        self.write_lines(self.transcript, self.lines(self.session))
        real_publish = identity.publish_receipt

        def publish_then_append(*args):
            real_publish(*args)
            with self.transcript.open('ab') as stream:
                stream.write((json.dumps(self.lines(self.session)[3]) + '\n').encode())
        before = self.ledger_bytes()
        with mock.patch.object(identity, 'publish_receipt', publish_then_append):
            with self.assertRaises(identity.Unpublished):
                self.register()
        self.assertEqual(self.ledger_bytes(), before)
        self.assertEqual(len(list((self.root / 'reports/review-context/host-registrations').glob('*.json'))), 1)
        alias = self.base / 'late-alias.json'
        real_check = identity.regular_file

        def link_after_check(path):
            checked = real_check(path)
            if not alias.exists():
                os.link(checked, alias)
            return checked
        with mock.patch.object(identity, 'regular_file', link_after_check), self.assertRaises(identity.Blocked):
            identity.read_regular(self.result, 1024)
        alias.unlink()

    def test_evidence_change_before_publication_blocks(self):
        report = self.put('reports/implementation/f/T-001.md', 'Run ID: impl-run\n')
        real_publish = identity.publish_receipt
        real_scan = identity.implementation_identities
        calls = []

        def scan_then_change(root):
            calls.append(root)
            if len(calls) == 2:
                report.write_text('Run ID: changed-run\n')
            return real_scan(root)
        before = self.state()
        with mock.patch.object(identity, 'implementation_identities', scan_then_change), \
                self.assertRaises(identity.Blocked) as caught:
            self.register()
        self.assertIn('implementation evidence changed', str(caught.exception))
        self.assertEqual(self.state(), before)
        self.put('reports/implementation/f/T-001.md', 'Run ID: impl-run\n')
        changed = []

        def change_result(*args):
            real_publish(*args)
            if not changed:
                changed.append(True)
                self.result.write_bytes(self.result.read_bytes() + b'\n')
        with mock.patch.object(identity, 'publish_receipt', change_result), self.assertRaises(identity.Unpublished):
            self.register()
        self.assertEqual(json.loads(self.ledger_bytes())['records'], self.records)

    def test_enumeration_limits_count_every_entry(self):
        for number in range(4):
            (self.root / 'reports/quality-gate/ignored' / str(number)).mkdir(parents=True)
        with mock.patch.object(identity, 'EVIDENCE_FILES', 3):
            self.assert_blocked(message='entry limit')
        shutil.rmtree(self.root / 'reports/quality-gate')
        receipts = self.root / 'reports/review-context/host-registrations'
        receipts.mkdir()
        for number in range(4):
            (receipts / (identity.RECEIPT_STAGING + str(number))).write_text('')
        with mock.patch.object(identity, 'EVIDENCE_FILES', 3):
            self.assert_blocked(message='receipt directory exceeds its entry limit')
        self.assertEqual('REVIEW_HOST_REGISTERED', self.register()['outcome'])

    def test_unreadable_evidence_directories_block(self):
        nested = self.root / 'reports/implementation/f/hidden'
        self.put('reports/implementation/f/hidden/T-001.md', f'Run ID: {self.session}\n')
        self.assert_blocked(message='already recorded by implementation evidence')
        for directory in ('handoffs/f/hidden', 'reports/quality-gate/f/hidden'):
            self.put(directory + '/inputs.json', json.dumps(dict(run_id='other-run')))
        targets = [nested, self.root / 'reports/implementation', self.root / 'handoffs/f/hidden',
                   self.root / 'reports/quality-gate']
        real_scandir = os.scandir

        def denied(target):
            def scandir(path='.'):
                if os.fspath(path) == os.fspath(target):
                    raise PermissionError(errno.EACCES, 'simulated unreadable directory')
                return real_scandir(path)
            return scandir
        for target in targets:
            with self.subTest(injected=target.relative_to(self.root).as_posix()):
                with mock.patch.object(identity.os, 'scandir', denied(target)):
                    self.assert_blocked(message='implementation evidence directory is unreadable')
            if os.geteuid() != 0:  # root ignores directory modes; the injected case still runs
                with self.subTest(mode=target.relative_to(self.root).as_posix()):
                    mode = target.stat().st_mode
                    target.chmod(0)
                    self.addCleanup(target.chmod, mode)
                    try:
                        self.assert_blocked(message='implementation evidence directory is unreadable')
                    finally:
                        target.chmod(mode)
        (nested / 'T-001.md').unlink()
        self.assertEqual('REVIEW_HOST_REGISTERED', self.register()['outcome'])

    def test_existing_host_retry_rechecks_implementation_evidence(self):
        self.assertEqual('REVIEW_HOST_REGISTERED', self.register()['outcome'])
        report = self.put('reports/implementation/f/T-001.md', f'Run ID: {self.session}\n')
        self.assert_blocked(message='already recorded by implementation evidence')
        report.write_text('Run ID: impl-run\n')
        resumed = self.transcript.read_bytes() + (json.dumps(self.lines(self.session)[3]) + '\n').encode()
        self.transcript.write_bytes(resumed)  # Clean same-ID resume stays valid.
        self.assertEqual('REVIEW_HOST_ALREADY_REGISTERED', self.register(check_only=True)['outcome'])
        self.assertEqual('REVIEW_HOST_ALREADY_REGISTERED', self.register()['outcome'])
        self.put('handoffs/f/inputs.json', '{"run_id":')
        self.assert_blocked(error=(ValueError, OSError))
        (self.root / 'handoffs/f/inputs.json').unlink()
        hidden = self.root / 'reports/implementation/f'
        real_scandir = os.scandir

        def scandir(path='.'):
            if os.fspath(path) == os.fspath(hidden):
                raise PermissionError(errno.EACCES, 'simulated unreadable directory')
            return real_scandir(path)
        with mock.patch.object(identity.os, 'scandir', scandir):
            self.assert_blocked(message='implementation evidence directory is unreadable')
        if os.geteuid() != 0:  # root ignores directory modes; the injected case above still runs
            mode = hidden.stat().st_mode
            hidden.chmod(0)
            self.addCleanup(hidden.chmod, mode)
            try:
                self.assert_blocked(message='implementation evidence directory is unreadable')
            finally:
                hidden.chmod(mode)
        self.assertEqual('REVIEW_HOST_ALREADY_REGISTERED', self.register()['outcome'])

    def test_domain_entrypoint_routes_existing_ledger_claude_host(self):
        skill = (ROOT / 'plugins/sdd-domain/skills/domain-review-loop/SKILL.md').read_text()
        boundary = (ROOT / 'plugins/sdd-review-loop/references/review-context-boundary.md').read_text()
        heading = 'Registering a Claude host into an existing ledger'
        self.assertIn('## ' + heading, boundary)
        self.assertIn(heading, skill)
        self.assertNotIn('skip initialization', skill)
        command = ('python3 plugins/sdd-quality-loop/scripts/initialize-review-identity.py --root <repository-root> '
                   '--register-existing --claude-result <captured result> --claude-transcript <native transcript>')
        lines = [line.strip() for line in skill.splitlines()]
        self.assertEqual(lines[lines.index(command + ' --check-only') + 1], command)  # check first, then append
        for text in ('--copilot-events', '--register-existing', '--check-only', 'before reviewer A',
                     'same native session ID is resumed', 'external operator', 'hard stop'):
            self.assertIn(text, skill)

    def test_known_path_only_manifest_citations(self):
        target = 'handoffs/T-007-input-manifest.json'
        report = 'reports/implementation/f/T-007.md'
        forms = ['Input manifest: `{}`.', 'Input manifest: `{}` (TASK_INPUT_OK).']

        def manifest(**fields):
            return json.dumps(dict(dict(schema='task-input-manifest/v1', task_id='T-007', run_id='impl-run',
                                        session_id='impl-session'), **fields))
        for form in forms:
            with self.subTest(form=form):
                self.put(target, manifest())
                self.put(report, 'Run ID: impl-run\n' + form.format(target) + '\n')
                self.assertEqual('REVIEW_HOST_CHECK_REGISTRABLE', self.register(check_only=True)['outcome'])
                for field in ('run_id', 'session_id'):
                    self.put(target, manifest(**{field: self.session}))
                    self.assert_blocked(message='already recorded by implementation evidence')
                for document in (manifest(schema='other/v1'), manifest(run_id=''), manifest(session_id=7),
                                 json.dumps(dict(schema='task-input-manifest/v1', run_id='impl-run')), '{"a":'):
                    self.put(target, document)
                    self.assert_blocked(error=(ValueError, OSError))
                # A manifest reference must be one object; arrays and scalars never pass, even holding the candidate.
                for document in ('[]', json.dumps([json.loads(manifest(run_id=self.session, session_id=self.session))]),
                                 'null', '"x"', '7', 'true'):
                    self.put(target, document)
                    self.assert_blocked(message='implementation task manifest identity is invalid')
                self.put(target, manifest())
                (self.root / target).unlink()
                self.assert_blocked(error=(ValueError, OSError))
                outside = self.put('elsewhere/m.json', manifest())
                (self.root / target).symlink_to(outside)
                self.assert_blocked(error=ValueError)
                (self.root / target).unlink()
                self.put(target, manifest())
                os.link(self.root / target, self.base / 'manifest-alias.json')
                self.assert_blocked(error=ValueError)
                (self.base / 'manifest-alias.json').unlink()
        self.put('handoffs/T-007-input-manifest.txt', manifest())
        self.put('specs/f/T-007-input-manifest.json', manifest())
        explicit = 'Input manifest: `{}`, SHA-256 `{}`.'
        rejected = [forms[0].format('handoffs/../specs/f/T-007-input-manifest.json'),
                    forms[0].format('handoffs/./T-007-input-manifest.json'),
                    forms[0].format('specs/f/T-007-input-manifest.json'),
                    forms[0].format('handoffs/T-007-input-manifest.txt'),
                    forms[0].format('/handoffs/T-007-input-manifest.json'),
                    'Input manifest: `{}` (OTHER).'.format(target), 'Input manifest: `{}`'.format(target),
                    'Input manifest: {}.'.format(target),
                    explicit.format(target, '0' * 64), explicit.format(target, 'abc'),
                    'Input manifest: `{}`, SHA-256 `{}` (TASK_INPUT_OK).'.format(target, '0' * 64)]
        for line in rejected:
            with self.subTest(line=line):
                self.put(report, 'Run ID: impl-run\n' + line + '\n')
                self.assert_blocked(error=(ValueError, OSError))
        self.put(report, 'Run ID: impl-run\n' + explicit.format(target, sha((self.root / target).read_bytes())) + '\n')
        self.assertEqual('REVIEW_HOST_CHECK_REGISTRABLE', self.register(check_only=True)['outcome'])
        valid = (self.root / target).read_bytes()
        self.put(target, '[]')
        self.put(report, 'Run ID: impl-run\n' + explicit.format(target, sha(b'[]')) + '\n')
        self.assert_blocked(message='implementation task manifest identity is invalid')
        self.put(target, valid)
        # A path-only target is still part of the recheck fingerprint before publication.
        self.put(report, 'Run ID: impl-run\n' + forms[1].format(target) + '\n')
        real_scan, calls = identity.implementation_identities, []

        def scan_then_change(root):
            calls.append(root)
            if len(calls) == 2:
                self.put(target, manifest(run_id='other-run'))
            return real_scan(root)
        before = self.state()
        with mock.patch.object(identity, 'implementation_identities', scan_then_change), \
                self.assertRaises(identity.Blocked) as caught:
            self.register()
        self.assertIn('implementation evidence changed', str(caught.exception))
        self.assertEqual((len(calls), self.state()), (2, before))
        self.assertEqual('REVIEW_HOST_REGISTERED', self.register()['outcome'])

    def test_exact_normal_mode_record_only(self):
        lines = self.lines(self.session)
        mode = dict(type='mode', mode='normal', sessionId=self.session)
        self.write_lines(self.transcript, lines[:1] + [mode] + lines[1:])
        self.assertEqual('REVIEW_HOST_CHECK_REGISTRABLE', self.register(check_only=True)['outcome'])
        accepted = self.transcript.read_bytes()
        for record in (dict(mode, mode='plan'), dict(mode, mode='Normal'), dict(mode, mode=None),
                       dict(mode, extra=1), {'type': 'mode', 'sessionId': self.session},
                       dict(mode, sessionId=str(uuid.uuid4())), dict(mode, type='mode-change'),
                       dict(type='future-record', sessionId=self.session)):
            with self.subTest(record=record):
                self.write_lines(self.transcript, lines[:1] + [record] + lines[1:])
                self.assert_blocked(error=identity.Blocked)
        self.transcript.write_bytes(accepted)
        self.assertEqual('REVIEW_HOST_REGISTERED', self.register()['outcome'])
        self.transcript.write_bytes(accepted + (json.dumps(mode) + '\n').encode())  # later same-ID resume
        self.assertEqual('REVIEW_HOST_ALREADY_REGISTERED', self.register()['outcome'])

    def test_staging_hardlink_interruption_is_unpublished(self):
        real_unlink = Path.unlink

        def keep_staging(path, missing_ok=False):
            if path.name.startswith(identity.RECEIPT_STAGING):
                raise OSError(errno.EIO, 'simulated interruption before staging unlink')
            return real_unlink(path, missing_ok=missing_ok)
        with mock.patch.object(identity.Path, 'unlink', keep_staging), self.assertRaises(OSError):
            self.register()
        folder = self.root / 'reports/review-context/host-registrations'
        staging = [path for path in folder.iterdir() if path.name.startswith(identity.RECEIPT_STAGING)]
        receipt = [path for path in folder.iterdir() if path.name.endswith('.json')]
        self.assertEqual((len(staging), len(receipt), receipt[0].stat().st_nlink), (1, 1, 2))
        self.assertTrue(os.path.samefile(staging[0], receipt[0]))
        self.assertEqual(json.loads(self.ledger_bytes())['records'], self.records)
        self.assert_blocked(error=identity.Unpublished, message='shares its file with one staging name')
        base = [sys.executable, str(IDENTITY), '--root', str(self.root), '--register-existing',
                '--claude-result', str(self.result), '--claude-transcript', str(self.transcript)]
        before = self.state()
        for extra in (['--check-only'], []):
            result = subprocess.run(base + extra, capture_output=True, text=True, stdin=subprocess.DEVNULL)
            self.assertEqual((result.returncode, result.stdout), (1, (
                'REVIEW_HOST_UNPUBLISHED: a registration receipt still shares its file with one staging '
                'name after an interrupted write; it was preserved and needs the documented manual recovery\n')))
            self.assertEqual(self.state(), before)
        # Unknown or extra links are refused, never treated as the recognized interruption.
        second = folder / (identity.RECEIPT_STAGING + 'second')
        os.link(receipt[0], second)
        self.assert_blocked(error=ValueError)
        self.assertNotIsInstance(self._last_blocked(), identity.Unpublished)
        second.unlink()
        staging[0].unlink()
        outside = self.base / 'outside-link.json'
        os.link(receipt[0], outside)
        self.assert_blocked(error=ValueError)
        self.assertNotIsInstance(self._last_blocked(), identity.Unpublished)
        outside.unlink()
        decoy = folder / (identity.RECEIPT_STAGING + 'decoy')
        decoy.write_bytes(receipt[0].read_bytes())
        os.link(receipt[0], outside)
        self.assertNotIsInstance(self._last_blocked(), identity.Unpublished)
        outside.unlink()
        decoy.unlink()
        # Documented manual recovery: only the staging name was removed; the identical append completes.
        status = self.register(check_only=True)
        self.assertEqual((status['outcome'], status['pending']), ('REVIEW_HOST_CHECK_REGISTRABLE', True))
        status = self.register()
        self.assertEqual((status['outcome'], status['pending']), ('REVIEW_HOST_REGISTERED', True))
        self.assertEqual(json.loads(self.ledger_bytes())['records'][:-1], self.records)

    def _last_blocked(self):
        try:
            self.register(check_only=True)
        except ValueError as error:
            return error
        self.fail('registration was not refused')

    def test_stream_json_preserves_raw_unicode_separators(self):
        # Raw-valid JSON separators; U+001C-001E are controls JSON must escape, so only the escaped form applies.
        for text in ('line\u2028separator', 'para\u2029graph', 'next\x85line', 'group\x1cfile\x1drecord\x1e'):
            with self.subTest(text=repr(text)):
                session, result, transcript = self.native(stream=True)
                documents = [json.loads(line) for line in result.read_text(encoding='utf-8').split('\n') if line]
                documents[1]['message']['content'] = [dict(type='text', text=text)]
                documents[2]['result'] = text
                raw = ''.join(json.dumps(item, ensure_ascii=False) + '\n' for item in documents).encode()
                self.assertEqual(text.encode() in raw, ord(min(text)) >= 0x20)
                result.write_bytes(raw)
                self.assertEqual('REVIEW_HOST_CHECK_REGISTRABLE',
                                 self.register(result, transcript, check_only=True)['outcome'])
                result.write_bytes(''.join(json.dumps(item) + '\n' for item in documents).encode())
                self.assertEqual('REVIEW_HOST_CHECK_REGISTRABLE',
                                 self.register(result, transcript, check_only=True)['outcome'])
                result.write_bytes(json.dumps(documents[2], ensure_ascii=False).encode())
                self.assertEqual('REVIEW_HOST_CHECK_REGISTRABLE',
                                 self.register(result, transcript, check_only=True)['outcome'])

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
