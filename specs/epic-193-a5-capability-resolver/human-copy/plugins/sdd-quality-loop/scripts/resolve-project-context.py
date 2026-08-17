#!/usr/bin/env python3
"""Capability Resolver, implementation stages T-002+T-003 (steps 0-9).

T-002 validates CLI input, derives Resolver state, obtains a single canonical
Project Context snapshot, and assembles/canonicalizes the Context Projection
in memory (steps 0-3). T-003 extends the same Python master with
affected-component resolution (`resolve-component-paths`), Registry
discovery + validation (ADR-0025 discovery + `validate-capability-registry`),
`registry_digest` (`generate-registry-digest --whole`), per-Capability/
per-affected-component trigger evaluation, matched-Capability
conditional-facet evaluation (both via `evaluate-predicate`), and the
any-branch WARN check (steps 4-9). Every step 4-9 result is staged in memory
only -- T-004 assembles the track branch and Resolver Evidence for a clean
resolve and performs output schema self-validation and the pre-publication
recheck (steps 10-13); T-007 layers the crash-recovery scan and the journaled
publication transaction (step 14) onto this same script.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


EXIT_BLOCK = 1
EXIT_USAGE = 2
FEATURE_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
EVIDENCE_SCHEMA = "sdd-resolver-evidence/v1"


class CanonicalizerFailed(Exception):
    pass


class CanonicalizerOutputMalformed(Exception):
    pass


class AffectedComponentResolutionFailed(Exception):
    """`resolve-component-paths` itself exited non-zero (step 4)."""

    def __init__(self, returncode):
        super().__init__(f"resolve-component-paths exited {returncode}")
        self.returncode = returncode


class ContractDiscoveryFailed(Exception):
    """ADR-0025 discovery/version-check failure for a Registry artifact
    (step 5's own `contract-discovery-failed` half)."""


class RegistryValidationFailed(Exception):
    """`validate-capability-registry` (step 5) or a `PREDICATE_SCHEMA_ERROR`
    exit from `evaluate-predicate` (steps 7/8) -- both are, by construction,
    a Registry validation defect this feature did not itself introduce."""


class DependencySubprocessFailed(Exception):
    """A dependency subprocess's own generic, otherwise-unnamed non-zero
    exit (B3's closed-enum catch-all) -- `generate-registry-digest` (step 6)
    or `evaluate-predicate` (steps 7/8), for a reason other than an internal
    canonicalizer failure or a `PREDICATE_SCHEMA_ERROR`."""


class DependencyOutputMalformed(Exception):
    """A dependency subprocess exited zero but its own stdout does not
    parse as the JSON/digest shape that dependency's own contract promises
    (B3)."""


def _reject_json_constant(token):
    raise ValueError(f"non-standard JSON constant {token}")


def _parse_args(argv):
    parser = argparse.ArgumentParser(prog="resolve-project-context.py")
    parser.add_argument("--config", required=True)
    parser.add_argument("--source-rev", default="HEAD")
    parser.add_argument("--target-rev", required=True)
    parser.add_argument("--include-untracked", action="store_true")
    parser.add_argument("--feature", required=True)
    args = parser.parse_args(argv)
    if not FEATURE_RE.fullmatch(args.feature):
        parser.error("--feature must match ^[a-z0-9][a-z0-9-]*$")
    return args


def _find_repo_root(config_path):
    candidate = config_path if config_path.is_absolute() else Path.cwd() / config_path
    for parent in (candidate.parent, *candidate.parent.parents):
        if (parent / ".git").exists():
            return parent
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=Path.cwd(), stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            check=False,
        )
    except OSError:
        result = None
    if result is not None and result.returncode == 0:
        return Path(result.stdout.decode("utf-8").strip())
    return Path.cwd()


def _canonicalizer_argv(input_path, input_format):
    script_dir = Path(__file__).resolve().parent
    python_master = script_dir / "canonicalize-sdd-yaml.py"
    shell_wrapper = script_dir / "canonicalize-sdd-yaml.sh"
    if python_master.is_file():
        return [sys.executable, str(python_master), str(input_path), "--input-format", input_format]
    if shell_wrapper.is_file():
        return [str(shell_wrapper), str(input_path), "--input-format", input_format]
    return ["canonicalize-sdd-yaml", str(input_path), "--input-format", input_format]


