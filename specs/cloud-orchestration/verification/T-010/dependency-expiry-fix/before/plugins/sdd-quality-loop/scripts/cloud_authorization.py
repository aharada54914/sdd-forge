"""Protected GitHub admission, not a cloud engine or local approval authority.

Trusted, pinned provider adapters call WriteBoundary.write for EVERY mutation.
Policy and this module must come from the external protected executor, never
from deployment inputs. Runtime strings alone grant nothing: HTTPS GitHub OIDC,
REST metadata, native provider federation and identity readback must all agree.
Transport/clock injection is for deterministic tests in trusted code ONLY; there
is no fixture-file, receipt-import, approved-flag or environment-based bypass.

Receipts are integrity/audit artifacts. Exclusive publication and an in-process
latch prevent job-local duplicate submissions, NOT distributed serialization or
durable external authorization. GitHub first-attempt-only protected jobs plus
account/region workflow concurrency and externally enforced exclusive repository
write ownership are prerequisites. A lost process never resumes writes; reconcile
original operation IDs, then use a fresh separately approved dispatch if needed.
"""

from __future__ import annotations

import base64
from dataclasses import dataclass, field
from datetime import datetime, timezone
import hashlib
import hmac
import json
from pathlib import Path
import re
import threading
import time
from typing import Any, Callable, Protocol
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

import cloud_contracts as contracts

ISSUER = "https://token.actions.githubusercontent.com"
GITHUB = "https://api.github.com"
STS = "https://sts.amazonaws.com/"
MAX_RESPONSE = 4 * 1024 * 1024


class AdmissionDenied(ValueError):
    """Safe fixed diagnostic. The adapter maps this pre-write error to BLOCKED."""


def require(condition: object, code: str = "ADMISSION_DENIED") -> None:
    if not condition:
        raise AdmissionDenied(code)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def encode(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, ensure_ascii=True) + "\n").encode()


def decode(data: bytes) -> Any:
    require(type(data) is bytes and len(data) <= MAX_RESPONSE)

    def pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in items:
            require(key not in result)
            result[key] = value
        return result

    def invalid(_: str) -> None:
        raise AdmissionDenied("INVALID_AUTH_RESPONSE")

    return json.loads(
        data.decode("utf-8"), object_pairs_hook=pairs, parse_constant=invalid, parse_float=invalid
    )


def claims_from_authenticated_response(token: str) -> dict[str, Any]:
    """Decode ONLY tokens just obtained from a fixed authenticated HTTPS issuer.

    This is not a general JWT verifier. Caller-supplied token files are unsupported.
    GitHub's TLS response authenticates its claims; provider federation additionally
    validates the GitHub JWT signature/audience/subject. Entra's TLS token endpoint
    response authenticates the access-token claims returned by that endpoint.
    """
    require(type(token) is str and len(token) < MAX_RESPONSE)
    parts = token.split(".")
    require(len(parts) == 3)
    value = decode(base64.b64decode(parts[1] + "=" * (-len(parts[1]) % 4), altchars=b"-_", validate=True))
    require(type(value) is dict)
    return value


def utc(epoch: int) -> str:
    return datetime.fromtimestamp(epoch, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def epoch(value: str) -> int:
    require(re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", value))
    return int(datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc).timestamp())


class Transport(Protocol):
    def request(self, method: str, url: str, headers: dict[str, str], body: bytes | None = None) -> bytes: ...


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req: Any, fp: Any, code: int, msg: str, headers: Any, newurl: str) -> None:
        raise AdmissionDenied("AUTH_REDIRECT_DENIED")


class HttpsTransport:
    """TLS verification on, redirects off, bounded read/deadline, no HTTP retries."""

    def request(self, method: str, url: str, headers: dict[str, str], body: bytes | None = None) -> bytes:
        try:
            parsed = urllib.parse.urlsplit(url)
            require(
                parsed.scheme == "https"
                and parsed.hostname
                and not parsed.username
                and not parsed.password
                and not parsed.fragment
                and parsed.port in (None, 443)
            )
            opener = urllib.request.build_opener(NoRedirect())
            request = urllib.request.Request(url, data=body, headers=headers, method=method)
            with opener.open(request, timeout=20) as response:
                require(response.status == 200 and response.geturl() == url)
                data = response.read(MAX_RESPONSE + 1)
                require(len(data) <= MAX_RESPONSE)
                return data
        except Exception:
            raise AdmissionDenied("AUTH_SERVICE_UNAVAILABLE") from None


