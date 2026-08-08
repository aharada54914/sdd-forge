#!/usr/bin/env bash
# component-path-resolver.tests.sh — epic-191-a3-path-ownership T-001.
# Exercises resolve-component-paths.sh (the dispatcher; goes through
# resolve-component-paths.py on any host with python3) against the fixture
# tree at tests/fixtures/component-path-ownership/, independently proving
# each glob-matching clause id (REQ-001, AC-001..AC-011) and each
# classification/Fail rule (REQ-002, AC-012..AC-018), per
# specs/epic-191-a3-path-ownership/tasks.md T-001 Done When.
#
# TEST-011 schema conformance is fail-closed: both the JSON Schema contract
# and its canonical YAML template must exist and match the parser contract.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SCRIPT="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/resolve-component-paths.sh"
FIXTURES="${REPO_ROOT}/tests/fixtures/component-path-ownership"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

# jq output is unconditionally scrubbed of CR bytes per Global Constraints'
# CI-resilience convention (Windows-authored fixture round-trips).
jqf() { jq "$@" | tr -d '\r'; }

resolve() {
  # $1 = config path, $2 = changed-paths file (may not exist -> stdin empty)
  if [ -f "$2" ]; then
    "$SCRIPT" --config "$1" --changed-paths-file "$2"
  else
    printf '' | "$SCRIPT" --config "$1"
  fi
}

classification_of() {
  # $1 = json output, $2 = raw_path
  printf '%s' "$1" | jqf -r --arg p "$2" '.records[] | select(.raw_path == $p) | .classification'
}

# ============================================================================
# TEST-001 (AC-001): ** crosses "/" boundaries, including the direct case
# ============================================================================
echo "=== TEST-001: ** crosses / boundaries ==="
out=$(resolve "${FIXTURES}/test-001-doublestar/config.yaml" "${FIXTURES}/test-001-doublestar/changed-paths.txt")
[ "$(classification_of "$out" "src/desktop/file.ts")" = "EXCLUSIVE" ] \
  && ok "TEST-001.1: src/desktop/** matches src/desktop/file.ts (direct child)" \
  || fail "TEST-001.1: expected EXCLUSIVE for src/desktop/file.ts"
[ "$(classification_of "$out" "src/desktop/sub/deep/file.ts")" = "EXCLUSIVE" ] \
  && ok "TEST-001.2: src/desktop/** matches src/desktop/sub/deep/file.ts (nested, crosses /)" \
  || fail "TEST-001.2: expected EXCLUSIVE for nested path"

# ============================================================================
# TEST-002 (AC-002): bare * confined to one segment, never crosses "/"
# ============================================================================
echo "=== TEST-002: bare * confined to one path segment ==="
out=$(resolve "${FIXTURES}/test-002-singlestar/config.yaml" "${FIXTURES}/test-002-singlestar/changed-paths.txt")
[ "$(classification_of "$out" "src/file.ts")" = "EXCLUSIVE" ] \
  && ok "TEST-002.1: src/*.ts matches src/file.ts" \
  || fail "TEST-002.1: expected EXCLUSIVE for src/file.ts"
[ "$(classification_of "$out" "src/sub/file.ts")" = "UNOWNED" ] \
  && ok "TEST-002.2: src/*.ts does NOT match src/sub/file.ts (bare * never crosses /)" \
  || fail "TEST-002.2: expected UNOWNED for src/sub/file.ts"

# ============================================================================
# TEST-003 (AC-003): backslash-authored pattern normalizes identically to /
# ============================================================================
echo "=== TEST-003: backslash pattern normalization ==="
out=$(resolve "${FIXTURES}/test-003-backslash/config.yaml" "${FIXTURES}/test-003-backslash/changed-paths.txt")
[ "$(classification_of "$out" "src/desktop/file.ts")" = "EXCLUSIVE" ] \
  && ok "TEST-003.1: backslash-separated pattern matches slash-separated path" \
  || fail "TEST-003.1: expected EXCLUSIVE via backslash-normalized pattern"

# ============================================================================
# TEST-004 (AC-004): NFD-encoded path matches NFC-encoded pattern (matching
# only — see TEST-010 for raw-identity preservation)
# ============================================================================
echo "=== TEST-004: NFC-normalized matching ==="
out=$(resolve "${FIXTURES}/test-004-nfc-match/config.yaml" "${FIXTURES}/test-004-nfc-match/changed-paths.txt")
count=$(printf '%s' "$out" | jqf -r '.records | length')
cls=$(printf '%s' "$out" | jqf -r '.records[0].classification')
[ "$count" = "1" ] && [ "$cls" = "EXCLUSIVE" ] \
  && ok "TEST-004.1: NFD-encoded raw path matches NFC-encoded 'café/**' pattern" \
  || fail "TEST-004.1: expected exactly 1 EXCLUSIVE record, got count=$count cls=$cls"

# ============================================================================
# TEST-005 (AC-005): byte-wise case-sensitive matching regardless of host OS
# ============================================================================
echo "=== TEST-005: case-sensitive matching ==="
out=$(resolve "${FIXTURES}/test-005-case-sensitive/config.yaml" "${FIXTURES}/test-005-case-sensitive/changed-paths.txt")
[ "$(classification_of "$out" "Src/file.ts")" = "EXCLUSIVE" ] \
  && ok "TEST-005.1: 'Src/**' matches 'Src/file.ts'" \
  || fail "TEST-005.1: expected EXCLUSIVE for Src/file.ts"
[ "$(classification_of "$out" "src/file.ts")" = "UNOWNED" ] \
  && ok "TEST-005.2: 'Src/**' does NOT match 'src/file.ts' (case differs)" \
  || fail "TEST-005.2: expected UNOWNED for src/file.ts (case-sensitive miss)"

