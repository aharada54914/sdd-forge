"""Candidate contract experiment, not production validation or native proof."""
import copy
from contextlib import redirect_stdout
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

F = load('fixture', ROOT / 'tests/fixtures/live-host-proof/run_cases.py')
B = load('batch', Path(__file__).with_name('a8-ac016-amendment-batch-20261006.py'))
V = F.load_validator_module()
PATHS = dict(zip(('sdd-bootstrap', 'sdd-bootstrap-interviewer', 'lite-gate',
                  'lite-spec', 'sdd-ship'), F.T008_CONSUMER_PATHS))

def pinned_preimages():
    changes = []
    for rel, expected in B.BASE.items():
        current = (ROOT / rel).read_bytes()
        appendix = (B.COMMON + B.DETAIL[Path(rel).name]).encode()
        if not current.endswith(appendix):
            raise AssertionError(f'amendment missing or changed: {rel}')
        before = current[:-len(appendix)]
        if rel.endswith('/requirements.md'):
            before = before.replace(b'Spec-Review-Status: Pending\n',
                                    b'Spec-Review-Status: Passed\n', 1)
        if hashlib.sha256(before).hexdigest() != expected:
            raise AssertionError(f'pinned preimage mismatch: {rel}')
        changes.append((rel, before, before + appendix))
    return changes

def check(record, blobs):
    inventory = record.get('consumer_inventory')
    if record['verdict'] == 'SKIP':
        if 'consumer_inventory' not in record or inventory is not None:
            raise ValueError('SKIP inventory')
        return
    if not isinstance(inventory, list) or len(inventory) != 5:
        raise ValueError('inventory count/type')
    names = []
    for item in inventory:
        if not isinstance(item, dict) or set(item) != {'entry_point', 'source_commit', 'source_path'}:
            raise ValueError('entry keys')
        if any(not isinstance(v, str) or not v for v in item.values()):
            raise ValueError('entry types')
        name, commit, path = item['entry_point'], item['source_commit'], item['source_path']
        if PATHS.get(name) != path or commit != F.T008_A1_COMMIT:
            raise ValueError('source identity')
        if blobs.get(path) != F.T008_CONSUMER_PATHS.get(path):
            raise ValueError('source object')
        names.append(name)
    if set(names) != set(PATHS):
        raise ValueError('consumer membership')

class ContractExperiment(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='a8-minimal-inventory-')
        self.addCleanup(self.tmp.cleanup)
        self.fixture = F.Fixture(self.tmp.name)

    def record(self, cell):
        record = self.fixture.load_record(cell)
        record['schema'] = 'live-host-verification-record/v2'
        record['consumer_inventory'] = [dict(entry_point=name, source_commit=F.T008_A1_COMMIT,
                                             source_path=path) for name, path in PATHS.items()]
        F.sign_record(record)
        return record

    def test_original_red(self):
        result = F.invoke(self.fixture)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('discharged', result.stdout)
        self.assertNotIn('consumer_inventory', self.fixture.load_record())
        print('RED: original discharges without consumer inventory')

    def test_actual_source_objects(self):
        for path, blob in F.T008_CONSUMER_PATHS.items():
            self.assertEqual(F.git_blob_at_commit(F.T008_A1_COMMIT, path), blob)

    def test_five_cells_and_existing_signatures(self):
        registry = json.loads(self.fixture.registry.read_text())
        for cell in F.CELLS:
            record = self.record(cell)
            check(record, F.T008_CONSUMER_PATHS)
            V.validate_signatures(record, registry, cell)
            record['consumer_inventory'].reverse()
            check(record, F.T008_CONSUMER_PATHS)
            with self.assertRaises(V.ValidationError):
                V.validate_signatures(record, registry, cell)
            F.sign_record(record)
            V.validate_signatures(record, registry, cell)

    def test_negative_matrix_each_cell(self):
        count = 0
        for cell in F.CELLS:
            original = self.record(cell)
            mutations = []
            for index in range(5):
                record = copy.deepcopy(original)
                record['consumer_inventory'].pop(index)
                mutations.append(record)
            for value in (None, {}, '', []):
                record = copy.deepcopy(original)
                record['consumer_inventory'] = value
                mutations.append(record)
            for key, value in (('entry_point', 'unknown'), ('source_commit', '0'*40),
                               ('source_path', 'missing'), ('source_commit', 7), ('extra', True)):
                record = copy.deepcopy(original)
                record['consumer_inventory'][0][key] = value
                mutations.append(record)
            record = copy.deepcopy(original)
            del record['consumer_inventory']
            mutations.append(record)
            record = copy.deepcopy(original)
            record['consumer_inventory'][-1] = copy.deepcopy(record['consumer_inventory'][0])
            mutations.append(record)
            for record in mutations:
                with self.assertRaises(ValueError):
                    check(record, F.T008_CONSUMER_PATHS)
                count += 1
            for blobs in ({}, dict.fromkeys(F.T008_CONSUMER_PATHS, '0'*40)):
                with self.assertRaises(ValueError):
                    check(original, blobs)
                count += 1
        print(f'Candidate negative cases rejected: {count}')

    def test_skip_inventory_only(self):
        record = self.record(next(iter(F.CELLS)))
        record['verdict'] = 'SKIP'
        with self.assertRaises(ValueError):
            check(record, F.T008_CONSUMER_PATHS)
        record['consumer_inventory'] = None
        check(record, F.T008_CONSUMER_PATHS)

    def test_pinned_append_only_documents(self):
        changes = pinned_preimages()
        self.assertEqual(len(changes), 10)
        for rel, before, after in changes:
            self.assertTrue(after.startswith(before), rel)
            self.assertIn(b'live-host-verification-record/v2', after[len(before):])
            current = (ROOT / rel).read_bytes()
            self.assertEqual(current, after if not rel.endswith('/requirements.md')
                             else after.replace(b'Spec-Review-Status: Passed\n',
                                                b'Spec-Review-Status: Pending\n', 1))

    def test_batch_stops_with_verified_backup_and_partial_warning(self):
        changes = pinned_preimages()
        with tempfile.TemporaryDirectory(prefix='a8-ac016-apply-fixture-') as directory, \
             tempfile.TemporaryDirectory(prefix='a8-ac016-backup-fixture-') as backup_directory:
            root = Path(directory)
            for rel, before, _ in changes:
                target = root / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(before)
            second = root / changes[1][0]
            write_bytes = Path.write_bytes
            def fail_second(path, data):
                if path == second:
                    raise OSError('injected second-target refusal')
                return write_bytes(path, data)
            output = io.StringIO()
            with patch.object(B.tempfile, 'mkdtemp', return_value=backup_directory), \
                 patch.object(Path, 'write_bytes', fail_second), redirect_stdout(output):
                with self.assertRaisesRegex(OSError, 'injected second-target refusal'):
                    B.apply_changes(changes, root)
            backup = Path(output.getvalue().split('BACKUP: ', 1)[1].splitlines()[0])
            self.assertEqual(backup, Path(backup_directory))
            self.assertIn('application may be partial', output.getvalue())
            self.assertEqual((root / changes[0][0]).read_bytes(), changes[0][2])
            for rel, before, _ in changes[1:]:
                self.assertEqual((root / rel).read_bytes(), before)
            for rel, before, _ in changes:
                self.assertEqual((backup / rel).read_bytes(), before)

if __name__ == '__main__':
    unittest.main(verbosity=2)
