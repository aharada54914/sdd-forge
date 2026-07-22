#!/bin/sh
# T-001 (epic-189-a1-project-context, REQ-001/REQ-002): acceptance checks
# for contracts/project-context.schema.json, contracts/provider-bindings.schema.json,
# and contracts/project-context.template.yaml.
#
# TEST-001 parameterized schema conformance (project-context, positive +
#   one-fixture-per-REQUIRED-pointer negative) — AC-001.
# TEST-002 field-allowlist coverage: all 8 ADR-0020 allowlist paths resolve
#   against a schema-defined field — AC-002.
# TEST-003 parameterized schema conformance (provider-bindings, positive +
#   state_authority/credentials passthrough + one-fixture-per-REQUIRED-pointer
#   negative) — AC-003.
# TEST-004 provider-neutrality: an invented provider string validates (no
#   fixed Provider enum) — AC-004.
# TEST-040 components[]/bindings[] duplicate-id semantic-validator rejection
#   (DUPLICATE_COMPONENT_ID / DUPLICATE_BINDING_ID) — AC-040.
# TEST-041 adapter_paths optional array-of-glob passthrough, present and
#   absent — AC-041.
# TEST-042 project-context.template.yaml validates and its shared_paths
#   contains all six canonical seed patterns — AC-042.
#
# The JSON Schema draft-07 subset validator and restricted block-style YAML
# loader below are purpose-built for these two schemas only (no jsonschema
# or PyYAML dependency is available or installed in CI, per this epic's
# CI-resilience constraint) — see pc_validator.py's own module docstring.
# python3/python resolution follows this repo's existing
# canonicalize-sdd-yaml.{sh,ps1,js} dispatcher convention (design.md
# Components).
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/pc-schema-test.XXXXXX")
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

PC_SCHEMA="$ROOT/contracts/project-context.schema.json"
PB_SCHEMA="$ROOT/contracts/provider-bindings.schema.json"
PC_TEMPLATE="$ROOT/contracts/project-context.template.yaml"
VALIDATOR="$WORK/pc_validator.py"

cat > "$VALIDATOR" <<'PYEOF'
#!/usr/bin/env python3
"""Minimal draft-07 JSON Schema subset validator + restricted YAML-subset
loader, purpose-built for contracts/project-context.schema.json and
contracts/provider-bindings.schema.json (T-001, epic-189-a1-project-context).

Not a general-purpose JSON Schema or YAML implementation. Supports exactly
the keywords/shapes these two schemas and the template use: type, required,
additionalProperties (bool), properties, items, enum, const, minLength,
oneOf. The YAML loader supports block-style mappings and lists-of-mappings
with 2-space indentation only (no anchors, tags, flow style, or multiline
scalars) -- sufficient for contracts/project-context.template.yaml.
"""
import copy
import json
import sys


def parse_scalar(val):
    val = val.strip()
    if len(val) >= 2 and val[0] == '"' and val[-1] == '"':
        return val[1:-1]
    if len(val) >= 2 and val[0] == "'" and val[-1] == "'":
        return val[1:-1]
    if val == "true":
        return True
    if val == "false":
        return False
    if val == "[]":
        return []
    if val == "{}":
        return {}
    return val


def indent_of(line):
    return len(line) - len(line.lstrip(" "))


def parse_yaml_block(lines):
    if not lines:
        return {}
    first_content = lines[0].lstrip(" ")
    if first_content.startswith("- "):
        result = []
        idx = 0
        while idx < len(lines):
            line = lines[idx]
            marker_indent = indent_of(line)
            content = line.lstrip(" ")[2:]
            entry = {}
            k, _, v = content.partition(":")
            entry[k.strip()] = parse_scalar(v.strip()) if v.strip() else None
            idx += 1
            cont_indent = marker_indent + 2
            while idx < len(lines) and indent_of(lines[idx]) == cont_indent and not lines[idx].lstrip(" ").startswith("- "):
                k2, _, v2 = lines[idx].strip().partition(":")
                entry[k2.strip()] = parse_scalar(v2.strip())
                idx += 1
            result.append(entry)
        return result
    else:
        result = {}
        base_indent = indent_of(lines[0])
        idx = 0
        while idx < len(lines):
            line = lines[idx]
            k, _, v = line.strip().partition(":")
            k = k.strip()
            v = v.strip()
            idx += 1
            if v == "":
                sub_indent = base_indent + 2
                sub_lines = []
                while idx < len(lines) and indent_of(lines[idx]) >= sub_indent:
                    sub_lines.append(lines[idx])
                    idx += 1
                result[k] = parse_yaml_block(sub_lines)
            else:
                result[k] = parse_scalar(v)
        return result


