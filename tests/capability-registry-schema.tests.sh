#!/usr/bin/env bash
# Schema-conformance suite for contracts/capability-registry.schema.json
# (T-001, REQ-001). Mirrors the workflow-state-registry.tests.sh convention:
# the schema's rules are re-expressed as an independent jq predicate rather
# than interpreted generically, so this suite is a second, independent
# implementation of the schema's constraints, not a re-run of the schema
# file itself.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
INSTANCE="$ROOT/contracts/capability-registry.json"
SCHEMA="$ROOT/contracts/capability-registry.schema.json"
FIXTURES="$ROOT/tests/fixtures/capability-registry"

fail() { printf 'not ok: %s\n' "$1" >&2; exit 1; }

# --- jq predicate library -------------------------------------------------
# strict_schema_accepts mirrors contracts/capability-registry.schema.json's
# rules exactly (an independent re-implementation, per Test Strategy item 5).
# permissive_schema_accepts is a deliberately weak stand-in schema used only
# to produce RED evidence: it proves the reject fixtures are not vacuously
# malformed and that the strict predicate's specific rules are what reject
# them, not merely "any invalid JSON is rejected".

JQ_LIB='
def keys_within($allowed): (keys - $allowed) | length == 0;
def has_all($required): ($required - keys) | length == 0;

def is_predicate:
  type == "object" and
  (
    ( (keys == ["all"]) and (.all | type == "array") and (.all | map(is_predicate) | all) )
    or
    ( (keys == ["any"]) and (.any | type == "array") and (.any | map(is_predicate) | all) )
    or
    ( (keys == ["not"]) and (.not | is_predicate) )
    or
    (
      keys_within(["scope","field","operator","value"]) and
      has_all(["scope","field","operator"]) and
      .scope == "affected_component" and
      (.field as $f | ["artifact_kinds","runtime_classes","characteristics.pii",
        "characteristics.ui","characteristics.auto_update",
        "characteristics.local_persistence","distribution_channels",
        "data_classification"] | index($f) != null) and
      (.operator as $o | ["equals","not_equals","contains","in","exists"] | index($o) != null) and
      (if .operator == "exists" then true else has("value") end)
    )
  );

def is_gate:
  type == "object" and
  keys_within(["id","stage","blocking","implementation_ref"]) and
  has_all(["id","stage","blocking"]) and
  (.id | type == "string" and test("^[a-z0-9][a-z0-9-]*$")) and
  (.stage as $s | ["implementation","artifact","promotion"] | index($s) != null) and
  (.blocking | type == "boolean") and
  (if has("implementation_ref") then (.implementation_ref | type == "string" and length > 0) else true end) and
  (if .stage == "implementation" then has("implementation_ref") else true end);

def is_conditional_facet:
  type == "object" and
  keys_within(["facet","when"]) and
  has_all(["facet","when"]) and
  (.facet | type == "string") and
  (.when | is_predicate);

def is_lite_policy:
  type == "object" and
  keys_within(["eligible","upgrade_reasons"]) and
  has_all(["eligible"]) and
  (.eligible | type == "boolean") and
  (if has("upgrade_reasons") then
    (.upgrade_reasons | type == "array" and all(.[]; type == "string" and length > 0))
  else true end);

def is_delivery_strategy:
  type == "object" and
  keys_within(["kind"]) and
  has_all(["kind"]) and
  (.kind | type == "string" and length > 0);

def is_capability:
  type == "object" and
  keys_within(["id","trigger","required_facets","conditional_facets",
    "review_check_ids","gate_ids","lite_policy","minimum_enforcement",
    "delivery_strategy"]) and
  has_all(["id","trigger","required_facets","conditional_facets",
    "review_check_ids","gate_ids","delivery_strategy"]) and
  (.id | type == "string" and test("^[a-z0-9][a-z0-9-]*$")) and
  (.trigger | is_predicate) and
  (.required_facets | type == "array" and length == (unique | length) and all(.[]; type == "string")) and
  (.conditional_facets | type == "array" and all(.[]; is_conditional_facet)) and
  (.review_check_ids | type == "array" and length == (unique | length) and all(.[]; type == "string" and length > 0)) and
  (.gate_ids | type == "array" and length == (unique | length) and all(.[]; type == "string")) and
  (if has("lite_policy") then (.lite_policy | is_lite_policy) else true end) and
  (if has("minimum_enforcement") then .minimum_enforcement == "required" else true end) and
  (.delivery_strategy | is_delivery_strategy);

def strict_schema_accepts:
  type == "object" and
  keys_within(["schema","gates","capabilities"]) and
  has_all(["schema","gates","capabilities"]) and
  .schema == "capability-registry/v1" and
  (.gates | type == "array" and all(.[]; is_gate)) and
  (.capabilities | type == "array" and all(.[]; is_capability));

def permissive_schema_accepts:
  type == "object" and
  has("schema") and has("gates") and has("capabilities") and
  (.gates | type == "array") and
  (.capabilities | type == "array");
'

strict_schema_accepts() {
  jq -e "$JQ_LIB"' strict_schema_accepts' "$1" >/dev/null 2>&1
}

permissive_schema_accepts() {
  jq -e "$JQ_LIB"' permissive_schema_accepts' "$1" >/dev/null 2>&1
}

accept_fixtures() {
  find "$FIXTURES" -maxdepth 1 -name 'schema-accept-*.json' | LC_ALL=C sort
}

reject_fixtures() {
  find "$FIXTURES" -maxdepth 1 -name 'schema-reject-*.json' | LC_ALL=C sort
}

