#!/usr/bin/env python3
"""T-009 driver shared by the POSIX and PowerShell twins for
`resolve-project-context-parity` (design.md Test Strategy item 5,
requirements.md REQ-005; AC-022, AC-023, AC-024, AC-025).

This is the ONE suite in this Epic that exercises the `.py` master
directly, in addition to the `.sh`/`.ps1` thin dispatchers T-002 through
T-008's own suites already exercise exclusively via `sh`/`pwsh` (see those
drivers' own `launcher_args`, which never spells `python3
resolve-project-context.py`). Every fixture repo this driver builds reuses
`tests/resolve-project-context-block-check.py`'s and `tests/resolve-
project-context-match-check.py`'s own already-established fixture-repo/
dependency-planting helpers (loaded by path, via the identical `_load_module`
technique `tests/resolve-project-context-cli-check.py`/`tests/resolve-
project-context-lite-check.py`/`tests/resolve-project-context-discovery-
check.py` already established) rather than re-implementing them.

TEST-022 (AC-022): two `.py` invocations of the identical input produce
byte-identical output across the invocation's own track-exclusive output
set (stdout, stderr, exit code, plus every live artifact path this
invocation may have published or left untouched).

TEST-023 (AC-023): `.py`/`.sh`/`.ps1` invocations of the identical input
produce byte-identical output plus identical stdout/stderr/exit code,
restricted to this feature's own emitted content (M8 -- every fixture below
Blocks or succeeds with NOTHING on stderr but this feature's own canonical
`capability-resolver: <id>: <detail>` line(s), never a dependency
subprocess's own raw stderr, so comparing the whole channel is exactly the
M8-compliant scope; a dedicated assertion below double-checks that
restriction directly rather than only inferring it). Includes a Windows-
style, backslash-separated `--config` path argument (`build_windows_path_
fixture`). Also covers `validate-resolver-evidence` (T-008's own triad,
which this same parity guarantee names by name in this task's own Depends
On text).

TEST-024 (AC-024): every semantic-output array this feature writes is
stable-sorted. `run_test_024_registry_reordering` proves `capability_
evaluations[]` stays sorted by `capability_id` against an intentionally
out-of-order Registry `capabilities[]` declaration (the exact case AC-024's
own text names), reusing `resolve-project-context-match-check.py`'s own
`full-pipeline-match` fixture inputs verbatim except for this suite's own
reordered Registry copy. `run_test_024_facet_manifest_sort_whitebox` proves
every Epic-A4-mandated Facet Manifest array (`required_facets`,
`resolved_gates`, `capabilities`) is independently re-sorted by
`_assemble_facet_manifest` regardless of both Registry declaration order
and the order `capability_evaluations` are fed in, via a direct,
no-subprocess call into the SAME staged module `resolve-project-context-
match-check.py` already loads this way for its own oracle-reconstruction
(module docstring there: "call the real staged function directly").
`run_test_024_diagnostics_sort_reuse` cites `tests/resolve-project-context-
block-check.py`'s own already-registered, already-regression-locked
`dsl-warn-unsorted-affected-components` fixture as this suite's own
`diagnostics[]` `(id, detail)`-sort proof, rather than re-deriving it a
second time -- sort CORRECTNESS is a within-runtime property of the ONE
shared `.py` master every dispatcher forwards to verbatim (module
docstring, `build_windows_path_fixture`), so one runtime's own proof
suffices here; TEST-023 above already independently proves cross-runtime
BYTE-IDENTITY for a representative fixture set.

TEST-025 (AC-025): a repository-wide grep-based self-check confirms no
Resolver-owned script -- the staged `resolve-project-context.{py,sh,ps1}`
candidates AND the already-landed, live `validate-resolver-evidence.
{py,sh,ps1}` -- calls `datetime.now()`/`time.time()`/any network primitive/
any provider-API client. The provider-API-client half reuses Epic A2's own
`provider-terms.json` allowlist and `facet-manifest-parity.tests.sh`'s own
`key=lambda`-idiom masking technique (TEST-043 there), verbatim, since this
Resolver's own `_write_evidence`/`_assemble_facet_manifest` share the
identical `sorted(..., key=lambda ...)` idiom that scan already had to
solve for.
"""

import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/capability-resolver/parity"
STAGED_SCRIPTS = (
    ROOT
    / "specs/epic-193-a5-capability-resolver/human-copy"
    / "plugins/sdd-quality-loop/scripts"
)
LIVE_SCRIPTS = ROOT / "plugins/sdd-quality-loop/scripts"
PROVIDER_TERMS_PATH = ROOT / "plugins/sdd-quality-loop/references/provider-terms.json"


