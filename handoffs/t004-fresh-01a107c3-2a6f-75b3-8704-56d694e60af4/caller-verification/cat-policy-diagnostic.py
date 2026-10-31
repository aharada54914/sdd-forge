"""Guard-decision diagnostic only: payload commands are never executed."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

installed = Path('/Users/jrmag/.codex/plugins/cache/sdd-plugins/sdd-quality-loop/1.18.0/scripts/sdd-hook-guard.py')
candidate = Path('/private/tmp/sdd-guard-main.3JEj4I/repo/plugins/sdd-quality-loop/scripts/sdd-hook-guard.py')
inputs = Path('/private/tmp/sdd-guard-main.3JEj4I/repo/reports/verification/read-policy-regression-inputs-20261004.json')
data = json.loads(inputs.read_text())
display = next(row for row in data['shell_forms'] if row['id'] == 'D01')
role = data['categories']['role']
exact = 'rtk proxy cat .codex/agents/sdd-investigator.toml .codex/agents/sdd-evaluator.toml'
cases = [
    ('observed-two-role-read', exact, 0),
    ('saved-D01-direct-role', display['command'].format(path=role), 0),
    ('saved-D01-proxy-role', 'rtk proxy ' + display['command'].format(path=role), 0),
    ('negative-redirect', 'rtk proxy cat docs/fixture.txt > ' + role, 2),
    ('negative-compound', 'rtk proxy cat ' + role + ' && printf x > ' + role, 2),
]
failures = 0
for label, guard in [('installed', installed), ('current-536-working-tree', candidate)]:
    before = hashlib.sha256(guard.read_bytes()).hexdigest()
    print(json.dumps({'guard': label, 'sha256': before}))
    for case, command, expected in cases:
        payload = {'tool_name': 'exec_command', 'tool_input': {'command': command}}
        # Run only the existing guard; no shell and no payload executable launch.
        result = subprocess.run(['rtk', 'proxy', sys.executable, '-B', str(guard)],
                                input=json.dumps(payload), text=True, capture_output=True, timeout=20)
        okay = result.returncode == expected
        failures += not okay
        print(json.dumps({'guard': label, 'case': case, 'input_command_data': command,
                          'expected_policy_exit': expected, 'actual_exit': result.returncode,
                          'policy_match': okay, 'stdout': result.stdout, 'stderr': result.stderr}, ensure_ascii=False))
    assert hashlib.sha256(guard.read_bytes()).hexdigest() == before
print(json.dumps({'checks': len(cases) * 2, 'policy_mismatches': failures,
                  'payload_commands_executed': False, 'installed_or_source_modified': False}))
sys.exit(1 if failures else 0)
