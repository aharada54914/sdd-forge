import itertools
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / 'junit_summary.py'


class SummaryCLI(unittest.TestCase):
    def test_single_pass_exact_json(self):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / 'report.xml'
            report.write_bytes(b'<testsuite><testcase name="works"/></testsuite>')
            result = subprocess.run([sys.executable, str(SCRIPT), str(report)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout,
                             '{"tests":1,"passed":1,"failures":0,"errors":0,"skipped":0}\n')
            self.assertEqual(result.stderr, '')


class ContractCLI(unittest.TestCase):
    def test_report_matrix(self):
        cases = [
            (b'<testsuite/>', [0, 0, 0, 0, 0]),
            (b'<testsuites/>', [0, 0, 0, 0, 0]),
            (b'<testsuite><testcase><skipped/></testcase></testsuite>', [1, 0, 0, 0, 1]),
            (b'<testsuites tests="999"><testsuite failures="777"><testcase/>'
             b'<testsuite><testcase><failure/></testcase></testsuite></testsuite>'
             b'<testcase><error/></testcase><testcase><skipped/></testcase></testsuites>',
             [4, 1, 1, 1, 1]),
            (b'<testsuite><unknown/><testcase><unknown><error/></unknown></testcase></testsuite>',
             [1, 1, 0, 0, 0]),
            ('<?xml version="1.0" encoding="iso-8859-1"?><testsuite><testcase name="café"/></testsuite>'.encode('iso-8859-1'),
             [1, 1, 0, 0, 0]),
        ]
        for size in range(4):
            for outcomes in itertools.permutations(('error', 'failure', 'skipped'), size):
                children = ''.join(f'<{tag}/><{tag}/>' for tag in outcomes)
                category = ('errors' if 'error' in outcomes else 'failures' if 'failure' in outcomes
                            else 'skipped' if 'skipped' in outcomes else 'passed')
                counts = [1] + [int(category == key) for key in ('passed', 'failures', 'errors', 'skipped')]
                cases.append((f'<testsuite><testcase>{children}</testcase></testsuite>'.encode(), counts))
        for prefix, declaration in (('', 'xmlns="urn:junit"'), ('j:', 'xmlns:j="urn:junit"')):
            document = (f'<{prefix}testsuites {declaration}><{prefix}testsuite>'
                        f'<{prefix}testcase><{prefix}error/><{prefix}failure/></{prefix}testcase>'
                        f'<{prefix}testcase><{prefix}skipped/></{prefix}testcase>'
                        f'</{prefix}testsuite></{prefix}testsuites>').encode()
            cases.append((document, [2, 0, 0, 1, 1]))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'report.xml'
            other = Path(directory) / 'other.xml'
            other.write_bytes(b'<testsuite><testcase/></testsuite>')
            for document, counts in cases:
                path.write_bytes(document)
                # Verify single input, distinct multiple inputs, and duplicate paths.
                for paths, expected in (([path], counts), ([path, other], [counts[0]+1, counts[1]+1, *counts[2:]]),
                                        ([path, path], [value*2 for value in counts])):
                    with self.subTest(document=document, paths=paths):
                        result = self.run_cli(paths)
                        self.assertEqual(result.returncode, int(bool(expected[2] or expected[3])), result.stderr)
                        self.assertEqual(result.stderr, '')
                        data = json.loads(result.stdout)
                        self.assertEqual(list(data), ['tests', 'passed', 'failures', 'errors', 'skipped'])
                        self.assertEqual(list(data.values()), expected)
                        self.assertTrue(all(type(v) is int and v >= 0 for v in data.values()))
                        self.assertEqual(expected[0], sum(expected[1:]))
                        self.assertEqual(path.read_bytes(), document)
                        self.assertEqual(other.read_bytes(), b'<testsuite><testcase/></testsuite>')

    def run_cli(self, paths):
        return subprocess.run([sys.executable, str(SCRIPT), *map(str, paths)], capture_output=True, text=True)

    def assert_invalid(self, paths, offending=None):
        result = self.run_cli(paths)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, '')
        self.assertTrue(result.stderr.strip())
        self.assertNotIn('Traceback', result.stderr)
        if offending:
            self.assertIn(str(offending), result.stderr)
            self.assertEqual(len(result.stderr.splitlines()), 1)

    def test_invalid_inputs(self):
        documents = [b'<testsuite>', b'<report/>', b'not xml',
                     b'<?xml version="1.0" encoding="unknown-junit-codec"?><testsuite/>',
                     b'<testsuite>\xff</testsuite>']
        with tempfile.TemporaryDirectory() as directory:
            good = Path(directory) / 'good.xml'
            good_bytes = b'<testsuite><testcase><failure/></testcase></testsuite>'
            good.write_bytes(good_bytes)
            bad = Path(directory) / 'bad.xml'
            for document in documents:
                bad.write_bytes(document)
                for paths in ([bad], [good, bad]):
                    with self.subTest(document=document, paths=paths):
                        self.assert_invalid(paths, bad)
                        self.assertEqual(bad.read_bytes(), document)
                        self.assertEqual(good.read_bytes(), good_bytes)
            for path in (Path(directory), Path(directory) / 'missing.xml'):
                self.assert_invalid([good, path], path)

    def test_no_arguments_and_help(self):
        self.assert_invalid([])
        result = self.run_cli(['--help'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('usage:', result.stdout)
        self.assertEqual(result.stderr, '')


if __name__ == '__main__':
    unittest.main()