# --- RED mode --------------------------------------------------------------
# Proves the reject fixtures are not vacuous: each one is wrongly *accepted*
# by the deliberately permissive stand-in schema, so a naive/incomplete
# schema would silently miss the defect the strict predicate below catches.
if [[ "${1:-}" == "--red-check" ]]; then
  count=0
  while IFS= read -r fixture; do
    permissive_schema_accepts "$fixture" ||
      fail "RED precondition violated: $(basename "$fixture") is rejected even by the permissive stand-in schema"
    printf 'RED: %s wrongly accepted by permissive schema (expected)\n' "$(basename "$fixture")"
    count=$((count + 1))
  done < <(reject_fixtures)
  [[ "$count" -gt 0 ]] || fail "no reject fixtures found for RED check"
  printf 'RED check complete: %d reject fixtures pass under the permissive schema.\n' "$count"
  exit 0
fi

# --- GREEN: strict schema-conformance suite --------------------------------

[[ -f "$SCHEMA" ]] || fail "schema missing"
[[ -f "$INSTANCE" ]] || fail "instance missing"

# TEST-001: base schema validates the canonical Registry instance.
strict_schema_accepts "$INSTANCE" || fail "canonical capability-registry.json fails strict schema check"

# The schema file itself must be valid JSON and declare draft-07 + the
# capability-registry/v1 $id/title conventions (AC-001).
jq -e '
  .["$schema"] == "http://json-schema.org/draft-07/schema#" and
  (.["$id"] | test("capability-registry.schema.json$")) and
  (.definitions.predicate != null)
' "$SCHEMA" >/dev/null || fail "schema file missing draft-07/$id/predicate-definition conventions"

# AC-006: no top-level "conditions" property/field anywhere in the schema file.
jq -e '[.. | objects | keys[]? ] | index("conditions") == null' "$SCHEMA" >/dev/null ||
  fail "schema file defines a forbidden top-level 'conditions' field (AC-006)"

# Accept fixtures: every one must validate (TEST-001, TEST-002 positive,
# TEST-003 positive, TEST-004 positive/open-kind, TEST-005 positive/
# optionality, TEST-037/TEST-038 positive/empty-array cases).
accept_count=0
while IFS= read -r fixture; do
  strict_schema_accepts "$fixture" || fail "$(basename "$fixture") unexpectedly rejected by strict schema check"
  accept_count=$((accept_count + 1))
done < <(accept_fixtures)
[[ "$accept_count" -ge 6 ]] || fail "expected at least 6 accept fixtures, found $accept_count"

# Reject fixtures: every one must be rejected (TEST-002 negative, TEST-003
# negative, TEST-004 negative x2, TEST-005 negative, TEST-006,
# TEST-037/TEST-038 negative cases, plus general additionalProperties:false
# coverage at the top level and inside gates[]).
reject_count=0
while IFS= read -r fixture; do
  if strict_schema_accepts "$fixture"; then
    fail "$(basename "$fixture") unexpectedly accepted by strict schema check"
  fi
  reject_count=$((reject_count + 1))
done < <(reject_fixtures)
[[ "$reject_count" -ge 16 ]] || fail "expected at least 16 reject fixtures, found $reject_count"

# Self-registration check (Suite/CI registration Done-When item).
grep -q 'tests/capability-registry-schema.tests.sh' "$ROOT/tests/run-all.sh" ||
  fail "suite not registered in tests/run-all.sh"
grep -q 'tests/capability-registry-schema.tests.ps1' "$ROOT/tests/run-all.ps1" ||
  fail "suite not registered in tests/run-all.ps1"

# Human-copy staged CI candidate + MANIFEST (Protected-File Statement /
# Done-When "Suite/CI registration" item). The real .github/workflows/test.yml
# is never touched directly; only the staged human-copy candidate is checked
# here, plus its MANIFEST.sha256 entry.
HUMAN_COPY_DIR="$ROOT/specs/epic-190-a2-capability-registry/human-copy"
STAGED_WORKFLOW="$HUMAN_COPY_DIR/.github/workflows/test.yml"
STAGED_MANIFEST="$HUMAN_COPY_DIR/MANIFEST.sha256"
[[ -f "$STAGED_WORKFLOW" ]] || fail "human-copy: staged .github/workflows/test.yml candidate missing"
[[ -f "$STAGED_MANIFEST" ]] || fail "human-copy: MANIFEST.sha256 missing"
grep -q 'tests/capability-registry-schema.tests.sh' "$STAGED_WORKFLOW" ||
  fail "human-copy: staged workflow candidate omits this suite's bash CI step"
grep -q 'tests/capability-registry-schema.tests.ps1' "$STAGED_WORKFLOW" ||
  fail "human-copy: staged workflow candidate omits this suite's pwsh CI step"
staged_hash="$(shasum -a 256 "$STAGED_WORKFLOW" | awk '{print $1}')"
manifest_hash="$(grep -F 'workflows/test.yml' "$STAGED_MANIFEST" | awk '{print $1}')"
[[ -n "$manifest_hash" ]] || fail "human-copy: MANIFEST.sha256 has no entry for the staged workflow candidate"
[[ "$staged_hash" == "$manifest_hash" ]] ||
  fail "human-copy: staged workflow candidate sha256 does not match its MANIFEST.sha256 entry"

printf 'capability-registry-schema: %d accept + %d reject fixtures pass; canonical instance valid.\n' \
  "$accept_count" "$reject_count"
