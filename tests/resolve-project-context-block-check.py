#!/usr/bin/env python3
"""T-002+T-003 driver shared by the POSIX and PowerShell twins.

Four sections:

1. The steps 0-3 Block matrix (T-002, five diagnostic rows over six
   invocations).
2. The step 3 Context Projection assembly and its own second canonicalizer
   pass (T-002). T-002 stages the projection in memory and deliberately
   writes no live artifact (design.md step 3, B1/B4), so the only point at
   which the assembled structure is observable from outside the resolver
   process is the input handed to the second (JSON-mode) canonicalizer
   invocation. A capture stub standing in for `canonicalize-sdd-yaml`
   records exactly those bytes, which are then compared against the field
   set Epic A4's REQ-003 fixes verbatim -- the authority design.md:818-822
   cites for this step ("Epic A4's own REQ-003 generation procedure,
   verbatim"), restated in this feature's own investigation.md:136-138:

     {schema (const "sdd-context-projection/v1"), source_sha256
      (project-context.yaml's own canonical-form sha256), workflow
      (verbatim), components (re-keyed by each entry's own `id`, with `id`
      itself omitted), shared_paths (as-is)}

   with `components: {}` / `shared_paths: []` materialized whenever the
   source document omits either key
   (specs/epic-192-a4-facet-manifest/requirements.md REQ-003, AC-015).

   REQ-003 also allows an OPTIONAL `provider_bindings_sha256`. T-002's own
   steps 0-3 consume no provider bindings, so this suite asserts the exact
   five-field set below. A later task that starts populating that sixth
   field must widen PROJECTION_FIELDS deliberately -- the assertion is meant
   to fail first, not to be silently outgrown.
3. T-003's own five new Block diagnostic-id rows (steps 4-9, six
   invocations -- `dsl-warn-on-matched-capability` gets two fixtures per
   B2's widened quantifier): `affected-component-resolution-failed`,
   `contract-discovery-failed`, `registry-validation-failed`,
   `dependency-subprocess-failed`, and the two `dsl-warn-on-matched-
   capability` WARN fixtures. Every dependency this stage invokes
   (`resolve-component-paths`, Registry discovery + `validate-capability-
   registry`, `generate-registry-digest --whole`, `evaluate-predicate`) is a
   REAL subprocess against a real, isolated git repository and a real
   fixture Registry -- matching this task's own Depends On text ("this
   task's own script invokes them as real subprocesses, not mocked
   stand-ins") -- except where the fixture itself is a deliberately-failing
   stub standing in for one specific dependency, exactly as section 1 above
   already does for `canonicalize-sdd-yaml`.
4. Section 3's own T-003 Resolver Evidence assertions recompute the expected
   `trigger_evaluations[].evidence` content by invoking the REAL
   `evaluate-predicate` directly against the identical predicate/properties
   pair, rather than hand-transcribing its own Evidence JSON Schema output
   -- the same "recompute via the real dependency" discipline section 2
   already uses for `source_sha256`.
5. T-004's own three new Block diagnostic-id rows (steps 10-13, four
   invocations -- `output-schema-validation-failed` gets two fixtures per
   AC-055's own dual-artifact-scope): `lite-check-source-undefined`,
   `output-schema-validation-failed` (sub-case a: Resolver Evidence itself
   fails; sub-case b: a non-Evidence staged artifact fails), and the first,
   digest-mismatch `snapshot-generation-mismatch` fixture. Two of Epic A4's
   own three governing output schemas this stage's step 12 self-validates
   against (`context-projection.schema.json`, `capability-summary.
   schema.json`) are not yet landed on this branch (Epic A4's own PR has
   not merged here; T-003's own Dependency Preflight already recorded the
   identical gap for its own, narrower scope) -- `install_t003_dependencies`
   below plants this suite's own test-harness-only stand-in copies (their
   real Epic A4 field shapes, transcribed verbatim from `specs/
   epic-192-a4-facet-manifest/design.md`'s own frozen API/Contract Plan;
   `facet-manifest.schema.json` and `resolver-evidence.schema.json` are
   both real, already-landed contracts and are copied as-is) into every
   fixture's own isolated `contracts/` directory, exactly like this
   driver's own already-established "real dependency plus one
   deliberately-failing stub/schema" pattern. `capability-summary.
   schema.json` is planted for completeness/future reuse but is never
   actually exercised by any of this task's own four fixtures below (each
   is deliberately shaped to Block, or to fail, before step 12 would ever
   reach a Capability Summary schema check -- see T-004's own
   implementation report for the exact reasoning).
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/capability-resolver/resolve-project-context-block"
PROJECTION_FIXTURES = ROOT / "tests/fixtures/capability-resolver/resolve-project-context-projection"
STAGED = (
    ROOT
    / "specs/epic-193-a5-capability-resolver/human-copy"
    / "plugins/sdd-quality-loop/scripts"
)
REAL_CANONICALIZER = ROOT / "plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py"
SCHEMA = ROOT / "contracts/resolver-evidence.schema.json"
SCHEMA_CHECK = ROOT / "tests/resolver-evidence-schema-check.py"

PROJECTION_SCHEMA = "sdd-context-projection/v1"
PROJECTION_FIELDS = ["components", "schema", "shared_paths", "source_sha256", "workflow"]

CASES = (
    ("disabled-legacy-invocation", "absent", "disabled-legacy-invocation", "sdd/project-context.yaml", "disabled-legacy"),
    ("workflow-combination-invalid-lite", "workflow-combination-invalid/lite-wrong-layout.yaml", "workflow-combination-invalid", "workflow spec_profile/artifact_layout combination is invalid", "advisory"),
    ("workflow-combination-invalid-full", "workflow-combination-invalid/full-lite-layout.yaml", "workflow-combination-invalid", "workflow spec_profile/artifact_layout combination is invalid", "required"),
    ("project-context-validation-failed", "project-context-validation-failed/missing-enforcement.yaml", "project-context-validation-failed", "project context does not conform to contracts/project-context.schema.json", None),
    ("canonicalizer-invocation-failed", "canonicalizer-invocation-failed/project-context.yaml", "canonicalizer-invocation-failed", "canonicalize-sdd-yaml failed while canonicalizing project context", None),
    ("dependency-output-malformed", "dependency-output-malformed/project-context.yaml", "dependency-output-malformed", "canonicalize-sdd-yaml returned malformed JSON while canonicalizing project context", None),
)

# The two Context Projection sources, with the projection each must produce
# per REQ-003. `source_sha256` is not spelled out here: it is recomputed
# independently, by hashing the real canonicalizer's own YAML-mode output
# over the same fixture (see expected_projection below).
PROJECTION_SOURCES = {
    "two-components": {
        "schema": PROJECTION_SCHEMA,
        "workflow": {
            "spec_profile": "full",
            "artifact_layout": "facet-hybrid",
            "capability_enforcement": "required",
        },
        "components": {
            "desktop-client": {
                "artifact_kinds": ["desktop-app"],
                "runtime_classes": ["electron"],
                "characteristics": {"pii": False, "ui": True},
                "paths": {"include": ["apps/desktop/**"]},
            },
            "Desktop/App": {
                "artifact_kinds": ["installer"],
                "paths": {"include": ["apps/installer/**"]},
            },
        },
        "shared_paths": [
            {"pattern": "shared/**", "classification": "cross-cutting"},
            {"pattern": "libs/core/**", "components": ["desktop-client"]},
        ],
    },
    "omits-components": {
        "schema": PROJECTION_SCHEMA,
        "workflow": {
            "spec_profile": "full",
            "artifact_layout": "facet-native",
            "capability_enforcement": "advisory",
        },
        "components": {},
        "shared_paths": [],
    },
}

# (case name, projection source, stub mode, expected diagnostic id, detail,
#  expected `state`). The two Block rows below are step 3's own second
# canonicalizer pass, distinct from the step 2 rows in CASES: same two
# diagnostic ids, different detail text, and `state` is already known by the
# time step 3 runs, so it must be present.
PROJECTION_BLOCK_CASES = (
    (
        "projection-canonicalizer-invocation-failed",
        "two-components",
        "json-fail",
        "canonicalizer-invocation-failed",
        "canonicalize-sdd-yaml failed while canonicalizing context projection",
        "required",
    ),
    (
        "projection-dependency-output-malformed",
        "omits-components",
        "json-garbage",
        "dependency-output-malformed",
        "canonicalize-sdd-yaml returned malformed JSON while canonicalizing context projection",
        "advisory",
    ),
)

ALL_CASE_NAMES = (
    [case[0] for case in CASES]
    + [f"projection-{name}" for name in PROJECTION_SOURCES]
    + [case[0] for case in PROJECTION_BLOCK_CASES]
    + [
        "affected-component-resolution-failed",
        "contract-discovery-failed",
        "registry-validation-failed",
        "dependency-subprocess-failed",
        "dsl-warn-unmatched-trigger",
        "dsl-warn-matched-nondetermining",
        "lite-check-source-undefined",
        "output-schema-validation-failed-evidence",
        "output-schema-validation-failed-artifact",
        "snapshot-generation-mismatch",
    ]
)

# --- T-003 (steps 4-9) additions -------------------------------------------

DEPENDENCY_SCRIPTS = (
    "resolve-component-paths.py",
    "evaluate-predicate.py",
    "generate-registry-digest.py",
    "validate-capability-registry.py",
    "registry_discovery.py",
)
REGISTRY_SCHEMA_REAL = ROOT / "contracts/capability-registry.schema.json"
LITE_CATALOG_REAL = ROOT / "contracts/lite-upgrade-reason-catalog.json"
PROVIDER_TERMS_REAL = ROOT / "plugins/sdd-quality-loop/references/provider-terms.json"
EVALUATE_PREDICATE_REAL = ROOT / "plugins/sdd-quality-loop/scripts/evaluate-predicate.py"
EMPTY_REGISTRY_PATH = PROJECTION_FIXTURES / "capability-registry-empty.json"

# T-004 (steps 10-13): step 12's own four governing output schemas.
# `facet-manifest.schema.json`/`resolver-evidence.schema.json` are real,
# already-landed contracts; `context-projection.schema.json`/`capability-
# summary.schema.json` are this suite's own test-harness-only stand-ins
# for Epic A4's own two not-yet-landed schemas (see module docstring,
# section 5).
FACET_MANIFEST_SCHEMA_REAL = ROOT / "contracts/facet-manifest.schema.json"
RESOLVER_EVIDENCE_SCHEMA_REAL = SCHEMA
CONTEXT_PROJECTION_SCHEMA_STANDIN = PROJECTION_FIXTURES / "context-projection.schema.json"
CAPABILITY_SUMMARY_SCHEMA_STANDIN = PROJECTION_FIXTURES / "capability-summary.schema.json"


def install_t003_dependencies(repo, scripts, fixture_dir, stub_name=None, registry_capabilities_path=None):
    """Install every real Epic A2/A3 dependency this stage invokes, then
    overlay `fixture_dir`'s own stub (if any) on top of exactly one of
    them -- the same "real dependency plus one deliberately-failing stub"
    pattern `install_scripts`/`copy_inputs` already use for
    `canonicalize-sdd-yaml`."""
    for name in DEPENDENCY_SCRIPTS:
        shutil.copy2(ROOT / "plugins/sdd-quality-loop/scripts" / name, scripts / name)
    if stub_name is not None:
        shutil.copy2(fixture_dir / stub_name, scripts / stub_name)
    references = repo / "plugins/sdd-quality-loop/references"
    references.mkdir(parents=True, exist_ok=True)
    shutil.copy2(PROVIDER_TERMS_REAL, references / "provider-terms.json")
    contracts = repo / "contracts"
    shutil.copy2(REGISTRY_SCHEMA_REAL, contracts / "capability-registry.schema.json")
    shutil.copy2(LITE_CATALOG_REAL, contracts / "lite-upgrade-reason-catalog.json")
    if registry_capabilities_path is not None:
        shutil.copy2(registry_capabilities_path, contracts / "capability-registry.json")
    # T-004 (step 12): every governing output schema this stage may
    # self-validate against, planted unconditionally so a fixture that
    # legitimately reaches step 10-13 (a success path, or one of T-004's
    # own new Block fixtures) can discover them via the identical
    # packaged-then-git-root ADR-0025 order `_discover_governing_schema`
    # uses -- these fixture repos only ever populate the git-root
    # location, matching this driver's own already-established
    # `install_scripts`/`_discover_registry` convention.
    shutil.copy2(FACET_MANIFEST_SCHEMA_REAL, contracts / "facet-manifest.schema.json")
    shutil.copy2(RESOLVER_EVIDENCE_SCHEMA_REAL, contracts / "resolver-evidence.schema.json")
    shutil.copy2(CONTEXT_PROJECTION_SCHEMA_STANDIN, contracts / "context-projection.schema.json")
    shutil.copy2(CAPABILITY_SUMMARY_SCHEMA_STANDIN, contracts / "capability-summary.schema.json")


def git_commit_all(repo, message):
    subprocess.run(["git", "-C", str(repo), "add", "-A"], check=True, capture_output=True)
    subprocess.run(
        [
            "git", "-C", str(repo),
            "-c", "user.email=resolver-test@example.com", "-c", "user.name=resolver-test",
            "commit", "-q", "-m", message,
        ],
        check=True, capture_output=True,
    )
    return subprocess.run(
        ["git", "-C", str(repo), "rev-parse", "HEAD"], check=True, capture_output=True, text=True,
    ).stdout.strip()


def t003_resolver_argv(kind, scripts, source_rev, target_rev):
    return launcher_args(kind, scripts) + [
        "--config", "project-context.yaml",
        "--source-rev", source_rev,
        "--target-rev", target_rev,
        "--feature", "example-feature",
    ]


def real_evaluate_predicate(predicate, properties):
    """Recompute the exact `{result, evidence}` shape via the REAL
    `evaluate-predicate`, mirroring section 2's own `expected_projection`
    discipline (recompute via the real dependency, never hand-transcribed)."""
    with tempfile.TemporaryDirectory(prefix="evaluate-predicate-expected-") as tmp:
        predicate_path = Path(tmp) / "predicate.json"
        properties_path = Path(tmp) / "properties.json"
        predicate_path.write_text(json.dumps(predicate), encoding="utf-8")
        properties_path.write_text(json.dumps(properties), encoding="utf-8")
        result = subprocess.run(
            [sys.executable, str(EVALUATE_PREDICATE_REAL), "--predicate", str(predicate_path),
             "--component-properties", str(properties_path)],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
        )
        parsed = json.loads(result.stdout.decode("utf-8"))
        return parsed["result"], parsed["evidence"]


def run_t003_case(kind, case_name, counts):
    fixture_dir = FIXTURES / case_name
    with tempfile.TemporaryDirectory(prefix="resolver-t003-") as tmp:
        repo = Path(tmp).resolve()
        subprocess.run(["git", "init", "-q", str(repo)], check=True, capture_output=True)
        scripts = install_scripts(repo)
        feature_dir, sentinels = plant_sentinels(repo, scripts)
        shutil.copy2(fixture_dir / "project-context.yaml", repo / "project-context.yaml")

        registry_path = fixture_dir / "capability-registry.json"
        stub_name = None
        if case_name == "affected-component-resolution-failed":
            stub_name = "resolve-component-paths.py"
        elif case_name == "dependency-subprocess-failed":
            stub_name = "generate-registry-digest.py"
        install_t003_dependencies(
            repo, scripts, fixture_dir, stub_name=stub_name,
            registry_capabilities_path=registry_path if registry_path.is_file() else None,
        )

        (repo / "README.md").write_text("baseline\n", encoding="utf-8")
        base_oid = git_commit_all(repo, "baseline")
        target_oid = base_oid

        expected_capability_evaluations = []
        state = "advisory"

        if case_name == "affected-component-resolution-failed":
            expected_id = "affected-component-resolution-failed"
            repo_relative_config = "project-context.yaml"
            expected_detail = None  # computed after the run, from the real exit code

        elif case_name == "contract-discovery-failed":
            expected_id = "contract-discovery-failed"
            expected_detail = (
                "registry discovery failed to locate or verify capability-registry.json "
                "or capability-registry.schema.json"
            )

        elif case_name == "registry-validation-failed":
            expected_id = "registry-validation-failed"
            expected_detail = "capability-registry.json failed validate-capability-registry checks"

        elif case_name == "dependency-subprocess-failed":
            expected_id = "dependency-subprocess-failed"
            expected_detail = "generate-registry-digest failed while computing registry_digest"

        elif case_name == "dsl-warn-unmatched-trigger":
            state = "advisory"
            (repo / "comp-a").mkdir()
            (repo / "comp-a/file.txt").write_text("x\n", encoding="utf-8")
            target_oid = git_commit_all(repo, "add comp-a")
            expected_id = "dsl-warn-on-matched-capability"
            expected_detail = "a predicate evaluation produced an outcome: warn evidence node"
            predicate = {"scope": "affected_component", "field": "characteristics.auto_update", "operator": "equals", "value": True}
            properties = {"characteristics": {"pii": True}}
            result, evidence = real_evaluate_predicate(predicate, properties)
            expected_capability_evaluations = [{
                "capability_id": "cap-unmatched-warn",
                "matched": result,
                "trigger_evaluations": [{"component_id": "comp-a", "result": result, "evidence": evidence}],
            }]

        elif case_name == "dsl-warn-matched-nondetermining":
            state = "required"
            (repo / "comp-a").mkdir()
            (repo / "comp-a/file.txt").write_text("x\n", encoding="utf-8")
            (repo / "comp-b").mkdir()
            (repo / "comp-b/file.txt").write_text("y\n", encoding="utf-8")
            target_oid = git_commit_all(repo, "add comp-a and comp-b")
            expected_id = "dsl-warn-on-matched-capability"
            expected_detail = "a predicate evaluation produced an outcome: warn evidence node"
            predicate = {"scope": "affected_component", "field": "characteristics.pii", "operator": "equals", "value": True}
            result_a, evidence_a = real_evaluate_predicate(predicate, {"characteristics": {"pii": True}})
            result_b, evidence_b = real_evaluate_predicate(predicate, {})
            expected_capability_evaluations = [{
                "capability_id": "cap-matched-warn",
                "matched": result_a or result_b,
                "trigger_evaluations": [
                    {"component_id": "comp-a", "result": result_a, "evidence": evidence_a},
                    {"component_id": "comp-b", "result": result_b, "evidence": evidence_b},
                ],
                "conditional_facet_evaluations": [],
            }]

        else:
            raise AssertionError(f"unknown T-003 case: {case_name}")

        result = subprocess.run(
            t003_resolver_argv(kind, scripts, base_oid, target_oid),
            cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        )
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")

        if case_name == "affected-component-resolution-failed":
            expected_detail = (
                f"resolve-component-paths exited 3 resolving project-context.yaml; "
                f"see resolve-component-paths diagnostics"
            )

        expected_line = f"capability-resolver: {expected_id}: {expected_detail}\n"
        counts.check(result.returncode == 1, f"{case_name}: exit 1", f"got {result.returncode}")
        counts.check(
            stdout == "" and stderr == expected_line and "FIXTURE_INJECTED_FAILURE" not in stderr,
            f"{case_name}: canonical diagnostic only, no upstream stderr embedded (M8)",
            f"stdout={stdout!r} stderr={stderr!r}",
        )

        evidence_path = feature_dir / "resolver-evidence.yaml"
        evidence, parse_error = read_evidence(evidence_path)
        expected = {
            "schema": "sdd-resolver-evidence/v1",
            "feature": "example-feature",
            "capability_evaluations": sorted(expected_capability_evaluations, key=lambda e: e["capability_id"]),
            "diagnostics": [{"id": expected_id, "detail": expected_detail, "severity": "block"}],
            "state": state,
        }
        counts.check(evidence == expected, f"{case_name}: exact Resolver Evidence", parse_error or repr(evidence))

        check_evidence_schema(counts, evidence_path, case_name)
        unchanged = all(path.read_bytes() == value for path, value in sentinels.items())
        counts.check(unchanged, f"{case_name}: no partial live artifact")


# --- T-004 (steps 10-13) additions ------------------------------------------


def run_t004_case(kind, case_name, counts):
    """T-004's own four new Block-suite invocations (steps 10-13):
    `lite-check-source-undefined`, the two `output-schema-validation-
    failed` sub-cases (AC-055), and the first, digest-mismatch
    `snapshot-generation-mismatch` fixture. Every real dependency this
    stage invokes (`resolve-component-paths`, Registry discovery +
    `validate-capability-registry`, `generate-registry-digest --whole`,
    `evaluate-predicate`) is a REAL subprocess, matching T-003's own
    established discipline -- except where a fixture deliberately swaps
    in a failing stub/schema for exactly the one dependency this fixture
    exists to break."""
    fixture_dir = FIXTURES / case_name
    with tempfile.TemporaryDirectory(prefix="resolver-t004-") as tmp:
        repo = Path(tmp).resolve()
        subprocess.run(["git", "init", "-q", str(repo)], check=True, capture_output=True)
        scripts = install_scripts(repo)
        feature_dir, sentinels = plant_sentinels(repo, scripts)
        shutil.copy2(fixture_dir / "project-context.yaml", repo / "project-context.yaml")

        state = "advisory"
        expected_capability_evaluations = []
        stub_name = None
        registry_capabilities_path = EMPTY_REGISTRY_PATH
        target_oid_extra_commit = False

        if case_name == "lite-check-source-undefined":
            state = "required"
            registry_capabilities_path = fixture_dir / "capability-registry.json"
            target_oid_extra_commit = True
            expected_id = "lite-check-source-undefined"
            expected_detail = (
                "matched Capability 'cap-lite' has no lite_policy.required_lite_checks "
                "source while capability_enforcement is required"
            )
        elif case_name == "output-schema-validation-failed-evidence":
            expected_id = "output-schema-validation-failed"
            expected_detail = "resolver-evidence.yaml failed its own defensive output schema self-validation"
        elif case_name == "output-schema-validation-failed-artifact":
            expected_id = "output-schema-validation-failed"
            expected_detail = "the staged context-projection artifact failed its own defensive output schema self-validation"
        elif case_name == "snapshot-generation-mismatch":
            stub_name = "generate-registry-digest.py"
            expected_id = "snapshot-generation-mismatch"
            expected_detail = (
                "a pre-publication recheck of the Project Context, Registry, or "
                "ownership-source snapshot detected drift since this invocation's own snapshot"
            )
        else:
            raise AssertionError(f"unknown T-004 case: {case_name}")

        install_t003_dependencies(
            repo, scripts, fixture_dir, stub_name=stub_name,
            registry_capabilities_path=registry_capabilities_path,
        )
        # T-004's own two output-schema-validation-failed fixtures each
        # overlay exactly one governing schema with a deliberately
        # unsatisfiable stand-in, on top of the otherwise-real/stand-in set
        # `install_t003_dependencies` just planted.
        if (fixture_dir / "resolver-evidence.schema.json").is_file():
            shutil.copy2(fixture_dir / "resolver-evidence.schema.json", repo / "contracts/resolver-evidence.schema.json")
        if (fixture_dir / "context-projection.schema.json").is_file():
            shutil.copy2(fixture_dir / "context-projection.schema.json", repo / "contracts/context-projection.schema.json")

        (repo / "README.md").write_text("baseline\n", encoding="utf-8")
        base_oid = git_commit_all(repo, "baseline")
        target_oid = base_oid

        if target_oid_extra_commit:
            (repo / "comp-a").mkdir()
            (repo / "comp-a/file.txt").write_text("x\n", encoding="utf-8")
            target_oid = git_commit_all(repo, "add comp-a")
            predicate = {"scope": "affected_component", "field": "characteristics.pii", "operator": "equals", "value": True}
            properties = {"characteristics": {"pii": True}}
            result, evidence_nodes = real_evaluate_predicate(predicate, properties)
            expected_capability_evaluations = [{
                "capability_id": "cap-lite",
                "matched": result,
                "trigger_evaluations": [{"component_id": "comp-a", "result": result, "evidence": evidence_nodes}],
                "conditional_facet_evaluations": [],
            }]

        result = subprocess.run(
            t003_resolver_argv(kind, scripts, base_oid, target_oid),
            cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        )
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")

        expected_line = f"capability-resolver: {expected_id}: {expected_detail}\n"
        counts.check(result.returncode == 1, f"{case_name}: exit 1", f"got {result.returncode} stderr={stderr!r}")
        counts.check(
            stdout == "" and stderr == expected_line and "FIXTURE_INJECTED_FAILURE" not in stderr,
            f"{case_name}: canonical diagnostic only, no upstream stderr embedded (M8)",
            f"stdout={stdout!r} stderr={stderr!r}",
        )

        evidence_path = feature_dir / "resolver-evidence.yaml"

        if case_name == "output-schema-validation-failed-evidence":
            # B3's sole exception: nothing is written to any live path at
            # all, not even a best-effort Evidence instance.
            counts.check(not evidence_path.exists(), f"{case_name}: no Resolver Evidence written (B3)")
        else:
            evidence, parse_error = read_evidence(evidence_path)
            expected = {
                "schema": "sdd-resolver-evidence/v1",
                "feature": "example-feature",
                "capability_evaluations": sorted(expected_capability_evaluations, key=lambda e: e["capability_id"]),
                "diagnostics": [{"id": expected_id, "detail": expected_detail, "severity": "block"}],
                "state": state,
            }
            counts.check(evidence == expected, f"{case_name}: exact Resolver Evidence", parse_error or repr(evidence))
            check_evidence_schema(counts, evidence_path, case_name)

        unchanged = all(path.read_bytes() == value for path, value in sentinels.items())
        counts.check(unchanged, f"{case_name}: no partial live artifact")


class Counts:
    def __init__(self):
        self.passed = 0
        self.failed = 0

    def check(self, condition, label, detail=""):
        if condition:
            self.passed += 1
            print(f"PASS: {label}")
        else:
            self.failed += 1
            suffix = f": {detail}" if detail else ""
            print(f"FAIL: {label}{suffix}")


def install_scripts(repo):
    scripts = repo / "plugins/sdd-quality-loop/scripts"
    scripts.mkdir(parents=True)
    for suffix in ("py", "sh", "ps1"):
        shutil.copy2(STAGED / f"resolve-project-context.{suffix}", scripts)
    shutil.copy2(REAL_CANONICALIZER, scripts)
    contracts = repo / "contracts"
    contracts.mkdir()
    shutil.copy2(ROOT / "contracts/project-context.schema.json", contracts)
    return scripts


def copy_inputs(repo, fixture_rel, case_name):
    scripts = install_scripts(repo)
    config = repo / "sdd/project-context.yaml"
    config.parent.mkdir()
    if fixture_rel != "absent":
        shutil.copy2(FIXTURES / fixture_rel, config)
    if case_name in ("canonicalizer-invocation-failed", "dependency-output-malformed"):
        shutil.copy2(FIXTURES / case_name / "canonicalize-sdd-yaml.py", scripts / "canonicalize-sdd-yaml.py")


def copy_projection_inputs(repo, source_name):
    """Install the real canonicalizer under a delegate name and put the
    capture stub in its place, so step 2 stays production-faithful while
    step 3's own input becomes observable."""
    scripts = install_scripts(repo)
    shutil.copy2(REAL_CANONICALIZER, scripts / "canonicalize-sdd-yaml-real.py")
    shutil.copy2(PROJECTION_FIXTURES / "canonicalize-sdd-yaml.py", scripts / "canonicalize-sdd-yaml.py")
    config = repo / "sdd/project-context.yaml"
    config.parent.mkdir()
    shutil.copy2(PROJECTION_FIXTURES / f"{source_name}.yaml", config)


