"""Unreserved historical-receipt diagnostic; never a review or identity proof."""
from pathlib import Path
import hashlib
import json
import subprocess
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
patch = (HERE / 'transport.candidate.patch').read_text()
source = '\n'.join(line[1:] for line in patch.splitlines()
                   if line.startswith('+') and not line.startswith('+++')) + '\n'
scope = {'__name__': 'isolated_transport_candidate'}
exec(compile(source, 'transport.candidate.py', 'exec'), scope)
invocation = ROOT / 'reports/review-context/epic-195-a7-compatibility-spec-a19r1-a-invocation.json'
receipt = ROOT / 'reports/spec-review/epic-195-a7-compatibility/attempt-19/round-1/reviewer-a-reservation-receipt.txt'
data = json.loads(invocation.read_bytes())
control = scope['receipt_control'](data, receipt.read_text())
prompt = scope['expected_prompt'](ROOT, invocation, receipt)
session = str(uuid.uuid4())
run = HERE / ('unreserved-' + session)
run.mkdir()
(run / 'prompt.txt').write_bytes(prompt)
role = {
    'receipt-diagnostic': {
        'description': 'Unreserved historical receipt arithmetic diagnostic only.',
        'prompt': 'This is an unreserved diagnostic, not a formal reviewer. The supplied fixed launch prompt refers to a historical consumed identity; do not claim it as your session, reserve, resume or emit a review verdict. Read only its invocation and boundary control document. Independently reconstruct the ordered inputs text. Before the first Bash call, state the current request and exactly what this hash command verifies. Execute ONLY the first provided literal hash command, wait for successful output, then reconstruct record_text with the actual observed input digest. Execute ONLY the second provided literal hash command after comparing it with this reconstruction. No other Bash command is permitted: no Python, variable shell, comparison command, additional helper or altered command. If a hook explicitly requires presenting facts, satisfy that condition and retry the identical operation only; any other refusal means stop blocked. Compare the observed record digest to the historical receipt and a one-character-changed receipt by reasoning, not another command; identify this as a reasoned comparison, not an executed negative test. Stop before substantive review. Return JSON with diagnostic_only=true, observed_input_digest, observed_record_digest, receipt_equal, reasoned_changed_receipt_equal, and both tool execution results in order. Caller-provided hashes are not execution evidence. No review verdict. You are read-only.',
        'tools': ['Read', 'Bash']}}
(run / 'role.json').write_text(json.dumps(role))
commands = control['hash_commands']
boundary = 'plugins/sdd-review-loop/references/review-context-boundary.md'
permissions = ['Read', 'Bash(rtk proxy shasum -a 256 -- ' + str(invocation.relative_to(ROOT)) + ')',
               'Bash(rtk proxy shasum -a 256 -- ' + boundary + ')']
permissions += ['Bash(' + command + ')' for command in commands]
permissions.append('Bash(rtk proxy shasum -a 256)')
args = ['rtk', 'proxy', 'claude', '-p', '--session-id', session,
        '--output-format', 'json', '--model', 'sonnet', '--agents', str(run / 'role.json'),
        '--agent', 'receipt-diagnostic', '--tools', 'Read,Bash', '--allowedTools', *permissions,
        '--disallowedTools', 'Write', 'Edit', 'NotebookEdit']
print('UNRESERVED_DIAGNOSTIC', run, flush=True)
result = subprocess.run(args, cwd=ROOT, input=prompt, capture_output=True, timeout=240)
(run / 'wrapper.json').write_bytes(result.stdout)
(run / 'stderr.txt').write_bytes(result.stderr)
print('EXIT', result.returncode, flush=True)
if result.stdout:
    wrapper = json.loads(result.stdout)
    print(wrapper.get('result'), flush=True)
raise SystemExit(result.returncode)
