"""T-006 synthetic tests. No credentials, native provider or cloud side effects.

Historical component Red failed on missing imports; current mismatch tests execute
the implemented reducer. Wire fixtures are synthetic, never live provenance.
"""

from __future__ import annotations

import copy
import importlib.util
import hashlib
import json
import os
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch
from types import ModuleType, SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT / "plugins/sdd-quality-loop/scripts"
sys.path.insert(0, str(SHARED))
import cloud_contracts as c  # noqa: E402


# Every protocol fixture is offline. A mock-target mistake must fail loudly,
# never become an expected cloud-denial exception or an implicit live read.
_network_guard = patch(
    "urllib.request.OpenerDirector.open",
    side_effect=AssertionError("LIVE_NETWORK_FORBIDDEN_IN_VERIFICATION_TESTS"),
)


def setUpModule():
    _network_guard.start()


def tearDownModule():
    _network_guard.stop()


def encode(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True) + "\n").encode()


def request(provider: str) -> dict:
    ref = dict(path="input.json", sha256="a" * 64)
    return dict(
        schema="cloud-run-request/v1",
        run_id="synthetic-run",
        unit_id="synthetic-unit",
        provider=provider,
        binding_id="synthetic-binding",
        environment="synthetic",
        scope=dict(
            account_id="synthetic-account",
            region="synthetic-region",
            deployment_scope="synthetic-scope",
        ),
        owner="cdk" if provider == "aws" else "bicep",
        route="aws-cdk" if provider == "aws" else "azure-bicep",
        operation="apply",
        predecessor_receipts=[],
        source_revision="b" * 40,
        input_artifacts=[dict(kind="compiled", **ref)],
        dependency_lock=ref,
        policy=ref,
        verification_profile=dict(id="synthetic-profile", version="1", **ref),
    )


class EntryPreflight(unittest.TestCase):
    def test_live_network_is_forbidden_before_transport(self):
        import urllib.request
        from unittest.mock import Mock

        self.assertIsInstance(urllib.request.OpenerDirector.open, Mock)
        with self.assertRaisesRegex(
            AssertionError, "LIVE_NETWORK_FORBIDDEN_IN_VERIFICATION_TESTS"
        ):
            urllib.request.OpenerDirector().open("https://invalid.example")

    def test_cli_without_trusted_executor_rejects_verify(self):
        # This tests direct CLI admission only; no saved observation is consumed.
        for provider in ("azure", "aws"):
            with self.subTest(provider=provider), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                (root / "request.json").write_bytes(encode(request(provider)))
                proc = subprocess.run(
                    [
                        sys.executable,
                        "-B",
                        "-c",
                        "import runpy,sys; from unittest.mock import patch; "
                        "path=sys.argv.pop(1); "
                        "guard=patch('urllib.request.OpenerDirector.open', side_effect=AssertionError('LIVE_NETWORK_FORBIDDEN_IN_CLI_TEST')); "
                        "guard.start(); runpy.run_path(path,run_name='__main__')",
                        str(ROOT / f"plugins/sdd-{provider}-cloud/scripts/cloud.py"),
                        "verify",
                        "--request",
                        str(root / "request.json"),
                        "--output",
                        str(root / "out.json"),
                    ],
                    env={
                        "PATH": os.defpath,
                        "HOME": temp,
                        "CLOUD_WORKSPACE_ROOT": temp,
                    },
                    capture_output=True,
                    timeout=10,
                )
                result = c.parse_artifact(proc.stdout)
                self.assertEqual(proc.returncode, 2)
                self.assertEqual(result["result"], "BLOCKED")
                self.assertEqual(result["error_code"], "TRUSTED_COLLECTOR_REQUIRED")
                self.assertFalse((root / "out.json").exists())

    def test_observation_settings_have_closed_executable_contract(self):
        for provider in ("azure", "aws"):
            path = (
                ROOT
                / f"plugins/sdd-{provider}-cloud/references/{provider}-local-config.schema.json"
            )
            schema = json.loads(path.read_bytes())
            self.assertIn("observation", schema["oneOf"][1]["properties"])

    def test_shared_reducer_available(self):
        path = SHARED / "cloud_verification.py"
        self.assertTrue(path.is_file(), "Shared reducer has not yet been implemented")
        spec = importlib.util.spec_from_file_location("cloud_verification", path)
        assert spec and spec.loader
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertTrue(callable(module.reduce))


def ref(path: str, value: object) -> dict:
    return dict(path=path, sha256=hashlib.sha256(encode(value)).hexdigest())


def reducer_case():
    req = request("aws")
    policy = dict(backup_required=True)
    profile: dict = dict(
        schema="cloud-verification-profile/v1",
        id="synthetic-profile",
        version="1",
        required_check_ids=[
            "resource",
            "network",
            "identity",
            "monitoring",
            "workload",
            "backup",
        ],
        max_age_seconds=300,
    )
    req["verification_profile"] = dict(
        id=profile["id"], version=profile["version"], **ref("profile.json", profile)
    )
    request_ref = ref("request.json", req)
    context = dict(
        schema="cloud-collection-context/v1",
        request=request_ref,
        **{
            k: copy.deepcopy(req[k])
            for k in (
                "run_id",
                "unit_id",
                "provider",
                "scope",
                "dependency_lock",
                "policy",
                "verification_profile",
            )
        },
        native_operation_id="synthetic-operation",
        resource_ids=["synthetic-resource"],
        principal="synthetic-observer",
        completed_at="2026-10-18T06:00:00Z",
        collected_at="2026-10-18T06:01:00Z",
        classification="synthetic",
    )
    records = []
    for check in profile["required_check_ids"]:
        payload = dict(
            schema="cloud-check-result/v1",
            context_sha256=ref("context.json", context)["sha256"],
            check_id=check,
            status="PASS",
            reason="HEALTHY",
            sampled_at="2026-10-18T06:01:00Z",
            queries=[
                dict(
                    locator="https://synthetic.example/read",
                    request_sha256="a" * 64,
                    response_sha256="b" * 64,
                    http_status=200,
                )
            ],
        )
        payload_ref = ref(check + ".result.json", payload)
        observation = dict(
            schema="cloud-observation/v1",
            **{
                k: context[k]
                for k in (
                    "run_id",
                    "unit_id",
                    "provider",
                    "native_operation_id",
                    "resource_ids",
                    "principal",
                    "classification",
                )
            },
            query=check,
            timestamp=context["collected_at"],
            exit_code=0,
            status="PASS",
            result=payload_ref,
        )
        records.append(
            dict(
                check_id=check,
                observation_path=check + ".json",
                observation_bytes=encode(observation),
                payload_bytes=encode(payload),
            )
        )
    return req, request_ref, profile, policy, context, records


