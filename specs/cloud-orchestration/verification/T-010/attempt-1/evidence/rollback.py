"""Disposable exact-input checkout experiment; no product candidate exists yet."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

ROOT = Path('/workspace/sdd-forge')
SCRATCH = Path('/tmp/cloud-T010-01a14f33-2447-79d0-8195-087bbe42669c')
EVIDENCE = Path('specs/cloud-orchestration/verification/T-010/attempt-1/evidence')
checkout = SCRATCH / 'rollback-checkout'
inputs = json.loads((ROOT / EVIDENCE / 'initial-input-map.json').read_text())
for row in json.loads((ROOT / EVIDENCE / 'test-dependency-manifest.json').read_text())['allowed_inputs']:
    inputs['inputs'].append(dict(source=row['path'], snapshot=row['path'], sha256=row['sha256']))
for row in json.loads((ROOT / EVIDENCE / 'example-dependency-manifest.json').read_text())['allowed_inputs']:
    inputs['inputs'].append(dict(source=row['path'], snapshot=row['path'], sha256=row['sha256']))
records: list[dict] = []


def run(name: str, command: list[str], cwd: Path) -> None:
    proc = subprocess.run(command, cwd=cwd, capture_output=True, text=True)
    (ROOT / EVIDENCE / (name + '.log')).write_text(proc.stdout + proc.stderr)
    records.append(dict(name=name, command=command, cwd=str(cwd), exit_code=proc.returncode))
    assert proc.returncode == 0, (name, proc.returncode)


def hashes() -> dict[str, str]:
    return {row['source']: hashlib.sha256((checkout / row['source']).read_bytes()).hexdigest()
            for row in inputs['inputs'] if not row['source'].startswith('/')}


run('rollback-create', ['git', 'worktree', 'add', '--detach', str(checkout), inputs['base_revision']], ROOT)
try:
    for row in inputs['inputs']:
        if row['source'].startswith('/'):
            continue
        dest = checkout / row['source']
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(SCRATCH / 'snapshot' / row['snapshot'], dest)
    before = hashes()
    baseline = ['python3', '-B', 'tests/cloud-orchestration-verification.tests.py',
                'EntryPreflight.test_live_network_is_forbidden_before_transport', 'ReducerCases',
                'AzureCompletionCases',
                'ProfileDispatchIntegration.test_native_transport_protocol_double_reaches_positive_existing_boundary']
    run('rollback-baseline', baseline, checkout)
    probe = checkout / EVIDENCE / 'probe.py'
    probe.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / EVIDENCE / 'probe.py', probe)
    run('rollback-diagnostic-candidate', ['python3', '-B', str(probe), '--repo-root', str(checkout)], checkout)
    probe.unlink()
    run('rollback-restored-baseline', baseline, checkout)
    after = hashes()
    assert before == after
    assert not (checkout / 'plugins/sdd-quality-loop/scripts/cloud_dependencies.py').exists()
    records.append(dict(before=before, after=after, equal=True, product_candidate='None; preflight halted',
                        rollback_scope='Remove added diagnostic probe only; original candidate product bytes remain untouched'))
finally:
    run('rollback-remove', ['git', 'worktree', 'remove', '--force', str(checkout)], ROOT)
    (ROOT / EVIDENCE / 'rollback.json').write_text(json.dumps(records, indent=2) + '\n')