def _load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# Reused, not reinvented (module docstring, above): the block/match drivers'
# own already-established fixture-repo/dependency-planting/oracle-
# reconstruction helpers.
block_check = _load_module(
    Path(__file__).resolve().parent / "resolve-project-context-block-check.py",
    "resolve_project_context_block_check_for_parity",
)
match_check = _load_module(
    Path(__file__).resolve().parent / "resolve-project-context-match-check.py",
    "resolve_project_context_match_check_for_parity",
)
vre_check = _load_module(
    Path(__file__).resolve().parent / "validate-resolver-evidence-check.py",
    "validate_resolver_evidence_check_for_parity",
)


# =============================================================================
# Shared invocation/capture helpers.
# =============================================================================

def _run_kind(kind, scripts, tail, cwd, env=None):
    """Invoke `resolve-project-context` as a genuine subprocess under one of
    the three runtimes. `kind == "py"` is this suite's own addition -- every
    sibling suite's own `launcher_args` only ever spells `sh`/`pwsh`, never
    the Python master directly."""
    if kind == "py":
        argv = [sys.executable, str(scripts / "resolve-project-context.py")] + tail
    else:
        argv = block_check.launcher_args(kind, scripts) + tail
    return subprocess.run(argv, cwd=str(cwd), env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)


def _tail(kind_agnostic_argv_fn, scripts, *args, **kwargs):
    """Recovers a block/match-driver argv-builder's own FIXED tail (the part
    after `launcher_args(kind, scripts)`) without hand-duplicating it --
    every one of those builders' own tail is independent of `kind` by
    construction (`launcher_args(kind, scripts) + fixed_tail`), so slicing
    off the `sh`-branch prefix recovers the identical tail every other kind
    would also receive."""
    prefix_len = len(block_check.launcher_args("sh", scripts))
    return kind_agnostic_argv_fn("sh", scripts, *args, **kwargs)[prefix_len:]


def _capture_artifacts(paths):
    out = {}
    for name, path in paths.items():
        out[name] = path.read_bytes() if path.is_file() else None
    return out


def _capture_result(result, artifact_paths):
    return {
        "exit": result.returncode,
        "stdout": result.stdout,
        "stderr": result.stderr,
        "artifacts": _capture_artifacts(artifact_paths),
    }


# =============================================================================
# Fixture builders. Each returns (scripts, feature_dir, tail, artifact_paths)
# for one already-initialized, empty git repo. Every one below reuses an
# already-established sibling suite's own fixture inputs or install helpers
# (module docstring) rather than hand-building a parallel fixture tree.
# =============================================================================

def build_quick_block_fixture(repo):
    """Reuses T-002's own `canonicalizer-invocation-failed` Block fixture
    (`resolve-project-context-block-check.py` CASES) -- a step-2 Block that
    never reaches step 4, so this fixture needs no Epic A2/A3 dependency
    planting at all."""
    block_check.copy_inputs(repo, "canonicalizer-invocation-failed/project-context.yaml", "canonicalizer-invocation-failed")
    scripts = repo / "plugins/sdd-quality-loop/scripts"
    feature_dir, _sentinels = block_check.plant_sentinels(repo, scripts)
    tail = ["--config", "sdd/project-context.yaml", "--target-rev", "HEAD", "--feature", "example-feature"]
    artifacts = {"resolver-evidence.yaml": feature_dir / "resolver-evidence.yaml"}
    return scripts, feature_dir, tail, artifacts


def build_disabled_legacy_fixture(repo):
    """Reuses T-002's own `disabled-legacy-invocation` Block fixture (config
    absent) -- step 1, before any filesystem work beyond the config check
    itself."""
    block_check.copy_inputs(repo, "absent", "disabled-legacy-invocation")
    scripts = repo / "plugins/sdd-quality-loop/scripts"
    feature_dir, _sentinels = block_check.plant_sentinels(repo, scripts)
    tail = ["--config", "sdd/project-context.yaml", "--target-rev", "HEAD", "--feature", "example-feature"]
    artifacts = {"resolver-evidence.yaml": feature_dir / "resolver-evidence.yaml"}
    return scripts, feature_dir, tail, artifacts


