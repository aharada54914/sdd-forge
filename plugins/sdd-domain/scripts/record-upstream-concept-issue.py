#!/usr/bin/env python3
"""Record an upstream concept finding and bound automatic reopening per attempt."""
import argparse
import json
import os
from pathlib import Path
import re
import sys
import tempfile


def record(root, stage, feature, attempt, concept, evidence):
    if not re.fullmatch(r"CONCEPT-[A-Z][A-Z0-9-]*", concept):
        raise ValueError("concept must be a concept identifier")
    if not evidence.strip():
        raise ValueError("evidence must identify the finding and affected record")
    if stage != "domain" and (not feature or not re.fullmatch(r"[a-z0-9][a-z0-9-]*", feature)):
        raise ValueError("a downstream review requires its feature slug")
    feature = "sdd-domain-model" if stage == "domain" else feature
    root = root.resolve(strict=True)
    directory = root
    parts = ["reports", f"{stage}-review"]
    if stage != "domain":
        parts.append(feature)
    parts.append(f"attempt-{attempt}")
    for part in parts:
        directory = directory / part
        if directory.is_symlink():
            raise ValueError("review evidence directory must not be a symlink")
        if not directory.is_dir():
            raise ValueError("an existing review attempt is required")
    prechecks = list(directory.glob("round-*/precheck-result.json"))
    valid_attempt = False
    for precheck in prechecks:
        if precheck.is_symlink() or precheck.parent.is_symlink():
            raise ValueError("review precheck must not be a symlink")
        data = json.loads(precheck.read_text(encoding="utf-8"))
        if (isinstance(data, dict) and data.get("schema") == f"{stage}-review-precheck/v1"
                and data.get("stage", stage) == stage and type(data.get("attempt")) is int
                and data["attempt"] == attempt and (stage == "domain" or data.get("feature") == feature)):
            valid_attempt = True
    if not valid_attempt:
        raise ValueError("a matching persisted review precheck is required")
    path = directory / "upstream-concept-issues.json"
    lock = directory / ".upstream-concept-issues.lock"
    if path.is_symlink():
        raise ValueError("upstream issue record must not be a symlink")
    with lock.open("x", encoding="utf-8"):
        pass
    try:
        state = {"schema": "upstream-concept-issues/v1", "stage": stage,
                 "feature": feature, "attempt": attempt, "issues": []}
        if path.exists():
            state = json.loads(path.read_text(encoding="utf-8"))
            if (not isinstance(state, dict)
                    or state.get("schema") != "upstream-concept-issues/v1"
                    or state.get("stage") != stage or state.get("feature") != feature
                    or type(state.get("attempt")) is not int or state.get("attempt") != attempt
                    or not isinstance(state.get("issues"), list)):
                raise ValueError("invalid upstream issue record")
        counts = {}
        for issue in state["issues"]:
            if (not isinstance(issue, dict)
                    or not isinstance(issue.get("concept_id"), str)
                    or not re.fullmatch(r"CONCEPT-[A-Z][A-Z0-9-]*", issue["concept_id"])
                    or not isinstance(issue.get("evidence"), str) or not issue["evidence"].strip()):
                raise ValueError("invalid upstream issue entry")
            key = issue["concept_id"]
            counts[key] = counts.get(key, 0) + 1
            expected = "reopen" if counts[key] == 1 else "requires_human_decision"
            if type(issue.get("occurrence")) is not int or issue.get("occurrence") != counts[key] or issue.get("action") != expected:
                raise ValueError("inconsistent upstream issue history")
        count = counts.get(concept, 0) + 1
        entry = {"concept_id": concept, "evidence": evidence, "occurrence": count,
                 "action": "reopen" if count == 1 else "requires_human_decision"}
        state["issues"].append(entry)
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=directory,
                                             delete=False) as output:
                temporary = Path(output.name)
                json.dump(state, output, indent=2, ensure_ascii=False)
                output.write("\n")
                output.flush()
                os.fsync(output.fileno())
            temporary.replace(path)
        finally:
            if temporary is not None and temporary.exists():
                temporary.unlink()
        return {"schema": "upstream-concept-decision/v1", "stage": stage,
                "feature": feature, "attempt": attempt, **entry}
    finally:
        lock.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--stage", choices=("domain", "spec", "impl", "task"), required=True)
    parser.add_argument("--feature")
    parser.add_argument("--attempt", type=int, required=True)
    parser.add_argument("--concept", required=True)
    parser.add_argument("--evidence", required=True)
    args = parser.parse_args()
    try:
        if args.attempt < 1:
            raise ValueError("attempt must be positive")
        print(json.dumps(record(args.root, args.stage, args.feature, args.attempt, args.concept, args.evidence)))
    except (OSError, ValueError, TypeError) as error:
        print(f"upstream-concept-issue: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