def _canonicalize(input_path, input_format):
    try:
        result = subprocess.run(
            _canonicalizer_argv(input_path, input_format),
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        )
    except OSError as exc:
        raise CanonicalizerFailed(str(exc)) from exc
    if result.returncode != 0:
        raise CanonicalizerFailed(f"exit {result.returncode}")
    try:
        text = result.stdout.decode("utf-8")
        parsed = json.loads(text, parse_constant=_reject_json_constant)
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        raise CanonicalizerOutputMalformed(str(exc)) from exc
    return result.stdout, parsed


def _repo_relative(path, repo_root):
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def _script_argv(script_dir, base_name, tail):
    python_master = script_dir / f"{base_name}.py"
    shell_wrapper = script_dir / f"{base_name}.sh"
    if python_master.is_file():
        return [sys.executable, str(python_master)] + tail
    if shell_wrapper.is_file():
        return [str(shell_wrapper)] + tail
    return [base_name] + tail


def _run_resolve_component_paths(script_dir, args):
    """Step 4: invoke `resolve-component-paths` with this invocation's own
    `--config`/`--source-rev`/`--target-rev`/`--include-untracked` values
    passed through verbatim -- no rev resolution, merge-base computation, or
    diff-basis logic performed here."""
    tail = [
        "--config", args.config,
        "--source-rev", args.source_rev,
        "--target-rev", args.target_rev,
        "--include-untracked" if args.include_untracked else "--no-include-untracked",
        "--json",
    ]
    argv = _script_argv(script_dir, "resolve-component-paths", tail)
    try:
        result = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    except OSError as exc:
        raise AffectedComponentResolutionFailed(f"launch failed: {exc}") from exc
    if result.returncode != 0:
        raise AffectedComponentResolutionFailed(result.returncode)
    try:
        parsed = json.loads(result.stdout.decode("utf-8"), parse_constant=_reject_json_constant)
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        raise DependencyOutputMalformed(str(exc)) from exc
    if not isinstance(parsed, dict):
        raise DependencyOutputMalformed("resolve-component-paths stdout is not a JSON object")
    affected_components = parsed.get("affected_components")
    ownership_digest = (parsed.get("context_binding") or {}).get("ownership_digest")
    if not isinstance(affected_components, list) or not all(isinstance(c, str) for c in affected_components):
        raise DependencyOutputMalformed("resolve-component-paths stdout has no valid affected_components array")
    if not isinstance(ownership_digest, str) or not re.fullmatch(r"sha256:[0-9a-f]{64}", ownership_digest):
        raise DependencyOutputMalformed("resolve-component-paths stdout has no valid context_binding.ownership_digest")
    return affected_components, ownership_digest


def _discover_registry(script_dir):
    """Step 5, discovery half: ADR-0025's own script-relative-then-git-root-
    fallback procedure (reused unmodified via Epic A2's own
    `registry_discovery` module, co-located with this script at its
    deployed, protected-suffix destination) for both `capability-
    registry.json` and its own `capability-registry.schema.json`."""
    sys.path.insert(0, str(script_dir))
    import registry_discovery  # noqa: E402  (deliberately deferred: co-located sibling module)

    try:
        registry_path = registry_discovery.discover_artifact("capability-registry.json")
        registry_discovery.discover_artifact("capability-registry.schema.json")
    except registry_discovery.DiscoveryError as exc:
        raise ContractDiscoveryFailed(str(exc)) from exc
    try:
        with registry_path.open("r", encoding="utf-8") as handle:
            registry_document = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        raise ContractDiscoveryFailed(str(exc)) from exc
    return registry_path, registry_document


