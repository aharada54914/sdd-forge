"""Exact frozen CDK template-asset -> governed Change Set -> read-only recovery.

No CDK execution, installations, bootstrap, resynthesis, cleanup or implicit role
assumption. Supported asset class is T-005's plain JSON stack-template asset only.
"""

from __future__ import annotations

from pathlib import Path
import re
import sys
import time
from typing import Callable

from cloud import (
    c,
    decode,
    digest,
    encode,
    detect_owner,
    output_path,
    publish_json,
    read_bytes,
    safe_publication,
)
from aws_local import local_policy, source_snapshot, upstream, assembly_policy
from aws_native import Native, Response, Transport, query  # noqa: F401

SHARED = Path(__file__).resolve().parents[2] / "sdd-quality-loop/scripts"
sys.path.insert(0, str(SHARED))
from cloud_authorization import (  # noqa: E402
    WriteBoundary,
    GitHubAdmission,
    AwsIdentity,
    utc,
    epoch,
    _policy_valid,
)
from aws_control import Control, intent_history  # noqa: E402

NO_CHANGES = "The submitted information didn't contain changes. Submit different information to create a change set."


def exact_artifacts(root: Path, ref: dict) -> tuple[dict, bytes, dict, dict]:
    request = c.read_artifact(root, ref, "cloud-run-request/v1")
    c._require(request["provider"] == "aws", "PROVIDER_MISMATCH")
    files = c.verify_local_context(root, request, execution=True)
    owner = detect_owner(root, request, files)
    cfg, params, policy, _ = local_policy(root, request)
    source_snapshot(root, request, files, cfg)
    upstream(root, request, cfg)  # hashes only; never toolchain()/prepare_local()
    compiled = [
        a for a in request["input_artifacts"] if a["kind"] in ("compiled", "asset")
    ]
    c._require(bool(compiled), "ASSEMBLY_REQUIRED")
    directories = {str(Path(a["path"]).parent) for a in compiled}
    c._require(len(directories) == 1, "ASSEMBLY_PATH")
    directory = directories.pop()
    c._require(
        str(Path(directory).parent) == cfg["output_directory"]
        and set(c._scan_unit(root, directory)) == {a["path"] for a in compiled},
        "ASSEMBLY_CLOSURE",
    )
    blobs = {
        Path(a["path"]).name: c.read_verified(root, c._file_ref(a)) for a in compiled
    }
    details = assembly_policy(blobs, params, policy, owner)
    template = blobs[details["template"]]
    c._require(all(safe_publication(b) for b in blobs.values()), "ASSET_SECRET_DENIED")
    assets = []
    manifest = decode(blobs["manifest.json"])
    for artifact in manifest["artifacts"].values():
        if artifact["type"] != "cdk:asset-manifest":
            continue
        doc = decode(blobs[artifact["properties"]["file"]])
        for sha, asset in doc.get("files", {}).items():
            c._require(
                sha == digest(template)
                and asset["source"]["path"] == details["template"],
                "ASSET_DIGEST_MISMATCH",
            )
            for destination in asset["destinations"].values():
                c._require(
                    set(destination)
                    <= {"bucketName", "objectKey", "region", "assumeRoleArn"},
                    "ASSET_DESTINATION_UNSUPPORTED",
                )
                c._require(
                    destination["objectKey"] == sha + ".json", "ASSET_KEY_MISMATCH"
                )
                # CDK's publisher/deployer role hints are not authority; deliberately
                # never assumed. The protected prepare identity is the sole publisher.
                assets.append(
                    dict(
                        bucket=destination["bucketName"],
                        key=destination["objectKey"],
                        region=destination["region"],
                        sha256=sha,
                    )
                )
    c._require(len(assets) == 1, "ASSET_TYPE_UNSUPPORTED")
    return request, template, assets[0], owner


