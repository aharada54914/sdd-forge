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
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "plugins/sdd-quality-loop/scripts"
sys.path.insert(0, str(SCRIPTS))
import cloud_contracts as contracts  # noqa: E402

NOW = 1792303200  # synthetic 2026-10-18T06:00:00Z
REV = "a" * 40
REPO = "synthetic/control"
WORKFLOW = ".github/workflows/cloud.yml"
SUBSCRIPTION = "00000000-0000-0000-0000-000000000001"
TENANT = "00000000-0000-0000-0000-000000000002"
CLIENT = "00000000-0000-0000-0000-000000000003"
OBJECT = "00000000-0000-0000-0000-000000000004"
APPLY_CLIENT = "00000000-0000-0000-0000-000000000005"
APPLY_OBJECT = "00000000-0000-0000-0000-000000000006"
OIDC_URL = "https://pipelines.actions.githubusercontent.com/synthetic/idtoken?api-version=2.0"


def encode(value):
    return (json.dumps(value, sort_keys=True) + "\n").encode()


def jwt(claims):
    # Synthetic token; only the deterministic HTTPS double returns this value.
    return "synthetic." + base64.urlsafe_b64encode(encode(claims)).decode().rstrip("=") + ".synthetic"


def utc(epoch):
    return datetime.fromtimestamp(epoch, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class DeterministicTransport:
    """Exact HTTP contract double, never a production authority source."""

    def __init__(self, provider, stage):
        self.provider, self.stage = provider, stage
        self.environment = "sandbox-" + stage
        self.subject = f"repo:{REPO}:environment:{self.environment}:workflow_ref:{REPO}/{WORKFLOW}@refs/heads/main:workflow_sha:{REV}"
        self.claims = dict(
            iss="https://token.actions.githubusercontent.com",
            sub=self.subject,
            aud="sts.amazonaws.com" if provider == "aws" else "api://AzureADTokenExchange",
            repository=REPO,
            repository_id="42",
            workflow_ref=f"{REPO}/{WORKFLOW}@refs/heads/main",
            workflow_sha=REV,
            ref="refs/heads/main",
            sha=REV,
            run_id="123",
            run_attempt="1",
            actor="operator",
            actor_id="7",
            environment=self.environment,
            event_name="workflow_dispatch",
            iat=NOW - 10,
            nbf=NOW - 10,
            exp=NOW + 600,
        )
        self.run = dict(
            id=123,
            run_attempt=1,
            status="in_progress",
            conclusion=None,
            event="workflow_dispatch",
            head_sha=REV,
            head_branch="main",
            path=WORKFLOW,
            repository=dict(id=42, full_name=REPO),
            head_repository=dict(id=42, full_name=REPO),
            actor=dict(id=7, login="operator"),
            triggering_actor=dict(id=7, login="operator"),
        )
        self.environment_response = dict(
            id=99,
            name=self.environment,
            can_admins_bypass=False,
            deployment_branch_policy=dict(protected_branches=True, custom_branch_policies=False),
            protection_rules=[
                dict(
                    type="required_reviewers",
                    prevent_self_review=True,
                    reviewers=[dict(type="User", reviewer=dict(id=8, login="reviewer"))],
                )
            ],
        )
        self.approvals: list[dict[str, Any]] = [
            dict(
                state="approved",
                comment="",
                user=dict(id=8, login="reviewer"),
                environments=[dict(id=99, name=self.environment)],
            )
        ]
        self.principal = f"arn:aws:sts::123456789012:assumed-role/cloud-{stage}/sdd-123"
        self.account = "123456789012"
        self.lease_end = NOW + 300
        self.azure_claims = dict(
            oid=OBJECT if stage == "prepare" else APPLY_OBJECT,
            tid=TENANT,
            appid=CLIENT if stage == "prepare" else APPLY_CLIENT,
            aud="https://management.azure.com/",
            iat=NOW - 10,
            nbf=NOW - 10,
            exp=NOW + 300,
        )
        self.subscription = dict(subscriptionId=SUBSCRIPTION, tenantId=TENANT, state="Enabled")
        self.calls = []
        self.fail_suffix = None
        self.raw_approvals = None

    def request(self, method, url, headers, body=None):
        self.calls.append((method, url, dict(headers), body))
        if self.fail_suffix and self.fail_suffix in url:
            raise OSError("synthetic-private-error")
        if url.startswith(OIDC_URL + "&audience="):
            assert method == "GET" and headers["Authorization"] == "Bearer synthetic-oidc-bearer"
            return encode(dict(value=jwt(self.claims)))
        base = f"https://api.github.com/repos/{REPO}"
        if url.startswith(base):
            assert method == "GET" and body is None
            assert headers["Authorization"] == "Bearer synthetic-github-bearer"
            assert headers["Accept"] == "application/vnd.github+json"
            assert headers["X-GitHub-Api-Version"] == "2022-11-28"
            if url == base + "/actions/runs/123":
                return encode(self.run)
            if url == base + "/actions/runs/123/approvals":
                return self.raw_approvals if self.raw_approvals is not None else encode(self.approvals)
            if url == base + "/environments/" + self.environment:
                return encode(self.environment_response)
        if url == "https://sts.amazonaws.com/":
            assert method == "POST"
            args = parse_qs(body.decode())
            assert args["Version"] == ["2011-06-15"]
            if args["Action"] == ["AssumeRoleWithWebIdentity"]:
                assert args["RoleArn"] == [f"arn:aws:iam::123456789012:role/cloud-{self.stage}"]
                assert args["RoleSessionName"] == ["sdd-123"]
                assert args["WebIdentityToken"] == [jwt(self.claims)]
                return (
                    f'<AssumeRoleWithWebIdentityResponse xmlns="https://sts.amazonaws.com/doc/2011-06-15/">'
                    f"<AssumeRoleWithWebIdentityResult><SubjectFromWebIdentityToken>{self.subject}</SubjectFromWebIdentityToken>"
                    f"<Audience>sts.amazonaws.com</Audience><Provider>https://token.actions.githubusercontent.com</Provider>"
                    f"<AssumedRoleUser><Arn>{self.principal}</Arn></AssumedRoleUser><Credentials>"
                    f"<AccessKeyId>SYNTHETICKEY</AccessKeyId><SecretAccessKey>synthetic-secret</SecretAccessKey>"
                    f"<SessionToken>synthetic-session</SessionToken><Expiration>{utc(self.lease_end)}</Expiration>"
                    "</Credentials></AssumeRoleWithWebIdentityResult></AssumeRoleWithWebIdentityResponse>"
                ).encode()
            assert args["Action"] == ["GetCallerIdentity"]
            assert headers["Authorization"].startswith("AWS4-HMAC-SHA256 Credential=SYNTHETICKEY/")
            assert headers["X-Amz-Security-Token"] == "synthetic-session"
            return (
                f'<GetCallerIdentityResponse xmlns="https://sts.amazonaws.com/doc/2011-06-15/">'
                f"<GetCallerIdentityResult><Account>{self.account}</Account><Arn>{self.principal}</Arn>"
                "<UserId>SYNTHETIC:sdd-123</UserId></GetCallerIdentityResult></GetCallerIdentityResponse>"
            ).encode()
        if url == f"https://login.microsoftonline.com/{TENANT}/oauth2/v2.0/token":
            assert method == "POST"
            args = parse_qs(body.decode())
            assert args == dict(
                client_id=[self.azure_claims["appid"]],
                grant_type=["client_credentials"],
                scope=["https://management.azure.com/.default"],
                client_assertion_type=["urn:ietf:params:oauth:client-assertion-type:jwt-bearer"],
                client_assertion=[jwt(self.claims)],
            )
            return encode(dict(token_type="Bearer", expires_in=300, access_token=jwt(self.azure_claims)))
        if url == f"https://management.azure.com/subscriptions/{SUBSCRIPTION}?api-version=2022-12-01":
            assert method == "GET" and headers["Authorization"] == "Bearer " + jwt(self.azure_claims)
            return encode(self.subscription)
        raise AssertionError("Unexpected deterministic transport request: " + url)


class Admission(unittest.TestCase):
    def setUp(self):
        self.assertTrue((SCRIPTS / "cloud_authorization.py").is_file(), "T-003 admission boundary is absent")
        import cloud_authorization

        self.a = cloud_authorization
        self.tmp = tempfile.TemporaryDirectory(prefix="cloud-T-003-fixture-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.evidence = self.root / "evidence"
        self.evidence.mkdir()
        self.writes = []
        self.local_mode = False
        self.anchor = patch.dict(os.environ, {"CLOUD_WORKSPACE_ROOT": str(self.root)})
        self.anchor.start()
        self.addCleanup(self.anchor.stop)

    def put(self, path, value):
        if self.local_mode:
            if path in ("source.bin", "compiled.bin", "asset.bin", "parameters.bin", "module.bin"):
                path = "bundle/unit/" + path
            elif path in ("policy.json", "profile.json", "lock.json", "tool.json") or path.startswith("upstream/"):
                path = "bundle/" + path
            elif path in ("preview.json", "changes.json"):
                path = self.request["local_context"]["evidence_directory"] + "/" + path
        data = value if isinstance(value, bytes) else encode(value)
        dest = self.root / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        return dict(path=path, sha256=hashlib.sha256(data).hexdigest())

    def setup_case(self, provider="aws", stage="prepare"):
        self.local_mode = False
        spec = importlib.util.spec_from_file_location(
            "contract_fixtures", ROOT / "tests/cloud-orchestration-contracts.tests.py"
        )
        assert spec is not None and spec.loader is not None
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        fixtures = module.fixtures()
        lock = fixtures["cloud-dependency-lock/v1"]
        for item in lock["upstream"][0]["files"]:
            self.put(item["path"], b"fixture")
        self.put("tool.json", b"fixture")
        lock_ref = self.put("lock.json", lock)
        policy_ref = self.put("policy.json", b"synthetic-external-policy-copy")
        profile_ref = self.put("profile.json", b"synthetic-profile")
        request = fixtures["cloud-run-request/v1"]
        request.update(
            operation="apply",
            environment="sandbox",
            provider=provider,
            dependency_lock=lock_ref,
            policy=policy_ref,
            verification_profile=dict(id="health", version="1", **profile_ref),
        )
        if provider == "azure":
            request.update(owner="bicep", route="azure-bicep")
            request["scope"].update(account_id=SUBSCRIPTION, region="eastus", deployment_scope="group-1")
        for item in request["input_artifacts"]:
            self.put(item["path"], b"fixture")
        module.install_local_context(self.root, request)
        self.local_mode = True
        self.evidence = self.root / request["local_context"]["evidence_directory"]
        policy_ref = request["policy"]
        lock_ref = request["dependency_lock"]
        profile_ref = {k: request["verification_profile"][k] for k in ("path", "sha256")}
        self.request = request
        self.request_ref = self.put("request.json", request)
        self.preview_ref = None
        if stage == "apply":
            preview = fixtures["cloud-preview/v1"]
            changes = self.put("changes.json", b"synthetic-changes")
            preview.update(
                provider=provider,
                scope=copy.deepcopy(request["scope"]),
                request=self.request_ref,
                policy=policy_ref,
                dependency_lock=lock_ref,
                verification_profile=profile_ref,
                changes=changes,
                semantic_sha256=changes["sha256"],
            )
            self.preview_ref = self.put("preview.json", preview)
        self.transport = DeterministicTransport(provider, stage)
        self.transport.run["display_title"] = (
            "cloud:"
            + self.request_ref["sha256"]
            + ":"
            + (self.preview_ref["sha256"] if self.preview_ref else "none")
        )
        self.policy = self.a.Policy(
            provider=provider,
            repository=REPO,
            repository_id=42,
            workflow=WORKFLOW,
            workflow_revision=REV,
            ref="refs/heads/main",
            operation=stage,
            environment="sandbox-" + stage,
            target_environment="sandbox",
            environment_id=99,
            account_id=request["scope"]["account_id"],
            region=request["scope"]["region"],
            deployment_scope=request["scope"]["deployment_scope"],
            policy_sha256=policy_ref["sha256"],
            actors=((7, "operator"),),
            reviewers=((8, "reviewer"),),
            exclusive_repository=REPO,
            ttl_seconds=120,
            aws_role_arn=f"arn:aws:iam::123456789012:role/cloud-{stage}",
            azure_tenant=TENANT,
            azure_client=CLIENT if stage == "prepare" else APPLY_CLIENT,
            azure_principal=OBJECT if stage == "prepare" else APPLY_OBJECT,
        )
        self.runtime = self.a.Runtime("synthetic-github-bearer", OIDC_URL, "synthetic-oidc-bearer")
        self.boundary = self.a.WriteBoundary(
            self.policy, self.runtime, self.evidence, transport=self.transport, clock=lambda: NOW
        )

    def write(self, boundary=None, mutation="submit"):
        return (boundary or self.boundary).write(
            self.root,
            self.request_ref,
            self.preview_ref,
            mutation_id=mutation,
            submit=lambda credentials: self.writes.append("write"),
            scan=lambda b: True,
        )

    def denied(self):
        with self.assertRaises(self.a.AdmissionDenied):
            self.write()
        self.assertEqual(self.writes, [])

    def test_native_positive_both_stages_providers_and_receipt_contract(self):
        for provider in ("aws", "azure"):
            for stage in ("prepare", "apply"):
                with self.subTest(provider=provider, stage=stage):
                    self.setup_case(provider, stage)
                    # Each fixture is an independent protected job evidence directory.
                    for p in self.evidence.glob("*.authorization.json"):
                        p.unlink()
                    ref, _ = self.write()
                    receipt = contracts.parse_artifact(contracts.read_verified(self.root, ref))
                    self.assertEqual(receipt["schema"], "cloud-authorization-receipt/v1")
                    for field in ("run_id", "unit_id", "provider", "scope", "dependency_lock", "policy"):
                        self.assertEqual(receipt[field], self.request[field])
                    self.assertEqual(receipt["request"], self.request_ref)
                    self.assertEqual(receipt["preview"], self.preview_ref)
                    self.assertEqual(receipt["operation"], stage)
                    self.assertEqual(receipt["issued_at"], utc(NOW - 10))
                    self.assertEqual(receipt["expires_at"], utc(NOW + 110))
                    self.assertEqual(
                        receipt["ci"],
                        dict(
                            repository=REPO,
                            workflow=WORKFLOW,
                            workflow_revision=REV,
                            ref="refs/heads/main",
                            environment="sandbox-" + stage,
                            run_id="123",
                            run_attempt=1,
                        ),
                    )
                    self.assertEqual(receipt["subject"], self.transport.subject)
                    self.assertEqual(receipt["issuer"], "https://token.actions.githubusercontent.com")
                    self.assertEqual(
                        receipt["principal"], self.transport.principal if provider == "aws" else self.transport.azure_claims["oid"]
                    )
                    self.assertEqual(
                        receipt["approval_evidence"],
                        dict(
                            locator=f"https://api.github.com/repos/{REPO}/actions/runs/123/approvals",
                            sha256=hashlib.sha256(encode(self.transport.approvals)).hexdigest(),
                        ),
                    )
                    self.assertNotIn(b"synthetic-secret", encode(receipt))
        self.assertEqual(len(self.writes), 4)

    def test_local_flags_receipts_and_missing_runtime_never_authorize(self):
        self.setup_case()
        self.put("approved.json", dict(approved=True))
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "true", "CLOUD_APPROVED": "true"}):
            self.boundary = self.a.WriteBoundary(
                self.policy,
                self.a.Runtime("", "", ""),
                self.evidence,
                transport=self.transport,
                clock=lambda: NOW,
            )
            self.denied()
        self.assertEqual(self.transport.calls, [])

    def test_each_authenticated_oidc_binding_mismatch_denies(self):
        changes = dict(
            iss="https://example.invalid",
            sub="forged",
            aud="other",
            repository="other/repo",
            repository_id="43",
            workflow_ref="other",
            workflow_sha="b" * 40,
            ref="refs/heads/other",
            sha="b" * 40,
            run_id="124",
            run_attempt="2",
            actor_id="9",
            actor="other",
            environment="other",
            event_name="pull_request",
            iat=NOW + 1,
            nbf=NOW + 1,
            exp=NOW,
        )
        for key, value in changes.items():
            with self.subTest(field=key):
                self.setup_case()
                self.transport.claims[key] = value
                self.denied()

    def test_each_authenticated_run_binding_mismatch_denies(self):
        changes = dict(
            id=124,
            run_attempt=2,
            status="completed",
            conclusion="cancelled",
            event="push",
            head_sha="b" * 40,
            head_branch="other",
            path="other.yml",
            display_title="cloud:forged",
            repository=dict(id=43, full_name=REPO),
            head_repository=dict(id=43, full_name=REPO),
            actor=dict(id=9, login="operator"),
            triggering_actor=dict(id=9, login="operator"),
        )
        for key, value in changes.items():
            with self.subTest(field=key):
                self.setup_case()
                self.transport.run[key] = value
                self.denied()

    def test_absent_revoked_denied_unknown_duplicate_approval_history(self):
        for stage in ("prepare", "apply"):
            for case in (
                "empty",
                "rejected",
                "pending",
                "duplicate",
                "wrong-user",
                "wrong-env",
                "missing-user",
            ):
                with self.subTest(stage=stage, case=case):
                    self.setup_case(stage=stage)
                    if case == "empty":
                        self.transport.approvals = []
                    elif case == "duplicate":
                        self.transport.approvals *= 2
                    elif case == "wrong-user":
                        self.transport.approvals[0]["user"]["id"] = 9
                    elif case == "wrong-env":
                        self.transport.approvals[0]["environments"][0]["id"] = 100
                    elif case == "missing-user":
                        del self.transport.approvals[0]["user"]
                    else:
                        self.transport.approvals[0]["state"] = case
                    self.denied()
        self.setup_case()
        denied = copy.deepcopy(self.transport.approvals[0])
        denied["state"] = "rejected"
        self.transport.approvals.append(denied)
        self.denied()

    def test_environment_policy_and_missing_api_data_fail_closed(self):
        for field, value in [
            ("id", 100),
            ("name", "other"),
            ("can_admins_bypass", True),
            ("deployment_branch_policy", None),
            ("protection_rules", []),
        ]:
            self.setup_case()
            self.transport.environment_response[field] = value
            self.denied()
        for endpoint in ("/approvals", "/environments/", "/actions/runs/"):
            self.setup_case()
            self.transport.fail_suffix = endpoint
            self.denied()
        self.setup_case()
        self.transport.raw_approvals = b'[{"state":"approved","state":"rejected"}]'
        self.denied()

    def test_provider_identity_and_lease_mismatch_before_each_stage(self):
        for stage in ("prepare", "apply"):
            for case in ("principal", "account", "lease"):
                self.setup_case(stage=stage)
                if case == "principal":
                    self.transport.principal += "-other"
                if case == "account":
                    self.transport.account = "999999999999"
                if case == "lease":
                    self.transport.lease_end = NOW
                self.denied()
            for key in ("oid", "tid", "appid", "aud", "exp"):
                self.setup_case("azure", stage)
                self.transport.azure_claims[key] = NOW if key == "exp" else "other"
                self.denied()
            self.setup_case("azure", stage)
            self.transport.subscription["subscriptionId"] = TENANT
            self.denied()

    def test_manifest_and_scope_rebinding_never_matches_authenticated_dispatch(self):
        for field in ("account_id", "region", "deployment_scope"):
            self.setup_case()
            self.request["scope"][field] = "other"
            self.request_ref = self.put("request.json", self.request)
            self.denied()
        for field, value in [
            ("operation", "prepare"),
            ("environment", "other"),
            ("run_id", "other"),
            ("unit_id", "other"),
            ("source_revision", "b" * 40),
        ]:
            self.setup_case()
            self.request[field] = value
            self.request_ref = self.put("request.json", self.request)
            self.denied()
        self.setup_case()
        self.put("asset.bin", b"swapped")
        self.denied()
        self.setup_case()
        self.request["policy"] = self.put("policy.json", b"changed")
        self.request_ref = self.put("request.json", self.request)
        self.denied()

    def test_replay_different_instance_tamper_and_unknown_submission_no_retry(self):
        self.setup_case()
        ref, _ = self.write()
        self.assertEqual(self.writes, ["write"])
        with self.assertRaises(self.a.AdmissionDenied):
            self.write()
        other = self.a.WriteBoundary(
            self.policy, self.runtime, self.evidence, transport=self.transport, clock=lambda: NOW
        )
        with self.assertRaises(self.a.AdmissionDenied):
            self.write(other)
        self.assertEqual(self.writes, ["write"])
        data = contracts.read_verified(self.root, ref)
        (self.root / ref["path"]).write_bytes(data.replace(b'"prepare"', b'"apply"'))
        with self.assertRaises(self.a.AdmissionDenied):
            self.write(other)
        self.assertEqual(self.writes, ["write"])

    def test_timeout_is_not_retried_and_receipt_is_retained(self):
        self.setup_case()

        def submit(_):
            self.writes.append("uncertain")
            raise TimeoutError("synthetic timeout")

        with self.assertRaises(TimeoutError):
            self.boundary.write(
                self.root, self.request_ref, None, mutation_id="submit", submit=submit, scan=lambda b: True
            )
        with self.assertRaises(self.a.AdmissionDenied):
            self.write()
        self.assertEqual(self.writes, ["uncertain"])
        self.assertEqual(len(list(self.evidence.iterdir())), 1)

    def test_fresh_checks_on_every_mutation_and_dependency_default_denial(self):
        self.setup_case()
        self.write(mutation="asset-1")
        self.transport.approvals = []
        with self.assertRaises(self.a.AdmissionDenied):
            self.write(mutation="asset-2")
        self.assertEqual(self.writes, ["write"])
        self.writes.clear()
        self.setup_case()
        self.request["predecessor_receipts"] = [dict(unit_id="prior", **self.put("prior.json", b"fixture"))]
        self.request_ref = self.put("request.json", self.request)
        self.transport.run["display_title"] = "cloud:" + self.request_ref["sha256"] + ":none"
        self.denied()

    def test_untrusted_endpoint_and_publication_failure_have_zero_writes(self):
        for url in (
            "https://example.invalid/token",
            OIDC_URL.replace("https:", "http:"),
            "https://pipelines.actions.githubusercontent.com@evil.invalid/token",
        ):
            self.setup_case()
            self.boundary = self.a.WriteBoundary(
                self.policy,
                replace(self.runtime, oidc_url=url),
                self.evidence,
                transport=self.transport,
                clock=lambda: NOW,
            )
            self.denied()
            self.assertEqual(self.transport.calls, [])
        self.setup_case()
        with self.assertRaises(self.a.AdmissionDenied):
            self.boundary.write(
                self.root,
                self.request_ref,
                None,
                mutation_id="submit",
                submit=lambda _: self.writes.append("write"),
                scan=lambda b: False,
            )
        self.assertEqual(self.writes, [])

    def test_concurrency_key_conservative_canonical_and_scope_prerequisite(self):
        self.setup_case()
        key = self.a.concurrency_key(self.policy)
        self.assertEqual(key, "cloud-aws-123456789012-us-east-1")
        self.assertEqual(key, self.a.concurrency_key(replace(self.policy, deployment_scope="another-stack")))
        self.boundary = self.a.WriteBoundary(
            replace(self.policy, exclusive_repository="other/repo"),
            self.runtime,
            self.evidence,
            transport=self.transport,
            clock=lambda: NOW,
        )
        self.denied()

    def test_https_transport_disallows_redirects_and_sanitizes_failures(self):
        self.assertTrue(
            issubclass(
                self.a.NoRedirect,
                __import__("urllib.request", fromlist=["HTTPRedirectHandler"]).HTTPRedirectHandler,
            )
        )
        with patch("urllib.request.OpenerDirector.open", side_effect=OSError("synthetic-sensitive-error")):
            with self.assertRaises(self.a.AdmissionDenied) as caught:
                self.a.HttpsTransport().request("GET", "https://api.github.com/", {})
        self.assertNotIn("sensitive", str(caught.exception))

    def test_templates_have_distinct_environments_roles_and_no_cancellation(self):
        for provider in ("aws", "azure"):
            content = (ROOT / f"templates/cloud/github-{provider}.yml").read_text()
            workflow = json.loads(content)
            self.assertIs(workflow["concurrency"]["cancel-in-progress"], False)
            self.assertNotIn("${{", workflow["concurrency"]["group"])
            self.assertIn("sandbox-prepare", content)
            self.assertIn("sandbox-apply", content)
            self.assertEqual(workflow["jobs"]["prepare"]["permissions"]["id-token"], "write")
            self.assertEqual(workflow["jobs"]["apply"]["permissions"]["id-token"], "write")
            self.assertIn("inputs.request_sha256", content)
            self.assertIn("inputs.preview_sha256", content)
            self.assertIn("exclusive", content)
        policies = list((ROOT / "templates/cloud/iam").glob("*.json"))
        self.assertGreaterEqual(len(policies), 4)
        for path in policies:
            json.loads(path.read_bytes())

    def test_expiry_after_final_binding_denies_and_retains_consumed_receipt(self):
        for provider in ("aws", "azure"):
            for stage in ("prepare", "apply"):
                for elapsed in (109, 110, 111):
                    with self.subTest(provider=provider, stage=stage, elapsed=elapsed):
                        self.setup_case(provider, stage)
                        self.writes.clear()
                        for receipt in self.evidence.glob("*.authorization.json"):
                            receipt.unlink()
                        original = contracts.verify_binding
                        calls = []

                        def verify(*args, **kwargs):
                            result = original(*args, **kwargs)
                            calls.append(True)
                            if len(calls) == 3:
                                self.boundary.clock = lambda: NOW + elapsed
                            return result

                        with patch.object(contracts, "verify_binding", side_effect=verify):
                            if elapsed < 110:
                                self.write()
                                self.assertEqual(self.writes, ["write"])
                            else:
                                with self.assertRaises(self.a.AdmissionDenied):
                                    self.write()
                                self.assertEqual(self.writes, [])
                        self.assertEqual(len(calls), 3)
                        self.assertEqual(len(list(self.evidence.glob("*.authorization.json"))), 1)

    def test_preview_expiry_after_final_binding_denies_and_retains_receipt(self):
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

    def test_expiry_or_artifact_swap_during_scan_denies_before_submit(self):
        for case in ("expiry", "swap", "revoked"):
            with self.subTest(case=case):
                self.setup_case("azure")
                for p in self.evidence.glob("*.authorization.json"):
                    p.unlink()

                def scan(_):
                    if case == "expiry":
                        self.boundary.clock = lambda: NOW + 1000
                    elif case == "revoked":
                        self.transport.approvals = []
                    else:
                        self.put("asset.bin", b"changed-during-scan")
                    return True

                with self.assertRaises(self.a.AdmissionDenied):
                    self.boundary.write(
                        self.root,
                        self.request_ref,
                        None,
                        mutation_id="submit",
                        submit=lambda _: self.writes.append("write"),
                        scan=scan,
                    )
                self.assertEqual(self.writes, [])

    def test_all_bound_artifact_mutations_and_preview_dispatch_mismatch(self):
        for path in (
            "source.bin",
            "compiled.bin",
            "asset.bin",
            "parameters.bin",
            "module.bin",
            "policy.json",
            "profile.json",
            "lock.json",
            "upstream/main.md",
            "tool.json",
        ):
            with self.subTest(path=path):
                self.setup_case(stage="apply")
                self.put(path, b"changed")
                self.denied()
        self.setup_case(stage="apply")
        assert self.preview_ref is not None
        preview = json.loads((self.root / self.preview_ref["path"]).read_bytes())
        preview["preview_identity"] = "other-native-preview"
        self.preview_ref = self.put("preview.json", preview)
        self.denied()

    def test_revocation_during_federation_and_missing_native_identity_denies(self):
        for provider in ("aws", "azure"):
            for stage in ("prepare", "apply"):
                for case in ("revoked", "missing"):
                    with self.subTest(provider=provider, stage=stage, case=case):
                        self.setup_case(provider, stage)
                        original = self.transport.request

                        def transport(method, url, headers, body=None):
                            data = original(method, url, headers, body)
                            if (
                                provider == "aws" and b"GetCallerIdentity" in (body or b"")
                            ) or url.startswith("https://management.azure.com/"):
                                if case == "missing":
                                    return b"{}"
                                self.transport.approvals = []
                            return data

                        with patch.object(self.transport, "request", side_effect=transport):
                            self.denied()

    def test_any_denied_or_unexpected_environment_history_requires_fresh_dispatch(self):
        self.setup_case()
        extra = copy.deepcopy(self.transport.approvals[0])
        extra["state"] = "rejected"
        extra["environments"] = [dict(id=100, name="other-environment")]
        self.transport.approvals.append(extra)
        self.denied()

    def test_missing_oidc_claims_ambiguous_reviewers_and_lease_ttl(self):
        self.setup_case()
        keys = list(self.transport.claims)
        for key in keys:
            with self.subTest(key=key):
                self.setup_case()
                del self.transport.claims[key]
                self.denied()
        self.setup_case()
        self.transport.environment_response["protection_rules"][0]["prevent_self_review"] = False
        self.denied()
        self.setup_case()
        self.transport.environment_response["protection_rules"][0]["reviewers"][0]["type"] = "Team"
        self.denied()
        self.setup_case()
        self.boundary.clock = lambda: NOW + 120
        self.denied()

    def test_native_https_success_redirect_and_size_contract(self):
        from io import BytesIO

        class Response(BytesIO):
            status = 200

            def geturl(self):
                return "https://api.github.com/"

        with patch("urllib.request.OpenerDirector.open", return_value=Response(b"{}")) as opened:
            self.assertEqual(self.a.HttpsTransport().request("GET", "https://api.github.com/", {}), b"{}")
            self.assertEqual(opened.call_args.kwargs["timeout"], 20)
        with self.assertRaises(self.a.AdmissionDenied):
            self.a.NoRedirect().redirect_request(None, None, 302, "redirect", {}, "https://example.invalid/")
        with patch(
            "urllib.request.OpenerDirector.open", return_value=Response(b"x" * (self.a.MAX_RESPONSE + 1))
        ):
            with self.assertRaises(self.a.AdmissionDenied):
                self.a.HttpsTransport().request("GET", "https://api.github.com/", {})

    def test_iam_templates_restrict_native_subjects_and_stage_actions(self):
        for stage in ("prepare", "apply"):
            trust = json.loads((ROOT / f"templates/cloud/iam/aws-{stage}-trust.json").read_bytes())
            statement = trust["Statement"][0]
            self.assertEqual(statement["Action"], "sts:AssumeRoleWithWebIdentity")
            condition = statement["Condition"]["StringEquals"]
            self.assertEqual(condition["token.actions.githubusercontent.com:aud"], "sts.amazonaws.com")
            self.assertIn(
                ":environment:sandbox-" + stage + ":workflow_ref:",
                condition["token.actions.githubusercontent.com:sub"],
            )
            permissions = json.loads(
                (ROOT / f"templates/cloud/iam/aws-{stage}-permissions.json").read_bytes()
            )
            actions = {a for statement in permissions["Statement"] for a in statement["Action"]}
            if stage == "prepare":
                self.assertIn("s3:PutObject", actions)
                self.assertIn("cloudformation:CreateChangeSet", actions)
                self.assertNotIn("cloudformation:ExecuteChangeSet", actions)
            else:
                self.assertIn("cloudformation:ExecuteChangeSet", actions)
                self.assertNotIn("s3:PutObject", actions)
                self.assertNotIn("cloudformation:CreateChangeSet", actions)
            self.assertNotIn("*", actions)
            self.assertIn(
                ":workflow_sha:REPLACE_REVIEWED_40_HEX_CONTROL_COMMIT",
                condition["token.actions.githubusercontent.com:sub"],
            )
            federation = json.loads(
                (ROOT / f"templates/cloud/iam/azure-{stage}-federation.json").read_bytes()
            )
            self.assertEqual(federation["audiences"], ["api://AzureADTokenExchange"])
            self.assertIn(":environment:sandbox-" + stage + ":workflow_ref:", federation["subject"])
            role = json.loads((ROOT / f"templates/cloud/iam/azure-{stage}-role.json").read_bytes())
            self.assertEqual("Microsoft.Resources/deployments/write" in role["Actions"], stage == "apply")
            self.assertNotIn("*", role["Actions"])


    def test_repair_same_request_prepare_preview_apply_separate_policies(self):
        for provider in ("aws", "azure"):
            self.setup_case(provider, "prepare")
            for file in self.evidence.iterdir():
                file.unlink()
            request_bytes = (self.root / self.request_ref["path"]).read_bytes()
            request_ref = dict(self.request_ref)
            prepare_policy = self.policy
            prepare_ref, _ = self.write(mutation="prepare-preview")
            prepare_receipt = contracts.read_artifact(self.root, prepare_ref)
            self.assertEqual(prepare_receipt["operation"], "prepare")
            # Separate protected apply identity; never rewrite the frozen request.
            self.policy = replace(self.policy, operation="apply", environment="sandbox-apply",
                aws_role_arn="arn:aws:iam::123456789012:role/cloud-apply",
                azure_client=APPLY_CLIENT, azure_principal=APPLY_OBJECT)
            self.transport = DeterministicTransport(provider, "apply")
            changes = self.put("changes.json", b"synthetic-preview")
            preview = dict(schema="cloud-preview/v1",
                **{k: self.request[k] for k in ("run_id", "unit_id", "provider", "scope", "policy", "dependency_lock")},
                request=self.request_ref, verification_profile={k: self.request["verification_profile"][k] for k in ("path", "sha256")},
                preview_identity="synthetic-preview", changes=changes, semantic_sha256=changes["sha256"],
                replacements=[], deletes=[], created_at=utc(NOW), expires_at=utc(NOW + 300))
            self.preview_ref = self.put("preview.json", preview)
            self.transport.run["display_title"] = f"cloud:{request_ref['sha256']}:{self.preview_ref['sha256']}"
            self.boundary = self.a.WriteBoundary(self.policy, self.runtime, self.evidence,
                transport=self.transport, clock=lambda: NOW)
            apply_ref, _ = self.write(mutation="apply-exact-preview")
            apply_receipt = contracts.read_artifact(self.root, apply_ref)
            self.assertEqual(apply_receipt["operation"], "apply")
            self.assertNotEqual(prepare_receipt["ci"]["environment"], apply_receipt["ci"]["environment"])
            self.assertEqual(prepare_policy.policy_sha256, self.policy.policy_sha256)
            self.assertNotEqual(prepare_receipt["subject"], apply_receipt["subject"])
            self.assertNotEqual(prepare_receipt["principal"], apply_receipt["principal"])
            self.assertEqual(prepare_receipt["request"], apply_receipt["request"])
            self.assertEqual(request_bytes, (self.root / request_ref["path"]).read_bytes())
            contracts.verify_binding(self.root, request_ref, self.preview_ref, apply_ref,
                now=utc(NOW), operation="apply")
        self.assertEqual(len(self.writes), 4)

    def test_repair_stage_target_context_and_digest_controls_zero_submissions(self):
        for case in ("phase", "target", "protected", "digest", "missing-context", "missing-anchor", "evidence-root", "preview"):
            with self.subTest(case=case):
                self.setup_case(stage="apply")
                if case == "phase":
                    self.policy = replace(self.policy, operation="prepare")
                elif case == "target":
                    self.policy = replace(self.policy, target_environment="production")
                elif case == "protected":
                    self.transport.claims["environment"] = "sandbox-prepare"
                elif case == "digest":
                    self.policy = replace(self.policy, policy_sha256="b" * 64)
                elif case == "missing-context":
                    del self.request["local_context"]
                    self.request_ref = self.put("request.json", self.request)
                elif case == "missing-anchor":
                    os.environ.pop("CLOUD_WORKSPACE_ROOT", None)
                elif case == "evidence-root":
                    self.evidence = self.root
                else:
                    self.preview_ref = None
                self.boundary = self.a.WriteBoundary(self.policy, self.runtime, self.evidence,
                    transport=self.transport, clock=lambda: NOW)
                self.denied()