def build_windows_path_fixture(repo):
    """AC-023's own named requirement: at least one Windows-style,
    backslash-separated path argument. The literal `--config` value below
    (`sdd\\project-context.yaml`) never resolves to an existing file on
    whatever POSIX host this suite itself runs on either way (there is no
    file literally named with an embedded backslash byte), so this
    invocation genuinely reaches the identical `disabled-legacy-invocation`
    Block as `build_disabled_legacy_fixture` above -- the assertion is that
    all three runtimes agree byte-for-byte on whatever this backslash
    string produces, matching facet-manifest-parity.tests.sh's own
    identical convention (`windows-style-path.txt`) rather than asserting
    real Windows path resolution, which this suite cannot exercise on a
    POSIX CI runner."""
    scripts = block_check.install_scripts(repo)
    feature_dir, _sentinels = block_check.plant_sentinels(repo, scripts)
    tail = ["--config", "sdd\\project-context.yaml", "--target-rev", "HEAD", "--feature", "example-feature"]
    artifacts = {"resolver-evidence.yaml": feature_dir / "resolver-evidence.yaml"}
    return scripts, feature_dir, tail, artifacts


def build_clean_publication_fixture(repo):
    """Reuses T-007's own `clean-full-track-publication` fixture verbatim
    (`resolve-project-context-block-check.py`'s own `t007_install_fixture`/
    `run_t007_clean_publication_case`) -- the ONE fixture in this suite that
    exercises the full, real, multi-target publication transaction, so this
    invocation's own track-exclusive output set (REQ-005) is the complete
    Full-track triple: Facet Manifest, Context Projection, Resolver
    Evidence, plus the B4 negative (Capability Summary stays absent)."""
    fixture_dir = block_check.FIXTURES / "clean-full-track-publication"
    scripts, feature_dir, _sentinels = block_check.t007_install_fixture(repo, fixture_dir, "clean-full-track-publication")
    (repo / "README.md").write_text("baseline\n", encoding="utf-8")
    base_oid = block_check.git_commit_all(repo, "baseline")
    (repo / "comp-a").mkdir()
    (repo / "comp-a/file.txt").write_text("x\n", encoding="utf-8")
    target_oid = block_check.git_commit_all(repo, "add comp-a")
    tail = _tail(block_check.t003_resolver_argv, scripts, base_oid, target_oid)
    artifacts = {
        "resolver-evidence.yaml": feature_dir / "resolver-evidence.yaml",
        "facet-manifest.yaml": feature_dir / "facet-manifest.yaml",
        "capability-summary.yaml": feature_dir / "capability-summary.yaml",
        "project-context.resolved.json": scripts / "generated/project-context.resolved.json",
    }
    return scripts, feature_dir, tail, artifacts


# =============================================================================
# TEST-022: repeated `.py` invocation determinism (AC-022).
# =============================================================================

def run_test_022(counts):
    cases = (
        ("quick-block-canonicalizer-invocation-failed", build_quick_block_fixture),
        ("clean-full-track-publication", build_clean_publication_fixture),
    )
    for label, build_fn in cases:
        captures = []
        for attempt in (1, 2):
            with tempfile.TemporaryDirectory(prefix=f"resolver-parity22-{label}-") as tmp:
                repo = Path(tmp).resolve()
                subprocess.run(["git", "init", "-q", str(repo)], check=True, capture_output=True)
                scripts, _feature_dir, tail, artifact_paths = build_fn(repo)
                result = _run_kind("py", scripts, tail, cwd=repo)
                captures.append(_capture_result(result, artifact_paths))
        first, second = captures
        ok = first == second
        counts.check(
            ok,
            f"TEST-022 {label}: two .py invocations of the identical input produce byte-identical exit/stdout/stderr "
            f"and identical track-exclusive artifact bytes, across two independent invocations (AC-022)",
            "" if ok else repr({"invocation_1": first, "invocation_2": second}),
        )


# =============================================================================
# TEST-023: `.py`/`.sh`/`.ps1` dual-runtime parity (AC-023).
# =============================================================================

