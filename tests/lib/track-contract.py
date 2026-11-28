#!/usr/bin/env python3
"""Resolve one ship CLI cell from a live product contract (Q09, T-010 2026-11-28).

Shared by compatibility-byte-identical.tests.{sh,ps1} so both runtimes apply
one rule. Usage: track-contract.py <document> <fixture> <flag>; prints the
resolution or exits non-zero with a diagnostic.
"""
from pathlib import Path
import re
import sys

document = Path(sys.argv[1])
fixture = Path(sys.argv[2])
flag = sys.argv[3]
if not document.is_file():
    raise SystemExit(f"missing live product contract: {document}")
text = document.read_text(encoding="utf-8")
agents = fixture / "AGENTS.md"
marker = "present" if agents.is_file() and "spec_profile: lite" in agents.read_text(encoding="utf-8").splitlines() else "absent"
if document.name == "PLUGIN-CONTRACTS.md":
    block = re.search(r"<!-- sdd:track-selection-contract v2 -->(.*?)<!-- /sdd:track-selection-contract -->", text, re.S)
    if block is None:
        raise SystemExit(f"missing v2 track-selection contract: {document}")
    cells = {}
    for row in re.finditer(r"(?m)^\| (none|`--full`|`--lite`) \| (present|absent) \| `([A-Z_]+)` \|$", block.group(1)):
        cells[(row.group(1).strip("`"), row.group(2))] = row.group(3)
    if len(cells) != 6:
        raise SystemExit(f"v2 track-selection contract must list exactly six cells: {document}")
    print(cells[(flag, marker)])
else:
    alias = "- `--lite` / `--full` *(互換エイリアス)*: 停止せず単一の標準フロー（各タスクの `Risk:` に従う）で実行する。"
    if alias not in text.splitlines():
        raise SystemExit(f"ship skill no longer states the alias rule: {document}")
    if re.search(r"spec_profile|(?<![A-Za-z])(FULL|LITE)(?![A-Za-z])", text):
        raise SystemExit(f"ship skill still resolves a track from a flag or marker: {document}")
    print("STANDARD_BY_RISK")