def load_yaml_subset(text):
    lines = []
    for raw in text.split("\n"):
        line = raw.rstrip("\n").rstrip("\r")
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        lines.append(line)
    return parse_yaml_block(lines)


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

    # required / properties / additionalProperties apply to any object
    # instance regardless of whether "type": "object" is explicitly
    # declared on this schema node (draft-07 keywords are inert against
    # non-applicable instance types, not against absent "type").
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

    if "oneOf" in schema:
        matches = 0
        for sub in schema["oneOf"]:
            if not validate(sub, instance, path):
                matches += 1
        if matches != 1:
            errors.append("%s: oneOf matched %d branches (need exactly 1)" % (path, matches))

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


def load_json_or_yaml(path):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    if path.endswith(".yaml") or path.endswith(".yml"):
        return load_yaml_subset(text)
    return json.loads(text)


def main(argv):
    if len(argv) < 2:
        print("usage: pc_validator.py <command> [args...]", file=sys.stderr)
        return 2
    cmd = argv[1]
    if cmd == "check":
        schema = load_json_or_yaml(argv[2])
        instance = load_json_or_yaml(argv[3])
        errors = validate(schema, instance)
        if errors:
            for e in errors:
                print(e, file=sys.stderr)
            return 1
        print("VALID")
        return 0
    if cmd == "delete-check":
        # Expects deletion at pointer to be REJECTED (errors non-empty).
        schema = load_json_or_yaml(argv[2])
        instance = load_json_or_yaml(argv[3])
        pointer = argv[4]
        mutated = delete_pointer(instance, pointer)
        errors = validate(schema, mutated)
        if errors:
            print("REJECTED: %s" % "; ".join(errors))
            return 0
        print("UNEXPECTEDLY VALID after deleting %s" % pointer, file=sys.stderr)
        return 1
    if cmd == "yaml-to-json":
        data = load_json_or_yaml(argv[2])
        print(json.dumps(data))
        return 0
    if cmd == "dup-check":
        instance = load_json_or_yaml(argv[2])
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

cat > "$WORK/pc_positive.json" <<'JSONEOF'
{
  "schema": "sdd-project-context/v1",
  "workflow": {
    "spec_profile": "full",
    "artifact_layout": "legacy-seven-layer",
    "capability_enforcement": "advisory"
  },
  "components": [
    {
      "id": "example-cli",
      "artifact_kinds": ["cli"],
      "runtime_classes": ["node"],
      "platform_targets": [
        {"os": "linux", "architecture": "x86_64"}
      ],
      "characteristics": {
        "pii": false,
        "ui": false,
        "auto_update": true,
        "local_persistence": true,
        "long_running": false,
        "replayable": true,
        "human_in_the_loop": false
      },
      "distribution_channels": ["npm"],
      "data_classification": ["internal"],
      "provider_binding_ids": ["example-provider"],
      "paths": {
        "include": ["src/**"],
        "exclude": ["src/**/*.test.ts"]
      }
    }
  ],
  "shared_paths": [
    {"pattern": "specs/**", "classification": "cross-cutting"}
  ]
}
JSONEOF

cat > "$WORK/pc_dup_component.json" <<'JSONEOF'
{
  "schema": "sdd-project-context/v1",
  "workflow": {"spec_profile": "full", "artifact_layout": "legacy-seven-layer", "capability_enforcement": "advisory"},
  "components": [
    {"id": "dup-id"},
    {"id": "dup-id"}
  ]
}
JSONEOF

cat > "$WORK/pb_positive.json" <<'JSONEOF'
{
  "schema": "sdd-provider-bindings/v1",
  "bindings": [
    {
      "id": "example-provider",
      "provider": "totally-invented-provider-xyz",
      "product": "widget-cloud",
      "purpose": "state storage",
      "state_authority": {"region": "us-east-1", "nested": {"a": 1}},
      "credentials": {"secret_ref": "vault://example"},
      "adapter_paths": ["adapters/**/*.ts"]
    }
  ]
}
JSONEOF

cat > "$WORK/pb_no_adapter_paths.json" <<'JSONEOF'
{
  "schema": "sdd-provider-bindings/v1",
  "bindings": [
    {
      "id": "example-provider-2",
      "provider": "another-invented-provider",
      "product": "widget-cloud",
      "purpose": "state storage"
    }
  ]
}
JSONEOF

cat > "$WORK/pb_dup_binding.json" <<'JSONEOF'
{
  "schema": "sdd-provider-bindings/v1",
  "bindings": [
    {"id": "dup-id", "provider": "p1", "product": "prod1", "purpose": "x"},
    {"id": "dup-id", "provider": "p2", "product": "prod2", "purpose": "y"}
  ]
}
JSONEOF

