#!/bin/sh
# T-004 (epic-189-a1-project-context, REQ-006): acceptance checks for
# contracts/approver-registry.schema.json.
#
# TEST-044 parameterized schema conformance (positive + one-fixture-per-
#   REQUIRED-field negative + malformed-shape + zero-entry-validates) — AC-044.
# TEST-045 approvers[] duplicate-id semantic-validator rejection
#   (DUPLICATE_APPROVER_REGISTRY_ID) — AC-045.
# TEST-046 the zero-identity `approvers: []` fixture validates against the
#   schema (the precondition T-005/T-006 build their downstream
#   classification/fail-closed proofs on; this task's own Done When scopes
#   only to this schema-conformance half) — AC-046.
#
# Reuses the same minimal draft-07 JSON Schema subset validator embedded in
# tests/project-context-schema.tests.sh (T-001) — no jsonschema library is
# available in this environment; python3/python resolution follows this
# repo's canonicalize-sdd-yaml.{sh,ps1,js} dispatcher convention.
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/approver-registry-test.XXXXXX")
# Physical-path normalization (design.md Test Strategy item 12; see
# tests/lib/loop-driver.sh:124): macOS $TMPDIR is itself a symlink.
WORK=$(cd "$WORK" && pwd -P)
trap 'rm -rf "$WORK"' EXIT INT TERM

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

if command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  printf 'FAIL: no python3/python interpreter available\n'
  exit 1
fi

SCHEMA="$ROOT/contracts/approver-registry.schema.json"
VALIDATOR="$WORK/ar_validator.py"

cat > "$VALIDATOR" <<'PYEOF'
#!/usr/bin/env python3
"""Minimal draft-07 JSON Schema subset validator, purpose-built for
contracts/approver-registry.schema.json (T-004,
epic-189-a1-project-context). Byte-identical logic to the validator
embedded in tests/project-context-schema.tests.sh (T-001) -- see that
file's module docstring for the supported keyword subset and rationale.
"""
import copy
import json
import sys


def validate(schema, instance, path="/"):
    errors = []
    if "const" in schema and instance != schema["const"]:
        errors.append("%s: expected const %r, got %r" % (path, schema["const"], instance))
    if "enum" in schema and instance not in schema["enum"]:
        errors.append("%s: %r not in enum %r" % (path, instance, schema["enum"]))
    t = schema.get("type")
    if t == "object" and not isinstance(instance, dict):
        errors.append("%s: expected object" % path)
    elif t == "array" and not isinstance(instance, list):
        errors.append("%s: expected array" % path)
    elif t == "string" and not isinstance(instance, str):
        errors.append("%s: expected string" % path)
    elif t == "boolean" and not isinstance(instance, bool):
        errors.append("%s: expected boolean" % path)

    if isinstance(instance, dict):
        for req in schema.get("required", []):
            if req not in instance:
                errors.append("%s: missing required field %r" % (path, req))
        props = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            for k in instance:
                if k not in props:
                    errors.append("%s: additional property %r not allowed" % (path, k))
        for k, v in instance.items():
            if k in props:
                errors.extend(validate(props[k], v, path.rstrip("/") + "/" + k))
    elif isinstance(instance, list) and "items" in schema:
        for idx, item in enumerate(instance):
            errors.extend(validate(schema["items"], item, path.rstrip("/") + "/%d" % idx))
    elif isinstance(instance, str) and "minLength" in schema and len(instance) < schema["minLength"]:
        errors.append("%s: shorter than minLength %d" % (path, schema["minLength"]))

    return errors


def delete_pointer(instance, pointer):
    inst = copy.deepcopy(instance)
    parts = [p for p in pointer.split("/") if p != ""]
    node = inst
    for i, part in enumerate(parts):
        last = i == len(parts) - 1
        if part == "*":
            if last:
                del node[0]
            else:
                node = node[0]
        else:
            if last:
                del node[part]
            else:
                node = node[part]
    return inst


def duplicate_id_check(instance, array_path, code):
    arr = instance.get(array_path, [])
    seen = set()
    for item in arr:
        iid = item.get("id")
        if iid in seen:
            return code
        seen.add(iid)
    return None


