import datetime
import json
import os
from pathlib import Path
import subprocess
import sys

output = Path(__file__).resolve().parents[1]
evidence = output / 'work/specs/shared-review-launch-repair/verification/T-005/attempt-2'
evidence.mkdir(parents=True, exist_ok=True)
label, *command = sys.argv[1:]
env = dict(os.environ)
env.update(HOME=str(output / 'home'), XDG_CACHE_HOME=str(output / 'cache'),
           XDG_CONFIG_HOME=str(output / 'home/config'), XDG_DATA_HOME=str(output / 'home/data'),
           PYTHONDONTWRITEBYTECODE='1', PYTHONPYCACHEPREFIX=str(output / 'cache/pycache'),
           DOTNET_CLI_HOME=str(output / 'home'), POWERSHELL_TELEMETRY_OPTOUT='1',
           DOTNET_CLI_TELEMETRY_OPTOUT='1')
assert all(Path(env[key]).resolve() == output / 'tmp' for key in ('TMPDIR', 'TMP', 'TEMP'))
record = dict(command=command, cwd=str(output / 'work'),
              started_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
              environment={key: env[key] for key in ('TMPDIR', 'TMP', 'TEMP', 'HOME',
                  'XDG_CACHE_HOME', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME',
                  'PYTHONDONTWRITEBYTECODE', 'PYTHONPYCACHEPREFIX', 'DOTNET_CLI_HOME')})
result = subprocess.run(command, cwd=output / 'work', env=env, text=True,
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
record.update(returncode=result.returncode,
              ended_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
(evidence / (label + '.log')).write_text(result.stdout)
(evidence / (label + '.json')).write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record))
print(result.stdout)
sys.exit(result.returncode)
