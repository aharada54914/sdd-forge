"""Local shape/consumer/mismatch checks, not hosted omission or activation proof."""
import ast
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import jsonschema

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
BEFORE = Path('/workspace/.task-scratch/ci-model-modernization/t011-readiness-implementation/before')

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

F = load('t011_fixtures', ROOT / 'tests/verification-ci-plan.tests.py')
P, W = F.IMPACT, F.W
fixture = F.OmissionReadinessTests()
records = []
for mutation in ('unknown-job-condition', 'missing-matrix', 'or-condition', 'missing-output', 'wrong-output', 'unknown-step-condition', 'undeclared-raw-setup'):
    catalog, workflow, job = fixture.fixture(raw=True)
    catalog['impact']['non_suite_steps'] = [{'job':job,'step':'Install Claude Code CLI','kind':'setup'}]
    condition = "needs.ci-plan.outputs.run_cli_hook_enforcement == 'true'"
    if mutation == 'unknown-job-condition':
        workflow['jobs'][job]['if'] = "needs.external.outputs.ready == 'true'"
    elif mutation == 'missing-matrix':
        workflow['jobs'][job]['if'] = condition + " && matrix.missing == 'yes'"
    elif mutation == 'or-condition':
        workflow['jobs'][job]['if'] = condition + ' || false'
    elif mutation == 'missing-output':
        del workflow['jobs']['ci-plan']['outputs']['run_cli_hook_enforcement']
    elif mutation == 'wrong-output':
        workflow['jobs']['ci-plan']['outputs']['run_cli_hook_enforcement'] = 'true'
    elif mutation == 'unknown-step-condition':
        workflow['jobs'][job]['steps'][0]['if'] = "needs.external.outputs.ready == 'true'"
    else:
        workflow['jobs'][job]['steps'].insert(1, {'name':'Other raw setup','run':'npm ci'})
    P.rules(catalog, workflow)
    full, selected = fixture.select(catalog, workflow)
    raw = [o for o in full if o['job'] == job and not o['suites']]
    selected_ids = {o['id'] for o in selected}
    expected = [o for o in raw if mutation != 'undeclared-raw-setup' or o['step'] == 'Other raw setup']
    assert expected and all(o['id'] in selected_ids for o in expected), mutation
    records.append({'mutation':mutation,'required_raw_steps':[o['step'] for o in expected],'all_retained':True})

catalog = json.loads((ROOT / 'tests/verification-catalog.json').read_text())
old_catalog = json.loads((BEFORE / 'tests/verification-catalog.json').read_text())
probe = copy.deepcopy(catalog)
assert probe['impact']['non_suite_steps'] == [{'job':'cli-hook-enforcement','step':'Install Claude Code CLI','kind':'setup'}]
probe['impact']['non_suite_steps'] = []
assert probe == old_catalog
schema = json.loads((ROOT / 'contracts/verification-ci-plan.schema.json').read_text())
old_schema = json.loads((BEFORE / 'contracts/verification-ci-plan.schema.json').read_text())
probe = copy.deepcopy(schema)
probe['$defs']['impactRules']['properties']['non_suite_steps']['items']['properties']['kind']['enum'].remove('setup')
assert probe == old_schema
jsonschema.Draft202012Validator.check_schema(schema)
jsonschema.validate(catalog['impact'], schema['$defs']['impactRules'])
for bad_kind in ('SETUP','unknown'):
    bad = copy.deepcopy(catalog['impact']); bad['non_suite_steps'][0]['kind'] = bad_kind
    try:
        jsonschema.validate(bad,schema['$defs']['impactRules'])
    except jsonschema.ValidationError:
        pass
    else:
        raise AssertionError('schema accepted ' + bad_kind)

def definitions(path):
    return {n.name:ast.dump(n,include_attributes=False) for n in ast.parse(path.read_text()).body if isinstance(n,(ast.FunctionDef,ast.ClassDef))}
old_defs = definitions(BEFORE / 'tests/verification-impact.py')
new_defs = definitions(ROOT / 'tests/verification-impact.py')
assert old_defs.keys() == new_defs.keys()
changed = [n for n in old_defs if old_defs[n] != new_defs[n]]
assert changed == ['rules','selected_obligations']
assert (ROOT/'tests/verification-workflow.py').read_bytes() == (BEFORE/'tests/verification-workflow.py').read_bytes()
assert (ROOT/'.github/workflows/test.yml').read_bytes() == (BEFORE/'.github/workflows/test.yml').read_bytes()
workflow = W.load_workflow(ROOT/'.github/workflows/test.yml')
P.rules(catalog,workflow)
full = W.plan_obligations(workflow,catalog)
chosen = P.selected_obligations(catalog['impact']['categories'],catalog,workflow,full)
full_groups, selected_groups = {o['job'] for o in full}, {o['job'] for o in chosen}
assert full_groups-selected_groups == {'cli-hook-enforcement'}
assert all(not c['active'] and c['evidence'] is None for c in catalog['impact']['categories'])
old = load('t011_before',BEFORE/'tests/verification-impact.py')
old.workflow_module = lambda: W
baseline_chosen = old.selected_obligations(old_catalog['impact']['categories'],old_catalog,workflow,full)
assert len(baseline_chosen) == len(full)
for job in ('mcp-tests','cloud-native'):
    raw = [o for o in full if o['job']==job and not o['suites']]
    assert raw and all(o['id'] in {s['id'] for s in chosen} for o in raw)
record = {'label':'ACTUAL_LOCAL_ENUMERATION_AND_MISMATCH_CHECKS_NOT_HOSTED_EXECUTION', 'new_field_mutations':records,'catalog_only_exact_setup_added':True,'all_preexisting_catalog_metadata_including_T009_dependencies_preserved':True,'schema_only_setup_enum_added':True,'schema_validated':True,'schema_unknown_and_case_kind_rejected':True,'planner_changed_definitions':changed,'workflow_and_interpreter_unchanged':True,'inactive_categories_preserved':True,'full':len(full),'baseline_selected':len(baseline_chosen),'candidate_selected':len(chosen),'candidate_planned_omissions':len(full)-len(chosen),'fully_omitted_groups':sorted(full_groups-selected_groups),'mcp_cloud_raw_setup_retained':True,'source_pins':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ('tests/verification-impact.py','tests/verification-catalog.json','contracts/verification-ci-plan.schema.json','tests/verification-ci-plan.tests.py')}}
(HERE/'readiness-counterparts.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record,indent=2))
