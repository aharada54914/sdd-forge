"""Read-only original verification, pinned relations and research presentation."""

from __future__ import annotations
import datetime as dt
import html
from pathlib import Path
import re
from research_evidence import (
    Invalid,
    require,
    ordinary,
    read_json,
    parse_json,
    validate_document,
    validate_file,
    digest,
    record_digest,
    timestamp,
    values,
    shared_snapshot,
)


from research_extraction import extract, subtitle_range

SUBTITLE_METHODS = ('webvtt-plain-cues/v1', 'srt-plain-cues/v1')


def closed(value, keys):
    require(isinstance(value, dict) and set(value) == set(keys), "schema-invalid")


def relative_file(root, relative):
    require(
        isinstance(relative, str)
        and relative
        and not re.search(r"[:\\\x00-\x1f]", relative),
        "path-invalid",
    )
    require(
        not relative.startswith("/")
        and all(p not in ("", ".", "..") for p in relative.split("/")),
        "path-invalid",
    )
    return ordinary(Path(root).absolute() / relative)


def current_access(source, now):
    require(source["storage_mode"] != "blocked", "rights-blocked")
    require(source["currency_status"] not in ("stale", "retracted"), "source-stale")
    rights = source["license_or_permission_basis"]["status"]
    require(rights not in ("restricted", "requires-human"), "rights-blocked")
    retention = source["retention_or_expiry"]
    if retention:
        require(retention["expires_at"] > now, "rights-expired")


def verify_originals(
    document, snapshot_manifest, snapshot_root, *, matching="exact", now=None
):
    """Recompute hashes/quotes from bytes; never consume a prior PASS as proof."""
    validate_document(document)
    now = now or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    timestamp(now, "/verified_at")
    require(matching in ("exact", "whitespace"), "matching-invalid")
    closed(snapshot_manifest, ["schema", "feature", "snapshots"])
    require(
        snapshot_manifest["schema"] == "research-snapshots/v1"
        and snapshot_manifest["feature"] == document["feature"],
        "schema-invalid",
    )
    require(isinstance(snapshot_manifest["snapshots"], list), "schema-invalid")
    snapshots = {}
    sources = {(s["source_id"], s["record_revision"]): s for s in document["sources"]}
    for item in snapshot_manifest["snapshots"]:
        closed(item, ["source_id", "record_revision", "original", "extracted"])
        require(
            isinstance(item["source_id"], str) and type(item["record_revision"]) is int,
            "snapshot-invalid",
        )
        key = (item["source_id"], item["record_revision"])
        require(
            key in sources
            and key not in snapshots
            and type(item["record_revision"]) is int,
            "snapshot-invalid",
        )
        source = sources[key]
        current_access(source, now)
        require(
            source["retrieval_status"] == "retrieved"
            and source["extraction"] is not None,
            "source-unavailable",
        )
        if source['storage_mode'] == 'licensed_shared':
            shared_snapshot(snapshot_root, item, source)
        with relative_file(snapshot_root, item["original"]).open("rb") as stream:
            original = stream.read(32 * 1024 * 1024 + 1)
        with relative_file(snapshot_root, item["extracted"]).open("rb") as stream:
            extracted = stream.read(8 * 1024 * 1024 + 1)
        require(
            len(original) <= 32 * 1024 * 1024 and len(extracted) <= 8 * 1024 * 1024,
            "snapshot-too-large",
        )
        require(
            digest(original) == source["content_sha256"]
            and digest(extracted) == source["extraction"]["extracted_sha256"],
            "snapshot-hash-mismatch",
        )
        regenerated, method, _ = extract(original, source["media_type"])
        require(
            method == source["extraction"]["method"] and regenerated == extracted,
            "extraction-provenance-mismatch",
        )
        try:
            text = extracted.decode("utf-8")
        except UnicodeError:
            raise Invalid("extraction-invalid") from None
        snapshots[key] = (item, text)
    results = []
    for c in document["claims"]:
        for index, cite in enumerate(c["citations"]):
            key = (cite["source_id"], cite["source_record_revision"])
            if sources[key]["retrieval_status"] != "retrieved":
                results.append(
                    dict(
                        claim_id=c["claim_id"],
                        claim_revision=c["record_revision"],
                        citation=index,
                        result="not-checkable",
                        source_id=key[0],
                        source_revision=key[1],
                    )
                )
                continue
            require(key in snapshots, "snapshot-missing")
            item, text = snapshots[key]
            anchor = cite["anchor"]
            lines = text.split("\n")
            require(anchor["line_end"] <= len(lines), "quote-range-mismatch")
            excerpt = "\n".join(lines[anchor["line_start"] - 1 : anchor["line_end"]])
            quote = anchor["quote"]
            if matching == "whitespace":
                excerpt = " ".join(excerpt.split())
                quote = " ".join(quote.split())
            require(bool(quote) and quote in excerpt, "quote-mismatch")
            results.append(
                dict(
                    claim_id=c["claim_id"],
                    claim_revision=c["record_revision"],
                    citation=index,
                    result="reverified",
                    matching=matching,
                    source_id=key[0],
                    source_revision=key[1],
                    content_sha256=sources[key]["content_sha256"],
                    extracted_sha256=sources[key]["extraction"]["extracted_sha256"],
                    quote_sha256=anchor["quote_sha256"],
                    original=item["original"],
                    extracted=item["extracted"],
                )
            )
            if sources[key]['extraction']['method'] in SUBTITLE_METHODS:
                results[-1]['time_range'] = subtitle_range(text, anchor['line_start'], anchor['line_end'])
    return dict(
        schema="source-evidence-result/v2" if any('time_range' in result for result in results) else "source-evidence-result/v1",
        feature=document["feature"],
        verified_at=now,
        meaning_assessed=False,
        results=results,
        complete=bool(results) and all(r["result"] == "reverified" for r in results),
    )