# ============================================================================
# TEST-006 (AC-006): unsupported glob metacharacters rejected fail-closed at
# config-load time
# ============================================================================
echo "=== TEST-006: unsupported metacharacter rejected fail-closed ==="
set +e
err=$(printf '' | "$SCRIPT" --config "${FIXTURES}/test-006-unsupported-metachar/config.yaml" 2>&1)
code=$?
set -e
if [ "$code" -ne 0 ] && printf '%s' "$err" | grep -q "unsupported glob metacharacter"; then
  ok "TEST-006.1: '[abc]' pattern rejected fail-closed at load time (exit $code)"
else
  fail "TEST-006.1: expected non-zero exit + diagnostic, got exit=$code err=$err"
fi

QUESTION_CONFIG=$(mktemp)
printf '%s\n' 'components:' '  - id: c1' '    paths:' '      include:' '        - "src/?.ts"' > "$QUESTION_CONFIG"
set +e
err=$(printf '' | "$SCRIPT" --config "$QUESTION_CONFIG" 2>&1)
code=$?
set -e
rm -f "$QUESTION_CONFIG"
if [ "$code" -ne 0 ] && printf '%s' "$err" | grep -q "unsupported glob metacharacter"; then
  ok "TEST-006.2: '?' pattern rejected fail-closed at load time (exit $code)"
else
  fail "TEST-006.2: expected non-zero exit + diagnostic, got exit=$code err=$err"
fi

# ============================================================================
# TEST-007 (AC-007): "**" zero-segment case — a/**/b matches literal a/b
# ============================================================================
echo "=== TEST-007: ** zero-segment case ==="
out=$(resolve "${FIXTURES}/test-007-zero-segment/config.yaml" "${FIXTURES}/test-007-zero-segment/changed-paths.txt")
[ "$(classification_of "$out" "a/b")" = "EXCLUSIVE" ] \
  && ok "TEST-007.1: 'a/**/b' matches literal 'a/b' (zero intervening segments)" \
  || fail "TEST-007.1: expected EXCLUSIVE for a/b"
[ "$(classification_of "$out" "a/x/b")" = "EXCLUSIVE" ] \
  && ok "TEST-007.2: 'a/**/b' also matches 'a/x/b' (one intervening segment)" \
  || fail "TEST-007.2: expected EXCLUSIVE for a/x/b"
[ "$(classification_of "$out" "a/c")" = "UNOWNED" ] \
  && ok "TEST-007.3: 'a/**/b' does not match unrelated 'a/c'" \
  || fail "TEST-007.3: expected UNOWNED for a/c"

# ============================================================================
# TEST-008 (AC-008): empty changed-paths resolves vacuously; a component
# with an empty include list is a config-load-time error (never conflated
# with a runtime UNOWNED result)
# ============================================================================
echo "=== TEST-008: empty-set clauses ==="
out=$(resolve "${FIXTURES}/test-008-empty-sets/config.yaml" "${FIXTURES}/test-008-empty-sets/changed-paths.txt")
count=$(printf '%s' "$out" | jqf -r '.records | length')
[ "$count" = "0" ] \
  && ok "TEST-008.1: empty changed-paths diff resolves vacuously (0 records, no error)" \
  || fail "TEST-008.1: expected 0 records for empty diff, got $count"

set +e
err=$(printf '' | "$SCRIPT" --config "${FIXTURES}/test-008-empty-include/config.yaml" 2>&1)
code=$?
set -e
if [ "$code" -ne 0 ] && printf '%s' "$err" | grep -q "empty paths.include"; then
  ok "TEST-008.2: component with empty include list is a config-load-time error"
else
  fail "TEST-008.2: expected non-zero exit + empty-include diagnostic, got exit=$code err=$err"
fi

# ============================================================================
# TEST-009 (AC-009): a shared_paths entry matching zero changed paths in a
# given resolve triggers no crash / no special record (Fail-4 needs an
# actual match — Fail-4 itself is T-004's Gate concern, not this resolver's)
# ============================================================================
echo "=== TEST-009: shared_paths zero-match this resolve ==="
out=$(resolve "${FIXTURES}/test-009-shared-zero-match/config.yaml" "${FIXTURES}/test-009-shared-zero-match/changed-paths.txt")
[ "$(classification_of "$out" "a/file.ts")" = "EXCLUSIVE" ] \
  && ok "TEST-009.1: a shared_paths entry that matches nothing this resolve does not disturb ordinary classification" \
  || fail "TEST-009.1: expected EXCLUSIVE for a/file.ts"

# ============================================================================
# TEST-010 (AC-010): NFC-collision fail-closed + raw-identity preservation +
# stable sort over raw path bytes
# ============================================================================
echo "=== TEST-010: NFC collision, raw identity, stable sort ==="
set +e
err=$(resolve "${FIXTURES}/test-010-nfc-collision/config.yaml" "${FIXTURES}/test-010-nfc-collision/changed-paths.txt" 2>&1)
code=$?
set -e
if [ "$code" -ne 0 ] && printf '%s' "$err" | grep -q "NFC-normalization collision"; then
  ok "TEST-010.1: two distinct raw paths differing only in NFC/NFD form are rejected fail-closed"
else
  fail "TEST-010.1: expected non-zero exit + collision diagnostic, got exit=$code err=$err"
fi

