"""One mutation per disposable registration or persisted evidence field."""
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile

EVIDENCE = Path(__file__).resolve().parent
WORK = EVIDENCE.parents[3]
OUTPUT = WORK.parent
SNAPSHOT = OUTPUT.parent / 'snapshot'
HANDOFF = 'handoffs/shared-review-launch-repair-T-004-attempt-1/'
spec = importlib.util.spec_from_file_location('wiring', EVIDENCE / 'wiring-check.py')
wiring = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wiring)
SOURCE_PATHS = ('.github/workflows/test.yml', 'tests/run-all.sh', 'tests/run-all.ps1',
                'specs/workflow-state-registry.json')
STEP = '      - name: Install contract validator\n        run: ' + wiring.INSTALL + '\n'
ANCHOR = '      - name: Test shared review launch and conditional input contracts\n'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def evidence_claims():
    manifest = json.loads((OUTPUT.parent / 'manifest.json').read_text())
    inventory = json.loads((SNAPSHOT / (HANDOFF + 'before-byte-inventory.json')).read_text())
    result = {key: manifest[key] for key in ('task_id', 'run_id', 'session_id',
                                           'agent_instance_id', 'isolation_mode')}
    result.update(task_attempt_count=1, manifest_sha256=digest(OUTPUT.parent / 'manifest.json'),
                  scratch_root=str(OUTPUT), spec_revision=inventory['head'])
    for row in manifest['allowed_inputs']:
        result['input:' + row['path']] = digest(SNAPSHOT / row['path'])
        assert result['input:' + row['path']] == row['sha256']
    for name, expected_exit in (('original-wiring-red', 1), ('original-missing-ajv-red', 1),
                                ('baseline-test013', 0)):
        record = json.loads((EVIDENCE / (name + '.json')).read_text())
        assert record['exit'] == expected_exit
        for field in ('command', 'cwd', 'exit', 'stdout', 'stderr', 'source_sha256'):
            result[name + ':' + field] = record[field]
    result.update({'TEST-006a': 'NOT RUN', 'TEST-006b': 'NOT RUN',
                   'native-windows': 'NOT RUN', 'combined-rollback': 'NOT RUN',
                   'independent-review': 'NOT RUN', 'quality-gate': 'NOT RUN',
                   'merge': 'NOT RUN', 'postmerge': 'NOT RUN'})
    return result


def check_claims(claims, counterpart):
    for field in counterpart:
        assert claims.get(field) == counterpart[field], field


if __name__ == '__main__':
    results = []
    with tempfile.TemporaryDirectory(dir=OUTPUT / 'tmp', prefix='t004-mismatch-') as temp:
        root = Path(temp)
        for name in SOURCE_PATHS:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((SNAPSHOT / name).read_bytes())
        workflow = root / SOURCE_PATHS[0]
        before = workflow.read_text()
        assert before.count(ANCHOR) == 1
        workflow.write_text(before.replace(ANCHOR, STEP + ANCHOR, 1))
        # This fixture is a mutation control, never original-production RED.
        assert all(wiring.checks(root).values())
        mutations = [
            ('consuming-install', SOURCE_PATHS[0], STEP, ''),
            ('consuming-install-order', SOURCE_PATHS[0], STEP, ''),
            ('ci-direct-transport', SOURCE_PATHS[0], '        run: python3 -B tests/quality-nontty-transport.tests.py', '        run: true'),
            ('ci-traceability', SOURCE_PATHS[0], '        run: python3 -B tests/traceability-freeze-contract.tests.py', '        run: true'),
            ('bash-transport', SOURCE_PATHS[1], 'if ! python3 -B tests/quality-nontty-transport.tests.py; then', 'if ! true; then'),
            ('bash-traceability', SOURCE_PATHS[1], 'if ! python3 -B tests/traceability-freeze-contract.tests.py; then', 'if ! true; then'),
            ('bash-python-execution', SOURCE_PATHS[1], 'if ! python3 -B "$test_file"; then', 'if ! true; then'),
            ('powershell-transport', SOURCE_PATHS[2], "'tests/quality-nontty-transport.tests.py', ", ''),
            ('powershell-hash-parity', SOURCE_PATHS[2], "    'tests/review-hash-normalization.tests.ps1',\n", ''),
            ('powershell-python-execution', SOURCE_PATHS[2], '& python -B (Join-Path $root $testFile)', 'Write-Host $testFile'),
            ('registry-full-profile', SOURCE_PATHS[3], '"feature": "shared-review-launch-repair"', '"feature": "removed-feature"'),
        ]
        for name in wiring.SUITES:
            mutations.extend([
                ('bash-' + name, SOURCE_PATHS[1], ' ' + name, ''),
                ('ci-' + name, SOURCE_PATHS[0], '          python3 -B tests/' + name + '.tests.py\n', ''),
            ])
        for name, relative, old, new in mutations:
            path = root / relative
            original = path.read_bytes()
            text = original.decode()
            assert old in text, name
            text = text.replace(old, new, 1)
            if name == 'consuming-install-order':
                marker = '      - name: Test guard dispatch fallback\n'
                assert text.count(marker) == 1
                text = text.replace(marker, STEP + marker, 1)
            path.write_text(text)
            check = 'consuming-install' if name == 'consuming-install-order' else name
            command = ['rtk', 'proxy', 'python3', '-B', str(EVIDENCE / 'wiring-check.py'), str(root), '--only', check]
            run = subprocess.run(command, cwd=WORK, capture_output=True, text=True,
                                 env=dict(os.environ, TMPDIR=str(OUTPUT / 'tmp'), PYTHONDONTWRITEBYTECODE='1'))
            results.append({'mutation': name, 'file': relative, 'before_sha256': hashlib.sha256(original).hexdigest(),
                            'mutated_sha256': digest(path), 'command': command, 'cwd': str(WORK),
                            'exit': run.returncode, 'stdout': run.stdout, 'stderr': run.stderr})
            assert run.returncode == 1 and ('FAIL ' + check) in run.stdout, name
            path.write_bytes(original)
            assert all(wiring.checks(root).values())
    claims = evidence_claims()
    check_claims(claims, claims)
    for field in claims:
        mutated = copy.deepcopy(claims)
        mutated[field] = {'mismatch': True}
        try:
            check_claims(mutated, claims)
        except AssertionError as error:
            assert str(error) == field
            results.append({'field': field, 'result': 'mismatch rejected', 'diagnostic': str(error)})
        else:
            raise AssertionError('accepted evidence field mismatch: ' + field)
    (EVIDENCE / 'preflight-claims.json').write_text(json.dumps(claims, indent=2) + '\n')
    (EVIDENCE / 'preflight-mismatch-results.json').write_text(json.dumps(results, indent=2) + '\n')
    print(f'{len(mutations)} registration/order mutations rejected; {len(claims)} evidence field mutations rejected')
