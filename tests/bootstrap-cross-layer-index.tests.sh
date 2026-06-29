#!/bin/sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEMPLATES="$ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates"
DESIGN="$TEMPLATES/design.template.md"
TRACEABILITY="$TEMPLATES/traceability.template.md"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

assert_contains() {
  file=$1
  pattern=$2
  label=$3
  if grep -Eq "$pattern" "$file"; then pass "$label"; else fail "$label"; fi
}

assert_absent() {
  file=$1
  pattern=$2
  label=$3
  if grep -Eq "$pattern" "$file"; then fail "$label"; else pass "$label"; fi
}

assert_contains "$DESIGN" 'ux-spec\.md#[a-z0-9-]+' "TEST-007 design links UX layer"
assert_contains "$DESIGN" 'frontend-spec\.md#[a-z0-9-]+' "TEST-007 design links frontend layer"
assert_contains "$DESIGN" 'infra-spec\.md#[a-z0-9-]+' "TEST-007 design links infrastructure layer"
assert_contains "$DESIGN" 'security-spec\.md#[a-z0-9-]+' "TEST-007 design links security layer"
assert_contains "$DESIGN" '^## Cross-Layer Dependencies$' "TEST-007 cross-layer dependencies"
assert_contains "$DESIGN" '^## ADR Change Log$' "TEST-007 ADR change log"
assert_contains "$DESIGN" '^## Test Strategy$' "TEST-007 retains test strategy"
assert_contains "$DESIGN" '^## Constraint Compliance$' "TEST-007 retains constraints"
assert_contains "$DESIGN" '^## Open Questions$' "TEST-007 retains open questions"
assert_contains "$DESIGN" '^## Risks$' "TEST-007 retains risks"
assert_absent "$DESIGN" '^## (Frontend|Backend) Plan$' "TEST-007 removes legacy inline plan placeholders"

assert_contains "$TRACEABILITY" 'Requirement.*Layer Spec.*Test ID.*Evidence' "TEST-008 Layer Spec traceability column"
assert_contains "$TRACEABILITY" '^## Layer Coverage$' "TEST-008 layer coverage summary"
assert_contains "$TRACEABILITY" 'ux-spec\.md#[a-z0-9-]+' "TEST-008 canonical UX anchor example"
assert_contains "$TRACEABILITY" 'frontend-spec\.md#[a-z0-9-]+' "TEST-008 canonical frontend anchor example"
assert_contains "$TRACEABILITY" 'infra-spec\.md#[a-z0-9-]+' "TEST-008 canonical infrastructure anchor example"
assert_contains "$TRACEABILITY" 'security-spec\.md#[a-z0-9-]+' "TEST-008 canonical security anchor example"
assert_contains "$TRACEABILITY" 'N/A — cross-layer only: [^|]+' "TEST-008 reasoned cross-layer example"

if awk -F '|' '
  /^\| REQ-/ {
    value = $5
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
    if (value == "" || value == "N/A") invalid = 1
  }
  END { exit invalid ? 0 : 1 }
' "$TRACEABILITY"; then
  fail "TEST-008 no blank or bare N/A Layer Spec examples"
else
  pass "TEST-008 no blank or bare N/A Layer Spec examples"
fi

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
[ "$FAIL" -eq 0 ]