def _validate_capability_registry(script_dir, registry_path):
    """Step 5, validation half: Epic A2's own `validate-capability-registry`
    checks (a)-(i), run against the located Registry as a real subprocess."""
    argv = _script_argv(script_dir, "validate-capability-registry", ["--registry", str(registry_path)])
    try:
        result = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    except OSError as exc:
        raise RegistryValidationFailed(f"launch failed: {exc}") from exc
    if result.returncode != 0:
        raise RegistryValidationFailed(f"exit {result.returncode}")


def _generate_registry_digest_whole(script_dir):
    """Step 6: `generate-registry-digest --whole` against the located
    Registry (the tool performs its own, identical ADR-0025 discovery).
    A canonicalizer failure inside that invocation is surfaced by the
    dependency's own stable `canonicalizer-failed:` error-class prefix
    (never this feature's own raw-stderr-embedding -- M8 -- this is a
    fixed, stable token this feature classifies control flow on, not a
    verbatim quotation placed into this feature's own emitted `detail`)."""
    argv = _script_argv(script_dir, "generate-registry-digest", ["--whole"])
    try:
        result = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    except OSError as exc:
        raise DependencySubprocessFailed(f"launch failed: {exc}") from exc
    if result.returncode != 0:
        stderr_text = result.stderr.decode("utf-8", errors="replace")
        if "canonicalizer-failed" in stderr_text:
            raise CanonicalizerFailed("generate-registry-digest")
        raise DependencySubprocessFailed(f"exit {result.returncode}")
    try:
        text = result.stdout.decode("ascii").strip()
    except UnicodeDecodeError as exc:
        raise DependencyOutputMalformed(str(exc)) from exc
    if not re.fullmatch(r"[0-9a-f]{64}", text):
        raise DependencyOutputMalformed("generate-registry-digest stdout is not a bare 64-hex digest")
    return "sha256:" + text


def _evaluate_predicate(script_dir, predicate, properties):
    """Steps 7/8's own shared per-(capability-or-facet, component) call:
    `evaluate-predicate --predicate <path> --component-properties <path>`.
    Both arguments are written to their own temp file (rather than `-`)
    since exactly one stdin stream cannot carry two independent documents."""
    predicate_fd, predicate_name = tempfile.mkstemp(suffix=".json")
    properties_fd, properties_name = tempfile.mkstemp(suffix=".json")
    try:
        with os.fdopen(predicate_fd, "w", encoding="utf-8") as handle:
            json.dump(predicate, handle, ensure_ascii=False, separators=(",", ":"))
        with os.fdopen(properties_fd, "w", encoding="utf-8") as handle:
            json.dump(properties, handle, ensure_ascii=False, separators=(",", ":"))
        argv = _script_argv(
            script_dir, "evaluate-predicate",
            ["--predicate", predicate_name, "--component-properties", properties_name],
        )
        try:
            result = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        except OSError as exc:
            raise DependencySubprocessFailed(f"launch failed: {exc}") from exc
        if result.returncode == 2:
            raise RegistryValidationFailed("PREDICATE_SCHEMA_ERROR")
        if result.returncode != 0:
            raise DependencySubprocessFailed(f"exit {result.returncode}")
        try:
            parsed = json.loads(result.stdout.decode("utf-8"), parse_constant=_reject_json_constant)
        except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
            raise DependencyOutputMalformed(str(exc)) from exc
        if (
            not isinstance(parsed, dict)
            or not isinstance(parsed.get("result"), bool)
            or not isinstance(parsed.get("evidence"), list)
        ):
            raise DependencyOutputMalformed("evaluate-predicate stdout is not the {result, evidence} shape")
        return parsed["result"], parsed["evidence"]
    finally:
        os.unlink(predicate_name)
        os.unlink(properties_name)


def _evidence_has_warn(evidence_nodes):
    """Depth-first scan for an `outcome: "warn"` node anywhere in an
    Evidence tree (step 9, B2's own any-branch, any-depth scope)."""
    for node in evidence_nodes:
        if node.get("outcome") == "warn":
            return True
        if _evidence_has_warn(node.get("children") or []):
            return True
    return False


