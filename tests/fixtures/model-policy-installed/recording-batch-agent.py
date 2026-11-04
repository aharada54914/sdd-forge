"""Native Agent boundary fixture only. Not a batch worker or provider client."""
import json
from pathlib import Path
import sys

definitions = json.loads(Path(sys.argv[1]).read_text())
call = json.load(sys.stdin)
if set(call) != {'subagent_type', 'prompt'} or call['subagent_type'] not in definitions:
    raise SystemExit('fixture rejects omitted custom type or per-call aliases/defaults')
definition = definitions[call['subagent_type']]
if set(definition) != {'model', 'effort', 'prompt', 'description'}:
    raise SystemExit('fixture rejects missing native controls or tool/permission replacement')
if definition['model'] in ('sonnet', 'opus', 'haiku', 'fable'):
    raise SystemExit('fixture rejects alias model')
record = {'event': 'allocation-fixture-only', 'call': call, 'definition': definition,
          'agentId': 'fixture-non-uuid-agent', 'backend_identity': 'unproven'}
print(json.dumps(record))
