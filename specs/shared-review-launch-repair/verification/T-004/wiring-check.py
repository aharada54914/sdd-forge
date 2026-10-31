"""T-004 evidence-scope assertions for the existing runner/workflow grammar."""
import argparse
import json
from pathlib import Path
import re


INSTALL = 'npm ci --prefix mcp/ci-mcp --ignore-scripts'
SUITES = ('review-conditional-inputs', 'spec-review-verify-inputs',
          'host-review-preflight', 'unified-launch-order', 'unified-task-launch',
          'task-structured-output', 'supplemental-delivery-declaration',
          't001-evaluation-preparation')


def checks(root):
    workflow = (root / '.github/workflows/test.yml').read_text()
    match = re.search(r'(?ms)^  posix-regression:\n(.*?)(?=^  [\w-]+:|\Z)', workflow)
    assert match, 'consuming posix-regression job missing'
    job = match.group(1)
    bash = (root / 'tests/run-all.sh').read_text()
    powershell = (root / 'tests/run-all.ps1').read_text()
    install = list(re.finditer(r'^        run: ' + re.escape(INSTALL) + r'[ \t]*$', job, re.M))
    suite = list(re.finditer(r'^          python3 -B tests/task-structured-output[.]tests[.]py$', job, re.M))
    results = {
        'consuming-install': len(install) == 1 and len(suite) == 1 and install[0].start() < suite[0].start(),
        'ci-direct-transport': len(re.findall(r'^        run: python3 -B tests/quality-nontty-transport[.]tests[.]py$', job, re.M)) == 1,
        'ci-traceability': len(re.findall(r'^        run: python3 -B tests/traceability-freeze-contract[.]tests[.]py$', job, re.M)) == 1,
        'bash-transport': 'if ! python3 -B tests/quality-nontty-transport.tests.py; then' in bash,
        'bash-traceability': 'if ! python3 -B tests/traceability-freeze-contract.tests.py; then' in bash,
        'bash-python-execution': 'if ! python3 -B "$test_file"; then' in bash and 'failed+=("$test_file")' in bash,
        'powershell-transport': bool(re.search(r"^    foreach \(\$testFile in @\('tests/quality-nontty-transport[.]tests[.]py'", powershell, re.M)),
        'powershell-hash-parity': bool(re.search(r"^    'tests/review-hash-normalization[.]tests[.]ps1',$", powershell, re.M)),
        'powershell-python-execution': '& python -B (Join-Path $root $testFile)' in powershell and '$failed += $testFile' in powershell,
        'registry-full-profile': [entry for entry in json.loads((root / 'specs/workflow-state-registry.json').read_text())['entries'] if entry['feature'] == 'shared-review-launch-repair'] == [{'feature': 'shared-review-launch-repair', 'profile': 'full'}],
    }
    loop = re.search(r'^for test_name in ([^\n]+); do$', bash, re.M)
    for name in SUITES:
        results['bash-' + name] = bool(loop and loop.group(1).split().count(name) == 1)
        results['ci-' + name] = len(re.findall(r'^          python3 -B tests/' + re.escape(name) + r'[.]tests[.]py$', job, re.M)) == 1
    return results


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('--only')
    parser.add_argument('--registrations-only', action='store_true')
    args = parser.parse_args()
    outcomes = checks(args.root)
    if args.only:
        outcomes = {args.only: outcomes[args.only]}
    elif args.registrations_only:
        del outcomes['consuming-install']
    for name, passed in outcomes.items():
        print(('PASS ' if passed else 'FAIL ') + name)
    raise SystemExit(0 if all(outcomes.values()) else 1)
