rtk proxy python3 -B -X pycache_prefix=/private/tmp/issue423-t002-evaluator-01a110a1-5589-7501-b440-8926b897e0a2/pycache - <<'PY'
import importlib.util,pathlib,json
root=pathlib.Path('/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge')
p=root/'specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py'
spec=importlib.util.spec_from_file_location('boundary_tests',p); mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod); mod.REPO_ROOT=root
case=mod.CapabilityRegistryProviderNeutralityTests(); case.setUp()
for boundary in ('trigger','conditional'):
 for value in ({'azure':True},{'metadata':{'aws':False}},{'metadata':{'name':'azure'}}):
  registry=case._predicate_registry(value,boundary)
  diagnostics=[]
  ok=case.registry_mod.check_g_provider_name_contamination(registry,case.provider_terms,diagnostics)
  print(json.dumps({'boundary':boundary,'value':value,'schema_errors':[],'check_g_accepted':ok,'diagnostics':diagnostics}))
for rel,a,b in [('plugins/sdd-quality-loop/scripts/validate-capability-registry.py',135,173),('specs/sdd-domain-multitarget/tasks.md',33,50),('specs/sdd-domain-multitarget/requirements.md',130,147)]:
 print(rel)
 lines=(root/rel).read_text().splitlines()
 for i in range(a-1,b):print(f'{i+1}: {lines[i]}')
PY