@dataclass(frozen=True)
class Runtime:
    github_token: str = field(repr=False)
    oidc_url: str = field(repr=False)
    oidc_token: str = field(repr=False)


@dataclass(frozen=True)
class Policy:
    """External trusted executor configuration, NOT parsed from run-request JSON.

    The policy SHA binds the owner-reviewed policy copy in the artifact bundle.
    Exclusive ownership must be established by platform IAM/repository administrators;
    this local object cannot prove absence of other writers in an account.
    """

    provider: str
    repository: str
    repository_id: int
    workflow: str
    workflow_revision: str
    ref: str
    operation: str
    environment: str
    target_environment: str
    environment_id: int
    account_id: str
    region: str
    deployment_scope: str
    policy_sha256: str
    actors: tuple[tuple[int, str], ...]
    reviewers: tuple[tuple[int, str], ...]
    exclusive_repository: str
    ttl_seconds: int
    aws_role_arn: str = ""
    azure_tenant: str = ""
    azure_client: str = ""
    azure_principal: str = ""
    dependency_request_sha256: str = ""
    predecessor_trust: tuple[dict, ...] = ()


def concurrency_key(policy: Policy) -> str:
    """Conservative key: stack/group/unit deliberately excluded."""
    require(policy.provider in ("aws", "azure"))
    require(re.fullmatch(r"[a-z0-9-]+", policy.account_id))
    require(re.fullmatch(r"[a-z0-9-]+", policy.region))
    return f"cloud-{policy.provider}-{policy.account_id}-{policy.region}"


def _policy_valid(p: Policy) -> None:
    concurrency_key(p)
    require(p.exclusive_repository == p.repository, "EXCLUSIVE_WRITER_REQUIRED")
    require(re.fullmatch(r"[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+", p.repository))
    require(re.fullmatch(r"\.github/workflows/[A-Za-z0-9_.-]+\.ya?ml", p.workflow))
    require(re.fullmatch(r"[a-f0-9]{40}", p.workflow_revision))
    require(re.fullmatch(r"refs/heads/[A-Za-z0-9_/-]+", p.ref))
    require(p.operation in ("prepare", "apply") and (p.environment.endswith("-" + p.operation)
            or (p.operation == "apply" and p.environment == "sandbox-verify")))
    if p.predecessor_trust or p.dependency_request_sha256:
        from cloud_dependencies import validate_trust
        contracts._sha(p.dependency_request_sha256)
        require(type(p.predecessor_trust) is tuple)
        for pin in p.predecessor_trust:
            validate_trust(pin)
    require(re.fullmatch(r"[A-Za-z0-9_-]+", p.environment))
    require(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:-]{0,127}", p.target_environment))
    require(re.fullmatch(r"[a-f0-9]{64}", p.policy_sha256))
    require(type(p.ttl_seconds) is int and 0 < p.ttl_seconds <= 3600)
    require(type(p.repository_id) is int and p.repository_id > 0)
    require(type(p.environment_id) is int and p.environment_id > 0)
    for identities in (p.actors, p.reviewers):
        require(bool(identities) and len(set(identities)) == len(identities))
        for number, name in identities:
            require(type(number) is int and number > 0 and re.fullmatch(r"[A-Za-z0-9_-]+", name))
    if p.provider == "aws":
        require(re.fullmatch(r"\d{12}", p.account_id))
        require(re.fullmatch(r"arn:aws:iam::" + p.account_id + r":role/[A-Za-z0-9_+=,.@/-]+", p.aws_role_arn))
    else:
        for identifier in (p.account_id, p.azure_tenant, p.azure_client, p.azure_principal):
            require(re.fullmatch(r"[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}", identifier))


def _window(claims: dict[str, Any], now: int) -> None:
    for key in ("iat", "nbf", "exp"):
        require(type(claims[key]) is int)
    require(claims["iat"] <= now and claims["nbf"] <= now < claims["exp"])
    require(claims["iat"] < claims["exp"])