# T-012: native ARM request shapes, deterministic transports only; never live IAM.
class AzureExecution(unittest.TestCase):
    def setUp(self):
        import shutil

        sys.path.insert(0, str(ROOT / "plugins/sdd-azure-cloud/scripts"))
        self.assertTrue(
            (ROOT / "plugins/sdd-azure-cloud/scripts/azure_execution.py").is_file(),
            "T-012 governed Azure executor is absent",
        )
        import azure_execution as execution
        import cloud_authorization as auth

        self.e, self.a = execution, auth
        self.tmp = tempfile.TemporaryDirectory(prefix="cloud-T012-synthetic-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        source = (
            ROOT
            / "specs/cloud-orchestration/verification/T-012/inputs/native-workspace/bundle"
        )
        shutil.copytree(source, self.root / "bundle")
        locked = next((self.root / "bundle/generated").glob("*.request.json"))
        self.req = json.loads(locked.read_bytes())
        self.request_bytes = locked.read_bytes()
        self.request_ref = dict(
            path=str(locked.relative_to(self.root)),
            sha256=hashlib.sha256(self.request_bytes).hexdigest(),
        )
        self.directory = self.req["local_context"]["evidence_directory"]
        (self.root / self.directory).mkdir(parents=True)
        self.anchor = patch.dict(os.environ, {"CLOUD_WORKSPACE_ROOT": str(self.root)})
        self.anchor.start()
        self.addCleanup(self.anchor.stop)
        self.arm = ArmFixture(execution, self.req)
        self.auths = []
        self.executor = self.stage("prepare")

    def stage(self, stage, preview=None):
        transport = AzureAuthFixture(stage, self.req["scope"]["account_id"])
        transport.run["display_title"] = (
            "cloud:"
            + self.request_ref["sha256"]
            + ":"
            + (preview["sha256"] if preview else "none")
        )
        self.auths.append(transport)
        scope = self.req["scope"]
        policy = self.a.Policy(
            provider="azure",
            repository=REPO,
            repository_id=42,
            workflow=WORKFLOW,
            workflow_revision=REV,
            ref="refs/heads/main",
            operation=stage,
            environment="sandbox-" + stage,
            target_environment=self.req["environment"],
            environment_id=99,
            **scope,
            policy_sha256=self.req["policy"]["sha256"],
            actors=((7, "operator"),),
            reviewers=((8, "reviewer"),),
            exclusive_repository=REPO,
            ttl_seconds=120,
            azure_tenant=TENANT,
            azure_client=CLIENT if stage == "prepare" else APPLY_CLIENT,
            azure_principal=OBJECT if stage == "prepare" else APPLY_OBJECT,
        )
        boundary = self.a.WriteBoundary(
            policy,
            self.a.Runtime(
                "synthetic-github-bearer", OIDC_URL, "synthetic-oidc-bearer"
            ),
            self.root / self.directory,
            transport=transport,
            clock=lambda: NOW,
        )
        return self.e.AzureExecutor(
            self.root,
            self.request_ref,
            boundary,
            arm=self.arm,
            clock=lambda: NOW,
            sleep=lambda _: None,
        )

    def prepare(self):
        result = self.executor.prepare(self.directory + "/prepare.json")
        self.assertEqual(result["result"], "PASS", result)
        self.preview_ref = json.loads(
            (self.root / result["evidence_manifest_path"]).read_bytes()
        )["preview"]
        self.executor = self.stage("apply", self.preview_ref)
        return result

    def apply(self, output="apply.json"):
        return self.executor.apply(self.preview_ref, self.directory + "/" + output)

    def test_exact_manifest_native_incremental_single_submission_no_compiler(self):
        with patch(
            "subprocess.run",
            side_effect=AssertionError("Credentialed compiler execution"),
        ):
            self.prepare()
            result = self.apply()
        self.assertEqual((result["state"], result["result"]), ("OBSERVED", "PASS"))
        self.assertNotIn(result["state"], ("VERIFIED", "EVIDENCE_COMPLETE"))
        self.assertEqual(self.arm.submissions, 1)
        self.assertEqual(
            (self.root / self.request_ref["path"]).read_bytes(), self.request_bytes
        )
        posts = [
            json.loads(body) for method, _, body in self.arm.calls if method == "POST"
        ]
        puts = [
            json.loads(body) for method, _, body in self.arm.calls if method == "PUT"
        ]
        self.assertEqual(len(posts), 2)
        self.assertEqual(posts[0], posts[1])
        self.assertEqual(posts[0]["properties"]["validationLevel"], "ProviderNoRbac")
        self.assertEqual(puts[0]["properties"]["mode"], "Incremental")
        for body in posts + puts:
            self.assertEqual(body["properties"]["template"], self.arm.template.decode())
            self.assertEqual(
                body["properties"]["parameters"], self.arm.parameters["parameters"]
            )
        self.assertEqual(self.auths[0].azure_claims["oid"], OBJECT)
        self.assertEqual(self.auths[1].azure_claims["oid"], APPLY_OBJECT)
        self.assertTrue(
            all("api-version=2025-04-01" in url for _, url, _ in self.arm.calls)
        )

    def test_bound_field_mismatch_matrix_zero_deployments(self):
        self.prepare()
        targets = [
            self.request_ref,
            self.req["policy"],
            self.req["verification_profile"],
            self.req["dependency_lock"],
            self.req["local_context"]["ownership"],
            self.req["local_context"]["provider_config"],
            *self.req["input_artifacts"],
            self.preview_ref,
        ]
        for n, ref in enumerate(targets):
            with self.subTest(path=ref["path"]):
                p = self.root / ref["path"]
                original = p.read_bytes()
                p.write_bytes(original + b" ")
                self.assertEqual(
                    self.apply("mismatch-" + str(n) + ".json")["result"], "BLOCKED"
                )
                self.assertEqual(self.arm.submissions, 0)
                p.write_bytes(original)
        for field, value in (
            ("scope", {**self.req["scope"], "region": "westus"}),
            ("owner", "terraform"),
            ("run_id", "changed"),
        ):
            altered = {**self.req, field: value}
            p = self.root / self.request_ref["path"]
            p.write_bytes(encode(altered))
            self.assertEqual(
                self.apply("field-" + field + ".json")["result"], "BLOCKED"
            )
            p.write_bytes(self.request_bytes)
        self.assertEqual(self.arm.submissions, 0)

    def test_owner_conflict_added_after_preview_zero_submissions(self):
        self.prepare()
        (self.root / "bundle/unit/hidden.tf").write_text("")
        self.assertEqual(self.apply()["result"], "BLOCKED")
        self.assertEqual(self.arm.submissions, 0)

    def test_owner_race_during_final_admission_zero_submissions(self):
        self.prepare()
        original = self.auths[-1].request

        def mutate(method, url, headers, body=None):
            if (
                "/approvals" in url
                and len([x for x in self.arm.calls if x[0] == "POST"]) == 2
            ):
                (self.root / "bundle/unit/race.tf").write_text("")
            return original(method, url, headers, body)

        self.auths[-1].request = mutate
        self.assertEqual(self.apply()["result"], "BLOCKED")
        self.assertEqual(self.arm.submissions, 0)

    def test_semantic_drift_zero_submissions(self):
        self.prepare()
        self.arm.changes[0]["after"]["tags"] = {"changed": "yes"}
        self.assertEqual(self.apply()["result"], "BLOCKED")
        self.assertEqual(self.arm.submissions, 0)

    def test_reordered_semantics_still_one_submission(self):
        self.prepare()
        self.arm.changes.reverse()
        self.assertEqual(self.apply()["result"], "PASS")
        self.assertEqual(self.arm.submissions, 1)

    def test_unknown_destructive_potential_diagnostics_are_not_dropped(self):
        for change in (
            "Delete",
            "Deploy",
            "Ignore",
            "Unsupported",
            "Replace",
            "unknown",
        ):
            with self.subTest(change=change):
                value = copy.deepcopy(self.arm.preview())
                value["properties"]["changes"][0]["changeType"] = change
                with self.assertRaises(ValueError):
                    self.e.normalize_preview(
                        value, self.req, self.arm.resources, self.arm.ownership
                    )
        for field, value in (
            ("potentialChanges", [self.arm.changes[0]]),
            ("diagnostics", [{"level": "Error", "message": "synthetic"}]),
            ("unrecognized", []),
        ):
            body = self.arm.preview()
            body["properties"][field] = value
            with self.assertRaises(ValueError):
                self.e.normalize_preview(
                    body, self.req, self.arm.resources, self.arm.ownership
                )
        for kind in ("Delete", "unknown", "Array"):
            body = self.arm.preview()
            body["properties"]["changes"][0]["delta"] = [
                dict(path="properties.unsafe", propertyChangeType=kind)
            ]
            with self.assertRaises(ValueError):
                self.e.normalize_preview(
                    body, self.req, self.arm.resources, self.arm.ownership
                )
        self.assertEqual(self.arm.submissions, 0)

    def test_referenced_resources_only_explicit_additive_attachments(self):
        for rid in [x["resource_id"] for x in self.arm.ownership["existing_resources"]]:
            body = self.arm.preview()
            body["properties"]["changes"].append(
                dict(
                    resourceId=rid,
                    changeType="Modify",
                    before={},
                    after={"changed": True},
                    delta=[
                        dict(path="changed", propertyChangeType="Create", after=True)
                    ],
                )
            )
            with self.assertRaises(ValueError):
                self.e.normalize_preview(
                    body, self.req, self.arm.resources, self.arm.ownership
                )
        body = self.arm.preview()
        body["properties"]["changes"][0]["resourceId"] += "/unauthorized/child"
        with self.assertRaises(ValueError):
            self.e.normalize_preview(
                body, self.req, self.arm.resources, self.arm.ownership
            )
        self.prepare()
        self.assertEqual(self.apply()["result"], "PASS")

    def test_missing_revoked_expired_approvals_zero_submissions(self):
        self.prepare()
        auth = self.auths[-1]
        original = copy.deepcopy(auth.approvals)
        for n, history in enumerate(
            ([], [{**original[0], "state": "rejected"}], original * 2)
        ):
            auth.approvals = history
            self.assertEqual(
                self.apply("denied-" + str(n) + ".json")["result"], "BLOCKED"
            )
        auth.approvals = original
        auth.claims["exp"] = NOW
        self.assertEqual(self.apply("expired.json")["result"], "BLOCKED")
        self.assertEqual(self.arm.submissions, 0)

    def test_empty_authentic_preview_no_change_no_fabricated_apply_id(self):
        self.arm.changes = []
        result = self.executor.prepare(self.directory + "/prepare.json")
        self.assertEqual(result["result"], "NO_CHANGE")
        self.assertNotIn("native_operation_id", result)
        self.preview_ref = json.loads(
            (self.root / result["evidence_manifest_path"]).read_bytes()
        )["preview"]
        self.executor = self.stage("apply", self.preview_ref)
        result = self.apply()
        self.assertEqual(result["result"], "NO_CHANGE")
        self.assertNotIn("native_operation_id", result)
        self.assertEqual(self.arm.submissions, 0)
        self.assertEqual(len([x for x in self.arm.calls if x[0] == "POST"]), 2)

    def test_timeout_durable_original_id_reconcile_no_second_mutation(self):
        self.prepare()
        self.arm.timeout = True
        result = self.apply()
        self.assertEqual(result["result"], "UNKNOWN")
        journal = json.loads(
            (self.root / result["evidence_manifest_path"]).read_bytes()
        )
        operation = journal["submission"]
        self.assertEqual(
            json.loads((self.root / operation["path"]).read_bytes())[
                "native_operation_id"
            ],
            result["native_operation_id"],
        )
        self.assertEqual(self.apply("retry.json")["result"], "BLOCKED")
        calls = len(self.arm.calls)
        self.arm.timeout = False
        self.arm.existing = True
        recovered = self.executor.reconcile(
            operation, self.directory + "/reconcile.json"
        )
        self.assertEqual(
            recovered["native_operation_id"], result["native_operation_id"]
        )
        self.assertEqual(recovered["state"], "OBSERVED")
        self.assertTrue(all(x[0] == "GET" for x in self.arm.calls[calls:]))
        self.assertEqual(self.arm.submissions, 1)

    def test_async_location_and_status_headers_real_shapes(self):
        self.arm.asynchronous = True
        self.prepare()
        result = self.apply()
        self.assertEqual(result["result"], "PASS", result)
        self.assertGreaterEqual(len([x for x in self.arm.calls if x[0] == "GET"]), 4)
        self.assertEqual(self.arm.submissions, 1)

    def test_async_bad_or_missing_header_is_unknown_after_submission(self):
        for n, header in enumerate(
            (
                {},
                {"Location": "https://evil.invalid/poll"},
                {
                    "Location": "https://management.azure.com/subscriptions/other/operations/1?api-version=2025-04-01"
                },
                {
                    "Location": "https://management.azure.com/a/../b?api-version=2025-04-01"
                },
            )
        ):
            with self.subTest(header=header):
                # Each independent prepare has an exclusive stable marker: new fixture.
                self.setUp()
                self.arm.asynchronous = True
                self.arm.bad_headers = header
                result = self.executor.prepare(self.directory + "/bad.json")
                self.assertEqual(result["result"], "UNKNOWN")
                self.assertTrue(result["evidence_manifest_path"])
                self.assertEqual(self.arm.submissions, 0)

    def test_bounded_async_poll_and_failed_native_state_not_health(self):
        self.prepare()
        self.arm.asynchronous = True
        self.arm.pending = True
        result = self.apply()
        self.assertEqual(result["result"], "UNKNOWN")
        self.assertLessEqual(len(self.arm.calls), 40)
        submission = json.loads(
            (self.root / result["evidence_manifest_path"]).read_bytes()
        )["submission"]
        self.arm.pending = False
        self.arm.state = "Failed"
        self.arm.existing = True
        result = self.executor.reconcile(
            submission, self.directory + "/failed-reconcile.json"
        )
        self.assertEqual(result["result"], "FAIL")
        self.assertEqual(self.arm.submissions, 1)

    def test_admission_deadline_crossed_in_final_local_work_never_sends(self):
        for stage, limit in (
            ("prepare", "policy"),
            ("apply", "policy"),
            ("apply", "provider"),
            ("apply", "preview"),
        ):
            with self.subTest(stage=stage, limit=limit):
                self.setUp()
                if stage == "apply":
                    self.prepare()
                now = [NOW]
                self.executor.clock = lambda: now[0]
                self.executor.boundary.clock = lambda: now[0]
                deadline = NOW + 110
                if limit == "provider":
                    self.auths[-1].azure_claims["exp"] = NOW + 20
                    deadline = NOW + 20
                if limit == "preview":
                    path = self.root / self.preview_ref["path"]
                    preview = json.loads(path.read_bytes())
                    preview["expires_at"] = utc(NOW + 20)
                    path.write_bytes(encode(preview))
                    self.preview_ref["sha256"] = hashlib.sha256(
                        path.read_bytes()
                    ).hexdigest()
                    self.auths[-1].run["display_title"] = (
                        "cloud:"
                        + self.request_ref["sha256"]
                        + ":"
                        + self.preview_ref["sha256"]
                    )
                    deadline = NOW + 20
                original = self.executor.audit

                def slow_publication(path, value):
                    ref = original(path, value)
                    if (
                        path.endswith("deployment-submission.json")
                        or stage == "prepare"
                        and path.endswith("prepare-what-if-submission.json")
                    ):
                        now[0] = deadline
                    return ref

                self.executor.audit = slow_publication
                result = (
                    self.executor.prepare(self.directory + "/expiry.json")
                    if stage == "prepare"
                    else self.apply("expiry.json")
                )
                self.assertEqual(result["result"], "BLOCKED")
                self.assertEqual(self.arm.submissions, 0)
                if stage == "prepare":
                    self.assertFalse(any(call[0] == "POST" for call in self.arm.calls))

    def test_real_caller_acquisition_prepare_apply_uses_identical_manifest_bytes(self):
        import io
        import zipfile
        from dataclasses import asdict
        import azure_governed as governed
        from cloud_authorization import WriteBoundary

        self.request_ref["path"] = "request.json"
        (self.root / "request.json").write_bytes(self.request_bytes)
        self.executor = self.stage("prepare")

        def archive_of(root):
            stream = io.BytesIO()
            with zipfile.ZipFile(stream, "w") as archive:
                for path in root.rglob("*"):
                    if path.is_file():
                        archive.write(path, path.relative_to(root).as_posix())
            return stream.getvalue()

        (self.root / "request.json").write_bytes(self.request_bytes)
        data = archive_of(self.root)
        original_root = self.root
        results = []
        for stage in ("prepare", "apply"):
            with self.subTest(stage=stage):
                dest = original_root / ("acquired-" + stage)
                auth = self.auths[-1]
                policy = self.executor.boundary.policy
                env = dict(
                    AZURE_CONTROL_POLICY=json.dumps(asdict(policy)),
                    GH_TOKEN="synthetic-github-bearer",
                    ACTIONS_ID_TOKEN_REQUEST_URL=OIDC_URL,
                    ACTIONS_ID_TOKEN_REQUEST_TOKEN="synthetic-oidc-bearer",
                    ARTIFACT_REPOSITORY="synthetic/plans",
                    ARTIFACT_ID="11",
                    ARTIFACT_RUN_ID="12",
                    ARTIFACT_TOKEN="synthetic-read-token",
                    REQUEST_SHA256=self.request_ref["sha256"],
                    PREVIEW_SHA256="none"
                    if stage == "prepare"
                    else self.preview_ref["sha256"],
                )

                def boundary(p, r, evidence):
                    return WriteBoundary(
                        p, r, evidence, transport=auth, clock=lambda: NOW
                    )

                def executor(root, ref, b):
                    return self.e.AzureExecutor(
                        root,
                        ref,
                        b,
                        arm=self.arm,
                        clock=lambda: NOW,
                        sleep=lambda _: None,
                    )

                with (
                    patch.dict(os.environ, env),
                    patch.object(
                        governed,
                        "ArtifactHttps",
                        return_value=ArtifactFixture(governed, data),
                    ),
                    patch.object(governed, "WriteBoundary", side_effect=boundary),
                    patch.object(governed, "AzureExecutor", side_effect=executor),
                ):
                    result = governed.main([stage, "--workspace", str(dest)])
                self.assertEqual(result["result"], "PASS", result)
                self.assertEqual(
                    (dest / "request.json").read_bytes(), self.request_bytes
                )
                results.append(result)
                if stage == "prepare":
                    self.root = dest
                    self.preview_ref = json.loads(
                        (dest / result["evidence_manifest_path"]).read_bytes()
                    )["preview"]
                    self.executor = self.stage("apply", self.preview_ref)
                    data = archive_of(dest)
        self.assertEqual(self.arm.submissions, 1)
        self.assertEqual(
            results[0]["input_manifest_sha256"], results[1]["input_manifest_sha256"]
        )

    def test_unknown_semantics_at_real_callsite_blocks_zero_apply(self):
        self.prepare()
        self.arm.changes[0]["changeType"] = "Unsupported"
        result = self.apply()
        self.assertEqual(result["result"], "BLOCKED")
        self.assertEqual(self.arm.submissions, 0)

    def test_revocation_between_fresh_preview_and_put_blocks(self):
        self.prepare()
        original = self.arm.request

        def revoke(method, url, headers, body=None):
            response = original(method, url, headers, body)
            if method == "POST":
                self.auths[-1].approvals[0]["state"] = "rejected"
            return response

        with patch.object(self.arm, "request", side_effect=revoke):
            self.assertEqual(self.apply()["result"], "BLOCKED")
        self.assertEqual(self.arm.submissions, 0)

    def test_readonly_reconcile_missing_state_and_error_preserves_unknown_identity(
        self,
    ):
        self.prepare()
        self.arm.timeout = True
        initial = self.apply()
        ref = json.loads((self.root / initial["evidence_manifest_path"]).read_bytes())[
            "submission"
        ]
        self.arm.timeout = False
        self.arm.state = "NewUnknownState"
        result = self.executor.reconcile(
            ref, self.directory + "/unknown-reconcile.json"
        )
        self.assertEqual(result["result"], "UNKNOWN")
        self.assertEqual(result["native_operation_id"], initial["native_operation_id"])
        self.assertEqual(self.arm.submissions, 1)

    def test_output_outside_evidence_is_not_published(self):
        result = self.executor.prepare("bundle/should-not-write.json")
        self.assertEqual(result["result"], "BLOCKED")
        self.assertFalse((self.root / "bundle/should-not-write.json").exists())
        self.assertEqual(self.arm.calls, [])

    def test_production_https_preserves_202_headers_and_does_not_retry(self):
        from azure_arm import HttpsTransport
        from unittest.mock import MagicMock

        response = MagicMock()
        response.__enter__.return_value = response
        url = self.executor.client.url.replace("?", "/whatIf?")
        location = self.executor.client.url.replace("?", "/operations/native?")
        response.status = 202
        response.geturl.return_value = url
        response.headers.items.return_value = [
            ("Location", location),
            ("Retry-After", "1"),
        ]
        response.read.return_value = b""
        opener = MagicMock()
        opener.open.return_value = response
        with patch("urllib.request.build_opener", return_value=opener):
            native = HttpsTransport().request(
                "POST", url, {"Authorization": "Bearer synthetic"}, b"{}"
            )
        self.assertEqual(native.status, 202)
        self.assertEqual(native.headers["Location"], location)
        self.assertEqual(opener.open.call_count, 1)
        self.assertEqual(opener.open.call_args.kwargs["timeout"], 20)

    def test_post_submit_evidence_failure_retains_unknown_original_id(self):
        self.prepare()
        original = self.executor.audit
        def fail_final_manifest(path, value):
            if path.endswith("apply.json.manifest.json"):
                raise OSError("synthetic evidence storage failure")
            return original(path, value)
        self.executor.audit = fail_final_manifest
        result = self.apply()
        self.assertEqual(result["result"], "UNKNOWN")
        self.assertEqual(result["native_operation_id"], self.executor.client.native_id)
        self.assertEqual(result["evidence_manifest_path"], self.directory + "/deployment-submission.json")
        self.assertEqual(self.arm.submissions, 1)
        self.assertTrue((self.root / result["evidence_manifest_path"]).is_file())

    def test_cross_job_original_prepare_archive_cannot_repeat_unknown_put(self):
        import shutil
        self.prepare()
        fresh = tempfile.TemporaryDirectory(prefix="cloud-T012-fresh-job-")
        self.addCleanup(fresh.cleanup)
        restored = Path(fresh.name) / "data"
        # Preserve the original immutable PREPARE output, before any apply marker.
        shutil.copytree(self.root, restored)
        prior_run = copy.deepcopy(self.auths[-1].run)
        self.arm.timeout = True
        first = self.apply()
        self.assertEqual(first["result"], "UNKNOWN")
        self.assertEqual(self.arm.submissions, 1)
        self.root = restored
        os.environ["CLOUD_WORKSPACE_ROOT"] = str(restored)
        self.executor = self.stage("apply", self.preview_ref)
        auth = self.auths[-1]
        auth.claims["run_id"] = "456"
        auth.run["id"] = 456
        prior_run.update(status="completed", conclusion="failure")
        auth.history = [prior_run, copy.deepcopy(auth.run)]
        self.arm.timeout = False
        self.arm.existing = False  # missing native history is NOT absence of a prior PUT
        second = self.apply("cross-job.json")
        self.assertEqual(second["result"], "UNKNOWN")
        self.assertEqual(second["native_operation_id"], first["native_operation_id"])
        self.assertEqual(self.arm.submissions, 1)
        manifest = json.loads((self.root / second["evidence_manifest_path"]).read_bytes())
        fence = manifest["submission"]
        self.assertEqual(json.loads((self.root / fence["path"]).read_bytes())["schema"], "azure-intent-fence/v1")
        self.arm.existing = True
        before = len(self.arm.calls)
        result = self.executor.reconcile(fence, self.directory + "/history-reconcile.json")
        self.assertEqual(result["native_operation_id"], first["native_operation_id"])
        self.assertEqual(result["result"], "PASS")
        self.assertTrue(all(x[0] == "GET" for x in self.arm.calls[before:]))
        self.assertEqual(self.arm.submissions, 1)

    def test_unavailable_incomplete_or_excessive_intent_history_blocks_without_put(self):
        self.prepare()
        auth = self.auths[-1]
        for n, value in enumerate((dict(total_count=0,workflow_runs=[]),
            dict(total_count=2,workflow_runs=[auth.run]),
            dict(total_count=1001,workflow_runs=[auth.run]),
            dict(total_count=1,workflow_runs=[{**auth.run,"id":789}]))):
            auth.history_response = value
            result = self.apply("history-denied-"+str(n)+".json")
            self.assertEqual(result["result"], "BLOCKED")
            self.assertEqual(self.arm.submissions, 0)
            # Fresh independent job for the next failure: a denied boundary stays consumed.
            self.executor = self.stage("apply", self.preview_ref)
            auth = self.auths[-1]
            for marker in (self.root / self.directory).glob("*.apply.*.authorization.json"):
                marker.unlink()
        auth.history_error = True
        self.assertEqual(self.apply("history-unavailable.json")["result"], "BLOCKED")
        self.assertEqual(self.arm.submissions, 0)

    def test_history_wrong_repository_duplicate_title_and_bound_are_denied(self):
        self.prepare()
        auth = self.auths[-1]
        current = copy.deepcopy(auth.run)
        prior = {**current, "id": 122, "status": "completed", "conclusion": "failure"}
        variants = [
            dict(total_count=True, workflow_runs=[current]),
            dict(total_count=101, workflow_runs=[current]),
            dict(total_count=2, workflow_runs=[current, current]),
            dict(total_count=1, workflow_runs=[{**current, "display_title": "truncated"}]),
        ]
        for key in ("repository", "head_repository"):
            variants.append(dict(total_count=2, workflow_runs=[current, {
                **prior, key: dict(id=77, full_name="elsewhere/control")}]))
        for key, value in (("event", "push"), ("id", "122"),
                           ("display_title", "cloud:truncated")):
            variants.append(dict(total_count=2, workflow_runs=[current, {**prior, key: value}]))
        for n, history_response in enumerate(variants):
            with self.subTest(n=n):
                auth.history_response = history_response
                result = self.apply("malformed-history-" + str(n) + ".json")
                self.assertEqual(result["result"], "BLOCKED")
                self.assertEqual(self.arm.submissions, 0)

    def test_history_changed_preview_and_revision_still_fences_same_intent(self):
        self.prepare()
        auth = self.auths[-1]
        prior = {**copy.deepcopy(auth.run), "id": 122, "head_sha": "b" * 40,
                 "status": "completed", "conclusion": "failure",
                 "display_title": "cloud:" + self.request_ref["sha256"] + ":" + "f" * 64}
        auth.history = [prior, auth.run]
        result = self.apply()
        self.assertEqual(result["result"], "UNKNOWN")
        self.assertEqual(result["native_operation_id"], self.executor.client.native_id)
        self.assertEqual(self.arm.submissions, 0)
        self.assertFalse(any(x[0] == "POST" for x in self.arm.calls[1:]))

    def test_complete_history_prepare_none_and_other_intents_allow_single_put(self):
        self.prepare()
        auth = self.auths[-1]
        prior = copy.deepcopy(auth.run)
        auth.history = [auth.run, {**prior, "id": 122,
            "display_title": "cloud:" + self.request_ref["sha256"] + ":none"}]
        auth.history.extend({**prior, "id": n,
            "display_title": "cloud:" + "f" * 64 + ":" + "e" * 64} for n in range(1, 99))
        result = self.apply()
        self.assertEqual(result["result"], "PASS")
        self.assertEqual(self.arm.submissions, 1)
        calls = [x for x in auth.calls if "/actions/runs?" in x[1]]
        self.assertTrue(calls, "No authenticated complete history was checked")
        self.assertTrue(all(x[0] == "GET" and "per_page=100&page=1" in x[1] for x in calls))

    def test_public_reconcile_fence_reauthenticates_and_rejects_forged_identity(self):
        import cloud
        self.prepare()
        auth = self.auths[-1]
        auth.history = [{**copy.deepcopy(auth.run), "id": 122}, auth.run]
        result = self.apply()
        self.assertEqual(result["result"], "UNKNOWN")
        manifest = json.loads((self.root / result["evidence_manifest_path"]).read_bytes())
        fence = manifest["submission"]
        path = self.root / fence["path"]
        original = path.read_bytes()
        self.executor.preview_ref = self.preview_ref
        self.arm.existing = True
        before = len(self.arm.calls)
        reconciled = cloud.run(["reconcile", "--request", self.request_ref["path"],
            "--output", self.directory + "/cli-reconcile.json"], executor=self.executor)
        self.assertEqual(reconciled["result"], "PASS")
        self.assertEqual(reconciled["native_operation_id"], self.executor.client.native_id)
        self.assertTrue(all(x[0] == "GET" for x in self.arm.calls[before:]))
        for key, value in (("request", {**self.request_ref, "sha256": "f" * 64}),
                           ("scope", {**self.req["scope"], "region": "elsewhere"}),
                           ("native_operation_id", self.executor.client.native_id + "other"),
                           ("repository", "elsewhere/control"), ("prior_run_ids", [777])):
            with self.subTest(field=key):
                forged = json.loads(original)
                forged[key] = value
                path.write_bytes(encode(forged))
                before = len(self.arm.calls)
                answer = cloud.run(["reconcile", "--request", self.request_ref["path"],
                    "--output", self.directory + "/forged-" + key + ".json"], executor=self.executor)
                self.assertEqual(answer["result"], "BLOCKED")
                self.assertEqual(len(self.arm.calls), before)
        path.write_bytes(original)
        auth.history_error = True
        answer = cloud.run(["reconcile", "--request", self.request_ref["path"],
            "--output", self.directory + "/unavailable-reconcile.json"], executor=self.executor)
        self.assertNotEqual(answer["result"], "PASS")
        self.assertEqual(self.arm.submissions, 0)

    def test_reconcile_trusted_scope_and_policy_mismatch_zero_native_reads(self):
        from dataclasses import replace
        for kind in ("journal", "fence"):
            case = AzureExecution()
            case.setUp()
            try:
                case.prepare()
                if kind == "fence":
                    auth = case.auths[-1]
                    auth.history = [{**copy.deepcopy(auth.run), "id": 122}, auth.run]
                else:
                    case.arm.timeout = True
                first = case.apply()
                self.assertEqual(first["result"], "UNKNOWN")
                manifest = json.loads((case.root / first["evidence_manifest_path"]).read_bytes())
                operation = manifest["submission"]
                case.arm.timeout = False
                case.arm.existing = True
                original = case.executor.boundary.policy
                fields = dict(provider="aws", account_id="99999999-9999-9999-9999-999999999999",
                              region="westus", deployment_scope="different-approved-group",
                              target_environment="other-target", policy_sha256="f" * 64,
                              operation="prepare", exclusive_repository="elsewhere/control")
                for field, value in fields.items():
                    with self.subTest(kind=kind, field=field):
                        case.executor.boundary.policy = replace(original, **{field: value})
                        before = len(case.arm.calls)
                        auth_before = len(case.auths[-1].calls)
                        result = case.executor.reconcile(operation, case.directory + "/policy-" + field + ".json")
                        self.assertEqual(result["result"], "UNKNOWN")
                        self.assertEqual(result["native_operation_id"], first["native_operation_id"])
                        self.assertEqual(len(case.arm.calls), before)
                        self.assertEqual(len(case.auths[-1].calls), auth_before)
            finally:
                case.doCleanups()

    def test_readonly_recovery_needs_no_new_mutation_approval_or_fresh_preview(self):
        for kind in ("journal", "fence"):
            case = AzureExecution()
            case.setUp()
            try:
                case.prepare()
                auth = case.auths[-1]
                if kind == "fence":
                    auth.history = [{**copy.deepcopy(auth.run), "id": 122}, auth.run]
                else:
                    case.arm.timeout = True
                first = case.apply()
                self.assertEqual(first["result"], "UNKNOWN")
                manifest = json.loads((case.root / first["evidence_manifest_path"]).read_bytes())
                operation = manifest["submission"]
                # Fresh read identity after both old apply lease and preview expiry;
                # no mutation approval history is present for read-only recovery.
                auth.approvals = []
                auth.claims.update(iat=NOW + 390, nbf=NOW + 390, exp=NOW + 900)
                auth.azure_claims.update(iat=NOW + 390, nbf=NOW + 390, exp=NOW + 900)
                case.executor.clock = case.executor.boundary.clock = lambda: NOW + 400
                case.arm.timeout = False
                case.arm.existing = True
                before = len(case.arm.calls)
                result = case.executor.reconcile(operation, case.directory + "/expired-preview-read.json")
                self.assertEqual(result["result"], "PASS", kind)
                self.assertEqual(result["native_operation_id"], first["native_operation_id"])
                self.assertTrue(all(row[0] == "GET" for row in case.arm.calls[before:]))
            finally:
                case.doCleanups()

    def test_prepare_admission_missing_is_zero_native_posts(self):
        self.auths[-1].approvals = []
        result = self.executor.prepare(self.directory + "/blocked.json")
        self.assertEqual(result["result"], "BLOCKED")
        self.assertFalse(any(x[0] in ("POST", "PUT") for x in self.arm.calls))


