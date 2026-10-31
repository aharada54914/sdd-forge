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
assert_contains "$IRA" 'ADR-PRESENT, DESIGN-SYSTEM-CONFORMANCE, DOMAIN-CONFORMANCE\.' "DS-010 ordered checks updated"
PRC="$ROOT/plugins/sdd-review-loop/references/phase-review-checklist.md"
assert_contains "$PRC" '^#### DESIGN-SYSTEM-CONFORMANCE$' "DS-010 checklist block"
assert_contains "$PRC" 'impl-review-loop`: 22 checks' "DS-010 impl count updated"

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

# DS-016 contract check id, matrix row, quality-gate wiring
VCT="$ROOT/plugins/sdd-quality-loop/templates/verification-contract.template.json"
assert_contains "$VCT" '"id": "design-system"' "DS-016 contract check id"
RGM="$ROOT/plugins/sdd-quality-loop/references/risk-gate-matrix.md"
assert_contains "$RGM" 'design-system conformance' "DS-016 matrix conditional row"
assert_contains "$QGS" 'check-design-system' "DS-016 quality-gate runs the script"

# DS-017 user-facing documentation
assert_contains "$ROOT/README.md" 'design-system/' "DS-017 README feature bullet"
assert_contains "$ROOT/docs/workflow-guide.md" 'design-sync-loop' "DS-017 workflow-guide integration"
assert_contains "$ROOT/docs/skill-reference.md" 'check-design-system' "DS-017 skill-reference script entry"
assert_contains "$ROOT/CHANGELOG.md" '統一デザインシステム統合' "DS-017 changelog entry"

# ---------------------------------------------------------------------------
# design-sync-consent (issue #138, DS-29) -- TEST-001..TEST-051
#
# T-001's own scope is authoring these 51 assertions against
# specs/design-sync-consent/acceptance-tests.md's Test Matrix. The content
# most of them check -- design-sync-loop/SKILL.md's Loop restructuring, the
# Design-Source field table, the four REQ-007 reconciliation sites, the
# staged lite-spec candidate -- is produced by T-002/T-003/T-004, none of
# which has landed at this task's authoring time. Most TEST-NNN below are
# therefore expected to FAIL (RED) against the live tree until those tasks
# land; that RED is this task's own required baseline evidence
# (tasks.md T-001 Done-When item 5), not a defect here. A handful already
# PASS today because the text they check is preserved unchanged by design
# (TEST-016, TEST-019, TEST-020, TEST-021, TEST-022, TEST-023, TEST-024,
# TEST-037, TEST-040).
#
# TEST-039 stays RED on the live tree even after every other task in this
# decomposition lands, by design (R-OQ-8 part 3, acceptance-tests.md
# Notes): CI registration is a separately staged, human-applied workflow
# patch outside this feature's task plan.
# ---------------------------------------------------------------------------

BSI="$ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md"
WFG="$ROOT/docs/workflow-guide.md"
CDW="$ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md"
CHG="$ROOT/CHANGELOG.md"
DSC_DRAFT="$ROOT/specs/design-sync-consent/verification/T-004/staged-lite-spec-candidate.draft.md"
DSC_MANIFEST="$ROOT/specs/design-sync-consent/human-copy/MANIFEST.sha256"
LITE_LIVE="$ROOT/plugins/sdd-lite/skills/lite-spec/SKILL.md"
LITE_DEST_NAME="plugins/sdd-lite/skills/lite-spec/SKILL.md"
# Captured 2026-08-05 at this task's authoring time, against the then-live
# file. plugins/sdd-lite/skills/lite-spec/SKILL.md is never edited live by
# any task in this decomposition (BL-004) -- T-004 stages a draft candidate
# instead -- so this hash holds until the human applies that candidate
# (T-004 handoff; MANIFEST.sha256 step 3). After the apply, the live file
# is byte-identical to the reviewed staged candidate -- until another
# feature's own human-applied change lands on the same shared protected
# file (epic-189 T-012's Track Detection section arrived via PR #229's
# merge, 2026-08-08, additions only). From then on no whole-file hash can
# hold, so past the two whole-file states test_038_staged falls back to
# T-004's own payload: the exact Process step-4 destination block the
# candidate changed must survive in the live file, contiguous and
# byte-identical. Loss or drift of that block still fails.
LITE_LIVE_SHA256_AT_T001='40fdba6f1849effb06a8439a09b92a192a36b42a708c3cf1a253d7d48a50fc74'

