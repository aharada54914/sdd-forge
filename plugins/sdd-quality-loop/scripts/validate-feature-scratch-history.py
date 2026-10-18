#!/usr/bin/env python3
"""Supplement the review validator; called only after its normal checks pass.

Snapshots retain declared roots without changing the identity-ledger/v1 schema.
This checks recorded locations, not operating-system sandbox enforcement.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
from typing import Any, Dict, Optional, Tuple


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=unique_object)


def safe_path(root, path):
    relative = path.relative_to(root)
    current = root
    for part in relative.parts:
        current /= part
        if current.is_symlink():
            raise ValueError("scratch history traverses a symbolic link")
    return path


def canonical(value):
    if not isinstance(value, str) or not re.fullmatch(r"(?:/|[A-Za-z]:/)[^\\\r\n]+", value):
        raise ValueError("scratch history contains a non-canonical root")
    if any(part in ("", ".", "..") for part in value.split("/")[1:]):
        raise ValueError("scratch history contains a non-canonical root")
    return value.lower() if re.match(r"^[A-Za-z]:/", value) else value


def report_root(value):
    if len(value) >= 2 and value.startswith("`") and value.endswith("`"):
        value = value[1:-1]
    if re.search(r"[\x00-\x1f\x7f`]", value):
        raise ValueError("scratch history contains invalid report path display")
    return canonical(value)


def overlap(left, right):
    left, right = canonical(left), canonical(right)
    return left == right or left.startswith(right + "/") or right.startswith(left + "/")


def identity(document):
    return tuple(document.get(key) for key in ("stage", "role", "run_id", "host_session_id"))


def declaration(document):
    feature = document.get("feature")
    if not isinstance(feature, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", feature):
        raise ValueError("scratch history has no valid feature")
    scratch = document.get("scratch_root")
    if scratch is not None:
        canonical(scratch)
    return feature, scratch


def binding(document):
    feature, scratch = declaration(document)
    if scratch is None:
        raise ValueError("bound scratch declaration is missing")
    return hashlib.sha256((feature + "\n" + scratch).encode()).hexdigest()


def check(root, invocation, ledger):
    scratch = invocation["scratch_root"]
    feature = invocation["feature"]
    canonical(scratch)
    reports = safe_path(root, root / "reports/implementation" / feature)
    if not reports.is_dir():
        raise ValueError("feature implementation reports are missing")
    for report in reports.glob("*.md"):
        safe_path(root, report)
        if not report.is_file():
            raise ValueError("implementation report is not a regular file")
        roots = re.findall(r"^- \*\*Scratch Root\*\*: (.*)$", report.read_bytes().decode("utf-8").replace("\r\n", "\n"), re.M)
        if len(roots) > 1:
            raise ValueError("implementation report has duplicate scratch declarations")
        for other in roots:
            if overlap(scratch, report_root(other)):
                raise ValueError("evaluator scratch root overlaps a feature implementation root")

    records = [record for record in ledger["records"]
               if record["stage"] == "quality" and record["role"] == "sdd-evaluator"]
    wanted = {identity(record) for record in records}
    histories: Dict[Tuple[Any, ...], Tuple[str, Optional[str]]] = {}
    if wanted:
        for directory, dirs, files in os.walk(safe_path(root, root / "reports"), followlinks=False):
            for name in dirs:
                safe_path(root, Path(directory) / name)
            for name in files:
                if not name.endswith(".json"):
                    continue
                path = safe_path(root, Path(directory) / name)
                try:
                    document = read_json(path)
                except (ValueError, UnicodeError):
                    if "invocation" in name or "scratch-reservations" in path.parts:
                        raise ValueError("unreadable invocation history")
                    continue
                if not isinstance(document, dict) or document.get("schema") != "review-context-invocation/v2":
                    continue
                key = identity(document)
                if key not in wanted:
                    continue
                value = declaration(document)
                if key in histories and histories[key] != value:
                    raise ValueError("conflicting scratch declarations for a reserved evaluator")
                histories[key] = value
    for record in records:
        key = identity(record)
        if key not in histories:
            if "scratch_declaration_sha256" in record:
                raise ValueError("bound evaluator invocation history is missing; restore original evidence")
            # Pre-extension records have no persisted scratch assertion. Do not
            # invent history or block an unrelated feature on an unknown root.
            continue
        previous_feature, previous_root = histories[key]
        if "scratch_declaration_sha256" in record:
            evidence = dict(feature=previous_feature, scratch_root=previous_root)
            if binding(evidence) != record["scratch_declaration_sha256"]:
                raise ValueError("reserved evaluator scratch binding mismatch")
        if key == identity(invocation):
            if histories[key] != declaration(invocation):
                raise ValueError("reserved evaluator scratch declaration changed")
        elif previous_feature == feature and previous_root is not None and overlap(scratch, previous_root):
            raise ValueError("evaluator scratch root overlaps a previously reserved evaluator root")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("repository", type=Path)
    parser.add_argument("--snapshot", action="store_true")
    args = parser.parse_args()
    root = args.repository.resolve(strict=True)
    invocation = read_json(args.manifest)
    if (invocation.get("stage"), invocation.get("role")) != ("quality", "sdd-evaluator") or "scratch_root" not in invocation:
        return
    ledger = read_json(safe_path(root, root / invocation["identity_ledger_path"]))
    check(root, invocation, ledger)
    if args.snapshot:
        text = "|".join(str(invocation[key]) for key in
                        ("sequence", "stage", "role", "run_id", "host_session_id", "previous_record_sha256"))
        text += "|scratch-declaration-v1|" + binding(invocation)
        record_hash = hashlib.sha256(text.encode()).hexdigest()
        directory = safe_path(root, root / "reports/review-context/scratch-reservations")
        directory.mkdir(exist_ok=True)
        destination = safe_path(root, directory / (record_hash + ".json"))
        # The caller holds the ledger lock. Never replace an earlier snapshot.
        with destination.open("x", encoding="utf-8") as stream:
            stream.write(json.dumps(invocation, sort_keys=True) + "\n")
            stream.flush()
            os.fsync(stream.fileno())


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"REVIEW_CONTEXT_PATH: {error}", file=sys.stderr)
        raise SystemExit(1)
