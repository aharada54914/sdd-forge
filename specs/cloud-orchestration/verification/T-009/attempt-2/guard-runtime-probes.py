"""Offline protected-path parity, with unprotected controls; no writes executed."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[5]
SCRIPTS = ROOT / 'plugins/sdd-quality-loop/scripts'


def main() -> None:
    source = json.loads((SCRIPTS.parent / 'references/guard-invariants.json').read_bytes())
    delta = json.loads((Path(__file__).resolve().parent / 'guard-protected-delta.json').read_bytes())
    added = delta['added']
    assert set(added) <= set(source['protected_gate_suffixes'])
    assert len(added) == 11, added
    commands = [
        ['python3', '-B', str(SCRIPTS / 'sdd-hook-guard.py'), '--emit', 'exit'],
        ['sh', str(SCRIPTS / 'sdd-hook-guard.sh'), '--emit', 'exit'],
        ['node', str(SCRIPTS / 'sdd-hook-guard.js'), '--emit', 'exit'],
        ['/workspace/.tools/sdd-forge-dev/bin/pwsh', '-NoProfile', '-File', str(SCRIPTS / 'sdd-hook-guard.ps1'), '-Emit', 'exit'],
    ]
    rows = []
    with tempfile.TemporaryDirectory(prefix='T009-guard-') as temp:
        environment = {k: os.environ[k] for k in ('PATH', 'TMPDIR')}
        environment.update(CLAUDE_PROJECT_DIR=temp, HOME=temp)
        for command in commands:
            for path in ['README.md', *added]:
                payload = dict(tool_name='write', tool_input=dict(file_path=path, content='synthetic probe'))
                proc = subprocess.run(command, input=json.dumps(payload), capture_output=True, text=True,
                                      cwd=temp, env=environment, timeout=30)
                expected = 0 if path == 'README.md' else 2
                assert proc.returncode == expected, (path, command, proc.returncode, proc.stderr)
                rows.append(dict(command=command, path=path, expected=expected, exit_code=proc.returncode))
    print(json.dumps(dict(classification='offline guard decision only', cases=rows), indent=2))


if __name__ == '__main__':
    main()
