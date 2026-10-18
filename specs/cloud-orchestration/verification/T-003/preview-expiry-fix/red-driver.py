from pathlib import Path
import subprocess,json,hashlib,datetime
r=Path('/workspace/sdd-forge');d=r/'specs/cloud-orchestration/verification/T-003/preview-expiry-fix';d.mkdir(exist_ok=False)
p=r/'plugins/sdd-quality-loop/scripts/cloud_authorization.py';t=r/'tests/cloud-orchestration-execution.tests.py';(d/'authorization-before.py.txt').write_bytes(p.read_bytes());(d/'tests-before.py.txt').write_bytes(t.read_bytes())
before={'source':str(p.relative_to(r)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'test_sha256':hashlib.sha256(t.read_bytes()).hexdigest(),'git_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),'ticket':'RT-20261018-CLOUD-PREVIEW-EXPIRY','implementer':'root host correction under fix-by-review-ticket; not a new independent context','recorded_at':datetime.datetime.now(datetime.timezone.utc).isoformat()};(d/'before.json').write_text(json.dumps(before,indent=2)+'\n')
new='''    def test_preview_expiry_after_final_binding_denies_and_retains_receipt(self):
        for provider in ("aws", "azure"):
            for elapsed in (0, 1, 2):
                with self.subTest(provider=provider, elapsed=elapsed):
                    self.setup_case(provider, "apply")
                    self.writes.clear()
                    for receipt in self.evidence.glob("*.authorization.json"):
                        receipt.unlink()
                    preview = contracts.read_artifact(self.root, self.preview_ref, "cloud-preview/v1")
                    preview["expires_at"] = utc(NOW + 1)
                    self.preview_ref = self.put("preview.json", preview)
                    self.transport.run["display_title"] = (
                        "cloud:" + self.request_ref["sha256"] + ":" + self.preview_ref["sha256"]
                    )
                    original = contracts.verify_binding
                    calls = []

                    def verify(*args, **kwargs):
                        result = original(*args, **kwargs)
                        calls.append(True)
                        if len(calls) == 3:
                            self.boundary.clock = lambda: NOW + elapsed
                        return result

                    with patch.object(contracts, "verify_binding", side_effect=verify):
                        if elapsed == 0:
                            ref, _ = self.write()
                            self.assertEqual(self.writes, ["write"])
                        else:
                            with self.assertRaises(self.a.AdmissionDenied):
                                self.write()
                            self.assertEqual(self.writes, [])
                    self.assertEqual(len(calls), 3)
                    receipts = list(self.evidence.glob("*.authorization.json"))
                    self.assertEqual(len(receipts), 1)
                    self.assertEqual(json.loads(receipts[0].read_bytes())["expires_at"], utc(NOW + 1))

'''
s=t.read_text();needle='    def test_expiry_or_artifact_swap_during_scan_denies_before_submit(self):';assert s.count(needle)==1;t.write_text(s.replace(needle,new+needle))
x=subprocess.run(['python3','-B',str(t),'Admission.test_preview_expiry_after_final_binding_denies_and_retains_receipt'],cwd=r,capture_output=True,text=True);(d/'red.log').write_text(x.stdout+x.stderr);print(x.returncode,x.stdout+x.stderr);assert x.returncode!=0 and 'AdmissionDenied not raised' in x.stderr
subprocess.run(['git','add','--',str(t.relative_to(r))],cwd=r,check=True);x=subprocess.run(['git','commit','-m','test(cloud): reject preview expiry during final binding','--',str(t.relative_to(r))],cwd=r,capture_output=True,text=True);(d/'red-commit.log').write_text(x.stdout+x.stderr);assert x.returncode==0;assert hashlib.sha256(p.read_bytes()).hexdigest()==before['sha256'];(d/'red-proof.json').write_text(json.dumps({'test_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),'production_unchanged':True,'production_sha256':before['sha256'],'exit_code':1},indent=2)+'\n')
