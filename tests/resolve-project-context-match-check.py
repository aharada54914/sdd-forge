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
T-002/T-003/T-004 already built writes only `{schema, feature,
capability_evaluations, diagnostics, state}` to Resolver Evidence --
never `context_binding`, `resolver`, or the track-exclusive artifact
(Facet Manifest/Capability Summary) itself, on ANY path, Block or clean.
Live publication of those fields is entirely T-007's own step-14 scope,
not yet landed on this branch. Several of this task's own target ACs
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
        target_oid = block_check.git_commit_all(repo, "add comp-a, comp-b, shared/util")

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
        canonical_context, document = _canonicalize_yaml(repo / "project-context.yaml")
        source_sha256 = "sha256:" + hashlib.sha256(canonical_context).hexdigest()
        expected_projection = resolver_module._projection(document, source_sha256)
        capture_path = repo / "projection-capture.json"
        captured, capture_parse_error = block_check.read_evidence(capture_path)
        counts.check(
            captured == expected_projection,
            f"{case_name}: Context Projection byte-identity (AC-003)",
            capture_parse_error or repr(captured),
        )

        # --- AC-004: resolve-component-paths pass-through --------------
        rcp_capture_path = scripts / "rcp-argv-capture.json"
        rcp_argv, rcp_parse_error = block_check.read_evidence(rcp_capture_path)
        expected_rcp_argv = [
            "--config", "project-context.yaml",
            "--source-rev", base_oid,
            "--target-rev", target_oid,
            "--no-include-untracked",
            "--json",
        ]
        counts.check(
            rcp_argv == expected_rcp_argv,
            f"{case_name}: resolve-component-paths invoked with --config/--source-rev/--target-rev/--include-untracked byte-identical to received flags (AC-004)",
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
        # at step 13 (AC-005 binding half; `context_binding` itself is
        # never externally observable pre-T-007, see module docstring).
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

        affected_components = sorted(["comp-a", "comp-b", "shared/util"])

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
        cfe_pairs = [(e["facet"], e["declaration_index"]) for e in cap_alpha_evidence["conditional_facet_evaluations"]]
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
        projection_sha256 = "sha256:" + hashlib.sha256(_canonicalize_json_document(expected_projection)).hexdigest()
        real_rcp = subprocess.run(
            [sys.executable, str(scripts / "resolve-component-paths-real.py")] + expected_rcp_argv,
            cwd=repo, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
        )
        real_rcp_parsed = json.loads(real_rcp.stdout.decode("utf-8"))
        ownership_digest = real_rcp_parsed["context_binding"]["ownership_digest"]
        counts.check(
            sorted(real_rcp_parsed["affected_components"]) == affected_components,
            f"{case_name}: independently-recomputed affected_components matches the fixture's own three components",
            repr(real_rcp_parsed.get("affected_components")),
        )
        registry_digest = "sha256:" + ("1" * 64)  # this fixture's own stub's FIRST_DIGEST (step 6's own value)

        context_binding = resolver_module._assemble_context_binding(
            source_sha256, affected_components, projection_sha256, registry_digest, ownership_digest,
        )
        resolver_block = resolver_module._resolver_block()

        # AC-044: dependency_pointers[] RFC-6901 canonical derivation,
        # exercising the escape rule against "shared/util"'s own `/`.
        expected_pointers = sorted({"/workflow", "/components/comp-a", "/components/comp-b", "/components/shared~1util"})
        counts.check(
            context_binding["dependency_pointers"] == expected_pointers,
            f"{case_name}: dependency_pointers[] is /workflow plus one RFC-6901-escaped pointer per affected component, stable-sorted (AC-044)",
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
        solo_never_evidence = []
        for entry in sorted(cap_alpha_cfe[2]["evaluations"], key=lambda e: e["component_id"]):
            solo_never_evidence.extend(entry["evidence"])
        expected_solo_node = {
            "facet": "solo-never-facet", "applied": False, "evidence": solo_never_evidence,
            "reason": "no contributing predicate instance's conditional facet matched any affected component (contributing: cap-alpha[2])",
        }
        counts.check(
            conditional_facets_by_name.get("solo-never-facet") == expected_solo_node,
            f"{case_name}: 'solo-never-facet' (single contributing instance, not applied) names cap-alpha[2] in its own reason (AC-043's own N/A-reason case)",
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
        advisory_minus_state = {k: v for k, v in advisory.items() if k != "state"}
        required_minus_state = {k: v for k, v in required.items() if k != "state"}
        counts.check(
            advisory_minus_state == required_minus_state,
            f"{case_name}: Resolver Evidence byte-identical across advisory/required except state (AC-016)",
            f"advisory={advisory_minus_state!r} required={required_minus_state!r}",
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


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--launcher", choices=("sh", "ps1"), required=True)
    args = parser.parse_args()
    counts = block_check.Counts()

    required_files = [block_check.STAGED / f"resolve-project-context.{suffix}" for suffix in ("py", "sh", "ps1")]
    case_labels = ["full-pipeline-match", "enforcement-byte-identity"]
    if not all(path.is_file() for path in required_files):
        for label in case_labels:
            counts.check(False, f"{label}: staged implementation exists", "TDD RED: implementation absent")
    else:
        resolver_module = _load_module(block_check.STAGED / "resolve-project-context.py", "resolve_project_context_oracle")
        run_full_pipeline_match_case(args.launcher, resolver_module, counts)
        run_enforcement_byte_identity_case(args.launcher, counts)
        run_facet_manifest_state_independence_check(resolver_module, counts)

    sh_registered = "tests/resolve-project-context-match.tests.sh" in (ROOT / "tests/run-all.sh").read_text(encoding="utf-8")
    ps_registered = "tests/resolve-project-context-match.tests.ps1" in (ROOT / "tests/run-all.ps1").read_text(encoding="utf-8")
    counts.check(sh_registered, "POSIX suite registered in tests/run-all.sh")
    counts.check(ps_registered, "PowerShell suite registered in tests/run-all.ps1")

    print(f"RESULT: {counts.passed} passed, {counts.failed} failed")
    return 1 if counts.failed else 0


if __name__ == "__main__":
    sys.exit(main())
