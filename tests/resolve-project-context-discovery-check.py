#!/usr/bin/env python3
"""T-006 driver shared by the POSIX and PowerShell twins for
`resolve-project-context-discovery` (design.md Test Strategy item 6,
TEST-002/AC-002 + TEST-028/AC-028): every `contracts/*` artifact this
feature's scripts locate (the Registry + its own schema, Epic A4's three
governing schemas, this feature's own `resolver-evidence.schema.json`)
resolves via the identical ADR-0025 script-relative-then-git-root-fallback
procedure, no environment variable of any kind ever consulted; plus three
installed-standalone-plugin-layout fixtures (one per runtime -- this
feature's own `.py`/`.sh`/`.ps1` dispatchers, not Epic A2's own "which host
CLI tool" axis its own three-fixture discovery pattern uses the word
"runtime" for) with only the packaged copy present, no monorepo
`contracts/`, no reachable `.git`.

Reuses `tests/resolve-project-context-block-check.py`'s own already-
established fixture-repo helpers (`Counts`, `STAGED`, `REAL_CANONICALIZER`,
`launcher_args`, `t003_resolver_argv`, `git_commit_all`, `read_evidence`),
loaded by path via the identical `_load_module` technique
`tests/resolve-project-context-match-check.py` already uses -- never
re-implemented.

Every fixture below forces the identical `snapshot-generation-mismatch`
Block at step 13 that T-004/T-005's own suites already established (the
two-fixed-digest `generate-registry-digest` stub technique): reaching that
Block proves every discovery-and-version-check step this fixture's own
invocation passes through (step 5's Registry+its-schema discovery, step
12's Resolver-Evidence/Context-Projection/track-schema discovery) already
succeeded, since any one of them failing would Block with a DIFFERENT,
earlier diagnostic id instead (`contract-discovery-failed`/
`registry-validation-failed`/`output-schema-validation-failed`) -- exactly
the same "reaching step 13 is itself load-bearing" discipline
`run_zero_affected_component_case` (match-check.py) already documents.

**Disclosed deviation (this suite's own "Specification Differences",
restated here per this Epic's own established convention -- see also this
task's own implementation report):** the three `installed-layout`
(TEST-028/AC-028) fixtures below stub `validate-capability-registry.py`
(Epic A2, out of `plugins/**` editing scope) rather than using it for
real. The REAL script unconditionally resolves its own `--repo-root` via
`registry_discovery.resolve_git_root()` whenever `resolve-project-
context.py` invokes it (no `--repo-root` override is ever passed at that
call site) and therefore hard-fails ("cannot resolve repository root") in
a genuinely no-git layout -- the EXACT layout AC-028 itself requires ("no
reachable .git"). That git-root dependency is Epic A2's own scope, already
`Spec-Review-Status: Passed`, and irrelevant to what THIS suite tests
(this feature's own Registry/schema DISCOVERY contract, never Epic A2's
own registry-content validation machinery, already covered against a real
git repository by T-003's own suite). `resolve-component-paths` is
likewise stubbed for the identical git-independence reason (Epic A3's own,
out-of-scope concern)."""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/capability-resolver/resolve-project-context-discovery"
BROKEN = FIXTURES / "broken"

REAL_CONTRACTS = {
    "capability-registry.schema.json": ROOT / "contracts/capability-registry.schema.json",
    "lite-upgrade-reason-catalog.json": ROOT / "contracts/lite-upgrade-reason-catalog.json",
    "facet-manifest.schema.json": ROOT / "contracts/facet-manifest.schema.json",
    "resolver-evidence.schema.json": ROOT / "contracts/resolver-evidence.schema.json",
    "context-projection.schema.json": ROOT / "contracts/context-projection.schema.json",
    "capability-summary.schema.json": ROOT / "contracts/capability-summary.schema.json",
}
BROKEN_ARTIFACTS = (
    "capability-registry.json",
    "capability-registry.schema.json",
    "facet-manifest.schema.json",
    "resolver-evidence.schema.json",
    "context-projection.schema.json",
    "capability-summary.schema.json",
)

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


# Reused, not reinvented (module docstring, above): the block driver's own
# already-established fixture-repo helpers.
block_check = _load_module(
    Path(__file__).resolve().parent / "resolve-project-context-block-check.py",
    "resolve_project_context_block_check_for_discovery",
)


