#!/usr/bin/env python3
"""REQ-002/REQ-006: Capability Summary (Lite track) schema validator.

Usage:
    validate-capability-summary.py --summary <path>

<path> ending in .yaml/.yml is loaded through the YAML parse contract: a
`canonicalize-sdd-yaml` subprocess invocation (canonical-JSON stdout) is the
sole path from YAML bytes to a Python structure -- never a hand-rolled YAML
parser and never a silent fallback. A non-zero canonicalizer exit surfaces as
this validator's own `canonicalizer-invocation-failed` diagnostic.

<path> ending in .json is loaded directly via stdlib `json.load` -- this is
NOT a YAML parsing path of any kind; it exists so the regression suite can
exercise `validate_document` (the actual hand-rolled schema engine) against
already-canonical JSON fixtures, independent of whichever tool eventually
turns a `capability-summary.yaml` into that structure (design.md YAML parse
contract, shared verbatim with `validate-facet-manifest`).

This module implements the same hand-rolled, stdlib-only subset of JSON
Schema draft-07 as `validate-facet-manifest.py` (INV-014: no third-party
`jsonschema` dependency; design.md's own `validate-capability-summary`
contract: "reusing T-001's hand-rolled draft-07 subset engine's same keyword
coverage, no new keyword needed"). This is an independent copy of that
engine -- design.md defines four standalone validator scripts, none of which
import from a sibling script -- not a shared module. Implemented keywords:
type (incl. array-form/union types), required, additionalProperties (bool or
schema), properties, propertyNames, pattern, enum, const, uniqueItems,
minItems, minLength, if/then/else, not, oneOf, boolean subschema values,
items, $ref/definitions (same-document fragments only). `$schema`/`$id`/
`title` are annotation keywords, not constraint keywords, and are
intentionally outside this engine's constraint set (Discovery contract
checks `$schema`/`$id` separately).

`contracts/capability-summary.schema.json` itself only exercises a subset of
that coverage (`type`, `additionalProperties`, `required`, `properties`,
`const`, `pattern`, `items`, `uniqueItems`, `minLength` -- `feature`'s own
`pattern` constraint on `^[a-z0-9][a-z0-9-]*$`). This engine still ships the
full keyword set so `pattern` (and every other keyword) is actually enforced
rather than silently unconstrained.

No semantic check beyond schema conformance exists for this script --
design.md's `validate-capability-summary` contract: "No semantic check
beyond schema conformance is needed for this script -- every REQ-002
invariant is schema-expressible now that there is only one branch."
"""
import argparse
import json
import os
import re
import subprocess
import sys
from collections import namedtuple

Diagnostic = namedtuple("Diagnostic", ["check_id", "pointer", "message"])

SCHEMA_FILENAME = "capability-summary.schema.json"


class CanonicalizerError(Exception):
    """Raised when the YAML parse contract's subprocess step fails."""


# --------------------------------------------------------------------------
# Discovery contract (REQ-006, all four scripts; identical to Epic A2's own
# REQ-005 discovery contract, design.md "Discovery contract").
# --------------------------------------------------------------------------

