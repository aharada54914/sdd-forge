#!/usr/bin/env python3
"""Validate citation coverage for Epic A8 investigation and prose claims."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

INV_ROW_RE = re.compile(r"^\|\s*(INV-\d{3})\s*\|")
FILE_LINE_RE = re.compile(r"\b[\w./-]+\.[A-Za-z0-9]+:\d+(?:-\d+)?\b")
URL_RE = re.compile(r"https?://\S+")
# Named investigation findings and ADRs are external evidence documents for
# requirements/design prose. Requirement, AC, and open-question identifiers
# are intentionally excluded: citing the claim itself is not evidence for it.
REF_RE = re.compile(r"\b(?:FP-[A-Za-z0-9._-]+|INV-\d{3}|ADR-\d{4})\b")
REPOSITORY_CLAIM_RE = re.compile(
    r"\b(?:the\s+)?(?:repository|worktree|codebase|source\s+tree)\s+"
    r"(?:currently\s+|already\s+)?"
    r"(?:contains?|has|have|runs?|uses?|accepts?|defaults?|supports?|"
    r"documents?|includes?|registers?|installs?|is|are)\b",
    re.IGNORECASE,
)
CONCRETE_ARTIFACT_RE = re.compile(
    r"(?:`?\b[\w./-]+\.(?:sh|ps1|py|md|json|toml|ya?ml)\b`?|"
    r"\b(?:repository|worktree|codebase|source\s+tree)\b)",
    re.IGNORECASE,
)
ARTIFACT_BEHAVIOR_RE = re.compile(
    r"\b(?:currently\s+|today\s+)?(?:contains?|runs?|accepts?|uses?|"
    r"defaults?|supports?|registers?|installs?)\b|\bhas\s+no\s+existing\b",
    re.IGNORECASE,
)
CURRENT_STATE_RE = re.compile(r"\b(?:currently|today)\b", re.IGNORECASE)
BEHAVIOR_VALUE_RE = re.compile(
    r"\b(?:contains?|runs?|accepts?|uses?|defaults?|supports?|registers?|installs?)\s+"
    r"(?:exactly\s+)?(?:an?\s+)?(?:\d+|one|two|three|four|five|six|seven|eight|nine|ten|"
    r"numeric|number|limit)\b",
    re.IGNORECASE,
)
QUANTIFIED_REPOSITORY_FACT_RE = re.compile(
    r"\b(?:exactly\s+|no\s+|\d+\s+|one\s+|two\s+|three\s+)"
    r"(?:active\s+)?(?:scripts?|tests?|files?|hooks?)\b.*"
    r"\b(?:enforce|run|exist|contain|register|support)",
    re.IGNORECASE,
)


def emit_missing(items: list[str]) -> int:
    for item in items:
        print(f"missing: {item}")
    return 1


def has_citation(text: str) -> bool:
    return bool(FILE_LINE_RE.search(text) or URL_RE.search(text) or REF_RE.search(text))


def is_checkable_factual_claim(text: str) -> bool:
    """Recognize concrete, present-state repository behavior claims."""
    for sentence in re.split(r"(?<=[.!?])\s+", text):
        if REPOSITORY_CLAIM_RE.search(sentence):
            return True
        artifact = CONCRETE_ARTIFACT_RE.search(sentence)
        behavior = ARTIFACT_BEHAVIOR_RE.search(sentence)
        concrete_state = CURRENT_STATE_RE.search(sentence) or BEHAVIOR_VALUE_RE.search(sentence)
        no_existing = re.search(r"\bhas\s+no\s+existing\b", sentence, re.IGNORECASE)
        if (
            artifact
            and behavior
            and artifact.start() <= behavior.start()
            and (concrete_state or no_existing)
        ):
            return True
        if QUANTIFIED_REPOSITORY_FACT_RE.search(sentence):
            return True
    return False


def parse_markdown_table(lines: list[str]) -> list[list[str]]:
    rows: list[list[str]] = []
    for line in lines:
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        # Evidence commands commonly contain escaped grep alternations (`\|`).
        # Split only on real Markdown cell boundaries so those citations remain
        # attached to their INV row.
        cells = [
            cell.replace(r"\|", "|").strip()
            for cell in re.split(r"(?<!\\)\|", stripped.strip("|"))
        ]
        if len(cells) >= 2:
            rows.append(cells)
    return rows


def check_investigation(path: Path) -> list[str]:
    errors: list[str] = []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        return [f"{path}: {exc}"]
    for cells in parse_markdown_table(lines):
        if not cells or not INV_ROW_RE.match("|" + cells[0] + "|"):
            continue
        if len(cells) < 3:
            errors.append(f"{cells[0]} evidence")
            continue
        evidence = cells[-1]
        if not has_citation(evidence):
            errors.append(f"{cells[0]} evidence")
    return errors


def collect_prose_blocks(lines: list[str]) -> list[str]:
    blocks: list[str] = []
    current: list[str] = []
    in_code = False
    for line in lines:
        stripped = line.rstrip()
        if stripped.startswith("```"):
            if current:
                blocks.append(" ".join(current))
                current = []
            in_code = not in_code
            continue
        if in_code:
            continue
        if not stripped or stripped.startswith("|"):
            if current:
                blocks.append(" ".join(current))
                current = []
            continue
        if stripped.startswith("#"):
            if current:
                blocks.append(" ".join(current))
                current = []
            continue
        current.append(stripped)
    if current:
        blocks.append(" ".join(current))
    return blocks


def check_claim_paragraphs(path: Path) -> list[str]:
    errors: list[str] = []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        return [f"{path}: {exc}"]
    for block in collect_prose_blocks(lines):
        normalized = " ".join(block.split())
        if not normalized or has_citation(normalized):
            continue
        if not is_checkable_factual_claim(normalized):
            continue
        errors.append(path.name)
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="check-a8-citation-compliance.py")
    parser.add_argument("investigation", help="Path to specs/epic-196-a8-integration/investigation.md")
    parser.add_argument("requirements", help="Path to specs/epic-196-a8-integration/requirements.md")
    parser.add_argument("design", help="Path to specs/epic-196-a8-integration/design.md")
    args = parser.parse_args(argv)

    paths = [Path(args.investigation), Path(args.requirements), Path(args.design)]
    errors: list[str] = []
    errors.extend(check_investigation(paths[0]))
    errors.extend(check_claim_paragraphs(paths[0]))
    errors.extend(check_claim_paragraphs(paths[1]))
    errors.extend(check_claim_paragraphs(paths[2]))

    if errors:
        return emit_missing(sorted(dict.fromkeys(errors)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