out=$(resolve "${FIXTURES}/test-004-nfc-match/config.yaml" "${FIXTURES}/test-004-nfc-match/changed-paths.txt")
# `jq -r` always appends its own trailing newline to raw string output; the
# fixture file's single line also ends in one trailing "\n" byte — so
# comparing both od dumps as-is (neither side stripped) is the correct,
# symmetric byte comparison here.
raw_bytes=$(printf '%s' "$out" | jqf -r '.records[0].raw_path' | od -An -tx1 | tr -d ' \n')
orig_bytes=$(od -An -tx1 "${FIXTURES}/test-004-nfc-match/changed-paths.txt" | tr -d ' \n')
if [ "$raw_bytes" = "$orig_bytes" ]; then
  ok "TEST-010.2: output raw_path preserves the original NFD byte sequence exactly (not the NFC comparison key)"
else
  fail "TEST-010.2: raw_path bytes diverged from the source fixture's original bytes"
fi

out=$(resolve "${FIXTURES}/test-010b-stable-sort/config.yaml" "${FIXTURES}/test-010b-stable-sort/changed-paths.txt")
order=$(printf '%s' "$out" | jqf -r '[.records[].raw_path] | join(",")')
[ "$order" = "A/upper.ts,a/lower.ts,z/last.ts,é/nonascii.ts" ] \
  && ok "TEST-010.3: output records are sorted by a stable, ordinal sort over raw path bytes" \
  || fail "TEST-010.3: expected raw UTF-8 byte order A,a,z,é, got '$order'"

# ============================================================================
# TEST-011 (AC-011): A1 schema conformance — FAIL-closed on absence, never a
# skip; validates field-name/type/version conformance when present.
# ============================================================================
echo "=== TEST-011: A1 schema-conformance fixture ==="
set +e
out=$(printf '' | "$SCRIPT" --check-schema-conformance --schema "${FIXTURES}/nonexistent-schema.yaml" 2>&1)
code=$?
set -e
if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '"conformant": false'; then
  ok "TEST-011.1: schema-conformance check reports fail-closed non-zero when the artifact is absent (behavior proof)"
else
  fail "TEST-011.1: expected non-zero + conformant:false for an absent schema artifact"
fi

CONFORMANT_SCHEMA="$(mktemp -d)"
CONFORMANT_SCHEMA_ROOT="$(cd "$CONFORMANT_SCHEMA" && pwd -P)"
cat > "${CONFORMANT_SCHEMA_ROOT}/schema.yaml" << 'EOF'
schema: sdd-project-context/v1
components: []
shared_paths:
  - pattern: "specs/**"
    classification: cross-cutting
  - pattern: "contracts/**"
    components:
      - example
EOF
cat > "${CONFORMANT_SCHEMA_ROOT}/schema.json" << 'EOF'
{
  "properties": {
    "schema": {"const": "sdd-project-context/v1"},
    "components": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "paths"],
        "properties": {
          "id": {"type": "string"},
          "paths": {"type": "object", "properties": {
            "include": {"type": "array", "items": {"type": "string"}},
            "exclude": {"type": "array", "items": {"type": "string"}}
          }}
        }
      }
    },
    "shared_paths": {"type": "array", "items": {
      "type": "object",
      "required": ["pattern"],
      "oneOf": [
        {"required": ["components"], "properties": {"components": {"type": "array", "items": {"type": "string"}}}},
        {"required": ["classification"], "properties": {"classification": {"const": "cross-cutting"}}}
      ]
    }}
  }
}
EOF
set +e
out=$(printf '' | "$SCRIPT" --check-schema-conformance \
  --schema "${CONFORMANT_SCHEMA_ROOT}/schema.yaml" \
  --schema-contract "${CONFORMANT_SCHEMA_ROOT}/schema.json" 2>&1)
code=$?
set -e
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -q '"conformant": true'; then
  ok "TEST-011.2: exact schema version/types and canonical components: [] report conformant:true"
else
  fail "TEST-011.2: expected exact version/types plus components: [] to conform, got code=$code out=$out"
fi

sed 's/sdd-project-context\/v1/sdd-project-context\/v2/' \
  "${CONFORMANT_SCHEMA_ROOT}/schema.yaml" > "${CONFORMANT_SCHEMA_ROOT}/wrong-version.yaml"
set +e
out=$(printf '' | "$SCRIPT" --check-schema-conformance \
  --schema "${CONFORMANT_SCHEMA_ROOT}/wrong-version.yaml" \
  --schema-contract "${CONFORMANT_SCHEMA_ROOT}/schema.json" 2>&1)
code=$?
set -e
if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '"conformant": false'; then
  ok "TEST-011.2a: wrong project-context schema version is rejected fail-closed"
else
  fail "TEST-011.2a: wrong project-context schema version was not rejected"
fi

sed 's/"type": "string"/"type": "number"/' \
  "${CONFORMANT_SCHEMA_ROOT}/schema.json" > "${CONFORMANT_SCHEMA_ROOT}/wrong-types.json"
set +e
out=$(printf '' | "$SCRIPT" --check-schema-conformance \
  --schema "${CONFORMANT_SCHEMA_ROOT}/schema.yaml" \
  --schema-contract "${CONFORMANT_SCHEMA_ROOT}/wrong-types.json" 2>&1)
code=$?
set -e
if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '"conformant": false'; then
  ok "TEST-011.2b: divergent project-context field types are rejected fail-closed"
else
  fail "TEST-011.2b: divergent project-context field types were not rejected"
fi

sed 's/"id":/"ID":/' \
  "${CONFORMANT_SCHEMA_ROOT}/schema.json" > "${CONFORMANT_SCHEMA_ROOT}/wrong-field-name.json"
set +e
out=$(printf '' | "$SCRIPT" --check-schema-conformance \
  --schema "${CONFORMANT_SCHEMA_ROOT}/schema.yaml" \
  --schema-contract "${CONFORMANT_SCHEMA_ROOT}/wrong-field-name.json" 2>&1)
