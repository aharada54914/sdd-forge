#!/usr/bin/env python3
"""T-006 driver shared by the POSIX and PowerShell twins for
`resolve-project-context-lite` (design.md Test Strategy item 4, TEST-009/
AC-009): the B5-narrowed non-Blocking Lite-track states -- **advisory-
missing** (`capability_enforcement == advisory`, a matched Capability's
own `lite_policy.required_lite_checks` key absent, contributing `[]`) and
**zero-match** (no matched Capability, either enforcement state) -- each
confirming the written `capability-summary.yaml` validates via the REAL
`validate-capability-summary.py` (Epic A4) AND that this same invocation
writes neither `facet-manifest.yaml` nor `project-context.resolved.json`
(track-exclusive publication set, B4).

Reuses `tests/resolve-project-context-block-check.py`'s own already-
established fixture-repo/dependency-planting helpers (`Counts`,
`install_scripts`, `install_t003_dependencies`, `plant_sentinels`,
`git_commit_all`, `t003_resolver_argv`, `read_evidence`,
`check_evidence_schema`), loaded by path via the identical `_load_module`
technique `tests/resolve-project-context-match-check.py` already uses --
never re-implemented.

**Disclosed structural constraint, restated from `tests/resolve-project-
context-match-check.py`'s own module docstring (this Epic's own
established convention -- see also this task's own implementation
report):** T-002/T-003/T-004 already established -- and this task's own
Depends On text repeats -- that this Resolver's steps 0-13 are staged-
only: a clean resolve (exit 0) writes NOTHING to any live path at all
(`resolve-project-context.py`'s own module docstring), including
Resolver Evidence itself; live publication of every artifact (Full-track
OR Lite-track) is entirely T-007's own step-14 scope, not yet landed on
this branch. This means AC-009's own "the written `capability-summary.
yaml` validates" cannot be observed from a genuinely clean (non-Blocked)
real subprocess run TODAY -- there is no live file to read. Each fixture
below therefore reuses the IDENTICAL, already-disclosed technique T-005's
own `run_full_pipeline_match_case` already established for the Full
track: force the deliberate, already-established `snapshot-generation-
mismatch` Block at step 13 (the two-fixed-digest `generate-registry-
digest` stub) so this invocation's own `capability_evaluations[]` becomes
observable via the Resolver Evidence a Block reached at/after step 10
DOES publish live (T-004's own "late Blocks carry provenance"
remediation) -- reaching step 13 is itself load-bearing, since it proves
step 10b's own Capability Summary assembly and step 12's own output-
schema self-validation against the REAL `capability-summary.schema.json`
already succeeded (a failure at either step would Block earlier, with a
DIFFERENT diagnostic id, instead). This driver then loads the SAME staged
`resolve-project-context.py` file the real subprocess run also executed
(via `importlib`, never a second, reimplemented copy of its logic) and
calls its own already-tested, unmodified `_assemble_capability_summary`
directly, fed the EXACT `capability_evaluations` that SAME real subprocess
run already produced -- this is not mocking the engine under test, it is
a secondary, disclosed oracle-reconstruction step used only to make an
otherwise print-only/publication-deferred internal computation
assertable, exactly as `run_full_pipeline_match_case` already does for
the Facet Manifest. The B4 track-exclusivity half (neither
`facet-manifest.yaml` nor `project-context.resolved.json` is EVER written,
Block or clean) is asserted directly against the real subprocess's own
sentinel files, which is fully observable without any oracle step at
all."""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/capability-resolver/resolve-project-context-lite"
VALIDATE_CAPABILITY_SUMMARY = ROOT / "plugins/sdd-quality-loop/scripts/validate-capability-summary.py"

SNAPSHOT_MISMATCH_DETAIL = (
    "a pre-publication recheck of the Project Context, Registry, or "
    "ownership-source snapshot detected drift since this invocation's own snapshot"
)
SNAPSHOT_MISMATCH_LINE = f"capability-resolver: snapshot-generation-mismatch: {SNAPSHOT_MISMATCH_DETAIL}\n"


def _load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# Reused, not reinvented (module docstring, above): T-002/T-003/T-004's own
# fixture-repo/dependency-planting helpers.
block_check = _load_module(
    Path(__file__).resolve().parent / "resolve-project-context-block-check.py",
    "resolve_project_context_block_check_for_lite",
)