# Lines from the first line matching $2 (inclusive) up to, but excluding,
# the first later line matching $3, from file $1. Scopes an assertion to
# one named section/site instead of sweeping the whole file
# (acceptance-tests.md Notes: "assert per-site, never...one repository-wide
# sweep").
section_between() {
  awk -v start="$2" -v end="$3" '
    $0 ~ start { flag = 1 }
    flag && $0 ~ end && $0 !~ start { exit }
    flag { print }
  ' "$1" 2>/dev/null
}

# Collapse text to one whitespace-normalized line, so a multi-word phrase
# assertion is not defeated by Markdown's ordinary prose line-wrapping
# (observed first-hand while validating these assertions against a
# realistic fixture: a phrase such as "both must match" can legitimately
# wrap mid-phrase across two source lines). Only used for phrase/content
# checks, never for the positional checks (TEST-010, TEST-025, TEST-026),
# which need real line boundaries to compare order.
flatten_file() {
  [ -f "$1" ] || return 1
  tr '\n' ' ' <"$1" | tr -s '[:space:]' ' '
}
flatten_text() {
  printf '%s' "$1" | tr '\n' ' ' | tr -s '[:space:]' ' '
}

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" 2>/dev/null | cut -d' ' -f1
  fi
}

# Runtime-assembled banned frequency-model markers, retired by this feature
# (AGENTS.md "Author-time sweeps" item 2; requirements.md Edge Case 8).
# TEST-033..TEST-036's negative half must never embed either retired phrase
# as a contiguous literal in this suite's own source, comments or messages --
# assembled here from non-contiguous parts instead, so this suite cannot
# become a false-positive target of any vocabulary scan run over tests/.
BANNED_PER_UPLOAD="$(printf '%s' 'per-up')$(printf '%s' 'load')"
BANNED_EVERY_TIME="$(printf '%s' 'every')$(printf '%s' ' time')"
BANNED_JA_PER_UPLOAD="$(printf '%s' '都度人間')$(printf '%s' '承認')"

LOOP_SECTION=$(section_between "$DSL" '^## Loop$' '^## ')
BOUNDARIES_SECTION=$(section_between "$DSL" '^## Boundaries$' '^## ')
DSL_CAP_SECTION=$(section_between "$DSL" '^## Capability Detection$' '^## ')
BSI_UI_BULLET=$(section_between "$BSI" '^- When the target is a UI application' '^- Otherwise ask whether the human has a local mockup')
WFG_SECTION=$(section_between "$WFG" '^### 3\.1b ' '^### 3\.2 ')

DSL_FLAT=$(flatten_file "$DSL")
LOOP_FLAT=$(flatten_text "$LOOP_SECTION")
BOUNDARIES_FLAT=$(flatten_text "$BOUNDARIES_SECTION")
DSL_CAP_FLAT=$(flatten_text "$DSL_CAP_SECTION")
BSI_UI_BULLET_FLAT=$(flatten_text "$BSI_UI_BULLET")
WFG_FLAT=$(flatten_text "$WFG_SECTION")
CDW_FLAT=$(flatten_file "$CDW")

# First line number (1-based, within $LOOP_SECTION) matching regex $1.
loop_line_of() {
  printf '%s\n' "$LOOP_SECTION" | grep -n -iE "$1" | head -1 | cut -d: -f1
}

# --- REQ-001 (AC-001, AC-002, AC-026, AC-027, AC-028, AC-030) --------------

if printf '%s' "$LOOP_FLAT" | grep -Eiq 'consent has not been obtained for this scope' \
   && printf '%s' "$LOOP_FLAT" | grep -Eiq 'Obtain informed consent'; then
  pass "TEST-001 first upload in a scope is gated on an explicit consent decision (AC-001 branch 1)"
else
  fail "TEST-001 first upload in a scope is gated on an explicit consent decision (AC-001 branch 1)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Eiq 'consent already holds' \
   && printf '%s' "$LOOP_FLAT" | grep -Eiq 'continue to 5|proceeds? (directly )?to (the )?(pre-upload|step 5)'; then
  pass "TEST-002 subsequent uploads in the same scope proceed without re-prompting (AC-001 branch 2)"