code=$?
set -e
rm -rf "$CONFORMANT_SCHEMA_ROOT"
if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '"conformant": false'; then
  ok "TEST-011.2c: mis-cased schema-contract field name is rejected fail-closed"
else
  fail "TEST-011.2c: mis-cased schema-contract field name was not rejected"
fi

# TEST-011.3 — Epic A1's canonical artifacts have LANDED (merged to main),
# so this is now an ordinary green assertion on the real contract, not the
# documented expected-RED it was while A1 was outstanding. AC-011 still
# requires it to FAIL closed (never skip, never pass via a stand-in) if the
# artifact ever goes missing again — TEST-011.6 below is the positive
# control proving that fail-closed path is still live.
set +e
out=$(printf '' | "$SCRIPT" --check-schema-conformance 2>&1)
code=$?
set -e
if [ "$code" -eq 0 ]; then
  ok "TEST-011.3: contracts/project-context.template.yaml conforms against A1's landed contract"
else
  fail "TEST-011.3: A1's landed template no longer conforms: $out"
fi

# TEST-011.4 (AC-011) — the substantive schema-conformance assertion: A1's
# template is validated as an INSTANCE against contracts/project-context.schema.json,
# not merely parsed and shape-checked. Before this, no A3 script referenced
# A1's JSON Schema at all, so AC-011's "schema conformance" framing was
# never actually performed.
set +e
out=$(printf '' | "$SCRIPT" --check-schema-conformance 2>&1)
code=$?
set -e
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -q 'validates against contracts/project-context.schema.json'; then
  ok "TEST-011.4: A1's template is validated as an instance against contracts/project-context.schema.json"
else
  fail "TEST-011.4: schema-conformance did not perform instance validation against A1's JSON Schema: $out"
fi

# TEST-011.5 (AC-011) — negative control for TEST-011.4: an instance that
# violates A1's schema is rejected fail-closed. Uses the exact legacy shape
# this epic diverged on (`name` instead of A1's required `id`, which A1
# rejects under "additionalProperties": false).
INSTANCE_VIOLATION=$(mktemp)
cat > "$INSTANCE_VIOLATION" << 'EOF'
schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: legacy-seven-layer
  capability_enforcement: advisory
components:
  - name: legacy-keyed-component
    paths:
      include:
        - "src/c1/**"
shared_paths:
  - pattern: "specs/**"
    classification: cross-cutting
EOF
set +e
out=$(printf '' | "$SCRIPT" --check-schema-conformance --schema "$INSTANCE_VIOLATION" 2>&1)
code=$?
set -e
rm -f "$INSTANCE_VIOLATION"
if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q "missing required field 'id'"; then
  ok "TEST-011.5: an instance violating A1's schema (legacy 'name' key) is rejected fail-closed"
else
  fail "TEST-011.5: a schema-violating instance was not rejected: $out"
fi

# TEST-011.6 (AC-011) — positive control that the FAIL-closed-on-absence
# discipline is still live now that the artifact exists (the old inline
# `[ ! -f ]` expected-failure branches are gone; absence must still be red,
# never a skip).
set +e
out=$(printf '' | "$SCRIPT" --check-schema-conformance \
  --schema "${REPO_ROOT}/contracts/does-not-exist.template.yaml" 2>&1)
code=$?
set -e
if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '"conformant": false'; then
  ok "TEST-011.6: an absent schema artifact still FAILS closed (never a skip)"
else
  fail "TEST-011.6: absent schema artifact did not fail closed: $out"
fi

# TEST-011.7: the ordinary resolve path enforces A1's canonical `id` field,
# not only the special schema-conformance path.
LEGACY_CONFIG_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/component-path-legacy.XXXXXX")
legacy_key='na'
legacy_key="${legacy_key}me"
cat > "${LEGACY_CONFIG_ROOT}/config.yaml" <<EOF
schema: sdd-project-context/v1
components:
  - ${legacy_key}: legacy-component
    paths:
      include:
        - "src/**"
shared_paths: []
EOF
set +e
out=$(printf '' | "$SCRIPT" --config "${LEGACY_CONFIG_ROOT}/config.yaml" 2>&1)
code=$?
set -e
rm -rf "$LEGACY_CONFIG_ROOT"
if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q "legacy 'name' is not supported"; then
  ok "TEST-011.7: ordinary resolve rejects the pre-A1 legacy name field"
else
  fail "TEST-011.7: ordinary resolve accepted legacy name, exit=$code out=$out"
fi

# TEST-011.8: the canonical declaration is preserved in ownership_input for
# the later digest-binding task; it must not be rewritten to the pre-A1 key.
out=$(resolve "${FIXTURES}/test-012-exclusive/config.yaml" "${FIXTURES}/test-012-exclusive/changed-paths.txt")
if printf '%s' "$out" | jqf -e '.ownership_input.components[0] | has("id") and (has("na" + "me") | not)' >/dev/null; then
  ok "TEST-011.8: ownership_input preserves canonical component id"
else
  fail "TEST-011.8: ownership_input rewrote canonical component id: $out"
fi

# ============================================================================
# TEST-012 (AC-012): single-component (include - exclude) match -> EXCLUSIVE
# ============================================================================
echo "=== TEST-012: EXCLUSIVE classification ==="
out=$(resolve "${FIXTURES}/test-012-exclusive/config.yaml" "${FIXTURES}/test-012-exclusive/changed-paths.txt")
[ "$(classification_of "$out" "src/c1/file.ts")" = "EXCLUSIVE" ] \
  && ok "TEST-012.1: single-component match classifies EXCLUSIVE" \
  || fail "TEST-012.1: expected EXCLUSIVE"
