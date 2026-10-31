"""Disposable-copy regression; never invokes a precheck in the owning checkout."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
FEATURE = 'epic-196-a8-integration'
PATCH = ROOT / 'reports/verification/a8-blocked-continuation-candidate-20261005.patch'
TEMP = Path(tempfile.mkdtemp(prefix='a8-blocked-candidate-'))
for name in ('plugins', 'tests', 'specs', 'reports', 'docs', 'contracts'):
    shutil.copytree(ROOT / name, TEMP / name, symlinks=True)
shutil.copy2(ROOT / 'AGENTS.md', TEMP / 'AGENTS.md')
history = TEMP / f'reports/impl-review/{FEATURE}/attempt-9/round-1'
destination = history.parent / 'round-2'
saved = {p: p.read_bytes() for p in history.iterdir() if p.is_file()}
baseline_hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                   for p in (ROOT / f'reports/impl-review/{FEATURE}/attempt-9/round-1').iterdir() if p.is_file()}
failures = 0

def restore():
    for p, content in saved.items():
        p.write_bytes(content)
    if destination.exists():
        shutil.rmtree(destination)

def mutate(name, key, value):
    path = history / name
    obj = json.loads(path.read_text())
    obj[key] = value
    path.write_text(json.dumps(obj) + '\n')

def run(runtime, phase, case, expected, round_number='2'):
    global failures
    command = (['bash', 'plugins/sdd-review-loop/scripts/impl-review-precheck.sh'] if runtime == 'bash'
               else ['pwsh', '-NoProfile', '-File', 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1'])
    mode = '--provenance-rereview' if runtime == 'bash' else '-ProvenanceRereview'
    result = subprocess.run(command + [FEATURE, '9', round_number, mode],
                            cwd=TEMP, capture_output=True, text=True, timeout=120)
    output = result.stdout + result.stderr
    ready = 'registry schema is unavailable' not in output and 'parameter cannot be found' not in output
    target = history.parent / ('round-' + round_number)
    good = ready and (result.returncode == 0) == expected and target.exists() == expected
    if case == 'round-limit':
        good = good and 'three-round limit' in output
    failures += not good
    print(json.dumps(dict(phase=phase, runtime=runtime, case=case, exit=result.returncode,
                          expected_success=expected, ok=good, output=result.stdout + result.stderr)), flush=True)

for runtime in ('bash', 'pwsh'):
    restore()
    run(runtime, 'RED', 'legitimate-critical-blocked', False)
subprocess.run(['git', 'apply', str(PATCH)], cwd=TEMP, check=True)
for runtime in ('bash', 'pwsh'):
    for case in ('legitimate-critical-blocked', 'forged-zero-critical', 'forged-major-count',
                 'mis-cased-verdict', 'unknown-verdict', 'reviewer-pin-mismatch'):
        restore()
        if case == 'forged-zero-critical':
            mutate('impl-review-contract.json', 'findings_critical', 0)
        elif case == 'forged-major-count':
            mutate('impl-review-contract.json', 'findings_major', 0)
        elif case == 'mis-cased-verdict':
            mutate('impl-review-contract.json', 'verdict', 'blocked')
        elif case == 'unknown-verdict':
            mutate('impl-review-contract.json', 'verdict', 'UNKNOWN')
        elif case == 'reviewer-pin-mismatch':
            obj = json.loads((history / 'reviewer-a.json').read_text())
            obj['allowed_input_manifest'][0]['sha256'] = '0' * 64
            (history / 'reviewer-a.json').write_text(json.dumps(obj) + '\n')
        run(runtime, 'GREEN', case, case == 'legitimate-critical-blocked')
    restore()
    terminal = history.parent / 'round-3'
    assert not terminal.exists()
    shutil.copytree(history, terminal)
    run(runtime, 'GREEN', 'round-limit', False, '4')
    shutil.rmtree(terminal)
restore()
result = subprocess.run(['bash', 'tests/impl-review-adr-inputs.tests.sh', '--generation-only'],
                        cwd=TEMP, capture_output=True, text=True, timeout=240)
print(result.stdout + result.stderr, flush=True)
failures += result.returncode != 0
for relative, digest in baseline_hashes.items():
    assert hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() == digest, relative
print('owner_history_unchanged=true; failures=' + str(failures), flush=True)
print('Disposable fixture retained for inspection: ' + str(TEMP), flush=True)
raise SystemExit(1 if failures else 0)
