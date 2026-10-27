#!/usr/bin/env python3
"""Two-route source collection and bounded feed observations are non-authoritative."""

import importlib.util
from pathlib import Path
import unittest
import tempfile
import json
import os
import subprocess
import sys

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
    @unittest.skipUnless(sys.platform == "linux", "licensed shared store is Linux-only")
    def test_watch_rechecks_shared_store_receipt_and_permissions(self):
        acquire_tests = load("acquire_fixtures", ROOT / "tests/research-acquire.tests.py")
        acquire = acquire_tests.a
        with tempfile.TemporaryDirectory(prefix="research-watch-shared-", dir=Path.home()) as directory:
            cache = Path(directory) / "store"
            cache.mkdir(mode=0o750)
            cache.chmod(0o750)
            metadata, body, extracted = acquire._acquire(
                "https://example.org/doc", ["example.org"],
                resolver=acquire_tests.resolver, transport=acquire_tests.response,
            )
            saved = acquire.save_cache(
                metadata, body, extracted, cache, repository=ROOT,
                permission_basis="Synthetic group sharing", expires_at="2099-01-01T00:00:00Z",
                shared_gid=os.getegid(),
            )
            source = acquire.source_record(saved, "SRC-001", "Synthetic", "Synthetic group sharing")
            doc = dict(schema="research-evidence/v1", feature="sample", sources=[source], claims=[])
            key = saved["cache_key"]
            item = dict(source_id="SRC-001", record_revision=1, original=key + "/original", extracted=key + "/extracted.txt")
            manifest = dict(schema="research-snapshots/v1", feature="sample", snapshots=[item])
            now = "2090-01-01T00:00:00Z"
            self.assertEqual(watch.source_snapshot(doc, manifest, cache, "SRC-001", now)["status"], "matching")
            receipt = cache / key / "receipt.json"
            raw = receipt.read_bytes()
            receipt.write_text("{}")
            drift = watch.source_snapshot(doc, manifest, cache, "SRC-001", now)
            self.assertEqual((drift["status"], drift["reason"]), ("unavailable", "shared-receipt-mismatch"))
            receipt.write_bytes(raw)
            original = cache / key / "original"
            original.chmod(0o644)
            drift = watch.source_snapshot(doc, manifest, cache, "SRC-001", now)
            self.assertEqual((drift["status"], drift["reason"]), ("unavailable", "shared-permissions"))
            original.chmod(0o640)
            receipt.unlink()
            drift = watch.source_snapshot(doc, manifest, cache, "SRC-001", now)
            self.assertEqual(drift["status"], "unavailable")
            self.assertIsNone(drift["original_sha256"])
            receipt.write_bytes(raw)
            receipt.chmod(0o640)
            item["original"] = "wrong/original"
            drift = watch.source_snapshot(doc, manifest, cache, "SRC-001", now)
            self.assertEqual((drift["status"], drift["reason"]), ("unavailable", "shared-snapshot-path-invalid"))

    def test_ordinary_terms_allowed_and_two_routes_explicit(self):
        plan = sources.search_plan("HTTP redirect DNS pinning")
        self.assertEqual(
            ["official", "citation-trail"], [r["route"] for r in plan["routes"]]
        )
        self.assertEqual("none", plan["authority"])

    def study(self):
        doc = f.document()
        doc["claims"] = [dict(f.claim(), claim_id=f"CLM-{i:03}",
                              statement="Keep private data local" if i == 1 else f"Alternative {i} reduces retries")
                         for i in range(1, 4)]
        return doc

    def test_claim_plan_preserves_constraint_and_bounded_search_without_meaning_claim(self):
        plan = sources.search_plan("retry strategy", document=self.study(),
                                   constraint="Keep private data local", assessable=["CLM-002", "CLM-003"])
        self.assertEqual(plan["claims"]["verbatim_constraint"], "Keep private data local")
        self.assertEqual(plan["claims"]["semantic_assessment"], "caller-declared-not-verified")
        self.assertEqual(plan["max_rounds"], 4)
        self.assertEqual(plan["minimum_citation_follow_attempts"], 1)
        self.assertNotIn("both-routes-inspected", plan["stop_when"])
        self.assertEqual(len(plan["routes"]), 2)

    def test_planning_preserves_history_and_pins_latest_distinct_claim_revisions(self):
        doc = self.study()
        revised = dict(doc["claims"][0], record_revision=2)
        doc["claims"].insert(1, revised)
        plan = sources.search_plan("retry strategy", document=doc,
                                   constraint="Keep private data local", assessable=["CLM-002", "CLM-003"])
        self.assertEqual(len(doc["claims"]), 4)
        self.assertEqual(len(plan["claims"]["claim_ids"]), 3)
        selected = plan["claims"]["claim_records"][0]
        self.assertEqual(selected["record_revision"], 2)
        self.assertEqual(selected["record_sha256"], sources.record_digest(revised))

    def test_claim_count_verbatim_identity_and_majority_reject_before_query(self):
        cases = [
            dict(document=dict(self.study(), claims=self.study()["claims"][:2])),
            dict(constraint="A paraphrase is not the request"),
            dict(assessable=["CLM-001"]),
            dict(assessable=["CLM-001", "CLM-001"]),
            dict(assessable=["CLM-001", "CLM-999"]),
            dict(saturation=float("nan")),
            dict(saturation=0),
        ]
        for changes in cases:
            args = dict(document=self.study(), constraint="Keep private data local",
                        assessable=["CLM-002", "CLM-003"])
            args.update(changes)
            with self.subTest(changes=changes), self.assertRaises(sources.Invalid):
                sources.search_plan("retry strategy", **args)
        with self.assertRaises(sources.Invalid):
            sources.search_plan("retry strategy", constraint="Missing canonical records")

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

    def cache_fixture(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name).resolve()
        (root / "original.txt").write_bytes(b"original")
        (root / "extracted.txt").write_bytes(b"original")
        doc = f.document()
        manifest = dict(schema="research-snapshots/v1", feature="sample", snapshots=[
            dict(source_id="SRC-001", record_revision=1, original="original.txt", extracted="extracted.txt")])
        return root, doc, manifest

    def test_watch_v2_migrates_timestamp_without_changing_legacy_default(self):
        legacy = watch.observe_feed(RSS, None, "SRC-001")
        self.assertEqual(legacy["state"]["schema"], "research-watch-state/v1")
        checked = "2026-10-25T02:00:00Z"
        migrated = watch.observe_feed(RSS, legacy["state"], "SRC-001", state_version=2, checked_at=checked)
        self.assertEqual(migrated["state"]["last_checked_at"], checked)
        self.assertEqual(migrated["source_status"], "not-observed")
        self.assertIsNone(migrated["cache_changed"])
        self.assertEqual(migrated["status"], "no-new-items")
        with self.assertRaises(watch.Invalid):
            watch.observe_feed(RSS, migrated["state"], "SRC-001")
        with self.assertRaisesRegex(watch.Invalid, "watch-clock-regression"):
            watch.observe_feed(RSS, migrated["state"], "SRC-001", state_version=2,
                               checked_at="2026-10-25T01:00:00Z")

    def test_original_cache_drift_is_detected_without_any_feed_update(self):
        root, doc, manifest = self.cache_fixture()
        now = "2026-10-25T02:00:00Z"
        snapshot = watch.source_snapshot(doc, manifest, root, "SRC-001", now)
        first = watch.observe_feed(RSS, None, "SRC-001", state_version=2, checked_at=now, snapshot=snapshot)
        (root / "original.txt").write_bytes(b"changed original")
        changed = watch.source_snapshot(doc, manifest, root, "SRC-001", now)
        result = watch.observe_feed(RSS, first["state"], "SRC-001", state_version=2, checked_at=now, snapshot=changed)
        self.assertEqual(result["status"], "no-new-items")
        self.assertFalse(result["feed_changed"])
        self.assertFalse(result["metadata_changed"])
        self.assertTrue(result["cache_changed"])
        self.assertEqual(result["source_status"], "mismatch")
        self.assertTrue(result["reverification_required"])
        self.assertEqual((root / "original.txt").read_bytes(), b"changed original")

    def test_metadata_change_and_missing_cache_are_distinct(self):
        root, doc, manifest = self.cache_fixture()
        now = "2026-10-25T02:00:00Z"
        snapshot = watch.source_snapshot(doc, manifest, root, "SRC-001", now)
        first = watch.observe_feed(RSS, None, "SRC-001", state_version=2, checked_at=now, snapshot=snapshot)
        doc["sources"][0]["title"] = "Changed metadata"
        changed = watch.source_snapshot(doc, manifest, root, "SRC-001", now)
        result = watch.observe_feed(RSS, first["state"], "SRC-001", state_version=2, checked_at=now, snapshot=changed)
        self.assertTrue(result["metadata_changed"])
        self.assertFalse(result["cache_changed"])
        self.assertEqual(result["source_status"], "matching")
        (root / "original.txt").unlink()
        unavailable = watch.source_snapshot(doc, manifest, root, "SRC-001", now)
        result = watch.observe_feed(RSS, first["state"], "SRC-001", state_version=2, checked_at=now, snapshot=unavailable)
        self.assertEqual(result["source_status"], "unavailable")
        self.assertIsNone(result["cache_changed"])
        self.assertTrue(result["reverification_required"])
        self.assertFalse((root / "original.txt").exists())

    def test_watch_state_cannot_cross_feature_even_after_feed_only_observation(self):
        root, doc, manifest = self.cache_fixture()
        now = "2026-10-25T02:00:00Z"
        snapshot = watch.source_snapshot(doc, manifest, root, "SRC-001", now)
        first = watch.observe_feed(RSS, None, "SRC-001", state_version=2, checked_at=now, snapshot=snapshot)
        doc["feature"] = manifest["feature"] = "unrelated"
        unrelated = watch.source_snapshot(doc, manifest, root, "SRC-001", now)
        feed_only = watch.observe_feed(RSS, first["state"], "SRC-001", state_version=2, checked_at=now)
        self.assertEqual(feed_only["state"]["feature"], "sample")
        for previous in (first["state"], feed_only["state"]):
            with self.assertRaisesRegex(watch.Invalid, "watch-feature-mismatch"):
                watch.observe_feed(RSS, previous, "SRC-001", state_version=2,
                                   checked_at=now, snapshot=unrelated)

    def test_watch_v2_cli_reports_drift_without_writing_inputs(self):
        root, doc, manifest = self.cache_fixture()
        (root / "feed.xml").write_bytes(RSS)
        (root / "records.json").write_text(json.dumps(doc))
        (root / "snapshots.json").write_text(json.dumps(manifest))
        command = [sys.executable, str(ROOT / "plugins/sdd-bootstrap/scripts/research-watch.py"),
                   "--source-id", "SRC-001", "--feed-file", str(root / "feed.xml"),
                   "--state-version", "2", "--file", str(root / "records.json"),
                   "--snapshots", str(root / "snapshots.json"), "--snapshot-root", str(root)]
        first = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        state = json.loads(first.stdout)["state"]
        previous = json.dumps(state).encode()
        (root / "previous.json").write_bytes(previous)
        (root / "extracted.txt").write_bytes(b"changed extracted")
        second = subprocess.run(command + ["--previous", str(root / "previous.json")], capture_output=True, text=True)
        self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
        result = json.loads(second.stdout)
        self.assertEqual(result["schema"], "research-watch-result/v2")
        self.assertTrue(result["cache_changed"])
        self.assertFalse(result["feed_changed"])
        self.assertFalse(result["changes_approval"])
        self.assertEqual((root / "previous.json").read_bytes(), previous)
        self.assertNotIn(str(root), second.stdout)

    def test_watch_private_escape_and_rights_are_not_read_or_persisted(self):
        root, doc, manifest = self.cache_fixture()
        now = "2026-10-25T02:00:00Z"
        manifest["snapshots"][0]["original"] = "../outside"
        result = watch.source_snapshot(doc, manifest, root, "SRC-001", now)
        self.assertEqual(result["status"], "unavailable")
        self.assertEqual(result["reason"], "path-invalid")
        self.assertNotIn("../outside", str(result))
        doc["sources"][0]["currency_status"] = "stale"
        doc["sources"][0]["currency_note"] = "New version expected"
        result = watch.source_snapshot(doc, manifest, root, "SRC-001", now)
        self.assertEqual(result["reason"], "source-stale")
        self.assertIsNone(result["original_sha256"])

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
