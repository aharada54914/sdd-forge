"""Test-data fixture helper: seeds synthetic canonical feature data under an installed fixture project.

Fixture data only. It asserts no real review or adoption. It never writes the CURRENT stage
precheck-result.json; the real <stage>-review-precheck.sh does that.
"""
import hashlib
import json
from pathlib import Path

SPEC_CAL = "plugins/sdd-review-loop/references/spec-review-calibration.md"
IMPL_CAL = "plugins/sdd-review-loop/references/reviewer-calibration.md"
LAYERS = ("ux-spec.md", "frontend-spec.md", "infra-spec.md", "security-spec.md")

TASKS = """# Tasks

Task-Review-Status: Pending

## T-001 First
Approval: Draft
Risk: low
Risk Rationale: Fixture coverage for dependency graph parsing.
Required Workflow: test-after
### Blockers
None

## T-002 Second
Approval: Draft
Risk: low
Risk Rationale: Fixture coverage for dependency graph parsing.
Required Workflow: test-after
### Blockers
T-001
"""


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _json(path: Path, data) -> None:
    _write(path, json.dumps(data, indent=2) + "\n")


def _pass_artifacts(root: Path, feature: str, stage: str) -> None:
    """Same shape as write_pass_artifacts in the legacy task-precheck fixture (attempt 1, round 1)."""
    spec = root / "specs" / feature
    rel_dir = f"reports/{stage}-review/{feature}/attempt-1/round-1"
    out = root / rel_dir
    _write(out / "precheck-result.json", "{}\n")
    _write(out / "integrated-summary.json", "{}\n")
    cal = SPEC_CAL if stage == "spec" else IMPL_CAL
    if stage == "spec":
        verdict = {"schema": "spec-review-integrated-verdict/v1", "stage": "spec", "feature": feature,
                   "attempt": 1, "round": 1, "verdict": "PASS",
                   "reviewer_a_run_id": "spec-a-run", "reviewer_b_run_id": "spec-b-run",
                   "reviewer_a_host_session_id": "spec-a-session",
                   "reviewer_b_host_session_id": "spec-b-session",
                   "finding_count": 0, "warning_count": 0}
    else:
        verdict = {"schema": "integrated-verdict/v1", "stage": stage, "feature": feature,
                   "attempt": 1, "round": 1, "run_id": f"{stage}-contract-run", "verdict": "PASS"}
    _json(out / "integrated-verdict.json", verdict)

    def entry(rel: str, abs_path: Path) -> dict:
        return {"path": rel, "sha256": _sha(abs_path)}

    shared = [entry(f"specs/{feature}/requirements.md", spec / "requirements.md"),
              entry(f"specs/{feature}/acceptance-tests.md", spec / "acceptance-tests.md"),
              entry(cal, root / cal),
              entry(f"{rel_dir}/precheck-result.json", out / "precheck-result.json")]
    if stage == "impl":
        shared.append(entry(f"specs/{feature}/design.md", spec / "design.md"))
    summary = entry(f"{rel_dir}/integrated-summary.json", out / "integrated-summary.json")
    _json(out / f"{stage}-review-contract.json", {
        "schema": f"{stage}-review-contract/v1", "stage": stage, "feature": feature,
        "attempt": 1, "round": 1, "run_id": f"{stage}-contract-run", "verdict": "PASS",
        "reviewers": [
            {"role": f"{stage}-reviewer-a", "run_id": f"{stage}-a-run",
             "host_session_id": f"{stage}-a-session", "allowed_input_manifest": shared},
            {"role": f"{stage}-reviewer-b", "run_id": f"{stage}-b-run",
             "host_session_id": f"{stage}-b-session", "allowed_input_manifest": shared + [summary]},
        ]})


def seed(root: Path, feature: str, stage: str) -> None:
    if stage not in ("impl", "task"):
        raise ValueError(f"stage must be impl or task, got {stage!r}")
    root = Path(root)
    spec = root / "specs" / feature
    for cal in (SPEC_CAL, IMPL_CAL):
        if not (root / cal).is_file():
            raise FileNotFoundError(f"installed calibration missing: {root / cal}")

    registry = root / "specs" / "workflow-state-registry.json"
    reg = json.loads(registry.read_text(encoding="utf-8"))
    reg["entries"] = [e for e in reg.get("entries", []) if e.get("feature") != feature]
    reg["entries"].append({"feature": feature, "profile": "lite"})
    _json(registry, reg)

    _write(spec / "requirements.md", "Spec-Review-Status: Passed\n")
    _write(spec / "acceptance-tests.md", "# Acceptance Tests\n")
    for name in LAYERS:
        _write(spec / name, f"# {name}\n\nLegacy fixture layer text.\n")

    # Source bytes are final before any hash below is computed.
    if stage == "impl":
        _write(spec / "design.md", "Impl-Review-Status: Pending\n")
        _pass_artifacts(root, feature, "spec")
    else:
        _write(spec / "design.md", "Impl-Review-Status: Passed\n")
        _write(spec / "tasks.md", TASKS)
        _write(spec / "traceability.md", "# Traceability\n")
        _pass_artifacts(root, feature, "spec")
        _pass_artifacts(root, feature, "impl")