def _validate_capability_summary(document):
    """AC-009: validates a reconstructed Capability Summary via the REAL,
    already-landed Epic A4 `validate-capability-summary` (never this
    driver's own re-implementation of its schema checks) -- mirrors
    `resolve-project-context-match-check.py`'s own `_validate_facet_
    manifest` helper for the Facet Manifest side of the identical
    discipline."""
    fd, name = tempfile.mkstemp(suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(document, handle)
        return subprocess.run(
            [sys.executable, str(VALIDATE_CAPABILITY_SUMMARY), "--summary", name],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, cwd=str(ROOT),
        )
    finally:
        os.unlink(name)


def _run_lite_case(case_name, kind, resolver_module, counts, zero_affected_components):
    fixture_dir = FIXTURES / case_name
    with tempfile.TemporaryDirectory(prefix=f"resolver-lite-{case_name}-") as tmp:
        repo = Path(tmp).resolve()
        subprocess.run(["git", "init", "-q", str(repo)], check=True, capture_output=True)
        scripts = block_check.install_scripts(repo)
        feature_dir, sentinels = block_check.plant_sentinels(repo, scripts)
        shutil.copy2(fixture_dir / "project-context.yaml", repo / "project-context.yaml")
        registry_path = fixture_dir / "capability-registry.json"
        block_check.install_t003_dependencies(
            repo, scripts, fixture_dir, stub_name="generate-registry-digest.py",
            registry_capabilities_path=registry_path,
        )

        (repo / "README.md").write_text("baseline\n", encoding="utf-8")
        base_oid = block_check.git_commit_all(repo, "baseline")
        if zero_affected_components:
            # Every declared component's own `paths.include` glob
            # (`comp-a/**`) is deliberately left untouched between these two
            # commits; the only path that changes is `README.md` at the
            # repository root, which no glob matches -- the identical
            # real, unstubbed `resolve-component-paths` technique `run_
            # zero_affected_component_case` (match-check.py) already
            # establishes.
            (repo / "README.md").write_text("baseline\nsecond line, still root-only\n", encoding="utf-8")
        else:
            (repo / "comp-a").mkdir()
            (repo / "comp-a/file.txt").write_text("a\n", encoding="utf-8")
        target_oid = block_check.git_commit_all(repo, "add comp-a" if not zero_affected_components else "touch README.md only")

        argv = block_check.t003_resolver_argv(kind, scripts, base_oid, target_oid)
        result = subprocess.run(argv, cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        counts.check(
            result.returncode == 1 and stdout == "" and stderr == SNAPSHOT_MISMATCH_LINE,
            f"{case_name}: reaches the forced step-13 snapshot-generation-mismatch Block, proving step 10b's own "
            f"Capability Summary assembly and step 12's own real capability-summary.schema.json self-validation "
            f"already succeeded (steps 0-12 all passed)",
            f"got exit {result.returncode} stdout={stdout!r} stderr={stderr!r}",
        )

        evidence_path = feature_dir / "resolver-evidence.yaml"
        evidence, parse_error = block_check.read_evidence(evidence_path)
        if not isinstance(evidence, dict):
            counts.check(False, f"{case_name}: Resolver Evidence readable", parse_error or repr(evidence))
            return
        block_check.check_evidence_schema(counts, evidence_path, case_name)

        state = evidence.get("state")
        capability_evaluations = evidence.get("capability_evaluations")
        counts.check(
            isinstance(capability_evaluations, list),
            f"{case_name}: Resolver Evidence publishes capability_evaluations[] (late-Block provenance, T-004)",
            repr(capability_evaluations),
        )

        registry_document = json.loads(registry_path.read_text(encoding="utf-8"))
        track_artifact = resolver_module._assemble_capability_summary(
            "example-feature", registry_document, capability_evaluations or [], state,
        )

        # --- AC-009: written capability-summary.yaml validates ----------
        validate_result = _validate_capability_summary(track_artifact)
        counts.check(
            validate_result.returncode == 0,
            f"{case_name}: the reconstructed capability-summary.yaml validates via the REAL "
            f"validate-capability-summary (AC-009)",
            validate_result.stdout.decode("utf-8", errors="replace") + validate_result.stderr.decode("utf-8", errors="replace"),
        )
        counts.check(
            track_artifact.get("track") == "lite" and track_artifact.get("schema") == "sdd-capability-summary/v1",
            f"{case_name}: track_artifact is genuinely a Capability Summary shape (schema/track fields)",
            repr(track_artifact),
        )

        # --- B4: track-exclusive output set ------------------------------
        # `plant_sentinels` seeds facet-manifest.yaml/capability-summary.yaml/
        # generated/project-context.resolved.json with known preimage bytes
        # before this invocation runs; every one of the three must remain
        # byte-unchanged (this Resolver's own staged-only regime today
        # never live-publishes ANY of them, Block or clean -- T-007's own
        # not-yet-landed scope -- so this assertion is also, structurally,
        # today's strongest available proof of B4's own "never both, and
        # never the Full-track artifacts on a Lite resolve" guarantee).
        unchanged = all(path.read_bytes() == value for path, value in sentinels.items())
        counts.check(
            unchanged,
            f"{case_name}: no facet-manifest.yaml/capability-summary.yaml/project-context.resolved.json ever "
            f"reaches a live path on this Lite-track invocation (B4/AC-009)",
            repr({str(p): p.read_bytes() for p in sentinels}),
        )
        return capability_evaluations


def run_advisory_missing_case(kind, resolver_module, counts):
    """AC-009(a): `capability_enforcement == advisory`, cap-alpha's own
    trigger matches the sole affected component, and its own `lite_policy`
    carries no `required_lite_checks` key at all -- the real-world state of
    every schema-conformant Registry today (investigation.md INV-019) --
    contributing `[]`, never Blocking `lite-check-source-undefined`."""
    case_name = "advisory-missing"
    capability_evaluations = _run_lite_case(case_name, kind, resolver_module, counts, zero_affected_components=False)
    if capability_evaluations is None:
        return
    cap_alpha = next((e for e in capability_evaluations if e["capability_id"] == "cap-alpha"), None)
    counts.check(
        cap_alpha is not None and cap_alpha.get("matched") is True,
        f"{case_name}: fixture sanity -- cap-alpha's own trigger genuinely matches the sole affected component "
        f"comp-a (characteristics.pii == true)",
        repr(cap_alpha),
    )
    registry_document = json.loads((FIXTURES / case_name / "capability-registry.json").read_text(encoding="utf-8"))
    track_artifact = resolver_module._assemble_capability_summary(
        "example-feature", registry_document, capability_evaluations, "advisory",
    )
    counts.check(
        track_artifact["capabilities"] == ["cap-alpha"] and track_artifact["required_lite_checks"] == [],
        f"{case_name}: cap-alpha's own absent required_lite_checks key contributes [] under advisory "
        f"enforcement, never Blocking (AC-009(a))",
        repr(track_artifact),
    )


def run_zero_match_case(kind, resolver_module, counts):
    """AC-009(b): `capability_enforcement == required`, but zero affected
    components (the real, unstubbed zero-affected-component Edge Case, M9)
    means zero matched Capabilities regardless of cap-alpha's own
    lite_policy shape -- `_assemble_capability_summary`'s own per-matched-
    Capability loop never executes, so `LiteCheckSourceUndefined` never
    fires even under `required` enforcement (design.md Test Strategy item
    4: "reachable under either enforcement state")."""
    case_name = "zero-match"
    capability_evaluations = _run_lite_case(case_name, kind, resolver_module, counts, zero_affected_components=True)
    if capability_evaluations is None:
        return
    counts.check(
        all(e.get("matched") is False for e in capability_evaluations),
        f"{case_name}: fixture sanity -- zero matched Capabilities (zero affected components)",
        repr(capability_evaluations),
    )
    registry_document = json.loads((FIXTURES / case_name / "capability-registry.json").read_text(encoding="utf-8"))
    track_artifact = resolver_module._assemble_capability_summary(
        "example-feature", registry_document, capability_evaluations, "required",
    )
    counts.check(
        track_artifact["capabilities"] == [] and track_artifact["required_lite_checks"] == []
        and track_artifact["full_upgrade_required"] is False,
        f"{case_name}: zero matched Capabilities is vacuously capabilities: []/required_lite_checks: []/"
        f"full_upgrade_required: false, never Blocking lite-check-source-undefined even under required "
        f"enforcement (AC-009(b))",
        repr(track_artifact),
    )


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--launcher", choices=("sh", "ps1"), required=True)
    args = parser.parse_args()
    counts = block_check.Counts()

    required_files = [block_check.STAGED / f"resolve-project-context.{suffix}" for suffix in ("py", "sh", "ps1")]
    if not all(path.is_file() for path in required_files):
        counts.check(False, "staged implementation exists", "TDD RED: implementation absent")
    else:
        resolver_module = _load_module(block_check.STAGED / "resolve-project-context.py", "resolve_project_context_oracle_lite")
        run_advisory_missing_case(args.launcher, resolver_module, counts)
        run_zero_match_case(args.launcher, resolver_module, counts)

    sh_registered = "tests/resolve-project-context-lite.tests.sh" in (ROOT / "tests/run-all.sh").read_text(encoding="utf-8")
    ps_registered = "tests/resolve-project-context-lite.tests.ps1" in (ROOT / "tests/run-all.ps1").read_text(encoding="utf-8")
    counts.check(sh_registered, "POSIX suite registered in tests/run-all.sh")
    counts.check(ps_registered, "PowerShell suite registered in tests/run-all.ps1")

    print(f"RESULT: {counts.passed} passed, {counts.failed} failed")
    return 1 if counts.failed else 0


if __name__ == "__main__":
    sys.exit(main())
