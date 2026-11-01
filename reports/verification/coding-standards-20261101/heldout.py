#!/usr/bin/env python3
"""One-shot held-out native controls, fixed after checker 86fc4955; not a product gate."""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tests'))
SPEC = importlib.util.spec_from_file_location('native', ROOT / 'tests/coding_standards.py')
NATIVE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(NATIVE)

# Frozen before collecting outputs. No checker or rule changes follow this evaluation.
CASES = [
    ('python', 'bad.py', 'def double(value):\n    return value + absent_operand\n', {'F821'}),
    ('python', 'good.py', 'def double(value):\n    return value + value\n', set()),
    ('bash', 'bad.sh', '#!/bin/bash\ninput="$1"\nprintf "%s\\n" $input\n', {'SC2086'}),
    ('bash', 'good.sh', '#!/bin/bash\ninput="$1"\nprintf "%s\\n" "$input"\n', set()),
    ('powershell', 'bad.ps1', '$PID = 123\nWrite-Output $PID\n', {'PSAvoidAssignmentToAutomaticVariable'}),
    ('powershell', 'good.ps1', '$ChildProcessId = 123\nWrite-Output $ChildProcessId\n', set()),
    ('typescript', 'bad.mts', 'export function parse(input: any) { return input; }\n', {'explicit-any'}),
    ('typescript', 'good.mts', 'export function parse(input: unknown) { return input; }\n', set()),
    ('javascript', 'good.cjs', 'module.exports = {any: "any", value: 1};\n', set()),
]


def main():
    results = []
    with tempfile.TemporaryDirectory(prefix='invoice-export-') as directory:
        root = Path(directory)
        subprocess.run(['git', 'init', '-q', str(root)], check=True)
        subprocess.run(['git', '-C', str(root), '-c', 'user.name=Control',
                        '-c', 'user.email=control@example.invalid', 'commit', '--allow-empty', '-qm', 'control'], check=True)
        shutil.copytree(ROOT / 'tests/coding-standards', root / 'tests/coding-standards')
        config_path = root / 'tests/coding-standards/tools.json'
        config = json.loads(config_path.read_text(encoding='utf-8'))
        config['exceptions'] = []
        config_path.write_text(json.dumps(config), encoding='utf-8')
        (root / 'tests/shared-launch-python').mkdir()
        shutil.copyfile(ROOT / 'tests/shared-launch-python/pyproject.toml', root / 'tests/shared-launch-python/pyproject.toml')
        modules = root / 'mcp/sdd-forge-mcp/node_modules'
        modules.parent.mkdir(parents=True)
        modules.symlink_to(ROOT / 'mcp/sdd-forge-mcp/node_modules', target_is_directory=True)
        for language, name, source, expected in CASES:
            path = root / name
            path.write_text(source, encoding='utf-8')
            subprocess.run(['git', '-C', str(root), 'add', '--', name], check=True)
            started = time.monotonic()
            result = NATIVE.scan(root, 'all', None, language)
            elapsed = time.monotonic() - started
            actual = {row['native_rule'] for row in result['findings']}
            results.append({'case': name, 'source': source, 'language': language,
                            'expected': sorted(expected), 'observed': sorted(actual),
                            'passed': actual == expected, 'elapsed_seconds': elapsed,
                            'tools': result['tools']})
            subprocess.run(['git', '-C', str(root), 'rm', '-q', '-f', '--', name], check=True)
    print(json.dumps({'checker_revision': '86fc49554614fb842d937147595baa6ef66fd63c',
                      'criteria': 'Exact native diagnostic set; no findings on valid controls.',
                      'repetitions': 1, 'model_comparison': 'not-performed',
                      'token_cost': 'unknown', 'results': results}, indent=2))
    return int(not all(row['passed'] for row in results))


if __name__ == '__main__':
    raise SystemExit(main())
