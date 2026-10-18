"""T-003 admission tests. ALL external requests use deterministic synthetic transports.

No live GitHub, OIDC, IAM or cloud writes. Future provider execution tests belong
in this suite but are not implemented by T-003.
"""
import base64
import copy
from dataclasses import replace
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from urllib.parse import parse_qs
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'plugins/sdd-quality-loop/scripts'
sys.path.insert(0, str(SCRIPTS))
import cloud_contracts as contracts  # noqa: E402

NOW = 1792303200  # synthetic 2026-10-18T06:00:00Z
REV = 'a' * 40
REPO = 'synthetic/control'
WORKFLOW = '.github/workflows/cloud.yml'
SUBSCRIPTION = '00000000-0000-0000-0000-000000000001'
TENANT = '00000000-0000-0000-0000-000000000002'
CLIENT = '00000000-0000-0000-0000-000000000003'
OBJECT = '00000000-0000-0000-0000-000000000004'
OIDC_URL = 'https://pipelines.actions.githubusercontent.com/synthetic/idtoken?api-version=2.0'


def encode(value):
    return (json.dumps(value, sort_keys=True) + '\n').encode()


def jwt(claims):
    # Synthetic token; only the deterministic HTTPS double returns this value.
    return 'synthetic.' + base64.urlsafe_b64encode(encode(claims)).decode().rstrip('=') + '.synthetic'


