#!/usr/bin/env python3
"""Two-route source collection and bounded feed observations are non-authoritative."""

import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


sources = load("sources", ROOT / "plugins/sdd-bootstrap/scripts/research-sources.py")
watch = load("watch", ROOT / "plugins/sdd-bootstrap/scripts/research-watch.py")
f = load("fixture", ROOT / "tests/research-evidence.tests.py")

RSS = b"<rss><channel><item><title>New source</title><link>https://example.org/new</link><pubDate>Sun, 25 Oct 2026 01:00:00 GMT</pubDate></item></channel></rss>"
ATOM = b'<feed xmlns="http://www.w3.org/2005/Atom"><entry><title>New source</title><link href="https://example.org/new"/><updated>2026-10-25T01:00:00Z</updated></entry></feed>'


class Discovery(unittest.TestCase):
    def test_ordinary_terms_allowed_and_two_routes_explicit(self):
        plan = sources.search_plan("HTTP redirect DNS pinning")
        self.assertEqual(
            ["official", "citation-trail"], [r["route"] for r in plan["routes"]]
        )
        self.assertEqual("none", plan["authority"])

    def test_secrets_no_send_and_bad_budget_stop_before_query(self):
        for question, kwargs in [
            ("ghp_" + "x" * 36, {}),
            ("HTTP", dict(no_send=True)),
            ("HTTP", dict(budget=0)),
        ]:
            with self.assertRaises(sources.Invalid):
                sources.search_plan(question, **kwargs)

    def test_two_routes_dedupe_source_without_assessing_claims(self):
        doc = dict(
            schema="research-evidence/v1", feature="sample", sources=[], claims=[]
        )
        batches = [
            dict(route=route, query="HTTP", sources=[f.source()])
            for route in ["official", "citation-trail"]
        ]
        result = sources.merge_routes(doc, batches)
        self.assertEqual(1, len(result["records"]["sources"]))
        self.assertFalse(result["claims_assessed"])
        self.assertEqual(["SRC-001"], result["routes"][1]["source_ids"])

    def test_distinct_source_versions_are_not_deduplicated(self):
        a = f.source()
        b = f.source()
        b["source_revision"] = "v2"
        batches = [
            dict(route="official", query="HTTP", sources=[a]),
            dict(route="citation-trail", query="HTTP", sources=[b]),
        ]
        result = sources.merge_routes(
            dict(
                schema="research-evidence/v1", feature="sample", sources=[], claims=[]
            ),
            batches,
        )
        self.assertEqual(
            ["SRC-001", "SRC-002"],
            [s["source_id"] for s in result["records"]["sources"]],
        )

    def test_duplicate_routes_untrusted_pass_and_budget_fail(self):
        doc = dict(
            schema="research-evidence/v1", feature="sample", sources=[], claims=[]
        )
        batches = [
            dict(route="official", query="HTTP", sources=[f.source()]),
            dict(route="official", query="HTTP", sources=[]),
        ]
        with self.assertRaises(sources.Invalid):
            sources.merge_routes(doc, batches)
        batches[1]["route"] = "citation-trail"
        batches[0]["sources"][0].update(
            verification_status="hash-verified", verification_at="2026-10-02T00:00:00Z"
        )
        with self.assertRaisesRegex(sources.Invalid, "untrusted-verification"):
            sources.merge_routes(doc, batches)

    def test_rss_atom_same_items_and_repeat_no_new(self):
        self.assertEqual(watch.feed_items(RSS), watch.feed_items(ATOM))
        first = watch.observe_feed(RSS, None, "SRC-001")
        self.assertEqual("initial-window", first["status"])
        second = watch.observe_feed(RSS, first["state"], "SRC-001")
        self.assertEqual("no-new-items", second["status"])
        self.assertFalse(second["changes_approval"])

    def test_new_item_preserves_seen_set(self):
        first = watch.observe_feed(RSS, None, "SRC-001")
        second = watch.observe_feed(
            RSS.replace(b"/new", b"/second"), first["state"], "SRC-001"
        )
        self.assertEqual("new-items", second["status"])
        self.assertEqual(2, len(second["state"]["seen_urls"]))

    def test_known_url_body_change_is_distinct_from_new_item(self):
        first = watch.observe_feed(RSS, None, "SRC-001")
        changed = RSS.replace(b"</channel>", b"<!-- changed feed --> </channel>")
        result = watch.observe_feed(changed, first["state"], "SRC-001")
        self.assertEqual("no-new-items", result["status"])
        self.assertTrue(result["feed_changed"])
        self.assertFalse(
            watch.observe_feed(RSS, first["state"], "SRC-001")["feed_changed"]
        )
        for value in (None, True, [], {}, "invalid", 17):
            previous = dict(first["state"], feed_sha256=value)
            with self.subTest(value=value), self.assertRaises(watch.Invalid):
                watch.observe_feed(RSS, previous, "SRC-001")

    def test_entity_utf16_dates_and_urls_fail(self):
        cases = [
            b'<!DOCTYPE rss [<!ENTITY x "hello">]><rss>&x;</rss>',
            '<!DOCTYPE rss [<!ENTITY x "hello">]><rss>&x;</rss>'.encode("utf-16"),
            RSS.replace(b"Sun, 25 Oct 2026 01:00:00 GMT", b"invalid"),
            RSS.replace(b"https://example.org/new", b"file:///etc/passwd"),
            b"<html>login page</html>",
        ]
        for raw in cases:
            with self.subTest(raw=raw[:20]), self.assertRaises(watch.Invalid):
                watch.feed_items(raw)

    def test_duplicates_and_bad_previous_state(self):
        duplicate = RSS.replace(
            b"</channel>",
            RSS.split(b"<channel>")[1].split(b"</channel>")[0] + b"</channel>",
        )
        self.assertEqual(1, len(watch.feed_items(duplicate)))
        previous = watch.observe_feed(RSS, None, "SRC-001")["state"]
        previous["source_id"] = "SRC-002"
        with self.assertRaises(watch.Invalid):
            watch.observe_feed(RSS, previous, "SRC-001")


if __name__ == "__main__":
    unittest.main()