def _plant_project_context_schema(repo_root_contracts_dir):
    """`contracts/project-context.schema.json` (Epic A1) is looked up at a
    fixed `repo_root/contracts/` path this file computes directly
    (resolve-project-context.py:863) -- NEVER via the ADR-0025 script-
    relative-then-git-root-fallback procedure this suite otherwise targets
    (design.md Discovery contract's own six-artifact list excludes it).
    Every fixture below needs it present, unconditionally, purely as a
    step-1 precondition for reaching the step 4-13 code this suite
    actually exercises -- planting it is never itself an AC-002/AC-028
    assertion target."""
    repo_root_contracts_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / "contracts/project-context.schema.json", repo_root_contracts_dir / "project-context.schema.json")


def _plant_valid_contracts(dest_dir):
    dest_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(FIXTURES / "capability-registry.json", dest_dir / "capability-registry.json")
    for filename, source in REAL_CONTRACTS.items():
        shutil.copy2(source, dest_dir / filename)


def _plant_broken_contracts(dest_dir):
    """Deliberately-wrong copies of every artifact THIS feature's scripts
    discover (never `lite-upgrade-reason-catalog.json`, which
    `resolve-project-context.py` itself never discovers -- design.md
    Discovery contract's own six-artifact list). Present but content-wrong,
    so a fixture where these are consulted by mistake fails a DIFFERENT,
    detectable way rather than merely being absent."""
    dest_dir.mkdir(parents=True, exist_ok=True)
    for filename in BROKEN_ARTIFACTS:
        shutil.copy2(BROKEN / filename, dest_dir / filename)
    shutil.copy2(REAL_CONTRACTS["lite-upgrade-reason-catalog.json"], dest_dir / "lite-upgrade-reason-catalog.json")


def _install_common_scripts(scripts_dir):
    scripts_dir.mkdir(parents=True, exist_ok=True)
    for suffix in ("py", "sh", "ps1"):
        shutil.copy2(block_check.STAGED / f"resolve-project-context.{suffix}", scripts_dir)
    shutil.copy2(block_check.REAL_CANONICALIZER, scripts_dir)
    shutil.copy2(ROOT / "plugins/sdd-quality-loop/scripts/registry_discovery.py", scripts_dir)
    shutil.copy2(ROOT / "plugins/sdd-quality-loop/scripts/evaluate-predicate.py", scripts_dir)


def _resolve_kind_argv(kind, scripts, base_oid, target_oid):
    return block_check.t003_resolver_argv(kind, scripts, base_oid, target_oid)


def _installed_layout_argv(kind, scripts, tail):
    """`kind == "py"` invokes the staged Python master directly, mirroring
    `resolve-project-context-parity-check.py`'s own already-established
    `_run_kind` helper exactly (never reinvented) -- `block_check.
    launcher_args` only ever spells `sh`/`ps1`, never the Python master
    directly, so AC-028's own third runtime needs this one extra branch."""
    if kind == "py":
        return [sys.executable, str(scripts / "resolve-project-context.py")] + tail
    return block_check.launcher_args(kind, scripts) + tail


