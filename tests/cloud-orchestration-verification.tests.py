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
import sys
import tempfile
import unittest
from unittest.mock import patch
from types import ModuleType

ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT / "plugins/sdd-quality-loop/scripts"
sys.path.insert(0, str(SHARED))
import cloud_contracts as c  # noqa: E402


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
                                0, dict(timeStamp=extra_time, maximum=extra_value)
                            )
                            result.body = encode(value)
                        else:
                            tree = ET.fromstring(result.body)
                            ns = "{http://monitoring.amazonaws.com/doc/2010-08-01/}"
                            points = tree.find(".//" + ns + "Datapoints")
                            assert points is not None
                            member = ET.SubElement(points, ns + "member")
                            ET.SubElement(member, ns + "Timestamp").text = extra_time
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
                response.body = encode(dict(value=[], nextLink="https://untrusted.example"))
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
        monitoring_workspace_id=prefix + "Microsoft.OperationalInsights/workspaces/monitor",
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
    actions = {"Microsoft.Authorization/permissions/read",
               "Microsoft.Authorization/roleAssignments/read",
               "Microsoft.Authorization/roleDefinitions/read"}
    mapping = {
        cfg["vm_id"]: {"Microsoft.Compute/virtualMachines/read", "Microsoft.Compute/virtualMachines/instanceView/read", "Microsoft.Insights/metrics/read", "Microsoft.Insights/metrics/write"},
        cfg["nic_id"]: {"Microsoft.Network/networkInterfaces/read", "Microsoft.Network/networkInterfaces/effectiveNetworkSecurityGroups/action"},
        cfg["identity_id"]: {"Microsoft.ManagedIdentity/userAssignedIdentities/read"},
        cfg["association_id"]: {"Microsoft.Insights/dataCollectionRuleAssociations/read"},
        cfg["data_collection_rule_id"]: {"Microsoft.Insights/dataCollectionRules/read"},
    }
    if "backup" in cfg:
        item = cfg["backup"]["protected_item_id"]
        mapping[item] = {"Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems/read", "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems/recoveryPoints/read"}
        if resource.startswith(item + "/recoveryPoints/"):
            return actions | mapping[item]
    return actions | mapping[resource]


def azure_role_records(fixture):
    cfg = fixture.cfg
    subscription = "/subscriptions/" + fixture.scope["account_id"]
    targets = [cfg[k] for k in ("vm_id", "nic_id", "identity_id", "association_id", "data_collection_rule_id")]
    if "backup" in cfg:
        targets.append(cfg["backup"]["protected_item_id"])
    audit = {"Microsoft.Authorization/roleAssignments/read", "Microsoft.Authorization/roleDefinitions/read"}
    assignments, definitions = [], {}
    for i, target in enumerate([subscription, *targets]):
        guid = "00000000-0000-0000-0000-" + str(i + 10).zfill(12)
        role_id = subscription + "/providers/Microsoft.Authorization/roleDefinitions/" + guid
        assignment_id = target + "/providers/Microsoft.Authorization/roleAssignments/" + guid
        actions = audit if target == subscription else azure_actions(target, cfg) - audit
        assignments.append(dict(id=assignment_id, name=guid, type="Microsoft.Authorization/roleAssignments", properties=dict(scope=target, principalId=fixture.principal, principalType="ServicePrincipal", roleDefinitionId=role_id, condition=None, conditionVersion=None, delegatedManagedIdentityResourceId=None)))
        definitions[role_id] = dict(id=role_id, name=guid, type="Microsoft.Authorization/roleDefinitions", properties=dict(roleName="Untrusted display name", type="CustomRole", assignableScopes=[subscription], permissions=[dict(actions=sorted(actions), notActions=[], dataActions=[], notDataActions=[])]))
    return assignments, definitions


