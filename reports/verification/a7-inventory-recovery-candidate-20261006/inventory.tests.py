#!/usr/bin/env python3
"""Disposable recovery-contract regressions; no owner evidence or ledger writes."""
import copy
import hashlib
import json
import pathlib
import runpy
import shutil
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]
FEATURE = 'epic-195-a7-compatibility'
HELPER = 'plugins/sdd-review-loop/scripts/fresh-review-recovery.py'
CONTRACT = 'reports/verification/a7-attempt20-formal-20261006/fresh-review-contract-attempt20.json'
CANDIDATE = pathlib.Path(__file__).with_name('fresh-review-recovery.candidate.py')


def sha(data):
    return hashlib.sha256(data).hexdigest()


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='a7-transport-tests-')
        self.addCleanup(self.tmp.cleanup)
        self.root = pathlib.Path(self.tmp.name).resolve()
        self.data = json.loads((ROOT / CONTRACT).read_text())
        paths = [item['path'] for item in self.data['evidence']]
        paths += [HELPER, 'plugins/sdd-review-loop/scripts/failed-last-attempt.py',
                  'plugins/sdd-review-loop/references/spec-review-calibration.md',
                  'reports/review-context/identity-ledger.json']
        paths += [f'specs/{FEATURE}/{name}.md' for name in
                  ('requirements', 'acceptance-tests', 'investigation')]
        for rel in paths:
            target = self.root / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / rel, target)
        self.data.pop('interrupted_evidence_inventory')
        self.data['interrupted_transport_inventories'] = [
            {'attempt': attempt, 'files': sorted(
                [copy.deepcopy(item) for item in self.data['evidence']
                 if item['path'].startswith(f'reports/spec-review/{FEATURE}/attempt-{attempt}/round-1/')],
                key=lambda item: item['path'])} for attempt in (18, 19)]
        self.audit = self.root / self.data['authority']['path']
        approval = json.loads(self.audit.read_text())
        approval['transport_inventories_sha256'] = sha(json.dumps(
            self.data['interrupted_transport_inventories'], sort_keys=True,
            separators=(',', ':'), ensure_ascii=False).encode())
        self.audit.write_text(json.dumps(approval, indent=2) + '\n')
        for item in self.data['evidence']:
            if item['path'] == self.data['authority']['path']:
                item['sha256'] = sha(self.audit.read_bytes())
        self.contract = self.root / CONTRACT
        self.validate = runpy.run_path(str(CANDIDATE))['validate']

    def run_contract(self, expected=None, validator=None):
        self.contract.write_text(json.dumps(self.data, indent=2) + '\n')
        execute = validator or self.validate
        if expected is None:
            result = execute(self.root, FEATURE, 20, self.contract)
            self.assertEqual(result['terminal_attempt'], 7)
            return
        with self.assertRaisesRegex(ValueError, expected):
            execute(self.root, FEATURE, 20, self.contract)

    def test_normal(self):
        self.run_contract()

    def test_original_rejects_new_contract(self):
        self.run_contract('unexpected fresh-review contract keys', runpy.run_path(str(ROOT / HELPER))['validate'])

    def test_legacy_single_inventory_compatible(self):
        legacy = 'reports/verification/a7-attempt19-formal-20261005/fresh-review-contract-attempt19.json'
        data = json.loads((ROOT / legacy).read_text())
        with tempfile.TemporaryDirectory(prefix='a7-legacy-tests-') as tmp:
            root = pathlib.Path(tmp).resolve()
            for item in data['evidence']:
                target = root / item['path']
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / item['path'], target)
            for rel in [HELPER, 'plugins/sdd-review-loop/scripts/failed-last-attempt.py',
                        'plugins/sdd-review-loop/references/spec-review-calibration.md',
                        'reports/review-context/identity-ledger.json'] + [
                        f'specs/{FEATURE}/{name}.md' for name in ('requirements', 'acceptance-tests', 'investigation')]:
                target = root / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / rel, target)
            target = root / legacy
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(json.dumps(data))
            self.assertEqual(self.validate(root, FEATURE, 19, target)['terminal_attempt'], 7)

    def test_missing(self):
        self.data['interrupted_transport_inventories'][1]['files'].pop()
        self.run_contract('transport inventory names mismatch')

    def test_mutated(self):
        item = self.data['interrupted_transport_inventories'][1]['files'][0]
        target = self.root / item['path']
        target.write_bytes(target.read_bytes() + b'changed\n')
        self.run_contract('hash mismatch')

    def test_repinned_inventory_without_approval(self):
        item = self.data['interrupted_transport_inventories'][1]['files'][0]
        target = self.root / item['path']
        target.write_bytes(target.read_bytes() + b'changed\n')
        item['sha256'] = sha(target.read_bytes())
        for evidence in self.data['evidence']:
            if evidence['path'] == item['path']:
                evidence['sha256'] = item['sha256']
        self.run_contract('transport inventory approval binding mismatch')

    def test_wrong_attempt(self):
        self.data['interrupted_transport_inventories'][1]['attempt'] = 20
        self.run_contract('invalid transport inventory entry')

    def test_unknown_extra(self):
        folder = self.root / f'reports/spec-review/{FEATURE}/attempt-19/round-1'
        (folder / 'unknown.txt').write_text('unknown')
        self.run_contract('transport inventory names mismatch')

    def test_duplicate(self):
        items = self.data['interrupted_transport_inventories'][1]['files']
        items.append(copy.deepcopy(items[0]))
        self.run_contract('transport inventory names mismatch')

    def test_wrong_type(self):
        self.data['interrupted_transport_inventories'][1]['attempt'] = True
        self.run_contract('invalid transport inventory entry')

    def test_escape(self):
        self.data['interrupted_transport_inventories'][1]['files'][0]['path'] = '../outside'
        self.run_contract('transport inventory names mismatch')

    def test_undeclared(self):
        self.data['interrupted_transport_inventories'].pop()
        self.run_contract('interrupted evidence inventory mismatch')

    def test_null(self):
        self.data['interrupted_transport_inventories'] = None
        self.run_contract('invalid transport inventories')


if __name__ == '__main__':
    unittest.main(verbosity=2)
