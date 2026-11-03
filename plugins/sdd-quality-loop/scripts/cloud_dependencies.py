"""Per-unit dependency proof and ordering, not a deployment engine.

Only externally protected Policy pins plus fresh authenticated GitHub acquisition
can authenticate a saved verification. Local labels/digests cannot. No provider
plugin imports: either provider can be installed with these four shared modules.
"""

from __future__ import annotations

import base64
from dataclasses import dataclass
from datetime import datetime, timedelta
import io
import os
from pathlib import Path
import re
import stat
import tempfile
import time
from typing import Callable
import urllib.parse
import urllib.request
import zipfile

import cloud_contracts as c
import cloud_verification as v
from cloud_verification import decode, digest


@dataclass(frozen=True)
class Response:
    status: int
    headers: dict[str, str]
    body: bytes


ARCHIVE_LIMIT = 32 * 1024 * 1024


class ArtifactRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None  # expose 302 headers; never follow automatically


class ArtifactHttps:
    """No automatic redirects, no credential forwarding, bounded archive reads."""

    def request(
        self, method: str, url: str, headers: dict[str, str], body: bytes | None = None
    ) -> Response:
        c._require(method == "GET" and body is None, "ARTIFACT_METHOD_DENIED")
        req = urllib.request.Request(url, headers=headers, method="GET")
        try:
            response = urllib.request.build_opener(ArtifactRedirect()).open(
                req, timeout=20
            )
        except urllib.error.HTTPError as error:
            response = error
        with response:
            c._require(response.geturl() == url, "ARTIFACT_REDIRECT_DENIED")
            content = response.read(ARCHIVE_LIMIT + 1)
            c._require(len(content) <= ARCHIVE_LIMIT, "ARCHIVE_TOO_LARGE")
            return Response(response.status, dict(response.headers.items()), content)