owner=$(printf '%s' "$out" | jqf -r '.records[0].owning_components[0]')
[ "$owner" = "c1" ] \
  && ok "TEST-012.2: EXCLUSIVE record names the owning component" \
  || fail "TEST-012.2: expected owning_components == [c1], got $owner"

# ============================================================================
# TEST-013/TEST-014 (AC-013/AC-014): Fail-5 exclude-as-include invariant +
# EXCLUDED_MATCH evidence tag
# ============================================================================
echo "=== TEST-013/014: exclude invariant + EXCLUDED_MATCH evidence ==="
out=$(resolve "${FIXTURES}/test-013-014-exclude-invariant/config.yaml" "${FIXTURES}/test-013-014-exclude-invariant/changed-paths.txt")
[ "$(classification_of "$out" "src/c1/generated/x.ts")" = "UNOWNED" ] \
  && ok "TEST-013.1: a path inside C's own exclude is never attributed to C, even though include also matched" \
  || fail "TEST-013.1: expected UNOWNED (Fail-5 invariant)"
evidence_comp=$(printf '%s' "$out" | jqf -r '.records[0].evidence.excluded_match[0].component')
evidence_pattern=$(printf '%s' "$out" | jqf -r '.records[0].evidence.excluded_match[0].pattern')
[ "$evidence_comp" = "c1" ] && [ "$evidence_pattern" = "src/c1/generated/**" ] \
  && ok "TEST-014.1: the UNOWNED record carries an EXCLUDED_MATCH evidence tag naming the excluding component + pattern" \
  || fail "TEST-014.1: expected excluded_match evidence [c1, src/c1/generated/**], got [$evidence_comp, $evidence_pattern]"

# ============================================================================
# TEST-015 (AC-015): zero-component match, no shared_paths -> UNOWNED
# (ordinary case: no EXCLUDED_MATCH evidence, since no include ever matched)
# ============================================================================
echo "=== TEST-015: UNOWNED (Fail-1), ordinary case ==="
out=$(resolve "${FIXTURES}/test-015-unowned/config.yaml" "${FIXTURES}/test-015-unowned/changed-paths.txt")
[ "$(classification_of "$out" "unrelated/file.txt")" = "UNOWNED" ] \
  && ok "TEST-015.1: a path matching no component's include classifies UNOWNED" \
  || fail "TEST-015.1: expected UNOWNED"
evidence=$(printf '%s' "$out" | jqf -r '.records[0].evidence.excluded_match')
[ "$evidence" = "null" ] \
  && ok "TEST-015.2: an ordinary UNOWNED record (no include ever matched) carries no EXCLUDED_MATCH evidence" \
  || fail "TEST-015.2: expected excluded_match == null, got $evidence"

# ============================================================================
# TEST-016 (AC-016): two-or-more-component match, no shared_paths -> OVERLAP
# ============================================================================
echo "=== TEST-016: OVERLAP (Fail-3) ==="
out=$(resolve "${FIXTURES}/test-016-overlap/config.yaml" "${FIXTURES}/test-016-overlap/changed-paths.txt")
[ "$(classification_of "$out" "shared/x.ts")" = "OVERLAP" ] \
  && ok "TEST-016.1: a path matching two components' include classifies OVERLAP" \
  || fail "TEST-016.1: expected OVERLAP"
owners=$(printf '%s' "$out" | jqf -c -r '.records[0].owning_components | sort')
[ "$owners" = '["c1","c2"]' ] \
  && ok "TEST-016.2: OVERLAP record names every residual owner" \
  || fail "TEST-016.2: expected owning_components == [c1,c2], got $owners"

# ============================================================================
# TEST-017 (AC-017): shared_paths match exempts from OVERLAP/UNOWNED
# classification regardless of how many component includes also match
# ============================================================================
echo "=== TEST-017: shared_paths exemption ==="
out=$(resolve "${FIXTURES}/test-017-shared-exempt/config.yaml" "${FIXTURES}/test-017-shared-exempt/changed-paths.txt")
[ "$(classification_of "$out" "contracts/zero.json")" = "SHARED_CROSS_CUTTING" ] \
  && ok "TEST-017.1: shared_paths precedence applies with zero matching component includes" \
  || fail "TEST-017.1: expected SHARED_CROSS_CUTTING with zero owners"
[ "$(classification_of "$out" "contracts/one/schema.json")" = "SHARED_CROSS_CUTTING" ] \
  && ok "TEST-017.2: shared_paths precedence applies with one matching component include" \
  || fail "TEST-017.2: expected SHARED_CROSS_CUTTING with one owner"
[ "$(classification_of "$out" "contracts/two/schema.json")" = "SHARED_CROSS_CUTTING" ] \
  && ok "TEST-017.3: shared_paths precedence applies with two matching component includes" \
  || fail "TEST-017.3: expected SHARED_CROSS_CUTTING with two owners"

# ============================================================================
# TEST-018 (AC-018): shared_paths both-or-neither shape is a fail-closed
# configuration error, distinct from the six Gate Fail conditions
# ============================================================================
echo "=== TEST-018: shared_paths shape fail-closed ==="
set +e
err=$(printf '' | "$SCRIPT" --config "${FIXTURES}/test-018-shared-shape-error/config-both.yaml" 2>&1)
code=$?
set -e
if [ "$code" -ne 0 ] && printf '%s' "$err" | grep -q "never both or neither"; then
  ok "TEST-018.1: shared_paths entry with BOTH components and classification is rejected fail-closed"
else
  fail "TEST-018.1: expected non-zero exit + shape diagnostic, got exit=$code err=$err"
fi
set +e
err=$(printf '' | "$SCRIPT" --config "${FIXTURES}/test-018-shared-shape-error/config-neither.yaml" 2>&1)
code=$?
set -e
if [ "$code" -ne 0 ] && printf '%s' "$err" | grep -q "never both or neither"; then
  ok "TEST-018.2: shared_paths entry with NEITHER components nor classification is rejected fail-closed"
