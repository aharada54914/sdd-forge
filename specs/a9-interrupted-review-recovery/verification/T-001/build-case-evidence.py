from pathlib import Path
import json,re,collections
root=Path.cwd();e=root/'specs/a9-interrupted-review-recovery/verification/T-001';inventory=json.loads((e/'case-inventory.json').read_text())
rows=[]
for runtime in ('bash','powershell'):
 final={};red=collections.defaultdict(list);baseline=collections.defaultdict(list)
 for file in e.glob('*.log'):
  if file.name.startswith('red-'):bucket=red
  elif 'baseline' in file.name:bucket=baseline
  else:continue
  for line in file.read_text().splitlines():
   m=re.match(r'(PASS|FAIL) '+runtime+r' (.+?) exit=(\d+)',line)
   if m and ((bucket is red and m[1]=='FAIL') or (bucket is baseline and m[1]=='PASS')):bucket[m[2]].append(file.name)
 initial=(e/f'red-{runtime}.log').read_text();original_not_run=set(re.findall(r'^NOT_RUN '+runtime+r' (.*?) admission absent$',initial,re.M))
 for line in (e/f'reviewed-{runtime}.log').read_text().splitlines():
  m=re.match(r'(PASS|FAIL) '+runtime+r' (.+?) exit=(\d+)',line)
  if m:final[m[2]]={'status':m[1],'exit':int(m[3])}
 for case in inventory['controls']+[r['name'] for r in inventory['cases']]:
  rows.append(dict(runtime=runtime,name=case,original_checkpoint='NOT_RUN' if case in original_not_run else ('real Red exit90' if case=='CONTROL::valid-interrupted-admission' else 'unchanged PASS' if case in inventory['controls'] else 'not present at original checkpoint'),genuine_red_logs=red[case],explicit_baseline_logs=baseline[case],final=final.get(case,{'status':'missing'}),interpretation='real Red-to-Green' if red[case] else 'existing-pass baseline; no individual Red claimed' if baseline[case] or case in inventory['controls'] else 'retrospective Green; no individual Red claimed'))
assert len(rows)==2*(inventory['concrete_variants_per_runtime']+3)
assert all(row['final']['status']=='PASS' for row in rows)
result={'schema':'a9-t001-case-evidence/v1','rows':rows,'counts_by_runtime':{runtime:dict(collections.Counter(r['interpretation'] for r in rows if r['runtime']==runtime)) for runtime in ('bash','powershell')},'procedural_unexecuted':['TEST-041','TEST-042'],'warning':'A shared missing-admission Red does not make the 530 original NOT_RUN variants individually Red. The frozen all-variants Red-then-Green DoneWhen is not satisfied by this evidence. No retrospective Green is represented as historical Red.'}
(e/'case-evidence.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result['counts_by_runtime']))
