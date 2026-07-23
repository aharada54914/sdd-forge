#!/usr/bin/env python3
"""REQ-001/REQ-006: Facet Manifest schema + semantic validator.

Usage:
    validate-facet-manifest.py --manifest <path>

<path> ending in .yaml/.yml is loaded through the YAML parse contract: a
`canonicalize-sdd-yaml` subprocess invocation (canonical-JSON stdout) is the
sole path from YAML bytes to a Python structure -- never a hand-rolled YAML
parser and never a silent fallback. A non-zero canonicalizer exit surfaces as
this validator's own `canonicalizer-invocation-failed` diagnostic.

<path> ending in .json is loaded directly via stdlib `json.load` -- this is
NOT a YAML parsing path of any kind; it exists because the schema-conformance
and semantic checks below operate on an already-parsed Python structure
(`validate_document`) and are exercised by the regression suite against
already-canonical JSON fixtures, independent of whichever tool eventually
turns a `facet-manifest.yaml` into that structure (design.md YAML parse
contract; External Checkout Constraints, tasks.md -- this worktree does not
contain Epic A1's canonicalizer, so end-to-end `.yaml` round-trip fixtures
are a Done-gating condition tracked separately from schema/semantic
coverage).

This module implements a hand-rolled, stdlib-only subset of JSON Schema
draft-07 (INV-014: no third-party `jsonschema` dependency), matching
`validate-capability-registry.py`'s own hand-rolled-validator convention.
Implemented keywords: type (incl. array-form/union types), required,
additionalProperties (bool or schema), properties, propertyNames, pattern,
enum, const, uniqueItems, minItems, minLength, if/then/else, not, oneOf,
boolean subschema values, items, $ref/definitions (same-document fragments
only). `$schema`/`$id`/`title` are annotation keywords, not constraint
keywords, and are not implemented here (Discovery contract checks
`$schema`/`$id` separately).
"""
import argparse
import json
import os
import re
import subprocess
import sys
from collections import namedtuple

Diagnostic = namedtuple("Diagnostic", ["check_id", "pointer", "message"])

SCHEMA_FILENAME = "facet-manifest.schema.json"


class CanonicalizerError(Exception):
    """Raised when the YAML parse contract's subprocess step fails."""


# --------------------------------------------------------------------------
# Discovery contract (REQ-006, all four scripts; identical to Epic A2's own
# REQ-005 discovery contract, design.md "Discovery contract").
# --------------------------------------------------------------------------

def discover_schema_path():
    """Resolve contracts/facet-manifest.schema.json.

    (1) packaged copy at the script-relative offset ../contracts/<filename>;
    (2) else via the git root's contracts/<filename>;
    (3) fail closed naming both attempted paths.
    """
    script_real = os.path.realpath(os.path.abspath(__file__))
    script_dir = os.path.dirname(script_real)
    packaged = os.path.normpath(
        os.path.join(script_dir, "..", "contracts", SCHEMA_FILENAME)
    )
    if os.path.isfile(packaged):
        return packaged

    git_root = _find_git_root(script_dir)
    git_root_path = None
    if git_root is not None:
        git_root_path = os.path.join(git_root, "contracts", SCHEMA_FILENAME)
        if os.path.isfile(git_root_path):
            return git_root_path

    attempted = [packaged, git_root_path or "<git root unresolved>/contracts/" + SCHEMA_FILENAME]
    raise FileNotFoundError(
        "facet-manifest: schema-discovery-failed: tried " + ", ".join(attempted)
    )


def _find_git_root(start_dir):
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=start_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if result.returncode == 0:
            return result.stdout.decode("utf-8").strip()
    except OSError:
        pass
    # Fall back to a manual .git-directory walk.
    current = start_dir
    while True:
        if os.path.isdir(os.path.join(current, ".git")):
            return current
        parent = os.path.dirname(current)
        if parent == current:
            return None
        current = parent


def load_schema():
    path = discover_schema_path()
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


# --------------------------------------------------------------------------
# YAML parse contract (REQ-006, fixing "B4").
# --------------------------------------------------------------------------

