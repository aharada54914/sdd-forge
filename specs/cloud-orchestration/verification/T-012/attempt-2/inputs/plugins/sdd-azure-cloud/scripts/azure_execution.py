"""Governed Azure execution over T-004 frozen bytes; no compile, CLI or cloud engine.

Only a trusted caller constructs WriteBoundary. No deployment file, local flag or
receipt selects policy, transport or executable code. Azure what-if is not an
immutable server-side plan: exclusive writers and native CI concurrency remain
mandatory and cannot eliminate external drift between final preview and PUT.
"""

from __future__ import annotations

import sys
from pathlib import Path
import time
from typing import Callable
import uuid

from cloud import (
    c,
    decode,
    digest,
    encode,
    detect_owner,
    output_path,
    publish_json,
    safe_publication,
    read_bytes,
)
from azure_arm import ArmClient, HttpsTransport, Response, Transport  # noqa: F401
from azure_graph import fields, flatten, resource_id, validate_graph
from azure_local import BINARY_SHA, VERSION, local_policy, source_snapshot, upstream

# Resolve admission from the trusted sibling plugin, never deployment input/PYTHONPATH.
SHARED = Path(__file__).resolve().parents[2] / "sdd-quality-loop/scripts"
sys.path.insert(0, str(SHARED))
from cloud_authorization import (  # noqa: E402
    WriteBoundary,
    GitHubAdmission,
    AzureIdentity,
    utc,
    AdmissionDenied,
    epoch,
)


def exact_artifacts(
    root: Path, request_ref: dict
) -> tuple[dict, bytes, dict, list[dict], dict]:
    request = c.read_artifact(root, request_ref, "cloud-run-request/v1")
    c._require(request["provider"] == "azure", "PROVIDER_MISMATCH")
    files = c.verify_local_context(root, request, execution=True)
    ownership = detect_owner(root, request, files)
    cfg, parameters = local_policy(root, request)
    source_snapshot(root, request, files, cfg)
    # Verify the frozen tool record against the reviewed T-004 compiler pin. The
    # compiler is not used here, so installing/executing it would add attack surface.
    upstream(root, request, cfg, dict(name="bicep", version=VERSION, sha256=BINARY_SHA))
    compiled = [a for a in request["input_artifacts"] if a["kind"] == "compiled"]
    c._require(len(compiled) == 1, "COMPILED_ARTIFACT_REQUIRED")
    template = c.read_verified(root, c._file_ref(compiled[0]))
    policy = c.read_artifact(root, request["policy"], "cloud-deployment-policy/v1")
    arm = decode(template)
    validate_graph(arm, parameters, request, policy, ownership)
    resources = flatten(
        arm, parameters, request["scope"], set(policy["allowed_resource_types"])
    )
    param_ref = next(
        a for a in request["input_artifacts"] if a["path"] == cfg["parameters"]
    )
    native_parameters = decode(c.read_verified(root, c._file_ref(param_ref)))[
        "parameters"
    ]
    return request, template, native_parameters, resources, ownership


def property_changes(value: list, depth: int = 0) -> list:
    c._require(
        type(value) is list and len(value) <= 4096 and depth <= 32,
        "PREVIEW_SHAPE_UNSUPPORTED",
    )
    result = []
    for change in value:
        fields(change, {"path", "propertyChangeType"}, {"before", "after", "children"})
        c._text(change["path"])
        kind = change["propertyChangeType"]
        c._require(
            kind in ("Create", "Modify", "Array", "NoEffect"), "PROPERTY_CHANGE_DENIED"
        )
        if kind == "Create":
            c._require(
                "after" in change and change.get("before") is None,
                "PROPERTY_CHANGE_AMBIGUOUS",
            )
        if kind == "Modify":
            c._require(
                "before" in change and "after" in change, "PROPERTY_CHANGE_AMBIGUOUS"
            )
        normalized = dict(change)
        if "children" in change:
            normalized["children"] = property_changes(change["children"], depth + 1)
        c._require(
            kind != "Array" or bool(change.get("children")), "PROPERTY_CHANGE_AMBIGUOUS"
        )
        result.append(normalized)
    c._unique([v["path"] for v in result])
    return sorted(result, key=lambda v: v["path"])