def _evaluate_capabilities(script_dir, registry_document, affected_components, projection_components, capability_evaluations):
    """Steps 7-8. Every Registry Capability, matched or not, is evaluated in
    full against every affected component, in Registry-declaration order
    (capabilities) and ascending-lexicographic order (affected_components,
    already returned pre-sorted by `resolve-component-paths`) -- no
    short-circuit on any individual evaluation's own outcome. `capability_
    evaluations` is mutated in place (appending one complete entry per
    Capability only after that Capability's own evaluation set is fully
    built) so a caller can still read every already-completed entry if a
    dependency subprocess failure aborts this function partway through.
    Returns whether any evaluation's own Evidence tree contained an
    `outcome: "warn"` node anywhere (step 9's own condition)."""
    any_warn = False
    for capability in registry_document.get("capabilities", []):
        capability_id = capability["id"]
        trigger_evaluations = []
        matched = False
        for component_id in affected_components:
            properties = projection_components.get(component_id, {})
            result, evidence = _evaluate_predicate(script_dir, capability["trigger"], properties)
            if _evidence_has_warn(evidence):
                any_warn = True
            trigger_evaluations.append({"component_id": component_id, "result": result, "evidence": evidence})
            if result:
                matched = True
        entry = {"capability_id": capability_id, "matched": matched, "trigger_evaluations": trigger_evaluations}
        if matched:
            conditional_facet_evaluations = []
            for declaration_index, facet_declaration in enumerate(capability.get("conditional_facets", [])):
                evaluations = []
                applied = False
                for component_id in affected_components:
                    properties = projection_components.get(component_id, {})
                    result, evidence = _evaluate_predicate(script_dir, facet_declaration["when"], properties)
                    if _evidence_has_warn(evidence):
                        any_warn = True
                    evaluations.append({"component_id": component_id, "result": result, "evidence": evidence})
                    if result:
                        applied = True
                conditional_facet_evaluations.append({
                    "facet": facet_declaration["facet"],
                    "declaration_index": declaration_index,
                    "applied": applied,
                    "evaluations": evaluations,
                })
            entry["conditional_facet_evaluations"] = conditional_facet_evaluations
        capability_evaluations.append(entry)
    return any_warn


def _json_type_matches(value, expected):
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    return True


def _schema_errors(value, schema, pointer="$"):
    errors = []
    if "const" in schema and value != schema["const"]:
        errors.append(f"{pointer}: const mismatch")
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{pointer}: enum mismatch")
    expected_type = schema.get("type")
    if expected_type and not _json_type_matches(value, expected_type):
        return errors + [f"{pointer}: type mismatch"]
    if isinstance(value, str) and len(value) < schema.get("minLength", 0):
        errors.append(f"{pointer}: minLength mismatch")
    if isinstance(value, dict):
        properties = schema.get("properties", {})
        for required in schema.get("required", []):
            if required not in value:
                errors.append(f"{pointer}: missing {required}")
        if schema.get("additionalProperties") is False:
            for key in value:
                if key not in properties:
                    errors.append(f"{pointer}: additional property {key}")
        for key, child in value.items():
            if key in properties:
                errors.extend(_schema_errors(child, properties[key], f"{pointer}/{key}"))
    if isinstance(value, list) and "items" in schema:
        for index, child in enumerate(value):
            errors.extend(_schema_errors(child, schema["items"], f"{pointer}/{index}"))
    if "oneOf" in schema:
        matches = sum(not _schema_errors(value, branch, pointer) for branch in schema["oneOf"])
        if matches != 1:
            errors.append(f"{pointer}: oneOf mismatch")
    return errors


def _project_context_valid(document, repo_root):
    schema_path = repo_root / "contracts/project-context.schema.json"
    try:
        with schema_path.open("r", encoding="utf-8") as handle:
            schema = json.load(handle)
    except (OSError, json.JSONDecodeError):
        return False
    return not _schema_errors(document, schema)


