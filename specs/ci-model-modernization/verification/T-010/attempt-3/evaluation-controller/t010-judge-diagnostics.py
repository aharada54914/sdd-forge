from pathlib import Path
import json
BASE=Path('/workspace/sdd-forge/specs/ci-model-modernization/verification/T-010/attempt-3/blinded-judges-v2')
for domain in ['implementation','review','investigation','skill-command-plan']:
 b=BASE/domain
 if not(b/'judge-response.json').exists():continue
 bundle=json.loads((b/'input.json').read_text());r=json.loads((b/'judge-response.json').read_text());subs={s['submission_id']:s for s in bundle['submissions']};rubric='\n'.join(d['content']for d in bundle['rubric_documents']);contract=bundle['natural_request']+'\n'+'\n'.join(d['content']for f in bundle['fixtures']for d in f['files']);globaldocs={d['path']:d['content']for d in bundle['rubric_documents']};globaldocs.update({d['path']:d['content']for f in bundle['fixtures']for d in f['files']});badcriteria=[];badquotes=[];count=0
 for row in r['submissions']:
  for c in row['criteria']:
   if c['criterion_quote']not in rubric:badcriteria.append({'submission_id':row['submission_id'],'criterion_quote':c['criterion_quote'],'exact_in_original_fixture_or_request':c['criterion_quote']in contract})
 for row in r['submissions']+r['material_regressions']:
  entries=[e for c in row['criteria']for e in c['evidence']]if 'criteria'in row else row['evidence']
  for e in entries:
   count+=1;docs=dict(globaldocs);s=subs.get(e['submission_id'])
   if s:docs.update({d['path']:d['content']for d in s['artifacts']});docs['answer.txt']=s['answer'];docs['deterministic-score.json']=s['deterministic_score']['receipt']
   lines=docs.get(e['path'],'').splitlines();span='\n'.join(lines[e['line']-1:e['line']-1+len(e['quote'].splitlines())]);valid=1<=e['line']<=len(lines)and e['quote']in(span,span.strip())
   if not valid:badquotes.append({'citation':e,'actual_span':span})
 result={'exact_contiguous_span_citations_checked':count,'invalid_citations':badquotes,'criterion_quotes_outside_rubric_documents':badcriteria,'all_additional_criterion_quotes_exact_in_frozen_contract_or_request':all(x['exact_in_original_fixture_or_request']for x in badcriteria),'no_response_or_input_changes':True};(b/'judge-validation-diagnostics.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'domain':domain,'cites':count,'invalid_cites':len(badquotes),'criteria_outside_rubric':len(badcriteria),'all_quoted_in_contract':result['all_additional_criterion_quotes_exact_in_frozen_contract_or_request'],'first_invalid':badquotes[:1]}))