def utc(epoch):
    return datetime.fromtimestamp(epoch, timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


class DeterministicTransport:
    """Exact HTTP contract double, never a production authority source."""
    def __init__(self, provider, stage):
        self.provider, self.stage = provider, stage
        self.environment = 'sandbox-' + stage
        self.subject = f'repo:{REPO}:environment:{self.environment}:workflow_ref:{REPO}/{WORKFLOW}@refs/heads/main'
        self.claims = dict(iss='https://token.actions.githubusercontent.com', sub=self.subject,
                           aud='sts.amazonaws.com' if provider == 'aws' else 'api://AzureADTokenExchange',
                           repository=REPO, repository_id='42', workflow_ref=f'{REPO}/{WORKFLOW}@refs/heads/main',
                           workflow_sha=REV, ref='refs/heads/main', sha=REV, run_id='123', run_attempt='1',
                           actor='operator', actor_id='7', environment=self.environment,
                           event_name='workflow_dispatch', iat=NOW-10, nbf=NOW-10, exp=NOW+600)
        self.run = dict(id=123, run_attempt=1, status='in_progress', conclusion=None,
                        event='workflow_dispatch', head_sha=REV, head_branch='main', path=WORKFLOW,
                        repository=dict(id=42, full_name=REPO), head_repository=dict(id=42, full_name=REPO),
                        actor=dict(id=7, login='operator'), triggering_actor=dict(id=7, login='operator'))
        self.environment_response = dict(id=99, name=self.environment, can_admins_bypass=False,
            deployment_branch_policy=dict(protected_branches=True, custom_branch_policies=False),
            protection_rules=[dict(type='required_reviewers', prevent_self_review=True,
                                   reviewers=[dict(type='User', reviewer=dict(id=8, login='reviewer'))])])
        self.approvals = [dict(state='approved', comment='', user=dict(id=8, login='reviewer'),
                               environments=[dict(id=99, name=self.environment)])]
        self.principal = f'arn:aws:sts::123456789012:assumed-role/cloud-{stage}/sdd-123'
        self.account = '123456789012'
        self.lease_end = NOW+300
        self.azure_claims = dict(oid=OBJECT, tid=TENANT, appid=CLIENT,
                                aud='https://management.azure.com/', iat=NOW-10, nbf=NOW-10, exp=NOW+300)
        self.subscription = dict(subscriptionId=SUBSCRIPTION, tenantId=TENANT, state='Enabled')
        self.calls = []
        self.fail_suffix = None
        self.raw_approvals = None

    def request(self, method, url, headers, body=None):
        self.calls.append((method, url, dict(headers), body))
        if self.fail_suffix and self.fail_suffix in url:
            raise OSError('synthetic-private-error')
        if url.startswith(OIDC_URL + '&audience='):
            assert method == 'GET' and headers['Authorization'] == 'Bearer synthetic-oidc-bearer'
            return encode(dict(value=jwt(self.claims)))
        base = f'https://api.github.com/repos/{REPO}'
        if url.startswith(base):
            assert method == 'GET' and body is None
            assert headers['Authorization'] == 'Bearer synthetic-github-bearer'
            assert headers['Accept'] == 'application/vnd.github+json'
            assert headers['X-GitHub-Api-Version'] == '2022-11-28'
            if url == base + '/actions/runs/123':
                return encode(self.run)
            if url == base + '/actions/runs/123/approvals':
                return self.raw_approvals if self.raw_approvals is not None else encode(self.approvals)
            if url == base + '/environments/' + self.environment:
                return encode(self.environment_response)
        if url == 'https://sts.amazonaws.com/':
            assert method == 'POST'
            args = parse_qs(body.decode())
            assert args['Version'] == ['2011-06-15']
            if args['Action'] == ['AssumeRoleWithWebIdentity']:
                assert args['RoleArn'] == [f'arn:aws:iam::123456789012:role/cloud-{self.stage}']
                assert args['RoleSessionName'] == ['sdd-123']
                assert args['WebIdentityToken'] == [jwt(self.claims)]
                return (f'<AssumeRoleWithWebIdentityResponse xmlns="https://sts.amazonaws.com/doc/2011-06-15/">'
                        f'<AssumeRoleWithWebIdentityResult><SubjectFromWebIdentityToken>{self.subject}</SubjectFromWebIdentityToken>'
                        f'<Audience>sts.amazonaws.com</Audience><Provider>token.actions.githubusercontent.com</Provider>'
                        f'<AssumedRoleUser><Arn>{self.principal}</Arn></AssumedRoleUser><Credentials>'
                        f'<AccessKeyId>SYNTHETICKEY</AccessKeyId><SecretAccessKey>synthetic-secret</SecretAccessKey>'
                        f'<SessionToken>synthetic-session</SessionToken><Expiration>{utc(self.lease_end)}</Expiration>'
                        '</Credentials></AssumeRoleWithWebIdentityResult></AssumeRoleWithWebIdentityResponse>').encode()
            assert args['Action'] == ['GetCallerIdentity']
            assert headers['Authorization'].startswith('AWS4-HMAC-SHA256 Credential=SYNTHETICKEY/')
            assert headers['X-Amz-Security-Token'] == 'synthetic-session'
            return (f'<GetCallerIdentityResponse xmlns="https://sts.amazonaws.com/doc/2011-06-15/">'
                    f'<GetCallerIdentityResult><Account>{self.account}</Account><Arn>{self.principal}</Arn>'
                    '<UserId>SYNTHETIC:sdd-123</UserId></GetCallerIdentityResult></GetCallerIdentityResponse>').encode()
        if url == f'https://login.microsoftonline.com/{TENANT}/oauth2/v2.0/token':
            assert method == 'POST'
            args = parse_qs(body.decode())
            assert args == dict(client_id=[CLIENT], grant_type=['client_credentials'],
                scope=['https://management.azure.com/.default'],
                client_assertion_type=['urn:ietf:params:oauth:client-assertion-type:jwt-bearer'],
                client_assertion=[jwt(self.claims)])
            return encode(dict(token_type='Bearer', expires_in=300, access_token=jwt(self.azure_claims)))
        if url == f'https://management.azure.com/subscriptions/{SUBSCRIPTION}?api-version=2022-12-01':
            assert method == 'GET' and headers['Authorization'] == 'Bearer ' + jwt(self.azure_claims)
            return encode(self.subscription)
        raise AssertionError('Unexpected deterministic transport request: ' + url)


class Admission(unittest.TestCase):
    def setUp(self):
        self.assertTrue((SCRIPTS/'cloud_authorization.py').is_file(), 'T-003 admission boundary is absent')
        import cloud_authorization
        self.a = cloud_authorization
        self.tmp = tempfile.TemporaryDirectory(prefix='cloud-T-003-fixture-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.evidence = self.root/'evidence'
        self.evidence.mkdir()
        self.writes = []

    def put(self, path, value):
        data = value if isinstance(value, bytes) else encode(value)
        dest = self.root/path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        return dict(path=path, sha256=hashlib.sha256(data).hexdigest())

    def setup_case(self, provider='aws', stage='prepare'):
        spec = importlib.util.spec_from_file_location('contract_fixtures', ROOT/'tests/cloud-orchestration-contracts.tests.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        fixtures = module.fixtures()
        lock = fixtures['cloud-dependency-lock/v1']
        for item in lock['upstream'][0]['files']:
            self.put(item['path'], b'fixture')
        self.put('tool.json', b'fixture')
        lock_ref = self.put('lock.json', lock)
        policy_ref = self.put('policy.json', b'synthetic-external-policy-copy')
        profile_ref = self.put('profile.json', b'synthetic-profile')
        request = fixtures['cloud-run-request/v1']
        request.update(operation=stage, environment='sandbox-'+stage, provider=provider,
                       dependency_lock=lock_ref, policy=policy_ref,
                       verification_profile=dict(id='health', version='1', **profile_ref))
        if provider == 'azure':
            request.update(owner='bicep', route='azure-bicep')
            request['scope'].update(account_id=SUBSCRIPTION, region='eastus', deployment_scope='group-1')
        for item in request['input_artifacts']:
            self.put(item['path'], b'fixture')
        self.request = request
        self.request_ref = self.put('request.json', request)
        self.preview_ref = None
        if stage == 'apply':
            preview = fixtures['cloud-preview/v1']
            changes = self.put('changes.json', b'synthetic-changes')
            preview.update(provider=provider, scope=copy.deepcopy(request['scope']), request=self.request_ref,
                           policy=policy_ref, dependency_lock=lock_ref, verification_profile=profile_ref,
                           changes=changes, semantic_sha256=changes['sha256'])
            self.preview_ref = self.put('preview.json', preview)
        self.transport = DeterministicTransport(provider, stage)
        self.transport.run['display_title'] = 'cloud:'+self.request_ref['sha256']+':'+(self.preview_ref['sha256'] if self.preview_ref else 'none')
        self.policy = self.a.Policy(provider=provider, repository=REPO, repository_id=42,
            workflow=WORKFLOW, workflow_revision=REV, ref='refs/heads/main', operation=stage,
            environment='sandbox-'+stage, environment_id=99,
            account_id=request['scope']['account_id'], region=request['scope']['region'],
            deployment_scope=request['scope']['deployment_scope'], policy_sha256=policy_ref['sha256'],
            actors=((7, 'operator'),), reviewers=((8, 'reviewer'),), exclusive_repository=REPO,
            ttl_seconds=120, aws_role_arn=f'arn:aws:iam::123456789012:role/cloud-{stage}',
            azure_tenant=TENANT, azure_client=CLIENT, azure_principal=OBJECT)
        self.runtime = self.a.Runtime('synthetic-github-bearer', OIDC_URL, 'synthetic-oidc-bearer')
        self.boundary = self.a.WriteBoundary(self.policy, self.runtime, self.evidence,
                                           transport=self.transport, clock=lambda: NOW)

    def write(self, boundary=None, mutation='submit'):
        return (boundary or self.boundary).write(self.root, self.request_ref, self.preview_ref,
            mutation_id=mutation, submit=lambda credentials: self.writes.append('write'), scan=lambda b: True)

    def denied(self):
        with self.assertRaises(self.a.AdmissionDenied):
            self.write()
        self.assertEqual(self.writes, [])

    def test_native_positive_both_stages_providers_and_receipt_contract(self):
        for provider in ('aws', 'azure'):
            for stage in ('prepare', 'apply'):
                with self.subTest(provider=provider, stage=stage):
                    self.setup_case(provider, stage)
                    # Each fixture is an independent protected job evidence directory.
                    for p in self.evidence.iterdir():
                        p.unlink()
                    ref, _ = self.write()
                    receipt = contracts.parse_artifact(contracts.read_verified(self.evidence, ref))
                    self.assertEqual(receipt['schema'], 'cloud-authorization-receipt/v1')
                    for field in ('run_id', 'unit_id', 'provider', 'scope', 'dependency_lock', 'policy'):
                        self.assertEqual(receipt[field], self.request[field])
                    self.assertEqual(receipt['request'], self.request_ref)
                    self.assertEqual(receipt['preview'], self.preview_ref)
                    self.assertEqual(receipt['operation'], stage)
                    self.assertEqual(receipt['issued_at'], utc(NOW-10))
                    self.assertEqual(receipt['expires_at'], utc(NOW+110))
                    self.assertEqual(receipt['ci'], dict(repository=REPO, workflow=WORKFLOW,
                        workflow_revision=REV, ref='refs/heads/main', environment='sandbox-'+stage,
                        run_id='123', run_attempt=1))
                    self.assertEqual(receipt['subject'], self.transport.subject)
                    self.assertEqual(receipt['issuer'], 'https://token.actions.githubusercontent.com')
                    self.assertEqual(receipt['principal'], self.transport.principal if provider == 'aws' else OBJECT)
                    self.assertEqual(receipt['approval_evidence'], dict(
                        locator=f'https://api.github.com/repos/{REPO}/actions/runs/123/approvals',
                        sha256=hashlib.sha256(encode(self.transport.approvals)).hexdigest()))
                    self.assertNotIn(b'synthetic-secret', encode(receipt))
        self.assertEqual(len(self.writes), 4)

    def test_local_flags_receipts_and_missing_runtime_never_authorize(self):
        self.setup_case()
        self.put('approved.json', dict(approved=True))
        with patch.dict(os.environ, {'GITHUB_ACTIONS':'true', 'CLOUD_APPROVED':'true'}):
            self.boundary = self.a.WriteBoundary(self.policy, self.a.Runtime('', '', ''), self.evidence,
                                                transport=self.transport, clock=lambda: NOW)
            self.denied()
        self.assertEqual(self.transport.calls, [])

    def test_each_authenticated_oidc_binding_mismatch_denies(self):
        changes = dict(iss='https://example.invalid', sub='forged', aud='other', repository='other/repo',
                       repository_id='43', workflow_ref='other', workflow_sha='b'*40, ref='refs/heads/other',
                       sha='b'*40, run_id='124', run_attempt='2', actor_id='9', actor='other',
                       environment='other', event_name='pull_request', iat=NOW+1, nbf=NOW+1, exp=NOW)
        for key, value in changes.items():
            with self.subTest(field=key):
                self.setup_case()
                self.transport.claims[key] = value
                self.denied()

    def test_each_authenticated_run_binding_mismatch_denies(self):
        changes = dict(id=124, run_attempt=2, status='completed', conclusion='cancelled', event='push',
                       head_sha='b'*40, head_branch='other', path='other.yml', display_title='cloud:forged',
                       repository=dict(id=43, full_name=REPO), head_repository=dict(id=43, full_name=REPO),
                       actor=dict(id=9, login='operator'), triggering_actor=dict(id=9, login='operator'))
        for key, value in changes.items():
            with self.subTest(field=key):
                self.setup_case(); self.transport.run[key] = value; self.denied()

    def test_absent_revoked_denied_unknown_duplicate_approval_history(self):
        for stage in ('prepare', 'apply'):
            for case in ('empty', 'rejected', 'pending', 'duplicate', 'wrong-user', 'wrong-env', 'missing-user'):
                with self.subTest(stage=stage, case=case):
                    self.setup_case(stage=stage)
                    if case == 'empty': self.transport.approvals = []
                    elif case == 'duplicate': self.transport.approvals *= 2
                    elif case == 'wrong-user': self.transport.approvals[0]['user']['id'] = 9
                    elif case == 'wrong-env': self.transport.approvals[0]['environments'][0]['id'] = 100
                    elif case == 'missing-user': del self.transport.approvals[0]['user']
                    else: self.transport.approvals[0]['state'] = case
                    self.denied()
        self.setup_case()
        denied = copy.deepcopy(self.transport.approvals[0]); denied['state'] = 'rejected'
        self.transport.approvals.append(denied); self.denied()

    def test_environment_policy_and_missing_api_data_fail_closed(self):
        for field, value in [('id',100), ('name','other'), ('can_admins_bypass',True),
                             ('deployment_branch_policy',None), ('protection_rules',[])]:
            self.setup_case(); self.transport.environment_response[field] = value; self.denied()
        for endpoint in ('/approvals', '/environments/', '/actions/runs/'):
            self.setup_case(); self.transport.fail_suffix = endpoint; self.denied()
        self.setup_case(); self.transport.raw_approvals = b'[{"state":"approved","state":"rejected"}]'; self.denied()

    def test_provider_identity_and_lease_mismatch_before_each_stage(self):
        for stage in ('prepare', 'apply'):
            for case in ('principal','account','lease'):
                self.setup_case(stage=stage)
                if case == 'principal': self.transport.principal += '-other'
                if case == 'account': self.transport.account = '999999999999'
                if case == 'lease': self.transport.lease_end = NOW
                self.denied()
            for key in ('oid','tid','appid','aud','exp'):
                self.setup_case('azure', stage)
                self.transport.azure_claims[key] = NOW if key == 'exp' else 'other'
                self.denied()
            self.setup_case('azure', stage); self.transport.subscription['subscriptionId'] = TENANT; self.denied()

    def test_manifest_and_scope_rebinding_never_matches_authenticated_dispatch(self):
        for field in ('account_id','region','deployment_scope'):
            self.setup_case()
            self.request['scope'][field] = 'other'
            self.request_ref = self.put('request.json', self.request)
            self.denied()
        for field, value in [('operation','apply'),('environment','other'),('run_id','other'),
                             ('unit_id','other'),('source_revision','b'*40)]:
            self.setup_case(); self.request[field] = value
            self.request_ref = self.put('request.json', self.request); self.denied()
        self.setup_case(); self.put('asset.bin', b'swapped'); self.denied()
        self.setup_case(); self.request['policy'] = self.put('policy.json', b'changed')
        self.request_ref = self.put('request.json', self.request); self.denied()

    def test_replay_different_instance_tamper_and_unknown_submission_no_retry(self):
        self.setup_case()
        ref, _ = self.write()
        self.assertEqual(self.writes, ['write'])
        with self.assertRaises(self.a.AdmissionDenied): self.write()
        other = self.a.WriteBoundary(self.policy, self.runtime, self.evidence,
                                     transport=self.transport, clock=lambda: NOW)
        with self.assertRaises(self.a.AdmissionDenied): self.write(other)
        self.assertEqual(self.writes, ['write'])
        data = contracts.read_verified(self.evidence, ref)
        (self.evidence/ref['path']).write_bytes(data.replace(b'"prepare"', b'"apply"'))
        with self.assertRaises(self.a.AdmissionDenied): self.write(other)
        self.assertEqual(self.writes, ['write'])

    def test_timeout_is_not_retried_and_receipt_is_retained(self):
        self.setup_case()
        def submit(_):
            self.writes.append('uncertain'); raise TimeoutError('synthetic timeout')
        with self.assertRaises(TimeoutError):
            self.boundary.write(self.root,self.request_ref,None,mutation_id='submit',submit=submit,scan=lambda b: True)
        with self.assertRaises(self.a.AdmissionDenied): self.write()
        self.assertEqual(self.writes, ['uncertain'])
        self.assertEqual(len(list(self.evidence.iterdir())), 1)

    def test_fresh_checks_on_every_mutation_and_dependency_default_denial(self):
        self.setup_case(); self.write(mutation='asset-1')
        self.transport.approvals = []
        with self.assertRaises(self.a.AdmissionDenied): self.write(mutation='asset-2')
        self.assertEqual(self.writes, ['write'])
        self.writes.clear(); self.setup_case()
        self.request['predecessor_receipts'] = [dict(unit_id='prior', **self.put('prior.json', b'fixture'))]
        self.request_ref = self.put('request.json',self.request)
        self.transport.run['display_title'] = 'cloud:'+self.request_ref['sha256']+':none'
        self.denied()

    def test_untrusted_endpoint_and_publication_failure_have_zero_writes(self):
        for url in ('https://example.invalid/token', OIDC_URL.replace('https:', 'http:'),
                    'https://pipelines.actions.githubusercontent.com@evil.invalid/token'):
            self.setup_case()
            self.boundary = self.a.WriteBoundary(self.policy, replace(self.runtime, oidc_url=url), self.evidence,
                                                transport=self.transport, clock=lambda: NOW)
            self.denied(); self.assertEqual(self.transport.calls, [])
        self.setup_case()
        with self.assertRaises(self.a.AdmissionDenied):
            self.boundary.write(self.root,self.request_ref,None,mutation_id='submit',submit=lambda _: self.writes.append('write'),scan=lambda b: False)
        self.assertEqual(self.writes, [])

    def test_concurrency_key_conservative_canonical_and_scope_prerequisite(self):
        self.setup_case()
        key = self.a.concurrency_key(self.policy)
        self.assertEqual(key, 'cloud-aws-123456789012-us-east-1')
        self.assertEqual(key,self.a.concurrency_key(replace(self.policy,deployment_scope='another-stack')))
        self.boundary = self.a.WriteBoundary(replace(self.policy,exclusive_repository='other/repo'),self.runtime,self.evidence,
                                            transport=self.transport,clock=lambda:NOW)
        self.denied()

    def test_https_transport_disallows_redirects_and_sanitizes_failures(self):
        self.assertTrue(issubclass(self.a.NoRedirect, __import__('urllib.request',fromlist=['HTTPRedirectHandler']).HTTPRedirectHandler))
        with patch('urllib.request.OpenerDirector.open',side_effect=OSError('synthetic-sensitive-error')):
            with self.assertRaises(self.a.AdmissionDenied) as caught:
                self.a.HttpsTransport().request('GET','https://api.github.com/',{})
        self.assertNotIn('sensitive', str(caught.exception))

    def test_templates_have_distinct_environments_roles_and_no_cancellation(self):
        for provider in ('aws','azure'):
            content = (ROOT/f'templates/cloud/github-{provider}.yml').read_text()
            self.assertIn('cancel-in-progress: false',content)
            self.assertIn('sandbox-prepare',content); self.assertIn('sandbox-apply',content)
            self.assertIn('id-token: write',content)
            self.assertIn('inputs.request_sha256',content)
            self.assertIn('inputs.preview_sha256',content)
            self.assertIn('exclusive',content)
        policies = list((ROOT/'templates/cloud/iam').glob('*.json'))
        self.assertGreaterEqual(len(policies),4)
        for path in policies:
            json.loads(path.read_bytes())


if __name__ == '__main__':
    unittest.main(verbosity=2)
