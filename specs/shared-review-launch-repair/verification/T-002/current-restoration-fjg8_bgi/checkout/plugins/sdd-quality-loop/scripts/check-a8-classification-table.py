#!/usr/bin/env python3
"""Validate the Epic A8 automated/manual classification table."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

EXPECTED_ACS = {f"AC-{index:03d}" for index in range(1, 25)} | {"AC-028"}
ALLOWED_CLASSIFICATIONS = {
    "automated",
    "automated-pending-confirmation",
    "manual-required",
}
TABLE_HEADER = "## Automated / Manual Classification Table (REQ-006; AC-025)"
ROW_AC_RE = re.compile(r"AC-(\d{3})(?:[–-](?:AC-)?(\d{3}))?")


def emit_missing(items: list[str]) -> int:
    for item in items:
        print(f"missing: {item}")
    return 1


def expand_acs(cell: str) -> list[str]:
    acs: list[str] = []
    for match in ROW_AC_RE.finditer(cell):
        start = int(match.group(1))
        end = int(match.group(2) or match.group(1))
        if end < start:
            return []
        acs.extend(f"AC-{value:03d}" for value in range(start, end + 1))
    return acs


def parse_table(lines: list[str]) -> tuple[dict[str, str], list[str]]:
    header_indexes = [
        index for index, line in enumerate(lines) if line.strip() == TABLE_HEADER
    ]
    if len(header_indexes) != 1:
        return {}, ["single classification table header"]
    row_start = header_indexes[0] + 1

    row_end = len(lines)
    for index in range(row_start, len(lines)):
        if lines[index].startswith("## "):
            row_end = index
            break

    by_ac: dict[str, str] = {}
    errors: list[str] = []
    for raw in lines[row_start:row_end]:
        line = raw.strip()
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) != 4:
            errors.append("well-formed four-column classification row")
            continue
        if cells[0] in {"Check (AC)", "---"}:
            continue
        acs = expand_acs(cells[0])
        classification = cells[1].strip().strip("`")
        if not acs:
            errors.append(f"{cells[0]} row")
            continue
        if "AC-028" in acs and len(acs) != 1:
            errors.append("AC-028 separate row")
        if classification not in ALLOWED_CLASSIFICATIONS:
            for ac in acs:
                errors.append(f"{ac} classification")
            continue
        for ac in acs:
            if ac in by_ac:
                errors.append(f"{ac} duplicate")
            by_ac[ac] = classification

    for ac in sorted(EXPECTED_ACS):
        if ac not in by_ac:
            errors.append(ac)

    extras = sorted(set(by_ac) - EXPECTED_ACS)
    errors.extend(extras)
    return by_ac, errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="check-a8-classification-table.py")
    parser.add_argument("design", help="Path to specs/epic-196-a8-integration/design.md")
    args = parser.parse_args(argv)

    design_path = Path(args.design)
    try:
        lines = design_path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        print(f"missing: {design_path}: {exc}", file=sys.stderr)
        return 1

    _, errors = parse_table(lines)
    if errors:
        return emit_missing(sorted(dict.fromkeys(errors)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
