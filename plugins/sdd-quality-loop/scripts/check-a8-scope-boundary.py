#!/usr/bin/env python3
"""Validate that Epic A8 requirements stay within the declared scope."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

FOREIGN_EPIC_RE = re.compile(
    r"\bEpic\s+A(?!8\b)\d+\b|\bepic-(?!196-a8-integration\b)\d+-[a-z0-9-]+\b",
    re.IGNORECASE,
)
IMPLEMENTATION_VERB_RE = re.compile(
    r"\b(?:build|built|building|create|created|creating|add|added|adding|"
    r"implement|implemented|implementing|ship|shipped|shipping|write|writing|"
    r"produce|producing|own|owning|commit|committed|commitment|new)\b",
    re.IGNORECASE,
)
PAIR_RE = re.compile(r"\.sh\b.*\.ps1\b|\.ps1\b.*\.sh\b", re.IGNORECASE | re.DOTALL)
PLUGIN_CONFIG_RE = re.compile(
    r"\b(?:plugin_hooks|hook config|hooks\.json|claude-hooks\.json|copilot-hooks\.json)\b|"
    r"(?:plugins?/)?[\w./-]*hooks?[\w./-]*\.(?:json|toml|ya?ml)\b",
    re.IGNORECASE,
)
ENV_TEST_RE = re.compile(
    r"\b(?:environment-specific|platform-specific|windows-specific|macos-specific|linux-specific)\s+test\b|"
    r"\b[\w./-]*(?:windows|linux|macos)[\w./-]*\.tests?\.(?:sh|ps1)\b",
    re.IGNORECASE,
)


def emit_missing(items: list[str]) -> int:
    for item in items:
        print(f"missing: {item}")
    return 1


def gather_ac_text(lines: list[str]) -> str:
    """Return prose blocks from the AC section without merging paragraphs."""
    blocks: list[str] = []
    current: list[str] = []
    in_code = False
    in_acceptance_criteria = False
    for line in lines:
        stripped = line.rstrip()
        if stripped == "## Acceptance Criteria":
            in_acceptance_criteria = True
            continue
        if in_acceptance_criteria and stripped.startswith("## "):
            break
        if not in_acceptance_criteria:
            continue
        fence = stripped.startswith("```")
        if fence:
            if current:
                blocks.append(" ".join(current))
                current = []
            in_code = not in_code
            continue
        if in_code:
            continue
        if re.match(r"^- AC-\d{3}:", stripped):
            if current:
                blocks.append(" ".join(current))
                current = []
        if not stripped or stripped.startswith("|"):
            if current:
                blocks.append(" ".join(current))
                current = []
            continue
        current.append(stripped)
    if current:
        blocks.append(" ".join(current))
    return "\n\n".join(blocks)


def find_scope_violations(text: str) -> list[str]:
    errors: list[str] = []
    for paragraph in re.split(r"\n{2,}", text):
        normalized = " ".join(paragraph.split())
        if not normalized:
            continue
        if not FOREIGN_EPIC_RE.search(normalized):
            continue
        if PAIR_RE.search(normalized) and IMPLEMENTATION_VERB_RE.search(normalized):
            errors.append("foreign-Epic .sh/.ps1 pair")
        if PLUGIN_CONFIG_RE.search(normalized) and IMPLEMENTATION_VERB_RE.search(normalized):
            errors.append("plugin hook config")
        if ENV_TEST_RE.search(normalized) and IMPLEMENTATION_VERB_RE.search(normalized):
            errors.append("environment-specific test")
    return errors


def acceptance_blocks(lines: list[str]) -> list[str]:
    """Return every AC-001..AC-030 block from the requirements."""
    text = gather_ac_text(lines)
    blocks: list[str] = []
    for paragraph in re.split(r"\n{2,}", text):
        match = re.match(r"\s*- AC-(\d{3}):", paragraph)
        if match and 1 <= int(match.group(1)) <= 30:
            blocks.append(paragraph)
    return blocks


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="check-a8-scope-boundary.py")
    parser.add_argument("requirements", help="Path to specs/epic-196-a8-integration/requirements.md")
    args = parser.parse_args(argv)

    path = Path(args.requirements)
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        print(f"missing: {path}: {exc}", file=sys.stderr)
        return 1

    blocks = acceptance_blocks(lines)
    if len(blocks) != 30:
        return emit_missing(["requirements Acceptance Criteria section"])
    errors = find_scope_violations("\n\n".join(blocks))
    if errors:
        return emit_missing(sorted(dict.fromkeys(errors)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