def endpoint_identity(node):
    return (
        node["kind"],
        node.get("feature", ""),
        node["id"],
        node.get("record_revision", 0),
    )


def validate_relations(doc, relations, root, *, read_source=None):
    validate_document(doc)
    closed(relations, ["schema", "feature", "edges"])
    require(
        relations["schema"] == "research-relations/v1"
        and relations["feature"] == doc["feature"]
        and isinstance(relations["edges"], list),
        "schema-invalid",
    )
    require(
        len(relations["edges"]) <= 2000 and len(doc["claims"]) <= 500,
        "graph-size-limit",
    )
    records = {("SRC", s["source_id"], s["record_revision"]): s for s in doc["sources"]}
    records.update(
        {("CLM", c["claim_id"], c["record_revision"]): c for c in doc["claims"]}
    )
    pins = {}
    nodes = {}

    def endpoint(n):
        require(
            isinstance(n, dict) and n.get("kind") in ("CLM", "REQ", "ADR"),
            "endpoint-invalid",
        )
        kind = n["kind"]
        if kind == "CLM":
            closed(n, ["kind", "feature", "id", "record_revision", "record_sha256"])
            require(
                n["feature"] == doc["feature"]
                and isinstance(n["id"], str)
                and type(n["record_revision"]) is int,
                "endpoint-invalid",
            )
            r = records.get(("CLM", n["id"], n["record_revision"]))
            require(
                r is not None and record_digest(r) == n["record_sha256"],
                "endpoint-stale",
            )
        else:
            if kind == "REQ":
                closed(n, ["kind", "feature", "id", "document_sha256"])
                require(
                    n["feature"] == doc["feature"]
                    and isinstance(n["id"], str)
                    and re.fullmatch(r"REQ-[0-9]{3}", n["id"]),
                    "endpoint-invalid",
                )
                path = f"specs/{doc['feature']}/requirements.md"
            else:
                closed(n, ["kind", "id", "path", "document_sha256"])
                require(
                    isinstance(n["id"], str)
                    and re.fullmatch(r"ADR-[0-9]{4}", n["id"]) is not None,
                    "endpoint-invalid",
                )
                path = n["path"]
                require(
                    isinstance(path, str)
                    and re.fullmatch(
                        r"docs/adr/" + n["id"][4:] + r"-[a-z0-9-]+\.md", path
                    )
                    is not None,
                    "endpoint-invalid",
                )
            raw = (
                read_source(path)
                if read_source
                else relative_file(root, path).read_bytes()
            )
            require(digest(raw) == n["document_sha256"], "endpoint-stale")
            if kind == "REQ":
                require(
                    re.search(
                        r"(?m)^#{1,6}\s+" + re.escape(n["id"]) + r"\b",
                        raw.decode("utf-8"),
                    )
                    is not None,
                    "requirement-missing",
                )
            pins[path] = digest(raw)
        ident = endpoint_identity(n)
        require(ident not in nodes or nodes[ident] == n, "endpoint-conflict")
        nodes[ident] = n
        return ident

    edges = []
    seen = set()
    for e in relations["edges"]:
        closed(e, ["from", "to", "relation"])
        a = endpoint(e["from"])
        b = endpoint(e["to"])
        relation = e["relation"]
        require(
            a[0] == "CLM"
            and (
                (b[0] in ("REQ", "ADR") and relation in ("justifies", "constrains"))
                or (b[0] == "CLM" and relation == "depends-on")
            ),
            "edge-invalid",
        )
        key = (a, b, relation)
        require(key not in seen, "edge-duplicate")
        seen.add(key)
        edges.append(key)
    # SRC -> CLM is derived from the one canonical citation list, not duplicated.
    for c in doc["claims"]:
        target = ("CLM", doc["feature"], c["claim_id"], c["record_revision"])
        for cite in c["citations"]:
            source = (
                "SRC",
                doc["feature"],
                cite["source_id"],
                cite["source_record_revision"],
            )
            key = (source, target, cite["relation"])
            if key not in seen:
                seen.add(key)
                edges.append(key)
    return sorted(edges), pins