class AzureClosureAndDcrCases(unittest.TestCase):
    def collector(self, native=False):
        sys.path.insert(0, str(ROOT / "plugins/sdd-azure-cloud/scripts"))
        import azure_observation as module
        fixture = NativeFixture("azure", "all", "healthy")
        transport = module.HttpsTransport() if native else fixture
        collector = module.Collector(fixture.scope, fixture.cfg, fixture.credentials,
            principal=fixture.principal, completed="2026-10-18T06:00:00Z", age=300,
            clock=lambda: 1792303260, transport=transport, run_id="synthetic-run", unit_id="synthetic-unit")
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
            for variant in ("principal", "group", "scope", "condition", "wildcard", "data", "notActions", "role-id", "assignment-id", "pagination", "denied", "empty", "caller-disagrees", "drift"):
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
                            if variant == "principal": prop["principalId"] = "00000000-0000-0000-0000-000000000099"
                            if variant == "group": prop["principalType"] = "Group"
                            if variant == "scope": prop["scope"] += "/unrelated/child"
                            if variant == "condition": prop["condition"] = "unsupported"
                            if variant == "assignment-id": row["id"] += "wrong"
                            if variant == "pagination": value["nextLink"] = "https://untrusted.example"
                            if variant == "denied": response.status = 403
                            if variant == "empty": value["value"] = []
                            if variant == "drift" and assignment_reads > 1: value["value"] = value["value"][:-1]
                        if "/roleDefinitions/" in url:
                            perm = value["properties"]["permissions"][0]
                            if variant == "wildcard": perm["actions"] = ["*"]
                            if variant == "data": perm["dataActions"] = ["Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"]
                            if variant == "notActions": perm["notActions"] = ["Microsoft.Compute/virtualMachines/read"]
                            if variant == "role-id": value["id"] += "wrong"
                        if "/permissions?" in url and variant == "caller-disagrees": value["value"][0]["actions"] = []
                        response.body = encode(value)
                        return response
                    with patch.object(collector.transport, "request", side_effect=wire):
                        with self.assertRaises(ValueError): collector.identity()

    def test_dcr_readback_and_mismatches(self):
        for variant in ("matched", "id", "location", "kind", "state", "source", "counter", "interval", "stream", "destination", "flow", "transform", "denied", "missing", "pagination"):
            with self.subTest(variant=variant):
                collector, fixture = self.collector()
                original = fixture.request
                def wire(method, url, headers, body=None):
                    response = original(method, url, headers, body)
                    if url.split("?")[0].endswith(fixture.cfg["data_collection_rule_id"]):
                        value = json.loads(response.body)
                        props = value["properties"]
                        if variant == "id": value["id"] += "wrong"
                        if variant == "location": value["location"] = "westus"
                        if variant == "kind": value["kind"] = "Windows"
                        if variant == "state": props["provisioningState"] = "Failed"
                        if variant == "source": props["dataSources"] = {}
                        if variant == "counter": props["dataSources"]["performanceCounters"][0]["counterSpecifiers"] = ["unrelated"]
                        if variant == "interval": props["dataSources"]["performanceCounters"][0]["samplingFrequencyInSeconds"] = 600
                        if variant == "stream": props["dataSources"]["performanceCounters"][0]["streams"] = ["Microsoft-Syslog"]
                        if variant == "destination": props["destinations"]["logAnalytics"][0]["workspaceResourceId"] += "wrong"
                        if variant == "flow": props["dataFlows"][0]["destinations"] = ["other"]
                        if variant == "transform": props["dataFlows"][0]["transformKql"] = "source | where false"
                        if variant == "denied": response.status = 403
                        if variant == "missing": value = {}
                        if variant == "pagination": value["nextLink"] = "https://untrusted.example"
                        response.body = encode(value)
                    return response
                with patch.object(fixture, "request", side_effect=wire):
                    if variant == "matched": self.assertTrue(collector.monitoring()[0])
                    else:
                        try: healthy = collector.monitoring()[0]
                        except (ValueError, KeyError): healthy = False
                        self.assertFalse(healthy)
                self.assertTrue(any(url.split("?")[0].endswith(fixture.cfg["data_collection_rule_id"]) for _, url, _ in fixture.calls))

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
            return dict(id=path, location=self.scope["region"], kind="Linux", properties=dict(
                provisioningState="Succeeded",
                dataSources=dict(performanceCounters=[dict(name="cpu", streams=["Microsoft-Perf"], samplingFrequencyInSeconds=60, counterSpecifiers=["\\Processor(_Total)\\% Processor Time"])]),
                destinations=dict(logAnalytics=[dict(name="workspace", workspaceResourceId=cfg["vm_id"].split("/providers/")[0] + "/providers/Microsoft.OperationalInsights/workspaces/monitor")]),
                dataFlows=[dict(streams=["Microsoft-Perf"], destinations=["workspace"])]))
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
            return dict(statuses=[dict(code="PowerState/running")])
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
                value=[
                    dict(
                        id=path + "/" + name,
                        name=dict(value=name),
                        timeseries=[
                            dict(
                                metadatavalues=metadata,
                                data=[dict(timeStamp=self.stamp(), maximum=val)],
                            )
                        ],
                    )
                ]
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


class AwsObservationOrchestration(unittest.TestCase):
    """Production prepare/apply/observe code over explicitly synthetic transports."""

    def setup_execution(self, *, selectors=True):
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
        case.request_bytes = encode(case.req)
        (case.root / case.request_ref["path"]).write_bytes(case.request_bytes)
        case.request_ref["sha256"] = hashlib.sha256(case.request_bytes).hexdigest()
        wire = ObservationWire(case.native, cfg)
        case.native = wire
        case.executor = case.stage("prepare")
        case.prepare()
        self.assertEqual(case.apply()["result"], "PASS")
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


class AzureCompletionCases(unittest.TestCase):
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


class AzureResourceBindingCases(unittest.TestCase):
    o: ModuleType
    g: ModuleType
    setUp = AzureCompletionCases.setUp

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
                    return SimpleNamespace(status=200, body=encode(operations))

            client = Client()
            client.native_id = native_id
            executor = SimpleNamespace(
                request=dict(scope=scope),
                client=client,
                request_id="synthetic-request-id",
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


class AzureObservationOrchestration(unittest.TestCase):
    setUp = AzureCompletionCases.setUp
    o: ModuleType
    g: ModuleType

    def test_public_verify_uses_original_operation_and_received_signal(self):
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
            monitoring_workspace_id=resources["Microsoft.Compute/virtualMachines"].split("/providers/")[0] + "/providers/Microsoft.OperationalInsights/workspaces/monitor",
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
        before = (case.root / case.request_ref["path"]).read_bytes()
        writes = case.arm.submissions
        with (
            patch.object(case.arm, "request", side_effect=wire),
            patch.object(auth, "request", side_effect=metadata),
        ):
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
