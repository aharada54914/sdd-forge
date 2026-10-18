"""Record stable source, identity and input preservation (never raw host event logs)."""

from pathlib import Path
import hashlib
import json
import datetime

ROOT = Path.cwd()
OUT = ROOT / "specs/cloud-orchestration/verification/T-006/attempt-3"
SCRATCH = Path("/tmp/cloud-T006-01a14e9b")
ID = "01a14e9b-59d8-7aa1-b988-8c2551229993"


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


allocation = json.loads((OUT / "native-allocation.json").read_text())
assert allocation["thread"]["id"] == allocation["thread"]["sessionId"] == ID
assert allocation["model"] == "gpt-6-astra" and allocation["reasoningEffort"] == "high"
(OUT / "identity-binding.json").write_text(
    json.dumps(
        dict(
            run_id=ID,
            session_id=ID,
            agent_instance_id=ID,
            provider="openai",
            model="gpt-6-astra",
            effort="high",
            model_tier="strong",
            isolation_mode="fresh-agent",
            scratch_root=str(SCRATCH),
            native_allocation_sha256=sha(OUT / "native-allocation.json"),
            spec_revision=json.loads((OUT / "entry.json").read_text())["spec_revision"],
        ),
        indent=2,
    )
    + "\n"
)
paths = [
    "specs/cloud-orchestration/" + name + ".md"
    for name in (
        "requirements",
        "design",
        "acceptance-tests",
        "traceability",
        "ux-spec",
        "frontend-spec",
        "infra-spec",
        "security-spec",
        "investigation",
        "tasks",
    )
]
paths += ["specs/cloud-orchestration/verification/T-006/second-handoff-report.md"]
rows = [
    dict(
        path=p, entry_sha256=sha(SCRATCH / "initial" / p), current_sha256=sha(ROOT / p)
    )
    for p in paths
]
assert all(r["entry_sha256"] == r["current_sha256"] for r in rows)
assert (
    rows[-1]["current_sha256"]
    == "764fd017ceec3191755013410be84789f8bf9465f3a8a38686e01fcbc78cfcd1"
)
(OUT / "preservation.json").write_text(
    json.dumps(
        dict(
            recorded_at=datetime.datetime.now(datetime.timezone.utc).strftime(
                "%Y-%m-%dT%H:%M:%SZ"
            ),
            fields=rows,
        ),
        indent=2,
    )
    + "\n"
)
