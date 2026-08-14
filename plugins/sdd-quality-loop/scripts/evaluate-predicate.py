#!/usr/bin/env python3
"""evaluate-predicate: the Predicate DSL evaluator (T-002, REQ-002).

Implements ADR-0020 (docs/adr/0020-conditional-predicate-dsl.md) in full:
the closed 8-operator grammar (all/any/not, equals/not_equals/contains/in/
exists), the general fail-closed rule for equals/not_equals/contains/in
(missing path, null value, or type mismatch -> false + WARN, never an
exception), the exists exception (path present -> true regardless of
value including null; path absent -> false + WARN; type never inspected),
all()=true / any()=false on an empty list with no short-circuit (every
child is evaluated and recorded), not's strict unary arity with its
documented truth table (including the child-WARN special case), and a
single evaluator/field-allowlist shared by both `trigger` and
`conditional_facets[].when` (AC-010 -- there is no second condition
language).

CLI contract (design.md API / Contract Plan):
    evaluate-predicate.py --predicate <path|-> --component-properties <path|->
      -> stdout JSON {"result": bool, "evidence": [...]}, exit 0 always for
         a well-formed predicate (a false/WARN result is a normal outcome,
         not an error).
    evaluate-predicate.py --check-field-allowlist <project-context-fixture>
      -> the field-allowlist drift-check (AC-011). Until Epic A1's real
         Project Context schema lands (it does not exist in this repository
         yet -- investigation.md INV-004a), this checks the local allowlist
         against a fixture file shaped like {"fields": [...]}; once A1's
         schema exists, the same flag can point at it directly as long as
         it exposes an equivalent flat "fields" list (or is adapted then).
         Exit 0 on an exact set match, non-zero (with a diagnostic) on any
         divergence.

Malformed input (invalid JSON, a field outside the allowlist, an operator
outside the fixed set, or a `not` node whose shape does not parse) is a
distinct, non-zero-exit PREDICATE_SCHEMA_ERROR -- a construction-time
error, never conflated with a WARN evaluation outcome.
"""
import json
import sys


def _emit_stdout(line):
    """Write one stdout line byte-deterministically (LF on every platform).

    Windows text-mode stdout translates \n to \r\n, which breaks the
    byte-identical cross-wrapper/golden comparisons (TEST-031); writing
    through sys.stdout.buffer pins LF.
    """
    sys.stdout.buffer.write((line + "\n").encode("utf-8"))
    sys.stdout.buffer.flush()


# AC-011 / INV-004a: this list is the field allowlist's source of truth
# within this script. It is generated from, or drift-checked against,
# Epic A1's Project Context schema per design.md's API/Contract Plan --
# until that schema exists in this repository, it remains a placeholder
# carrying an explicit drift-check obligation (see --check-field-allowlist
# above and investigation.md INV-004a).
ALLOWED_FIELDS = (
    "artifact_kinds",
    "runtime_classes",
    "characteristics.pii",
    "characteristics.ui",
    "characteristics.auto_update",
    "characteristics.local_persistence",
    "distribution_channels",
    "data_classification",
)
ALLOWED_FIELDS_SET = frozenset(ALLOWED_FIELDS)

COMPARISON_OPERATORS = frozenset({"equals", "not_equals", "contains", "in", "exists"})
LOGICAL_KEYS = ("all", "any", "not")


class PredicateSchemaError(Exception):
    """Raised for any construction-time grammar violation (never for a
    fail-closed evaluation outcome, which is a normal WARN, not this)."""


def _read_arg_source(value):
    if value == "-":
        return sys.stdin.read()
    with open(value, "r", encoding="utf-8") as fh:
        return fh.read()


def _json_type(value):
    """JSON-level type category (bool is its own category, never 'number')."""
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, (int, float)):
        return "number"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "array"
    if isinstance(value, dict):
        return "object"
    return "unknown"


def resolve_path(properties, dotted_path):
    """Nested/dotted-path traversal (Epic A1's Project Context schema
    convention, AC-013 -- never a flattened-key-only map). Returns
    (found: bool, value)."""
    current = properties
    for segment in dotted_path.split("."):
        if not isinstance(current, dict) or segment not in current:
            return False, None
        current = current[segment]
    return True, current


