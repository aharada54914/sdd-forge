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
)
from research_consumers import impact, closed  # noqa: E402 - sibling runtime path is explicit.


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


def observe_feed(raw, previous, source_id):
    items = feed_items(raw)
    if previous is None:
        seen = set()
    else:
        closed(previous, ["schema", "source_id", "seen_urls", "feed_sha256"])
        require(
            previous["schema"] == "research-watch-state/v1"
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
    return dict(
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
        result = observe_feed(
            raw, read_json(a.previous) if a.previous else None, a.source_id
        )
        if a.file or a.relations or a.repo_root:
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
                    schema="research-watch-result/v1",
                    status="unavailable",
                    reason=e.code,
                ),
                sort_keys=True,
            )
        )
        return 1
    except (OSError, TypeError, ValueError, KeyError):
        print(
            '{"schema":"research-watch-result/v1","status":"unavailable","reason":"input-invalid"}'
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