class GitHubAdmission:
    def __init__(self, policy: Policy, runtime: Runtime, transport: Transport):
        self.policy, self.runtime, self.transport = policy, runtime, transport

    def oidc(self, now: int) -> tuple[str, dict[str, Any]]:
        p, runtime = self.policy, self.runtime
        require(
            all(type(v) is str and v for v in (runtime.github_token, runtime.oidc_url, runtime.oidc_token)),
            "PROTECTED_WORKFLOW_REQUIRED",
        )
        url = urllib.parse.urlsplit(runtime.oidc_url)
        require(
            url.scheme == "https"
            and url.netloc == "pipelines.actions.githubusercontent.com"
            and not url.fragment
            and url.path.endswith("/idtoken")
            and "%" not in url.path
        )
        query = urllib.parse.parse_qs(url.query, strict_parsing=True)
        require(set(query) == {"api-version"} and len(query["api-version"]) == 1)
        audience = "sts.amazonaws.com" if p.provider == "aws" else "api://AzureADTokenExchange"
        response = decode(
            self.transport.request(
                "GET",
                runtime.oidc_url + "&audience=" + urllib.parse.quote(audience, safe=""),
                {"Authorization": "Bearer " + runtime.oidc_token},
            )
        )
        token = response["value"]
        claims = claims_from_authenticated_response(token)
        expected = dict(
            iss=ISSUER,
            aud=audience,
            repository=p.repository,
            repository_id=str(p.repository_id),
            workflow_ref=f"{p.repository}/{p.workflow}@{p.ref}",
            workflow_sha=p.workflow_revision,
            ref=p.ref,
            sha=p.workflow_revision,
            environment=p.environment,
            event_name="workflow_dispatch",
            run_attempt="1",
            sub=f"repo:{p.repository}:environment:{p.environment}:workflow_ref:{p.repository}/{p.workflow}@{p.ref}:workflow_sha:{p.workflow_revision}",
        )
        for key, value in expected.items():
            require(claims[key] == value, "OIDC_BINDING_MISMATCH")
        require(type(claims["run_id"]) is str and re.fullmatch(r"[1-9][0-9]{0,19}", claims["run_id"]))
        require((int(claims["actor_id"]), claims["actor"]) in p.actors)
        _window(claims, now)
        return token, claims

    def metadata(self, claims: dict[str, Any], request_sha: str, preview_sha: str) -> dict[str, str]:
        p = self.policy
        base = f"{GITHUB}/repos/{p.repository}"
        run_url = base + "/actions/runs/" + claims["run_id"]
        headers = {
            "Authorization": "Bearer " + self.runtime.github_token,
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        }
        run = decode(self.transport.request("GET", run_url, headers))
        expected = dict(
            id=int(claims["run_id"]),
            run_attempt=1,
            status="in_progress",
            conclusion=None,
            event="workflow_dispatch",
            head_sha=p.workflow_revision,
            head_branch=p.ref.removeprefix("refs/heads/"),
            path=p.workflow,
            display_title=f"cloud:{request_sha}:{preview_sha}",
        )
        for key, value in expected.items():
            require(type(run[key]) is type(value) and run[key] == value, "RUN_BINDING_MISMATCH")
        for key in ("repository", "head_repository"):
            require(run[key]["id"] == p.repository_id and run[key]["full_name"] == p.repository)
        for key in ("actor", "triggering_actor"):
            require((run[key]["id"], run[key]["login"]) == (int(claims["actor_id"]), claims["actor"]))
        environment = decode(self.transport.request("GET", base + "/environments/" + p.environment, headers))
        require(environment["id"] == p.environment_id and environment["name"] == p.environment)
        require(environment["can_admins_bypass"] is False)
        require(
            environment["deployment_branch_policy"]
            == dict(protected_branches=True, custom_branch_policies=False)
        )
        rules = [r for r in environment["protection_rules"] if r["type"] == "required_reviewers"]
        require(len(rules) == 1 and rules[0]["prevent_self_review"] is True)
        reviewers = {
            (r["reviewer"]["id"], r["reviewer"]["login"])
            for r in rules[0]["reviewers"]
            if r["type"] == "User"
        }
        require(
            len(rules[0]["reviewers"]) == len(reviewers) and reviewers == set(p.reviewers),
            "REVIEWER_POLICY_MISMATCH",
        )
        approval_url = run_url + "/approvals"
        raw = self.transport.request("GET", approval_url, headers)
        history = decode(raw)
        require(type(history) is list and len(history) == 1, "AMBIGUOUS_REVIEW_HISTORY")
        matched = []
        for review in history:
            require(type(review["environments"]) is list and len(review["environments"]) == 1)
            for env in review["environments"]:
                # Either identity matching but not the other is itself ambiguous.
                if env["id"] == p.environment_id or env["name"] == p.environment:
                    require(env["id"] == p.environment_id and env["name"] == p.environment)
                    matched.append(review)
        require(len(matched) == 1, "AMBIGUOUS_REVIEW_HISTORY")
        review = matched[0]
        require(review["state"] == "approved", "APPROVAL_REQUIRED")
        user = (review["user"]["id"], review["user"]["login"])
        require(user in reviewers and user != (int(claims["actor_id"]), claims["actor"]), "REVIEWER_MISMATCH")
        return dict(locator=approval_url, sha256=digest(raw))


