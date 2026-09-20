#!/usr/bin/env python3
"""T-010 driver shared by the POSIX and PowerShell twins for
`resolve-project-context-metamorphic` (design.md Test Strategy item 9, M10):
the completeness/invariance suite an earlier revision of this design left
unfixtured (AC-045). Every case below drives the assembled, staged
`resolve-project-context` CLI as a genuine subprocess against a real,
throwaway git repository -- never a mocked stand-in for the engine under
test -- reusing `tests/resolve-project-context-block-check.py`'s own
already-established fixture-repo/dependency-planting/schema-checking
helpers (loaded by path, via `_load_module`, since a hyphenated filename
cannot be a normal Python import target), matching every sibling driver in
this feature's own suite (`resolve-project-context-match-check.py`,
`resolve-project-context-parity-check.py`, `validate-resolver-evidence-
check.py`).

Sub-items (a)-(g) below are design.md Test Strategy item 9's own seven
named locks, in that order:

(a) `run_combination_matrix_case` -- all four true/false combinations of a
    2-affected-component `trigger` result (TT/TF/FT/FF), asserting
    `matched` exactly per the union-match rule in every case.
(b) `run_order_invariance_case` -- the identical fixture's own
    `affected_components[]` fed in each of its 2 possible orderings,
    asserting byte-identical output.
(c) `run_multi_true_dedup_case` -- a 3-affected-component fixture with more
    than one `true` evaluation, asserting the Capability is recorded
    exactly once.
(d) `run_reason_template_case` -- an `applied: false` `conditional_facets[]`
    fixture whose `reason` is asserted VERBATIM against the exact template.
(e) `run_warn_matched_trigger_case` / `run_warn_unmatched_trigger_case` /
    `run_warn_conditional_facet_case` -- one fixture per WARN branch, each
    independently Blocking (B2).
(f) `run_nested_array_completeness_case` -- reuses `validate-resolver-
    evidence-check.py`'s own already-established fixtures/helpers (loaded
    by path, this task's own Depends On T-008 text: "validate-resolver-
    evidence's own exact-set checks are this suite's own assertion
    mechanism for the nested-array-completeness fixture") to drive the
    REAL `validate-resolver-evidence` against the `clean` fixture (passes)
    and one intentionally-corrupted copy per nesting level (fails with the
    matching check-id): `capability-set-mismatch` (`capability_
    evaluations[]`), `trigger-evaluation-set-mismatch`
    (`trigger_evaluations[]`), `conditional-facet-set-mismatch`
    (`conditional_facet_evaluations[]`), `conditional-facet-evaluation-
    set-mismatch` (`evaluations[]`) -- the four arrays design.md's own
    item 9(f) names, in that order.
(g) `run_dependency_order_spy_case` -- a PATH-free, filename-overlay spy
    (the identical "capture, then delegate to a `-real` sibling" technique
    T-002's own suite already established, generalized to five dependency
    names at once) asserting this invocation's own first seven subprocess
    launches are exactly canonicalize-sdd-yaml (Project Context pass) ->
    canonicalize-sdd-yaml (Context Projection pass) -> resolve-component-
    paths -> validate-capability-registry -> generate-registry-digest ->
    evaluate-predicate (trigger fan-out) -> evaluate-predicate
    (conditional-facet fan-out), and that a forced non-zero exit at each
    position in turn Blocks with that position's own correct diagnostic id
    and invokes no later-ordered subprocess at all.

**Specification difference, disclosed (see this task's own implementation
report for the full write-up):** design.md's own item 9(g) text names this
invocation's own fourth subprocess-observable position "Registry
discovery". Read literally against `resolve-project-context.py`'s own
step 5, Registry discovery ITSELF (`_discover_registry`) is a co-located
sibling-module IMPORT, never a subprocess launch -- the only genuine
subprocess `resolve-project-context.py` invokes at step 5 is
`validate-capability-registry` (`_validate_capability_registry`). This
driver spies on the real, observable subprocess at that position
(`validate-capability-registry`) rather than a non-existent "registry
discovery" subprocess, which is the only reading under which item 9(g)'s
own list of SEVEN names maps onto SEVEN real `subprocess.run` call sites
in `resolve-project-context.py` at all.

`generate-registry-digest.py` internally invokes `canonicalize-sdd-yaml.py`
as its OWN nested dependency (to hash the discovered Registry) -- an
unguarded canonicalize-sdd-yaml spy would therefore also fire on that
GRANDCHILD call, one call after the "generate-registry-digest" position,
polluting the seven-call sequence this fixture exists to prove. Every spy
shim below propagates `SDD_SPY_SUPPRESS=1` into its own delegate's
environment before calling its `-real` sibling, and every spy shim skips
its own logging/fail-check entirely whenever ITS OWN environment already
carries that flag -- so only `resolve-project-context.py`'s own DIRECT
subprocess launches are ever logged, never a grandchild call a dependency
makes on its own behalf.

Plus the feature-wide completeness lock the Done When bullet requires:
`run_feature_wide_completeness_check` confirms every one of the nine
`tests/*.tests.{sh,ps1}` suite pairs T-001..T-010 build (AC-026, "nine of
ten" -- item 10's own live-caller-contract suite is explicitly deferred,
Global Constraints "Deferred, Not Scheduled") is present and registered in
`tests/run-all.{sh,ps1}`, and that at least one independently-invocable
fixture anchor exists under `tests/fixtures/capability-resolver/` for each
of REQ-006's own fixture-matrix items (a)-(h) (AC-027).
"""

import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
FIXTURES_ROOT = ROOT / "tests/fixtures/capability-resolver"
FIXTURES = FIXTURES_ROOT / "metamorphic"


def _load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# Reused, not reinvented (module docstring, above): T-002/T-003/T-004's own
# fixture-repo/dependency-planting/schema-checking helpers.
block_check = _load_module(
    Path(__file__).resolve().parent / "resolve-project-context-block-check.py",
    "resolve_project_context_block_check_t010",
)
# T-008's own already-established fixtures/helpers, reused verbatim for
# sub-item (f) rather than reinvented (module docstring, above).
validate_check = _load_module(
    Path(__file__).resolve().parent / "validate-resolver-evidence-check.py",
    "validate_resolver_evidence_check_t010",
)


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


