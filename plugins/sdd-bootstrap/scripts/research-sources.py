#!/usr/bin/env python3
"""Merge two explicit research routes without inventing acquisition or meaning.

Input batches contain canonical Source records from the caller's actual tools.
Ordinary technical queries are allowed; detected secrets or explicit no-send stop.
"""

import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
QUALITY = Path(__file__).resolve().parents[2] / "sdd-quality-loop/scripts"
sys.path.insert(0, str(QUALITY))
from research_evidence import (  # noqa: E402 - sibling runtime path is explicit.
    Parser,
    Invalid,
    require,
    read_json,
    values,
    validate_document,
    validate_file,
)
from research_consumers import closed  # noqa: E402 - sibling runtime path is explicit.


def search_plan(question, *, no_send=False, budget=10):
    require(not no_send, "external-send-forbidden")
    values(question)
    require(
        isinstance(question, str)
        and 0 < len(question) <= 500
        and type(budget) is int
        and 2 <= budget <= 50,
        "search-budget-invalid",
    )
    return dict(
        schema="research-search-plan/v1",
        question=question,
        max_results=budget,
        routes=[
            dict(
                route="official",
                query=question + " official documentation specification",
            ),
            dict(
                route="citation-trail",
                query=question + " primary source references implementation",
            ),
        ],
        stop_when=["budget-exhausted", "both-routes-inspected", "permission-denied"],
        authority="none",
    )


def merge_routes(doc, batches, *, budget=10):
    validate_document(doc)
    require(
        isinstance(batches, list)
        and len(batches) == 2
        and type(budget) is int
        and 2 <= budget <= 50,
        "search-budget-invalid",
    )
    routes = set()
    sources = [dict(s) for s in doc["sources"]]
    identities = {
        (s["url"], s["source_revision"], s["content_sha256"]): s["source_id"]
        for s in sources
    }
    used = {s["source_id"] for s in sources}
    count = 0
    log = []
    for batch in batches:
        closed(batch, ["route", "query", "sources"])
        require(
            batch["route"] in ("official", "citation-trail")
            and batch["route"] not in routes,
            "search-route-invalid",
        )
        routes.add(batch["route"])
        values(batch["query"])
        require(isinstance(batch["sources"], list), "schema-invalid")
        ids = []
        for candidate in batch["sources"]:
            count += 1
            require(count <= budget, "search-budget-exceeded")
            validate_document(
                dict(
                    schema="research-evidence/v1",
                    feature=doc["feature"],
                    sources=[candidate],
                    claims=[],
                )
            )
            require(
                candidate["verification_status"] == "unverified",
                "untrusted-verification",
            )
            key = (
                candidate["url"],
                candidate["source_revision"],
                candidate["content_sha256"],
            )
            if key not in identities:
                available = next(
                    (
                        f"SRC-{n:03}"
                        for n in range(1, 1000)
                        if f"SRC-{n:03}" not in used
                    ),
                    None,
                )
                require(available is not None, "source-id-exhausted")
                candidate = dict(candidate, source_id=available)
                sources.append(candidate)
                used.add(available)
                identities[key] = available
            ids.append(identities[key])
        log.append(
            dict(
                route=batch["route"], query=batch["query"], source_ids=sorted(set(ids))
            )
        )
    result = dict(
        doc,
        sources=sorted(sources, key=lambda s: (s["source_id"], s["record_revision"])),
    )
    validate_document(result)
    return dict(
        schema="research-search-result/v1",
        records=result,
        routes=log,
        claims_assessed=False,
    )


def main(argv=None):
    p = Parser()
    p.add_argument("command", choices=["plan", "merge"])
    p.add_argument("--question")
    p.add_argument("--no-send", action="store_true")
    p.add_argument("--budget", type=int, default=10)
    p.add_argument("--file")
    p.add_argument("--batches")
    a = p.parse_args(argv)
    try:
        if a.command == "plan":
            result = search_plan(a.question, no_send=a.no_send, budget=a.budget)
        else:
            require(a.file and a.batches, "usage-invalid")
            result = merge_routes(
                validate_file(a.file), read_json(a.batches), budget=a.budget
            )
        print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
        return 0
    except Invalid as e:
        print("research-sources: " + e.code, file=sys.stderr)
        return 1
    except (OSError, TypeError, ValueError, KeyError):
        print("research-sources: input-invalid", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