def impact(doc, relations, root, source_id):
    edges, pins = validate_relations(doc, relations, root)
    require(any(s["source_id"] == source_id for s in doc["sources"]), "source-missing")
    initial = {
        ("SRC", doc["feature"], s["source_id"], s["record_revision"])
        for s in doc["sources"]
        if s["source_id"] == source_id
    }
    seen = set(initial)
    pending = list(initial)
    cycles = []
    while pending:
        n = pending.pop()
        # depends-on A -> B means a change in B affects A, unlike justification.
        for a, b, relation in edges:
            if relation == "depends-on":
                a, b = b, a
            if a != n:
                continue
            if b in seen:
                continue
            seen.add(b)
            pending.append(b)
    # Report dependency cycles explicitly using bounded DFS on CLM edges.
    adjacency = {}
    for a, b, r in edges:
        if r == "depends-on":
            adjacency.setdefault(a, []).append(b)
    active = set()
    done = set()

    def visit(n):
        if n in active:
            cycles.append(n)
            return
        if n in done:
            return
        active.add(n)
        for b in adjacency.get(n, []):
            visit(b)
        active.remove(n)
        done.add(n)

    for n in sorted(adjacency):
        visit(n)
    requirements = sorted(n[2] for n in seen if n[0] == "REQ")
    adrs = sorted(n[2] for n in seen if n[0] == "ADR")
    downstream = []
    trace = f"specs/{doc['feature']}/traceability.json"
    if requirements:
        data, trace_raw = read_json(relative_file(root, trace), with_raw=True)
        require(
            isinstance(data, dict)
            and data.get("feature") == doc["feature"]
            and isinstance(data.get("links"), list),
            "traceability-invalid",
        )
        for req in requirements:
            links = [
                link
                for link in data["links"]
                if isinstance(link, dict) and link.get("req") == req
            ]
            require(bool(links), "traceability-missing")
            for link in links:
                require(
                    all(
                        isinstance(link.get(k), list)
                        for k in ("acs", "tests", "evidence")
                    ),
                    "traceability-invalid",
                )
                require(
                    all(link[k] and all(isinstance(v, str) and v.strip() for v in link[k])
                        for k in ("acs", "tests"))
                    and all(isinstance(v, str) and v.strip() for v in link["evidence"]),
                    "traceability-invalid",
                )
                downstream.append(link)
        pins[trace] = digest(trace_raw)
    return dict(
        schema="research-impact/v1",
        feature=doc["feature"],
        source_id=source_id,
        status="revalidation-candidate" if requirements or adrs else "impact-unknown",
        requirements=requirements,
        adrs=adrs,
        claims=sorted({n[2] for n in seen if n[0] == "CLM"}),
        traceability=sorted(downstream, key=lambda r: r["req"]),
        cycles=sorted({n[2] for n in cycles}),
        pins=[dict(path=p, sha256=h) for p, h in sorted(pins.items())],
        changes_approval=False,
    )