class AwsExecutor:
    def __init__(
        self,
        root: Path,
        request_ref: dict,
        boundary: WriteBoundary,
        control: Control,
        *,
        transport: Transport | None = None,
        clock: Callable[[], float] = time.time,
        sleep: Callable[[float], None] = time.sleep,
    ):
        self.root, self.request_ref, self.boundary, self.control = (
            root,
            dict(request_ref),
            boundary,
            control,
        )
        self.clock, self.sleep = clock, sleep
        self.request = c.read_artifact(root, request_ref, "cloud-run-request/v1")
        self.directory = self.request["local_context"]["evidence_directory"]
        self.name = "sdd-" + request_ref["sha256"]
        self.token = "sdd-" + request_ref["sha256"]
        self.native = Native(self.request["scope"], control.bucket, transport, clock)
        self.preview_ref: dict | None = None
        self.submission: dict | None = None
        self.credentials: dict[str, str] = {}
        self.may_have_submitted = False
        self.output_ready = False
        self.native_id = self.name
        self.stack_id = self.request["scope"]["deployment_scope"]
        self.lease = 0
        self.receipt: dict = {}

    def trusted_binding(self) -> None:
        p = self.boundary.policy
        _policy_valid(p)
        r = c.read_artifact(self.root, self.request_ref, "cloud-run-request/v1")
        c._require(
            r == self.request
            and r["provider"] == p.provider == "aws"
            and r["operation"] == "apply"
            and r["environment"] == p.target_environment
            and r["owner"] == "cdk"
            and r["route"] == "aws-cdk"
            and r["scope"]
            == dict(
                account_id=p.account_id,
                region=p.region,
                deployment_scope=p.deployment_scope,
            )
            and r["policy"]["sha256"] == p.policy_sha256,
            "TRUSTED_POLICY_BINDING_MISMATCH",
        )
        self.control.validate(p, r)

    def check(self) -> tuple[dict, bytes, dict, dict]:
        self.trusted_binding()
        data = exact_artifacts(self.root, self.request_ref)
        c._require(
            data[0] == self.request and data[2]["bucket"] == self.control.bucket,
            "REQUEST_DRIFT",
        )
        return data

    def authenticate(self, *, approval: bool, preview: dict | None = None) -> None:
        self.trusted_binding()
        p = self.boundary.policy
        github = GitHubAdmission(p, self.boundary.runtime, self.boundary.transport)
        now = int(self.clock())
        token, claims = github.oidc(now)
        if approval:
            github.metadata(
                claims,
                self.request_ref["sha256"],
                preview["sha256"] if preview else "none",
            )
        _, end, self.credentials = AwsIdentity.exchange(
            p, token, claims, self.boundary.transport, now
        )
        self.lease = min(end, claims["exp"])

    def read(self, action: str, params: dict, *, absent: bool = False) -> dict:
        c._require(int(self.clock()) < self.lease, "READ_CREDENTIAL_EXPIRED")
        return self.native.cfn(action, params, self.credentials, absent_stack=absent)

    def tags(self) -> list[dict]:
        return [
            dict(Key="sdd-unit", Value=self.control.unit_id),
            dict(Key="sdd-owner", Value="cdk"),
        ]

    def stack(self, *, initial: bool = False) -> dict | None:
        target = self.request["scope"]["deployment_scope"] if initial else self.stack_id
        value = self.read("DescribeStacks", dict(StackName=target), absent=initial)
        stacks = value["Stacks"]
        if not stacks:
            c._require(
                initial and self.control.existing_stack_id is None,
                "STACK_OWNER_UNESTABLISHED",
            )
            return None
        c._require(len(stacks) == 1, "STACK_SCOPE_MISMATCH")
        stack = stacks[0]
        self.arn(stack["StackId"], "stack", self.request["scope"]["deployment_scope"])
        c._require(
            stack["StackName"] == self.request["scope"]["deployment_scope"]
            and (
                stack.get("RoleARN") == self.control.execution_role_arn
                or (
                    not initial
                    and self.control.existing_stack_id is None
                    and stack["StackStatus"] == "REVIEW_IN_PROGRESS"
                    and not stack.get("RoleARN")
                )
            )
            and sorted(stack.get("Tags", []), key=lambda t: t["Key"])
            == sorted(self.tags(), key=lambda t: t["Key"]),
            "STACK_AUTHORITY_MISMATCH",
        )
        if initial:
            c._require(
                self.control.existing_stack_id == stack["StackId"]
                and stack["StackStatus"] in ("CREATE_COMPLETE", "UPDATE_COMPLETE"),
                "STACK_OWNER_UNESTABLISHED",
            )
        else:
            c._require(stack["StackId"] == self.stack_id, "STACK_ID_MISMATCH")
        return stack

    def arn(self, arn: str, kind: str, name: str) -> None:
        scope = self.request["scope"]
        prefix = (
            "arn:aws:cloudformation:"
            + scope["region"]
            + ":"
            + scope["account_id"]
            + ":"
            + kind
            + "/"
            + name
            + "/"
        )
        c._require(
            type(arn) is str
            and re.fullmatch(re.escape(prefix) + r"[A-Za-z0-9-]+", arn),
            "NATIVE_ID_MISMATCH",
        )

    def create_params(self, data: tuple, asset: dict, kind: str) -> dict:
        template = decode(data[1])
        parameters = []
        for key, param in sorted(template.get("Parameters", {}).items()):
            c._require(
                type(param.get("Default")) is str and not param.get("NoEcho"),
                "PARAMETER_UNSUPPORTED",
            )
            parameters.append(dict(ParameterKey=key, ParameterValue=param["Default"]))
        params = dict(
            StackName=self.request["scope"]["deployment_scope"],
            TemplateURL=self.native.object_url(asset["key"], asset["version"]),
            RoleARN=self.control.execution_role_arn,
            Tags=self.tags(),
            ChangeSetName=self.name,
            ClientToken=self.token,
            ChangeSetType=kind,
            IncludeNestedStacks=False,
            ImportExistingResources=False,
            Parameters=parameters,
            Capabilities=[],
        )
        # Native authenticated description binds exact request AND immutable assets.
        params["Description"] = "sdd:" + digest(
            encode(dict(request=self.request_ref, create=params, asset=asset))
        )
        return params

    def audit(self, path: str, value: dict) -> dict:
        return publish_json(self.root, path, value)

    @staticmethod
    def wire_hash(mutation: str, body: dict) -> str:
        if mutation == "publish":
            c._sha(body["sha256"])
            return body["sha256"]
        c._require(mutation in ("create", "execute"), "INTENT_MUTATION_INVALID")
        return digest(
            query(
                "CreateChangeSet" if mutation == "create" else "ExecuteChangeSet", body
            )
        )

    def mutate(
        self,
        mutation: str,
        preview: dict | None,
        callback: Callable[[], dict],
        *,
        body: dict,
    ) -> dict:
        def submit(credentials: dict[str, str]):
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
            receipt = c.parse_artifact(
                read_bytes(self.root, receipt_path), "cloud-authorization-receipt/v1"
            )
            self.check()
            self.receipt = receipt
            self.credentials = credentials
            self.lease = epoch(receipt["expires_at"])
            self.submission = self.audit(
                self.directory + "/" + mutation + "-submission.json",
                dict(
                    schema="aws-submission/v1",
                    request=self.request_ref,
                    preview=preview,
                    scope=self.request["scope"],
                    native_operation_id=self.native_id,
                    stack_id=self.stack_id,
                    client_token=self.token,
                    body=body,
                    body_sha256=self.wire_hash(mutation, body),
                    created_at=utc(int(self.clock())),
                    status="UNKNOWN",
                    mutation=mutation,
                ),
            )
            c.verify_binding(
                self.root,
                self.request_ref,
                preview,
                now=utc(int(self.clock())),
                operation=self.boundary.policy.operation,
            )
            c._require(int(self.clock()) < self.lease, "CREDENTIAL_EXPIRED")
            # Callback's final native validation runs before it sets may_have_submitted.
            return callback()

        return self.boundary.write(
            self.root,
            self.request_ref,
            preview,
            mutation_id=mutation,
            submit=submit,
            scan=safe_publication,
        )[1]

    def final_admission(self, preview: dict | None) -> None:
        github = GitHubAdmission(
            self.boundary.policy, self.boundary.runtime, self.boundary.transport
        )
        _, claims = github.oidc(int(self.clock()))
        approval = github.metadata(
            claims, self.request_ref["sha256"], preview["sha256"] if preview else "none"
        )
        c._require(
            approval == self.receipt["approval_evidence"]
            and claims["run_id"] == self.receipt["ci"]["run_id"],
            "APPROVAL_CHANGED",
        )
        self.check()
        c.verify_binding(
            self.root,
            self.request_ref,
            preview,
            now=utc(int(self.clock())),
            operation=self.boundary.policy.operation,
        )
        c._require(int(self.clock()) < self.lease, "CREDENTIAL_EXPIRED")

    def describe(self, *, wait: bool = False) -> dict:
        for attempt in range(8 if wait else 1):
            value = self.read(
                "DescribeChangeSet",
                dict(
                    ChangeSetName=self.native_id,
                    StackName=self.stack_id,
                    IncludePropertyValues=True,
                ),
            )
            if value["Status"] not in ("CREATE_PENDING", "CREATE_IN_PROGRESS"):
                return value
            if not wait:
                break
            self.sleep(min(2**attempt, 8))
        raise TimeoutError("CHANGE_SET_PENDING")

    def semantic(self, value: dict, create: dict, asset: dict, template: bytes) -> dict:
        self.arn(value["ChangeSetId"], "changeSet", self.name)
        self.arn(value["StackId"], "stack", self.request["scope"]["deployment_scope"])
        c._require(
            value["ChangeSetId"] == self.native_id
            and value["StackId"] == self.stack_id
            and value["ChangeSetName"] == self.name
            and value["StackName"] == create["StackName"]
            and value.get("Description") == create["Description"]
            and value.get("Capabilities", []) == create["Capabilities"]
            and value.get("Parameters", []) == create["Parameters"]
            and sorted(value.get("Tags", []), key=lambda t: t["Key"])
            == sorted(create["Tags"], key=lambda t: t["Key"])
            and not value.get("IncludeNestedStacks", False)
            and not value.get("ImportExistingResources", False)
            and not value.get("ParentChangeSetId")
            and not value.get("RootChangeSetId")
            and not value.get("OnStackFailure")
            and not value.get("NotificationARNs", [])
            and not value.get("RollbackConfiguration", {}).get("RollbackTriggers", [])
            and not value.get("DeploymentConfig")
            and value.get("DeploymentMode", "REVERT_DRIFT") == "REVERT_DRIFT",
            "CHANGE_SET_BINDING_MISMATCH",
        )
        no_change = (
            value["Status"] == "FAILED"
            and value["ExecutionStatus"] == "UNAVAILABLE"
            and value.get("StatusReason") == NO_CHANGES
            and value.get("Changes", []) == []
        )
        c._require(
            no_change
            or (
                value["Status"] == "CREATE_COMPLETE"
                and value["ExecutionStatus"] == "AVAILABLE"
            ),
            "CHANGE_SET_UNAVAILABLE",
        )
        resources = decode(template)["Resources"]
        changes = value.get("Changes", [])
        c._require(no_change or bool(changes), "EMPTY_CHANGE_SET_AMBIGUOUS")
        c._require(type(changes) is list and len(changes) <= 4096, "CHANGE_SET_SHAPE")
        seen = set()
        for change in changes:
            c._require(
                set(change) == {"Type", "ResourceChange"}
                and change["Type"] == "Resource",
                "CHANGE_UNSUPPORTED",
            )
            r = change["ResourceChange"]
            logical = r["LogicalResourceId"]
            c._require(
                logical in resources
                and logical not in seen
                and r["ResourceType"] == resources[logical]["Type"],
                "RESOURCE_SCOPE_MISMATCH",
            )
            seen.add(logical)
            owner = c.read_artifact(
                self.root,
                self.request["local_context"]["ownership"],
                "cloud-ownership/v1",
            )
            c._require(
                r.get("PhysicalResourceId")
                not in {x["resource_id"] for x in owner["existing_resources"]}
                and r.get("PolicyAction") in (None, "Retain"),
                "REFERENCED_RESOURCE_MUTATION",
            )
            c._require(
                r["Action"] in ("Add", "Modify")
                and r.get("Replacement", "False") == "False",
                "DESTRUCTIVE_CHANGE_DENIED",
            )
            c._require(
                not r.get("ChangeSetId") and not r.get("ModuleInfo"),
                "NESTED_CHANGE_DENIED",
            )
            if r["Action"] == "Modify":
                c._require(
                    bool(r.get("Details")) and r.get("Scope") == ["Properties"],
                    "MODIFY_UNSUPPORTED",
                )
                for detail in r["Details"]:
                    c._require(
                        detail.get("Evaluation") == "Static"
                        and detail.get("ChangeSource") == "DirectModification"
                        and detail["Target"].get("Attribute") == "Properties"
                        and detail["Target"].get("RequiresRecreation") == "Never",
                        "MODIFY_UNSUPPORTED",
                    )
        return dict(
            schema="aws-exact-preview/v1",
            request=self.request_ref,
            create=create,
            asset=asset,
            template_sha256=digest(template),
            change_set_arn=self.native_id,
            stack_id=self.stack_id,
            scope=self.request["scope"],
            changes=sorted(
                changes, key=lambda x: x["ResourceChange"]["LogicalResourceId"]
            ),
            no_change=no_change,
        )

    def readback(self, semantic: dict, data: tuple, *, wait: bool = False) -> dict:
        asset, create = semantic["asset"], semantic["create"]
        c._require(
            create
            == self.create_params(
                data, asset, "UPDATE" if self.control.existing_stack_id else "CREATE"
            ),
            "CREATE_REQUEST_MISMATCH",
        )
        self.native.bucket_check(self.credentials)
        self.native.read_object(asset, self.credentials, data[1])
        self.stack()
        value = self.describe(wait=wait)
        template = self.read(
            "GetTemplate",
            dict(
                StackName=self.stack_id,
                ChangeSetName=self.native_id,
                TemplateStage="Original",
            ),
        )
        c._require(
            type(template["TemplateBody"]) is str
            and template["TemplateBody"].encode() == data[1],
            "TEMPLATE_SUBSTITUTION",
        )
        return self.semantic(value, create, asset, data[1])

    def check_preview(self, ref: dict) -> tuple[dict, tuple]:
        data = self.check()
        c.verify_binding(
            self.root,
            self.request_ref,
            ref,
            now=utc(int(self.clock())),
            operation="apply",
        )
        preview = c.read_artifact(self.root, ref, "cloud-preview/v1")
        semantic = decode(c.read_verified(self.root, preview["changes"]))
        c._require(
            preview["semantic_sha256"] == digest(encode(semantic))
            and preview["replacements"] == []
            and preview["deletes"] == [],
            "PREVIEW_DRIFT",
        )
        c._require(
            semantic["request"] == self.request_ref
            and semantic["scope"] == self.request["scope"],
            "PREVIEW_BINDING_MISMATCH",
        )
        self.arn(semantic["change_set_arn"], "changeSet", self.name)
        self.arn(
            semantic["stack_id"], "stack", self.request["scope"]["deployment_scope"]
        )
        c._require(
            preview["preview_identity"] == semantic["change_set_arn"],
            "PREVIEW_ARN_MISMATCH",
        )
        self.native_id, self.stack_id = semantic["change_set_arn"], semantic["stack_id"]
        return semantic, data

    def start(self, output: str) -> None:
        self.output_ready = False
        output_path(self.root, self.request, output)
        output_path(self.root, self.request, output + ".manifest.json")
        self.output_ready = True

    def result(
        self,
        phase: str,
        output: str,
        result: str,
        *,
        preview: dict | None = None,
        native: bool = False,
        error: str | None = None,
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
            message="Native execution only; workload health is not verified.",
            input_manifest_sha256=self.request_ref["sha256"],
            evidence_manifest_path=None,
        )
        if native:
            value["native_operation_id"] = self.native_id
        if self.output_ready:
            path = output + ".manifest.json"
            try:
                self.audit(
                    path,
                    dict(
                        schema="aws-execution-evidence/v1",
                        request=self.request_ref,
                        preview=preview,
                        submission=self.submission,
                        native_trace=self.native.trace,
                        operation=phase,
                        result=result,
                        recorded_at=utc(int(self.clock())),
                        health_verified=False,
                    ),
                )
                value["evidence_manifest_path"] = path
                c.parse_artifact(encode(value), "cloud-operation-result/v1")
                c.publish_artifact(
                    self.root, output, encode(value), scan=safe_publication
                )
            except (OSError, ValueError):
                if not self.may_have_submitted:
                    raise
                value.update(
                    result="UNKNOWN",
                    state="UNKNOWN",
                    error_code="EVIDENCE_PUBLICATION_FAILED",
                    evidence_manifest_path=self.submission["path"]
                    if self.submission
                    else None,
                )
        return value

    def failure(self, phase: str, output: str) -> dict:
        unknown = self.may_have_submitted
        return self.result(
            phase,
            output,
            "UNKNOWN" if unknown else "BLOCKED",
            native=unknown,
            error="AWS_OUTCOME_UNKNOWN" if unknown else "AWS_EXECUTION_BLOCKED",
        )

    def prepare(self, output: str) -> dict:
        try:
            self.start(output)
            c._require(self.boundary.policy.operation == "prepare", "STAGE_MISMATCH")
            data = self.check()
            self.native_id = self.native.object_url(data[2]["key"])
            history = intent_history(self, None, prepare=True)
            if history["prior_run_ids"]:
                self.submission = self.audit(
                    self.directory + "/prepare-fence.json",
                    dict(
                        schema="aws-prepare-fence/v1",
                        request=self.request_ref,
                        preview=None,
                        scope=self.request["scope"],
                        native_operation_id=self.native_id,
                        stack_id=self.stack_id,
                        client_token=self.token,
                        asset_hint=data[2],
                        status="UNKNOWN",
                        **history,
                    ),
                )
                self.may_have_submitted = True
                return self.result(
                    "prepare",
                    output,
                    "UNKNOWN",
                    native=True,
                    error="PREPARE_RECONCILE_REQUIRED",
                )
            for mutation in ("create", "publish"):
                path = self.directory + "/" + mutation + "-submission.json"
                if (self.root / path).exists():
                    raw = read_bytes(self.root, path)
                    self.submission = dict(path=path, sha256=digest(raw))
                    self.native_id = decode(raw)["native_operation_id"]
                    self.may_have_submitted = True
                    return self.result(
                        "prepare",
                        output,
                        "UNKNOWN",
                        native=True,
                        error="PREPARE_RECONCILE_REQUIRED",
                    )
            self.authenticate(approval=True)
            stack = self.stack(initial=True)
            self.native.bucket_check(self.credentials)

            self.native_id = self.native.object_url(data[2]["key"])

            def upload():
                self.native.bucket_check(self.credentials)
                self.check()
                c._require(int(self.clock()) < self.lease, "CREDENTIAL_EXPIRED")
                self.final_admission(None)
                self.may_have_submitted = True
                response = self.native.call(
                    "PUT",
                    self.native.object_url(data[2]["key"]),
                    self.credentials,
                    data[1],
                    {
                        **self.native.owner_headers(),
                        "x-amz-server-side-encryption": "AES256",
                        "content-type": "application/json",
                    },
                )
                asset = self.native.object_identity(
                    response, data[2]["key"], digest(data[1])
                )
                self.audit(
                    self.directory + "/published.json",
                    dict(request=self.request_ref, asset=asset),
                )
                self.native.read_object(asset, self.credentials, data[1])
                self.may_have_submitted = False
                return asset

            asset = self.mutate("publish", None, upload, body=data[2])
            c._require(type(asset) is dict, "ASSET_PUBLICATION_FAILED")
            create = self.create_params(data, asset, "UPDATE" if stack else "CREATE")

            self.native_id = self.name

            def create_set():
                self.native.read_object(asset, self.credentials, data[1])
                self.stack(initial=True)
                self.check()
                c._require(int(self.clock()) < self.lease, "CREDENTIAL_EXPIRED")
                self.final_admission(None)
                self.may_have_submitted = True
                return self.native.cfn("CreateChangeSet", create, self.credentials)

            created = self.mutate("create", None, create_set, body=create)
            c._require(type(created) is dict, "CREATE_RESPONSE_REQUIRED")
            self.arn(created["Id"], "changeSet", self.name)
            self.arn(
                created["StackId"], "stack", self.request["scope"]["deployment_scope"]
            )
            self.native_id, self.stack_id = created["Id"], created["StackId"]
            self.audit(
                self.directory + "/created.json",
                dict(
                    request=self.request_ref,
                    create=create,
                    change_set_arn=self.native_id,
                    stack_id=self.stack_id,
                    asset=asset,
                ),
            )
            semantic = self.readback(dict(create=create, asset=asset), data, wait=True)
            self.may_have_submitted = False
            ref = self.publish_preview(semantic)
            return self.result(
                "prepare",
                output,
                "NO_CHANGE" if semantic["no_change"] else "PASS",
                preview=ref,
            )
        except Exception:
            return self.failure("prepare", output)

    def publish_preview(self, semantic: dict) -> dict:
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
            preview_identity=self.native_id,
            semantic_sha256=changes["sha256"],
            changes=changes,
            replacements=[],
            deletes=[],
            created_at=utc(now),
            expires_at=utc(now + 300),
        )
        ref = c.publish_artifact(
            self.root,
            self.directory + "/preview.json",
            encode(preview),
            scan=safe_publication,
        )
        return ref

    def apply(self, preview_ref: dict, output: str) -> dict:
        self.may_have_submitted = False
        try:
            self.start(output)
            c._require(self.boundary.policy.operation == "apply", "STAGE_MISMATCH")
            semantic, data = self.check_preview(preview_ref)
            self.preview_ref = preview_ref
            history = intent_history(self, preview_ref)
            if history["prior_run_ids"]:
                self.submission = self.audit(
                    self.directory + "/intent-fence.json",
                    dict(
                        schema="aws-intent-fence/v1",
                        request=self.request_ref,
                        preview=preview_ref,
                        scope=self.request["scope"],
                        native_operation_id=self.native_id,
                        stack_id=self.stack_id,
                        client_token=self.token,
                        status="UNKNOWN",
                        **history,
                    ),
                )
                self.may_have_submitted = True
                return self.result(
                    "apply", output, "UNKNOWN", native=True, error="RECONCILE_REQUIRED"
                )
            journal_path = self.directory + "/execute-submission.json"
            if (self.root / journal_path).exists():
                journal = read_bytes(self.root, journal_path)
                self.submission = dict(path=journal_path, sha256=digest(journal))
                self.may_have_submitted = True
                return self.result(
                    "apply", output, "UNKNOWN", native=True, error="RECONCILE_REQUIRED"
                )
            self.authenticate(approval=True, preview=preview_ref)
            c._require(self.readback(semantic, data) == semantic, "PREVIEW_DRIFT")
            if semantic["no_change"]:
                return self.result("apply", output, "NO_CHANGE", preview=preview_ref)
            params = dict(
                ChangeSetName=self.native_id,
                StackName=self.stack_id,
                ClientRequestToken=self.token,
                DisableRollback=True,
                RetainExceptOnCreate=False,
            )

            def execute():
                c._require(
                    not intent_history(self, preview_ref)["prior_run_ids"],
                    "RECONCILE_REQUIRED",
                )
                c._require(
                    self.readback(semantic, self.check()) == semantic, "PREVIEW_DRIFT"
                )
                self.check()
                c.verify_binding(
                    self.root,
                    self.request_ref,
                    preview_ref,
                    now=utc(int(self.clock())),
                    operation="apply",
                )
                c._require(int(self.clock()) < self.lease, "CREDENTIAL_EXPIRED")
                self.final_admission(preview_ref)
                self.may_have_submitted = True
                return self.native.cfn("ExecuteChangeSet", params, self.credentials)

            self.mutate("execute", preview_ref, execute, body=params)
            return self.finish("apply", output)
        except Exception:
            return self.failure("apply", output)

    def finish(self, phase: str, output: str) -> dict:
        # Empty ExecuteChangeSet result is not a deployment ID or success signal.
        for attempt in range(8):
            stack = self.stack()
            events = self.read("DescribeStackEvents", dict(StackName=self.stack_id))[
                "StackEvents"
            ]
            matched = [
                e
                for e in events
                if e.get("StackId") == self.stack_id
                and e.get("ClientRequestToken") == self.token
                and e.get("ResourceType") == "AWS::CloudFormation::Stack"
                and e.get("LogicalResourceId")
                == self.request["scope"]["deployment_scope"]
            ]
            if (
                stack
                and matched
                and matched[0]["ResourceStatus"] == stack["StackStatus"]
            ):
                status = stack["StackStatus"]
                if status in (
                    "CREATE_COMPLETE",
                    "UPDATE_COMPLETE",
                    "CREATE_FAILED",
                    "UPDATE_FAILED",
                ):
                    success = status.endswith("_COMPLETE")
                    return self.result(
                        phase,
                        output,
                        "PASS" if success else "FAIL",
                        native=True,
                        error=None if success else "NATIVE_STACK_FAILED",
                    )
            self.sleep(min(2**attempt, 8))
        raise TimeoutError("ORIGINAL_OPERATION_UNRESOLVED")

    def recover_prepare(self, op: dict, operation_ref: dict, output: str) -> dict:
        data = self.check()
        c._require(
            op["body_sha256"] == self.wire_hash(op["mutation"], op["body"]),
            "PREPARE_JOURNAL_MISMATCH",
        )
        expected_path = self.directory + "/" + op["mutation"] + "-submission.json"
        c._require(operation_ref["path"] == expected_path, "PREPARE_JOURNAL_MISMATCH")
        if op["mutation"] == "publish":
            c._require(
                op["body"] == data[2]
                and op["native_operation_id"] == self.native.object_url(data[2]["key"]),
                "ASSET_INTENT_MISMATCH",
            )
            self.submission, self.may_have_submitted = operation_ref, True
            self.native_id = op["native_operation_id"]
            # No version survived the response: latest/listing guesses cannot identify
            # the original PUT. Preserve uncertainty; never upload again or use latest.
            return self.result(
                "reconcile",
                output,
                "UNKNOWN",
                native=True,
                error="ASSET_VERSION_UNRESOLVED",
            )
        c._require(
            op["native_operation_id"] == self.name
            and op["stack_id"] == self.request["scope"]["deployment_scope"],
            "CREATE_INTENT_MISMATCH",
        )
        published = decode(read_bytes(self.root, self.directory + "/published.json"))
        c._require(
            published["request"] == self.request_ref
            and op["body"]
            == self.create_params(
                data,
                published["asset"],
                "UPDATE" if self.control.existing_stack_id else "CREATE",
            ),
            "CREATE_INTENT_MISMATCH",
        )
        self.submission, self.may_have_submitted = operation_ref, True
        self.authenticate(approval=False)
        value = self.describe(wait=True)
        self.arn(value["ChangeSetId"], "changeSet", self.name)
        self.arn(value["StackId"], "stack", self.request["scope"]["deployment_scope"])
        self.native_id, self.stack_id = value["ChangeSetId"], value["StackId"]
        semantic = self.readback(
            dict(create=op["body"], asset=published["asset"]), data
        )
        ref = self.publish_preview(semantic)
        self.may_have_submitted = False
        return self.result(
            "reconcile",
            output,
            "NO_CHANGE" if semantic["no_change"] else "PASS",
            preview=ref,
            native=not semantic["no_change"],
        )

    def reconcile(self, operation_ref: dict, output: str) -> dict:
        self.may_have_submitted = False
        try:
            self.start(output)
            self.trusted_binding()  # no native query can precede authority binding
            c._require(self.boundary.policy.operation == "apply", "STAGE_MISMATCH")
            op = decode(c.read_verified(self.root, operation_ref))
            c._require(
                op["schema"]
                in ("aws-submission/v1", "aws-intent-fence/v1", "aws-prepare-fence/v1")
                and op["request"] == self.request_ref
                and op["scope"] == self.request["scope"]
                and op["client_token"] == self.token
                and op["status"] == "UNKNOWN"
                and operation_ref["path"]
                in (
                    self.directory + "/execute-submission.json",
                    self.directory + "/intent-fence.json",
                    self.directory + "/create-submission.json",
                    self.directory + "/publish-submission.json",
                    self.directory + "/prepare-fence.json",
                ),
                "RECOVERY_BINDING_MISMATCH",
            )
            common = {
                "schema",
                "request",
                "preview",
                "scope",
                "native_operation_id",
                "stack_id",
                "client_token",
                "status",
            }
            if op["schema"] == "aws-submission/v1":
                c._require(
                    set(op)
                    == common | {"body", "body_sha256", "created_at", "mutation"},
                    "JOURNAL_SHAPE",
                )
                epoch(op["created_at"])
                c._require(
                    op["body_sha256"] == self.wire_hash(op["mutation"], op["body"]),
                    "INTENT_BYTES_MISMATCH",
                )
                if op["mutation"] == "execute":
                    c._require(
                        operation_ref["path"]
                        == self.directory + "/execute-submission.json"
                        and op["body"]
                        == dict(
                            ChangeSetName=op["native_operation_id"],
                            StackName=op["stack_id"],
                            ClientRequestToken=self.token,
                            DisableRollback=True,
                            RetainExceptOnCreate=False,
                        ),
                        "EXECUTE_INTENT_MISMATCH",
                    )
            else:
                c._require(
                    set(op)
                    == common
                    | {
                        "repository",
                        "repository_id",
                        "current_run_id",
                        "prior_run_ids",
                        "history",
                    }
                    | (
                        {"asset_hint"}
                        if op["schema"] == "aws-prepare-fence/v1"
                        else set()
                    ),
                    "FENCE_SHAPE",
                )
                c._require(
                    op["repository"] == self.boundary.policy.repository
                    and op["repository_id"] == self.boundary.policy.repository_id,
                    "FENCE_AUTHORITY_MISMATCH",
                )
            if op["schema"] == "aws-prepare-fence/v1":
                data = self.check()
                c._require(
                    operation_ref["path"] == self.directory + "/prepare-fence.json"
                    and op["asset_hint"] == data[2]
                    and op["native_operation_id"]
                    == self.native.object_url(data[2]["key"]),
                    "PREPARE_FENCE_MISMATCH",
                )
                self.native_id = op["native_operation_id"]
                self.submission, self.may_have_submitted = operation_ref, True
                history = intent_history(self, None, read_only=True, prepare=True)
                c._require(
                    bool(op["prior_run_ids"])
                    and set(op["prior_run_ids"]) <= set(history["prior_run_ids"]),
                    "PREPARE_FENCE_HISTORY",
                )
                self.audit(output + ".history.json", history)
                return self.result(
                    "reconcile",
                    output,
                    "UNKNOWN",
                    native=True,
                    error="ORIGINAL_PREPARE_EVIDENCE_REQUIRED",
                )
            if op.get("mutation") in ("publish", "create"):
                return self.recover_prepare(op, operation_ref, output)
            self.arn(op["native_operation_id"], "changeSet", self.name)
            self.arn(op["stack_id"], "stack", self.request["scope"]["deployment_scope"])
            self.native_id, self.stack_id = op["native_operation_id"], op["stack_id"]
            self.submission, self.may_have_submitted = operation_ref, True
            # No approval/preview-expiry requirement for querying original intent.
            history = intent_history(self, op["preview"], read_only=True)
            self.audit(output + ".history.json", history)
            self.authenticate(approval=False)
            return self.finish("reconcile", output)
        except Exception:
            return self.failure("reconcile", output)

    def observe(self, output: str, phase: str) -> dict:
        from aws_observation import observe
        return observe(self, output, phase)