def discover_schema_path():
    """Resolve contracts/capability-summary.schema.json.

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
        "capability-summary: schema-discovery-failed: tried " + ", ".join(attempted)
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
# YAML parse contract (REQ-006, shared verbatim with validate-facet-manifest).
# --------------------------------------------------------------------------

def load_summary_yaml(path):
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
            argv = [sys.executable, canonicalizer, "--input-format", "yaml", path]
        else:
            argv = [canonicalizer, "--input-format", "yaml", path]
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


def load_summary_json(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def load_summary(path):
    if path.endswith(".yaml") or path.endswith(".yml"):
        return load_summary_yaml(path)
    return load_summary_json(path)


# --------------------------------------------------------------------------
# Hand-rolled draft-07 subset schema engine (independent copy of
# validate-facet-manifest.py's own engine; see module docstring).
# --------------------------------------------------------------------------

def _escape_pointer_token(token):
    return str(token).replace("~", "~0").replace("/", "~1")


# Draft-07 `pattern` values follow ECMA-262 regex semantics (no
# `re.MULTILINE`), where a bare, non-multiline `$` asserts end-of-string
# only. Python's `re` module's `$` is more permissive: it also matches
# immediately before a single trailing "\n". That divergence means an
# instance like "epic-192-a4-facet-manifest\n" wrongly satisfies a naive
# `re.search("^[a-z0-9][a-z0-9-]*$", instance)`, silently admitting a
# trailing-newline value the schema author intended to reject. `\Z` is
# Python's strict absolute-end-of-string anchor with no such exception, so
# every unescaped `$` outside a `[...]` character class is rewritten to
# `\Z` before compiling. Diagnostic text still reports the original,
# untranslated pattern string.
_PATTERN_CACHE = {}


def _ecma_anchor(pattern):
    """Rewrite unescaped, non-character-class `$` to `\\Z` (see module note
    above). Walks the pattern tracking backslash-escapes (an escape
    consumes exactly the following character, whatever it is) and `[...]`
    character-class state, including the ECMA-262/POSIX convention that a
    `]` in the first position of a class (optionally right after a leading
    `^`) is a literal member, not the closing bracket."""
    out = []
    i = 0
    length = len(pattern)
    in_class = False
    while i < length:
        ch = pattern[i]
        if ch == "\\" and i + 1 < length:
            out.append(ch)
            out.append(pattern[i + 1])
            i += 2
            continue
        if not in_class:
            if ch == "[":
                in_class = True
                out.append(ch)
                i += 1
                if i < length and pattern[i] == "^":
                    out.append(pattern[i])
                    i += 1
                if i < length and pattern[i] == "]":
                    out.append(pattern[i])
                    i += 1
                continue
            if ch == "$":
                out.append(r"\Z")
                i += 1
                continue
            out.append(ch)
            i += 1
            continue
        else:
            if ch == "]":
                in_class = False
            out.append(ch)
            i += 1
    return "".join(out)


def _compile_pattern(pattern):
    """Compile a schema-supplied `pattern` under ECMA-262 `$` semantics,
    caching the compiled regex (schema patterns repeat across many
    instances/fixtures within a single validator invocation)."""
    compiled = _PATTERN_CACHE.get(pattern)
    if compiled is None:
        compiled = re.compile(_ecma_anchor(pattern))
        _PATTERN_CACHE[pattern] = compiled
    return compiled


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
        if "pattern" in schema and not _compile_pattern(schema["pattern"]).search(instance):
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


def validate_document(document, schema=None):
    """Run schema conformance; return a Diagnostic list.

    Pure function over an already-parsed structure -- no I/O, no YAML
    handling. This is the function both the CLI (after the YAML parse
    contract) and the regression suite (against JSON fixtures) call. Unlike
    `validate-facet-manifest.py`, no semantic check beyond schema
    conformance exists for this artifact (design.md `validate-capability-
    summary` contract)."""
    if schema is None:
        schema = load_schema()
    return list(validate_against_schema(document, schema))


# --------------------------------------------------------------------------
# Diagnostic determinism contract (REQ-006, all four scripts).
# --------------------------------------------------------------------------

def format_diagnostics(diags):
    ordered = sorted(diags, key=lambda d: (d.check_id, d.pointer))
    return [f"capability-summary: {d.check_id}: {d.pointer}: {d.message}" for d in ordered]


def main(argv=None):
    # Diagnostic determinism contract: LF-only output on every runtime.
    # Python's text-mode stdout translates "\n" to os.linesep on some
    # platforms unless reconfigured; force LF explicitly.
    try:
        sys.stdout.reconfigure(newline="\n")
    except AttributeError:
        pass  # Python < 3.7: stdout is already LF on the platforms this ships to.

    parser = argparse.ArgumentParser(prog="validate-capability-summary")
    parser.add_argument("--summary", required=True)
    args = parser.parse_args(argv)

    try:
        document = load_summary(args.summary)
    except CanonicalizerError as exc:
        sys.stdout.write(f"capability-summary: canonicalizer-invocation-failed: {exc}\n")
        return 1
    # ValueError covers json.JSONDecodeError AND UnicodeDecodeError (both
    # ValueError subclasses) -- a non-UTF-8 --summary input must surface
    # this diagnostic, never an unhandled Python traceback (T-001..T-004
    # quality-gate lesson -- RT-20260817-004; not a design.md/tasks.md
    # instruction; validate-context-projection.py/compare-facet-manifest-
    # staleness.py already carried this fix, this was the one remaining gap).
    except (OSError, ValueError) as exc:
        sys.stdout.write(f"capability-summary: summary-unreadable: {exc}\n")
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