def validate_predicate(node):
    """Raise PredicateSchemaError if `node` does not conform to
    #/definitions/predicate. Called before any evaluation begins, so a
    malformed predicate never partially evaluates."""
    if not isinstance(node, dict):
        raise PredicateSchemaError(f"predicate node is not an object: {node!r}")
    keys = set(node.keys())

    if keys == {"all"}:
        if not isinstance(node["all"], list):
            raise PredicateSchemaError("'all' value must be an array")
        for child in node["all"]:
            validate_predicate(child)
        return
    if keys == {"any"}:
        if not isinstance(node["any"], list):
            raise PredicateSchemaError("'any' value must be an array")
        for child in node["any"]:
            validate_predicate(child)
        return
    if keys == {"not"}:
        # AC-012: 'not' is strictly unary. Its value must be a single
        # predicate object, not a list (zero or two-plus children under a
        # list shape is the arity violation this guards against).
        if isinstance(node["not"], list):
            raise PredicateSchemaError(
                "'not' must hold exactly one predicate object, "
                f"not an array of {len(node['not'])}"
            )
        validate_predicate(node["not"])
        return

    # Leaf comparison node.
    required = {"scope", "field", "operator"}
    if not required.issubset(keys):
        raise PredicateSchemaError(
            f"predicate node missing required key(s): {sorted(required - keys)}"
        )
    allowed_leaf_keys = {"scope", "field", "operator", "value"}
    if not keys.issubset(allowed_leaf_keys):
        raise PredicateSchemaError(
            f"predicate node has unexpected key(s): {sorted(keys - allowed_leaf_keys)}"
        )
    if node["scope"] != "affected_component":
        raise PredicateSchemaError(f"unsupported scope: {node['scope']!r}")
    field = node["field"]
    if field not in ALLOWED_FIELDS_SET:
        raise PredicateSchemaError(f"field not in allowlist: {field!r}")
    operator = node["operator"]
    if operator not in COMPARISON_OPERATORS:
        raise PredicateSchemaError(f"operator not in closed operator set: {operator!r}")
    if operator != "exists" and "value" not in keys:
        raise PredicateSchemaError(f"operator {operator!r} requires a 'value' key")


def _child_bool(evidence_entry):
    """A child's boolean contribution to a parent all/any/not combination.
    WARN counts as false, same as no-match (AC-009's all/any semantics)."""
    return evidence_entry["outcome"] == "match"


def evaluate(node, properties):
    """Evaluate one predicate node against `properties`; returns its
    Evidence entry (design.md's Evidence JSON Schema shape). Assumes
    `node` already passed validate_predicate()."""
    keys = set(node.keys())

    if keys == {"all"}:
        # No short-circuit (AC-009): every child is evaluated regardless
        # of whether an earlier child already determines the outcome.
        children = [evaluate(child, properties) for child in node["all"]]
        result = all(_child_bool(child) for child in children)  # empty -> True
        return {
            "operator": "all",
            "path": None,
            "outcome": "match" if result else "no-match",
            "children": children,
        }

    if keys == {"any"}:
        children = [evaluate(child, properties) for child in node["any"]]
        result = any(_child_bool(child) for child in children)  # empty -> False
        return {
            "operator": "any",
            "path": None,
            "outcome": "match" if result else "no-match",
            "children": children,
        }

    if keys == {"not"}:
        child = evaluate(node["not"], properties)
        # AC-012 truth table: child match -> false; child no-match -> true;
        # child WARN -> false (NOT naive negation -- an ambiguous child
        # never becomes a confident match merely by being negated). The
        # child's own WARN reason is preserved on the child's own entry,
        # never copied onto `not`'s own entry.
        if child["outcome"] == "warn":
            not_result = False
        else:
            not_result = not _child_bool(child)
        return {
            "operator": "not",
            "path": None,
            "outcome": "match" if not_result else "no-match",
            "children": [child],
        }

    # Leaf comparison node.
    field = node["field"]
    operator = node["operator"]
    found, value = resolve_path(properties, field)

    if operator == "exists":
        # The explicit exception to the general fail-closed rule: presence
        # is `true` regardless of value (including null); type is never
        # inspected. Absence is the only WARN case for this operator.
        if found:
            return {"operator": "exists", "path": field, "outcome": "match"}
        return {
            "operator": "exists",
            "path": field,
            "outcome": "warn",
            "reason": "missing-path",
        }

    # General fail-closed rule (equals/not_equals/contains/in): missing
    # path or null value -> false + WARN, uniformly, before any
    # operator-specific comparison is attempted.
    if not found:
        return {
            "operator": operator,
            "path": field,
            "outcome": "warn",
            "reason": "missing-path",
        }
    if value is None:
        return {
            "operator": operator,
            "path": field,
            "outcome": "warn",
            "reason": "null-value",
        }

    expected = node.get("value")

    if operator in ("equals", "not_equals"):
        # Same-typed scalars only; a type mismatch is false + WARN for
        # BOTH operators -- not_equals never becomes true merely because
        # the compared values have different types.
        if _json_type(value) != _json_type(expected):
            return {
                "operator": operator,
                "path": field,
                "outcome": "warn",
                "reason": "type-mismatch",
            }
        is_equal = value == expected
        matched = is_equal if operator == "equals" else (not is_equal)
        return {
            "operator": operator,
            "path": field,
            "outcome": "match" if matched else "no-match",
        }

    if operator == "contains":
        # "array (field) contains scalar (value)" only.
        if not isinstance(value, list):
            return {
                "operator": operator,
                "path": field,
                "outcome": "warn",
                "reason": "non-array-field",
            }
        matched = expected in value
        return {
            "operator": operator,
            "path": field,
            "outcome": "match" if matched else "no-match",
        }

    if operator == "in":
        # "scalar (field) is a member of array literal (value)" only.
        if not isinstance(expected, list):
            return {
                "operator": operator,
                "path": field,
                "outcome": "warn",
                "reason": "malformed-value-array",
            }
        matched = value in expected
        return {
            "operator": operator,
            "path": field,
            "outcome": "match" if matched else "no-match",
        }

    raise AssertionError(f"unreachable: operator already validated: {operator!r}")


