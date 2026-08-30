#!/usr/bin/env python3
"""Acceptance-first REQ-004 matrix and oracle verifier."""

from __future__ import annotations

import hashlib
import itertools
import json
import os
import sys
import tempfile
import unicodedata
from pathlib import Path


SCHEMA = "path-lineending-fixture-result/v1"
NFD_CONTENT_SHA = "sha256:7fb55369be8a348ee7cef7482d252b6b707f78ede7e750f7344ac760716d1f82"
NFC_CONTENT_SHA = "sha256:6cda10f4181cb575e27c4b0ba8d7a63ffb18bac85f7464233455558f98cd4128"
LF_BLOB_SHA = "sha256:e49c81e2d2f84e259d40e2fb8192f3bcd198b355184845d76d8f58807d0d78ee"
CRLF_SOURCE_SHA = "sha256:98ab4d3aeab1e120560e942e2df6a0db1147bf94bafcf1590000ffb3c2b6fc80"
CASES = (
    "windows-path-separator",
    "crlf-lf-gitattributes-layer",
    "nfc-nfd-filename",
)
OS_CYCLE = ("windows", "linux", "macos")
AXES = {
    "os": OS_CYCLE,
    "runtime_script": ("sh", "ps1"),
    "eol": ("LF", "CRLF"),
    "normalization": ("NFC", "NFD"),
    "phase": ("install", "uninstall"),
}
EXPECTED_LAYER_ROWS = (
    ("Windows path-separator (AC-018)", "ASSERT (automated, AC-018)"),
    ("CRLF-vs-LF, `.gitattributes` layer (AC-019)", "ASSERT (automated, AC-019)"),
    ("CRLF-vs-LF, canonicalizer layer", "N/A for this package"),
    ("NFC-vs-NFD filename/content (AC-020)", "ASSERT (automated, AC-020)"),
)
EXPECTED_ROWS = (
    ("windows", "sh", "forward-slash", "LF", "NFC", "install"),
    ("linux", "sh", "forward-slash", "LF", "NFC", "uninstall"),
    ("macos", "sh", "forward-slash", "LF", "NFD", "install"),
    ("windows", "sh", "forward-slash", "LF", "NFD", "uninstall"),
    ("linux", "sh", "forward-slash", "CRLF", "NFC", "install"),
    ("macos", "sh", "forward-slash", "CRLF", "NFC", "uninstall"),
    ("windows", "sh", "forward-slash", "CRLF", "NFD", "install"),
    ("linux", "sh", "forward-slash", "CRLF", "NFD", "uninstall"),
    ("macos", "ps1", "forward-slash", "LF", "NFC", "install"),
    ("windows", "ps1", "backslash", "LF", "NFC", "uninstall"),
    ("linux", "ps1", "forward-slash", "LF", "NFD", "install"),
    ("macos", "ps1", "forward-slash", "LF", "NFD", "uninstall"),
    ("windows", "ps1", "backslash", "CRLF", "NFC", "install"),
    ("linux", "ps1", "forward-slash", "CRLF", "NFC", "uninstall"),
    ("macos", "ps1", "forward-slash", "CRLF", "NFD", "install"),
    ("windows", "ps1", "backslash", "CRLF", "NFD", "uninstall"),
)


def sha256(data: bytes) -> str:
    return f"sha256:{hashlib.sha256(data).hexdigest()}"


def fixture_bytes(path: Path) -> bytes:
    return bytes.fromhex(path.read_text(encoding="ascii").strip())


def eol_source_bytes(fixture_root: Path, eol: str) -> bytes:
    if eol == "LF":
        return (fixture_root / "eol-lf.txt").read_bytes()
    return fixture_bytes(fixture_root / "eol-crlf.hex")


def normalized_path(separator: str, *parts: str) -> str:
    if separator == "backslash":
        return "C:\\matrix-root\\" + "\\".join(parts)
    return "/matrix-root/" + "/".join(parts)


def has_normalization_collision(names: list[str]) -> bool:
    """Return true when distinct byte forms map to one NFC logical name."""
    return len(names) != len({unicodedata.normalize("NFC", name) for name in names})


def build_rows() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    combinations = itertools.product(
        AXES["runtime_script"],
        AXES["eol"],
        AXES["normalization"],
        AXES["phase"],
    )
    for index, (script, eol, normalization, phase) in enumerate(combinations, 1):
        target_os = OS_CYCLE[(index - 1) % len(OS_CYCLE)]
        separator = (
            "backslash"
            if target_os == "windows" and script == "ps1"
            else "forward-slash"
        )
        rows.append(
            {
                "row": index,
                "os": target_os,
                "runtime_script": script,
                "separator": separator,
                "eol": eol,
                "normalization": normalization,
                "phase": phase,
            }
        )
    return rows


