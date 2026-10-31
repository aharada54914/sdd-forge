"""Two diagnostic-only launches. No formal inputs, reservations, or retries."""
from pathlib import Path
import json
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
PROMPT = 'Transport diagnostic only, not a review. Return the structured object with probe equal to ok. Do not read or change any files.'
SCHEMA = '{"type":"object","properties":{"probe":{"type":"string","enum":["ok"]}},"required":["probe"],"additionalProperties":false}'
BASE = ['rtk', 'proxy', 'claude', '-p', '--model', 'sonnet', '--output-format', 'json',
        '--json-schema', SCHEMA, '--tools', 'Read,Grep,Glob,Bash',
        '--allowedTools', 'Read', 'Grep', 'Glob', 'Bash(rtk proxy shasum -a 256)',
        '--disallowedTools', 'Write', 'Edit', 'NotebookEdit']
ROLE = {'transport-probe': {'description': 'Transport diagnostic, never a formal reviewer',
        'prompt': PROMPT, 'model': 'sonnet', 'tools': ['Read', 'Grep', 'Glob', 'Bash'],
        'disallowedTools': ['Write', 'Edit', 'NotebookEdit']}}
for case in ('default-readonly-tools', 'custom-readonly-tools'):
    for suffix in ('wrapper.json', 'stderr.txt', 'command.json', 'exit.txt'):
        if (OUT / (case + '.' + suffix)).exists():
            raise SystemExit('Existing diagnostic; no retry: ' + case)
for case in ('default-readonly-tools', 'custom-readonly-tools'):
    args = BASE[:]
    if case == 'custom-readonly-tools':
        args += ['--agents', json.dumps(ROLE), '--agent', 'transport-probe']
    args += ['--', PROMPT]
    with (OUT / (case + '.command.json')).open('x') as f:
        json.dump(args, f, indent=2)
    print('Starting unreserved diagnostic: ' + case, flush=True)
    with (OUT / (case + '.wrapper.json')).open('xb') as out, (OUT / (case + '.stderr.txt')).open('xb') as err:
        run = subprocess.run(args, cwd=ROOT, stdout=out, stderr=err)
    with (OUT / (case + '.exit.txt')).open('x') as f:
        f.write(str(run.returncode) + '\n')
    print(case + ': exit ' + str(run.returncode), flush=True)
    if run.returncode:
        raise SystemExit('Diagnostic refused; no further launch')
