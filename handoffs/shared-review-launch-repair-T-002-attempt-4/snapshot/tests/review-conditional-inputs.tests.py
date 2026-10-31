#!/usr/bin/env python3
"""Conditional review dependencies: selection, skip and path boundaries."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import sys
import hashlib
import shutil
import subprocess

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('conditional', ROOT / 'plugins/sdd-quality-loop/scripts/review-conditional-inputs.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class Inputs(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.put('specs/example/requirements.md', 'Bounded-Context: sales\n')
        self.put('specs/example/design.md', '## Design System Compliance\nImplemented\n')
        for version in ('v1', 'v2'):
            self.put('contracts/domain-contract.' + version + '.schema.json',
                     (ROOT / ('contracts/domain-contract.' + version + '.schema.json')).read_text())

    def put(self, path, text):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding='utf-8')

    def domain(self, version='v1'):
        self.put('domain/context-map.md', 'Domain-Model-Status: Approved\n')
        doc = {'schema': 'domain-contract/' + version,
               'meta': {'version': '1.0.0', 'status': 'Approved', 'generated_from': ['domain/context-map.md']},
               'contexts': [{'name': 'sales', 'description': '', 'terms': [], 'aggregates': []}]}
        if version == 'v2':
            doc['concepts'] = [{'id': 'CONCEPT-ORDER', 'name': 'Order', 'context': 'sales',
                                'definition': 'order', 'essence': 'order',
                                'responsibilities': ['record'], 'evidence': ['story']}]
        self.put('domain/domain-contract.json', json.dumps(doc))
        return doc

    def resolve(self, stage='impl'):
        return module.resolve(self.root, 'example', stage)

    def test_absence_observed(self):
        result = self.resolve()
        self.assertEqual(result['inputs'], [])
        self.assertIsNone(result['observed']['domain/context-map.md'])

    def test_versions(self):
        for version in ('v1', 'v2'):
            self.domain(version)
            self.assertEqual(self.resolve()['domain_status'], 'active')
            self.assertEqual(len(self.resolve('spec')['inputs']), 2)

    def test_invalid_schema_preserves_skip(self):
        self.domain()
        for raw in ('{}', '{', '{"schema":"domain-contract/v1","schema":"domain-contract/v1"}'):
            self.put('domain/domain-contract.json', raw)
            self.assertEqual(self.resolve()['domain_status'], 'skipped')

    def test_schema_dependency_missing_blocks(self):
        self.domain()
        (self.root / 'contracts/domain-contract.v1.schema.json').unlink()
        with self.assertRaises(ValueError): self.resolve()

    def test_status_case_skips_and_bytes_bound(self):
        self.domain()
        before = self.resolve()
        self.put('domain/context-map.md', 'Domain-Model-Status: approved\n')
        after = self.resolve()
        self.assertEqual(after['domain_status'], 'skipped')
        self.assertNotEqual(before['observed'], after['observed'])

    def test_aggregate_selection_all_cards_only_selected_context(self):
        doc = self.domain()
        doc['contexts'][0]['aggregates'] = [{'name': 'Order', 'root_entity': 'Order', 'invariants': ['valid'], 'transaction_boundary': 'order', 'card': 'domain/aggregates/Order.md'}]
        other = json.loads(json.dumps(doc['contexts'][0]))
        other['name'] = 'other'
        other['aggregates'][0]['card'] = 'domain/aggregates/Absent.md'
        doc['contexts'].append(other)
        self.put('domain/domain-contract.json', json.dumps(doc))
        self.assertEqual(self.resolve('spec')['domain_status'], 'active')
        with self.assertRaisesRegex(ValueError, 'missing conditional input'): self.resolve()
        self.put('domain/aggregates/Order.md', 'Not mentioned in the design')
        selected = self.resolve()['inputs']
        self.assertEqual([x['path'] for x in selected][2:], ['domain/aggregates/Order.md'])
        self.assertEqual(selected[2]['sha256'], hashlib.sha256(b'Not mentioned in the design').hexdigest())
        self.assertEqual(len(self.resolve('spec')['inputs']), 2)

    def test_multiple_contexts_bind_sorted_union_without_relevance_filter(self):
        doc = self.domain()
        aggregate = dict(name='Order', root_entity='Order', invariants=['valid'], transaction_boundary='order')
        doc['contexts'][0]['aggregates'] = [dict(aggregate, card='domain/aggregates/Z.md')]
        doc['contexts'].append(dict(name='billing', description='', terms=[], aggregates=[
            dict(aggregate, card='domain/aggregates/Z.md'),
            dict(aggregate, name='Invoice', card='domain/aggregates/A.md')]))
        self.put('domain/domain-contract.json', json.dumps(doc))
        self.put('specs/example/requirements.md', 'Bounded-Context: sales, billing\n')
        for name in ('A', 'Z'):
            self.put(f'domain/aggregates/{name}.md', 'Not mentioned in design')
        self.assertEqual([item['path'] for item in self.resolve()['inputs']][2:],
                         ['domain/aggregates/A.md', 'domain/aggregates/Z.md'])

    def test_aggregate_rejects_unsafe_and_symlink_cards(self):
        doc = self.domain()
        aggregate = dict(name='Order', root_entity='Order', invariants=['valid'], transaction_boundary='order')
        for card in ('specs/example/design.md', '../outside.md', 'domain/aggregates/../secret.md', 'domain/aggregates/\\secret.md'):
            doc['contexts'][0]['aggregates'] = [dict(aggregate, card=card)]
            self.put('domain/domain-contract.json', json.dumps(doc))
            with self.assertRaises(ValueError): self.resolve()
        card = 'domain/aggregates/Order.md'
        doc['contexts'][0]['aggregates'] = [dict(aggregate, card=card)]
        self.put('domain/domain-contract.json', json.dumps(doc))
        self.put('domain/aggregates/Other.md', 'data')
        (self.root / card).symlink_to(self.root / 'domain/aggregates/Other.md')
        with self.assertRaises(ValueError): self.resolve()

    def test_ds_requires_three_and_spec_excludes(self):
        self.put('design-system/design-tokens.json', '{}')
        self.assertEqual(self.resolve('spec')['inputs'], [])
        with self.assertRaises(ValueError): self.resolve()
        self.put('design-system/design-system.md', 'rules')
        self.put('design-system/ui-patterns.md', 'patterns')
        self.assertEqual(len(self.resolve()['inputs']), 3)

    def test_strict_na_and_skip_hash(self):
        (self.root / 'design-system').mkdir()
        self.put('specs/example/design.md', '## Design System Compliance\r\nN/A — ds_profile: none\r\n')
        result = self.resolve()
        self.assertEqual(result['design_system_status'], 'skipped')
        self.assertIn('specs/example/design.md', result['observed'])
        self.put('specs/example/design.md', '## Design System Compliance\nN/A — ds_profile: none\nextra')
        with self.assertRaises(ValueError): self.resolve()

    def test_symlink_ancestor_and_broken_ds_rejected(self):
        (self.root / 'domain').symlink_to(self.root / 'absent', target_is_directory=True)
        with self.assertRaises(ValueError): self.resolve()
        (self.root / 'domain').unlink()
        (self.root / 'design-system').symlink_to(self.root / 'absent', target_is_directory=True)
        with self.assertRaises(ValueError): self.resolve()

    def test_path_boundaries(self):
        for value in ('../outside', '/etc/passwd', 'domain/../x', 'domain\\x'):
            with self.assertRaises(ValueError): module.read_safe(self.root, value)

    def test_canonical_admission_both_runtimes(self):
        self.domain()
        digest = lambda data: hashlib.sha256(data).hexdigest()
        record_hash = digest(b'1|spec|spec-reviewer-a|fixture-1|session-1|')
        ledger = {'schema': 'review-identity-ledger/v1', 'records': [dict(
            sequence=1, stage='spec', role='spec-reviewer-a', run_id='fixture-1',
            host_session_id='session-1', previous_record_sha256='', record_sha256=record_hash)]}
        ledger_path = 'reports/review-context/identity-ledger.json'
        self.put(ledger_path, json.dumps(ledger))
        manifest = dict(schema='review-context-invocation/v2', input_mode='file-manifest',
                        fallback_mode='none', read_only=True, stage='spec', role='spec-reviewer-a',
                        feature='example', run_id='fixture-2', host_session_id='session-2', sequence=2,
                        identity_ledger_path=ledger_path,
                        identity_ledger_sha256=digest((self.root / ledger_path).read_bytes()),
                        previous_record_sha256=record_hash,
                        allowed_input_manifest=self.resolve('spec')['inputs'])
        script = ROOT / 'plugins/sdd-quality-loop/scripts/validate-review-context-set'
        commands = [['bash', str(script) + '.sh', str(self.root / 'manifest.json'), str(self.root)]]
        if shutil.which('pwsh'):
            commands.append(['pwsh', '-NoProfile', '-File', str(script) + '.ps1',
                             '-Manifest', str(self.root / 'manifest.json'), '-RepositoryRoot', str(self.root)])
        else:
            self.fail('PowerShell required to verify runtime parity')
        before = (self.root / ledger_path).read_bytes()
        for command in commands:
            for case in ('valid', 'wrong-hash', 'unrelated', 'omit-one', 'omit-all'):
                trial = json.loads(json.dumps(manifest))
                if case == 'wrong-hash': trial['allowed_input_manifest'][0]['sha256'] = '0' * 64
                if case == 'unrelated':
                    self.put('domain/unrelated.md', 'not a role input')
                    trial['allowed_input_manifest'].append(dict(path='domain/unrelated.md', sha256=digest(b'not a role input')))
                if case == 'omit-one': trial['allowed_input_manifest'].pop()
                if case == 'omit-all':
                    trial['allowed_input_manifest'] = [dict(
                        path='specs/example/requirements.md',
                        sha256=digest((self.root / 'specs/example/requirements.md').read_bytes()))]
                self.put('manifest.json', json.dumps(trial))
                modes = (False,) if case == 'valid' else (False, True)
                for reserve in modes:
                    self.put(ledger_path, json.dumps(ledger))
                    invocation = command + (['--reserve'] if command[0] == 'bash' else ['-Reserve']) if reserve else command
                    result = subprocess.run(invocation, text=True, capture_output=True, timeout=30)
                    with self.subTest(runtime=command[0], case=case, reserve=reserve):
                        self.assertEqual(result.returncode == 0, case == 'valid', result.stdout + result.stderr)
                        self.assertEqual((self.root / ledger_path).read_bytes(), before)

    def test_persisted_reservation_keeps_historical_conditional_selection(self):
        digest = lambda data: hashlib.sha256(data).hexdigest()
        record_hash = digest(b'1|spec|spec-reviewer-a|fixture-1|session-1|')
        ledger_path = 'reports/review-context/identity-ledger.json'
        initial = {'schema': 'review-identity-ledger/v1', 'records': [dict(
            sequence=1, stage='spec', role='spec-reviewer-a', run_id='fixture-1',
            host_session_id='session-1', previous_record_sha256='', record_sha256=record_hash)]}
        script = ROOT / 'plugins/sdd-quality-loop/scripts/validate-review-context-set'
        commands = [['bash', str(script) + '.sh', str(self.root / 'manifest.json'), str(self.root)],
                    ['pwsh', '-NoProfile', '-File', str(script) + '.ps1',
                     '-Manifest', str(self.root / 'manifest.json'), '-RepositoryRoot', str(self.root)]]
        self.assertIsNotNone(shutil.which('pwsh'), 'PowerShell required to verify runtime parity')
        for command in commands:
            with self.subTest(runtime=command[0]):
                self.put(ledger_path, json.dumps(initial))
                (self.root / 'domain/context-map.md').unlink(missing_ok=True)
                (self.root / 'domain/domain-contract.json').unlink(missing_ok=True)
                manifest = dict(schema='review-context-invocation/v2', input_mode='file-manifest',
                                fallback_mode='none', read_only=True, stage='spec', role='spec-reviewer-a',
                                feature='example', run_id='fixture-2', host_session_id='session-2', sequence=2,
                                identity_ledger_path=ledger_path,
                                identity_ledger_sha256=digest((self.root / ledger_path).read_bytes()),
                                previous_record_sha256=record_hash,
                                allowed_input_manifest=[dict(
                                    path='specs/example/requirements.md',
                                    sha256=digest((self.root / 'specs/example/requirements.md').read_bytes()))])
                self.put('manifest.json', json.dumps(manifest))
                reserve = command + (['--reserve'] if command[0] == 'bash' else ['-Reserve'])
                result = subprocess.run(reserve, text=True, capture_output=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                persisted = (self.root / ledger_path).read_bytes()
                self.domain()
                result = subprocess.run(command, text=True, capture_output=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual((self.root / ledger_path).read_bytes(), persisted)
                result = subprocess.run(reserve, text=True, capture_output=True, timeout=30)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual((self.root / ledger_path).read_bytes(), persisted)
                changed = json.loads(json.dumps(manifest))
                changed['allowed_input_manifest'][0]['sha256'] = '0' * 64
                self.put('manifest.json', json.dumps(changed))
                result = subprocess.run(command, text=True, capture_output=True, timeout=30)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual((self.root / ledger_path).read_bytes(), persisted)
                self.put('manifest.json', json.dumps(manifest))
                self.put('specs/example/requirements.md', 'Bounded-Context: changed\n')
                result = subprocess.run(command, text=True, capture_output=True, timeout=30)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual((self.root / ledger_path).read_bytes(), persisted)
                self.put('specs/example/requirements.md', 'Bounded-Context: sales\n')

    def test_impl_design_system_completeness_both_runtimes(self):
        for path in ('design-tokens.json', 'design-system.md', 'ui-patterns.md'):
            self.put('design-system/' + path, '{}')
        doc = self.domain()
        card = 'domain/aggregates/Order.md'
        doc['contexts'][0]['aggregates'] = [dict(name='Order', root_entity='Order',
            invariants=['valid'], transaction_boundary='order', card=card)]
        self.put('domain/domain-contract.json', json.dumps(doc))
        self.put(card, 'Order aggregate')
        digest = lambda data: hashlib.sha256(data).hexdigest()
        record_hash = digest(b'1|impl|impl-reviewer-a|fixture-1|session-1|')
        ledger_path = 'reports/review-context/identity-ledger.json'
        ledger = {'schema': 'review-identity-ledger/v1', 'records': [dict(
            sequence=1, stage='impl', role='impl-reviewer-a', run_id='fixture-1',
            host_session_id='session-1', previous_record_sha256='', record_sha256=record_hash)]}
        self.put(ledger_path, json.dumps(ledger))
        design = dict(path='specs/example/design.md',
                      sha256=digest((self.root / 'specs/example/design.md').read_bytes()))
        selected = self.resolve('impl')['inputs']
        self.assertEqual(len(selected), 6)
        manifest = dict(schema='review-context-invocation/v2', input_mode='file-manifest',
                        fallback_mode='none', read_only=True, stage='impl', role='impl-reviewer-a',
                        feature='example', run_id='fixture-2', host_session_id='session-2', sequence=2,
                        identity_ledger_path=ledger_path,
                        identity_ledger_sha256=digest((self.root / ledger_path).read_bytes()),
                        previous_record_sha256=record_hash, allowed_input_manifest=[design] + selected)
        script = ROOT / 'plugins/sdd-quality-loop/scripts/validate-review-context-set'
        commands = [['bash', str(script) + '.sh', str(self.root / 'manifest.json'), str(self.root)],
                    ['pwsh', '-NoProfile', '-File', str(script) + '.ps1',
                     '-Manifest', str(self.root / 'manifest.json'), '-RepositoryRoot', str(self.root)]]
        self.assertIsNotNone(shutil.which('pwsh'), 'PowerShell required to verify runtime parity')
        before = (self.root / ledger_path).read_bytes()
        for command in commands:
            for case, entries in (('valid', [design] + selected),
                                  ('omit-one', [design] + selected[:-1]),
                                  ('omit-aggregate', [design] + [x for x in selected if x['path'] != card]),
                                  ('wrong-aggregate-hash', [design] + [dict(x, sha256='0' * 64) if x['path'] == card else x for x in selected]),
                                  ('omit-all', [design])):
                trial = dict(manifest, allowed_input_manifest=entries)
                self.put('manifest.json', json.dumps(trial))
                for reserve in ((False,) if case == 'valid' else (False, True)):
                    self.put(ledger_path, json.dumps(ledger))
                    invocation = command + (['--reserve'] if command[0] == 'bash' else ['-Reserve']) if reserve else command
                    result = subprocess.run(invocation, text=True, capture_output=True, timeout=30)
                    with self.subTest(runtime=command[0], case=case, reserve=reserve):
                        self.assertEqual(result.returncode == 0, case == 'valid', result.stdout + result.stderr)
                        self.assertEqual((self.root / ledger_path).read_bytes(), before)

    def test_historical_conditional_paths_need_exact_name_and_input_binding(self):
        self.domain()
        self.put('domain/unrelated.md', 'unrelated')
        digest = lambda data: hashlib.sha256(data).hexdigest()
        first_hash = digest(b'1|spec|spec-reviewer-a|fixture-1|session-1|')
        ledger_path = 'reports/review-context/identity-ledger.json'
        first = dict(sequence=1, stage='spec', role='spec-reviewer-a', run_id='fixture-1',
                     host_session_id='session-1', previous_record_sha256='', record_sha256=first_hash)
        script = ROOT / 'plugins/sdd-quality-loop/scripts/validate-review-context-set'
        commands = [['bash', str(script) + '.sh', str(self.root / 'manifest.json'), str(self.root)],
                    ['pwsh', '-NoProfile', '-File', str(script) + '.ps1',
                     '-Manifest', str(self.root / 'manifest.json'), '-RepositoryRoot', str(self.root)]]
        self.assertIsNotNone(shutil.which('pwsh'), 'PowerShell required to verify runtime parity')
        for bound, path, accepted in ((False, 'specs/example/requirements.md', True),
                                      (False, 'domain/context-map.md', False),
                                      (False, 'domain/unrelated.md', False),
                                      (True, 'domain/context-map.md', True),
                                      (True, 'domain/unrelated.md', False),
                                      (True, 'design-system/design-system.md', False)):
            if path.startswith('design-system/'):
                self.put(path, 'unrelated')
            entry = dict(path=path, sha256=digest((self.root / path).read_bytes()))
            record = dict(sequence=2, stage='spec', role='spec-reviewer-a', run_id='fixture-2',
                          host_session_id='session-2', previous_record_sha256=first_hash)
            record_text = '2|spec|spec-reviewer-a|fixture-2|session-2|' + first_hash
            if bound:
                binding = digest((path + '\t' + entry['sha256']).encode())
                record['allowed_inputs_sha256'] = binding
                record_text += '|allowed-inputs-v1|' + binding
            record['record_sha256'] = digest(record_text.encode())
            ledger = {'schema': 'review-identity-ledger/v1', 'records': [first, record]}
            self.put(ledger_path, json.dumps(ledger))
            before = (self.root / ledger_path).read_bytes()
            manifest = dict(schema='review-context-invocation/v2', input_mode='file-manifest',
                            fallback_mode='none', read_only=True, stage='spec', role='spec-reviewer-a',
                            feature='example', run_id='fixture-2', host_session_id='session-2', sequence=2,
                            identity_ledger_path=ledger_path,
                            identity_ledger_sha256=digest(before),
                            previous_record_sha256=first_hash, allowed_input_manifest=[entry])
            self.put('manifest.json', json.dumps(manifest))
            for command in commands:
                result = subprocess.run(command, text=True, capture_output=True, timeout=30)
                with self.subTest(runtime=command[0], bound=bound, path=path):
                    self.assertEqual(result.returncode == 0, accepted, result.stdout + result.stderr)
                    self.assertEqual((self.root / ledger_path).read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