def render_report(doc, verified, annotations=None):
    require(verified["feature"] == doc["feature"], "report-input-mismatch")
    results = {
        (r["claim_id"], r["claim_revision"], r["citation"]): r
        for r in verified["results"]
    }
    sources = {(s["source_id"], s["record_revision"]): s for s in doc["sources"]}
    translations = {}
    if annotations is not None:
        closed(annotations, ["schema", "feature", "translations"])
        require(
            annotations["schema"] == "research-report-annotations/v1"
            and annotations["feature"] == doc["feature"]
            and isinstance(annotations["translations"], list),
            "report-annotations-invalid",
        )
        total = 0
        for translation in annotations["translations"]:
            closed(
                translation,
                [
                    "claim_id",
                    "claim_revision",
                    "citation",
                    "quote_sha256",
                    "language",
                    "text",
                ],
            )
            require(
                isinstance(translation["claim_id"], str)
                and type(translation["claim_revision"]) is int
                and type(translation["citation"]) is int,
                "report-annotations-invalid",
            )
            key = (
                translation["claim_id"],
                translation["claim_revision"],
                translation["citation"],
            )
            require(
                key in results
                and key not in translations
                and results[key]["result"] == "reverified"
                and translation["quote_sha256"] == results[key]["quote_sha256"],
                "report-annotations-stale",
            )
            require(
                isinstance(translation["language"], str)
                and re.fullmatch(
                    r"[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*", translation["language"]
                )
                and isinstance(translation["text"], str)
                and translation["text"],
                "report-annotations-invalid",
            )
            values(translation["text"])
            total += len(translation["text"])
            require(total <= 1500, "report-translation-budget")
            translations[key] = translation
    esc = html.escape
    parts = [
        '<!doctype html><html lang="en"><meta charset="utf-8">',
        "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; base-uri 'none'; form-action 'none'\">",
        "<title>Research evidence</title><h1>Research evidence</h1><p>String verification is separate from semantic assessment and approval.</p><main>",
    ]
    for c in doc["claims"]:
        parts.append(
            f"<section><h2>{esc(c['claim_id'])}: {esc(c['statement'])}</h2><p>Evidence: {esc(c['evidence_status'])}; meaning: {esc(c['semantic_status'])}</p>"
        )
        if not c["citations"]:
            parts.append("<p>Unreached: no source citations.</p>")
        for i, cite in enumerate(c["citations"]):
            s = sources[(cite["source_id"], cite["source_record_revision"])]
            r = results[(c["claim_id"], c["record_revision"], i)]
            parts.append(
                f'<p>{esc(cite["relation"])}: <a rel="noreferrer" href="{esc(s["url"], quote=True)}">{esc(s["title"])}</a> · {esc(s["source_revision"] or "unknown revision")} · {esc(r["result"])}</p>'
            )
            parts.append(
                f"<p>Retrieved: {esc(s['retrieved_at'] or 'unavailable')}; storage: {esc(s['storage_mode'])}; permission: {esc(s['license_or_permission_basis']['status'])}.</p>"
            )
            if cite["relation"] == "contradicts":
                parts.append(
                    "<p>Disagreement: this citation contradicts the claim.</p>"
                )
            if r["result"] == "reverified":
                a = cite["anchor"]
                if 'time_range' in r:
                    def clock(milliseconds):
                        seconds, fraction = divmod(milliseconds, 1000)
                        minutes, seconds = divmod(seconds, 60)
                        hours, minutes = divmod(minutes, 60)
                        return f'{hours:02}:{minutes:02}:{seconds:02}.{fraction:03}'
                    span = r['time_range']
                    parts.append(f"<p>Subtitle cue time: {clock(span['start_ms'])}–{clock(span['end_ms'])}; timing from the caption file, video alignment not independently verified.</p>")
                parts.append(
                    f"<details><summary>Original excerpt, lines {a['line_start']}–{a['line_end']}</summary><blockquote>{esc(a['quote'])}</blockquote></details>"
                )
                translation = translations.get((c["claim_id"], c["record_revision"], i))
                if translation:
                    parts.append(
                        f'<p>Translation ({esc(translation["language"])}); meaning not verified:</p><blockquote lang="{esc(translation["language"], quote=True)}">{esc(translation["text"])}</blockquote>'
                    )
            else:
                parts.append(
                    "<p>Original unavailable; no fresh verification claimed.</p>"
                )
        parts.append("</section>")
    parts.append("</main></html>")
    return "\n".join(parts) + "\n"


