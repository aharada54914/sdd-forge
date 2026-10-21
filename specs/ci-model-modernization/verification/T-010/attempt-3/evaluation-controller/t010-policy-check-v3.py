from pathlib import Path
import copy,datetime,difflib,hashlib,importlib.util,json,os,shutil,subprocess,tempfile,sys
ROOT=Path('/workspace/sdd-forge');ATT=ROOT/'specs/ci-model-modernization/verification/T-010/attempt-3';SNAP=Path('/workspace/.task-scratch/ci-model-modernization/ci-t010-attempt3-x6jpw02p/snapshot/inputs');OUT=ATT/'policy-reference-regression-v3';OUT.mkdir(exist_ok=True);work=Path(tempfile.mkdtemp(prefix='t010-policy-',dir='/workspace/.task-scratch/ci-model-modernization'));checkout=work/'checkout';shutil.copytree(SNAP,checkout)
for d in [checkout]+list(checkout.rglob('*')):
 d.chmod(0o755 if d.is_dir()else 0o644)
native_tests=(ROOT/'tests/model-policy.tests.py').read_bytes();assert hashlib.sha256(native_tests).hexdigest()=='24223de0acb981651e03b71a4e5d8d6a6d25aa9b8e8abac6cd417a8366756243';(checkout/'tests/model-policy.tests.py').write_bytes(native_tests)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();old=(checkout/'tests/model-policy.tests.py').read_text();start=old.index('    def test_shipped_contracts_have_actual_schemas_and_no_unproved_adoption(self):');end=old.index('\n\nif __name__',start);block=old[start:end];block=block.replace('test_shipped_contracts_have_actual_schemas_and_no_unproved_adoption','test_shipped_contracts_have_actual_schemas_and_reviewed_adoption');block=block.replace("        for model in policy['models']:\n            self.assertEqual(model['adoption'], [], 'T-006 must not invent new controlled adoption evidence')", """        expected_path = 'contracts/model-adoption/ci-model-modernization-20261021.json'
        expected_hash = '0423fb14c0297db8446cb9a55767d2a0bb6ebade5d25ae1c42c0b3e09cc4ee32'
        for model in policy['models']:
            expected = [{'role': 'implementer', 'path': expected_path, 'sha256': expected_hash}] if model['id'] == 'gpt-6-astra' else []
            self.assertEqual(model['adoption'], expected, 'Only the reviewed implementer baseline has adoption evidence')
        self.assertEqual(hashlib.sha256((ROOT / expected_path).read_bytes()).hexdigest(), expected_hash)
        helper = load_helper()
        registry, registered = helper._policy_registry(ROOT / 'contracts/agent-model-capabilities.v2.json')
        token = helper._SNAPSHOT_ROOT.set(ROOT)
        try:
            helper._validate_role_policy(policy, registered, registry['role_defaults'])
        finally:
            helper._SNAPSHOT_ROOT.reset(token)

    def test_shipped_adoption_reference_rejects_changed_evidence(self):
        helper = load_helper()
        registry, registered = helper._policy_registry(ROOT / 'contracts/agent-model-capabilities.v2.json')
        policy = json.loads((ROOT / 'contracts/model-policy.v1.json').read_text())
        ref = next(x for x in policy['models'] if x['id'] == 'gpt-6-astra')['adoption'][0]
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            target = root / ref['path']
            target.parent.mkdir(parents=True)
            target.write_bytes((ROOT / ref['path']).read_bytes() + b'\\n')
            token = helper._SNAPSHOT_ROOT.set(root)
            try:
                with self.assertRaises(helper.PolicyError) as caught:
                    helper._validate_role_policy(policy, registered, registry['role_defaults'])
                self.assertEqual(caught.exception.reason, 'config-invalid')
            finally:
                helper._SNAPSHOT_ROOT.reset(token)

    def test_passing_unregistered_model_cannot_be_added_to_policy(self):
        helper = load_helper()
        registry, registered = helper._policy_registry(ROOT / 'contracts/agent-model-capabilities.v2.json')
        self.assertNotIn('gpt-6.1-sol', registered)
        policy = json.loads((ROOT / 'contracts/model-policy.v1.json').read_text())
        model = copy.deepcopy(next(x for x in policy['models'] if x['id'] == 'gpt-6-astra'))
        model['id'] = 'gpt-6.1-sol'
        model['hosts'] = {'codex-cli': 'gpt-6.1-sol'}
        policy['models'].append(model)
        token = helper._SNAPSHOT_ROOT.set(ROOT)
        try:
            with self.assertRaises(helper.PolicyError) as caught:
                helper._validate_role_policy(policy, registered, registry['role_defaults'])
            self.assertEqual(caught.exception.reason, 'config-invalid')
        finally:
            helper._SNAPSHOT_ROOT.reset(token)""")