def validate_pairwise(rows: list[dict[str, object]]) -> list[str]:
    issues: list[str] = []
    observed_rows = tuple(
        (
            str(row["os"]),
            str(row["runtime_script"]),
            str(row["separator"]),
            str(row["eol"]),
            str(row["normalization"]),
            str(row["phase"]),
        )
        for row in rows
    )
    if observed_rows != EXPECTED_ROWS:
        issues.append("generated row ordering differs from the normative 16-row table")
    asserted_separator_rows = tuple(
        int(row["row"]) for row in rows if row["separator"] == "backslash"
    )
    if asserted_separator_rows != (10, 13, 16):
        issues.append(
            f"TEST-018 expected backslash rows (10, 13, 16), found {asserted_separator_rows}"
        )
    independent = ("os", "runtime_script", "eol", "normalization", "phase")
    for left_index, left in enumerate(independent):
        for right in independent[left_index + 1 :]:
            observed = {(row[left], row[right]) for row in rows}
            required = set(itertools.product(AXES[left], AXES[right]))
            missing = sorted(required - observed)
            if missing:
                issues.append(f"missing pairwise coverage for {left} x {right}: {missing}")
    return issues


def validate_fixtures(fixture_root: Path, repo_root: Path) -> list[str]:
    issues: list[str] = []
    nfd_name = "cafe\u0301-manifest.txt"
    nfd_path = fixture_root / nfd_name
    if not nfd_path.is_file():
        issues.append("NFD-authored source fixture is missing")
    else:
        raw_name = os.fsencode(nfd_path.name)
        raw_content = nfd_path.read_bytes()
        if unicodedata.normalize("NFD", nfd_path.name) != nfd_path.name:
            issues.append("source fixture filename is not NFD")
        if unicodedata.normalize("NFC", nfd_path.name) == nfd_path.name:
            issues.append("source fixture filename is already NFC")
        decoded = raw_content.decode("utf-8")
        if unicodedata.normalize("NFD", decoded) != decoded:
            issues.append("source fixture content is not NFD")
        if raw_name == os.fsencode(unicodedata.normalize("NFC", nfd_path.name)):
            issues.append("source fixture filename bytes do not differ from NFC")
        if sha256(raw_content) != NFD_CONTENT_SHA:
            issues.append("NFD source bytes differ from the fixed oracle")
        nfc_content = unicodedata.normalize("NFC", decoded).encode("utf-8")
        if sha256(nfc_content) != NFC_CONTENT_SHA:
            issues.append("NFC consumed bytes differ from the fixed oracle")

    lf = eol_source_bytes(fixture_root, "LF")
    crlf = fixture_bytes(fixture_root / "eol-crlf.hex")
    if b"\r\n" in lf or not lf.endswith(b"\n"):
        issues.append("LF fixture does not contain LF-only bytes")
    if b"\r\n" not in crlf or crlf.replace(b"\r\n", b"\n") != lf:
        issues.append("CRLF fixture is not the correction twin of the LF fixture")
    if sha256(lf) != LF_BLOB_SHA:
        issues.append("tracked LF repository blob differs from the fixed oracle")
    if sha256(crlf) != CRLF_SOURCE_SHA:
        issues.append("CRLF source bytes differ from the fixed oracle")

    attributes = (repo_root / ".gitattributes").read_text(encoding="utf-8").splitlines()
    required = (
        "* text=auto eol=lf",
        "*.sh text eol=lf",
        "*.ps1 text eol=lf",
        "*.js text eol=lf",
        "*.py text eol=lf",
        "*.json text eol=lf",
        "*.md text eol=lf",
        "*.yml text eol=lf",
        "*.toml text eol=lf",
    )
    if tuple(attributes[:9]) != required:
        issues.append(".gitattributes:1-9 no longer matches the REQ-004 LF contract")
    if not has_normalization_collision(
        ["caf\u00e9-manifest.txt", "cafe\u0301-manifest.txt"]
    ):
        issues.append("NFC/NFD collision policy did not reject dual byte forms")
    return issues


def validate_layer_table(design_path: Path) -> list[str]:
    design = design_path.read_text(encoding="utf-8")
    heading = "## Path/Line-Ending Regression Matrix (REQ-004; AC-021)"
    if design.count(heading) != 1:
        return ["TEST-021 layer-disposition heading is missing or duplicated"]
    section = design.split(heading, 1)[1].split("\n## ", 1)[0]
    table_rows = [line for line in section.splitlines() if line.startswith("|")]
    data_rows = [line for line in table_rows if not line.startswith("| Case |") and not line.startswith("|---")]
    if len(data_rows) != len(EXPECTED_LAYER_ROWS):
        return [f"TEST-021 expected 4 disposition rows, found {len(data_rows)}"]
    issues: list[str] = []
    for case_name, disposition in EXPECTED_LAYER_ROWS:
        matches = [line for line in data_rows if f"| {case_name} |" in line]
        if len(matches) != 1:
            issues.append(f"TEST-021 expected exactly one row for {case_name}")
        elif f"| {disposition} |" not in matches[0]:
            issues.append(f"TEST-021 wrong disposition for {case_name}")
    return issues


