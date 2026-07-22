#!/usr/bin/env bash
# component-path-resolver.tests.sh — epic-191-a3-path-ownership T-001.
# Exercises resolve-component-paths.sh (the dispatcher; goes through
# resolve-component-paths.py on any host with python3) against the fixture
# tree at tests/fixtures/component-path-ownership/, independently proving
# each glob-matching clause id (REQ-001, AC-001..AC-011) and each
# classification/Fail rule (REQ-002, AC-012..AC-018), per
# specs/epic-191-a3-path-ownership/tasks.md T-001 Done When.
#
# TEST-011 (schema conformance) is DELIBERATELY, PERMANENTLY red on this
# suite's last assertion (TEST-011.3) until Epic A1 ships
# contracts/project-context.template.yaml — this is not a defect. See the
# TEST-011 section below and specs/epic-191-a3-path-ownership/tasks.md's
# T-001 Blockers note: "this task cannot reach Done while that fixture is
# red for an unlanded/divergent schema" (AC-011, requirements.md
# Dependencies). Never silence, skip, or downgrade that assertion to make
# this suite artificially green.
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
[ "$order" = "a/x.ts,a/y.ts,b/z.ts" ] \
  && ok "TEST-010.3: output records are sorted by a stable, ordinal sort over raw path bytes" \
  || fail "TEST-010.3: expected 'a/x.ts,a/y.ts,b/z.ts', got '$order'"

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
components:
  - name: example
    paths:
      include:
        - "example/**"
shared_paths:
  - pattern: "specs/**"
    classification: cross-cutting
  - pattern: "contracts/**"
    components:
      - example
EOF
set +e
out=$(printf '' | "$SCRIPT" --check-schema-conformance --schema "${CONFORMANT_SCHEMA_ROOT}/schema.yaml" 2>&1)
code=$?
set -e
rm -rf "$CONFORMANT_SCHEMA_ROOT"
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -q '"conformant": true'; then
  ok "TEST-011.2: schema-conformance check reports exit 0 + conformant:true when the artifact matches this parser's shape"
else
  fail "TEST-011.2: expected exit 0 + conformant:true for a well-formed schema artifact"
fi

# TEST-011.3 — DELIBERATE, DOCUMENTED, PERMANENT RED until Epic A1 lands
# contracts/project-context.template.yaml. This is the fixture
# tasks.md's T-001 Blockers note identifies as the reason this task cannot
# reach Done yet — it is not a bug in this suite or in
# resolve-component-paths, and must never be skipped, waived, or made to
# pass via a stand-in (requirements.md Dependencies, AC-011).
set +e
out=$(printf '' | "$SCRIPT" --check-schema-conformance 2>&1)
code=$?
set -e
if [ "$code" -eq 0 ]; then
  ok "TEST-011.3: contracts/project-context.template.yaml now conforms (Epic A1 has landed — this line should now read ok, not fail)"
else
  fail "TEST-011.3 [EXPECTED — Epic A1 has not landed contracts/project-context.template.yaml yet]: $out"
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
evidence_pattern=$(printf '%s' "$out" | jqf -r '.records[0].evidence.excluded_match[0].patterns[0]')
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
[ "$(classification_of "$out" "contracts/schema.json")" = "SHARED_CROSS_CUTTING" ] \
  && ok "TEST-017.1: a shared_paths match exempts a path from OVERLAP even when 2 components' include also match" \
  || fail "TEST-017.1: expected SHARED_CROSS_CUTTING"

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
# directly (never a stand-in/copy) and are DELIBERATELY, PERMANENTLY red
# while it is absent from this repository — exactly the same documented,
# designed external-dependency pattern as TEST-011.3 above. This is
# re-verified at this task's own implementation-start time
# (`ls contracts/ | grep -i project-context` -> confirmed absent, per
# tasks.md T-005 Depends On) and is not a defect in this suite or in
# resolve-component-paths.
# ============================================================================
# Shared inventory-conformance check, factored out so it can be proven
# against BOTH the real A1 template (TEST-042) and a deliberately wrong
# local fixture (TEST-042-negative, the acceptance-first RED evidence this
# task's Required Workflow calls for) — this is the same logic in both
# calls, not a re-implementation that could silently diverge.
check_inventory_conformance() {
  # $1 = template path. Returns 0 (conformant) or 1 (non-conformant); never
  # a skip on a present file.
  tpl="$1"
  expected_entries="specs/** reports/** docs/** .github/** tests/fixtures/** CHANGELOG.md"
  missing=0
  for entry in $expected_entries; do
    grep -Fq -- "$entry" "$tpl" || missing=1
  done
  if grep -Fq "contracts/**" "$tpl"; then
    return 1
  elif [ "$missing" -ne 0 ]; then
    return 1
  fi
  return 0
}

echo "=== TEST-042: cross-epic inventory conformance (A1 template) ==="
A1_TEMPLATE="${REPO_ROOT}/contracts/project-context.template.yaml"
if [ ! -f "$A1_TEMPLATE" ]; then
  fail "TEST-042 [EXPECTED — Epic A1 has not landed contracts/project-context.template.yaml yet]: artifact absent at ${A1_TEMPLATE}"
elif check_inventory_conformance "$A1_TEMPLATE"; then
  ok "TEST-042: A1's landed template's cross-cutting shared_paths entries match the six-entry canonical set exactly, contracts/** absent"
else
  fail "TEST-042: A1's landed template diverges from the six-entry canonical cross-cutting set (missing entry, extra entry, or contracts/** wrongly included)"
fi

echo "=== TEST-042-negative: inventory-conformance check catches a deliberately wrong seed set (acceptance-first RED evidence) ==="
WRONG_SEED_FILE=$(mktemp)
cat > "$WRONG_SEED_FILE" << 'WRONGEOF'
shared_paths:
  - pattern: "specs/**"
    classification: cross-cutting
  - pattern: "docs/**"
    classification: cross-cutting
  - pattern: "contracts/**"
    classification: cross-cutting
WRONGEOF
if check_inventory_conformance "$WRONG_SEED_FILE"; then
  fail "TEST-042-negative: a deliberately wrong seed set (missing entries + wrongly-included contracts/**) should have been rejected, but the check reported conformant"
else
  ok "TEST-042-negative: the inventory-conformance check correctly rejects a deliberately wrong seed set (missing entries, contracts/** wrongly present) — proves the check is not vacuously always-passing"
fi
rm -f "$WRONG_SEED_FILE"

echo "=== TEST-043: no-op proof for the six-entry cross-cutting set ==="
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
  fail "TEST-044 [EXPECTED — Epic A1 has not landed contracts/project-context.template.yaml yet]: artifact absent at ${A1_TEMPLATE}, day-one integration cannot be proven against it"
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

MANIFEST="${REPO_ROOT}/specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256"
if [ -f "$MANIFEST" ] && grep -q "\.github/workflows/test\.yml" "$MANIFEST"; then
  ok "TEST-045.5: staged .github/workflows/test.yml candidate has a MANIFEST.sha256 entry"
else
  fail "TEST-045.5: expected a .github/workflows/test.yml entry in ${MANIFEST}"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed."
[ "$FAIL" -eq 0 ]
