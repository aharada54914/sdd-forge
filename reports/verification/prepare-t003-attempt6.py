"""Freeze current admitted inputs for one fresh T-003 implementation context."""
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

root = Path(__file__).resolve().parents[2]
prefix = 'specs/sdd-domain-multitarget/verification/T-003/attempt6-20261016'
out = root / prefix
if out.exists():
    raise SystemExit('Refusing to overwrite existing attempt6 inputs')
old = json.loads((root / 'specs/sdd-domain-multitarget/verification/T-003/task-input-manifest-c43e18b9f2a7.json').read_text())
outputs = [
    'plugins/sdd-quality-loop/scripts/evaluate-selected-plan.py',
    'plugins/sdd-quality-loop/skills/quality-gate/SKILL.md',
    'contracts/selected-verification-plan.schema.json',
    'tests/sdd-domain-multitarget-T-003.tests.py',
    'tests/fixtures/sdd-domain-multitarget/T-003/',
    'tests/run-all.sh', 'tests/run-all.ps1',
    'reports/implementation/sdd-domain-multitarget/T-003-attempt6.md',
    prefix + '/output/',
]
paths = list(dict.fromkeys([x['path'] for x in old['allowed_inputs']] + [
    'plugins/sdd-quality-loop/skills/quality-gate/SKILL.md',
    'reports/quality-gate/20261014-sdd-domain-multitarget-T-002.md',
    'reports/verification/issue423-t002-completion-20261014.md',
    'reports/implementation/sdd-domain-multitarget/T-003-preflight-handoff-20261016-fresh.md',
]))
contents = {}
for relative in paths:
    source = root / relative
    if not source.is_file() or source.is_symlink():
        raise SystemExit('Missing or unsafe input: ' + relative)
    contents[relative] = source.read_bytes()
out.mkdir(parents=True)
mapping, inputs = {}, []
for relative, content in contents.items():
    admitted = relative
    if any(relative == p.rstrip('/') or relative.startswith(p.rstrip('/') + '/') for p in outputs):
        admitted = prefix + '/baseline/' + relative
        target = root / admitted
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        mapping[relative] = admitted
    inputs.append({'path': admitted, 'sha256': hashlib.sha256(content).hexdigest()})
identity = '01a1409f-5fa6-7ef0-9d05-040b8b5e0649'
manifest = dict(old, run_id='t003-20261016-attempt6', session_id=identity,
    agent_instance_id=identity, model='gpt-6-astra', estimated_cost_per_attempt_usd='5.00',
    cost_estimate_source='rough planning estimate only; not billing evidence',
    cost_estimate_timestamp=datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    allowed_inputs=inputs, allowed_outputs=outputs)
(out / 'baseline-map.json').write_text(json.dumps(mapping, indent=2) + '\n')
(out / 'task-input-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
(out / 'owner-dirty-before.txt').write_bytes(subprocess.check_output(['git', 'status', '--short'], cwd=root))
(out / 'owner-head.txt').write_bytes(subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root))
print(out / 'task-input-manifest.json')
print('Inputs:', len(inputs), '; baseline mappings:', len(mapping))
