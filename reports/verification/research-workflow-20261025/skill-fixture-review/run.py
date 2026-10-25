import argparse
import copy
import importlib.util
import json
import pathlib
import socket
import subprocess
import tempfile
import sys

ROOT = pathlib.Path(__file__).resolve().parents[4]
parser = argparse.ArgumentParser(description="Replay fixture review without overwriting historical evidence")
parser.add_argument("--output", required=True, type=pathlib.Path)
replay_options = parser.parse_args()
if replay_options.output.exists():
    parser.error("output must not already exist")


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


f = load("review_fixture", "tests/research-evidence.tests.py")
a = load("review_acquire", "plugins/sdd-bootstrap/scripts/research-acquire.py")
sys.path.insert(0, str(ROOT / "plugins/sdd-quality-loop/scripts"))
from research_evidence import record_digest, digest, validate_document  # noqa: E402 - explicit repository helper path.

results = []


def cli(label, args, expected=0):
    r = subprocess.run(
        [sys.executable, *map(str, args)], cwd=ROOT, capture_output=True, text=True
    )
    results.append(
        dict(
            case=label,
            exit_code=r.returncode,
            stdout=r.stdout,
            stderr=r.stderr,
            expected=expected,
        )
    )
    assert r.returncode == expected, (label, r.stdout, r.stderr)
    return json.loads(r.stdout) if r.stdout and r.stdout.startswith("{") else r.stdout


