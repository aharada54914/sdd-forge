#!/usr/bin/env python3
"""Hand-rolled, stdlib-only draft-07-subset validator for a single
Resolver Evidence fixture against contracts/resolver-evidence.schema.json
(T-001, AC-017/018/019/020). Not a general-purpose JSON Schema engine —
implements only the keyword subset this one schema document uses: type,
enum, const, pattern, minItems, minLength, minimum, required,
additionalProperties, properties, items, $ref (local #/definitions/*
only), if/then, not. Matches the closed-subset approach
investigation.md INV-011 names (no third-party dependency).

Usage:
    resolver-evidence-schema-check.py <schema.json> <instance.json> <valid|invalid>

Exit 0 when the instance's actual validity matches the expected
argument; exit 1 otherwise. Errors (if any) are always printed to
stderr for diagnosis.
"""
import json
import re
import sys


def _resolve_ref(ref, root):
    if not ref.startswith("#/definitions/"):
        raise ValueError("unsupported $ref (only local #/definitions/* supported): %r" % ref)
    name = ref[len("#/definitions/"):]
    try:
        return root["definitions"][name]
    except KeyError:
        raise ValueError("unresolved $ref: %r" % ref)


def _type_name(value):
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, int):
        return "integer"
    if isinstance(value, float):
        return "number"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "array"
    if isinstance(value, dict):
        return "object"
    if value is None:
        return "null"
    return "unknown"


def validate(instance, schema, root, path="$"):
    """Return a list of human-readable error strings; empty means valid."""
    errors = []

    if "$ref" in schema:
        schema = _resolve_ref(schema["$ref"], root)

    if "const" in schema:
        if instance != schema["const"]:
            errors.append("%s: expected const %r, got %r" % (path, schema["const"], instance))

    if "enum" in schema:
        if instance not in schema["enum"]:
            errors.append("%s: %r not in enum %r" % (path, instance, schema["enum"]))

    if "type" in schema:
        expected = schema["type"]
        expected_list = expected if isinstance(expected, list) else [expected]
        actual = _type_name(instance)
        ok = actual in expected_list or (actual == "integer" and "number" in expected_list)
        if not ok:
            errors.append("%s: expected type %r, got %r" % (path, expected, actual))

    if "pattern" in schema and isinstance(instance, str):
        if not re.search(schema["pattern"], instance):
            errors.append("%s: %r does not match pattern %r" % (path, instance, schema["pattern"]))

    if "minLength" in schema and isinstance(instance, str):
        if len(instance) < schema["minLength"]:
            errors.append("%s: length %d < minLength %d" % (path, len(instance), schema["minLength"]))

    if "minimum" in schema and isinstance(instance, (int, float)) and not isinstance(instance, bool):
        if instance < schema["minimum"]:
            errors.append("%s: %r < minimum %r" % (path, instance, schema["minimum"]))

    if "minItems" in schema and isinstance(instance, list):
        if len(instance) < schema["minItems"]:
            errors.append("%s: length %d < minItems %d" % (path, len(instance), schema["minItems"]))

    if isinstance(instance, dict):
        properties = schema.get("properties", {})
        if "required" in schema:
            for key in schema["required"]:
                if key not in instance:
                    errors.append("%s: missing required property %r" % (path, key))
        if schema.get("additionalProperties") is False:
            allowed = set(properties.keys())
            for key in instance.keys():
                if key not in allowed:
                    errors.append("%s: additional property %r not allowed" % (path, key))
        for key, subschema in properties.items():
            if key in instance:
                errors.extend(validate(instance[key], subschema, root, "%s.%s" % (path, key)))

    if isinstance(instance, list) and "items" in schema:
        for i, item in enumerate(instance):
            errors.extend(validate(item, schema["items"], root, "%s[%d]" % (path, i)))

    if "not" in schema:
        sub_errors = validate(instance, schema["not"], root, path)
        if not sub_errors:
            errors.append("%s: instance must not satisfy schema %r" % (path, schema["not"]))

    if "if" in schema:
        if_errors = validate(instance, schema["if"], root, path)
        if not if_errors:
            if "then" in schema:
                errors.extend(validate(instance, schema["then"], root, path))
        else:
            if "else" in schema:
                errors.extend(validate(instance, schema["else"], root, path))

    return errors


def main(argv):
    if len(argv) != 4:
        print("usage: resolver-evidence-schema-check.py <schema.json> <instance.json> <valid|invalid>", file=sys.stderr)
        return 2
    schema_path, instance_path, expectation = argv[1], argv[2], argv[3]
    if expectation not in ("valid", "invalid"):
        print("expectation must be 'valid' or 'invalid', got %r" % expectation, file=sys.stderr)
        return 2

    with open(schema_path, "r", encoding="utf-8") as f:
        schema = json.load(f)
    with open(instance_path, "r", encoding="utf-8") as f:
        instance = json.load(f)

    errors = validate(instance, schema, schema)
    is_valid = len(errors) == 0

    if errors:
        for e in errors:
            print(e, file=sys.stderr)

    if expectation == "valid" and not is_valid:
        print("FAIL: expected VALID, instance failed schema validation (%s)" % instance_path, file=sys.stderr)
        return 1
    if expectation == "invalid" and is_valid:
        print("FAIL: expected INVALID, instance passed schema validation (%s)" % instance_path, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
