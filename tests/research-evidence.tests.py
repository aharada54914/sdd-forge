#!/usr/bin/env python3
"""Research metadata trust-boundary and history regressions (#605)."""

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "plugins/sdd-quality-loop/scripts"
sys.path.insert(0, str(SCRIPTS))
from research_evidence import Invalid, validate_document, validate_file, record_digest  # noqa: E402 - sibling runtime path is explicit.


def source():
    return dict(
        source_id="SRC-001",
        record_revision=1,
        source_type="official-doc",
        title="Example",
        authors=[],
        url="https://example.org/doc",
        final_url="https://example.org/doc",
        source_revision="v1",
        retrieval_status="retrieved",
        attempted_at="2026-10-01T00:00:00Z",
        retrieved_at="2026-10-01T00:00:01Z",
        content_sha256=hashlib.sha256(b"original").hexdigest(),
        media_type="text/plain",
        extraction=dict(
            method="plain/v1", extracted_sha256=hashlib.sha256(b"original").hexdigest()
        ),
        currency_status="current",
        currency_note=None,
        verification_status="unverified",
        verification_at=None,
        storage_mode="reference_only",
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


def claim():
    return dict(
        claim_id="CLM-001",
        record_revision=1,
        statement="A claim needing independent interpretation",
        evidence_status="cited",
        search_record=None,
        citations=[
            dict(
                source_id="SRC-001",
                source_record_revision=1,
                relation="supports",
                anchor=dict(
                    line_start=1,
                    line_end=1,
                    quote="original",
                    quote_sha256=hashlib.sha256(b"original").hexdigest(),
                ),
                quote_status="unverified",
                quote_verified_at=None,
            )
        ],
        semantic_status="unassessed",
        semantic_assessed_by=None,
        semantic_note=None,
        uncertainty=None,
    )


def document():
    return dict(
        schema="research-evidence/v1",
        feature="sample",
        sources=[source()],
        claims=[claim()],
    )


class ResearchTests(unittest.TestCase):
    def reject(self, doc, code=None):
        with self.assertRaises(Invalid) as caught:
            validate_document(doc)
        if code:
            self.assertEqual(code, caught.exception.code)

    def test_valid_metadata_is_passive(self):
        doc = document()
        self.assertEqual(doc, validate_document(doc))
        self.assertEqual("unassessed", doc["claims"][0]["semantic_status"])

    def test_wrong_scalar_types_throughout_document(self):
        def leaves(value, path=()):
            if isinstance(value, dict):
                for key, child in value.items():
                    yield from leaves(child, path + (key,))
            elif isinstance(value, list):
                for index, child in enumerate(value):
                    yield from leaves(child, path + (index,))
            else:
                yield path, value

        baseline = document()
        for path, original in leaves(baseline):
            # null marks explicitly nullable fields; object alternatives are tested separately.
            replacements = (
                [True, [], {}, 3.5]
                if isinstance(original, str) or original is None
                else [None, [], {}, "invalid", True]
            )
            for replacement in replacements:
                if type(original) is type(replacement):
                    continue
                d = copy.deepcopy(baseline)
                target = d
                for part in path[:-1]:
                    target = target[part]
                target[path[-1]] = replacement
                with self.subTest(path=path, replacement=replacement):
                    self.reject(d)

    def test_empty_new_document(self):
        validate_document(
            dict(schema="research-evidence/v1", feature="new", sources=[], claims=[])
        )

    def test_closed_objects_at_every_layer(self):
        for target in ("root", "source", "claim", "anchor", "permission", "extraction"):
            with self.subTest(target=target):
                d = document()
                obj = {
                    "root": d,
                    "source": d["sources"][0],
                    "claim": d["claims"][0],
                    "anchor": d["claims"][0]["citations"][0]["anchor"],
                    "permission": d["sources"][0]["license_or_permission_basis"],
                    "extraction": d["sources"][0]["extraction"],
                }[target]
                obj["unexpected-secret-key"] = "value"
                self.reject(d, "schema-invalid")

    def test_required_nullable_fields_are_required(self):
        d = document()
        del d["sources"][0]["uncertainty"]
        self.reject(d, "schema-invalid")

    def test_ids_order_duplicates_and_revision_gaps(self):
        d = document()
        d["sources"].append(copy.deepcopy(d["sources"][0]))
        self.reject(d, "id-duplicate")
        d = document()
        d["sources"][0]["record_revision"] = 2
        self.reject(d, "revision-gap")
        d = document()
        s = source()
        s["source_id"] = "SRC-000"
        d["sources"].append(s)
        self.reject(d, "value-invalid")

    def test_numbers_calendar_unicode_and_size(self):
        for field, value in [
            ("record_revision", True),
            ("record_revision", 0),
            ("attempted_at", "2026-02-30T00:00:00Z"),
            ("title", "\ud800"),
            ("title", "x" * 2049),
        ]:
            d = document()
            d["sources"][0][field] = value
            self.reject(d)

    def test_urls_and_secret_values_do_not_leak(self):
        for url in [
            "file:///etc/passwd",
            "https://user:password@example.org",
            "https://example.org/?%74oken=secret",
            "https://example.org/\nheader",
            "https://example.org:bad/",
        ]:
            d = document()
            d["sources"][0]["url"] = url
            self.reject(d)
        d = document()
        d["sources"][0]["title"] = "ghp_" + "a" * 36
        self.reject(d, "secret-detected")
        d = document()
        d["sources"][0]["title"] = 'TOKEN="' + "a" * 12 + '"'
        self.reject(d, "secret-detected")

    def test_retrieval_and_verification_axes(self):
        for change in [
            {"retrieval_status": "not-attempted"},
            {"retrieved_at": None},
            {"attempted_at": "2026-10-02T00:00:00Z"},
            {"verification_status": "hash-verified"},
            {"currency_status": "stale"},
        ]:
            d = document()
            d["sources"][0].update(change)
            self.reject(d, "status-inconsistent")

    def test_rights_do_not_follow_public_url(self):
        d = document()
        d["sources"][0]["storage_mode"] = "local_cache"
        self.reject(d, "rights-inconsistent")
        d = document()
        d["sources"][0]["license_or_permission_basis"]["status"] = "permitted"
        self.reject(d, "rights-inconsistent")

    def test_storage_retention_and_scope(self):
        d = document()
        s = d["sources"][0]
        s.update(
            storage_mode="local_cache",
            storage_location_class="local-cache",
            access_scope="local-user",
            license_or_permission_basis=dict(
                status="permitted",
                basis="Recorded owner permission",
                asserted_by="human",
            ),
            retention_or_expiry=dict(
                expires_at="2026-11-01T00:00:00Z",
                delete_when=["expiry", "rights-revoked"],
            ),
        )
        validate_document(d)
        for change in [
            {"access_scope": "named-group"},
            {"storage_location_class": "shared-store"},
            {"retention_or_expiry": None},
        ]:
            bad = copy.deepcopy(d)
            bad["sources"][0].update(change)
            self.reject(bad, "storage-inconsistent")
        s["retention_or_expiry"]["expires_at"] = "2026-09-01T00:00:00Z"
        self.reject(d, "storage-inconsistent")

    def test_unresolved_duplicate_and_modified_quotes(self):
        d = document()
        d["claims"][0]["citations"][0]["source_id"] = "SRC-999"
        self.reject(d, "citation-unresolved")
        d = document()
        d["claims"][0]["citations"] *= 2
        self.reject(d, "id-duplicate")
        for change in [{"quote": "paraphrase"}, {"line_end": 6}, {"line_start": 2}]:
            d = document()
            d["claims"][0]["citations"][0]["anchor"].update(change)
            self.reject(d, "quote-invalid")
        d = document()
        d["claims"][0]["citations"][0].update(
            quote_status="verified", quote_verified_at="2026-10-01T00:00:02Z"
        )
        self.reject(d, "quote-invalid")

    def test_claim_evidence_and_meaning_not_interchangeable(self):
        for status in [
            "conflicting",
            "searched-not-found",
            "not-searched",
            "unreachable",
        ]:
            d = document()
            d["claims"][0]["evidence_status"] = status
            self.reject(d, "evidence-inconsistent")
        d = document()
        d["claims"][0]["semantic_status"] = "supported"
        self.reject(d, "semantic-inconsistent")

    def test_many_to_many_and_conflicting_sources(self):
        d = document()
        s = source()
        s["source_id"] = "SRC-002"
        d["sources"].append(s)
        c = d["claims"][0]
        c["evidence_status"] = "conflicting"
        cite = copy.deepcopy(c["citations"][0])
        cite.update(source_id="SRC-002", relation="contradicts")
        c["citations"].append(cite)
        second = copy.deepcopy(c)
        second["claim_id"] = "CLM-002"
        d["claims"].append(second)
        validate_document(d)

    def test_quote_budget_across_history(self):
        d = document()
        d["claims"] = []
        for i in range(6):
            c = claim()
            c["claim_id"] = f"CLM-{i + 1:03}"
            a = c["citations"][0]["anchor"]
            a["quote"] = str(i) * 251
            a["quote_sha256"] = hashlib.sha256(a["quote"].encode()).hexdigest()
            d["claims"].append(c)
        self.reject(d, "quote-budget-exceeded")
        d["claims"][-1]["citations"][0]["anchor"] = copy.deepcopy(
            d["claims"][0]["citations"][0]["anchor"]
        )
        validate_document(d)

    def test_inheritance_has_no_transferred_authority(self):
        d = document()
        d["sources"][0]["inherited_from"] = dict(
            feature="other",
            source_id="SRC-001",
            record_revision=1,
            record_sha256="0" * 64,
        )
        validate_document(d)
        d["sources"][0].update(
            verification_status="hash-verified", verification_at="2026-10-01T00:00:02Z"
        )
        self.reject(d, "inheritance-unresolved")

    def test_history_requires_original_values_not_normalized_equality(self):
        with tempfile.TemporaryDirectory() as td:
            old = Path(td) / "previous.json"
            new = Path(td) / "current.json"
            d = document()
            old.write_text(json.dumps(d))
            new.write_text(json.dumps(d, indent=2))
            validate_file(new, previous=old)
            d["sources"][0]["title"] = "changed"
            new.write_text(json.dumps(d))
            with self.assertRaisesRegex(Invalid, "revision-rewritten"):
                validate_file(new, previous=old)

    def test_location_closure_symlink_duplicate_json_and_bom(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            p = root / "specs/sample/research/records/research-evidence.json"
            p.parent.mkdir(parents=True)
            p.write_text(json.dumps(document()))
            validate_file(p, root)
            extra = p.parent / "other.json"
            extra.write_text("{}")
            with self.assertRaisesRegex(Invalid, "research-dir-unexpected-file"):
                validate_file(p, root)
            extra.unlink()
            link = root / "link.json"
            try:
                link.symlink_to(p)
            except OSError:
                pass
            else:
                with self.assertRaisesRegex(Invalid, "file-unreadable"):
                    validate_file(link)
            for raw in ["\ufeff{}", '{"schema":1,"schema":2}']:
                p.write_text(raw)
                with self.assertRaisesRegex(Invalid, "file-unreadable"):
                    validate_file(p)

    def test_repository_inheritance_pins_canonical_record(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            d = document()
            other = document()
            other["feature"] = "other"
            for name, data in [("sample", d), ("other", other)]:
                p = root / f"specs/{name}/research/records/research-evidence.json"
                p.parent.mkdir(parents=True)
                p.write_text(json.dumps(data))
            d["sources"][0]["inherited_from"] = dict(
                feature="other",
                source_id="SRC-001",
                record_revision=1,
                record_sha256=record_digest(other["sources"][0]),
            )
            p = root / "specs/sample/research/records/research-evidence.json"
            p.write_text(json.dumps(d))
            validate_file(p, root)
            d["sources"][0]["inherited_from"]["record_sha256"] = "0" * 64
            p.write_text(json.dumps(d))
            with self.assertRaisesRegex(Invalid, "inheritance-unresolved"):
                validate_file(p, root)

    def test_cli_errors_hide_secret_arguments(self):
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPTS / "validate-research-evidence.py"),
                "--secret-argument",
                "do-not-print",
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(2, result.returncode)
        self.assertEqual("", result.stdout)
        self.assertNotIn("do-not-print", result.stderr)

    def test_schema_copies_identical(self):
        self.assertEqual(
            (ROOT / "contracts/research-evidence.schema.json").read_bytes(),
            (SCRIPTS.parent / "contracts/research-evidence.schema.json").read_bytes(),
        )


if __name__ == "__main__":
    unittest.main()
