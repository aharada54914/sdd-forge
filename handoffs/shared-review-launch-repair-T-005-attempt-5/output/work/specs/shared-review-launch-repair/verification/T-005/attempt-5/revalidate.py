import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time

EVIDENCE = Path(__file__).resolve().parent
WORK = EVIDENCE.parents[4]
OUTPUT = WORK.parent
HANDOFF = OUTPUT.parent
ENV = os.environ.copy()
ENV.update({key: str(OUTPUT / 'tmp') for key in ('TMPDIR', 'TMP', 'TEMP')})
ENV.update(PYTHONDONTWRITEBYTECODE='1', XDG_CACHE_HOME=str(OUTPUT / 'tmp/cache'),
           XDG_CONFIG_HOME=str(OUTPUT / 'tmp/config'), XDG_DATA_HOME=str(OUTPUT / 'tmp/data'),
           DOTNET_CLI_HOME=str(OUTPUT / 'tmp/dotnet'), DOTNET_CLI_TELEMETRY_OPTOUT='1',
           POWERSHELL_TELEMETRY_OPTOUT='1', GIT_CEILING_DIRECTORIES=str(OUTPUT))
for name in ('cache', 'config', 'data', 'dotnet'):
    (OUTPUT / 'tmp' / name).mkdir(exist_ok=True)


def save(name, data):
    (EVIDENCE / name).write_text(json.dumps(data, indent=2) + '\n')


def run(label, argv, cwd=WORK):
    command = ['rtk', 'proxy', *argv]
    start = datetime.datetime.now(datetime.timezone.utc).isoformat()
    begin = time.monotonic()
    print('START', label, flush=True)
    with (EVIDENCE / (label + '.stdout.log')).open('w') as out, (EVIDENCE / (label + '.stderr.log')).open('w') as err:
        result = subprocess.run(command, cwd=cwd, env=ENV, stdin=subprocess.DEVNULL, stdout=out, stderr=err)
    record = dict(label=label, command=command, cwd=str(cwd), stdin='DEVNULL',
                  started_at=start, ended_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  elapsed_seconds=round(time.monotonic() - begin, 3), exit_code=result.returncode)
    save(label + '.json', record)
    stdout = (EVIDENCE / (label + '.stdout.log')).read_text()
    stderr = (EVIDENCE / (label + '.stderr.log')).read_text()
    print('END', label, 'exit', result.returncode, '\n' + (stdout + stderr)[-1600:], flush=True)
    # Expected application-level negative fixtures are distinct from a host denial.
    if 'Operation not permitted' in stdout + stderr or 'sandbox-exec: sandbox_apply' in stdout + stderr:
        save('host-refusal.json', record)
        raise SystemExit('Host refusal observed; stop without retry')
    return record


