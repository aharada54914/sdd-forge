#!/bin/sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCHEMA="$ROOT/contracts/design-system.contract.v1.schema.json"
TOKENS="$ROOT/plugins/sdd-bootstrap/skills/design-sync-loop/templates/design-tokens.template.json"
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
DS="$ROOT/plugins/sdd-bootstrap/skills/design-sync-loop/templates/design-system.template.md"
assert_contains "$DS" '^## Layer 1 — Tokens \(machine-extracted\)$' "DS-003 layer 1 section"
assert_contains "$DS" '^## Layer 2 — Do / Don'"'"'t \(component conventions\)$' "DS-003 layer 2 section"
assert_contains "$DS" '^## Layer 3 — Review checklist \(human-curated\)$' "DS-003 layer 3 section"
assert_contains "$DS" '^## Change Process$' "DS-003 change process section"
assert_contains "$DS" 'WCAG 2\.2 AA' "DS-003 WCAG 2.2 AA"

# DS-004 ui-patterns.md template required sections (D6 categories)
UIP="$ROOT/plugins/sdd-bootstrap/skills/design-sync-loop/templates/ui-patterns.template.md"
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
assert_contains "$DSL" '^## [0-9]+\. Ensure `design-system/`' "DS-006 ensure section"
assert_contains "$DSL" 'ui-ux-pro-max' "DS-006 seed generator detection"
assert_contains "$DSL" 'design-system --persist' "DS-006 seed generation command"
assert_contains "$DSL" 'ui-ux-pro-max unavailable — D6 template interview used' "DS-006 D6 fallback note"
assert_contains "$DSL" 'Figma DTCG JSON.*ローカルファイル.*design-tokens\.json' "DS-006 figma DTCG import path"
assert_contains "$DSL" 'Generate Mockups.*トークン準拠' "DS-006 mockups reference tokens"
assert_contains "$DSL" 'MASTER\.md' "DS-006 seed is input, artifacts authoritative"

# DS-007 investigate-codebase brownfield design inventory
INV="$ROOT/plugins/sdd-bootstrap/skills/investigate-codebase/SKILL.md"
assert_contains "$INV" 'Design Inventory' "DS-007 design inventory group"
# DS-007 v2 wording: tests/fixtures/design-system-contract/v2-needles.json

# Retired 2026-11-28 (T-010, ADR-0051 decision 2): DS-008 and DS-009 read the retired interviewer
# design template and the retired sdd-lite template.
# DS-010 impl-reviewer-a design-system conformance check
# Retired 2026-11-28 (T-010, ADR-0051 decision 2): DS-010/DS-011 reviewer checks read the retired impl reviewers.
PRC="$ROOT/plugins/sdd-review-loop/references/phase-review-checklist.md"
assert_contains "$PRC" '^#### DESIGN-SYSTEM-CONFORMANCE$' "DS-010 checklist block"
assert_contains "$PRC" 'impl-review-loop`: 22 checks' "DS-010 impl count updated"

# DS-011 impl-reviewer-b unsanctioned UI library rule
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
assert_contains "$VVL" 'design-system/\{design-tokens\.json,ui-patterns\.md\}' "DS-013 token conformance in loop"
assert_contains "$VVL" 'design-system/\{design-tokens\.json,ui-patterns\.md\}' "DS-013 ui-patterns in loop"
assert_contains "$VVL" 'verdicts stay with sdd-gate' "DS-013 the loop leaves verdicts to sdd-gate (v2 gate ownership)"

# DS-014 design-system checklist and evaluator wiring
DSC="$ROOT/plugins/sdd-quality-loop/references/design-system-checklist.md"
assert_contains "$DSC" '^# Design System Review Checklist$' "DS-014 checklist exists"
assert_contains "$DSC" '^## UI Patterns \(ui-patterns\.md\)$' "DS-014 ui-patterns section"
RUB="$ROOT/plugins/sdd-quality-loop/references/evaluation-rubric.md"
assert_contains "$RUB" 'design-system non-conformance' "DS-014 rubric Major classification"
assert_contains "$ROOT/plugins/sdd-quality-loop/agents/evaluator.md" 'G5.*design-system/' "DS-014 the v2 evaluator checks design-system conformance (G5)"

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
# Retired 2026-11-28 (T-010, ADR-0051 decision 2): the retired quality-gate skill ran check-design-system. The v2 gate does
# not run it; like check-component-coverage (T-010 N2) it ships as a standalone check.
assert_contains "$ROOT/docs/skill-reference.md" 'check-design-system' "DS-016 check-design-system stays documented as a standalone check"

