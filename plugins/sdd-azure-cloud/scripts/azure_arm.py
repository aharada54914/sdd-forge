"""Azure-only bounded HTTPS/LRO transport. Auth transport's bytes API is unchanged."""

from __future__ import annotations

from dataclasses import dataclass
import re
import time
from typing import Callable, Protocol
import urllib.parse
import urllib.request

from cloud import c, decode, digest

ORIGIN = "https://management.azure.com"
VERSION = "2025-04-01"
QUERY = "?api-version=" + VERSION


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
        raise ValueError("ARM_REDIRECT_DENIED")


class HttpsTransport:
    def request(
        self, method: str, url: str, headers: dict[str, str], body: bytes | None = None
    ) -> Response:
        c._require(
            method in ("GET", "POST", "PUT") and url.startswith(ORIGIN + "/"),
            "ARM_URL_DENIED",
        )
        request = urllib.request.Request(url, data=body, headers=headers, method=method)
        try:
            response = urllib.request.build_opener(NoRedirect()).open(
                request, timeout=20
            )
        except urllib.error.HTTPError as error:
            response = error
        with response:
            c._require(response.geturl() == url, "ARM_REDIRECT_DENIED")
            data = response.read(c.MAX_BYTES + 1)
            c._require(len(data) <= c.MAX_BYTES, "ARM_RESPONSE_TOO_LARGE")
            pairs = list(response.headers.items())
            c._require(
                len({k.lower() for k, _ in pairs}) == len(pairs), "ARM_DUPLICATE_HEADER"
            )
            return Response(response.status, dict(pairs), data)


class ArmClient:
    def __init__(
        self,
        scope: dict,
        name: str,
        transport: Transport,
        *,
        sleep: Callable[[float], None] = time.sleep,
    ):
        self.scope, self.transport, self.sleep = scope, transport, sleep
        for key in ("account_id", "region", "deployment_scope"):
            c._require(re.fullmatch(r"[A-Za-z0-9_-]+", scope[key]), "ARM_SCOPE_INVALID")
        c._require(re.fullmatch(r"sdd-[a-f0-9]{60}", name), "ARM_ID_INVALID")
        self.native_id = (
            "/subscriptions/"
            + scope["account_id"]
            + "/resourceGroups/"
            + scope["deployment_scope"]
            + "/providers/Microsoft.Resources/deployments/"
            + name
        )
        self.url = ORIGIN + self.native_id + QUERY
        self.trace: list[dict] = []

    def poll_url(self, url: str) -> str:
        """Allow only this deployment or ARM operation endpoints in its subscription/region.

        Location is authenticated response data, not a caller-selected scope. Regional
        ARM LRO endpoints have no resource-group component; bind their exact region.
        """
        parsed = urllib.parse.urlsplit(url)
        c._require(
            parsed.scheme == "https"
            and parsed.netloc == "management.azure.com"
            and not parsed.fragment
            and parsed.query == "api-version=" + VERSION,
            "ARM_POLL_URL_DENIED",
        )
        path = parsed.path
        c._require(
            not any(s in path for s in ("%", "\\", "//"))
            and all(s not in (".", "..") for s in path.split("/")),
            "ARM_POLL_URL_DENIED",
        )
        regional = (
            "/subscriptions/"
            + self.scope["account_id"]
            + "/providers/Microsoft.Resources/locations/"
            + self.scope["region"]
        )
        allowed = (
            path == self.native_id
            or re.fullmatch(
                re.escape(self.native_id) + r"/operations/[A-Za-z0-9_.()-]+", path
            )
            or re.fullmatch(
                re.escape(regional)
                + r"/(?:operationStatuses|operationResults|operationresults)/[A-Za-z0-9_.()-]+",
                path,
            )
        )
        c._require(allowed, "ARM_POLL_SCOPE_DENIED")
        return url

    def call(
        self,
        method: str,
        url: str,
        credentials: dict[str, str],
        request_id: str,
        body: bytes | None = None,
    ) -> Response:
        response = self.transport.request(
            method,
            url,
            {
                "Authorization": "Bearer " + credentials["AZURE_ACCESS_TOKEN"],
                "Content-Type": "application/json",
                "x-ms-client-request-id": request_id,
                "x-ms-return-client-request-id": "true",
            },
            body,
        )
        c._require(
            type(response.status) is int
            and type(response.body) is bytes
            and len(response.body) <= c.MAX_BYTES,
            "ARM_RESPONSE_INVALID",
        )
        headers = {k.lower(): v for k, v in response.headers.items()}
        c._require(len(headers) == len(response.headers), "ARM_DUPLICATE_HEADER")
        # Raw bodies may contain secrets; persist their digest, not native diagnostics.
        self.trace.append(
            dict(
                method=method,
                url=url,
                status=response.status,
                response_sha256=digest(response.body),
            )
        )
        for key in ("location", "azure-asyncoperation"):
            if key in headers:
                self.trace[-1][key] = self.poll_url(headers[key])
        return Response(response.status, headers, response.body)

    def finish(
        self,
        response: Response,
        credentials: dict[str, str],
        request_id: str,
        *,
        preview: bool,
    ) -> dict:
        c._require(response.status in (200, 201, 202), "ARM_HTTP_FAILURE")
        location = response.headers.get("location")
        asynchronous = response.headers.get("azure-asyncoperation")
        if response.status == 202 or response.status == 201:
            c._require(
                location or (asynchronous and not preview), "ARM_LRO_HEADER_REQUIRED"
            )
        if preview and response.status == 202:
            c._require(location, "ARM_LRO_LOCATION_REQUIRED")
        deadline = time.monotonic() + 300
        for _ in range(12):
            c._require(time.monotonic() < deadline, "ARM_POLL_TIMEOUT")
            value = decode(response.body) if response.body else {}
            c._require(type(value) is dict, "ARM_RESPONSE_INVALID")
            if preview and response.status == 200 and "properties" in value:
                return value
            if (
                not preview
                and response.status in (200, 201)
                and value.get("id") == self.native_id
            ):
                state = value.get("properties", {}).get("provisioningState")
                if state in ("Succeeded", "Failed", "Canceled"):
                    return value
            if value.get("status") in ("Failed", "Canceled"):
                raise ValueError("ARM_ASYNC_FAILED")
            if asynchronous and value.get("status") == "Succeeded":
                asynchronous = None
            url = asynchronous or location or (None if preview else self.url)
            c._require(url, "ARM_LRO_HEADER_REQUIRED")
            assert url is not None
            self.poll_url(url)
            delay = response.headers.get("retry-after", "1")
            c._require(
                type(delay) is str
                and re.fullmatch(r"[0-9]{1,3}", delay)
                and int(delay) <= 30,
                "ARM_RETRY_AFTER_INVALID",
            )
            self.sleep(int(delay))
            response = self.call("GET", url, credentials, request_id)
            c._require(response.status in (200, 202), "ARM_POLL_FAILED")
            # Never permit a changed operation endpoint during polling.
            c._require(
                response.headers.get("location", location) == location
                and response.headers.get("azure-asyncoperation", asynchronous)
                == asynchronous,
                "ARM_POLL_ID_CHANGED",
            )
        raise TimeoutError("ARM_POLL_TIMEOUT")
