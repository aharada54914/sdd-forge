"""T-002 local synthetic fixtures; no cloud or authorization authority.

Stdlib only. Independent structural schema oracle is the repository's existing
sidecar schema validator; semantic/date/filesystem checks are runtime-only.
"""
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / 'plugins/sdd-quality-loop/scripts/cloud_contracts.py'
NOW = '2026-10-18T06:00:00Z'
END = '2026-10-18T07:00:00Z'
SHA = 'a' * 64


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def encode(value):
    return (json.dumps(value, sort_keys=True, ensure_ascii=True) + '\n').encode()


def ref(path, data=b'fixture'):
    return {'path': path, 'sha256': hashlib.sha256(data).hexdigest()}


def fixtures():
    identity = dict(run_id='run-1', unit_id='unit-1', provider='aws')
    scope = dict(account_id='123456789012', region='us-east-1', deployment_scope='stack-1')
    request = dict(schema='cloud-run-request/v1', **identity, binding_id='binding-1',
                   environment='sandbox', scope=scope, owner='cdk', route='aws-cdk',
                   operation='apply', predecessor_receipts=[], source_revision='a'*40,
                   input_artifacts=[dict(kind=k, **ref(k+'.bin')) for k in
                                    ('source', 'compiled', 'asset', 'parameters', 'module')],
                   dependency_lock=ref('lock.json'), policy=ref('policy.json'),
                   verification_profile=dict(id='health', version='1', **ref('profile.json')))
    lock = dict(schema='cloud-dependency-lock/v1', adapter_version='1.0.0',
                upstream=[dict(repository='https://example.invalid/source', commit='a'*40,
                               root='upstream', files=[dict(**ref('upstream/main.md'), references=['upstream/child.md']),
                                                        dict(**ref('upstream/child.md'), references=[])])],
                tools=[dict(name='cdk', version='2.1.0', sha256=SHA)],
                managed_endpoints=[dict(endpoint='https://example.invalid/mcp', tool_schema=ref('tool.json'))])
    preview = dict(schema='cloud-preview/v1', **identity, scope=copy.deepcopy(scope),
                   request=ref('request.json'), dependency_lock=ref('lock.json'), policy=ref('policy.json'),
                   verification_profile=ref('profile.json'), preview_identity='change-set-1',
                   semantic_sha256=SHA, changes=ref('changes.json'), replacements=[], deletes=[],
                   created_at=NOW, expires_at=END)
    receipt = dict(schema='cloud-authorization-receipt/v1', **identity, scope=copy.deepcopy(scope),
                   operation='apply', issuer='https://token.actions.githubusercontent.com',
                   principal='principal-1', subject='repo:example/project:environment:sandbox',
                   ci=dict(repository='example/project', workflow='.github/workflows/cloud.yml',
                           workflow_revision='a'*40, ref='refs/heads/main', environment='sandbox',
                           run_id='123', run_attempt=1), request=ref('request.json'), preview=ref('preview.json'),
                   dependency_lock=ref('lock.json'), policy=ref('policy.json'),
                   verification_profile=ref('profile.json'), issued_at=NOW, expires_at=END,
                   approval_evidence=dict(locator='https://example.invalid/approvals/1', sha256=SHA))
    observation = dict(schema='cloud-observation/v1', **identity, native_operation_id='operation-1',
                       resource_ids=['resource-1'], principal='observer-1', query='describe-health',
                       timestamp=NOW, exit_code=0, status='PASS', result=ref('query.json'), classification='synthetic')
    verification = dict(schema='cloud-verification/v1', **identity,
                        profile=dict(id='health', version='1', **ref('profile.json')),
                        required_check_ids=['network'], checks=[dict(check_id='network', observation=ref('observation.json'), result='PASS')],
                        overall_result='PASS', evidence_complete=True)
    result = dict(schema='cloud-operation-result/v1', **identity, operation='apply', state='BLOCKED',
                  result='BLOCKED', error_code='AUTH_UNAVAILABLE', message='Use the protected workflow.',
                  input_manifest_sha256=SHA, evidence_manifest_path='evidence/manifest.json')
    error = dict(schema='cloud-input-error/v1', error_code='INVALID_INPUT', message='Invalid request.', field='run_id')
    return {v['schema']: v for v in (request, lock, preview, receipt, observation, verification, result, error)}


def nodes(value, path=()):
    yield path, value
    if isinstance(value, dict):
        for key, child in value.items():
            yield from nodes(child, path+(key,))
    elif isinstance(value, list):
        for i, child in enumerate(value):
            yield from nodes(child, path+(i,))


