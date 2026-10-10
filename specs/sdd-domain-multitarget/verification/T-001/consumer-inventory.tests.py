#!/usr/bin/env python3
"""T-001 stdlib regression test for the machine-readable consumer inventory.

Covers TEST-001a through TEST-001i (acceptance-tests.md AC-001): every named
consumer group must have exactly one classification (KEEP/PARAMETERIZE/
EXTRACT/DEFER), a rationale, a repository-relative source mapping whose cited
lines still contain the expected evidence keyword, and a re-verification
command. Missing or duplicate classification, and stale source evidence,
must fail.

Usage:
    python3 consumer-inventory.tests.py --repo-root REPO [--inventory FILE]

--repo-root is required and is used to resolve every source path in the
inventory. --inventory optionally points at an alternate inventory file (for
validating a negative/mutated fixture); it defaults to the
consumer-inventory.json shipped alongside this script.

This module uses only the Python 3 standard library.
"""
import argparse
import copy
import json
import os
import sys
import unittest

DISPOSITIONS = {"KEEP", "PARAMETERIZE", "EXTRACT", "DEFER"}

ALL_TEST_IDS = {"TEST-001" + c for c in "abcdefghi"}

# One entry per consumer scope named in requirements.md REQ-001 / design.md
# Consumer Disposition, keyed by the id the inventory must use for it.
REQUIRED_ENTRIES = {
    "bootstrap-question-bank": ("TEST-001a", "KEEP"),
    "bootstrap-seven-layer-output": ("TEST-001a", "PARAMETERIZE"),
    "layer-template-fixed-rows": ("TEST-001b", "PARAMETERIZE"),
    "risk-tier-verifier-contract": ("TEST-001c", "PARAMETERIZE"),
    "ui-design-loop": ("TEST-001d", "EXTRACT"),
    "endpoint-contract-checklist": ("TEST-001e", "PARAMETERIZE"),
    "ci-mcp-package": ("TEST-001f", "KEEP"),
    "provider-state-boundary": ("TEST-001g", "DEFER"),
    "gate-stage-boundary": ("TEST-001g", "DEFER"),
    "host-adapters": ("TEST-001h", "KEEP"),
    "facet-native-migration": ("TEST-001h", "DEFER"),
    "compile-checks-noncode": ("TEST-001i", "PARAMETERIZE"),
}


