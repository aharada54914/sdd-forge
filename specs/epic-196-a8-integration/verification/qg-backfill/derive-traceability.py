#!/usr/bin/env python3
"""Derive epic-196's traceability.json mechanically from its traceability.md.

Mirrors the schema epic-195's traceability.json uses:
  {feature, generated_by, schema, links:[{req, acs[], tests[], evidence[]}]}

Rules:
- REQ/AC/TEST ids are extracted from the REQ table rows in traceability.md;
  nothing is invented here.
- evidence is restricted to files that actually exist on disk under
  specs/<feature>/verification/, resolved from the task ids the same row
  names (T-NNN). A non-existent path is never emitted.
"""
import json
import re
from pathlib import Path

FEATURE = "epic-196-a8-integration"
ROOT = Path("/Users/jrmag/Projects/active/sdd-forge-wt-epic-196")
SPEC = ROOT / "specs" / FEATURE
MD = SPEC / "traceability.md"
OUT = SPEC / "traceability.json"

text = MD.read_text(encoding="utf-8")

# AC -> REQ (and AC -> TEST) is authoritatively mapped by acceptance-tests.md's
# own table rows: | AC-NNN | REQ-NNN | TEST-NNN | ... . traceability.md's REQ
# rows carry TEST ids but no AC column, so ACs are taken from here, never guessed.
AT = SPEC / "acceptance-tests.md"
req_to_acs: dict[str, set[str]] = {}
ac_to_tests: dict[str, set[str]] = {}
for row in AT.read_text(encoding="utf-8").splitlines():
    m = re.match(r"^\|\s*(AC-\d{3})\s*\|\s*([^|]*)\|\s*([^|]*)\|", row)
    if not m:
        continue
    ac, req_cell, test_cell = m.group(1), m.group(2), m.group(3)
    for r in re.findall(r"REQ-\d{3}", req_cell):
        req_to_acs.setdefault(r, set()).add(ac)
    ac_to_tests[ac] = set(re.findall(r"TEST-\d{3}", test_cell))

links = []
for line in text.splitlines():
    if not re.match(r"^\|\s*REQ-\d{3}\s*\|", line):
        continue
    req = re.match(r"^\|\s*(REQ-\d{3})\s*\|", line).group(1)
    acs = sorted(req_to_acs.get(req, set()))
    tests = sorted(set(re.findall(r"TEST-\d{3}", line)) |
                   {t for a in acs for t in ac_to_tests.get(a, set())})
    tasks = sorted(set(re.findall(r"T-\d{3}", line)))

    evidence = []
    for t in tasks:
        d = SPEC / "verification" / t
        if d.is_dir():
            for f in sorted(d.iterdir()):
                if f.is_file() and f.suffix in (".log", ".json"):
                    evidence.append(f"specs/{FEATURE}/verification/{t}/{f.name}")
    links.append({"req": req, "acs": acs, "tests": tests, "evidence": evidence})

doc = {
    "feature": FEATURE,
    "generated_by": (
        f"Derived mechanically from specs/{FEATURE}/traceability.md by "
        "scratchpad/derive-e196-traceability.py (RT-20260831-005); evidence "
        "paths restricted to files present on disk at derivation time."
    ),
    "schema": "REQ -> AC -> TEST -> evidence; validated by scripts/check-traceability.{sh,ps1}",
    "links": links,
}

OUT.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"wrote {OUT}")
for l in links:
    print(f"  {l['req']}: {len(l['acs'])} ACs, {len(l['tests'])} TESTs, {len(l['evidence'])} evidence files")
