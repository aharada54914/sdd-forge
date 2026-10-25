#!/usr/bin/env python3
"""Explicit offline/feed-fetch source watch; never schedules or mutates specs."""

import datetime as dt
from email.utils import parsedate_to_datetime
import importlib.util
import json
import re
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "sdd-quality-loop/scripts"))
from research_evidence import (  # noqa: E402 - sibling runtime path is explicit.
    Parser,
    Invalid,
    require,
    read_json,
    safe_url,
    validate_file,
    digest,
    ordinary,
    validate_document,
    record_digest,
    timestamp,
)
from research_consumers import impact, closed, relative_file, current_access  # noqa: E402 - sibling runtime path is explicit.


def feed_items(raw):
    require(len(raw) <= 1024 * 1024, "feed-too-large")
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeError:
        raise Invalid("feed-encoding-invalid") from None
    require(
        "<!DOCTYPE" not in text.upper() and "<!ENTITY" not in text.upper(),
        "feed-entity-forbidden",
    )
    try:
        tree = ET.fromstring(text)
    except ET.ParseError:
        raise Invalid("feed-invalid") from None
    atom = "{http://www.w3.org/2005/Atom}"
    if tree.tag == "rss":
        items = tree.findall("./channel/item")
        kind = "rss"
    elif tree.tag == atom + "feed":
        items = tree.findall(atom + "entry")
        kind = "atom"
    else:
        raise Invalid("feed-unsupported")
    require(len(items) <= 500, "feed-too-large")
    out = {}
    for item in items:
        if kind == "rss":
            url = item.findtext("link")
            date = item.findtext("pubDate")
            title = item.findtext("title")
            try:
                published = parsedate_to_datetime(date)
            except (TypeError, ValueError):
                raise Invalid("feed-date-invalid") from None
        else:
            links = [
                x
                for x in item.findall(atom + "link")
                if x.attrib.get("rel", "alternate") == "alternate"
            ]
            url = links[0].attrib.get("href") if links else None
            date = item.findtext(atom + "published") or item.findtext(atom + "updated")
            title = item.findtext(atom + "title")
            try:
                published = dt.datetime.fromisoformat(date.replace("Z", "+00:00"))
            except (AttributeError, ValueError):
                raise Invalid("feed-date-invalid") from None
        require(
            isinstance(url, str)
            and isinstance(title, str)
            and title
            and len(title) <= 2048,
            "feed-item-invalid",
        )
        safe_url(url)
        require(published.tzinfo is not None, "feed-date-invalid")
        record = dict(
            url=url,
            title=title,
            published_at=published.astimezone(dt.timezone.utc).strftime(
                "%Y-%m-%dT%H:%M:%SZ"
            ),
        )
        require(url not in out or out[url] == record, "feed-item-conflict")
        out[url] = record
    return sorted(out.values(), key=lambda x: (x["published_at"], x["url"]))


def source_snapshot(document, manifest, root, source_id, now):
    """Observe permitted bytes, not quote meaning or a reusable verification PASS."""
    validate_document(document)
    require(isinstance(now, str), "watch-state-invalid")
    timestamp(now, "/last_checked_at")
    closed(manifest, ["schema", "feature", "snapshots"])
    require(manifest["schema"] == "research-snapshots/v1"
            and manifest["feature"] == document["feature"]
            and isinstance(manifest["snapshots"], list), "snapshot-invalid")
    candidates = [source for source in document["sources"] if source["source_id"] == source_id]
    require(bool(candidates), "source-missing")
    source = max(candidates, key=lambda item: item["record_revision"])
    selected = []
    for item in manifest["snapshots"]:
        closed(item, ["source_id", "record_revision", "original", "extracted"])
        require(isinstance(item["source_id"], str)
                and re.fullmatch(r"SRC-[0-9]{3}", item["source_id"])
                and type(item["record_revision"]) is int and item["record_revision"] >= 1,
                "snapshot-invalid")
        if item["source_id"] == source_id and item["record_revision"] == source["record_revision"]:
            selected.append(item)
    require(len(selected) <= 1, "snapshot-invalid")
    result = dict(feature=document["feature"], source_id=source_id, record_revision=source["record_revision"],
                  metadata_sha256=record_digest(source), original_sha256=None,
                  extracted_sha256=None, status="unavailable", reason=None)
    try:
        current_access(source, now)
        require(bool(selected), "snapshot-missing")
        require(source["retrieval_status"] == "retrieved" and source["extraction"] is not None,
                "source-unavailable")
        for field, limit in (("original", 32 * 1024 * 1024), ("extracted", 8 * 1024 * 1024)):
            with relative_file(root, selected[0][field]).open("rb") as stream:
                raw = stream.read(limit + 1)
            require(len(raw) <= limit, "snapshot-too-large")
            result[field + "_sha256"] = digest(raw)
        matches = (result["original_sha256"] == source["content_sha256"]
                   and result["extracted_sha256"] == source["extraction"]["extracted_sha256"])
        result["status"] = "matching" if matches else "mismatch"
        result["reason"] = None if matches else "snapshot-hash-mismatch"
    except Invalid as error:
        result["reason"] = error.code
    except OSError:
        result["reason"] = "file-unreadable"
    return result