updated=old[:start]+block+old[end:];(OUT/'model-policy-adoption-only.patch').write_text(''.join(difflib.unified_diff(old.splitlines(True),updated.splitlines(True),fromfile='a/tests/model-policy.tests.py',tofile='b/tests/model-policy.tests.py')));(OUT/'model-policy-metadata-only.patch').write_text(''.join(difflib.unified_diff((checkout/'contracts/model-policy.v1.json').read_text().splitlines(True),(ATT/'policy-runtime-closure-v3/contracts/model-policy.v1.json').read_text().splitlines(True),fromfile='a/contracts/model-policy.v1.json',tofile='b/contracts/model-policy.v1.json')))
rel=Path('contracts/model-adoption/ci-model-modernization-20261021.json');(checkout/rel).parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ATT/'role-decisions.json',checkout/rel);before={'policy':h(checkout/'contracts/model-policy.v1.json'),'tests':h(checkout/'tests/model-policy.tests.py'),'registry':h(checkout/'contracts/agent-model-capabilities.v2.json')};(checkout/'contracts/model-policy.v1.json').write_bytes((ATT/'policy-runtime-closure-v3/contracts/model-policy.v1.json').read_bytes());(checkout/'tests/model-policy.tests.py').write_text(updated)
env=dict(os.environ);env['SDD_TEST_PWSH']='/workspace/.tools/sdd-forge-dev/bin/pwsh';env['TMPDIR']='/workspace/.task-scratch/ci-model-modernization';env['PYTHONDONTWRITEBYTECODE']='1';runs=[]
for label in ['candidate','restored-baseline']:
 if label=='restored-baseline':
  (checkout/'contracts/model-policy.v1.json').write_bytes((SNAP/'contracts/model-policy.v1.json').read_bytes());(checkout/'tests/model-policy.tests.py').write_bytes(native_tests)
 p=subprocess.run([sys.executable,'-B','tests/model-policy.tests.py'],cwd=checkout,env=env,capture_output=True,text=True,timeout=300);(OUT/(label+'.stdout.log')).write_text(p.stdout);(OUT/(label+'.stderr.log')).write_text(p.stderr);runs.append({'label':label,'exit_code':p.returncode,'stdout_sha256':h(OUT/(label+'.stdout.log')),'stderr_sha256':h(OUT/(label+'.stderr.log'))});print(json.dumps(runs[-1]),flush=True)
after={'policy':h(checkout/'contracts/model-policy.v1.json'),'tests':h(checkout/'tests/model-policy.tests.py'),'registry':h(checkout/'contracts/agent-model-capabilities.v2.json')};result={'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'disposable_checkout':str(checkout),'root_product_files_changed':False,'basis':'admitted229 immutable inputs plus Root-admitted native test harness24223de0; narrow adoption fragment preserves all six portable regressions; no root replacement','before':before,'after':after,'rollback_exact':before==after,'runs':runs,'policy_proposal_sha256':h(ATT/'policy-runtime-closure-v3/contracts/model-policy.v1.json'),'test_fragment_sha256':h(OUT/'model-policy-adoption-only.patch')};(OUT/'results.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
