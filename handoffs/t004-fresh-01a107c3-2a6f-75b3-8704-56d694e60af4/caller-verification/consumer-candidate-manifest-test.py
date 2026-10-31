"""Exercise candidate manifest functions only against disposable inert paths."""
import pathlib
import runpy
import subprocess
import tempfile
import unittest

CANDIDATE = pathlib.Path('/private/tmp/sdd-guard-main.3JEj4I/repo/reports/verification/spec-boundary-consumers-human-apply.py')


class CandidateManifestTest(unittest.TestCase):
    def test_candidate_preserves_all_manifest_members(self):
        candidate = runpy.run_path(str(CANDIDATE))
        rel = 'tests/lib/loop-driver.sh'
        source = candidate['transform'](rel, (candidate['ROOT'] / rel).read_text())
        functions = source[source.index('_loop_spec_manifest_a() {'):source.index('_loop_drive_spec_round() {')]
        for role in ('a', 'b'):
            for investigation in (False, True):
                with self.subTest(role=role, investigation=investigation), tempfile.TemporaryDirectory() as directory:
                    root = pathlib.Path(directory)
                    if investigation:
                        fixture = root / 'specs/synthetic/investigation.md'
                        fixture.parent.mkdir(parents=True)
                        fixture.write_text('inert test fixture\n')
                    program = '_loop_manifest_array() { printf "%s\\n" "$@"; }\n' + functions
                    program += '\nLOOP_FIXTURE_ROOT="$1"; LOOP_FIXTURE_FEATURE=synthetic\n_loop_spec_manifest_' + role + ' "$1/reports/synthetic"\n'
                    result = subprocess.run(['bash', '-s', '--', str(root)], input=program, text=True, capture_output=True, check=True)
                    expected = ['specs/synthetic/requirements.md', 'specs/synthetic/acceptance-tests.md']
                    if investigation:
                        expected.append('specs/synthetic/investigation.md')
                    expected += [candidate['C'], candidate['B'], 'reports/synthetic/precheck-result.json']
                    if role == 'b':
                        expected.append('reports/synthetic/integrated-summary.json')
                    self.assertEqual(result.stdout.splitlines(), expected)


if __name__ == '__main__':
    unittest.main()
