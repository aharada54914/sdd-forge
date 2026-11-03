"""Bounded AWS Query/S3 HTTPS adapter; no SDK credential chain or mutation retries.

Wire contracts: CloudFormation 2010-05-15, S3 2006-03-01, AWS botocore model
4de93abe62cc263980414f7a66be5226bd541b77. Only the operations below are implemented.
Preserve S3 status/headers: a body-only authentication transport is insufficient.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import hmac
import re
import time
from typing import Callable, Protocol
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

from cloud import c, digest

CFN_VERSION = "2010-05-15"
MODEL_SHA256 = "142ac136f30bf2ba93723536c67e66443b00d86cc2128448916d6d7ab145eec3"
S3_MODEL_SHA256 = "84c3a4e6ac1c80ed49cb1ddf1f548ea7f51d8a41acbfa0f198b9ba0028d784e8"
CFN_NS = "http://cloudformation.amazonaws.com/doc/2010-05-15/"
S3_NS = "http://s3.amazonaws.com/doc/2006-03-01/"
OPERATIONS = {
    "CreateChangeSet": {
        "StackName",
        "TemplateURL",
        "RoleARN",
        "Tags",
        "ChangeSetName",
        "ClientToken",
        "Description",
        "ChangeSetType",
        "IncludeNestedStacks",
        "ImportExistingResources",
        "Parameters",
        "Capabilities",
    },
    "DescribeChangeSet": {"ChangeSetName", "StackName", "IncludePropertyValues"},
    "GetTemplate": {"StackName", "ChangeSetName", "TemplateStage"},
    "ExecuteChangeSet": {
        "ChangeSetName",
        "StackName",
        "ClientRequestToken",
        "DisableRollback",
        "RetainExceptOnCreate",
    },
    "DescribeStacks": {"StackName"},
    "DescribeStackEvents": {"StackName"},
    "DescribeStackResource": {"StackName", "LogicalResourceId"},
}
LISTS = {
    "Parameters",
    "Capabilities",
    "Changes",
    "Tags",
    "Stacks",
    "StackEvents",
    "StagesAvailable",
    "Details",
    "Scope",
    "NotificationARNs",
    "RollbackTriggers",
    "CausingEntityPath",
}
BOOLS = {
    "IncludeNestedStacks",
    "ImportExistingResources",
    "UsePreviousValue",
    "DriftIgnored",
    "DisableRollback",
    "RetainExceptOnCreate",
}


@dataclass(frozen=True)
class Response:
    status: int
    headers: dict[str, str]
    body: bytes


class Transport(Protocol):
    def request(
        self, method: str, url: str, headers: dict[str, str], body: bytes | None = None
    ) -> Response: ...


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("AWS_REDIRECT_DENIED")


class HttpsTransport:
    def request(
        self, method: str, url: str, headers: dict[str, str], body: bytes | None = None
    ) -> Response:
        c._require(method in ("GET", "POST", "PUT"), "AWS_METHOD_DENIED")
        request = urllib.request.Request(url, data=body, headers=headers, method=method)
        try:
            response = urllib.request.build_opener(NoRedirect()).open(
                request, timeout=20
            )
        except urllib.error.HTTPError as error:
            response = error
        with response:
            c._require(response.geturl() == url, "AWS_REDIRECT_DENIED")
            data = response.read(c.MAX_BYTES + 1)
            c._require(len(data) <= c.MAX_BYTES, "AWS_RESPONSE_TOO_LARGE")
            pairs = list(response.headers.items())
            c._require(
                len({k.lower() for k, _ in pairs}) == len(pairs), "AWS_DUPLICATE_HEADER"
            )
            return Response(response.status, dict(pairs), data)


def xml(raw: bytes, namespace: str) -> ET.Element:
    c._require(len(raw) <= c.MAX_BYTES and b"<!" not in raw, "AWS_XML_INVALID")
    root = ET.fromstring(raw)
    c._require(
        all(node.tag.startswith("{" + namespace + "}") for node in root.iter()),
        "AWS_XML_NAMESPACE",
    )
    c._require(sum(1 for _ in root.iter()) <= 50000, "AWS_XML_LIMIT")
    return root


def value(node: ET.Element, depth: int = 0):
    c._require(depth <= 48, "AWS_XML_LIMIT")
    key = node.tag.split("}")[-1]
    if key in LISTS:
        c._require(
            all(n.tag.split("}")[-1] == "member" for n in node), "AWS_LIST_INVALID"
        )
        return [value(n, depth + 1) for n in node]
    if len(node):
        keys = [n.tag.split("}")[-1] for n in node]
        c._unique(keys)
        return {k: value(n, depth + 1) for k, n in zip(keys, node)}
    if key in BOOLS:
        c._require(node.text in ("true", "false"), "AWS_BOOLEAN_INVALID")
        return node.text == "true"
    return node.text or ""


def query(action: str, params: dict) -> bytes:
    c._require(
        action in OPERATIONS and set(params) == OPERATIONS[action], "AWS_REQUEST_SHAPE"
    )
    if action == "CreateChangeSet":
        c._require(
            params["IncludeNestedStacks"] is False
            and params["ImportExistingResources"] is False,
            "AWS_REQUEST_SHAPE",
        )
    if action == "ExecuteChangeSet":
        c._require(
            params["DisableRollback"] is True
            and params["RetainExceptOnCreate"] is False,
            "AWS_FAILURE_POLICY",
        )
    pairs = [("Action", action), ("Version", CFN_VERSION)]
    for k, v in sorted(params.items()):
        if k in ("Tags", "Parameters"):
            keys = (
                ("Key", "Value") if k == "Tags" else ("ParameterKey", "ParameterValue")
            )
            for i, tag in enumerate(v, 1):
                c._require(set(tag) == set(keys), "AWS_REQUEST_SHAPE")
                for field in keys:
                    pairs.append((f"{k}.member.{i}.{field}", tag[field]))
        elif k == "Capabilities":
            c._require(v == [], "AWS_CAPABILITY_DENIED")
        else:
            c._require(type(v) in (str, bool), "AWS_REQUEST_SHAPE")
            pairs.append((k, str(v).lower() if type(v) is bool else v))
    return urllib.parse.urlencode(pairs, quote_via=urllib.parse.quote).encode()


def sign(
    method: str,
    url: str,
    body: bytes,
    headers: dict[str, str],
    credentials: dict[str, str],
    service: str,
    region: str,
    now: int,
) -> dict[str, str]:
    parsed = urllib.parse.urlsplit(url)
    stamp = datetime.fromtimestamp(now, timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    headers = {k.lower(): v for k, v in headers.items()}
    headers.update(
        host=parsed.netloc,
        **{
            "x-amz-date": stamp,
            "x-amz-security-token": credentials["AWS_SESSION_TOKEN"],
            "x-amz-content-sha256": digest(body),
        },
    )
    names = ";".join(sorted(headers))
    canonical_headers = "".join(
        k + ":" + " ".join(headers[k].split()) + "\n" for k in sorted(headers)
    )
    # Generated URLs already have canonical URI encoding. CFN is always '/'.
    qs = urllib.parse.urlencode(
        sorted(urllib.parse.parse_qsl(parsed.query, keep_blank_values=True)),
        quote_via=urllib.parse.quote,
        safe="~",
    )
    canonical = "\n".join(
        (method, parsed.path or "/", qs, canonical_headers, names, digest(body))
    )
    scope = stamp[:8] + "/" + region + "/" + service + "/aws4_request"
    text = (
        "AWS4-HMAC-SHA256\n" + stamp + "\n" + scope + "\n" + digest(canonical.encode())
    )
    key = ("AWS4" + credentials["AWS_SECRET_ACCESS_KEY"]).encode()
    for part in (stamp[:8], region, service, "aws4_request"):
        key = hmac.new(key, part.encode(), hashlib.sha256).digest()
    signature = hmac.new(key, text.encode(), hashlib.sha256).hexdigest()
    headers["Authorization"] = (
        f"AWS4-HMAC-SHA256 Credential={credentials['AWS_ACCESS_KEY_ID']}/{scope}, SignedHeaders={names}, Signature={signature}"
    )
    return headers


class Native:
    def __init__(
        self,
        scope: dict,
        bucket: str,
        transport: Transport | None = None,
        clock: Callable[[], float] = time.time,
    ):
        c._require(
            re.fullmatch(r"[a-z]{2}-[a-z]+-[1-9]", scope["region"]),
            "AWS_REGION_INVALID",
        )
        c._require(
            re.fullmatch(r"[a-z0-9][a-z0-9-]{1,61}[a-z0-9]", bucket),
            "S3_BUCKET_INVALID",
        )
        self.scope, self.bucket, self.clock = scope, bucket, clock
        self.transport = transport or HttpsTransport()
        self.origin = "https://cloudformation." + scope["region"] + ".amazonaws.com/"
        self.s3 = "https://" + bucket + ".s3." + scope["region"] + ".amazonaws.com/"
        self.trace: list[dict] = []

    def call(
        self,
        method: str,
        url: str,
        credentials: dict[str, str],
        body: bytes = b"",
        headers: dict[str, str] | None = None,
    ) -> Response:
        c._require(url.startswith(self.s3) or url == self.origin, "AWS_SCOPE_DENIED")
        service = "cloudformation" if url == self.origin else "s3"
        signed = sign(
            method,
            url,
            body,
            headers or {},
            credentials,
            service,
            self.scope["region"],
            int(self.clock()),
        )
        response = self.transport.request(
            method, url, signed, body if method != "GET" else None
        )
        c._require(len(response.body) <= c.MAX_BYTES, "AWS_RESPONSE_TOO_LARGE")
        self.trace.append(
            dict(
                method=method,
                url=url,
                status=response.status,
                response_sha256=digest(response.body),
                request_sha256=digest(body),
                classification="private-native-response-digest-only",
            )
        )
        return response

    def cfn(
        self,
        action: str,
        params: dict,
        credentials: dict[str, str],
        *,
        absent_stack: bool = False,
    ) -> dict:
        response = self.call(
            "POST",
            self.origin,
            credentials,
            query(action, params),
            {"content-type": "application/x-www-form-urlencoded"},
        )
        root = xml(response.body, CFN_NS)
        if absent_stack and response.status == 400:
            error = root.find("{" + CFN_NS + "}Error")
            if error is not None:
                obj = value(error)
                if (
                    obj.get("Code") == "ValidationError"
                    and obj.get("Message")
                    == "Stack with id " + params["StackName"] + " does not exist"
                ):
                    return {"Stacks": []}
        c._require(
            response.status == 200
            and root.tag == "{" + CFN_NS + "}" + action + "Response",
            "AWS_NATIVE_DENIED",
        )
        nodes = root.findall("{" + CFN_NS + "}" + action + "Result")
        c._require(len(nodes) == 1, "AWS_RESPONSE_SHAPE")
        result = value(nodes[0]) if len(nodes[0]) else {}
        # Deliberately block rather than ignore pagination or issue scope-widening queries.
        c._require(not result.get("NextToken"), "AWS_PAGINATION_UNSUPPORTED")
        return result

    def object_url(self, key: str, version: str | None = None) -> str:
        c._require(re.fullmatch(r"[a-f0-9]{64}\.json", key), "S3_KEY_DENIED")
        if version is not None:
            c._require(
                type(version) is str and 0 < len(version) <= 1024 and version != "null",
                "S3_VERSION_REQUIRED",
            )
        return (
            self.s3
            + key
            + (
                "?versionId=" + urllib.parse.quote(version, safe="")
                if version is not None
                else ""
            )
        )

    def owner_headers(self) -> dict[str, str]:
        return {"x-amz-expected-bucket-owner": self.scope["account_id"]}

    def bucket_check(self, credentials: dict[str, str]) -> None:
        for suffix in ("location", "versioning", "publicAccessBlock"):
            response = self.call(
                "GET",
                self.s3 + "?" + suffix + "=",
                credentials,
                headers=self.owner_headers(),
            )
            c._require(response.status == 200, "S3_PREREQUISITE_DENIED")
            root = xml(response.body, S3_NS)
            if suffix == "location":
                c._require(
                    root.tag == "{" + S3_NS + "}LocationConstraint"
                    and (root.text or "us-east-1") == self.scope["region"],
                    "S3_REGION_MISMATCH",
                )
            elif suffix == "versioning":
                c._require(
                    value(root).get("Status") == "Enabled", "S3_VERSIONING_REQUIRED"
                )
            else:
                c._require(
                    value(root)
                    == {
                        k: "true"
                        for k in (
                            "BlockPublicAcls",
                            "IgnorePublicAcls",
                            "BlockPublicPolicy",
                            "RestrictPublicBuckets",
                        )
                    },
                    "S3_ACCESS_DENIED",
                )

    def object_identity(self, response: Response, key: str, sha: str) -> dict:
        h = {k.lower(): v for k, v in response.headers.items()}
        c._require(
            response.status == 200
            and h.get("x-amz-server-side-encryption") == "AES256",
            "S3_OBJECT_DENIED",
        )
        version, etag = h.get("x-amz-version-id"), h.get("etag")
        c._require(type(etag) is str and bool(etag), "S3_ETAG_REQUIRED")
        self.object_url(key, version or "null")
        return dict(
            bucket=self.bucket,
            key=key,
            version=version,
            etag=etag,
            sha256=sha,
            expected_owner=self.scope["account_id"],
            region=self.scope["region"],
            encryption="AES256",
        )

    def read_object(
        self, identity: dict, credentials: dict[str, str], expected: bytes
    ) -> None:
        c._require(
            identity["bucket"] == self.bucket
            and identity["expected_owner"] == self.scope["account_id"]
            and identity["region"] == self.scope["region"]
            and identity["sha256"] == digest(expected),
            "S3_IDENTITY_MISMATCH",
        )
        response = self.call(
            "GET",
            self.object_url(identity["key"], identity["version"]),
            credentials,
            headers=self.owner_headers(),
        )
        c._require(
            response.body == expected
            and self.object_identity(response, identity["key"], digest(expected))
            == identity,
            "S3_SUBSTITUTION",
        )