else
  fail "TEST-002 subsequent uploads in the same scope proceed without re-prompting (AC-001 branch 2)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Eiq 'both must match' \
   || printf '%s' "$LOOP_FLAT" | grep -Eiq 'session has ended does not hold'; then
  pass "TEST-003 a different scope does not inherit the consent (AC-001 branch 3)"
else
  fail "TEST-003 a different scope does not inherit the consent (AC-001 branch 3)"
fi

if printf '%s' "$DSL_FLAT" | grep -Eq 'this feature AND this session|this feature and this session' \
   && ! printf '%s' "$DSL_FLAT" | grep -Eiq 'feature or session|feature/session|per-feature/session'; then
  pass "TEST-004 scope names exactly one unit, no disjunction between units (AC-002)"
else
  fail "TEST-004 scope names exactly one unit, no disjunction between units (AC-002)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Eiq 'REQ-NNN' && printf '%s' "$LOOP_FLAT" | grep -Eiq 'AC-NNN' \
   && printf '%s' "$LOOP_FLAT" | grep -Eiq 'confidential|pre-release'; then
  pass "TEST-005 disclosure element (a): payload is specification-derived, may be confidential (AC-003)"
else
  fail "TEST-005 disclosure element (a): payload is specification-derived, may be confidential (AC-003)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Fq 'claude.ai/design' && printf '%s' "$LOOP_FLAT" | grep -Eiq 'external' \
   && printf '%s' "$LOOP_FLAT" | grep -Eiq 'selected in step 1|project selected'; then
  pass "TEST-006 disclosure element (b): destination is claude.ai/design, external, the selected project (AC-003)"
else
  fail "TEST-006 disclosure element (b): destination is claude.ai/design, external, the selected project (AC-003)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Eiq 'may be retained' \
   && printf '%s' "$LOOP_FLAT" | grep -Eiq 'does not control|outside this repository.{0,3}s control'; then
  pass "TEST-007 disclosure element (c): content sent there may be retained, outside repo control (AC-003)"
else
  fail "TEST-007 disclosure element (c): content sent there may be retained, outside repo control (AC-003)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Eiq 'for this session' \
   && printf '%s' "$LOOP_FLAT" | grep -Eiq 'without asking again|without prompting again|proceed without asking'; then
  pass "TEST-008 disclosure states scope and that later uploads proceed without asking again (AC-004)"
else
  fail "TEST-008 disclosure states scope and that later uploads proceed without asking again (AC-004)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Fq 'finalize_plan' \
   && printf '%s' "$LOOP_FLAT" | grep -Eiq 'not (fully )?(known|knowable|established)|opacity|limitation|not (fully )?enumerable'; then
  pass "TEST-009 finalize_plan payload is cited or its opacity is stated as a limitation (AC-005)"
else
  fail "TEST-009 finalize_plan payload is cited or its opacity is stated as a limitation (AC-005)"
fi

t010_gen=$(loop_line_of 'Generate mockups')
t010_consent=$(loop_line_of 'Resolve egress consent|Consent Resolution')
t010_push=$(loop_line_of '\bPush\b')
t010_review=$(loop_line_of 'claude\.ai/design browser')
if [ -n "$t010_gen" ] && [ -n "$t010_consent" ] && [ -n "$t010_push" ] && [ -n "$t010_review" ] \
   && [ "$t010_gen" -lt "$t010_consent" ] && [ "$t010_consent" -lt "$t010_push" ] \
   && [ "$t010_push" -lt "$t010_review" ]; then
  pass "TEST-010 Loop order: generate -> consent -> push -> claude.ai review (AC-006, ordered structure)"
else
  fail "TEST-010 Loop order: generate -> consent -> push -> claude.ai review (AC-006, ordered structure)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Eiq 'Local review is OPTIONAL'; then
  pass "TEST-011 local review carries an optionality marker (AC-007)"
else
  fail "TEST-011 local review carries an optionality marker (AC-007)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Eiq 'no upload waits on it|not a precondition for push'; then
  pass "TEST-012 local review is explicitly stated not to be a precondition for push (AC-007)"
else
  fail "TEST-012 local review is explicitly stated not to be a precondition for push (AC-007)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Eiq 'reach claude\.ai without.{0,20}(any )?human|without any human having read it'; then
  pass "TEST-013 the demotion's consequence is stated where the demotion is described (AC-008)"
