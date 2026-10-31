#!/usr/bin/env python3
"""Derive specs/epic-195-a7-compatibility/traceability.json from traceability.md.

traceability.md is the reviewed, frozen human artifact; traceability.json is its
machine-readable companion consumed by
plugins/sdd-quality-loop/scripts/check-traceability.{sh,ps1}. This script derives
the JSON mechanically from the Markdown so the two can never drift by
transcription error, and so the derivation is auditable and re-runnable.

Derivation rules (each cites the traceability.md table it reads):

  tests(REQ) = the REQ's own "Test ID" cell in the top Requirement matrix
             UNION the "Acceptance Tests" cells of every row in the
             "Task Mapping" table whose "Requirements" cell names that REQ.

             The union is needed because the top matrix's Test ID column
             under-lists for REQ-003/REQ-007: TEST-004/019/020/021 appear only
             via their tasks (T-007, T-008). Taking the union keeps the JSON a
             superset of both frozen tables rather than silently dropping rows.

  acs(REQ)   = every AC whose "Test ID" in the "Acceptance Mapping" table is in
               tests(REQ). ACs are therefore never hand-assigned to a REQ.

  evidence(REQ) = committed verification artifacts of the Done tasks that the
               "Task Mapping" table maps to that REQ. Only Done tasks
               contribute; Planned tasks carry no evidence key at all, per
               specs/epic-136-phase3/traceability.json's own precedent
               ("omitting it here keeps the structural check passing without
               fabricating evidence paths that do not exist yet").

REQ-009 is deliberately excluded: its Test ID, Code Target, and Evidence cells
are all "N/A" because it is Epic A1's own requirement, cited here only as the
external upstream contract (traceability.md's REQ-009 row; requirements.md
Non-goals). A link with zero tests fails check-traceability by design, and
inventing a test id for an out-of-scope external requirement would be exactly
the fabrication that gate exists to prevent.

Usage: python3 derive-traceability-json.py [--check]
  (no flag) writes specs/epic-195-a7-compatibility/traceability.json
  --check   re-derives and exits 1 if the file on disk differs
"""
import json
import pathlib
import re
import sys

FEATURE = "epic-195-a7-compatibility"
REPO_ROOT = pathlib.Path(__file__).resolve().parents[4]
SRC = REPO_ROOT / "specs" / FEATURE / "traceability.md"
DST = REPO_ROOT / "specs" / FEATURE / "traceability.json"

EXCLUDED_REQS = {"REQ-009"}

# Tasks whose Status is Done in tasks.md at derivation time, mapped to the
# committed verification artifacts that carry their acceptance/TDD evidence.
# Every path is asserted to exist below; none is invented.
DONE_TASK_EVIDENCE = {
    "T-001": [
        f"specs/{FEATURE}/verification/T-001/red-sh.log",
        f"specs/{FEATURE}/verification/T-001/green-sh.log",
    ],
    "T-002": [
        f"specs/{FEATURE}/verification/T-002/red-bash.log",
        f"specs/{FEATURE}/verification/T-002/green-bash.log",
    ],
    "T-003": [
        f"specs/{FEATURE}/verification/T-003/red-preimplementation.log",
        f"specs/{FEATURE}/verification/T-003/green-sh.log",
    ],
}


def rows(text, header):
    """Yield the data rows of the Markdown table whose header row is exactly
    `header`, as lists of len(header) stripped cells.

    The whole header is matched, not just its first cell: traceability.md
    carries two tables starting with "Acceptance Criterion" (the Deferred /
    Non-Task table and the Acceptance Mapping table) and two starting with
    "Task" (Task Mapping and Deliverables), so a first-cell match would splice
    unrelated tables together.
    """
    out = []
    in_table = False
    matched = 0
    for line in text.split("\n"):
        if not line.startswith("|"):
            in_table = False
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if cells == header:
            in_table = True
            matched += 1
            continue
        if not in_table:
            continue
        if set("".join(cells)) <= {"-", ":"}:  # separator row
            continue
        if len(cells) != len(header):
            raise SystemExit(
                f"derive-traceability-json: table '{header[0]}' row has "
                f"{len(cells)} cells, expected {len(header)}: {line[:90]}"
            )
        out.append(cells)
    if matched != 1:
        raise SystemExit(
            f"derive-traceability-json: expected exactly 1 table with header "
            f"{header}, found {matched}"
        )
    return out


def ids(cell, prefix):
    return re.findall(rf"\b{prefix}-\d+[a-z]?\b", cell)


