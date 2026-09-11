#!/usr/bin/env python3
"""Emit deterministic WFI-034 scratch-isolation metrics from repository records."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

SCRATCH_LINE = re.compile(r"^- \*\*Scratch Root\*\*: (.+)$", re.MULTILINE)


def normalized_for_comparison(value: str) -> str:
    if re.match(r"^[A-Za-z]:/", value):
        return value.casefold()
    return value


def overlaps(left: str, right: str) -> bool:
    left = normalized_for_comparison(left)
    right = normalized_for_comparison(right)
    return left == right or left.startswith(f"{right}/") or right.startswith(f"{left}/")


def measure(repository: Path, feature: str | None) -> dict[str, object]:
    declared = auditable = shared = 0
    context_root = repository / "reports" / "review-context"
    for invocation in sorted(context_root.rglob("*.json")) if context_root.is_dir() else []:
        try:
            record = json.loads(invocation.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError):
            continue
        if (
            not isinstance(record, dict)
            or record.get("schema") != "review-context-invocation/v2"
            or record.get("stage") != "quality"
        ):
            continue
        if feature is not None and record.get("feature") != feature:
            continue
        evaluator_root = record.get("scratch_root")
        task_id = record.get("task_id")
        record_feature = record.get("feature")
        if not all(isinstance(value, str) and value for value in (evaluator_root, task_id, record_feature)):
            continue
        declared += 1
        implementation_dir = repository / "reports" / "implementation" / record_feature
        reports = sorted(implementation_dir.glob("*.md")) if implementation_dir.is_dir() else []
        current_report = implementation_dir / f"{task_id}.md"
        if current_report not in reports:
            continue

        implementation_roots: list[str] = []
        complete = True
        for report in reports:
            try:
                roots = SCRATCH_LINE.findall(report.read_text(encoding="utf-8"))
            except (OSError, UnicodeDecodeError):
                complete = False
                break
            if len(roots) != 1:
                complete = False
                break
            implementation_roots.append(roots[0])
        if not complete:
            continue
        auditable += 1
        if any(overlaps(evaluator_root, root) for root in implementation_roots):
            shared += 1

    return {
        "metrics": {
            "evaluator_scratch_shared_with_implementation": shared,
            "evaluator_scratch_declared": declared,
            "evaluator_scratch_auditable": auditable,
        }
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("repository", nargs="?", default=".")
    parser.add_argument("--feature")
    args = parser.parse_args()
    result = measure(Path(args.repository).resolve(), args.feature)
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