def negative_preparation():
    helper = HANDOFF / 'snapshot/handoffs/shared-review-launch-repair-T-005-attempt-5/prepare-fixture.cjs'
    inventory_path = 'handoffs/shared-review-launch-repair-T-005-attempt-5/source-modes.json'
    cases = []
    for case in ('valid-mode-restoration', 'traversal', 'absolute', 'duplicate-input',
                 'duplicate-inventory', 'invalid-mode', 'noninteger-mode', 'hash-mismatch',
                 'unpinned-mode-change', 'external-root'):
        root = OUTPUT / 'tmp' / ('preparation-' + case)
        snapshot, output = root / 'snapshot', root / 'output'
        snapshot.mkdir(parents=True)
        output.mkdir()
        source = snapshot / 'fixture.txt'
        source.write_text('fixture\n')
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        entry = dict(path='fixture.txt', sha256=digest, mode=493)
        allowed = [dict(path='fixture.txt', sha256=digest)]
        inventory = dict(schema='t005-fixture-modes/v1', entries=[entry])
        if case in ('traversal', 'absolute'):
            allowed[0]['path'] = '../escape' if case == 'traversal' else str(OUTPUT / 'tmp/escape')
        if case == 'duplicate-input':
            allowed.append(allowed[0].copy())
        if case == 'duplicate-inventory':
            inventory['entries'].append(entry.copy())
        if case == 'invalid-mode':
            entry['mode'] = 512
        if case == 'noninteger-mode':
            entry['mode'] = '0755'
        if case == 'hash-mismatch':
            source.write_text('tampered\n')
        inventory_file = snapshot / inventory_path
        inventory_file.parent.mkdir(parents=True)
        inventory_file.write_text(json.dumps(inventory))
        allowed.append(dict(path=inventory_path, sha256=hashlib.sha256(inventory_file.read_bytes()).hexdigest()))
        if case == 'unpinned-mode-change':
            entry['mode'] = 420
            inventory_file.write_text(json.dumps(inventory))
        manifest = root / 'manifest.json'
        manifest.write_text(json.dumps(dict(allowed_inputs=allowed)))
        target = output
        if case == 'external-root':
            target = root / 'external'
            target.mkdir()
        before = (source.read_bytes(), source.stat().st_mode)
        record = run('prepare-' + case, ['node', str(helper), str(manifest), str(snapshot), str(target)])
        success = record['exit_code'] == 0
        assert success == (case == 'valid-mode-restoration'), case
        assert before == (source.read_bytes(), source.stat().st_mode), case
        if success:
            assert (output / 'work/fixture.txt').stat().st_mode & 511 == 493
        else:
            assert not (target / 'work').exists(), case
        cases.append(dict(case=case, exit_code=record['exit_code'], assertion='expected outcome and unchanged synthetic source'))
    save('fixture-negative-summary.json', cases)


def main():
    environment = dict(platform=platform.platform(), machine=platform.machine(), python=sys.version,
                       scratch_root=str(OUTPUT.resolve()), environment={k: ENV[k] for k in (
                           'TMPDIR', 'TMP', 'TEMP', 'PYTHONDONTWRITEBYTECODE', 'XDG_CACHE_HOME',
                           'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'DOTNET_CLI_HOME', 'GIT_CEILING_DIRECTORIES')})
    environment['versions'] = [run('version-' + name, argv) for name, argv in (
        ('python', ['python3', '--version']), ('bash', ['bash', '--version']),
        ('node', ['node', '--version']), ('pwsh', ['pwsh', '-NoLogo', '-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()']),
        ('jq', ['jq', '--version']), ('rtk', ['rtk', '--version']), ('claude', ['claude', '--version']))]
    save('environment.json', environment)
    negative_preparation()
    results = []
    suites = [
        ('unified-task-launch', ['python3', '-B', 'tests/unified-task-launch.tests.py', '-v']),
        ('task-structured-bindings', ['python3', '-B', 'tests/task-structured-output.tests.py', '-v']),
        ('unified-quality-launch', ['python3', '-B', 'tests/quality-nontty-transport.tests.py', '-v']),
        ('spec-review-verify-inputs', ['python3', '-B', 'tests/spec-review-verify-inputs.tests.py', '-v']),
        ('host-launch-profile', ['python3', '-B', 'tests/host-review-preflight.tests.py', '-v']),
        ('unified-launch-order', ['python3', '-B', 'tests/unified-launch-order.tests.py', '-v']),
        ('review-conditional-inputs', ['python3', '-B', 'tests/review-conditional-inputs.tests.py', '-v']),
        ('review-context-boundary', ['bash', 'tests/review-context-boundary.tests.sh']),
        ('supplemental-delivery-declaration', ['python3', '-B', 'tests/supplemental-delivery-declaration.tests.py', '-v']),
        ('review-agent-isolation', ['bash', 'tests/review-agent-isolation.tests.sh']),
        ('review-scratch-history', ['python3', '-B', 'tests/review-scratch-history.tests.py', '--repo', str(WORK)]),
    ]
    for label, argv in suites:
        results.append(run(label, argv))
        save('execution-summary.json', results)


if __name__ == '__main__':
    main()