class AzureAuthFixture(DeterministicTransport):
    def __init__(self, stage, subscription):
        super().__init__("azure", stage)
        self.subscription["subscriptionId"] = subscription
        self.history = None
        self.history_response = None
        self.history_error = False

    def request(self, method, url, headers, body=None):
        if url == f"https://api.github.com/repos/{REPO}/actions/runs?event=workflow_dispatch&per_page=100&page=1":
            self.calls.append((method, url, headers, body))
            assert method == "GET" and body is None
            assert headers["Authorization"] == "Bearer synthetic-github-bearer"
            if self.history_error:
                raise OSError("synthetic unavailable authenticated history")
            history = self.history if self.history is not None else [self.run]
            return encode(self.history_response if self.history_response is not None else
                          dict(total_count=len(history), workflow_runs=history))
        current = self.claims["run_id"]
        if current != "123" and f"/actions/runs/{current}" in url:
            url = url.replace(f"/actions/runs/{current}", "/actions/runs/123")
        if (
            url
            == f"https://management.azure.com/subscriptions/{self.subscription['subscriptionId']}?api-version=2022-12-01"
        ):
            self.calls.append((method, url, headers, body))
            assert method == "GET" and headers["Authorization"] == "Bearer " + jwt(
                self.azure_claims
            )
            return encode(self.subscription)
        return super().request(method, url, headers, body)


