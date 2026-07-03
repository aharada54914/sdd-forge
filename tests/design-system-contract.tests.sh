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

# DS-005 PLUGIN-CONTRACTS section
PC="$ROOT/PLUGIN-CONTRACTS.md"
assert_contains "$PC" '^## sdd-bootstrap design-system artifacts → consumers \(v1\.8\.0\+\)$' "DS-005 contract section heading"
assert_contains "$PC" 'design-system\.contract\.v1\.schema\.json' "DS-005 schema referenced"
assert_contains "$PC" 'absence never blocks' "DS-005 absence contract"

# DS-006 design-sync-loop v2 ensures design-system/ and token-driven mockups
DSL="$ROOT/plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md"
assert_contains "$DSL" '^## Ensure design-system/$' "DS-006 ensure section"
assert_contains "$DSL" 'ui-ux-pro-max' "DS-006 seed generator detection"
assert_contains "$DSL" 'design-system --persist' "DS-006 seed generation command"
assert_contains "$DSL" 'ui-ux-pro-max unavailable — D6 template interview used' "DS-006 D6 fallback note"
assert_contains "$DSL" 'figma-dtcg-import' "DS-006 figma DTCG import path"
assert_contains "$DSL" 'design-system/design-tokens\.json' "DS-006 mockups reference tokens"
assert_contains "$DSL" 'MASTER\.md' "DS-006 seed is input, artifacts authoritative"

# DS-007 investigate-codebase brownfield design inventory
INV="$ROOT/plugins/sdd-bootstrap/skills/investigate-codebase/SKILL.md"
assert_contains "$INV" 'Design Inventory' "DS-007 design inventory group"
assert_contains "$INV" '#hex / rgb\(\) / hsl\(\)' "DS-007 hardcoded color patterns"

# DS-008 design.template.md compliance section / DS-009 lite declaration
DT="$ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design.template.md"
assert_contains "$DT" '^## Design System Compliance$' "DS-008 compliance section"
assert_contains "$DT" 'ds_profile: none' "DS-008 none profile N/A rule"
assert_contains "$DT" 'design_system_version' "DS-008 version placeholder"
DL="$ROOT/plugins/sdd-lite/templates/design-lite.md"
assert_contains "$DL" 'design-system/' "DS-009 lite token declaration"

# DS-010 impl-reviewer-a design-system conformance check
IRA="$ROOT/plugins/sdd-review-loop/agents/impl-reviewer-a.md"
assert_contains "$IRA" '^## DESIGN-SYSTEM-CONFORMANCE \(Major, TYPE-D\)$' "DS-010 reviewer-a check defined"
assert_contains "$IRA" 'ADR-PRESENT, DESIGN-SYSTEM-CONFORMANCE\.' "DS-010 ordered checks updated"
PRC="$ROOT/plugins/sdd-review-loop/references/phase-review-checklist.md"
assert_contains "$PRC" '^#### DESIGN-SYSTEM-CONFORMANCE$' "DS-010 checklist block"
assert_contains "$PRC" 'impl-review-loop`: 20 checks' "DS-010 impl count updated"

# DS-011 impl-reviewer-b unsanctioned UI library rule
IRB="$ROOT/plugins/sdd-review-loop/agents/impl-reviewer-b.md"
assert_contains "$IRB" 'component library or styling framework' "DS-011 reviewer-b UI library rule"
assert_contains "$PRC" 'unsanctioned UI component library' "DS-011 checklist UI library rule"

# DS-012 implementation policy UI rules and conditional required reading
IPOL="$ROOT/plugins/sdd-implementation/skills/implement-task/references/implementation-policy.md"
assert_contains "$IPOL" '^## UI Implementation Rules$' "DS-012 UI rules section"
assert_contains "$IPOL" 'design-tokens\.json tokens only' "DS-012 tokens-only rule"
assert_contains "$IPOL" 'design-system/ui-patterns\.md' "DS-012 ui-patterns reference"
ITSK="$ROOT/plugins/sdd-implementation/skills/implement-task/SKILL.md"
assert_contains "$ITSK" 'design-system/design-system\.md' "DS-012 conditional required reading"

# DS-013 visual-verify-loop design-system comparison
VVL="$ROOT/plugins/sdd-implementation/skills/visual-verify-loop/SKILL.md"
assert_contains "$VVL" 'design-system/design-tokens\.json' "DS-013 token conformance in loop"
assert_contains "$VVL" 'design-system/ui-patterns\.md' "DS-013 ui-patterns in loop"
assert_contains "$VVL" 'check-design-system' "DS-013 deterministic gate ownership"

# DS-014 design-system checklist and evaluator wiring
DSC="$ROOT/plugins/sdd-quality-loop/references/design-system-checklist.md"
assert_contains "$DSC" '^# Design System Review Checklist$' "DS-014 checklist exists"
assert_contains "$DSC" '^## UI Patterns \(ui-patterns\.md\)$' "DS-014 ui-patterns section"
RUB="$ROOT/plugins/sdd-quality-loop/references/evaluation-rubric.md"
assert_contains "$RUB" 'design-system non-conformance' "DS-014 rubric Major classification"
QGS="$ROOT/plugins/sdd-quality-loop/skills/quality-gate/SKILL.md"
assert_contains "$QGS" 'design-system-checklist\.md' "DS-014 quality-gate conditional load"

# DS-015 WCAG 2.2 AA update
ACC="$ROOT/plugins/sdd-quality-loop/references/accessibility-checklist.md"
assert_contains "$ACC" 'WCAG 2\.2 AA' "DS-015 target updated"
assert_contains "$ACC" '2\.5\.8 Target' "DS-015 target size SC"
assert_contains "$ACC" '3\.3\.8 Accessible' "DS-015 accessible authentication SC"

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
[ "$FAIL" -eq 0 ]
