#!/usr/bin/env python3
"""Capability Resolver, implementation stages T-002+T-003+T-004 (steps 0-13).

T-002 validates CLI input, derives Resolver state, obtains a single canonical
Project Context snapshot, and assembles/canonicalizes the Context Projection
in memory (steps 0-3). T-003 extends the same Python master with
affected-component resolution (`resolve-component-paths`), Registry
discovery + validation (ADR-0025 discovery + `validate-capability-registry`),
`registry_digest` (`generate-registry-digest --whole`), per-Capability/
per-affected-component trigger evaluation, matched-Capability
conditional-facet evaluation (both via `evaluate-predicate`), and the
any-branch WARN check (steps 4-9). T-004 completes the staged-only pipeline:
the track branch (Facet Manifest on `full`, Capability Summary on `lite`,
never both -- B4), Resolver Evidence assembly (context_binding/resolver
provenance canonicalization, B9), output schema self-validation against
every staged artifact's own governing schema (B3), and the pre-publication
snapshot recheck (B8 TOCTOU) (steps 10-13). Every step 0-13 result is staged
in memory only -- a clean resolve (exit 0) writes nothing to any live path;
T-007 layers the crash-recovery scan and the journaled publication
transaction (step 14) onto this same script, the sole component with any
live-filesystem write of its own.
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

# T-004 (steps 10-13): resolver.version/resolver.rule_set_revision
# single-source-of-truth + canonical-preimage rules (Data Plan "B9", no
# upstream rule fixed either). RESOLVER_VERSION is this feature's own
# single source of truth -- the .sh/.ps1 dispatchers never read, duplicate,
# or independently derive it, so .py/.sh/.ps1 parity (REQ-005/AC-023) is
# structural. Mutated only via scripts/bump-version.sh (REQ-008/AC-034),
# matching Epic A3's own identical `resolve-component-paths.py:
# RESOLVER_VERSION` precedent. RULE_SET_REVISION is the sha256 of a fixed,
# versioned canonical string identifying *which revision of this feature's
# own orchestration rule set* (union-match, WARN-Block scope, facet-name
# aggregation, the REQ-002 Block taxonomy) produced a given Resolver
# Evidence instance -- never a hash of any input file, so it is identical
# across every invocation of the same Resolver revision.
RESOLVER_VERSION = "1.0.0"
RULE_SET_STRING = "sdd-resolver-rule-set/v1"
RULE_SET_REVISION = "sha256:" + hashlib.sha256(RULE_SET_STRING.encode("utf-8")).hexdigest()

# T-004 step 12's own governing-schema filenames (ADR-0025 discovery,
# `_discover_governing_schema` below).
FACET_MANIFEST_SCHEMA_FILENAME = "facet-manifest.schema.json"
CAPABILITY_SUMMARY_SCHEMA_FILENAME = "capability-summary.schema.json"
CONTEXT_PROJECTION_SCHEMA_FILENAME = "context-projection.schema.json"
RESOLVER_EVIDENCE_SCHEMA_FILENAME = "resolver-evidence.schema.json"


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


class LiteCheckSourceUndefined(Exception):
    """Step 10b's own Block condition (B5-narrowed): `spec_profile ==
    lite`, `capability_enforcement == required`, and at least one matched
    Capability's own `lite_policy.required_lite_checks` key is absent.
    Carries that Capability's own id for the diagnostic detail."""


class OutputSchemaValidationFailed(Exception):
    """Step 12 (B3): a staged artifact failed its own defensive output
    schema self-validation. `artifact_name` is one of "resolver-evidence"
    (the sole case where nothing is written to any live path at all),
    "context-projection", "facet-manifest", or "capability-summary"."""

    def __init__(self, artifact_name):
        super().__init__(artifact_name)
        self.artifact_name = artifact_name


class SnapshotGenerationMismatch(Exception):
    """Step 13 (B8 TOCTOU): the pre-publication recheck of the Project
    Context/Registry/ownership-source snapshot, including a fresh
    re-derivation of `affected_components` (not only `ownership_digest`),
    no longer matches this invocation's own step-2/4/5-6 snapshot."""


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
        # A launch failure (missing binary, unreadable/non-executable
        # wrapper) never produced an exit code at all, so it cannot be
        # formatted through AffectedComponentResolutionFailed's own
        # returncode-shaped canonical sentence (that constructor's sole
        # parameter is a returncode, not a string) -- doing so is exactly
        # the panelist-caught defect: the raw OSError text (an absolute
        # path, an errno) would otherwise land in the committed Resolver
        # Evidence, violating both AC-014's canonical-sentence rule and
        # security-spec.md B5's no-local-path containment. Instead, this
        # sub-case is folded into the SAME closed-enum, fixed-sentence
        # DependencySubprocessFailed path steps 5/6/7-8 already use for an
        # identical OSError on their own subprocess.run calls -- main()'s
        # own handler discards this exception's payload entirely.
        raise DependencySubprocessFailed(f"launch failed: {exc}") from exc
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
    try:
        import registry_discovery  # noqa: E402  (deliberately deferred: co-located sibling module)
    except ImportError as exc:
        raise ContractDiscoveryFailed(f"registry_discovery module not importable: {exc}") from exc

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
            or not all(isinstance(node, dict) for node in parsed.get("evidence", []))
        ):
            raise DependencyOutputMalformed("evaluate-predicate stdout is not the {result, evidence} shape")
        return parsed["result"], parsed["evidence"]
    finally:
        os.unlink(predicate_name)
        os.unlink(properties_name)


def _iter_warn_nodes(evidence_nodes, node_path=()):
    """Depth-first, declaration-order walk of an Evidence tree, yielding
    `(node, node_path)` for every `outcome: "warn"` node at any depth
    (step 9, B2's own any-branch, any-depth scope; AC-056). `node_path` is
    the 0-based child-index path from this tree's own root -- a stable,
    always-distinct positional identifier for a warn node even when two
    leaves happen to share an identical `field`/`operator`/`reason`."""
    for index, node in enumerate(evidence_nodes):
        this_path = node_path + (index,)
        if node.get("outcome") == "warn":
            yield node, this_path
        yield from _iter_warn_nodes(node.get("children") or [], this_path)


def _evidence_has_warn(evidence_nodes):
    """Depth-first scan for an `outcome: "warn"` node anywhere in an
    Evidence tree (step 9, B2's own any-branch, any-depth scope)."""
    for _ in _iter_warn_nodes(evidence_nodes):
        return True
    return False


def _warn_diagnostic_detail(capability_id, component_id, declaration_index, node_path, node):
    """AC-056: one `severity: "warn"` diagnostics[] entry's own `detail`
    per individual `outcome: "warn"` DSL-evaluation node, naming that
    node's own `capability_id`/`component_id`/`declaration_index`
    location plus its own tree position/DSL attributes -- guaranteeing a
    distinct `detail` per node even across two nodes sharing an identical
    location (AC-024 no-`(id, detail)`-repeat), and always distinct from
    the summary `severity: "block"` entry's own fixed sentence (below),
    which carries no location suffix at all."""
    location = (
        f"capability_id={capability_id!r} component_id={component_id!r} "
        f"declaration_index={declaration_index!r}"
    )
    node_position = ".".join(str(index) for index in node_path)
    return (
        f"a predicate evaluation produced an outcome: warn evidence node at {location} "
        f"(node_path={node_position!r}, operator={node.get('operator')!r}, "
        f"field={node.get('path')!r}, reason={node.get('reason')!r})"
    )


def _evaluate_capabilities(
    script_dir, registry_document, affected_components, projection_components,
    capability_evaluations, warn_diagnostics,
):
    """Steps 7-8. Every Registry Capability, matched or not, is evaluated in
    full against every affected component, in Registry-declaration order
    (capabilities) and ascending-lexicographic order (affected_components,
    explicitly sorted at this fan-out -- REQ-005/AC-024 determinism, never
    assumed pre-sorted from `resolve-component-paths`, whose own contract
    makes no ordering guarantee, investigation.md INV-006) -- no
    short-circuit on any individual evaluation's own outcome. `capability_
    evaluations` is mutated in place (appending one complete entry per
    Capability only after that Capability's own evaluation set is fully
    built) so a caller can still read every already-completed entry if a
    dependency subprocess failure aborts this function partway through.
    `warn_diagnostics` is likewise mutated in place, gaining one
    `severity: "warn"` diagnostics[] entry per individual `outcome: "warn"`
    DSL-evaluation node found anywhere in any evaluation's own Evidence
    tree, in this same declaration-order evaluation sequence (AC-056).
    Returns whether any evaluation's own Evidence tree contained an
    `outcome: "warn"` node anywhere (step 9's own condition)."""
    sorted_affected_components = sorted(affected_components)
    any_warn = False
    for capability in registry_document.get("capabilities", []):
        capability_id = capability["id"]
        trigger_evaluations = []
        matched = False
        for component_id in sorted_affected_components:
            properties = projection_components.get(component_id, {})
            result, evidence = _evaluate_predicate(script_dir, capability["trigger"], properties)
            for node, node_path in _iter_warn_nodes(evidence):
                any_warn = True
                warn_diagnostics.append({
                    "id": "dsl-warn-on-matched-capability",
                    "detail": _warn_diagnostic_detail(capability_id, component_id, None, node_path, node),
                    "severity": "warn",
                })
            trigger_evaluations.append({"component_id": component_id, "result": result, "evidence": evidence})
            if result:
                matched = True
        entry = {"capability_id": capability_id, "matched": matched, "trigger_evaluations": trigger_evaluations}
        if matched:
            conditional_facet_evaluations = []
            for declaration_index, facet_declaration in enumerate(capability.get("conditional_facets", [])):
                evaluations = []
                applied = False
                for component_id in sorted_affected_components:
                    properties = projection_components.get(component_id, {})
                    result, evidence = _evaluate_predicate(script_dir, facet_declaration["when"], properties)
                    for node, node_path in _iter_warn_nodes(evidence):
                        any_warn = True
                        warn_diagnostics.append({
                            "id": "dsl-warn-on-matched-capability",
                            "detail": _warn_diagnostic_detail(
                                capability_id, component_id, declaration_index, node_path, node,
                            ),
                            "severity": "warn",
                        })
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


def _write_evidence(
    repo_root, feature, diagnostic_id, detail, state_marker,
    capability_evaluations=None, warn_diagnostics=None,
):
    # AC-024 stable-sort discipline: capability_evaluations[] is sorted by
    # capability_id in the written record, even though steps 7-8 evaluate
    # capabilities in Registry-declaration order (the evaluation order
    # itself is never re-sorted, only this feature's own output array).
    sorted_evaluations = sorted(capability_evaluations or [], key=lambda entry: entry["capability_id"])
    # AC-056: every already-collected `severity: "warn"` diagnostics[]
    # entry (one per individual `outcome: "warn"` DSL-evaluation node,
    # already in declaration-evaluation order -- see `_evaluate_
    # capabilities`) is written first, followed by exactly one summary
    # `severity: "block"` entry sharing the identical `diagnostic_id`.
    # Every other diagnostic path passes no `warn_diagnostics`, leaving
    # this unchanged from its own prior single-entry shape.
    diagnostics = list(warn_diagnostics or []) + [{"id": diagnostic_id, "detail": detail, "severity": "block"}]
    evidence = {
        "schema": EVIDENCE_SCHEMA,
        "feature": feature,
        "capability_evaluations": sorted_evaluations,
        "diagnostics": diagnostics,
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


def _block(
    repo_root, feature, diagnostic_id, detail, state_marker,
    capability_evaluations=None, warn_diagnostics=None,
):
    _write_evidence(
        repo_root, feature, diagnostic_id, detail, state_marker,
        capability_evaluations, warn_diagnostics,
    )
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


# ---------------------------------------------------------------------------
# T-004 (steps 10-13): track branch, Resolver Evidence assembly, output
# schema self-validation, pre-publication snapshot recheck.
# ---------------------------------------------------------------------------


def _rfc6901_escape(token):
    return token.replace("~", "~0").replace("/", "~1")


def _dependency_pointers(affected_components):
    """B9 (Data Plan, no upstream rule fixed this): exactly `/workflow`
    plus one RFC-6901-escaped `/components/<id>` pointer per affected
    component (never every component the Project Context declares), the
    resulting set stable-sorted and de-duplicated. `/shared_paths` is
    never included (Data Plan, "dependency_pointers[] -- canonical
    derivation rule")."""
    pointers = {"/workflow"}
    for component_id in affected_components:
        pointers.add("/components/" + _rfc6901_escape(component_id))
    return sorted(pointers)


def _required_facets(registry_document, matched_capability_ids):
    capabilities_by_id = {c["id"]: c for c in registry_document.get("capabilities", [])}
    facets = set()
    for capability_id in matched_capability_ids:
        facets.update(capabilities_by_id.get(capability_id, {}).get("required_facets", []))
    return sorted(facets)


def _resolved_gates(registry_document, matched_capability_ids):
    """Every matched Capability's own `gate_ids[]`, resolved via a
    Resolver-side join against the discovered Registry's own `gates[]`, at
    any `stage` value -- this feature does not filter to
    `stage: implementation` only (Design Decisions, "resolved_gates[]
    includes ... at any stage value")."""
    capabilities_by_id = {c["id"]: c for c in registry_document.get("capabilities", [])}
    gates_by_id = {g["id"]: g for g in registry_document.get("gates", [])}
    seen = set()
    resolved = []
    for capability_id in matched_capability_ids:
        for gate_id in capabilities_by_id.get(capability_id, {}).get("gate_ids", []):
            if gate_id in seen or gate_id not in gates_by_id:
                continue
            seen.add(gate_id)
            gate = gates_by_id[gate_id]
            resolved.append({"id": gate_id, "stage": gate["stage"], "blocking": gate["blocking"]})
    resolved.sort(key=lambda entry: entry["id"])
    return resolved


def _capability_minimum_enforcement(registry_document, matched_capability_ids):
    """The `max()` (logical OR, since `"required"` is the schema's own
    only non-absent value) of every matched Capability's own
    `minimum_enforcement` -- the key is omitted entirely (never a false-ish
    placeholder) when no matched Capability names it, matching the
    Facet Manifest schema's own optional, `const: "required"`-only field."""
    capabilities_by_id = {c["id"]: c for c in registry_document.get("capabilities", [])}
    for capability_id in matched_capability_ids:
        if capabilities_by_id.get(capability_id, {}).get("minimum_enforcement") == "required":
            return "required"
    return None


def _lite_eligibility(registry_document, matched_capability_ids):
    """The aggregate `{eligible, upgrade_reasons}` signal both 10a's own
    Facet Manifest field and 10b's own `full_upgrade_required` derive
    from: `eligible` is the AND of every matched Capability's own
    `lite_policy.eligible` (a single non-lite-eligible matched Capability
    forces the aggregate non-eligible, the identical union/soundness
    argument this feature's own Design Decisions already apply to
    `trigger`/`when` matching, one level higher); `upgrade_reasons` is the
    stable-sorted, de-duplicated union of every matched Capability's own
    `lite_policy.upgrade_reasons`. Zero matched Capabilities is vacuously
    `{eligible: true, upgrade_reasons: []}` (Edge Cases, "zero affected
    components" -- the identical vacuous shape applies here since an empty
    AND is true and an empty union is `[]`)."""
    capabilities_by_id = {c["id"]: c for c in registry_document.get("capabilities", [])}
    eligible = True
    reasons = set()
    for capability_id in matched_capability_ids:
        policy = capabilities_by_id.get(capability_id, {}).get("lite_policy") or {}
        if not policy.get("eligible", True):
            eligible = False
        reasons.update(policy.get("upgrade_reasons", []))
    return {"eligible": eligible, "upgrade_reasons": sorted(reasons)}


def _aggregate_conditional_facets(capability_evaluations):
    """Step 10a's own cross-Capability facet-name aggregation (Design
    Decisions "facet-name aggregation, predicate-instance keyed", B7).
    Aggregates, per distinct `facet` name, across every predicate instance
    `(capability_id, declaration_index)` -- Registry-wide, across every
    matched Capability -- whose own `conditional_facets[declaration_index].
    facet` equals that name: `applied` is the OR of every contributing
    instance's own `applied` (step 8's own per-instance union-match
    result); `evidence` is the concatenation of every contributing
    `(capability_id, declaration_index, component_id)` triple's own
    evaluation-node array, ordered `capability_id`-then-`declaration_
    index`-then-`component_id` ascending; `reason` (present iff
    `applied: false`) names every contributing predicate instance in the
    identical ascending order."""
    contributions = {}
    for entry in capability_evaluations:
        if not entry.get("matched"):
            continue
        for cfe in entry.get("conditional_facet_evaluations", []):
            contributions.setdefault(cfe["facet"], []).append(
                (entry["capability_id"], cfe["declaration_index"], cfe["applied"], cfe["evaluations"])
            )

    result = []
    for facet in sorted(contributions):
        instances = sorted(contributions[facet], key=lambda instance: (instance[0], instance[1]))
        applied = any(instance[2] for instance in instances)
        evidence = []
        for _capability_id, _declaration_index, _applied, evaluations in instances:
            for evaluation in sorted(evaluations, key=lambda e: e["component_id"]):
                evidence.extend(evaluation["evidence"])
        node = {"facet": facet, "applied": applied, "evidence": evidence}
        if not applied:
            names = ", ".join(f"{cid}[{idx}]" for cid, idx, _a, _e in instances)
            node["reason"] = (
                "no contributing predicate instance's conditional facet matched "
                f"any affected component (contributing: {names})"
            )
        result.append(node)
    return result


def _assemble_facet_manifest(feature, affected_components, registry_document, capability_evaluations, context_binding, resolver_block):
    """Step 10a: Full-track Facet Manifest assembly (staged only)."""
    matched_ids = sorted(entry["capability_id"] for entry in capability_evaluations if entry["matched"])
    manifest = {
        "schema": "sdd-facet-manifest/v1",
        "feature": feature,
        "affected_components": sorted(set(affected_components)),
        "required_facets": _required_facets(registry_document, matched_ids),
        "conditional_facets": _aggregate_conditional_facets(capability_evaluations),
        "resolved_gates": _resolved_gates(registry_document, matched_ids),
        "capabilities": matched_ids,
        "lite_eligibility": _lite_eligibility(registry_document, matched_ids),
        "context_binding": context_binding,
        "resolver": resolver_block,
    }
    enforcement = _capability_minimum_enforcement(registry_document, matched_ids)
    if enforcement is not None:
        manifest["capability_minimum_enforcement"] = enforcement
    return manifest


def _assemble_capability_summary(feature, registry_document, capability_evaluations, state):
    """Step 10b: Lite-track Capability Summary assembly (staged only).
    Raises LiteCheckSourceUndefined (B5-narrowed) iff `state == "required"`
    and at least one matched Capability's own `lite_policy.
    required_lite_checks` key is absent; under `advisory`, an absent key
    contributes an empty `[]` instead."""
    capabilities_by_id = {c["id"]: c for c in registry_document.get("capabilities", [])}
    matched_ids = sorted(entry["capability_id"] for entry in capability_evaluations if entry["matched"])
    required_lite_checks = set()
    for capability_id in matched_ids:
        lite_policy = capabilities_by_id.get(capability_id, {}).get("lite_policy") or {}
        if "required_lite_checks" in lite_policy:
            required_lite_checks.update(lite_policy["required_lite_checks"])
        elif state == "required":
            raise LiteCheckSourceUndefined(capability_id)
        # else: advisory (or a non-required state) -- absent contributes [].
    lite_eligibility = _lite_eligibility(registry_document, matched_ids)
    return {
        "schema": "sdd-capability-summary/v1",
        "feature": feature,
        "track": "lite",
        "capabilities": matched_ids,
        "required_lite_checks": sorted(required_lite_checks),
        "full_upgrade_required": not lite_eligibility["eligible"],
    }


def _assemble_context_binding(source_sha256, affected_components, projection_sha256, registry_digest, ownership_digest):
    return {
        "full_context_revision": source_sha256,
        "dependency_pointers": _dependency_pointers(affected_components),
        "projection_sha256": projection_sha256,
        "registry_digest": registry_digest,
        "ownership_digest": ownership_digest,
    }


def _resolver_block():
    return {"version": RESOLVER_VERSION, "rule_set_revision": RULE_SET_REVISION}


def _assemble_resolver_evidence(feature, state, capability_evaluations, context_binding, resolver_block):
    """Step 11: Resolver Evidence assembly (staged only) for a clean
    resolve -- `diagnostics: []` (no Block condition fired through step
    10), every `capability_evaluations[]` entry from steps 7-8 in full."""
    return {
        "schema": EVIDENCE_SCHEMA,
        "feature": feature,
        "state": state,
        "context_binding": context_binding,
        "resolver": resolver_block,
        "capability_evaluations": sorted(capability_evaluations, key=lambda entry: entry["capability_id"]),
        "diagnostics": [],
    }


# --- Step 12: output schema self-validation (B3) --------------------------
#
# A hand-rolled, stdlib-only draft-07 subset engine -- reimplemented locally
# rather than imported, mirroring Epic A4's own `validate-facet-manifest.py`
# engine closely enough to validate against the identical governing schema
# documents ($ref, if/then/else, oneOf, propertyNames, pattern, uniqueItems,
# minItems). Resolver Evidence's own self-check has no external validator
# script to shell out to at all -- `validate-resolver-evidence` is T-008's
# own, not-yet-built deliverable -- so this feature's own step 12 validates
# every governing schema (Facet Manifest/Capability Summary/Context
# Projection/Resolver Evidence) the identical, uniform, in-process way.


def _draft7_type_matches(value, type_spec):
    if isinstance(type_spec, list):
        return any(_draft7_type_matches(value, entry) for entry in type_spec)
    if type_spec == "object":
        return isinstance(value, dict)
    if type_spec == "array":
        return isinstance(value, list)
    if type_spec == "string":
        return isinstance(value, str)
    if type_spec == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if type_spec == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if type_spec == "boolean":
        return isinstance(value, bool)
    if type_spec == "null":
        return value is None
    return False


def _draft7_resolve_ref(ref, root_schema):
    if not ref.startswith("#/"):
        raise ValueError(f"unsupported $ref (not a same-document fragment): {ref}")
    node = root_schema
    for part in ref[2:].split("/"):
        node = node[part.replace("~1", "/").replace("~0", "~")]
    return node


def _draft7_matches(instance, schema, root_schema):
    probe = []
    _draft7_validate(instance, schema, root_schema, "", probe)
    return not probe


def _draft7_validate(instance, schema, root_schema, pointer, diags):
    if schema is True:
        return
    if schema is False:
        diags.append(pointer)
        return
    if "$ref" in schema:
        _draft7_validate(instance, _draft7_resolve_ref(schema["$ref"], root_schema), root_schema, pointer, diags)
        return
    if "const" in schema and instance != schema["const"]:
        diags.append(pointer)
        return
    if "enum" in schema and instance not in schema["enum"]:
        diags.append(pointer)
        return
    if "type" in schema and not _draft7_type_matches(instance, schema["type"]):
        diags.append(pointer)
        return
    if "oneOf" in schema:
        matches = sum(1 for branch in schema["oneOf"] if _draft7_matches(instance, branch, root_schema))
        if matches != 1:
            diags.append(pointer)
    if "if" in schema:
        if _draft7_matches(instance, schema["if"], root_schema):
            if "then" in schema:
                _draft7_validate(instance, schema["then"], root_schema, pointer, diags)
        elif "else" in schema:
            _draft7_validate(instance, schema["else"], root_schema, pointer, diags)
    if isinstance(instance, str):
        if "pattern" in schema and not re.search(schema["pattern"], instance):
            diags.append(pointer)
        if "minLength" in schema and len(instance) < schema["minLength"]:
            diags.append(pointer)
    if isinstance(instance, dict):
        for required_key in schema.get("required", []):
            if required_key not in instance:
                diags.append(f"{pointer}/{required_key}")
        properties = schema.get("properties", {})
        for key, value in instance.items():
            if key in properties:
                _draft7_validate(value, properties[key], root_schema, f"{pointer}/{key}", diags)
        if "propertyNames" in schema:
            for key in instance:
                _draft7_validate(key, schema["propertyNames"], root_schema, f"{pointer}/{key}", diags)
        additional = schema.get("additionalProperties", True)
        if additional is not True:
            extra_keys = [key for key in instance if key not in properties]
            if additional is False:
                for key in extra_keys:
                    diags.append(f"{pointer}/{key}")
            else:
                for key in extra_keys:
                    _draft7_validate(instance[key], additional, root_schema, f"{pointer}/{key}", diags)
    if isinstance(instance, list):
        if "items" in schema:
            items_schema = schema["items"]
            for index, element in enumerate(instance):
                _draft7_validate(element, items_schema, root_schema, f"{pointer}/{index}", diags)
        if schema.get("uniqueItems"):
            seen = []
            for index, element in enumerate(instance):
                canonical = json.dumps(element, sort_keys=True)
                if canonical in seen:
                    diags.append(f"{pointer}/{index}")
                else:
                    seen.append(canonical)
        if "minItems" in schema and len(instance) < schema["minItems"]:
            diags.append(pointer)


def _draft7_conforms(document, schema):
    diags = []
    _draft7_validate(document, schema, schema, "", diags)
    return not diags


def _discover_governing_schema(script_dir, repo_root, filename):
    """Step 12's own ADR-0025-style discovery for a governing output
    schema: the packaged, script-relative `contracts/` copy first, then
    the git-root `contracts/` fallback -- the identical two-step order
    `registry_discovery.discover_artifact` already uses for the Registry
    (step 5), reimplemented locally here rather than reused, since that
    shared module's own `VERSION_CHECKS` table is closed to Epic A2's own
    three registry-family filenames and this feature's own Global
    Constraints forbid editing any file under `plugins/**`, including
    `registry_discovery.py` itself. A resolution failure maps to the
    identical `contract-discovery-failed` diagnostic REQ-002 already names
    for "any of Epic A4's three schemas" failing this same procedure."""
    packaged = script_dir.parent / "contracts" / filename
    if packaged.is_file():
        return packaged
    git_path = repo_root / "contracts" / filename
    if git_path.is_file():
        return git_path
    raise ContractDiscoveryFailed(f"{filename} not found at the packaged or git-root contracts/ location")


def _load_governing_schema(script_dir, repo_root, filename):
    path = _discover_governing_schema(script_dir, repo_root, filename)
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        raise ContractDiscoveryFailed(f"{filename} could not be read/parsed: {exc}")


def _self_validate_output(script_dir, repo_root, evidence, context_projection, track_artifact, track_artifact_schema_filename, track_artifact_name):
    """Step 12 (B3). Resolver Evidence (already staged, step 11) is
    re-validated FIRST -- if it is itself the artifact that fails, the
    caller must write NOTHING to any live path, not even a best-effort,
    fields-omitted Evidence instance (the sole exception to REQ-002's
    "Evidence always emitted" rule). Context Projection (staged at step 3
    on every invocation, regardless of track) is checked next, then the
    track-exclusive artifact (Facet Manifest on `full`, Capability Summary
    on `lite`) last -- if either check after Evidence's own fails,
    Resolver Evidence itself (already independently schema-valid) is still
    written normally as this Block's own record."""
    evidence_schema = _load_governing_schema(script_dir, repo_root, RESOLVER_EVIDENCE_SCHEMA_FILENAME)
    if not _draft7_conforms(evidence, evidence_schema):
        raise OutputSchemaValidationFailed("resolver-evidence")

    projection_schema = _load_governing_schema(script_dir, repo_root, CONTEXT_PROJECTION_SCHEMA_FILENAME)
    if not _draft7_conforms(context_projection, projection_schema):
        raise OutputSchemaValidationFailed("context-projection")

    track_schema = _load_governing_schema(script_dir, repo_root, track_artifact_schema_filename)
    if not _draft7_conforms(track_artifact, track_schema):
        raise OutputSchemaValidationFailed(track_artifact_name)


def _pre_publication_recheck(script_dir, args, absolute_config, source_sha256, affected_components, ownership_digest, registry_digest):
    """Step 13 (B8 TOCTOU, Data Plan gives the digest-derivation
    mechanism). Re-reads the Project Context, re-invokes `resolve-
    component-paths` for a FRESH `ownership_digest` and a FRESH
    `affected_components` set (B8 correction -- `ownership_digest` alone
    cannot detect a diff-only generation change), and re-derives
    `registry_digest`; any digest mismatch, or any `affected_components`
    set difference (even with every digest, including `ownership_digest`,
    still matching), raises SnapshotGenerationMismatch. This function
    performs no live write of any kind -- the values it recomputes are
    used only for this comparison; a passing recheck changes nothing this
    invocation has already computed."""
    try:
        fresh_canonical, _fresh_document = _canonicalize(absolute_config, "yaml")
    except (CanonicalizerFailed, CanonicalizerOutputMalformed):
        raise SnapshotGenerationMismatch("project context recheck canonicalization failed")
    fresh_source_sha256 = "sha256:" + hashlib.sha256(fresh_canonical).hexdigest()

    try:
        fresh_affected_components, fresh_ownership_digest = _run_resolve_component_paths(script_dir, args)
    except (AffectedComponentResolutionFailed, DependencySubprocessFailed, DependencyOutputMalformed):
        raise SnapshotGenerationMismatch("affected-component recheck failed")

    try:
        fresh_registry_digest = _generate_registry_digest_whole(script_dir)
    except (CanonicalizerFailed, DependencySubprocessFailed, DependencyOutputMalformed):
        raise SnapshotGenerationMismatch("registry_digest recheck failed")

    if (
        fresh_source_sha256 != source_sha256
        or fresh_ownership_digest != ownership_digest
        or fresh_registry_digest != registry_digest
        or set(fresh_affected_components) != set(affected_components)
    ):
        raise SnapshotGenerationMismatch("snapshot recheck detected drift")


def _block_no_write(diagnostic_id, detail):
    """Step 12's own sole exception (B3): Resolver Evidence itself failed
    its own schema self-validation, so this invocation writes NOTHING to
    any live path at all, not even a best-effort record."""
    sys.stderr.write(f"capability-resolver: {diagnostic_id}: {detail}\n")
    return EXIT_BLOCK


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

    # T-002's own steps 0-3 staged values, retained in memory for T-004's
    # own step 11 (context_binding.projection_sha256, below); the raw
    # canonicalized bytes themselves are not needed past this point.
    projection_sha256 = "sha256:" + hashlib.sha256(canonical_projection).hexdigest()
    del canonical_context, canonical_projection

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
    except DependencySubprocessFailed:
        detail = "resolve-component-paths failed to launch while resolving affected components"
        return _block(repo_root, args.feature, "dependency-subprocess-failed", detail, state)
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
    warn_diagnostics = []
    try:
        any_warn = _evaluate_capabilities(
            script_dir, registry_document, affected_components, projection_components,
            capability_evaluations, warn_diagnostics,
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

    # Step 9: any-branch WARN check (B2, widened scope). AC-056:
    # `warn_diagnostics` already carries one `severity: "warn"` entry per
    # individual `outcome: "warn"` DSL-evaluation node `_evaluate_
    # capabilities` found above; `_block` prepends them before this one
    # summary `severity: "block"` entry, which shares the identical id.
    if any_warn:
        detail = "a predicate evaluation produced an outcome: warn evidence node"
        return _block(
            repo_root, args.feature, "dsl-warn-on-matched-capability", detail, state,
            capability_evaluations, warn_diagnostics,
        )

    # Step 10: track branch, decided here, before any publication (B4).
    context_binding = _assemble_context_binding(
        source_sha256, affected_components, projection_sha256, registry_digest, ownership_digest,
    )
    resolver_block = _resolver_block()

    if workflow["spec_profile"] == "full":
        # 10a: Full track -- Facet Manifest assembly. No Capability Summary
        # is staged on this track (B4).
        track_artifact = _assemble_facet_manifest(
            args.feature, affected_components, registry_document, capability_evaluations,
            context_binding, resolver_block,
        )
        track_artifact_schema_filename = FACET_MANIFEST_SCHEMA_FILENAME
        track_artifact_name = "facet-manifest"
    else:
        # 10b: Lite track -- Capability Summary assembly only. No Facet
        # Manifest and no published Context Projection on this track (B4).
        try:
            track_artifact = _assemble_capability_summary(
                args.feature, registry_document, capability_evaluations, state,
            )
        except LiteCheckSourceUndefined as exc:
            capability_id = exc.args[0]
            detail = (
                f"matched Capability {capability_id!r} has no lite_policy.required_lite_checks "
                "source while capability_enforcement is required"
            )
            return _block(repo_root, args.feature, "lite-check-source-undefined", detail, state, capability_evaluations)
        track_artifact_schema_filename = CAPABILITY_SUMMARY_SCHEMA_FILENAME
        track_artifact_name = "capability-summary"

    # Step 11: Resolver Evidence assembly (staged only).
    evidence = _assemble_resolver_evidence(args.feature, state, capability_evaluations, context_binding, resolver_block)

    # Step 12: output schema self-validation (B3).
    try:
        _self_validate_output(
            script_dir, repo_root, evidence, parsed_projection,
            track_artifact, track_artifact_schema_filename, track_artifact_name,
        )
    except ContractDiscoveryFailed as exc:
        detail = f"governing output schema discovery failed: {exc}"
        return _block(repo_root, args.feature, "contract-discovery-failed", detail, state, capability_evaluations)
    except OutputSchemaValidationFailed as exc:
        if exc.artifact_name == "resolver-evidence":
            detail = "resolver-evidence.yaml failed its own defensive output schema self-validation"
            return _block_no_write("output-schema-validation-failed", detail)
        detail = f"the staged {exc.artifact_name} artifact failed its own defensive output schema self-validation"
        return _block(repo_root, args.feature, "output-schema-validation-failed", detail, state, capability_evaluations)

    # Step 13: pre-publication snapshot recheck (B8 TOCTOU).
    try:
        _pre_publication_recheck(
            script_dir, args, absolute_config, source_sha256, affected_components, ownership_digest, registry_digest,
        )
    except SnapshotGenerationMismatch:
        detail = (
            "a pre-publication recheck of the Project Context, Registry, or "
            "ownership-source snapshot detected drift since this invocation's own snapshot"
        )
        return _block(repo_root, args.feature, "snapshot-generation-mismatch", detail, state, capability_evaluations)

    # T-004 owns staging only through step 13 -- step 14's own journaled
    # publication transaction (T-007's own scope) is the sole component
    # with any live-filesystem write of its own. A clean resolve here
    # writes nothing to any live path.
    del track_artifact, evidence
    return 0


if __name__ == "__main__":
    sys.exit(main())