# DS-017 user-facing documentation
assert_contains "$ROOT/docs/skill-reference.md" '^\| design-sync-loop \| sdd-bootstrap \|' "DS-017 skill reference lists design-sync-loop"
# DS-017 workflow guide: tests/fixtures/design-system-contract/v2-needles.json
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

WFG="$ROOT/docs/workflow-guide.md"
CDW="$ROOT/plugins/sdd-bootstrap/skills/design-sync-loop/references/claude-design-workflow.md"
CHG="$ROOT/CHANGELOG.md"
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

# v2 rewrote the loop as step 3 of the skill (Japanese).
LOOP_SECTION=$(section_between "$DSL" '^## 3\. Mockup & Egress Consent Loop' '^## ')
BOUNDARIES_SECTION=$(section_between "$DSL" '^## Boundaries$' '^## ')

DSL_FLAT=$(flatten_file "$DSL")
LOOP_FLAT=$(flatten_text "$LOOP_SECTION")
BOUNDARIES_FLAT=$(flatten_text "$BOUNDARIES_SECTION")
CDW_FLAT=$(flatten_file "$CDW")

# First line number (1-based, within $LOOP_SECTION) matching regex $1.
loop_line_of() {
  printf '%s\n' "$LOOP_SECTION" | grep -n -iE "$1" | head -1 | cut -d: -f1
}

# --- REQ-001 (AC-001, AC-002, AC-026, AC-027, AC-028, AC-030) --------------

if node "$ROOT/tests/lib/bootstrap-core-contracts.mjs" consent-initial; then
  pass "TEST-001 first upload in a scope is gated on an explicit consent decision (AC-001 branch 1)"
else
  fail "TEST-001 first upload in a scope is gated on an explicit consent decision (AC-001 branch 1)"
fi

if python3 -B "$ROOT/tests/design-sync-policy.tests.py" PolicyTests.test_subsequent_uploads_reuse_current_grant; then
  pass "TEST-002 subsequent uploads in the same scope proceed without re-prompting (AC-001 branch 2)"
else
  fail "TEST-002 subsequent uploads in the same scope proceed without re-prompting (AC-001 branch 2)"
fi

if python3 -B "$ROOT/tests/design-sync-policy.tests.py" PolicyTests.test_different_feature_or_session_requires_consent; then
  pass "TEST-003 a different scope does not inherit the consent (AC-001 branch 3)"
else
  fail "TEST-003 a different scope does not inherit the consent (AC-001 branch 3)"
fi

# TEST-004: tests/fixtures/design-system-contract/v2-needles.json

check_consent_policy() {
  if python3 -B "$ROOT/tests/design-sync-policy.tests.py" "PolicyTests.$1"; then
    pass "$2"
  else
    fail "$2"
  fi
}
check_consent_policy 'test_disclosure_payload' 'TEST-005 disclosure element (a): payload is specification-derived, may be confidential (AC-003)'
check_consent_policy 'test_disclosure_destination' 'TEST-006 disclosure element (b): destination is claude.ai/design, external, the selected project (AC-003)'
check_consent_policy 'test_disclosure_retention' 'TEST-007 disclosure element (c): content sent there may be retained, outside repo control (AC-003)'
check_consent_policy 'test_disclosure_repeated_uploads' 'TEST-008 disclosure states scope and that later uploads proceed without asking again (AC-004)'
check_consent_policy 'test_disclosure_regenerated_mockups' 'TEST-048 disclosure element (d): coverage includes future regenerations, this session (AC-029)'
check_consent_policy 'test_disclosure_operator_authority' 'TEST-050 disclosure element (f): operator asserts authority to send content externally (AC-029)'

# Retired 2026-11-28 (T-010, ADR-0051 decision 2): TEST-009 cited the v1 finalize_plan call, which v2 does not use.

t010_gen=$(loop_line_of 'Generate mockups')
t010_consent=$(loop_line_of 'Resolve egress consent|Consent Resolution')
t010_push=$(loop_line_of '\bPush\b')
t010_review=$(loop_line_of 'claude\.ai/design browser')
# TEST-010: tests/fixtures/design-system-contract/v2-needles.json




# Retired 2026-11-28 (T-010, ADR-0051 decision 2): TEST-011..TEST-013 described the v1 optional local review step, which v2 removed.
# TEST-014: tests/fixtures/design-system-contract/v2-needles.json

# TEST-015: tests/fixtures/design-system-contract/v2-needles.json

# TEST-016: tests/fixtures/design-system-contract/v2-needles.json