def acquire_bundle(
    root: Path,
    repository: str,
    artifact_id: int,
    run_id: int,
    token: str,
    *,
    transport=None,
) -> dict:
    """Authenticate immutable artifact ID/digest then safely extract data in a NEW root."""
    c._require(not root.exists() and not root.is_symlink(), "ARTIFACT_ROOT_EXISTS")
    c._require(
        re.fullmatch(r"[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+", repository)
        and type(artifact_id) is int
        and artifact_id > 0
        and type(run_id) is int
        and run_id > 0,
        "ARTIFACT_LOCATOR_INVALID",
    )
    api = transport or ArtifactHttps()
    base = f"https://api.github.com/repos/{repository}/actions/artifacts/{artifact_id}"
    headers = {
        "Authorization": "Bearer " + token,
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    response = api.request("GET", base, headers)
    c._require(response.status == 200, "ARTIFACT_METADATA_UNAVAILABLE")
    metadata = decode(response.body)
    c._require(
        metadata["id"] == artifact_id
        and metadata["expired"] is False
        and metadata["workflow_run"]["id"] == run_id,
        "ARTIFACT_IDENTITY_CHANGED",
    )
    expected = metadata["digest"]
    c._require(
        type(expected) is str and re.fullmatch(r"sha256:[a-f0-9]{64}", expected),
        "ARTIFACT_DIGEST_REQUIRED",
    )
    response = api.request("GET", base + "/zip", headers)
    c._require(response.status == 302, "ARTIFACT_DOWNLOAD_UNAVAILABLE")
    location = {k.lower(): v for k, v in response.headers.items()}["location"]
    url = urllib.parse.urlsplit(location)
    c._require(
        url.scheme == "https"
        and not url.username
        and not url.password
        and not url.fragment
        and url.port is None
        and re.fullmatch(r"[a-z0-9]+\.blob\.core\.windows\.net", url.netloc),
        "ARTIFACT_LOCATION_DENIED",
    )
    response = api.request("GET", location, {})
    c._require(
        response.status == 200
        and len(response.body) <= ARCHIVE_LIMIT
        and "sha256:" + digest(response.body) == expected,
        "ARTIFACT_DIGEST_MISMATCH",
    )
    # Validate the entire archive before writing anything. No zipfile.extract or links.
    with zipfile.ZipFile(io.BytesIO(response.body)) as archive:
        infos = archive.infolist()
        c._require(
            0 < len(infos) <= 4096 and sum(i.file_size for i in infos) <= ARCHIVE_LIMIT,
            "ARCHIVE_TOO_LARGE",
        )
        names = set()
        for info in infos:
            c._path(info.filename.rstrip("/") if info.is_dir() else info.filename)
            mode = info.external_attr >> 16
            c._require(
                not mode or stat.S_IFMT(mode) in (0, stat.S_IFREG, stat.S_IFDIR),
                "ARCHIVE_LINK_DENIED",
            )
            c._require(
                info.filename not in names and not info.flag_bits & 1,
                "ARCHIVE_ENTRY_INVALID",
            )
            names.add(info.filename)
        root.mkdir(mode=0o700)
        for info in infos:
            destination = root / info.filename
            if info.is_dir():
                destination.mkdir(parents=True, exist_ok=True, mode=0o700)
                continue
            destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            data = archive.read(info)
            c._require(len(data) == info.file_size, "ARCHIVE_TRUNCATED")
            with destination.open("xb") as stream:
                stream.write(data)

    return metadata


def verification_job(provider: str, repository: str, revision: str) -> dict:
    """Exact fixed verify producer job shared with both inert workflow generators."""
    c._enum(provider, ("azure", "aws"))
    env = {
        provider.upper() + "_CONTROL_POLICY": "${{ vars."
        + provider.upper()
        + "_VERIFY_POLICY }}",
        "GH_TOKEN": "${{ github.token }}",
        "ARTIFACT_TOKEN": "${{ github.token }}",
        "ARTIFACT_REPOSITORY": "${{ github.repository }}",
        "ARTIFACT_ID": "${{ inputs.artifact_id }}",
        "ARTIFACT_RUN_ID": "${{ inputs.artifact_run_id }}",
        "REQUEST_SHA256": "${{ inputs.request_sha256 }}",
        "PREVIEW_SHA256": "${{ inputs.preview_sha256 }}",
    }
    if provider == "aws":
        env["AWS_EXECUTION_CONTROL"] = "${{ vars.AWS_EXECUTION_CONTROL }}"
    return {
        "if": "${{ github.run_attempt == 1 && inputs.operation == 'verify' }}",
        "runs-on": "ubuntu-24.04",
        "environment": "sandbox-verify",
        "permissions": {"contents": "read", "actions": "read", "id-token": "write"},
        "timeout-minutes": 30,
        "steps": [
            {
                "name": "Reviewed executor only",
                "uses": "actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683",
                "with": {
                    "repository": repository,
                    "ref": revision,
                    "path": "executor",
                    "persist-credentials": False,
                },
            },
            {
                "name": "Execute fixed read-only verify",
                "shell": "bash",
                "env": env,
                "run": f'set -euo pipefail\npython3 -I executor/plugins/sdd-{provider}-cloud/scripts/{provider}_governed.py verify --workspace "$RUNNER_TEMP/{provider}-data"',
            },
            {
                "name": "Retain immutable data and original operation identity even on failure",
                "if": "${{ always() }}",
                "uses": "actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9",
                "with": {
                    "name": provider + "-verify-${{ github.run_id }}",
                    "path": "${{ runner.temp }}/" + provider + "-data/",
                    "if-no-files-found": "error",
                    "include-hidden-files": True,
                    "retention-days": "${{ vars."
                    + provider.upper()
                    + "_EVIDENCE_RETENTION_DAYS }}",
                },
            },
        ],
    }


def validate_trust(pin: dict) -> None:
    """Closed external executor configuration, not an artifact-supplied authority."""

    def repository(x):
        c._match(x, r"[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+")

    def positive(x):
        c._require(type(x) is int and 0 < x < 10**20)

    def identities(x):
        c._list(
            x,
            lambda pair: c._require(
                type(pair) is list
                and len(pair) == 2
                and type(pair[0]) is int
                and pair[0] > 0
                and type(pair[1]) is str
                and re.fullmatch(r"[A-Za-z0-9_-]+", pair[1])
            ),
            1,
        )

    c._record(
        pin,
        dict(
            unit_id=c._id,
            run_id=c._id,
            provider=lambda x: c._enum(x, ("azure", "aws")),
            request=c._ref,
            verification=c._ref,
            scope=c._scope,
            profile=lambda x: c._record(
                x, dict(id=c._id, version=c._version, path=c._path, sha256=c._sha)
            ),
            repository=repository,
            repository_id=positive,
            workflow=lambda x: c._match(
                x, r"\.github/workflows/[A-Za-z0-9_.-]+\.ya?ml"
            ),
            workflow_revision=lambda x: c._match(x, r"[a-f0-9]{40}"),
            ref=lambda x: c._match(x, r"refs/heads/[A-Za-z0-9_/-]+"),
            workflow_sha256=c._sha,
            executor_repository=repository,
            executor_revision=lambda x: c._match(x, r"[a-f0-9]{40}"),
            producer_run_id=positive,
            artifact_id=positive,
            environment_id=positive,
            actors=identities,
            reviewers=identities,
        ),
    )
    for key in ("actors", "reviewers"):
        c._unique([tuple(row) for row in pin[key]])


def _producer(
    pin: dict, runtime, transport, request_ref: dict, preview_ref: dict, now: str
) -> tuple[str, str]:
    """Authenticate successful exact verify workflow/job/code and environment history."""
    base = "https://api.github.com/repos/" + pin["repository"]
    headers = {
        "Authorization": "Bearer " + runtime.github_token,
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }

    def get(suffix):
        return decode(transport.request("GET", base + suffix, headers))

    suffix = "/actions/runs/" + str(pin["producer_run_id"])
    run = get(suffix)
    expected = dict(
        id=pin["producer_run_id"],
        run_attempt=1,
        status="completed",
        conclusion="success",
        event="workflow_dispatch",
        head_sha=pin["workflow_revision"],
        head_branch=pin["ref"].removeprefix("refs/heads/"),
        path=pin["workflow"],
        display_title="cloud:" + request_ref["sha256"] + ":" + preview_ref["sha256"],
    )
    c._require(
        all(
            type(run.get(k)) is type(value) and run[k] == value
            for k, value in expected.items()
        )
        and all(
            run[k]["id"] == pin["repository_id"]
            and run[k]["full_name"] == pin["repository"]
            for k in ("repository", "head_repository")
        )
        and all(
            [run[k]["id"], run[k]["login"]] in pin["actors"]
            for k in ("actor", "triggering_actor")
        ),
        "DEPENDENCY_RUN_MISMATCH",
    )
    file = get("/contents/" + pin["workflow"] + "?ref=" + pin["workflow_revision"])
    c._require(
        file.get("type") == "file"
        and file.get("path") == pin["workflow"]
        and file.get("encoding") == "base64",
        "DEPENDENCY_WORKFLOW_MISMATCH",
    )
    raw = base64.b64decode(file["content"].replace("\n", ""), validate=True)
    c._require(digest(raw) == pin["workflow_sha256"], "DEPENDENCY_WORKFLOW_MISMATCH")
    workflow = decode(raw)
    expected_job = verification_job(
        pin["provider"], pin["executor_repository"], pin["executor_revision"]
    )
    # Full workflow digest is independently owner-pinned. This additionally checks
    # the supported fixed producer, so an apply/reconcile success cannot impersonate verify.
    c._require(
        workflow["jobs"].get("verify") == expected_job, "DEPENDENCY_EXECUTOR_MISMATCH"
    )
    c._require(
        workflow.get("run-name")
        == "cloud:${{ inputs.request_sha256 }}:${{ inputs.preview_sha256 }}"
        and workflow.get("permissions") == {},
        "DEPENDENCY_WORKFLOW_MISMATCH",
    )
    listing = get(suffix + "/attempts/1/jobs?per_page=100&page=1")
    jobs = listing["jobs"]
    c._require(
        type(listing["total_count"]) is int
        and 1 <= listing["total_count"] <= 100
        and type(jobs) is list
        and len(jobs) == listing["total_count"],
        "PAGINATION_INCOMPLETE",
    )
    c._unique([j["id"] for j in jobs])
    matches = [j for j in jobs if j["name"] == "verify"]
    c._require(len(matches) == 1, "DEPENDENCY_VERIFY_JOB_REQUIRED")
    job = matches[0]
    c._require(
        type(job["id"]) is int
        and job["id"] > 0
        and all(
            job[k] == expected[k]
            for k in ("run_attempt", "head_sha", "status", "conclusion")
        )
        and job["run_id"] == pin["producer_run_id"],
        "DEPENDENCY_VERIFY_JOB_REQUIRED",
    )
    starts, ends = [], []
    for step in expected_job["steps"]:
        matches = [s for s in job["steps"] if s["name"] == step["name"]]
        c._require(
            len(matches) == 1
            and matches[0]["status"] == "completed"
            and matches[0]["conclusion"] == "success",
            "DEPENDENCY_VERIFY_STEP_REQUIRED",
        )
        start, end = (matches[0][k] for k in ("started_at", "completed_at"))
        c._require(
            c._utc(job["started_at"])
            <= c._utc(start)
            <= c._utc(end)
            <= c._utc(job["completed_at"])
            <= c._utc(now),
            "DEPENDENCY_COMPLETION_WINDOW",
        )
        starts.append(start)
        ends.append(end)
    environment = get("/environments/sandbox-verify")
    rules = [
        r for r in environment["protection_rules"] if r["type"] == "required_reviewers"
    ]
    c._require(
        environment["id"] == pin["environment_id"]
        and environment["name"] == "sandbox-verify"
        and environment["can_admins_bypass"] is False
        and environment["deployment_branch_policy"]
        == dict(protected_branches=True, custom_branch_policies=False)
        and len(rules) == 1
        and rules[0]["prevent_self_review"] is True
        and len(rules[0]["reviewers"]) == len(pin["reviewers"])
        and sorted(
            [
                [r["reviewer"]["id"], r["reviewer"]["login"]]
                for r in rules[0]["reviewers"]
                if r["type"] == "User"
            ]
        )
        == sorted(pin["reviewers"]),
        "DEPENDENCY_ENVIRONMENT_MISMATCH",
    )
    approvals = get(suffix + "/approvals")
    c._require(
        type(approvals) is list and len(approvals) == 1, "DEPENDENCY_APPROVAL_MISMATCH"
    )
    approval = approvals[0]
    c._require(
        approval["state"] == "approved"
        and [approval["user"]["id"], approval["user"]["login"]] in pin["reviewers"]
        and all(
            approval["user"]["id"] != run[k]["id"]
            for k in ("actor", "triggering_actor")
        )
        and approval["environments"]
        == [dict(id=pin["environment_id"], name="sandbox-verify")],
        "DEPENDENCY_APPROVAL_MISMATCH",
    )
    return starts[1], ends[1]


def _verified(
    pin: dict,
    runtime,
    transport,
    *,
    clock: Callable[[], float],
    expected_request: dict | None = None,
) -> tuple[dict, bytes, datetime]:
    """Fresh authenticated acquisition is the authority; pure reducer checks its bytes."""
    validate_trust(pin)
    with tempfile.TemporaryDirectory(prefix="cloud-predecessor-") as temp:
        root = Path(temp).resolve() / "artifact"
        metadata = acquire_bundle(
            root,
            pin["repository"],
            pin["artifact_id"],
            pin["producer_run_id"],
            runtime.github_token,
        )
        request_raw = c.read_verified(root, pin["request"])
        request = c.parse_artifact(request_raw, "cloud-run-request/v1")
        c._require(
            all(
                request[k] == pin[k] for k in ("run_id", "unit_id", "provider", "scope")
            )
            and request["verification_profile"] == pin["profile"]
            and (expected_request is None or request == expected_request),
            "DEPENDENCY_REQUEST_BINDING",
        )
        output = request["local_context"]["evidence_directory"] + "/verify-result.json"

        def read(path):
            # Safe contained read even for producer files without an embedded digest.
            with c._parent(root, path) as (fd, name):
                file_fd = os.open(
                    name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd
                )
                with os.fdopen(file_fd, "rb") as stream:
                    c._require(
                        stat.S_ISREG(os.fstat(stream.fileno()).st_mode), "UNSAFE_FILE"
                    )
                    raw = stream.read(c.MAX_BYTES + 1)
                    c._require(len(raw) <= c.MAX_BYTES, "ARTIFACT_TOO_LARGE")
                    return raw

        contract_raw = read(output + ".contract.json")
        contract = decode(contract_raw)
        c._require(
            contract["request"] == pin["request"]
            and contract["verification"] == pin["verification"],
            "DEPENDENCY_PRODUCER_OUTPUT_MISMATCH",
        )
        started, ended = _producer(
            pin, runtime, transport, pin["request"], contract["preview"], v.utc(clock())
        )
        c._require(
            metadata["name"]
            == pin["provider"] + "-verify-" + str(pin["producer_run_id"])
            and metadata["workflow_run"]["head_sha"] == pin["workflow_revision"]
            and metadata["workflow_run"]["repository_id"] == pin["repository_id"]
            and metadata["workflow_run"]["head_repository_id"] == pin["repository_id"],
            "DEPENDENCY_ARTIFACT_PRODUCER_MISMATCH",
        )
        # Keep saved-file selection deliberately BLOCKED. Its checks validate the
        # closed contract; authentication above, not an override flag, establishes origin.
        v.saved_profile_plan(contract_raw, root)
        raw = c.read_verified(root, pin["verification"])
        verification = c.parse_artifact(raw, "cloud-verification/v1")
        manifest = decode(read(output + ".manifest.json"))
        c._require(
            set(manifest)
            == {
                "schema",
                "request",
                "context",
                "observations",
                "verification",
                "classification",
                "provenance",
                "saved_receipt_authorizes_nothing",
            }
            and manifest["schema"] == "cloud-observation-evidence/v1"
            and manifest["request"] == pin["request"]
            and manifest["verification"] == pin["verification"]
            and manifest["classification"] == "native"
            and manifest["provenance"] == "fresh-authenticated-collection"
            and manifest["saved_receipt_authorizes_nothing"] is True,
            "DEPENDENCY_PRODUCER_OUTPUT_MISMATCH",
        )
        context = decode(c.read_verified(root, manifest["context"]))
        c._require(
            c._utc(started) <= c._utc(context["collected_at"]) <= c._utc(ended),
            "DEPENDENCY_COMPLETION_WINDOW",
        )
        records = []
        for item in manifest["observations"]:
            c._require(
                set(item) == {"check_id", "observation", "result"},
                "DEPENDENCY_PRODUCER_OUTPUT_MISMATCH",
            )
            observation = c.read_verified(root, item["observation"])
            c._require(
                c.parse_artifact(observation)["result"] == item["result"],
                "DEPENDENCY_PRODUCER_OUTPUT_MISMATCH",
            )
            records.append(
                dict(
                    check_id=item["check_id"],
                    observation_path=item["observation"]["path"],
                    observation_bytes=observation,
                    payload_bytes=c.read_verified(root, item["result"]),
                )
            )
        profile_raw = c.read_verified(root, c._file_ref(pin["profile"]))
        profile = c.parse_artifact(profile_raw, "cloud-verification-profile/v1")
        policy = c.read_artifact(root, request["policy"], "cloud-deployment-policy/v1")
        selection = v.protected_selection(profile, policy)
        reduced = v.reduce(
            request,
            pin["request"],
            profile,
            policy,
            context,
            records,
            now=v.utc(clock()),
            trusted_native=True,
            request_bytes=request_raw,
            profile_bytes=profile_raw,
        )
        c._require(
            reduced == verification
            and reduced["overall_result"] == "PASS"
            and reduced["evidence_complete"] is True,
            "DEPENDENCY_NOT_VERIFIED",
        )
        plan = v._profile_plan(
            request,
            pin["request"],
            verification,
            pin["verification"],
            contract["preview"],
            selection,
            fresh=True,
        )
        c._require(
            decode(read(output + ".selected-plan.json")) == plan,
            "DEPENDENCY_PRODUCER_OUTPUT_MISMATCH",
        )
        operation = c.parse_artifact(read(output), "cloud-operation-result/v1")
        c._require(
            all(operation[k] == request[k] for k in ("run_id", "unit_id", "provider"))
            and operation["operation"] == "verify"
            and operation["state"] == "EVIDENCE_COMPLETE"
            and operation["result"] == "PASS"
            and operation["input_manifest_sha256"] == pin["request"]["sha256"]
            and operation["native_operation_id"] == context["native_operation_id"]
            and operation["evidence_manifest_path"] == output + ".manifest.json",
            "DEPENDENCY_PRODUCER_OUTPUT_MISMATCH",
        )
        deadline = min(
            c._utc(decode(r["payload_bytes"])["sampled_at"])
            + timedelta(seconds=profile["max_age_seconds"])
            for r in records
        )
        c._require(c._utc(v.utc(clock())) <= deadline, "DEPENDENCY_NOT_VERIFIED")
        return operation, raw, deadline


def admit_predecessors(
    root: Path,
    request: dict,
    request_ref: dict,
    policy,
    runtime,
    transport,
    *,
    clock: Callable[[], float],
) -> datetime | None:
    pins = policy.predecessor_trust
    refs = request["predecessor_receipts"]
    if not refs and not pins and not policy.dependency_request_sha256:
        return None
    c._require(
        request_ref["sha256"] == policy.dependency_request_sha256,
        "DEPENDENCY_CONSUMER_MISMATCH",
    )
    expected = [dict(unit_id=pin["unit_id"], **pin["verification"]) for pin in pins]
    c._require(
        len({p["unit_id"] for p in pins}) == len(pins)
        and sorted(refs, key=lambda x: x["unit_id"])
        == sorted(expected, key=lambda x: x["unit_id"]),
        "DEPENDENCY_SET_MISMATCH",
    )
    deadlines = []
    for pin in sorted(pins, key=lambda x: x["unit_id"]):
        _, authenticated, deadline = _verified(pin, runtime, transport, clock=clock)
        deadlines.append(deadline)
        c._require(
            c.read_verified(root, pin["verification"]) == authenticated,
            "DEPENDENCY_RECEIPT_MISMATCH",
        )
    c._require(
        all(c._utc(v.utc(clock())) <= end for end in deadlines),
        "DEPENDENCY_NOT_VERIFIED",
    )

    return min(deadlines) if deadlines else None


def ordered_units(requests: list[dict]) -> list[dict]:
    """Validate the entire finite unit graph before any callback; lexical ready order."""
    c._require(type(requests) is list and bool(requests), "DEPENDENCY_GRAPH_EMPTY")
    for request in requests:
        c._request(request)
    units = {r["unit_id"]: r for r in requests}
    c._require(len(units) == len(requests), "DEPENDENCY_DUPLICATE_UNIT")
    edges = {
        key: {ref["unit_id"] for ref in row["predecessor_receipts"]}
        for key, row in units.items()
    }
    c._require(
        all(deps <= units.keys() for deps in edges.values()), "DEPENDENCY_MISSING_UNIT"
    )
    ordered = []
    while edges:
        ready = sorted(key for key, deps in edges.items() if not deps)
        c._require(bool(ready), "DEPENDENCY_CYCLE")
        # One at a time gives stable lexical order among all currently ready units.
        key = ready[0]
        ordered.append(units[key])
        del edges[key]
        for deps in edges.values():
            deps.discard(key)
    return ordered


def dispatch(
    requests: list[dict],
    execute: Callable[[dict], dict],
    proofs: dict[str, dict],
    runtime,
    *,
    transport=None,
    clock: Callable[[], float] = time.time,
) -> dict:
    """Per-unit callback ordering only. Provider boundary still owns every write.

    Never retries or rolls back. UNKNOWN is returned with its original native ID;
    reconciliation belongs to the provider. Only authenticated verify output can
    release dependents or produce an aggregate VERIFIED result.
    """
    from cloud_authorization import HttpsTransport

    ordered = ordered_units(requests)
    results: dict[str, dict] = {}
    verified: set[str] = set()
    for request in ordered:
        key = request["unit_id"]
        if any(
            ref["unit_id"] not in verified for ref in request["predecessor_receipts"]
        ):
            results[key] = dict(result="BLOCKED", error_code="DEPENDENCY_NOT_VERIFIED")
            continue
        result = execute(request)
        results[key] = result
        if result.get("result") != "PASS":
            continue
        try:
            pin = proofs[key]
            c._require(
                all(
                    pin[k] == request[k]
                    for k in ("run_id", "unit_id", "provider", "scope")
                ),
                "DEPENDENCY_REQUEST_BINDING",
            )
            c._require(
                pin["request"]["sha256"] == result["input_manifest_sha256"],
                "DEPENDENCY_REQUEST_BINDING",
            )
            operation, _, _ = _verified(
                pin,
                runtime,
                transport or HttpsTransport(),
                clock=clock,
                expected_request=request,
            )
            c._require(operation == result, "DEPENDENCY_PRODUCER_OUTPUT_MISMATCH")
            verified.add(key)
        except (ValueError, KeyError, TypeError, OSError):
            # The original result/evidence is immutable; aggregate denial is separate.
            pass
    return dict(
        order=[r["unit_id"] for r in ordered],
        units=results,
        aggregate="VERIFIED" if len(verified) == len(ordered) else "BLOCKED",
    )
