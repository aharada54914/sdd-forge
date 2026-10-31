import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

OUT = Path(__file__).resolve().parent
WORK = OUT / 'work'
EVIDENCE = WORK / 'specs/shared-review-launch-repair/verification/T-005/attempt-6'
env = os.environ.copy()
env.update({
    'TMPDIR': str(OUT / 'tmp'), 'TMP': str(OUT / 'tmp'), 'TEMP': str(OUT / 'tmp'),
    'TMPPREFIX': str(OUT / 'tmp/zsh'), 'PYTHONDONTWRITEBYTECODE': '1',
    'XDG_CACHE_HOME': str(OUT / 'tmp/cache'), 'XDG_CONFIG_HOME': str(OUT / 'tmp/config'),
    'XDG_DATA_HOME': str(OUT / 'tmp/data'), 'DOTNET_CLI_HOME': str(OUT / 'tmp/dotnet'),
    'DOTNET_CLI_TELEMETRY_OPTOUT': '1', 'DOTNET_SKIP_FIRST_TIME_EXPERIENCE': '1',
    'GIT_CONFIG_NOSYSTEM': '1', 'GIT_CONFIG_GLOBAL': '/dev/null',
    'GIT_CEILING_DIRECTORIES': str(OUT), 'GIT_TERMINAL_PROMPT': '0',
    'T005_SOURCE_GIT_ROOT': str(OUT / 'git-history.git'),
})


def run(label, argv, cwd=WORK, destination=EVIDENCE):
    destination.mkdir(parents=True, exist_ok=True)
    start = datetime.datetime.now(datetime.timezone.utc).isoformat()
    t = time.monotonic()
    command = ['rtk', 'proxy', *argv]
    with (destination / (label + '.log')).open('wb') as log:
        result = subprocess.run(command, cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                                stdout=log, stderr=subprocess.STDOUT)
    record = dict(label=label, argv=command, cwd=str(cwd), stdin='DEVNULL',
                  environment={k: env[k] for k in env if k in (
                      'TMPDIR', 'TMP', 'TEMP', 'TMPPREFIX', 'PYTHONDONTWRITEBYTECODE',
                      'XDG_CACHE_HOME', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'DOTNET_CLI_HOME',
                      'GIT_CONFIG_NOSYSTEM', 'GIT_CONFIG_GLOBAL', 'GIT_CEILING_DIRECTORIES',
                      'T005_SOURCE_GIT_ROOT')}, started_at=start,
                  finished_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  duration_seconds=round(time.monotonic()-t, 3), exit_code=result.returncode)
    (destination / (label + '.json')).write_text(json.dumps(record, indent=2)+'\n')
    print(json.dumps(record), flush=True)
    print((destination / (label + '.log')).read_text(errors='replace')[-2500:], flush=True)
    return result.returncode


if __name__ == '__main__':
    if sys.argv[1] == 'prepare':
        base = OUT.parent
        rc = run('prepare-fixture', ['node', str(base / 'snapshot/handoffs/shared-review-launch-repair-T-005-attempt-6/prepare-fixture.cjs'),
                 str(base / 'manifest.json'), str(base / 'snapshot'), str(OUT)], OUT, OUT / 'tmp/preparation')
        if rc == 0:
            EVIDENCE.mkdir(parents=True, exist_ok=True)
            for suffix in ('.log', '.json'):
                (EVIDENCE / ('prepare-fixture'+suffix)).write_bytes((OUT / 'tmp/preparation' / ('prepare-fixture'+suffix)).read_bytes())
        sys.exit(rc)
    label, runtime, file, *args = sys.argv[1:]
    sys.exit(run(label, [runtime, *(['-B'] if runtime == 'python3' else []), file, *args]))