else
  fail "TEST-018.2: expected non-zero exit + shape diagnostic, got exit=$code err=$err"
fi

# WFI-012 operator-layer negative: the Python master compares the contract
# literal case-sensitively, so the PowerShell twin must not accept this input
# through its default case-insensitive -eq/-ne behavior.
set +e
err=$(printf '' | "$SCRIPT" --config "${FIXTURES}/test-018-shared-shape-error/config-miscased-classification.yaml" 2>&1)
code=$?
set -e
if [ "$code" -ne 0 ] && printf '%s' "$err" | grep -q "unsupported classification"; then
  ok "TEST-018.3: mis-cased Cross-Cutting literal is rejected fail-closed"
else
  fail "TEST-018.3: expected exact-case classification rejection, got exit=$code err=$err"
fi

# WFI-012 language-feature negative: PowerShell's [ordered] map is
# case-insensitive unless constructed with an ordinal comparer. A mis-cased
# contract field must therefore be rejected explicitly by both twins.
set +e
err=$(printf '' | "$SCRIPT" --config "${FIXTURES}/test-018-shared-shape-error/config-miscased-components.yaml" 2>&1)
code=$?
set -e
if [ "$code" -ne 0 ] && printf '%s' "$err" | grep -q "config.components must be a list"; then
  ok "TEST-018.4: mis-cased Components field is rejected fail-closed"
else
  fail "TEST-018.4: expected exact-case field-name rejection, got exit=$code err=$err"
fi

# ============================================================================
# TEST-042/043/044 (AC-042/043/044, REQ-006, T-005): cross-epic
# cross-cutting seed inventory — Epic A1's contracts/project-context.template.yaml
# is the SOLE canonical source of the default cross-cutting seed list; A3
# authors no competing list of its own (Non-goals). These cases extend
# T-001's already-registered component-path-resolver suite (no new
# tests/run-all.sh/.ps1 or .github/workflows/test.yml entry — T-005 shares
# T-001's suite/fixture tree, design.md Global Constraints).
#
# TEST-042 and TEST-044 read Epic A1's REAL, canonical template artifact
# directly (never a stand-in/copy). Epic A1 (#189) has now MERGED, so that
# artifact is a tracked repository file and both cases are ordinary green
# assertions on the real contract; they were documented expected-RED only
# while A1 was outstanding. AC-042 still requires them to FAIL closed
# (never skip, never a stand-in) if the artifact ever disappears, which is
# what the `[ ! -f ]` guards below now report as a regression.
# ============================================================================
# Shared inventory-conformance check, factored out so it can be proven
# against BOTH the real A1 template (TEST-042) and deliberately wrong local
# fixtures (TEST-042-negative, the acceptance-first RED evidence this
# task's Required Workflow calls for) — this is the same logic in both
# calls, not a re-implementation that could silently diverge.
#
# T-005 quality-gate finding (Major, reports/quality-gate/epic-191-a3-path-ownership/T-005.md):
# a prior version of this check did a fixed-string/regex-escaped substring
# grep, which caught a MISSING entry and the one specific extra
# `contracts/**` case, but did not reject an ARBITRARY extra cross-cutting
# entry ("no more") or a CANONICAL entry wrongly classified as bounded
# instead of cross-cutting ("no differently classified") — both of which
# AC-042 explicitly requires this fixture to fail on. Remedied here by
# parsing the actual shared_paths structure (reusing
# resolve-component-paths.py's own restricted-YAML parser, not a
# second, potentially-diverging implementation) and asserting SET EQUALITY
# between the template's cross-cutting patterns and the canonical six —
# a single assertion that catches missing, extra, AND misclassified
# entries simultaneously (a canonical pattern declared bounded is neither
# absent from shared_paths nor cross-cutting, so it fails the same
# equality check either way).
check_inventory_conformance() {
  # $1 = template path (real or fixture). Returns 0 (conformant) or 1
  # (non-conformant), printing the mismatch reason to stdout on rejection;
  # never a skip on a present file.
  tpl="$1"
  python3 - "$tpl" "${REPO_ROOT}/plugins/sdd-quality-loop/scripts/resolve-component-paths.py" << 'PYEOF'
import importlib.util
import sys

tpl_path, resolver_path = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("rcp", resolver_path)
rcp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rcp)

CANONICAL = {"specs/**", "reports/**", "docs/**", ".github/**", "tests/fixtures/**", "CHANGELOG.md"}

with open(tpl_path, "r", encoding="utf-8") as fh:
    text = fh.read()
try:
    data = rcp.parse_minimal_yaml(text)
except rcp.ConfigError as exc:
    print(f"template could not be parsed: {exc}")
    sys.exit(1)

shared_paths = data.get("shared_paths")
if not isinstance(shared_paths, list):
    print("template has no top-level 'shared_paths' list")
    sys.exit(1)

cross_cutting_patterns = set()
misclassified = []
for entry in shared_paths:
    if not isinstance(entry, dict):
        continue
    pattern = entry.get("pattern")
    classification = entry.get("classification")
    components = entry.get("components")
    if pattern in CANONICAL and (classification != "cross-cutting" or components is not None):
        misclassified.append(pattern)
    if classification == "cross-cutting":
        cross_cutting_patterns.add(pattern)

if misclassified:
    print(f"canonical entries wrongly classified as bounded (not cross-cutting): {sorted(misclassified)}")
    sys.exit(1)
if cross_cutting_patterns != CANONICAL:
    missing = CANONICAL - cross_cutting_patterns
    extra = cross_cutting_patterns - CANONICAL
    print(f"cross-cutting set mismatch: missing={sorted(missing)} extra={sorted(extra)}")
    sys.exit(1)