with tempfile.TemporaryDirectory(prefix="research-skill-fixture-") as temp:
    root = pathlib.Path(temp)
    research = root / "specs/sample/research"
    records = research / "records/research-evidence.json"
    records.parent.mkdir(parents=True)
    doc = dict(
        schema="research-evidence/v1",
        feature="sample",
        sources=[],
        claims=[
            dict(
                f.claim(),
                claim_id=f"CLM-{i:03}",
                statement={
                    1: "Keep originals private",
                    2: "A two-attempt retry cap sends at most two requests under permanent failure.",
                    3: "A retry cap cannot guarantee successful delivery after a permanent authorization failure.",
                }[i],
                citations=[],
                evidence_status="not-searched",
            )
            for i in range(1, 4)
        ],
    )
    records.write_text(json.dumps(doc))
    planner = ROOT / "plugins/sdd-bootstrap/scripts/research-sources.py"
    args = [
        planner,
        "plan",
        "--question",
        "bounded retries",
        "--file",
        records,
        "--constraint",
        "Keep originals private",
        "--budget",
        "2",
    ]
    plan = cli(
        "three-claim-plan",
        args + ["--assessable-claim", "CLM-002", "--assessable-claim", "CLM-003"],
    )
    assert plan["authority"] == "none"
    assert plan["claims"]["semantic_assessment"] == "caller-declared-not-verified"
    cli("minority-rejected", args + ["--assessable-claim", "CLM-002"], 1)
    cli("legacy-question-only", [planner, "plan", "--question", "bounded retries"])
    route_data = [
        dict(
            route="official",
            query="fixture bounded retries official",
            sources=[f.source(), f.source()],
        ),
        dict(
            route="citation-trail",
            query="fixture implementation references",
            sources=[],
        ),
    ]
    batches = root / "batches.json"
    batches.write_text(json.dumps(route_data))
    merged = cli(
        "duplicate-plus-empty-route",
        [planner, "merge", "--file", records, "--batches", batches, "--budget", "2"],
    )
    assert (
        len(merged["records"]["sources"]) == 1
        and merged["routes"][1]["source_ids"] == []
        and not merged["claims_assessed"]
    )
    route_data[1]["sources"] = [f.source()]
    batches.write_text(json.dumps(route_data))
    cli(
        "examined-result-budget-rejected",
        [planner, "merge", "--file", records, "--batches", batches, "--budget", "2"],
        1,
    )
    follow = []

    def resolver(host, port, **kwargs):
        return [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", port))]

    def response(url, addresses, timeout):
        follow.append(url)
        return 403, {"content-type": "text/plain"}, b"Fixture denied"

    try:
        a._acquire(
            "https://example.org/reference",
            ["example.org"],
            resolver=resolver,
            transport=response,
        )
    except a.Invalid as e:
        follow_status = e.code
    assert (
        follow == ["https://example.org/reference"]
        and follow_status == "access-restricted"
    )
    doc = merged["records"]
    doc["claims"][1] = dict(
        f.claim(),
        claim_id="CLM-002",
        statement="A two-attempt retry cap sends at most two requests under permanent failure.",
    )
    records.write_text(json.dumps(doc))
    # Synthetic original owned by this fixture, outside the repository.
    (root / "original").write_bytes(b"original")
    (root / "text").write_bytes(b"original")
    snapshots = root / "snapshots.json"
    snapshots.write_text(
        json.dumps(
            dict(
                schema="research-snapshots/v1",
                feature="sample",
                snapshots=[
                    dict(
                        source_id="SRC-001",
                        record_revision=1,
                        original="original",
                        extracted="text",
                    )
                ],
            )
        )
    )
    req = root / "specs/sample/requirements.md"
    req.write_text(
        "# Requirements\n\n## REQ-001 bounded policy\n\n## REQ-002 unrelated\n"
    )
    relation = dict(
        schema="research-relations/v1",
        feature="sample",
        edges=[
            {
                "from": dict(
                    kind="CLM",
                    feature="sample",
                    id="CLM-002",
                    record_revision=1,
                    record_sha256=record_digest(doc["claims"][1]),
                ),
                "to": dict(
                    kind="REQ",
                    feature="sample",
                    id="REQ-001",
                    document_sha256=digest(req.read_bytes()),
                ),
                "relation": "justifies",
            }
        ],
    )
    relations = research / "relations.json"
    relations.write_text(json.dumps(relation))
    tool = ROOT / "plugins/sdd-quality-loop/scripts/research-evidence-tools.py"
    base = ["--file", records, "--repo-root", root]
    proof = cli(
        "synthetic-original-verification",
        [tool, "check", *base, "--snapshots", snapshots, "--snapshot-root", root],
    )
    assert proof["meaning_assessed"] is False
    graph = cli(
        "typed-relation-handoff", [tool, "graph", *base, "--relations", relations]
    )
    assert any(edge[1][2] == "REQ-001" for edge in graph["edges"])
    assert all(edge[1][2] != "REQ-002" for edge in graph["edges"])
    packet = cli(
        "review-packet-no-approval",
        [
            tool,
            "bind",
            *base,
            "--relations",
            relations,
            "--snapshots",
            snapshots,
            "--snapshot-root",
            root,
        ],
    )
    assert packet["changes_approval"] is False
    relation["edges"][0]["to"]["feature"] = "other"
    relations.write_text(json.dumps(relation))
    cli("cross-feature-rejected", [tool, "graph", *base, "--relations", relations], 1)
    revised = copy.deepcopy(doc)
    revised["claims"].insert(
        1,
        dict(
            copy.deepcopy(revised["claims"][0]),
            record_revision=2,
            uncertainty="Corrected next round",
        ),
    )
    validate_document(revised)
    records.write_text(json.dumps(revised))
    r = subprocess.run(
        [
            sys.executable,
            *map(str, args),
            "--assessable-claim",
            "CLM-002",
            "--assessable-claim",
            "CLM-003",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    assert r.returncode == 0, (r.stdout, r.stderr)
    selected = json.loads(r.stdout)["claims"]["claim_records"]
    assert selected[0]["record_revision"] == 2 and len(selected) == 3
    results.append(
        dict(
            case="canonical-history-replan",
            exit_code=r.returncode,
            stdout=r.stdout,
            stderr=r.stderr,
            expected=0,
        )
    )
    output = dict(
        schema="research-skill-fixture-evaluation/v1",
        live_search=False,
        model_adoption=False,
        fixture_follow=dict(
            start="https://example.org/doc",
            followed=follow[0],
            response=403,
            result=follow_status,
            successful_discovery=False,
        ),
        stop=dict(
            reason="acquisition-wall",
            live_provider_calls=0,
            fixture_route_batches=2,
            fixture_follow_calls=1,
            tool_cost="unknown",
            result_budget=2,
            examined=2,
            new=1,
            seen=1,
            saturation=0.5,
            empty_route_saturation=None,
            required_follow_attempted=True,
            claims_satisfied=False,
            unresolved=["CLM-001", "CLM-003"],
        ),
        results=results,
    )
    # Temporary root path is evaluator-local, not evidence metadata needed for replay.
    raw = json.dumps(output, indent=2).replace(str(root), "<temporary-fixture-root>")
    with replay_options.output.open("x", encoding="utf-8") as output_file:
        output_file.write(raw + "\n")
print("Fixture checks completed, including preserved-history replanning.")
