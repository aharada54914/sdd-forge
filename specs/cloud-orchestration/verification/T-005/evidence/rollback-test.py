"""Disposable checkout experiment restoring the actual pre-task candidate bytes."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent
SCRATCH = Path('/tmp/cloud-T005-01a14dcb')
CHECKOUT = SCRATCH / 'rollback-checkout'


def run(label, command, cwd):
    start = time.monotonic()
    proc = subprocess.run(command, cwd=cwd, env={**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'},
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=300)
    (HERE / (label + '.log')).write_bytes(proc.stdout)
    return dict(label=label, command=command, cwd=str(cwd), exit_code=proc.returncode,
                elapsed_seconds=round(time.monotonic() - start, 3))


def copy_file(source, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)


def main():
    before = json.loads((HERE.parent / 'before.json').read_bytes())
    results = [run('rollback-create', ['git', 'worktree', 'add', '--detach', str(CHECKOUT), before['base_revision']], ROOT)]
    assert results[-1]['exit_code'] == 0
    try:
        snapshot = SCRATCH / 'input-snapshot'
        for path in snapshot.rglob('*'):
            if path.is_file():
                copy_file(path, CHECKOUT / path.relative_to(snapshot))
        test_path = 'tests/cloud-orchestration-routing.tests.py'
        original = snapshot / 'specs/cloud-orchestration/verification/T-005/initial-inputs' / test_path
        copy_file(original, CHECKOUT / test_path)
        # T-004's real native upstream closure is an unchanged test dependency.
        dep = 'specs/cloud-orchestration/verification/T-004/attempt-2/evidence/native-workspace/bundle/upstream'
        shutil.copytree(ROOT / dep, CHECKOUT / dep, dirs_exist_ok=True)
        baseline = [sys.executable, '-B', test_path]
        results.append(run('rollback-before', baseline, CHECKOUT))
        copy_file(ROOT / test_path, CHECKOUT / test_path)
        shutil.copytree(ROOT / 'plugins/sdd-aws-cloud', CHECKOUT / 'plugins/sdd-aws-cloud')
        candidate = [sys.executable, '-B', test_path,
                     'AwsNativePreparation.test_real_synth_complete_locked_assembly_validate_without_execution',
                     'AwsNativePreparation.test_literal_and_composed_markers_are_not_resource_references',
                     'AwsNativePreparation.test_installed_runtime_mutation_denied',
                     'AzureNativePreparation.test_real_compile_locked_plan_and_validate_exact_bytes']
        results.append(run('rollback-candidate', candidate, CHECKOUT))
        # Restore ONLY this task's original test bytes; added AWS code/config did not exist.
        copy_file(original, CHECKOUT / test_path)
        shutil.rmtree(CHECKOUT / 'plugins/sdd-aws-cloud')
        actual = hashlib.sha256((CHECKOUT / test_path).read_bytes()).hexdigest()
        expected = before['task_owned_before'][0]['sha256']
        assert actual == expected
        results.append(run('rollback-restored', baseline, CHECKOUT))
        assert all(r['exit_code'] == 0 for r in results)
        (HERE / 'rollback.json').write_text(json.dumps(dict(base_revision=before['base_revision'],
            before_sha256=expected, restored_sha256=actual, restored_aws_absence=True,
            commands=results, scope='Task code/config restoration only, not cloud cleanup or evidence/history rollback'), indent=2) + '\n')
    finally:
        result = run('rollback-remove', ['git', 'worktree', 'remove', '--force', str(CHECKOUT)], ROOT)
        assert result['exit_code'] == 0


if __name__ == '__main__':
    main()
