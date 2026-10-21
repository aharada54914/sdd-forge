from pathlib import Path
import hashlib,importlib.util,json,sys
ROOT=Path('/workspace/sdd-forge/specs/ci-model-modernization/verification/T-010/attempt-3');BASE=ROOT/'blinded-judges-v2';spec=importlib.util.spec_from_file_location('fixed',Path('/workspace/.task-scratch/ci-model-modernization/t010-judge-v2.py'));module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
def origin(doc,quote):
 pos=doc['content'].find(quote)
 return None if pos<0 else {'path':doc['path'],'sha256':doc['sha256'],'line':doc['content'][:pos].count('\n')+1,'quote':quote}
def run(domain):
 target=BASE/domain
 if not(target/'judge-response.json').exists():return
 bundle=json.loads((target/'input.json').read_text());response=json.loads((target/'judge-response.json').read_text());schema=json.loads((target/'response.schema.json').read_text());errors=[];origins=[];checked=0
 try:module.schema(response,schema,schema)
 except Exception as e:errors.append('full-original-schema:'+str(e))
 subs={x['submission_id']:x for x in bundle['submissions']};assert response['domain']==domain
 if {s['submission_id']for s in response['submissions']}!=set(subs)or len(response['submissions'])!=len(subs):errors.append('submission-ids-mismatch')
 docs={d['path']:d for d in bundle['rubric_documents']};docs.update({d['path']:d for f in bundle['fixtures']for d in f['files']});request=module.document('natural_request',bundle['natural_request']);authorities=bundle['rubric_documents']+[request]+[d for f in bundle['fixtures']for d in f['files']if d['path'].endswith(('/README.md','/procedure.md'))]
 mapping_doc=next(d for d in bundle['rubric_documents']if d['path']==('criteria/skill-1.md'if domain=='skill-command-plan'else 'criteria/model-rubric.md'));tag={'implementation':'| Implementation |','review':'| Review |','investigation':'| Investigation |','skill-command-plan':'Required deterministic artifact checks'}[domain];mapline=next((i,line)for i,line in enumerate(mapping_doc['content'].splitlines(),1)if tag in line);applicable={'path':mapping_doc['path'],'sha256':mapping_doc['sha256'],'line':mapline[0],'quote':mapline[1]}
 def criterion(quote):
  found=next((o for d in authorities if(o:=origin(d,quote))),None)
  if found is None:errors.append('criterion-not-in-original-authority:'+quote)
  else:origins.append({'criterion_quote':quote,'exact_original_origin':found,'applicable_frozen_rubric_criterion':applicable})
 def evidence(e):
  nonlocal checked
  checked+=1;available={k:d['content']for k,d in docs.items()};sid=e['submission_id']
  if sid is not None:
   if sid not in subs:errors.append('unknown-evidence-submission:'+sid);return
   s=subs[sid];available.update({d['path']:d['content']for d in s['artifacts']});available.update({'answer':s['answer'],'answer.txt':s['answer'],'deterministic_score.receipt':s['deterministic_score']['receipt'],'deterministic-score.json':s['deterministic_score']['receipt']});available.update({'controller_observations.'+k:json.dumps(v)for k,v in s['controller_observations'].items()})
  path=e['path'];text=available.get(path)
  if path.startswith('/'):
   try:
    parts=[p.replace('~1','/').replace('~0','~')for p in path.split('/')[1:]];value=bundle
    if len(parts)>1 and parts[0]=='submissions' and sid is not None:assert bundle['submissions'][int(parts[1])]['submission_id']==sid
    for part in parts:value=value[int(part)]if isinstance(value,list)else value[part]
    assert isinstance(value,(str,bool,int,float))or value is None
    text=value if isinstance(value,str)else json.dumps(value)
   except (KeyError,IndexError,ValueError,AssertionError):text=None
  if text is None:errors.append('unknown-evidence-path:'+path);return
  lines=text.splitlines();line=e['line'];quote=e['quote'];tail='\n'.join(lines[line-1:])if 1<=line<=len(lines)else '';pos=tail.find(quote)
  if pos<0 or pos>len(lines[line-1])if 1<=line<=len(lines)else True:errors.append('inexact-or-wrong-line:'+json.dumps(e))
 for s in response['submissions']:
  if s['submission_id']not in subs:continue
  if not subs[s['submission_id']]['deterministic_score']['hard_pass']and not s['deterministic_failure_preserved']:errors.append('deterministic-failure-waived:'+s['submission_id'])
  for c in s['criteria']:
   criterion(c['criterion_quote'])
   for e in c['evidence']:evidence(e)
 for r in response['material_regressions']:
  if r['reference_id']not in subs or r['affected_id']not in subs or r['reference_id']==r['affected_id']:errors.append('invalid-regression-ids')
  criterion(r['criterion_quote'])
  for e in r['evidence']:evidence(e)
 result={'validation_version':'original-contract-and-schema-field-resolution/v1','input_sha256':module.h(target/'input.json'),'response_sha256':module.h(target/'judge-response.json'),'full_original_schema_sha256':module.h(target/'response.schema.json'),'schema_and_proof_checks_pass':not errors,'errors':errors,'criterion_origins':origins,'exact_anchored_citations_checked':checked,'resolution':'Exact schema-defined supplied string/scalar fields resolve as logical documents; contiguous quote may begin within cited line. No fuzzy matching, wrong lines, inferred/generated criteria or candidate-response edits.','submissions':[{ 'submission_id':s['submission_id'],'all_semantic_criteria_satisfied':all(c['satisfied']and not c['uncertain']for c in s['criteria']),'deterministic_failure_preserved':s['deterministic_failure_preserved'],'deterministic_hard_pass':subs[s['submission_id']]['deterministic_score']['hard_pass']}for s in response['submissions']if s['submission_id']in subs]}
 (target/'validated-judge-evidence.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'domain':domain,'valid':not errors,'errors':errors[:3],'citations_checked':checked,'submissions':result['submissions']}))
for domain in ['implementation','review','investigation','skill-command-plan']:run(domain)