def load_inventory(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def _validate_source(entry_id, src, repo_root):
    """Validates one source mapping; returns a list of failure strings."""
    if not isinstance(src, dict):
        return [f"entry '{entry_id}' has a non-dict source"]

    rel_path = src.get("path")
    line_start = src.get("line_start")
    line_end = src.get("line_end")
    keyword = src.get("keyword")

    if (
        not isinstance(rel_path, str)
        or not rel_path
        or rel_path.startswith("/")
        or ".." in rel_path.split("/")
    ):
        return [f"entry '{entry_id}' has an invalid repository-relative source path: {rel_path!r}"]

    abs_path = os.path.join(repo_root, rel_path)
    if not os.path.isfile(abs_path):
        return [f"entry '{entry_id}' source file does not exist under repo-root: {rel_path}"]

    if (
        not isinstance(line_start, int)
        or isinstance(line_start, bool)
        or not isinstance(line_end, int)
        or isinstance(line_end, bool)
        or line_start < 1
        or line_end < line_start
    ):
        return [f"entry '{entry_id}' has an invalid line range for {rel_path}"]

    with open(abs_path, "r", encoding="utf-8", errors="replace") as fh:
        lines = fh.readlines()

    if line_end > len(lines):
        return [
            f"entry '{entry_id}' line range {line_start}-{line_end} exceeds current file "
            f"length ({len(lines)}) for {rel_path} (stale source evidence)"
        ]

    window = "".join(lines[line_start - 1 : line_end])
    if not isinstance(keyword, str) or not keyword or keyword not in window:
        return [
            f"entry '{entry_id}' keyword {keyword!r} not found in {rel_path}:"
            f"{line_start}-{line_end} (stale source evidence)"
        ]

    return []


def validate_inventory(inventory, repo_root):
    """Returns a list of failure strings; an empty list means the inventory is valid.

    Fails for: a missing 'entries' list, any entry missing required fields, an
    invalid disposition, a duplicate entry id, a source file/line/keyword that
    no longer matches the current on-disk file (stale evidence), and any
    required consumer group that is absent, misclassified, or not mapped to
    its expected TEST-001 id.
    """
    failures = []
    entries = inventory.get("entries")
    if not isinstance(entries, list):
        return ["'entries' is missing or is not a list"]

    seen_ids = {}
    seen_consumers = set()
    for entry in entries:
        if not isinstance(entry, dict):
            failures.append("a non-dict entry is present in 'entries'")
            continue

        entry_id = entry.get("id")
        if not entry_id or not isinstance(entry_id, str):
            failures.append("an entry is missing a non-empty string 'id'")
            continue
        if entry_id in seen_ids:
            failures.append(f"duplicate entry id '{entry_id}'")
            continue
        seen_ids[entry_id] = entry

        consumer = entry.get("consumer")
        if not isinstance(consumer, str) or not consumer.strip():
            failures.append(f"entry '{entry_id}' is missing a non-empty string 'consumer'")
        elif consumer in seen_consumers:
            failures.append(f"entry '{entry_id}' has duplicate consumer classification '{consumer}'")
        else:
            seen_consumers.add(consumer)

        disposition = entry.get("disposition")
        if disposition not in DISPOSITIONS:
            failures.append(f"entry '{entry_id}' has invalid disposition {disposition!r}")

        test_ids = entry.get("test_ids")
        if (
            not isinstance(test_ids, list)
            or not test_ids
            or any(t not in ALL_TEST_IDS for t in test_ids)
        ):
            failures.append(f"entry '{entry_id}' has invalid or missing 'test_ids'")

        if not entry.get("rationale"):
            failures.append(f"entry '{entry_id}' is missing 'rationale'")

        if not entry.get("reverify_command"):
            failures.append(f"entry '{entry_id}' is missing 'reverify_command'")

        sources = entry.get("source")
        if not isinstance(sources, list) or not sources:
            failures.append(f"entry '{entry_id}' has no source mapping")
            continue

        for src in sources:
            failures.extend(_validate_source(entry_id, src, repo_root))

    for required_id, (expected_test_id, expected_disposition) in REQUIRED_ENTRIES.items():
        entry = seen_ids.get(required_id)
        if entry is None:
            failures.append(f"missing required consumer entry '{required_id}'")
            continue
        if expected_test_id not in (entry.get("test_ids") or []):
            failures.append(
                f"entry '{required_id}' is not mapped to its expected test id {expected_test_id}"
            )
        if entry.get("disposition") != expected_disposition:
            failures.append(
                f"entry '{required_id}' disposition {entry.get('disposition')!r} "
                f"!= expected {expected_disposition!r} (missing or duplicate classification)"
            )

    return failures


class ConsumerInventoryTests(unittest.TestCase):
    """One test method per TEST-001a..i acceptance row, plus negative mutation checks."""

    repo_root = None
    inventory = None

    def _relevant_failures(self, entry_ids):
        failures = validate_inventory(self.inventory, self.repo_root)
        return [f for f in failures if any(f"'{eid}'" in f for eid in entry_ids)]

    def test_TEST_001a_interviewer_questions_and_layer_output(self):
        relevant = self._relevant_failures(
            ["bootstrap-question-bank", "bootstrap-seven-layer-output"]
        )
        self.assertEqual(relevant, [], f"TEST-001a failures: {relevant}")

    def test_TEST_001b_fixed_layer_template(self):
        relevant = self._relevant_failures(["layer-template-fixed-rows"])
        self.assertEqual(relevant, [], f"TEST-001b failures: {relevant}")

    def test_TEST_001c_risk_tier_verifier_contract(self):
        relevant = self._relevant_failures(["risk-tier-verifier-contract"])
        self.assertEqual(relevant, [], f"TEST-001c failures: {relevant}")

    def test_TEST_001d_ui_design_loop(self):
        relevant = self._relevant_failures(["ui-design-loop"])
        self.assertEqual(relevant, [], f"TEST-001d failures: {relevant}")

    def test_TEST_001e_endpoint_contract_checklist(self):
        relevant = self._relevant_failures(["endpoint-contract-checklist"])
        self.assertEqual(relevant, [], f"TEST-001e failures: {relevant}")

    def test_TEST_001f_ci_mcp_package(self):
        relevant = self._relevant_failures(["ci-mcp-package"])
        self.assertEqual(relevant, [], f"TEST-001f failures: {relevant}")

    def test_TEST_001g_provider_state_and_gate_stage_boundaries(self):
        relevant = self._relevant_failures(["provider-state-boundary", "gate-stage-boundary"])
        self.assertEqual(relevant, [], f"TEST-001g failures: {relevant}")

    def test_TEST_001h_host_adapters_and_artifact_layout_migration(self):
        relevant = self._relevant_failures(["host-adapters", "facet-native-migration"])
        self.assertEqual(relevant, [], f"TEST-001h failures: {relevant}")

    def test_TEST_001i_compile_build_lint_checks_on_noncode_targets(self):
        relevant = self._relevant_failures(["compile-checks-noncode"])
        self.assertEqual(relevant, [], f"TEST-001i failures: {relevant}")

    def test_full_inventory_has_no_outstanding_failures(self):
        failures = validate_inventory(self.inventory, self.repo_root)
        self.assertEqual(failures, [], f"unexpected inventory failures: {failures}")

    # --- negative mutation checks -------------------------------------------------

    def test_missing_required_entry_is_rejected(self):
        for entry_id, (test_id, _) in REQUIRED_ENTRIES.items():
            with self.subTest(test_id=test_id, entry_id=entry_id):
                mutated = copy.deepcopy(self.inventory)
                mutated["entries"] = [e for e in mutated["entries"] if e.get("id") != entry_id]
                failures = validate_inventory(mutated, self.repo_root)
                self.assertIn(f"missing required consumer entry '{entry_id}'", failures)

    def test_duplicate_entry_id_is_rejected(self):
        for entry_id, (test_id, _) in REQUIRED_ENTRIES.items():
            with self.subTest(test_id=test_id, entry_id=entry_id):
                mutated = copy.deepcopy(self.inventory)
                entry = next(e for e in mutated["entries"] if e.get("id") == entry_id)
                mutated["entries"].append(copy.deepcopy(entry))
                failures = validate_inventory(mutated, self.repo_root)
                self.assertIn(f"duplicate entry id '{entry_id}'", failures)

    def test_invalid_disposition_is_rejected(self):
        mutated = copy.deepcopy(self.inventory)
        mutated["entries"][0]["disposition"] = "MAYBE"
        failures = validate_inventory(mutated, self.repo_root)
        self.assertTrue(
            any("invalid disposition" in f for f in failures),
            f"expected an invalid-disposition failure, got: {failures}",
        )

    def test_same_consumer_under_another_id_is_rejected(self):
        for entry_id, (test_id, disposition) in REQUIRED_ENTRIES.items():
            for alternate in sorted(DISPOSITIONS - {disposition}):
                with self.subTest(test_id=test_id, entry_id=entry_id, alternate=alternate):
                    mutated = copy.deepcopy(self.inventory)
                    entry = copy.deepcopy(next(e for e in mutated["entries"] if e.get("id") == entry_id))
                    entry["id"] += "-alias"
                    entry["disposition"] = alternate
                    mutated["entries"].append(entry)
                    failures = validate_inventory(mutated, self.repo_root)
                    self.assertTrue(any("duplicate consumer classification" in f for f in failures))

    def test_stale_source_keyword_is_rejected(self):
        mutated = copy.deepcopy(self.inventory)
        for entry in mutated["entries"]:
            if entry.get("id") == "ci-mcp-package":
                entry["source"][0]["keyword"] = "this keyword is not present in those lines"
        failures = validate_inventory(mutated, self.repo_root)
        self.assertTrue(
            any("stale source evidence" in f for f in failures),
            f"expected a stale-evidence failure, got: {failures}",
        )

    def test_out_of_range_line_end_is_rejected(self):
        mutated = copy.deepcopy(self.inventory)
        for entry in mutated["entries"]:
            if entry.get("id") == "ci-mcp-package":
                entry["source"][0]["line_end"] = 10_000_000
        failures = validate_inventory(mutated, self.repo_root)
        self.assertTrue(
            any("exceeds current file" in f for f in failures),
            f"expected an out-of-range failure, got: {failures}",
        )

    def test_missing_source_file_is_rejected(self):
        mutated = copy.deepcopy(self.inventory)
        for entry in mutated["entries"]:
            if entry.get("id") == "ci-mcp-package":
                entry["source"][0]["path"] = "mcp/ci-mcp/src/does-not-exist.ts"
        failures = validate_inventory(mutated, self.repo_root)
        self.assertTrue(
            any("does not exist under repo-root" in f for f in failures),
            f"expected a missing-file failure, got: {failures}",
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        required=True,
        help="repository root used to resolve every source path in the inventory",
    )
    parser.add_argument(
        "--inventory",
        default=None,
        help=(
            "path to a consumer-inventory.json to validate (default: the "
            "consumer-inventory.json shipped alongside this script); use this "
            "to validate an alternate/mutated fixture"
        ),
    )
    args, remaining = parser.parse_known_args()

    inventory_path = args.inventory or os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "consumer-inventory.json"
    )

    ConsumerInventoryTests.repo_root = os.path.abspath(args.repo_root)
    ConsumerInventoryTests.inventory = load_inventory(inventory_path)

    unittest.main(argv=[sys.argv[0]] + remaining)


if __name__ == "__main__":
    main()