else
  fail "TEST-013 the demotion's consequence is stated where the demotion is described (AC-008)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Eq 'return to 2\b' \
   && ! printf '%s' "$LOOP_FLAT" | grep -Eq 'return to 3\b'; then
  pass "TEST-014 regeneration cycle returns to generation (2), not consent (3) (AC-009, ordered structure)"
else
  fail "TEST-014 regeneration cycle returns to generation (2), not consent (3) (AC-009, ordered structure)"
fi

if grep -Fq 'Egress-Consent-Scope' "$DSL" && grep -Fq 'Egress-Consent-Subject' "$DSL" \
   && grep -Fq 'Egress-Destination' "$DSL" && grep -Fq 'Egress-Consent-Expiry' "$DSL" \
   && grep -Fq 'Egress-Consent' "$DSL"; then
  pass "TEST-015 Design-Source record fields are enumerated by name, not a heading check (AC-010)"
else
  fail "TEST-015 Design-Source record fields are enumerated by name, not a heading check (AC-010)"
fi

if grep -Fq 'specs/<feature>/ux-spec.md' "$DSL"; then
  pass "TEST-016 full-profile record destination is specs/<feature>/ux-spec.md (AC-011)"
else
  fail "TEST-016 full-profile record destination is specs/<feature>/ux-spec.md (AC-011)"
fi

# TEST-017 targets the STAGED draft candidate (T-004), never the live,
# protected plugins/sdd-lite/skills/lite-spec/SKILL.md -- red against the
# live tree until T-004 lands (tasks.md T-001 Done-When, per-Test-ID
# structural correctness bullet).
if [ -f "$DSC_DRAFT" ] && grep -Fq 'specs/<feature>/design.md' "$DSC_DRAFT"; then
  pass "TEST-017 lite-profile record destination is specs/<feature>/design.md, staged draft (AC-011)"
else
  fail "TEST-017 lite-profile record destination is specs/<feature>/design.md, staged draft (AC-011)"
fi

# TEST-018 -- load-bearing (security-spec.md:169). Structural: requires the
# negation RELATIONSHIP (audit trace .. not .. authorization) within one
# neighbourhood, not the independent presence of the two vocabulary words.
# Demonstrated against a deliberately vacuous fixture in the implementation
# report (tasks.md T-001 Done-When), not embedded in this suite.
if printf '%s' "$DSL_FLAT" | grep -Eiq 'audit trace[^.]{0,100}not[^.]{0,60}authorization'; then
  pass "TEST-018 record is an audit trace, not an authorization anything enforces (AC-012, load-bearing)"
else
  fail "TEST-018 record is an audit trace, not an authorization anything enforces (AC-012, load-bearing)"
fi

if printf '%s' "$DSL_CAP_FLAT" | grep -Eiq 'tool is unavailable' \
   && printf '%s' "$DSL_CAP_FLAT" | grep -Fq 'design tools unavailable'; then
  pass "TEST-019 capability-detection branch 1: tool unavailable -> fallback, marker recorded (AC-013)"
else
  fail "TEST-019 capability-detection branch 1: tool unavailable -> fallback, marker recorded (AC-013)"
fi

if printf '%s' "$DSL_CAP_FLAT" | grep -Eiq 'authentication fails' \
   && printf '%s' "$DSL_CAP_FLAT" | grep -Fq 'design tools unavailable'; then
  pass "TEST-020 capability-detection branch 2: authentication failure -> fallback, marker recorded (AC-013)"
else
  fail "TEST-020 capability-detection branch 2: authentication failure -> fallback, marker recorded (AC-013)"
fi

if grep -Fq 'does not automatically inspect, upload, or retain' "$CDW" \
   && ! printf '%s' "$CDW_FLAT" | grep -Eiq 'consent'; then
  pass "TEST-021 fallback still performs no upload, and gained no consent step (AC-014, positive+negative)"
else
  fail "TEST-021 fallback still performs no upload, and gained no consent step (AC-014, positive+negative)"
fi

if printf '%s' "$BOUNDARIES_FLAT" | grep -Eiq 'absence of mockups.{0,20}never blocks|mockups or design tools'; then
  pass "TEST-022 non-blocking condition 1: absence of mockups never blocks review (AC-015)"