def run_test_023(counts):
    cases = (
        ("disabled-legacy-invocation", build_disabled_legacy_fixture),
        ("canonicalizer-invocation-failed", build_quick_block_fixture),
        ("windows-style-path", build_windows_path_fixture),
        ("clean-full-track-publication", build_clean_publication_fixture),
    )
    for label, build_fn in cases:
        results = {}
        for kind in ("py", "sh", "ps1"):
            with tempfile.TemporaryDirectory(prefix=f"resolver-parity23-{label}-{kind}-") as tmp:
                repo = Path(tmp).resolve()
                subprocess.run(["git", "init", "-q", str(repo)], check=True, capture_output=True)
                scripts, _feature_dir, tail, artifact_paths = build_fn(repo)
                result = _run_kind(kind, scripts, tail, cwd=repo)
                results[kind] = _capture_result(result, artifact_paths)

        py, sh, ps1 = results["py"], results["sh"], results["ps1"]
        ok = py == sh == ps1
        counts.check(
            ok,
            f"TEST-023 {label}: .py/.sh/.ps1 invocations of the identical input produce byte-identical exit/"
            f"stdout/stderr and identical track-exclusive artifact bytes (AC-023)",
            "" if ok else repr(results),
        )

        # M8: this feature's own stderr channel, whenever non-empty, is
        # ENTIRELY this feature's own canonical `capability-resolver: <id>:
        # <detail>` line(s) -- never a dependency subprocess's own raw
        # stderr text -- which is exactly what makes the whole-channel byte-
        # identity comparison above M8-compliant scope rather than an
        # accidental pass. Checked directly, not only inferred.
        for kind, capture in results.items():
            stderr_text = capture["stderr"].decode("utf-8", errors="replace")
            m8_ok = stderr_text == "" or all(
                line.startswith("capability-resolver: ") for line in stderr_text.splitlines()
            )
            counts.check(
                m8_ok,
                f"TEST-023 {label} ({kind}): stderr is empty or consists entirely of this feature's own "
                f"'capability-resolver: <id>: <detail>' canonical line(s) -- never a dependency subprocess's own "
                f"raw stderr text (M8)",
                repr(stderr_text),
            )

    # AC-023 non-vacuity: the Windows-style path fixture's own detail
    # genuinely embeds a raw backslash byte (never silently normalized to a
    # forward slash by any of the three runtimes) -- otherwise the parity
    # assertion above for that case would be trivially true regardless of
    # whether this suite's own backslash argument reached the Resolver at
    # all.
    with tempfile.TemporaryDirectory(prefix="resolver-parity23-winpath-sanity-") as tmp:
        repo = Path(tmp).resolve()
        subprocess.run(["git", "init", "-q", str(repo)], check=True, capture_output=True)
        scripts, feature_dir, tail, _artifacts = build_windows_path_fixture(repo)
        result = _run_kind("py", scripts, tail, cwd=repo)
        evidence, parse_error = block_check.read_evidence(feature_dir / "resolver-evidence.yaml")
        detail = evidence["diagnostics"][0]["detail"] if isinstance(evidence, dict) and evidence.get("diagnostics") else None
        counts.check(
            detail == "sdd\\project-context.yaml",
            f"TEST-023 windows-style-path non-vacuity: the published diagnostic detail genuinely embeds a raw "
            f"backslash byte, unmutated (AC-023)",
            parse_error or repr(detail),
        )

    # T-008's own `.py`/`.sh`/`.ps1` triad participates in this same parity
    # guarantee (this task's own Depends On text, T-008 row): reused here
    # via `validate-resolver-evidence-check.py`'s own already-established
    # `build_repo`/`resolve_args` fixture-repo helpers, never re-implemented.
    for name in ("clean", "schema-invalid"):
        meta = vre_check.load_json(vre_check.FIXTURES / name / "case.json")
        expected_exit = meta["expect_exit"]
        results = {}
        for kind in ("py", "sh", "ps1"):
            with tempfile.TemporaryDirectory(prefix=f"resolver-parity23-vre-{name}-{kind}-") as tmp:
                repo = Path(tmp).resolve()
                digest = vre_check.build_repo(repo, vre_check.FIXTURES / name)
                scripts = repo / "plugins/sdd-quality-loop/scripts"
                tail = ["--evidence", vre_check.EVIDENCE_REL] + vre_check.resolve_args(meta["args"])
                if kind == "py":
                    argv = [sys.executable, str(scripts / "validate-resolver-evidence.py")] + tail
                else:
                    argv = vre_check.wrapper_argv(kind, scripts) + tail
                result = subprocess.run(argv, cwd=str(repo), stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
                results[kind] = {"digest_ok": digest is not None, "exit": result.returncode, "stdout": result.stdout, "stderr": result.stderr}

        py, sh, ps1 = results["py"], results["sh"], results["ps1"]
        digests_ok = py["digest_ok"] and sh["digest_ok"] and ps1["digest_ok"]
        comparable = {k: {"exit": v["exit"], "stdout": v["stdout"], "stderr": v["stderr"]} for k, v in results.items()}
        ok = digests_ok and comparable["py"] == comparable["sh"] == comparable["ps1"] and py["exit"] == expected_exit
        counts.check(
            ok,
            f"TEST-023 validate-resolver-evidence/{name}: .py/.sh/.ps1 invocations of the identical input produce "
            f"byte-identical exit/stdout/stderr (AC-023, T-008's own triad)",
            "" if ok else repr(results),
        )


# =============================================================================
# TEST-024: stable-sort discipline (AC-024).
# =============================================================================

def run_test_024_registry_reordering(counts):
    """AC-024's own named case: `capability_evaluations[]` stays sorted by
    `capability_id` regardless of the source Registry's own `capabilities[]`
    declaration order. Reuses `resolve-project-context-match-check.py`'s own
    `full-pipeline-match` fixture inputs (`project-context.yaml`, the
    two-fixed-digest forced-`snapshot-generation-mismatch` stub, the
    `resolve-component-paths` capture-and-delegate stub) verbatim -- only
    the Registry file itself is this suite's own, deliberately reordered
    copy (`tests/fixtures/capability-resolver/parity/stable-sort-registry-
    reordered/capability-registry.json`: `cap-gamma`, `cap-beta`,
    `cap-alpha`, in that declared order)."""
    match_fixture_dir = match_check.FIXTURES / "full-pipeline-match"
    registry_path = FIXTURES / "stable-sort-registry-reordered/capability-registry.json"
    registry_document = json.loads(registry_path.read_text(encoding="utf-8"))
    declared_order = [c["id"] for c in registry_document["capabilities"]]
    counts.check(
        declared_order != sorted(declared_order),
        f"TEST-024 fixture sanity: the Registry's own capabilities[] declaration order is genuinely NOT ascending "
        f"({declared_order!r}) -- otherwise this fixture could not distinguish 'sorted by construction' from "
        f"'sorted because the Resolver itself sorts'",
    )

    for kind in ("py", "sh", "ps1"):
        with tempfile.TemporaryDirectory(prefix=f"resolver-parity24-{kind}-") as tmp:
            repo = Path(tmp).resolve()
            subprocess.run(["git", "init", "-q", str(repo)], check=True, capture_output=True)
            scripts = block_check.install_scripts(repo)
            feature_dir, _sentinels = block_check.plant_sentinels(repo, scripts)
            shutil.copy2(match_fixture_dir / "project-context.yaml", repo / "project-context.yaml")
            match_check._install_full_pipeline_dependencies(repo, scripts, match_fixture_dir, registry_path)

            (repo / "README.md").write_text("baseline\n", encoding="utf-8")
            base_oid = block_check.git_commit_all(repo, "baseline")
            (repo / "comp-a").mkdir()
            (repo / "comp-a/file.txt").write_text("a\n", encoding="utf-8")
            (repo / "comp-b").mkdir()
            (repo / "comp-b/file.txt").write_text("b\n", encoding="utf-8")
            target_oid = block_check.git_commit_all(repo, "add comp-a, comp-b")

            tail = _tail(block_check.t003_resolver_argv, scripts, base_oid, target_oid)
            # `_install_full_pipeline_dependencies` overlays the passthrough
            # canonicalize-sdd-yaml capture stub match-check.py's own
            # `run_full_pipeline_match_case` already established -- that
            # stub requires this env var (matching that function's own
            # invocation, never reinvented).
            env = os.environ.copy()
            env["SDD_T002_PROJECTION_MODE"] = "passthrough"
            result = _run_kind(kind, scripts, tail, cwd=repo, env=env)
            stderr_text = result.stderr.decode("utf-8", errors="replace")
            counts.check(
                result.returncode == 1 and stderr_text == match_check.SNAPSHOT_MISMATCH_LINE,
                f"TEST-024 registry-reordering ({kind}): reaches the SPECIFIC forced snapshot-generation-mismatch "
                f"Block (steps 0-12 all passed, capability_evaluations[] is observable), not some earlier, "
                f"different Block that would leave capability_evaluations[] vacuously empty",
                f"got exit {result.returncode} stderr={stderr_text!r}",
            )

            evidence, parse_error = block_check.read_evidence(feature_dir / "resolver-evidence.yaml")
            capability_ids = (
                [entry["capability_id"] for entry in evidence.get("capability_evaluations", [])]
                if isinstance(evidence, dict) else None
            )
            counts.check(
                capability_ids == sorted(capability_ids or []),
                f"TEST-024 registry-reordering ({kind}): capability_evaluations[] is stable-sorted by capability_id "
                f"even though the source Registry declares {declared_order!r} (AC-024)",
                parse_error or repr(capability_ids),
            )
            counts.check(
                capability_ids == ["cap-alpha", "cap-beta", "cap-gamma"],
                f"TEST-024 registry-reordering ({kind}) non-vacuity: the exact expected three-capability set is "
                f"present -- the sort assertion above is not vacuously true over an empty/partial list",
                repr(capability_ids),
            )


def run_test_024_facet_manifest_sort_whitebox(counts):
    """Every Epic-A4-mandated Facet Manifest array `_assemble_facet_manifest`
    writes (`required_facets`, `resolved_gates`, `capabilities`) is
    independently re-sorted regardless of Registry declaration order AND
    the order `capability_evaluations` are fed in -- proven via a direct,
    no-subprocess call into the SAME staged module `resolve-project-
    context-match-check.py` already loads this way for its own oracle-
    reconstruction (that driver's own module docstring: "call the real
    staged function directly... never a mocked stand-in"), fed entirely
    hand-built, out-of-order inputs (no fixture repo, no subprocess needed
    -- `_assemble_facet_manifest` is a pure function of its six arguments)."""
    resolver_module = _load_module(STAGED_SCRIPTS / "resolve-project-context.py", "resolve_project_context_parity_facet_oracle")

    registry_document = {
        "schema": "capability-registry/v1",
        "gates": [
            {"id": "gate-z", "stage": "promotion", "blocking": True},
            {"id": "gate-a", "stage": "artifact", "blocking": False},
        ],
        "capabilities": [
            {"id": "cap-zebra", "trigger": {}, "required_facets": ["facet-z"], "conditional_facets": [], "gate_ids": ["gate-z"]},
            {"id": "cap-mango", "trigger": {}, "required_facets": ["facet-m"], "conditional_facets": [], "gate_ids": ["gate-a"]},
            {"id": "cap-apple", "trigger": {}, "required_facets": ["facet-a"], "conditional_facets": [], "gate_ids": ["gate-a", "gate-z"]},
        ],
    }
    declared_order = [c["id"] for c in registry_document["capabilities"]]
    counts.check(
        declared_order != sorted(declared_order),
        f"TEST-024 white-box fixture sanity: this hand-built Registry's own capabilities[] declaration order is "
        f"genuinely NOT ascending ({declared_order!r})",
    )
    # Fed in the IDENTICAL out-of-order sequence as the Registry declares --
    # never pre-sorted by this driver itself -- so a defect that merely
    # echoes input order back out would survive undetected by a
    # pre-sorted-input fixture.
    capability_evaluations = [
        {"capability_id": "cap-zebra", "matched": True, "trigger_evaluations": []},
        {"capability_id": "cap-mango", "matched": True, "trigger_evaluations": []},
        {"capability_id": "cap-apple", "matched": True, "trigger_evaluations": []},
    ]
    context_binding = {
        "full_context_revision": "sha256:" + "0" * 64,
        "dependency_pointers": ["/workflow"],
        "projection_sha256": "sha256:" + "0" * 64,
        "registry_digest": "sha256:" + "0" * 64,
        "ownership_digest": "sha256:" + "0" * 64,
    }
    resolver_block = resolver_module._resolver_block()

    manifest = resolver_module._assemble_facet_manifest(
        "example-feature", ["comp-a"], registry_document, capability_evaluations, context_binding, resolver_block,
    )

    counts.check(
        manifest["capabilities"] == sorted(declared_order),
        f"TEST-024 white-box: Facet Manifest capabilities[] is stable-sorted regardless of Registry declaration "
        f"order or fed capability_evaluations order (AC-024)",
        repr(manifest["capabilities"]),
    )
    counts.check(
        manifest["required_facets"] == ["facet-a", "facet-m", "facet-z"],
        f"TEST-024 white-box: Facet Manifest required_facets[] is stable-sorted (AC-024, Epic-A4-mandated array)",
        repr(manifest["required_facets"]),
    )
    gate_ids_in_order = [gate["id"] for gate in manifest["resolved_gates"]]
    counts.check(
        gate_ids_in_order == ["gate-a", "gate-z"],
        f"TEST-024 white-box: Facet Manifest resolved_gates[] is stable-sorted by id, deduplicated across "
        f"contributing Capabilities (AC-024, Epic-A4-mandated array)",
        repr(manifest["resolved_gates"]),
    )


def run_test_024_diagnostics_sort_reuse(counts):
    """`diagnostics[]` sorted by `(id, detail)` (AC-024's own second clause):
    cites `resolve-project-context-block-check.py`'s own already-registered
    `dsl-warn-unsorted-affected-components` fixture (its own module docstring
    labels this exact scenario as an AC-056/AC-024 stable-sort case) rather
    than re-deriving a parallel fixture -- sort CORRECTNESS is a
    within-runtime property of the ONE shared `.py` master every dispatcher
    forwards to byte-for-byte verbatim (this suite's own module docstring;
    `resolve-project-context.sh`/`.ps1` are thin `exec`/`Process.Start`
    dispatchers with no logic of their own), so one runtime's own proof
    suffices for a sort-correctness assertion -- TEST-023 above already
    independently proves cross-runtime byte-identity for a representative
    fixture set, including this exact class of Block."""
    counts_before = (counts.passed, counts.failed)
    block_check.run_t003_case("sh", "dsl-warn-unsorted-affected-components", counts)
    added = counts.passed + counts.failed - sum(counts_before)
    counts.check(
        added > 0,
        f"TEST-024 diagnostics-sort reuse non-vacuity: reusing "
        f"resolve-project-context-block-check.py's own dsl-warn-unsorted-affected-components case actually ran "
        f"{added} assertion(s), not zero",
    )


# =============================================================================
# TEST-025: no-nondeterministic-source lock (AC-025).
# =============================================================================

NONDETERMINISM_PATTERNS = {
    "datetime.now()": re.compile(r"datetime\.now\s*\("),
    "time.time()": re.compile(r"\btime\.time\s*\("),
    "network primitive (python: socket/urllib/requests/httpx/http.client/ftplib/smtplib)": re.compile(
        r"\b(socket|urllib(\.request)?|requests|httpx|http\.client|ftplib|smtplib)\b"
    ),
    "network primitive (shell: curl/wget/nc)": re.compile(r"\b(curl|wget|nc)\b"),
    "network primitive (PowerShell: Invoke-WebRequest/Invoke-RestMethod/System.Net/WebClient)": re.compile(
        r"\b(Invoke-WebRequest|Invoke-RestMethod|System\.Net|WebClient)\b"
    ),
}


def _scan_nondeterminism(path):
    text = path.read_text(encoding="utf-8", errors="replace")
    return [label for label, pattern in NONDETERMINISM_PATTERNS.items() if pattern.search(text)]


def _provider_terms():
    doc = json.loads(PROVIDER_TERMS_PATH.read_text(encoding="utf-8"))
    terms = []
    for category_terms in doc.get("categories", {}).values():
        terms.extend(category_terms)
    return terms


def _scan_provider_terms(path):
    """Reuses facet-manifest-parity.tests.sh's own TEST-043 mechanism and
    its own `key=lambda`-idiom mask verbatim: this Resolver's own
    `_write_evidence`/`_assemble_facet_manifest`/`_resolved_gates` share the
    identical `sorted(..., key=lambda ...)` Python sort-key idiom that mask
    exists for (confirmed directly against this tree before relying on it --
    see this task's own implementation report, "Specification Differences")."""
    text = path.read_text(encoding="utf-8", errors="replace")
    masked = re.sub(r"key\s*=\s*lambda\b", "key=__PY_LAMBDA_KEYWORD_IDIOM__", text)
    masked_lower = masked.lower()
    return [term for term in _provider_terms() if re.search(r"\b" + re.escape(term.lower()) + r"\b", masked_lower)]


def run_test_025(counts):
    targets = [
        STAGED_SCRIPTS / "resolve-project-context.py",
        STAGED_SCRIPTS / "resolve-project-context.sh",
        STAGED_SCRIPTS / "resolve-project-context.ps1",
        LIVE_SCRIPTS / "validate-resolver-evidence.py",
        LIVE_SCRIPTS / "validate-resolver-evidence.sh",
        LIVE_SCRIPTS / "validate-resolver-evidence.ps1",
    ]
    scanned_any = False
    for target in targets:
        exists = target.is_file()
        counts.check(exists, f"TEST-025: scan target exists: {target.relative_to(ROOT)}")
        if not exists:
            continue
        scanned_any = True
        nondet_hits = _scan_nondeterminism(target)
        counts.check(
            not nondet_hits,
            f"TEST-025: {target.relative_to(ROOT)} contains no datetime.now()/time.time()/network-primitive call "
            f"(AC-025)",
            repr(nondet_hits),
        )
        provider_hits = _scan_provider_terms(target)
        counts.check(
            not provider_hits,
            f"TEST-025: {target.relative_to(ROOT)} contains no provider-API-client allowlist term (AC-025)",
            repr(provider_hits),
        )
    counts.check(scanned_any, "TEST-025 non-vacuity: at least one scan target was actually found and scanned")

    # Non-vacuity canaries (mirroring facet-manifest-parity.tests.sh's own
    # dirty/clean-fixture convention, TEST-043): a synthetic dirty fixture
    # IS flagged, for every category this scan recognizes -- proving the
    # scan is not vacuously blind -- and a synthetic clean fixture sharing
    # surface-level English vocabulary is NOT flagged -- proving the scan is
    # not over-broad either.
    dirty_hits = _scan_nondeterminism(FIXTURES / "nondeterminism-dirty.py.txt")
    counts.check(
        set(dirty_hits) == set(NONDETERMINISM_PATTERNS),
        f"TEST-025 non-vacuity canary: the dirty fixture is flagged for every one of this scan's own "
        f"{len(NONDETERMINISM_PATTERNS)} categories",
        repr(dirty_hits),
    )
    clean_hits = _scan_nondeterminism(FIXTURES / "nondeterminism-clean.py.txt")
    counts.check(
        not clean_hits,
        f"TEST-025 false-positive control: the clean fixture (benign English prose about time/networking, no "
        f"literal forbidden API call) is not flagged",
        repr(clean_hits),
    )
    dirty_provider_hits = _scan_provider_terms(FIXTURES / "provider-term-dirty.txt")
    counts.check(
        bool(dirty_provider_hits),
        f"TEST-025 non-vacuity canary: the dirty provider-term fixture is flagged",
        repr(dirty_provider_hits),
    )
    clean_provider_hits = _scan_provider_terms(FIXTURES / "provider-term-clean.txt")
    counts.check(
        not clean_provider_hits,
        f"TEST-025 false-positive control: the clean provider-term fixture (this feature's own vocabulary plus "
        f"near-miss substrings) is not flagged",
        repr(clean_provider_hits),
    )


# =============================================================================
# Registration self-check.
# =============================================================================

def run_registration_check(counts):
    sh_registered = "tests/resolve-project-context-parity.tests.sh" in (ROOT / "tests/run-all.sh").read_text(encoding="utf-8")
    ps_registered = "tests/resolve-project-context-parity.tests.ps1" in (ROOT / "tests/run-all.ps1").read_text(encoding="utf-8")
    counts.check(sh_registered, "self-registration: tests/run-all.sh lists tests/resolve-project-context-parity.tests.sh")
    counts.check(ps_registered, "self-registration: tests/run-all.ps1 lists tests/resolve-project-context-parity.tests.ps1")

    staged_workflow = ROOT / "specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/test.yml"
    staged_manifest = ROOT / "specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256"
    if staged_workflow.is_file():
        text = staged_workflow.read_text(encoding="utf-8")
        staged_ok = (
            "tests/resolve-project-context-parity.tests.sh" in text
            and "tests/resolve-project-context-parity.tests.ps1" in text
        )
        counts.check(staged_ok, "self-registration: the staged .github/workflows/test.yml candidate carries this suite's CI steps")
    else:
        counts.check(False, "self-registration: staged .github/workflows/test.yml candidate is missing", str(staged_workflow))

    if staged_workflow.is_file() and staged_manifest.is_file():
        import hashlib
        staged_hash = hashlib.sha256(staged_workflow.read_bytes()).hexdigest()
        manifest_line = next(
            (line for line in staged_manifest.read_text(encoding="utf-8").splitlines() if line.endswith("workflows/test.yml")),
            "",
        )
        manifest_hash = manifest_line.split()[0] if manifest_line else ""
        counts.check(
            bool(manifest_hash) and staged_hash == manifest_hash,
            "self-registration: staged .github/workflows/test.yml candidate sha256 matches its own MANIFEST.sha256 entry",
            repr({"staged": staged_hash, "manifest": manifest_hash}),
        )
    else:
        counts.check(False, "self-registration: staged workflow or MANIFEST.sha256 is missing")

    live_workflow = ROOT / ".github/workflows/test.yml"
    result = subprocess.run(
        ["git", "-C", str(ROOT), "diff", "--quiet", "HEAD", "--", str(live_workflow.relative_to(ROOT))],
        capture_output=True,
    )
    counts.check(
        result.returncode == 0,
        "self-registration: the live .github/workflows/test.yml is byte-unchanged relative to its committed state "
        "(this task never writes to it)",
        result.stdout.decode("utf-8", errors="replace") + result.stderr.decode("utf-8", errors="replace"),
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--launcher", choices=("sh", "ps1"), required=True)
    args = parser.parse_args()
    counts = block_check.Counts()

    required = [STAGED_SCRIPTS / f"resolve-project-context.{suffix}" for suffix in ("py", "sh", "ps1")]
    if not all(path.is_file() for path in required):
        counts.check(False, "staged resolve-project-context implementation exists", "implementation absent")
    else:
        run_test_022(counts)
        run_test_023(counts)
        run_test_024_registry_reordering(counts)
        run_test_024_facet_manifest_sort_whitebox(counts)
        run_test_024_diagnostics_sort_reuse(counts)
        run_test_025(counts)

    run_registration_check(counts)

    print(f"resolve-project-context-parity ({args.launcher} launcher): {counts.passed} passed, {counts.failed} failed")
    print(f"RESULT: {counts.passed} passed, {counts.failed} failed")
    return 1 if counts.failed else 0


if __name__ == "__main__":
    sys.exit(main())