def _write_evidence(repo_root, feature, diagnostic_id, detail, state_marker, capability_evaluations=None):
    # AC-024 stable-sort discipline: capability_evaluations[] is sorted by
    # capability_id in the written record, even though steps 7-8 evaluate
    # capabilities in Registry-declaration order (the evaluation order
    # itself is never re-sorted, only this feature's own output array).
    sorted_evaluations = sorted(capability_evaluations or [], key=lambda entry: entry["capability_id"])
    evidence = {
        "schema": EVIDENCE_SCHEMA,
        "feature": feature,
        "capability_evaluations": sorted_evaluations,
        "diagnostics": [{"id": diagnostic_id, "detail": detail, "severity": "block"}],
    }
    if state_marker is not None:
        evidence["state"] = state_marker
    target = repo_root / "specs" / feature / "resolver-evidence.yaml"
    target.parent.mkdir(parents=True, exist_ok=True)
    payload = (json.dumps(evidence, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
    fd, temp_name = tempfile.mkstemp(prefix=".resolver-evidence-", dir=str(target.parent))
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_name, target)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)


def _block(repo_root, feature, diagnostic_id, detail, state_marker, capability_evaluations=None):
    _write_evidence(repo_root, feature, diagnostic_id, detail, state_marker, capability_evaluations)
    sys.stderr.write(f"capability-resolver: {diagnostic_id}: {detail}\n")
    return EXIT_BLOCK


def _projection(document, source_sha256):
    components = {}
    for component in document.get("components", []):
        components[component["id"]] = {key: value for key, value in component.items() if key != "id"}
    return {
        "schema": "sdd-context-projection/v1",
        "source_sha256": source_sha256,
        "workflow": document["workflow"],
        "components": components,
        "shared_paths": document.get("shared_paths", []),
    }


