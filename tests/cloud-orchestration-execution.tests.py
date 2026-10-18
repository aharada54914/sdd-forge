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


if __name__ == "__main__":
    unittest.main(verbosity=2)
