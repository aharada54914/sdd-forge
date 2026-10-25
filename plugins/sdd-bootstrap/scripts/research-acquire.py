#!/usr/bin/env python3
"""Bounded, explicitly allowed public-source acquisition with pinned peers.

Reference-only is the default. Proxy and shared-store transports require their
own authenticated adapter; this direct transport refuses rather than bypassing
an inherited proxy or claiming to enforce its remote DNS/peer boundary.
"""

from __future__ import annotations
import base64
import datetime as dt
import gzip
import http.client
import io
import ipaddress
import json
import math
import os
import re
from pathlib import Path
import socket
import ssl
import stat
import subprocess
import sys
import tempfile
import time
from urllib.parse import urljoin, urlsplit
from urllib.request import getproxies

sys.dont_write_bytecode = True
QUALITY = Path(__file__).resolve().parents[2] / "sdd-quality-loop/scripts"
sys.path.insert(0, str(QUALITY))
from research_evidence import (  # noqa: E402 - sibling runtime path is explicit.
    Invalid,
    Parser,
    require,
    safe_url,
    digest,
    values,
    read_json,
)

MAX_RESPONSE = 4 * 1024 * 1024
from research_extraction import extract, supervise  # noqa: E402 - sibling runtime path is explicit.


def public_addresses(host, port, resolver=socket.getaddrinfo):
    try:
        addresses = sorted(
            {row[4][0] for row in resolver(host, port, type=socket.SOCK_STREAM)}
        )
    except OSError:
        raise Invalid("dns-unavailable") from None
    require(bool(addresses), "dns-unavailable")
    for address in addresses:
        try:
            ip = ipaddress.ip_address(address)
        except ValueError:
            raise Invalid("address-invalid") from None
        require(
            ip.is_global
            and not ip.is_multicast
            and not ip.is_unspecified
            and not ip.is_reserved,
            "ssrf-blocked",
        )
    return addresses


def allowed_url(url, hosts, allow_http=False):
    safe_url(url)
    parsed = urlsplit(url)
    require(parsed.hostname in hosts, "host-not-allowed")
    require(
        parsed.scheme == "https" or (allow_http and parsed.scheme == "http"),
        "scheme-not-allowed",
    )
    require(
        parsed.port in (None, 443 if parsed.scheme == "https" else 80),
        "port-not-allowed",
    )
    return parsed


def request_pinned(url, addresses, timeout):
    """Connect directly to a validated IP while retaining origin SNI/Host."""
    require(not getproxies(), "proxy-adapter-required")
    parsed = urlsplit(url)
    port = parsed.port or (443 if parsed.scheme == "https" else 80)
    try:
        sock = socket.create_connection((addresses[0], port), timeout)
        if parsed.scheme == "https":
            sock = ssl.create_default_context().wrap_socket(
                sock, server_hostname=parsed.hostname
            )
        require(sock.getpeername()[0] in addresses, "peer-mismatch")
        connection = http.client.HTTPConnection(parsed.hostname, port, timeout=timeout)
        connection.sock = sock
        target = (parsed.path or "/") + ("?" + parsed.query if parsed.query else "")
        connection.request(
            "GET",
            target,
            headers={
                "Host": parsed.netloc,
                "Accept-Encoding": "identity",
                "User-Agent": "sdd-forge-research/1",
            },
        )
        response = connection.getresponse()
        headers = {k.lower(): v for k, v in response.getheaders()}
        length = headers.get("content-length")
        if length:
            require(
                length.isdecimal() and int(length) <= MAX_RESPONSE, "response-too-large"
            )
        deadline = time.monotonic() + timeout
        chunks = []
        size = 0
        while True:
            remaining = deadline - time.monotonic()
            require(remaining > 0, "transport-timeout")
            sock.settimeout(remaining)
            chunk = response.read1(min(65536, MAX_RESPONSE + 1 - size))
            if not chunk:
                break
            size += len(chunk)
            require(size <= MAX_RESPONSE, "response-too-large")
            chunks.append(chunk)
        body = b"".join(chunks)
        return response.status, headers, body
    except (OSError, ssl.SSLError, http.client.HTTPException):
        raise Invalid("transport-unavailable") from None
    finally:
        if "connection" in locals():
            connection.close()
        elif "sock" in locals():
            sock.close()