else
  fail "TEST-022 non-blocking condition 1: absence of mockups never blocks review (AC-015)"
fi

if printf '%s' "$BOUNDARIES_FLAT" | grep -Eiq 'design tools.{0,20}never blocks|mockups or design tools'; then
  pass "TEST-023 non-blocking condition 2: absence of design tools never blocks review (AC-015)"
else
  fail "TEST-023 non-blocking condition 2: absence of design tools never blocks review (AC-015)"
fi

if grep -Fq 'no artifacts and no' "$BSI" && grep -Fq 'further design-system questions' "$BSI"; then
  pass "TEST-024 ds_profile: none keeps no artifacts / no further questions; no consent leak (AC-016)"
else
  fail "TEST-024 ds_profile: none keeps no artifacts / no further questions; no consent leak (AC-016)"
fi

t025_cp=$(loop_line_of 'Pre-upload check point')
t025_consent=$(loop_line_of 'Resolve egress consent|Consent Resolution')
if [ -n "$t025_cp" ] && [ -n "$t025_consent" ] && [ "$t025_cp" != "$t025_consent" ] \
   && printf '%s' "$LOOP_FLAT" | grep -Fq 'specs/<feature>/mockups/'; then
  pass "TEST-025 pre-upload check point named, distinct from consent, over mockups/ (AC-017)"
else
  fail "TEST-025 pre-upload check point named, distinct from consent, over mockups/ (AC-017)"
fi

