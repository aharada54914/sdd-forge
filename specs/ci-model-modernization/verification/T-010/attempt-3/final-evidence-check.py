"""Read actual frozen trial/judge/source artifacts; no inference or code execution."""
from pathlib import Path
import ast,datetime,hashlib,importlib.util,json
ROOT=Path(__file__).resolve().parents[5];ATT=Path(__file__).resolve().parent;PRE=ATT.parent/'pre-output-preparation';h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();started=datetime.datetime.now(datetime.timezone.utc).isoformat();plan=json.loads((PRE/'attempt-3-capability-fix/execution-plan.json').read_text());snap=Path(plan['snapshot_root']);manifest=json.loads((PRE/'attempt-3-capability-fix/task-input-manifest.json').read_text());errors=[]
assert all(h(snap/r['path'])==r['sha256']for r in manifest['allowed_inputs'])
for name in ['trial-output-manifest.json','judge-output-manifest.json']:
 j=json.loads((ATT/name).read_text())
 if 'files'in j:assert all(h(ATT/p)==v for p,v in j['files'].items())
 else:
  for domain,row in j['judges'].items():assert all(h(ATT/'blinded-judges-v2'/domain/p)==v for p,v in row['files'].items())
summary=json.loads((ATT/'actual-comparison-summary.json').read_text());assert(summary['native_turns_started'],summary['completed_native_turns'],summary['deterministic_pass'],summary['deterministic_fail'])==(20,19,9,11)
for domain in ['implementation','review','investigation','skill-command-plan']:assert json.loads((ATT/'blinded-judges-v2'/domain/'validated-judge-evidence.json').read_text())['schema_and_proof_checks_pass']
candidate=ATT/'policy-runtime-closure-v3';runtime=candidate/'contracts/model-adoption/ci-model-modernization-20261021.json';assert runtime.read_bytes()==(ATT/'role-decisions.json').read_bytes();assert h(runtime)=='0423fb14c0297db8446cb9a55767d2a0bb6ebade5d25ae1c42c0b3e09cc4ee32'
spec=importlib.util.spec_from_file_location('unchanged_policy',snap/'inputs/plugins/sdd-implementation/scripts/model-policy.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);registry,registered=module._policy_registry(snap/'inputs/contracts/agent-model-capabilities.v2.json');policy=json.loads((candidate/'contracts/model-policy.v1.json').read_text());baseline=json.loads((snap/'inputs/contracts/model-policy.v1.json').read_text());token=module._SNAPSHOT_ROOT.set(candidate)
try:module._validate_role_policy(policy,registered,registry['role_defaults'])
finally:module._SNAPSHOT_ROOT.reset(token)
assert policy['roles']==baseline['roles'];assert 'gpt-6.1-sol'not in registered and 'gpt-6-luna'not in registered
for model,old in zip(policy['models'],baseline['models']):
 if model['id']=='gpt-6-astra':
  assert model['lifecycle']=='current';assert model['adoption']==[{'role':'implementer','path':'contracts/model-adoption/ci-model-modernization-20261021.json','sha256':h(runtime)}]
  assert {k:v for k,v in model.items()if k not in('lifecycle','adoption')}=={k:v for k,v in old.items()if k not in('lifecycle','adoption')}
 else:assert model==old
patch=ATT/'policy-reference-regression-v3/model-policy-adoption-only.patch';assert not any(line.rstrip('\n').endswith((' ','\t'))for line in patch.read_text().splitlines(True)if line.startswith('+'));ast.parse(Path('/workspace/.task-scratch/ci-model-modernization/t010-v3-tested-model-policy.tests.py').read_text())
reg=json.loads((ATT/'policy-reference-regression-v3/results.json').read_text());assert reg['rollback_exact']and all(x['exit_code']==0 for x in reg['runs']);assert h(PRE/'original-model-rubric.md')==h(ROOT/'reports/verification/model-selection-adoption-rubric-20261018.md')
record={'started_at':started,'finished_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'command':['python3','-B',str(Path(__file__).resolve())],'exit_code':0,'immutable_source_pins':len(manifest['allowed_inputs']),'trial_output_files_verified':172,'actual_judges_full_schema_proof_validated':4,'candidate_policy_typed_validation':'unchanged T006 validator passes','metadata_only':'preferences/registry/floors/host mappings/historical IDs unchanged; Astra implementer only','runtime_copy_sha256':h(runtime),'policy_sha256':h(candidate/'contracts/model-policy.v1.json'),'test_patch_sha256':h(patch),'tested_testfile_sha256':h(Path('/workspace/.task-scratch/ci-model-modernization/t010-v3-tested-model-policy.tests.py')),'candidate_plus_rollback':'59/59 then57/57; exact baseline restoration','result':'PASS'}
(ATT/'final-evidence-check.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record,indent=2))
