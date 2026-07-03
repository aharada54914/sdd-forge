#!/bin/sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCHEMA="$ROOT/contracts/design-system.contract.v1.schema.json"
TOKENS="$ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-tokens.template.json"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

assert_contains() {
  file=$1
  pattern=$2
  label=$3
  if [ -f "$file" ] && grep -Eq "$pattern" "$file"; then pass "$label"; else fail "$label"; fi
}

# DS-001 contract schema envelope
assert_contains "$SCHEMA" 'https://json-schema\.org/draft/2020-12/schema' "DS-001 schema draft 2020-12"
assert_contains "$SCHEMA" 'https://sdd-forge\.dev/contracts/design-system\.contract\.v1\.schema\.json' "DS-001 schema \$id"
assert_contains "$SCHEMA" '"design-system-contract/v1"' "DS-001 schema const id"
assert_contains "$SCHEMA" '"generated_by"' "DS-001 generated_by in contract"
assert_contains "$SCHEMA" '"additionalProperties": false' "DS-001 strict meta envelope"

# DS-002 tokens template is a conforming instance
assert_contains "$TOKENS" '"schema": "design-system-contract/v1"' "DS-002 template meta.schema"
assert_contains "$TOKENS" '"version": "[0-9]+\.[0-9]+\.[0-9]+"' "DS-002 template meta.version semver"
assert_contains "$TOKENS" '"generated_by": "manual"' "DS-002 template meta.generated_by"
assert_contains "$TOKENS" '"profile": "custom"' "DS-002 template meta.profile"
for group in color typography spacing; do
  assert_contains "$TOKENS" "\"$group\"" "DS-002 token group $group"
done
assert_contains "$TOKENS" '"\$type"' "DS-002 DTCG \$type present"
assert_contains "$TOKENS" '"\$value"' "DS-002 DTCG \$value present"

# DS-003 design-system.md template required sections
DS="$ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-system.template.md"
assert_contains "$DS" '^## Layer 1 — Tokens \(machine-extracted\)$' "DS-003 layer 1 section"
assert_contains "$DS" '^## Layer 2 — Do / Don'"'"'t \(component conventions\)$' "DS-003 layer 2 section"
assert_contains "$DS" '^## Layer 3 — Review checklist \(human-curated\)$' "DS-003 layer 3 section"
assert_contains "$DS" '^## Change Process$' "DS-003 change process section"
assert_contains "$DS" 'WCAG 2\.2 AA' "DS-003 WCAG 2.2 AA"

# DS-004 ui-patterns.md template required sections (D6 categories)
UIP="$ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ui-patterns.template.md"
for section in Actions Dialogs Icons Flow States 'Cognitive Load'; do
  assert_contains "$UIP" "^## $section$" "DS-004 ui-patterns section $section"
done
assert_contains "$UIP" 'Exactly one primary action per screen' "DS-004 single primary action rule"
assert_contains "$UIP" 'irreversible or destructive' "DS-004 dialog timing rule"

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
[ "$FAIL" -eq 0 ]