def load_manifest_yaml(path):
    """Sole path from YAML bytes to a Python structure: canonicalize-sdd-yaml
    subprocess + json.loads. Never a hand-rolled parser, never a silent
    fallback."""
    script_real = os.path.realpath(os.path.abspath(__file__))
    script_dir = os.path.dirname(script_real)
    candidates = [
        os.path.normpath(os.path.join(script_dir, "canonicalize-sdd-yaml.py")),
        os.path.normpath(os.path.join(script_dir, "canonicalize-sdd-yaml")),
    ]
    canonicalizer = next((c for c in candidates if os.path.isfile(c)), None)
    if canonicalizer is None:
        canonicalizer = "canonicalize-sdd-yaml"  # rely on PATH as a last resort

    try:
        if canonicalizer.endswith(".py"):
            argv = [sys.executable, canonicalizer, "--yaml", path]
        else:
            argv = [canonicalizer, "--yaml", path]
        result = subprocess.run(
            argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False
        )
    except OSError as exc:
        raise CanonicalizerError(str(exc))

    if result.returncode != 0:
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        raise CanonicalizerError(detail or f"exit {result.returncode}")

    try:
        return json.loads(result.stdout.decode("utf-8"))
    except json.JSONDecodeError as exc:
        raise CanonicalizerError(f"non-JSON canonicalizer stdout: {exc}")