def validate_verification_record(doc, verification):
    """Validate recorded claims of verification; does not authenticate fresh proof."""
    closed(
        verification,
        ["schema", "feature", "verified_at", "meaning_assessed", "results", "complete"],
    )
    require(
        verification["schema"] in ("source-evidence-result/v1", "source-evidence-result/v2")
        and verification["feature"] == doc["feature"]
        and verification["meaning_assessed"] is False
        and type(verification["complete"]) is bool
        and isinstance(verification["results"], list),
        "research-review-invalid",
    )
    timestamp(verification["verified_at"], "/verified_at")
    sources = {(s["source_id"], s["record_revision"]): s for s in doc["sources"]}
    expected = [
        (c, i, cite) for c in doc["claims"] for i, cite in enumerate(c["citations"])
    ]
    require(len(expected) == len(verification["results"]), "research-review-invalid")
    complete = bool(expected)
    for result, (claim, index, cite) in zip(verification["results"], expected):
        require(
            isinstance(result, dict)
            and result.get("result") in ("reverified", "not-checkable"),
            "research-review-invalid",
        )
        keys = [
            "claim_id",
            "claim_revision",
            "citation",
            "result",
            "source_id",
            "source_revision",
        ]
        source = sources[(cite["source_id"], cite["source_record_revision"])]
        if result["result"] == "reverified":
            keys += [
                "matching",
                "content_sha256",
                "extracted_sha256",
                "quote_sha256",
                "original",
                "extracted",
            ]
            if source['extraction']['method'] in SUBTITLE_METHODS:
                require(verification['schema'] == 'source-evidence-result/v2', 'research-review-invalid')
                keys.append('time_range')
                span = result.get('time_range')
                closed(span, ['start_ms', 'end_ms'])
                require(type(span['start_ms']) is int and type(span['end_ms']) is int
                        and 0 <= span['start_ms'] < span['end_ms'] < 3600000000000,
                        'research-review-invalid')
        closed(result, keys)
        require(
            result["claim_id"] == claim["claim_id"]
            and type(result["claim_revision"]) is int
            and result["claim_revision"] == claim["record_revision"]
            and type(result["citation"]) is int
            and result["citation"] == index
            and result["source_id"] == cite["source_id"]
            and type(result["source_revision"]) is int
            and result["source_revision"] == cite["source_record_revision"],
            "research-review-invalid",
        )
        source = sources[(cite["source_id"], cite["source_record_revision"])]
        if result["result"] == "not-checkable":
            require(
                source["retrieval_status"] != "retrieved", "research-review-invalid"
            )
            complete = False
        else:
            require(
                source["retrieval_status"] == "retrieved"
                and result["matching"] in ("exact", "whitespace")
                and result["content_sha256"] == source["content_sha256"]
                and result["extracted_sha256"]
                == source["extraction"]["extracted_sha256"]
                and result["quote_sha256"] == cite["anchor"]["quote_sha256"],
                "research-review-invalid",
            )
            for key in ("original", "extracted"):
                value = result[key]
                require(
                    isinstance(value, str)
                    and value
                    and not re.search(r"[:\\\x00-\x1f]", value)
                    and not value.startswith("/")
                    and all(part not in ("", ".", "..") for part in value.split("/")),
                    "research-review-invalid",
                )
    require(verification["complete"] is complete, "research-review-invalid")


