#!/usr/bin/env python3
"""Actual quote verification and read-only graph/HTML negative controls."""

import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "plugins/sdd-quality-loop/scripts"
sys.path.insert(0, str(SCRIPTS))
from research_evidence import Invalid, record_digest, digest  # noqa: E402 - sibling runtime path is explicit.
from research_consumers import (  # noqa: E402 - sibling runtime path is explicit.
    verify_originals,
    validate_relations,
    impact,
    render_report,
    validate_verification_record,
)
from research_extraction import extract  # noqa: E402 - sibling runtime path is explicit.

spec = importlib.util.spec_from_file_location(
    "research_fixture", Path(__file__).with_name("research-evidence.tests.py")
)
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)


class Consumers(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.doc = fixture.document()
        (self.root / "original").write_bytes(b"original")
        (self.root / "text").write_bytes(b"original")
        self.snapshots = dict(
            schema="research-snapshots/v1",
            feature="sample",
            snapshots=[
                dict(
                    source_id="SRC-001",
                    record_revision=1,
                    original="original",
                    extracted="text",
                )
            ],
        )
        self.now = "2026-10-02T00:00:00Z"

    def verify(self):
        return verify_originals(self.doc, self.snapshots, self.root, now=self.now)

    def test_subtitle_time_is_recomputed_from_original_not_claimed_metadata(self):
        original = b'WEBVTT\n\n00:01.200 --> 00:03.500\noriginal\n\n00:04.000 --> 00:06.000\nLater statement.\n'
        extracted, method, _ = extract(original, 'text/vtt')
        (self.root / 'original').write_bytes(original)
        (self.root / 'text').write_bytes(extracted)
        source = self.doc['sources'][0]
        source.update(media_type='text/vtt', content_sha256=digest(original))
        source['extraction'] = dict(method=method, extracted_sha256=digest(extracted))
        anchor = self.doc['claims'][0]['citations'][0]['anchor']
        anchor.update(line_start=2, line_end=2)
        result = self.verify()
        self.assertEqual(result['schema'], 'source-evidence-result/v2')
        self.assertEqual(result['results'][0]['time_range'], dict(start_ms=1200, end_ms=3500))
        validate_verification_record(self.doc, result)
        self.assertIn('00:00:01.200–00:00:03.500', render_report(self.doc, result))
        for bad in [dict(start_ms=True, end_ms=3500), dict(start_ms=4000, end_ms=3500), {}]:
            forged = copy.deepcopy(result)
            forged['results'][0]['time_range'] = bad
            with self.subTest(bad=bad), self.assertRaises(Invalid):
                validate_verification_record(self.doc, forged)
        forged = copy.deepcopy(result)
        forged['schema'] = 'source-evidence-result/v1'
        with self.assertRaises(Invalid):
            validate_verification_record(self.doc, forged)
        changed = extracted.replace(b'1200 3500', b'9000 9500')
        (self.root / 'text').write_bytes(changed)
        source['extraction']['extracted_sha256'] = digest(changed)
        with self.assertRaisesRegex(Invalid, 'extraction-provenance-mismatch'):
            self.verify()

    def test_recomputes_original_and_quote_and_never_semantic_pass(self):
        result = self.verify()
        self.assertTrue(result["complete"])
        self.assertFalse(result["meaning_assessed"])
        self.assertEqual("reverified", result["results"][0]["result"])
        (self.root / "original").write_bytes(b"Original")
        with self.assertRaisesRegex(Invalid, "snapshot-hash-mismatch"):
            self.verify()

    def test_forged_extracted_text_cannot_keep_original_proof(self):
        forged = b"Completely invented statement."
        (self.root / "text").write_bytes(forged)
        self.doc["sources"][0]["extraction"]["extracted_sha256"] = digest(forged)
        anchor = self.doc["claims"][0]["citations"][0]["anchor"]
        anchor["quote"] = forged.decode()
        anchor["quote_sha256"] = digest(forged)
        with self.assertRaises(Invalid):
            self.verify()

    def test_optional_translation_is_bound_escaped_and_not_meaning_proof(self):
        translation = dict(
            claim_id="CLM-001",
            claim_revision=1,
            citation=0,
            quote_sha256=self.doc["claims"][0]["citations"][0]["anchor"][
                "quote_sha256"
            ],
            language="ja",
            text="<script>translation</script>",
        )
        annotations = dict(
            schema="research-report-annotations/v1",
            feature="sample",
            translations=[translation],
        )
        rendered = render_report(self.doc, self.verify(), annotations)
        self.assertIn("Translation (ja); meaning not verified", rendered)
        self.assertIn("&lt;script&gt;translation&lt;/script&gt;", rendered)
        self.assertNotIn("<script>", rendered)
        for value in ("0" * 64, None, True, [], {}):
            translation["quote_sha256"] = value
            with self.subTest(value=value), self.assertRaises(Invalid):
                render_report(self.doc, self.verify(), annotations)

    def test_original_absent_does_not_replay_metadata_pass(self):
        self.doc["sources"][0].update(
            verification_status="hash-verified", verification_at=self.now
        )
        (self.root / "original").unlink()
        with self.assertRaisesRegex(Invalid, "file-unreadable"):
            self.verify()

    def test_false_quote_line_shift_and_extraction_hash(self):
        for case in ["quote", "line", "hash"]:
            d = copy.deepcopy(self.doc)
            if case == "quote":
                d["claims"][0]["citations"][0]["anchor"]["quote"] = "paraphrased"
            if case == "line":
                d["claims"][0]["citations"][0]["anchor"]["line_end"] = 2
            if case == "hash":
                d["sources"][0]["extraction"]["extracted_sha256"] = "0" * 64
            with self.subTest(case=case), self.assertRaises(Invalid):
                verify_originals(d, self.snapshots, self.root, now=self.now)

    def test_whitespace_is_explicit_not_exact_pass(self):
        raw = b"original  text"
        (self.root / "original").write_bytes(raw)
        (self.root / "text").write_bytes(raw)
        s = self.doc["sources"][0]
        s["content_sha256"] = digest(raw)
        s["extraction"]["extracted_sha256"] = digest(raw)
        a = self.doc["claims"][0]["citations"][0]["anchor"]
        a["quote"] = "original text"
        a["quote_sha256"] = digest(a["quote"].encode())
        with self.assertRaisesRegex(Invalid, "quote-mismatch"):
            self.verify()
        result = verify_originals(
            self.doc, self.snapshots, self.root, matching="whitespace", now=self.now
        )
        self.assertEqual("whitespace", result["results"][0]["matching"])

    def test_paths_symlinks_extra_revisions_and_duplicates(self):
        for value in ["../original", "/original", "C:/original", "a\\original", "a//b"]:
            data = copy.deepcopy(self.snapshots)
            data["snapshots"][0]["original"] = value
            with self.subTest(value=value), self.assertRaises(Invalid):
                verify_originals(self.doc, data, self.root)
        target = self.root / "link"
        try:
            target.symlink_to(self.root / "original")
        except OSError:
            pass
        else:
            data = copy.deepcopy(self.snapshots)
            data["snapshots"][0]["original"] = "link"
            with self.assertRaises(Invalid):
                verify_originals(self.doc, data, self.root)
        self.snapshots["snapshots"] *= 2
        with self.assertRaisesRegex(Invalid, "snapshot-invalid"):
            self.verify()

    def test_blocked_expired_stale_and_missing_snapshot(self):
        for changes in [
            dict(storage_mode="blocked"),
            dict(currency_status="stale"),
            dict(retention_or_expiry=dict(expires_at="2026-10-01T00:00:00Z")),
        ]:
            d = copy.deepcopy(self.doc)
            d["sources"][0].update(changes)
            with self.assertRaises(Invalid):
                verify_originals(d, self.snapshots, self.root, now=self.now)
        self.snapshots["snapshots"] = []
        with self.assertRaisesRegex(Invalid, "snapshot-missing"):
            self.verify()

    def graph(self):
        path = self.root / "specs/sample"
        path.mkdir(parents=True, exist_ok=True)
        req = b"# Requirements\n\n## REQ-001 First\n\n## REQ-002 Independent\n"
        (path / "requirements.md").write_bytes(req)
        (path / "traceability.json").write_text(
            json.dumps(
                dict(
                    feature="sample",
                    links=[
                        dict(
                            req="REQ-001",
                            acs=["AC-001", "AC-002"],
                            tests=["TEST-001", "TEST-002"],
                            evidence=["proof.json"],
                        ),
                        dict(
                            req="REQ-002",
                            acs=["AC-003"],
                            tests=["TEST-003"],
                            evidence=["other.json"],
                        ),
                    ],
                )
            )
        )
        c = dict(
            kind="CLM",
            feature="sample",
            id="CLM-001",
            record_revision=1,
            record_sha256=record_digest(self.doc["claims"][0]),
        )
        r = dict(
            kind="REQ", feature="sample", id="REQ-001", document_sha256=digest(req)
        )
        return dict(
            schema="research-relations/v1",
            feature="sample",
            edges=[dict(relation="justifies", **{"from": c, "to": r})],
        )

    def test_impact_joins_existing_traceability_only_affected_requirements(self):
        graph = self.graph()
        result = impact(self.doc, graph, self.root, "SRC-001")
        self.assertEqual(["REQ-001"], result["requirements"])
        self.assertEqual(["TEST-001", "TEST-002"], result["traceability"][0]["tests"])
        self.assertFalse(result["changes_approval"])
        self.assertEqual(result, impact(self.doc, graph, self.root, "SRC-001"))

    def test_graph_rejects_stale_dangling_wrong_direction_duplicates(self):
        graph = self.graph()
        for mutation in [
            "hash",
            "kind",
            "direction",
            "duplicate",
            "missing",
            "unknown",
        ]:
            g = copy.deepcopy(graph)
            if mutation == "hash":
                g["edges"][0]["from"]["record_sha256"] = "0" * 64
            if mutation == "kind":
                g["edges"][0]["to"]["kind"] = "TASK"
            if mutation == "direction":
                g["edges"][0]["from"], g["edges"][0]["to"] = (
                    g["edges"][0]["to"],
                    g["edges"][0]["from"],
                )
            if mutation == "duplicate":
                g["edges"] *= 2
            if mutation == "missing":
                g["edges"][0]["to"]["id"] = "REQ-999"
            if mutation == "unknown":
                g["schema"] = "research-relations/v9"
            with self.subTest(mutation=mutation), self.assertRaises(Invalid):
                validate_relations(self.doc, g, self.root)

    def test_cycle_terminates_and_is_reported(self):
        graph = self.graph()
        c = copy.deepcopy(self.doc["claims"][0])
        c["claim_id"] = "CLM-002"
        self.doc["claims"].append(c)
        a = graph["edges"][0]["from"]
        b = dict(
            kind="CLM",
            feature="sample",
            id="CLM-002",
            record_revision=1,
            record_sha256=record_digest(c),
        )
        graph["edges"].extend(
            [
                dict(relation="depends-on", **{"from": a, "to": b}),
                dict(relation="depends-on", **{"from": b, "to": a}),
            ]
        )
        result = impact(self.doc, graph, self.root, "SRC-001")
        self.assertTrue(result["cycles"])
        self.assertEqual(["CLM-001", "CLM-002"], result["claims"])

    def test_html_escapes_original_and_no_scripts_or_full_text(self):
        raw = b"<script>alert(1)</script>\nprivate full text not quoted"
        (self.root / "original").write_bytes(raw)
        (self.root / "text").write_bytes(raw)
        s = self.doc["sources"][0]
        s["content_sha256"] = digest(raw)
        s["extraction"]["extracted_sha256"] = digest(raw)
        a = self.doc["claims"][0]["citations"][0]["anchor"]
        a["quote"] = "<script>alert(1)</script>"
        a["quote_sha256"] = digest(a["quote"].encode())
        page = render_report(self.doc, self.verify())
        self.assertNotIn("<script>", page)
        self.assertIn("&lt;script&gt;", page)
        self.assertNotIn("private full text", page)
        self.assertIn("<details>", page)

    def test_cli_failed_regeneration_preserves_report(self):
        doc = self.root / "records.json"
        manifest = self.root / "snapshots.json"
        output = self.root / "report.html"
        doc.write_text(json.dumps(self.doc))
        manifest.write_text(json.dumps(self.snapshots))
        output.write_text("previous report")
        (self.root / "original").write_bytes(b"tampered")
        run = subprocess.run(
            [
                sys.executable,
                str(SCRIPTS / "research-evidence-tools.py"),
                "report",
                "--file",
                str(doc),
                "--snapshots",
                str(manifest),
                "--snapshot-root",
                str(self.root),
                "--output",
                str(output),
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(1, run.returncode)
        self.assertEqual("previous report", output.read_text())

    def test_non_source_or_missing_graph_not_zero_impact(self):
        graph = self.graph()
        with self.assertRaisesRegex(Invalid, "source-missing"):
            impact(self.doc, graph, self.root, "SRC-999")
        graph["edges"] = []
        self.assertEqual(
            "impact-unknown", impact(self.doc, graph, self.root, "SRC-001")["status"]
        )


if __name__ == "__main__":
    unittest.main()
