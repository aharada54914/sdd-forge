"""Closed research metadata and deterministic local evidence checks.

Metadata validation never authenticates rights, independent judgment or gate PASS.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import stat
import sys
from urllib.parse import unquote, urlsplit, parse_qsl

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
SCHEMA_ID = (
    "https://github.com/aharada54914/sdd-forge/contracts/research-evidence.schema.json"
)
SECRET = re.compile(
    r"-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}"
)
ASSIGNMENT = re.compile(
    r"""(api[_-]?key|secret|token|password)\s*[:=]\s*['"][^'"\s]{8,}['"]""", re.I
)
CREDENTIAL_KEYS = {
    "token",
    "access_token",
    "api_key",
    "password",
    "secret",
    "signature",
    "x-amz-signature",
}


class Invalid(ValueError):
    def __init__(self, code, pointer="/"):
        self.code, self.pointer = code, pointer
        super().__init__(code)


def shared_scope(uid, gid):
    return f'linux-uid-{uid}-gid-{gid}'


def shared_permissions(path, uid, gid, *, directory):
    """Linux local-store profile; named ACLs and aliases are not supported."""
    require(sys.platform == 'linux', 'shared-adapter-unavailable')
    info = path.lstat()
    expected = 0o750 if directory else 0o640
    require((stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode))
            and info.st_uid == uid and info.st_gid == gid
            and stat.S_IMODE(info.st_mode) == expected
            and (directory or info.st_nlink == 1), 'shared-permissions')
    require(not any(name.startswith('system.posix_acl_') for name in os.listxattr(path, follow_symlinks=False)),
            'shared-acl-unsupported')


def shared_root(path, uid, gid):
    """Only publisher/root-controlled ancestors on a supported local mount."""
    require(sys.platform == 'linux', 'shared-adapter-unavailable')
    path = Path(path).absolute()
    for parent in path.parents:
        info = parent.lstat()
        require(stat.S_ISDIR(info.st_mode) and info.st_uid in (0, uid)
                and not info.st_mode & 0o022, 'shared-parent-permissions')
        require(not any(name.startswith('system.posix_acl_') for name in os.listxattr(parent, follow_symlinks=False)),
                'shared-acl-unsupported')
    descriptor = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        info = Path(f'/proc/self/fdinfo/{descriptor}').read_text(encoding="utf-8")
        match = re.search(r'^mnt_id:\s+(\d+)$', info, re.MULTILINE)
        require(match is not None, 'shared-filesystem-unsupported')
        mounts = [line.split() for line in Path('/proc/self/mountinfo').read_text(encoding="utf-8").splitlines()
                  if line.split()[0] == match[1]]
    finally:
        os.close(descriptor)
    require(len(mounts) == 1 and mounts[0][mounts[0].index('-') + 1] in ('ext4', 'xfs', 'btrfs', 'tmpfs', 'overlay'),
            'shared-filesystem-unsupported')
    shared_permissions(path, uid, gid, directory=True)


def shared_snapshot(root, item, source):
    """Admit licensed shared bytes using current OS permissions and bound receipt."""
    try:
        match = re.fullmatch(r'linux-uid-(\d+)-gid-(\d+)', source['access_scope_label'] or '')
        require(match is not None, 'shared-scope-invalid')
        uid, gid = map(int, match.groups())
        root = Path(root).absolute()
        key = source['content_sha256']
        require(item['original'] == f'{key}/original' and item['extracted'] == f'{key}/extracted.txt',
                'shared-snapshot-path-invalid')
        shared_root(root, uid, gid)
        entry = root / key
        shared_permissions(entry, uid, gid, directory=True)
        for name in ('original', 'extracted.txt', 'receipt.json'):
            shared_permissions(entry / name, uid, gid, directory=False)
        receipt = read_json(entry / 'receipt.json')
        expected = dict(schema='research-shared-cache/v1', content_sha256=key,
                        extracted_sha256=source['extraction']['extracted_sha256'],
                        expires_at=source['retention_or_expiry']['expires_at'],
                        permission_basis=source['license_or_permission_basis']['basis'],
                        access_scope=shared_scope(uid, gid), publisher_uid=uid, reader_gid=gid)
        require(receipt == expected and type(receipt['publisher_uid']) is int
                and type(receipt['reader_gid']) is int, 'shared-receipt-mismatch')
    except PermissionError:
        raise Invalid('shared-access-denied') from None


def require(condition, code, pointer="/"):
    if not condition:
        raise Invalid(code, pointer)


def module(name):
    try:
        spec = importlib.util.spec_from_file_location(
            "research_" + name.replace("-", "_"), HERE / (name + ".py")
        )
        require(spec is not None and spec.loader is not None, "dependency-unavailable")
        result = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = result
        spec.loader.exec_module(result)
        return result
    except (OSError, ImportError, SyntaxError):
        raise Invalid("dependency-unavailable") from None


def digest(data):
    return hashlib.sha256(data).hexdigest()


def record_digest(record):
    canonical = module("canonicalize-sdd-yaml")
    return digest(canonical.jcs_serialize(canonical.normalize_and_validate(record)))


def ordinary(path):
    """Reject symlinks in every traversed component, before resolving paths."""
    path = Path(path).absolute()
    try:
        for part in [*reversed(path.parents), path]:
            require(not part.is_symlink(), "file-unreadable")
        require(stat.S_ISREG(path.stat().st_mode), "file-unreadable")
    except OSError:
        raise Invalid("file-unreadable") from None
    return path


def parse_json(raw):
    def pairs(items):
        out = {}
        for key, value in items:
            require(key not in out, "file-unreadable")
            out[key] = value
        return out

    try:
        require(len(raw) <= 16 * 1024 * 1024, "file-unreadable")
        return json.loads(
            raw.decode("utf-8"),
            object_pairs_hook=pairs,
            parse_constant=lambda _: (_ for _ in ()).throw(Invalid("file-unreadable")),
        )
    except (UnicodeError, json.JSONDecodeError, RecursionError):
        raise Invalid("file-unreadable") from None


def read_json(path, *, with_raw=False):
    try:
        with ordinary(path).open("rb") as stream:
            raw = stream.read(16 * 1024 * 1024 + 1)
        document = parse_json(raw)
        return (document, raw) if with_raw else document
    except OSError:
        raise Invalid("file-unreadable") from None


def timestamp(value, pointer):
    if value is None:
        return
    require(
        isinstance(value, str)
        and re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", value),
        "value-invalid",
        pointer,
    )
    try:
        dt.datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")
    except ValueError:
        raise Invalid("value-invalid", pointer) from None


def safe_url(value, pointer="/"):
    try:
        require(not re.search(r"[\s\\\x00-\x1f\x7f]", value), "value-invalid", pointer)
        u = urlsplit(value)
        require(
            u.scheme in ("http", "https")
            and u.hostname
            and not u.username
            and not u.password,
            "value-invalid",
            pointer,
        )
        _ = u.port
        require(
            not any(k.casefold() in CREDENTIAL_KEYS for k, v in parse_qsl(u.query)),
            "secret-detected",
            pointer,
        )
        decoded = unquote(value)
        require(
            not SECRET.search(decoded) and not ASSIGNMENT.search(decoded),
            "secret-detected",
            pointer,
        )
    except Invalid:
        raise
    except (ValueError, UnicodeError):
        raise Invalid("value-invalid", pointer) from None


def validate_shape(document):
    schema_path = HERE.parent / "contracts/research-evidence.schema.json"
    if not schema_path.exists():
        schema_path = HERE.parents[2] / "contracts/research-evidence.schema.json"
    try:
        schema = read_json(schema_path)
        require(
            schema.get("$id") == SCHEMA_ID
            and schema.get("$schema") == "http://json-schema.org/draft-07/schema#",
            "dependency-unavailable",
        )
        require(
            not module("validate-facet-manifest").validate_against_schema(
                document, schema
            ),
            "schema-invalid",
        )
    except (AttributeError, KeyError, TypeError):
        raise Invalid("dependency-unavailable") from None


def values(value, pointer="/"):
    if isinstance(value, str):
        require(
            0 < len(value) <= 2048
            and not any(0xD800 <= ord(c) <= 0xDFFF for c in value),
            "value-invalid",
            pointer,
        )
        require(
            not SECRET.search(value) and not ASSIGNMENT.search(value),
            "secret-detected",
            pointer,
        )
    elif isinstance(value, dict):
        for key in sorted(value):
            child = pointer.rstrip("/") + "/" + key
            v = value[key]
            if key in (
                "record_revision",
                "source_record_revision",
                "line_start",
                "line_end",
            ):
                require(type(v) is int and v >= 1, "value-invalid", child)
            if key.endswith("_at"):
                timestamp(v, child)
            if key in ("url", "final_url") and v is not None:
                safe_url(v, child)
            values(v, child)
    elif isinstance(value, list):
        for i, v in enumerate(value):
            values(v, pointer.rstrip("/") + "/" + str(i))


def index_records(records, key):
    keys = [(r[key], r["record_revision"]) for r in records]
    require(keys == sorted(keys), "value-invalid")
    require(len(keys) == len(set(keys)), "id-duplicate")
    revisions = {}
    for name, revision in keys:
        require(revision == revisions.get(name, 0) + 1, "revision-gap")
        revisions[name] = revision
    return dict(zip(keys, records))


def validate_source(s, pointer):
    def check(c, code="status-inconsistent"):
        require(c, code, pointer)

    retrieved = s["retrieval_status"] == "retrieved"
    fields = ("content_sha256", "final_url", "retrieved_at", "media_type")
    if retrieved:
        check(all(s[k] is not None for k in fields) and s["attempted_at"] is not None)
        check(s["attempted_at"] <= s["retrieved_at"])
    else:
        check(all(s[k] is None for k in fields) and s["extraction"] is None)
        check((s["attempted_at"] is None) == (s["retrieval_status"] == "not-attempted"))
    if s["currency_status"] in ("stale", "retracted"):
        check(s["currency_note"] is not None)
    check((s["verification_at"] is None) == (s["verification_status"] == "unverified"))
    if s["verification_status"] in ("hash-verified", "hash-mismatch"):
        check(retrieved)
    if s["verification_at"] and s["retrieved_at"]:
        check(s["verification_at"] >= s["retrieved_at"])
    rights = s["license_or_permission_basis"]
    if rights["status"] == "unknown":
        check(
            rights["basis"] is None and rights["asserted_by"] is None,
            "rights-inconsistent",
        )
    if rights["status"] == "permitted":
        check(
            rights["basis"] is not None and rights["asserted_by"] == "human",
            "rights-inconsistent",
        )
    mode = s["storage_mode"]
    retention = s["retention_or_expiry"]
    if mode in ("reference_only", "blocked"):
        check(
            s["storage_location_class"] == "none"
            and retention is None
            and s["access_scope"] == "none"
            and s["access_scope_label"] is None,
            "storage-inconsistent",
        )
    else:
        check(rights["status"] == "permitted", "rights-inconsistent")
        check(retention is not None, "storage-inconsistent")
        check(
            {"expiry", "rights-revoked"} <= set(retention["delete_when"]),
            "storage-inconsistent",
        )
        if s["retrieved_at"]:
            check(retention["expires_at"] > s["retrieved_at"], "storage-inconsistent")
        if mode == "local_cache":
            check(
                s["storage_location_class"] == "local-cache"
                and s["access_scope"] == "local-user"
                and s["access_scope_label"] is None,
                "storage-inconsistent",
            )
        else:
            check(
                s["storage_location_class"] == "shared-store"
                and s["access_scope"] == "named-group"
                and s["access_scope_label"] is not None,
                "storage-inconsistent",
            )
    if s["inherited_from"] and s["record_revision"] == 1:
        check(
            rights["status"] == "unknown"
            and s["verification_status"] == "unverified"
            and mode in ("reference_only", "blocked"),
            "inheritance-unresolved",
        )


def validate_document(doc):
    validate_shape(doc)
    values(doc)
    sources = index_records(doc["sources"], "source_id")
    index_records(doc["claims"], "claim_id")
    budgets = {}
    for i, s in enumerate(doc["sources"]):
        validate_source(s, "/sources/" + str(i))
        if s["inherited_from"]:
            require(
                s["inherited_from"]["feature"] != doc["feature"],
                "inheritance-unresolved",
            )
    for i, c in enumerate(doc["claims"]):
        pointer = "/claims/" + str(i)
        seen = set()
        relationships = []
        cited_sources = []
        for j, citation in enumerate(c["citations"]):
            p = pointer + "/citations/" + str(j)
            source = sources.get(
                (citation["source_id"], citation["source_record_revision"])
            )
            require(source is not None, "citation-unresolved", p)
            identity = json.dumps(
                [
                    citation[k]
                    for k in (
                        "source_id",
                        "source_record_revision",
                        "relation",
                        "anchor",
                    )
                ],
                sort_keys=True,
            )
            require(identity not in seen, "id-duplicate", p)
            seen.add(identity)
            anchor = citation["anchor"]
            retrieved = source["retrieval_status"] == "retrieved"
            require((anchor is not None) == retrieved, "quote-invalid", p)
            if anchor:
                require(source["extraction"] is not None, "quote-invalid", p)
                require(
                    1
                    <= anchor["line_start"]
                    <= anchor["line_end"]
                    <= anchor["line_start"] + 4
                    and len(anchor["quote"]) <= 300,
                    "quote-invalid",
                    p,
                )
                require(
                    digest(anchor["quote"].encode()) == anchor["quote_sha256"],
                    "quote-invalid",
                    p,
                )
                budgets.setdefault(citation["source_id"], set()).add(anchor["quote"])
            require(
                (citation["quote_verified_at"] is None)
                == (citation["quote_status"] == "unverified"),
                "quote-invalid",
                p,
            )
            if citation["quote_status"] in ("verified", "mismatch"):
                require(
                    anchor is not None
                    and source["verification_status"] == "hash-verified",
                    "quote-invalid",
                    p,
                )
            if citation["quote_verified_at"] and source["retrieved_at"]:
                require(
                    citation["quote_verified_at"] >= source["retrieved_at"],
                    "quote-invalid",
                    p,
                )
            if retrieved:
                relationships.append(citation["relation"])
            cited_sources.append(source)
        status = c["evidence_status"]
        if status == "cited":
            valid = "supports" in relationships and not any(
                x["relation"] == "contradicts" for x in c["citations"]
            )
        elif status == "conflicting":
            valid = "supports" in relationships and "contradicts" in relationships
        elif status == "searched-not-found":
            valid = not c["citations"] and c["search_record"] is not None
        elif status == "not-searched":
            valid = not c["citations"] and c["search_record"] is None
        else:
            valid = bool(cited_sources) and all(
                s["retrieval_status"] in ("unreachable", "access-restricted")
                for s in cited_sources
            )
        require(valid, "evidence-inconsistent", pointer)
        if c["semantic_status"] == "unassessed":
            valid = c["semantic_assessed_by"] is None and c["semantic_note"] is None
        else:
            valid = (
                c["semantic_assessed_by"] is not None and c["semantic_note"] is not None
            )
        require(valid, "semantic-inconsistent", pointer)
    require(
        all(sum(map(len, quotes)) <= 1500 for quotes in budgets.values()),
        "quote-budget-exceeded",
    )
    return doc


def validate_file(path, root=None, previous=None, *, with_raw=False):
    path = ordinary(path)
    document, raw = read_json(path, with_raw=True)
    doc = validate_document(document)
    if root is not None:
        root = Path(root).absolute()
        expected = (
            root / "specs" / doc["feature"] / "research/records/research-evidence.json"
        )
        require(path == expected, "location-mismatch")
        require(list(path.parent.iterdir()) == [path], "research-dir-unexpected-file")
        for s in doc["sources"]:
            inherited = s["inherited_from"]
            if not inherited:
                continue
            try:
                target = (
                    root
                    / "specs"
                    / inherited["feature"]
                    / "research/records/research-evidence.json"
                )
                other = validate_document(read_json(target))
                require(
                    other["feature"] == inherited["feature"], "inheritance-unresolved"
                )
                matches = [
                    r
                    for r in other["sources"]
                    if (r["source_id"], r["record_revision"])
                    == (inherited["source_id"], inherited["record_revision"])
                ]
                require(
                    len(matches) == 1
                    and record_digest(matches[0]) == inherited["record_sha256"],
                    "inheritance-unresolved",
                )
            except Invalid:
                raise Invalid("inheritance-unresolved") from None
    if previous:
        try:
            old = validate_document(read_json(previous))
            require(old["feature"] == doc["feature"], "revision-rewritten")
            for field, key in [("sources", "source_id"), ("claims", "claim_id")]:
                current = index_records(doc[field], key)
                require(
                    all(
                        current.get((r[key], r["record_revision"])) == r
                        for r in old[field]
                    ),
                    "revision-rewritten",
                )
        except Invalid:
            raise Invalid("revision-rewritten") from None
    return (doc, raw) if with_raw else doc


class Parser(argparse.ArgumentParser):
    def error(self, message):
        self.exit(2, "research-evidence: usage error\n")


def main(argv=None):
    parser = Parser(add_help=True)
    parser.add_argument("--file", required=True)
    parser.add_argument("--repo-root")
    parser.add_argument("--previous")
    args = parser.parse_args(argv)
    try:
        doc = validate_file(args.file, args.repo_root, args.previous)
        print(
            f"research-evidence: VALID {doc['feature']} scope={'repository' if args.repo_root else 'file'} history={'checked' if args.previous else 'unchecked'} sources={len(doc['sources'])} claims={len(doc['claims'])}"
        )
        return 0
    except Invalid as exc:
        print(f"research-evidence: INVALID: {exc.code} {exc.pointer}", file=sys.stderr)
        return 1
    except (KeyError, TypeError, ValueError, RecursionError, OSError):
        print("research-evidence: INVALID: input-invalid /", file=sys.stderr)
        return 1