def normalize_preview(
    value: dict, request: dict, resources: list[dict], ownership: dict
) -> dict:
    """Closed 2025-04-01 semantics. Unknown/potential/diagnostic content never vanishes."""
    fields(value, {"status", "properties"}, {"error"})
    c._require(
        value["status"] == "Succeeded" and value.get("error") is None, "WHAT_IF_FAILED"
    )
    props = value["properties"]
    fields(props, {"changes"}, {"potentialChanges", "diagnostics"})
    c._require(
        props.get("potentialChanges", []) == [] and props.get("diagnostics", []) == [],
        "WHAT_IF_INCOMPLETE",
    )
    c._require(
        type(props["changes"]) is list and len(props["changes"]) <= 4096,
        "PREVIEW_SHAPE_UNSUPPORTED",
    )
    expected = {
        r.get("scope", "") + "/providers/" + r["type"] + "/" + r["name"]
        if "scope" in r
        else resource_id(request["scope"], r["type"], r["name"])
        for r in resources
    }
    referenced = {r["resource_id"] for r in ownership["existing_resources"]}
    normalized = []
    for change in props["changes"]:
        fields(
            change,
            {"resourceId", "changeType"},
            {"before", "after", "delta", "deploymentId", "symbolicName"},
        )
        rid, kind = change["resourceId"], change["changeType"]
        c._require(rid in expected | referenced, "PREVIEW_RESOURCE_DENIED")
        c._require(kind in ("Create", "Modify", "NoChange"), "RESOURCE_CHANGE_DENIED")
        c._require(
            rid not in referenced or kind == "NoChange", "REFERENCED_RESOURCE_MUTATION"
        )
        if kind == "Create":
            c._require(
                type(change.get("after")) is dict and change.get("before") is None,
                "PREVIEW_AMBIGUOUS",
            )
        if kind == "Modify":
            c._require(
                type(change.get("before")) is dict
                and type(change.get("after")) is dict
                and bool(change.get("delta")),
                "PREVIEW_AMBIGUOUS",
            )
        if kind == "NoChange":
            c._require(
                not change.get("delta") and change.get("before") == change.get("after"),
                "PREVIEW_AMBIGUOUS",
            )
        item = dict(change)
        item["delta"] = property_changes(change.get("delta", []))
        for key in ("deploymentId", "symbolicName"):
            if key in item:
                c._text(item[key])
        normalized.append(item)
    c._unique([item["resourceId"].lower() for item in normalized])
    return dict(changes=sorted(normalized, key=lambda item: item["resourceId"]))