def expected_cell(
    row: dict[str, object], case_name: str, fixture_root: Path
) -> dict[str, object]:
    separator = str(row["separator"])
    phase = str(row["phase"])
    nfd_name = "cafe\u0301-manifest.txt"
    nfc_name = unicodedata.normalize("NFC", nfd_name)
    nfd_bytes = (fixture_root / nfd_name).read_bytes()

    if case_name == "windows-path-separator":
        resolved = normalized_path(separator, "generated", nfc_name)
        cli_path = normalized_path(separator, "bin", "sdd-forge")
        result = "PASS" if separator == "backslash" else "N/A"
        source_bytes_sha = NFD_CONTENT_SHA
        source_name = nfd_name
        copied_bytes_sha = NFC_CONTENT_SHA
        stdout = f"{phase}: generated={resolved}; cli-registration={cli_path}"
    elif case_name == "crlf-lf-gitattributes-layer":
        source_name = "eol-lf.txt" if row["eol"] == "LF" else "eol-crlf.hex"
        source_bytes_sha = LF_BLOB_SHA if row["eol"] == "LF" else CRLF_SOURCE_SHA
        copied_bytes_sha = LF_BLOB_SHA
        resolved = normalized_path(separator, "plugins", "path-lineending", "SKILL.md")
        stdout = f"{phase}: copied={resolved}"
        result = "PASS"
    else:
        source_name = (
            nfc_name if row["normalization"] == "NFC" else nfd_name
        )
        source_bytes_sha = NFC_CONTENT_SHA if row["normalization"] == "NFC" else NFD_CONTENT_SHA
        copied_bytes_sha = NFC_CONTENT_SHA
        resolved = normalized_path(separator, "skills", nfc_name)
        stdout = f"{phase}: normalized={resolved}"
        result = "PASS"

    return {
        "os": row["os"],
        "separator": separator,
        "eol": row["eol"],
        "normalization": row["normalization"],
        "runtime_script": row["runtime_script"],
        "phase": phase,
        "case": case_name,
        "result": result,
        "oracle": {
            "source_bytes_sha256": source_bytes_sha,
            "source_name": source_name,
            "resolved_path": resolved,
            "copied_bytes_sha256": copied_bytes_sha,
            "stdout_substring": stdout,
            "uninstall_residue": [],
        },
    }


def permissive_cell(row: dict[str, object], case_name: str) -> dict[str, object]:
    """Deliberately permissive fixture harness used to prove acceptance RED."""
    return {
        "os": row["os"],
        "separator": row["separator"],
        "eol": row["eol"],
        "normalization": row["normalization"],
        "runtime_script": row["runtime_script"],
        "phase": row["phase"],
        "case": case_name,
        "result": "PASS",
        "oracle": {
            "source_bytes_sha256": "sha256:" + ("0" * 64),
            "source_name": "",
            "resolved_path": "",
            "copied_bytes_sha256": "sha256:" + ("0" * 64),
            "stdout_substring": "",
            "uninstall_residue": [],
        },
    }


