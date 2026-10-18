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
MODULE = ROOT / "plugins/sdd-quality-loop/scripts/cloud_contracts.py"
NOW = "2026-10-18T06:00:00Z"
END = "2026-10-18T07:00:00Z"
SHA = "a" * 64


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise ImportError(f"Cannot load test dependency: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def encode(value):
    return (json.dumps(value, sort_keys=True, ensure_ascii=True) + "\n").encode()


def ref(path, data=b"fixture"):
    return {"path": path, "sha256": hashlib.sha256(data).hexdigest()}


def fixtures():
    identity = dict(run_id="run-1", unit_id="unit-1", provider="aws")
    scope = dict(
        account_id="123456789012", region="us-east-1", deployment_scope="stack-1"
    )
    request = dict(
        schema="cloud-run-request/v1",
        **identity,
        binding_id="binding-1",
        environment="sandbox",
        scope=scope,
        owner="cdk",
        route="aws-cdk",
        operation="apply",
        predecessor_receipts=[],
        source_revision="a" * 40,
        input_artifacts=[
            dict(kind=k, **ref(k + ".bin"))
            for k in ("source", "compiled", "asset", "parameters", "module")
        ],
        dependency_lock=ref("lock.json"),
        policy=ref("policy.json"),
        verification_profile=dict(id="health", version="1", **ref("profile.json")),
    )
    lock = dict(
        schema="cloud-dependency-lock/v1",
        adapter_version="1.0.0",
        upstream=[
            dict(
                repository="https://example.invalid/source",
                commit="a" * 40,
                root="upstream",
                files=[
                    dict(**ref("upstream/main.md"), references=["upstream/child.md"]),
                    dict(**ref("upstream/child.md"), references=[]),
                ],
            )
        ],
        tools=[dict(name="cdk", version="2.1.0", sha256=SHA)],
        managed_endpoints=[
            dict(endpoint="https://example.invalid/mcp", tool_schema=ref("tool.json"))
        ],
    )
    preview = dict(
        schema="cloud-preview/v1",
        **identity,
        scope=copy.deepcopy(scope),
        request=ref("request.json"),
        dependency_lock=ref("lock.json"),
        policy=ref("policy.json"),
        verification_profile=ref("profile.json"),
        preview_identity="change-set-1",
        semantic_sha256=SHA,
        changes=ref("changes.json"),
        replacements=[],
        deletes=[],
        created_at=NOW,
        expires_at=END,
    )
    receipt = dict(
        schema="cloud-authorization-receipt/v1",
        **identity,
        scope=copy.deepcopy(scope),
        operation="apply",
        issuer="https://token.actions.githubusercontent.com",
        principal="principal-1",
        subject="repo:example/project:environment:sandbox",
        ci=dict(
            repository="example/project",
            workflow=".github/workflows/cloud.yml",
            workflow_revision="a" * 40,
            ref="refs/heads/main",
            environment="sandbox",
            run_id="123",
            run_attempt=1,
        ),
        request=ref("request.json"),
        preview=ref("preview.json"),
        dependency_lock=ref("lock.json"),
        policy=ref("policy.json"),
        verification_profile=ref("profile.json"),
        issued_at=NOW,
        expires_at=END,
        approval_evidence=dict(
            locator="https://example.invalid/approvals/1", sha256=SHA
        ),
    )
    observation = dict(
        schema="cloud-observation/v1",
        **identity,
        native_operation_id="operation-1",
        resource_ids=["resource-1"],
        principal="observer-1",
        query="describe-health",
        timestamp=NOW,
        exit_code=0,
        status="PASS",
        result=ref("query.json"),
        classification="synthetic",
    )
    verification = dict(
        schema="cloud-verification/v1",
        **identity,
        profile=dict(id="health", version="1", **ref("profile.json")),
        required_check_ids=["network"],
        checks=[
            dict(check_id="network", observation=ref("observation.json"), result="PASS")
        ],
        overall_result="PASS",
        evidence_complete=True,
    )
    result = dict(
        schema="cloud-operation-result/v1",
        **identity,
        operation="apply",
        state="BLOCKED",
        result="BLOCKED",
        error_code="AUTH_UNAVAILABLE",
        message="Use the protected workflow.",
        input_manifest_sha256=SHA,
        evidence_manifest_path="evidence/manifest.json",
    )
    error = dict(
        schema="cloud-input-error/v1",
        error_code="INVALID_INPUT",
        message="Invalid request.",
        field="run_id",
    )
    return {
        v["schema"]: v
        for v in (
            request,
            lock,
            preview,
            receipt,
            observation,
            verification,
            result,
            error,
        )
    }


def local_bodies(scope=None, owner="cdk"):
    """Strict synthetic local data; never credentials or executable policy."""
    scope = scope or fixtures()["cloud-run-request/v1"]["scope"]
    return {
        "cloud-ownership/v1": dict(schema="cloud-ownership/v1",
            owners=[dict(owner=owner, root="bundle/unit")],
            existing_resources=[dict(resource_id="synthetic-resource", owner="terraform",
                attachments=[dict(resource_type="synthetic/attachment", name="monitor")])]),
        "cloud-deployment-policy/v1": dict(schema="cloud-deployment-policy/v1",
            allowed_scopes=[scope], allowed_resource_types=["synthetic/compute"],
            backup_required=True, private_networking=True,
            budget=dict(ceiling_minor_units=10000, currency="USD"),
            evidence=dict(residency="owner-selected", retention_days=30, access="restricted")),
        "cloud-verification-profile/v1": dict(schema="cloud-verification-profile/v1",
            id="health", version="1", required_check_ids=["resource", "network", "identity",
            "monitoring", "workload", "backup"], max_age_seconds=300),
    }


def install_local_context(root, request):
    """Upgrade an integrity fixture; move inputs, not request/preview evidence."""
    def put(path, value):
        data = value if isinstance(value, bytes) else encode(value)
        dest = root / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        return ref(path, data)
    bodies = local_bodies(request["scope"], request["owner"])
    for item in request["input_artifacts"]:
        item.update(put("bundle/unit/" + Path(item["path"]).name, b"fixture"))
    lock = fixtures()["cloud-dependency-lock/v1"]
    for upstream in lock["upstream"]:
        upstream["root"] = "bundle/" + upstream["root"]
        for item in upstream["files"]:
            item.update(put("bundle/" + item["path"], b"fixture"))
            item["references"] = ["bundle/" + r for r in item["references"]]
    for endpoint in lock["managed_endpoints"]:
        endpoint["tool_schema"] = put("bundle/tool.json", b"fixture")
    request["dependency_lock"] = put("bundle/lock.json", lock)
    request["policy"] = put("bundle/policy.json", bodies["cloud-deployment-policy/v1"])
    request["verification_profile"] = dict(id="health", version="1",
        **put("bundle/profile.json", bodies["cloud-verification-profile/v1"]))
    evidence = f"specs/cloud-orchestration/verification/T-002/cloud/{request['run_id']}/{request['unit_id']}"
    request["local_context"] = dict(workspace_anchor="CLOUD_WORKSPACE_ROOT",
        artifact_root="bundle", unit_roots=["bundle/unit"], evidence_directory=evidence,
        feature="cloud-orchestration", task_id="T-002",
        ownership=put("bundle/ownership.json", bodies["cloud-ownership/v1"]),
        provider_config=put("bundle/provider.json", b'{"synthetic":true}'))
    (root / evidence).mkdir(parents=True, exist_ok=True)
    return request


def nodes(value, path=()):
    yield path, value
    if isinstance(value, dict):
        for key, child in value.items():
            yield from nodes(child, path + (key,))
    elif isinstance(value, list):
        for i, child in enumerate(value):
            yield from nodes(child, path + (i,))


def at(value, path):
    for key in path:
        value = value[key]
    return value


class Contracts(unittest.TestCase):
    def setUp(self):
        self.assertTrue(
            MODULE.is_file(), "T-002 shared contract implementation is absent"
        )
        self.c = load(MODULE, "cloud_contracts")
        self.oracle = load(
            ROOT / "plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py",
            "schema_oracle",
        )
        self.f = {**fixtures(), **local_bodies()}
        self.temp = tempfile.TemporaryDirectory(prefix="cloud-contracts-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def schema(self, kind):
        return json.loads(
            (ROOT / "contracts" / (kind.split("/")[0] + ".schema.json")).read_bytes()
        )

    def rejects(self, value):
        with self.assertRaises(self.c.ContractError):
            self.c.parse_artifact(encode(value))

    def both(self, value, valid):
        errors = self.oracle._schema_validate(self.schema(value["schema"]), value)
        self.assertEqual(not errors, valid, errors)
        if valid:
            self.assertEqual(self.c.parse_artifact(encode(value)), value)
        else:
            self.rejects(value)

    def test_positive_all_families_and_both_providers(self):
        for value in self.f.values():
            with self.subTest(schema=value["schema"]):
                self.both(value, True)
        request = copy.deepcopy(self.f["cloud-run-request/v1"])
        request.update(provider="azure", owner="bicep", route="azure-bicep")
        request["scope"]["account_id"] = "00000000-0000-0000-0000-000000000001"
        self.both(request, True)
        request["owner"] = "cdk"
        self.both(request, False)

    def test_all_object_boundaries_unknown_and_missing_fields(self):
        for kind, original in self.f.items():
            for path, node in nodes(original):
                if not isinstance(node, dict):
                    continue
                bad = copy.deepcopy(original)
                at(bad, path)["unexpected"] = True
                with self.subTest(kind=kind, path=path, case="extra"):
                    self.both(bad, False)
                for key in node:
                    if key == "schema":
                        continue
                    bad = copy.deepcopy(original)
                    del at(bad, path)[key]
                    with self.subTest(kind=kind, path=path + (key,), case="missing"):
                        self.both(bad, False)

    def test_all_scalar_types_and_schema_versions(self):
        for kind, original in self.f.items():
            for path, node in nodes(original):
                if isinstance(node, (dict, list)) or not path or path[-1] == "schema":
                    continue
                bad = copy.deepcopy(original)
                at(bad, path[:-1])[path[-1]] = {}  # no coercion
                with self.subTest(kind=kind, path=path):
                    self.both(bad, False)
            for version in ("/v0", "/v2", "/V1", "/v1\n"):
                bad = dict(original, schema=kind.split("/")[0] + version)
                self.rejects(bad)

    def test_parser_rejects_ambiguous_json_without_echo(self):
        canary = "canary-" + "do-not-publish-482"
        for raw in (
            b"{}{}",
            b"[]",
            b"null",
            b"\xef\xbb\xbf{}",
            b"\xff",
            b"{",
            b'{"schema":"cloud-input-error/v1","schema":"cloud-input-error/v1"}',
            b'{"nested":{"x":1,"x":2}}',
            b'{"x":NaN}',
            b'{"x":Infinity}',
            b'{"x":-Infinity}',
            b'{"x":1e999}',
            ('{"' + canary + '":').encode(),
        ):
            with self.subTest(raw=raw[:10]):
                with self.assertRaises(self.c.ContractError) as caught:
                    self.c.parse_artifact(raw)
                self.assertNotIn(canary, str(caught.exception))

    def test_digests_utc_paths_and_scalar_edge_cases(self):
        original = self.f["cloud-preview/v1"]
        for key in ("created_at", "expires_at"):
            for value in (
                "2026-02-30T00:00:00Z",
                "2026-10-18T06:00:00+00:00",
                "2026-10-18T06:00:00z",
                NOW + "\n",
                "0000-01-01T00:00:00Z",
            ):
                self.rejects(dict(original, **{key: value}))
        for digest in ("A" * 64, "a" * 63, SHA + "\n", "sha256:" + SHA, None):
            self.both(dict(original, semantic_sha256=digest), False)
        paths = (
            "../x",
            "/x",
            "C:/x",
            "a\\x",
            "a//x",
            "./x",
            "a/../x",
            "a/",
            "a\nx",
            "a/%2e%2e/x",
            "a/CON",
            "a/x.",
            "a/x ",
            "a/aux.txt",
            "a/NUL",
        )
        for path in paths:
            bad = copy.deepcopy(original)
            bad["changes"]["path"] = path
            with self.subTest(path=path):
                self.both(bad, False)
        bad = copy.deepcopy(self.f["cloud-observation/v1"])
        bad["exit_code"] = True
        self.both(bad, False)
        self.rejects(dict(original, expires_at=NOW))

    def make_bundle(self):
        f = copy.deepcopy(self.f)
        for name in (
            "source.bin",
            "compiled.bin",
            "asset.bin",
            "parameters.bin",
            "module.bin",
            "policy.json",
            "profile.json",
            "upstream/main.md",
            "upstream/child.md",
            "tool.json",
            "changes.json",
        ):
            p = self.root / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(b"fixture")
        lock = f["cloud-dependency-lock/v1"]
        lock_ref = self.put("lock.json", lock)
        request = f["cloud-run-request/v1"]
        request["dependency_lock"] = lock_ref
        request_ref = self.put("request.json", request)
        preview = f["cloud-preview/v1"]
        preview.update(
            request=request_ref,
            dependency_lock=lock_ref,
            semantic_sha256=ref("changes.json")["sha256"],
        )
        preview_ref = self.put("preview.json", preview)
        receipt = f["cloud-authorization-receipt/v1"]
        receipt.update(
            request=request_ref, preview=preview_ref, dependency_lock=lock_ref
        )
        receipt_ref = self.put("receipt.json", receipt)
        return request_ref, preview_ref, receipt_ref

    def put(self, path, value):
        data = encode(value)
        (self.root / path).write_bytes(data)
        return ref(path, data)

    def bound(self, refs):
        return self.c.verify_binding(self.root, *refs, now=NOW)

    def test_every_bound_file_mutation_is_rejected(self):
        refs = self.make_bundle()
        self.bound(refs)
        for path in sorted(p for p in self.root.rglob("*") if p.is_file()):
            data = path.read_bytes()
            path.write_bytes(data + b" ")
            with self.subTest(file=path.name), self.assertRaises(self.c.ContractError):
                self.bound(refs)
            path.write_bytes(data)

    def test_bound_scope_owner_profile_policy_identity_and_preview_drift(self):
        refs = self.make_bundle()
        for schema, path, ref_index in (
            ("cloud-run-request/v1", "request.json", 0),
            ("cloud-preview/v1", "preview.json", 1),
            ("cloud-authorization-receipt/v1", "receipt.json", 2),
        ):
            original = json.loads((self.root / path).read_bytes())
            fields = ["run_id", "unit_id", "provider", "scope"]
            if ref_index == 0:
                fields += [
                    "owner",
                    "binding_id",
                    "environment",
                    "source_revision",
                    "verification_profile",
                    "policy",
                ]
            if ref_index == 1:
                fields += [
                    "preview_identity",
                    "semantic_sha256",
                    "request",
                    "dependency_lock",
                    "policy",
                    "verification_profile",
                ]
            if ref_index == 2:
                fields += [
                    "request",
                    "preview",
                    "dependency_lock",
                    "policy",
                    "verification_profile",
                ]
            for key in fields:
                bad = copy.deepcopy(original)
                if key == "scope":
                    bad[key]["region"] = "different-region"
                elif isinstance(bad[key], dict):
                    bad[key]["sha256"] = "b" * 64
                elif key in ("source_revision", "semantic_sha256"):
                    bad[key] = "b" * len(bad[key])
                else:
                    bad[key] = "different"
                changed = list(refs)
                changed[ref_index] = self.put(path, bad)
                with (
                    self.subTest(schema=schema, key=key),
                    self.assertRaises(self.c.ContractError),
                ):
                    self.bound(changed)
                self.put(path, original)
        with self.assertRaises(self.c.ContractError):
            self.c.verify_binding(self.root, *refs, now=END)

    def test_lock_closure_versions_packages_schemas_and_adapter(self):
        self.make_bundle()
        lock = json.loads((self.root / "lock.json").read_bytes())
        kwargs = dict(
            consumed_paths=["upstream/main.md", "upstream/child.md"],
            tools=copy.deepcopy(lock["tools"]),
            adapter_version="1.0.0",
            tool_schemas={"https://example.invalid/mcp": ref("tool.json")["sha256"]},
        )
        self.c.verify_lock(self.root, lock, **kwargs)
        for key, value in [
            ("consumed_paths", ["upstream/main.md"]),
            ("consumed_paths", kwargs["consumed_paths"] + ["upstream/unlocked.md"]),
            ("tools", []),
            ("adapter_version", "2.0.0"),
            ("tool_schemas", {}),
            ("tool_schemas", {"https://example.invalid/mcp": "b" * 64}),
        ]:
            with self.subTest(key=key), self.assertRaises(self.c.ContractError):
                self.c.verify_lock(self.root, lock, **dict(kwargs, **{key: value}))
        for key in ("version", "sha256"):
            bad = copy.deepcopy(kwargs)
            bad["tools"][0][key] = "2.2.2" if key == "version" else "b" * 64
            with self.assertRaises(self.c.ContractError):
                self.c.verify_lock(self.root, lock, **bad)
        for target in ("upstream/missing.md", "elsewhere.md", "../escape"):
            bad = copy.deepcopy(lock)
            bad["upstream"][0]["files"][0]["references"] = [target]
            with self.assertRaises(self.c.ContractError):
                self.c.verify_lock(self.root, bad, **kwargs)
        bad = copy.deepcopy(lock)
        bad["upstream"][0]["files"].append(
            copy.deepcopy(bad["upstream"][0]["files"][0])
        )
        with self.assertRaises(self.c.ContractError):
            self.c.verify_lock(self.root, bad, **kwargs)

    def test_safe_reader_rejects_symlinks_hardlinks_and_nonfiles(self):
        (self.root / "real").mkdir()
        (self.root / "real/x").write_bytes(b"fixture")
        (self.root / "alias").symlink_to(self.root / "real", target_is_directory=True)
        (self.root / "link").symlink_to(self.root / "real/x")
        os.link(self.root / "real/x", self.root / "hard")
        for path in ("alias/x", "link", "hard", "real", "missing"):
            with self.subTest(path=path), self.assertRaises(self.c.ContractError):
                self.c.read_verified(self.root, ref(path))
        with self.assertRaises(self.c.ContractError):
            self.c.read_verified(self.root / "alias", ref("x"))
        os.mkfifo(self.root / "fifo")
        with self.assertRaises(self.c.ContractError):
            self.c.read_verified(self.root, ref("fifo"))

    def test_publication_atomic_no_overwrite_containment_and_scan_failure(self):
        value = self.f["cloud-input-error/v1"]
        data = encode(value)
        self.c.publish_artifact(self.root, "new.json", data, scan=lambda b: True)
        self.assertEqual((self.root / "new.json").read_bytes(), data)
        with self.assertRaises(self.c.ContractError):
            self.c.publish_artifact(self.root, "new.json", data, scan=lambda b: True)
        (self.root / "alias").symlink_to(self.root, target_is_directory=True)
        for path in ("alias/out.json", "../escape.json"):
            with self.assertRaises(self.c.ContractError):
                self.c.publish_artifact(self.root, path, data, scan=lambda b: True)
        canary = "canary-" + "do-not-publish-482"
        bad = encode(dict(value, message=canary))
        for scanner in (lambda b: False, lambda b: None, lambda b: 1):
            with self.assertRaises(self.c.ContractError):
                self.c.publish_artifact(self.root, "secret.json", bad, scan=scanner)
            self.assertFalse((self.root / "secret.json").exists())

        def broken(_):
            raise RuntimeError(canary)

        with self.assertRaises(self.c.ContractError) as caught:
            self.c.publish_artifact(self.root, "secret.json", bad, scan=broken)
        self.assertNotIn(canary, str(caught.exception))
        self.assertEqual(
            sorted(p.name for p in self.root.iterdir()), ["alias", "new.json"]
        )

    def test_result_exit_mapping_and_invalid_identity(self):
        original = self.f["cloud-operation-result/v1"]
        for result, state, code in [
            ("PASS", "LOCAL_VALIDATED", 0),
            ("NO_CHANGE", "NO_CHANGE", 0),
            ("BLOCKED", "BLOCKED", 2),
            ("FAIL", "FAILED", 1),
            ("UNKNOWN", "UNKNOWN", 3),
        ]:
            value = dict(
                original,
                result=result,
                state=state,
                error_code=None if code == 0 else "ERROR",
            )
            self.both(value, True)
            self.assertEqual(self.c.exit_code(value), code)
            self.both(dict(value, state="Done"), False)
            self.both(dict(value, error_code="ERROR" if code == 0 else None), False)
        self.both(
            dict(
                original,
                result="NO_CHANGE",
                state="NO_CHANGE",
                error_code=None,
                native_operation_id="fake",
            ),
            False,
        )
        self.both(dict(original, result="PASS", state="FAILED", error_code=None), False)
        for bad in ("", None, "../run", "run\n"):
            self.rejects(dict(original, run_id=bad))
        error = self.c.input_error("INVALID_INPUT", "run_id")
        self.both(error, True)
        self.assertEqual(self.c.exit_code(error), 2)
        self.assertEqual(set(error), {"schema", "error_code", "message", "field"})

    def test_verification_inconsistent_claims_and_duplicate_checks(self):
        original = self.f["cloud-verification/v1"]
        for result in ("FAIL", "BLOCKED"):
            bad = copy.deepcopy(original)
            bad["checks"][0]["result"] = result
            self.rejects(bad)
        for field in ("checks", "required_check_ids"):
            bad = copy.deepcopy(original)
            bad[field] *= 2
            self.rejects(bad)
        bad = copy.deepcopy(original)
        bad["checks"][0]["check_id"] = "other"
        self.rejects(bad)
        self.rejects(dict(original, overall_result="FAIL", evidence_complete=True))

    def test_read_artifact_checks_observation_and_verification_references(self):
        observation = self.f["cloud-observation/v1"]
        (self.root / "query.json").write_bytes(b"fixture")
        observation_ref = self.put("observation.json", observation)
        self.assertEqual(self.c.read_artifact(self.root, observation_ref), observation)
        (self.root / "query.json").write_bytes(b"drift")
        with self.assertRaises(self.c.ContractError):
            self.c.read_artifact(self.root, observation_ref)
        (self.root / "query.json").write_bytes(b"fixture")
        verification = self.f["cloud-verification/v1"]
        verification["checks"][0]["observation"] = observation_ref
        (self.root / "profile.json").write_bytes(b"fixture")
        verification_ref = self.put("verification.json", verification)
        self.assertEqual(
            self.c.read_artifact(self.root, verification_ref), verification
        )
        (self.root / "observation.json").write_bytes(b"drift")
        with self.assertRaises(self.c.ContractError):
            self.c.read_artifact(self.root, verification_ref)

    def test_prepare_binding_does_not_invent_preview(self):
        self.make_bundle()
        request = json.loads((self.root / "request.json").read_bytes())
        request["operation"] = "prepare"
        request_ref = self.put("request.json", request)
        receipt = json.loads((self.root / "receipt.json").read_bytes())
        receipt.update(operation="prepare", request=request_ref, preview=None)
        receipt_ref = self.put("receipt.json", receipt)
        self.c.verify_binding(self.root, request_ref, None, receipt_ref, now=NOW)
        receipt["ci"]["environment"] = "other"
        receipt_ref = self.put("receipt.json", receipt)
        with self.assertRaises(self.c.ContractError):
            self.c.verify_binding(self.root, request_ref, None, receipt_ref, now=NOW)

    def test_large_numbers_bounded_payloads_and_unpaired_unicode(self):
        for raw in (
            b'{"n":' + b"9" * 5000 + b"}",
            b" " * (self.c.MAX_BYTES + 1),
            encode(dict(self.f["cloud-input-error/v1"], message=chr(0xD800))),
        ):
            with self.assertRaises(self.c.ContractError):
                self.c.parse_artifact(raw)
        bad = copy.deepcopy(self.f["cloud-dependency-lock/v1"])
        with self.assertRaises(self.c.ContractError):
            self.c.verify_lock(
                self.root,
                bad,
                consumed_paths=["upstream/main.md", "upstream/child.md"],
                tools=[{}],
                adapter_version="1.0.0",
                tool_schemas={},
            )

    def test_scanner_receives_exact_bytes_and_no_secret_publication(self):
        canary = "synthetic-" + "secret-canary-924"
        safe = encode(self.f["cloud-input-error/v1"])
        unsafe = encode(dict(self.f["cloud-input-error/v1"], message=canary))
        seen = []

        def scan(data):
            seen.append(data)
            return canary.encode() not in data

        self.c.publish_artifact(self.root, "safe.json", safe, scan=scan)
        with self.assertRaises(self.c.ContractError):
            self.c.publish_artifact(self.root, "unsafe.json", unsafe, scan=scan)
        self.assertEqual(seen, [safe, unsafe])
        self.assertFalse((self.root / "unsafe.json").exists())
        self.assertNotIn(canary.encode(), (self.root / "safe.json").read_bytes())

    def test_concurrent_publication_has_one_complete_winner(self):
        from concurrent.futures import ThreadPoolExecutor

        values = [
            encode(dict(self.f["cloud-input-error/v1"], message="writer-" + str(i)))
            for i in range(8)
        ]

        def publish(data):
            try:
                self.c.publish_artifact(
                    self.root, "winner.json", data, scan=lambda b: True
                )
                return data
            except self.c.ContractError:
                return None

        with ThreadPoolExecutor(max_workers=8) as pool:
            winners = [data for data in pool.map(publish, values) if data is not None]
        self.assertEqual(len(winners), 1)
        self.assertEqual((self.root / "winner.json").read_bytes(), winners[0])
        self.assertEqual([p.name for p in self.root.iterdir()], ["winner.json"])

    def test_unavailable_safe_filesystem_primitives_fail_closed(self):
        from unittest.mock import patch

        with patch.object(os, "supports_dir_fd", set()):
            with self.assertRaises(self.c.ContractError):
                self.c.read_verified(self.root, ref("x"))
            with self.assertRaises(self.c.ContractError):
                self.c.publish_artifact(
                    self.root,
                    "x",
                    encode(self.f["cloud-input-error/v1"]),
                    scan=lambda b: True,
                )
        self.assertEqual(list(self.root.iterdir()), [])

    def test_schema_scalar_domains_and_optional_field_boundaries(self):
        for kind, original in self.f.items():
            schema = self.schema(kind)
            for path, value in nodes(original):
                if not path or isinstance(value, (dict, list)) or path[-1] == "schema":
                    continue
                fragment = schema
                for key in path:
                    if "oneOf" in fragment and "properties" not in fragment:
                        fragment = next(
                            branch
                            for branch in fragment["oneOf"]
                            if branch.get("type") != "null"
                        )
                    fragment = (
                        fragment["items"]
                        if type(key) is int
                        else fragment["properties"][key]
                    )
                candidates = []
                if "enum" in fragment:
                    candidates = ["not-a-member", "", value.lower(), value + "X"]
                elif "pattern" in fragment:
                    candidates = [
                        "",
                        value + "\n",
                        value + " ",
                        value + "/",
                        "x" * 3000,
                    ]
                for candidate in candidates:
                    bad = copy.deepcopy(original)
                    at(bad, path[:-1])[path[-1]] = candidate
                    schema_valid = not self.oracle._schema_validate(schema, bad)
                    with self.subTest(kind=kind, path=path, candidate=candidate[:30]):
                        # Some independent semantic checks are strictly stronger than
                        # JSON Schema (e.g. dates and unique IDs); never weaker.
                        if not schema_valid:
                            self.rejects(bad)
        for field in ("issuer",):
            for url in (
                "https://example.invalid/../escape",
                "https://example.invalid/./x",
                "https://user:pass@example.invalid/x",
                "http://example.invalid/x",
            ):
                bad = dict(self.f["cloud-authorization-receipt/v1"], **{field: url})
                self.both(bad, False)
        request = copy.deepcopy(self.f["cloud-run-request/v1"])
        request["predecessor_receipts"] = [dict(unit_id="prior", **ref("prior.json"))]
        self.both(request, True)
        for field in ("unit_id", "path", "sha256"):
            bad = copy.deepcopy(request)
            del bad["predecessor_receipts"][0][field]
            self.both(bad, False)
        extra: object
        for extra in (None, 7, {}, ""):
            self.both(
                dict(self.f["cloud-operation-result/v1"], native_operation_id=extra),
                False,
            )
        self.both(
            dict(self.f["cloud-operation-result/v1"], native_operation_id="native-1"),
            True,
        )

    def test_schema_published_limits_have_executable_runtime_counterparts(self):
        original = self.f["cloud-observation/v1"]
        schema = self.schema(original["schema"])
        self.assertEqual(schema["properties"]["exit_code"]["maximum"], 2147483647)
        self.assertEqual(schema["properties"]["resource_ids"]["maxItems"], 4096)
        self.assertEqual(schema["properties"]["timestamp"]["format"], "date-time")
        self.c.parse_artifact(
            encode(dict(original, status="FAIL", exit_code=2147483647))
        )
        for value in (-1, 2147483648):
            self.rejects(dict(original, exit_code=value))
        self.c.parse_artifact(
            encode(dict(original, resource_ids=["r" + str(i) for i in range(4096)]))
        )
        self.rejects(dict(original, resource_ids=["r" + str(i) for i in range(4097)]))
        for field, size in (("run_id", 128), ("query", 2048)):
            self.both(dict(original, **{field: "x" * size}), True)
            self.both(dict(original, **{field: "x" * (size + 1)}), False)
        with self.assertRaises(self.c.ContractError):
            self.c.parse_artifact(b'{"x":1,"\\u0078":2}')

    def test_schema_inventory_has_no_open_object_or_unexercised_family(self):
        expected = {kind.split("/")[0] + ".schema.json" for kind in self.f}
        self.assertEqual(
            {p.name for p in (ROOT / "contracts").glob("cloud-*.schema.json")}, expected
        )
        for kind in self.f:
            schema = self.schema(kind)
            for path, node in nodes(schema):
                if isinstance(node, dict) and node.get("type") == "object":
                    self.assertIs(node.get("additionalProperties"), False, (kind, path))
                    optional = (
                        {"native_operation_id"}
                        if kind == "cloud-operation-result/v1" and not path
                        else {"local_context"} if kind == "cloud-run-request/v1" and not path
                        else set()
                    )
                    self.assertEqual(
                        set(node["required"]),
                        set(node["properties"]) - optional,
                        (kind, path),
                    )
            self.assertEqual(schema["properties"]["schema"]["const"], kind)
        self.assertEqual(set(self.c.VALIDATORS), set(self.f))

    def test_explicit_preview_and_receipt_mismatches_without_stale_outer_hash(self):
        refs = self.make_bundle()
        preview = json.loads((self.root / "preview.json").read_bytes())
        for field, value in (
            ("run_id", "other-run"),
            ("unit_id", "other-unit"),
            ("provider", "azure"),
            ("semantic_sha256", "b" * 64),
            ("created_at", "2026-10-18T06:30:00Z"),
        ):
            changed = dict(preview, **{field: value})
            changed_ref = self.put("preview.json", changed)
            with self.subTest(field=field), self.assertRaises(self.c.ContractError):
                self.c.verify_binding(self.root, refs[0], changed_ref, None, now=NOW)
        scope = copy.deepcopy(preview)
        scope["scope"]["account_id"] = "other-account"
        changed_ref = self.put("preview.json", scope)
        with self.assertRaises(self.c.ContractError):
            self.c.verify_binding(self.root, refs[0], changed_ref, None, now=NOW)
        self.put("preview.json", preview)
        receipt = json.loads((self.root / "receipt.json").read_bytes())
        for fields in (
            {"issued_at": "2026-10-18T06:30:00Z"},
            {"issued_at": "2026-10-18T05:00:00Z", "expires_at": NOW},
            {"operation": "prepare"},
        ):
            changed_ref = self.put("receipt.json", dict(receipt, **fields))
            with self.subTest(fields=fields), self.assertRaises(self.c.ContractError):
                self.c.verify_binding(self.root, refs[0], refs[1], changed_ref, now=NOW)
        with self.assertRaises(self.c.ContractError):
            self.c.verify_binding(self.root, refs[0], None, None, now=NOW)

    def test_input_alias_output_and_expected_type_are_rejected(self):
        data = encode(self.f["cloud-input-error/v1"])
        original = self.put("input.json", self.f["cloud-input-error/v1"])
        (self.root / "link.json").symlink_to(self.root / "input.json")
        for path in ("input.json", "link.json"):
            with self.assertRaises(self.c.ContractError):
                self.c.publish_artifact(self.root, path, data, scan=lambda b: True)
        self.assertEqual((self.root / "input.json").read_bytes(), data)
        with self.assertRaises(self.c.ContractError):
            self.c.read_artifact(self.root, original, "cloud-run-request/v1")
        with self.assertRaises(self.c.ContractError):
            self.c.read_verified(self.root, dict(original, sha256="b" * 64))
        self.assertEqual(self.c.read_verified(self.root, original), data)


    def test_repair_local_context_schema_and_each_field(self):
        request = install_local_context(self.root, fixtures()["cloud-run-request/v1"])
        self.both(request, True)
        for path, node in nodes(request["local_context"]):
            full = ("local_context",) + path
            if isinstance(node, dict):
                for key in list(node) + ["unknown"]:
                    bad = copy.deepcopy(request)
                    if key == "unknown":
                        at(bad, full)[key] = True
                    else:
                        del at(bad, full)[key]
                    self.both(bad, False)
            elif not isinstance(node, list):
                bad = copy.deepcopy(request)
                at(bad, full[:-1])[full[-1]] = {}
                self.both(bad, False)
        for field, value in [("workspace_anchor", "HOME"), ("task_id", "T-2"),
                             ("artifact_root", "../escape"), ("feature", "a/b"),
                             ("unit_roots", [])]:
            bad = copy.deepcopy(request)
            bad["local_context"][field] = value
            self.both(bad, False)

        bad = copy.deepcopy(request)
        bad["local_context"]["unit_roots"] *= 2
        self.rejects(bad)  # existing structural oracle does not implement uniqueItems
        self.assertTrue(self.schema(request["schema"])["properties"]["local_context"]["properties"]["unit_roots"]["uniqueItems"])

    def test_repair_discovery_and_honest_unpublished_errors(self):
        for owner in (None, "terraform", "sam", "cloudformation", "azd", "bicep", "cdk"):
            request = dict(fixtures()["cloud-run-request/v1"], operation="route", owner=owner, route=None)
            self.both(request, True)
            self.both(dict(request, operation="apply"), False)
        original = self.f["cloud-operation-result/v1"]
        for result, state in [("BLOCKED", "BLOCKED"), ("FAIL", "FAILED")]:
            good = dict(original, result=result, state=state, evidence_manifest_path=None)
            self.both(good, True)
            self.both(dict(good, native_operation_id="submitted"), False)
        for result, state in [("PASS", "PLANNED"), ("NO_CHANGE", "NO_CHANGE"), ("UNKNOWN", "UNKNOWN")]:
            self.both(dict(original, result=result, state=state,
                error_code="UNCERTAIN" if result == "UNKNOWN" else None, evidence_manifest_path=None), False)

    def test_repair_explicit_phase_preserves_legacy_integrity_api(self):
        from unittest.mock import patch
        request = install_local_context(self.root, fixtures()["cloud-run-request/v1"])
        rr = self.put("request.json", request)
        with patch.dict(os.environ, {"CLOUD_WORKSPACE_ROOT": str(self.root)}):
            self.c.verify_binding(self.root, rr, None, now=NOW, operation="prepare")
            with self.assertRaises(self.c.ContractError):
                self.c.verify_binding(self.root, rr, None, now=NOW, operation="apply")
            with self.assertRaises(self.c.ContractError):
                self.c.verify_binding(self.root, rr, None, now=NOW, operation="route")

    def test_repair_physical_workspace_and_declared_boundary(self):
        from unittest.mock import patch
        request = install_local_context(self.root, fixtures()["cloud-run-request/v1"])
        with patch.dict(os.environ, {"CLOUD_WORKSPACE_ROOT": str(self.root)}):
            self.assertEqual(self.c.workspace_root(), self.root)
            files = self.c.verify_local_context(self.root, request, execution=True)
            self.assertIn("bundle/unit/source.bin", files)
            # A real recursive scan must expose undeclared conflicting metadata to the router.
            (self.root / "bundle/unit/nested").mkdir()
            (self.root / "bundle/unit/nested/main.tf").write_text("synthetic")
            self.assertIn("bundle/unit/nested/main.tf", self.c.verify_local_context(self.root, request))
            for field, value in [("artifact_root", "other"), ("unit_roots", ["outside"]),
                                 ("evidence_directory", "bundle/unit"),
                                 ("evidence_directory", "specs/wrong/verification/T-002/cloud/run-1/unit-1")]:
                bad = copy.deepcopy(request)
                bad["local_context"][field] = value
                with self.assertRaises(self.c.ContractError):
                    self.c.verify_local_context(self.root, bad)
            link = self.root / "bundle/unit/link"
            link.symlink_to(self.root / "bundle/unit/source.bin")
            with self.assertRaises(self.c.ContractError):
                self.c.verify_local_context(self.root, request)
            link.unlink()
            for field in ("ownership", "provider_config"):
                dest = self.root / request["local_context"][field]["path"]
                data = dest.read_bytes()
                dest.write_bytes(data + b" ")
                with self.assertRaises(self.c.ContractError):
                    self.c.verify_local_context(self.root, request)
                dest.write_bytes(data)
        for value in ("", "relative", str(self.root / "..")):
            with patch.dict(os.environ, {"CLOUD_WORKSPACE_ROOT": value}):
                with self.assertRaises(self.c.ContractError):
                    self.c.workspace_root()
        link = self.root / "workspace-link"
        link.symlink_to(self.root, target_is_directory=True)
        with patch.dict(os.environ, {"CLOUD_WORKSPACE_ROOT": str(link)}):
            with self.assertRaises(self.c.ContractError):
                self.c.workspace_root()



    def test_repair_workspace_control_bytes_are_typed_blocked(self):
        from unittest.mock import patch
        for value in (str(self.root) + "\x00", str(self.root) + "\n", "/", str(self.root) + "//"):
            with self.subTest(value=repr(value)), patch.dict(os.environ, {"CLOUD_WORKSPACE_ROOT": value}):
                with self.assertRaises(self.c.ContractError):
                    self.c.workspace_root()

    def test_repair_context_cross_artifact_controls(self):
        from unittest.mock import patch
        request = install_local_context(self.root, fixtures()["cloud-run-request/v1"])
        with patch.dict(os.environ, {"CLOUD_WORKSPACE_ROOT": str(self.root)}):
            # Rehash edited bodies so these exercise semantic checks, not stale outer hashes.
            for body_field, mutation in [
                ("policy", lambda b: b["allowed_scopes"][0].update(region="wrong")),
                ("verification_profile", lambda b: b.update(id="wrong")),
                ("verification_profile", lambda b: b.update(required_check_ids=["network"])),
                ("ownership", lambda b: b["owners"][0].update(root="outside")),
                ("ownership", lambda b: b["owners"].append(dict(owner="terraform", root="bundle/unit"))),
            ]:
                bad = copy.deepcopy(request)
                container = bad["local_context"] if body_field == "ownership" else bad
                dest = self.root / container[body_field]["path"]
                original = dest.read_bytes()
                value = json.loads(original)
                mutation(value)
                raw = encode(value)
                dest.write_bytes(raw)
                container[body_field]["sha256"] = hashlib.sha256(raw).hexdigest()
                with self.subTest(body=body_field), self.assertRaises(self.c.ContractError):
                    self.c.verify_local_context(self.root, bad, execution=True)
                dest.write_bytes(original)
            for field in ("policy", "dependency_lock", "verification_profile"):
                bad = copy.deepcopy(request)
                data = (self.root / bad[field]["path"]).read_bytes()
                (self.root / "outside.json").write_bytes(data)
                bad[field]["path"] = "outside.json"
                with self.subTest(ref=field), self.assertRaises(self.c.ContractError):
                    self.c.verify_local_context(self.root, bad)
            # Recursive dependency references are not exempt from the declared artifact root.
            bad = copy.deepcopy(request)
            lock_path = self.root / bad["dependency_lock"]["path"]
            original = lock_path.read_bytes()
            lock = json.loads(original)
            lock["upstream"][0]["root"] = "outside"
            for f in lock["upstream"][0]["files"]:
                f["path"] = f["path"].replace("bundle/upstream", "outside")
                f["references"] = [r.replace("bundle/upstream", "outside") for r in f["references"]]
                dest = self.root / f["path"]
                dest.parent.mkdir(exist_ok=True)
                dest.write_bytes(b"fixture")
            lock_path.write_bytes(encode(lock))
            bad["dependency_lock"]["sha256"] = hashlib.sha256(encode(lock)).hexdigest()
            with self.assertRaises(self.c.ContractError):
                self.c.verify_local_context(self.root, bad)
            lock_path.write_bytes(original)
            # Existing evidence ancestors and scan directories cannot be links.
            evidence = self.root / request["local_context"]["evidence_directory"]
            evidence.rmdir()
            evidence.symlink_to(self.root / "bundle", target_is_directory=True)
            with self.assertRaises(self.c.ContractError):
                self.c.verify_local_context(self.root, request)
            evidence.unlink()
            link = self.root / "bundle/unit/nested-link"
            link.symlink_to(self.root / "bundle", target_is_directory=True)
            with self.assertRaises(self.c.ContractError):
                self.c.verify_local_context(self.root, request)
            link.unlink()
            link = self.root / "bundle/unit/linked-file"
            os.link(self.root / "bundle/unit/source.bin", link)
            with self.assertRaises(self.c.ContractError):
                self.c.verify_local_context(self.root, request)

    def test_repair_phase_receipt_and_evidence_path_controls(self):
        from unittest.mock import patch
        request = install_local_context(self.root, fixtures()["cloud-run-request/v1"])
        rr = self.put("request.json", request)
        evidence = request["local_context"]["evidence_directory"]
        changes = self.put(evidence + "/changes.json", {"synthetic": True})
        preview = dict(fixtures()["cloud-preview/v1"], request=rr,
            dependency_lock=request["dependency_lock"], policy=request["policy"],
            verification_profile={k: request["verification_profile"][k] for k in ("path", "sha256")},
            changes=changes, semantic_sha256=changes["sha256"])
        pr = self.put(evidence + "/preview.json", preview)
        receipt = dict(fixtures()["cloud-authorization-receipt/v1"], request=rr, preview=pr,
            dependency_lock=request["dependency_lock"], policy=request["policy"],
            verification_profile=preview["verification_profile"])
        receipt["ci"]["environment"] = "sandbox-apply"
        ar = self.put(evidence + "/receipt.json", receipt)
        with patch.dict(os.environ, {"CLOUD_WORKSPACE_ROOT": str(self.root)}):
            self.c.verify_binding(self.root, rr, pr, ar, now=NOW, operation="apply")
            with self.assertRaises(self.c.ContractError):
                self.c.verify_binding(self.root, rr, pr, ar, now=NOW)  # no implicit bound phase
            for case in ("stage", "preview-path", "receipt-path", "changes-path", "request-digest"):
                changed_pr, changed_ar = pr, ar
                if case == "stage":
                    changed_ar = self.put(evidence + "/wrong-stage.json", dict(receipt, operation="prepare"))
                elif case == "preview-path":
                    changed_pr = self.put("outside-preview.json", preview)
                    changed_ar = None
                elif case == "receipt-path":
                    changed_ar = self.put("outside-receipt.json", receipt)
                elif case == "changes-path":
                    changed = self.put("outside-changes.json", {"synthetic": True})
                    changed_pr = self.put(evidence + "/wrong-changes.json", dict(preview, changes=changed))
                    changed_ar = None
                else:
                    changed_pr = self.put(evidence + "/wrong-request.json", dict(preview, request=dict(rr, sha256="b" * 64)))
                    changed_ar = None
                with self.subTest(case=case), self.assertRaises(self.c.ContractError):
                    self.c.verify_binding(self.root, rr, changed_pr, changed_ar, now=NOW, operation="apply")


if __name__ == "__main__":
    unittest.main(verbosity=2)