class AzureExecutor:
    def __init__(
        self,
        root: Path,
        request_ref: dict,
        boundary: WriteBoundary,
        *,
        arm: Transport | None = None,
        clock: Callable[[], float] = time.time,
        sleep: Callable[[float], None] = time.sleep,
    ):
        self.root, self.request_ref, self.boundary, self.clock = (
            root,
            dict(request_ref),
            boundary,
            clock,
        )
        self.request = c.read_artifact(root, request_ref, "cloud-run-request/v1")
        self.directory = self.request["local_context"]["evidence_directory"]
        self.name = "sdd-" + request_ref["sha256"][:60]
        self.request_id = str(
            uuid.uuid5(uuid.NAMESPACE_URL, "azure:" + request_ref["sha256"])
        )
        self.client = ArmClient(
            self.request["scope"], self.name, arm or HttpsTransport(), sleep=sleep
        )
        self.credentials: dict[str, str] = {}
        self.preview_ref: dict | None = None
        self.submission: dict | None = None
        self.may_have_submitted = False
        self.output_ready = False
        self.pending_native_id = self.client.native_id

    def check(self) -> tuple[dict, bytes, dict, list[dict], dict]:
        data = exact_artifacts(self.root, self.request_ref)
        c._require(data[0] == self.request, "REQUEST_CHANGED")
        c._require(self.boundary.policy.provider == "azure", "PROVIDER_MISMATCH")
        return data

    def body(self, data: tuple, *, preview: bool) -> bytes:
        properties = dict(
            template=data[1].decode("utf-8"), parameters=data[2], mode="Incremental"
        )
        if preview:
            properties.update(
                validationLevel="ProviderNoRbac",
                whatIfSettings=dict(resultFormat="FullResourcePayloads"),
            )
        return encode(dict(properties=properties))

    def audit(self, path: str, value: dict) -> dict:
        return publish_json(self.root, path, value)

    def mutate(
        self,
        method: str,
        url: str,
        body: bytes,
        mutation: str,
        preview_ref: dict | None,
        *,
        semantic: dict | None = None,
    ) -> tuple[dict, Response]:
        def submit(credentials: dict[str, str]) -> Response:
            # Read only the receipt this WriteBoundary just exclusively published;
            # imported receipts cannot reach this callback. Its deadline is the
            # minimum of OIDC, provider, policy TTL and (apply) preview expiry.
            receipt_path = (
                self.directory
                + "/"
                + self.request["unit_id"]
                + "."
                + self.boundary.policy.operation
                + "."
                + mutation
                + ".authorization.json"
            )
            receipt_bytes = read_bytes(self.root, receipt_path)
            receipt = c.parse_artifact(receipt_bytes, "cloud-authorization-receipt/v1")
            deadline = epoch(receipt["expires_at"])
            # The authenticated boundary just rechecked policy/approval. These final
            # pure checks additionally cover actual owner roots and provider closure.
            data = self.check()
            c._require(self.body(data, preview=method == "POST") == body, "INPUT_DRIFT")
            if semantic is not None:
                self.check_preview(preview_ref, semantic, data)
            self.credentials = credentials
            self.pending_native_id = self.client.native_id if method == "PUT" else url
            if method == "PUT":
                self.submission = self.audit(
                    self.directory + "/deployment-submission.json",
                    dict(
                        schema="azure-submission/v1",
                        request=self.request_ref,
                        preview=preview_ref,
                        native_operation_id=self.client.native_id,
                        request_id=self.request_id,
                        body_sha256=digest(body),
                        created_at=utc(int(self.clock())),
                        scope=self.request["scope"],
                        status="UNKNOWN",
                    ),
                )
            else:
                self.submission = self.audit(
                    self.directory + "/" + mutation + "-submission.json",
                    dict(
                        schema="azure-preview-submission/v1",
                        request=self.request_ref,
                        preview=preview_ref,
                        native_operation_id=url,
                        request_id=self.request_id,
                        body_sha256=digest(body),
                        created_at=utc(int(self.clock())),
                        scope=self.request["scope"],
                        status="UNKNOWN",
                    ),
                )
            # All local scans, hashing and durable journal publication finish before
            # this final bounded admission check. No filesystem work follows it.
            c.verify_binding(
                self.root,
                self.request_ref,
                preview_ref,
                now=utc(int(self.boundary.clock())),
                operation=self.boundary.policy.operation,
            )
            c._require(int(self.boundary.clock()) < deadline, "CREDENTIAL_EXPIRED")
            self.may_have_submitted = True
            return self.client.call(method, url, credentials, self.request_id, body)

        return self.boundary.write(
            self.root,
            self.request_ref,
            preview_ref,
            mutation_id=mutation,
            submit=submit,
            scan=safe_publication,
        )

    def what_if(self, preview_ref: dict | None) -> tuple[dict, dict]:
        data = self.check()
        receipt, response = self.mutate(
            "POST",
            self.client.url.replace("?", "/whatIf?"),
            self.body(data, preview=True),
            self.boundary.policy.operation + "-what-if",
            preview_ref,
        )
        native = self.client.finish(
            response, self.credentials, self.request_id, preview=True
        )
        # A completed what-if with unsupported semantics blocks apply, not an
        # unknown deployment. Transport/LRO failures above retain uncertainty.
        self.may_have_submitted = False
        normalized = normalize_preview(native, self.request, data[3], data[4])
        return receipt, normalized

    def check_preview(
        self, reference: dict | None, semantic: dict, data: tuple
    ) -> None:
        c._require(reference is not None, "PREVIEW_REQUIRED")
        c.verify_binding(
            self.root,
            self.request_ref,
            reference,
            now=utc(int(self.clock())),
            operation="apply",
        )
        preview = c.read_artifact(self.root, reference, "cloud-preview/v1")
        c._require(
            preview["preview_identity"] == self.client.url.replace("?", "/whatIf?"),
            "PREVIEW_ID_CHANGED",
        )
        changes = c.read_verified(self.root, preview["changes"])
        c._require(
            changes == encode(semantic)
            and preview["semantic_sha256"] == digest(changes)
            and preview["deletes"] == []
            and preview["replacements"] == [],
            "PREVIEW_DRIFT",
        )
        # Re-evaluate the persisted native semantics, not an unsigned PASS flag.
        normalize_preview(
            dict(status="Succeeded", properties=decode(changes)),
            self.request,
            data[3],
            data[4],
        )

    def result(
        self,
        phase: str,
        output: str,
        result: str,
        *,
        preview: dict | None = None,
        error: str | None = None,
        native: bool = False,
    ) -> dict:
        value = dict(
            schema="cloud-operation-result/v1",
            **{k: self.request[k] for k in ("run_id", "unit_id", "provider")},
            operation=phase,
            result=result,
            state={
                "PASS": "PREVIEW_READY" if phase == "prepare" else "OBSERVED",
                "FAIL": "FAILED",
            }.get(result, result),
            error_code=error,
            message="Native execution evidence only; resource health is not verified.",
            input_manifest_sha256=self.request_ref["sha256"],
            evidence_manifest_path=None,
        )
        if self.output_ready and (
            result != "BLOCKED" or self.submission is not None or preview is not None
        ):
            path = output + ".manifest.json"
            evidence = dict(
                schema="azure-execution-evidence/v1",
                request=self.request_ref,
                preview=preview,
                submission=self.submission,
                native_trace=self.client.trace,
                operation=phase,
                result=result,
                recorded_at=utc(int(self.clock())),
                health_verified=False,
            )
            try:
                self.audit(path, evidence)
                value["evidence_manifest_path"] = path
            except (OSError, ValueError):
                # Intent was fsynced BEFORE sending. Losing final publication cannot
                # erase uncertainty or the original identity, even on a full disk.
                if not self.may_have_submitted or self.submission is None:
                    raise
                value["evidence_manifest_path"] = self.submission["path"]
                value.update(result="UNKNOWN", state="UNKNOWN", error_code="EVIDENCE_PUBLICATION_FAILED")
        if native:
            value["native_operation_id"] = self.pending_native_id
        c.parse_artifact(encode(value), "cloud-operation-result/v1")
        if not self.output_ready:
            return value
        try:
            c.publish_artifact(self.root, output, encode(value), scan=safe_publication)
        except (OSError, ValueError):
            if not self.may_have_submitted:
                raise
        return value

    def failure(self, phase: str, output: str) -> dict:
        unknown = self.may_have_submitted
        return self.result(
            phase,
            output,
            "UNKNOWN" if unknown else "BLOCKED",
            error="ARM_OUTCOME_UNKNOWN" if unknown else "AZURE_EXECUTION_BLOCKED",
            native=unknown,
        )

    def prepare(self, output: str) -> dict:
        try:
            self.output_ready = False
            output_path(self.root, self.request, output)
            output_path(self.root, self.request, output + ".manifest.json")
            self.output_ready = True
            c._require(self.boundary.policy.operation == "prepare", "STAGE_MISMATCH")
            receipt, semantic = self.what_if(None)
            changes = self.audit(self.directory + "/preview-changes.json", semantic)
            now = int(self.clock())
            preview = dict(
                schema="cloud-preview/v1",
                **{
                    k: self.request[k]
                    for k in (
                        "run_id",
                        "unit_id",
                        "provider",
                        "scope",
                        "dependency_lock",
                        "policy",
                    )
                },
                request=self.request_ref,
                verification_profile=c._file_ref(self.request["verification_profile"]),
                preview_identity=self.client.url.replace("?", "/whatIf?"),
                semantic_sha256=changes["sha256"],
                changes=changes,
                replacements=[],
                deletes=[],
                created_at=utc(now),
                expires_at=utc(now + 300),
            )
            reference = c.publish_artifact(
                self.root,
                self.directory + "/preview.json",
                encode(preview),
                scan=safe_publication,
            )
            self.audit(
                self.directory + "/prepare-receipt.json",
                dict(authorization=receipt, preview=reference),
            )
            return self.result(
                "prepare",
                output,
                "NO_CHANGE" if self.no_change(semantic) else "PASS",
                preview=reference,
            )
        except Exception:
            return self.failure("prepare", output)

    @staticmethod
    def no_change(semantic: dict) -> bool:
        return all(change["changeType"] == "NoChange" for change in semantic["changes"])

    def apply(self, preview_ref: dict, output: str) -> dict:
        self.may_have_submitted = False
        try:
            self.output_ready = False
            output_path(self.root, self.request, output)
            output_path(self.root, self.request, output + ".manifest.json")
            self.output_ready = True
            c._require(self.boundary.policy.operation == "apply", "STAGE_MISMATCH")
            data = self.check()
            prior = c.read_artifact(self.root, preview_ref, "cloud-preview/v1")
            semantic = decode(c.read_verified(self.root, prior["changes"]))
            self.check_preview(preview_ref, semantic, data)
            # Marker belongs to the intent, not this process/output/CI attempt.
            with c._parent(
                self.root, self.directory + "/deployment-submission.json"
            ) as (fd, name):
                import os

                try:
                    os.stat(name, dir_fd=fd, follow_symlinks=False)
                except FileNotFoundError:
                    pass
                else:
                    raise AdmissionDenied("RECONCILE_REQUIRED")
            _, current = self.what_if(preview_ref)
            self.check_preview(preview_ref, current, self.check())
            if self.no_change(current):
                return self.result("apply", output, "NO_CHANGE", preview=preview_ref)
            # Native history is a second replay fence under the same CI scope lock.
            existing = self.client.call(
                "GET", self.client.url, self.credentials, self.request_id
            )
            c._require(existing.status == 404, "RECONCILE_REQUIRED")
            _, response = self.mutate(
                "PUT",
                self.client.url,
                self.body(data, preview=False),
                "deploy",
                preview_ref,
                semantic=current,
            )
            value = self.client.finish(
                response, self.credentials, self.request_id, preview=False
            )
            state = value["properties"]["provisioningState"]
            return self.result(
                "apply",
                output,
                "PASS" if state == "Succeeded" else "FAIL",
                preview=preview_ref,
                error=None if state == "Succeeded" else "NATIVE_DEPLOYMENT_FAILED",
                native=True,
            )
        except Exception:
            return self.failure("apply", output)

    def reconcile(self, operation_ref: dict, output: str) -> dict:
        """Read only, original immutable submission ID. Never call write/prepare/apply."""
        self.may_have_submitted = False
        try:
            self.output_ready = False
            output_path(self.root, self.request, output)
            output_path(self.root, self.request, output + ".manifest.json")
            self.output_ready = True
            c._require(
                operation_ref["path"] == self.directory + "/deployment-submission.json",
                "SUBMISSION_REQUIRED",
            )
            operation = decode(c.read_verified(self.root, operation_ref))
            fields(
                operation,
                {
                    "schema",
                    "request",
                    "preview",
                    "native_operation_id",
                    "request_id",
                    "body_sha256",
                    "created_at",
                    "scope",
                    "status",
                },
            )
            c._require(
                operation["schema"] == "azure-submission/v1"
                and operation["request"] == self.request_ref
                and operation["native_operation_id"] == self.client.native_id
                and operation["request_id"] == self.request_id
                and operation["scope"] == self.request["scope"],
                "SUBMISSION_MISMATCH",
            )
            self.submission = operation_ref
            self.pending_native_id = self.client.native_id
            self.may_have_submitted = True
            # Authenticated fresh federation; no imported receipt confers credentials.
            p = self.boundary.policy
            github = GitHubAdmission(p, self.boundary.runtime, self.boundary.transport)
            now = int(self.clock())
            token, claims = github.oidc(now)
            _, _, credentials = AzureIdentity.exchange(
                p, token, claims, self.boundary.transport, now
            )
            response = self.client.call(
                "GET", self.client.url, credentials, self.request_id
            )
            value = self.client.finish(
                response, credentials, self.request_id, preview=False
            )
            state = value["properties"]["provisioningState"]
            return self.result(
                "reconcile",
                output,
                "PASS" if state == "Succeeded" else "FAIL",
                error=None if state == "Succeeded" else "NATIVE_DEPLOYMENT_FAILED",
                native=True,
            )
        except Exception:
            return self.failure("reconcile", output)