def run_evaluate(predicate, properties):
    validate_predicate(predicate)
    root_evidence = evaluate(predicate, properties)
    result = root_evidence["outcome"] == "match"
    return {"result": result, "evidence": [root_evidence]}


def check_field_allowlist(project_context_path):
    """AC-011 drift-check: compare ALLOWED_FIELDS against a Project
    Context schema (or, until Epic A1's real schema lands, a fixture
    shaped like {"fields": [...]})."""
    try:
        with open(project_context_path, "r", encoding="utf-8") as fh:
            doc = json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PREDICATE_SCHEMA_ERROR: cannot read/parse {project_context_path}: {exc}", file=sys.stderr)
        return 2
    declared = doc.get("fields") if isinstance(doc, dict) else None
    if not isinstance(declared, list) or not all(isinstance(f, str) for f in declared):
        print(
            f"FIELD_ALLOWLIST_DRIFT: {project_context_path} has no valid top-level 'fields' array of strings",
            file=sys.stderr,
        )
        return 1
    declared_set = set(declared)
    if declared_set != ALLOWED_FIELDS_SET:
        missing = sorted(ALLOWED_FIELDS_SET - declared_set)
        extra = sorted(declared_set - ALLOWED_FIELDS_SET)
        print(
            f"FIELD_ALLOWLIST_DRIFT: missing={missing} extra={extra}",
            file=sys.stderr,
        )
        return 1
    _emit_stdout("Field allowlist matches the Project Context schema (or fixture): no drift.")
    return 0


def main(argv=None):
    argv = sys.argv[1:] if argv is None else list(argv)

    predicate_path = None
    properties_path = None
    check_field_allowlist_path = None
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--predicate" and i + 1 < len(argv):
            predicate_path = argv[i + 1]
            i += 2
        elif arg == "--component-properties" and i + 1 < len(argv):
            properties_path = argv[i + 1]
            i += 2
        elif arg == "--check-field-allowlist" and i + 1 < len(argv):
            check_field_allowlist_path = argv[i + 1]
            i += 2
        else:
            print(f"evaluate-predicate: unrecognized argument: {arg}", file=sys.stderr)
            return 2

    if check_field_allowlist_path is not None:
        return check_field_allowlist(check_field_allowlist_path)

    if predicate_path is None or properties_path is None:
        print(
            "usage: evaluate-predicate.py --predicate <path|-> --component-properties <path|->",
            file=sys.stderr,
        )
        return 2

    try:
        predicate = json.loads(_read_arg_source(predicate_path))
        properties = json.loads(_read_arg_source(properties_path))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PREDICATE_SCHEMA_ERROR: cannot read/parse input: {exc}", file=sys.stderr)
        return 2

    if not isinstance(properties, dict):
        print("PREDICATE_SCHEMA_ERROR: component-properties must be a JSON object", file=sys.stderr)
        return 2

    try:
        output = run_evaluate(predicate, properties)
    except PredicateSchemaError as exc:
        print(f"PREDICATE_SCHEMA_ERROR: {exc}", file=sys.stderr)
        return 2

    _emit_stdout(json.dumps(output, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