print("conformant")
sys.exit(0)
PYEOF
}

echo "=== TEST-042: cross-epic inventory conformance (A1 template) ==="
A1_TEMPLATE="${REPO_ROOT}/contracts/project-context.template.yaml"
if [ ! -f "$A1_TEMPLATE" ]; then
  fail "TEST-042: A1's canonical template has LANDED and is a tracked repository artifact; its absence at ${A1_TEMPLATE} is now a regression, not an expected pre-A1 state"
elif check_inventory_conformance "$A1_TEMPLATE" >/dev/null; then
  ok "TEST-042: A1's landed template's cross-cutting shared_paths entries match the six-entry canonical set exactly, contracts/** absent, none misclassified"
else
  fail "TEST-042: A1's landed template diverges from the six-entry canonical cross-cutting set: $(check_inventory_conformance "$A1_TEMPLATE")"
fi

echo "=== TEST-042-negative: inventory-conformance check catches deliberately wrong seed sets (acceptance-first RED evidence) ==="
WRONG_SEED_MISSING_PLUS_EXTRA=$(mktemp)
cat > "$WRONG_SEED_MISSING_PLUS_EXTRA" << 'WRONGEOF'
shared_paths:
  - pattern: "specs/**"
    classification: cross-cutting
  - pattern: "docs/**"
    classification: cross-cutting
  - pattern: "contracts/**"
    classification: cross-cutting
WRONGEOF
if check_inventory_conformance "$WRONG_SEED_MISSING_PLUS_EXTRA" >/dev/null; then
  fail "TEST-042-negative.1: a seed set with missing entries + wrongly-included contracts/** should have been rejected, but the check reported conformant"
else
  ok "TEST-042-negative.1: the check correctly rejects missing entries + wrongly-included contracts/**"
fi
rm -f "$WRONG_SEED_MISSING_PLUS_EXTRA"

# Sub-case the QG finding specifically named: an ARBITRARY 7th extra
# cross-cutting entry, with all six canonical entries otherwise present
# and correctly classified — a pure "no more" violation the old
# substring-grep check would have missed entirely.
WRONG_SEED_EXTRA_ONLY=$(mktemp)
cat > "$WRONG_SEED_EXTRA_ONLY" << 'WRONGEOF'
shared_paths:
  - pattern: "specs/**"
    classification: cross-cutting
  - pattern: "reports/**"
    classification: cross-cutting
  - pattern: "docs/**"
    classification: cross-cutting
  - pattern: ".github/**"
    classification: cross-cutting
  - pattern: "tests/fixtures/**"
    classification: cross-cutting
  - pattern: "CHANGELOG.md"
    classification: cross-cutting
  - pattern: "vendor/**"
    classification: cross-cutting
WRONGEOF
if check_inventory_conformance "$WRONG_SEED_EXTRA_ONLY" >/dev/null; then
  fail "TEST-042-negative.2: a seed set with all six canonical entries PLUS one arbitrary extra (vendor/**) should have been rejected, but the check reported conformant"
else
  ok "TEST-042-negative.2: the check correctly rejects an arbitrary extra cross-cutting entry even when all six canonical entries are present and correctly classified ('no more')"
fi
rm -f "$WRONG_SEED_EXTRA_ONLY"

# Sub-case the QG finding specifically named: a canonical pattern present
# but wrongly classified as BOUNDED (components: [...]) instead of
# cross-cutting — a pure "no differently classified" violation the old
# substring-grep check would have missed entirely (the pattern string
# itself is still present in the file, just under the wrong shape).
WRONG_SEED_MISCLASSIFIED=$(mktemp)
cat > "$WRONG_SEED_MISCLASSIFIED" << 'WRONGEOF'
shared_paths:
  - pattern: "specs/**"
    components:
      - some-component
  - pattern: "reports/**"
    classification: cross-cutting
  - pattern: "docs/**"
    classification: cross-cutting
  - pattern: ".github/**"
    classification: cross-cutting
  - pattern: "tests/fixtures/**"
    classification: cross-cutting
  - pattern: "CHANGELOG.md"
    classification: cross-cutting
WRONGEOF
if check_inventory_conformance "$WRONG_SEED_MISCLASSIFIED" >/dev/null; then
  fail "TEST-042-negative.3: specs/** declared bounded (components:) instead of cross-cutting should have been rejected, but the check reported conformant"
else
  ok "TEST-042-negative.3: the check correctly rejects a canonical entry wrongly classified as bounded instead of cross-cutting ('no differently classified')"
fi
rm -f "$WRONG_SEED_MISCLASSIFIED"

echo "=== TEST-043: no-op proof for the six-entry cross-cutting set ==="
# TEST-043.0 — AC-043 is specifically about a diff "with zero components
# declared to own them" (requirements.md AC-043). This fixture previously
# declared a dummy component while the pass message claimed zero owners,
# which made the headline assertion vacuous and hid the fact that the
# resolver rejected an empty `components` list outright. Assert the
# fixture's actual precondition so the claim and the fixture agree.
if grep -Eq '^components:[[:space:]]*\[\][[:space:]]*$' \
     "${FIXTURES}/test-043-cross-cutting-no-op/config.yaml"; then
  ok "TEST-043.0: the no-op fixture really does declare zero component owners (components: [])"
else
  fail "TEST-043.0: fixture claims zero declared component owners but does not declare 'components: []'"