def main(argv=None):
    args = _parse_args(argv)
    config_path = Path(args.config)
    absolute_config = config_path if config_path.is_absolute() else Path.cwd() / config_path
    repo_root = _find_repo_root(absolute_config)

    if not absolute_config.is_file():
        return _block(repo_root, args.feature, "disabled-legacy-invocation", args.config, "disabled-legacy")

    try:
        canonical_context, document = _canonicalize(absolute_config, "yaml")
    except CanonicalizerFailed:
        return _block(
            repo_root, args.feature, "canonicalizer-invocation-failed",
            "canonicalize-sdd-yaml failed while canonicalizing project context", None,
        )
    except CanonicalizerOutputMalformed:
        return _block(
            repo_root, args.feature, "dependency-output-malformed",
            "canonicalize-sdd-yaml returned malformed JSON while canonicalizing project context", None,
        )

    if not _project_context_valid(document, repo_root):
        return _block(
            repo_root, args.feature, "project-context-validation-failed",
            "project context does not conform to contracts/project-context.schema.json", None,
        )

    workflow = document["workflow"]
    state = workflow["capability_enforcement"]
    invalid = (
        workflow["spec_profile"] == "lite" and workflow["artifact_layout"] != "lite-three-file"
    ) or (
        workflow["spec_profile"] == "full" and workflow["artifact_layout"] == "lite-three-file"
    )
    if invalid:
        return _block(
            repo_root, args.feature, "workflow-combination-invalid",
            "workflow spec_profile/artifact_layout combination is invalid", state,
        )

    source_sha256 = "sha256:" + hashlib.sha256(canonical_context).hexdigest()
    projection = _projection(document, source_sha256)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", suffix=".json", delete=False, newline="\n") as handle:
        json.dump(projection, handle, ensure_ascii=False, separators=(",", ":"))
        projection_input = Path(handle.name)
    try:
        try:
            canonical_projection, parsed_projection = _canonicalize(projection_input, "json")
        except CanonicalizerFailed:
            return _block(
                repo_root, args.feature, "canonicalizer-invocation-failed",
                "canonicalize-sdd-yaml failed while canonicalizing context projection", state,
            )
        except CanonicalizerOutputMalformed:
            return _block(
                repo_root, args.feature, "dependency-output-malformed",
                "canonicalize-sdd-yaml returned malformed JSON while canonicalizing context projection", state,
            )
    finally:
        projection_input.unlink(missing_ok=True)

    # T-002's own steps 0-3 staged values, retained in memory only.
    _staged_context_snapshot = canonical_context
    _staged_projection = canonical_projection
    _projection_sha256 = "sha256:" + hashlib.sha256(canonical_projection).hexdigest()
    del _staged_context_snapshot, _staged_projection, _projection_sha256

    script_dir = Path(__file__).resolve().parent
    repo_relative_config = _repo_relative(absolute_config, repo_root)
    projection_components = parsed_projection.get("components", {})

    # Step 4: affected-component resolution (Epic A3).
    try:
        affected_components, ownership_digest = _run_resolve_component_paths(script_dir, args)
    except AffectedComponentResolutionFailed as exc:
        detail = (
            f"resolve-component-paths exited {exc.returncode} resolving "
            f"{repo_relative_config}; see resolve-component-paths diagnostics"
        )
        return _block(repo_root, args.feature, "affected-component-resolution-failed", detail, state)
    except DependencyOutputMalformed:
        detail = "resolve-component-paths returned malformed JSON while resolving affected components"
        return _block(repo_root, args.feature, "dependency-output-malformed", detail, state)

    # Step 5: Registry discovery (ADR-0025) + validate-capability-registry.
    try:
        registry_path, registry_document = _discover_registry(script_dir)
    except ContractDiscoveryFailed:
        detail = "registry discovery failed to locate or verify capability-registry.json or capability-registry.schema.json"
        return _block(repo_root, args.feature, "contract-discovery-failed", detail, state)
    try:
        _validate_capability_registry(script_dir, registry_path)
    except RegistryValidationFailed:
        detail = "capability-registry.json failed validate-capability-registry checks"
        return _block(repo_root, args.feature, "registry-validation-failed", detail, state)

    # Step 6: registry_digest.
    try:
        registry_digest = _generate_registry_digest_whole(script_dir)
    except CanonicalizerFailed:
        detail = "canonicalize-sdd-yaml failed while computing registry_digest"
        return _block(repo_root, args.feature, "canonicalizer-invocation-failed", detail, state)
    except DependencySubprocessFailed:
        detail = "generate-registry-digest failed while computing registry_digest"
        return _block(repo_root, args.feature, "dependency-subprocess-failed", detail, state)
    except DependencyOutputMalformed:
        detail = "generate-registry-digest returned malformed output while computing registry_digest"
        return _block(repo_root, args.feature, "dependency-output-malformed", detail, state)

    # Steps 7-8: per-Capability/per-component trigger evaluation and
    # matched-Capability conditional-facet evaluation.
    capability_evaluations = []
    try:
        any_warn = _evaluate_capabilities(
            script_dir, registry_document, affected_components, projection_components, capability_evaluations,
        )
    except RegistryValidationFailed:
        detail = "a Registry-declared predicate failed predicate-schema validation"
        return _block(repo_root, args.feature, "registry-validation-failed", detail, state, capability_evaluations)
    except DependencySubprocessFailed:
        detail = "evaluate-predicate failed while evaluating a predicate"
        return _block(repo_root, args.feature, "dependency-subprocess-failed", detail, state, capability_evaluations)
    except DependencyOutputMalformed:
        detail = "evaluate-predicate returned malformed JSON while evaluating a predicate"
        return _block(repo_root, args.feature, "dependency-output-malformed", detail, state, capability_evaluations)

    # Step 9: any-branch WARN check (B2, widened scope).
    if any_warn:
        detail = "a predicate evaluation produced an outcome: warn evidence node"
        return _block(repo_root, args.feature, "dsl-warn-on-matched-capability", detail, state, capability_evaluations)

    # T-003 owns staging only through step 9. These values are deliberately
    # retained in memory for T-004's own steps 10-13 (track branch, Resolver
    # Evidence assembly, output schema self-validation, pre-publication
    # recheck) and never written live here.
    _staged_capability_evaluations = capability_evaluations
    _staged_registry_digest = registry_digest
    _staged_ownership_digest = ownership_digest
    _staged_affected_components = affected_components
    del _staged_capability_evaluations, _staged_registry_digest, _staged_ownership_digest, _staged_affected_components
    return 0


if __name__ == "__main__":
    sys.exit(main())