def at(value, path):
    for key in path:
        value = value[key]
    return value


class Contracts(unittest.TestCase):
    def setUp(self):
        self.assertTrue(MODULE.is_file(), 'T-002 shared contract implementation is absent')
        self.c = load(MODULE, 'cloud_contracts')
        self.oracle = load(ROOT/'plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py', 'schema_oracle')
        self.f = fixtures()
        self.temp = tempfile.TemporaryDirectory(prefix='cloud-contracts-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def schema(self, kind):
        return json.loads((ROOT/'contracts'/(kind.split('/')[0]+'.schema.json')).read_bytes())

    def rejects(self, value):
        with self.assertRaises(self.c.ContractError):
            self.c.parse_artifact(encode(value))

    def both(self, value, valid):
        errors = self.oracle._schema_validate(self.schema(value['schema']), value)
        self.assertEqual(not errors, valid, errors)
        if valid:
            self.assertEqual(self.c.parse_artifact(encode(value)), value)
        else:
            self.rejects(value)

    def test_positive_all_families_and_both_providers(self):
        for value in self.f.values():
            with self.subTest(schema=value['schema']):
                self.both(value, True)
        request = copy.deepcopy(self.f['cloud-run-request/v1'])
        request.update(provider='azure', owner='bicep', route='azure-bicep')
        request['scope']['account_id'] = '00000000-0000-0000-0000-000000000001'
        self.both(request, True)
        request['owner'] = 'cdk'
        self.both(request, False)

    def test_all_object_boundaries_unknown_and_missing_fields(self):
        for kind, original in self.f.items():
            for path, node in nodes(original):
                if not isinstance(node, dict):
                    continue
                bad = copy.deepcopy(original)
                at(bad, path)['unexpected'] = True
                with self.subTest(kind=kind, path=path, case='extra'):
                    self.both(bad, False)
                for key in node:
                    if key == 'schema':
                        continue
                    bad = copy.deepcopy(original)
                    del at(bad, path)[key]
                    with self.subTest(kind=kind, path=path+(key,), case='missing'):
                        self.both(bad, False)

    def test_all_scalar_types_and_schema_versions(self):
        for kind, original in self.f.items():
            for path, node in nodes(original):
                if isinstance(node, (dict, list)) or not path or path[-1] == 'schema':
                    continue
                bad = copy.deepcopy(original)
                at(bad, path[:-1])[path[-1]] = {}  # no coercion
                with self.subTest(kind=kind, path=path):
                    self.both(bad, False)
            for version in ('/v0', '/v2', '/V1', '/v1\n'):
                bad = dict(original, schema=kind.split('/')[0]+version)
                self.rejects(bad)

    def test_parser_rejects_ambiguous_json_without_echo(self):
        canary = 'canary-' + 'do-not-publish-482'
        for raw in (b'{}{}', b'[]', b'null', b'\xef\xbb\xbf{}', b'\xff', b'{',
                    b'{"schema":"cloud-input-error/v1","schema":"cloud-input-error/v1"}',
                    b'{"nested":{"x":1,"x":2}}', b'{"x":NaN}', b'{"x":Infinity}',
                    b'{"x":-Infinity}', b'{"x":1e999}', ('{"'+canary+'":').encode()):
            with self.subTest(raw=raw[:10]):
                with self.assertRaises(self.c.ContractError) as caught:
                    self.c.parse_artifact(raw)
                self.assertNotIn(canary, str(caught.exception))

    def test_digests_utc_paths_and_scalar_edge_cases(self):
        original = self.f['cloud-preview/v1']
        for key in ('created_at', 'expires_at'):
            for value in ('2026-02-30T00:00:00Z', '2026-10-18T06:00:00+00:00',
                          '2026-10-18T06:00:00z', NOW+'\n', '0000-01-01T00:00:00Z'):
                self.rejects(dict(original, **{key:value}))
        for digest in ('A'*64, 'a'*63, SHA+'\n', 'sha256:'+SHA, None):
            self.both(dict(original, semantic_sha256=digest), False)
        paths = ('../x', '/x', 'C:/x', 'a\\x', 'a//x', './x', 'a/../x', 'a/',
                 'a\nx', 'a/%2e%2e/x', 'a/CON', 'a/x.', 'a/x ', 'a/aux.txt', 'a/NUL')
        for path in paths:
            bad = copy.deepcopy(original); bad['changes']['path'] = path
            with self.subTest(path=path):
                self.both(bad, False)
        bad = copy.deepcopy(self.f['cloud-observation/v1']); bad['exit_code'] = True
        self.both(bad, False)
        self.rejects(dict(original, expires_at=NOW))

    def make_bundle(self):
        f = copy.deepcopy(self.f)
        for name in ('source.bin','compiled.bin','asset.bin','parameters.bin','module.bin',
                     'policy.json','profile.json','upstream/main.md','upstream/child.md','tool.json','changes.json'):
            p=self.root/name; p.parent.mkdir(parents=True,exist_ok=True); p.write_bytes(b'fixture')
        lock=f['cloud-dependency-lock/v1']; lock_ref=self.put('lock.json',lock)
        request=f['cloud-run-request/v1']; request['dependency_lock']=lock_ref
        request_ref=self.put('request.json',request)
        preview=f['cloud-preview/v1']; preview.update(request=request_ref, dependency_lock=lock_ref,
                                                     semantic_sha256=ref('changes.json')['sha256'])
        preview_ref=self.put('preview.json',preview)
        receipt=f['cloud-authorization-receipt/v1']; receipt.update(request=request_ref,preview=preview_ref,dependency_lock=lock_ref)
        receipt_ref=self.put('receipt.json',receipt)
        return request_ref,preview_ref,receipt_ref

    def put(self,path,value):
        data=encode(value); (self.root/path).write_bytes(data); return ref(path,data)

    def bound(self,refs):
        return self.c.verify_binding(self.root,*refs,now=NOW)

    def test_every_bound_file_mutation_is_rejected(self):
        refs=self.make_bundle()
        self.bound(refs)
        for path in sorted(p for p in self.root.rglob('*') if p.is_file()):
            data=path.read_bytes(); path.write_bytes(data+b' ')
            with self.subTest(file=path.name), self.assertRaises(self.c.ContractError):
                self.bound(refs)
            path.write_bytes(data)

    def test_bound_scope_owner_profile_policy_identity_and_preview_drift(self):
        refs=self.make_bundle()
        for schema,path,ref_index in (('cloud-run-request/v1','request.json',0),
                                      ('cloud-preview/v1','preview.json',1),
                                      ('cloud-authorization-receipt/v1','receipt.json',2)):
            original=json.loads((self.root/path).read_bytes())
            fields=['run_id','unit_id','provider','scope']
            if ref_index==0: fields += ['owner','binding_id','environment','source_revision','verification_profile','policy']
            if ref_index==1: fields += ['preview_identity','semantic_sha256','request','dependency_lock','policy','verification_profile']
            if ref_index==2: fields += ['request','preview','dependency_lock','policy','verification_profile']
            for key in fields:
                bad=copy.deepcopy(original)
                if key=='scope': bad[key]['region']='different-region'
                elif isinstance(bad[key],dict): bad[key]['sha256']='b'*64
                elif key in ('source_revision','semantic_sha256'): bad[key]='b'*len(bad[key])
                else: bad[key]='different'
                changed=list(refs); changed[ref_index]=self.put(path,bad)
                with self.subTest(schema=schema,key=key),self.assertRaises(self.c.ContractError):
                    self.bound(changed)
                self.put(path,original)
        with self.assertRaises(self.c.ContractError):
            self.c.verify_binding(self.root,*refs,now=END)

    def test_lock_closure_versions_packages_schemas_and_adapter(self):
        self.make_bundle(); lock=json.loads((self.root/'lock.json').read_bytes())
        kwargs=dict(consumed_paths=['upstream/main.md','upstream/child.md'],
                    tools=copy.deepcopy(lock['tools']),adapter_version='1.0.0',
                    tool_schemas={'https://example.invalid/mcp':ref('tool.json')['sha256']})
        self.c.verify_lock(self.root,lock,**kwargs)
        for key,value in [('consumed_paths',['upstream/main.md']),('consumed_paths',kwargs['consumed_paths']+['upstream/unlocked.md']),
                          ('tools',[]),('adapter_version','2.0.0'),('tool_schemas',{}),
                          ('tool_schemas',{'https://example.invalid/mcp':'b'*64})]:
            with self.subTest(key=key),self.assertRaises(self.c.ContractError):
                self.c.verify_lock(self.root,lock,**dict(kwargs,**{key:value}))
        for key in ('version','sha256'):
            bad=copy.deepcopy(kwargs); bad['tools'][0][key]='2.2.2' if key=='version' else 'b'*64
            with self.assertRaises(self.c.ContractError): self.c.verify_lock(self.root,lock,**bad)
        for target in ('upstream/missing.md','elsewhere.md','../escape'):
            bad=copy.deepcopy(lock); bad['upstream'][0]['files'][0]['references']=[target]
            with self.assertRaises(self.c.ContractError): self.c.verify_lock(self.root,bad,**kwargs)
        bad=copy.deepcopy(lock); bad['upstream'][0]['files'].append(copy.deepcopy(bad['upstream'][0]['files'][0]))
        with self.assertRaises(self.c.ContractError): self.c.verify_lock(self.root,bad,**kwargs)

    def test_safe_reader_rejects_symlinks_hardlinks_and_nonfiles(self):
        (self.root/'real').mkdir(); (self.root/'real/x').write_bytes(b'fixture')
        (self.root/'alias').symlink_to(self.root/'real',target_is_directory=True)
        (self.root/'link').symlink_to(self.root/'real/x')
        os.link(self.root/'real/x',self.root/'hard')
        for path in ('alias/x','link','hard','real','missing'):
            with self.subTest(path=path),self.assertRaises(self.c.ContractError):
                self.c.read_verified(self.root,ref(path))
        with self.assertRaises(self.c.ContractError):
            self.c.read_verified(self.root/'alias',ref('x'))
        os.mkfifo(self.root/'fifo')
        with self.assertRaises(self.c.ContractError): self.c.read_verified(self.root,ref('fifo'))

    def test_publication_atomic_no_overwrite_containment_and_scan_failure(self):
        value=self.f['cloud-input-error/v1']; data=encode(value)
        self.c.publish_artifact(self.root,'new.json',data,scan=lambda b:True)
        self.assertEqual((self.root/'new.json').read_bytes(),data)
        with self.assertRaises(self.c.ContractError): self.c.publish_artifact(self.root,'new.json',data,scan=lambda b:True)
        (self.root/'alias').symlink_to(self.root,target_is_directory=True)
        for path in ('alias/out.json','../escape.json'):
            with self.assertRaises(self.c.ContractError): self.c.publish_artifact(self.root,path,data,scan=lambda b:True)
        canary='canary-'+'do-not-publish-482'; bad=encode(dict(value,message=canary))
        for scanner in (lambda b:False,lambda b:None,lambda b:1):
            with self.assertRaises(self.c.ContractError): self.c.publish_artifact(self.root,'secret.json',bad,scan=scanner)
            self.assertFalse((self.root/'secret.json').exists())
        def broken(_): raise RuntimeError(canary)
        with self.assertRaises(self.c.ContractError) as caught:
            self.c.publish_artifact(self.root,'secret.json',bad,scan=broken)
        self.assertNotIn(canary,str(caught.exception))
        self.assertEqual(sorted(p.name for p in self.root.iterdir()),['alias','new.json'])

    def test_result_exit_mapping_and_invalid_identity(self):
        original=self.f['cloud-operation-result/v1']
        for result,state,code in [('PASS','LOCAL_VALIDATED',0),('NO_CHANGE','NO_CHANGE',0),
                                  ('BLOCKED','BLOCKED',2),('FAIL','FAILED',1),('UNKNOWN','UNKNOWN',3)]:
            value=dict(original,result=result,state=state,error_code=None if code==0 else 'ERROR')
            self.both(value,True); self.assertEqual(self.c.exit_code(value),code)
            self.both(dict(value,state='Done'),False)
            self.both(dict(value,error_code='ERROR' if code==0 else None),False)
        self.both(dict(original,result='NO_CHANGE',state='NO_CHANGE',error_code=None,native_operation_id='fake'),False)
        self.both(dict(original,result='PASS',state='FAILED',error_code=None),False)
        for bad in ('',None,'../run','run\n'):
            self.rejects(dict(original,run_id=bad))
        error=self.c.input_error('INVALID_INPUT','run_id')
        self.both(error,True); self.assertEqual(self.c.exit_code(error),2)
        self.assertEqual(set(error),{'schema','error_code','message','field'})

    def test_verification_inconsistent_claims_and_duplicate_checks(self):
        original=self.f['cloud-verification/v1']
        for result in ('FAIL','BLOCKED'):
            bad=copy.deepcopy(original); bad['checks'][0]['result']=result
            self.rejects(bad)
        for field in ('checks','required_check_ids'):
            bad=copy.deepcopy(original); bad[field]*=2; self.rejects(bad)
        bad=copy.deepcopy(original); bad['checks'][0]['check_id']='other'; self.rejects(bad)
        self.rejects(dict(original,overall_result='FAIL',evidence_complete=True))


if __name__ == '__main__':
    unittest.main(verbosity=2)