# ---------------------------------------------------------------------------
# TEST-001: project-context parameterized schema conformance (AC-001)
# ---------------------------------------------------------------------------

if "$PY" "$VALIDATOR" check "$PC_SCHEMA" "$WORK/pc_positive.json" >/dev/null 2>"$WORK/err"; then
  pass "TEST-001 positive fixture (full field coverage) validates"
else
  fail "TEST-001 positive fixture (full field coverage) validates: $(cat "$WORK/err")"
fi

for ptr in /schema /workflow /workflow/spec_profile /workflow/artifact_layout \
  /workflow/capability_enforcement /components/*/id \
  /components/*/platform_targets/*/os /components/*/platform_targets/*/architecture; do
  if "$PY" "$VALIDATOR" delete-check "$PC_SCHEMA" "$WORK/pc_positive.json" "$ptr" >"$WORK/out" 2>"$WORK/err"; then
    pass "TEST-001 deleting required pointer $ptr is rejected"
  else
    fail "TEST-001 deleting required pointer $ptr is rejected: $(cat "$WORK/out" "$WORK/err")"
  fi
done

# ---------------------------------------------------------------------------
# TEST-002: field-allowlist coverage — all 8 ADR-0020 paths resolve to a
# schema-defined field (AC-002).
# ---------------------------------------------------------------------------

check_allowlist_field() {
  jq_path=$1
  label=$2
  if jq -e "$jq_path" "$PC_SCHEMA" >/dev/null 2>"$WORK/err"; then
    pass "TEST-002 allowlist path $label resolves to a schema field"
  else
    fail "TEST-002 allowlist path $label resolves to a schema field: $(cat "$WORK/err")"
  fi
}

check_allowlist_field '.properties.components.items.properties.artifact_kinds' 'artifact_kinds'
check_allowlist_field '.properties.components.items.properties.runtime_classes' 'runtime_classes'
check_allowlist_field '.properties.components.items.properties.characteristics.properties.pii' 'characteristics.pii'
check_allowlist_field '.properties.components.items.properties.characteristics.properties.ui' 'characteristics.ui'
check_allowlist_field '.properties.components.items.properties.characteristics.properties.auto_update' 'characteristics.auto_update'
check_allowlist_field '.properties.components.items.properties.characteristics.properties.local_persistence' 'characteristics.local_persistence'
check_allowlist_field '.properties.components.items.properties.distribution_channels' 'distribution_channels'
check_allowlist_field '.properties.components.items.properties.data_classification' 'data_classification'

# ---------------------------------------------------------------------------
# TEST-003: provider-bindings parameterized schema conformance +
# state_authority/credentials passthrough (AC-003).
# ---------------------------------------------------------------------------

if "$PY" "$VALIDATOR" check "$PB_SCHEMA" "$WORK/pb_positive.json" >/dev/null 2>"$WORK/err"; then
  pass "TEST-003 positive fixture with state_authority/credentials passthrough validates"
else
  fail "TEST-003 positive fixture with state_authority/credentials passthrough validates: $(cat "$WORK/err")"
fi

for ptr in /schema /bindings /bindings/*/id /bindings/*/provider /bindings/*/product /bindings/*/purpose; do
  if "$PY" "$VALIDATOR" delete-check "$PB_SCHEMA" "$WORK/pb_positive.json" "$ptr" >"$WORK/out" 2>"$WORK/err"; then
    pass "TEST-003 deleting required pointer $ptr is rejected"
  else
    fail "TEST-003 deleting required pointer $ptr is rejected: $(cat "$WORK/out" "$WORK/err")"
  fi
done

# ---------------------------------------------------------------------------
# TEST-004: provider-neutrality — an invented Provider string validates,
# proving no fixed Provider enum exists (AC-004).
# ---------------------------------------------------------------------------

if jq -e '.properties.bindings.items.properties.provider.enum' "$PB_SCHEMA" >/dev/null 2>&1; then
  fail "TEST-004 no fixed Provider enum exists in the schema"
else
  pass "TEST-004 no fixed Provider enum exists in the schema"
fi

if "$PY" "$VALIDATOR" check "$PB_SCHEMA" "$WORK/pb_positive.json" >/dev/null 2>"$WORK/err"; then
  pass "TEST-004 invented provider string 'totally-invented-provider-xyz' validates"
else
  fail "TEST-004 invented provider string 'totally-invented-provider-xyz' validates: $(cat "$WORK/err")"
fi

# ---------------------------------------------------------------------------
# TEST-040: components[]/bindings[] duplicate-id semantic-validator
# rejection — DUPLICATE_COMPONENT_ID / DUPLICATE_BINDING_ID (AC-040).
# ---------------------------------------------------------------------------

# M18 proof: JSON Schema draft-07 alone cannot express array-item-key
# uniqueness — the duplicate-id fixture still validates at the plain
# schema layer.
if "$PY" "$VALIDATOR" check "$PC_SCHEMA" "$WORK/pc_dup_component.json" >/dev/null 2>"$WORK/err"; then
  pass "TEST-040 duplicate-id components[] fixture still passes plain JSON Schema (M18)"
else
  fail "TEST-040 duplicate-id components[] fixture still passes plain JSON Schema (M18): $(cat "$WORK/err")"
fi

if "$PY" "$VALIDATOR" dup-check "$WORK/pc_dup_component.json" components DUPLICATE_COMPONENT_ID >"$WORK/out" 2>"$WORK/err"; then
  pass "TEST-040 semantic-validator layer rejects duplicate components[].id (DUPLICATE_COMPONENT_ID)"
else
  fail "TEST-040 semantic-validator layer rejects duplicate components[].id (DUPLICATE_COMPONENT_ID): $(cat "$WORK/out" "$WORK/err")"
fi

if "$PY" "$VALIDATOR" check "$PB_SCHEMA" "$WORK/pb_dup_binding.json" >/dev/null 2>"$WORK/err"; then
  pass "TEST-040 duplicate-id bindings[] fixture still passes plain JSON Schema (M18)"
else
  fail "TEST-040 duplicate-id bindings[] fixture still passes plain JSON Schema (M18): $(cat "$WORK/err")"
fi

if "$PY" "$VALIDATOR" dup-check "$WORK/pb_dup_binding.json" bindings DUPLICATE_BINDING_ID >"$WORK/out" 2>"$WORK/err"; then
  pass "TEST-040 semantic-validator layer rejects duplicate bindings[].id (DUPLICATE_BINDING_ID)"
else
  fail "TEST-040 semantic-validator layer rejects duplicate bindings[].id (DUPLICATE_BINDING_ID): $(cat "$WORK/out" "$WORK/err")"
fi

# ---------------------------------------------------------------------------
# TEST-041: adapter_paths optional array-of-glob passthrough, present and
# absent (AC-041).
# ---------------------------------------------------------------------------

if "$PY" "$VALIDATOR" check "$PB_SCHEMA" "$WORK/pb_positive.json" >/dev/null 2>"$WORK/err"; then
  pass "TEST-041 bindings[] entry declaring adapter_paths validates"
else
  fail "TEST-041 bindings[] entry declaring adapter_paths validates: $(cat "$WORK/err")"
fi

if "$PY" "$VALIDATOR" check "$PB_SCHEMA" "$WORK/pb_no_adapter_paths.json" >/dev/null 2>"$WORK/err"; then
  pass "TEST-041 bindings[] entry with no adapter_paths also validates"
else
  fail "TEST-041 bindings[] entry with no adapter_paths also validates: $(cat "$WORK/err")"
fi

# ---------------------------------------------------------------------------
# TEST-042: contracts/project-context.template.yaml validates and its
# shared_paths contains all six canonical seed patterns (AC-042).
# ---------------------------------------------------------------------------

if "$PY" "$VALIDATOR" yaml-to-json "$PC_TEMPLATE" >"$WORK/template.json" 2>"$WORK/err"; then
  pass "TEST-042 project-context.template.yaml parses"
else
  fail "TEST-042 project-context.template.yaml parses: $(cat "$WORK/err")"
fi

if "$PY" "$VALIDATOR" check "$PC_SCHEMA" "$WORK/template.json" >/dev/null 2>"$WORK/err"; then
  pass "TEST-042 project-context.template.yaml validates against the schema"
else
  fail "TEST-042 project-context.template.yaml validates against the schema: $(cat "$WORK/err")"
fi

for seed_pattern in 'specs/**' 'reports/**' 'docs/**' '.github/**' 'tests/fixtures/**' 'CHANGELOG.md'; do
  if jq -e --arg p "$seed_pattern" \
    '.shared_paths | map(select(.pattern == $p and .classification == "cross-cutting")) | length == 1' \
    "$WORK/template.json" >/dev/null 2>"$WORK/err"; then
    pass "TEST-042 shared_paths contains cross-cutting seed pattern '$seed_pattern'"
  else
    fail "TEST-042 shared_paths contains cross-cutting seed pattern '$seed_pattern': $(cat "$WORK/err")"
  fi
done

if jq -e '.shared_paths | length == 6' "$WORK/template.json" >/dev/null 2>"$WORK/err"; then
  pass "TEST-042 shared_paths contains exactly the six canonical seed patterns"
else
  fail "TEST-042 shared_paths contains exactly the six canonical seed patterns: $(cat "$WORK/err")"
fi

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
[ "$FAIL" -eq 0 ]
