#!/usr/bin/env python3
"""T-005 driver shared by the POSIX and PowerShell twins for
`resolve-project-context-match` (design.md Test Strategy item 3): the full
match/no-match/conditional/WARN fixture matrix exercising T-002/T-003/
T-004's own already-authored, complete evaluation pipeline (steps 0-13),
via real subprocess invocations of the assembled `resolve-project-context`
-- never a mocked stand-in for the engine under test.

This module reuses `tests/resolve-project-context-block-check.py`'s own
already-established fixture-repo/dependency-planting/schema-checking
helpers (loaded by path, since a hyphenated filename cannot be a normal
Python import target) rather than re-implementing them -- the identical
"reuse this task's own already-established mechanism, don't invent a
second one" discipline T-004's own report already applied to its own
governing-schema stand-ins.

**A genuine external constraint, confirmed directly against this tree
(not assumed), that shapes this suite's own design (see this task's own
implementation report, "Specification Differences", for the full
disclosure):** T-002/T-003/T-004 already established -- and this task's
own Depends On text repeats -- that this Resolver's steps 0-13 are
staged-only: "a clean resolve (exit 0) writes nothing to any live path"
(resolve-project-context.py's own module docstring). Every Block path
reached BEFORE step 10 (disabled-legacy/workflow-invalid/project-context-
invalid/steps 4-9) writes only `{schema, feature, capability_evaluations,
diagnostics, state}` to Resolver Evidence; every Block reached AT OR
AFTER step 10 (`lite-check-source-undefined`, step 12's own two
`output-schema-validation-failed`/`contract-discovery-failed` sub-cases,
`snapshot-generation-mismatch`) additionally carries `context_binding`/
`resolver` (T-004 NEEDS_WORK cycle 2 remediation, "late Blocks drop
provenance" -- those values are already computed by step 10, before any
of these Blocks fire). The track-exclusive artifact (Facet Manifest/
Capability Summary) itself is never written to any live path on ANY
path, Block or clean -- live publication of that artifact is entirely
T-007's own step-14 scope, not yet landed on this branch. Several of
this task's own target ACs
(AC-007/008/016/043/044/052's Facet-Manifest half) describe the CONTENT of
artifacts that are therefore never externally observable via a real
subprocess invocation alone, on this tree, today. This driver closes that
gap the same way this driver's own predecessors already recompute
expected values via a real dependency rather than hand-transcribing them
(`expected_projection`, `real_evaluate_predicate` in the block driver):
by loading the SAME staged `resolve-project-context.py` file the real
subprocess run also executed (via `importlib`, never a second,
reimplemented copy of its logic) and calling its own already-tested,
unmodified assembly functions (`_assemble_facet_manifest`,
`_assemble_context_binding`, `_resolver_block`) directly, fed the EXACT
`capability_evaluations` that SAME real subprocess run already produced
and this driver already independently verified byte-for-byte (via
`real_evaluate_predicate`) before ever calling them. This is not mocking
the engine under test -- the primary pipeline invocation under test in
every fixture below remains a genuine subprocess launch of the assembled
`.sh`/`.py`/`.ps1` CLI -- it is a secondary, disclosed oracle-reconstruction
step, used only to make an otherwise print-only/publication-deferred
internal computation assertable, exactly as this Epic's own established
convention already treats "recompute the expected shape via the real,
unmodified producer" as the correct oracle technique.
"""

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/capability-resolver/resolve-project-context-match"
VALIDATE_FACET_MANIFEST = ROOT / "plugins/sdd-quality-loop/scripts/validate-facet-manifest.py"

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
# fixture-repo/dependency-planting/schema-checking helpers.
block_check = _load_module(
    Path(__file__).resolve().parent / "resolve-project-context-block-check.py",
    "resolve_project_context_block_check",
)


