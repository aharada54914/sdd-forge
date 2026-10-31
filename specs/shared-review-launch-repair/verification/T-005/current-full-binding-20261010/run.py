"""Current-owner verification; all generated evidence is scoped beside this file."""
import datetime
import difflib
import hashlib
import importlib.util
import json
import os
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
INDEX = OUT.parent / 'attempt-6/input-and-source-hashes.json'
index = json.loads(INDEX.read_text())
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
def compare(label):
    rows = []
    for e in index['copies']:
        current = ROOT / e['path']
        old = Path(index['scratch_root']) / 'work' / e['path']
        rows.append(dict(path=e['path'], historical_sha256=e['sha256'],
                         historical_actual_sha256=sha(old), current_sha256=sha(current),
                         current_mode=oct(current.stat().st_mode & 0o777),
                         historical_mode=e.get('mode'), bytes_match=sha(current)==e['sha256']))
    data = dict(checked_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                owner=str(ROOT), index_sha256=sha(INDEX), count=len(rows), rows=rows,
                matching=sum(r['bytes_match'] for r in rows))
    (OUT / (label+'.json')).write_text(json.dumps(data, indent=2)+'\n')
    return data

before = compare('comparison-before')
ledger = ROOT / 'reports/review-context/identity-ledger.json'
ledger_before = sha(ledger)
attribution = []
for row in before['rows']:
    if row['bytes_match']:
        continue
    path = row['path']
    old = Path(index['scratch_root']) / 'work' / path
    patch = ''.join(difflib.unified_diff(old.read_text().splitlines(True),
                    (ROOT/path).read_text().splitlines(True), fromfile='attempt6/'+path,
                    tofile='current-owner/'+path))
    name = path.replace('/', '__')+'.diff'
    (OUT/name).write_text(patch)
    attribution.append(dict(path=path, historical_sha256=row['historical_sha256'],
        current_sha256=row['current_sha256'], diff=name,
        classification='test-only' if path.startswith('tests/') else 'production-source'))
(OUT/'diff-attribution.json').write_text(json.dumps(attribution, indent=2)+'\n')

source = OUT.parent / 'attempt-6/harness/run-verification.py'
spec = importlib.util.spec_from_file_location('capture_runner', source)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
env = dict(os.environ)
for key, relative in {'TMPDIR':'tmp','TMP':'tmp','TEMP':'tmp',
        'XDG_CACHE_HOME':'cache','XDG_CONFIG_HOME':'config','XDG_DATA_HOME':'data',
        'DOTNET_CLI_HOME':'dotnet'}.items():
    folder = OUT/relative
    folder.mkdir(exist_ok=True)
    env[key]=str(folder)
env.update(PYTHONDONTWRITEBYTECODE='1',DOTNET_CLI_TELEMETRY_OPTOUT='1',
           POWERSHELL_TELEMETRY_OPTOUT='1',DOTNET_SKIP_FIRST_TIME_EXPERIENCE='1',
           T005_SOURCE_GIT_ROOT=str(ROOT))
runner.env=env
results=[]
for name, runtime, suffix in (
    ('host-review-preflight','python3','py'),
    ('spec-review-verify-inputs','python3','py'),
    ('review-conditional-inputs','python3','py'),
    ('review-context-boundary','bash','sh'),
    ('supplemental-delivery-declaration','python3','py'),
    ('review-agent-isolation','bash','sh')):
    argv=[runtime]+(['-B'] if runtime=='python3' else [])+['tests/'+name+'.tests.'+suffix]+(['-v'] if runtime=='python3' else [])
    code=runner.run(name,argv,cwd=ROOT,destination=OUT)
    results.append(dict(suite=name,exit_code=code))
    (OUT/'results.json').write_text(json.dumps(results,indent=2)+'\n')
after=compare('comparison-after')
summary=dict(results=results,compared_rows_stable=before['rows']==after['rows'],
             ledger_before_sha256=ledger_before,ledger_after_sha256=sha(ledger),
             ledger_unchanged=ledger_before==sha(ledger),
             historical_execution_is_owner_execution=False,
             formal_gate='NOT RUN',native='NOT RUN',windows='NOT RUN',ci='NOT RUN')
(OUT/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary),flush=True)