class ReducerCases(unittest.TestCase):
    def reduce(self, case):
        # Missing import is initial component Red only, never mismatch-validation evidence.
        import cloud_verification

        return cloud_verification.reduce(*case, now="2026-10-18T06:01:01Z")

    def test_all_checks_synthetic_never_complete(self):
        result = self.reduce(reducer_case())
        self.assertEqual(result["overall_result"], "PASS")
        self.assertFalse(result["evidence_complete"])

    def test_each_context_counterpart_mismatch(self):
        for field in (
            "request",
            "run_id",
            "unit_id",
            "provider",
            "scope",
            "dependency_lock",
            "policy",
            "verification_profile",
        ):
            case = reducer_case()
            ctx = case[4]
            ctx[field] = (
                dict(path="other.json", sha256="f" * 64)
                if isinstance(ctx[field], dict)
                else "wrong"
            )
            with (
                self.subTest(field=field),
                self.assertRaisesRegex(ValueError, "COLLECTION_BINDING_MISMATCH"),
            ):
                self.reduce(case)

    def test_each_observation_counterpart_mismatch(self):
        for field in (
            "run_id",
            "unit_id",
            "provider",
            "native_operation_id",
            "resource_ids",
            "principal",
            "timestamp",
            "query",
            "classification",
            "result",
            "status",
            "exit_code",
        ):
            case = reducer_case()
            record = case[5][0]
            observation = json.loads(record["observation_bytes"])
            replacements = dict(
                provider="azure",
                classification="native",
                resource_ids=["other"],
                timestamp="2026-10-18T05:00:00Z",
                result=dict(path="other.json", sha256="f" * 64),
                status="FAIL",
                exit_code=1,
            )
            observation[field] = replacements.get(field, "wrong")
            record["observation_bytes"] = encode(observation)
            with (
                self.subTest(field=field),
                self.assertRaisesRegex(ValueError, "OBSERVATION_BINDING_MISMATCH"),
            ):
                self.reduce(case)

    def test_each_payload_counterpart_mismatch(self):
        for field in ("context_sha256", "check_id", "status"):
            case = reducer_case()
            record = case[5][0]
            payload = json.loads(record["payload_bytes"])
            payload[field] = "f" * 64 if field == "context_sha256" else "wrong"
            record["payload_bytes"] = encode(payload)
            observation = json.loads(record["observation_bytes"])
            observation["result"]["sha256"] = hashlib.sha256(
                record["payload_bytes"]
            ).hexdigest()
            record["observation_bytes"] = encode(observation)
            with (
                self.subTest(field=field),
                self.assertRaisesRegex(ValueError, "OBSERVATION_BINDING_MISMATCH"),
            ):
                self.reduce(case)

    def test_check_fail_block_unknown_stale_missing_tampered(self):
        for check in range(6):
            for variant in (
                "FAIL",
                "BLOCKED",
                "UNKNOWN",
                "stale",
                "missing",
                "tampered",
            ):
                case = reducer_case()
                record = case[5][check]
                observation = json.loads(record["observation_bytes"])
                payload = json.loads(record["payload_bytes"])
                if variant == "missing":
                    case[5].pop(check)
                elif variant == "tampered":
                    record["payload_bytes"] += b" "
                else:
                    if variant == "stale":
                        payload["sampled_at"] = "2026-10-18T05:59:59Z"
                    else:
                        payload["status"] = observation["status"] = variant
                        payload["reason"] = (
                            "UNHEALTHY" if variant == "FAIL" else "NATIVE_UNAVAILABLE"
                        )
                        observation["exit_code"] = 1
                    record["payload_bytes"] = encode(payload)
                    observation["result"]["sha256"] = hashlib.sha256(
                        record["payload_bytes"]
                    ).hexdigest()
                    record["observation_bytes"] = encode(observation)
                with self.subTest(check=check, variant=variant):
                    if variant in ("missing", "tampered"):
                        with self.assertRaises(ValueError):
                            self.reduce(case)
                    else:
                        result = self.reduce(case)
                        self.assertEqual(
                            result["overall_result"],
                            "FAIL" if variant == "FAIL" else "BLOCKED",
                        )
                        self.assertFalse(result["evidence_complete"])

    def test_native_denial_cannot_be_overridden_by_healthy_label(self):
        for code in (202, 403, 500):
            case = reducer_case()
            record = case[5][0]
            payload = json.loads(record["payload_bytes"])
            payload["queries"][0]["http_status"] = code
            record["payload_bytes"] = encode(payload)
            observation = json.loads(record["observation_bytes"])
            observation["result"]["sha256"] = hashlib.sha256(
                record["payload_bytes"]
            ).hexdigest()
            record["observation_bytes"] = encode(observation)
            with self.subTest(http_status=code):
                self.assertEqual(self.reduce(case)["overall_result"], "BLOCKED")

    def test_context_shape_and_window(self):
        for field, value in [
            ("schema", "unknown/v1"),
            ("extra", True),
            ("completed_at", "2026-10-18T06:02:00Z"),
            ("collected_at", "2026-10-18T06:02:00Z"),
            ("classification", "native"),
        ]:
            case = reducer_case()
            case[4][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.reduce(case)

    def test_profile_policy_and_check_set(self):
        for variant in (
            "missing-backup",
            "profile-version",
            "profile-digest",
            "extra-check",
            "duplicate-check",
        ):
            case = reducer_case()
            if variant == "missing-backup":
                case[2]["required_check_ids"].remove("backup")
            elif variant == "profile-version":
                case[2]["version"] = "9"
            elif variant == "profile-digest":
                case[2]["max_age_seconds"] = 900
            elif variant == "extra-check":
                case[2]["required_check_ids"].append("unknown")
            else:
                case[5].append(copy.deepcopy(case[5][0]))
            with self.subTest(variant=variant), self.assertRaises(ValueError):
                self.reduce(case)

    def test_query_trace_shape(self):
        for field, value in [
            ("locator", "http://untrusted.example"),
            ("request_sha256", "wrong"),
            ("response_sha256", "wrong"),
            ("http_status", -1),
            ("extra", "unknown"),
        ]:
            case = reducer_case()
            record = case[5][0]
            payload = json.loads(record["payload_bytes"])
            payload["queries"][0][field] = value
            record["payload_bytes"] = encode(payload)
            observation = json.loads(record["observation_bytes"])
            observation["result"]["sha256"] = hashlib.sha256(
                record["payload_bytes"]
            ).hexdigest()
            record["observation_bytes"] = encode(observation)
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.reduce(case)


class FreshnessCases(unittest.TestCase):
    def test_old_deployment_recent_samples_and_time_order(self):
        from cloud_verification import fresh, samples

        context = dict(
            completed_at="2026-10-18T04:00:00Z", collected_at="2026-10-18T06:02:30Z"
        )
        now = context["collected_at"]
        self.assertTrue(fresh("2026-10-18T06:01:30Z", context, 300, now))
        self.assertEqual(
            samples(
                [("2026-10-18T06:01:30Z", 1)],
                dict(minimum=1, maximum=1),
                context["completed_at"],
                now,
                300,
            ),
            (True, "2026-10-18T06:01:30Z"),
        )
        for sample in (
            "2026-10-18T03:59:59Z",
            "2026-10-18T05:57:29Z",
            "2026-10-18T06:02:31Z",
        ):
            with self.subTest(sample=sample):
                self.assertFalse(fresh(sample, context, 300, now))
        self.assertFalse(
            fresh("2026-10-18T06:01:30Z", context, 300, "2026-10-18T06:02:29Z")
        )
        self.assertTrue(fresh("2026-10-18T05:57:30Z", context, 300, now))
        self.assertFalse(
            samples(
                [("2026-10-18T06:00:00Z", 0), ("2026-10-18T06:01:00Z", 1)],
                dict(minimum=1, maximum=1),
                context["completed_at"],
                now,
                300,
            )[0]
        )

    def collector(self, provider, check, variant, completed):
        sys.path.insert(0, str(ROOT / f"plugins/sdd-{provider}-cloud/scripts"))
        module = __import__(provider + "_observation")
        fixture = NativeFixture(provider, check, variant)
        collector = module.Collector(
            fixture.scope,
            fixture.cfg,
            fixture.credentials,
            principal=fixture.principal,
            completed=completed,
            age=300,
            clock=lambda: 1792303350,
            transport=fixture,
            run_id="synthetic-run",
            unit_id="synthetic-unit",
        )
        return collector, fixture

    def test_old_deployment_native_recent_metric_and_backup(self):
        for provider in ("aws", "azure"):
            for check in ("monitoring", "workload", "backup"):
                for variant in ("healthy", "unhealthy"):
                    with self.subTest(provider=provider, check=check, variant=variant):
                        collector, fixture = self.collector(
                            provider, check, variant, "2026-10-18T04:00:00Z"
                        )
                        self.assertEqual(
                            getattr(collector, check)()[0], variant == "healthy"
                        )
                        self.assertTrue(fixture.calls)

    def test_metric_query_recent_postcompletion_minute_window(self):
        from urllib.parse import parse_qs, urlsplit

        for provider in ("aws", "azure"):
            for completed, expected in (
                ("2026-10-18T04:00:00Z", "2026-10-18T05:58:00Z"),
                ("2026-10-18T06:00:10Z", "2026-10-18T06:01:00Z"),
            ):
                with self.subTest(provider=provider, completed=completed):
                    collector, fixture = self.collector(
                        provider, "workload", "healthy", completed
                    )
                    # Query assertion remains executable even while the old freshness guard rejects the response.
                    try:
                        collector.workload()
                    except c.ContractError:
                        pass
                    _, url, body = fixture.calls[-1]
                    query = parse_qs(body.decode() if body else urlsplit(url).query)
                    if provider == "aws":
                        self.assertEqual(query["StartTime"], [expected])
                        self.assertEqual(query["EndTime"], ["2026-10-18T06:02:30Z"])
                        self.assertEqual(query["Period"], ["60"])
                    else:
                        self.assertEqual(
                            query["timespan"], [expected + "/2026-10-18T06:02:30Z"]
                        )
                        self.assertEqual(query["interval"], ["PT1M"])
                        self.assertEqual(query["AutoAdjustTimegrain"], ["false"])

    def test_native_selected_window_never_chooses_only_healthy_point(self):
        import xml.etree.ElementTree as ET

        for provider in ("aws", "azure"):
            for extra_time, extra_value, expected in (
                ("2026-10-18T06:00:00Z", 0, "FAIL"),
                ("2026-10-18T05:57:00Z", 1, "BLOCKED"),
                ("2026-10-18T06:03:00Z", 1, "BLOCKED"),
                ("2026-10-18T06:00:00Z", 1, "PASS"),
            ):
                with self.subTest(
                    provider=provider, extra_time=extra_time, extra_value=extra_value
                ):
                    collector, fixture = self.collector(
                        provider, "workload", "healthy", "2026-10-18T04:00:00Z"
                    )
                    original = fixture.request

                    def response(method, url, headers, body=None):
                        result = original(method, url, headers, body)
                        if provider == "azure":
                            value = json.loads(result.body)
                            value["value"][0]["timeseries"][0]["data"].insert(
                                0,
                                dict(
                                    timeStamp=extra_time,
                                    minimum=extra_value,
                                    maximum=extra_value,
                                ),
                            )
                            result.body = encode(value)
                        else:
                            tree = ET.fromstring(result.body)
                            ns = "{http://monitoring.amazonaws.com/doc/2010-08-01/}"
                            points = tree.find(".//" + ns + "Datapoints")
                            assert points is not None
                            member = ET.SubElement(points, ns + "member")
                            ET.SubElement(member, ns + "Timestamp").text = extra_time
                            ET.SubElement(member, ns + "Minimum").text = str(
                                extra_value
                            )
                            ET.SubElement(member, ns + "Maximum").text = str(
                                extra_value
                            )
                            result.body = ET.tostring(tree)
                        return result

                    with patch.object(fixture, "request", side_effect=response):
                        if expected == "BLOCKED":
                            with self.assertRaisesRegex(
                                c.ContractError, "STALE_SIGNAL"
                            ):
                                collector.workload()
                        else:
                            self.assertEqual(
                                collector.workload()[0], expected == "PASS"
                            )

    def test_aws_backup_native_recent_query_window(self):
        from urllib.parse import parse_qs, urlsplit

        collector, fixture = self.collector(
            "aws", "backup", "healthy", "2026-10-18T04:00:00Z"
        )
        try:
            collector.backup()
        except c.ContractError:
            pass
        query = parse_qs(urlsplit(fixture.calls[-1][1]).query)
        self.assertEqual(query["createdAfter"], [str(1792303350 - 300)])


class NativeCollectorCases(unittest.TestCase):
    def test_native_collectors_have_closed_configuration_and_read_only_boundaries(self):
        for provider in ("azure", "aws"):
            with self.subTest(provider=provider):
                sys.path.insert(0, str(ROOT / f"plugins/sdd-{provider}-cloud/scripts"))
                module = __import__(provider + "_observation")
                cfg = observation_config(provider)
                if provider == "aws":
                    cfg.pop("instance_id")
                    cfg.pop("security_group_ids")
                    cfg.pop("alarm_name")
                    cfg.update(
                        instance_logical_id="Workload",
                        security_group_logical_ids=["PrivateGroup"],
                        alarm_logical_id="Health",
                    )
                    cfg["backup"].pop("selection_id")
                    cfg["backup"]["selection_logical_id"] = "Protection"
                module.configuration(cfg)
                for field in cfg:
                    changed = copy.deepcopy(cfg)
                    changed[field] = "; arbitrary command"
                    with self.subTest(field=field), self.assertRaises(ValueError):
                        module.configuration(changed)
                changed = copy.deepcopy(cfg)
                changed["command"] = "arbitrary"
                with self.assertRaises(ValueError):
                    module.configuration(changed)

    def test_native_healthy_and_each_unhealthy_denied_missing_stale(self):
        for provider in ("azure", "aws"):
            sys.path.insert(0, str(ROOT / f"plugins/sdd-{provider}-cloud/scripts"))
            module = __import__(provider + "_observation")
            for check in (
                "resource",
                "network",
                "identity",
                "monitoring",
                "workload",
                "backup",
            ):
                for variant in ("healthy", "unhealthy", "denied", "missing", "stale"):
                    with self.subTest(provider=provider, check=check, variant=variant):
                        fixture = NativeFixture(provider, check, variant)
                        collector = module.Collector(
                            fixture.scope,
                            fixture.cfg,
                            fixture.credentials,
                            principal=fixture.principal,
                            completed="2026-10-18T06:00:00Z",
                            age=300,
                            clock=lambda: 1792303260,
                            transport=fixture,
                            run_id="synthetic-run",
                            unit_id="synthetic-unit",
                        )
                        if variant in ("denied", "missing") or (
                            variant == "stale"
                            and check in ("monitoring", "workload", "backup")
                        ):
                            with self.assertRaises((ValueError, KeyError, TypeError)):
                                getattr(collector, check)()
                        else:
                            healthy, _ = getattr(collector, check)()
                            self.assertEqual(healthy, variant != "unhealthy")
                        self.assertTrue(fixture.calls)

    def test_native_azure_incomplete_permission_proof_cannot_pass(self):
        sys.path.insert(0, str(ROOT / "plugins/sdd-azure-cloud/scripts"))
        import azure_observation as module

        fixture = NativeFixture("azure", "identity", "healthy")
        native = module.HttpsTransport()
        collector = module.Collector(
            fixture.scope,
            fixture.cfg,
            fixture.credentials,
            principal=fixture.principal,
            completed="2026-10-18T06:00:00Z",
            age=300,
            clock=lambda: 1792303260,
            transport=native,
            run_id="synthetic-run",
            unit_id="synthetic-unit",
        )
        # The actual native transport class is used, but its I/O is explicitly
        # mocked with synthetic bytes. No network/provenance claim is made.
        original = fixture.request

        def incomplete(method, url, headers, body=None):
            response = original(method, url, headers, body)
            if "/roleAssignments?" in url:
                response.body = encode(
                    dict(value=[], nextLink="https://untrusted.example")
                )
            return response

        with patch.object(native, "request", side_effect=incomplete):
            with self.assertRaises(ValueError):
                collector.identity()

    def test_backup_discovery_without_future_identifier(self):
        sys.path.insert(0, str(ROOT / "plugins/sdd-aws-cloud/scripts"))
        import aws_observation as module

        fixture = NativeFixture("aws", "backup", "healthy")
        config = copy.deepcopy(fixture.cfg)
        collector = module.Collector(
            fixture.scope,
            config,
            fixture.credentials,
            principal=fixture.principal,
            completed="2026-10-18T06:00:00Z",
            age=300,
            clock=lambda: 1792303260,
            transport=fixture,
            run_id="synthetic-run",
            unit_id="synthetic-unit",
        )
        self.assertTrue(collector.backup()[0])
        self.assertTrue(
            any(
                "resourceArn=" in url and "backupPlanId=" in url
                for _, url, _ in fixture.calls
            )
        )

    def test_azure_backup_does_not_require_future_recovery_id(self):
        sys.path.insert(0, str(ROOT / "plugins/sdd-azure-cloud/scripts"))
        import azure_observation as module

        fixture = NativeFixture("azure", "backup", "healthy")
        config = copy.deepcopy(fixture.cfg)
        config["backup"].pop("recovery_point_id", None)
        collector = module.Collector(
            fixture.scope,
            config,
            fixture.credentials,
            principal=fixture.principal,
            completed="2026-10-18T06:00:00Z",
            age=300,
            clock=lambda: 1792303260,
            transport=fixture,
            run_id="synthetic-run",
            unit_id="synthetic-unit",
        )
        self.assertTrue(collector.backup()[0])
        self.assertTrue(any("/recoveryPoints?" in url for _, url, _ in fixture.calls))

    def test_expired_collector_lease_has_zero_reads(self):
        for provider in ("aws", "azure"):
            sys.path.insert(0, str(ROOT / f"plugins/sdd-{provider}-cloud/scripts"))
            module = __import__(provider + "_observation")
            fixture = NativeFixture(provider, "resource", "healthy")
            collector = module.Collector(
                fixture.scope,
                fixture.cfg,
                fixture.credentials,
                principal=fixture.principal,
                completed="2026-10-18T06:00:00Z",
                age=300,
                clock=lambda: 1792303260,
                transport=fixture,
                run_id="synthetic-run",
                unit_id="synthetic-unit",
            )
            collector.lease = 1792303259
            with (
                self.subTest(provider=provider),
                self.assertRaisesRegex(ValueError, "READ_CREDENTIAL_EXPIRED"),
            ):
                collector.resource()
            self.assertEqual(fixture.calls, [])

    def test_optional_backup_is_omitted_only_by_original_profile(self):
        import cloud_verification as verification

        for provider in ("aws", "azure"):
            sys.path.insert(0, str(ROOT / f"plugins/sdd-{provider}-cloud/scripts"))
            module = __import__(provider + "_observation")
            fixture = NativeFixture(provider, "all", "healthy")
            config = copy.deepcopy(fixture.cfg)
            del config["backup"]
            fixture.cfg = config
            collector = module.Collector(
                fixture.scope,
                config,
                fixture.credentials,
                principal=fixture.principal,
                completed="2026-10-18T06:00:00Z",
                age=300,
                clock=lambda: 1792303260,
                transport=fixture,
                run_id="synthetic-run",
                unit_id="synthetic-unit",
            )
            for required in (True, False):
                req, req_ref, profile, policy, _, _ = reducer_case()
                policy["backup_required"] = required
                if not required:
                    profile["required_check_ids"].remove("backup")
                context, records = verification.collect_checks(
                    collector,
                    req,
                    profile,
                    policy,
                    req_ref,
                    principal=fixture.principal,
                    native_id="synthetic-operation",
                    resources=["synthetic-resource"],
                    completed="2026-10-18T06:00:00Z",
                    native=False,
                    clock=lambda: 1792303260,
                )
                statuses = {
                    r["check_id"]: json.loads(r["payload_bytes"])["status"]
                    for r in records
                }
                self.assertEqual(
                    statuses.get("backup"), "BLOCKED" if required else None
                )
                self.assertEqual(
                    {v for k, v in statuses.items() if k != "backup"}, {"PASS"}
                )


def observation_config(provider: str) -> dict:
    if provider == "aws":
        return dict(
            instance_id="i-0123456789abcdef0",
            vpc_id="vpc-0123456789abcdef0",
            subnet_id="subnet-0123456789abcdef0",
            security_group_ids=["sg-0123456789abcdef0"],
            instance_profile_arn="arn:aws:iam::123456789012:instance-profile/workload",
            role_arn="arn:aws:iam::123456789012:role/workload",
            guard_policy_name="ObservationGuard",
            alarm_name="workload-health",
            workload_metric=dict(
                namespace="Workload", name="Healthy", minimum=1, maximum=1
            ),
            backup=dict(
                plan_id="plan",
                selection_id="selection",
                vault_name="vault",
                role_arn="arn:aws:iam::123456789012:role/backup",
            ),
        )
    prefix = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/sandbox/providers/"
    vm = prefix + "Microsoft.Compute/virtualMachines/workload"
    protected = (
        prefix
        + "Microsoft.RecoveryServices/vaults/vault/backupFabrics/Azure/protectionContainers/container/protectedItems/workload"
    )
    return dict(
        vm_id=vm,
        nic_id=prefix + "Microsoft.Network/networkInterfaces/workload-nic",
        subnet_id=prefix + "Microsoft.Network/virtualNetworks/private/subnets/workload",
        identity_id=prefix
        + "Microsoft.ManagedIdentity/userAssignedIdentities/workload",
        association_id=vm
        + "/providers/Microsoft.Insights/dataCollectionRuleAssociations/monitor",
        data_collection_rule_id=prefix
        + "Microsoft.Insights/dataCollectionRules/workload",
        monitoring_workspace_id=prefix
        + "Microsoft.OperationalInsights/workspaces/monitor",
        workload_metric=dict(
            namespace="Workload", name="Healthy", minimum=1, maximum=1
        ),
        backup=dict(
            protected_item_id=protected,
            policy_id=prefix
            + "Microsoft.RecoveryServices/vaults/vault/backupPolicies/daily",
        ),
    )


def azure_actions(resource: str, cfg: dict) -> set[str]:
    """Independent fixture oracle for the supported VM policy, not implementation output."""
    actions = {
        "Microsoft.Authorization/permissions/read",
        "Microsoft.Authorization/roleAssignments/read",
        "Microsoft.Authorization/roleDefinitions/read",
        "Microsoft.Resources/deployments/read",
        "Microsoft.Resources/deployments/operations/read",
    }
    mapping = {
        cfg["vm_id"]: {
            "Microsoft.Compute/virtualMachines/read",
            "Microsoft.Compute/virtualMachines/instanceView/read",
            "Microsoft.Insights/metrics/read",
            "Microsoft.Insights/metrics/write",
        },
        cfg["nic_id"]: {
            "Microsoft.Network/networkInterfaces/read",
            "Microsoft.Network/networkInterfaces/effectiveNetworkSecurityGroups/action",
        },
        cfg["identity_id"]: {"Microsoft.ManagedIdentity/userAssignedIdentities/read"},
        cfg["association_id"]: {
            "Microsoft.Insights/dataCollectionRuleAssociations/read"
        },
        cfg["data_collection_rule_id"]: {"Microsoft.Insights/dataCollectionRules/read"},
    }
    if "backup" in cfg:
        item = cfg["backup"]["protected_item_id"]
        mapping[item] = {
            "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems/read",
            "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems/recoveryPoints/read",
        }
        if resource.startswith(item + "/recoveryPoints/"):
            return actions | mapping[item]
    return actions | mapping[resource]


def azure_role_records(fixture):
    cfg = fixture.cfg
    subscription = "/subscriptions/" + fixture.scope["account_id"]
    targets = [
        cfg[k]
        for k in (
            "vm_id",
            "nic_id",
            "identity_id",
            "association_id",
            "data_collection_rule_id",
        )
    ]
    if "backup" in cfg:
        targets.append(cfg["backup"]["protected_item_id"])
    audit = {
        "Microsoft.Authorization/roleAssignments/read",
        "Microsoft.Authorization/roleDefinitions/read",
    }
    assignments, definitions = [], {}
    group = subscription + "/resourceGroups/" + fixture.scope["deployment_scope"]
    deployment_reads = {
        "Microsoft.Resources/deployments/read",
        "Microsoft.Resources/deployments/operations/read",
    }
    for i, target in enumerate([subscription, group, *targets]):
        guid = "00000000-0000-0000-0000-" + str(i + 10).zfill(12)
        role_id = (
            subscription + "/providers/Microsoft.Authorization/roleDefinitions/" + guid
        )
        assignment_id = (
            target + "/providers/Microsoft.Authorization/roleAssignments/" + guid
        )
        actions = (
            audit
            if target == subscription
            else deployment_reads
            if target == group
            else azure_actions(target, cfg) - audit - deployment_reads
        )
        assignments.append(
            dict(
                id=assignment_id,
                name=guid,
                type="Microsoft.Authorization/roleAssignments",
                properties=dict(
                    scope=target,
                    principalId=fixture.principal,
                    principalType="ServicePrincipal",
                    roleDefinitionId=role_id,
                    condition=None,
                    conditionVersion=None,
                    delegatedManagedIdentityResourceId=None,
                ),
            )
        )
        definitions[role_id] = dict(
            id=role_id,
            name=guid,
            type="Microsoft.Authorization/roleDefinitions",
            properties=dict(
                roleName="Untrusted display name",
                type="CustomRole",
                assignableScopes=[subscription],
                permissions=[
                    dict(
                        actions=sorted(actions),
                        notActions=[],
                        dataActions=[],
                        notDataActions=[],
                    )
                ],
            ),
        )
    return assignments, definitions


class AzureClosureAndDcrCases(unittest.TestCase):
    @staticmethod
    def collector(native=False):
        sys.path.insert(0, str(ROOT / "plugins/sdd-azure-cloud/scripts"))
        import azure_observation as module

        fixture = NativeFixture("azure", "all", "healthy")
        transport = module.HttpsTransport() if native else fixture
        collector = module.Collector(
            fixture.scope,
            fixture.cfg,
            fixture.credentials,
            principal=fixture.principal,
            completed="2026-10-18T06:00:00Z",
            age=300,
            clock=lambda: 1792303260,
            transport=transport,
            run_id="synthetic-run",
            unit_id="synthetic-unit",
        )
        return collector, fixture

    def test_native_positive_permission_closure_protocol(self):
        collector, fixture = self.collector(native=True)
        with patch.object(collector.transport, "request", side_effect=fixture.request):
            self.assertTrue(collector.identity()[0])
        self.assertTrue(any("assignedTo" in url for _, url, _ in fixture.calls))
        self.assertTrue(any("/roleDefinitions/" in url for _, url, _ in fixture.calls))
        self.assertTrue(any("/permissions?" in url for _, url, _ in fixture.calls))

    def test_permission_closure_mismatches(self):
        # Native and injected paths must enforce the identical guard. Native I/O is
        # mocked explicitly; no EVIDENCE_COMPLETE or live IAM claim is made.
        for native in (False, True):
            for variant in (
                "principal",
                "group",
                "scope",
                "condition",
                "wildcard",
                "data",
                "notActions",
                "role-id",
                "assignment-id",
                "pagination",
                "denied",
                "empty",
                "caller-disagrees",
                "drift",
            ):
                with self.subTest(native=native, variant=variant):
                    collector, fixture = self.collector(native=native)
                    original = fixture.request
                    assignment_reads = 0

                    def wire(method, url, headers, body=None):
                        nonlocal assignment_reads
                        response = original(method, url, headers, body)
                        value = json.loads(response.body)
                        if "/roleAssignments?" in url:
                            assignment_reads += 1
                            row = value["value"][-1]
                            prop = row["properties"]
                            if variant == "principal":
                                prop["principalId"] = (
                                    "00000000-0000-0000-0000-000000000099"
                                )
                            if variant == "group":
                                prop["principalType"] = "Group"
                            if variant == "scope":
                                prop["scope"] += "/unrelated/child"
                            if variant == "condition":
                                prop["condition"] = "unsupported"
                            if variant == "assignment-id":
                                row["id"] += "wrong"
                            if variant == "pagination":
                                value["nextLink"] = "https://untrusted.example"
                            if variant == "denied":
                                response.status = 403
                            if variant == "empty":
                                value["value"] = []
                            if variant == "drift" and assignment_reads > 1:
                                value["value"] = value["value"][:-1]
                        if "/roleDefinitions/" in url:
                            perm = value["properties"]["permissions"][0]
                            if variant == "wildcard":
                                perm["actions"] = ["*"]
                            if variant == "data":
                                perm["dataActions"] = [
                                    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"
                                ]
                            if variant == "notActions":
                                perm["notActions"] = [
                                    "Microsoft.Compute/virtualMachines/read"
                                ]
                            if variant == "role-id":
                                value["id"] += "wrong"
                        if "/permissions?" in url and variant == "caller-disagrees":
                            value["value"][0]["actions"] = []
                        response.body = encode(value)
                        return response

                    with patch.object(collector.transport, "request", side_effect=wire):
                        with self.assertRaises(ValueError):
                            collector.identity()

    def test_dcr_readback_and_mismatches(self):
        for variant in (
            "matched",
            "id",
            "location",
            "kind",
            "state",
            "source",
            "counter",
            "interval",
            "stream",
            "destination",
            "flow",
            "transform",
            "denied",
            "missing",
            "pagination",
        ):
            with self.subTest(variant=variant):
                collector, fixture = self.collector()
                original = fixture.request

                def wire(method, url, headers, body=None):
                    response = original(method, url, headers, body)
                    if url.split("?")[0].endswith(
                        fixture.cfg["data_collection_rule_id"]
                    ):
                        value = json.loads(response.body)
                        props = value["properties"]
                        if variant == "id":
                            value["id"] += "wrong"
                        if variant == "location":
                            value["location"] = "westus"
                        if variant == "kind":
                            value["kind"] = "Windows"
                        if variant == "state":
                            props["provisioningState"] = "Failed"
                        if variant == "source":
                            props["dataSources"] = {}
                        if variant == "counter":
                            props["dataSources"]["performanceCounters"][0][
                                "counterSpecifiers"
                            ] = ["unrelated"]
                        if variant == "interval":
                            props["dataSources"]["performanceCounters"][0][
                                "samplingFrequencyInSeconds"
                            ] = 600
                        if variant == "stream":
                            props["dataSources"]["performanceCounters"][0][
                                "streams"
                            ] = ["Microsoft-Syslog"]
                        if variant == "destination":
                            props["destinations"]["logAnalytics"][0][
                                "workspaceResourceId"
                            ] += "wrong"
                        if variant == "flow":
                            props["dataFlows"][0]["destinations"] = ["other"]
                        if variant == "transform":
                            props["dataFlows"][0]["transformKql"] = (
                                "source | where false"
                            )
                        if variant == "denied":
                            response.status = 403
                        if variant == "missing":
                            value = {}
                        if variant == "pagination":
                            value["nextLink"] = "https://untrusted.example"
                        response.body = encode(value)
                    return response

                with patch.object(fixture, "request", side_effect=wire):
                    if variant == "matched":
                        self.assertTrue(collector.monitoring()[0])
                    else:
                        try:
                            healthy = collector.monitoring()[0]
                        except (ValueError, KeyError):
                            healthy = False
                        self.assertFalse(healthy)
                self.assertTrue(
                    any(
                        url.split("?")[0].endswith(
                            fixture.cfg["data_collection_rule_id"]
                        )
                        for _, url, _ in fixture.calls
                    )
                )


class AzureMetricContextCases(unittest.TestCase):
    collector = staticmethod(AzureClosureAndDcrCases.collector)

    def test_metric_context_counterparts(self):
        for field in (
            "namespace",
            "resourceregion",
            "interval",
            "timespan",
            "id",
            "metadata-duplicate",
        ):
            collector, fixture = self.collector()
            original = fixture.request

            def wire(method, url, headers, body=None):
                response = original(method, url, headers, body)
                value = json.loads(response.body)
                if field == "id":
                    value["value"][0]["id"] += "wrong"
                elif field == "metadata-duplicate":
                    value["value"][0]["timeseries"][0]["metadatavalues"].append(
                        dict(name=dict(value="RunId"), value="synthetic-run")
                    )
                else:
                    value[field] = "wrong"
                response.body = encode(value)
                return response

            with (
                self.subTest(field=field),
                patch.object(fixture, "request", side_effect=wire),
                self.assertRaises(ValueError),
            ):
                collector.workload()


class NativeFixture:
    """Native response transport double; NEVER native evidence provenance."""

    def __init__(self, provider, check, variant):
        self.provider, self.check, self.variant = provider, check, variant
        self.cfg = observation_config(provider)
        self.scope = dict(
            account_id="123456789012"
            if provider == "aws"
            else "00000000-0000-0000-0000-000000000001",
            region="us-east-1" if provider == "aws" else "eastus",
            deployment_scope="sandbox",
        )
        self.principal = (
            "00000000-0000-0000-0000-000000000004"
            if provider == "azure"
            else "synthetic-observer"
        )
        self.credentials = {
            "AZURE_ACCESS_TOKEN": "synthetic",
            "AWS_ACCESS_KEY_ID": "synthetic",
            "AWS_SECRET_ACCESS_KEY": "synthetic",
            "AWS_SESSION_TOKEN": "synthetic",
        }
        self.calls: list[tuple[str, str, bytes | None]] = []

    def request(self, method, url, headers, body=None):
        self.calls.append((method, url, body))
        # Response construction is deliberately centralized, not a prebuilt
        # observation: tests exercise real parsing, native target and health logic.
        from types import SimpleNamespace

        if self.variant == "denied":
            return SimpleNamespace(status=403, headers={}, body=b"{}")
        if self.variant == "missing":
            return SimpleNamespace(status=200, headers={}, body=b"{}")
        value = (
            self.azure(url, method)
            if self.provider == "azure"
            else self.aws(url, method, body)
        )
        return SimpleNamespace(
            status=200,
            headers={},
            body=value if isinstance(value, bytes) else encode(value),
        )

    def stamp(self):
        return (
            "2026-10-18T05:00:00Z"
            if self.variant == "stale"
            else "2026-10-18T06:01:00Z"
        )

    def azure(self, url, method):
        from urllib.parse import urlsplit, parse_qs

        path = urlsplit(url).path
        query = parse_qs(urlsplit(url).query)
        cfg = self.cfg
        bad = self.variant == "unhealthy"
        self.assert_read(method, path)
        if path.endswith("/roleAssignments"):
            assignments, _ = azure_role_records(self)
            assert query["$filter"] == ["assignedTo('" + self.principal + "')"]
            return dict(value=assignments)
        if "/roleDefinitions/" in path:
            _, definitions = azure_role_records(self)
            return definitions[path]
        if path == cfg["data_collection_rule_id"]:
            return dict(
                id=path,
                location=self.scope["region"],
                kind="Linux",
                properties=dict(
                    provisioningState="Succeeded",
                    dataSources=dict(
                        performanceCounters=[
                            dict(
                                name="cpu",
                                streams=["Microsoft-Perf"],
                                samplingFrequencyInSeconds=60,
                                counterSpecifiers=[
                                    "\\Processor(_Total)\\% Processor Time"
                                ],
                            )
                        ]
                    ),
                    destinations=dict(
                        logAnalytics=[
                            dict(
                                name="workspace",
                                workspaceResourceId=cfg["vm_id"].split("/providers/")[0]
                                + "/providers/Microsoft.OperationalInsights/workspaces/monitor",
                            )
                        ]
                    ),
                    dataFlows=[
                        dict(streams=["Microsoft-Perf"], destinations=["workspace"])
                    ],
                ),
            )
        if path.endswith("/permissions"):
            resource = path.removesuffix(
                "/providers/Microsoft.Authorization/permissions"
            )
            actions = sorted(azure_actions(resource, cfg))
            if bad and self.check == "identity":
                actions.append("Microsoft.Authorization/roleAssignments/write")
            return dict(
                value=[
                    dict(
                        actions=actions,
                        notActions=[],
                        dataActions=[],
                        notDataActions=[],
                    )
                ]
            )
        if path == cfg["identity_id"]:
            return dict(
                id=path,
                properties=dict(
                    principalId=self.principal,
                    clientId="00000000-0000-0000-0000-000000000003",
                ),
            )
        if path == cfg["vm_id"]:
            return dict(
                id=path,
                location=self.scope["region"],
                identity=dict(
                    type="UserAssigned",
                    userAssignedIdentities={
                        cfg["identity_id"]: dict(principalId=self.principal)
                    },
                ),
                properties=dict(
                    provisioningState="Failed"
                    if bad and self.check == "resource"
                    else "Succeeded",
                    networkProfile=dict(networkInterfaces=[dict(id=cfg["nic_id"])]),
                ),
            )
        if path == cfg["vm_id"] + "/instanceView":
            return dict(
                statuses=[
                    dict(
                        code="PowerState/stopped"
                        if bad and self.check == "resource"
                        else "PowerState/running"
                    )
                ]
            )
        if path == cfg["nic_id"]:
            return dict(
                id=path,
                properties=dict(
                    virtualMachine=dict(id=cfg["vm_id"]),
                    ipConfigurations=[
                        dict(
                            properties=dict(
                                subnet=dict(id=cfg["subnet_id"]),
                                privateIPAddress="10.0.0.4",
                            )
                        )
                    ],
                ),
            )
        if path.endswith("/effectiveNetworkSecurityGroups"):
            return dict(
                value=[
                    dict(
                        association=dict(networkInterface=dict(id=cfg["nic_id"])),
                        effectiveSecurityRules=[
                            dict(
                                direction="Inbound",
                                access="Allow",
                                expandedSourceAddressPrefix=[
                                    "0.0.0.0/0" if bad else "10.0.0.0/16"
                                ],
                            ),
                            dict(
                                direction="Outbound",
                                access="Allow",
                                expandedDestinationAddressPrefix=["10.0.0.0/16"],
                            ),
                        ],
                    )
                ]
            )
        if path == cfg["association_id"]:
            return dict(
                id=path,
                properties=dict(dataCollectionRuleId=cfg["data_collection_rule_id"]),
            )
        if path.endswith("/metrics"):
            name = query["metricnames"][0]
            metric_bad = bad and self.check in ("monitoring", "workload")
            val = 999 if metric_bad else (1 if name == "Healthy" else 10)
            metadata = (
                [
                    dict(name=dict(value=k), value=v)
                    for k, v in [
                        ("RunId", "synthetic-run"),
                        ("UnitId", "synthetic-unit"),
                    ]
                ]
                if name == "Healthy"
                else []
            )
            return dict(
                namespace=query["metricnamespace"][0],
                resourceregion=self.scope["region"],
                interval="PT1M",
                timespan=query["timespan"][0],
                value=[
                    dict(
                        id=path + "/" + name,
                        name=dict(value=name),
                        timeseries=[
                            dict(
                                metadatavalues=metadata,
                                data=[
                                    dict(
                                        timeStamp=self.stamp(), minimum=val, maximum=val
                                    )
                                ],
                            )
                        ],
                    )
                ],
            )
        b = cfg["backup"]
        if path == b["protected_item_id"]:
            return dict(
                id=path,
                properties=dict(
                    virtualMachineId=cfg["vm_id"],
                    policyId=b["policy_id"],
                    protectionState="ProtectionError" if bad else "Protected",
                    lastBackupStatus="Completed",
                    lastBackupTime=self.stamp(),
                ),
            )
        if path == b["protected_item_id"] + "/recoveryPoints":
            return dict(
                value=[
                    dict(
                        id=path + "/newly-created",
                        properties=dict(
                            recoveryPointTime=self.stamp(),
                            recoveryPointType="AppConsistent",
                        ),
                    )
                ]
            )
        raise AssertionError("unrecognized fixed Azure read " + path)

    @staticmethod
    def assert_read(method, path):
        assert method == "GET" or (
            method == "POST" and path.endswith("/effectiveNetworkSecurityGroups")
        )

    def aws(self, url, method, body):
        from urllib.parse import parse_qs, urlsplit, quote

        cfg = self.cfg
        values: dict
        bad = self.variant == "unhealthy"
        host = urlsplit(url).netloc
        if host.startswith("backup."):
            assert method == "GET"
            if "/selections/" in url:
                return dict(
                    BackupPlanId="plan",
                    SelectionId="selection",
                    BackupSelection=dict(
                        Resources=[
                            "arn:aws:ec2:us-east-1:123456789012:instance/"
                            + cfg["instance_id"]
                        ],
                        IamRoleArn=cfg["backup"]["role_arn"],
                    ),
                )
            recovery = dict(
                RecoveryPointArn="arn:aws:backup:us-east-1:123456789012:recovery-point:point",
                BackupVaultName="vault",
                ResourceArn="arn:aws:ec2:us-east-1:123456789012:instance/"
                + cfg["instance_id"],
                CreatedBy=dict(BackupPlanId="plan"),
                Status="PARTIAL" if bad else "COMPLETED",
                IsEncrypted=True,
                CreationDate=1792299600 if self.variant == "stale" else 1792303260,
                CompletionDate=1792299600 if self.variant == "stale" else 1792303260,
            )
            if urlsplit(url).path.endswith("/recovery-points/"):
                return dict(RecoveryPoints=[recovery])
            return recovery
        assert method == "POST"
        args = parse_qs(body.decode())
        action = args["Action"][0]
        if host.startswith("ec2."):
            ns = "http://ec2.amazonaws.com/doc/2016-11-15/"
            if action == "DescribeInstances":
                values = dict(
                    reservationSet=[
                        dict(
                            ownerId="123456789012",
                            instancesSet=[
                                dict(
                                    instanceId=cfg["instance_id"],
                                    instanceState=dict(
                                        name="stopped"
                                        if bad and self.check == "resource"
                                        else "running"
                                    ),
                                    vpcId=cfg["vpc_id"],
                                    subnetId=cfg["subnet_id"],
                                    monitoring=dict(state="enabled"),
                                    iamInstanceProfile=dict(
                                        arn=cfg["instance_profile_arn"]
                                    ),
                                    groupSet=[
                                        dict(groupId=cfg["security_group_ids"][0])
                                    ],
                                    networkInterfaceSet=[
                                        dict(
                                            subnetId=cfg["subnet_id"],
                                            groupSet=[
                                                dict(
                                                    groupId=cfg["security_group_ids"][0]
                                                )
                                            ],
                                            ipv6AddressesSet=[],
                                        )
                                    ],
                                )
                            ],
                        )
                    ]
                )
            elif action == "DescribeSecurityGroups":
                ingress = (
                    [dict(ipProtocol="-1", ipRanges=[dict(cidrIp="0.0.0.0/0")])]
                    if bad
                    else []
                )
                values = dict(
                    securityGroupInfo=[
                        dict(
                            ownerId="123456789012",
                            groupId=cfg["security_group_ids"][0],
                            vpcId=cfg["vpc_id"],
                            ipPermissions=ingress,
                            ipPermissionsEgress=[
                                dict(
                                    ipProtocol="tcp",
                                    fromPort="443",
                                    toPort="443",
                                    ipRanges=[dict(cidrIp="10.0.0.0/16")],
                                    ipv6Ranges=[],
                                    groups=[],
                                    prefixListIds=[],
                                )
                            ],
                        )
                    ]
                )
            else:
                raise AssertionError(action)
            return native_xml(action, values, ns, ec2=True)
        if host == "iam.amazonaws.com":
            ns = "https://iam.amazonaws.com/doc/2010-05-08/"
            if action == "GetInstanceProfile":
                values = dict(
                    InstanceProfile=dict(
                        Arn=cfg["instance_profile_arn"],
                        Roles=[dict(Arn=cfg["role_arn"], RoleName="workload")],
                    )
                )
            elif action == "GetRolePolicy":
                policy: dict = dict(
                    Version="2012-10-17",
                    Statement=[
                        dict(
                            Effect="Deny",
                            NotAction="cloudwatch:PutMetricData",
                            Resource="*",
                        ),
                        dict(
                            Effect="Deny",
                            Action="cloudwatch:PutMetricData",
                            Resource="*",
                            Condition={
                                "StringNotEquals": {"cloudwatch:namespace": "Workload"}
                            },
                        ),
                        dict(
                            Effect="Allow",
                            Action="cloudwatch:PutMetricData",
                            Resource="*",
                            Condition={
                                "StringEquals": {"cloudwatch:namespace": "Workload"}
                            },
                        ),
                    ],
                )
                if bad:
                    policy["Statement"].pop(0)
                values = dict(
                    RoleName="workload",
                    PolicyName=cfg["guard_policy_name"],
                    PolicyDocument=quote(json.dumps(policy)),
                )
            else:
                raise AssertionError(action)
            return native_xml(action, values, ns)
        assert host == "monitoring.us-east-1.amazonaws.com"
        ns = "http://monitoring.amazonaws.com/doc/2010-08-01/"
        if action == "DescribeAlarms":
            values = dict(
                MetricAlarms=[
                    dict(
                        AlarmName=cfg["alarm_name"],
                        Namespace="AWS/EC2",
                        MetricName="StatusCheckFailed",
                        Statistic="Maximum",
                        Period="60",
                        EvaluationPeriods="2",
                        Threshold="0",
                        ComparisonOperator="GreaterThanThreshold",
                        TreatMissingData="breaching",
                        Dimensions=[dict(Name="InstanceId", Value=cfg["instance_id"])],
                        StateValue="ALARM" if bad else "OK",
                    )
                ]
            )
        elif action == "GetMetricStatistics":
            name = args["MetricName"][0]
            values = dict(
                Label=name,
                Datapoints=[
                    dict(
                        Timestamp=self.stamp(),
                        Maximum="999" if bad else ("1" if name == "Healthy" else "0"),
                        Minimum="999" if bad else ("1" if name == "Healthy" else "0"),
                    )
                ],
            )
        else:
            raise AssertionError(action)
        return native_xml(action, values, ns)


def native_xml(action, values, namespace, ec2=False):
    import xml.etree.ElementTree as ET

    root = ET.Element(action + "Response", xmlns=namespace)
    target = root if ec2 else ET.SubElement(root, action + "Result")

    def add(parent, key, value):
        node = ET.SubElement(parent, key)
        if isinstance(value, dict):
            for k, v in value.items():
                add(node, k, v)
        elif isinstance(value, list):
            for v in value:
                add(node, "item" if ec2 else "member", v)
        else:
            node.text = str(value)

    for k, v in values.items():
        add(target, k, v)
    return ET.tostring(root)



def use_protected_profile(case):
    reference = case.req["verification_profile"]
    path = case.root / reference["path"]
    profile = json.loads(path.read_bytes())
    profile.update(id="cloud-compute", version="2")
    path.write_bytes(encode(profile))
    reference.update(id=profile["id"], version=profile["version"], sha256=hashlib.sha256(encode(profile)).hexdigest())


class AwsObservationOrchestration(unittest.TestCase):
    """Production prepare/apply/observe code over explicitly synthetic transports."""

    def setup_execution(self, *, selectors=True, update=False, protected=False):
        spec = importlib.util.spec_from_file_location(
            "observation_execution_fixtures",
            ROOT / "tests/cloud-orchestration-execution.tests.py",
        )
        assert spec and spec.loader
        fixtures = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(fixtures)
        case = fixtures.AwsExecution(
            "test_exact_async_assets_native_role_failure_settings_and_single_execution"
        )
        case.setUp()
        if update:
            from dataclasses import replace

            case.native.existing = True
            case.native.control = replace(
                case.native.control, existing_stack_id=case.native.stack
            )
        self.addCleanup(case.doCleanups)
        sys.modules.pop("aws_observation", None)
        cfg = observation_config("aws")
        cfg = json.loads(
            json.dumps(cfg).replace("123456789012", case.req["scope"]["account_id"])
        )
        cfg["instance_profile_arn"] = (
            "arn:aws:iam::111111111111:instance-profile/synthetic-profile"
        )
        cfg["vpc_id"] = "vpc-11111111"
        cfg["subnet_id"] = "subnet-11111111"
        cfg["backup"]["plan_id"] = "synthetic-plan"
        if selectors:
            cfg.pop("instance_id")
            cfg.pop("security_group_ids")
            cfg.pop("alarm_name")
            cfg.update(
                instance_logical_id="Workload",
                security_group_logical_ids=["PrivateGroup"],
                alarm_logical_id="Health",
            )
            cfg["backup"].pop("selection_id")
            cfg["backup"]["selection_logical_id"] = "Protection"
        config_ref = case.req["local_context"]["provider_config"]
        config = json.loads((case.root / config_ref["path"]).read_bytes())
        config["observation"] = cfg
        (case.root / config_ref["path"]).write_bytes(encode(config))
        config_ref["sha256"] = hashlib.sha256(encode(config)).hexdigest()
        if protected:
            use_protected_profile(case)
        case.request_bytes = encode(case.req)
        (case.root / case.request_ref["path"]).write_bytes(case.request_bytes)
        case.request_ref["sha256"] = hashlib.sha256(case.request_bytes).hexdigest()
        wire = ObservationWire(case.native, cfg)
        case.native = wire
        case.executor = case.stage("prepare")
        case.prepare()
        self.assertEqual(case.apply()["result"], "PASS")
        if protected:
            wire.profile_executed = True
        case.executor.clock = lambda: 1792303260
        return case, wire

    def test_unknown_create_ids_resolved_without_request_edits(self):
        case, wire = self.setup_execution()
        before = (case.root / case.request_ref["path"]).read_bytes()
        writes = list(wire.writes)
        result = case.executor.observe(case.directory + "/verify.json", "verify")
        verification = json.loads(
            (
                case.root / (case.directory + "/verify.json.verification.json")
            ).read_bytes()
        )
        self.assertEqual(verification["overall_result"], "PASS")
        self.assertFalse(verification["evidence_complete"])
        self.assertEqual(result["result"], "BLOCKED")
        self.assertEqual(wire.writes, writes)
        self.assertEqual((case.root / case.request_ref["path"]).read_bytes(), before)
        self.assertEqual(
            set(wire.resolved), {"Workload", "PrivateGroup", "Health", "Protection"}
        )

    def test_newer_or_ambiguous_stack_operation_rejected(self):
        from dataclasses import replace
        from urllib.parse import parse_qs
        import xml.etree.ElementTree as ET

        for variant in (
            "newer-stack",
            "newer-resource",
            "missing-token",
            "unordered",
            "same-time",
        ):
            with self.subTest(variant=variant):
                case, wire = self.setup_execution(update=True)
                self.assertEqual(wire.native.create["ChangeSetType"], "UPDATE")
                wire.health.cfg["instance_id"] = "i-fedcba98765432100"
                original = wire.request

                def response(method, url, headers, body=None):
                    value = original(method, url, headers, body)
                    if "cloudformation." in url and parse_qs(body.decode()).get(
                        "Action"
                    ) == ["DescribeStackEvents"]:
                        tree = ET.fromstring(value.body)
                        events = next(
                            n for n in tree.iter() if n.tag.endswith("}StackEvents")
                        )
                        other = copy.deepcopy(list(events)[0])
                        for node in other:
                            if node.tag.endswith("}ClientRequestToken"):
                                node.text = (
                                    ""
                                    if variant == "missing-token"
                                    else "other-operation"
                                )
                            if node.tag.endswith("}Timestamp"):
                                node.text = (
                                    "2026-10-18T06:00:00Z"
                                    if variant == "same-time"
                                    else "2026-10-18T06:00:30Z"
                                )
                            if (
                                node.tag.endswith("}ResourceType")
                                and variant == "newer-resource"
                            ):
                                node.text = "AWS::EC2::Instance"
                        events.insert(
                            len(events) if variant == "unordered" else 0, other
                        )
                        value = replace(value, body=ET.tostring(tree))
                    return value

                writes = list(wire.writes)
                with (
                    patch.object(wire, "request", side_effect=response),
                    self.assertRaises(ValueError),
                ):
                    case.executor.observe(case.directory + "/newer.json", "verify")
                self.assertEqual(wire.writes, writes)

    def test_legacy_physical_config_rejected_before_admission(self):
        sys.path.insert(0, str(ROOT / "plugins/sdd-aws-cloud/scripts"))
        import aws_observation

        with self.assertRaises(ValueError):
            aws_observation.configuration(observation_config("aws"))

    def test_stack_membership_counterparts(self):
        for field, value in [
            ("StackId", "wrong"),
            ("LogicalResourceId", "Other"),
            ("ResourceType", "AWS::EC2::Volume"),
            ("PhysicalResourceId", "wrong"),
            ("ResourceStatus", "CREATE_FAILED"),
        ]:
            with self.subTest(field=field):
                case, wire = self.setup_execution()
                wire.membership_override = {field: value}
                with self.assertRaises(ValueError):
                    case.executor.observe(case.directory + "/mismatch.json", "verify")

    def test_original_native_operation_not_copied_receipt(self):
        case, wire = self.setup_execution()
        path = case.root / (case.directory + "/execute-submission.json")
        journal = json.loads(path.read_bytes())
        journal["stack_id"] = journal["stack_id"].replace("/native-id", "/copied")
        path.write_bytes(encode(journal))
        writes = list(wire.writes)
        with self.assertRaisesRegex(ValueError, "STACK_ID_MISMATCH"):
            case.executor.observe(case.directory + "/copied.json", "verify")
        self.assertEqual(wire.writes, writes)

    def test_native_healthy_substitute_response_blocks(self):
        case, wire = self.setup_execution()
        original = wire.health.request

        def substituted(method, url, headers, body=None):
            response = original(method, url, headers, body)
            response.body = response.body.replace(
                b"i-0123456789abcdef0", b"i-fedcba98765432100"
            )
            return response

        with patch.object(wire.health, "request", side_effect=substituted):
            result = case.executor.observe(
                case.directory + "/substituted.json", "verify"
            )
        self.assertEqual(result["result"], "BLOCKED")

    def test_publication_fresh_checks_never_reuse_saved_success(self):
        case, wire = self.setup_execution()
        first = case.executor.observe(case.directory + "/first.json", "verify")
        self.assertEqual(first["result"], "BLOCKED")  # synthetic, never native proof
        wire.health.variant = "unhealthy"
        wire.health.check = "workload"
        result = case.executor.observe(case.directory + "/second.json", "verify")
        self.assertEqual(result["result"], "FAIL")
        with self.assertRaises(ValueError):
            case.executor.observe(case.directory + "/first.json", "verify")

    def test_emitted_contracts_are_closed(self):
        case, wire = self.setup_execution()
        case.executor.observe(case.directory + "/schema.json", "verify")
        spec = importlib.util.spec_from_file_location(
            "observation_schema_oracle",
            ROOT / "plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py",
        )
        assert spec and spec.loader
        oracle = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(oracle)
        for contract, suffix in [
            ("collection-context", ".context.json"),
            ("check-result", ".resource.result.json"),
            ("observation-evidence", ".manifest.json"),
        ]:
            schema = json.loads(
                (ROOT / ("contracts/cloud-" + contract + ".schema.json")).read_bytes()
            )
            value = json.loads(
                (case.root / (case.directory + "/schema.json" + suffix)).read_bytes()
            )
            self.assertEqual(oracle._schema_validate(schema, value), [])
            changed = dict(value, unknown="not allowed")
            self.assertTrue(oracle._schema_validate(schema, changed))
            for key in value:
                changed = dict(value)
                del changed[key]
                with self.subTest(contract=contract, missing=key):
                    self.assertTrue(oracle._schema_validate(schema, changed))


class AzureTestBase(unittest.TestCase):
    def setUp(self):
        scripts = str(ROOT / "plugins/sdd-azure-cloud/scripts")
        self.modules = patch.dict(sys.modules)
        self.modules.start()
        self.addCleanup(self.modules.stop)
        for name in (
            "cloud",
            "azure_governed",
            "azure_execution",
            "azure_observation",
            "azure_arm",
            "azure_local",
            "azure_graph",
        ):
            sys.modules.pop(name, None)
        paths = patch.object(sys, "path", [scripts, *sys.path])
        paths.start()
        self.addCleanup(paths.stop)
        import azure_governed
        import azure_observation

        self.g, self.o = azure_governed, azure_observation


class AzureCompletionCases(AzureTestBase):
    def test_inert_template_has_literal_separate_phase_boundaries(self):
        workflow = self.g.workflow_template()
        self.assertEqual(
            set(workflow["jobs"]),
            {"prepare", "apply", "reconcile", "observe", "verify"},
        )
        for phase, job in workflow["jobs"].items():
            self.assertEqual(job["environment"], "sandbox-" + phase)
            self.assertEqual(
                job["if"],
                "${{ github.run_attempt == 1 && inputs.operation == '" + phase + "' }}",
            )
            step = job["steps"][1]
            self.assertNotIn("CLOUD_PHASE", step["env"])
            self.assertIn("azure_governed.py " + phase + " --workspace", step["run"])
            self.assertEqual("--require-native-apply" in step["run"], phase == "apply")

    def completion(self, mutation=None):
        from types import SimpleNamespace
        import base64

        repo, revision = "synthetic/control", "a" * 40
        request_ref = dict(path="request.json", sha256="b" * 64)
        preview = dict(path="preview.json", sha256="c" * 64)
        scope = dict(
            account_id="00000000-0000-0000-0000-000000000001",
            region="eastus",
            deployment_scope="sandbox",
        )
        workflow = self.g.workflow_template(
            executor_repository="synthetic/executor",
            executor_revision="d" * 40,
            subscription=scope["account_id"],
            region=scope["region"],
            input_repository="synthetic/plans",
        )
        run = dict(
            id=123,
            run_attempt=1,
            status="completed",
            conclusion="success",
            event="workflow_dispatch",
            head_sha=revision,
            path=".github/workflows/cloud.yml",
            display_title="cloud:" + request_ref["sha256"] + ":" + preview["sha256"],
            repository=dict(id=42, full_name=repo),
            head_repository=dict(id=42, full_name=repo),
        )
        job = dict(
            id=456,
            run_id=123,
            run_attempt=1,
            head_sha=revision,
            name="apply",
            status="completed",
            conclusion="success",
            started_at="2026-10-18T06:00:00Z",
            completed_at="2026-10-18T06:01:00Z",
            steps=[
                dict(
                    number=2,
                    name="Execute original apply; require native completion",
                    status="completed",
                    conclusion="success",
                    started_at="2026-10-18T06:00:01Z",
                    completed_at="2026-10-18T06:00:59Z",
                )
            ],
        )
        jobs = dict(total_count=1, jobs=[job])
        if mutation:
            mutation(run, job, jobs, workflow)

        class Transport:
            calls = []

            def request(self, method, url, headers):
                self.calls.append((method, url))
                if "/contents/" in url:
                    return encode(
                        dict(
                            type="file",
                            encoding="base64",
                            path=".github/workflows/cloud.yml",
                            content=base64.b64encode(encode(workflow)).decode(),
                        )
                    )
                return encode(jobs if "/jobs?" in url else run)

        transport = Transport()
        policy = SimpleNamespace(
            repository=repo,
            repository_id=42,
            workflow=".github/workflows/cloud.yml",
            workflow_revision=revision,
        )
        executor = SimpleNamespace(
            request_ref=request_ref,
            request=dict(scope=scope),
            clock=lambda: 1792303320,
            boundary=SimpleNamespace(
                policy=policy,
                runtime=SimpleNamespace(github_token="synthetic"),
                transport=transport,
            ),
        )
        trace: list[dict] = []
        stamp = self.o.original_apply_completion(executor, 123, preview, trace)
        self.assertTrue(all(method == "GET" for method, _ in transport.calls))
        self.assertEqual(len(trace), 3)
        return stamp

    def test_original_job_completion_matches_fixed_pinned_workflow(self):
        self.assertEqual(self.completion(), "2026-10-18T06:01:00Z")

    def test_original_job_counterpart_mismatches(self):
        cases = [
            lambda r, j, listing, w: r.update(event="push"),
            lambda r, j, listing, w: r.update(status="in_progress"),
            lambda r, j, listing, w: r.update(conclusion="failure"),
            lambda r, j, listing, w: r.update(path="other.yml"),
            lambda r, j, listing, w: r.update(
                head_repository=dict(id=99, full_name="other/repo")
            ),
            lambda r, j, listing, w: j.update(run_attempt=2),
            lambda r, j, listing, w: j.update(status="queued"),
            lambda r, j, listing, w: j.update(started_at="2026-10-18T06:02:00Z"),
            lambda r, j, listing, w: j["steps"][0].update(status="in_progress"),
            lambda r, j, listing, w: j["steps"][0].update(
                completed_at="2026-10-18T06:03:00Z"
            ),
            lambda r, j, listing, w: listing.update(jobs=[]),
            lambda r, j, listing, w: r.update(id=999),
            lambda r, j, listing, w: r.update(run_attempt=2),
            lambda r, j, listing, w: r.update(head_sha="f" * 40),
            lambda r, j, listing, w: r.update(display_title="copied"),
            lambda r, j, listing, w: r.update(
                repository=dict(id=99, full_name="other/repo")
            ),
            lambda r, j, listing, w: j.update(run_id=999),
            lambda r, j, listing, w: j.update(head_sha="f" * 40),
            lambda r, j, listing, w: j.update(name="reconcile"),
            lambda r, j, listing, w: j.update(conclusion="skipped"),
            lambda r, j, listing, w: j.update(completed_at=None),
            lambda r, j, listing, w: j["steps"][0].update(conclusion="skipped"),
            lambda r, j, listing, w: listing.update(total_count=101),
            lambda r, j, listing, w: w["jobs"]["apply"]["steps"][1].update(
                run="python arbitrary.py"
            ),
            lambda r, j, listing, w: w["jobs"]["apply"]["steps"][0]["with"].update(
                ref="main"
            ),
        ]
        for index, mutation in enumerate(cases):
            with self.subTest(case=index), self.assertRaises(ValueError):
                self.completion(mutation)


class AzureResourceBindingCases(AzureTestBase):
    o: ModuleType
    g: ModuleType

    def test_compiled_and_original_operation_membership(self):
        from types import SimpleNamespace

        scope = dict(
            account_id="00000000-0000-0000-0000-000000000001",
            region="eastus",
            deployment_scope="sandbox",
        )
        cfg = observation_config("azure")
        vm = dict(
            type="Microsoft.Compute/virtualMachines", name="workload", properties={}
        )
        nic = dict(
            type="Microsoft.Network/networkInterfaces",
            name="workload-nic",
            properties={},
        )
        association = dict(
            type="Microsoft.Insights/dataCollectionRuleAssociations",
            name="monitor",
            scope=cfg["vm_id"],
            properties={},
        )
        native_id = (
            "/subscriptions/"
            + scope["account_id"]
            + "/resourceGroups/sandbox/providers/Microsoft.Resources/deployments/sdd-original"
        )
        targets = [
            ("vm_id", "Microsoft.Compute/virtualMachines"),
            ("nic_id", "Microsoft.Network/networkInterfaces"),
            ("association_id", "Microsoft.Insights/dataCollectionRuleAssociations"),
        ]
        for variant in (
            "matched",
            "compiled-substitute",
            "native-substitute",
            "type",
            "state",
            "pagination",
            "newer-deployment",
            "active-deployment",
            "same-time-deployment",
            "deployment-pagination",
            "deployment-denied",
        ):
            current = copy.deepcopy(cfg)
            current.pop("backup")
            compiled = [vm, nic, association]
            if variant == "compiled-substitute":
                compiled = [dict(vm, name="other"), nic, association]
            operations: dict = dict(
                value=[
                    dict(
                        id=native_id + "/operations/" + str(i),
                        operationId=str(i),
                        properties=dict(
                            provisioningState="Succeeded",
                            provisioningOperation="Create",
                            targetResource=dict(id=cfg[key], resourceType=typ),
                        ),
                    )
                    for i, (key, typ) in enumerate(targets)
                ]
            )
            if variant == "native-substitute":
                operations["value"][0]["properties"]["targetResource"]["id"] += "-other"
            if variant == "type":
                operations["value"][0]["properties"]["targetResource"][
                    "resourceType"
                ] = "Microsoft.Compute/disks"
            if variant == "state":
                operations["value"][0]["properties"]["provisioningState"] = "Failed"
            if variant == "pagination":
                operations["nextLink"] = "https://untrusted.example/next"

            class Client:
                native_id: str

                def call(self, method, url, credentials, request_id):
                    self.last = (method, url)
                    if "/deployments?" in url:
                        value: dict = dict(
                            value=[
                                dict(
                                    id=native_id,
                                    properties=dict(
                                        timestamp="2026-10-18T06:00:00Z",
                                        provisioningState="Succeeded",
                                    ),
                                )
                            ]
                        )
                        if variant in (
                            "newer-deployment",
                            "active-deployment",
                            "same-time-deployment",
                        ):
                            value["value"].append(
                                dict(
                                    id=native_id + "-other",
                                    properties=dict(
                                        timestamp="2026-10-18T05:00:00Z"
                                        if variant == "active-deployment"
                                        else "2026-10-18T06:00:00Z"
                                        if variant == "same-time-deployment"
                                        else "2026-10-18T06:00:30Z",
                                        provisioningState="Running"
                                        if variant == "active-deployment"
                                        else "Succeeded",
                                    ),
                                )
                            )
                        if variant == "deployment-pagination":
                            value["nextLink"] = "https://untrusted.example"
                        return SimpleNamespace(
                            status=403 if variant == "deployment-denied" else 200,
                            body=encode(value),
                        )
                    return SimpleNamespace(status=200, body=encode(operations))

            client = Client()
            client.native_id = native_id
            executor = SimpleNamespace(
                request=dict(scope=scope),
                client=client,
                request_id="synthetic-request-id",
                clock=lambda: 1792303320,
            )
            with self.subTest(variant=variant):
                if variant == "matched":
                    self.o.bind_original_resources(executor, current, compiled, {}, [])
                    self.assertEqual(client.last[0], "GET")
                else:
                    with self.assertRaises(ValueError):
                        self.o.bind_original_resources(
                            executor, current, compiled, {}, []
                        )


class AzureObservationOrchestration(AzureTestBase):
    o: ModuleType
    g: ModuleType

    def setup_execution(self, protected=False):
        import base64
        from types import SimpleNamespace
        from urllib.parse import urlsplit

        spec = importlib.util.spec_from_file_location(
            "azure_observation_execution",
            ROOT / "tests/cloud-orchestration-execution.tests.py",
        )
        assert spec and spec.loader
        fixtures = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(fixtures)
        case = fixtures.AzureExecution(
            "test_exact_manifest_native_incremental_single_submission_no_compiler"
        )
        case.setUp()
        self.addCleanup(case.doCleanups)
        params = {k: v["value"] for k, v in case.arm.parameters["parameters"].items()}
        resources = {
            r["type"]: change["resourceId"]
            for r, change in zip(case.arm.resources, case.arm.changes)
        }
        cfg = dict(
            vm_id=resources["Microsoft.Compute/virtualMachines"],
            nic_id=resources["Microsoft.Network/networkInterfaces"],
            subnet_id=params["subnetId"],
            identity_id=params["identityId"],
            association_id=resources[
                "Microsoft.Insights/dataCollectionRuleAssociations"
            ],
            data_collection_rule_id=params["dataCollectionRuleId"],
            monitoring_workspace_id=resources[
                "Microsoft.Compute/virtualMachines"
            ].split("/providers/")[0]
            + "/providers/Microsoft.OperationalInsights/workspaces/monitor",
            workload_metric=dict(
                namespace="Workload", name="Healthy", minimum=1, maximum=1
            ),
            backup=dict(
                protected_item_id=resources[
                    "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems"
                ],
                policy_id=params["backupPolicyId"],
            ),
        )
        ref = case.req["local_context"]["provider_config"]
        config = json.loads((case.root / ref["path"]).read_bytes())
        config["observation"] = cfg
        (case.root / ref["path"]).write_bytes(encode(config))
        ref["sha256"] = hashlib.sha256(encode(config)).hexdigest()
        if protected:
            use_protected_profile(case)
        case.request_bytes = encode(case.req)
        (case.root / case.request_ref["path"]).write_bytes(case.request_bytes)
        case.request_ref["sha256"] = hashlib.sha256(case.request_bytes).hexdigest()
        case.executor = case.stage("prepare")
        case.prepare()
        applied = case.apply()
        self.assertEqual(applied["result"], "PASS")
        self.g.require_native_apply(applied, case.executor)
        for changed in [
            dict(applied, result="NO_CHANGE"),
            dict(applied, operation="reconcile"),
            dict(applied, native_operation_id="wrong"),
        ]:
            with self.assertRaises(ValueError):
                self.g.require_native_apply(changed, case.executor)
        health = NativeFixture("azure", "all", "healthy")
        health.cfg = cfg
        health.scope = case.req["scope"]
        health.principal = fixtures.APPLY_OBJECT
        native_id = case.executor.client.native_id
        original_arm = case.arm.request

        def wire(method, url, headers, body=None):
            path = urlsplit(url).path
            if path.endswith("/providers/Microsoft.Resources/deployments"):
                return SimpleNamespace(
                    status=200,
                    headers={},
                    body=encode(
                        dict(
                            value=[
                                dict(
                                    id=native_id,
                                    properties=dict(
                                        timestamp="2026-10-18T06:00:00Z",
                                        provisioningState="Succeeded",
                                    ),
                                )
                            ]
                        )
                    ),
                )
            if path == native_id + "/operations":
                return SimpleNamespace(
                    status=200,
                    headers={},
                    body=encode(
                        dict(
                            value=[
                                dict(
                                    id=native_id + "/operations/" + str(i),
                                    operationId=str(i),
                                    properties=dict(
                                        provisioningState="Succeeded",
                                        provisioningOperation="Create",
                                        targetResource=dict(
                                            id=change["resourceId"],
                                            resourceType=change["after"]["type"],
                                        ),
                                    ),
                                )
                                for i, change in enumerate(case.arm.changes)
                            ]
                        )
                    ),
                )
            if path == native_id:
                response = original_arm(method, url, headers, body)
                value = json.loads(response.body)
                value["properties"]["outputResources"] = [
                    dict(id=v) for v in resources.values()
                ]
                return SimpleNamespace(
                    status=response.status, headers=response.headers, body=encode(value)
                )
            return health.request(method, url, headers, body)

        workflow = self.g.workflow_template(
            executor_repository="synthetic/executor",
            executor_revision="d" * 40,
            subscription=case.req["scope"]["account_id"],
            region=case.req["scope"]["region"],
            input_repository="synthetic/plans",
        )
        auth = case.auths[-1]
        original_auth = auth.request

        def metadata(method, url, headers, body=None):
            if "/contents/" in url:
                return encode(
                    dict(
                        type="file",
                        encoding="base64",
                        path=fixtures.WORKFLOW,
                        content=base64.b64encode(encode(workflow)).decode(),
                    )
                )
            if "/attempts/1/jobs?" in url:
                return encode(
                    dict(
                        total_count=1,
                        jobs=[
                            dict(
                                id=456,
                                run_id=123,
                                run_attempt=1,
                                head_sha=fixtures.REV,
                                name="apply",
                                status="completed",
                                conclusion="success",
                                started_at="2026-10-18T06:00:00Z",
                                completed_at="2026-10-18T06:01:00Z",
                                steps=[
                                    dict(
                                        name="Execute original apply; require native completion",
                                        status="completed",
                                        conclusion="success",
                                        started_at="2026-10-18T06:00:01Z",
                                        completed_at="2026-10-18T06:00:59Z",
                                    )
                                ],
                            )
                        ],
                    )
                )
            if url.endswith("/actions/runs/123"):
                return encode(dict(auth.run, status="completed", conclusion="success"))
            return original_auth(method, url, headers, body)

        case.executor.clock = lambda: 1792303320
        for target, method in ((case.arm, wire), (auth, metadata)):
            patched = patch.object(target, "request", side_effect=method)
            patched.start()
            self.addCleanup(patched.stop)
        return case, health

    def test_public_verify_uses_original_operation_and_received_signal(self):
        case, health = self.setup_execution()
        before = (case.root / case.request_ref["path"]).read_bytes()
        writes = case.arm.submissions
        result = case.executor.observe(case.directory + "/observed.json", "verify")
        verification = json.loads(
            (
                case.root / (case.directory + "/observed.json.verification.json")
            ).read_bytes()
        )
        self.assertEqual(verification["overall_result"], "PASS")
        self.assertFalse(verification["evidence_complete"])
        self.assertEqual(result["result"], "BLOCKED")
        self.assertEqual(case.arm.submissions, writes)
        self.assertEqual((case.root / case.request_ref["path"]).read_bytes(), before)


class ObservationWire:
    """Existing CFN executor fixture plus independent service response fixture."""

    def __init__(self, native, config):
        self.native = native
        self.health = NativeFixture("aws", "all", "healthy")
        self.health.cfg = json.loads(
            json.dumps(self.health.cfg).replace("123456789012", "111111111111")
        )
        self.health.cfg.update(
            {
                k: config[k]
                for k in (
                    "instance_profile_arn",
                    "role_arn",
                    "guard_policy_name",
                    "vpc_id",
                    "subnet_id",
                )
            }
        )
        self.health.cfg["backup"]["plan_id"] = "synthetic-plan"
        self.resolved = []
        self.membership_override = {}
        self.profile_executed = False

    def __getattr__(self, name):
        return getattr(self.native, name)

    def request(self, method, url, headers, body=None):
        from urllib.parse import parse_qs

        if "cloudformation." not in url:
            if ".s3." in url:
                return self.native.request(method, url, headers, body)
            response = self.health.request(method, url, headers, body)
            response.body = response.body.replace(
                b"123456789012", b"111111111111"
            ).replace(b'"plan"', b'"synthetic-plan"')
            return response
        args = parse_qs(body.decode())
        if args["Action"] == ["DescribeStackResource"]:
            logical = args["LogicalResourceId"][0]
            self.resolved.append(logical)
            cfg = self.health.cfg
            targets = {
                "Workload": ("AWS::EC2::Instance", cfg["instance_id"]),
                "PrivateGroup": (
                    "AWS::EC2::SecurityGroup",
                    cfg["security_group_ids"][0],
                ),
                "Health": ("AWS::CloudWatch::Alarm", cfg["alarm_name"]),
                "Protection": (
                    "AWS::Backup::BackupSelection",
                    cfg["backup"]["selection_id"],
                ),
            }
            typ, physical = targets[logical]
            detail = dict(
                StackId=self.native.stack,
                LogicalResourceId=logical,
                ResourceType=typ,
                PhysicalResourceId=physical,
                ResourceStatus="CREATE_COMPLETE",
            )
            detail.update(self.membership_override)
            return self.native.xml(
                "DescribeStackResource", dict(StackResourceDetail=detail)
            )
        response = self.native.request(method, url, headers, body)
        if args["Action"] == ["DescribeChangeSet"] and self.__dict__.get("profile_executed", False):
            from dataclasses import replace
            response = replace(response, body=response.body.replace(b"<ExecutionStatus>AVAILABLE</ExecutionStatus>", b"<ExecutionStatus>EXECUTE_COMPLETE</ExecutionStatus>"))
        if args["Action"] == ["DescribeStackEvents"]:
            from dataclasses import replace

            response = replace(
                response,
                body=response.body.replace(
                    b"</ResourceStatus>",
                    b"</ResourceStatus><Timestamp>2026-10-18T06:00:00Z</Timestamp>",
                ),
            )
        return response


class PublicObservationCases(unittest.TestCase):
    def setup_execution(self, provider, protected=False):
        harness: AzureObservationOrchestration | AwsObservationOrchestration
        if provider == "azure":
            harness = AzureObservationOrchestration(
                "test_public_verify_uses_original_operation_and_received_signal"
            )
            harness.setUp()
        else:
            harness = AwsObservationOrchestration(
                "test_unknown_create_ids_resolved_without_request_edits"
            )
        self.addCleanup(harness.doCleanups)
        case, wire = harness.setup_execution(protected=protected)
        health = wire if provider == "azure" else wire.health
        module = sys.modules["cloud"]
        return case, wire, health, module

    def run_public(self, case, module, name):
        with patch.dict(os.environ, {"CLOUD_WORKSPACE_ROOT": str(case.root)}):
            return module.run(
                [
                    "verify",
                    "--request",
                    case.request_ref["path"],
                    "--output",
                    case.directory + "/" + name + ".json",
                ],
                executor=case.executor,
            )

    @staticmethod
    def target(provider, check, url, body):
        from urllib.parse import parse_qs

        if provider == "azure":
            return {
                "resource": "/instanceView?" in url,
                "network": "/effectiveNetworkSecurityGroups?" in url,
                "identity": "/permissions?" in url,
                "monitoring": "metricnames=Percentage%20CPU" in url,
                "workload": "metricnames=Healthy" in url,
                "backup": "/protectedItems/" in url,
            }[check]
        action = parse_qs(body.decode()).get("Action", [""])[0] if body else ""
        metric = parse_qs(body.decode()).get("MetricName", [""])[0] if body else ""
        return {
            "resource": action == "DescribeInstances",
            "network": action == "DescribeSecurityGroups",
            "identity": action == "GetRolePolicy",
            "monitoring": action == "DescribeAlarms" or metric == "StatusCheckFailed",
            "workload": metric == "Healthy",
            "backup": "backup." in url,
        }[check]

    def test_public_all_checks_matrix_native_protocol_fixtures(self):
        # Finite required-check branches; dimensions sharing the same reducer guard
        # are tested separately rather than an unbounded Cartesian product.
        for provider in ("aws", "azure"):
            for check in (
                "resource",
                "network",
                "identity",
                "monitoring",
                "workload",
                "backup",
            ):
                for variant in ("healthy", "unhealthy", "denied", "missing", "stale"):
                    if variant == "stale" and check not in (
                        "monitoring",
                        "workload",
                        "backup",
                    ):
                        continue  # synchronous configuration read freshness is the lease, tested below
                    with self.subTest(provider=provider, check=check, variant=variant):
                        case, wire, health, module = self.setup_execution(provider)
                        original = health.request
                        hit = []

                        def response(method, url, headers, body=None):
                            target = self.target(provider, check, url, body)
                            health.variant, health.check = (
                                (variant if target else "healthy"),
                                check,
                            )
                            if target:
                                hit.append(url)
                            return original(method, url, headers, body)

                        with patch.object(health, "request", side_effect=response):
                            result = self.run_public(case, module, "matrix")
                        self.assertTrue(hit)
                        v = json.loads(
                            (
                                case.root
                                / (case.directory + "/matrix.json.verification.json")
                            ).read_bytes()
                        )
                        expected = (
                            "PASS"
                            if variant == "healthy"
                            else "FAIL"
                            if variant == "unhealthy"
                            else "BLOCKED"
                        )
                        self.assertEqual(
                            next(
                                c["result"]
                                for c in v["checks"]
                                if c["check_id"] == check
                            ),
                            expected,
                        )
                        self.assertFalse(v["evidence_complete"])
                        self.assertEqual(
                            result["result"],
                            "FAIL" if variant == "unhealthy" else "BLOCKED",
                        )
                        # Release nested fixture/module patches promptly between subtests.
                        self.doCleanups()

    def test_publication_bindings_scan_no_overwrite_escape_and_secret_redaction(self):
        for provider in ("aws", "azure"):
            for variant in (
                "matched",
                "overwrite",
                "symlink",
                "scanner-false",
                "scanner-error",
                "raw-secret",
                "request-drift",
                "fake-native",
            ):
                with self.subTest(provider=provider, variant=variant):
                    case, wire, health, module = self.setup_execution(provider)
                    output = case.root / (case.directory + "/publish.json")
                    original = health.request
                    canary = ("secret" + "-canary").encode()

                    def response(method, url, headers, body=None):
                        r = original(method, url, headers, body)
                        if variant == "raw-secret":
                            # Provider body only, not a record or a query identifier.
                            if r.body.startswith(b"{"):
                                value = json.loads(r.body)
                                value["privateDiagnostic"] = canary.decode()
                                r.body = encode(value)
                            else:
                                r.body = r.body.replace(
                                    b"</", b"<!--" + canary + b"--></", 1
                                )
                        if variant == "request-drift":
                            path = case.root / case.request_ref["path"]
                            if not path.read_bytes().endswith(b" \n"):
                                path.write_bytes(path.read_bytes() + b" \n")
                        return r

                    if variant in ("overwrite", "symlink"):
                        if variant == "overwrite":
                            output.write_bytes(b"preserved")
                        else:
                            output.symlink_to(case.root / "outside.json")
                    if variant == "fake-native":
                        (case.root / "fake.json").write_bytes(
                            encode(
                                dict(
                                    classification="native",
                                    approved=True,
                                    exit_code=0,
                                    evidence_complete=True,
                                )
                            )
                        )
                        setattr(health, "classification", "native")
                    with patch.object(health, "request", side_effect=response):
                        if variant.startswith("scanner"):
                            scan_patch = (
                                patch.object(
                                    module, "safe_publication", return_value=False
                                )
                                if variant == "scanner-false"
                                else patch.object(
                                    module,
                                    "safe_publication",
                                    side_effect=OSError("scanner unavailable"),
                                )
                            )
                            with scan_patch:
                                result = self.run_public(case, module, "publish")
                        else:
                            result = self.run_public(case, module, "publish")
                    self.assertEqual(result["result"], "BLOCKED")
                    if variant in ("matched", "raw-secret", "fake-native"):
                        manifest = json.loads(
                            (
                                case.root
                                / (case.directory + "/publish.json.manifest.json")
                            ).read_bytes()
                        )
                        self.assertEqual(manifest["request"], case.request_ref)
                        self.assertEqual(manifest["classification"], "synthetic")
                        self.assertTrue(manifest["saved_receipt_authorizes_nothing"])
                        for ref in [
                            manifest["request"],
                            manifest["context"],
                            manifest["verification"],
                            *[
                                row[k]
                                for row in manifest["observations"]
                                for k in ("observation", "result")
                            ],
                        ]:
                            data = (case.root / ref["path"]).read_bytes()
                            self.assertEqual(
                                hashlib.sha256(data).hexdigest(), ref["sha256"]
                            )
                            self.assertNotIn(canary, data)
                        self.assertEqual(
                            result["input_manifest_sha256"], case.request_ref["sha256"]
                        )
                        self.assertEqual(
                            result["evidence_manifest_path"],
                            case.directory + "/publish.json.manifest.json",
                        )
                    elif variant == "overwrite":
                        self.assertEqual(output.read_bytes(), b"preserved")
                    elif variant == "symlink":
                        self.assertFalse((case.root / "outside.json").exists())
                    else:
                        self.assertFalse(output.exists())
                        if variant.startswith("scanner"):
                            self.assertFalse(
                                Path(str(output) + ".context.json").exists()
                            )
                    self.doCleanups()

    def test_all_emitted_required_fields_have_closed_schema_counterparts(self):
        spec = importlib.util.spec_from_file_location(
            "schema_oracle",
            ROOT / "plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py",
        )
        assert spec and spec.loader
        oracle = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(oracle)
        case, _, _, module = self.setup_execution("azure")
        self.run_public(case, module, "schema")

        def walk(value, schema, location):
            if isinstance(value, dict):
                for key in value:
                    if location == "operation-result" and key == "native_operation_id":
                        continue  # contract permits absent native ID for genuine no-op
                    changed = copy.deepcopy(value)
                    del changed[key]
                    with self.subTest(location=location, field=key):
                        self.assertTrue(oracle._schema_validate(schema, changed))
                if schema.get("additionalProperties") is False:
                    with self.subTest(location=location, field="unknown"):
                        self.assertTrue(
                            oracle._schema_validate(
                                schema, dict(value, unknown="extra")
                            )
                        )
                for key, item in value.items():
                    child = schema.get("properties", {}).get(key)
                    if child:
                        walk(item, child, location + "/" + key)
            elif isinstance(value, list) and "items" in schema:
                for i, item in enumerate(value):
                    walk(item, schema["items"], location + "/" + str(i))

        for contract, suffix in [
            ("collection-context", ".context.json"),
            ("check-result", ".resource.result.json"),
            ("observation", ".resource.json"),
            ("observation-evidence", ".manifest.json"),
            ("verification", ".verification.json"),
            ("operation-result", ""),
        ]:
            schema = json.loads(
                (ROOT / ("contracts/cloud-" + contract + ".schema.json")).read_bytes()
            )
            value = json.loads(
                (case.root / (case.directory + "/schema.json" + suffix)).read_bytes()
            )
            self.assertEqual(oracle._schema_validate(schema, value), [])
            walk(value, schema, contract)

    def test_public_request_and_trusted_policy_counterparts(self):
        for provider in ("aws", "azure"):
            for field in (
                "run_id",
                "unit_id",
                "scope",
                "verification_profile",
                "principal",
                "missing-credentials",
            ):
                with self.subTest(provider=provider, field=field):
                    case, wire, health, module = self.setup_execution(provider)
                    if field in ("principal", "missing-credentials"):
                        # Actual federation/identity exchange denial, not a saved local label.
                        auth = case.executor.boundary.transport
                        original = auth.request

                        def deny(method, url, headers, body=None):
                            if "login.microsoftonline.com" in url or "sts." in url:
                                if field == "missing-credentials":
                                    raise OSError("unavailable")
                                return b"{}"
                            return original(method, url, headers, body)

                        with patch.object(auth, "request", side_effect=deny):
                            result = self.run_public(case, module, "binding")
                    else:
                        value = copy.deepcopy(case.req)
                        if field == "scope":
                            value[field]["region"] = "wrong-region"
                        elif field == "verification_profile":
                            value[field]["sha256"] = "f" * 64
                        else:
                            value[field] = "other"
                        (case.root / case.request_ref["path"]).write_bytes(
                            encode(value)
                        )
                        result = self.run_public(case, module, "binding")
                    self.assertEqual(result["result"], "BLOCKED")
                    self.assertFalse(
                        (case.root / (case.directory + "/binding.json")).exists()
                    )
                    self.doCleanups()


class AlarmNumericCases(unittest.TestCase):
    """CloudWatch double semantics over real XML decoding; all I/O is synthetic."""

    ZEROS = ("0", "0.0", "0.000", "0e0", "0E+12", "0e-4000", "-0", "-0.0", "-0e-12", "+0.0")
    REJECTED = (
        "1", "-1", "0.01", "-0.01", "1e-4000", "-1e-4000", "1e4000",
        "NaN", "sNaN", "Inf", "-Inf", "Infinity", "-Infinity", "nan",
        "", "garbage", "0x0", "0_0", "0e", "0 0", "０", "0.0junk",
    )

    @staticmethod
    def alarm_response(original, value, *, field="Threshold"):
        import xml.etree.ElementTree as ET
        from urllib.parse import parse_qs

        hits = []

        def response(method, url, headers, body=None):
            result = original(method, url, headers, body)
            if body and parse_qs(body.decode()).get("Action") == ["DescribeAlarms"]:
                tree = ET.fromstring(result.body)
                nodes = [n for n in tree.iter() if n.tag.endswith("}" + field)]
                assert len(nodes) == 1
                nodes[0].text = value
                result.body = ET.tostring(tree)
                hits.append(hashlib.sha256(result.body).hexdigest())
            return result

        return response, hits

    def test_native_xml_threshold_numeric_zero(self):
        for value in self.ZEROS:
            with self.subTest(threshold=value):
                collector, fixture = FreshnessCases().collector(
                    "aws", "monitoring", "healthy", "2026-10-18T06:00:00Z"
                )
                response, hits = self.alarm_response(fixture.request, value)
                with patch.object(fixture, "request", side_effect=response):
                    self.assertTrue(collector.monitoring()[0])
                self.assertEqual(len(hits), 1)
                self.assertIn(hits[0], [q["response_sha256"] for q in collector.trace])

    def test_native_xml_threshold_rejects_nonzero_and_invalid(self):
        for value in self.REJECTED:
            with self.subTest(threshold=value):
                collector, fixture = FreshnessCases().collector(
                    "aws", "monitoring", "healthy", "2026-10-18T06:00:00Z"
                )
                response, hits = self.alarm_response(fixture.request, value)
                with patch.object(fixture, "request", side_effect=response):
                    self.assertFalse(collector.monitoring()[0])
                self.assertEqual(len(hits), 1)

    def test_other_alarm_field_semantics_remain_exact(self):
        for field, value in (("Period", "60.0"), ("EvaluationPeriods", "2e0"), ("MetricName", "statuscheckfailed")):
            with self.subTest(field=field, value=value):
                collector, fixture = FreshnessCases().collector(
                    "aws", "monitoring", "healthy", "2026-10-18T06:00:00Z"
                )
                response, hits = self.alarm_response(fixture.request, value, field=field)
                with patch.object(fixture, "request", side_effect=response):
                    self.assertFalse(collector.monitoring()[0])
                self.assertEqual(len(hits), 1)

    def test_public_synthetic_threshold_result_counterparts(self):
        for value in self.ZEROS + self.REJECTED:
            with self.subTest(threshold=value):
                harness = PublicObservationCases()
                self.addCleanup(harness.doCleanups)
                case, wire, health, module = harness.setup_execution("aws")
                response, hits = self.alarm_response(health.request, value)
                with patch.object(health, "request", side_effect=response):
                    result = harness.run_public(case, module, "numeric")
                expected = "PASS" if value in self.ZEROS else "FAIL"
                verification = json.loads((case.root / (case.directory + "/numeric.json.verification.json")).read_bytes())
                check = next(q for q in verification["checks"] if q["check_id"] == "monitoring")
                self.assertEqual(check["result"], expected)
                obs_data = (case.root / check["observation"]["path"]).read_bytes()
                self.assertEqual(hashlib.sha256(obs_data).hexdigest(), check["observation"]["sha256"])
                obs = json.loads(obs_data)
                self.assertEqual(obs["status"], expected)
                self.assertEqual(obs["exit_code"], 0 if expected == "PASS" else 1)
                self.assertEqual(obs["classification"], "synthetic")
                payload_data = (case.root / obs["result"]["path"]).read_bytes()
                self.assertEqual(hashlib.sha256(payload_data).hexdigest(), obs["result"]["sha256"])
                payload = json.loads(payload_data)
                self.assertEqual(payload["status"], expected)
                self.assertEqual(payload["reason"], "HEALTHY" if expected == "PASS" else "UNHEALTHY")
                self.assertEqual(len(hits), 1)
                self.assertIn(hits[0], [q["response_sha256"] for q in payload["queries"]])
                self.assertFalse(verification["evidence_complete"])
                public = "BLOCKED" if expected == "PASS" else "FAIL"
                self.assertEqual(verification["overall_result"], expected)
                self.assertEqual(result["result"], public)
                self.assertNotEqual(result["state"], "EVIDENCE_COMPLETE")
                self.doCleanups()


class WorkloadRangeCases(unittest.TestCase):
    def test_native_bucket_minimum_and_maximum(self):
        import xml.etree.ElementTree as ET
        from urllib.parse import parse_qs, urlsplit

        for provider in ("aws", "azure"):
            for minimum, maximum in ((1, 1), (0, 1), (1, 2), (0, 2)):
                with self.subTest(provider=provider, minimum=minimum, maximum=maximum):
                    collector, fixture = FreshnessCases().collector(
                        provider, "workload", "healthy", "2026-10-18T06:00:00Z"
                    )
                    original = fixture.request

                    def response(method, url, headers, body=None):
                        r = original(method, url, headers, body)
                        if provider == "azure":
                            value = json.loads(r.body)
                            point = value["value"][0]["timeseries"][0]["data"][0]
                            point.update(minimum=minimum, maximum=maximum)
                            r.body = encode(value)
                        else:
                            tree = ET.fromstring(r.body)
                            for n in tree.iter():
                                if n.tag.endswith("}Minimum"):
                                    n.text = str(minimum)
                                if n.tag.endswith("}Maximum"):
                                    n.text = str(maximum)
                            r.body = ET.tostring(tree)
                        return r

                    with patch.object(fixture, "request", side_effect=response):
                        self.assertEqual(
                            collector.workload()[0], minimum == maximum == 1
                        )
                    _, url, body = fixture.calls[-1]
                    query = parse_qs(body.decode() if body else urlsplit(url).query)
                    if provider == "aws":
                        self.assertEqual(
                            {
                                query["Statistics.member.1"][0],
                                query["Statistics.member.2"][0],
                            },
                            {"Minimum", "Maximum"},
                        )
                    else:
                        self.assertEqual(
                            set(query["aggregation"][0].split(",")),
                            {"Minimum", "Maximum"},
                        )


class NativeAdversarialCases(unittest.TestCase):
    def test_native_response_binding_pagination_and_unknown(self):
        import xml.etree.ElementTree as ET

        for provider in ("aws", "azure"):
            for check in (
                "resource",
                "network",
                "identity",
                "monitoring",
                "workload",
                "backup",
            ):
                for variant in ("tampered", "pagination", "unknown"):
                    if variant == "unknown" and check not in ("resource", "backup"):
                        continue  # unknown metrics/numbers and unsupported rights have their own concrete tests
                    with self.subTest(provider=provider, check=check, variant=variant):
                        collector, fixture = FreshnessCases().collector(
                            provider, check, "healthy", "2026-10-18T06:00:00Z"
                        )
                        original = fixture.request

                        def response(method, url, headers, body=None):
                            r = original(method, url, headers, body)
                            if provider == "azure":
                                value = json.loads(r.body)
                                if variant == "pagination":
                                    value["nextLink"] = "https://untrusted.example"
                                elif variant == "tampered":
                                    if (
                                        check == "identity"
                                        and "principalId" in value.get("properties", {})
                                    ):
                                        value["properties"]["principalId"] = "other"
                                    elif (
                                        check in ("monitoring", "workload")
                                        and "/metrics?" in url
                                    ):
                                        value["value"][0]["id"] += "wrong"
                                    elif "id" in value:
                                        value["id"] += "wrong"
                                elif variant == "unknown":
                                    if check == "resource" and "/instanceView?" in url:
                                        value["statuses"] = [
                                            dict(code="PowerState/unknown")
                                        ]
                                    elif (
                                        check == "backup"
                                        and "lastBackupStatus"
                                        in value.get("properties", {})
                                    ):
                                        value["properties"]["lastBackupStatus"] = (
                                            "unknown"
                                        )
                                r.body = encode(value)
                            elif r.body.startswith(b"{"):
                                value = json.loads(r.body)
                                if variant == "pagination":
                                    value["NextToken"] = "more"
                                elif "RecoveryPoints" in value:
                                    point = value["RecoveryPoints"][0]
                                    point[
                                        "ResourceArn"
                                        if variant == "tampered"
                                        else "Status"
                                    ] = "unknown"
                                r.body = encode(value)
                            else:
                                tree = ET.fromstring(r.body)
                                if variant == "pagination":
                                    container = next(
                                        (n for n in tree if n.tag.endswith("Result")),
                                        tree,
                                    )
                                    ns = tree.tag.split("}")[0] + "}"
                                    ET.SubElement(
                                        container, ns + "NextToken"
                                    ).text = "more"
                                else:
                                    key = {
                                        "resource": "instanceId"
                                        if variant == "tampered"
                                        else "name",
                                        "network": "groupId",
                                        "identity": "Arn",
                                        "monitoring": "AlarmName",
                                        "workload": "Label",
                                    }.get(check)
                                    for node in tree.iter():
                                        if node.tag.endswith("}" + str(key)):
                                            node.text = "unknown"
                                r.body = ET.tostring(tree)
                            return r

                        with (
                            patch.object(fixture, "request", side_effect=response),
                            self.assertRaises((ValueError, KeyError)),
                        ):
                            getattr(collector, check)()

    def test_postcollection_lease_expiry_prevents_publication(self):
        for provider in ("aws", "azure"):
            harness = PublicObservationCases()
            self.addCleanup(harness.doCleanups)
            case, wire, health, module = harness.setup_execution(provider)
            now = [1792303320 if provider == "azure" else 1792303260]
            case.executor.clock = lambda: now[0]
            original = health.request

            def response(method, url, headers, body=None):
                r = original(method, url, headers, body)
                if "/recoveryPoints?" in url or "/recovery-points/?" in url:
                    now[0] += 10000
                return r

            with patch.object(health, "request", side_effect=response):
                result = harness.run_public(case, module, "expired")
            self.assertEqual(result["result"], "BLOCKED")
            self.assertFalse((case.root / (case.directory + "/expired.json")).exists())
            self.doCleanups()


class ExpandedBindingCases(unittest.TestCase):
    def test_query_digests_are_exact_transport_bytes(self):
        for provider in ("aws", "azure"):
            for check in (
                "resource",
                "network",
                "identity",
                "monitoring",
                "workload",
                "backup",
            ):
                with self.subTest(provider=provider, check=check):
                    collector, fixture = FreshnessCases().collector(
                        provider, check, "healthy", "2026-10-18T06:00:00Z"
                    )
                    original = fixture.request
                    actual = []

                    def response(method, url, headers, body=None):
                        r = original(method, url, headers, body)
                        actual.append(
                            dict(
                                locator=url,
                                request_sha256=hashlib.sha256(body or b"").hexdigest(),
                                response_sha256=hashlib.sha256(r.body).hexdigest(),
                                http_status=r.status,
                            )
                        )
                        return r

                    with patch.object(fixture, "request", side_effect=response):
                        self.assertTrue(getattr(collector, check)()[0])
                    self.assertEqual(collector.trace, actual)

    def test_nested_context_fields_and_untrusted_native_labels(self):
        import cloud_verification as v

        for field in (
            "request",
            "scope",
            "dependency_lock",
            "policy",
            "verification_profile",
        ):
            for subfield in reducer_case()[4][field]:
                case = reducer_case()
                case[4][field][subfield] = "f" * 64 if subfield == "sha256" else "wrong"
                with (
                    self.subTest(field=field, subfield=subfield),
                    self.assertRaises(ValueError),
                ):
                    v.reduce(*case, now="2026-10-18T06:01:01Z")
        case = reducer_case()
        case[4]["classification"] = "native"
        for item in case[5]:
            payload = json.loads(item["payload_bytes"])
            obs = json.loads(item["observation_bytes"])
            payload["context_sha256"] = v.digest(v.encode(case[4]))
            item["payload_bytes"] = v.encode(payload)
            obs["classification"] = "native"
            obs["result"]["sha256"] = v.digest(item["payload_bytes"])
            item["observation_bytes"] = v.encode(obs)
        with self.assertRaisesRegex(ValueError, "COLLECTOR_PROVENANCE_REQUIRED"):
            v.reduce(*case, now="2026-10-18T06:01:01Z")
        # Explicitly synthetic library trust-boundary control, never public provenance.
        self.assertTrue(
            v.reduce(*case, now="2026-10-18T06:01:01Z", trusted_native=True)[
                "evidence_complete"
            ]
        )

    def test_every_check_lease_expiry_during_native_response(self):
        for provider in ("aws", "azure"):
            for check in (
                "resource",
                "network",
                "identity",
                "monitoring",
                "workload",
                "backup",
            ):
                with self.subTest(provider=provider, check=check):
                    collector, fixture = FreshnessCases().collector(
                        provider, check, "healthy", "2026-10-18T06:00:00Z"
                    )
                    original = fixture.request

                    def response(method, url, headers, body=None):
                        result = original(method, url, headers, body)
                        collector.lease = 1
                        return result

                    with (
                        patch.object(fixture, "request", side_effect=response),
                        self.assertRaisesRegex(ValueError, "READ_CREDENTIAL_EXPIRED"),
                    ):
                        getattr(collector, check)()



class ProtectedProfileCases(unittest.TestCase):
    """T-009 additive dispatch Red at existing callable boundaries."""

    def test_unsupported_profile_version_at_reducer(self):
        import cloud_verification as v

        case = reducer_case()
        req, request_ref, profile, _, context, records = case
        profile.update(id="cloud-compute", version="999")
        req["verification_profile"] = dict(id=profile["id"], version=profile["version"], **ref("profile.json", profile))
        request_ref.update(ref("request.json", req))
        context.update(verification_profile=req["verification_profile"], request=request_ref)
        for item in records:
            payload = json.loads(item["payload_bytes"])
            payload["context_sha256"] = ref("context.json", context)["sha256"]
            item["payload_bytes"] = encode(payload)
            obs = json.loads(item["observation_bytes"])
            obs["result"]["sha256"] = hashlib.sha256(item["payload_bytes"]).hexdigest()
            item["observation_bytes"] = encode(obs)
        with self.assertRaisesRegex(ValueError, "PROFILE_UNSUPPORTED"):
            v.reduce(*case, now="2026-10-18T06:01:01Z")

    def test_legacy_cannot_accept_cloud_discriminator(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "evidence.log").write_text("Synthetic legacy control, not cloud evidence.\n")
            contract = dict(schema="verification-contract/v2", task_id="T-009", profile="cloud", checks=[
                dict(id=cid, required=True, passes=True, evidence="evidence.log")
                for cid in ("lint", "typecheck", "unit-tests", "build", "placeholder-scan", "task-state-check")
            ])
            path = root / "contract.json"
            path.write_text(json.dumps(contract))
            proc = subprocess.run([sys.executable, "-B", str(SHARED / "check-contract.py"), str(path), str(root)], capture_output=True, text=True)
            self.assertNotEqual(proc.returncode, 0, proc.stdout)
            self.assertIn("cloud profile requires verification-contract/v3", proc.stdout)



class ProfileDispatchIntegration(unittest.TestCase):
    """Real public/provider consumers with synthetic API transports; no live proof."""

    def fixture(self, provider):
        harness = PublicObservationCases()
        self.addCleanup(harness.doCleanups)
        case, wire, health, module = harness.setup_execution(provider, protected=True)
        return harness, case, wire, health, module

    def test_both_public_paths_select_real_iac_and_health_without_fake_unit_checks(self):
        import cloud_verification as v

        for provider in ("azure", "aws"):
            with self.subTest(provider=provider):
                harness, case, _, _, module = self.fixture(provider)
                result = harness.run_public(case, module, "protected")
                self.assertEqual(result["result"], "BLOCKED", result)
                output = case.root / (case.directory + "/protected.json")
                plan = json.loads(Path(str(output) + ".selected-plan.json").read_bytes())
                contract_raw = Path(str(output) + ".contract.json").read_bytes()
                self.assertEqual(plan["selection_result"], "PASS")
                self.assertEqual(plan["verdict"], "BLOCKED")
                self.assertEqual({c["id"] for c in plan["checks"]}, set(v.CHECKS) | set(v.PREFLIGHT_IDS))
                self.assertTrue(all(c["required"] is True for c in plan["checks"]))
                self.assertEqual(v.saved_profile_plan(contract_raw, case.root), plan)
                for check in plan["checks"]:
                    c.read_verified(case.root, check["evidence"])
                self.doCleanups()

    def test_native_transport_protocol_double_reaches_positive_existing_boundary(self):
        import cloud_authorization as auth

        for provider in ("azure", "aws"):
            with self.subTest(provider=provider):
                harness, case, _, _, module = self.fixture(provider)
                holder = case.executor.client if provider == "azure" else case.executor.native
                native_type = sys.modules[provider + ("_arm" if provider == "azure" else "_native")].HttpsTransport
                native, admission = native_type(), auth.HttpsTransport()
                old_native, old_admission = holder.transport, case.executor.boundary.transport
                with (patch.object(native, "request", side_effect=old_native.request),
                      patch.object(admission, "request", side_effect=old_admission.request),
                      patch.object(holder, "transport", native),
                      patch.object(case.executor.boundary, "transport", admission)):
                    result = harness.run_public(case, module, "native-protocol-double")
                self.assertEqual(result["result"], "PASS", result)
                output = case.root / (case.directory + "/native-protocol-double.json")
                plan = json.loads(Path(str(output) + ".selected-plan.json").read_bytes())
                self.assertEqual(plan["verdict"], "PASS")
                # The saved-file reader NEVER inherits the in-process trust decision.
                import cloud_verification as v
                saved = v.saved_profile_plan(Path(str(output) + ".contract.json").read_bytes(), case.root)
                self.assertEqual(saved["verdict"], "BLOCKED")
                self.doCleanups()

    def test_preview_and_iac_mismatches_at_public_boundary(self):
        for provider in ("azure", "aws"):
            for variant in ("preview-missing", "preview-binding", "compiled-drift"):
                with self.subTest(provider=provider, variant=variant):
                    harness, case, _, _, module = self.fixture(provider)
                    journal_name = "deployment-submission.json" if provider == "azure" else "execute-submission.json"
                    journal = json.loads((case.root / (case.directory + "/" + journal_name)).read_bytes())
                    if variant == "compiled-drift":
                        artifact = next(a for a in case.req["input_artifacts"] if a["kind"] == "compiled")
                        (case.root / artifact["path"]).write_bytes(b"{}")
                    else:
                        path = case.root / journal["preview"]["path"]
                        if variant == "preview-missing":
                            path.unlink()
                        else:
                            doc = json.loads(path.read_bytes())
                            doc["scope"]["region"] = "other"
                            path.write_bytes(encode(doc))
                    result = harness.run_public(case, module, "negative")
                    self.assertNotEqual(result["result"], "PASS")
                    self.assertFalse((case.root / (case.directory + "/negative.json.selected-plan.json")).exists())
                    self.doCleanups()



class ProfileSavedConsumers(unittest.TestCase):
    def fixture(self):
        helper = ProfileDispatchIntegration()
        self.addCleanup(helper.doCleanups)
        harness, case, _, _, module = helper.fixture("aws")
        result = harness.run_public(case, module, "saved")
        self.assertEqual(result["result"], "BLOCKED")
        path = case.root / (case.directory + "/saved.json.contract.json")
        return case, path, json.loads(path.read_bytes())

    def test_all_direct_consumers_explicit_selection_not_saved_authority(self):
        case, path, contract = self.fixture()
        plan_path = case.root / (case.directory + "/saved.json.selected-plan.json")
        plan = json.loads(plan_path.read_bytes())
        commands = [
            [sys.executable, "-B", str(SHARED / "check-contract.py"), str(path), str(case.root)],
            ["sh", str(SHARED / "check-contract.sh"), str(path), str(case.root)],
        ]
        powershell = shutil.which("pwsh") or shutil.which("powershell")
        if powershell:
            commands.append([powershell, "-NoProfile", "-File", str(SHARED / "check-contract.ps1"), "-ContractPath", str(path), "-RepoRoot", str(case.root)])
        else:
            with self.subTest(consumer="PowerShell"):
                self.skipTest("PowerShell unavailable; native PowerShell consumer coverage not executed")
        for command in commands:
            with self.subTest(consumer=command[0]):
                proc = subprocess.run(command, capture_output=True, text=True, timeout=30)
                self.assertEqual(proc.returncode, 1, proc.stderr)
                self.assertIn("fresh authenticated collection", proc.stdout)
                # Separate operator/value and JSON-property case-negative fixtures.
                for changed in (dict(contract, profile="Cloud"), dict(contract, schema="Verification-contract/v3"),
                                {("Profile" if k == "profile" else k): v for k, v in contract.items()}):
                    path.write_text(json.dumps(changed))
                    denied = subprocess.run(command, capture_output=True, text=True, timeout=30)
                    self.assertNotEqual(denied.returncode, 0, denied.stdout)
                    self.assertNotIn("fresh authenticated collection", denied.stdout)
                path.write_text(json.dumps(contract))
        spec = importlib.util.spec_from_file_location("profile_selected_fixture", ROOT / "tests/sdd-domain-multitarget-T-003.tests.py")
        assert spec and spec.loader
        fixture_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(fixture_module)
        registry, manifest, _ = fixture_module.passing_fixture("iac-cloud")
        manifest["feature"] = contract["feature"]
        for name, value in (("registry.json", registry), ("facet.json", manifest)):
            (case.root / name).write_text(json.dumps(value))
        output = case.root / "specs" / contract["feature"] / "verification" / contract["task_id"] / "selected-plan.json"
        proc = subprocess.run([sys.executable, "-B", str(SHARED / "evaluate-selected-plan.py"),
            "--repo-root", str(case.root), "--registry", str(case.root / "registry.json"),
            "--facet-manifest", str(case.root / "facet.json"), "--contract", str(path),
            "--output", str(output)], capture_output=True, text=True, timeout=30)
        self.assertEqual(proc.returncode, 1, proc.stderr)
        self.assertIn("selected-verification-plan: BLOCKED", proc.stdout)
        self.assertEqual(json.loads(output.read_bytes()), plan)
        self.assertNotIn("unit-tests", {c["id"] for c in plan["checks"]})

    def test_saved_contract_each_field_and_binding_guard(self):
        import cloud_verification as v

        case, _, baseline = self.fixture()
        control = v.saved_profile_plan(encode(baseline), case.root)
        self.assertEqual(control["selection_result"], "PASS")
        self.assertEqual(control["verdict"], "BLOCKED")
        for key in baseline:
            mutated = copy.deepcopy(baseline)
            del mutated[key]
            with self.subTest(missing=key), self.assertRaises(ValueError):
                v.saved_profile_plan(encode(mutated), case.root)
        for key, value in [("schema", "verification-contract/v999"), ("profile", "Cloud"),
                           ("feature", "other"), ("task_id", "T-999"), ("unknown", True)]:
            with self.subTest(field=key), self.assertRaises(ValueError):
                v.saved_profile_plan(encode(dict(baseline, **{key: value})), case.root)
        for key in ("request", "preview", "verification"):
            for field, value in [("path", "../escape"), ("sha256", "0" * 64), ("unknown", "x")]:
                mutated = copy.deepcopy(baseline)
                mutated[key][field] = value
                with self.subTest(ref=key, field=field), self.assertRaises(ValueError):
                    v.saved_profile_plan(encode(mutated), case.root)
        for raw in [encode(baseline).replace(b'"profile": "cloud"', b'"profile": "cloud", "profile": "cloud"'),
                    encode(baseline).replace(b'"profile": "cloud"', b'"profile": NaN')]:
            with self.assertRaises(ValueError):
                v.saved_profile_plan(raw, case.root)
        # Rehash mutated counterpart records: the mismatch body, not the digest gate, must reject.
        for key, fields, message in [
            ("preview", ("run_id", "unit_id", "provider", "scope", "request", "dependency_lock", "policy", "verification_profile"), "PROFILE_PREVIEW_BINDING_MISMATCH"),
            ("verification", ("run_id", "unit_id", "provider", "profile", "required_check_ids"), "PROFILE_VERIFICATION_MISMATCH"),
        ]:
            artifact_path = case.root / baseline[key]["path"]
            original = artifact_path.read_bytes()
            for field in fields:
                document = json.loads(original)
                val = document[field]
                if field == "required_check_ids":
                    document[field] = list(reversed(val))
                elif isinstance(val, dict):
                    document[field] = dict(val)
                    if "id" in val:
                        document[field]["id"] = "other"
                    elif "sha256" in val:
                        document[field] = dict(case.req["dependency_lock"] if field == "policy" else case.req["policy"])
                    else:
                        document[field]["region"] = "other"
                elif field == "provider":
                    document[field] = "azure"
                else:
                    document[field] = "other"
                artifact_path.write_bytes(encode(document))
                mutated = copy.deepcopy(baseline)
                mutated[key]["sha256"] = hashlib.sha256(encode(document)).hexdigest()
                try:
                    with self.subTest(artifact=key, field=field), self.assertRaisesRegex(ValueError, message):
                        v.saved_profile_plan(encode(mutated), case.root)
                finally:
                    artifact_path.write_bytes(original)
        self.assertEqual(v.saved_profile_plan(encode(baseline), case.root), control)

    def test_plan_fields_match_schema_and_recomputed_counterparts(self):
        case, _, baseline = self.fixture()
        import cloud_verification as v

        spec = importlib.util.spec_from_file_location("profile_selected_evaluator", SHARED / "evaluate-selected-plan.py")
        assert spec and spec.loader
        evaluator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(evaluator)
        expected = v.saved_profile_plan(encode(baseline), case.root)
        self.assertEqual(evaluator.validate_plan(expected, expected), [])
        for key in expected:
            mutated = copy.deepcopy(expected)
            del mutated[key]
            with self.subTest(missing=key):
                self.assertTrue(evaluator.validate_plan(mutated, expected))
        for field in expected["bindings"]:
            mutated = copy.deepcopy(expected)
            mutated["bindings"][field] = "0" * 64
            with self.subTest(binding=field):
                self.assertIn("selected-plan-input-mismatch", evaluator.validate_plan(mutated, expected))
        for i, check in enumerate(expected["checks"]):
            for field, val in [("id", "unit-tests"), ("required", False), ("result", "PASS"), ("evidence", dict(path="other.json", sha256="0" * 64))]:
                mutated = copy.deepcopy(expected)
                mutated["checks"][i][field] = val
                with self.subTest(check=check["id"], field=field):
                    self.assertTrue(evaluator.validate_plan(mutated, expected))
            mutated = copy.deepcopy(expected)
            mutated["checks"].pop(i)
            self.assertTrue(evaluator.validate_plan(mutated, expected))
        for field, value in [("schema", "selected-verification-plan/v999"), ("verdict", "PASS"), ("selection_result", "FAIL"), ("profile", "Cloud")]:
            self.assertTrue(evaluator.validate_plan(dict(expected, **{field: value}), expected))

    def test_registry_protection_and_old_schema_mirrors(self):
        import cloud_verification as v

        registry = ROOT / "plugins/sdd-quality-loop/references/cloud-verification-registry.json"
        raw = registry.read_bytes()
        profile: dict = dict(schema="cloud-verification-profile/v1", id="cloud-compute", version="2", required_check_ids=sorted(v.CHECKS), max_age_seconds=300)
        chosen, _ = v.protected_selection(profile, dict(backup_required=True))
        self.assertEqual(set(chosen), set(v.CHECKS) | set(v.PREFLIGHT_IDS))
        for field in ("id", "version", "required_check_ids", "conditional_check_ids", "preflight_check_ids"):
            document = json.loads(raw)
            document["profiles"][0][field] = [] if field.endswith("ids") else ("999" if field == "version" else "unknown")
            with patch.object(Path, "read_bytes", return_value=encode(document)), self.subTest(field=field), self.assertRaisesRegex(ValueError, "PROFILE_REGISTRY_INVALID"):
                v.protected_selection(profile, dict(backup_required=True))
        for cid in v.CHECKS:
            mutated = dict(profile, required_check_ids=[c for c in profile["required_check_ids"] if c != cid])
            with self.subTest(check=cid), self.assertRaisesRegex(ValueError, "PROFILE_CHECK_SET_MISMATCH"):
                v.protected_selection(mutated, dict(backup_required=True))
        guard = json.loads((SHARED.parent / "references/guard-invariants.json").read_bytes())
        self.assertIn(registry.relative_to(ROOT).as_posix(), guard["protected_gate_suffixes"])
        for name in ("selected-verification-plan.schema.json", "selected-verification-plan-v2.schema.json", "verification-contract-v3.schema.json", "cloud-verification-registry.schema.json", "capability-registry.schema.json", "capability-registry.json"):
            self.assertEqual((ROOT / "contracts" / name).read_bytes(), (SHARED.parent / "contracts" / name).read_bytes())

    def test_legacy_import_never_loads_cloud_runtime(self):
        import ast

        script = SHARED / "check-contract.py"
        ast.parse(script.read_text(), feature_version=(3, 6))
        source = "import runpy,sys; runpy.run_path(sys.argv[1],run_name='legacy_import'); assert 'cloud_verification' not in sys.modules; assert 'cloud_contracts' not in sys.modules"
        proc = subprocess.run([sys.executable, "-B", "-c", source, str(script)], capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)



class ProfilePreviewProvenance(unittest.TestCase):
    def test_self_consistent_postapply_preview_substitution_is_not_authenticated(self):
        import cloud_authorization as auth

        for provider in ("aws", "azure"):
            with self.subTest(provider=provider):
                helper = ProfileDispatchIntegration()
                self.addCleanup(helper.doCleanups)
                harness, case, _, _, module = helper.fixture(provider)
                holder = case.executor.client if provider == "azure" else case.executor.native
                native_type = sys.modules[provider + ("_arm" if provider == "azure" else "_native")].HttpsTransport
                native, admission = native_type(), auth.HttpsTransport()
                old_native, old_admission = holder.transport, case.executor.boundary.transport
                journal_path = case.root / (case.directory + "/" + ("deployment-submission.json" if provider == "azure" else "execute-submission.json"))
                journal = json.loads(journal_path.read_bytes())
                preview_path = case.root / journal["preview"]["path"]
                preview = json.loads(preview_path.read_bytes())
                changes_path = case.root / preview["changes"]["path"]
                changes = json.loads(changes_path.read_bytes())
                with (patch.object(native, "request", side_effect=old_native.request),
                      patch.object(admission, "request", side_effect=old_admission.request),
                      patch.object(holder, "transport", native),
                      patch.object(case.executor.boundary, "transport", admission)):
                    control = harness.run_public(case, module, "before-substitution")
                    self.assertEqual(control["result"], "PASS", control)
                    if provider == "aws":
                        changes["changes"][0]["ResourceChange"]["LogicalResourceId"] = "PrivateGroup"
                        changes["changes"][0]["ResourceChange"]["ResourceType"] = "AWS::EC2::SecurityGroup"
                    else:
                        changes["changes"] = []
                    changes_path.write_bytes(encode(changes))
                    preview["changes"]["sha256"] = hashlib.sha256(encode(changes)).hexdigest()
                    preview["semantic_sha256"] = preview["changes"]["sha256"]
                    preview_path.write_bytes(encode(preview))
                    journal["preview"]["sha256"] = hashlib.sha256(encode(preview)).hexdigest()
                    journal_path.write_bytes(encode(journal))
                    if provider == "azure":
                        receipt_path = case.root / (case.directory + "/" + case.req["unit_id"] + ".apply.deploy.authorization.json")
                        receipt = json.loads(receipt_path.read_bytes())
                        receipt["preview"] = journal["preview"]
                        receipt_path.write_bytes(encode(receipt))
                    result = harness.run_public(case, module, "after-substitution")
                self.assertNotEqual(result["result"], "PASS", result)
                if provider == "aws":
                    self.assertEqual(result["error_code"], "PROFILE_PREVIEW_SEMANTICS_MISMATCH")
                else:
                    self.assertEqual(result["error_code"], "ORIGINAL_RUN_MISMATCH")
                self.assertFalse((case.root / (case.directory + "/after-substitution.json.selected-plan.json")).exists())
                self.doCleanups()



class ProfileGuardSensitivity(unittest.TestCase):
    def test_bound_preview_guard_sensitivity_with_valid_rehashed_counterpart(self):
        import cloud_verification as v

        helper = ProfileSavedConsumers()
        self.addCleanup(helper.doCleanups)
        case, _, baseline = helper.fixture()
        preview_path = case.root / baseline["preview"]["path"]
        preview = json.loads(preview_path.read_bytes())
        control = v.saved_profile_plan(encode(baseline), case.root)
        self.assertEqual(control["selection_result"], "PASS")
        preview["unit_id"] = "other-unit"
        preview_path.write_bytes(encode(preview))
        changed = copy.deepcopy(baseline)
        changed["preview"]["sha256"] = hashlib.sha256(encode(preview)).hexdigest()
        with self.assertRaisesRegex(ValueError, "PROFILE_PREVIEW_BINDING_MISMATCH"):
            v.saved_profile_plan(encode(changed), case.root)
        original = c._require

        def bypass_only_preview(condition, reason="INVALID_ARTIFACT"):
            if reason != "PROFILE_PREVIEW_BINDING_MISMATCH":
                original(condition, reason)

        with patch.object(c, "_require", side_effect=bypass_only_preview):
            self.assertEqual(v.saved_profile_plan(encode(changed), case.root)["selection_result"], "PASS")

    def test_profile_allowlist_and_required_check_guard_sensitivity(self):
        import cloud_verification as v

        profile: dict = dict(schema="cloud-verification-profile/v1", id="cloud-compute", version="2", required_check_ids=sorted(v.CHECKS), max_age_seconds=300)
        self.assertEqual(len(v.protected_selection(profile, dict(backup_required=True))[0]), 9)
        original = c._require
        for message, changed in [
            ("PROFILE_UNSUPPORTED", dict(profile, version="999")),
            ("PROFILE_CHECK_SET_MISMATCH", dict(profile, required_check_ids=["resource"])),
        ]:
            with self.subTest(guard=message):
                with self.assertRaisesRegex(ValueError, message):
                    v.protected_selection(changed, dict(backup_required=True))

                def bypass(condition, reason="INVALID_ARTIFACT"):
                    if reason != message:
                        original(condition, reason)

                with patch.object(c, "_require", side_effect=bypass):
                    v.protected_selection(changed, dict(backup_required=True))

    def test_aws_native_preview_guard_is_necessary_not_a_saved_hash_check(self):
        import cloud_authorization as auth
        from contextlib import ExitStack

        helper = ProfileDispatchIntegration()
        self.addCleanup(helper.doCleanups)
        harness, case, _, _, module = helper.fixture("aws")
        holder = case.executor.native
        transport_type = sys.modules["aws_native"].HttpsTransport
        transport, admission = transport_type(), auth.HttpsTransport()
        old_transport, old_admission = holder.transport, case.executor.boundary.transport
        with ExitStack() as stack:
            stack.enter_context(patch.object(transport, "request", side_effect=old_transport.request))
            stack.enter_context(patch.object(admission, "request", side_effect=old_admission.request))
            stack.enter_context(patch.object(holder, "transport", transport))
            stack.enter_context(patch.object(case.executor.boundary, "transport", admission))
            self.assertEqual(harness.run_public(case, module, "control")["result"], "PASS")
            journal_path = case.root / (case.directory + "/execute-submission.json")
            journal = json.loads(journal_path.read_bytes())
            path = case.root / journal["preview"]["path"]
            preview = json.loads(path.read_bytes())
            semantic_path = case.root / preview["changes"]["path"]
            semantic = json.loads(semantic_path.read_bytes())
            semantic["changes"][0]["ResourceChange"]["LogicalResourceId"] = "PrivateGroup"
            semantic["changes"][0]["ResourceChange"]["ResourceType"] = "AWS::EC2::SecurityGroup"
            semantic_path.write_bytes(encode(semantic))
            preview["changes"]["sha256"] = hashlib.sha256(encode(semantic)).hexdigest()
            preview["semantic_sha256"] = preview["changes"]["sha256"]
            path.write_bytes(encode(preview))
            journal["preview"]["sha256"] = hashlib.sha256(encode(preview)).hexdigest()
            journal_path.write_bytes(encode(journal))
            self.assertEqual(harness.run_public(case, module, "denied")["error_code"], "PROFILE_PREVIEW_SEMANTICS_MISMATCH")
            with patch.object(sys.modules["aws_observation"], "profile_preview_readback", return_value=None):
                self.assertEqual(harness.run_public(case, module, "bypassed")["result"], "PASS")



class ProfileCompletionCases(unittest.TestCase):
    def test_protected_mandatory_checks_never_become_optional(self):
        import cloud_authorization as auth
        from contextlib import ExitStack

        for provider in ("aws", "azure"):
            for check in ("resource", "network", "identity", "monitoring", "workload", "backup"):
                for variant in ("unhealthy", "denied"):
                    with self.subTest(provider=provider, check=check, variant=variant):
                        helper = ProfileDispatchIntegration()
                        self.addCleanup(helper.doCleanups)
                        harness, case, _, health, module = helper.fixture(provider)
                        original = health.request
                        hits = []

                        def response(method, url, headers, body=None):
                            target = harness.target(provider, check, url, body)
                            health.variant, health.check = (variant if target else "healthy"), check
                            if target:
                                hits.append(url)
                            return original(method, url, headers, body)

                        holder = case.executor.client if provider == "azure" else case.executor.native
                        transport_type = sys.modules[provider + ("_arm" if provider == "azure" else "_native")].HttpsTransport
                        transport, admission = transport_type(), auth.HttpsTransport()
                        original_transport, original_admission = holder.transport, case.executor.boundary.transport
                        with ExitStack() as stack:
                            stack.enter_context(patch.object(health, "request", side_effect=response))
                            stack.enter_context(patch.object(transport, "request", side_effect=original_transport.request))
                            stack.enter_context(patch.object(admission, "request", side_effect=original_admission.request))
                            stack.enter_context(patch.object(holder, "transport", transport))
                            stack.enter_context(patch.object(case.executor.boundary, "transport", admission))
                            result = harness.run_public(case, module, "mandatory")
                        self.assertTrue(hits)
                        expected = "FAIL" if variant == "unhealthy" else "BLOCKED"
                        self.assertEqual(result["result"], expected, result)
                        plan = json.loads((case.root / (case.directory + "/mandatory.json.selected-plan.json")).read_bytes())
                        observed = next(item for item in plan["checks"] if item["id"] == check)
                        self.assertTrue(observed["required"])
                        self.assertEqual(observed["result"], expected)
                        self.assertEqual(plan["verdict"], "NEEDS_WORK" if variant == "unhealthy" else "BLOCKED")
                        self.doCleanups()

    def test_every_plan_leaf_and_closed_object(self):
        helper = ProfileSavedConsumers()
        self.addCleanup(helper.doCleanups)
        case, _, contract = helper.fixture()
        import cloud_verification as v

        spec = importlib.util.spec_from_file_location("profile_leaf_evaluator", SHARED / "evaluate-selected-plan.py")
        assert spec and spec.loader
        evaluator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(evaluator)
        expected = v.saved_profile_plan(encode(contract), case.root)
        self.assertEqual(evaluator.validate_plan(expected, expected), [])

        def walk(value, path=()):
            if isinstance(value, dict):
                yield path, value
                for k, child in value.items():
                    yield from walk(child, (*path, k))
            elif isinstance(value, list):
                for k, child in enumerate(value):
                    yield from walk(child, (*path, k))
            else:
                yield path, value

        for path, value in walk(expected):
            changed = copy.deepcopy(expected)
            parent = changed
            for key in path[:-1]:
                parent = parent[key]
            if isinstance(value, dict):
                node = changed
                for key in path:
                    node = node[key]
                node["unexpected"] = True
            else:
                parent[path[-1]] = False if value is True else (
                    "PASS" if value == "BLOCKED" else "0" * 64 if path[-1] in ("sha256", "request_sha256", "verification_sha256", "registry_sha256") else
                    "T-999" if path[-1] == "task_id" else "999" if path[-1] == "version" else "other")
            with self.subTest(path=path):
                errors = evaluator.validate_plan(changed, expected)
                self.assertIn("selected-plan-input-mismatch", errors)
                # Schema-valid substitutions become valid ONLY with the changed counterpart.
                # Schema-invalid values remain rejected even with matching expected bytes.
                schema_errors = evaluator.facets.validate_against_schema(changed, evaluator.schema("selected-verification-plan-v2.schema.json"))
                if schema_errors:
                    self.assertTrue(evaluator.validate_plan(changed, changed))
                else:
                    self.assertEqual(evaluator.validate_plan(changed, changed), [])
        self.assertEqual(evaluator.validate_plan(expected, expected), [])

    def test_saved_observation_mismatch_sensitivity(self):
        helper = ProfileSavedConsumers()
        self.addCleanup(helper.doCleanups)
        case, _, baseline = helper.fixture()
        import cloud_verification as v

        self.assertEqual(v.saved_profile_plan(encode(baseline), case.root)["selection_result"], "PASS")
        vp = case.root / baseline["verification"]["path"]
        original_v = vp.read_bytes()
        original_require = c._require
        for field in ("run_id", "unit_id", "provider", "query"):
            verification = json.loads(original_v)
            observation_ref = verification["checks"][0]["observation"]
            op = case.root / observation_ref["path"]
            original_o = op.read_bytes()
            observation = json.loads(original_o)
            observation[field] = "azure" if field == "provider" else "other"
            op.write_bytes(encode(observation))
            observation_ref["sha256"] = hashlib.sha256(encode(observation)).hexdigest()
            vp.write_bytes(encode(verification))
            changed = copy.deepcopy(baseline)
            changed["verification"]["sha256"] = hashlib.sha256(encode(verification)).hexdigest()
            try:
                with self.subTest(field=field), self.assertRaisesRegex(ValueError, "PROFILE_OBSERVATION_MISMATCH"):
                    v.saved_profile_plan(encode(changed), case.root)

                def bypass(condition, reason="INVALID_ARTIFACT"):
                    if reason != "PROFILE_OBSERVATION_MISMATCH":
                        original_require(condition, reason)

                with patch.object(c, "_require", side_effect=bypass):
                    self.assertEqual(v.saved_profile_plan(encode(changed), case.root)["selection_result"], "PASS")
            finally:
                vp.write_bytes(original_v)
                op.write_bytes(original_o)
        self.assertEqual(v.saved_profile_plan(encode(baseline), case.root)["selection_result"], "PASS")

    def test_preview_guard_matrix(self):
        helper = ProfileSavedConsumers()
        self.addCleanup(helper.doCleanups)
        case, _, baseline = helper.fixture()
        import cloud_verification as v

        path = case.root / baseline["preview"]["path"]
        original = path.read_bytes()
        original_require = c._require
        for field, value, reason in [
            ("deletes", ["resource"], "PROFILE_DESTRUCTIVE_PREVIEW"),
            ("replacements", ["resource"], "PROFILE_DESTRUCTIVE_PREVIEW"),
            ("semantic_sha256", "0" * 64, "PROFILE_PREVIEW_DIGEST_MISMATCH"),
        ]:
            changed = dict(json.loads(original), **{field: value})
            path.write_bytes(encode(changed))
            reference = dict(baseline["preview"], sha256=hashlib.sha256(encode(changed)).hexdigest())
            try:
                with self.subTest(field=field), self.assertRaisesRegex(ValueError, reason):
                    v._bound_preview(case.root, case.req, case.request_ref, reference)

                def bypass(condition, message="INVALID_ARTIFACT"):
                    if message != reason:
                        original_require(condition, message)

                with patch.object(c, "_require", side_effect=bypass):
                    self.assertEqual(v._bound_preview(case.root, case.req, case.request_ref, reference), changed)
            finally:
                path.write_bytes(original)
        v._bound_preview(case.root, case.req, case.request_ref, baseline["preview"])

    def test_iac_required_and_preview_window_at_publication(self):
        import cloud_verification as v

        helper = ProfileSavedConsumers()
        self.addCleanup(helper.doCleanups)
        case, _, contract = helper.fixture()
        verification = c.read_artifact(case.root, contract["verification"], "cloud-verification/v1")
        profile = c.read_artifact(case.root, c._file_ref(case.req["verification_profile"]), "cloud-verification-profile/v1")
        policy = c.read_artifact(case.root, case.req["policy"], "cloud-deployment-policy/v1")
        selection = v.protected_selection(profile, policy)
        v._profile_plan(case.req, case.request_ref, verification, contract["verification"], contract["preview"], selection, fresh=False)
        changed = copy.deepcopy(case.req)
        changed["input_artifacts"] = [a for a in changed["input_artifacts"] if a["kind"] != "compiled"]
        with self.assertRaisesRegex(ValueError, "PROFILE_IAC_REQUIRED"):
            v._profile_plan(changed, case.request_ref, verification, contract["verification"], contract["preview"], selection, fresh=False)
        preview_path = case.root / contract["preview"]["path"]
        preview = json.loads(preview_path.read_bytes())
        # Existing serialized creation may equal completion; move completion back to
        # isolate the publication window guard without an earlier readback denial.
        from datetime import datetime
        completed = v.utc(datetime.fromisoformat(preview["created_at"].replace("Z", "+00:00")).timestamp() - 1)
        kwargs = dict(principal="synthetic", native_id=case.executor.native_id, resources=["synthetic"],
                      completed=completed, native=False, publish_json=lambda *args: None,
                      publish_bytes=lambda *args: None, scan=lambda *args: None,
                      recheck=lambda: [], preview_ref=contract["preview"])
        with self.assertRaisesRegex(ValueError, "PROFILE_PREVIEW_WINDOW"):
            v.publish_collection(case.executor, case.directory + "/window.json", "verify", None, **kwargs)
        # Guard-specific bypass proves the call advanced to collection, not a setup failure.
        original = c._require

        def bypass(condition, reason="INVALID_ARTIFACT"):
            if reason != "PROFILE_PREVIEW_WINDOW":
                original(condition, reason)

        with patch.object(c, "_require", side_effect=bypass), patch.object(v, "collect_checks", side_effect=RuntimeError("collection-reached")):
            with self.assertRaisesRegex(RuntimeError, "collection-reached"):
                v.publish_collection(case.executor, case.directory + "/window.json", "verify", None, **kwargs)
        kwargs["completed"] = preview["created_at"]
        with patch.object(v, "collect_checks", side_effect=RuntimeError("collection-reached")):
            with self.assertRaisesRegex(RuntimeError, "collection-reached"):
                v.publish_collection(case.executor, case.directory + "/window.json", "verify", None, **kwargs)

    def test_original_profile_version_and_conditional_backup(self):
        import cloud_verification as v

        for version in ("1", "2"):
            case = reducer_case()
            req, request_ref, profile, policy, context, records = case
            profile.update(id="cloud-compute", version=version)
            req["verification_profile"] = dict(id=profile["id"], version=version, **ref("profile.json", profile))
            request_ref.update(ref("request.json", req))
            context.update(verification_profile=req["verification_profile"], request=request_ref)
            for item in records:
                payload = json.loads(item["payload_bytes"])
                payload["context_sha256"] = ref("context.json", context)["sha256"]
                item["payload_bytes"] = encode(payload)
                obs = json.loads(item["observation_bytes"])
                obs["result"]["sha256"] = hashlib.sha256(item["payload_bytes"]).hexdigest()
                item["observation_bytes"] = encode(obs)
            with self.subTest(version=version):
                self.assertEqual(v.reduce(*case, now="2026-10-18T06:01:01Z")["overall_result"], "PASS")
        profile["required_check_ids"].remove("backup")
        self.assertNotIn("backup", v.protected_selection(profile, dict(backup_required=False))[0])
        with self.assertRaisesRegex(ValueError, "PROFILE_CHECK_SET_MISMATCH"):
            v.protected_selection(profile, dict(backup_required=True))


class ProfileAwsReadbackCases(unittest.TestCase):
    def test_executed_preview_requires_actual_asset_readback(self):
        helper = ProfileDispatchIntegration()
        self.addCleanup(helper.doCleanups)
        harness, case, _, _, module = helper.fixture("aws")
        self.assertEqual(harness.run_public(case, module, "asset-control")["result"], "BLOCKED")
        observation = sys.modules["aws_observation"]
        executor = case.executor
        journal = json.loads((case.root / (case.directory + "/execute-submission.json")).read_bytes())
        observation.profile_preview_readback(executor, journal["preview"])
        original = case.native.native.object_bytes
        # Keep native template readback matched: only S3 object bytes disagree.
        case.native.native.template_override = original
        case.native.native.object_bytes = b"substituted asset"
        try:
            with self.assertRaisesRegex(ValueError, "S3_SUBSTITUTION"):
                observation.profile_preview_readback(executor, journal["preview"])
            with patch.object(executor.native, "read_object", return_value=None):
                observation.profile_preview_readback(executor, journal["preview"])
        finally:
            case.native.native.object_bytes = original
            case.native.native.template_override = None
        observation.profile_preview_readback(executor, journal["preview"])

    def test_semantic_native_and_policy_guards(self):
        helper = ProfileDispatchIntegration()
        self.addCleanup(helper.doCleanups)
        harness, case, _, _, module = helper.fixture("aws")
        result = harness.run_public(case, module, "readback-control")
        self.assertEqual(result["result"], "BLOCKED")  # synthetic transport, not live
        observation = sys.modules["aws_observation"]
        executor = case.executor
        journal = json.loads((case.root / (case.directory + "/execute-submission.json")).read_bytes())
        preview_ref = journal["preview"]
        preview_path = case.root / preview_ref["path"]
        preview_raw = preview_path.read_bytes()
        preview = json.loads(preview_raw)
        semantic_path = case.root / preview["changes"]["path"]
        semantic_raw = semantic_path.read_bytes()
        semantic = json.loads(semantic_raw)
        native = executor.describe()
        template = executor.read("GetTemplate", dict(StackName=executor.stack_id, ChangeSetName=executor.native_id, TemplateStage="Original"))
        original_read, original_require = executor.read, observation.c._require
        observation.profile_preview_readback(executor, preview_ref)
        variants: list[tuple[str, dict, dict, dict, str | None]] = []
        for field in ("request", "scope", "template_sha256", "change_set_arn", "stack_id", "no_change", "create"):
            changed = copy.deepcopy(semantic)
            if field == "request":
                changed[field]["sha256"] = "0" * 64
            elif field == "scope":
                changed[field]["region"] = "other"
            elif field == "create":
                changed[field]["Description"] = "other"
            else:
                changed[field] = True if field == "no_change" else "0" * 64 if field == "template_sha256" else "other"
            variants.append(("semantic." + field, changed, native, template, "PROFILE_PREVIEW_NATIVE_BINDING"))
        for field in ("ChangeSetId", "StackId", "ChangeSetName", "StackName", "Description", "Capabilities", "Parameters", "Status", "ExecutionStatus", "Tags"):
            changed = copy.deepcopy(native)
            changed[field] = [] if isinstance(changed[field], list) else "other"
            if changed[field] == native[field]:
                changed[field] = [{"Key": "other", "Value": "other"}]
            variants.append(("native." + field, semantic, changed, template, "PROFILE_PREVIEW_NATIVE_BINDING"))
        variants.append(("template", semantic, native, dict(TemplateBody="{}"), "PROFILE_PREVIEW_NATIVE_BINDING"))
        for field in ("IncludeNestedStacks", "ImportExistingResources", "ParentChangeSetId", "RootChangeSetId", "OnStackFailure", "NotificationARNs", "DeploymentConfig", "RollbackConfiguration", "DeploymentMode"):
            changed = copy.deepcopy(native)
            changed[field] = {"RollbackTriggers": ["other"]} if field == "RollbackConfiguration" else "other"
            variants.append(("native." + field, semantic, changed, template, "PROFILE_PREVIEW_NATIVE_BINDING"))
        changed = copy.deepcopy(native)
        changed["Changes"] = []
        variants.append(("native.Changes", semantic, changed, template, "PROFILE_PREVIEW_SEMANTICS_MISMATCH"))
        # Match local/native changes to reach each policy predicate rather than hash/semantic guards.
        for field, value in (("Action", "Remove"), ("Replacement", "True"), ("LogicalResourceId", "Unknown"),
                             ("ResourceType", "AWS::Unknown::Type"), ("ChangeSetId", "nested"), ("ModuleInfo", {"x": 1}),
                             ("PolicyAction", "Delete")):
            changed_s, changed_n = copy.deepcopy(semantic), copy.deepcopy(native)
            changed_s["changes"][0]["ResourceChange"][field] = value
            changed_n["Changes"] = changed_s["changes"]
            variants.append(("policy." + field, changed_s, changed_n, template, "PROFILE_PREVIEW_POLICY_DENIED"))
        # Exercise Modify's static/non-recreating property branch with its own matched control.
        modify = copy.deepcopy(semantic)
        change = modify["changes"][0]["ResourceChange"]
        change.update(Action="Modify", Scope=["Properties"], Details=[dict(
            Evaluation="Static", ChangeSource="DirectModification",
            Target=dict(Attribute="Properties", RequiresRecreation="Never"))])
        matched_modify = copy.deepcopy(native)
        matched_modify["Changes"] = modify["changes"]
        variants.append(("modify.control", modify, matched_modify, template, None))
        for field in ("Details", "Scope", "Evaluation", "ChangeSource", "Attribute", "RequiresRecreation"):
            changed_s, changed_n = copy.deepcopy(modify), copy.deepcopy(native)
            change = changed_s["changes"][0]["ResourceChange"]
            if field in ("Details", "Scope"):
                change[field] = []
            elif field in ("Attribute", "RequiresRecreation"):
                change["Details"][0]["Target"][field] = "other"
            else:
                change["Details"][0][field] = "other"
            changed_n["Changes"] = changed_s["changes"]
            variants.append(("modify." + field, changed_s, changed_n, template, "PROFILE_PREVIEW_POLICY_DENIED"))
        for label, changed_s, changed_n, changed_t, reason in variants:
            with self.subTest(field=label):
                semantic_path.write_bytes(encode(changed_s))
                changed_p = copy.deepcopy(preview)
                changed_p["changes"]["sha256"] = hashlib.sha256(encode(changed_s)).hexdigest()
                changed_p["semantic_sha256"] = changed_p["changes"]["sha256"]
                preview_path.write_bytes(encode(changed_p))
                changed_ref = dict(preview_ref, sha256=hashlib.sha256(encode(changed_p)).hexdigest())

                def read(action, params):
                    return changed_t if action == "GetTemplate" else original_read(action, params)

                def bypass(condition, message="INVALID_ARTIFACT"):
                    if message != reason:
                        original_require(condition, message)

                try:
                    with patch.object(executor, "describe", return_value=changed_n), patch.object(executor, "read", side_effect=read):
                        if reason is None:
                            observation.profile_preview_readback(executor, changed_ref)
                            continue
                        with self.assertRaisesRegex(ValueError, reason):
                            observation.profile_preview_readback(executor, changed_ref)
                        with patch.object(observation.c, "_require", side_effect=bypass):
                            observation.profile_preview_readback(executor, changed_ref)
                finally:
                    semantic_path.write_bytes(semantic_raw)
                    preview_path.write_bytes(preview_raw)
        observation.profile_preview_readback(executor, preview_ref)

class DependencyReceiptCases(unittest.TestCase):
    """T-010: actual collector output + authenticated-protocol doubles, never live."""

    def fixture(self, provider="azure", stage="prepare", consumer_provider=None):
        import base64
        from contextlib import ExitStack
        from types import SimpleNamespace
        import cloud_authorization as auth

        stack = ExitStack()
        self.addCleanup(stack.close)
        harness = PublicObservationCases()
        self.addCleanup(harness.doCleanups)
        producer, _, _, module = harness.setup_execution(provider, protected=True)
        holder = (
            producer.executor.client
            if provider == "azure"
            else producer.executor.native
        )
        native_type = sys.modules[
            provider + ("_arm" if provider == "azure" else "_native")
        ].HttpsTransport
        native, admission = native_type(), auth.HttpsTransport()
        stack.enter_context(
            patch.object(native, "request", side_effect=holder.transport.request)
        )
        stack.enter_context(
            patch.object(
                admission,
                "request",
                side_effect=producer.executor.boundary.transport.request,
            )
        )
        stack.enter_context(patch.object(holder, "transport", native))
        stack.enter_context(
            patch.object(producer.executor.boundary, "transport", admission)
        )
        result = harness.run_public(producer, module, "verify-result")
        self.assertEqual(result["result"], "PASS", result)
        output = producer.directory + "/verify-result.json"
        receipt_path = output + ".verification.json"
        receipt_raw = (producer.root / receipt_path).read_bytes()
        receipt = json.loads(receipt_raw)
        contract = json.loads(
            (producer.root / (output + ".contract.json")).read_bytes()
        )
        spec = importlib.util.spec_from_file_location(
            "dependency_execution",
            ROOT / "tests/cloud-orchestration-execution.tests.py",
        )
        assert spec and spec.loader
        execution = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(execution)
        target = execution.Admission()
        target.setUp()
        self.addCleanup(target.doCleanups)
        target.setup_case(consumer_provider or provider, stage)
        consumer_profile = target.request["verification_profile"]
        consumer_profile["path"] = target.put(
            "bundle/consumer-profile.json",
            (target.root / consumer_profile["path"]).read_bytes(),
        )["path"]
        target.put(
            receipt["profile"]["path"],
            (producer.root / receipt["profile"]["path"]).read_bytes(),
        )
        # Same feature is required by the existing path contract; unit/run remain distinct.
        for path in (producer.root / producer.directory).rglob("*"):
            if path.is_file():
                target.put(str(path.relative_to(producer.root)), path.read_bytes())
        ref = target.put(receipt_path, receipt_raw)
        target.request["predecessor_receipts"] = [
            dict(unit_id=receipt["unit_id"], **ref)
        ]
        target.request_ref = target.put("request.json", target.request)
        if stage == "apply":
            preview = json.loads(
                (target.root / target.preview_ref["path"]).read_bytes()
            )
            preview["request"] = target.request_ref
            preview["verification_profile"] = {
                k: consumer_profile[k] for k in ("path", "sha256")
            }
            target.preview_ref = target.put(target.preview_ref["path"], preview)
        target.transport.run["display_title"] = (
            "cloud:"
            + target.request_ref["sha256"]
            + ":"
            + (target.preview_ref["sha256"] if target.preview_ref else "none")
        )
        # Consumer lease and producer completion are both fresh at this synthetic time.
        now = int(producer.executor.clock()) + 5
        target.boundary.clock = lambda: now
        target.transport.claims.update(iat=now - 10, nbf=now - 10, exp=now + 600)
        target.transport.lease_end = now + 300
        target.transport.azure_claims.update(iat=now - 10, nbf=now - 10, exp=now + 300)
        governed = __import__(provider + "_governed")
        kwargs = dict(
            executor_repository="synthetic/executor",
            executor_revision="d" * 40,
            input_repository="synthetic/plans",
            region=producer.executor.request["scope"]["region"],
        )
        kwargs["subscription" if provider == "azure" else "account"] = (
            producer.executor.request["scope"]["account_id"]
        )
        workflow = governed.workflow_template(**kwargs)
        if "verify" not in workflow["jobs"]:
            # Test-first desired fixed verify job, not an existing shipped workflow claim.
            job = copy.deepcopy(workflow["jobs"]["apply"])
            job.update(
                environment="sandbox-verify",
                **{
                    "if": "${{ github.run_attempt == 1 && inputs.operation == 'verify' }}"
                },
            )
            step = job["steps"][1]
            step["name"] = "Execute fixed read-only verify"
            step["env"].pop("CLOUD_PHASE")
            step["env"]["AWS_CONTROL_POLICY"] = "${{ vars.AWS_VERIFY_POLICY }}"
            step["run"] = (
                'set -euo pipefail\npython3 -I executor/plugins/sdd-aws-cloud/scripts/aws_governed.py verify --workspace "$RUNNER_TEMP/aws-data"'
            )
            job["steps"][2]["with"]["name"] = "aws-verify-${{ github.run_id }}"
            workflow["jobs"]["verify"] = job
            workflow["on"]["workflow_dispatch"]["inputs"]["operation"][
                "options"
            ].append("verify")
        pin = dict(
            unit_id=receipt["unit_id"],
            run_id=receipt["run_id"],
            provider=provider,
            request=producer.request_ref.copy(),
            verification=ref,
            scope=copy.deepcopy(producer.executor.request["scope"]),
            profile=copy.deepcopy(receipt["profile"]),
            repository="synthetic/producer",
            repository_id=77,
            workflow=".github/workflows/cloud.yml",
            workflow_revision="a" * 40,
            ref="refs/heads/main",
            workflow_sha256=hashlib.sha256(encode(workflow)).hexdigest(),
            executor_repository="synthetic/executor",
            executor_revision="d" * 40,
            producer_run_id=789,
            artifact_id=17,
            environment_id=88,
            actors=[[7, "operator"]],
            reviewers=[[8, "reviewer"]],
        )
        object.__setattr__(target.policy, "predecessor_trust", (pin,))
        object.__setattr__(
            target.policy, "dependency_request_sha256", target.request_ref["sha256"]
        )
        run = dict(
            id=789,
            run_attempt=1,
            status="completed",
            conclusion="success",
            event="workflow_dispatch",
            head_sha=pin["workflow_revision"],
            head_branch="main",
            path=pin["workflow"],
            display_title="cloud:"
            + pin["request"]["sha256"]
            + ":"
            + contract["preview"]["sha256"],
            repository=dict(id=77, full_name=pin["repository"]),
            head_repository=dict(id=77, full_name=pin["repository"]),
            actor=dict(id=7, login="operator"),
            triggering_actor=dict(id=7, login="operator"),
        )
        steps = [
            dict(
                name=s["name"],
                status="completed",
                conclusion="success",
                started_at=auth.utc(now - 5),
                completed_at=auth.utc(now - 3),
            )
            for s in workflow["jobs"]["verify"]["steps"]
        ]
        job = dict(
            id=456,
            run_id=789,
            run_attempt=1,
            head_sha=pin["workflow_revision"],
            name="verify",
            status="completed",
            conclusion="success",
            started_at=auth.utc(now - 6),
            completed_at=auth.utc(now - 2),
            steps=steps,
        )
        state = SimpleNamespace(
            target=target,
            producer=producer,
            pin=pin,
            run=run,
            job=job,
            workflow=workflow,
            output=output,
            receipt=receipt,
            ref=ref,
            now=now,
            contract=contract,
            artifact_calls=[],
            api_calls=[],
            archive_override=None,
            metadata=dict(
                id=17,
                expired=False,
                name=provider + "-verify-789",
                workflow_run=dict(
                    id=789,
                    head_sha=pin["workflow_revision"],
                    repository_id=77,
                    head_repository_id=77,
                ),
            ),
        )
        state.jobs = dict(total_count=1, jobs=[job])
        state.file = dict(
            type="file",
            path=pin["workflow"],
            encoding="base64",
            content=base64.b64encode(encode(workflow)).decode(),
        )
        state.environment = dict(
            target.transport.environment_response, id=88, name="sandbox-verify"
        )
        state.approvals = [
            dict(
                state="approved",
                user=dict(id=8, login="reviewer"),
                environments=[dict(id=88, name="sandbox-verify")],
            )
        ]
        old = target.transport.request

        def metadata(method, url, headers, body=None):
            if "/repos/synthetic/" not in url or "/repos/synthetic/control/" in url:
                return old(method, url, headers, body)
            state.api_calls.append(url)
            self.assertEqual(headers["Authorization"], "Bearer synthetic-github-bearer")
            if "/contents/" in url:
                return encode(
                    dict(
                        state.file, content=base64.b64encode(encode(workflow)).decode()
                    )
                    if state.file["content"] == "dynamic"
                    else state.file
                )
            if "/jobs?" in url:
                return encode(state.jobs)
            if url.endswith("/approvals"):
                return encode(state.approvals)
            if "/environments/" in url:
                return encode(state.environment)
            return encode(run)

        stack.enter_context(
            patch.object(target.transport, "request", side_effect=metadata)
        )

        def artifact(method, url, headers, body=None):
            from types import SimpleNamespace
            import io
            import zipfile

            state.artifact_calls.append((url, headers.copy()))
            buffer = io.BytesIO()
            with zipfile.ZipFile(buffer, "w") as archive:
                for path in sorted(producer.root.rglob("*")):
                    if path.is_file():
                        archive.writestr(
                            str(path.relative_to(producer.root)), path.read_bytes()
                        )
            raw = (
                buffer.getvalue()
                if state.archive_override is None
                else state.archive_override
            )
            if "/actions/artifacts/" in url and not url.endswith("/zip"):
                state.download_bytes = raw
            else:
                raw = state.download_bytes
            meta = {
                "digest": "sha256:" + hashlib.sha256(raw).hexdigest(),
                **state.metadata,
            }
            if "/actions/artifacts/" in url and not url.endswith("/zip"):
                return SimpleNamespace(status=200, headers={}, body=encode(meta))
            if url.endswith("/zip"):
                return SimpleNamespace(
                    status=302,
                    headers={
                        "Location": "https://synthetic.blob.core.windows.net/artifact"
                    },
                    body=b"",
                )
            self.assertEqual(headers, {})
            return SimpleNamespace(status=200, headers={}, body=raw)

        # Before implementation the existing callable must execute, not fail at import/setup.
        if importlib.util.find_spec("cloud_dependencies"):
            import cloud_dependencies as dependencies

            stack.enter_context(
                patch.object(
                    dependencies.ArtifactHttps, "request", side_effect=artifact
                )
            )
        return state

    def failure(self, state, expected):
        seen = []
        original = state.target.a.contracts._require

        def require(condition, code="INVALID_ARTIFACT"):
            if not condition:
                seen.append(code)
            original(condition, code)

        original_auth = state.target.a.require

        def auth_require(condition, code="ADMISSION_DENIED"):
            if not condition:
                seen.append(code)
            original_auth(condition, code)

        from contextlib import ExitStack

        with ExitStack() as stack:
            for module in {c, state.target.a.contracts, sys.modules["cloud_contracts"]}:
                stack.enter_context(
                    patch.object(module, "_require", side_effect=require)
                )
                original_read = module.read_verified

                def read(*args, _read=original_read, **kwargs):
                    try:
                        return _read(*args, **kwargs)
                    except ValueError as exc:
                        seen.append(str(exc))
                        raise

                stack.enter_context(
                    patch.object(module, "read_verified", side_effect=read)
                )
            stack.enter_context(
                patch.object(state.target.a, "require", side_effect=auth_require)
            )
            with self.assertRaises(state.target.a.AdmissionDenied):
                state.target.write()
        self.assertEqual(state.target.writes, [])
        self.assertIn(
            expected,
            seen,
            "Mismatch reached existing boundary; blanket denial is not this field guard",
        )

    def test_dependency_matched_control_at_both_shared_stages(self):
        for provider in ("azure", "aws"):
            for stage in ("prepare", "apply"):
                with self.subTest(provider=provider, stage=stage):
                    state = self.fixture(provider, stage)
                    state.target.write()
                    self.assertEqual(state.target.writes, ["write"])
                    self.assertGreaterEqual(len(state.artifact_calls), 6)
                    self.doCleanups()

    def test_dependency_per_field_red_mismatches(self):
        variants = {
            "run_id": ("wrong-run", "DEPENDENCY_REQUEST_BINDING"),
            "unit_id": ("wrong-unit", "DEPENDENCY_SET_MISMATCH"),
            "provider": ("aws", "DEPENDENCY_REQUEST_BINDING"),
            "scope": (
                dict(account_id="wrong", region="wrong", deployment_scope="wrong"),
                "DEPENDENCY_REQUEST_BINDING",
            ),
            "profile": (
                dict(
                    id="cloud-compute",
                    version="999",
                    path="bundle/profile.json",
                    sha256="b" * 64,
                ),
                "DEPENDENCY_REQUEST_BINDING",
            ),
            "workflow_sha256": ("b" * 64, "DEPENDENCY_WORKFLOW_MISMATCH"),
            "executor_revision": ("b" * 40, "DEPENDENCY_EXECUTOR_MISMATCH"),
            "producer_run_id": (790, "ARTIFACT_IDENTITY_CHANGED"),
            "repository_id": (78, "DEPENDENCY_RUN_MISMATCH"),
            "environment_id": (89, "DEPENDENCY_ENVIRONMENT_MISMATCH"),
        }
        for field, (value, guard) in variants.items():
            with self.subTest(field=field):
                state = self.fixture()
                state.pin[field] = value
                self.failure(state, guard)
                self.doCleanups()

    def test_dependency_producer_and_evidence_red_mismatches(self):
        variants = [
            "job",
            "run",
            "artifact",
            "classification",
            "context",
            "observation",
            "payload",
            "verification",
            "plan",
            "operation",
            "stale",
        ]
        for variant in variants:
            with self.subTest(field=variant):
                state = self.fixture()
                guard = "DEPENDENCY_PRODUCER_OUTPUT_MISMATCH"
                if variant == "job":
                    state.job["conclusion"] = "failure"
                    guard = "DEPENDENCY_VERIFY_JOB_REQUIRED"
                elif variant == "run":
                    state.run["conclusion"] = "failure"
                    guard = "DEPENDENCY_RUN_MISMATCH"
                elif variant == "artifact":
                    state.metadata["expired"] = True
                    guard = "ARTIFACT_IDENTITY_CHANGED"
                elif variant == "stale":
                    state.target.boundary.clock = lambda: state.now + 10000
                    guard = "DEPENDENCY_NOT_VERIFIED"
                else:
                    suffix = {
                        "classification": ".manifest.json",
                        "context": ".context.json",
                        "observation": ".manifest.json",
                        "payload": ".manifest.json",
                        "verification": ".verification.json",
                        "plan": ".selected-plan.json",
                        "operation": "",
                    }[variant]
                    path = state.producer.root / (state.output + suffix)
                    value = json.loads(path.read_bytes())
                    if variant == "classification":
                        value["classification"] = "synthetic"
                    elif variant == "context":
                        value["principal"] = "wrong-principal"
                    elif variant in ("observation", "payload"):
                        row = value["observations"][0]
                        ref = row[
                            "observation" if variant == "observation" else "result"
                        ]
                        path = state.producer.root / ref["path"]
                        value = json.loads(path.read_bytes())
                        value[
                            "principal"
                            if variant == "observation"
                            else "context_sha256"
                        ] = "wrong" if variant == "observation" else "b" * 64
                    elif variant == "verification":
                        value["evidence_complete"] = False
                    elif variant == "plan":
                        value["verdict"] = "BLOCKED"
                    else:
                        value.update(
                            result="BLOCKED",
                            state="BLOCKED",
                            error_code="EVIDENCE_INCOMPLETE",
                        )
                    path.write_bytes(encode(value))
                    if variant in ("context", "observation", "payload", "verification"):
                        guard = "DIGEST_MISMATCH"
                self.failure(state, guard)
                self.doCleanups()


def dependency_field_matrix():
    """Every new protected configuration / authenticated producer binding leaf."""
    rows: list[tuple[str, str, list[str], object, str]] = []

    def add(target, values, guard):
        rows.extend(
            (target + "." + path, target, path.split("."), value, guard)
            for path, value in values.items()
        )

    add(
        "pin",
        {
            "unit_id": "other",
            "verification.path": "other.json",
            "verification.sha256": "b" * 64,
        },
        "DEPENDENCY_SET_MISMATCH",
    )
    add(
        "pin",
        {
            "run_id": "other",
            "provider": "aws",
            "scope.account_id": "other",
            "scope.region": "westus",
            "scope.deployment_scope": "other",
            "profile.id": "other",
            "profile.version": "9",
            "profile.path": "other.json",
            "profile.sha256": "b" * 64,
        },
        "DEPENDENCY_REQUEST_BINDING",
    )
    add("pin", {"request.path": "other.json"}, "UNSAFE_OR_UNAVAILABLE_FILE")
    add("pin", {"request.sha256": "b" * 64}, "DIGEST_MISMATCH")
    add(
        "pin",
        {
            "repository": "synthetic/other",
            "repository_id": 78,
            "workflow": ".github/workflows/other.yml",
            "workflow_revision": "b" * 40,
            "ref": "refs/heads/other",
            "producer_run_id": 790,
            "actors.0.0": 9,
            "actors.0.1": "other",
        },
        "DEPENDENCY_RUN_MISMATCH",
    )
    add("pin", {"workflow_sha256": "b" * 64}, "DEPENDENCY_WORKFLOW_MISMATCH")
    add(
        "pin",
        {"executor_repository": "synthetic/other", "executor_revision": "b" * 40},
        "DEPENDENCY_EXECUTOR_MISMATCH",
    )
    add("pin", {"artifact_id": 18}, "ARTIFACT_IDENTITY_CHANGED")
    add(
        "pin",
        {"environment_id": 89, "reviewers.0.0": 9, "reviewers.0.1": "other"},
        "DEPENDENCY_ENVIRONMENT_MISMATCH",
    )
    add(
        "run",
        {
            "id": 790,
            "run_attempt": 2,
            "status": "in_progress",
            "conclusion": "failure",
            "event": "push",
            "head_sha": "b" * 40,
            "head_branch": "other",
            "path": ".github/workflows/other.yml",
            "display_title": "cloud:" + "b" * 64 + ":" + "c" * 64,
            "repository.id": 78,
            "repository.full_name": "synthetic/other",
            "head_repository.id": 78,
            "head_repository.full_name": "synthetic/other",
            "actor.id": 9,
            "actor.login": "other",
            "triggering_actor.id": 9,
            "triggering_actor.login": "other",
        },
        "DEPENDENCY_RUN_MISMATCH",
    )
    add(
        "file",
        {
            "type": "dir",
            "path": ".github/workflows/other.yml",
            "encoding": "none",
            "content": "e30K",
        },
        "DEPENDENCY_WORKFLOW_MISMATCH",
    )
    add(
        "job",
        {
            "id": 0,
            "name": "apply",
            "run_id": 790,
            "run_attempt": 2,
            "head_sha": "b" * 40,
            "status": "in_progress",
            "conclusion": "failure",
        },
        "DEPENDENCY_VERIFY_JOB_REQUIRED",
    )
    add("jobs", {"total_count": 2}, "PAGINATION_INCOMPLETE")
    add(
        "job",
        {"started_at": "2026-10-18T07:00:00Z", "completed_at": "2026-10-18T05:00:00Z"},
        "DEPENDENCY_COMPLETION_WINDOW",
    )
    for index in range(3):
        add(
            "job",
            {
                f"steps.{index}.name": "other",
                f"steps.{index}.status": "in_progress",
                f"steps.{index}.conclusion": "failure",
            },
            "DEPENDENCY_VERIFY_STEP_REQUIRED",
        )
        add(
            "job",
            {
                f"steps.{index}.started_at": "2026-10-18T07:00:00Z",
                f"steps.{index}.completed_at": "2026-10-18T05:00:00Z",
            },
            "DEPENDENCY_COMPLETION_WINDOW",
        )
    add(
        "environment",
        {
            "id": 89,
            "name": "other-verify",
            "can_admins_bypass": True,
            "deployment_branch_policy.protected_branches": False,
            "deployment_branch_policy.custom_branch_policies": True,
            "protection_rules.0.type": "wait_timer",
            "protection_rules.0.prevent_self_review": False,
            "protection_rules.0.reviewers.0.type": "Team",
            "protection_rules.0.reviewers.0.reviewer.id": 9,
            "protection_rules.0.reviewers.0.reviewer.login": "other",
        },
        "DEPENDENCY_ENVIRONMENT_MISMATCH",
    )
    add(
        "approvals",
        {
            "0.state": "rejected",
            "0.user.id": 9,
            "0.user.login": "other",
            "0.environments.0.id": 89,
            "0.environments.0.name": "other-verify",
        },
        "DEPENDENCY_APPROVAL_MISMATCH",
    )
    add(
        "metadata",
        {"id": 18, "expired": True, "workflow_run.id": 790},
        "ARTIFACT_IDENTITY_CHANGED",
    )
    add("metadata", {"digest": None}, "ARTIFACT_DIGEST_REQUIRED")
    add("metadata", {"digest": "sha256:" + "b" * 64}, "ARTIFACT_DIGEST_MISMATCH")
    add(
        "metadata",
        {
            "name": "azure-apply-789",
            "workflow_run.head_sha": "b" * 40,
            "workflow_run.repository_id": 78,
            "workflow_run.head_repository_id": 78,
        },
        "DEPENDENCY_ARTIFACT_PRODUCER_MISMATCH",
    )
    rows = [
        (
            label,
            target,
            path,
            value,
            "ARTIFACT_IDENTITY_CHANGED" if label == "pin.producer_run_id" else guard,
        )
        for label, target, path, value, guard in rows
    ]
    return rows


class DependencyFieldMatrix(DependencyReceiptCases):
    def test_every_new_trust_and_producer_binding(self):
        for label, target, path, value, guard in dependency_field_matrix():
            with self.subTest(field=label):
                state = self.fixture()
                obj = getattr(state, target)
                for part in path[:-1]:
                    obj = obj[int(part) if isinstance(obj, list) else part]
                key = int(path[-1]) if isinstance(obj, list) else path[-1]
                original_value = (
                    copy.deepcopy(obj[key])
                    if key in obj or isinstance(obj, list)
                    else None
                )
                existed = isinstance(obj, list) or key in obj
                obj[key] = value
                self.failure(state, guard)
                if existed:
                    obj[key] = original_value
                else:
                    del obj[key]
                state.target.write()
                self.assertEqual(state.target.writes, ["write"])
                self.doCleanups()

    def test_consumer_request_and_trust_set(self):
        for variant in (
            "request-sha",
            "trust-omitted",
            "trust-added",
            "receipt-omitted",
            "receipt-added",
        ):
            with self.subTest(field=variant):
                state = self.fixture()
                guard = "DEPENDENCY_SET_MISMATCH"
                if variant == "request-sha":
                    object.__setattr__(
                        state.target.policy, "dependency_request_sha256", "b" * 64
                    )
                    guard = "DEPENDENCY_CONSUMER_MISMATCH"
                elif variant == "trust-omitted":
                    object.__setattr__(state.target.policy, "predecessor_trust", ())
                elif variant == "trust-added":
                    other = copy.deepcopy(state.pin)
                    other["unit_id"] = "other"
                    object.__setattr__(
                        state.target.policy, "predecessor_trust", (state.pin, other)
                    )
                else:
                    if variant == "receipt-omitted":
                        state.target.request["predecessor_receipts"] = []
                    else:
                        # New valid-format independent receipt, not a duplicate/schema error.
                        other = copy.deepcopy(state.receipt)
                        other["unit_id"] = "other"
                        path = state.ref["path"].replace(
                            "/" + state.receipt["unit_id"] + "/", "/other/"
                        )
                        ref = state.target.put(path, other)
                        state.target.request["predecessor_receipts"].append(
                            dict(unit_id="other", **ref)
                        )
                    state.target.request_ref = state.target.put(
                        "request.json", state.target.request
                    )
                    state.target.transport.run["display_title"] = (
                        "cloud:" + state.target.request_ref["sha256"] + ":none"
                    )
                    guard = "DEPENDENCY_CONSUMER_MISMATCH"
                self.failure(state, guard)
                self.doCleanups()


class DependencyGraphCases(unittest.TestCase):
    def graph(self):
        values = []
        for unit in ("C", "B", "A"):
            value = request("aws")
            value["unit_id"] = unit
            if unit == "C":
                value["predecessor_receipts"] = [
                    dict(unit_id="B", path="b.json", sha256="a" * 64)
                ]
            values.append(value)
        return values

    def test_order_and_each_invalid_graph_before_callbacks(self):
        # Component-absence Red is recorded separately from executed boundary mismatches.
        self.assertTrue(
            (SHARED / "cloud_dependencies.py").is_file(), "Ordering component absent"
        )
        import cloud_dependencies as d

        values = self.graph()
        self.assertEqual(
            [r["unit_id"] for r in d.ordered_units(values)], ["A", "B", "C"]
        )
        for variant in ("cycle", "self", "duplicate-unit", "duplicate-edge", "missing"):
            with self.subTest(variant=variant):
                changed = copy.deepcopy(values)

                def edge(unit):
                    return dict(unit_id=unit, path="b.json", sha256="a" * 64)

                if variant == "cycle":
                    changed[1]["predecessor_receipts"] = [edge("C")]
                elif variant == "self":
                    changed[1]["predecessor_receipts"] = [edge("B")]
                elif variant == "duplicate-unit":
                    changed.append(copy.deepcopy(changed[1]))
                elif variant == "duplicate-edge":
                    changed[0]["predecessor_receipts"] *= 2
                else:
                    changed[0]["predecessor_receipts"] = [edge("absent")]
                with self.assertRaises(ValueError):
                    d.ordered_units(changed)

    def test_transitive_unknown_preserves_identity_without_retry(self):
        self.assertTrue(
            (SHARED / "cloud_dependencies.py").is_file(), "Ordering component absent"
        )
        import cloud_dependencies as d

        values = self.graph()
        values[2]["predecessor_receipts"] = [
            dict(unit_id="C", path="c.json", sha256="a" * 64)
        ]
        calls = []
        unknown = dict(result="UNKNOWN", native_operation_id="original-operation")

        def execute(req):
            calls.append(req["unit_id"])
            return unknown

        result = d.dispatch(values, execute, {}, None)
        self.assertEqual(calls, ["B"])
        self.assertEqual(result["units"]["B"], unknown)
        self.assertEqual(result["order"], ["B", "C", "A"])
        self.assertNotEqual(result["aggregate"], "VERIFIED")


class DependencyBoundaryCases(DependencyReceiptCases):
    def test_freshness_expires_during_final_acquisition_not_consumer_lease(self):
        import cloud_dependencies as d
        from dataclasses import replace

        state = self.fixture(stage="apply")
        target = state.target
        target.policy = replace(target.policy, ttl_seconds=3600)
        target.boundary.policy = target.policy
        target.transport.claims["exp"] = state.now + 3600
        target.transport.azure_claims["exp"] = state.now + 3600
        target.transport.lease_end = state.now + 3600
        preview = json.loads((target.root / target.preview_ref["path"]).read_bytes())
        preview["expires_at"] = target.a.utc(state.now + 3600)
        target.preview_ref = target.put(target.preview_ref["path"], preview)
        target.transport.run["display_title"] = (
            "cloud:" + target.request_ref["sha256"] + ":" + target.preview_ref["sha256"]
        )
        tick = [state.now]
        target.boundary.clock = lambda: tick[0]
        original = d.ArtifactHttps.request
        metadata_calls = []

        def acquire(method, url, headers, body=None):
            response = original(method, url, headers, body)
            if url.endswith("/artifacts/17"):
                metadata_calls.append(url)
                if len(metadata_calls) == 2:
                    tick[0] += 1000
            return response

        with patch.object(d.ArtifactHttps, "request", side_effect=acquire):
            self.failure(state, "DEPENDENCY_NOT_VERIFIED")
        self.assertEqual(len(metadata_calls), 2)
        self.assertLess(tick[0], state.now + 3600 - 10)
        self.assertTrue(list(target.evidence.glob("*.authorization.json")))

    def test_approval_self_review_uses_stable_id_despite_extra_metadata(self):
        state = self.fixture()
        state.pin["actors"] = [[8, "reviewer"]]
        state.run["actor"] = dict(
            id=8, login="reviewer", html_url="https://example.invalid/actor"
        )
        state.run["triggering_actor"] = dict(id=8, login="reviewer", type="User")
        self.failure(state, "DEPENDENCY_APPROVAL_MISMATCH")

    def test_each_write_reacquires_and_final_scan_revocation_blocks(self):
        for stage in ("prepare", "apply"):
            state = self.fixture(stage=stage)
            state.target.write(mutation="first")
            self.assertEqual(len(state.target.writes), 1)
            state.run["conclusion"] = "failure"
            with self.assertRaises(state.target.a.AdmissionDenied):
                state.target.write(mutation="second")
            self.assertEqual(len(state.target.writes), 1)
            self.doCleanups()
            state = self.fixture(stage=stage)

            def scan(raw):
                state.run["conclusion"] = "failure"
                return True

            with self.assertRaises(state.target.a.AdmissionDenied):
                state.target.boundary.write(
                    state.target.root,
                    state.target.request_ref,
                    state.target.preview_ref,
                    mutation_id="final",
                    submit=lambda credentials: state.target.writes.append("write"),
                    scan=scan,
                )
            self.assertEqual(state.target.writes, [])
            self.doCleanups()

    def test_physically_resolved_temporary_root(self):
        from contextlib import contextmanager
        import cloud_dependencies as d

        state = self.fixture()
        factory = tempfile.TemporaryDirectory

        @contextmanager
        def alias_root(*args, **kwargs):
            with factory(*args, **kwargs) as temp:
                parent = Path(temp)
                physical = parent / "physical"
                physical.mkdir()
                alias = parent / "alias"
                alias.symlink_to(physical, target_is_directory=True)
                yield str(alias)

        with patch.object(d.tempfile, "TemporaryDirectory", side_effect=alias_root):
            state.target.write()
        self.assertEqual(state.target.writes, ["write"])

    def test_read_only_verify_policy_is_loadable_but_never_a_writer(self):
        from dataclasses import asdict, replace

        for provider in ("azure", "aws"):
            state = self.fixture(provider)
            policy = replace(
                state.target.policy, operation="apply", environment="sandbox-verify"
            )
            governed = __import__(provider + "_governed")
            loaded = governed.load_policy(json.dumps(asdict(policy)), "verify")
            self.assertEqual(loaded, policy)
            state.target.boundary.policy = loaded
            with self.assertRaises(state.target.a.AdmissionDenied):
                state.target.write()
            self.assertEqual(state.target.writes, [])
            self.doCleanups()

    def test_three_actual_adapter_units_partial_failure_preserves_a(self):
        import cloud_dependencies as d

        # A prototype only supplies deterministic input bytes; acceptance A runs
        # its real prepare/apply/verify pipeline inside the dispatcher callback.
        prototype = self.fixture()
        a_request = copy.deepcopy(prototype.producer.executor.request)
        runtime = prototype.target.runtime
        self.doCleanups()
        # Other protocol cases may leave AWS's same-basename `cloud` CLI loaded.
        # Use the established scoped provider module isolation before constructing
        # the Azure adapters; otherwise their owner detector can bind to AWS code.
        isolation = AzureTestBase()
        isolation.setUp()
        self.addCleanup(isolation.doCleanups)
        spec = importlib.util.spec_from_file_location(
            "dependency_adapters", ROOT / "tests/cloud-orchestration-execution.tests.py"
        )
        assert spec and spec.loader
        execution = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(execution)
        units = {}
        for label in ("unit-b", "unit-c"):
            case = execution.AzureExecution()
            case.setUp()
            self.addCleanup(case.doCleanups)
            self.assertEqual(
                Path(case.e.detect_owner.__code__.co_filename),
                ROOT / "plugins/sdd-azure-cloud/scripts/cloud.py",
            )
            case.req["unit_id"] = label
            old = case.directory
            case.directory = old.rsplit("/", 1)[0] + "/" + label
            case.req["local_context"]["evidence_directory"] = case.directory
            (case.root / case.directory).mkdir(parents=True)
            owner = case.req["local_context"]["ownership"]
            value = json.loads((case.root / owner["path"]).read_bytes())
            raw = encode(value)
            (case.root / owner["path"]).write_bytes(raw)
            owner["sha256"] = hashlib.sha256(raw).hexdigest()
            if label == "unit-c":
                path = (
                    case.directory.replace("/unit-c", "/unit-b")
                    + "/verify-result.json.verification.json"
                )
                receipt = dict(
                    schema="cloud-verification/v1",
                    run_id=case.req["run_id"],
                    unit_id="unit-b",
                    provider="azure",
                    profile=case.req["verification_profile"],
                    required_check_ids=["resource"],
                    checks=[
                        dict(
                            check_id="resource",
                            observation=case.req["policy"],
                            result="FAIL",
                        )
                    ],
                    overall_result="FAIL",
                    evidence_complete=False,
                )
                raw = encode(receipt)
                (case.root / path).parent.mkdir(parents=True)
                (case.root / path).write_bytes(raw)
                case.req["predecessor_receipts"] = [
                    dict(
                        unit_id="unit-b",
                        path=path,
                        sha256=hashlib.sha256(raw).hexdigest(),
                    )
                ]
            case.request_bytes = encode(case.req)
            (case.root / case.request_ref["path"]).write_bytes(case.request_bytes)
            case.request_ref["sha256"] = hashlib.sha256(case.request_bytes).hexdigest()
            case.executor = case.stage("prepare")
            units[label] = case
        proofs = {}
        accepted: list[SimpleNamespace] = []
        a_bytes = []
        calls = []

        class Transport:
            def request(self, *args, **kwargs):
                return accepted[0].target.transport.request(*args, **kwargs)

        def execute(req):
            key = req["unit_id"]
            calls.append(key)
            if key == a_request["unit_id"]:
                state = self.fixture()
                accepted.append(state)
                a_bytes.append((state.producer.root / state.ref["path"]).read_bytes())
                proofs[key] = state.pin
                return json.loads((state.producer.root / state.output).read_bytes())
            case = units[key]
            with patch.dict(os.environ, {"CLOUD_WORKSPACE_ROOT": str(case.root)}):
                case.prepare()
                case.arm.state = "Failed"
                return case.apply()

        result = d.dispatch(
            [units["unit-c"].req, units["unit-b"].req, a_request],
            execute,
            proofs,
            runtime,
            transport=Transport(),
            clock=lambda: 1792303325,
        )
        self.assertEqual(calls, [a_request["unit_id"], "unit-b"])
        self.assertEqual(result["units"][a_request["unit_id"]]["result"], "PASS")
        self.assertEqual(result["units"]["unit-b"]["result"], "FAIL")
        self.assertEqual(result["units"]["unit-c"]["result"], "BLOCKED")
        self.assertNotEqual(result["aggregate"], "VERIFIED")
        a = accepted[0]
        original = a_bytes[0]
        self.assertEqual(a.producer.arm.submissions, 1)
        self.assertEqual(units["unit-b"].arm.submissions, 1)
        dependent = units["unit-c"]
        self.assertEqual(dependent.arm.calls, [])
        # A direct provider call cannot bypass scheduling/admission of C either.
        with patch.dict(os.environ, {"CLOUD_WORKSPACE_ROOT": str(dependent.root)}):
            blocked = dependent.executor.prepare(dependent.directory + "/direct.json")
        self.assertEqual(blocked["result"], "BLOCKED")
        self.assertEqual(dependent.arm.submissions, 0)
        self.assertFalse(
            any(call[0] in ("POST", "PUT") for call in dependent.arm.calls)
        )
        self.assertEqual((a.producer.root / a.ref["path"]).read_bytes(), original)
        # Successful independent A remains usable through authenticated acquisition.
        operation, raw, _ = d._verified(
            a.pin, runtime, a.target.transport, clock=lambda: a.now
        )
        self.assertEqual(raw, original)
        self.assertEqual(operation["result"], "PASS")
        single = d.dispatch(
            [a_request],
            lambda request: operation,
            proofs,
            runtime,
            transport=a.target.transport,
            clock=lambda: a.now,
        )
        self.assertEqual(single["aggregate"], "VERIFIED")


class DependencyFinalBoundaryCases(DependencyReceiptCases):
    def test_consumer_expiry_during_second_acquisition(self):
        import cloud_dependencies as d

        for elapsed in (0, 111):
            with self.subTest(elapsed=elapsed):
                state = self.fixture(stage="apply")
                now = [state.now]
                state.target.boundary.clock = lambda: now[0]
                original = d.ArtifactHttps.request
                acquisitions = []

                def acquire(method, url, headers, body=None):
                    response = original(method, url, headers, body)
                    if url.endswith("/artifacts/17"):
                        acquisitions.append(url)
                        if len(acquisitions) == 2:
                            now[0] += elapsed
                    return response

                with patch.object(d.ArtifactHttps, "request", side_effect=acquire):
                    if elapsed:
                        self.failure(state, "CREDENTIAL_EXPIRED")
                    else:
                        state.target.write()
                        self.assertEqual(state.target.writes, ["write"])
                self.assertEqual(len(acquisitions), 2)
                self.doCleanups()

    def test_final_consumer_metadata_latency_cannot_stale_predecessor(self):
        from dataclasses import replace

        for elapsed in (0, 301):
            with self.subTest(elapsed=elapsed):
                state = self.fixture()
                target = state.target
                target.boundary.policy = replace(target.policy, ttl_seconds=1000)
                target.transport.lease_end = state.now + 1200
                target.transport.azure_claims["exp"] = state.now + 1200
                now = [state.now]
                target.boundary.clock = lambda: now[0]
                original = target.a.GitHubAdmission.metadata
                calls = []

                def metadata(admission, *args, **kwargs):
                    result = original(admission, *args, **kwargs)
                    calls.append(result)
                    if len(calls) == 3:
                        now[0] += elapsed
                    return result

                with patch.object(target.a.GitHubAdmission, "metadata", metadata):
                    if elapsed:
                        self.failure(state, "DEPENDENCY_NOT_VERIFIED")
                    else:
                        target.write()
                        self.assertEqual(target.writes, ["write"])
                self.assertEqual(len(calls), 3)
                self.assertLess(now[0], target.transport.claims["exp"])
                self.assertLess(now[0], target.transport.lease_end)
                self.doCleanups()

    def test_cross_provider_predecessors_and_foreign_provenance_denial(self):
        for predecessor, consumer in (("aws", "azure"), ("azure", "aws")):
            for stage in ("prepare", "apply"):
                with self.subTest(
                    predecessor=predecessor, consumer=consumer, stage=stage
                ):
                    state = self.fixture(predecessor, stage, consumer_provider=consumer)
                    original = state.pin["scope"]["account_id"]
                    state.pin["scope"]["account_id"] = "foreign-scope"
                    self.failure(state, "DEPENDENCY_REQUEST_BINDING")
                    state.pin["scope"]["account_id"] = original
                    original_sha = state.run["head_sha"]
                    state.run["head_sha"] = "b" * 40
                    self.failure(state, "DEPENDENCY_RUN_MISMATCH")
                    state.run["head_sha"] = original_sha
                    state.target.write()
                    self.assertEqual(state.target.writes, ["write"])
                    self.doCleanups()

    def test_consumer_revocation_during_second_predecessor_acquisition(self):
        import cloud_dependencies as d

        for variant in ("approval", "run"):
            with self.subTest(variant=variant):
                state = self.fixture(stage="apply")
                target = state.target
                original = d.ArtifactHttps.request
                acquisitions = []

                def acquire(method, url, headers, body=None):
                    response = original(method, url, headers, body)
                    if url.endswith("/artifacts/17"):
                        acquisitions.append(url)
                        if len(acquisitions) == 2:
                            if variant == "approval":
                                target.transport.approvals[0]["state"] = "rejected"
                            else:
                                target.transport.run.update(
                                    status="completed", conclusion="cancelled"
                                )
                    return response

                with patch.object(d.ArtifactHttps, "request", side_effect=acquire):
                    with self.assertRaises(target.a.AdmissionDenied):
                        target.write()
                self.assertEqual(len(acquisitions), 2)
                self.assertEqual(target.writes, [])
                self.assertLess(target.boundary.clock(), target.transport.lease_end)
                self.assertTrue(list(target.evidence.glob("*.authorization.json")))
                self.doCleanups()

    def test_guards_are_sensitive_not_blanket_denial(self):
        from contextlib import ExitStack
        import cloud_dependencies as d

        selected = {
            "pin.run_id",
            "run.event",
            "pin.workflow_sha256",
            "pin.executor_revision",
            "job.conclusion",
            "job.started_at",
            "environment.can_admins_bypass",
            "approvals.0.state",
            "metadata.expired",
            "metadata.digest",
            "metadata.name",
        }
        for label, target, path, value, guard in dependency_field_matrix():
            if label not in selected or value is None:
                continue
            with self.subTest(field=label):
                state = self.fixture()
                obj = getattr(state, target)
                for part in path[:-1]:
                    obj = obj[int(part) if isinstance(obj, list) else part]
                obj[int(path[-1]) if isinstance(obj, list) else path[-1]] = value
                self.failure(state, guard)
                original = d.c._require
                hits = []

                def bypass(condition, code="INVALID_ARTIFACT"):
                    if code == guard and not condition:
                        hits.append(code)
                        return
                    original(condition, code)

                with ExitStack() as stack:
                    for module in {d.c, state.target.a.contracts, c}:
                        stack.enter_context(
                            patch.object(module, "_require", side_effect=bypass)
                        )
                    state.target.write()
                self.assertTrue(hits)
                self.assertEqual(state.target.writes, ["write"])
                self.doCleanups()

    def test_standalone_provider_install_does_not_import_other_provider(self):
        for provider in ("azure", "aws"):
            with self.subTest(provider=provider), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                scripts = root / f"plugins/sdd-{provider}-cloud/scripts"
                shutil.copytree(
                    ROOT / f"plugins/sdd-{provider}-cloud/scripts",
                    scripts,
                    ignore=shutil.ignore_patterns("__pycache__"),
                )
                shared = root / "plugins/sdd-quality-loop/scripts"
                shared.mkdir(parents=True)
                for name in (
                    "cloud_contracts",
                    "cloud_authorization",
                    "cloud_verification",
                    "cloud_dependencies",
                ):
                    shutil.copy2(SHARED / (name + ".py"), shared / (name + ".py"))
                code = (
                    "import sys;from unittest.mock import patch;"
                    "guard=patch('urllib.request.OpenerDirector.open',side_effect=AssertionError('OFFLINE'));guard.start();"
                    "sys.path.insert(0,sys.argv[1]);"
                    "m=__import__(sys.argv[2]);"
                    "assert m.workflow_template()['jobs']['verify'];"
                    "import cloud_dependencies;"
                    "assert not any(k.startswith(sys.argv[3]) for k in sys.modules)"
                )
                result = subprocess.run(
                    [
                        sys.executable,
                        "-I",
                        "-c",
                        code,
                        str(scripts),
                        provider + "_governed",
                        ("aws" if provider == "azure" else "azure") + "_",
                    ],
                    capture_output=True,
                    text=True,
                    timeout=20,
                )
                self.assertEqual(result.returncode, 0, result.stderr)


class DependencyCallbackExpiryCases(unittest.TestCase):
    """Synthetic admitted deadline, real boundary/provider guards and wire counters.

    This isolates deadline handoff, NOT predecessor provenance. The separate
    DependencyReceipt/FieldMatrix/FinalBoundary cases exercise real acquisition.
    """

    def fixtures(self):
        spec = importlib.util.spec_from_file_location(
            "dependency_expiry_execution", ROOT / "tests/cloud-orchestration-execution.tests.py"
        )
        assert spec and spec.loader
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def callback_case(self, provider, mutation, checkpoint, elapsed):
        import cloud_dependencies as dependencies
        import inspect

        fixtures = self.fixtures()
        if provider == "azure":
            isolation = AzureTestBase()
            isolation.setUp()
            self.addCleanup(isolation.doCleanups)
        case = fixtures.AzureExecution() if provider == "azure" else fixtures.AwsExecution()
        case.setUp()
        self.addCleanup(case.doCleanups)
        if mutation in ("deploy", "execute"):
            case.prepare()
        executor = case.executor
        now = [fixtures.NOW]
        executor.clock = executor.boundary.clock = lambda: now[0]
        deadline = c._utc(fixtures.utc(fixtures.NOW + 10))
        acquisitions = []
        delays: list[str] = []
        guards = []
        journal = case.root / case.directory / (mutation + "-submission.json")
        if provider == "azure":
            journal = case.root / case.directory / (
                "deployment-submission.json" if mutation == "deploy"
                else "prepare-what-if-submission.json"
            )
        original_require = case.e.c._require

        def observe_guard(condition, code="INVALID_ARTIFACT"):
            if delays and code in ("CREDENTIAL_EXPIRED", "READ_CREDENTIAL_EXPIRED"):
                guards.append((code, bool(condition)))
            original_require(condition, code)

        def admitted(*args, **kwargs):
            self.assertLess(now[0], fixtures.NOW + 10)
            acquisitions.append(now[0])
            return deadline

        def delay():
            if not delays:
                # Two dependency admissions completed while fresh; delay is INSIDE
                # the provider callback, never another shared pre-submit check.
                self.assertGreaterEqual(len(acquisitions), 2)
                self.assertEqual(len(acquisitions) % 2, 0)
                delays.append(checkpoint)
                now[0] += elapsed

        from contextlib import ExitStack
        with ExitStack() as stack:
            stack.enter_context(patch.object(dependencies, "admit_predecessors", side_effect=admitted))
            stack.enter_context(patch.object(case.e.c, "_require", side_effect=observe_guard))
            if checkpoint == "journal":
                original = executor.audit

                def audit(path, value):
                    result = original(path, value)
                    if case.root / path == journal:
                        delay()
                    return result

                stack.enter_context(patch.object(executor, "audit", side_effect=audit))
            elif checkpoint == "validation":
                original_check = executor.check

                def check():
                    result = original_check()
                    if len(acquisitions) >= (4 if mutation == "deploy" else 2):
                        delay()
                    return result

                stack.enter_context(patch.object(executor, "check", side_effect=check))
            elif checkpoint == "authentication":
                original_metadata = case.a.GitHubAdmission.metadata

                def metadata(admission, *args, **kwargs):
                    result = original_metadata(admission, *args, **kwargs)
                    if journal.exists() and any(
                        frame.function == "final_admission" for frame in inspect.stack()
                    ):
                        delay()
                    return result

                stack.enter_context(patch.object(case.a.GitHubAdmission, "metadata", metadata))
            elif checkpoint == "history":
                original_history = case.e.intent_history

                def history(*args, **kwargs):
                    result = original_history(*args, **kwargs)
                    if journal.exists():
                        delay()
                    return result

                stack.enter_context(patch.object(case.e, "intent_history", side_effect=history))
            else:
                self.assertEqual(checkpoint, "readback")
                holder = executor.native if mutation == "create" else executor
                method = "read_object" if mutation == "create" else "readback"
                original_read = getattr(holder, method)

                def read(*args, **kwargs):
                    result = original_read(*args, **kwargs)
                    if journal.exists():
                        delay()
                    return result

                stack.enter_context(patch.object(holder, method, side_effect=read))
            result = (
                case.apply("dependency-expiry.json") if mutation in ("deploy", "execute")
                else executor.prepare(case.directory + "/dependency-expiry.json")
            )
        if provider == "azure":
            writes = case.arm.submissions if mutation == "deploy" else sum(
                method == "POST" and "/whatIf?" in url for method, url, _ in case.arm.calls
            )
        else:
            writes = case.native.writes.count(
                dict(publish="PutObject", create="CreateChangeSet", execute="ExecuteChangeSet")[mutation]
            )
        print("SYNTHETIC_DEADLINE_REAL_FINAL_GUARD", provider, mutation, checkpoint,
              "elapsed", elapsed, "admissions", acquisitions, "guards", guards,
              "target_native_submissions", writes, "result", result["result"], flush=True)
        self.assertEqual(delays, [checkpoint])
        self.assertTrue(guards, "real callback expiry guard must execute")
        if elapsed >= 10:
            self.assertTrue(any(not valid for _, valid in guards))
        self.assertTrue(journal.is_file(), "consumed intent retained")
        self.assertLess(now[0], fixtures.NOW + 110, "consumer TTL still valid")
        if mutation in ("deploy", "execute"):
            preview = c.read_artifact(case.root, case.preview_ref, "cloud-preview/v1")
            self.assertLess(now[0], case.a.epoch(preview["expires_at"]))
        self.assertEqual(writes, 0 if elapsed >= 10 else 1)
        self.assertEqual(result["result"], "BLOCKED" if elapsed >= 10 else "PASS")

    def test_azure_callback_freshness_validation_and_journal(self):
        for mutation in ("preview", "deploy"):
            for checkpoint in ("validation", "journal"):
                for elapsed in (0, 10, 11):
                    with self.subTest(mutation=mutation, checkpoint=checkpoint, elapsed=elapsed):
                        try:
                            self.callback_case("azure", mutation, checkpoint, elapsed)
                        finally:
                            self.doCleanups()

    def test_aws_callback_freshness_readback_history_and_authentication(self):
        for mutation, checkpoint in (
            ("publish", "authentication"), ("create", "authentication"),
            ("execute", "authentication"), ("create", "readback"),
            ("execute", "readback"), ("execute", "history"),
        ):
            for elapsed in (0, 10, 11):
                with self.subTest(mutation=mutation, checkpoint=checkpoint, elapsed=elapsed):
                    try:
                        self.callback_case("aws", mutation, checkpoint, elapsed)
                    finally:
                        self.doCleanups()

    def test_receipt_expiry_minimum_and_empty_predecessors(self):
        import cloud_dependencies as dependencies

        fixtures = self.fixtures()
        for provider in ("azure", "aws"):
            for stage in ("prepare", "apply"):
                for bound in ("predecessor", "policy", "oidc", "provider", "preview", "empty"):
                    if bound == "preview" and stage == "prepare":
                        continue
                    with self.subTest(provider=provider, stage=stage, bound=bound):
                        case = fixtures.Admission()
                        case.setUp()
                        try:
                            case.setup_case(provider, stage)
                            end = fixtures.NOW + (10 if bound == "predecessor" else 110)
                            if bound == "oidc":
                                case.transport.claims["exp"] = end = fixtures.NOW + 20
                            if bound == "provider":
                                case.transport.lease_end = end = fixtures.NOW + 20
                                case.transport.azure_claims["exp"] = end
                            if bound == "preview":
                                preview = json.loads((case.root / case.preview_ref["path"]).read_bytes())
                                preview["expires_at"] = case.a.utc(end := fixtures.NOW + 20)
                                case.preview_ref = case.put(case.preview_ref["path"], preview)
                                case.transport.run["display_title"] = (
                                    "cloud:" + case.request_ref["sha256"] + ":" + case.preview_ref["sha256"]
                                )
                            deadline = c._utc(fixtures.utc(
                                fixtures.NOW + (10 if bound == "predecessor" else 200)
                            ))
                            if bound == "empty":
                                # Execute the real empty predecessor admission, not a stub.
                                ref, _ = case.write()
                            else:
                                with patch.object(dependencies, "admit_predecessors", return_value=deadline):
                                    ref, _ = case.write()
                            receipt = c.read_artifact(case.root, ref, "cloud-authorization-receipt/v1")
                            self.assertEqual(case.writes, ["write"])
                            self.assertEqual(receipt["expires_at"], case.a.utc(end))
                        finally:
                            case.doCleanups()


if __name__ == "__main__":
    unittest.main(verbosity=2)