def _snapshot_shape(value, source_id):
    if value is None:
        return
    closed(value, ["feature", "source_id", "record_revision", "metadata_sha256", "original_sha256",
                   "extracted_sha256", "status", "reason"])
    require(isinstance(value["feature"], str) and re.fullmatch(r"[a-z0-9][a-z0-9-]*", value["feature"])
            and value["source_id"] == source_id and type(value["record_revision"]) is int
            and value["record_revision"] >= 1 and value["status"] in ("matching", "mismatch", "unavailable"),
            "watch-state-invalid")
    for field in ("metadata_sha256", "original_sha256", "extracted_sha256"):
        require((value[field] is None and field != "metadata_sha256")
                or (isinstance(value[field], str) and re.fullmatch(r"[a-f0-9]{64}", value[field])),
                "watch-state-invalid")
    require(value["reason"] is None or (isinstance(value["reason"], str)
            and re.fullmatch(r"[a-z][a-z0-9-]{0,79}", value["reason"])), "watch-state-invalid")
    require((value["reason"] is None) == (value["status"] == "matching"), "watch-state-invalid")
    if value["status"] != "unavailable":
        require(value["original_sha256"] is not None and value["extracted_sha256"] is not None,
                "watch-state-invalid")


def observe_feed(raw, previous, source_id, *, state_version=1, checked_at=None, snapshot=None):
    require(type(state_version) is int and state_version in (1, 2), "watch-state-invalid")
    require(isinstance(source_id, str) and re.fullmatch(r"SRC-[0-9]{3}", source_id), "watch-state-invalid")
    require(state_version == 2 or snapshot is None, "watch-state-version-required")
    checked_at = checked_at or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    timestamp(checked_at, "/last_checked_at")
    _snapshot_shape(snapshot, source_id)
    items = feed_items(raw)
    if previous is None:
        seen = set()
    else:
        keys = ["schema", "source_id", "seen_urls", "feed_sha256"]
        if isinstance(previous, dict) and previous.get("schema") == "research-watch-state/v2":
            require(state_version == 2, "watch-state-version-required")
            keys += ["last_checked_at", "feature", "source_snapshot"]
            require(previous["feature"] is None or (isinstance(previous["feature"], str)
                    and re.fullmatch(r"[a-z0-9][a-z0-9-]*", previous["feature"])), "watch-state-invalid")
            require(isinstance(previous["last_checked_at"], str), "watch-state-invalid")
            timestamp(previous["last_checked_at"], "/last_checked_at")
            require(previous["last_checked_at"] <= checked_at, "watch-clock-regression")
            _snapshot_shape(previous["source_snapshot"], source_id)
            require(previous["source_snapshot"] is None
                    or previous["source_snapshot"]["feature"] == previous["feature"], "watch-state-invalid")
            require(snapshot is None or previous["feature"] is None
                    or snapshot["feature"] == previous["feature"], "watch-feature-mismatch")
        closed(previous, keys)
        require(
            previous["schema"] in ("research-watch-state/v1", "research-watch-state/v2")
            and previous["source_id"] == source_id,
            "watch-state-invalid",
        )
        require(
            isinstance(previous["seen_urls"], list)
            and all(isinstance(x, str) for x in previous["seen_urls"]),
            "watch-state-invalid",
        )
        require(
            isinstance(previous["feed_sha256"], str)
            and re.fullmatch(r"[a-f0-9]{64}", previous["feed_sha256"]),
            "watch-state-invalid",
        )
        for url in previous["seen_urls"]:
            safe_url(url)
        seen = set(previous["seen_urls"])
    new = [item for item in items if item["url"] not in seen]
    result = dict(
        schema="research-watch-result/v1",
        source_id=source_id,
        status="initial-window"
        if previous is None
        else ("new-items" if new else "no-new-items"),
        items=new,
        feed_changed=previous is None or previous["feed_sha256"] != digest(raw),
        state=dict(
            schema="research-watch-state/v1",
            source_id=source_id,
            seen_urls=sorted(seen | {i["url"] for i in items}),
            feed_sha256=digest(raw),
        ),
        changes_approval=False,
    )
    if state_version == 2:
        old = previous.get("source_snapshot") if previous else None
        result["schema"] = "research-watch-result/v2"
        result["state"].update(schema="research-watch-state/v2", last_checked_at=checked_at,
                               feature=snapshot["feature"] if snapshot else (previous.get("feature") if previous else None),
                               source_snapshot=snapshot)
        result["metadata_changed"] = (old["metadata_sha256"] != snapshot["metadata_sha256"]
                                      if old and snapshot else None)
        fields = ("original_sha256", "extracted_sha256")
        result["cache_changed"] = (any(old[field] != snapshot[field] for field in fields)
                                   if old and snapshot and all(old[f] and snapshot[f] for f in fields)
                                   else None)
        result["source_status"] = snapshot["status"] if snapshot else "not-observed"
        result["reverification_required"] = bool(new or result["feed_changed"]
            or result["metadata_changed"] or result["cache_changed"]
            or (snapshot and (old is None or snapshot["status"] != "matching")))
    return result


