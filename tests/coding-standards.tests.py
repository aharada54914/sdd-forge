#!/usr/bin/env python3
"""Native positive/negative controls and fail-closed census/adapter contracts."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('coding_standards', ROOT / 'tests/coding_standards.py')
C = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(C)


class StandardsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git('init', '-q')
        self.git('config', 'user.name', 'Fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        for name in ('tools.json', 'powershell.ps1', 'typescript.mjs'):
            self.write('tests/coding-standards/' + name,
                       (ROOT / 'tests/coding-standards' / name).read_text())
        config = json.loads((self.root / 'tests/coding-standards/tools.json').read_text())
        config['exceptions'] = []
        self.write('tests/coding-standards/tools.json', json.dumps(config))
        self.write('tests/shared-launch-python/pyproject.toml',
                   (ROOT / 'tests/shared-launch-python/pyproject.toml').read_text())
        self.write('README.md', 'Fixture\n')
        self.git('add', 'README.md')
        self.git('commit', '-qm', 'initial')

    def git(self, *args):
        return C.git(self.root, *args)

    def write(self, path, content):
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(content)

    def track(self, path, content):
        self.write(path, content)
        self.git('add', '--', path)

    def test_nul_safe_names_symlink_and_unknown_surfaces(self):
        self.track('scripts/space new\nline.py', 'print("ok")\n')
        self.track('guide.md', '```mystery\ninput\n```\n')
        (self.root / 'outside.py').symlink_to('/nonexistent-private-file')
        self.git('add', 'outside.py')
        rows = {r['path']: r for r in C.census(self.root)['entries']}
        self.assertIn('scripts/space new\nline.py', rows)
        self.assertEqual(rows['outside.py']['surfaces'], ['symlink'])
        self.assertEqual(rows['outside.py']['state'], 'needs-review')
        self.assertIn('embedded:unknown', rows['guide.md']['surfaces'])
        self.assertTrue(all(r['state'] in {'unreviewed', 'needs-review'} for r in rows.values()))

    def test_history_and_generated_are_distinct_and_neither_approved(self):
        self.track('reports/run/result.py', 'print(1)\n')
        self.track('plugins/p/scripts/generated/live.py', 'print(1)\n')
        rows = {r['path']: r for r in C.census(self.root)['entries']}
        self.assertEqual(rows['reports/run/result.py']['classification'], 'historical')
        self.assertEqual(rows['plugins/p/scripts/generated/live.py']['classification'], 'current-code')
        self.assertEqual(rows['reports/run/result.py']['state'], 'unreviewed')

    def test_empty_population_and_missing_worktree_fail(self):
        self.git('rm', '--cached', 'README.md')
        with self.assertRaisesRegex(ValueError, 'empty'):
            C.census(self.root)
        self.git('add', 'README.md')
        (self.root / 'README.md').unlink()
        with self.assertRaises(OSError):
            C.census(self.root)

    def test_missing_base_shallow_and_zero_targets_are_distinct(self):
        for base in (None, '0' * 40):
            with self.assertRaisesRegex(ValueError, 'base unavailable'):
                C.scan(self.root, 'diff', base, 'python')
        result = C.scan(self.root, 'all', None, 'python')
        self.assertEqual(result['selected_count'], 0)
        self.assertEqual(result['tools'][0]['status'], 'no-targets')
        self.assertEqual(result['manual_review'], 'unknown')
        clone = self.root / 'shallow'
        subprocess.run(['git', 'clone', '-q', '--depth=1', self.root.as_uri(), str(clone)], check=True)
        # The existing selector must report missing parents, never an empty diff.
        spec = importlib.util.spec_from_file_location('impact', ROOT / 'tests/verification-impact.py')
        impact = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(impact)
        self.assertEqual(impact.changed_paths(clone, 'HEAD^', 'HEAD')[1], 'diff-unavailable')

    def test_invalid_config_missing_tool_timeout_and_bad_output_fail(self):
        self.track('a.py', 'print(1)\n')
        for error in (FileNotFoundError(), subprocess.TimeoutExpired('ruff', 1)):
            with patch.object(C, 'invoke', side_effect=error), self.assertRaises(type(error)):
                C.scan(self.root, 'all', None, 'python')
        version = subprocess.CompletedProcess([], 0, 'ruff 0.13.3\n', '')
        broken = subprocess.CompletedProcess([], 0, 'not json', '')
        with patch.object(C, 'invoke', side_effect=[version, broken]), self.assertRaises(ValueError):
            C.scan(self.root, 'all', None, 'python')
        self.write('tests/coding-standards/tools.json', '{}')
        with self.assertRaises(ValueError):
            C.scan(self.root, 'all', None, 'python')

    def test_native_python_bad_and_good_strict_tolerant_controls(self):
        self.track('case space\nname.py', 'print(undefined_name)\n')
        bad = C.scan(self.root, 'all', None, 'python')
        self.assertTrue(any(r['native_rule'] == 'F821' for r in bad['findings']))
        self.track('case space\nname.py', '''def strict(value):
    return int(value)


def tolerant(value):
    try:
        return int(value)
    except ValueError:
        return None


# Source markers are data, not violations.
marker = "shell=True; any; Invoke-Expression"
''')
        self.git('commit', '-qm', 'control')
        good = C.scan(self.root, 'all', None, 'python')
        diff = C.scan(self.root, 'diff', 'HEAD^', 'python')
        self.assertEqual(good['findings'], [])
        self.assertEqual(diff['findings'], good['findings'])

    def test_native_shell_each_selected_rule_and_normal_quoting(self):
        self.track('case.sh', '#!/bin/bash\nf() { local x=$(pwd); echo $x; }\necho $(pwd)\n')
        bad = C.scan(self.root, 'all', None, 'bash')
        self.assertEqual({r['native_rule'] for r in bad['findings']}, {'SC2086', 'SC2046', 'SC2155'})
        self.track('case.sh', '#!/bin/bash\nf() { local x; x=$(pwd) || return; echo "$x"; }\nprintf "%s\\n" "$(pwd)"\n')
        self.assertEqual(C.scan(self.root, 'all', None, 'bash')['findings'], [])

    def test_native_powershell_bad_and_windows_path_normal(self):
        self.track('case.ps1', 'param([string]$Password)\n$home = "broken"\nInvoke-Expression $args[0]\n$value = 1 ` \nWrite-Output $value\n')
        rules = {r['native_rule'] for r in C.scan(self.root, 'all', None, 'powershell')['findings']}
        self.assertIn('PSAvoidAssignmentToAutomaticVariable', rules)
        self.assertIn('PSAvoidUsingInvokeExpression', rules)
        self.assertIn('PSAvoidUsingPlainTextForPassword', rules)
        self.assertIn('PSMisleadingBacktick', rules)
        self.track('case.ps1', "$Path = 'C:\\space folder\\file.txt'\nWrite-Output $Path\n")
        self.assertEqual(C.scan(self.root, 'all', None, 'powershell')['findings'], [])

    def test_native_typescript_real_ast_ignores_string_and_property_any(self):
        node_modules = self.root / 'mcp/sdd-forge-mcp/node_modules'
        node_modules.parent.mkdir(parents=True)
        node_modules.symlink_to(ROOT / 'mcp/sdd-forge-mcp/node_modules', target_is_directory=True)
        self.track('case.ts', 'const data: any = {};\n')
        self.assertTrue(any(r['native_rule'] == 'explicit-any' for r in C.scan(
            self.root, 'all', None, 'typescript')['findings']))
        self.track('case.ts', 'const data: unknown = {}; const normal = { any: "any" };\n')
        self.assertEqual(C.scan(self.root, 'all', None, 'typescript')['findings'], [])


if __name__ == '__main__':
    unittest.main()
