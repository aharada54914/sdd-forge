import hashlib
import json
import re
from pathlib import Path

out=Path(__file__).resolve().parent
summary=json.loads((out/'summary.json').read_text())
before=json.loads((out/'comparison-before.json').read_text())
prior=json.loads((out.parent/'parent-binding-20261010/comparison-after.json').read_text())
old={r['path']:r['current_owner_sha256'] for r in prior['rows']}
summary['prior_current_binding_matches_all_620']=all(old.get(r['path'])==r['current_sha256'] for r in before['rows'])
summary['current_matches_attempt6']=before['matching']
summary['historical_copy_hashes_match']=all(r['historical_actual_sha256']==r['historical_sha256'] for r in before['rows'])
for item in summary['results']:
    log=(out/(item['suite']+'.log')).read_text()
    item['summaries']=re.findall(r'^(?:Ran \d+ tests.*|PASS:.*|.*"passed": \d+.*|.*"failed": \d+.*)$',log,re.M)
    item['skip_lines']=[line for line in log.splitlines() if re.search(r'\bSKIP(?:PED)?\b',line)]
summary['evidence_sha256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest()
    for p in sorted(out.iterdir()) if p.is_file() and p.name!='binding-summary.json'}
(out/'binding-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k!='evidence_sha256'},indent=2))
