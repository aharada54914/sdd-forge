#!/usr/bin/env python3
"""Isolated regression for the separately authorized fresh-review transition."""
import importlib.util
import json
import pathlib
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[3]
FEATURE = 'epic-195-a7-compatibility'
BASE = f'reports/spec-review/{FEATURE}'
HELPER = ROOT / 'plugins/sdd-review-loop/scripts/fresh-review-recovery.py'


def main():
    # Fail specifically on the missing new admission mechanism before fixtures
    # can accidentally exercise the old no-output recovery path instead.
    assert HELPER.is_file(), 'fresh-review recovery admission helper is missing'
    spec = importlib.util.spec_from_file_location('fresh', HELPER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    with tempfile.TemporaryDirectory(prefix='a7-fresh-recovery-') as tmp:
        root = pathlib.Path(tmp) / 'repo'
        for rel in ('plugins/sdd-review-loop', 'plugins/sdd-quality-loop',
                    f'specs/{FEATURE}', f'{BASE}/attempt-7',
                    f'{BASE}/attempt-8', f'{BASE}/attempt-9', 'reports/review-context'):
            shutil.copytree(ROOT / rel, root / rel)
        contract = module.make_fixture_contract(root, FEATURE, 10)
        path = root / 'fresh-review-contract.json'
        path.write_text(json.dumps(contract))
        for runtime in ('bash', 'pwsh'):
            target = pathlib.Path(tmp) / runtime
            shutil.copytree(root, target)
            script = target / 'plugins/sdd-review-loop/scripts/spec-review-precheck'
            cmd = (['bash', str(script) + '.sh', FEATURE, '10', '1', '--reset',
                    '--fresh-review-contract=' + str(target / path.name)] if runtime == 'bash'
                   else ['pwsh', '-NoProfile', '-File', str(script) + '.ps1', FEATURE,
                         '10', '1', '-Reset', '-FreshReviewContract', str(target / path.name)])
            result = subprocess.run(cmd, capture_output=True, text=True)
            assert result.returncode == 0, (runtime, result.stdout, result.stderr)
            print('PASS', runtime, 'fresh transition')


if __name__ == '__main__':
    main()