def _budget(timeout, redirects):
    require(
        type(timeout) in (int, float)
        and 0 < timeout <= 60
        and math.isfinite(timeout)
        and type(redirects) is int
        and 0 <= redirects <= 5,
        "budget-invalid",
    )


def _acquire(
    url,
    hosts,
    *,
    allow_http=False,
    timeout=15,
    redirects=3,
    resolver=socket.getaddrinfo,
    transport=request_pinned,
):
    _budget(timeout, redirects)
    require(
        isinstance(hosts, list)
        and hosts
        and all(isinstance(h, str) and h for h in hosts),
        "host-not-allowed",
    )
    original_url = url
    for attempt in range(redirects + 1):
        parsed = allowed_url(url, hosts, allow_http)
        addresses = public_addresses(
            parsed.hostname,
            parsed.port or (443 if parsed.scheme == "https" else 80),
            resolver,
        )
        status, headers, body = transport(url, addresses, timeout)
        require(len(body) <= MAX_RESPONSE, "response-too-large")
        if status in (301, 302, 303, 307, 308):
            require(attempt < redirects and "location" in headers, "redirect-limit")
            url = urljoin(url, headers["location"])
            continue
        require(
            status == 200,
            "access-restricted" if status in (401, 403) else "unreachable",
        )
        encoding = headers.get("content-encoding", "identity").lower()
        if encoding == "gzip":
            try:
                with gzip.GzipFile(fileobj=io.BytesIO(body)) as stream:
                    body = stream.read(MAX_RESPONSE + 1)
            except (OSError, EOFError):
                raise Invalid("encoding-invalid") from None
            require(len(body) <= MAX_RESPONSE, "response-too-large")
        else:
            require(encoding == "identity", "encoding-unsupported")
        extracted, method, media = extract(body, headers.get("content-type", ""))
        require(len(extracted.decode("utf-8").strip()) >= 20, "extraction-too-short")
        return (
            dict(
                url=original_url,
                final_url=url,
                retrieved_at=dt.datetime.now(dt.timezone.utc).strftime(
                    "%Y-%m-%dT%H:%M:%SZ"
                ),
                content_sha256=digest(body),
                media_type=media,
                extraction=dict(method=method, extracted_sha256=digest(extracted)),
                storage_mode="reference_only",
            ),
            body,
            extracted,
        )
    raise Invalid("redirect-limit")