def _setup_repo(fixture_dir, project_context_name="project-context.yaml"):
    """Shared throwaway-repo assembly for every (a)-(e) sub-item: real
    dependencies (no stub -- these fixtures never need to force drift),
    the fixture's own Registry + Project Context, sentinels planted so a
    Block fixture can independently confirm no partial live write."""
    tmp = tempfile.mkdtemp(prefix="resolver-metamorphic-")
    repo = Path(tmp).resolve()
    subprocess.run(["git", "init", "-q", str(repo)], check=True, capture_output=True)
    scripts = block_check.install_scripts(repo)
    feature_dir, sentinels = block_check.plant_sentinels(repo, scripts)
    shutil.copy2(fixture_dir / project_context_name, repo / "project-context.yaml")
    block_check.install_t003_dependencies(
        repo, scripts, fixture_dir, stub_name=None,
        registry_capabilities_path=fixture_dir / "capability-registry.json",
    )
    return repo, scripts, feature_dir, sentinels


def _commit_components(repo, component_ids):
    (repo / "README.md").write_text("baseline\n", encoding="utf-8")
    base_oid = block_check.git_commit_all(repo, "baseline")
    for component_id in component_ids:
        (repo / component_id).mkdir()
        (repo / component_id / "file.txt").write_text(f"{component_id}\n", encoding="utf-8")
    target_oid = block_check.git_commit_all(repo, "add " + ", ".join(component_ids))
    return base_oid, target_oid


# ---------------------------------------------------------------------------
# (a) TT/TF/FT/FF union-match combination matrix (AC-045's own first lock).
# ---------------------------------------------------------------------------

COMBINATION_CASES = (
    ("tt", True, True, True),
    ("tf", True, False, True),
    ("ft", False, True, True),
    ("ff", False, False, False),
)

TRIGGER_PII_EQUALS_TRUE = {
    "scope": "affected_component", "field": "characteristics.pii", "operator": "equals", "value": True,
}


def _component_properties(pii, extra_paths_id):
    return {
        "characteristics": {"pii": pii, "ui": False, "auto_update": False, "local_persistence": False},
        "paths": {"include": [f"{extra_paths_id}/**"]},
    }