class ArmFixture:
    """Labeled synthetic ARM HTTPS response/status/headers double; no network."""

    def __init__(self, e, request):
        import azure_graph

        self.e = e
        self.calls = []
        self.submissions = 0
        self.timeout = False
        self.asynchronous = False
        self.pending = False
        self.bad_headers = None
        self.existing = False
        self.state = "Succeeded"
        root = Path(os.environ["CLOUD_WORKSPACE_ROOT"])
        ref = next(a for a in request["input_artifacts"] if a["kind"] == "compiled")
        self.template = (root / ref["path"]).read_bytes()
        cfg = json.loads(
            (root / request["local_context"]["provider_config"]["path"]).read_bytes()
        )
        self.parameters = json.loads((root / cfg["parameters"]).read_bytes())
        params = {k: v["value"] for k, v in self.parameters["parameters"].items()}
        self.resources = azure_graph.flatten(
            json.loads(self.template),
            params,
            request["scope"],
            set(
                json.loads((root / request["policy"]["path"]).read_bytes())[
                    "allowed_resource_types"
                ]
            ),
        )
        self.ownership = json.loads(
            (root / request["local_context"]["ownership"]["path"]).read_bytes()
        )
        self.changes: list[dict[str, Any]] = [
            dict(
                resourceId=r.get("scope", "")
                + "/providers/"
                + r["type"]
                + "/"
                + r["name"]
                if "scope" in r
                else azure_graph.resource_id(request["scope"], r["type"], r["name"]),
                changeType="Create",
                after=r,
            )
            for r in self.resources
        ]

    def preview(self):
        return dict(
            status="Succeeded",
            properties=dict(
                changes=copy.deepcopy(self.changes), potentialChanges=[], diagnostics=[]
            ),
        )

    def request(self, method, url, headers, body=None):
        self.calls.append((method, url, body))
        assert headers["Authorization"].startswith("Bearer synthetic.")
        assert url.startswith("https://management.azure.com/") and url.endswith(
            "api-version=2025-04-01"
        )
        if method == "POST":
            self.preview_url = url.replace("/whatIf?", "/operations/preview?")
            if self.asynchronous:
                return self.e.Response(
                    202,
                    self.bad_headers
                    if self.bad_headers is not None
                    else {"Location": self.preview_url, "Retry-After": "0"},
                    b"",
                )
            return self.e.Response(200, {}, encode(self.preview()))
        if method == "PUT":
            self.submissions += 1
            self.existing = True
            self.deployment_url = url
            if self.timeout:
                raise TimeoutError("synthetic uncertain delivery")
            if self.asynchronous:
                self.status_url = url.replace("?", "/operations/status?")
                return self.e.Response(
                    202,
                    {
                        "Azure-AsyncOperation": self.status_url,
                        "Location": url,
                        "Retry-After": "0",
                    },
                    b"",
                )
        if method == "GET" and url == getattr(self, "preview_url", None):
            return self.e.Response(200, {}, encode(self.preview()))
        if method == "GET" and url == getattr(self, "status_url", None):
            return self.e.Response(
                200, {}, encode(dict(status="Running" if self.pending else self.state))
            )
        if method == "GET" and not self.existing:
            return self.e.Response(404, {}, b"")
        return self.e.Response(
            200,
            {},
            encode(
                dict(
                    id=url.split("?")[0].removeprefix("https://management.azure.com"),
                    properties=dict(
                        provisioningState="Running" if self.pending else self.state
                    ),
                )
            ),
        )