def plant_sentinels(repo, scripts):
    feature_dir = repo / "specs/example-feature"
    feature_dir.mkdir(parents=True)
    sentinels = {
        feature_dir / "facet-manifest.yaml": b"facet-preimage\n",
        feature_dir / "capability-summary.yaml": b"summary-preimage\n",
        scripts / "generated/project-context.resolved.json": b"projection-preimage\n",
    }
    for path, value in sentinels.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(value)
    return feature_dir, sentinels


def install_spy(repo):
    """A PATH shim for every step-4-or-later dependency this task must never
    reach. Firing it leaves a marker file behind."""
    spy = repo / "subprocess-spy-fired"
    spy_bin = repo / "spy-bin"
    spy_bin.mkdir()
    for name in ("resolve-component-paths", "validate-capability-registry"):
        path = spy_bin / name
        path.write_text(f"#!/bin/sh\nprintf fired > '{spy}'\nexit 91\n", encoding="utf-8", newline="\n")
        path.chmod(0o755)
    env = os.environ.copy()
    env["PATH"] = str(spy_bin) + os.pathsep + env.get("PATH", "")
    return spy, env


def launcher_args(kind, scripts):
    if kind == "sh":
        return ["sh", str(scripts / "resolve-project-context.sh")]
    return ["pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(scripts / "resolve-project-context.ps1")]


def resolver_argv(kind, scripts):
    return launcher_args(kind, scripts) + [
        "--config", "sdd/project-context.yaml",
        "--target-rev", "HEAD",
        "--feature", "example-feature",
    ]


def read_evidence(evidence_path):
    try:
        return json.loads(evidence_path.read_text(encoding="utf-8")), ""
    except (OSError, json.JSONDecodeError) as exc:
        return None, str(exc)


def check_evidence_schema(counts, evidence_path, case_name):
    schema_result = subprocess.run(
        [sys.executable, str(SCHEMA_CHECK), str(SCHEMA), str(evidence_path), "valid"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    ) if evidence_path.is_file() else None
    counts.check(schema_result is not None and schema_result.returncode == 0,
                 f"{case_name}: Resolver Evidence schema agreement",
                 "evidence absent" if schema_result is None else schema_result.stderr.decode("utf-8", errors="replace"))


def expected_projection(source_name):
    """REQ-003's expected projection for one source fixture, with
    `source_sha256` recomputed here from the real canonicalizer rather than
    taken from the resolver under test."""
    canonical = subprocess.run(
        [sys.executable, str(REAL_CANONICALIZER), str(PROJECTION_FIXTURES / f"{source_name}.yaml"),
         "--input-format", "yaml"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
    ).stdout
    expected = dict(PROJECTION_SOURCES[source_name])
    expected["source_sha256"] = "sha256:" + hashlib.sha256(canonical).hexdigest()
    return expected


def run_case(kind, case, counts):
    case_name, fixture_rel, expected_id, expected_detail, expected_state = case
    with tempfile.TemporaryDirectory(prefix="resolver-block-") as tmp:
        repo = Path(tmp).resolve()
        subprocess.run(["git", "init", "-q", str(repo)], check=True)
        copy_inputs(repo, fixture_rel, case_name)
        scripts = repo / "plugins/sdd-quality-loop/scripts"
        feature_dir, sentinels = plant_sentinels(repo, scripts)
        spy, env = install_spy(repo)

        result = subprocess.run(resolver_argv(kind, scripts), cwd=repo, env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        stderr = result.stderr.decode("utf-8", errors="replace")
        stdout = result.stdout.decode("utf-8", errors="replace")
        expected_line = f"capability-resolver: {expected_id}: {expected_detail}\n"
        counts.check(result.returncode == 1, f"{case_name}: exit 1", f"got {result.returncode}")
        counts.check(stdout == "" and stderr == expected_line and "UPSTREAM_SECRET" not in stderr,
                     f"{case_name}: canonical diagnostic only", f"stdout={stdout!r} stderr={stderr!r}")

        evidence_path = feature_dir / "resolver-evidence.yaml"
        evidence, parse_error = read_evidence(evidence_path)
        expected = {
            "schema": "sdd-resolver-evidence/v1",
            "feature": "example-feature",
            "capability_evaluations": [],
            "diagnostics": [{"id": expected_id, "detail": expected_detail, "severity": "block"}],
        }
        if expected_state is not None:
            expected["state"] = expected_state
        counts.check(evidence == expected, f"{case_name}: exact Resolver Evidence", parse_error or repr(evidence))

        check_evidence_schema(counts, evidence_path, case_name)
        unchanged = all(path.read_bytes() == value for path, value in sentinels.items())
        counts.check(unchanged, f"{case_name}: no partial live artifact")
        counts.check(not spy.exists(), f"{case_name}: no step-4-or-later subprocess")


def run_projection_success_case(kind, source_name, counts):
    """Step 3 runs to completion; assert the projection handed to the second
    canonicalizer pass is exactly REQ-003's shape.

    T-003 extends this same script past step 3, so a step-3-only success now
    continues into steps 4-9 (`resolve-component-paths`, Registry discovery,
    `registry_digest`, evaluation) before this invocation's own `exit 0`.
    This fixture is widened, not narrowed, to keep exercising a genuine
    end-to-end clean resolve: an empty-capabilities Registry (T-003's own
    `EMPTY_REGISTRY_PATH`) and one baseline commit (so `resolve-component-
    paths`'s own `git rev-parse HEAD` resolves) make steps 4-9 a legitimate,
    real-subprocess no-op (zero Registry Capabilities to evaluate) rather
    than a stub -- the original step-3 assertions below are otherwise
    unchanged."""
    case_name = f"projection-{source_name}"
    with tempfile.TemporaryDirectory(prefix="resolver-projection-") as tmp:
        repo = Path(tmp).resolve()
        subprocess.run(["git", "init", "-q", str(repo)], check=True)
        copy_projection_inputs(repo, source_name)
        scripts = repo / "plugins/sdd-quality-loop/scripts"
        feature_dir, sentinels = plant_sentinels(repo, scripts)
        # `omits-components` deliberately omits `components` to exercise
        # step 3's own default-fill rule; the REAL resolve-component-paths
        # cannot parse that omission (Epic A3's own restricted YAML parser
        # requires the key present, verified directly), so this one source
        # gets a fixed, always-succeeding step-4 stub instead -- see that
        # stub's own module docstring.
        install_t003_dependencies(
            repo, scripts, fixture_dir=None, stub_name=None,
            registry_capabilities_path=EMPTY_REGISTRY_PATH,
        )
        if source_name == "omits-components":
            shutil.copy2(
                PROJECTION_FIXTURES / "resolve-component-paths-stub-empty.py",
                scripts / "resolve-component-paths.py",
            )
        git_commit_all(repo, "baseline")
        spy, env = install_spy(repo)
        env["SDD_T002_PROJECTION_MODE"] = "passthrough"

        result = subprocess.run(resolver_argv(kind, scripts), cwd=repo, env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        counts.check(result.returncode == 0, f"{case_name}: exit 0", f"got {result.returncode} stderr={stderr!r}")
        counts.check(stdout == "" and stderr == "", f"{case_name}: no diagnostic on either stream",
                     f"stdout={stdout!r} stderr={stderr!r}")

        capture_path = repo / "projection-capture.json"
        captured, parse_error = read_evidence(capture_path)
        counts.check(isinstance(captured, dict),
                     f"{case_name}: step 3 second canonicalizer pass ran in JSON mode",
                     parse_error or "no projection was handed to a JSON-mode canonicalizer invocation")

        expected = expected_projection(source_name)
        fields = sorted(captured) if isinstance(captured, dict) else None
        counts.check(fields == PROJECTION_FIELDS,
                     f"{case_name}: Context Projection field set is REQ-003's exact five", repr(fields))
        got = captured if isinstance(captured, dict) else {}
        counts.check(got.get("schema") == PROJECTION_SCHEMA,
                     f"{case_name}: Context Projection schema const", repr(got.get("schema")))
        counts.check(got.get("source_sha256") == expected["source_sha256"],
                     f"{case_name}: source_sha256 binds the canonical Project Context",
                     f"{got.get('source_sha256')!r} != {expected['source_sha256']!r}")
        counts.check(got.get("workflow") == expected["workflow"],
                     f"{case_name}: workflow copied verbatim", repr(got.get("workflow")))
        counts.check(got.get("components") == expected["components"],
                     f"{case_name}: components re-keyed by id with id stripped", repr(got.get("components")))
        counts.check(got.get("shared_paths") == expected["shared_paths"],
                     f"{case_name}: shared_paths carried as-is", repr(got.get("shared_paths")))
        counts.check(captured == expected, f"{case_name}: exact Context Projection document", repr(captured))

        if source_name == "two-components":
            counts.check(not (feature_dir / "resolver-evidence.yaml").exists(),
                         f"{case_name}: no Resolver Evidence on the success path")
            unchanged = all(path.read_bytes() == value for path, value in sentinels.items())
            counts.check(unchanged, f"{case_name}: no partial live artifact")
            # T-003 note: this fixture now legitimately drives steps 4-9 (a
            # real, empty-capabilities Registry resolve) to reach this same
            # `exit 0`, so the PATH-based spy this suite installs is no
            # longer expected to stay unfired -- `_script_argv` finds each
            # T-003 dependency directly in `script_dir` before ever
            # consulting PATH, so the spy simply never intercepts anything
            # either way, and asserting on it here would no longer test what
            # its own label claims.


def run_projection_block_case(kind, case, counts):
    """Step 3's own second canonicalizer pass fails; assert its two Block
    rows, which are distinct from step 2's same-id rows."""
    case_name, source_name, mode, expected_id, expected_detail, expected_state = case
    with tempfile.TemporaryDirectory(prefix="resolver-projection-") as tmp:
        repo = Path(tmp).resolve()
        subprocess.run(["git", "init", "-q", str(repo)], check=True)
        copy_projection_inputs(repo, source_name)
        scripts = repo / "plugins/sdd-quality-loop/scripts"
        feature_dir, sentinels = plant_sentinels(repo, scripts)
        spy, env = install_spy(repo)
        env["SDD_T002_PROJECTION_MODE"] = mode

        result = subprocess.run(resolver_argv(kind, scripts), cwd=repo, env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        expected_line = f"capability-resolver: {expected_id}: {expected_detail}\n"
        counts.check(result.returncode == 1, f"{case_name}: exit 1", f"got {result.returncode}")
        counts.check(stdout == "" and stderr == expected_line and "UPSTREAM_SECRET" not in stderr,
                     f"{case_name}: canonical diagnostic only", f"stdout={stdout!r} stderr={stderr!r}")

        evidence_path = feature_dir / "resolver-evidence.yaml"
        evidence, parse_error = read_evidence(evidence_path)
        expected = {
            "schema": "sdd-resolver-evidence/v1",
            "feature": "example-feature",
            "capability_evaluations": [],
            "diagnostics": [{"id": expected_id, "detail": expected_detail, "severity": "block"}],
            "state": expected_state,
        }
        counts.check(evidence == expected, f"{case_name}: exact Resolver Evidence", parse_error or repr(evidence))

        check_evidence_schema(counts, evidence_path, case_name)
        unchanged = all(path.read_bytes() == value for path, value in sentinels.items())
        counts.check(unchanged, f"{case_name}: no partial live artifact")
        counts.check(not spy.exists(), f"{case_name}: no step-4-or-later subprocess")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--launcher", choices=("sh", "ps1"), required=True)
    args = parser.parse_args()
    counts = Counts()

    required = [STAGED / f"resolve-project-context.{suffix}" for suffix in ("py", "sh", "ps1")]
    if not all(path.is_file() for path in required):
        for case_name in ALL_CASE_NAMES:
            counts.check(False, f"{case_name}: staged implementation exists", "TDD RED: implementation absent")
    else:
        for case in CASES:
            run_case(args.launcher, case, counts)
        for source_name in PROJECTION_SOURCES:
            run_projection_success_case(args.launcher, source_name, counts)
        for case in PROJECTION_BLOCK_CASES:
            run_projection_block_case(args.launcher, case, counts)
        for case_name in (
            "affected-component-resolution-failed",
            "contract-discovery-failed",
            "registry-validation-failed",
            "dependency-subprocess-failed",
            "dsl-warn-unmatched-trigger",
            "dsl-warn-matched-nondetermining",
        ):
            run_t003_case(args.launcher, case_name, counts)
        for case_name in (
            "lite-check-source-undefined",
            "output-schema-validation-failed-evidence",
            "output-schema-validation-failed-artifact",
            "snapshot-generation-mismatch",
        ):
            run_t004_case(args.launcher, case_name, counts)

    sh_registered = "tests/resolve-project-context-block.tests.sh" in (ROOT / "tests/run-all.sh").read_text(encoding="utf-8")
    ps_registered = "tests/resolve-project-context-block.tests.ps1" in (ROOT / "tests/run-all.ps1").read_text(encoding="utf-8")
    counts.check(sh_registered, "POSIX suite registered in tests/run-all.sh")
    counts.check(ps_registered, "PowerShell suite registered in tests/run-all.ps1")

    print(f"RESULT: {counts.passed} passed, {counts.failed} failed")
    return 1 if counts.failed else 0


if __name__ == "__main__":
    sys.exit(main())