# TEST-017 targets the STAGED draft candidate (T-004), never the live,
# protected plugins/sdd-lite/skills/lite-spec/SKILL.md -- red against the
# live tree until T-004 lands (tasks.md T-001 Done-When, per-Test-ID
# structural correctness bullet).
# Retired 2026-11-28 (T-010, ADR-0051 decision 2): TEST-017 read the staged sdd-lite candidate; sdd-lite retired.

# TEST-018 -- load-bearing (security-spec.md:169). Structural: requires the
# negation RELATIONSHIP (audit trace .. not .. authorization) within one
# neighbourhood, not the independent presence of the two vocabulary words.
# Demonstrated against a deliberately vacuous fixture in the implementation
# report (tasks.md T-001 Done-When), not embedded in this suite.
# v2 feeds earlier records (e.g. withdrawn) back into the resolver, so the v1
# statement that nothing reads the record retired; what remains is that the
# tool never verifies the operator's authority to send.
# TEST-018: tests/fixtures/design-system-contract/v2-needles.json

if node "$ROOT/tests/lib/bootstrap-core-contracts.mjs" tool-unavailable; then
  pass "TEST-019 capability-detection branch 1: tool unavailable -> fallback, marker recorded (AC-013)"
else
  fail "TEST-019 capability-detection branch 1: tool unavailable -> fallback, marker recorded (AC-013)"
fi

if node "$ROOT/tests/lib/bootstrap-core-contracts.mjs" auth-failed; then
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

if printf '%s' "$CDW_FLAT" | grep -Eiq 'mockups and HTML previews are optional attachments.{0,25}absence never blocks specification review'; then
  pass "TEST-022 non-blocking condition 1: absence of mockups never blocks review (AC-015)"
else
  fail "TEST-022 non-blocking condition 1: absence of mockups never blocks review (AC-015)"
fi

# TEST-023: tests/fixtures/design-system-contract/v2-needles.json

# TEST-024: tests/fixtures/design-system-contract/v2-needles.json

# TEST-025: tests/fixtures/design-system-contract/v2-needles.json

# TEST-026: tests/fixtures/design-system-contract/v2-needles.json

# TEST-027: tests/fixtures/design-system-contract/v2-needles.json

if node "$ROOT/tests/lib/bootstrap-core-contracts.mjs" consent-prompt; then
  pass "TEST-028 consent-resolution outcome 1: must be requested (AC-019)"
else
  fail "TEST-028 consent-resolution outcome 1: must be requested (AC-019)"
fi

# TEST-029: tests/fixtures/design-system-contract/v2-needles.json

if node "$ROOT/tests/lib/bootstrap-core-contracts.mjs" consent-off; then
  pass "TEST-030 consent-resolution outcome 3: not permitted -> manual fallback, no upload (AC-019)"
else
  fail "TEST-030 consent-resolution outcome 3: not permitted -> manual fallback, no upload (AC-019)"
fi

# Retired 2026-11-28 (T-010, ADR-0051 decision 2): TEST-031 checked a v1 extensibility statement that v2 does not make.

# TEST-032: tests/fixtures/design-system-contract/v2-needles.json

DSL_DESC_LINE=$(grep -m1 '^description:' "$DSL")
if [ -n "$DSL_DESC_LINE" ] \
   && ! printf '%s' "$DSL_DESC_LINE" | grep -Fq "$BANNED_PER_UPLOAD" \
   && printf '%s' "$DSL_DESC_LINE" | grep -Fq 'explicit egress consent'; then
  pass "TEST-033 site 1 (frontmatter description) states explicit consent, not ${BANNED_PER_UPLOAD} (AC-021)"
else
  fail "TEST-033 site 1 (frontmatter description) states explicit consent, not ${BANNED_PER_UPLOAD} (AC-021)"
fi

if [ -n "$BOUNDARIES_SECTION" ] \
   && ! printf '%s' "$BOUNDARIES_FLAT" | grep -Fq "$BANNED_EVERY_TIME"; then
  pass "TEST-034 site 2 (Boundaries) does not claim ${BANNED_EVERY_TIME} consent (AC-021)"
else
  fail "TEST-034 site 2 (Boundaries) does not claim ${BANNED_EVERY_TIME} consent (AC-021)"
fi

# Retired 2026-11-28 (T-010, ADR-0051 decision 2): TEST-035 read the retired interviewer and TEST-036 a workflow-guide
# section v2 removed; the per-feature model itself is TEST-032.


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

# Retired 2026-11-28 (T-010, ADR-0051 decision 2): TEST-038 checked the staged sdd-lite candidate; sdd-lite retired.

