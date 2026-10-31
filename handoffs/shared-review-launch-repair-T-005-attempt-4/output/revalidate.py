import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

OUT = Path(__file__).resolve().parent
BASE = OUT.parent
SNAP = BASE / 'snapshot'
MANIFEST = BASE / 'manifest.json'
PIN = '3587faa97e05ea6a361a115d57735bc940411abebc2c4dedfe1c3d3c88db978d'
WORK = OUT / 'work'
EV = WORK / 'specs/shared-review-launch-repair/verification/T-005/attempt-4'
HELPER = 'handoffs/shared-review-launch-repair-T-005-attempt-4/prepare-fixture.cjs'
INVENTORY = 'handoffs/shared-review-launch-repair-T-005-attempt-4/source-modes.json'
TMP = OUT / 'tmp'
TMP.mkdir(exist_ok=True)
for key in ('TMPDIR', 'TMP', 'TEMP'):
    os.environ[key] = str(TMP)
for key, suffix in [('XDG_CACHE_HOME', 'cache'), ('XDG_CONFIG_HOME', 'config'),
                    ('XDG_DATA_HOME', 'data'), ('DOTNET_CLI_HOME', 'dotnet'),
                    ('npm_config_cache', 'npm-cache')]:
    os.environ[key] = str(TMP / suffix)
os.environ['PYTHONDONTWRITEBYTECODE'] = '1'
os.environ['DOTNET_CLI_TELEMETRY_OPTOUT'] = '1'

def sha(data):
    return hashlib.sha256(data).hexdigest()

def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + '\n')

def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def run(label, args, cwd=WORK):
    command = ['rtk', 'proxy', *args]
    start = now()
    begin = time.monotonic()
    with (EV / (label + '.log')).open('wb') as log:
        result = subprocess.run(command, cwd=cwd, stdin=subprocess.DEVNULL,
                                stdout=log, stderr=subprocess.STDOUT, check=False)
    record = dict(label=label, command=command, cwd=str(cwd), stdin='DEVNULL',
                  started_at=start, ended_at=now(), elapsed_seconds=time.monotonic()-begin,
                  exit_code=result.returncode,
                  environment={k: os.environ[k] for k in ('TMPDIR', 'TMP', 'TEMP',
                      'XDG_CACHE_HOME', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME',
                      'DOTNET_CLI_HOME', 'PYTHONDONTWRITEBYTECODE')})
    save(EV / (label + '.json'), record)
    print(json.dumps(record), flush=True)
    return record

assert sha(MANIFEST.read_bytes()) == PIN
manifest = json.loads(MANIFEST.read_bytes())

if sys.argv[1] == 'prepare':
    before = []
    seen = set()
    for row in manifest['allowed_inputs']:
        p = row['path']
        assert not Path(p).is_absolute() and all(v not in ('', '.', '..') for v in p.split('/'))
        assert p not in seen
        seen.add(p)
        file = SNAP / p
        assert not file.is_symlink() and file.resolve() == file
        assert sha(file.read_bytes()) == row['sha256'], p
        before.append(dict(path=p, sha256=row['sha256'], mode=file.stat().st_mode & 0o777))
    inventory = json.loads((SNAP / INVENTORY).read_bytes())
    assert len(inventory['entries']) == 607
    start = now()
    command = ['rtk', 'proxy', 'node', str(SNAP / HELPER), str(MANIFEST), str(SNAP), str(OUT)]
    result = subprocess.run(command, cwd=OUT, stdin=subprocess.DEVNULL, capture_output=True)
    (TMP / 'prepare.stdout').write_bytes(result.stdout)
    (TMP / 'prepare.stderr').write_bytes(result.stderr)
    if result.returncode:
        print(result.stdout.decode() + result.stderr.decode())
        sys.exit(result.returncode)
    EV.mkdir(parents=True, exist_ok=False)
    (EV / 'fixture-preparation.log').write_bytes(result.stdout + result.stderr)
    save(EV / 'fixture-preparation.json', dict(command=command, cwd=str(OUT), stdin='DEVNULL',
        started_at=start, ended_at=now(), exit_code=result.returncode, manifest_sha256=PIN,
        admitted_inputs=len(before), inventory_entries=607, snapshot_before=before))
    print(result.stdout.decode(), end='')
elif sys.argv[1] == 'environment':
    for label, args in [
        ('version-os', ['sw_vers']), ('version-kernel', ['uname', '-smr']),
        ('version-python', ['python3', '--version']), ('version-bash', ['bash', '--version']),
        ('version-pwsh', ['pwsh', '-NoLogo', '-NoProfile', '-Command', '$PSVersionTable | ConvertTo-Json']),
        ('version-node', ['node', '--version']), ('version-jq', ['jq', '--version']),
        ('version-rtk', ['rtk', '--version']), ('version-claude', ['claude', '--version'])]:
        run(label, args)
elif sys.argv[1] == 'suite':
    suites = {
        'unified-task-launch': 'unified-task-launch.tests.py',
        'task-structured-bindings': 'task-structured-output.tests.py',
        'unified-quality-launch': 'quality-nontty-transport.tests.py',
        'spec-review-verify-inputs': 'spec-review-verify-inputs.tests.py',
        'host-launch-profile': 'host-review-preflight.tests.py',
        'unified-launch-order': 'unified-launch-order.tests.py',
        'review-conditional-inputs': 'review-conditional-inputs.tests.py',
        'review-context-boundary': 'review-context-boundary.tests.sh',
    }
    label = sys.argv[2]
    filename = 'tests/' + suites[label]
    args = ['bash', filename] if filename.endswith('.sh') else ['python3', '-B', filename, '-v']
    run(label, args)
elif sys.argv[1] == 'negative':
    run('fixture-negative-controls', ['python3', '-B',
        str(EV / 'harness/fixture_controls.py'), str(SNAP / HELPER), str(TMP), str(EV)])
elif sys.argv[1] == 'integrity':
    before = json.loads((EV / 'fixture-preparation.json').read_text())['snapshot_before']
    errors = []
    for row in before:
        file = SNAP / row['path']
        if sha(file.read_bytes()) != row['sha256'] or file.stat().st_mode & 0o777 != row['mode']:
            errors.append(row['path'])
    inventory = json.loads((SNAP / INVENTORY).read_bytes())
    copy_errors = []
    for row in inventory['entries']:
        file = WORK / row['path']
        if sha(file.read_bytes()) != row['sha256'] or file.stat().st_mode & 0o777 != row['mode']:
            copy_errors.append(row['path'])
    result = dict(manifest_sha256=sha(MANIFEST.read_bytes()), snapshot_files=len(before),
                  snapshot_hash_or_mode_changes=errors, work_files=len(inventory['entries']),
                  work_hash_or_mode_changes=copy_errors, checked_at=now())
    save(EV / 'integrity.json', result)
    print(json.dumps(result))
    assert not errors and not copy_errors and result['manifest_sha256'] == PIN