def run_combination_matrix_case(kind, counts):
    fixture_dir = FIXTURES / "combination-matrix"
    for variant, comp_a_pii, comp_b_pii, expected_matched in COMBINATION_CASES:
        case_name = f"combination-matrix-{variant}"
        repo, scripts, feature_dir, sentinels = _setup_repo(fixture_dir, f"project-context-{variant}.yaml")
        try:
            base_oid, target_oid = _commit_components(repo, ["comp-a", "comp-b"])
            argv = block_check.t003_resolver_argv(kind, scripts, base_oid, target_oid)
            result = subprocess.run(argv, cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
            counts.check(
                result.returncode == 0,
                f"{case_name}: clean run (exit 0)",
                f"exit={result.returncode} stdout={result.stdout!r} stderr={result.stderr!r}",
            )

            comp_a_props = _component_properties(comp_a_pii, "comp-a")
            comp_b_props = _component_properties(comp_b_pii, "comp-b")
            result_a, evidence_a = block_check.real_evaluate_predicate(TRIGGER_PII_EQUALS_TRUE, comp_a_props)
            result_b, evidence_b = block_check.real_evaluate_predicate(TRIGGER_PII_EQUALS_TRUE, comp_b_props)
            counts.check(
                result_a is comp_a_pii and result_b is comp_b_pii,
                f"{case_name}: fixture sanity -- comp-a/comp-b trigger results equal this cell's own pii values",
                repr((result_a, result_b)),
            )

            evidence_path = feature_dir / "resolver-evidence.yaml"
            evidence, parse_error = block_check.read_evidence(evidence_path)
            entry = None
            if isinstance(evidence, dict):
                entry = next(
                    (e for e in evidence.get("capability_evaluations", []) if e.get("capability_id") == "cap-union"),
                    None,
                )
            counts.check(
                entry is not None and entry.get("matched") == expected_matched,
                f"{case_name}: matched == {expected_matched} exactly per the union-match rule "
                f"(comp-a pii={comp_a_pii}, comp-b pii={comp_b_pii}) (AC-045(a))",
                parse_error or repr(entry),
            )
            expected_trigger_evaluations = [
                {"component_id": "comp-a", "result": result_a, "evidence": evidence_a},
                {"component_id": "comp-b", "result": result_b, "evidence": evidence_b},
            ]
            counts.check(
                entry is not None and entry.get("trigger_evaluations") == expected_trigger_evaluations,
                f"{case_name}: trigger_evaluations exact, per-component results independently "
                f"recomputed via the real evaluate-predicate",
                repr(entry.get("trigger_evaluations") if entry else None),
            )
            block_check.check_evidence_schema(counts, evidence_path, case_name)
        finally:
            shutil.rmtree(repo, ignore_errors=True)


# ---------------------------------------------------------------------------
# (b) affected_components[] input-order invariance (AC-045's own second
# lock, REQ-005).
# ---------------------------------------------------------------------------

def run_order_invariance_case(kind, counts):
    case_name = "order-invariance"
    fixture_dir = FIXTURES / "order-invariance"
    captured = {}
    for order in ("a", "b"):
        repo, scripts, feature_dir, sentinels = _setup_repo(fixture_dir)
        try:
            # This fixture's own resolve-component-paths[] input order is
            # controlled by a fixed-output stub, never the real dependency
            # (real `git diff` output order cannot be deterministically
            # forced two different ways) -- `_setup_repo` already installed
            # the REAL resolve-component-paths.py via `install_t003_
            # dependencies`; this overlay replaces it with the order-`a`/
            # order-`b` fixture stub, matching every other stub-overlay
            # fixture in this feature's own suite.
            shutil.copy2(fixture_dir / f"resolve-component-paths-order-{order}.py", scripts / "resolve-component-paths.py")
            base_oid = block_check.git_commit_all(repo, "baseline")
            target_oid = base_oid
            argv = block_check.t003_resolver_argv(kind, scripts, base_oid, target_oid)
            result = subprocess.run(argv, cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
            counts.check(
                result.returncode == 0,
                f"{case_name}-{order}: clean run (exit 0)",
                f"exit={result.returncode} stdout={result.stdout!r} stderr={result.stderr!r}",
            )
            evidence_path = feature_dir / "resolver-evidence.yaml"
            manifest_path = feature_dir / "facet-manifest.yaml"
            projection_path = scripts / "generated/project-context.resolved.json"
            captured[order] = {
                "stdout": result.stdout,
                "stderr": result.stderr,
                "evidence": evidence_path.read_bytes() if evidence_path.is_file() else b"",
                "manifest": manifest_path.read_bytes() if manifest_path.is_file() else b"",
                "projection": projection_path.read_bytes() if projection_path.is_file() else b"",
            }
        finally:
            shutil.rmtree(repo, ignore_errors=True)

    counts.check(
        len(captured.get("a", {}).get("evidence", b"")) > 0,
        f"{case_name}: fixture sanity -- Resolver Evidence bytes are genuinely non-empty "
        f"(so the byte-identity checks below are not vacuously true on two empty strings)",
    )
    for key in ("stdout", "stderr", "evidence", "manifest", "projection"):
        counts.check(
            captured["a"][key] == captured["b"][key],
            f"{case_name}: {key} byte-identical regardless of affected_components[] input order "
            f"([comp-a, comp-b] vs. [comp-b, comp-a], same set) (AC-045(b), REQ-005)",
            repr((captured["a"][key][:200], captured["b"][key][:200])),
        )


# ---------------------------------------------------------------------------
# (c) >1-true-component single-recording, no duplication (AC-045's own
# third lock).
# ---------------------------------------------------------------------------

def run_multi_true_dedup_case(kind, counts):
    case_name = "multi-true-dedup"
    fixture_dir = FIXTURES / case_name
    repo, scripts, feature_dir, sentinels = _setup_repo(fixture_dir)
    try:
        base_oid, target_oid = _commit_components(repo, ["comp-a", "comp-b", "comp-c"])
        argv = block_check.t003_resolver_argv(kind, scripts, base_oid, target_oid)
        result = subprocess.run(argv, cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        counts.check(
            result.returncode == 0,
            f"{case_name}: clean run (exit 0)",
            f"exit={result.returncode} stdout={result.stdout!r} stderr={result.stderr!r}",
        )

        evidence_path = feature_dir / "resolver-evidence.yaml"
        evidence, parse_error = block_check.read_evidence(evidence_path)
        matches = []
        if isinstance(evidence, dict):
            matches = [e for e in evidence.get("capability_evaluations", []) if e.get("capability_id") == "cap-union"]
        counts.check(
            len(matches) == 1,
            f"{case_name}: cap-union recorded exactly once in capability_evaluations[] despite more than "
            f"one component's own evaluation being true (comp-a, comp-b), never duplicated (AC-045(c))",
            parse_error or repr(matches),
        )
        entry = matches[0] if matches else {}
        true_count = sum(1 for e in entry.get("trigger_evaluations", []) if e.get("result") is True)
        counts.check(
            entry.get("matched") is True and true_count >= 2,
            f"{case_name}: fixture sanity -- more than one component's own evaluation is genuinely "
            f"true ({true_count})",
            repr(entry.get("trigger_evaluations")),
        )

        manifest_path = feature_dir / "facet-manifest.yaml"
        manifest, manifest_error = block_check.read_evidence(manifest_path)
        manifest_capabilities = manifest.get("capabilities") if isinstance(manifest, dict) else None
        counts.check(
            manifest_capabilities == ["cap-union"],
            f"{case_name}: Facet Manifest capabilities[] names cap-union exactly once too",
            manifest_error or repr(manifest_capabilities),
        )
        block_check.check_evidence_schema(counts, evidence_path, case_name)
    finally:
        shutil.rmtree(repo, ignore_errors=True)


# ---------------------------------------------------------------------------
# (d) verbatim applied:false reason template (AC-045's own fourth lock).
# ---------------------------------------------------------------------------

REASON_TEMPLATE = (
    "no contributing predicate instance's conditional facet matched any affected component "
    "(contributing: cap-d[0])"
)


def run_reason_template_case(kind, counts):
    case_name = "reason-template"
    fixture_dir = FIXTURES / case_name
    repo, scripts, feature_dir, sentinels = _setup_repo(fixture_dir)
    try:
        base_oid, target_oid = _commit_components(repo, ["comp-a"])
        argv = block_check.t003_resolver_argv(kind, scripts, base_oid, target_oid)
        result = subprocess.run(argv, cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        counts.check(
            result.returncode == 0,
            f"{case_name}: clean run (exit 0)",
            f"exit={result.returncode} stdout={result.stdout!r} stderr={result.stderr!r}",
        )

        evidence_path = feature_dir / "resolver-evidence.yaml"
        evidence, parse_error = block_check.read_evidence(evidence_path)
        entry = None
        if isinstance(evidence, dict):
            entry = next(
                (e for e in evidence.get("capability_evaluations", []) if e.get("capability_id") == "cap-d"),
                None,
            )
        cfe = (entry or {}).get("conditional_facet_evaluations", [])
        # `capability_evaluations[].conditional_facet_evaluations[]` entries
        # (`_evaluate_capabilities`, resolve-project-context.py) never carry
        # a `reason` key at all -- that field is owned exclusively by the
        # AGGREGATED Facet Manifest's own `conditional_facets[]` array
        # (`_aggregate_conditional_facets`, "reason (present iff applied:
        # false)"), the literal `conditional_facets[]` name design.md's own
        # item 9(d) text names. This per-Capability entry is asserted for
        # its own correct `applied: false` shape (no `reason` leak at the
        # wrong level); the manifest-level assertion below is this fixture's
        # own VERBATIM template lock.
        counts.check(
            len(cfe) == 1 and cfe[0].get("applied") is False and "reason" not in cfe[0],
            f"{case_name}: Resolver Evidence's own per-Capability conditional_facet_evaluations[] entry is "
            f"applied: false with no reason key at this level (reason is the aggregated Facet Manifest's "
            f"own field, asserted verbatim below, AC-045(d))",
            parse_error or repr(cfe),
        )

        manifest_path = feature_dir / "facet-manifest.yaml"
        manifest, manifest_error = block_check.read_evidence(manifest_path)
        aggregated = None
        if isinstance(manifest, dict):
            aggregated = next((n for n in manifest.get("conditional_facets", []) if n.get("facet") == "solo-facet"), None)
        counts.check(
            aggregated is not None and aggregated.get("applied") is False and aggregated.get("reason") == REASON_TEMPLATE,
            f"{case_name}: Facet Manifest's own conditional_facets[] applied: false entry carries `reason` "
            f"VERBATIM against the exact template this feature's design fixes (AC-045(d))",
            manifest_error or repr(aggregated),
        )
        block_check.check_evidence_schema(counts, evidence_path, case_name)
    finally:
        shutil.rmtree(repo, ignore_errors=True)


# ---------------------------------------------------------------------------
# (e) one fixture per WARN branch, each independently Blocking (B2).
# ---------------------------------------------------------------------------

WARN_BLOCK_DETAIL = "a predicate evaluation produced an outcome: warn evidence node"
WARN_BLOCK_CANONICAL_LINE = f"capability-resolver: dsl-warn-on-matched-capability: {WARN_BLOCK_DETAIL}\n"


def _collect_warn_entries(capability_id, component_id, declaration_index, evidence_nodes):
    """Independent (non-hand-transcribed) collection of every
    `outcome: warn` node this fixture's own minimal (leaf-only, never
    all/any-wrapped) predicates can produce. Each per-component `evidence`
    list this suite's own predicates ever produce is exactly ONE root node
    (`evaluate-predicate.py`'s own `evidence = [root_evidence]` wrapping),
    so its own `node_path` is always `(0,)` when that root node is itself a
    WARN leaf -- a structural fact about THIS fixture's own predicate
    shape (never all/any-nested), not a hand-transcribed expectation of
    `evaluate-predicate`'s own output."""
    entries = []
    for index, node in enumerate(evidence_nodes):
        if node.get("outcome") == "warn":
            entries.append(block_check.expected_warn_diagnostic(capability_id, component_id, declaration_index, (index,), node))
    return entries


def _expected_diagnostics(warn_entries):
    return sorted(
        list(warn_entries) + [{"id": "dsl-warn-on-matched-capability", "detail": WARN_BLOCK_DETAIL, "severity": "block"}],
        key=lambda entry: (entry["id"], entry["detail"]),
    )


def run_warn_matched_trigger_case(kind, counts):
    """matched-capability-trigger-WARN: comp-a's own trigger evaluation
    genuinely matches; comp-b's own trigger evaluation is a WARN
    (missing-path) on a non-determining branch -- `matched` is already
    `True` from comp-a alone -- yet this invocation still Blocks (B2's
    own widened any-branch scope)."""
    case_name = "warn-matched-trigger"
    fixture_dir = FIXTURES / case_name
    repo, scripts, feature_dir, sentinels = _setup_repo(fixture_dir)
    try:
        base_oid, target_oid = _commit_components(repo, ["comp-a", "comp-b"])
        argv = block_check.t003_resolver_argv(kind, scripts, base_oid, target_oid)
        result = subprocess.run(argv, cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        counts.check(result.returncode == 1, f"{case_name}: exit 1 (Block)", f"got {result.returncode} stderr={stderr!r}")
        counts.check(
            stdout == "" and stderr == WARN_BLOCK_CANONICAL_LINE,
            f"{case_name}: canonical diagnostic only",
            f"stdout={stdout!r} stderr={stderr!r}",
        )

        comp_a_props = {
            "characteristics": {"pii": True, "ui": False, "auto_update": False, "local_persistence": False},
            "paths": {"include": ["comp-a/**"]},
        }
        comp_b_props = {
            "characteristics": {"ui": False, "auto_update": False, "local_persistence": False},
            "paths": {"include": ["comp-b/**"]},
        }
        result_a, evidence_a = block_check.real_evaluate_predicate(TRIGGER_PII_EQUALS_TRUE, comp_a_props)
        result_b, evidence_b = block_check.real_evaluate_predicate(TRIGGER_PII_EQUALS_TRUE, comp_b_props)
        counts.check(
            result_a is True and evidence_b[0].get("outcome") == "warn",
            f"{case_name}: fixture sanity -- comp-a genuinely matches, comp-b genuinely WARNs (missing-path)",
            repr((result_a, evidence_b)),
        )

        trigger_evaluations = [
            {"component_id": "comp-a", "result": result_a, "evidence": evidence_a},
            {"component_id": "comp-b", "result": result_b, "evidence": evidence_b},
        ]
        warn_entries = _collect_warn_entries("cap-w1", "comp-b", None, evidence_b)
        expected_evidence = {
            "schema": "sdd-resolver-evidence/v1",
            "feature": "example-feature",
            "state": "advisory",
            "capability_evaluations": [
                {"capability_id": "cap-w1", "matched": True, "trigger_evaluations": trigger_evaluations, "conditional_facet_evaluations": []},
            ],
            "diagnostics": _expected_diagnostics(warn_entries),
        }
        evidence_path = feature_dir / "resolver-evidence.yaml"
        evidence, parse_error = block_check.read_evidence(evidence_path)
        counts.check(
            evidence == expected_evidence,
            f"{case_name}: exact published Resolver Evidence (matched-capability-trigger-WARN, B2)",
            parse_error or repr(evidence),
        )
        block_check.check_evidence_schema(counts, evidence_path, case_name)
        unchanged = all(path.read_bytes() == value for path, value in sentinels.items())
        counts.check(unchanged, f"{case_name}: no live facet-manifest/capability-summary/projection written on Block")
    finally:
        shutil.rmtree(repo, ignore_errors=True)


def run_warn_unmatched_trigger_case(kind, counts):
    """unmatched-capability-trigger-WARN: comp-a's own (sole) trigger
    evaluation is a WARN (missing-path); the Capability ends up
    `matched: False` overall, yet this invocation still Blocks (B2's own
    widened any-branch scope -- this exact fixture is the regression proof
    that an earlier, representative-branch-only revision would have
    accepted)."""
    case_name = "warn-unmatched-trigger"
    fixture_dir = FIXTURES / case_name
    repo, scripts, feature_dir, sentinels = _setup_repo(fixture_dir)
    try:
        base_oid, target_oid = _commit_components(repo, ["comp-a"])
        argv = block_check.t003_resolver_argv(kind, scripts, base_oid, target_oid)
        result = subprocess.run(argv, cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        counts.check(result.returncode == 1, f"{case_name}: exit 1 (Block)", f"got {result.returncode} stderr={stderr!r}")
        counts.check(
            stdout == "" and stderr == WARN_BLOCK_CANONICAL_LINE,
            f"{case_name}: canonical diagnostic only",
            f"stdout={stdout!r} stderr={stderr!r}",
        )

        comp_a_props = {
            "characteristics": {"ui": False, "auto_update": False, "local_persistence": False},
            "paths": {"include": ["comp-a/**"]},
        }
        result_a, evidence_a = block_check.real_evaluate_predicate(TRIGGER_PII_EQUALS_TRUE, comp_a_props)
        counts.check(
            result_a is False and evidence_a[0].get("outcome") == "warn",
            f"{case_name}: fixture sanity -- comp-a's own sole trigger evaluation genuinely WARNs "
            f"(missing-path) and the Capability ends up unmatched",
            repr((result_a, evidence_a)),
        )

        trigger_evaluations = [{"component_id": "comp-a", "result": result_a, "evidence": evidence_a}]
        warn_entries = _collect_warn_entries("cap-w2", "comp-a", None, evidence_a)
        expected_evidence = {
            "schema": "sdd-resolver-evidence/v1",
            "feature": "example-feature",
            "state": "advisory",
            "capability_evaluations": [
                {"capability_id": "cap-w2", "matched": False, "trigger_evaluations": trigger_evaluations},
            ],
            "diagnostics": _expected_diagnostics(warn_entries),
        }
        evidence_path = feature_dir / "resolver-evidence.yaml"
        evidence, parse_error = block_check.read_evidence(evidence_path)
        counts.check(
            evidence == expected_evidence,
            f"{case_name}: exact published Resolver Evidence (unmatched-capability-trigger-WARN, B2)",
            parse_error or repr(evidence),
        )
        block_check.check_evidence_schema(counts, evidence_path, case_name)
        unchanged = all(path.read_bytes() == value for path, value in sentinels.items())
        counts.check(unchanged, f"{case_name}: no live facet-manifest/capability-summary/projection written on Block")
    finally:
        shutil.rmtree(repo, ignore_errors=True)


def run_warn_conditional_facet_case(kind, counts):
    """matched-capability-conditional-facet-WARN: comp-a's own trigger
    evaluation is a clean match (no WARN); the SAME capability's own
    conditional_facets[0].when evaluation against the SAME component is a
    WARN (missing-path) -- this invocation still Blocks."""
    case_name = "warn-conditional-facet"
    fixture_dir = FIXTURES / case_name
    repo, scripts, feature_dir, sentinels = _setup_repo(fixture_dir)
    try:
        base_oid, target_oid = _commit_components(repo, ["comp-a"])
        argv = block_check.t003_resolver_argv(kind, scripts, base_oid, target_oid)
        result = subprocess.run(argv, cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        counts.check(result.returncode == 1, f"{case_name}: exit 1 (Block)", f"got {result.returncode} stderr={stderr!r}")
        counts.check(
            stdout == "" and stderr == WARN_BLOCK_CANONICAL_LINE,
            f"{case_name}: canonical diagnostic only",
            f"stdout={stdout!r} stderr={stderr!r}",
        )

        comp_a_props = {
            "characteristics": {"pii": True, "ui": False, "auto_update": False},
            "paths": {"include": ["comp-a/**"]},
        }
        when_predicate = {
            "scope": "affected_component", "field": "characteristics.local_persistence",
            "operator": "equals", "value": True,
        }
        result_trigger, evidence_trigger = block_check.real_evaluate_predicate(TRIGGER_PII_EQUALS_TRUE, comp_a_props)
        result_when, evidence_when = block_check.real_evaluate_predicate(when_predicate, comp_a_props)
        counts.check(
            result_trigger is True and evidence_trigger[0].get("outcome") == "match"
            and result_when is False and evidence_when[0].get("outcome") == "warn",
            f"{case_name}: fixture sanity -- the trigger evaluation is a clean match (no WARN); the "
            f"conditional facet's own `when` evaluation against the SAME component genuinely WARNs "
            f"(missing-path)",
            repr((result_trigger, evidence_trigger, result_when, evidence_when)),
        )

        trigger_evaluations = [{"component_id": "comp-a", "result": result_trigger, "evidence": evidence_trigger}]
        conditional_facet_evaluations = [
            {
                "facet": "facet-w3", "declaration_index": 0, "applied": False,
                "evaluations": [{"component_id": "comp-a", "result": result_when, "evidence": evidence_when}],
            },
        ]
        warn_entries = _collect_warn_entries("cap-w3", "comp-a", 0, evidence_when)
        expected_evidence = {
            "schema": "sdd-resolver-evidence/v1",
            "feature": "example-feature",
            "state": "advisory",
            "capability_evaluations": [
                {
                    "capability_id": "cap-w3", "matched": True,
                    "trigger_evaluations": trigger_evaluations,
                    "conditional_facet_evaluations": conditional_facet_evaluations,
                },
            ],
            "diagnostics": _expected_diagnostics(warn_entries),
        }
        evidence_path = feature_dir / "resolver-evidence.yaml"
        evidence, parse_error = block_check.read_evidence(evidence_path)
        counts.check(
            evidence == expected_evidence,
            f"{case_name}: exact published Resolver Evidence (matched-capability-conditional-facet-WARN, B2)",
            parse_error or repr(evidence),
        )
        block_check.check_evidence_schema(counts, evidence_path, case_name)
        unchanged = all(path.read_bytes() == value for path, value in sentinels.items())
        counts.check(unchanged, f"{case_name}: no live facet-manifest/capability-summary/projection written on Block")
    finally:
        shutil.rmtree(repo, ignore_errors=True)


# ---------------------------------------------------------------------------
# (f) nested-array-completeness, via validate-resolver-evidence's own
# exact-set checks (AC-045's own fourth named lock; T-008's own already-
# established fixtures/mechanism, reused verbatim per this task's own
# Depends On text).
# ---------------------------------------------------------------------------

NESTED_ARRAY_CASES = (
    # (fixture name, expected exit, the one nesting-level array design.md
    # item 9(f) names this fixture proves).
    ("clean", 0, "every level (a complete, non-corrupted fixture passes)"),
    ("capability-set-mismatch", 1, "capability_evaluations[]"),
    ("trigger-evaluation-set-mismatch", 1, "trigger_evaluations[]"),
    ("conditional-facet-set-mismatch", 1, "conditional_facet_evaluations[]"),
    ("conditional-facet-evaluation-set-mismatch", 1, "evaluations[]"),
)


def run_nested_array_completeness_case(kind, counts):
    for fixture_name, expect_exit, nesting_level in NESTED_ARRAY_CASES:
        case_dir = validate_check.FIXTURES / fixture_name
        meta = validate_check.load_json(case_dir / "case.json")
        with tempfile.TemporaryDirectory(prefix="resolver-nested-") as tmp:
            repo = Path(tmp).resolve()
            digest = validate_check.build_repo(repo, case_dir)
            if digest is None:
                counts.check(
                    False, f"nested-array-completeness ({fixture_name}): fixture repo prepared",
                    "generate-registry-digest --whole did not yield a digest",
                )
                continue
            scripts = repo / "plugins/sdd-quality-loop/scripts"
            argv = (
                validate_check.wrapper_argv(kind, scripts)
                + ["--evidence", validate_check.EVIDENCE_REL]
                + validate_check.resolve_args(meta["args"])
            )
            result = subprocess.run(argv, cwd=str(repo), stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
            stdout = result.stdout.decode("utf-8", errors="replace")
            observed_ids, malformed = validate_check.parse_diagnostics(stdout)
            counts.check(
                result.returncode == expect_exit,
                f"nested-array-completeness ({fixture_name}, {nesting_level}): exit {expect_exit} via "
                f"validate-resolver-evidence's own exact-set checks (AC-045(f))",
                f"got {result.returncode}; stdout={stdout!r}",
            )
            counts.check(
                sorted(observed_ids) == sorted(meta["expect_check_ids"]),
                f"nested-array-completeness ({fixture_name}): emits exactly {meta['expect_check_ids']!r} "
                f"and nothing else",
                repr(observed_ids),
            )
            counts.check(not malformed, f"nested-array-completeness ({fixture_name}): every diagnostic line well-formed", repr(malformed))


# ---------------------------------------------------------------------------
# (g) dependency-invocation-order spy, per-position forced-failure
# sub-fixtures (OK-2 reinforcement).
# ---------------------------------------------------------------------------

SPY_BASE_NAMES = (
    "canonicalize-sdd-yaml",
    "resolve-component-paths",
    "validate-capability-registry",
    "generate-registry-digest",
    "evaluate-predicate",
)

EXPECTED_SPY_SEQUENCE = [
    "canonicalize-sdd-yaml",
    "canonicalize-sdd-yaml",
    "resolve-component-paths",
    "validate-capability-registry",
    "generate-registry-digest",
    "evaluate-predicate",
    "evaluate-predicate",
]

# position -> (expected diagnostic id, a detail substring that discriminates
# this position from its own same-id siblings, or None when the id alone is
# already unambiguous).
SPY_POSITION_BLOCK = {
    1: ("canonicalizer-invocation-failed", "project context"),
    2: ("canonicalizer-invocation-failed", "context projection"),
    3: ("affected-component-resolution-failed", None),
    4: ("registry-validation-failed", None),
    5: ("dependency-subprocess-failed", None),
    6: ("dependency-subprocess-failed", None),
    7: ("dependency-subprocess-failed", None),
}

_SPY_SHIM_TEMPLATE = '''#!/usr/bin/env python3
"""T-010 dependency-invocation-order spy shim (design.md Test Strategy
item 9(g)), generated by tests/resolve-project-context-metamorphic-check.py
-- never hand-copied into a static fixture file, since its own content is
identical regardless of which of the five dependency names it stands in
for. Self-derives its own base name and its own real "-real" sibling from
`__file__`, matching `install_spy`'s (T-004, resolve-project-context-
block-check.py) own established "generate the harness in Python, don\\'t
hand-author N near-identical fixture files" convention. Logs this
invocation\\'s own 1-based call position (this run\\'s own shared,
append-only SDD_SPY_LOG) before either forcing a deterministic non-zero
exit (SDD_SPY_FAIL_AT, env, equals this position) or delegating to the
untouched, real sibling script this filename\\'s own "-real" suffix names
-- never a reimplementation of that dependency\\'s own logic. Every
delegate call propagates SDD_SPY_SUPPRESS=1 downward and every shim skips
its own logging/fail-check when that flag is already set on entry, so a
GRANDCHILD subprocess call one of these five dependencies makes on its own
behalf (generate-registry-digest.py internally invokes canonicalize-sdd-
yaml.py to hash the Registry it discovers) never pollutes the parent
resolver\\'s own direct call sequence this fixture exists to prove."""
import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
REAL_SIBLING = HERE.with_name(HERE.stem + "-real.py")
LOG_PATH = Path(os.environ["SDD_SPY_LOG"])
FAIL_AT = os.environ.get("SDD_SPY_FAIL_AT")
SUPPRESSED = os.environ.get("SDD_SPY_SUPPRESS") == "1"

if not SUPPRESSED:
    existing = LOG_PATH.read_text(encoding="utf-8").splitlines() if LOG_PATH.exists() else []
    position = len(existing) + 1
    with LOG_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps({"position": position, "script": HERE.stem}) + "\\n")
    if FAIL_AT is not None and str(position) == FAIL_AT:
        sys.stderr.write(f"SPY: forced non-zero exit at position {position} ({HERE.stem})\\n")
        sys.exit(1)

child_env = os.environ.copy()
child_env["SDD_SPY_SUPPRESS"] = "1"
result = subprocess.run(
    [sys.executable, str(REAL_SIBLING)] + sys.argv[1:],
    stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=child_env,
)
sys.stdout.buffer.write(result.stdout)
sys.stderr.buffer.write(result.stderr)
sys.exit(result.returncode)
'''


def _install_spy_shims(scripts):
    for base_name in SPY_BASE_NAMES:
        live = scripts / f"{base_name}.py"
        real = scripts / f"{base_name}-real.py"
        shutil.copy2(live, real)
        live.write_text(_SPY_SHIM_TEMPLATE, encoding="utf-8", newline="\n")


def _spy_repo(fixture_dir):
    tmp = tempfile.mkdtemp(prefix="resolver-spy-")
    repo = Path(tmp).resolve()
    subprocess.run(["git", "init", "-q", str(repo)], check=True, capture_output=True)
    scripts = block_check.install_scripts(repo)
    feature_dir, sentinels = block_check.plant_sentinels(repo, scripts)
    shutil.copy2(fixture_dir / "project-context.yaml", repo / "project-context.yaml")
    block_check.install_t003_dependencies(
        repo, scripts, fixture_dir, stub_name=None,
        registry_capabilities_path=fixture_dir / "capability-registry.json",
    )
    _install_spy_shims(scripts)
    base_oid, target_oid = _commit_components(repo, ["comp-a"])
    log_path = repo / "spy-call-log.jsonl"
    return repo, scripts, base_oid, target_oid, log_path, feature_dir, sentinels


def _read_spy_log(log_path):
    if not log_path.exists():
        return []
    return [json.loads(line) for line in log_path.read_text(encoding="utf-8").splitlines() if line]


def run_dependency_order_spy_case(kind, counts):
    fixture_dir = FIXTURES / "dependency-order-spy"

    # --- clean run: exact seven-call sequence ---------------------------
    repo, scripts, base_oid, target_oid, log_path, feature_dir, sentinels = _spy_repo(fixture_dir)
    try:
        env = os.environ.copy()
        env["SDD_SPY_LOG"] = str(log_path)
        env.pop("SDD_SPY_FAIL_AT", None)
        argv = block_check.t003_resolver_argv(kind, scripts, base_oid, target_oid)
        result = subprocess.run(argv, cwd=repo, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        counts.check(
            result.returncode == 0,
            "dependency-order-spy: clean run reaches exit 0 (no Block anywhere on the happy path)",
            f"exit={result.returncode} stdout={result.stdout!r} stderr={result.stderr!r}",
        )
        log_entries = _read_spy_log(log_path)
        observed_sequence = [entry["script"] for entry in log_entries[:7]]
        counts.check(
            len(log_entries) >= 7 and observed_sequence == EXPECTED_SPY_SEQUENCE,
            "dependency-order-spy: this invocation's own first seven subprocess launches are exactly "
            "canonicalize-sdd-yaml (Project Context pass) -> canonicalize-sdd-yaml (Context Projection "
            "pass) -> resolve-component-paths -> validate-capability-registry (this invocation's own "
            "step-5 subprocess-observable event -- step 5's own discovery half is an in-process "
            "sibling-module import, never a subprocess; design.md item 9(g)'s own \"Registry discovery\" "
            "label names this position, see this driver's own module docstring) -> generate-registry-"
            "digest -> evaluate-predicate (trigger fan-out) -> evaluate-predicate (conditional-facet "
            "fan-out) (design.md Test Strategy item 9(g))",
            repr(observed_sequence),
        )
    finally:
        shutil.rmtree(repo, ignore_errors=True)

    # --- per-position forced-failure sub-fixtures ------------------------
    for position, (expected_id, detail_substring) in SPY_POSITION_BLOCK.items():
        repo, scripts, base_oid, target_oid, log_path, feature_dir, sentinels = _spy_repo(fixture_dir)
        try:
            env = os.environ.copy()
            env["SDD_SPY_LOG"] = str(log_path)
            env["SDD_SPY_FAIL_AT"] = str(position)
            argv = block_check.t003_resolver_argv(kind, scripts, base_oid, target_oid)
            result = subprocess.run(argv, cwd=repo, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
            stdout = result.stdout.decode("utf-8", errors="replace")
            stderr = result.stderr.decode("utf-8", errors="replace")
            case_name = f"dependency-order-spy-position-{position}"
            counts.check(
                result.returncode == 1,
                f"{case_name}: forced failure at position {position} Blocks (exit 1)",
                f"exit={result.returncode} stdout={stdout!r} stderr={stderr!r}",
            )
            canonical_prefix = f"capability-resolver: {expected_id}: "
            counts.check(
                stderr.endswith("\n") and canonical_prefix in stderr,
                f"{case_name}: Blocks with position {position}'s own correct diagnostic id {expected_id!r}",
                repr(stderr),
            )
            if detail_substring is not None:
                counts.check(
                    detail_substring in stderr,
                    f"{case_name}: detail names the correct sub-phase ({detail_substring!r})",
                    repr(stderr),
                )
            log_entries = _read_spy_log(log_path)
            counts.check(
                len(log_entries) == position,
                f"{case_name}: exactly {position} subprocess launch(es) occurred -- no later-ordered "
                f"subprocess was ever invoked after the forced failure",
                repr(log_entries),
            )
            unchanged = all(path.read_bytes() == value for path, value in sentinels.items())
            counts.check(unchanged, f"{case_name}: no partial live artifact")
        finally:
            shutil.rmtree(repo, ignore_errors=True)


# ---------------------------------------------------------------------------
# Feature-wide fixture-matrix completeness (Done When bullet; AC-026 "nine
# of ten" per Global Constraints' own "Deferred, Not Scheduled" note;
# AC-027).
# ---------------------------------------------------------------------------

NINE_SUITES = (
    "resolve-project-context-cli",
    "resolve-project-context-block",
    "resolve-project-context-match",
    "resolve-project-context-lite",
    "resolve-project-context-parity",
    "resolve-project-context-discovery",
    "resolver-evidence-schema",
    "validate-resolver-evidence",
    "resolve-project-context-metamorphic",
)

# One independently-invocable fixture anchor per REQ-006 fixture-matrix
# item (a)-(h) -- not a re-execution of another task's own suite (each is
# already exercised, and independently passing, under its own owning
# suite; T-001..T-009's own regression tallies, cited in this task's own
# implementation report, are the authority on that), only a presence lock
# that the anchor this feature's design already assigned to that item
# still exists under this shared fixtures root.
REQ006_ANCHOR_FIXTURES = {
    "a": [FIXTURES_ROOT / "resolve-project-context-match/full-pipeline-match"],
    "b": [FIXTURES_ROOT / "resolve-project-context-match/full-pipeline-match"],
    "c": [FIXTURES_ROOT / "resolve-project-context-match/full-pipeline-match"],
    "d": [
        FIXTURES_ROOT / "resolve-project-context-block/dsl-warn-matched-nondetermining",
        FIXTURES_ROOT / "resolve-project-context-block/dsl-warn-unmatched-trigger",
        FIXTURES / "warn-conditional-facet",
    ],
    "e": [FIXTURES_ROOT / "resolve-project-context-block"],
    "f": [FIXTURES_ROOT / "resolve-project-context-match/full-pipeline-match"],
    "g": [FIXTURES_ROOT / "resolve-project-context-match/zero-affected-component-match"],
    "h": [
        FIXTURES / "combination-matrix",
        FIXTURES / "order-invariance",
        FIXTURES / "multi-true-dedup",
        FIXTURES / "reason-template",
        FIXTURES / "warn-matched-trigger",
        FIXTURES / "warn-unmatched-trigger",
        FIXTURES / "warn-conditional-facet",
        FIXTURES / "dependency-order-spy",
    ],
}


def run_feature_wide_completeness_check(counts):
    run_all_sh = (ROOT / "tests/run-all.sh").read_text(encoding="utf-8")
    run_all_ps1 = (ROOT / "tests/run-all.ps1").read_text(encoding="utf-8")
    for suite in NINE_SUITES:
        sh_launcher = ROOT / f"tests/{suite}.tests.sh"
        ps1_launcher = ROOT / f"tests/{suite}.tests.ps1"
        counts.check(
            sh_launcher.is_file() and ps1_launcher.is_file(),
            f"feature-wide completeness: {suite} sh/ps1 launcher pair exists "
            f"(nine of ten suites T-001..T-010 build, AC-026)",
            f"sh={sh_launcher.is_file()} ps1={ps1_launcher.is_file()}",
        )
        counts.check(
            f"tests/{suite}.tests.sh" in run_all_sh,
            f"feature-wide completeness: {suite} registered in tests/run-all.sh",
        )
        counts.check(
            f"tests/{suite}.tests.ps1" in run_all_ps1,
            f"feature-wide completeness: {suite} registered in tests/run-all.ps1",
        )

    for item, paths in REQ006_ANCHOR_FIXTURES.items():
        for path in paths:
            counts.check(
                path.exists(),
                f"feature-wide completeness: REQ-006 fixture-matrix item ({item}) anchor fixture present "
                f"under tests/fixtures/capability-resolver/: {path.relative_to(ROOT)}",
                f"missing: {path}",
            )

    schema_path = ROOT / "contracts/resolver-evidence.schema.json"
    with schema_path.open("r", encoding="utf-8") as handle:
        schema = json.load(handle)
    enum_ids = schema["definitions"]["diagnostic"]["properties"]["id"]["enum"]
    counts.check(
        len(enum_ids) == 16 and len(set(enum_ids)) == 16,
        "feature-wide completeness: REQ-006 item (e)'s own governing schema enum is closed at sixteen "
        "distinct diagnostic-id rows",
        repr(enum_ids),
    )
    block_dir = FIXTURES_ROOT / "resolve-project-context-block"
    present_dirs = [p for p in block_dir.iterdir() if p.is_dir()] if block_dir.is_dir() else []
    counts.check(
        len(present_dirs) >= len(enum_ids),
        f"feature-wide completeness: REQ-006 item (e)'s own {len(enum_ids)}-row diagnostic-id matrix has "
        f"at least that many independently-invocable fixtures present under resolve-project-context-block/ "
        f"(the exact id-to-fixture mapping is that suite's own already-passing "
        f"`run_block_matrix_completeness_check` lock, cited by name in this task's own report)",
        f"present={len(present_dirs)} required>={len(enum_ids)}",
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--launcher", choices=("sh", "ps1"), required=True)
    args = parser.parse_args()
    counts = Counts()

    required = [block_check.STAGED / f"resolve-project-context.{suffix}" for suffix in ("py", "sh", "ps1")]
    if not all(path.is_file() for path in required):
        counts.check(False, "staged implementation exists", "TDD RED: implementation absent")
    else:
        run_combination_matrix_case(args.launcher, counts)
        run_order_invariance_case(args.launcher, counts)
        run_multi_true_dedup_case(args.launcher, counts)
        run_reason_template_case(args.launcher, counts)
        run_warn_matched_trigger_case(args.launcher, counts)
        run_warn_unmatched_trigger_case(args.launcher, counts)
        run_warn_conditional_facet_case(args.launcher, counts)
        run_nested_array_completeness_case(args.launcher, counts)
        run_dependency_order_spy_case(args.launcher, counts)
        # Must run LAST: it depends on this suite's own launcher pair and
        # this suite's own new fixture directories, all of which are
        # authored by this same task.
        run_feature_wide_completeness_check(counts)

    sh_registered = "tests/resolve-project-context-metamorphic.tests.sh" in (ROOT / "tests/run-all.sh").read_text(encoding="utf-8")
    ps_registered = "tests/resolve-project-context-metamorphic.tests.ps1" in (ROOT / "tests/run-all.ps1").read_text(encoding="utf-8")
    counts.check(sh_registered, "POSIX suite registered in tests/run-all.sh")
    counts.check(ps_registered, "PowerShell suite registered in tests/run-all.ps1")

    print(f"RESULT: {counts.passed} passed, {counts.failed} failed")
    return 1 if counts.failed else 0


if __name__ == "__main__":
    sys.exit(main())
