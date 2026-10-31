"""Restore only the T-004 workflow change in a disposable admitted projection."""
import hashlib
import json
import os
from pathlib import Path
import subprocess

evidence = Path(__file__).resolve().parent
work = evidence.parents[3]
output = work.parent
snapshot = output.parent / 'snapshot'
root = output / 'tmp/t004-source-rollback'
root.mkdir(exist_ok=False)
manifest = json.loads((output.parent / 'manifest.json').read_text())
modes = json.loads((snapshot / 'handoffs/shared-review-launch-repair-T-004-attempt-1/source-modes.json').read_text())['entries']
for entry in manifest['allowed_inputs']:
    path = root / entry['path']
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes((snapshot / entry['path']).read_bytes())
for entry in modes:
    (root / entry['path']).chmod(entry['mode'])


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


commands = []


def run(args, expected):
    command = ['rtk', 'proxy', *args]
    result = subprocess.run(command, cwd=root, capture_output=True, text=True,
                            env=dict(os.environ, TMPDIR=str(output / 'tmp'), PYTHONDONTWRITEBYTECODE='1'))
    commands.append({'command': command, 'cwd': str(root), 'exit': result.returncode,
                     'expected_exit': expected, 'stdout': result.stdout, 'stderr': result.stderr})
    assert result.returncode == expected, result.stdout + result.stderr


name = '.github/workflows/test.yml'
path = root / name
before = {'sha256': sha(path), 'mode': path.stat().st_mode & 0o777}
path.write_bytes((work / name).read_bytes())
path.chmod((work / name).stat().st_mode & 0o777)
candidate = {'sha256': sha(path), 'mode': path.stat().st_mode & 0o777}
assert before['sha256'] != candidate['sha256']
run(['python3', '-B', str(evidence / 'wiring-check.py'), '.'], 0)
path.write_bytes((snapshot / name).read_bytes())
path.chmod(before['mode'])
restored = {'sha256': sha(path), 'mode': path.stat().st_mode & 0o777}
assert restored == before
run(['python3', '-B', str(evidence / 'wiring-check.py'), '.'], 1)
assert commands[-1]['stdout'].splitlines().count('FAIL consuming-install') == 1
assert len([line for line in commands[-1]['stdout'].splitlines() if line.startswith('FAIL ')]) == 1
run(['python3', '-B', str(evidence / 'wiring-check.py'), '.', '--registrations-only'], 0)
run(['python3', '-B', 'tests/host-review-preflight.tests.py',
     'ProtectedEntrypointTests.test_013_ci_transport_registration'], 0)
run(['python3', '-B', 'plugins/sdd-quality-loop/scripts/generate-guard-invariants.py', '--check'], 0)
for entry in manifest['allowed_inputs']:
    assert sha(root / entry['path']) == entry['sha256'], entry['path']
for entry in modes:
    assert (root / entry['path']).stat().st_mode & 0o777 == entry['mode'], entry['path']
record = {'scope': 'T-004 source rollback only; combined T001-T005 rollback NOT RUN',
          'root': str(root), 'changed_source': name, 'before': before,
          'candidate': candidate, 'restored': restored,
          'restored_admitted_hashes': len(manifest['allowed_inputs']), 'commands': commands}
(evidence / 'rollback-results.json').write_text(json.dumps(record, indent=2) + '\n')
print('T-004 workflow bytes/mode restored; dependency-wiring RED restored; applicable registration/TEST-013/generator baselines GREEN')
