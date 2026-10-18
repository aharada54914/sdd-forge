"""Record one scoped offline command and stable output, never native host logs."""
import json
import os
from datetime import datetime, timezone
from pathlib import Path
import subprocess
import sys

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
SCRATCH = '/tmp/cloud-T009-01a14ef5-f7d9-79e3-8b89-23b4811edc3b'


def main() -> None:
    label, *command = sys.argv[1:]
    environment = dict(os.environ)
    overrides = dict(TMPDIR=SCRATCH, PYTHONDONTWRITEBYTECODE='1',
                     MYPYPATH='plugins/sdd-quality-loop/scripts:plugins/sdd-azure-cloud/scripts:plugins/sdd-aws-cloud/scripts',
                     PATH='/workspace/.tools/sdd-forge-dev/bin:/opt/codex/runtimes/codex-primary-runtime/dependencies/node/bin:' + os.defpath)
    environment.update(overrides)
    cwd = ROOT
    if command[0] == '--cwd':
        cwd = Path(command[1])
        command = command[2:]
    start = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    proc = subprocess.run(command, cwd=cwd, env=environment, capture_output=True, timeout=1200)
    log = OUT / (label + '.log')
    log.write_bytes(proc.stdout + proc.stderr)
    record = dict(command=command, cwd=str(cwd), environment_overrides=overrides,
                  started_at=start, finished_at=datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
                  exit_code=proc.returncode, log=log.relative_to(ROOT).as_posix())
    (OUT / (label + '.json')).write_text(json.dumps(record, indent=2) + '\n')
    print(label, proc.returncode, proc.stdout.decode(errors='replace')[-500:], proc.stderr.decode(errors='replace')[-1000:])
    sys.exit(proc.returncode)


if __name__ == '__main__':
    main()