fi
out=$(resolve "${FIXTURES}/test-043-cross-cutting-no-op/config.yaml" "${FIXTURES}/test-043-cross-cutting-no-op/changed-paths.txt")
all_cross_cutting=1
for p in specs/some-feature/requirements.md reports/quality-gate/2026-01-01.md docs/architecture/overview.md .github/workflows/example.yml tests/fixtures/some-fixture.json CHANGELOG.md; do
  cls=$(classification_of "$out" "$p")
  if [ "$cls" != "SHARED_CROSS_CUTTING" ]; then
    all_cross_cutting=0
    fail "TEST-043: expected SHARED_CROSS_CUTTING for $p, got $cls"
  fi
done
if [ "$all_cross_cutting" -eq 1 ]; then
  ok "TEST-043: a diff confined to the six-entry cross-cutting set, with zero declared component owners, never triggers Fail-1/UNOWNED"
fi

echo "=== TEST-044: day-one cross-epic integration proof (A1 template) ==="
if [ ! -f "$A1_TEMPLATE" ]; then
  fail "TEST-044: A1's canonical template has LANDED and is a tracked repository artifact; its absence at ${A1_TEMPLATE} is now a regression, not an expected pre-A1 state"
else
  DAYONE_PATHS_FILE=$(mktemp)
  printf 'specs/epic-example/requirements.md\nreports/quality-gate/2026-01-01.md\n' > "$DAYONE_PATHS_FILE"
  set +e
  dayone_out=$(resolve "$A1_TEMPLATE" "$DAYONE_PATHS_FILE" 2>&1)
  dayone_code=$?
  set -e
  rm -f "$DAYONE_PATHS_FILE"
  if [ "$dayone_code" -eq 0 ] \
     && [ "$(classification_of "$dayone_out" "specs/epic-example/requirements.md")" != "UNOWNED" ] \
     && [ "$(classification_of "$dayone_out" "reports/quality-gate/2026-01-01.md")" != "UNOWNED" ]; then
    ok "TEST-044: a project-context.yaml shaped like A1's own landed template does not trip Fail-1 on an ordinary day-one specs/**/reports/** change"
  else
    fail "TEST-044: day-one integration against A1's landed template failed (exit=$dayone_code, or an ordinary day-one change tripped Fail-1)"
  fi
fi

# ============================================================================
# TEST-045 (AC-045): fixture-tree base shape (>=2 overlapping components,
# nested excluded subtree, bounded shared_paths entry); suite/CI
# self-registration proof; live test.yml byte-unchanged proof.
# ============================================================================
echo "=== TEST-045: fixture-tree base shape + suite/CI registration ==="
out=$(resolve "${FIXTURES}/base-tree/config.yaml" "${FIXTURES}/base-tree/changed-paths.txt")
[ "$(classification_of "$out" "src/shared-ui/button.ts")" = "OVERLAP" ] \
  && ok "TEST-045.1: base fixture tree has >=2 components with an overlapping candidate owned path" \
  || fail "TEST-045.1: expected OVERLAP for src/shared-ui/button.ts"
[ "$(classification_of "$out" "src/desktop/generated/x.ts")" = "UNOWNED" ] \
  && ok "TEST-045.2: base fixture tree has a nested excluded subtree" \
  || fail "TEST-045.2: expected UNOWNED for src/desktop/generated/x.ts"
[ "$(classification_of "$out" "contracts/schema.json")" = "SHARED_BOUNDED" ] \
  && ok "TEST-045.3: base fixture tree has a bounded shared_paths entry" \
  || fail "TEST-045.3: expected SHARED_BOUNDED for contracts/schema.json"

if grep -q "component-path-resolver" "${REPO_ROOT}/tests/run-all.sh" \
   && grep -q "component-path-resolver" "${REPO_ROOT}/tests/run-all.ps1"; then
  ok "TEST-045.4: component-path-resolver suite self-registers in tests/run-all.sh and .ps1"
else
  fail "TEST-045.4: component-path-resolver missing from tests/run-all.sh/.ps1 registration"
fi

DRAFT_DIR="${REPO_ROOT}/reports/implementation/epic-191-a3-path-ownership/drafts"
DRAFT_FILE="${DRAFT_DIR}/component-path-resolver-ci-steps.yml"
MANIFEST="${DRAFT_DIR}/MANIFEST.sha256"
if [ -f "$DRAFT_FILE" ] && [ -f "$MANIFEST" ] && (cd "$DRAFT_DIR" && shasum -a 256 -c MANIFEST.sha256 >/dev/null 2>&1); then
  ok "TEST-045.5: non-protected CI-step draft has a verified MANIFEST.sha256 entry"
else
  fail "TEST-045.5: expected a hash-verified CI-step draft in ${DRAFT_DIR}"
fi

if git -C "$REPO_ROOT" diff --quiet -- .github/workflows/test.yml; then
  ok "TEST-045.6: live .github/workflows/test.yml remains byte-unchanged"
else
  fail "TEST-045.6: live .github/workflows/test.yml has working-tree changes"
fi

# TEST-045.7 — this suite's fixture corpus is keyed on Epic A1's canonical
# `id`, not this epic's pre-A1 `name`. A1's schema requires `id` under
# "additionalProperties": false, so a `name`-keyed component is INVALID
# against A1 (TEST-011.5 proves the rejection). The resolver rejects that
# legacy key, and A3's fixtures must demonstrate the
# canonical shape.
legacy_named=$(grep -rl '^[[:space:]]*-[[:space:]]*name:' "${FIXTURES}" 2>/dev/null || true)
if [ -z "$legacy_named" ]; then
  ok "TEST-045.7: every component-path-ownership fixture uses A1's canonical 'id' key"
else
  fail "TEST-045.7: fixtures still use the pre-A1 'name' key: $(printf '%s' "$legacy_named" | tr '\n' ' ')"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed."
[ "$FAIL" -eq 0 ]
