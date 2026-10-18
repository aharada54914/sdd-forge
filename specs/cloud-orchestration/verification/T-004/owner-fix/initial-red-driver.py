from pathlib import Path
import json,hashlib,subprocess,datetime
r=Path('/workspace/sdd-forge');d=r/'specs/cloud-orchestration/verification/T-004/owner-fix';d.mkdir(exist_ok=False);prod=r/'plugins/sdd-azure-cloud/scripts/cloud.py';test=r/'tests/cloud-orchestration-routing.tests.py';doc=r/'plugins/sdd-azure-cloud/references/local-contract.md'
for p,name in [(prod,'cloud-before.py.txt'),(test,'tests-before.py.txt'),(doc,'contract-before.md.txt')]: (d/name).write_bytes(p.read_bytes())
before={'source_sha256':hashlib.sha256(prod.read_bytes()).hexdigest(),'test_sha256':hashlib.sha256(test.read_bytes()).hexdigest(),'git_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'implementer':'root bounded fix-by-review-ticket correction; no independent-review claim'};(d/'before.json').write_text(json.dumps(before,indent=2)+'\n')
new='''    def test_encoded_cloudformation_keys_and_ambiguous_yaml_block_owner_route(self):
        escaped = b'{"' + bytes([92]) + b'u0052esources":{"Bucket":{"Type":"AWS::S3::Bucket"}}}'
        for name, body in (("escaped.json", escaped), ("escaped.yml", escaped),
                           ("quoted.yaml", b'"' + bytes([92]) + b'u0052esources": {}')):
            with self.subTest(name=name):
                ref = self.put("bundle/unit/" + name, body)
                result = self.invoke(expected=2)
                self.assertEqual(result["result"], "BLOCKED")
                self.assertIn(result["error_code"], ("OWNER_CONFLICT", "OWNER_UNRESOLVED"))
                (self.root / ref["path"]).unlink()
        self.put("bundle/unit/settings.json", {"description": "Resources", "enabled": True})
        self.assertEqual(self.invoke()["state"], "ROUTED")

'''
s=test.read_text();needle='    def test_explicit_unsupported_inventory_and_provider_mismatch(self):';assert s.count(needle)==1;test.write_text(s.replace(needle,new+needle));cmd=['python3','-B',str(test),'AzureRouting.test_encoded_cloudformation_keys_and_ambiguous_yaml_block_owner_route'];print([l for l in s.splitlines() if l.startswith('class ')])
# Resolve the actual test class from the containing source rather than assuming a name.
class_name=s[:s.index(needle)].rsplit('class ',1)[1].split('(',1)[0];cmd[-1]=class_name+'.test_encoded_cloudformation_keys_and_ambiguous_yaml_block_owner_route';x=subprocess.run(cmd,cwd=r,capture_output=True,text=True);(d/'red.log').write_text(x.stdout+x.stderr);print(x.returncode,x.stdout+x.stderr);assert x.returncode!=0 and 'AssertionError: 0 != 2' in x.stderr
subprocess.run(['git','add','--',str(test.relative_to(r))],cwd=r,check=True);x=subprocess.run(['git','commit','-m','test(cloud): deny escaped mixed-owner templates','--',str(test.relative_to(r))],cwd=r,capture_output=True,text=True);(d/'red-commit.log').write_text(x.stdout+x.stderr);assert x.returncode==0;assert hashlib.sha256(prod.read_bytes()).hexdigest()==before['source_sha256'];(d/'red-proof.json').write_text(json.dumps({'test_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),'production_sha256':before['source_sha256'],'production_unchanged':True,'command':cmd,'exit_code':1},indent=2)+'\n')