def run_packaged_copy_preferred_case(kind, counts):
    """AC-002: the packaged, script-relative copy is discovered and used
    for every one of the six contracts/* artifacts this feature's scripts
    locate, even when a DIFFERENT, deliberately-broken copy exists at the
    git-root fallback location -- proving step 1 (script-relative) is
    genuinely tried, and used, before step 2 (git-root) ever would be."""
    case_name = "packaged-copy-preferred"
    with tempfile.TemporaryDirectory(prefix="resolver-disco-pref-") as tmp:
        fixture_dir = FIXTURES / "full-pipeline"
        repo = Path(tmp).resolve()
        subprocess.run(["git", "init", "-q", str(repo)], check=True, capture_output=True)
        scripts = repo / "plugins/sdd-quality-loop/scripts"
        _install_common_scripts(scripts)
        for name in ("resolve-component-paths.py", "validate-capability-registry.py"):
            shutil.copy2(ROOT / "plugins/sdd-quality-loop/scripts" / name, scripts / name)
        shutil.copy2(fixture_dir / "generate-registry-digest.py", scripts / "generate-registry-digest.py")
        references = repo / "plugins/sdd-quality-loop/references"
        references.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / "plugins/sdd-quality-loop/references/provider-terms.json", references / "provider-terms.json")

        _plant_valid_contracts(repo / "plugins/sdd-quality-loop/contracts")
        _plant_broken_contracts(repo / "contracts")
        _plant_project_context_schema(repo / "contracts")

        shutil.copy2(fixture_dir / "project-context.yaml", repo / "project-context.yaml")
        (repo / "README.md").write_text("baseline\n", encoding="utf-8")
        base_oid = block_check.git_commit_all(repo, "baseline")
        (repo / "comp-a").mkdir()
        (repo / "comp-a/file.txt").write_text("a\n", encoding="utf-8")
        target_oid = block_check.git_commit_all(repo, "add comp-a")

        argv = _resolve_kind_argv(kind, scripts, base_oid, target_oid)
        result = subprocess.run(argv, cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        counts.check(
            result.returncode == 1 and stdout == "" and stderr == SNAPSHOT_MISMATCH_LINE,
            f"{case_name}: reaches the forced step-13 snapshot-generation-mismatch Block, proving every one of "
            f"the six contracts/* artifacts this feature's scripts locate resolved via the PACKAGED, "
            f"script-relative copy -- a deliberately-broken copy sits at the git-root fallback location for "
            f"every one of them, so falling through to it would Block earlier with a different diagnostic (AC-002)",
            f"got exit {result.returncode} stdout={stdout!r} stderr={stderr!r}",
        )


def run_git_root_fallback_case(kind, counts):
    """AC-002: with no packaged copy present at all, every one of the six
    contracts/* artifacts resolves via the git-root fallback location
    alone -- step 2 of ADR-0025's own procedure, genuinely exercised."""
    case_name = "git-root-fallback"
    with tempfile.TemporaryDirectory(prefix="resolver-disco-gitroot-") as tmp:
        fixture_dir = FIXTURES / "full-pipeline"
        repo = Path(tmp).resolve()
        subprocess.run(["git", "init", "-q", str(repo)], check=True, capture_output=True)
        scripts = repo / "plugins/sdd-quality-loop/scripts"
        _install_common_scripts(scripts)
        for name in ("resolve-component-paths.py", "validate-capability-registry.py"):
            shutil.copy2(ROOT / "plugins/sdd-quality-loop/scripts" / name, scripts / name)
        shutil.copy2(fixture_dir / "generate-registry-digest.py", scripts / "generate-registry-digest.py")
        references = repo / "plugins/sdd-quality-loop/references"
        references.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / "plugins/sdd-quality-loop/references/provider-terms.json", references / "provider-terms.json")

        # No packaged plugins/sdd-quality-loop/contracts/ directory at all.
        _plant_valid_contracts(repo / "contracts")
        _plant_project_context_schema(repo / "contracts")

        shutil.copy2(fixture_dir / "project-context.yaml", repo / "project-context.yaml")
        (repo / "README.md").write_text("baseline\n", encoding="utf-8")
        base_oid = block_check.git_commit_all(repo, "baseline")
        (repo / "comp-a").mkdir()
        (repo / "comp-a/file.txt").write_text("a\n", encoding="utf-8")
        target_oid = block_check.git_commit_all(repo, "add comp-a")

        counts.check(
            not (repo / "plugins/sdd-quality-loop/contracts").exists(),
            f"{case_name}: fixture sanity -- no packaged contracts/ directory exists at all (git-root fallback "
            f"is the ONLY location that can possibly resolve any of the six artifacts)",
        )

        argv = _resolve_kind_argv(kind, scripts, base_oid, target_oid)
        result = subprocess.run(argv, cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        counts.check(
            result.returncode == 1 and stdout == "" and stderr == SNAPSHOT_MISMATCH_LINE,
            f"{case_name}: reaches the forced step-13 snapshot-generation-mismatch Block with no packaged copy "
            f"present anywhere -- every one of the six contracts/* artifacts resolved via the git-root "
            f"fallback location alone (AC-002)",
            f"got exit {result.returncode} stdout={stdout!r} stderr={stderr!r}",
        )


# Plausible decoy environment-variable names a naive alternate discovery
# implementation might consult -- none of them is ever read by this
# feature's real, unmutated discovery code (design.md Discovery contract:
# "no runtime environment variable of any kind is consulted").
DECOY_ENV_VARS = (
    "SDD_CONTRACTS_DIR",
    "SDD_QUALITY_LOOP_CONTRACTS",
    "CAPABILITY_REGISTRY_PATH",
    "CAPABILITY_REGISTRY_SCHEMA_PATH",
    "RESOLVER_EVIDENCE_SCHEMA_PATH",
    "FACET_MANIFEST_SCHEMA_PATH",
    "CONTEXT_PROJECTION_SCHEMA_PATH",
    "CAPABILITY_SUMMARY_SCHEMA_PATH",
)


def run_no_environment_variable_consulted_case(kind, counts):
    """AC-002: with a decoy environment variable set for every plausible
    "override the contracts location" name, pointing at a THIRD,
    deliberately-broken location neither this feature's scripts nor
    `registry_discovery.py` ever reads, this invocation reaches the
    identical forced step-13 Block as `git-root-fallback` above --
    non-vacuously proving these env vars have zero effect (if any one of
    them WERE consulted, the broken content at its decoy target would
    cause a DIFFERENT, earlier Block instead)."""
    case_name = "no-environment-variable-consulted"
    with tempfile.TemporaryDirectory(prefix="resolver-disco-noenv-") as tmp:
        fixture_dir = FIXTURES / "full-pipeline"
        repo = Path(tmp).resolve()
        subprocess.run(["git", "init", "-q", str(repo)], check=True, capture_output=True)
        scripts = repo / "plugins/sdd-quality-loop/scripts"
        _install_common_scripts(scripts)
        for name in ("resolve-component-paths.py", "validate-capability-registry.py"):
            shutil.copy2(ROOT / "plugins/sdd-quality-loop/scripts" / name, scripts / name)
        shutil.copy2(fixture_dir / "generate-registry-digest.py", scripts / "generate-registry-digest.py")
        references = repo / "plugins/sdd-quality-loop/references"
        references.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / "plugins/sdd-quality-loop/references/provider-terms.json", references / "provider-terms.json")

        _plant_valid_contracts(repo / "contracts")
        _plant_project_context_schema(repo / "contracts")
        decoy_dir = repo / "decoy-env-contracts"
        _plant_broken_contracts(decoy_dir)

        shutil.copy2(fixture_dir / "project-context.yaml", repo / "project-context.yaml")
        (repo / "README.md").write_text("baseline\n", encoding="utf-8")
        base_oid = block_check.git_commit_all(repo, "baseline")
        (repo / "comp-a").mkdir()
        (repo / "comp-a/file.txt").write_text("a\n", encoding="utf-8")
        target_oid = block_check.git_commit_all(repo, "add comp-a")

        env = os.environ.copy()
        for var in DECOY_ENV_VARS:
            env[var] = str(decoy_dir)

        argv = _resolve_kind_argv(kind, scripts, base_oid, target_oid)
        result = subprocess.run(argv, cwd=repo, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        counts.check(
            result.returncode == 1 and stdout == "" and stderr == SNAPSHOT_MISMATCH_LINE,
            f"{case_name}: reaches the identical forced step-13 Block as git-root-fallback with every plausible "
            f"decoy environment variable set to a THIRD, deliberately-broken location -- these env vars have "
            f"zero effect on discovery (AC-002)",
            f"got exit {result.returncode} stdout={stdout!r} stderr={stderr!r} env_vars={list(DECOY_ENV_VARS)!r}",
        )


def run_installed_layout_case(counts):
    """AC-028: one fixture per runtime -- this feature's own `.py`/`.sh`/
    `.ps1` dispatchers, all THREE, not just the two `launcher_args` itself
    spells (gate-cycle-1 remediation, below) -- simulating an
    installed-standalone-plugin layout: only the packaged `plugins/
    sdd-quality-loop/contracts/*` copy present, no monorepo `contracts/`,
    no reachable `.git` (a plain tempdir outside this repository's own
    working tree, sanity-checked below). Runs BOTH a full-track and a
    lite-track resolve per runtime, jointly exercising all six contracts/*
    artifacts this feature's scripts locate within that one runtime's own
    invocation (a single invocation only ever selects one of
    facet-manifest.schema.json/capability-summary.schema.json, per the
    track-exclusive publication set, B4 -- design.md Test Strategy item
    6's own "one artifact set per runtime" is the union of both tracks'
    own discovery, never a ninth, per-artifact fixture).

    **gate-cycle-1 remediation (quality-gate NEEDS_WORK, Major):** this
    function used to take a single `kind` argument, driven by `main()`'s
    own `--launcher` choice (`sh` or `ps1` only) -- the `py` dispatcher
    (direct `python3 resolve-project-context.py` invocation, never routed
    through either shell wrapper) was never exercised anywhere in this
    suite, even though `--launcher` never claimed to gate this function's
    own runtime coverage and `resolve-project-context-parity-check.py`'s
    own `_run_kind` helper (`:128`) already establishes the exact `kind ==
    "py"` invocation shape this fix reuses (`_installed_layout_argv`,
    above), unstubbed and structurally unblocked, in the same helper
    family. This function now loops over all three kinds internally,
    independent of `main()`'s own `--launcher` argument -- `python3` is
    available to both the `.sh`-launched and `.ps1`-launched runs of this
    shared driver, so BOTH this suite's own sh-invoked and ps1-invoked
    runs demonstrably execute the `py` dispatcher case (an
    `installed-layout-py-*` label appears in either run's own output)."""
    fixture_dir = FIXTURES / "installed-layout"

    for kind in ("py", "sh", "ps1"):
        case_name = f"installed-layout-{kind}"
        for track, config_name in (("full", "project-context-full.yaml"), ("lite", "project-context-lite.yaml")):
            with tempfile.TemporaryDirectory(prefix=f"resolver-disco-installed-{kind}-{track}-") as tmp:
                root = Path(tmp).resolve()

                git_check = subprocess.run(
                    ["git", "rev-parse", "--show-toplevel"], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                )
                counts.check(
                    git_check.returncode != 0,
                    f"{case_name}-{track}: fixture sanity -- no reachable git root from this tempdir (AC-028 "
                    f"'no reachable .git')",
                    repr(git_check.stdout + git_check.stderr),
                )

                scripts = root / "plugins/sdd-quality-loop/scripts"
                _install_common_scripts(scripts)
                shutil.copy2(fixture_dir / "resolve-component-paths.py", scripts / "resolve-component-paths.py")
                shutil.copy2(fixture_dir / "validate-capability-registry.py", scripts / "validate-capability-registry.py")
                shutil.copy2(fixture_dir / "generate-registry-digest.py", scripts / "generate-registry-digest.py")

                packaged = root / "plugins/sdd-quality-loop/contracts"
                _plant_valid_contracts(packaged)
                # `contracts/project-context.schema.json` (Epic A1) is looked up
                # at a fixed `repo_root/contracts/` path unrelated to this
                # feature's own ADR-0025 discovery contract (helper docstring,
                # above) -- planting ONLY that one, unrelated file here, never
                # any of the six artifacts AC-028 itself targets, so the
                # "no monorepo contracts/ COPY OF THIS FEATURE'S OWN DISCOVERY
                # TARGETS" sanity check below stays meaningful.
                _plant_project_context_schema(root / "contracts")
                monorepo_discovery_targets = set(BROKEN_ARTIFACTS) & {
                    path.name for path in (root / "contracts").glob("*")
                }
                counts.check(
                    not monorepo_discovery_targets,
                    f"{case_name}-{track}: fixture sanity -- no monorepo contracts/ copy of any of the six "
                    f"artifacts this feature's scripts locate (only the unrelated, always-git-root-only "
                    f"project-context.schema.json lives there, purely as a step-1 precondition)",
                    repr(monorepo_discovery_targets),
                )

                shutil.copy2(fixture_dir / config_name, root / config_name)

                tail = ["--config", config_name, "--target-rev", "HEAD", "--feature", "example-feature"]
                argv = _installed_layout_argv(kind, scripts, tail)
                result = subprocess.run(argv, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
                stdout = result.stdout.decode("utf-8", errors="replace")
                stderr = result.stderr.decode("utf-8", errors="replace")
                counts.check(
                    result.returncode == 1 and stdout == "" and stderr == SNAPSHOT_MISMATCH_LINE,
                    f"{case_name}-{track}: reaches the forced step-13 snapshot-generation-mismatch Block in a "
                    f"genuinely no-git, packaged-copy-only installed-standalone-plugin layout -- proving Registry+"
                    f"its-schema (step 5 discovery) and resolver-evidence/context-projection/{track}-track-schema "
                    f"(step 12 discovery+version-check) all resolved correctly via the packaged copy alone "
                    f"(AC-028; this label claims discovery, never validate-capability-registry's own content "
                    f"checks, which this fixture stubs unconditional-success -- Specification Differences)",
                    f"got exit {result.returncode} stdout={stdout!r} stderr={stderr!r}",
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
        run_packaged_copy_preferred_case(args.launcher, counts)
        run_git_root_fallback_case(args.launcher, counts)
        run_no_environment_variable_consulted_case(args.launcher, counts)
        run_installed_layout_case(counts)

    sh_registered = "tests/resolve-project-context-discovery.tests.sh" in (ROOT / "tests/run-all.sh").read_text(encoding="utf-8")
    ps_registered = "tests/resolve-project-context-discovery.tests.ps1" in (ROOT / "tests/run-all.ps1").read_text(encoding="utf-8")
    counts.check(sh_registered, "POSIX suite registered in tests/run-all.sh")
    counts.check(ps_registered, "PowerShell suite registered in tests/run-all.ps1")

    print(f"RESULT: {counts.passed} passed, {counts.failed} failed")
    return 1 if counts.failed else 0


if __name__ == "__main__":
    sys.exit(main())