def review_inputs(feature, read_source):
    """Resolve only an explicit fixed-byte packet; no original cache is exported."""
    packet_path = f"specs/{feature}/research/review-input.json"
    raw = read_source(packet_path, True)
    if raw is None:
        return []
    packet = parse_json(raw)
    closed(
        packet,
        [
            "schema",
            "feature",
            "allowed_inputs",
            "source_verification",
            "status",
            "changes_approval",
        ],
    )
    require(
        packet["schema"] == "research-review-input/v1"
        and packet["feature"] == feature
        and packet["changes_approval"] is False
        and packet["status"] in ("ready-for-independent-review", "open-questions"),
        "research-review-invalid",
    )
    records_path = f"specs/{feature}/research/records/research-evidence.json"
    relations_path = f"specs/{feature}/research/relations.json"
    require(isinstance(packet["allowed_inputs"], list), "research-review-invalid")
    selected = {}
    parsed = {}
    for entry in packet["allowed_inputs"]:
        closed(entry, ["path", "sha256"])
        path = entry["path"]
        require(
            isinstance(path, str)
            and (
                path
                in (records_path, relations_path, f"specs/{feature}/requirements.md")
                or re.fullmatch(r"docs/adr/[0-9]{4}-[a-z0-9-]+\.md", path)
            )
            and path not in selected,
            "research-review-path",
        )
        content = read_source(path)
        if (path == f"specs/{feature}/requirements.md"
                and digest(content) != entry["sha256"]):
            # Reconstruct only the existing Pending -> Passed lifecycle change.
            # Exact original SHA matching still proves every other byte unchanged.
            pattern = rb"(?m)^Spec-Review-Status: Passed(\r?)$"
            if (len(re.findall(pattern, content)) == 1
                    and len(re.findall(rb"(?m)^Spec-Review-Status:", content)) == 1):
                content = re.sub(pattern, rb"Spec-Review-Status: Pending\1", content)
        require(digest(content) == entry["sha256"], "research-review-stale")
        selected[path] = entry["sha256"]
        parsed[path] = content
    require(
        records_path in selected and relations_path in selected,
        "research-review-missing",
    )
    doc = validate_document(parse_json(parsed[records_path]))
    require(doc["feature"] == feature, "research-review-invalid")
    relations = parse_json(parsed[relations_path])

    def selected_source(path):
        require(path in parsed, "research-review-missing")
        return parsed[path]

    _, pins = validate_relations(doc, relations, None, read_source=selected_source)
    require(
        set(selected) == {records_path, relations_path, *pins}, "research-review-path"
    )
    verification = packet["source_verification"]
    validate_verification_record(doc, verification)
    ready = (
        verification["complete"]
        and all(s["currency_status"] == "current" for s in doc["sources"])
        and all(c["evidence_status"] != "conflicting" for c in doc["claims"])
    )
    require(
        packet["status"]
        == ("ready-for-independent-review" if ready else "open-questions"),
        "research-review-status",
    )
    # The packet is review input, not fresh original verification or approval.
    return sorted(
        [dict(path=packet_path, sha256=digest(raw))]
        + [dict(path=p, sha256=h) for p, h in selected.items()],
        key=lambda e: e["path"],
    )


def verify_check_record(record_path, root, snapshot_root):
    """The existing contract owner recomputes source evidence instead of trusting PASS."""
    require(snapshot_root is not None and snapshot_root != "", "snapshot-root-required")
    record = read_json(record_path)
    closed(
        record,
        [
            "schema",
            "file",
            "records_sha256",
            "snapshots",
            "snapshots_sha256",
            "matching",
        ],
    )
    require(record["schema"] == "source-evidence-check/v1", "schema-invalid")
    file = relative_file(root, record["file"])
    doc, raw = validate_file(file, root, with_raw=True)
    snapshots, manifest_raw = read_json(
        relative_file(root, record["snapshots"]), with_raw=True
    )
    require(
        digest(raw) == record["records_sha256"]
        and digest(manifest_raw) == record["snapshots_sha256"],
        "source-evidence-input-stale",
    )
    result = verify_originals(
        doc, snapshots, snapshot_root, matching=record["matching"]
    )
    require(result["complete"], "source-evidence-incomplete")
    return result
