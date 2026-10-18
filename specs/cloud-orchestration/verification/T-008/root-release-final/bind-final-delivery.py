from pathlib import Path
import json,re,hashlib
r=Path('/workspace/sdd-forge');d=r/'specs/cloud-orchestration/verification/T-008/root-release-final';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();rows=lambda p:dict(re.findall(r'^\| `([^`]+)` \| `([a-f0-9]{64})` \|$',p.read_text(),re.M))
reports=['T-008-release-fixes.md','T-008-ci-time-budget.md','T-008-platform-test-fixes.md','T-008-mcp-report-scan-fix.md','T-008-mcp-fixture-path-fix.md','T-008-posix-harness-boundary-fix.md'];sources={}
for index,name in enumerate(reports,2):
 p=r/'reports/implementation/cloud-orchestration'/name;snapshot=r/f'specs/cloud-orchestration/verification/T-008/attempt-{index}/implementation-report-snapshot.md';assert p.read_bytes()==snapshot.read_bytes()
 for path,h in rows(p).items():
  if (r/path).is_file() and sha(r/path)==h:sources[path]={'report':str(p.relative_to(r)),'report_sha256':sha(p),'snapshot':str(snapshot.relative_to(r))}
canonical=r/'reports/implementation/cloud-orchestration/T-008.md';differences=[];original=rows(canonical)
for path,h in original.items():
 current=sha(r/path)
 if current!=h:
  source=sources.get(path)
  if path=='reports/verification/cloud-orchestration-release.md':source={'root_audit_binding':'specs/cloud-orchestration/verification/T-008/root-release-final/release-audit-binding.json'}
  assert source is not None,path
  differences.append({'path':path,'original_sha256':h,'current_sha256':current,'superseding_evidence':source})
(d/'implementation-output-supersession.json').write_text(json.dumps({'canonical_report':str(canonical.relative_to(r)),'canonical_report_sha256':sha(canonical),'original_outputs':len(original),'unchanged_outputs':len(original)-len(differences),'differences':differences,'policy':'Frozen original and six repair reports preserved byte-for-byte. Current source and root publication evidence explicitly supersede listed historical output hashes.'},indent=2)+'\n');print('Bound',len(differences),'changed output hashes')
