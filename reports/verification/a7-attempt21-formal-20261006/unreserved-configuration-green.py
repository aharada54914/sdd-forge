"""One unreserved GREEN probe; only add StructuredOutput to custom agent tools."""
from pathlib import Path
import json
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
args = json.loads((OUT / 'custom-readonly-tools.command.json').read_text())
index = args.index('--agents') + 1
role = json.loads(args[index])
assert role['transport-probe']['tools'] == ['Read', 'Grep', 'Glob', 'Bash']
role['transport-probe']['tools'].append('StructuredOutput')
args[index] = json.dumps(role)
case = 'custom-structured-output-green'
for suffix in ('wrapper.json', 'stderr.txt', 'command.json', 'exit.txt', 'validation.json'):
    if (OUT / (case + '.' + suffix)).exists():
        raise SystemExit('Existing diagnostic; no retry')
with (OUT / (case + '.command.json')).open('x') as f:
    json.dump(args, f, indent=2)
with (OUT / (case + '.wrapper.json')).open('xb') as out, (OUT / (case + '.stderr.txt')).open('xb') as err:
    run = subprocess.run(args, cwd=ROOT, stdout=out, stderr=err)
with (OUT / (case + '.exit.txt')).open('x') as f:
    f.write(str(run.returncode) + '\n')
print('CLI exit:', run.returncode, flush=True)
assert run.returncode == 0
wrapper = json.loads((OUT / (case + '.wrapper.json')).read_text())
assert wrapper['is_error'] is False
assert wrapper['structured_output'] == {'probe': 'ok'}
assert json.loads(wrapper['result']) == {'probe': 'ok'}
assert wrapper.get('permission_denials') == []
result = {'status': 'DIAGNOSTIC_GREEN', 'session_id': wrapper['session_id'],
          'raw_result': wrapper['result'], 'structured_output': wrapper['structured_output'],
          'schema_exact': True, 'raw_extra_text': False, 'formal_review': False}
with (OUT / (case + '.validation.json')).open('x') as f:
    json.dump(result, f, indent=2)
print(json.dumps(result), flush=True)
