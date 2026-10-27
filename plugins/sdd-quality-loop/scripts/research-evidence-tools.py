#!/usr/bin/env python3
"""Offline consumers of the versioned research evidence contract."""

import json
import os
from pathlib import Path
import sys
import tempfile

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from research_evidence import (  # noqa: E402 - sibling runtime path is explicit.
    Parser,
    Invalid,
    validate_file,
    read_json,
    digest,
    require,
    ordinary,
)
from research_consumers import (  # noqa: E402 - sibling runtime path is explicit.
    verify_originals,
    impact,
    render_report,
    validate_relations,
)


def publish(path, text):
    path = Path(path).absolute()
    require(all(not p.is_symlink() for p in [path, *path.parents]), "output-invalid")
    fd, temp = tempfile.mkstemp(prefix=".research-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def main(argv=None):
    p = Parser()
    p.add_argument("command", choices=["check", "graph", "impact", "report", "bind"])
    p.add_argument("--file", required=True)
    p.add_argument("--repo-root")
    p.add_argument("--relations")
    p.add_argument("--source-id")
    p.add_argument("--snapshots")
    p.add_argument("--snapshot-root")
    p.add_argument("--matching", choices=["exact", "whitespace"], default="exact")
    p.add_argument("--output")
    p.add_argument("--annotations")
    a = p.parse_args(argv)
    try:
        require(not a.annotations or a.command == "report", "usage-invalid")
        doc, document_raw = validate_file(a.file, a.repo_root, with_raw=True)
        if a.command in ("check", "report", "bind"):
            require(a.snapshots and a.snapshot_root, "usage-invalid")
            verified = verify_originals(
                doc, read_json(a.snapshots), a.snapshot_root, matching=a.matching
            )
        if a.command in ("graph", "impact", "bind"):
            require(a.relations and a.repo_root, "usage-invalid")
            relations, relations_raw = read_json(a.relations, with_raw=True)
            edges, pins = validate_relations(doc, relations, a.repo_root)
        if a.command == "check":
            result = verified
        elif a.command == "graph":
            result = dict(
                schema="research-graph-result/v1",
                feature=doc["feature"],
                edges=edges,
                pins=pins,
                meaning_assessed=False,
            )
        elif a.command == "impact":
            require(a.source_id is not None, "usage-invalid")
            result = impact(doc, relations, a.repo_root, a.source_id)
        elif a.command == "report":
            result = render_report(
                doc, verified, read_json(a.annotations) if a.annotations else None
            )
        else:
            root = Path(a.repo_root).absolute()
            inputs = []
            for path, raw in ((a.file, document_raw), (a.relations, relations_raw)):
                file = ordinary(path)
                require(file.is_relative_to(root), "path-invalid")
                require(digest(file.read_bytes()) == digest(raw), "input-changed")
                inputs.append(
                    dict(
                        path=file.relative_to(root).as_posix(),
                        sha256=digest(raw),
                    )
                )
            inputs.extend(
                dict(path=path, sha256=sha) for path, sha in sorted(pins.items())
            )
            result = dict(
                schema="research-review-input/v1",
                feature=doc["feature"],
                allowed_inputs=inputs,
                source_verification=verified,
                status="ready-for-independent-review"
                if verified["complete"]
                and all(s["currency_status"] == "current" for s in doc["sources"])
                and all(c["evidence_status"] != "conflicting" for c in doc["claims"])
                else "open-questions",
                changes_approval=False,
            )
        text = (
            result
            if isinstance(result, str)
            else json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
        )
        if a.output:
            publish(a.output, text)
        else:
            print(text, end="")
        return 1 if a.command == "check" and not verified["complete"] else 0
    except Invalid as exc:
        print(
            "research-evidence: INVALID: " + exc.code + " " + exc.pointer,
            file=sys.stderr,
        )
        return 1
    except (OSError, UnicodeError, ValueError, TypeError, KeyError, RecursionError):
        print("research-evidence: INVALID: input-unavailable /", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