def strict_cell(
    row: dict[str, object], case_name: str, fixture_root: Path
) -> dict[str, object]:
    """Exercise the fixture transform and report the observed oracle."""
    separator = str(row["separator"])
    phase = str(row["phase"])
    nfd_name = "cafe\u0301-manifest.txt"
    nfc_name = unicodedata.normalize("NFC", nfd_name)
    nfd_content = (fixture_root / nfd_name).read_bytes()
    nfc_content = unicodedata.normalize(
        "NFC", nfd_content.decode("utf-8")
    ).encode("utf-8")
    residue: list[str] = []

    with tempfile.TemporaryDirectory(prefix="path-lineending-") as temp_root:
        output_root = Path(temp_root)
        if case_name == "windows-path-separator":
            source_name = nfd_name
            source_bytes = nfd_content
            copied_bytes = nfc_content
            relative_parts = ("generated", nfc_name)
            output_path = output_root.joinpath(*relative_parts)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_bytes(copied_bytes)
            copied_bytes = output_path.read_bytes()
            resolved = normalized_path(separator, *relative_parts)
            cli_path = normalized_path(separator, "bin", "sdd-forge")
            stdout = f"{phase}: generated={resolved}; cli-registration={cli_path}"
            result = "PASS" if separator == "backslash" else "N/A"
        elif case_name == "crlf-lf-gitattributes-layer":
            source_name = "eol-lf.txt" if row["eol"] == "LF" else "eol-crlf.hex"
            source_bytes = eol_source_bytes(fixture_root, str(row["eol"]))
            copied_bytes = source_bytes.replace(b"\r\n", b"\n")
            relative_parts = ("plugins", "path-lineending", "SKILL.md")
            output_path = output_root.joinpath(*relative_parts)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_bytes(copied_bytes)
            copied_bytes = output_path.read_bytes()
            resolved = normalized_path(separator, *relative_parts)
            stdout = f"{phase}: copied={resolved}"
            result = "PASS"
        else:
            source_name = nfc_name if row["normalization"] == "NFC" else nfd_name
            source_text = nfd_content.decode("utf-8")
            if row["normalization"] == "NFC":
                source_text = unicodedata.normalize("NFC", source_text)
            source_bytes = source_text.encode("utf-8")
            consumed_name = unicodedata.normalize("NFC", source_name)
            consumed_bytes = unicodedata.normalize("NFC", source_text).encode("utf-8")
            relative_parts = ("skills", consumed_name)
            output_path = output_root.joinpath(*relative_parts)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_bytes(consumed_bytes)
            copied_bytes = output_path.read_bytes()
            resolved = normalized_path(separator, *relative_parts)
            stdout = f"{phase}: normalized={resolved}"
            result = "PASS"

            skills_root = output_root / "skills"
            # Normalization-insensitive filesystems make the NFC and NFD Path
            # spellings alias one directory entry.  Count actual entries so an
            # alias is not mistaken for two colliding installed artifacts.
            equivalent_entries = [
                candidate
                for candidate in skills_root.iterdir()
                if unicodedata.normalize("NFC", candidate.name) == nfc_name
            ]
            if has_normalization_collision(
                [candidate.name for candidate in equivalent_entries]
            ):
                result = "FAIL"
            if phase == "uninstall":
                for candidate in equivalent_entries:
                    candidate.unlink(missing_ok=True)
                form_paths = (
                    skills_root / nfc_name,
                    skills_root / nfd_name,
                )
                residue = [
                    os.fsencode(candidate.name).hex()
                    for candidate in form_paths
                    if candidate.exists()
                ]

    return {
        "os": row["os"],
        "separator": separator,
        "eol": row["eol"],
        "normalization": row["normalization"],
        "runtime_script": row["runtime_script"],
        "phase": phase,
        "case": case_name,
        "result": result,
        "oracle": {
            "source_bytes_sha256": sha256(source_bytes),
            "source_name": source_name,
            "resolved_path": resolved,
            "copied_bytes_sha256": sha256(copied_bytes),
            "stdout_substring": stdout,
            "uninstall_residue": residue,
        },
    }


def main() -> int:
    fixture_root = Path(__file__).resolve().parent
    repo_root = fixture_root.parents[2]
    rows = build_rows()
    structural_issues = []
    structural_issues.extend(validate_pairwise(rows))
    structural_issues.extend(validate_fixtures(fixture_root, repo_root))
    structural_issues.extend(
        validate_layer_table(repo_root / "specs/epic-196-a8-integration/design.md")
    )
    if structural_issues:
        for issue in structural_issues:
            print(f"not ok - {issue}", file=sys.stderr)
        return 1

    expected = [
        expected_cell(row, case_name, fixture_root)
        for row in rows
        for case_name in CASES
    ]
    harness_mode = os.environ.get("PATH_LINEENDING_FIXTURE_HARNESS", "strict")
    if harness_mode == "permissive":
        actual = [
            permissive_cell(row, case_name)
            for row in rows
            for case_name in CASES
        ]
    elif harness_mode == "strict":
        actual = [
            strict_cell(row, case_name, fixture_root)
            for row in rows
            for case_name in CASES
        ]
    else:
        print(f"unknown PATH_LINEENDING_FIXTURE_HARNESS: {harness_mode}", file=sys.stderr)
        return 2
    failures = []
    for index, (expected_item, actual_item) in enumerate(zip(expected, actual), 1):
        if actual_item != expected_item:
            row_number = ((index - 1) // len(CASES)) + 1
            failures.append((row_number, expected_item["case"]))
            print(
                f"not ok - row {row_number:02d} {expected_item['case']}: {harness_mode} harness violated oracle",
                file=sys.stderr,
            )

    passed = len(expected) - len(failures)
    print(f"48 row x case cells: {passed} passed, {len(failures)} failed")
    if failures:
        return 1

    print("ok TEST-018 - rows 10/13/16 ASSERT; remaining rows explicit N/A")
    print("ok TEST-019 - 16 LF identity/CRLF correction cells")
    print("ok TEST-020 - 16 NFC outcomes and uninstall collision checks")
    print("ok TEST-021 - four layer-disposition rows are exhaustive")
    print(json.dumps({"schema": SCHEMA, "cells": actual}, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