class AzureCallerIntegration(unittest.TestCase):
    def setUp(self):
        sys.path.insert(0, str(ROOT / "plugins/sdd-azure-cloud/scripts"))
        self.assertTrue(
            (ROOT / "plugins/sdd-azure-cloud/scripts/azure_governed.py").is_file(),
            "T-012 trusted caller integration is absent",
        )
        import azure_governed

        self.g = azure_governed

    def test_acyclic_render_order_external_policy_and_inert_placeholders(self):
        inert = self.g.workflow_template()
        self.assertIn("REPLACE_REVIEWED_EXECUTOR_COMMIT", json.dumps(inert))
        # E is reviewed first, W is created using E, then protected policy pins W.
        workflow = self.g.workflow_template(
            executor_repository="synthetic/executor",
            executor_revision="b" * 40,
            subscription=SUBSCRIPTION,
            region="eastus",
            input_repository="synthetic/plans",
        )
        workflow_revision = hashlib.sha1(
            encode(workflow)
        ).hexdigest()  # synthetic Git identity only
        self.assertNotIn(workflow_revision, json.dumps(workflow))
        for stage, job in workflow["jobs"].items():
            self.assertEqual(job["environment"], "sandbox-" + stage)
            self.assertEqual(job["steps"][0]["with"]["ref"], "b" * 40)
            self.assertEqual(
                job["steps"][1]["env"]["AZURE_CONTROL_POLICY"],
                "${{ vars.AZURE_" + stage.upper() + "_POLICY }}",
            )
            command = job["steps"][1]["run"]
            self.assertIn("python3 -I", command)
            self.assertNotIn("CLOUD_POLICY_PATH", command)
            self.assertNotIn("pip ", command)
            self.assertNotIn("bicep ", command)
            self.assertEqual(job["steps"][2]["if"], "${{ always() }}")
        self.assertEqual(
            workflow["concurrency"],
            dict(
                group="cloud-azure-" + SUBSCRIPTION + "-eastus",
                **{"cancel-in-progress": False},
            ),
        )
        for invalid in ("main", "REPLACE_REVIEWED_EXECUTOR_COMMIT"):
            with self.assertRaises(ValueError):
                self.g.workflow_template(
                    executor_repository="synthetic/executor",
                    executor_revision=invalid,
                    subscription=SUBSCRIPTION,
                    region="eastus",
                    input_repository="synthetic/plans",
                )

    def test_archive_acquisition_is_immutable_digest_checked_and_data_only(self):
        import io
        import zipfile

        payload = io.BytesIO()
        with zipfile.ZipFile(payload, "w") as z:
            z.writestr("request.json", b'{ "immutable" : true }\n')
            z.writestr(
                "bundle/unit/main.bicep", b"// synthetic source; never executed\n"
            )
        archive = payload.getvalue()
        transport = ArtifactFixture(self.g, archive)
        with tempfile.TemporaryDirectory(prefix="cloud-T012-download-") as t:
            root = Path(t) / "data"
            self.g.acquire_bundle(
                root,
                "synthetic/plans",
                11,
                12,
                "synthetic-read-token",
                transport=transport,
            )
            self.assertEqual(
                (root / "request.json").read_bytes(), b'{ "immutable" : true }\n'
            )
            self.assertEqual([x[0] for x in transport.calls], ["GET"] * 3)
            self.assertNotIn("Authorization", transport.calls[-1][2])
            with self.assertRaises(ValueError):
                self.g.acquire_bundle(
                    root,
                    "synthetic/plans",
                    11,
                    12,
                    "synthetic-read-token",
                    transport=transport,
                )
        for field, value in (
            ("digest", "sha256:" + "0" * 64),
            ("expired", True),
            ("id", 13),
            ("workflow_run", dict(id=13)),
        ):
            transport = ArtifactFixture(self.g, archive)
            transport.metadata[field] = value
            with tempfile.TemporaryDirectory(prefix="cloud-T012-denied-download-") as t:
                with self.assertRaises(ValueError):
                    self.g.acquire_bundle(
                        Path(t) / "data",
                        "synthetic/plans",
                        11,
                        12,
                        "synthetic-read-token",
                        transport=transport,
                    )
                self.assertFalse((Path(t) / "data/request.json").exists())
        for filename in (
            "../escape.json",
            "/absolute.json",
            "bundle/../alias",
            "bundle\\\\escape",
        ):
            payload = io.BytesIO()
            with zipfile.ZipFile(payload, "w") as z:
                z.writestr(filename, b"synthetic")
            with tempfile.TemporaryDirectory(prefix="cloud-T012-unsafe-archive-") as t:
                with self.assertRaises(ValueError):
                    self.g.acquire_bundle(
                        Path(t) / "data",
                        "synthetic/plans",
                        11,
                        12,
                        "synthetic-read-token",
                        transport=ArtifactFixture(self.g, payload.getvalue()),
                    )

    def test_role_setup_actions_are_concrete_and_stage_separated(self):
        assignments = self.g.role_setup(SUBSCRIPTION, "synthetic-group")
        prepare = assignments["prepare"]["Actions"]
        apply = assignments["apply"]["Actions"]
        self.assertNotIn("Microsoft.Resources/deployments/write", prepare)
        for action in (
            "Microsoft.Compute/virtualMachines/write",
            "Microsoft.Network/networkInterfaces/write",
            "Microsoft.Compute/disks/write",
            "Microsoft.Compute/virtualMachines/extensions/write",
            "Microsoft.Insights/dataCollectionRuleAssociations/write",
            "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems/write",
        ):
            self.assertIn(action, apply)
            self.assertNotIn(action, prepare)
        for role in assignments.values():
            self.assertFalse(
                any(
                    "*" in action
                    or "roleAssignments" in action
                    or action.endswith("/delete")
                    for action in role["Actions"]
                )
            )