# TEST-026 -- structural, load-bearing (security-spec.md:169): the
# consent-already-holds path routes to the named pre-upload point, and every
# upload call follows that point. Deliberately scans only `write_files` (the call the
# security-spec.md B1 boundary and the loop's own Push step name as the
# actual sender), not `finalize_plan` too: `finalize_plan` is legitimately
# *discussed*, never called, inside step 4's disclosure (the OQ-6 hedge
# AC-005/TEST-009 requires), which sits before the check point by design --
# scanning for it as an upload-call site would make this test fail against
# a conforming file, the opposite of what a structural check should do.
# Demonstrated against a deliberately vacuous fixture in the implementation
# report (tasks.md T-001 Done-When), not embedded in this suite.
test_026_no_bypass() {
  cp_line=$(loop_line_of 'Pre-upload check point')
  [ -n "$cp_line" ] || return 1
  consent_holds_target=$(printf '%s\n' "$LOOP_SECTION" | awk '
    /^[[:space:]]*- \*\*\(a\)/ { in_outcome_a = 1 }
    in_outcome_a && /continue to [0-9]+ with no prompt/ {
      match($0, /continue to [0-9]+/)
      target = substr($0, RSTART, RLENGTH)
      sub(/^continue to /, "", target)
      print target
      exit
    }
    in_outcome_a && /^[[:space:]]*- \*\*\(b\)/ { exit }
  ')
  [ "$consent_holds_target" = "5" ] || return 1
  upload_lines=$(printf '%s\n' "$LOOP_SECTION" | grep -n -E 'write_files' | cut -d: -f1)
  [ -n "$upload_lines" ] || return 1
  for l in $upload_lines; do
    [ "$l" -ge "$cp_line" ] || return 1
  done
  return 0
}
if test_026_no_bypass; then
  pass "TEST-026 no upload path in the Loop bypasses the pre-upload check point (AC-017, structural)"
else
  fail "TEST-026 no upload path in the Loop bypasses the pre-upload check point (AC-017, structural)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Fq 'property of the check' \
   && printf '%s' "$LOOP_FLAT" | grep -Eiq 'does not presume.{0,10}an interactive human'; then
  pass "TEST-027 check point's blocking behaviour carries no interactive-human precondition (AC-018)"
else
  fail "TEST-027 check point's blocking behaviour carries no interactive-human precondition (AC-018)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Eiq 'consent has not been obtained for this scope'; then
  pass "TEST-028 consent-resolution outcome 1: must be requested (AC-019)"
else
  fail "TEST-028 consent-resolution outcome 1: must be requested (AC-019)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Eiq 'consent already holds for this feature'; then
  pass "TEST-029 consent-resolution outcome 2: already holds for this scope (AC-019)"
else
  fail "TEST-029 consent-resolution outcome 2: already holds for this scope (AC-019)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Eiq 'egress is not permitted' \
   && printf '%s' "$LOOP_FLAT" | grep -Eiq 'manual fallback' \
   && printf '%s' "$LOOP_FLAT" | grep -Eiq 'no upload'; then
  pass "TEST-030 consent-resolution outcome 3: not permitted -> manual fallback, no upload (AC-019)"
else
  fail "TEST-030 consent-resolution outcome 3: not permitted -> manual fallback, no upload (AC-019)"
fi

if printf '%s' "$DSL_FLAT" | grep -Eiq 'extensible' && printf '%s' "$DSL_FLAT" | grep -Eiq 'ignored|non-conforming'; then
  pass "TEST-031 Design-Source shape is stated as additively extensible (AC-020)"
else
  fail "TEST-031 Design-Source shape is stated as additively extensible (AC-020)"
fi

if printf '%s' "$DSL_FLAT" | grep -Eiq 'per-feature.{0,80}(select|default)|(select|default).{0,80}per-feature'; then
  pass "TEST-032 this feature's behaviour is the one a later per-feature setting selects (AC-020)"
else
  fail "TEST-032 this feature's behaviour is the one a later per-feature setting selects (AC-020)"
fi

DSL_DESC_LINE=$(grep -m1 '^description:' "$DSL")
if [ -n "$DSL_DESC_LINE" ] \
   && ! printf '%s' "$DSL_DESC_LINE" | grep -Fq "$BANNED_PER_UPLOAD" \
   && printf '%s' "$DSL_DESC_LINE" | grep -Eiq 'per-feature|feature.{0,15}(and|AND).{0,15}session'; then
  pass "TEST-033 site 1 (frontmatter description) states the per-feature model, not ${BANNED_PER_UPLOAD} (AC-021)"
else
  fail "TEST-033 site 1 (frontmatter description) states the per-feature model, not ${BANNED_PER_UPLOAD} (AC-021)"
fi

if [ -n "$BOUNDARIES_SECTION" ] \
   && ! printf '%s' "$BOUNDARIES_FLAT" | grep -Fq "$BANNED_EVERY_TIME" \
   && printf '%s' "$BOUNDARIES_FLAT" | grep -Eiq 'per-feature|feature.{0,15}(and|AND).{0,15}session'; then
  pass "TEST-034 site 2 (Boundaries) states the per-feature model, not ${BANNED_EVERY_TIME} (AC-021)"
else
  fail "TEST-034 site 2 (Boundaries) states the per-feature model, not ${BANNED_EVERY_TIME} (AC-021)"
fi

if [ -n "$BSI_UI_BULLET" ] \
   && ! printf '%s' "$BSI_UI_BULLET_FLAT" | grep -Fq "$BANNED_PER_UPLOAD" \
   && printf '%s' "$BSI_UI_BULLET_FLAT" | grep -Eiq 'per-feature|feature.{0,15}(and|AND).{0,15}session'; then
  pass "TEST-035 site 3 (sdd-bootstrap-interviewer) states the per-feature model, not ${BANNED_PER_UPLOAD} (AC-021)"
else
  fail "TEST-035 site 3 (sdd-bootstrap-interviewer) states the per-feature model, not ${BANNED_PER_UPLOAD} (AC-021)"
fi

if [ -n "$WFG_SECTION" ] \
   && ! printf '%s' "$WFG_FLAT" | grep -Fq "$BANNED_JA_PER_UPLOAD" \
   && printf '%s' "$WFG_FLAT" | grep -Fq 'セッション'; then
  pass "TEST-036 site 4 (workflow-guide.md, Japanese) states the per-feature/session model (AC-021)"
else
  fail "TEST-036 site 4 (workflow-guide.md, Japanese) states the per-feature/session model (AC-021)"
fi

# TEST-037 -- regression (negative): the historical release note is
# byte-identical to its pre-change content (BL-006, AC-022). Located by an
# ASCII-only anchor ("design-sync-loop`", backtick immediately following,
# unique in CHANGELOG.md) rather than a hardcoded line number, then
# compared by SHA-256 over the anchor line plus the following four lines --
# a true byte-identity check.
test_037_unchanged() {
  anchor_line=$(grep -n 'design-sync-loop`' "$CHG" | head -1 | cut -d: -f1)
  [ -n "$anchor_line" ] || return 1
  end_line=$((anchor_line + 4))
  block=$(sed -n "${anchor_line},${end_line}p" "$CHG")
  actual_hash=$(printf '%s\n' "$block" | shasum -a 256 2>/dev/null | cut -d' ' -f1)
  if [ -z "$actual_hash" ]; then
    actual_hash=$(printf '%s\n' "$block" | sha256sum 2>/dev/null | cut -d' ' -f1)
  fi
  [ -n "$actual_hash" ] || return 1
  [ "$actual_hash" = "4d911e7a8adc86e9ea79adfe1bec5c6e26b62c939a6f0dde517d204a2ef410c8" ]
}
if test_037_unchanged; then
  pass "TEST-037 CHANGELOG.md historical release note is byte-identical to pre-change content (AC-022)"
else
  fail "TEST-037 CHANGELOG.md historical release note is byte-identical to pre-change content (AC-022)"
fi

test_038_staged() {
  [ -f "$DSC_DRAFT" ] || return 1
  [ -f "$DSC_MANIFEST" ] || return 1
  draft_hash=$(sha256_of "$DSC_DRAFT")
  [ -n "$draft_hash" ] || return 1
  grep -Eq "^${draft_hash}[[:space:]]+.*${LITE_DEST_NAME}\$" "$DSC_MANIFEST" || return 1
  live_hash=$(sha256_of "$LITE_LIVE")
  # Three designed epochs (see LITE_LIVE_SHA256_AT_T001's comment):
  # pre-apply the live file is untouched; applied-verbatim it is the
  # reviewed candidate; once other features' human-applied changes land on
  # the same shared protected file, whole-file identity cannot hold and
  # the check falls back to T-004's own payload block. The fallback fires
  # only after both whole-file comparisons miss, and requires the anchor
  # to be unique in each file, so ambiguity fails closed.
  [ "$live_hash" = "$LITE_LIVE_SHA256_AT_T001" ] && return 0
  [ "$live_hash" = "$draft_hash" ] && return 0
  payload_anchor='design.md` に記録される'
  [ "$(grep -cF -- "$payload_anchor" "$DSC_DRAFT")" = "1" ] || return 1
  [ "$(grep -cF -- "$payload_anchor" "$LITE_LIVE")" = "1" ] || return 1
  draft_block=$(grep -F -A2 -- "$payload_anchor" "$DSC_DRAFT")
  [ -n "$draft_block" ] || return 1
  live_block=$(grep -F -A2 -- "$payload_anchor" "$LITE_LIVE")
  [ "$draft_block" = "$live_block" ]
}
if test_038_staged; then
  pass "TEST-038 lite-spec change staged, live file unmodified or applied verbatim, manifest hash matches (AC-023)"
else
  fail "TEST-038 lite-spec change staged, live file unmodified or applied verbatim, manifest hash matches (AC-023)"
fi

# TEST-039 -- CI-registration conformance. Traced from a CI entry point
# (.github/workflows/*.yml) to this suite, in both runtimes. Expected RED
# against the live tree until a human applies the separately staged
# workflow patch (R-OQ-8 part 3) -- not this task's or T-005's to fix.
test_039_ci_registered() {
  ci_dir="$ROOT/.github/workflows"
  [ -d "$ci_dir" ] || return 1
  has_sh=0
  has_ps1=0
  for wf in "$ci_dir"/*.yml "$ci_dir"/*.yaml; do
    [ -f "$wf" ] || continue
    grep -q 'design-system-contract\.tests\.sh' "$wf" && has_sh=1
    grep -q 'design-system-contract\.tests\.ps1' "$wf" && has_ps1=1
  done
  [ "$has_sh" -eq 1 ] && [ "$has_ps1" -eq 1 ]
}
if test_039_ci_registered; then
  pass "TEST-039 this feature's assertions are reachable from a CI entry point (AC-024)"
else
  fail "TEST-039 this feature's assertions are reachable from a CI entry point (AC-024) -- DESIGNED RED: staged workflow patch not yet applied (R-OQ-8 part 3)"
fi

if grep -Eq '^## Ensure design-system/$' "$DSL" && grep -Fq 'ui-ux-pro-max' "$DSL" \
   && grep -Fq 'design-system --persist' "$DSL" \
   && grep -Fq 'ui-ux-pro-max unavailable — D6 template interview used' "$DSL" \
   && grep -Fq 'figma-dtcg-import' "$DSL" && grep -Eq 'design-system/design-tokens\.json' "$DSL" \
   && grep -Fq 'MASTER.md' "$DSL"; then
  pass "TEST-040 the seven pre-existing DS-006 literals still pass (AC-025, regression)"
else
  fail "TEST-040 the seven pre-existing DS-006 literals still pass (AC-025, regression)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Eiq 'no upload' && printf '%s' "$LOOP_FLAT" | grep -Eiq 'decline'; then
  pass "TEST-041 a decline blocks that upload -- no upload occurs (AC-026)"
else
  fail "TEST-041 a decline blocks that upload -- no upload occurs (AC-026)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Eiq 'next (one|attempt).{0,20}asks again|next upload attempt.{0,20}prompts again'; then
  pass "TEST-042 the next upload attempt within the same scope prompts again (AC-026)"
else
  fail "TEST-042 the next upload attempt within the same scope prompts again (AC-026)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Eiq 'not the same thing as a decline at 4'; then
  pass "TEST-043 a decline is distinguished from AC-019's persistent not-permitted outcome (AC-026)"
else
  fail "TEST-043 a decline is distinguished from AC-019's persistent not-permitted outcome (AC-026)"
fi

if printf '%s' "$DSL_FLAT" | grep -Fq 'Egress-Destination' \
   && printf '%s' "$DSL_FLAT" | grep -Eiq 'project selected in step 1|selected in step 1'; then
  pass "TEST-044 the consent names the destination project as part of its coverage (AC-027)"
else
  fail "TEST-044 the consent names the destination project as part of its coverage (AC-027)"
fi

if printf '%s' "$DSL_FLAT" | grep -Eiq 'does not carry to|re-enters step 4|different destination.{0,30}gated again'; then
  pass "TEST-045 a different destination project does not inherit the consent, is gated again (AC-027)"
else
  fail "TEST-045 a different destination project does not inherit the consent, is gated again (AC-027)"
fi

if printf '%s' "$DSL_FLAT" | grep -Eiq 'withdraw' && printf '%s' "$DSL_FLAT" | grep -Eiq 'mid-session'; then
  pass "TEST-046 a mid-session withdrawal path is stated (AC-028)"
else
  fail "TEST-046 a mid-session withdrawal path is stated (AC-028)"
fi

if printf '%s' "$DSL_FLAT" | grep -Eiq 'withdraw' \
   && printf '%s' "$DSL_FLAT" | grep -Eiq 'gated again|does not hold'; then
  pass "TEST-047 after withdrawal, the next upload within that scope is gated again (AC-028)"
else
  fail "TEST-047 after withdrawal, the next upload within that scope is gated again (AC-028)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Eiq 'future regenerations' && printf '%s' "$LOOP_FLAT" | grep -Eiq 'for this session'; then
  pass "TEST-048 disclosure element (d): coverage includes future regenerations, this session (AC-029)"
else
  fail "TEST-048 disclosure element (d): coverage includes future regenerations, this session (AC-029)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Eiq 'pull direction' && printf '%s' "$LOOP_FLAT" | grep -Eiq 'human-supplied project name'; then
  pass "TEST-049 disclosure element (e): the pull direction also transmits a project name (AC-029)"
else
  fail "TEST-049 disclosure element (e): the pull direction also transmits a project name (AC-029)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Eiq 'asserting.{0,20}authority' \
   && printf '%s' "$LOOP_FLAT" | grep -Eiq 'claim, not a check|not enforced'; then
  pass "TEST-050 disclosure element (f): operator asserts authority to send content externally (AC-029)"
else
  fail "TEST-050 disclosure element (f): operator asserts authority to send content externally (AC-029)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Eiq 'not change consent state' \
   && printf '%s' "$LOOP_FLAT" | grep -Eiq 'reports the failure' \
   && printf '%s' "$LOOP_FLAT" | grep -Eiq 'no re-prompt|without a new consent prompt' \
   && printf '%s' "$LOOP_FLAT" | grep -Eiq 'no standing forbiddance'; then
  pass "TEST-051 push-failure rule, all four parts (AC-030)"
else
  fail "TEST-051 push-failure rule, all four parts (AC-030)"
fi

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
[ "$FAIL" -eq 0 ]
