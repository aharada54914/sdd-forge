#!/usr/bin/env python3
"""Concept Test acceptance: real signed evidence, stale inputs, and read-only gates."""
import copy
import hashlib
import importlib.util
import io
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
SCRIPT = ROOT / 'plugins/sdd-domain/scripts/validate-concept-test.py'
GENERATOR = ROOT / 'plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py'
spec = importlib.util.spec_from_file_location('concept', SCRIPT)
concept = importlib.util.module_from_spec(spec)
spec.loader.exec_module(concept)
IDENTITY = ROOT / 'plugins/sdd-quality-loop/scripts/initialize-review-identity.py'
identity_spec = importlib.util.spec_from_file_location('initial_review_identity', IDENTITY)
identity = importlib.util.module_from_spec(identity_spec)
identity_spec.loader.exec_module(identity)


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

    def local_proposal(self, proposal='NEW_CONCEPT_CANDIDATE'):
        self.record.update(schema='concept-test/v2', proposal=proposal)
        self.record.pop('decision', None)
        self.save()
        return self.feature / 'concept-test.decision.json'

    def test_manual_publication_of_the_reviewed_model(self):
        # Simulate a human's documented edits on an isolated project. The
        # product reads both canonical files and never grants approval itself.
        contract_path = self.root / 'domain/domain-contract.json'
        context_path = self.root / 'domain/context-map.md'
        contract = json.loads(contract_path.read_bytes())
        shell = (['pwsh', '-NoProfile', '-File', str(SCRIPT.with_name('validate-domain-contract.ps1'))]
                 if os.name == 'nt' else ['bash', str(SCRIPT.with_name('validate-domain-contract.sh'))])

        def propose():
            for source in self.record['inputs']:
                source['sha256'] = hashlib.sha256((self.root / source['path']).read_bytes()).hexdigest()
            self.local_proposal('FITS_EXISTING_CONCEPTS')

        def publish_after_comparison(staged):
            # Simulate the human comparing the old release, the reviewed status
            # and the candidate, before the shipped checker and atomic replace.
            current = json.loads(contract_path.read_bytes())
            candidate = contract_path.with_suffix('.candidate')
            candidate.write_text(json.dumps(staged), encoding='utf-8')
            for document in (current, staged):
                try:
                    concept.check_schema('domain-contract.v2.schema.json', document)
                except ValueError:
                    return False
            major, minor, patch = current['meta']['version'].split('.')
            expected = copy.deepcopy(current)
            expected['meta'].update(status='Approved', version=f'{major}.{minor}.{int(patch) + 1}')
            if staged != expected or context_path.read_text().splitlines() != ['Domain-Model-Status: Approved']:
                return False
            check = subprocess.run([*shell, str(candidate)], capture_output=True, text=True)
            self.assertEqual(0, check.returncode, check.stdout + check.stderr)
            candidate.replace(contract_path)
            return True

        for revision in (1, 2):  # Initial review and the next explicit update.
            with self.subTest(revision=revision):
                contract['meta']['status'] = 'Pending'
                self.write('domain/domain-contract.json', contract)
                for status in ('Pending', 'Reviewed', 'Approved'):
                    context_path.write_text(f'Domain-Model-Status: {status}\n')
                    propose()
                    self.gate(1)
                contract['meta'].update(status='Approved', version=f'1.0.{revision}')
                before = contract_path.read_bytes()
                for metadata in ({'version': f'1.0.{revision}.'}, {'version': f'1.0.{revision + 1}'},
                                 {'version': f'2.0.{revision}'}, {'version': f'1.1.{revision}'},
                                 {'status': 'Reviewed'}, {'status': 'ApprovedLater'}):
                    with self.subTest(metadata=metadata):
                        staged = copy.deepcopy(contract)
                        staged['meta'].update(metadata)
                        self.assertFalse(publish_after_comparison(staged))
                        self.assertEqual(before, contract_path.read_bytes())
                altered = copy.deepcopy(contract)
                altered['concepts'][0]['definition'] += ' Unreviewed change.'
                self.assertFalse(publish_after_comparison(altered))
                self.assertEqual(before, contract_path.read_bytes())
                self.assertTrue(publish_after_comparison(contract))
                self.gate(1)  # The previous proposal still pins the old version.
                propose()
                before = contract_path.read_bytes()
                self.assertEqual('CONTINUE\n', self.gate().stdout)
                self.assertEqual(before, contract_path.read_bytes())
                context_path.write_text('Domain-Model-Status: Reviewed\n')
                propose()
                self.gate(1)  # An Approved JSON alone does not authorize the model.

        contract['meta']['version'] += '.'
        self.write('domain/domain-contract.json', contract)
        before = contract_path.read_bytes()
        contract['meta']['version'] = '1.0.3'
        context_path.write_text('Domain-Model-Status: Approved\n')
        self.assertFalse(publish_after_comparison(contract))
        self.assertEqual(before, contract_path.read_bytes())

    def local_confirmation(self, answer):
        # Synthetic terminal input only, inside this test's temporary project.
        output = io.StringIO()
        with mock.patch.object(sys.stdin, 'isatty', return_value=True), mock.patch.object(sys, 'stdout', output), \
                mock.patch.object(output, 'isatty', return_value=True), mock.patch('builtins.input') as prompt:
            if callable(answer) or isinstance(answer, BaseException):
                prompt.side_effect = answer
            else:
                prompt.return_value = answer
            result = concept.confirm(self.root, 'example')
            self.assertIn('proceed / defer-to-domain-update / rejected', prompt.call_args.args[0])
            return result, output.getvalue()

    def test_keyless_all_proposals_and_choices(self):
        (self.root / 'sdd/approver-registry.yaml').unlink()
        with mock.patch.dict(os.environ, {}, clear=False):
            os.environ.pop('SDD_CONTEXT_KEY', None)
            os.environ.pop('SDD_CONTEXT_KEY_FILE', None)
            for proposal in ('NEW_CONCEPT_CANDIDATE', 'RESPONSIBILITY_CONFLICT', 'REQUIRES_HUMAN_DECISION'):
                path = self.local_proposal(proposal)
                for answer, outcome in (('proceed', 'CONTINUE'), ('defer-to-domain-update', 'DEFER'), ('rejected', 'REJECT')):
                    with self.subTest(proposal=proposal, answer=answer):
                        result, output = self.local_confirmation(answer)
                        self.assertEqual(outcome, result)
                        displayed = json.loads(output)
                        for key in ('feature', 'proposal', 'rationale', 'distinctions', 'inputs'):
                            self.assertEqual(self.record[key], displayed[key])
                        receipt = json.loads(path.read_bytes())
                        self.assertEqual(answer, receipt['decision'])
                        self.assertEqual('example', receipt['feature'])
                        self.assertEqual('concept-test-decision/v1', receipt['schema'])
                        for ext in ('json', 'md'):
                            expected = hashlib.sha256((self.feature / ('concept-test.' + ext)).read_bytes()).hexdigest()
                            self.assertEqual(expected, receipt['proposal_' + ext + '_sha256'])
                            self.assertEqual(expected, displayed['proposal_' + ext + '_sha256'])
                        before = {f.name: f.read_bytes() for f in self.feature.iterdir()}
                        self.assertEqual(outcome, concept.validate(self.root, 'example', require_v2=True))
                        self.assertEqual(before, {f.name: f.read_bytes() for f in self.feature.iterdir()})

    def test_keyless_fits_strict_mode_and_dispatchers(self):
        with self.assertRaises(ValueError):
            concept.validate(self.root, 'example', require_v2=True)
        path = self.local_proposal('FITS_EXISTING_CONCEPTS')
        self.assertEqual('CONTINUE', concept.validate(self.root, 'example', require_v2=True))
        with self.assertRaises(ValueError):
            self.local_confirmation('proceed')
        self.assertFalse(path.exists())
        self.local_proposal()
        self.local_confirmation('defer-to-domain-update')
        for wrapper in ([sys.executable, str(SCRIPT)], ['sh', str(SCRIPT.with_suffix('.sh'))],
                        ['pwsh', '-NoProfile', '-File', str(SCRIPT.with_suffix('.ps1'))]):
            if not shutil.which(wrapper[0]):
                continue
            self.assertEqual('DEFER\n', self.gate(2, wrapper=wrapper + ['--require-v2']).stdout)
            blocked = subprocess.run(wrapper + ['--confirm', '--root', str(self.root), '--feature', 'example'],
                                     input='proceed\n', capture_output=True, text=True)
            self.assertEqual(1, blocked.returncode)
            self.assertIn('interactive', blocked.stderr)
        invalid = subprocess.run([sys.executable, str(SCRIPT), '--root', str(self.root), '--feature', 'example',
                                  '--confirm', '--decision', 'proceed'], capture_output=True, text=True)
        self.assertNotEqual(0, invalid.returncode)
        self.assertIn('unrecognized arguments', invalid.stderr)
        self.assertEqual('defer-to-domain-update', json.loads(path.read_bytes())['decision'])
        shutil.rmtree(self.root / 'domain')
        self.assertEqual('SKIP', concept.validate(self.root, 'example'))
        with self.assertRaises(ValueError):
            concept.validate(self.root, 'example', require_v2=True)

    def test_keyless_absent_stale_invalid_or_mixed_decisions_block(self):
        path = self.local_proposal()
        self.gate(1)
        self.local_confirmation('proceed')
        receipt = json.loads(path.read_bytes())
        for update in ({'feature': 'different'}, {'decision': 'unknown'}, {'proposal_json_sha256': '0' * 64},
                       {'proposal_md_sha256': '0' * 64}, {'extra': True}, {'schema': 'unknown'}):
            with self.subTest(update=update):
                path.write_text(json.dumps(dict(receipt, **update)), encoding='utf-8')
                self.gate(1)
        path.write_text(json.dumps(receipt), encoding='utf-8')
        for ext in ('md', 'json'):
            f = self.feature / ('concept-test.' + ext)
            original = f.read_bytes()
            f.write_bytes(original + b'\n')
            self.gate(1)
            f.write_bytes(original)
        self.record['decision'] = 'proceed'
        self.save()
        self.gate(1)
        self.local_proposal()
        approval = self.feature / 'concept-test.approval.json'
        approval.write_text('{}', encoding='utf-8')
        self.gate(1)
        with self.assertRaises(ValueError):
            self.local_confirmation('proceed')
        self.local_proposal('FITS_EXISTING_CONCEPTS')
        path.unlink()
        self.gate(1)
        self.record['schema'] = 'concept-test/v1'
        self.save()
        self.gate(1)
        approval.unlink()
        path.write_text(json.dumps(receipt), encoding='utf-8')
        self.gate(1)
        self.record.update(proposal='NEW_CONCEPT_CANDIDATE', decision='proceed')
        self.save()
        self.sign()
        self.gate(1)

    def test_keyless_cancel_concurrent_choice_and_failed_publication(self):
        path = self.local_proposal()
        for answer, error in (('', ValueError), ('unknown', ValueError), (EOFError(), EOFError)):
            with self.assertRaises(error):
                self.local_confirmation(answer)
            self.assertFalse(path.exists())

        def change_inputs(prompt):
            seed = self.feature / 'concept-test-seed.md'
            seed.write_bytes(seed.read_bytes() + b' updated')
            return 'proceed'

        with self.assertRaisesRegex(ValueError, 'changed'):
            self.local_confirmation(change_inputs)
        self.assertFalse(path.exists())
        self.write('specs/example/concept-test-seed.md', 'Find a publication.\n')

        def other_confirmation(prompt):
            self.local_confirmation('rejected')
            return 'proceed'

        with self.assertRaisesRegex(ValueError, 'changed'):
            self.local_confirmation(other_confirmation)
        prior = path.read_bytes()
        self.assertEqual('rejected', json.loads(prior)['decision'])
        lock = path.with_suffix('.lock')
        lock.touch()
        with self.assertRaises(FileExistsError):
            self.local_confirmation('proceed')
        self.assertTrue(lock.exists())
        lock.unlink()
        before = set(self.feature.iterdir())
        with mock.patch.object(concept.os, 'replace', side_effect=OSError('fixture write failure')):
            with self.assertRaisesRegex(OSError, 'fixture write failure'):
                self.local_confirmation('proceed')
        self.assertEqual(prior, path.read_bytes())
        self.assertEqual(before, set(self.feature.iterdir()))

        publish = os.replace
        def concurrent_edit(source, destination):
            publish(source, destination)
            change_inputs(None)

        with mock.patch.object(concept.os, 'replace', side_effect=concurrent_edit):
            with self.assertRaisesRegex(ValueError, 'input changed'):
                self.local_confirmation('proceed')
        self.assertEqual(path.read_bytes(), prior)
        self.gate(1)
        path.unlink()
        self.write('specs/example/concept-test-seed.md', 'Find a publication.\n')
        with mock.patch.object(concept.os, 'replace', side_effect=concurrent_edit):
            with self.assertRaisesRegex(ValueError, 'input changed'):
                self.local_confirmation('proceed')
        self.assertFalse(path.exists())

    def test_keyless_review_manifest_and_fixed_revision(self):
        # An installed consumer project does not contain the plugin source contracts.
        shutil.rmtree(self.root / 'contracts')
        path = self.local_proposal()
        self.write('specs/example/requirements.md', 'Bounded-Context: catalog\n')

        def git(*args):
            return subprocess.check_output(['git', '-C', str(self.root), *args], text=True).strip()

        def commit(message):
            git('add', '.')
            git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', message)
            return git('rev-parse', 'HEAD')

        git('init', '-q')
        absent = commit('Proposal only')
        self.local_confirmation('proceed')
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        selected = commit('Synthetic local decision')
        with self.assertRaises(ValueError):
            concept.evidence(self.root, 'example')  # Legacy signed decision-packet consumer.
        for stage in ('spec', 'impl', 'task', 'quality'):
            with self.subTest(stage=stage):
                with self.assertRaises(ValueError):
                    concept.conditional.resolve(self.root, 'example', stage, absent)
                live = concept.conditional.resolve(self.root, 'example', stage)
                fixed = concept.conditional.resolve(self.root, 'example', stage, selected)
                self.assertEqual(live['inputs'], fixed['inputs'])
                self.assertIn({'path': 'specs/example/concept-test.decision.json', 'sha256': digest}, fixed['inputs'])
                self.assertNotIn('sdd/approver-registry.yaml', fixed['observed'])
        for answer in ('defer-to-domain-update', 'rejected'):
            self.local_confirmation(answer)
            for stage in ('spec', 'impl', 'task', 'quality'):
                with self.assertRaises(ValueError):
                    concept.conditional.resolve(self.root, 'example', stage)
                self.assertTrue(concept.conditional.resolve(self.root, 'example', stage, selected)['inputs'])

    def test_nested_installed_project_selects_its_own_revision(self):
        # The monorepo and the nested project deliberately share a feature name.
        nested = self.root / 'apps/billing'
        (self.root / 'apps').mkdir()
        nested.mkdir()
        for name in ('domain', 'specs'):
            shutil.copytree(self.root / name, nested / name)
        self.local_proposal('FITS_EXISTING_CONCEPTS')
        self.write('specs/example/requirements.md', 'Bounded-Context: catalog\n')
        self.root = nested
        self.feature = nested / 'specs/example'
        self.local_proposal()
        self.write('specs/example/requirements.md', 'Bounded-Context: catalog\n')
        self.local_confirmation('proceed')
        git = ['git', '-C', str(nested.parents[1])]
        subprocess.run(git + ['init', '-q'], check=True)
        subprocess.run(git + ['add', '.'], check=True)
        subprocess.run(git + ['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                              'commit', '-qm', 'Two projects sharing a feature name'], check=True)
        revision = subprocess.check_output(git + ['rev-parse', 'HEAD'], text=True).strip()
        for stage in ('spec', 'impl', 'task', 'quality'):
            with self.subTest(stage=stage):
                live = concept.conditional.resolve(nested, 'example', stage)
                fixed = concept.conditional.resolve(nested, 'example', stage, revision)
                self.assertEqual('active', fixed['domain_status'])
                self.assertEqual(live['inputs'], fixed['inputs'])
                self.assertIn('specs/example/concept-test.decision.json', {e['path'] for e in fixed['inputs']})
        self.local_confirmation('rejected')
        subprocess.run(git + ['add', '.'], check=True)
        subprocess.run(git + ['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                              'commit', '-qm', 'Rejected nested proposal'], check=True)
        rejected = subprocess.check_output(git + ['rev-parse', 'HEAD'], text=True).strip()
        for stage in ('spec', 'impl', 'task', 'quality'):
            with self.assertRaisesRegex(ValueError, 'does not permit'):
                concept.conditional.resolve(nested, 'example', stage, rejected)

    def test_no_domain_skips(self):
        shutil.rmtree(self.root / 'domain')
        self.assertEqual('SKIP\n', self.gate().stdout)

    def test_no_domain_skips_for_any_feature_name_ship_accepts(self):
        # #809: applicability comes before the DDD naming rule, so a project
        # without domain/ never stops on a feature name ship accepts.
        shutil.rmtree(self.root / 'domain')
        wrappers = [[sys.executable, str(SCRIPT)]]
        if os.name != 'nt' and shutil.which('sh'):
            wrappers.append(['sh', str(SCRIPT.with_suffix('.sh'))])
        for wrapper in wrappers:
            for feature in ('order_sync', 'order-sync', 'Order.v2'):
                result = subprocess.run(wrapper + ['--root', str(self.root), '--feature', feature],
                                        env=self.env, capture_output=True, text=True)
                self.assertEqual((0, 'SKIP\n'), (result.returncode, result.stdout), feature + result.stderr)
            for feature in ('..', 'a/b', ''):
                result = subprocess.run(wrapper + ['--root', str(self.root), '--feature', feature],
                                        env=self.env, capture_output=True, text=True)
                self.assertEqual(1, result.returncode, feature)

    def test_ddd_feature_outside_naming_rule_says_so(self):
        result = subprocess.run([sys.executable, str(SCRIPT), '--root', str(self.root), '--feature', 'order_sync'],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(1, result.returncode)
        self.assertIn('lowercase', result.stderr)

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
        core_spec = (ROOT / 'plugins/sdd-bootstrap/skills/sdd-core-spec/SKILL.md').read_text(encoding='utf-8')
        self.assertIn('`concept-test`', core_spec)
        self.assertIn('`domain-sync`', core_spec)
        self.assertIn('`domain-sync skipped: no domain/ directory`', core_spec)
        skill = (ROOT / 'plugins/sdd-domain/skills/concept-test/SKILL.md').read_text(encoding='utf-8')
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


if __name__ == '__main__':
    unittest.main()