def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def main(argv):
    if len(argv) < 2:
        print("usage: ar_validator.py <command> [args...]", file=sys.stderr)
        return 2
    cmd = argv[1]
    if cmd == "check":
        schema = load_json(argv[2])
        instance = load_json(argv[3])
        errors = validate(schema, instance)
        if errors:
            for e in errors:
                print(e, file=sys.stderr)
            return 1
        print("VALID")
        return 0
    if cmd == "check-expect-invalid":
        schema = load_json(argv[2])
        instance = load_json(argv[3])
        errors = validate(schema, instance)
        if errors:
            print("REJECTED: %s" % "; ".join(errors))
            return 0
        print("UNEXPECTEDLY VALID", file=sys.stderr)
        return 1
    if cmd == "delete-check":
        schema = load_json(argv[2])
        instance = load_json(argv[3])
        pointer = argv[4]
        mutated = delete_pointer(instance, pointer)
        errors = validate(schema, mutated)
        if errors:
            print("REJECTED: %s" % "; ".join(errors))
            return 0
        print("UNEXPECTEDLY VALID after deleting %s" % pointer, file=sys.stderr)
        return 1
    if cmd == "dup-check":
        instance = load_json(argv[2])
        array_path = argv[3]
        expected_code = argv[4]
        code = duplicate_id_check(instance, array_path, expected_code)
        if code == expected_code:
            print("DETECTED: %s" % code)
            return 0
        print("NOT DETECTED (got %r, expected %r)" % (code, expected_code), file=sys.stderr)
        return 1
    print("unknown command: %s" % cmd, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
PYEOF

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

cat > "$WORK/ar_positive.json" <<'JSONEOF'
{
  "schema": "sdd-approver-registry/v1",
  "approvers": [
    {"id": "alice-01", "name": "Alice Example", "registered_at": "2026-01-01T00:00:00Z"},
    {"id": "bob-02", "name": "Bob Example", "registered_at": "2026-01-02T00:00:00Z"}
  ]
}
JSONEOF

cat > "$WORK/ar_empty.json" <<'JSONEOF'
{
  "schema": "sdd-approver-registry/v1",
  "approvers": []
}
JSONEOF

cat > "$WORK/ar_malformed_shape.json" <<'JSONEOF'
{
  "schema": "sdd-approver-registry/v1",
  "approvers": "not-an-array"
}
JSONEOF

cat > "$WORK/ar_dup_id.json" <<'JSONEOF'
{
  "schema": "sdd-approver-registry/v1",
  "approvers": [
    {"id": "dup-approver", "name": "First"},
    {"id": "dup-approver", "name": "Second"}
  ]
}
JSONEOF

# ---------------------------------------------------------------------------
# TEST-044: schema conformance (AC-044)
# ---------------------------------------------------------------------------

if "$PY" "$VALIDATOR" check "$SCHEMA" "$WORK/ar_positive.json" >/dev/null 2>"$WORK/err"; then
  pass "TEST-044 positive fixture (id+name+registered_at) validates"
else
  fail "TEST-044 positive fixture (id+name+registered_at) validates: $(cat "$WORK/err")"
fi

for ptr in /approvers/*/id /approvers/*/name; do
  if "$PY" "$VALIDATOR" delete-check "$SCHEMA" "$WORK/ar_positive.json" "$ptr" >"$WORK/out" 2>"$WORK/err"; then
    pass "TEST-044 deleting required field $ptr is rejected"
  else
    fail "TEST-044 deleting required field $ptr is rejected: $(cat "$WORK/out" "$WORK/err")"
  fi
done

if "$PY" "$VALIDATOR" check-expect-invalid "$SCHEMA" "$WORK/ar_malformed_shape.json" >"$WORK/out" 2>"$WORK/err"; then
  pass "TEST-044 non-array 'approvers' value is rejected"
else
  fail "TEST-044 non-array 'approvers' value is rejected: $(cat "$WORK/out" "$WORK/err")"
fi

if "$PY" "$VALIDATOR" check "$SCHEMA" "$WORK/ar_empty.json" >/dev/null 2>"$WORK/err"; then
  pass "TEST-044 zero-entry 'approvers: []' fixture validates"
else
  fail "TEST-044 zero-entry 'approvers: []' fixture validates: $(cat "$WORK/err")"
fi

# ---------------------------------------------------------------------------
# TEST-045: approvers[] duplicate-id semantic-validator rejection (AC-045)
# ---------------------------------------------------------------------------

if "$PY" "$VALIDATOR" check "$SCHEMA" "$WORK/ar_dup_id.json" >/dev/null 2>"$WORK/err"; then
  pass "TEST-045 duplicate-id fixture still passes plain JSON Schema (M18-equivalent)"
else
  fail "TEST-045 duplicate-id fixture still passes plain JSON Schema (M18-equivalent): $(cat "$WORK/err")"
fi

if "$PY" "$VALIDATOR" dup-check "$WORK/ar_dup_id.json" approvers DUPLICATE_APPROVER_REGISTRY_ID >"$WORK/out" 2>"$WORK/err"; then
  pass "TEST-045 semantic-validator layer rejects duplicate approvers[].id (DUPLICATE_APPROVER_REGISTRY_ID)"
else
  fail "TEST-045 semantic-validator layer rejects duplicate approvers[].id (DUPLICATE_APPROVER_REGISTRY_ID): $(cat "$WORK/out" "$WORK/err")"
fi

# ---------------------------------------------------------------------------
# TEST-046: zero-identity approver-registry boundary — schema-conformance
# half only (AC-046; the verdict/fail-closed half is T-005's/T-006's own
# Done When).
# ---------------------------------------------------------------------------

if "$PY" "$VALIDATOR" check "$SCHEMA" "$WORK/ar_empty.json" >/dev/null 2>"$WORK/err"; then
  pass "TEST-046 zero-identity 'approvers: []' fixture validates against the schema"
else
  fail "TEST-046 zero-identity 'approvers: []' fixture validates against the schema: $(cat "$WORK/err")"
fi

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
[ "$FAIL" -eq 0 ]
