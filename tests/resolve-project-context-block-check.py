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
   digest-mismatch `snapshot-generation-mismatch` fixture. All four of Epic
   A4's own governing output schemas this stage's step 12 self-validates
   against -- `facet-manifest.schema.json`, `resolver-evidence.schema.json`,
   `context-projection.schema.json`, `capability-summary.schema.json` -- are
   now landed at `ROOT/contracts/` (confirmation-panel Major, 2026-08-24:
   an earlier revision of this comment/`install_t003_dependencies` still
   planted this suite's own test-harness-only stand-in copies for the last
   two, one of them deliberately LOOSER than the real, now-landed contract
   -- `projectedComponent: {"additionalProperties": true}, vs. the real
   schema's own closed, explicitly-enumerated property set -- so no
   assertion in this suite could ever fail on a staged Context Projection
   that violated Epic A4's REAL contract). `install_t003_dependencies`
   below now plants the REAL files at `ROOT/contracts/` for all four,
   identically to `run_draft7_keyword_coverage_check`'s own
   `GOVERNING_SCHEMA_FILES` (which already read the real files, never the
   stand-ins) -- into every fixture's own isolated `contracts/` directory,
   exactly like this driver's own already-established "real dependency
   plus one deliberately-failing stub/schema" pattern.
   `capability-summary.schema.json` was already byte-identical between the
   stand-in and the real contract (confirmed by diff before this change),
   so only `context-projection.schema.json` changes this suite's own
   observable behavior. `capability-summary.schema.json` is planted for
   completeness/future reuse but is never actually exercised by any of
   this task's own four fixtures below (each is deliberately shaped to
   Block, or to fail, before step 12 would ever reach a Capability Summary
   schema check -- see T-004's own implementation report for the exact
   reasoning).
6. Cross-model panelist remediation (T-003.panelist-anthropic.verdict.json,
   three Major findings), four fixtures added to sections 3-4's own
   pattern: `resolve-component-paths-launch-failed` (step 4's own OSError
   subprocess-launch path -- previously untested by any fixture here --
   deletes the fixture repo's own `resolve-component-paths.py` sibling so
   `_script_argv` falls back to a bare, off-PATH name, forcing a genuine
   OSError rather than a non-zero exit); `registry-discovery-unimportable`
   (a second, independent trigger for the existing `contract-discovery-
   failed` diagnostic -- an unimportable `registry_discovery` sibling
   module, rather than a missing Registry artifact); `evaluate-predicate-
   output-malformed` (a zero-exit `evaluate-predicate` whose own
   `evidence[]` array elements are not objects); and `dsl-warn-unsorted-
   affected-components` (a stub `resolve-component-paths` returning
   `affected_components` in descending order, asserting the fan-out itself
   sorts ascending rather than trusting the upstream order every other
   fixture here happens to already receive pre-sorted).
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

# Cross-model panel finding (T-004 NEEDS_WORK cycle 2, "late Blocks drop
# provenance"): `resolve-project-context.py` now threads `context_binding`/
# `resolver` into every Block reached at/after step 10 (those values are
# already computed by then). `RESOLVER_VERSION_LITERAL`/`RULE_SET_STRING_
# LITERAL` mirror resolve-project-context.py's own fixed top-of-module
# constants as INDEPENDENT literals (never imported from the module under
# test), the identical discipline `resolve-project-context-match-check.py`
# already applies to the same two constants.
RESOLVER_VERSION_LITERAL = "1.0.0"
RULE_SET_STRING_LITERAL = "sdd-resolver-rule-set/v1"
EXPECTED_RESOLVER_BLOCK = {
    "version": RESOLVER_VERSION_LITERAL,
    "rule_set_revision": "sha256:" + hashlib.sha256(RULE_SET_STRING_LITERAL.encode("utf-8")).hexdigest(),
}


def _canonicalize_json_document(document):
    """Canonicalize an in-memory JSON-compatible document via the REAL
    canonicalizer's JSON mode -- the identical technique `resolve-project-
    context-match-check.py` already established for the same purpose,
    reused rather than reinvented."""
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", suffix=".json", delete=False, newline="\n") as handle:
        json.dump(document, handle, ensure_ascii=False, separators=(",", ":"))
        temp_path = Path(handle.name)
    try:
        result = subprocess.run(
            [sys.executable, str(REAL_CANONICALIZER), str(temp_path), "--input-format", "json"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
        )
        return result.stdout
    finally:
        temp_path.unlink(missing_ok=True)


def real_registry_digest(registry_path):
    """Recompute `context_binding.registry_digest`'s own expected value
    independently of `generate-registry-digest --whole`: canonicalize the
    REAL registry file's own full document via the REAL canonicalizer
    (JSON mode) and hash it -- the identical "hash the real canonicalizer's
    own output" discipline `source_sha256`/`projection_sha256` already use
    throughout this driver, applied here to the Registry's own bytes."""
    document = json.loads(registry_path.read_text(encoding="utf-8"))
    canonical = _canonicalize_json_document(document)
    return "sha256:" + hashlib.sha256(canonical).hexdigest()


def real_resolve_component_paths_context_binding(repo, config_rel, source_rev, target_rev):
    """Recompute `{affected_components, context_binding.ownership_digest}`
    via the REAL, unmodified `resolve-component-paths.py` (Epic A3) -- the
    identical "recompute via the real dependency" discipline `real_
    evaluate_predicate` already established for `evaluate-predicate` -- so
    a fixture's own expected `context_binding` can be derived independently
    of `resolve-project-context.py` itself. Invoked with the identical
    `--config`/`--source-rev`/`--target-rev` values (and the identical
    `--include-untracked` omission, matching AC-004's own pass-through
    fix) the resolver's own step 4 call already used."""
    real_rcp = ROOT / "plugins/sdd-quality-loop/scripts/resolve-component-paths.py"
    result = subprocess.run(
        [
            sys.executable, str(real_rcp),
            "--config", config_rel, "--source-rev", source_rev, "--target-rev", target_rev, "--json",
        ],
        cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
    )
    parsed = json.loads(result.stdout.decode("utf-8"))
    return parsed["affected_components"], parsed["context_binding"]["ownership_digest"]


# Cross-model confirmation-panel Minor (Anthropic T-004): every literal
# entry here is hand-transcribed, never computed by calling `_dependency_
# pointers`/`_rfc6901_escape` (resolve-project-context.py) or replicating
# their own `.replace("~", "~0").replace("/", "~1")` logic -- a shared
# defect in that escape rule could otherwise pass both sides silently.
# `"shared/util"`/`"other~thing"` -> `"shared~1util"`/`"other~0thing"` are
# the identical two escape-bearing ids T-005's own `full-pipeline-match`
# fixture (tests/resolve-project-context-match-check.py) already
# hand-transcribes this SAME way against the SAME production function;
# `expected_dependency_pointers` below extends that literal-string style
# to this driver's own scope (`recheck-dependency-failed`, below, is the
# one fixture here whose own `affected_components` are pinned rather than
# derived from a real git diff, so it is where those two escape-bearing
# ids are exercised).
_KNOWN_COMPONENT_POINTER_ESCAPES = {
    "comp-a": "comp-a",
    "shared/util": "shared~1util",
    "other~thing": "other~0thing",
}


def expected_dependency_pointers(affected_components):
    """Independent mirror of `_dependency_pointers` (Data Plan "B9"):
    exactly `/workflow` plus one RFC-6901-escaped `/components/<id>`
    pointer per affected component, stable-sorted and de-duplicated --
    via the LITERAL lookup table above, never a computed escape (see that
    table's own docstring)."""
    pointers = {"/workflow"}
    for component_id in affected_components:
        if component_id not in _KNOWN_COMPONENT_POINTER_ESCAPES:
            raise AssertionError(
                f"expected_dependency_pointers: no literal escape known for {component_id!r} -- "
                "add it to _KNOWN_COMPONENT_POINTER_ESCAPES (hand-transcribed, never computed)"
            )
        pointers.add("/components/" + _KNOWN_COMPONENT_POINTER_ESCAPES[component_id])
    return sorted(pointers)

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
        "resolve-component-paths-launch-failed",
        "contract-discovery-failed",
        "registry-discovery-unimportable",
        "registry-validation-failed",
        "validate-capability-registry-launch-failed",
        "dependency-subprocess-failed",
        "evaluate-predicate-output-malformed",
        "evaluate-predicate-schema-error",
        "evaluate-predicate-failure-after-warn",
        "dsl-warn-unmatched-trigger",
        "dsl-warn-matched-nondetermining",
        "dsl-warn-unsorted-affected-components",
        "lite-check-source-undefined",
        "output-schema-validation-failed-evidence",
        "output-schema-validation-failed-artifact",
        "output-schema-validation-failed-facet-manifest",
        "snapshot-generation-mismatch",
        "contract-discovery-failed-governing-schema",
        "contract-discovery-failed-governing-schema-wrong-version",
        "contract-discovery-failed-governing-schema-malformed",
        "contract-discovery-failed-governing-schema-invalid-utf8",
        "contract-discovery-failed-governing-schema-malformed-ref",
        "recheck-dependency-failed",
        "registry-swapped-during-validation",
        "registry-discovery-syntax-error",
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

# T-004 (steps 10-13): step 12's own four governing output schemas -- all
# four now real, already-landed `ROOT/contracts/` contracts (confirmation-
# panel Major, 2026-08-24: see module docstring, section 5, for why the
# earlier `context-projection.schema.json` stand-in was loosened and had
# to be replaced, not merely relabeled).
FACET_MANIFEST_SCHEMA_REAL = ROOT / "contracts/facet-manifest.schema.json"
RESOLVER_EVIDENCE_SCHEMA_REAL = SCHEMA
CONTEXT_PROJECTION_SCHEMA_REAL = ROOT / "contracts/context-projection.schema.json"
CAPABILITY_SUMMARY_SCHEMA_REAL = ROOT / "contracts/capability-summary.schema.json"


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
    shutil.copy2(CONTEXT_PROJECTION_SCHEMA_REAL, contracts / "context-projection.schema.json")
    shutil.copy2(CAPABILITY_SUMMARY_SCHEMA_REAL, contracts / "capability-summary.schema.json")


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


def t003_resolver_argv(kind, scripts, source_rev, target_rev, include_untracked=False):
    """AC-004 gate-cycle-5 Major remediation: `include_untracked` defaults
    to `False` (every pre-existing caller's own byte-identical argv,
    unchanged) and, when `True`, inserts `--include-untracked` in its own
    CLI-contract position (design.md API/Contract Plan: `--config
    [--source-rev] --target-rev [--include-untracked] --feature`) --
    between `--target-rev <rev>` and `--feature <slug>` -- so a caller can
    exercise the SUPPLIED half of AC-004's own pass-through claim, not
    only the omission half every existing fixture already covers."""
    argv = launcher_args(kind, scripts) + [
        "--config", "project-context.yaml",
        "--source-rev", source_rev,
        "--target-rev", target_rev,
    ]
    if include_untracked:
        argv.append("--include-untracked")
    argv += ["--feature", "example-feature"]
    return argv


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


def expected_warn_diagnostic(capability_id, component_id, declaration_index, node_path, node):
    """AC-056: mirrors `_warn_diagnostic_detail` in `resolve-project-
    context.py` byte-for-byte (recomputed here, never hand-transcribed,
    matching `real_evaluate_predicate`'s own discipline above) so a
    `severity: "warn"` diagnostics[] entry's own `detail` can be asserted
    exactly for the three `dsl-warn-*` T-003 fixtures below, each of which
    now legitimately carries more than one diagnostics[] entry.

    Cross-model confirmation-panel Minor (Anthropic T-003): REQ-004
    scopes `declaration_index` to a `conditional_facets[].when` node
    only -- mirrors production's own omission of the
    `declaration_index=...` clause for a trigger-evaluation node
    (`declaration_index is None`), never a literal `declaration_index=
    None`."""
    location = f"capability_id={capability_id!r} component_id={component_id!r}"
    if declaration_index is not None:
        location += f" declaration_index={declaration_index!r}"
    node_position = ".".join(str(index) for index in node_path)
    detail = (
        f"a predicate evaluation produced an outcome: warn evidence node at {location} "
        f"(node_path={node_position!r}, operator={node.get('operator')!r}, "
        f"field={node.get('path')!r}, reason={node.get('reason')!r})"
    )
    return {"id": "dsl-warn-on-matched-capability", "detail": detail, "severity": "warn"}


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
        elif case_name == "registry-swapped-during-validation":
            stub_name = "generate-registry-digest.py"
        elif case_name == "registry-discovery-unimportable":
            stub_name = "registry_discovery.py"
        elif case_name == "registry-discovery-syntax-error":
            stub_name = "registry_discovery.py"
        elif case_name == "evaluate-predicate-output-malformed":
            stub_name = "evaluate-predicate.py"
        elif case_name == "evaluate-predicate-failure-after-warn":
            stub_name = "evaluate-predicate.py"
        elif case_name == "dsl-warn-unsorted-affected-components":
            stub_name = "resolve-component-paths.py"
        install_t003_dependencies(
            repo, scripts, fixture_dir, stub_name=stub_name,
            registry_capabilities_path=registry_path if registry_path.is_file() else None,
        )
        if case_name == "resolve-component-paths-launch-failed":
            # Neither a `.py` nor a `.sh` sibling is planted for this one
            # case, so `_script_argv` falls back to a bare, unqualified
            # `resolve-component-paths` -- not present on PATH in this test
            # environment -- forcing subprocess.run's own OSError launch
            # failure at step 4, the exact path the panelist's Major #1
            # finding names as untested by any existing fixture.
            (scripts / "resolve-component-paths.py").unlink()
        if case_name == "validate-capability-registry-launch-failed":
            # Cross-model panel finding (T-003 NEEDS_WORK cycle 2, step-5
            # launch-failure mislabel): the identical technique
            # `resolve-component-paths-launch-failed` already established
            # for step 4, reused here for step 5's OWN OSError launch path
            # -- neither a `.py` nor a `.sh` sibling planted for `validate-
            # capability-registry`, so `_script_argv` falls back to a bare,
            # unqualified name not present on PATH, forcing subprocess.run's
            # own OSError. Previously mapped to `registry-validation-
            # failed` (blaming the Registry's own content for a local
            # environment fault); now the SAME `dependency-subprocess-
            # failed` path steps 4/6/7-8 already use for an identical
            # OSError.
            (scripts / "validate-capability-registry.py").unlink()

        (repo / "README.md").write_text("baseline\n", encoding="utf-8")
        base_oid = git_commit_all(repo, "baseline")
        target_oid = base_oid

        expected_capability_evaluations = []
        expected_warn_diagnostics = []  # AC-056: populated only by the dsl-warn-* cases and the amended abort-forwarding case below
        state = "advisory"

        if case_name == "affected-component-resolution-failed":
            expected_id = "affected-component-resolution-failed"
            repo_relative_config = "project-context.yaml"
            expected_detail = None  # computed after the run, from the real exit code

        elif case_name == "resolve-component-paths-launch-failed":
            expected_id = "dependency-subprocess-failed"
            expected_detail = "resolve-component-paths failed to launch while resolving affected components"

        elif case_name == "contract-discovery-failed":
            expected_id = "contract-discovery-failed"
            expected_detail = (
                "registry discovery failed to locate or verify capability-registry.json "
                "or capability-registry.schema.json"
            )

        elif case_name == "registry-discovery-unimportable":
            # A second, independent trigger for the identical
            # `contract-discovery-failed` diagnostic above (an unimportable
            # sibling module, rather than a missing artifact) -- both must
            # produce byte-identical canonical output, never a raw
            # ImportError traceback with no diagnostic line and no
            # Resolver Evidence at all (the panelist's Major #3 finding).
            expected_id = "contract-discovery-failed"
            expected_detail = (
                "registry discovery failed to locate or verify capability-registry.json "
                "or capability-registry.schema.json"
            )

        elif case_name == "registry-discovery-syntax-error":
            # Cross-model confirmation-panel Minor (Anthropic, security-
            # spec.md B5): a THIRD, independent trigger for the identical
            # `contract-discovery-failed` diagnostic -- a co-located
            # sibling module that fails to import with a `SyntaxError`
            # (never `ImportError`), the exact class `_discover_registry`'s
            # own narrow `except ImportError` previously let escape
            # uncaught as a raw traceback embedding this fixture's own
            # absolute path. Byte-identical canonical output to the
            # `registry-discovery-unimportable` fixture above.
            expected_id = "contract-discovery-failed"
            expected_detail = (
                "registry discovery failed to locate or verify capability-registry.json "
                "or capability-registry.schema.json"
            )

        elif case_name == "registry-validation-failed":
            # Confirmation-panel Minor (Anthropic T-004, `_resolved_gates`
            # dangling-`gate_ids` silent-drop): this fixture's own
            # Registry (`cap-dangling`, `gate_ids: ["nonexistent-gate"]`
            # against `gates: []`) is ALSO the proof this invocation
            # Blocks at step 5 (Epic A2 `validate-capability-registry`
            # check (f) `dangling-gate-reference`) and never reaches step
            # 10's own `_resolved_gates` join -- i.e. that function's own
            # `gate_id not in gates_by_id` branch is unreachable
            # defense-in-depth in production, not a live under-population
            # path. Asserted below (`exit 1`, this id, and step 10-13
            # never runs at all on a step-5 Block) rather than duplicated
            # into a second, differently-named fixture.
            expected_id = "registry-validation-failed"
            expected_detail = "capability-registry.json failed validate-capability-registry checks"

        elif case_name == "validate-capability-registry-launch-failed":
            expected_id = "dependency-subprocess-failed"
            expected_detail = "validate-capability-registry failed to launch while validating the located Registry"

        elif case_name == "dependency-subprocess-failed":
            expected_id = "dependency-subprocess-failed"
            expected_detail = "generate-registry-digest failed while computing registry_digest"

        elif case_name == "registry-swapped-during-validation":
            # T-004 confirmation-panel Critical (OpenAI)/Major (both
            # vendors): closes the "three independent Registry reads, no
            # binding" gap. This fixture's own `generate-registry-digest`
            # stub overwrites the discovered Registry file in place as a
            # side effect of step 6's own dependency invocation; step 6.5's
            # `_recheck_registry_snapshot` must detect the swap and Block
            # `snapshot-generation-mismatch` -- the identical id/vocabulary
            # step 13's own TOCTOU recheck already uses, never a bespoke
            # second id for the identical condition.
            expected_id = "snapshot-generation-mismatch"
            expected_detail = (
                "the Registry changed between this invocation's own discovery read (step 5) and its "
                "post-validation/digest recheck (step 6)"
            )

        elif case_name == "evaluate-predicate-output-malformed":
            state = "advisory"
            (repo / "comp-a").mkdir()
            (repo / "comp-a/file.txt").write_text("x\n", encoding="utf-8")
            target_oid = git_commit_all(repo, "add comp-a")
            expected_id = "dependency-output-malformed"
            expected_detail = "evaluate-predicate returned malformed JSON while evaluating a predicate"

        elif case_name == "evaluate-predicate-schema-error":
            # Cross-model panel finding (T-003 NEEDS_WORK cycle 3, Major
            # #1): `_evaluate_predicate`'s own PREDICATE_SCHEMA_ERROR ->
            # RegistryValidationFailed mapping was keyed on a hardcoded
            # `returncode == 2` with no fixture at all. This fixture's own
            # Registry declares a trigger predicate whose `field`
            # (`characteristics.not_a_real_field`) is NOT one of
            # evaluate-predicate.py's own ALLOWED_FIELDS -- well-formed
            # enough to pass `validate-capability-registry`'s own checks
            # (a)-(i) (none of which inspect a predicate's own field/
            # operator shape) but rejected by the REAL, unmodified
            # `evaluate-predicate` at evaluation time with a genuine
            # `PREDICATE_SCHEMA_ERROR` stderr line and exit 2 -- no stub
            # planted for this dependency at all.
            state = "advisory"
            (repo / "comp-a").mkdir()
            (repo / "comp-a/file.txt").write_text("x\n", encoding="utf-8")
            target_oid = git_commit_all(repo, "add comp-a")
            expected_id = "registry-validation-failed"
            expected_detail = "a Registry-declared predicate failed predicate-schema validation"

        elif case_name == "evaluate-predicate-failure-after-warn":
            # Amendment A① (human-approved 2026-08-24): requirements.md's
            # AC-056 sentence now carries an explicit "or jointly caused"
            # exception -- `severity: "warn"` entries already collected
            # before an evaluation abort lawfully appear alongside that
            # abort's own DIFFERENT-id `severity: "block"` summary entry
            # (with no same-id summary, since step 9 is never reached on
            # this abort path) when the abort and the warns are jointly
            # caused by the same evaluation pass, reconciling the sentence
            # with REQ-004's own "recording every diagnostic-worthy
            # condition" mandate. This fixture's own Registry declares TWO
            # capabilities in declaration order: `cap-warn-first` (a real
            # WARN outcome on comp-a, fully evaluated and appended to
            # `capability_evaluations` first) then `cap-fails-second`
            # (whose own trigger evaluation is this fixture's own stubbed
            # `evaluate-predicate`'s SECOND invocation, which fails with a
            # generic non-zero exit). The already-collected WARN entry for
            # cap-warn-first is therefore FORWARDED, not dropped, on this
            # abort path -- the lossless shape: `expected_warn_diagnostics`
            # carries that one entry, alongside the different-id block
            # summary composed below (restoring the forwarding 1811ed0e
            # reversed under the unamended sentence).
            state = "advisory"
            (repo / "comp-a").mkdir()
            (repo / "comp-a/file.txt").write_text("x\n", encoding="utf-8")
            target_oid = git_commit_all(repo, "add comp-a")
            expected_id = "dependency-subprocess-failed"
            expected_detail = "evaluate-predicate failed while evaluating a predicate"
            warn_evidence_node = {
                "operator": "equals", "outcome": "warn",
                "path": "characteristics.auto_update", "reason": "missing-path",
            }
            expected_capability_evaluations = [{
                "capability_id": "cap-warn-first",
                "matched": False,
                "trigger_evaluations": [{"component_id": "comp-a", "result": False, "evidence": [warn_evidence_node]}],
            }]
            expected_warn_diagnostics = [
                expected_warn_diagnostic("cap-warn-first", "comp-a", None, (0,), warn_evidence_node),
            ]

        elif case_name == "dsl-warn-unsorted-affected-components":
            # AC-056: two independent WARN nodes (comp-a's own trigger
            # evaluation and comp-z's own, both against the identical
            # empty properties) -- diagnostics[] now carries one
            # `severity: "warn"` entry per node, in sorted-affected-
            # component evaluation order, plus one summary entry.
            state = "advisory"
            expected_id = "dsl-warn-on-matched-capability"
            expected_detail = "a predicate evaluation produced an outcome: warn evidence node"
            predicate = {"scope": "affected_component", "field": "characteristics.auto_update", "operator": "equals", "value": True}
            result, evidence = real_evaluate_predicate(predicate, {})
            expected_capability_evaluations = [{
                "capability_id": "cap-order",
                "matched": result,
                "trigger_evaluations": [
                    {"component_id": "comp-a", "result": result, "evidence": evidence},
                    {"component_id": "comp-z", "result": result, "evidence": evidence},
                ],
            }]
            expected_warn_diagnostics = [
                expected_warn_diagnostic("cap-order", "comp-a", None, (0,), evidence[0]),
                expected_warn_diagnostic("cap-order", "comp-z", None, (0,), evidence[0]),
            ]

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
            expected_warn_diagnostics = [
                expected_warn_diagnostic("cap-unmatched-warn", "comp-a", None, (0,), evidence[0]),
            ]

        elif case_name == "dsl-warn-matched-nondetermining":
            # AC-056: only comp-b's own trigger evaluation produces a WARN
            # node (comp-a's own matches cleanly) -- exactly one
            # `severity: "warn"` entry, naming comp-b's own location, plus
            # one summary entry.
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
            expected_warn_diagnostics = [
                expected_warn_diagnostic("cap-matched-warn", "comp-b", None, (0,), evidence_b[0]),
            ]

        else:
            raise AssertionError(f"unknown T-003 case: {case_name}")

        # T-003 confirmation-panel Minor (Anthropic v3): `dsl-warn-
        # unsorted-affected-components` is the one T-003 fixture whose own
        # `resolve-component-paths` stub already ignores its argv content
        # (module docstring, that fixture's own stub), so wiring THIS case
        # to supply `include_untracked=True` exercises the SUPPLIED half
        # of AC-004's pass-through claim (asserted below via that stub's
        # own `rcp-argv-capture.json`) without perturbing any other
        # case's own `include_untracked=False` (every pre-existing
        # caller's own byte-identical argv, per `t003_resolver_argv`'s own
        # docstring).
        include_untracked = case_name == "dsl-warn-unsorted-affected-components"
        result = subprocess.run(
            t003_resolver_argv(kind, scripts, base_oid, target_oid, include_untracked=include_untracked),
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
        # Confirmation-panel Major (2026-08-24, both vendors): REQ-005/
        # design.md step 4/security-spec.md B5 all require a dependency
        # subprocess's own stderr to "remain visible to a human operator
        # on the terminal exactly as that subprocess itself already
        # writes it" -- this feature's own canonical `<detail>` sentence
        # is the only thing that must never quote it verbatim. The old
        # exact-equality assertion (`stderr == expected_line`, asserting
        # "FIXTURE_INJECTED_FAILURE" ABSENT) therefore locked in the
        # violating, fully-suppressed shape; it would fail now that
        # `_reemit_dependency_stderr` passes a failing dependency's own
        # stderr through before this feature's own canonical line. This
        # asserts stdout stays empty and the canonical line is present and
        # LAST on stderr (re-emitted upstream content, if any, precedes
        # it) -- a fixture whose own stub writes no stderr (most cases
        # above) still passes, since `stderr == expected_line` is one
        # valid case of `stderr.endswith(expected_line)`.
        counts.check(
            stdout == "" and stderr.endswith(expected_line),
            f"{case_name}: canonical diagnostic line present and last on stderr (B5)",
            f"stdout={stdout!r} stderr={stderr!r}",
        )
        # Mutation-kill for the pass-through itself: `endswith` alone is
        # satisfied even with NO re-emit at all (an empty prefix is a
        # valid "ends with"), so it cannot by itself detect
        # `_reemit_dependency_stderr` being dropped. These three fixtures'
        # own stub dependencies (`resolve-component-paths.py`/
        # `generate-registry-digest.py`/`evaluate-predicate.py`) write a
        # KNOWN, fixed line to their own stderr on the exact failure this
        # case exercises -- asserting stderr is EXACTLY that upstream line
        # followed by the canonical line fails if the re-emit call is
        # ever removed (stderr would then be only the canonical line).
        injected_stderr_by_case = {
            "affected-component-resolution-failed": "resolve-component-paths: FIXTURE_INJECTED_FAILURE\n",
            "dependency-subprocess-failed": "generate-registry-digest: FIXTURE_INJECTED_FAILURE\n",
            "evaluate-predicate-failure-after-warn": "FIXTURE_INJECTED_FAILURE: evaluate-predicate failed on its second invocation\n",
        }
        if case_name in injected_stderr_by_case:
            counts.check(
                stderr == injected_stderr_by_case[case_name] + expected_line,
                f"{case_name}: dependency stderr re-emitted verbatim before the canonical line (B5, REQ-005)",
                f"stderr={stderr!r}",
            )

        evidence_path = feature_dir / "resolver-evidence.yaml"
        evidence, parse_error = read_evidence(evidence_path)
        # AC-056: the three dsl-warn-* cases above pre-populate
        # `expected_warn_diagnostics` with one `severity: "warn"` entry per
        # WARN node; every other case leaves it `[]`, preserving the
        # original single-entry shape unchanged. AC-024 stable-sort
        # discipline (cross-epic panel finding, 2026-08-23): `diagnostics[]`
        # is sorted by `(id, detail)`, never concatenated in emission
        # order -- the summary sentence ("...outcome: warn evidence node")
        # is a strict lexical prefix of every per-node detail ("...outcome:
        # warn evidence node at ..."), so it sorts FIRST, not last. This
        # expectation is DERIVED via the identical `sorted(..., key=(id,
        # detail))` rule `_write_evidence` itself now applies -- never a
        # second, independently-ordered concatenation, which would just
        # relocate the same "expectation mirrors emission" defect (a
        # single-entry list's own sort is a no-op, so every non-`dsl-warn-*`
        # case above is unaffected).
        expected = {
            "schema": "sdd-resolver-evidence/v1",
            "feature": "example-feature",
            "capability_evaluations": sorted(expected_capability_evaluations, key=lambda e: e["capability_id"]),
            "diagnostics": sorted(
                expected_warn_diagnostics + [{"id": expected_id, "detail": expected_detail, "severity": "block"}],
                key=lambda entry: (entry["id"], entry["detail"]),
            ),
            "state": state,
        }
        counts.check(evidence == expected, f"{case_name}: exact Resolver Evidence", parse_error or repr(evidence))

        check_evidence_schema(counts, evidence_path, case_name)
        unchanged = all(path.read_bytes() == value for path, value in sentinels.items())
        counts.check(unchanged, f"{case_name}: no partial live artifact")

        if case_name == "dsl-warn-unsorted-affected-components":
            # AC-004 SUPPLIED-half pass-through (T-003 confirmation-panel
            # Minor, Anthropic v3): this fixture's own `resolve-component-
            # paths` stub records its own received argv verbatim to
            # `rcp-argv-capture.json` (that stub's own module docstring).
            # A resolver-side mutant that filters `--include-untracked`
            # out of every downstream argv, or synthesizes a bespoke
            # `--no-include-untracked` in its place, would leave this
            # capture missing the flag or carrying the wrong one.
            rcp_capture_path = scripts / "rcp-argv-capture.json"
            rcp_argv, rcp_parse_error = read_evidence(rcp_capture_path)
            expected_rcp_argv = [
                "--config", "project-context.yaml",
                "--source-rev", base_oid,
                "--target-rev", target_oid,
                "--include-untracked",
                "--json",
            ]
            counts.check(
                rcp_argv == expected_rcp_argv,
                f"{case_name}: resolve-component-paths invoked with --include-untracked forwarded verbatim, "
                f"in its own CLI-contract position (immediately before --json, design.md API/Contract Plan "
                f"step 4 order), when this invocation's own resolver CLI call supplies it -- the SUPPLIED half "
                f"of AC-004's pass-through claim, now covered by T-003's own suite (previously only "
                f"T-005's resolve-project-context-match-check.py)",
                rcp_parse_error or repr(rcp_argv),
            )


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
        elif case_name == "output-schema-validation-failed-facet-manifest":
            # Cross-model confirmation-panel Minor (Anthropic T-004):
            # step 12's track-exclusive-artifact sub-case (AC-055(b)) was
            # previously exercised only via Context Projection's own
            # sibling fixture above -- the `track_artifact` branch itself
            # (Facet Manifest on `full`, Capability Summary on `lite`) had
            # no fixture of its own. This fixture overrides
            # `facet-manifest.schema.json` with a deliberately
            # unsatisfiable stand-in on the Full track, so a genuinely
            # well-formed, staged Facet Manifest fails step 12's own last
            # check (Resolver Evidence and Context Projection both still
            # pass first).
            expected_id = "output-schema-validation-failed"
            expected_detail = "the staged facet-manifest artifact failed its own defensive output schema self-validation"
        elif case_name == "snapshot-generation-mismatch":
            stub_name = "generate-registry-digest.py"
            expected_id = "snapshot-generation-mismatch"
            expected_detail = (
                "a pre-publication recheck of the Project Context, Registry, or "
                "ownership-source snapshot detected drift since this invocation's own snapshot"
            )
        elif case_name == "contract-discovery-failed-governing-schema":
            # Cross-model panel finding (T-004 NEEDS_WORK cycle 2, "late
            # Blocks drop provenance"): step 12's OWN `ContractDiscoveryFailed`
            # handler (a governing output schema itself missing, distinct
            # from step 5's Registry-discovery `contract-discovery-failed`
            # -- same id, reused, matching this driver's own established
            # "registry-discovery-unimportable" precedent for the SAME id
            # under a distinct case name) was previously entirely
            # unexercised by any fixture; `context_binding`/`resolver` are
            # already computed by the time this Block fires (step 10, before
            # step 12), so this is also this finding's third affected site.
            expected_id = "contract-discovery-failed"
            expected_detail = (
                "governing output schema discovery failed: facet-manifest.schema.json not found at the "
                "packaged or git-root contracts/ location"
            )
        elif case_name == "contract-discovery-failed-governing-schema-wrong-version":
            # Cross-model panel finding (T-004 NEEDS_WORK cycle 2, OpenAI
            # panelist, Major #1): `_load_governing_schema` previously only
            # checked that a governing schema file EXISTS and parses as
            # JSON -- never a per-artifact `$schema`/`$id` version check
            # (REQ-002/AC-002). This fixture's own `contracts/resolver-
            # evidence.schema.json` override (checked FIRST at step 12, so
            # this is a genuine, direct reach, not incidental) carries a
            # deliberately WRONG `$id` -- otherwise byte-identical to the
            # real schema -- so it is discoverable and parses cleanly, but
            # must still Block `contract-discovery-failed`, never silently
            # self-validate Resolver Evidence against a wrong-version
            # document.
            expected_id = "contract-discovery-failed"
            expected_detail = (
                "governing output schema discovery failed: resolver-evidence.schema.json "
                "failed its own $schema/$id version check"
            )
        elif case_name == "contract-discovery-failed-governing-schema-malformed":
            # Cross-model panel finding (T-004 NEEDS_WORK cycle 2, OpenAI
            # panelist, Major #2): a schema read/parse failure previously
            # interpolated the raw exception text (`{exc}`) into this
            # Block's own diagnostic detail and Resolver Evidence --
            # capable of carrying an absolute path/errno wording, violating
            # AC-014's canonical-sentence rule and security-spec.md B5's
            # no-local-path containment. This fixture's own `contracts/
            # resolver-evidence.schema.json` override is genuinely
            # malformed (not valid JSON at all), so `_load_governing_
            # schema`'s own `json.JSONDecodeError` handler fires for real;
            # the expected detail below asserts the exception's own CLASS
            # NAME only, never its message text (which would embed this
            # fixture's own absolute temp-directory path).
            expected_id = "contract-discovery-failed"
            expected_detail = (
                "governing output schema discovery failed: resolver-evidence.schema.json "
                "could not be read or parsed (JSONDecodeError)"
            )
        elif case_name == "contract-discovery-failed-governing-schema-invalid-utf8":
            # T-004 confirmation-panel bookkeeping-lag delta (OpenAI v3
            # Major 3): `_load_governing_schema`'s own `except (OSError,
            # json.JSONDecodeError)` previously let a genuinely invalid-
            # UTF-8 governing schema file escape uncaught -- `json.load`
            # raises `UnicodeDecodeError` (a `ValueError` subclass, not an
            # `OSError`/`JSONDecodeError`) while consuming the open
            # text-mode handle, before any JSON parsing is even attempted.
            # This fixture's own `contracts/resolver-evidence.schema.json`
            # override is byte-identical to the real schema except for one
            # deliberately invalid UTF-8 byte sequence (a lone continuation
            # byte, `\\xff\\x80`) inserted into the `title` string value --
            # confirmed genuinely invalid UTF-8 at fixture-authoring time
            # (`bytes.decode("utf-8")` raises `UnicodeDecodeError` on it
            # directly). The expected detail asserts the exception's own
            # CLASS NAME only, matching the identical no-raw-text
            # discipline the `-malformed` fixture above already
            # established.
            expected_id = "contract-discovery-failed"
            expected_detail = (
                "governing output schema discovery failed: resolver-evidence.schema.json "
                "could not be read or parsed (UnicodeDecodeError)"
            )
        elif case_name == "contract-discovery-failed-governing-schema-malformed-ref":
            # T-004 confirmation-panel bookkeeping-lag delta (OpenAI v3
            # Major 3): `_draft7_resolve_ref` walks a `$ref`'s own fragment
            # path directly against `root_schema` with no existence guard
            # -- a `$ref` naming a definition the schema's own
            # `definitions` block never declares previously escaped
            # `_self_validate_output` as an uncaught `KeyError`, a raw
            # traceback rather than the canonical `contract-discovery-
            # failed` Block REQ-002 requires. This fixture's own
            # `contracts/resolver-evidence.schema.json` override is
            # otherwise byte-identical to the real schema (genuinely
            # discoverable, correct `$schema`/`$id`, valid UTF-8/JSON) --
            # only `properties.context_binding.properties.
            # full_context_revision`'s own `$ref` is renamed to
            # `#/definitions/sha256DigestMissingDefinition`, a name
            # `definitions` never declares. `context_binding` is always
            # populated (all five required sub-fields, including
            # `full_context_revision`) by the time step 12 runs (T-004's
            # own "late Blocks drop provenance" fix), so this `$ref` is
            # genuinely reached during a normal step-12 self-validation of
            # this fixture's own otherwise-successful Evidence, never a
            # dead branch.
            expected_id = "contract-discovery-failed"
            expected_detail = (
                "governing output schema discovery failed: resolver-evidence.schema.json "
                "contains a malformed $ref (KeyError)"
            )
        elif case_name == "recheck-dependency-failed":
            # Fourth Pass finding, tested rather than left as a "no fixture
            # regression" disclosure: `_pre_publication_recheck`'s own
            # dependency calls now propagate `AffectedComponentResolution
            # Failed`/`DependencySubprocessFailed`/etc. UNWRAPPED (Fourth
            # Pass), mapped by `main()`'s own step-13 handler to the SAME
            # REQ-002 id step 4 already uses for an identical failure. This
            # fixture's own `resolve-component-paths` stub succeeds (a
            # FIXED, deterministic JSON document) on its first invocation
            # (step 4) and fails with a generic non-zero exit on its
            # second (step 13's own recheck) -- proving the recheck's own
            # internal dependency failure is `affected-component-
            # resolution-failed`, never re-labeled `snapshot-generation-
            # mismatch` (the earlier, incorrect revision this same pass
            # replaced).
            stub_name = "resolve-component-paths.py"
            expected_id = "affected-component-resolution-failed"
            expected_detail = (
                "resolve-component-paths exited 3 re-resolving affected components "
                "during the pre-publication recheck; see resolve-component-paths diagnostics"
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
        if (fixture_dir / "facet-manifest.schema.json").is_file():
            shutil.copy2(fixture_dir / "facet-manifest.schema.json", repo / "contracts/facet-manifest.schema.json")
        if case_name == "contract-discovery-failed-governing-schema":
            # Neither the packaged (`plugins/sdd-quality-loop/contracts/`,
            # never populated by any fixture in this driver, module
            # docstring section 5) nor the git-root location this line
            # just deleted resolves -- a genuine, both-locations-absent
            # ADR-0025 discovery failure for the full-track's own
            # `facet-manifest.schema.json`, step 12's own last governing
            # schema check (Resolver Evidence and Context Projection are
            # both still present and conformant).
            (repo / "contracts/facet-manifest.schema.json").unlink()

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

        # Cross-model panel finding (T-004 NEEDS_WORK cycle 2, "late Blocks
        # drop provenance"): steps 10-13 have already computed
        # `context_binding`/`resolver` by the time any of this function's
        # own three non-"evidence" Block cases fires, so this feature's own
        # Resolver Evidence record for each now carries both -- recomputed
        # here independently of `resolve-project-context.py` (never read
        # back off its own stdout/Evidence), via the REAL dependencies
        # (`resolve-component-paths`, the real canonicalizer) plus this
        # driver's own already-established oracle helpers, above.
        expected_context_binding = None
        if case_name != "output-schema-validation-failed-evidence":
            canonical_context = subprocess.run(
                [sys.executable, str(REAL_CANONICALIZER), str(repo / "project-context.yaml"), "--input-format", "yaml"],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
            ).stdout
            source_sha256 = "sha256:" + hashlib.sha256(canonical_context).hexdigest()
            if case_name == "recheck-dependency-failed":
                # This fixture's own `resolve-component-paths` stub
                # (installed above) never inspects argv and returns a
                # FIXED, deterministic document on its first invocation
                # (this invocation's own step 4) regardless of this repo's
                # own real git history, so the expected `context_binding`
                # below is pinned to that SAME fixed value, never
                # recomputed via the real dependency (which would observe
                # a different, genuine ownership_digest for this empty
                # diff) -- the identical "pin to the stub's own known
                # first-call output" discipline `snapshot-generation-
                # mismatch` already applies to its own `registry_digest`,
                # below.
                # Cross-model confirmation-panel Minor (Anthropic T-004,
                # RFC-6901 escape non-vacuity): the stub's own fixed
                # output additionally carries two escape-bearing ids
                # (shared/util, other~thing) alongside comp-a, so
                # expected_dependency_pointers below exercises the
                # literal ~->~0//->~1 lookup, not only the no-escape
                # identity case.
                affected_components = ["comp-a", "shared/util", "other~thing"]
                ownership_digest = "sha256:" + ("0" * 64)
            else:
                affected_components, ownership_digest = real_resolve_component_paths_context_binding(
                    repo, "project-context.yaml", base_oid, target_oid,
                )
            if case_name == "lite-check-source-undefined":
                projection_workflow = {
                    "spec_profile": "lite", "artifact_layout": "lite-three-file", "capability_enforcement": "required",
                }
                projection_components = {"comp-a": {"characteristics": {"pii": True}, "paths": {"include": ["comp-a/**"]}}}
                registry_digest = real_registry_digest(fixture_dir / "capability-registry.json")
            else:
                projection_workflow = {
                    "spec_profile": "full", "artifact_layout": "facet-native", "capability_enforcement": "advisory",
                }
                projection_components = {}
                if case_name == "snapshot-generation-mismatch":
                    # This fixture's own `generate-registry-digest.py` stub
                    # (installed above) returns a FIXED digest on its first
                    # call (this invocation's own step 6, staged into
                    # Resolver Evidence at step 11) and a DIFFERENT fixed
                    # digest on its second (step 13's own recheck, which
                    # never re-writes anything already staged) -- so the
                    # value this fixture's own Evidence record actually
                    # carries is the stub's own first, FIRST_DIGEST value,
                    # never the real registry file's own canonical digest.
                    registry_digest = "sha256:" + ("1" * 64)
                else:
                    registry_digest = real_registry_digest(EMPTY_REGISTRY_PATH)
            projection_document = {
                "schema": PROJECTION_SCHEMA,
                "source_sha256": source_sha256,
                "workflow": projection_workflow,
                "components": projection_components,
                "shared_paths": [],
            }
            projection_sha256 = "sha256:" + hashlib.sha256(_canonicalize_json_document(projection_document)).hexdigest()
            expected_context_binding = {
                "full_context_revision": source_sha256,
                "dependency_pointers": expected_dependency_pointers(affected_components),
                "projection_sha256": projection_sha256,
                "registry_digest": registry_digest,
                "ownership_digest": ownership_digest,
            }

        result = subprocess.run(
            t003_resolver_argv(kind, scripts, base_oid, target_oid),
            cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        )
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")

        expected_line = f"capability-resolver: {expected_id}: {expected_detail}\n"
        counts.check(result.returncode == 1, f"{case_name}: exit 1", f"got {result.returncode} stderr={stderr!r}")
        # Confirmation-panel Major (2026-08-24, both vendors) -- same fix
        # as `run_t003_case` above, since this stage's own step-13 recheck
        # reuses the identical `_run_resolve_component_paths` dependency
        # call site: the canonical line must be present and LAST, no
        # longer the WHOLE stream.
        counts.check(
            stdout == "" and stderr.endswith(expected_line),
            f"{case_name}: canonical diagnostic line present and last on stderr (B5)",
            f"stdout={stdout!r} stderr={stderr!r}",
        )
        if case_name == "recheck-dependency-failed":
            # Mutation-kill: this fixture's own `resolve-component-paths.py`
            # stub writes a known line to stderr on its second (step-13
            # recheck) invocation -- exact-equality proves the pass-through
            # fired, not merely that the canonical line is present.
            counts.check(
                stderr == "FIXTURE_INJECTED_FAILURE: resolve-component-paths failed on its second invocation\n" + expected_line,
                f"{case_name}: dependency stderr re-emitted verbatim before the canonical line (B5, REQ-005)",
                f"stderr={stderr!r}",
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
                "context_binding": expected_context_binding,
                "resolver": EXPECTED_RESOLVER_BLOCK,
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


def run_draft7_validator_keyword_checks(counts):
    """Cross-model panel finding (T-004 NEEDS_WORK cycle 2, OpenAI
    panelist): step 12's own defensive draft-07-subset output-schema
    validator (`_draft7_validate`) did not implement `not`/`minimum` --
    two keywords the REAL, unmodified governing `contracts/resolver-
    evidence.schema.json` itself uses (`capabilityEvaluation.then.not.
    required` forbids `conditional_facet_evaluations` on a `matched: false`
    entry, B6; `declaration_index`'s own `minimum: 0`). An unimplemented
    keyword this validator's own governing schema declares is not a no-op
    defensive check -- it is a silent pass on exactly the malformed shape
    that keyword exists to reject.

    Loads the SAME staged `resolve-project-context.py` file (never a
    second, reimplemented copy) and calls its own `_draft7_conforms`
    directly against the REAL governing schema, fed hand-built instances --
    the identical "call the real staged function directly" white-box
    discipline `resolve-project-context-match-check.py`'s own
    `run_facet_manifest_state_independence_check` already established for
    a property with no CLI-observable trigger (a correctly-behaved
    resolver never itself emits the non-conforming shape this validator
    exists to catch, so this property cannot be exercised end-to-end
    through a real subprocess invocation alone)."""
    staged_py = STAGED / "resolve-project-context.py"
    if not staged_py.is_file():
        counts.check(False, "draft7-validator-keywords: staged implementation exists", "TDD RED: implementation absent")
        return

    import importlib.util
    spec = importlib.util.spec_from_file_location("resolve_project_context_draft7_oracle", staged_py)
    resolver_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(resolver_module)

    if not hasattr(resolver_module, "_draft7_conforms"):
        # `_draft7_conforms`/`_draft7_validate` are T-004's own step-12
        # additions (output schema self-validation) -- absent from a T-003-
        # or-earlier snapshot (e.g. this driver's own RED reconstruction,
        # which rewinds resolve-project-context.py to its pre-T-003
        # content). A clean, reportable FAIL here, never an unguarded
        # AttributeError crashing the whole suite before it prints a
        # RESULT line (the identical discipline `cfe_pairs` already
        # applies in resolve-project-context-match-check.py for the same
        # class of "staged code predates this check's own dependency"
        # gap).
        counts.check(False, "draft7-validator-keywords: _draft7_conforms exists on the staged module",
                     "TDD RED: T-004 step-12 self-validation absent from this staged snapshot")
        return

    with SCHEMA.open("r", encoding="utf-8") as handle:
        schema = json.load(handle)

    def envelope(evaluation):
        return {
            "schema": "sdd-resolver-evidence/v1",
            "feature": "example-feature",
            "capability_evaluations": [evaluation],
            "diagnostics": [],
        }

    unmatched_conforming = {"capability_id": "cap-a", "matched": False, "trigger_evaluations": []}
    counts.check(
        resolver_module._draft7_conforms(envelope(unmatched_conforming), schema),
        "draft7-validator-keywords: a matched:false entry with no conditional_facet_evaluations conforms (sanity)",
    )

    unmatched_with_cfe = dict(unmatched_conforming)
    unmatched_with_cfe["conditional_facet_evaluations"] = []
    counts.check(
        not resolver_module._draft7_conforms(envelope(unmatched_with_cfe), schema),
        "draft7-validator-keywords: `not` -- a matched:false entry carrying conditional_facet_evaluations is "
        "rejected (resolver-evidence.schema.json capabilityEvaluation.then.not.required)",
    )

    def matched_with_index(declaration_index):
        return {
            "capability_id": "cap-b", "matched": True, "trigger_evaluations": [],
            "conditional_facet_evaluations": [{
                "facet": "some-facet", "declaration_index": declaration_index,
                "applied": False, "evaluations": [],
            }],
        }

    counts.check(
        not resolver_module._draft7_conforms(envelope(matched_with_index(-1)), schema),
        "draft7-validator-keywords: `minimum` -- a negative declaration_index is rejected "
        "(resolver-evidence.schema.json conditional_facet_evaluations[].declaration_index minimum:0)",
    )
    counts.check(
        resolver_module._draft7_conforms(envelope(matched_with_index(0)), schema),
        "draft7-validator-keywords: declaration_index: 0 conforms (sanity, minimum is inclusive)",
    )

    # Cross-model confirmation-panel Minor (Anthropic T-004): `pattern`
    # fixes ECMA-262 semantics, where `$` matches ONLY at the true end of
    # the subject string -- Python's own `$` additionally matches
    # immediately before a single trailing `\n`. `feature`'s own
    # `^[a-z0-9][a-z0-9-]*$` pattern (this same governing schema's own
    # top-level `feature` property) is the white-box probe: a value
    # carrying a trailing newline is schema-illegal under ECMA-262/JSON-
    # Schema semantics and must be rejected, never silently accepted by a
    # Python-`$`-specific loophole.
    trailing_newline_envelope = dict(envelope(unmatched_conforming))
    trailing_newline_envelope["feature"] = "example-feature\n"
    counts.check(
        not resolver_module._draft7_conforms(trailing_newline_envelope, schema),
        "draft7-validator-keywords: `pattern` -- a feature value carrying a trailing newline is rejected, "
        "never accepted via Python re's own $-before-trailing-newline exception to ECMA-262 semantics "
        "(resolver-evidence.schema.json feature pattern)",
    )
    clean_envelope = dict(envelope(unmatched_conforming))
    clean_envelope["feature"] = "example-feature"
    counts.check(
        resolver_module._draft7_conforms(clean_envelope, schema),
        "draft7-validator-keywords: feature: 'example-feature' (no trailing newline) conforms (sanity)",
    )


# --- T-004 cross-model panel finding, Major #3: draft-07 engine coverage ---
# meta-assertion ------------------------------------------------------------
#
# Two consecutive panel rounds each found ONE instance of `_draft7_validate`
# silently no-op'ing on a keyword its own governing schema actually uses
# (`not`, then `minimum`) -- each closed keyword-by-keyword. This
# meta-assertion converts the class from "silent, found one keyword at a
# time" to "loud, permanently": it enumerates every draft-07 keyword each of
# the four REAL, landed governing schemas actually uses (walking each
# document's own schema tree -- `properties`/`definitions`/
# `patternProperties` values, `items`/`allOf`/`anyOf`/`oneOf` elements,
# `if`/`then`/`else`/`not`/`contains`/`additionalProperties`/
# `propertyNames`/`additionalItems` sub-schemas -- never a flat string-key
# grep, which would also match ordinary property NAMES that happen to look
# like a keyword, e.g. this feature's own `facet`/`applied`/`title`-shaped
# field names) and fails if any schema uses a keyword `_draft7_validate`
# does not implement.

DRAFT7_METADATA_ONLY_KEYWORDS = frozenset({
    # Annotation/identity keywords that never themselves constrain instance
    # data -- correctly absent from `_draft7_validate`'s own keyword
    # handling, not a gap.
    "$id", "$schema", "title", "description", "definitions", "default", "examples",
})

# Mirrors `_draft7_validate`'s own implemented keyword set BY HAND (never
# introspected from the module under test, matching this driver's own
# "independent oracle" discipline throughout) -- maintained alongside any
# future change to that function.
DRAFT7_IMPLEMENTED_KEYWORDS = frozenset({
    "$ref", "const", "enum", "type", "oneOf", "if", "then", "else", "not",
    "pattern", "minLength", "minimum", "required", "properties",
    "propertyNames", "additionalProperties", "items", "uniqueItems", "minItems",
})

# The FULL draft-07 keyword vocabulary this walker recognizes at a
# schema-keyword position -- an INDEPENDENT, hardcoded literal (never
# derived from `DRAFT7_IMPLEMENTED_KEYWORDS` via set union) so that
# mutating/shrinking `DRAFT7_IMPLEMENTED_KEYWORDS` cannot also shrink this
# set: this is what makes a real schema using a keyword this engine does
# NOT implement still show up as `used` below (and therefore as `missing`)
# instead of silently vanishing because it was never on the "implemented"
# list to begin with. Covers every standard draft-07 keyword: the ones
# `_draft7_validate` implements, the metadata-only ones, and every other
# standard keyword it does not implement.
DRAFT7_KNOWN_KEYWORDS = frozenset({
    "$ref", "$id", "$schema", "title", "description", "definitions", "default", "examples",
    "const", "enum", "type", "oneOf", "allOf", "anyOf", "if", "then", "else", "not",
    "pattern", "minLength", "maxLength", "minimum", "maximum",
    "exclusiveMinimum", "exclusiveMaximum", "multipleOf",
    "required", "properties", "propertyNames", "patternProperties",
    "additionalProperties", "dependencies",
    "items", "additionalItems", "maxItems", "minItems", "uniqueItems", "contains",
    "maxProperties", "minProperties",
    "format", "contentEncoding", "contentMediaType",
})

GOVERNING_SCHEMA_FILES = {
    "resolver-evidence.schema.json": RESOLVER_EVIDENCE_SCHEMA_REAL,
    "context-projection.schema.json": ROOT / "contracts/context-projection.schema.json",
    "facet-manifest.schema.json": FACET_MANIFEST_SCHEMA_REAL,
    "capability-summary.schema.json": ROOT / "contracts/capability-summary.schema.json",
}


def _draft7_schema_keywords_used(node, found):
    """Test-harness-only schema walker (never imported from the module
    under test): collects every draft-07 KEYWORD position this schema tree
    actually uses, correctly distinguishing a keyword position from a
    sibling property-NAME/definition-NAME/enum-value position (a flat
    string-key grep cannot make this distinction -- it would also match
    this feature's own field names like `facet`/`applied` that happen to
    share a spelling with no real keyword here, and would MISS keywords
    nested only inside `if`/`then`/`else`/`not`/`allOf` branches, which a
    naive regex-based counterpart earlier in this investigation did in
    fact reach for these four schemas). Membership in `found` is decided
    against `DRAFT7_KNOWN_KEYWORDS` -- the full vocabulary superset, NEVER
    `DRAFT7_IMPLEMENTED_KEYWORDS` alone -- so this walker still records a
    real, unimplemented keyword's own usage instead of silently dropping
    it (which would make `run_draft7_keyword_coverage_check`'s own
    `missing` computation vacuously empty regardless of what
    `DRAFT7_IMPLEMENTED_KEYWORDS` says)."""
    if isinstance(node, bool) or not isinstance(node, dict):
        return
    for key, value in node.items():
        if key in DRAFT7_KNOWN_KEYWORDS:
            found.add(key)
        if key in ("properties", "patternProperties", "definitions"):
            if isinstance(value, dict):
                for sub in value.values():
                    _draft7_schema_keywords_used(sub, found)
        elif key == "items":
            if isinstance(value, list):
                for sub in value:
                    _draft7_schema_keywords_used(sub, found)
            else:
                _draft7_schema_keywords_used(value, found)
        elif key in (
            "additionalItems", "additionalProperties", "propertyNames",
            "if", "then", "else", "not", "contains",
        ):
            _draft7_schema_keywords_used(value, found)
        elif key in ("allOf", "anyOf", "oneOf"):
            if isinstance(value, list):
                for sub in value:
                    _draft7_schema_keywords_used(sub, found)
        elif key == "dependencies":
            if isinstance(value, dict):
                for sub in value.values():
                    if isinstance(sub, dict):
                        _draft7_schema_keywords_used(sub, found)


def run_draft7_keyword_coverage_check(counts):
    for filename, path in GOVERNING_SCHEMA_FILES.items():
        with path.open("r", encoding="utf-8") as handle:
            schema = json.load(handle)
        used = set()
        _draft7_schema_keywords_used(schema, used)
        used -= DRAFT7_METADATA_ONLY_KEYWORDS
        missing = sorted(used - DRAFT7_IMPLEMENTED_KEYWORDS)
        counts.check(
            not missing,
            f"draft7-keyword-coverage: {filename} uses only keywords _draft7_validate implements",
            f"missing={missing}",
        )


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
            "resolve-component-paths-launch-failed",
            "contract-discovery-failed",
            "registry-discovery-unimportable",
            "registry-validation-failed",
            "validate-capability-registry-launch-failed",
            "dependency-subprocess-failed",
            "evaluate-predicate-output-malformed",
            "evaluate-predicate-schema-error",
            "evaluate-predicate-failure-after-warn",
            "dsl-warn-unmatched-trigger",
            "dsl-warn-matched-nondetermining",
            "dsl-warn-unsorted-affected-components",
            "registry-swapped-during-validation",
            "registry-discovery-syntax-error",
        ):
            run_t003_case(args.launcher, case_name, counts)
        for case_name in (
            "lite-check-source-undefined",
            "output-schema-validation-failed-evidence",
            "output-schema-validation-failed-artifact",
            "output-schema-validation-failed-facet-manifest",
            "snapshot-generation-mismatch",
            "contract-discovery-failed-governing-schema",
            "contract-discovery-failed-governing-schema-wrong-version",
            "contract-discovery-failed-governing-schema-malformed",
            "contract-discovery-failed-governing-schema-invalid-utf8",
            "contract-discovery-failed-governing-schema-malformed-ref",
            "recheck-dependency-failed",
        ):
            run_t004_case(args.launcher, case_name, counts)
        run_draft7_validator_keyword_checks(counts)
        run_draft7_keyword_coverage_check(counts)

    sh_registered = "tests/resolve-project-context-block.tests.sh" in (ROOT / "tests/run-all.sh").read_text(encoding="utf-8")
    ps_registered = "tests/resolve-project-context-block.tests.ps1" in (ROOT / "tests/run-all.ps1").read_text(encoding="utf-8")
    counts.check(sh_registered, "POSIX suite registered in tests/run-all.sh")
    counts.check(ps_registered, "PowerShell suite registered in tests/run-all.ps1")

    print(f"RESULT: {counts.passed} passed, {counts.failed} failed")
    return 1 if counts.failed else 0


if __name__ == "__main__":
    sys.exit(main())