# Retired 2026-11-28 (T-010, ADR-0051 decision 2): TEST-039 waited for a staged v1 workflow patch. v2 registers suites in
# tests/verification-catalog.json (verification-catalog-status reports CI reach).

if grep -Eq '^## [0-9]+\. Ensure `design-system/`' "$DSL" && grep -Fq 'ui-ux-pro-max' "$DSL" \
   && grep -Fq 'design-system --persist' "$DSL" \
   && grep -Fq 'ui-ux-pro-max unavailable — D6 template interview used' "$DSL" \
   && grep -Fq 'figma-dtcg-import' "$DSL" && grep -Eq 'design-system/design-tokens\.json' "$DSL" \
   && grep -Fq 'MASTER.md' "$DSL"; then
  pass "TEST-040 the seven pre-existing DS-006 literals still pass (AC-025, regression)"
else
  fail "TEST-040 the seven pre-existing DS-006 literals still pass (AC-025, regression)"
fi

check_consent_policy 'test_decline_stops_current_upload' "TEST-041 a decline blocks that upload -- no upload occurs (AC-026)"
check_consent_policy 'test_retry_after_decline_prompts_again' "TEST-042 the next upload attempt within the same scope prompts again (AC-026)"
check_consent_policy 'test_decline_is_distinct_from_prohibition' "TEST-043 a decline is distinguished from AC-019's persistent not-permitted outcome (AC-026)"
check_consent_policy 'test_consent_binds_selected_project' "TEST-044 the consent names the destination project as part of its coverage (AC-027)"
check_consent_policy 'test_destination_change_checks_its_own_grant' "TEST-045 a different destination project does not inherit the consent, is gated again (AC-027)"
check_consent_policy 'test_operator_can_withdraw_during_session' "TEST-046 a mid-session withdrawal path is stated (AC-028)"
check_consent_policy 'test_withdrawn_consent_needs_fresh_grant' "TEST-047 after withdrawal, the next upload within that scope is gated again (AC-028)"

# TEST-049: tests/fixtures/design-system-contract/v2-needles.json

# Retired 2026-11-28 (T-010, ADR-0051 decision 2): TEST-051 checked the v1 push-failure rule; v2 states none (reported as an
# open question in the T-010 implementation report).

# v2 skill wording (Japanese), shared with the PowerShell twin through one
# UTF-8 fixture so the two runtimes check identical needles (T-010).
V2_NEEDLES="$ROOT/tests/fixtures/design-system-contract/v2-needles.json"
v2_results=$(python3 - "$ROOT" "$V2_NEEDLES" <<'PY'
import json, re, sys
from pathlib import Path
root, fixture = Path(sys.argv[1]), json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
dsl_path = root / "plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md"
dsl_lines = dsl_path.read_text(encoding="utf-8").splitlines()
def section(bounds):
    start, end = (re.compile(b) for b in bounds)
    out, inside = [], False
    for line in dsl_lines:
        if inside and end.search(line) and not start.search(line):
            break
        if start.search(line):
            inside = True
        if inside:
            out.append(line)
    return out
flat = lambda lines: " ".join(" ".join(lines).split())
loop = section(fixture["loop_section"])
scopes = {"loop": flat(loop), "dsl": flat(dsl_lines), "boundaries": flat(section(fixture["boundaries_section"]))}
for check in fixture["checks"]:
    scope = check["scope"]
    text = scopes[scope] if scope in scopes else flat((root / scope[5:]).read_text(encoding="utf-8").splitlines())
    ok = all(" ".join(n.split()) in text for n in check["contains"]) and not any(n in text for n in check["absent"])
    print(("PASS " if ok else "FAIL ") + check["label"])
order = fixture["order"]
positions = [next((i for i, line in enumerate(loop) if re.search(step, line)), -1) for step in order["steps"]]
print(("PASS " if -1 not in positions and positions == sorted(positions) and len(set(positions)) == len(positions) else "FAIL ") + order["label"])
PY
)
while IFS= read -r line; do
  case "$line" in
    PASS\ *) pass "${line#PASS }" ;;
    FAIL\ *) fail "${line#FAIL }" ;;
    *) fail "v2 needle runner: $line" ;;
  esac
done <<EOF_V2
$v2_results
EOF_V2
[ -n "$v2_results" ] || fail "v2 needle runner produced no result"

if node "$ROOT/tests/lib/bootstrap-core-contracts.mjs" design-system; then
  pass "Core design-system contract"
else
  fail "Core design-system contract"
fi

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
[ "$FAIL" -eq 0 ]
