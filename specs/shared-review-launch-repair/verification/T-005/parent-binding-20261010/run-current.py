"""Reuse attempt-6 capture runner; execute current owner, isolate fixture writes."""
import importlib.util
import json
import os
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
source = OUT.parent / 'attempt-6/harness/run-verification.py'
spec = importlib.util.spec_from_file_location('historical_runner', source)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
env = dict(os.environ)
for key, relative in {'TMPDIR':'tmp', 'TMP':'tmp', 'TEMP':'tmp',
                     'XDG_CACHE_HOME':'cache', 'XDG_CONFIG_HOME':'config',
                     'XDG_DATA_HOME':'data', 'DOTNET_CLI_HOME':'dotnet'}.items():
    folder = OUT / relative
    folder.mkdir(exist_ok=True)
    env[key] = str(folder)
env.update(PYTHONDONTWRITEBYTECODE='1', DOTNET_CLI_TELEMETRY_OPTOUT='1',
           POWERSHELL_TELEMETRY_OPTOUT='1', DOTNET_SKIP_FIRST_TIME_EXPERIENCE='1')
runner.env = env
results = []
for name in ('quality-nontty-transport', 'task-structured-output',
             'unified-launch-order', 'unified-task-launch'):
    code = runner.run(name, ['python3', '-B', 'tests/'+name+'.tests.py', '-v'],
                      cwd=ROOT, destination=OUT)
    results.append(dict(suite=name, exit_code=code))
(OUT / 'current-tests.json').write_text(json.dumps(results, indent=2)+'\n')