def main():
    text = SRC.read_text(encoding="utf-8")

    # Table 1: the Requirement matrix (Test ID is column index 6).
    matrix = rows(text, [
        "Requirement", "Investigation", "Layer Spec", "Design", "API/Schema",
        "Code Target", "Test ID", "Test Target", "Evidence", "Status",
    ])
    # Table 2: Task Mapping.
    task_map = rows(text, [
        "Task", "Requirements", "Acceptance Tests", "Planned Verification Evidence",
    ])
    # Table 3: Acceptance Mapping.
    acc_map = rows(text, ["Acceptance Criterion", "Test ID", "Task"])

    if not matrix or not task_map or not acc_map:
        raise SystemExit("derive-traceability-json: a required table is empty")

    ac_to_test = {}
    for ac_cell, test_cell, _task_cell in acc_map:
        ac = ids(ac_cell, "AC")
        test = ids(test_cell, "TEST")
        if len(ac) == 1 and len(test) == 1:
            ac_to_test[ac[0]] = test[0]

    req_tests = {}
    req_order = []
    for row in matrix:
        req = ids(row[0], "REQ")
        if len(req) != 1:
            continue
        req = req[0]
        req_order.append(req)
        req_tests[req] = set(ids(row[6], "TEST"))

    task_reqs = {}
    for task_cell, reqs_cell, tests_cell, _ev in task_map:
        task = ids(task_cell, "T")
        if len(task) != 1:
            continue
        task = task[0]
        task_reqs[task] = set(ids(reqs_cell, "REQ"))
        for req in task_reqs[task]:
            req_tests.setdefault(req, set()).update(ids(tests_cell, "TEST"))

    links = []
    for req in req_order:
        if req in EXCLUDED_REQS:
            continue
        tests = sorted(req_tests.get(req, ()))
        acs = sorted(ac for ac, test in ac_to_test.items() if test in tests)
        if not tests or not acs:
            raise SystemExit(
                f"derive-traceability-json: {req} derived {len(acs)} ac(s) and "
                f"{len(tests)} test(s); a link needs at least one of each"
            )
        link = {"req": req, "acs": acs, "tests": tests}
        evidence = []
        for task in sorted(t for t, reqs in task_reqs.items() if req in reqs):
            evidence.extend(DONE_TASK_EVIDENCE.get(task, []))
        if evidence:
            missing = [p for p in evidence if not (REPO_ROOT / p).is_file()]
            if missing:
                raise SystemExit(
                    f"derive-traceability-json: {req} evidence does not exist: {missing}"
                )
            link["evidence"] = evidence
        links.append(link)

    doc = {
        "feature": FEATURE,
        "generated_by": (
            "Derived mechanically from specs/" + FEATURE + "/traceability.md by "
            "specs/" + FEATURE + "/verification/qg-backfill/derive-traceability-json.py "
            "(re-run with --check to prove the two are still in sync). Authored during "
            "the T-001/T-002/T-003 verification-artifact backfill, because "
            "requirement-traceability is a required check at T-002's high risk tier "
            "(references/risk-gate-matrix.md) and this feature carried no JSON "
            "companion. traceability.md itself is unchanged: this file adds a "
            "machine-readable view, it does not restate or amend the reviewed one. "
            "REQ-009 is excluded by design -- it is Epic A1's own requirement with "
            "N/A test/code/evidence cells, and a fabricated test id would defeat the "
            "gate. Evidence arrays are populated only for REQ rows whose mapped tasks "
            "are Done (T-001, T-002, T-003); Planned rows carry no evidence key, per "
            "specs/epic-136-phase3/traceability.json's precedent."
        ),
        "schema": "REQ -> AC -> TEST -> evidence; validated by scripts/check-traceability.{sh,ps1}",
        "links": links,
    }

    rendered = json.dumps(doc, indent=2, ensure_ascii=False) + "\n"

    if "--check" in sys.argv[1:]:
        current = DST.read_text(encoding="utf-8") if DST.is_file() else ""
        if current != rendered:
            print("derive-traceability-json: traceability.json is STALE "
                  "(re-run without --check to regenerate)", file=sys.stderr)
            return 1
        print(f"derive-traceability-json: traceability.json is in sync with "
              f"traceability.md ({len(links)} link(s)).")
        return 0

    DST.write_text(rendered, encoding="utf-8")
    print(f"derive-traceability-json: wrote {DST.relative_to(REPO_ROOT)} "
          f"({len(links)} link(s)).")
    for link in links:
        print(f"  {link['req']}: {len(link['acs'])} ac, {len(link['tests'])} test, "
              f"{len(link.get('evidence', []))} evidence")
    return 0


if __name__ == "__main__":
    sys.exit(main())
