#!/usr/bin/env python3
"""REQ-003/REQ-006: Context Projection schema validator.

Usage:
    validate-context-projection.py --projection <path>

`<path>` is loaded directly via stdlib `json.load` -- this script's target,
`plugins/sdd-quality-loop/scripts/generated/project-context.resolved.json`
(Epic A1's already-reserved path, INV-007), is already JSON, never YAML.
Unlike `validate-facet-manifest.py`/`validate-capability-summary.py`, there
is no YAML parse contract here and no `canonicalize-sdd-yaml` subprocess
invocation at all (design.md `validate-context-projection` contract: "needs
no such step"; Planned Files, "no YAML/canonicalizer subprocess").

This module implements the same hand-rolled, stdlib-only subset of JSON
Schema draft-07 `validate-facet-manifest.py`/`validate-capability-summary.py`
already implement (INV-014: no third-party `jsonschema` dependency). This is
an independent copy of that engine -- design.md defines four standalone
validator scripts, none of which import from a sibling script -- not a
shared module. Implemented keywords: type (incl. array-form/union types),
required, additionalProperties (bool or schema), properties, propertyNames,
pattern, enum, const, uniqueItems, minItems, minLength, if/then/else, not,
oneOf, boolean subschema values, items, $ref/definitions (same-document
fragments only). `$schema`/`$id`/`title` are annotation keywords, not
constraint keywords, and are intentionally outside this engine's constraint
set (Discovery contract checks `$schema`/`$id` separately).

`contracts/context-projection.schema.json` itself exercises `type`,
`additionalProperties`, `required`, `properties`, `enum`, `propertyNames`,
`items`, `oneOf`, `const`, `pattern` (`source_sha256`/`provider_bindings_
sha256`'s `^sha256:[0-9a-f]{64}$` constraint), and `$ref`/`definitions`.
This engine still ships the full keyword set so `pattern` (and every other
keyword) is actually enforced rather than silently unconstrained -- see this
task's own Specification Differences note on design.md's keyword-audit
paragraph.

Checks: schema conformance only (`schema-invalid`), including the
`components` re-keying shape -- a fixture where `components` is still
array-typed fails `type: object` at the schema level (AC-030). The earlier-
revision `component-key-pattern-invalid` semantic check is retired ("B3");
`propertyNames: {"minLength": 1}` is the only remaining constraint on
`components` keys and it is already schema-level.
"""
import argparse
import json
import os
import re
import subprocess
import sys
from collections import namedtuple

Diagnostic = namedtuple("Diagnostic", ["check_id", "pointer", "message"])

SCHEMA_FILENAME = "context-projection.schema.json"


# --------------------------------------------------------------------------
# Discovery contract (REQ-006, all four scripts; identical to Epic A2's own
# REQ-005 discovery contract, design.md "Discovery contract").
# --------------------------------------------------------------------------

def discover_schema_path():
    """Resolve contracts/context-projection.schema.json.

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
        "context-projection: schema-discovery-failed: tried " + ", ".join(attempted)
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
# Projection load (REQ-003/REQ-006). No YAML parse contract: this script's
# target is always already-canonical JSON (Epic A1's reserved
# project-context.resolved.json path, or an equivalently-shaped fixture).
# --------------------------------------------------------------------------

def load_projection(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


# --------------------------------------------------------------------------
# Hand-rolled draft-07 subset schema engine (independent copy of
# validate-facet-manifest.py's/validate-capability-summary.py's own engine;
# see module docstring).
# --------------------------------------------------------------------------

def _escape_pointer_token(token):
    return str(token).replace("~", "~0").replace("/", "~1")


# Draft-07 `pattern` values follow ECMA-262 regex semantics (no
# `re.MULTILINE`), where a bare, non-multiline `$` asserts end-of-string
# only. Python's `re` module's `$` is more permissive: it also matches
# immediately before a single trailing "\n". That divergence means an
# instance like "sha256:<64 hex>\n" wrongly satisfies a naive
# `re.search("^sha256:[0-9a-f]{64}$", instance)`, silently admitting a
# trailing-newline value the schema author intended to reject. `\Z` is
# Python's strict absolute-end-of-string anchor with no such exception, so
# every unescaped `$` outside a `[...]` character class is rewritten to
# `\Z` before compiling. Diagnostic text still reports the original,
# untranslated pattern string. (T-001 quality-gate lesson, RT-20260817-003 --
# not a design.md/tasks.md instruction; carried into this validator's own
# independent copy of the engine for the same reason T-001/T-002 needed it.)
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

    Pure function over an already-parsed structure -- no I/O. This is the
    function both the CLI (after `load_projection`) and the regression suite
    (against JSON fixtures) call. No semantic check beyond schema
    conformance exists for this artifact (design.md `validate-context-
    projection` contract: "Checks: schema conformance only")."""
    if schema is None:
        schema = load_schema()
    return list(validate_against_schema(document, schema))


# --------------------------------------------------------------------------
# Diagnostic determinism contract (REQ-006, all four scripts).
# --------------------------------------------------------------------------

def format_diagnostics(diags):
    ordered = sorted(diags, key=lambda d: (d.check_id, d.pointer))
    return [f"context-projection: {d.check_id}: {d.pointer}: {d.message}" for d in ordered]


def main(argv=None):
    # Diagnostic determinism contract: LF-only output on every runtime.
    # Python's text-mode stdout translates "\n" to os.linesep on some
    # platforms unless reconfigured; force LF explicitly.
    try:
        sys.stdout.reconfigure(newline="\n")
    except AttributeError:
        pass  # Python < 3.7: stdout is already LF on the platforms this ships to.

    parser = argparse.ArgumentParser(prog="validate-context-projection")
    parser.add_argument("--projection", required=True)
    args = parser.parse_args(argv)

    try:
        document = load_projection(args.projection)
    # ValueError covers json.JSONDecodeError (a ValueError subclass) AND
    # UnicodeDecodeError (raised by the implicit UTF-8 text decode inside
    # `open(..., encoding="utf-8")` when the input bytes are not valid
    # UTF-8) -- catching only json.JSONDecodeError let a non-UTF-8 input
    # leak an unhandled traceback instead of this diagnostic, violating the
    # diagnostic determinism contract (a caller/CI parser expects a single
    # `context-projection: <check-id>: <detail>` line, never a traceback).
    except (OSError, ValueError) as exc:
        sys.stdout.write(f"context-projection: projection-unreadable: {exc}\n")
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