def main(argv=None):
    p = Parser()
    p.add_argument("--source-id", required=True)
    p.add_argument("--feed-file")
    p.add_argument("--feed-url")
    p.add_argument("--allow-host", action="append")
    p.add_argument("--previous")
    p.add_argument("--file")
    p.add_argument("--relations")
    p.add_argument("--repo-root")
    p.add_argument("--state-version", type=int, choices=[1, 2], default=1)
    p.add_argument("--snapshots")
    p.add_argument("--snapshot-root")
    a = p.parse_args(argv)
    try:
        require(bool(a.feed_file) != bool(a.feed_url), "usage-invalid")
        if a.feed_file:
            with ordinary(a.feed_file).open("rb") as stream:
                raw = stream.read(1024 * 1024 + 1)
        else:
            spec = importlib.util.spec_from_file_location(
                "research_acquire", HERE / "research-acquire.py"
            )
            acquire = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(acquire)
            _, raw, _ = acquire.acquire(a.feed_url, a.allow_host)
        now = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        snapshot = None
        if a.snapshots or a.snapshot_root:
            require(a.file and a.snapshots and a.snapshot_root and a.state_version == 2, "usage-invalid")
            snapshot = source_snapshot(validate_file(a.file, a.repo_root), read_json(a.snapshots),
                                       a.snapshot_root, a.source_id, now)
        result = observe_feed(
            raw, read_json(a.previous) if a.previous else None, a.source_id,
            state_version=a.state_version, checked_at=now, snapshot=snapshot,
        )
        if a.relations or (snapshot is None and (a.file or a.repo_root)):
            require(a.file and a.relations and a.repo_root, "usage-invalid")
            result["impact"] = impact(
                validate_file(a.file, a.repo_root),
                read_json(a.relations),
                a.repo_root,
                a.source_id,
            )
        else:
            result["impact"] = dict(
                status="impact-unknown", reason="no-bound-relations"
            )
        print(json.dumps(result, sort_keys=True, ensure_ascii=False, indent=2))
        return 0
    except Invalid as e:
        print(
            json.dumps(
                dict(
                    schema=f"research-watch-result/v{a.state_version}",
                    status="unavailable",
                    reason=e.code,
                ),
                sort_keys=True,
            )
        )
        return 1
    except (OSError, TypeError, ValueError, KeyError):
        print(json.dumps(dict(schema=f"research-watch-result/v{a.state_version}",
                              status="unavailable", reason="input-invalid"), sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