class ArtifactFixture:
    """Authenticated GitHub metadata/archive deterministic transport, not provenance."""

    def __init__(self, g, archive):
        self.g = g
        self.archive = archive
        self.calls = []
        self.metadata = dict(
            id=11,
            expired=False,
            digest="sha256:" + hashlib.sha256(archive).hexdigest(),
            workflow_run=dict(id=12),
        )

    def request(self, method, url, headers, body=None):
        self.calls.append((method, url, headers))
        if url == "https://api.github.com/repos/synthetic/plans/actions/artifacts/11":
            return self.g.Response(200, {}, encode(self.metadata))
        if (
            url
            == "https://api.github.com/repos/synthetic/plans/actions/artifacts/11/zip"
        ):
            return self.g.Response(
                302,
                {
                    "Location": "https://productionresultssa0.blob.core.windows.net/artifact/synthetic"
                },
                b"",
            )
        if (
            url
            == "https://productionresultssa0.blob.core.windows.net/artifact/synthetic"
        ):
            return self.g.Response(200, {}, self.archive)
        raise AssertionError("Unexpected artifact URL")


class AwsExecution(unittest.TestCase):
    """T-013 native wire-contract tests; synthetic HTTPS only, NOT live IAM."""

    def setUp(self):
        import shutil
        scripts = ROOT / "plugins/sdd-aws-cloud/scripts"
        self.assertTrue((scripts / "aws_execution.py").is_file(), "T-013 AWS executor absent")
        # Provider modules share the historical CLI basename. Scope module aliases.
        self.modules = patch.dict(sys.modules)
        self.modules.start()
        self.addCleanup(self.modules.stop)
        for name in ("cloud", "aws_local", "aws_graph", "aws_execution", "aws_native", "aws_control", "aws_governed"):
            sys.modules.pop(name, None)
        self.paths = patch.object(sys, "path", [str(scripts), *sys.path])
        self.paths.start()
        self.addCleanup(self.paths.stop)
        import aws_execution as execution
        import cloud_authorization as auth
        self.e, self.a = execution, auth
        self.tmp = tempfile.TemporaryDirectory(prefix="cloud-T013-synthetic-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        shutil.copytree(ROOT / "specs/cloud-orchestration/verification/T-013/inputs/aws/bundle", self.root / "bundle")
        locked = next((self.root / "bundle/generated").glob("*.request.json"))
        self.request_bytes = locked.read_bytes()
        self.req = json.loads(self.request_bytes)
        self.request_ref = dict(path=str(locked.relative_to(self.root)), sha256=hashlib.sha256(self.request_bytes).hexdigest())
        self.directory = self.req["local_context"]["evidence_directory"]
        (self.root / self.directory).mkdir(parents=True)
        self.anchor = patch.dict(os.environ, {"CLOUD_WORKSPACE_ROOT": str(self.root)})
        self.anchor.start()
        self.addCleanup(self.anchor.stop)
        self.native = AwsWireFixture(execution, self.req)
        self.auths = []
        self.executor = self.stage("prepare")

    def stage(self, stage, preview=None):
        transport = AwsAuthFixture(stage, self.req["scope"]["account_id"])
        transport.run["display_title"] = "cloud:" + self.request_ref["sha256"] + ":" + (preview["sha256"] if preview else "none")
        self.auths.append(transport)
        policy = self.a.Policy(provider="aws", repository=REPO, repository_id=42, workflow=WORKFLOW,
            workflow_revision=REV, ref="refs/heads/main", operation=stage, environment="sandbox-" + stage,
            target_environment=self.req["environment"], environment_id=99, **self.req["scope"],
            policy_sha256=self.req["policy"]["sha256"], actors=((7,"operator"),), reviewers=((8,"reviewer"),),
            exclusive_repository=REPO, ttl_seconds=120,
            aws_role_arn="arn:aws:iam::"+self.req["scope"]["account_id"]+":role/cloud-"+stage)
        boundary = self.a.WriteBoundary(policy, self.a.Runtime("synthetic-github-bearer",OIDC_URL,"synthetic-oidc-bearer"),
            self.root/self.directory, transport=transport, clock=lambda:NOW)
        return self.e.AwsExecutor(self.root,self.request_ref,boundary, self.native.control,
            transport=self.native,clock=lambda:NOW,sleep=lambda _:None)

    def prepare(self):
        result=self.executor.prepare(self.directory+"/prepare.json")
        self.assertEqual(result["result"],"PASS",result)
        self.preview_ref=json.loads((self.root/result["evidence_manifest_path"]).read_bytes())["preview"]
        self.executor=self.stage("apply",self.preview_ref)
        return result

    def apply(self, name="apply.json"):
        return self.executor.apply(self.preview_ref,self.directory+"/"+name)

    def test_exact_async_assets_native_role_failure_settings_and_single_execution(self):
        with patch("subprocess.run",side_effect=AssertionError("credentialed app execution")):
            self.prepare()
            result=self.apply()
        self.assertEqual(result["result"],"PASS",result)
        self.assertEqual(self.native.writes.count("PutObject"),1)
        self.assertEqual(self.native.writes.count("CreateChangeSet"),1)
        self.assertEqual(self.native.writes.count("ExecuteChangeSet"),1)
        self.assertEqual(self.native.create["RoleARN"],self.native.control.execution_role_arn)
        self.assertNotIn("OnStackFailure",self.native.create)
        self.assertEqual(self.native.execute["DisableRollback"],"true")
        self.assertEqual(self.native.execute["RetainExceptOnCreate"],"false")
        self.assertEqual(self.native.execute["ClientRequestToken"],self.native.create["ClientToken"])
        self.assertIn("versionId=",self.native.create["TemplateURL"])
        self.assertEqual((self.root/self.request_ref["path"]).read_bytes(),self.request_bytes)
        self.assertNotEqual(result["state"],"VERIFIED")

    def test_every_bound_file_mismatch_blocks_before_native_mutation(self):
        self.prepare()
        refs=[self.request_ref,self.req["policy"],self.req["dependency_lock"],self.req["verification_profile"],
              self.req["local_context"]["ownership"],self.req["local_context"]["provider_config"],
              *self.req["input_artifacts"],self.preview_ref]
        for i,ref in enumerate(refs):
            with self.subTest(path=ref["path"]):
                p=self.root/ref["path"]; original=p.read_bytes();p.write_bytes(original+b" ")
                try:self.assertEqual(self.apply("mismatch-"+str(i)+".json")["result"],"BLOCKED")
                finally:p.write_bytes(original)
        self.assertNotIn("ExecuteChangeSet",self.native.writes)

    def test_native_binding_substitutions_and_pagination_block(self):
        self.prepare()
        for field,value in [("ChangeSetId","arn:aws:cloudformation:us-east-1:111111111111:changeSet/wrong/id"),
                            ("StackName","Other"),("Parameters",[{"ParameterKey":"unexpected","ParameterValue":"x"}]),
                            ("Capabilities",["CAPABILITY_IAM"]),("NextToken","unconsumed"),
                            ("ExecutionStatus","UNAVAILABLE"),("Description","unbound")]:
            with self.subTest(field=field):
                self.native.override={field:value}
                self.assertEqual(self.apply(field+".json")["result"],"BLOCKED")
        self.native.override={}
        self.native.template_override=b'{"Resources":{}}'
        self.assertEqual(self.apply("template.json")["result"],"BLOCKED")
        self.assertNotIn("ExecuteChangeSet",self.native.writes)

    def test_denied_prepare_and_revoked_apply_zero_mutations(self):
        self.auths[-1].approvals[0]["state"]="rejected"
        self.assertEqual(self.executor.prepare(self.directory+"/denied.json")["result"],"BLOCKED")
        self.assertEqual(self.native.writes,[])
        self.auths[-1].approvals[0]["state"]="approved"
        self.prepare()
        self.auths[-1].approvals[0]["state"]="rejected"
        self.assertEqual(self.apply()["result"],"BLOCKED")
        self.assertNotIn("ExecuteChangeSet",self.native.writes)

    def test_versioned_asset_substitution_and_bucket_owner_fail_closed(self):
        self.prepare();self.native.object_bytes=b"substituted"
        self.assertEqual(self.apply()["result"],"BLOCKED")
        self.assertNotIn("ExecuteChangeSet",self.native.writes)

    def test_no_change_only_unambiguous_native_failed_diagnosis(self):
        self.native.no_change=True
        result=self.executor.prepare(self.directory+"/prepare.json")
        self.assertEqual(result["result"],"NO_CHANGE",result)
        self.preview_ref=json.loads((self.root/result["evidence_manifest_path"]).read_bytes())["preview"]
        self.executor=self.stage("apply",self.preview_ref)
        result=self.apply()
        self.assertEqual(result["result"],"NO_CHANGE",result)
        self.assertNotIn("native_operation_id",result)
        self.assertNotIn("ExecuteChangeSet",self.native.writes)

    def test_timeout_original_id_read_only_recovery_and_old_archive_replay(self):
        import shutil
        self.prepare()
        old=self.root/"old-prepare";shutil.copytree(self.root/self.directory,old)
        self.native.lose_execute=True
        result=self.apply()
        self.assertEqual(result["result"],"UNKNOWN",result)
        operation=self.executor.submission
        self.native.lose_execute=False
        recovery=self.stage("apply",self.preview_ref)
        result=recovery.reconcile(operation,self.directory+"/recovery.json")
        self.assertEqual(result["result"],"PASS",result)
        prior=copy.deepcopy(self.auths[-2].run);prior.update(id=122,status="completed",conclusion="failure")
        shutil.rmtree(self.root/self.directory);shutil.copytree(old,self.root/self.directory)
        fresh=self.stage("apply",self.preview_ref);self.auths[-1].history=[prior,self.auths[-1].run]
        self.native.history_missing=True
        result=fresh.apply(self.preview_ref,self.directory+"/fresh.json")
        self.assertEqual(result["result"],"UNKNOWN",result)
        self.assertEqual(self.native.writes.count("ExecuteChangeSet"),1)

    def test_recovery_scope_mismatch_no_native_reads_even_after_expiry(self):
        self.prepare();self.native.lose_execute=True;self.apply()
        recovery=self.stage("apply",self.preview_ref)
        recovery.boundary.policy=replace(recovery.boundary.policy,deployment_scope="Other")
        before=len(self.native.calls)
        result=recovery.reconcile(self.executor.submission,self.directory+"/recovery.json")
        self.assertIn(result["result"],("UNKNOWN","BLOCKED"))
        self.assertEqual(len(self.native.calls),before)


class AwsAuthFixture(DeterministicTransport):
    def __init__(self,stage,account):
        super().__init__("aws",stage);self.actual_account=account
        self.history=None;self.history_error=False
    def request(self,method,url,headers,body=None):
        if "?event=workflow_dispatch&per_page=100&page=1" in url:
            if self.history_error:raise OSError("synthetic unavailable history")
            history=self.history if self.history is not None else [self.run]
            return encode(dict(total_count=len(history),workflow_runs=history))
        old="123456789012"
        sent=body.replace(self.actual_account.encode(),old.encode()) if body else body
        return super().request(method,url,headers,sent).replace(old.encode(),self.actual_account.encode())


class AwsWireFixture:
    """Real AWS adapter consumes XML/headers; this double is NOT a cloud sandbox."""
    def __init__(self,e,request):
        self.e,self.request=e,request
        scope=request["scope"]
        self.control=e.Control(execution_role_arn="arn:aws:iam::"+scope["account_id"]+":role/cfn-execution",
            bucket="cdk-hnb659fds-assets-"+scope["account_id"]+"-"+scope["region"],
            unit_id=request["unit_id"], existing_stack_id=None)
        self.calls=[];self.writes=[];self.create={};self.execute={};self.override={}
        self.object_bytes=b"";self.version="native-version-1";self.template_override=None
        self.no_change=False;self.lose_execute=False;self.history_missing=False;self.describes=0
        self.arn="";self.stack="arn:aws:cloudformation:"+scope["region"]+":"+scope["account_id"]+":stack/"+scope["deployment_scope"]+"/native-id"

    def xml(self,action,value):
        import xml.etree.ElementTree as ET
        root=ET.Element(action+"Response",xmlns="http://cloudformation.amazonaws.com/doc/2010-05-15/")
        result=ET.SubElement(root,action+"Result")
        def fill(node,value):
            if isinstance(value,dict):
                for k,v in value.items():fill(ET.SubElement(node,k),v)
            elif isinstance(value,list):
                for v in value:fill(ET.SubElement(node,"member"),v)
            else:node.text=str(value).lower() if isinstance(value,bool) else str(value)
        fill(result,value)
        return self.e.Response(200,{},ET.tostring(root))

    def request(self,method,url,headers,body=None):
        from urllib.parse import urlsplit
        self.calls.append((method,url,body))
        assert headers["Authorization"].startswith("AWS4-HMAC-SHA256 Credential=SYNTHETICKEY/")
        if ".s3." in url:
            assert headers["x-amz-expected-bucket-owner"]==self.request["scope"]["account_id"]
            if "versioning" in url:return self.e.Response(200,{},b'<VersioningConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/"><Status>Enabled</Status></VersioningConfiguration>')
            if "location" in url:return self.e.Response(200,{},b'<LocationConstraint xmlns="http://s3.amazonaws.com/doc/2006-03-01/"/>')
            if "publicAccessBlock" in url:return self.e.Response(200,{},b'<PublicAccessBlockConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/"><BlockPublicAcls>true</BlockPublicAcls><IgnorePublicAcls>true</IgnorePublicAcls><BlockPublicPolicy>true</BlockPublicPolicy><RestrictPublicBuckets>true</RestrictPublicBuckets></PublicAccessBlockConfiguration>')
            if method=="PUT":
                assert headers["x-amz-server-side-encryption"]=="AES256"
                assert body is not None
                self.writes.append("PutObject");self.object_bytes=body
                return self.e.Response(200,{"x-amz-version-id":self.version,"ETag":'"native-etag"',"x-amz-server-side-encryption":"AES256"},b"")
            assert "versionId=" in urlsplit(url).query
            return self.e.Response(200,{"x-amz-version-id":self.version,"ETag":'"native-etag"',"x-amz-server-side-encryption":"AES256"},self.object_bytes)
        assert method=="POST" and body is not None
        p={k:v[0] for k,v in parse_qs(body.decode()).items()};action=p.pop("Action");assert p.pop("Version")=="2010-05-15"
        if action=="CreateChangeSet":
            self.writes.append(action);self.create=p
            self.arn="arn:aws:cloudformation:"+self.request["scope"]["region"]+":"+self.request["scope"]["account_id"]+":changeSet/"+p["ChangeSetName"]+"/native-id"
            return self.xml(action,dict(Id=self.arn,StackId=self.stack))
        if action=="DescribeStacks":
            if not self.create:
                return self.e.Response(400,{},b'<ErrorResponse xmlns="http://cloudformation.amazonaws.com/doc/2010-05-15/"><Error><Code>ValidationError</Code><Message>Stack with id '+self.request["scope"]["deployment_scope"].encode()+b' does not exist</Message></Error></ErrorResponse>')
            return self.xml(action,dict(Stacks=[dict(StackId=self.stack,StackName=self.request["scope"]["deployment_scope"],RoleARN=self.control.execution_role_arn,
                StackStatus="CREATE_COMPLETE" if self.execute else "REVIEW_IN_PROGRESS",
                Tags=[dict(Key="sdd-unit",Value=self.request["unit_id"]),dict(Key="sdd-owner",Value="cdk")])]))
        if action=="DescribeChangeSet":
            assert p["IncludePropertyValues"]=="true"
            self.describes+=1
            changes=[dict(Type="Resource",ResourceChange=dict(Action="Add",LogicalResourceId="Workload",ResourceType="AWS::EC2::Instance",Scope=["Properties"],Details=[]))]
            value=dict(ChangeSetName=self.create["ChangeSetName"],ChangeSetId=self.arn,StackId=self.stack,StackName=self.create["StackName"],Description=self.create["Description"],
                ExecutionStatus="UNAVAILABLE" if self.no_change else "AVAILABLE",Status="FAILED" if self.no_change else "CREATE_COMPLETE",Parameters=[],Capabilities=[],Changes=[] if self.no_change else changes,
                Tags=[dict(Key="sdd-unit",Value=self.request["unit_id"]),dict(Key="sdd-owner",Value="cdk")])
            if self.no_change:value["StatusReason"]="The submitted information didn't contain changes. Submit different information to create a change set."
            if self.describes==1 and not self.no_change:value.update(Status="CREATE_IN_PROGRESS",ExecutionStatus="UNAVAILABLE",Changes=[])
            value.update(self.override)
            return self.xml(action,value)
        if action=="GetTemplate":return self.xml(action,dict(TemplateBody=(self.template_override or self.object_bytes).decode(),StagesAvailable=["Original"]))
        if action=="ExecuteChangeSet":
            self.writes.append(action);self.execute=p
            assert p["DisableRollback"]=="true" and p["RetainExceptOnCreate"]=="false"
            assert "OnStackFailure" not in self.create
            if self.lose_execute:raise TimeoutError("synthetic response loss")
            return self.xml(action,{})
        if action=="DescribeStackEvents":
            return self.xml(action,dict(StackEvents=[] if self.history_missing else [dict(StackId=self.stack,ResourceType="AWS::CloudFormation::Stack",LogicalResourceId=self.request["scope"]["deployment_scope"],ClientRequestToken=self.create["ClientToken"],ResourceStatus="CREATE_COMPLETE")]))
        raise AssertionError("Unexpected native action "+action)


if __name__ == "__main__":
    unittest.main(verbosity=2)