def load_manifest_json(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def load_manifest(path):
    if path.endswith(".yaml") or path.endswith(".yml"):
        return load_manifest_yaml(path)
    return load_manifest_json(path)


# --------------------------------------------------------------------------
# Hand-rolled draft-07 subset schema engine.
# --------------------------------------------------------------------------

def _escape_pointer_token(token):
    return str(token).replace("~", "~0").replace("/", "~1")


def _type_matches(value, type_spec):
    if isinstance(type_spec, list):
        return any(_type_matches(value, t) for t in type_spec)
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


def _resolve_ref(ref, root_schema):
    if not ref.startswith("#/"):
        raise ValueError(f"unsupported $ref (not a same-document fragment): {ref}")
    node = root_schema
    for part in ref[2:].split("/"):
        part = part.replace("~1", "/").replace("~0", "~")
        node = node[part]
    return node


def _schema_matches(instance, schema, root_schema):
    """True if instance satisfies schema with zero diagnostics."""
    probe = []
    _validate(instance, schema, root_schema, "", probe)
    return not probe


def _validate(instance, schema, root_schema, pointer, diags):
    if schema is True:
        return
    if schema is False:
        diags.append((pointer, "value not allowed (schema: false)"))
        return
    if not isinstance(schema, dict):
        raise ValueError(f"malformed schema node at {pointer!r}: {schema!r}")

    if "$ref" in schema:
        resolved = _resolve_ref(schema["$ref"], root_schema)
        _validate(instance, resolved, root_schema, pointer, diags)
        return

    if "const" in schema:
        if instance != schema["const"]:
            diags.append((pointer, f"expected const {schema['const']!r}, got {instance!r}"))
            return

    if "enum" in schema:
        if instance not in schema["enum"]:
            diags.append((pointer, f"expected one of {schema['enum']!r}, got {instance!r}"))
            return

    if "type" in schema:
        if not _type_matches(instance, schema["type"]):
            diags.append((pointer, f"expected type {schema['type']!r}, got {type(instance).__name__}"))
            return

    if "not" in schema:
        if _schema_matches(instance, schema["not"], root_schema):
            diags.append((pointer, "value matched a schema under 'not'"))

    if "oneOf" in schema:
        matches = sum(1 for sub in schema["oneOf"] if _schema_matches(instance, sub, root_schema))
        if matches != 1:
            diags.append((pointer, f"expected exactly one 'oneOf' branch to match, {matches} matched"))

    if "if" in schema:
        if _schema_matches(instance, schema["if"], root_schema):
            if "then" in schema:
                _validate(instance, schema["then"], root_schema, pointer, diags)
        else:
            if "else" in schema:
                _validate(instance, schema["else"], root_schema, pointer, diags)

    if isinstance(instance, str):
        if "pattern" in schema and not re.search(schema["pattern"], instance):
            diags.append((pointer, f"does not match pattern {schema['pattern']!r}"))
        if "minLength" in schema and len(instance) < schema["minLength"]:
            diags.append((pointer, f"length {len(instance)} < minLength {schema['minLength']}"))

    if isinstance(instance, dict):
        for req in schema.get("required", []):
            if req not in instance:
                diags.append((f"{pointer}/{_escape_pointer_token(req)}", f"missing required property {req!r}"))
        properties = schema.get("properties", {})
        for key, value in instance.items():
            if key in properties:
                _validate(value, properties[key], root_schema, f"{pointer}/{_escape_pointer_token(key)}", diags)
        if "propertyNames" in schema:
            for key in instance.keys():
                _validate(key, schema["propertyNames"], root_schema, f"{pointer}/{_escape_pointer_token(key)}", diags)
        additional = schema.get("additionalProperties", True)
        if additional is not True:
            extra_keys = [k for k in instance.keys() if k not in properties]
            if additional is False:
                for key in extra_keys:
                    diags.append((f"{pointer}/{_escape_pointer_token(key)}", "additional property not allowed"))
            else:
                for key in extra_keys:
                    _validate(instance[key], additional, root_schema, f"{pointer}/{_escape_pointer_token(key)}", diags)

    if isinstance(instance, list):
        if "items" in schema:
            items_schema = schema["items"]
            for index, element in enumerate(instance):
                _validate(element, items_schema, root_schema, f"{pointer}/{index}", diags)
        if schema.get("uniqueItems"):
            seen_canonical = []
            for index, element in enumerate(instance):
                canonical = json.dumps(element, sort_keys=True)
                if canonical in seen_canonical:
                    diags.append((f"{pointer}/{index}", "duplicate item (uniqueItems violated)"))
                else:
                    seen_canonical.append(canonical)
        if "minItems" in schema and len(instance) < schema["minItems"]:
            diags.append((pointer, f"array length {len(instance)} < minItems {schema['minItems']}"))


def validate_against_schema(document, schema):
    raw = []
    _validate(document, schema, schema, "", raw)
    return [Diagnostic("schema-invalid", pointer, message) for pointer, message in raw]


# --------------------------------------------------------------------------
# Semantic checks (REQ-006 diagnostic-id table, design.md
# `validate-facet-manifest` contract).
# --------------------------------------------------------------------------

def check_resolved_gate_id_duplicate(doc):
    diags = []
    gates = doc.get("resolved_gates")
    if not isinstance(gates, list):
        return diags
    seen = {}
    for index, gate in enumerate(gates):
        if not isinstance(gate, dict):
            continue
        gate_id = gate.get("id")
        if gate_id in seen:
            diags.append(Diagnostic(
                "resolved-gate-id-duplicate",
                f"/resolved_gates/{index}/id",
                f"duplicate resolved_gates id {gate_id!r} (first seen at /resolved_gates/{seen[gate_id]}/id)",
            ))
        else:
            seen[gate_id] = index
    return diags


def check_facet_classification_conflict(doc):
    diags = []
    required_facets = doc.get("required_facets")
    conditional_facets = doc.get("conditional_facets")
    if not isinstance(required_facets, list) or not isinstance(conditional_facets, list):
        return diags
    required_set = {f for f in required_facets if isinstance(f, str)}
    for index, entry in enumerate(conditional_facets):
        if not isinstance(entry, dict):
            continue
        facet = entry.get("facet")
        if facet in required_set:
            diags.append(Diagnostic(
                "facet-classification-conflict",
                f"/conditional_facets/{index}/facet",
                f"facet {facet!r} present in both required_facets and conditional_facets",
            ))
    return diags


def check_conditional_facet_duplicate(doc):
    diags = []
    conditional_facets = doc.get("conditional_facets")
    if not isinstance(conditional_facets, list):
        return diags
    seen = {}
    for index, entry in enumerate(conditional_facets):
        if not isinstance(entry, dict):
            continue
        facet = entry.get("facet")
        if facet in seen:
            diags.append(Diagnostic(
                "conditional-facet-duplicate",
                f"/conditional_facets/{index}/facet",
                f"duplicate conditional_facets facet {facet!r} (first seen at /conditional_facets/{seen[facet]}/facet)",
            ))
        else:
            seen[facet] = index
    return diags


def _is_sorted_strings(values):
    return isinstance(values, list) and all(isinstance(v, str) for v in values) and values == sorted(values)


def check_array_not_stable_sorted(doc):
    diags = []

    for field in ("affected_components", "required_facets", "capabilities"):
        values = doc.get(field)
        if isinstance(values, list) and not _is_sorted_strings(values):
            diags.append(Diagnostic(
                "array-not-stable-sorted", f"/{field}",
                f"{field} is not sorted lexicographically ascending",
            ))

    lite = doc.get("lite_eligibility")
    if isinstance(lite, dict):
        upgrade_reasons = lite.get("upgrade_reasons")
        if isinstance(upgrade_reasons, list) and not _is_sorted_strings(upgrade_reasons):
            diags.append(Diagnostic(
                "array-not-stable-sorted", "/lite_eligibility/upgrade_reasons",
                "lite_eligibility.upgrade_reasons is not sorted lexicographically ascending",
            ))

    conditional_facets = doc.get("conditional_facets")
    if isinstance(conditional_facets, list):
        keys = [e.get("facet") for e in conditional_facets if isinstance(e, dict)]
        if len(keys) == len(conditional_facets) and all(isinstance(k, str) for k in keys) and keys != sorted(keys):
            diags.append(Diagnostic(
                "array-not-stable-sorted", "/conditional_facets",
                "conditional_facets is not sorted ascending by facet",
            ))

    resolved_gates = doc.get("resolved_gates")
    if isinstance(resolved_gates, list):
        keys = [g.get("id") for g in resolved_gates if isinstance(g, dict)]
        if len(keys) == len(resolved_gates) and all(isinstance(k, str) for k in keys) and keys != sorted(keys):
            diags.append(Diagnostic(
                "array-not-stable-sorted", "/resolved_gates",
                "resolved_gates is not sorted ascending by id",
            ))

    return diags


SEMANTIC_CHECKS = (
    check_resolved_gate_id_duplicate,
    check_facet_classification_conflict,
    check_conditional_facet_duplicate,
    check_array_not_stable_sorted,
)


def validate_document(document, schema=None):
    """Run schema conformance + all semantic checks; return a Diagnostic list.

    Pure function over an already-parsed structure -- no I/O, no YAML
    handling. This is the function both the CLI (after the YAML parse
    contract) and the regression suite (against JSON fixtures) call."""
    if schema is None:
        schema = load_schema()
    diags = list(validate_against_schema(document, schema))
    if isinstance(document, dict):
        for check in SEMANTIC_CHECKS:
            diags.extend(check(document))
    return diags


# --------------------------------------------------------------------------
# Diagnostic determinism contract (REQ-006, all four scripts).
# --------------------------------------------------------------------------

def format_diagnostics(diags):
    ordered = sorted(diags, key=lambda d: (d.check_id, d.pointer))
    return [f"facet-manifest: {d.check_id}: {d.pointer}: {d.message}" for d in ordered]


def main(argv=None):
    # Diagnostic determinism contract: LF-only output on every runtime.
    # Python's text-mode stdout translates "\n" to os.linesep on some
    # platforms unless reconfigured; force LF explicitly.
    try:
        sys.stdout.reconfigure(newline="\n")
    except AttributeError:
        pass  # Python < 3.7: stdout is already LF on the platforms this ships to.

    parser = argparse.ArgumentParser(prog="validate-facet-manifest")
    parser.add_argument("--manifest", required=True)
    args = parser.parse_args(argv)

    try:
        document = load_manifest(args.manifest)
    except CanonicalizerError as exc:
        sys.stdout.write(f"facet-manifest: canonicalizer-invocation-failed: {exc}\n")
        return 1
    except (OSError, json.JSONDecodeError) as exc:
        sys.stdout.write(f"facet-manifest: manifest-unreadable: {exc}\n")
        return 1

    try:
        schema = load_schema()
    except FileNotFoundError as exc:
        sys.stdout.write(f"{exc}\n")
        return 1

    diags = validate_document(document, schema)
    if not diags:
        return 0

    out = sys.stdout
    for line in format_diagnostics(diags):
        out.write(line + "\n")
    return 1


if __name__ == "__main__":
    sys.exit(main())