def _xml_result(raw: bytes, action: str) -> ET.Element:
    require(len(raw) <= MAX_RESPONSE and b"<!" not in raw)
    root = ET.fromstring(raw)
    namespace = "{https://sts.amazonaws.com/doc/2011-06-15/}"
    require(root.tag == namespace + action + "Response")
    results = root.findall(namespace + action + "Result")
    require(len(results) == 1)
    return results[0]


def _xml_text(root: ET.Element, path: str) -> str:
    namespace = "{https://sts.amazonaws.com/doc/2011-06-15/}"
    elements = root.findall("/".join(namespace + part for part in path.split("/")))
    require(len(elements) == 1 and bool(elements[0].text))
    return str(elements[0].text)


def _sts_headers(body: bytes, credentials: dict[str, str], now: int) -> dict[str, str]:
    """SigV4 for the single read-only STS GetCallerIdentity request."""
    stamp = datetime.fromtimestamp(now, timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    date = stamp[:8]
    canonical_headers = (
        "content-type:application/x-www-form-urlencoded\nhost:sts.amazonaws.com\n"
        f"x-amz-date:{stamp}\nx-amz-security-token:{credentials['AWS_SESSION_TOKEN']}\n"
    )
    names = "content-type;host;x-amz-date;x-amz-security-token"
    canonical = f"POST\n/\n\n{canonical_headers}\n{names}\n{digest(body)}"
    scope = date + "/us-east-1/sts/aws4_request"
    string = f"AWS4-HMAC-SHA256\n{stamp}\n{scope}\n{digest(canonical.encode())}"
    key = ("AWS4" + credentials["AWS_SECRET_ACCESS_KEY"]).encode()
    for part in (date, "us-east-1", "sts", "aws4_request"):
        key = hmac.new(key, part.encode(), hashlib.sha256).digest()
    signature = hmac.new(key, string.encode(), hashlib.sha256).hexdigest()
    return {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-Amz-Date": stamp,
        "X-Amz-Security-Token": credentials["AWS_SESSION_TOKEN"],
        "Authorization": f"AWS4-HMAC-SHA256 Credential={credentials['AWS_ACCESS_KEY_ID']}/{scope}, SignedHeaders={names}, Signature={signature}",
    }


class AwsIdentity:
    """Native STS federation followed by signed identity readback; no resource API."""

    @staticmethod
    def exchange(
        p: Policy, token: str, claims: dict[str, Any], transport: Transport, now: int
    ) -> tuple[str, int, dict[str, str]]:
        body = urllib.parse.urlencode(
            dict(
                Action="AssumeRoleWithWebIdentity",
                Version="2011-06-15",
                RoleArn=p.aws_role_arn,
                RoleSessionName="sdd-" + claims["run_id"],
                WebIdentityToken=token,
                DurationSeconds=900,
            )
        ).encode()
        result = _xml_result(
            transport.request("POST", STS, {"Content-Type": "application/x-www-form-urlencoded"}, body),
            "AssumeRoleWithWebIdentity",
        )
        require(_xml_text(result, "SubjectFromWebIdentityToken") == claims["sub"])
        require(_xml_text(result, "Audience") == "sts.amazonaws.com")
        require(_xml_text(result, "Provider") == ISSUER)
        principal = f"arn:aws:sts::{p.account_id}:assumed-role/{p.aws_role_arn.rsplit('/', 1)[1]}/sdd-{claims['run_id']}"
        require(_xml_text(result, "AssumedRoleUser/Arn") == principal, "PROVIDER_PRINCIPAL_MISMATCH")
        end = epoch(_xml_text(result, "Credentials/Expiration"))
        credentials = {
            key: _xml_text(result, "Credentials/" + field_name)
            for key, field_name in (
                ("AWS_ACCESS_KEY_ID", "AccessKeyId"),
                ("AWS_SECRET_ACCESS_KEY", "SecretAccessKey"),
                ("AWS_SESSION_TOKEN", "SessionToken"),
            )
        }
        require(end > now, "CREDENTIAL_EXPIRED")
        body = urllib.parse.urlencode(dict(Action="GetCallerIdentity", Version="2011-06-15")).encode()
        identity = _xml_result(
            transport.request("POST", STS, _sts_headers(body, credentials, now), body), "GetCallerIdentity"
        )
        require(
            _xml_text(identity, "Account") == p.account_id and _xml_text(identity, "Arn") == principal,
            "PROVIDER_PRINCIPAL_MISMATCH",
        )
        return principal, end, credentials


class AzureIdentity:
    """Authenticated Entra token issuance/claims plus ARM subscription readback.

    No supplied access-token JWT is accepted. Principal claims are read solely from
    Entra's TLS token response, not from CLI account metadata or unverified files.
    """

    @staticmethod
    def exchange(
        p: Policy, token: str, claims: dict[str, Any], transport: Transport, now: int
    ) -> tuple[str, int, dict[str, str]]:
        body = urllib.parse.urlencode(
            dict(
                client_id=p.azure_client,
                grant_type="client_credentials",
                scope="https://management.azure.com/.default",
                client_assertion_type="urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
                client_assertion=token,
            )
        ).encode()
        response = decode(
            transport.request(
                "POST",
                f"https://login.microsoftonline.com/{p.azure_tenant}/oauth2/v2.0/token",
                {"Content-Type": "application/x-www-form-urlencoded"},
                body,
            )
        )
        require(
            response["token_type"] == "Bearer"
            and type(response["expires_in"]) is int
            and response["expires_in"] > 0
        )
        access = response["access_token"]
        identity = claims_from_authenticated_response(access)
        _window(identity, now)
        require(identity["oid"] == p.azure_principal and identity["tid"] == p.azure_tenant)
        require(identity.get("appid", identity.get("azp")) == p.azure_client)
        require(identity["aud"] == "https://management.azure.com/")
        subscription = decode(
            transport.request(
                "GET",
                f"https://management.azure.com/subscriptions/{p.account_id}?api-version=2022-12-01",
                {"Authorization": "Bearer " + access},
            )
        )
        require(
            subscription["subscriptionId"] == p.account_id
            and subscription["tenantId"] == p.azure_tenant
            and subscription["state"] == "Enabled",
            "PROVIDER_SCOPE_MISMATCH",
        )
        return (
            p.azure_principal,
            min(identity["exp"], now + response["expires_in"]),
            {"AZURE_ACCESS_TOKEN": access},
        )


class WriteBoundary:
    """One protected job's pre-write boundary. Submit is called at most once.

    Adapters own native operation IDs, fixed commands, exact in-memory artifact
    bytes, provider preview semantics, tool-closure checks and UNKNOWN recovery.
    Callers MUST NOT load executable code/policy from the artifact root. The callback
    receives only the newly federated credentials, never local CLI credentials.
    Receipt files are permanent consumed markers even when submission raises.
    """

    def __init__(
        self,
        policy: Policy,
        runtime: Runtime,
        evidence_root: Path,
        *,
        transport: Transport | None = None,
        clock: Callable[[], float] = time.time,
    ):
        self.policy, self.runtime, self.evidence_root = policy, runtime, evidence_root
        self.transport = transport if transport is not None else HttpsTransport()
        self.clock = clock
        self._seen: set[str] = set()
        self._mutex = threading.Lock()

    def write(
        self,
        root: Path,
        request_ref: dict[str, str],
        preview_ref: dict[str, str] | None,
        *,
        mutation_id: str,
        submit: Callable[[dict[str, str]], Any],
        scan: Callable[[bytes], bool],
    ) -> tuple[dict[str, str], Any]:
        """Fresh admission then exclusive audit publication then one mutation.

        No imported receipt can grant admission. Stable mutation_id comes from the
        trusted adapter's deterministic operation plan, never a retry-generated UUID.
        Predecessor proofs are reacquired on entry and immediately before submission.
        """
        with self._mutex:
            try:
                p = self.policy
                _policy_valid(p)
                require(p.environment.endswith("-" + p.operation), "READ_ONLY_ENVIRONMENT")
                require(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", mutation_id))
                now = int(self.clock())
                contracts.verify_binding(root, request_ref, preview_ref, now=utc(now), operation=p.operation)
                request = contracts.read_artifact(root, request_ref, "cloud-run-request/v1")
                require(
                    request["provider"] == p.provider
                    and request["operation"] == "apply"
                    and request["environment"] == p.target_environment,
                    "STAGE_MISMATCH",
                )
                require(
                    request["scope"]
                    == dict(account_id=p.account_id, region=p.region, deployment_scope=p.deployment_scope),
                    "SCOPE_MISMATCH",
                )
                require(request["policy"]["sha256"] == p.policy_sha256, "POLICY_MISMATCH")
                from cloud_dependencies import admit_predecessors
                admit_predecessors(root, request, request_ref, p, self.runtime, self.transport, clock=self.clock)
                require(self.evidence_root == root / request["local_context"]["evidence_directory"],
                        "EVIDENCE_BOUNDARY_MISMATCH")
                name = f"{request['unit_id']}.{p.operation}.{mutation_id}.authorization.json"
                require(name not in self._seen, "REPLAY_DENIED")
                github = GitHubAdmission(p, self.runtime, self.transport)
                token, claims = github.oidc(now)
                require(now < claims["iat"] + p.ttl_seconds, "CREDENTIAL_EXPIRED")
                preview_sha = preview_ref["sha256"] if preview_ref is not None else "none"
                github.metadata(claims, request_ref["sha256"], preview_sha)
                provider = AwsIdentity if p.provider == "aws" else AzureIdentity
                principal, lease_end, credentials = provider.exchange(p, token, claims, self.transport, now)
                # Recheck revocation, run state and exact bytes after federation, at the write site.
                approval = github.metadata(claims, request_ref["sha256"], preview_sha)
                end = min(lease_end, claims["exp"], claims["iat"] + p.ttl_seconds)
                if preview_ref is not None:
                    preview = contracts.read_artifact(root, preview_ref, "cloud-preview/v1")
                    end = min(end, epoch(preview["expires_at"]))
                now = int(self.clock())
                require(claims["iat"] <= now < end, "CREDENTIAL_EXPIRED")
                contracts.verify_binding(root, request_ref, preview_ref, now=utc(now), operation=p.operation)
                receipt = dict(
                    schema="cloud-authorization-receipt/v1",
                    **{
                        key: request[key]
                        for key in ("run_id", "unit_id", "provider", "scope", "dependency_lock", "policy")
                    },
                    request=request_ref,
                    verification_profile={
                        key: request["verification_profile"][key] for key in ("path", "sha256")
                    },
                    preview=preview_ref,
                    operation=p.operation,
                    issuer=ISSUER,
                    principal=principal,
                    subject=claims["sub"],
                    ci=dict(
                        repository=p.repository,
                        workflow=p.workflow,
                        workflow_revision=p.workflow_revision,
                        ref=p.ref,
                        environment=p.environment,
                        run_id=claims["run_id"],
                        run_attempt=1,
                    ),
                    issued_at=utc(claims["iat"]),
                    expires_at=utc(end),
                    approval_evidence=approval,
                )
                reference = contracts.publish_artifact(self.evidence_root, name, encode(receipt), scan=scan)
                self._seen.add(name)
                # Publication/scanning can take time; a failed last check keeps the
                # consumed marker and never falls through to a native mutation.
                require(int(self.clock()) < end, "CREDENTIAL_EXPIRED")
                dependency_deadline = admit_predecessors(root, request, request_ref, p, self.runtime, self.transport,
                                                        clock=self.clock)
                require(
                    github.metadata(claims, request_ref["sha256"], preview_sha) == approval,
                    "APPROVAL_CHANGED",
                )
                contracts.verify_binding(root, request_ref, preview_ref, now=utc(int(self.clock())), operation=p.operation)
                require(dependency_deadline is None or contracts._utc(utc(int(self.clock()))) <= dependency_deadline,
                        "DEPENDENCY_NOT_VERIFIED")
                require(int(self.clock()) < end, "CREDENTIAL_EXPIRED")
            except Exception:
                # Never echo native errors, tokens or attacker-controlled artifact bytes.
                raise AdmissionDenied("WRITE_ADMISSION_BLOCKED") from None
            # Submission exceptions are NOT converted to pre-write denial or retried.
            # All public references use the explicit workspace anchor, not a private sub-root.
            reference = dict(reference, path=request["local_context"]["evidence_directory"] + "/" + reference["path"])
            return reference, submit(credentials)