def _stop_worker(process):
    """A timeout must not leave DNS or socket work running in a background thread."""
    try:
        if process.poll() is None:
            process.kill()
        process.communicate(timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        raise Invalid("transport-cleanup-failed") from None
    require(process.poll() is not None, "transport-cleanup-failed")


def _run_bounded(command, payload, timeout):
    _budget(timeout, 0)
    if sys.platform == 'linux':
        return supervise(command, payload, timeout, prefix='transport', output_limit=9 * 1024 * 1024)
    started = time.monotonic()
    try:
        process = subprocess.Popen(
            command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except OSError:
        raise Invalid("transport-worker-unavailable") from None
    try:
        remaining = timeout - (time.monotonic() - started)
        if remaining <= 0:
            raise subprocess.TimeoutExpired(command, timeout)
        stdout, _ = process.communicate(payload, timeout=remaining)
        return process.returncode, stdout
    except subprocess.TimeoutExpired:
        _stop_worker(process)
        raise Invalid("transport-timeout") from None
    except BaseException:
        _stop_worker(process)
        raise
    finally:
        for stream in (process.stdin, process.stdout, process.stderr):
            if stream is not None:
                stream.close()


def _worker_main():
    """Private fetch entry; isolated PDF children die with this worker; no cache writes."""
    try:
        raw = sys.stdin.buffer.read(16385)
        require(len(raw) <= 16384, "request-too-large")
        request = json.loads(raw)
        require(
            isinstance(request, dict)
            and set(request) == {"url", "hosts", "allow_http", "timeout", "redirects"},
            "request-invalid",
        )
        metadata, body, extracted = _acquire(**request)
        result = dict(
            metadata=metadata,
            body=base64.b64encode(body).decode("ascii"),
            extracted=base64.b64encode(extracted).decode("ascii"),
        )
        print(json.dumps(result, allow_nan=False))
        return 0
    except Invalid as exc:
        print(json.dumps({"error": exc.code}))
        return 1
    except (OSError, ValueError, TypeError, KeyError):
        print('{"error":"transport-unavailable"}')
        return 1


def acquire(url, hosts, *, allow_http=False, timeout=15, redirects=3):
    """Bound the entire fetch, including DNS and every redirect, in one worker.

    Killing/reaping has a separate five-second cleanup allowance. Cleanup failure
    is explicit and never reported as an ordinary successfully cancelled timeout.
    """
    _budget(timeout, redirects)
    require(type(allow_http) is bool, "request-invalid")
    require(
        isinstance(hosts, list)
        and hosts
        and all(isinstance(h, str) and h for h in hosts),
        "host-not-allowed",
    )
    allowed_url(url, hosts, allow_http)
    # Preserve the environment's required transport; never bypass an inherited proxy.
    require(not getproxies(), "proxy-adapter-required")
    payload = json.dumps(
        dict(
            url=url,
            hosts=hosts,
            allow_http=allow_http,
            timeout=timeout,
            redirects=redirects,
        ),
        allow_nan=False,
    ).encode()
    require(len(payload) <= 16384, "request-too-large")
    command = [
        sys.executable,
        "-I",
        "-B",
        "-c",
        "import runpy,sys; raise SystemExit(runpy.run_path(sys.argv[1])['_worker_main']())",
        str(Path(__file__).resolve()),
    ]
    code, raw = _run_bounded(command, payload, timeout)
    require(len(raw) <= 9 * 1024 * 1024, "transport-worker-invalid")
    try:
        result = json.loads(raw)
        if code and isinstance(result, dict) and set(result) == {"error"}:
            require(
                isinstance(result["error"], str)
                and re.fullmatch(r"[a-z][a-z0-9-]{0,63}", result["error"]),
                "transport-worker-invalid",
            )
            raise Invalid(result["error"])
        require(
            code == 0
            and isinstance(result, dict)
            and set(result) == {"metadata", "body", "extracted"},
            "transport-worker-invalid",
        )
        body = base64.b64decode(result["body"], validate=True)
        extracted = base64.b64decode(result["extracted"], validate=True)
        metadata = result["metadata"]
        require(
            isinstance(metadata, dict)
            and set(metadata)
            == {
                "url",
                "final_url",
                "retrieved_at",
                "content_sha256",
                "media_type",
                "extraction",
                "storage_mode",
            },
            "transport-worker-invalid",
        )
        require(
            metadata["url"] == url
            and metadata["storage_mode"] == "reference_only"
            and isinstance(metadata["media_type"], str)
            and isinstance(metadata["extraction"], dict)
            and set(metadata["extraction"]) == {"method", "extracted_sha256"},
            "transport-worker-invalid",
        )
        allowed_url(metadata["final_url"], hosts, allow_http)
        media = metadata["media_type"].split(";", 1)[0].strip().lower()
        methods = {
            media: "plain/v1"
            for media in (
                "text/plain",
                "application/xml",
                "text/xml",
                "application/rss+xml",
                "application/atom+xml",
            )
        }
        methods.update(
            {"text/html": "html-text/v1", "application/xhtml+xml": "html-text/v1"}
        )
        require(
            (media in methods and metadata["extraction"]["method"] == methods[media])
            or (media == "application/pdf" and isinstance(metadata["extraction"]["method"], str)
                and re.fullmatch(r"pypdf-[0-9]+-[0-9]+-[0-9]+-[0-9a-f]{64}-layout/v1",
                                 metadata["extraction"]["method"]) is not None),
            "transport-worker-invalid",
        )
        require(
            0 < len(body) <= MAX_RESPONSE
            and len(extracted) <= 2 * 1024 * 1024
            and len(extracted.decode("utf-8").strip()) >= 20
            and metadata["content_sha256"] == digest(body)
            and metadata["extraction"]["extracted_sha256"] == digest(extracted),
            "transport-worker-invalid",
        )
        # Reuse the source contract for URL/time/hash/media value validation.
        source_record(metadata, "SRC-001", "Acquired source")
        return metadata, body, extracted
    except Invalid:
        raise
    except (ValueError, TypeError, KeyError):
        raise Invalid("transport-worker-invalid") from None


def save_cache(
    metadata,
    body,
    extracted,
    cache,
    *,
    repository,
    permission_basis,
    expires_at,
    excluded=(),
):
    """Create a new private content-addressed directory; never overwrite history."""
    require(os.name == "posix", "cache-acl-adapter-required")
    require(
        permission_basis and isinstance(permission_basis, str), "permission-required"
    )
    values(permission_basis)
    from research_evidence import timestamp

    timestamp(expires_at, "/expires_at")
    require(
        expires_at > metadata["retrieved_at"]
        and expires_at
        > dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "rights-expired",
    )
    cache = Path(cache).absolute()
    require(
        all(not p.is_symlink() for p in [cache, *cache.parents]), "cache-path-invalid"
    )
    forbidden = [Path(repository).resolve(), Path(tempfile.gettempdir()).resolve()]
    forbidden.extend(Path(p).resolve() for p in excluded)
    forbidden.extend(
        Path(os.environ[k]).resolve()
        for k in ("GITHUB_WORKSPACE", "RUNNER_TEMP", "CI_PROJECT_DIR")
        if os.environ.get(k)
    )
    require(
        not any(cache.resolve().is_relative_to(root) for root in forbidden),
        "cache-export-boundary",
    )
    # Every existing ancestor inside a git worktree is an export boundary too.
    require(
        not any((p / ".git").exists() for p in [cache, *cache.parents]),
        "cache-export-boundary",
    )
    cache.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = cache.stat()
    require(
        info.st_uid == os.geteuid() and stat.S_IMODE(info.st_mode) == 0o700,
        "cache-permissions",
    )
    key = metadata["content_sha256"]
    require(
        isinstance(key, str)
        and re.fullmatch(r"[a-f0-9]{64}", key)
        and key == digest(body)
        and metadata["extraction"]["extracted_sha256"] == digest(extracted),
        "snapshot-hash-mismatch",
    )
    target = cache / key
    require(not target.exists() and not target.is_symlink(), "snapshot-exists")
    scratch = Path(tempfile.mkdtemp(prefix=".acquire-", dir=cache))
    try:
        for name, data in [("original", body), ("extracted.txt", extracted)]:
            fd = os.open(scratch / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, "wb") as stream:
                stream.write(data)
        receipt = dict(
            schema="research-cache/v1",
            content_sha256=key,
            extracted_sha256=metadata["extraction"]["extracted_sha256"],
            expires_at=expires_at,
            permission_basis=permission_basis,
            access_scope="local-user",
        )
        fd = os.open(
            scratch / "receipt.json", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600
        )
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(receipt, stream, sort_keys=True)
        os.rename(scratch, target)
        return dict(
            metadata, storage_mode="local_cache", cache_key=key, expires_at=expires_at
        )
    finally:
        if scratch.exists():
            for child in scratch.iterdir():
                child.unlink()
            scratch.rmdir()


def purge_cache(cache, *, revoke=(), now=None):
    """Delete only expired/revoked, private, complete cache snapshots."""
    require(os.name == "posix", "cache-acl-adapter-required")
    cache = Path(cache).absolute()
    require(
        cache.is_dir() and all(not p.is_symlink() for p in [cache, *cache.parents]),
        "cache-path-invalid",
    )
    info = cache.stat()
    require(
        info.st_uid == os.geteuid() and stat.S_IMODE(info.st_mode) == 0o700,
        "cache-permissions",
    )
    require(
        all(
            isinstance(key, str) and re.fullmatch(r"[a-f0-9]{64}", key)
            for key in revoke
        ),
        "cache-key-invalid",
    )
    now = now or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    from research_evidence import timestamp

    timestamp(now, "/now")
    selected = []
    for entry in sorted(cache.iterdir()):
        require(
            re.fullmatch(r"[a-f0-9]{64}", entry.name)
            and not entry.is_symlink()
            and entry.is_dir(),
            "cache-entry-invalid",
        )
        require(
            {p.name for p in entry.iterdir()}
            == {"original", "extracted.txt", "receipt.json"},
            "cache-entry-invalid",
        )
        for file in entry.iterdir():
            require(
                not file.is_symlink()
                and file.is_file()
                and file.stat().st_uid == os.geteuid()
                and stat.S_IMODE(file.stat().st_mode) == 0o600,
                "cache-permissions",
            )
        receipt = read_json(entry / "receipt.json")
        require(
            isinstance(receipt, dict)
            and receipt.get("schema") == "research-cache/v1"
            and receipt.get("content_sha256") == entry.name,
            "cache-entry-invalid",
        )
        timestamp(receipt.get("expires_at"), "/expires_at")
        require(isinstance(receipt.get("expires_at"), str), "cache-entry-invalid")
        if receipt["expires_at"] <= now or entry.name in revoke:
            selected.append(entry)
    # Validate the complete deletion set before the first mutation.
    for entry in selected:
        for name in ["original", "extracted.txt", "receipt.json"]:
            (entry / name).unlink()
        entry.rmdir()
    return dict(
        schema="research-cache-purge/v1",
        deleted=len(selected),
        retained=len(list(cache.iterdir())),
    )


def source_record(metadata, source_id, title, permission_basis=None):
    source = dict(
        source_id=source_id,
        record_revision=1,
        source_type="other",
        title=title,
        authors=[],
        url=metadata["url"],
        final_url=metadata["final_url"],
        source_revision=None,
        retrieval_status="retrieved",
        attempted_at=metadata["retrieved_at"],
        retrieved_at=metadata["retrieved_at"],
        content_sha256=metadata["content_sha256"],
        media_type=metadata["media_type"],
        extraction=metadata["extraction"],
        currency_status="unknown",
        currency_note=None,
        verification_status="unverified",
        verification_at=None,
        storage_mode=metadata["storage_mode"],
        license_or_permission_basis=dict(
            status="unknown", basis=None, asserted_by=None
        ),
        storage_location_class="none",
        retention_or_expiry=None,
        access_scope="none",
        access_scope_label=None,
        inherited_from=None,
        uncertainty=None,
    )
    if metadata["storage_mode"] == "local_cache":
        source.update(
            license_or_permission_basis=dict(
                status="permitted", basis=permission_basis, asserted_by="human"
            ),
            storage_location_class="local-cache",
            retention_or_expiry=dict(
                expires_at=metadata["expires_at"],
                delete_when=["expiry", "rights-revoked"],
            ),
            access_scope="local-user",
        )
    from research_evidence import validate_document

    validate_document(
        dict(
            schema="research-evidence/v1",
            feature="acquisition",
            sources=[source],
            claims=[],
        )
    )
    return source


def main(argv=None):
    parser = Parser()
    parser.add_argument("--source-id")
    parser.add_argument("--title")
    parser.add_argument("--url")
    parser.add_argument("--allow-host", action="append")
    parser.add_argument("--allow-http", action="store_true")
    parser.add_argument("--timeout", type=int, default=15)
    parser.add_argument("--cache")
    parser.add_argument("--repo-root")
    parser.add_argument("--permission-basis")
    parser.add_argument("--expires-at")
    parser.add_argument("--purge-cache")
    parser.add_argument("--revoke", action="append", default=[])
    args = parser.parse_args(argv)
    try:
        if args.purge_cache:
            require(
                not any(
                    [args.url, args.cache, args.allow_host, args.source_id, args.title]
                ),
                "usage-invalid",
            )
            print(
                json.dumps(
                    purge_cache(args.purge_cache, revoke=args.revoke), sort_keys=True
                )
            )
            return 0
        require(
            args.url
            and args.allow_host
            and args.source_id
            and args.title
            and not args.revoke,
            "usage-invalid",
        )
        if args.cache:
            require(
                args.repo_root and args.permission_basis and args.expires_at,
                "permission-required",
            )
        metadata, body, text = acquire(
            args.url, args.allow_host, allow_http=args.allow_http, timeout=args.timeout
        )
        if args.cache:
            metadata = save_cache(
                metadata,
                body,
                text,
                args.cache,
                repository=args.repo_root,
                permission_basis=args.permission_basis,
                expires_at=args.expires_at,
            )
        print(
            json.dumps(
                dict(
                    schema="research-acquisition/v1",
                    status="retrieved",
                    source=source_record(
                        metadata, args.source_id, args.title, args.permission_basis
                    ),
                ),
                sort_keys=True,
            )
        )
        return 0
    except Invalid as exc:
        print(
            json.dumps(
                dict(schema="research-acquisition/v1", status=exc.code), sort_keys=True
            )
        )
        return 1
    except (OSError, ValueError, TypeError):
        print('{"schema":"research-acquisition/v1","status":"input-unavailable"}')
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
