"""No reservations, role launches, production writes or verdict adoption."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
spec = importlib.util.spec_from_file_location('candidate', HERE / 'receipt_prompt.candidate.py')
candidate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(candidate)
DATA = json.loads((ROOT / 'reports/review-context/epic-195-a7-compatibility-spec-a19r1-a-invocation.json').read_bytes())
RECEIPT = (ROOT / 'reports/spec-review/epic-195-a7-compatibility/attempt-19/round-1/reviewer-a-reservation-receipt.txt').read_text()


class ReceiptTests(unittest.TestCase):
    def test_existing_receipt_and_literal_commands(self):
        control = candidate.receipt_control(DATA, RECEIPT)
        self.assertEqual(control['record_sha256'], '0599e72ba9a2382aad1b7540bfbc7f45b3424abaefc010fb686933e4d9964a95')
        for command, expected in zip(control['hash_commands'],
                                     [control['inputs_sha256'], control['record_sha256']]):
            result = subprocess.run(['rtk', 'proxy', 'bash', '-c', command], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.split()[0], expected)

    def test_changed_receipt_hash_rejected(self):
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            candidate.receipt_control(DATA, RECEIPT.replace('0599e72b', '1599e72b'))

    def test_changed_inputs_rejected(self):
        for mutation in ['hash', 'order', 'path']:
            data = copy.deepcopy(DATA)
            if mutation == 'hash':
                data['allowed_input_manifest'][0]['sha256'] = '0' * 64
            elif mutation == 'order':
                data['allowed_input_manifest'].reverse()
            else:
                data['allowed_input_manifest'][0]['path'] += '.other'
            with self.subTest(mutation=mutation), self.assertRaisesRegex(ValueError, 'hash mismatch'):
                candidate.receipt_control(data, RECEIPT)

    def test_changed_identity_rejected(self):
        data = copy.deepcopy(DATA)
        data['run_id'] = '7a457566-4156-4f0e-b1a2-62bb0c1e6f03'
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            candidate.receipt_control(data, RECEIPT)

    def test_chain_fields_rejected(self):
        for old, new in [('sequence=1206', 'sequence=1207'),
                         ('pre_append_tip_sequence=1205', 'pre_append_tip_sequence=1204'),
                         ('identity_unique=yes', 'identity_unique=no')]:
            with self.subTest(old=old), self.assertRaises(ValueError):
                candidate.receipt_control(DATA, RECEIPT.replace(old, new))

    def test_duplicate_and_control_character_paths_rejected(self):
        for mutation in ['duplicate', 'newline']:
            data = copy.deepcopy(DATA)
            if mutation == 'duplicate':
                data['allowed_input_manifest'].append(data['allowed_input_manifest'][0])
            else:
                data['allowed_input_manifest'][0]['path'] += '\nother'
            with self.subTest(mutation=mutation), self.assertRaisesRegex(ValueError, 'invalid ordered'):
                candidate.receipt_control(data, RECEIPT)

    def test_terminal_newline_changes_hash(self):
        control = candidate.receipt_control(DATA, RECEIPT)
        self.assertNotEqual(hashlib.sha256((control['record_text'] + '\n').encode()).hexdigest(), control['record_sha256'])

    def test_control_prompt_explicit_and_stable(self):
        text = candidate.control_prompt(DATA, RECEIPT, 'a' * 64)
        self.assertIn('Caller-provided digests alone are not reviewer proof', text)
        self.assertIn('Never inspect the ledger or reserve again', text)
        self.assertEqual(text, candidate.control_prompt(DATA, RECEIPT, 'a' * 64))


if __name__ == '__main__':
    unittest.main(verbosity=2)