def _canonicalize_yaml(path):
    result = subprocess.run(
        [sys.executable, str(block_check.REAL_CANONICALIZER), str(path), "--input-format", "yaml"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
    )
    return result.stdout, json.loads(result.stdout.decode("utf-8"))


def _canonicalize_json_document(document):
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", suffix=".json", delete=False, newline="\n") as handle:
        json.dump(document, handle, ensure_ascii=False, separators=(",", ":"))
        path = Path(handle.name)
    try:
        result = subprocess.run(
            [sys.executable, str(block_check.REAL_CANONICALIZER), str(path), "--input-format", "json"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
        )
        return result.stdout
    finally:
        path.unlink(missing_ok=True)


def _validate_facet_manifest(document):
    """AC-008: validates a reconstructed Facet Manifest via the REAL,
    already-landed Epic A4 `validate-facet-manifest` (never this driver's
    own re-implementation of its schema checks)."""
    fd, name = tempfile.mkstemp(suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(document, handle)
        result = subprocess.run(
            [sys.executable, str(VALIDATE_FACET_MANIFEST), "--manifest", name],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, cwd=str(ROOT),
        )
        return result
    finally:
        os.unlink(name)


def _install_full_pipeline_dependencies(repo, scripts, fixture_dir, registry_capabilities_path):
    block_check.install_t003_dependencies(
        repo, scripts, fixture_dir, stub_name="generate-registry-digest.py",
        registry_capabilities_path=registry_capabilities_path,
    )
    # AC-004: overlay the resolve-component-paths capture-and-delegate spy
    # on top of the real script `install_t003_dependencies` already
    # installed (module docstring: "capture, then delegate to a -real
    # sibling", T-002's own established technique, reused for a
    # different dependency).
    if (fixture_dir / "resolve-component-paths.py").is_file():
        shutil.copy2(scripts / "resolve-component-paths.py", scripts / "resolve-component-paths-real.py")
        shutil.copy2(fixture_dir / "resolve-component-paths.py", scripts / "resolve-component-paths.py")
    # AC-003: overlay the projection capture stub -- T-002's own
    # already-established mechanism, reused verbatim, never reinvented.
    shutil.copy2(block_check.REAL_CANONICALIZER, scripts / "canonicalize-sdd-yaml-real.py")
    shutil.copy2(block_check.PROJECTION_FIXTURES / "canonicalize-sdd-yaml.py", scripts / "canonicalize-sdd-yaml.py")


def run_full_pipeline_match_case(kind, resolver_module, counts):
    """The primary `resolve-project-context-match` fixture: a real,
    non-empty Registry (two Capabilities, three affected components,
    cross-Capability AND same-Capability duplicate-facet-name conditional
    facets, a required-minimum-enforcement Capability, mixed lite_policy)
    driven all the way through steps 0-13 via a real subprocess, forced to
    Block at step 13 (`snapshot-generation-mismatch`, via the identical
    two-fixed-digest technique T-004's own suite already established) so
    this invocation's own full `capability_evaluations[]` becomes
    observable. Covers TEST-003 (Context Projection byte-identity,
    AC-003), TEST-004 (resolve-component-paths pass-through, AC-004),
    TEST-005 (registry_digest --whole binding, AC-005), TEST-006
    (union-match, AC-006), TEST-007 (field-assembly conformance, AC-007),
    TEST-008 (Facet Manifest schema-conformance, AC-008), TEST-043
    (cross-Capability facet-name aggregation, AC-043), TEST-044
    (provenance canonicalization, AC-044), and TEST-052 (same-Capability
    duplicate-facet predicate-instance, AC-052) -- one comprehensive
    fixture, matching design.md Test Strategy item 3's own list of
    closely related assertions against a single evaluation pipeline."""
    case_name = "full-pipeline-match"
    fixture_dir = FIXTURES / case_name
    with tempfile.TemporaryDirectory(prefix="resolver-match-") as tmp:
        repo = Path(tmp).resolve()
        subprocess.run(["git", "init", "-q", str(repo)], check=True, capture_output=True)
        scripts = block_check.install_scripts(repo)
        feature_dir, sentinels = block_check.plant_sentinels(repo, scripts)
        shutil.copy2(fixture_dir / "project-context.yaml", repo / "project-context.yaml")
        registry_path = fixture_dir / "capability-registry.json"
        _install_full_pipeline_dependencies(repo, scripts, fixture_dir, registry_path)

        (repo / "README.md").write_text("baseline\n", encoding="utf-8")
        base_oid = block_check.git_commit_all(repo, "baseline")
        (repo / "comp-a").mkdir()
        (repo / "comp-a/file.txt").write_text("a\n", encoding="utf-8")
        (repo / "comp-b").mkdir()
        (repo / "comp-b/file.txt").write_text("b\n", encoding="utf-8")
        (repo / "shared/util").mkdir(parents=True)
        (repo / "shared/util/file.txt").write_text("s\n", encoding="utf-8")
        (repo / "other-thing").mkdir()
        (repo / "other-thing/file.txt").write_text("o\n", encoding="utf-8")
        target_oid = block_check.git_commit_all(repo, "add comp-a, comp-b, shared/util, other-thing")

        argv = block_check.t003_resolver_argv(kind, scripts, base_oid, target_oid)
        env = os.environ.copy()
        env["SDD_T002_PROJECTION_MODE"] = "passthrough"
        result = subprocess.run(argv, cwd=repo, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        counts.check(result.returncode == 1, f"{case_name}: exit 1 (forced snapshot-generation-mismatch)", f"got {result.returncode} stderr={stderr!r}")
        counts.check(
            stdout == "" and stderr == SNAPSHOT_MISMATCH_LINE,
            f"{case_name}: canonical diagnostic only, reached step 13 (steps 0-12 all passed)",
            f"stdout={stdout!r} stderr={stderr!r}",
        )

        # --- AC-003: Context Projection byte-identity -----------------
        # gate-cycle-2 Major A remediation: `expected_projection` used to be
        # `resolver_module._projection(document, source_sha256)` -- the
        # SAME function under test computing its own expectation, so the
        # comparison below could never fail (the evaluator proved this by
        # mutating every `paths.include` to `MUTANT-WRONG-PATH/**` inside
        # the real resolver subprocess and still seeing 63/0). Per
        # acceptance-tests.md:45 ("computed once by hand per Epic A4's own
        # REQ-003 procedure"), this is now literal expected data,
        # hand-transcribed from this fixture's own
        # `project-context.yaml` (see that file, checked into this same
        # directory) and sharing no code with `resolve-project-context.py`.
        canonical_context, document = _canonicalize_yaml(repo / "project-context.yaml")
        source_sha256 = "sha256:" + hashlib.sha256(canonical_context).hexdigest()
        expected_projection = {
            "schema": "sdd-context-projection/v1",
            "source_sha256": source_sha256,
            "workflow": {
                "spec_profile": "full",
                "artifact_layout": "facet-hybrid",
                "capability_enforcement": "required",
            },
            "components": {
                "comp-a": {
                    "characteristics": {
                        "pii": True, "ui": False, "auto_update": False, "local_persistence": False,
                    },
                    "paths": {"include": ["comp-a/**"]},
                },
                "comp-b": {
                    "characteristics": {
                        "pii": False, "ui": True, "auto_update": False, "local_persistence": False,
                    },
                    "paths": {"include": ["comp-b/**"]},
                },
                "shared/util": {
                    "characteristics": {
                        "pii": False, "ui": False, "auto_update": False, "local_persistence": False,
                    },
                    "paths": {"include": ["shared/util/**"]},
                },
                "other~thing": {
                    "characteristics": {
                        "pii": False, "ui": False, "auto_update": False, "local_persistence": False,
                    },
                    "paths": {"include": ["other-thing/**"]},
                },
            },
            "shared_paths": [],
        }
        capture_path = repo / "projection-capture.json"
        captured, capture_parse_error = block_check.read_evidence(capture_path)
        counts.check(
            captured == expected_projection,
            f"{case_name}: Context Projection byte-identity (AC-003)",
            capture_parse_error or repr(captured),
        )

        # --- AC-004: resolve-component-paths pass-through --------------
        # Cross-model panel finding (T-003 NEEDS_WORK cycle 2): this
        # fixture's own resolver invocation (`block_check.t003_resolver_
        # argv`) never supplies `--include-untracked`, so AC-004's own
        # "identical values it itself received" rule requires the identical
        # OMISSION be passed through -- never a synthesized
        # `--no-include-untracked`, which is not part of this feature's own
        # CLI contract at all (design.md API/Contract Plan step 4:
        # `[--include-untracked]`, passed only when supplied). An earlier
        # revision of `resolve-project-context.py` synthesized that flag
        # unconditionally; this expectation previously pinned that
        # (incorrect) synthesized-flag behavior instead of asserting it.
        rcp_capture_path = scripts / "rcp-argv-capture.json"
        rcp_argv, rcp_parse_error = block_check.read_evidence(rcp_capture_path)
        expected_rcp_argv = [
            "--config", "project-context.yaml",
            "--source-rev", base_oid,
            "--target-rev", target_oid,
            "--json",
        ]
        counts.check(
            rcp_argv == expected_rcp_argv,
            f"{case_name}: resolve-component-paths invoked with --config/--source-rev/--target-rev byte-identical "
            "to received flags, and --include-untracked's own omission passed through verbatim, never synthesized "
            "as --no-include-untracked (AC-004)",
            rcp_parse_error or repr(rcp_argv),
        )

        # --- AC-005: registry_digest --whole binding --------------------
        digest_argv_path = scripts / "argv-capture.json"
        digest_argv, digest_parse_error = block_check.read_evidence(digest_argv_path)
        counts.check(
            digest_argv == ["--whole"],
            f"{case_name}: generate-registry-digest invoked with exactly --whole, never a --capability-ids/--gate-ids fragment (AC-005 flag)",
            digest_parse_error or repr(digest_argv),
        )
        # The forced step-13 mismatch fires with `ownership_digest` and
        # `affected_components` held byte-identical between step 4 and
        # step 13 (this fixture's own git state and resolve-component-paths
        # invocation are otherwise unchanged) -- the ONLY input that
        # differs between the two calls is this stub's own digest value,
        # so this fixture's own Block is attributable to `registry_digest`
        # alone, proving the step-6 value is retained and compared (bound)
        # at step 13 (AC-005 binding half). T-004 NEEDS_WORK cycle 2
        # remediation ("late Blocks drop provenance"): `context_binding`
        # is now written into THIS fixture's own Block evidence too (steps
        # 10-13 have already computed it) -- the assertion further below
        # re-derives and checks it directly; the Facet Manifest/Capability
        # Summary/Context Projection track-exclusive artifacts remain
        # unobservable pre-T-007 (module docstring), which is what this
        # driver's own oracle-reconstruction section (below) is for.
        counts.check(
            stderr == SNAPSHOT_MISMATCH_LINE,
            f"{case_name}: snapshot mismatch attributable to registry_digest alone (AC-005 binding)",
        )

        evidence_path = feature_dir / "resolver-evidence.yaml"
        evidence, parse_error = block_check.read_evidence(evidence_path)
        if not isinstance(evidence, dict):
            counts.check(False, f"{case_name}: Resolver Evidence readable", parse_error or repr(evidence))
            return

        registry_document = json.loads(registry_path.read_text(encoding="utf-8"))
        projection_components = expected_projection["components"]

        def eval_for(predicate, component_ids):
            entries = []
            for component_id in component_ids:
                result_, evidence_nodes = block_check.real_evaluate_predicate(predicate, projection_components.get(component_id, {}))
                entries.append({"component_id": component_id, "result": result_, "evidence": evidence_nodes})
            return entries

        affected_components = sorted(["comp-a", "comp-b", "shared/util", "other~thing"])

        cap_alpha_registry = next(c for c in registry_document["capabilities"] if c["id"] == "cap-alpha")
        cap_beta_registry = next(c for c in registry_document["capabilities"] if c["id"] == "cap-beta")

        cap_alpha_trigger_evals = eval_for(cap_alpha_registry["trigger"], affected_components)
        cap_alpha_matched = any(e["result"] for e in cap_alpha_trigger_evals)
        cap_alpha_cfe = []
        for idx, decl in enumerate(cap_alpha_registry["conditional_facets"]):
            evals = eval_for(decl["when"], affected_components)
            cap_alpha_cfe.append({
                "facet": decl["facet"], "declaration_index": idx,
                "applied": any(e["result"] for e in evals), "evaluations": evals,
            })

        cap_beta_trigger_evals = eval_for(cap_beta_registry["trigger"], affected_components)
        cap_beta_matched = any(e["result"] for e in cap_beta_trigger_evals)
        cap_beta_cfe = []
        for idx, decl in enumerate(cap_beta_registry["conditional_facets"]):
            evals = eval_for(decl["when"], affected_components)
            cap_beta_cfe.append({
                "facet": decl["facet"], "declaration_index": idx,
                "applied": any(e["result"] for e in evals), "evaluations": evals,
            })

        expected_capability_evaluations = sorted(
            [
                {
                    "capability_id": "cap-alpha", "matched": cap_alpha_matched,
                    "trigger_evaluations": cap_alpha_trigger_evals,
                    "conditional_facet_evaluations": cap_alpha_cfe,
                },
                {
                    "capability_id": "cap-beta", "matched": cap_beta_matched,
                    "trigger_evaluations": cap_beta_trigger_evals,
                    "conditional_facet_evaluations": cap_beta_cfe,
                },
            ],
            key=lambda entry: entry["capability_id"],
        )
        counts.check(
            evidence.get("capability_evaluations") == expected_capability_evaluations,
            f"{case_name}: exact capability_evaluations, union-match on both Capabilities (AC-006)",
            parse_error or repr(evidence.get("capability_evaluations")),
        )
        counts.check(cap_alpha_matched is True and cap_beta_matched is True, f"{case_name}: union-match sanity (only one of several affected components satisfies each trigger)")

        # --- AC-052(a): Resolver Evidence never collapses a same-
        # Capability duplicate facet name to one entry -----------------
        cap_alpha_evidence = next(e for e in evidence["capability_evaluations"] if e["capability_id"] == "cap-alpha")
        # gate-cycle-2 Minor remediation: `conditional_facet_evaluations` is
        # genuinely absent (never an empty list) on an entry whose own
        # `matched` is False (resolve-project-context.py:447/473) -- e.g. an
        # under-matched-Capability mutant. `.get(..., [])` turns that into a
        # real, reportable `cfe_pairs == [...]` FAIL instead of an unguarded
        # `KeyError` crashing the whole driver before it prints a RESULT
        # line (see verification/T-005/red-undermatched-capability-*.log).
        cfe_pairs = [
            (e["facet"], e["declaration_index"])
            for e in cap_alpha_evidence.get("conditional_facet_evaluations", [])
        ]
        counts.check(
            cfe_pairs == [("shared-facet", 0), ("shared-facet", 1), ("solo-never-facet", 2)],
            f"{case_name}: cap-alpha's own duplicate 'shared-facet' declarations recorded as two independent entries, never collapsed (AC-052(a))",
            repr(cfe_pairs),
        )

        block_check.check_evidence_schema(counts, evidence_path, case_name)
        unchanged = all(path.read_bytes() == value for path, value in sentinels.items())
        counts.check(unchanged, f"{case_name}: no partial live artifact")

        # --- Oracle reconstruction (module docstring): Facet Manifest /
        # context_binding, via the REAL, unmodified staged functions,
        # fed this run's own already-verified capability_evaluations. ---
        # gate-cycle-2 Major A remediation (second half): `projection_sha256`
        # used to be derived solely from this driver's own hand-built
        # `expected_projection` and fed into `_assemble_context_binding`
        # without ever being compared against anything the resolver itself
        # produced. Canonicalize `capture_path` -- the resolver's own real,
        # captured in-memory projection bytes (module docstring; NOT
        # `expected_projection`) -- via the identical real canonicalizer,
        # independently of the hand-built value, and assert the two hashes
        # agree before using the resolver-produced one going forward.
        hand_projection_sha256 = "sha256:" + hashlib.sha256(_canonicalize_json_document(expected_projection)).hexdigest()
        canonical_captured_projection = subprocess.run(
            [sys.executable, str(block_check.REAL_CANONICALIZER), str(capture_path), "--input-format", "json"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
        ).stdout
        resolver_projection_sha256 = "sha256:" + hashlib.sha256(canonical_captured_projection).hexdigest()
        counts.check(
            resolver_projection_sha256 == hand_projection_sha256,
            f"{case_name}: projection_sha256 independently recomputed from the resolver's own captured "
            f"projection bytes matches the hand-built expectation's own hash (AC-003 remainder)",
            repr({"resolver": resolver_projection_sha256, "hand": hand_projection_sha256}),
        )
        projection_sha256 = resolver_projection_sha256
        real_rcp = subprocess.run(
            [sys.executable, str(scripts / "resolve-component-paths-real.py")] + expected_rcp_argv,
            cwd=repo, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
        )
        real_rcp_parsed = json.loads(real_rcp.stdout.decode("utf-8"))
        ownership_digest = real_rcp_parsed["context_binding"]["ownership_digest"]
        counts.check(
            sorted(real_rcp_parsed["affected_components"]) == affected_components,
            f"{case_name}: independently-recomputed affected_components matches the fixture's own four components",
            repr(real_rcp_parsed.get("affected_components")),
        )
        registry_digest = "sha256:" + ("1" * 64)  # this fixture's own stub's FIRST_DIGEST (step 6's own value)

        context_binding = resolver_module._assemble_context_binding(
            source_sha256, affected_components, projection_sha256, registry_digest, ownership_digest,
        )
        resolver_block = resolver_module._resolver_block()

        # --- RT-20260823-001 Route 1: context_binding scalar remainder --
        # `_assemble_context_binding` (resolve-project-context.py) is a
        # pure pass-through for its own four scalar fields
        # (`full_context_revision`, `projection_sha256`, `registry_digest`,
        # `ownership_digest` each equal the identically-named constructor
        # argument, verbatim, in that function's own body) -- until now,
        # NONE of the four was read back off `context_binding` and
        # compared to anything; a mutant substituting a well-formed wrong
        # digest for any one of them survived undetected. Every argument
        # fed into `_assemble_context_binding` above is independently
        # derived from something other than `_assemble_context_binding`
        # itself: `source_sha256` from this driver's own hashlib hash of
        # the real canonicalizer's output (:216); `projection_sha256` from
        # the resolver's own captured projection bytes, independently
        # re-canonicalized and re-hashed by this driver and already
        # cross-checked against the hand-built expectation above
        # (:398-409) -- never from calling `_assemble_context_binding`
        # itself; `registry_digest` from this fixture's own stub's fixed
        # FIRST_DIGEST constant (:422); `ownership_digest` from a second,
        # real, independent subprocess launch of `resolve-component-
        # paths-real.py` (:411-416), never `resolve-project-context.py`.
        # Reading `context_binding[field]` back and diffing it against
        # that SAME independent value exercises `_assemble_context_
        # binding`'s own real, unmutated assembly logic against an
        # expectation it never produced -- the identical "expectation
        # independent of the implementation under test" move that closed
        # AC-044 and AC-003's first half.
        counts.check(
            context_binding["full_context_revision"] == source_sha256,
            f"{case_name}: context_binding.full_context_revision is this run's own independently-hashed "
            f"source_sha256, unmutated by assembly (AC-003 remainder)",
            repr({"context_binding": context_binding.get("full_context_revision"), "expected": source_sha256}),
        )
        counts.check(
            context_binding["projection_sha256"] == projection_sha256,
            f"{case_name}: context_binding.projection_sha256 is the resolver-captured, independently "
            f"re-canonicalized-and-hashed projection digest, unmutated by assembly (AC-003 remainder)",
            repr({"context_binding": context_binding.get("projection_sha256"), "expected": projection_sha256}),
        )
        counts.check(
            context_binding["registry_digest"] == registry_digest,
            f"{case_name}: context_binding.registry_digest is this fixture's own stub's fixed FIRST_DIGEST "
            f"constant, unmutated by assembly (AC-005 remainder)",
            repr({"context_binding": context_binding.get("registry_digest"), "expected": registry_digest}),
        )
        counts.check(
            context_binding["ownership_digest"] == ownership_digest,
            f"{case_name}: context_binding.ownership_digest is resolve-component-paths-real.py's own "
            f"independent, real-subprocess-derived value, unmutated by assembly (AC-005 remainder)",
            repr({"context_binding": context_binding.get("ownership_digest"), "expected": ownership_digest}),
        )

        # AC-044: dependency_pointers[] RFC-6901 canonical derivation,
        # exercising the escape rule against "shared/util"'s own `/` AND
        # (gate-cycle-2 Major B remediation) "other~thing"'s own `~` --
        # dropping the `~`->`~0` rule while keeping `/`->`~1` used to
        # survive undetected (no fixture component id contained `~`).
        expected_pointers = sorted({
            "/workflow", "/components/comp-a", "/components/comp-b",
            "/components/shared~1util", "/components/other~0thing",
        })
        counts.check(
            context_binding["dependency_pointers"] == expected_pointers,
            f"{case_name}: dependency_pointers[] is /workflow plus one RFC-6901-escaped pointer per affected component, stable-sorted (AC-044)",
            repr(context_binding["dependency_pointers"]),
        )
        # gate-cycle-2 Major B remediation: a dedicated, narrow assertion
        # that the `~` half of the escape rule specifically fires --
        # dropping only `token.replace("~", "~0")` while keeping the `/`
        # half survived undetected before "other~thing" existed in this
        # fixture, since no prior component id ever exercised it.
        counts.check(
            "/components/other~0thing" in context_binding["dependency_pointers"],
            f"{case_name}: \"other~thing\"'s own `~` is escaped to `~0` in its dependency_pointers[] entry (AC-044)",
            repr(context_binding["dependency_pointers"]),
        )
        counts.check(
            resolver_block["version"] == resolver_module.RESOLVER_VERSION
            and resolver_block["rule_set_revision"] == resolver_module.RULE_SET_REVISION
            and resolver_block["rule_set_revision"] == "sha256:" + hashlib.sha256(resolver_module.RULE_SET_STRING.encode("utf-8")).hexdigest(),
            f"{case_name}: resolver.version/rule_set_revision are this Resolver revision's own single-source-of-truth constants (AC-044 remainder -- "
            f"white-box: never written to any live path pre-T-007, so cross-invocation/cross-runtime identity is a structural consequence of "
            f".sh/.ps1 delegating unconditionally to this identical .py master, not something a real-subprocess run can itself observe)",
        )

        track_artifact = resolver_module._assemble_facet_manifest(
            "example-feature", affected_components, registry_document,
            evidence["capability_evaluations"], context_binding, resolver_block,
        )

        # --- affected_components (RT-20260823-001 Minor, closed) --------
        # Outside AC-007's own enumerated field list (`required_facets`/
        # `conditional_facets`/`resolved_gates`/`capabilities`/
        # `capability_minimum_enforcement`/`lite_eligibility` --
        # acceptance-tests.md AC-007 row), so not obligatory, but cheap to
        # close with the identical independent expectation already in
        # scope (this fixture's own four-component set, hardcoded above
        # at `affected_components`, never `resolve-project-context.py`'s
        # own re-derivation of it).
        counts.check(
            track_artifact["affected_components"] == affected_components,
            f"{case_name}: affected_components is this fixture's own four independently-known component ids, "
            f"unmutated by assembly (outside AC-007's enumerated field list)",
            repr(track_artifact.get("affected_components")),
        )

        # --- AC-007: field-assembly conformance -------------------------
        counts.check(track_artifact["required_facets"] == ["core-facet"], f"{case_name}: required_facets (AC-007)", repr(track_artifact["required_facets"]))
        counts.check(track_artifact["capabilities"] == ["cap-alpha", "cap-beta"], f"{case_name}: capabilities (AC-007)", repr(track_artifact["capabilities"]))
        counts.check(
            track_artifact["resolved_gates"] == [
                {"id": "gate-artifact", "stage": "artifact", "blocking": False},
                {"id": "gate-impl", "stage": "promotion", "blocking": True},
            ],
            f"{case_name}: resolved_gates (AC-007)", repr(track_artifact["resolved_gates"]),
        )
        counts.check(track_artifact.get("capability_minimum_enforcement") == "required", f"{case_name}: capability_minimum_enforcement (AC-007)", repr(track_artifact.get("capability_minimum_enforcement")))
        counts.check(
            track_artifact["lite_eligibility"] == {"eligible": False, "upgrade_reasons": ["pii"]},
            f"{case_name}: lite_eligibility (AC-007)", repr(track_artifact["lite_eligibility"]),
        )

        # --- AC-043/AC-052(b): cross-Capability + same-Capability
        # facet-name aggregation on the Facet Manifest itself -----------
        conditional_facets_by_name = {node["facet"]: node for node in track_artifact["conditional_facets"]}
        counts.check(
            sorted(conditional_facets_by_name) == ["shared-facet", "solo-never-facet"],
            f"{case_name}: conditional_facets[] facet-name-unique set (AC-043/AC-052(b))",
            repr(sorted(conditional_facets_by_name)),
        )
        shared_evidence = []
        for evals in (cap_alpha_cfe[0]["evaluations"], cap_alpha_cfe[1]["evaluations"], cap_beta_cfe[0]["evaluations"]):
            for entry in sorted(evals, key=lambda e: e["component_id"]):
                shared_evidence.extend(entry["evidence"])
        expected_shared_node = {"facet": "shared-facet", "applied": True, "evidence": shared_evidence}
        counts.check(
            conditional_facets_by_name.get("shared-facet") == expected_shared_node,
            f"{case_name}: 'shared-facet' aggregates cap-alpha[0], cap-alpha[1] (both declarations, never collapsed), and cap-beta[0], OR'd, evidence concatenated capability_id-then-declaration_index-then-component_id ascending (AC-043/AC-052(b))",
            repr(conditional_facets_by_name.get("shared-facet")),
        )
        # gate-cycle-2 Major C remediation: `solo-never-facet` used to have
        # exactly one contributing predicate instance (cap-alpha[2]), so
        # "names every contributing instance" and "names the first" were
        # indistinguishable and a mutant that only named the first survived
        # vacuously. cap-beta now ALSO declares `solo-never-facet` (index 1,
        # `capability-registry.json`) with its own always-false predicate,
        # so `reason` must name both, in `capability_id`-then-
        # `declaration_index` ascending order (cap-alpha[2] before
        # cap-beta[1]).
        solo_never_evidence = []
        for evals in (cap_alpha_cfe[2]["evaluations"], cap_beta_cfe[1]["evaluations"]):
            for entry in sorted(evals, key=lambda e: e["component_id"]):
                solo_never_evidence.extend(entry["evidence"])
        expected_solo_node = {
            "facet": "solo-never-facet", "applied": False, "evidence": solo_never_evidence,
            "reason": "no contributing predicate instance's conditional facet matched any affected component (contributing: cap-alpha[2], cap-beta[1])",
        }
        counts.check(
            conditional_facets_by_name.get("solo-never-facet") == expected_solo_node,
            f"{case_name}: 'solo-never-facet' (two contributing instances, not applied) names BOTH cap-alpha[2] AND cap-beta[1] in its own reason, never just the first (AC-043's own N/A-reason case)",
            repr(conditional_facets_by_name.get("solo-never-facet")),
        )

        # --- AC-008: Facet Manifest schema-conformance ------------------
        validate_result = _validate_facet_manifest(track_artifact)
        counts.check(
            validate_result.returncode == 0,
            f"{case_name}: reconstructed Facet Manifest validates via the real validate-facet-manifest (AC-008)",
            validate_result.stdout.decode("utf-8", errors="replace") + validate_result.stderr.decode("utf-8", errors="replace"),
        )


def run_enforcement_byte_identity_case(kind, counts):
    """TEST-016: a fixture pair identical except `workflow.
    capability_enforcement` (advisory vs. required) produces byte-identical
    Resolver Evidence except its own `state` field (AC-016). No matched
    Capability's own `lite_policy.required_lite_checks` key is at issue --
    this fixture uses the Full track, sidestepping the Lite-track-only
    caveat AC-016's own row text names entirely."""
    case_name = "enforcement-byte-identity"
    fixture_dir = FIXTURES / case_name
    results = {}
    for variant in ("advisory", "required"):
        with tempfile.TemporaryDirectory(prefix="resolver-match-enf-") as tmp:
            repo = Path(tmp).resolve()
            subprocess.run(["git", "init", "-q", str(repo)], check=True, capture_output=True)
            scripts = block_check.install_scripts(repo)
            feature_dir, sentinels = block_check.plant_sentinels(repo, scripts)
            shutil.copy2(fixture_dir / f"project-context-{variant}.yaml", repo / "project-context.yaml")
            block_check.install_t003_dependencies(
                repo, scripts, fixture_dir, stub_name="generate-registry-digest.py",
                registry_capabilities_path=fixture_dir / "capability-registry.json",
            )

            (repo / "README.md").write_text("baseline\n", encoding="utf-8")
            base_oid = block_check.git_commit_all(repo, "baseline")
            (repo / "comp-a").mkdir()
            (repo / "comp-a/file.txt").write_text("a\n", encoding="utf-8")
            target_oid = block_check.git_commit_all(repo, "add comp-a")

            argv = block_check.t003_resolver_argv(kind, scripts, base_oid, target_oid)
            result = subprocess.run(argv, cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
            stdout = result.stdout.decode("utf-8", errors="replace")
            stderr = result.stderr.decode("utf-8", errors="replace")
            counts.check(result.returncode == 1, f"{case_name}-{variant}: exit 1", f"got {result.returncode} stderr={stderr!r}")
            counts.check(
                stdout == "" and stderr == SNAPSHOT_MISMATCH_LINE,
                f"{case_name}-{variant}: canonical diagnostic only",
                f"stdout={stdout!r} stderr={stderr!r}",
            )

            evidence_path = feature_dir / "resolver-evidence.yaml"
            evidence, parse_error = block_check.read_evidence(evidence_path)
            counts.check(
                isinstance(evidence, dict) and evidence.get("state") == variant,
                f"{case_name}-{variant}: state field records {variant!r}",
                parse_error or repr(evidence),
            )
            block_check.check_evidence_schema(counts, evidence_path, f"{case_name}-{variant}")
            unchanged = all(path.read_bytes() == value for path, value in sentinels.items())
            counts.check(unchanged, f"{case_name}-{variant}: no partial live artifact")
            results[variant] = evidence

    advisory = results.get("advisory")
    required = results.get("required")
    if isinstance(advisory, dict) and isinstance(required, dict):
        # T-004 NEEDS_WORK cycle 2 remediation ("late Blocks drop
        # provenance"): `context_binding` is now present on this fixture's
        # own `snapshot-generation-mismatch` Block (steps 10-13 have
        # already computed it), so this comparison must additionally
        # exclude `context_binding.full_context_revision`/`projection_
        # sha256` -- both are hashes of bytes that themselves ENCODE
        # `workflow.capability_enforcement` (the canonical Project
        # Context text and the canonical Context Projection text, which
        # copies `workflow` verbatim), so they are STRUCTURALLY
        # guaranteed to differ between this advisory/required fixture
        # pair for any correct implementation -- never identical, by
        # construction of a hash function over differing input bytes.
        # AC-016's own "byte-identical ... except state" claim is
        # therefore precise for every OTHER field (unaffected by which
        # single scalar differs in the source config), asserted
        # separately below rather than folded into a blanket exclusion
        # that would silently stop checking `context_binding` at all.
        def _without(evidence, *keys):
            stripped = {k: v for k, v in evidence.items() if k != "state"}
            context_binding = dict(stripped.get("context_binding") or {})
            for key in keys:
                context_binding.pop(key, None)
            if "context_binding" in stripped:
                stripped["context_binding"] = context_binding
            return stripped

        advisory_minus_state = _without(advisory, "full_context_revision", "projection_sha256")
        required_minus_state = _without(required, "full_context_revision", "projection_sha256")
        counts.check(
            advisory_minus_state == required_minus_state,
            f"{case_name}: Resolver Evidence byte-identical across advisory/required except state and the two "
            "config-byte-derived context_binding digests (AC-016)",
            f"advisory={advisory_minus_state!r} required={required_minus_state!r}",
        )

        advisory_binding = advisory.get("context_binding") or {}
        required_binding = required.get("context_binding") or {}
        counts.check(
            advisory_binding.get("full_context_revision") != required_binding.get("full_context_revision")
            and advisory_binding.get("projection_sha256") != required_binding.get("projection_sha256"),
            f"{case_name}: full_context_revision/projection_sha256 genuinely DO differ across advisory/required "
            "(sanity -- confirms the exclusion above is not vacuous)",
            f"advisory={advisory_binding!r} required={required_binding!r}",
        )
    else:
        counts.check(False, f"{case_name}: both advisory/required Resolver Evidence readable")


def run_facet_manifest_state_independence_check(resolver_module, counts):
    """AC-016's own remaining claim ("byte-identical ... across this
    invocation's own track-exclusive output set") extends past Resolver
    Evidence to the Facet Manifest itself, which is never written to any
    live path pre-T-007 (module docstring) and so cannot be compared via
    two written files. `_assemble_facet_manifest` takes no `state`/
    `capability_enforcement` parameter at all -- a structural, white-box
    guarantee, checked here directly against the REAL function's own
    signature, that its own output cannot depend on that field on the
    Full track."""
    import inspect
    params = set(inspect.signature(resolver_module._assemble_facet_manifest).parameters)
    counts.check(
        "state" not in params and "capability_enforcement" not in params,
        "enforcement-byte-identity: _assemble_facet_manifest takes no state/capability_enforcement parameter "
        "(structural proof the Facet Manifest itself is enforcement-independent on the Full track, AC-016 remainder)",
        repr(params),
    )


WARN_SUMMARY_DETAIL = "a predicate evaluation produced an outcome: warn evidence node"
WARN_DIAGNOSTIC_ID = "dsl-warn-on-matched-capability"


def _expected_trigger_warn_detail(fixture_dir, registry_document, capability_id, component_id):
    """RT-20260823-001 Minor (warn `detail` substring-only tightening):
    independently recomputes ONE trigger evaluation's own exact warn
    `detail` string -- via the SAME real, unmutated `evaluate-predicate`
    dependency `block_check.real_evaluate_predicate` already uses
    elsewhere in this driver (never `resolve-project-context.py` itself,
    never a second evaluation performed inside the resolver module) fed
    this fixture's own real `project-context.yaml`/`capability-
    registry.json` text, and the SAME byte-for-byte `_warn_diagnostic_
    detail` mirror (`block_check.expected_warn_diagnostic`) T-002/T-003's
    own suite already established and reuses verbatim (module docstring:
    "reuse this task's own already-established mechanism, don't invent a
    second one") -- so the two warn-detail checks below can assert full
    string equality instead of merely "this substring appears somewhere."
    Both TEST-056 fixtures use a single-clause trigger (`equals`, no AND/
    OR/NOT nesting) evaluated with `declaration_index=None` (a trigger,
    never a conditional facet -- resolve-project-context.py's own
    `_evaluate_capabilities`), so exactly one warn node exists per
    component, at that component's own top-level evidence index."""
    _, document = _canonicalize_yaml(fixture_dir / "project-context.yaml")
    component = next(c for c in document["components"] if c["id"] == component_id)
    properties = {key: value for key, value in component.items() if key != "id"}
    trigger = next(c for c in registry_document["capabilities"] if c["id"] == capability_id)["trigger"]
    _, evidence_nodes = block_check.real_evaluate_predicate(trigger, properties)
    [(node_index, warn_node)] = [
        (idx, node) for idx, node in enumerate(evidence_nodes) if node.get("outcome") == "warn"
    ]
    return block_check.expected_warn_diagnostic(
        capability_id, component_id, None, (node_index,), warn_node,
    )["detail"]


def _check_warn_cardinality(counts, case_name, evidence, sentinels, evidence_path, expected_warn_count):
    """Shared AC-056 assertion body for both TEST-056 fixtures below:
    exactly `expected_warn_count` `severity: "warn"` diagnostics[] entries
    (one per individual `outcome: "warn"` DSL-evaluation node the
    fixture's own input produces) plus exactly one additional
    `severity: "block"` summary entry, all sharing the identical
    `dsl-warn-on-matched-capability` id, every `detail` distinct (no
    `(id, detail)` pair repeats -- AC-024), and the summary entry's own
    `detail` the fixed sentence, never a warn entry's own."""
    if not isinstance(evidence, dict):
        counts.check(False, f"{case_name}: Resolver Evidence readable", repr(evidence))
        return
    diagnostics = evidence.get("diagnostics", [])
    warn_entries = [d for d in diagnostics if d.get("severity") == "warn"]
    block_entries = [d for d in diagnostics if d.get("severity") == "block"]

    counts.check(
        len(warn_entries) == expected_warn_count,
        f"{case_name}: exactly {expected_warn_count} severity:warn entr{'y' if expected_warn_count == 1 else 'ies'}, "
        f"one per outcome:warn node, never fewer (AC-056)",
        repr(diagnostics),
    )
    counts.check(
        len(block_entries) == 1,
        f"{case_name}: exactly one summary severity:block entry, never a second (AC-056)",
        repr(diagnostics),
    )
    counts.check(
        diagnostics and all(d.get("id") == WARN_DIAGNOSTIC_ID for d in diagnostics),
        f"{case_name}: every diagnostics[] entry shares the identical {WARN_DIAGNOSTIC_ID!r} id (AC-056)",
        repr(diagnostics),
    )
    counts.check(
        bool(block_entries) and block_entries[0].get("detail") == WARN_SUMMARY_DETAIL,
        f"{case_name}: the summary severity:block entry's own detail is the fixed summary sentence, "
        f"distinct from every severity:warn entry's own detail (AC-056)",
        repr(block_entries),
    )
    warn_details = [d.get("detail") for d in warn_entries]
    counts.check(
        WARN_SUMMARY_DETAIL not in warn_details,
        f"{case_name}: no severity:warn entry's own detail collides with the summary sentence (AC-056)",
        repr(warn_details),
    )
    all_details = [d.get("detail") for d in diagnostics]
    counts.check(
        len(all_details) == len(set(all_details)),
        f"{case_name}: no (id, detail) pair repeats across diagnostics[] (AC-024)",
        repr(all_details),
    )
    # AC-024 stable-sort discipline (cross-epic panel finding,
    # 2026-08-23): diagnostics[] itself must be sorted by (id, detail),
    # not merely have the right membership. Since every entry here shares
    # the identical id (checked above), this is decided by detail alone --
    # and the summary sentence ("...outcome: warn evidence node") is a
    # strict lexical PREFIX of every per-node detail ("...outcome: warn
    # evidence node at ..."), so the correct sort puts the summary FIRST,
    # not last (the prior emission order). The expectation is DERIVED via
    # `sorted(..., key=(id, detail))` here -- the identical rule
    # `_write_evidence` itself now applies -- never a second,
    # independently-ordered array, which would just relocate the same
    # "expectation mirrors emission" defect this finding named.
    counts.check(
        diagnostics == sorted(diagnostics, key=lambda entry: (entry.get("id"), entry.get("detail"))),
        f"{case_name}: diagnostics[] is sorted by (id, detail) -- the summary entry sorts FIRST, "
        f"since its own fixed sentence is a strict lexical prefix of every per-node detail (AC-024)",
        repr(diagnostics),
    )
    block_check.check_evidence_schema(counts, evidence_path, case_name)
    unchanged = all(path.read_bytes() == value for path, value in sentinels.items())
    counts.check(unchanged, f"{case_name}: no partial live artifact")


def run_warn_cardinality_single_node_case(kind, counts):
    """TEST-056 (part 1): reuses REQ-006 item (d)'s own `dsl-warn-
    unmatched-trigger` any-branch-WARN fixture verbatim (T-003's own
    already-authored `tests/fixtures/capability-resolver/resolve-project-
    context-block/dsl-warn-unmatched-trigger/`, per AC-056's own
    spec-review remedy directing reuse over inventing a new single-node
    fixture) -- a single affected component (`comp-a`) whose own trigger
    evaluation produces exactly one `outcome: "warn"` DSL-evaluation node
    (the `characteristics.auto_update` field is absent), asserting the
    `diagnostics[]` warn/block cardinality lock for the 1-node case."""
    case_name = "warn-cardinality-single-node"
    fixture_dir = block_check.FIXTURES / "dsl-warn-unmatched-trigger"
    with tempfile.TemporaryDirectory(prefix="resolver-match-warn1-") as tmp:
        repo = Path(tmp).resolve()
        subprocess.run(["git", "init", "-q", str(repo)], check=True, capture_output=True)
        scripts = block_check.install_scripts(repo)
        feature_dir, sentinels = block_check.plant_sentinels(repo, scripts)
        shutil.copy2(fixture_dir / "project-context.yaml", repo / "project-context.yaml")
        registry_path = fixture_dir / "capability-registry.json"
        block_check.install_t003_dependencies(
            repo, scripts, fixture_dir, registry_capabilities_path=registry_path,
        )

        (repo / "README.md").write_text("baseline\n", encoding="utf-8")
        base_oid = block_check.git_commit_all(repo, "baseline")
        (repo / "comp-a").mkdir()
        (repo / "comp-a/file.txt").write_text("x\n", encoding="utf-8")
        target_oid = block_check.git_commit_all(repo, "add comp-a")

        argv = block_check.t003_resolver_argv(kind, scripts, base_oid, target_oid)
        result = subprocess.run(argv, cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        expected_line = f"capability-resolver: {WARN_DIAGNOSTIC_ID}: {WARN_SUMMARY_DETAIL}\n"
        counts.check(result.returncode == 1, f"{case_name}: exit 1", f"got {result.returncode} stderr={stderr!r}")
        counts.check(
            stdout == "" and stderr == expected_line,
            f"{case_name}: canonical diagnostic only, no upstream stderr embedded (M8)",
            f"stdout={stdout!r} stderr={stderr!r}",
        )

        evidence_path = feature_dir / "resolver-evidence.yaml"
        evidence, parse_error = block_check.read_evidence(evidence_path)
        if not isinstance(evidence, dict):
            counts.check(False, f"{case_name}: Resolver Evidence readable", parse_error or repr(evidence))
            return
        _check_warn_cardinality(counts, case_name, evidence, sentinels, evidence_path, expected_warn_count=1)
        warn_details = [d.get("detail") for d in evidence.get("diagnostics", []) if d.get("severity") == "warn"]
        registry_document = json.loads(registry_path.read_text(encoding="utf-8"))
        expected_detail = _expected_trigger_warn_detail(fixture_dir, registry_document, "cap-unmatched-warn", "comp-a")
        counts.check(
            warn_details == [expected_detail],
            f"{case_name}: the severity:warn entry's own detail is byte-identical to this node's own "
            f"independently-recomputed capability_id/component_id/operator/field/reason text, never merely "
            f"a substring match (AC-056; RT-20260823-001 Minor)",
            repr({"actual": warn_details, "expected": [expected_detail]}),
        )


def run_warn_cardinality_multi_node_case(kind, counts):
    """TEST-056 (part 2, AC-056's own companion fixture): a NEW,
    purpose-built multi-node fixture -- one Capability's own trigger,
    evaluated against three affected components (`comp-a`/`comp-b`/
    `comp-c`), none of which declare `characteristics.auto_update`, so
    every one of the three per-component trigger evaluations produces its
    own independent `outcome: "warn"` DSL-evaluation node. Confirms the
    `diagnostics[]` entry count scales 1:1 with node count (three
    `severity: "warn"` entries, each naming its own distinct
    `component_id`) plus exactly one summary `severity: "block"` entry --
    never fewer, never a second summary entry -- and that no `(id,
    detail)` pair repeats (AC-024)."""
    case_name = "warn-cardinality-multi-node"
    fixture_dir = FIXTURES / case_name
    with tempfile.TemporaryDirectory(prefix="resolver-match-warnN-") as tmp:
        repo = Path(tmp).resolve()
        subprocess.run(["git", "init", "-q", str(repo)], check=True, capture_output=True)
        scripts = block_check.install_scripts(repo)
        feature_dir, sentinels = block_check.plant_sentinels(repo, scripts)
        shutil.copy2(fixture_dir / "project-context.yaml", repo / "project-context.yaml")
        registry_path = fixture_dir / "capability-registry.json"
        block_check.install_t003_dependencies(
            repo, scripts, fixture_dir, registry_capabilities_path=registry_path,
        )

        (repo / "README.md").write_text("baseline\n", encoding="utf-8")
        base_oid = block_check.git_commit_all(repo, "baseline")
        (repo / "comp-a").mkdir()
        (repo / "comp-a/file.txt").write_text("a\n", encoding="utf-8")
        (repo / "comp-b").mkdir()
        (repo / "comp-b/file.txt").write_text("b\n", encoding="utf-8")
        (repo / "comp-c").mkdir()
        (repo / "comp-c/file.txt").write_text("c\n", encoding="utf-8")
        target_oid = block_check.git_commit_all(repo, "add comp-a, comp-b, comp-c")

        argv = block_check.t003_resolver_argv(kind, scripts, base_oid, target_oid)
        result = subprocess.run(argv, cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        expected_line = f"capability-resolver: {WARN_DIAGNOSTIC_ID}: {WARN_SUMMARY_DETAIL}\n"
        counts.check(result.returncode == 1, f"{case_name}: exit 1", f"got {result.returncode} stderr={stderr!r}")
        counts.check(
            stdout == "" and stderr == expected_line,
            f"{case_name}: canonical diagnostic only, no upstream stderr embedded (M8)",
            f"stdout={stdout!r} stderr={stderr!r}",
        )

        evidence_path = feature_dir / "resolver-evidence.yaml"
        evidence, parse_error = block_check.read_evidence(evidence_path)
        if not isinstance(evidence, dict):
            counts.check(False, f"{case_name}: Resolver Evidence readable", parse_error or repr(evidence))
            return
        _check_warn_cardinality(counts, case_name, evidence, sentinels, evidence_path, expected_warn_count=3)
        warn_details = [d.get("detail") for d in evidence["diagnostics"] if d.get("severity") == "warn"]
        registry_document = json.loads(registry_path.read_text(encoding="utf-8"))
        expected_by_component = {
            component: _expected_trigger_warn_detail(fixture_dir, registry_document, "cap-multi-warn", component)
            for component in ("comp-a", "comp-b", "comp-c")
        }
        # Minor fix (gate-cycle-1): the prior version of this check only
        # confirmed every component_id appeared SOMEWHERE in the joined
        # string of all three details -- true even if one detail named two
        # components and another named none. RT-20260823-001 Minor
        # (tightened further): rather than a bijection over substring
        # containment, assert the multiset of actual details is exactly
        # the multiset of independently-recomputed expected details --
        # still a bijection between {comp-a, comp-b, comp-c} and the three
        # details (each expected value is distinct, since each names its
        # own component_id), now on full string equality rather than
        # 'every name appears somewhere in the joined string'.
        counts.check(
            sorted(warn_details) == sorted(expected_by_component.values()),
            f"{case_name}: each of the three severity:warn entries' own detail is byte-identical to its own "
            f"independently-recomputed capability_id/component_id/operator/field/reason text -- a bijection "
            f"between {{comp-a, comp-b, comp-c}} and the three details (AC-056; RT-20260823-001 Minor)",
            repr({"actual": sorted(warn_details), "expected": sorted(expected_by_component.values())}),
        )


_RESOLVER_IDENTITY_PROBE = """
import importlib.util, json, os, sys
spec = importlib.util.spec_from_file_location("resolve_project_context_oracle", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
print(json.dumps({
    "version": module.RESOLVER_VERSION,
    "rule_set_revision": module.RULE_SET_REVISION,
    "pid": os.getpid(),
}))
"""


def run_resolver_identity_cross_process_check(counts):
    """AC-044 remainder (Major 1 remediation): `resolver.version`/
    `resolver.rule_set_revision` must be identical 'across repeated
    invocations and across the .py/.sh/.ps1 runtimes' -- a claim about
    INDEPENDENT invocations, not about one already-loaded module compared
    against itself. `run_full_pipeline_match_case`'s own AC-044 assertion
    (above) loads `resolve-project-context.py` exactly once per test-driver
    process and diffs the assembled `resolver_block` against that SAME
    load's own `RESOLVER_VERSION`/`RULE_SET_REVISION` -- invisible to a
    per-process derivation (e.g. folding `os.getpid()` into
    `RULE_SET_STRING`), since both sides of that comparison necessarily
    share one pid. This check instead spawns the staged `.py` master TWICE,
    as two genuinely separate OS processes (fresh `python3` interpreter,
    fresh `importlib` load each time -- never the driver's own in-process
    module), and diffs the two independently-produced values."""
    staged_py = block_check.STAGED / "resolve-project-context.py"
    runs = []
    for _ in range(2):
        result = subprocess.run(
            [sys.executable, "-c", _RESOLVER_IDENTITY_PROBE, str(staged_py)],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
        )
        runs.append(json.loads(result.stdout.decode("utf-8")))
    first, second = runs
    counts.check(
        first["pid"] != second["pid"],
        "resolver-identity-cross-process: sanity -- the two invocations are genuinely separate OS "
        "processes (distinct pid), not one process's own module compared against itself",
        repr(runs),
    )
    counts.check(
        first["version"] == second["version"] and first["rule_set_revision"] == second["rule_set_revision"],
        "resolver-identity-cross-process: resolver.version/rule_set_revision are identical across two "
        "genuinely separate process invocations of the identical staged .py (AC-044 remainder -- kills a "
        "per-process derivation, e.g. folding os.getpid() into RULE_SET_STRING, that an in-process "
        "self-comparison cannot see)",
        repr(runs),
    )


def run_dispatcher_delegation_check(counts):
    """AC-044 remainder (Major 1 remediation), structural half: the
    cross-process check above proves the .py master's own two constants
    are invocation-stable, but AC-044's own text also spans the `.sh`/
    `.ps1` runtimes, and neither dispatcher ever surfaces
    `resolver.version`/`resolver.rule_set_revision` to any externally
    observable location pre-T-007 (module docstring), so no real
    subprocess run can black-box-compare them. This white-box structural
    check instead reads each staged dispatcher's own source text and
    confirms (a) every mention of the identical staged
    `resolve-project-context.py` in the dispatcher's own text is a genuine
    process-launch statement -- never a bare textual mention (e.g. a
    comment) and never a second, forked implementation -- and (b) it
    carries no copy of its own -- no `RESOLVER_VERSION`/`RULE_SET_REVISION`/
    `RULE_SET_STRING` identifier appears anywhere in either dispatcher's own
    text -- so cross-runtime identity is a structural consequence of
    single-sourcing, not two values that merely happen to agree today.

    gate-cycle-2 Minor remediation: this used to label itself "delegates
    unconditionally" while its own check only substring-tested for
    "resolve-project-context.py" ANYWHERE in the file -- satisfied even by
    a stray comment mentioning the filename with no invocation at all. Each
    runtime's own launch marker (`exec` for the POSIX `sh` dispatcher,
    `ArgumentList.Add` for the `.ps1` dispatcher's own process object) must
    now appear on the SAME line as every delegation-marker occurrence --
    both of the real `sh` dispatcher's own two interpreter-fallback `exec`
    lines (`python3` then `python`) legitimately satisfy this, so the check
    is "every mention is a real launch," never "exactly one mention" (which
    would false-fail the real, correct dispatcher)."""
    identity_identifiers = ("RESOLVER_VERSION", "RULE_SET_REVISION", "RULE_SET_STRING")
    launch_markers = {"sh": "exec", "ps1": "ArgumentList.Add"}
    for suffix, delegation_marker in (("sh", "resolve-project-context.py"), ("ps1", "resolve-project-context.py")):
        dispatcher_path = block_check.STAGED / f"resolve-project-context.{suffix}"
        text = dispatcher_path.read_text(encoding="utf-8")
        launch_marker = launch_markers[suffix]
        mention_lines = [line for line in text.splitlines() if delegation_marker in line]
        genuine_launch_lines = [line for line in mention_lines if launch_marker in line]
        delegates_only_via_real_launch = bool(genuine_launch_lines) and genuine_launch_lines == mention_lines
        carries_own_copy = any(identifier in text for identifier in identity_identifiers)
        counts.check(
            delegates_only_via_real_launch and not carries_own_copy,
            f"resolver-identity-dispatcher-delegation: every mention of resolve-project-context.py in "
            f"resolve-project-context.{suffix} is a real process-launch statement (never a bare textual "
            f"mention, never a second implementation) and it carries no own copy of "
            f"RESOLVER_VERSION/RULE_SET_REVISION/RULE_SET_STRING (AC-044 remainder)",
            f"mention_lines={mention_lines!r} genuine_launch_lines={genuine_launch_lines!r} carries_own_copy={carries_own_copy}",
        )


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--launcher", choices=("sh", "ps1"), required=True)
    args = parser.parse_args()
    counts = block_check.Counts()

    required_files = [block_check.STAGED / f"resolve-project-context.{suffix}" for suffix in ("py", "sh", "ps1")]
    case_labels = [
        "full-pipeline-match", "enforcement-byte-identity",
        "warn-cardinality-single-node", "warn-cardinality-multi-node",
    ]
    if not all(path.is_file() for path in required_files):
        for label in case_labels:
            counts.check(False, f"{label}: staged implementation exists", "TDD RED: implementation absent")
    else:
        resolver_module = _load_module(block_check.STAGED / "resolve-project-context.py", "resolve_project_context_oracle")
        run_full_pipeline_match_case(args.launcher, resolver_module, counts)
        run_enforcement_byte_identity_case(args.launcher, counts)
        run_facet_manifest_state_independence_check(resolver_module, counts)
        run_warn_cardinality_single_node_case(args.launcher, counts)
        run_warn_cardinality_multi_node_case(args.launcher, counts)
        run_resolver_identity_cross_process_check(counts)
        run_dispatcher_delegation_check(counts)

    sh_registered = "tests/resolve-project-context-match.tests.sh" in (ROOT / "tests/run-all.sh").read_text(encoding="utf-8")
    ps_registered = "tests/resolve-project-context-match.tests.ps1" in (ROOT / "tests/run-all.ps1").read_text(encoding="utf-8")
    counts.check(sh_registered, "POSIX suite registered in tests/run-all.sh")
    counts.check(ps_registered, "PowerShell suite registered in tests/run-all.ps1")

    print(f"RESULT: {counts.passed} passed, {counts.failed} failed")
    return 1 if counts.failed else 0


if __name__ == "__main__":
    sys.exit(main())
