#!/usr/bin/env python3
"""Concept Test acceptance: real signed evidence, stale inputs, and read-only gates."""
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

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'plugins/sdd-domain/scripts/validate-concept-test.py'
GENERATOR = ROOT / 'plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py'
spec = importlib.util.spec_from_file_location('concept', SCRIPT)
concept = importlib.util.module_from_spec(spec)
spec.loader.exec_module(concept)


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
        (self.root / path).write_text(value if isinstance(value, str) else json.dumps(value), encoding='utf-8')

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
        result = concept.conditional.resolve(self.root, 'example', 'spec')
        self.assertIn('specs/example/concept-test.approval.json', {item['path'] for item in result['inputs']})
        (self.feature / 'concept-test.md').unlink()
        with self.assertRaises(ValueError):
            concept.conditional.resolve(self.root, 'example', 'spec')


if __name__ == '__main__':
    unittest.main()
