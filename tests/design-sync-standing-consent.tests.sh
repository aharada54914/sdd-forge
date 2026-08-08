#!/bin/sh
set -u

# design-sync-standing-consent (issue #140, DS-31) -- TEST-001..TEST-053,
# TEST-055, TEST-056 (55 blocking rows) plus TEST-054 (Deferred, non-
# blocking) -- specs/design-sync-standing-consent/tasks.md T-001.
#
# T-001's own scope is authoring these assertions against
# specs/design-sync-standing-consent/acceptance-tests.md's Test Matrix. The
# content most of them check -- AGENTS.md's new "## Project Settings"
# section, design-sync-loop/SKILL.md's step-3 outer branch and Design-Source
# field table, claude-design-workflow.md's new indirect-reference bullet --
# is produced by T-002/T-003/T-004, none of which has landed at this task's
# authoring time. Most TEST-NNN below are therefore expected to FAIL (RED)
# against the live tree until those tasks land; that RED is this task's own
# required baseline evidence (tasks.md T-001 Done-When), not a defect here.
#
# TEST-054 stays RED on the live tree even after every other task in this
# decomposition lands, by design (REQ-010/AC-028, acceptance-tests.md's
# "Deferred (non-blocking verification)" section): CI registration is a
# separately staged, human-applied workflow patch outside this feature's
# task plan.

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

AG="$ROOT/AGENTS.md"
DSL="$ROOT/plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md"
CDW="$ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md"
RUN_ALL_SH="$ROOT/tests/run-all.sh"
RUN_ALL_PS1="$ROOT/tests/run-all.ps1"
DSC_SH="$ROOT/tests/design-system-contract.tests.sh"
CI_DIR="$ROOT/.github/workflows"
BASELINE_SH="$ROOT/specs/design-sync-standing-consent/verification/T-001/ds29-baseline-sh.log"

# Lines from the first line matching $2 (inclusive) up to, but excluding,
# the first later line matching $3, from file $1. Mirrors
# tests/design-system-contract.tests.sh's own helper of the same name
# (acceptance-tests.md Notes: "assert per-site, never...one repository-wide
# sweep").
section_between() {
  awk -v start="$2" -v end="$3" '
    $0 ~ start { flag = 1 }
    flag && $0 ~ end && $0 !~ start { exit }
    flag { print }
  ' "$1" 2>/dev/null
}

# Same scoping logic as section_between, but over an already-extracted text
# blob ($1) instead of a file -- used to scope within a section already
# isolated by section_between (e.g. step 3's own regime bullets inside
# "## Loop").
section_of_lines() {
  printf '%s\n' "$1" | awk -v start="$2" -v end="$3" '
    $0 ~ start { flag = 1 }
    flag && $0 ~ end && $0 !~ start { exit }
    flag { print }
  '
}

# Collapse text to one whitespace-normalized line, so a multi-word phrase
# assertion is not defeated by Markdown's ordinary prose line-wrapping
# (tests/design-system-contract.tests.sh's own flatten_file/flatten_text
# precedent). Only used for phrase/content checks, never for the positional
# checks, which need real line boundaries to compare order or byte range.
flatten_file() {
  [ -f "$1" ] || return 1
  tr '\n' ' ' <"$1" | tr -s '[:space:]' ' '
}
flatten_text() {
  printf '%s' "$1" | tr '\n' ' ' | tr -s '[:space:]' ' '
}

sha256_of_text() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | cut -d' ' -f1
  elif command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | cut -d' ' -f1
  fi
}

# Every "PASS: DS-NNN ..." / "PASS: TEST-NNN ..." line recorded in the
# documented baseline log at $1 (REQ-009/AC-025's "documented pre-change
# baseline" leg -- captured by this task, before T-002/T-003/T-004 land)
# must still be present, verbatim, in a fresh run of DS-29's own suite ($2,
# already captured). DS-29's suite is never edited by this feature
# (BL-001/BL-002), so a stable full-line label is a reliable, precise
# comparison key -- unlike a bare Test-ID prefix, it also catches a partial
# regression among the several DS-006-prefixed sub-checks. The two bare
# numeric summary lines ("PASS: <n>", "FAIL: <n>") are excluded by the
# DS-/TEST- prefix requirement.
no_green_to_red_flip() {
  baseline_log=$1
  current_output=$2
  [ -f "$baseline_log" ] || return 1
  flipped=0
  while IFS= read -r line; do
    case "$line" in
    "PASS: DS-"* | "PASS: TEST-"*)
      printf '%s\n' "$current_output" | grep -Fxq -- "$line" || flipped=1
      ;;
    esac
  done <"$baseline_log"
  [ "$flipped" -eq 0 ]
}

# Runtime-assembled banned literals (AGENTS.md "Author-time sweeps" item 2;
# requirements.md Edge Case 8; acceptance-tests.md Notes). TEST-046's and
# TEST-050's own check logic and pass/fail labels must never embed either
# banned string as a contiguous literal in this suite's own source --
# assembled here from non-contiguous parts instead, exactly as DS-29's own
# TEST-033..TEST-036 already do for their banned phrases. Every other row in
# this suite checking for the *presence* of this feature's own setting key
# in AGENTS.md or design-sync-loop/SKILL.md writes it as an ordinary
# literal -- the constraint applies only to the two negative checks against
# claude-design-workflow.md.
BANNED_KEY="$(printf '%s' 'ds_upload')$(printf '%s' '_consent')"
BANNED_WORD="$(printf '%s' 'con')$(printf '%s' 'sent')"

AG_FLAT=$(flatten_file "$AG")
AG_PS_SECTION=$(section_between "$AG" '^## Project Settings$' '^## ')
AG_PS_FLAT=$(flatten_text "$AG_PS_SECTION")
AG_KEY_LINE=$(grep -n "${BANNED_KEY}" "$AG" 2>/dev/null | head -1 | cut -d: -f2-)

DSL_FLAT=$(flatten_file "$DSL")
LOOP_SECTION=$(section_between "$DSL" '^## Loop$' '^## ')
LOOP_FLAT=$(flatten_text "$LOOP_SECTION")
STEP3_SECTION=$(section_of_lines "$LOOP_SECTION" '^3[.] [*][*]Resolve egress consent' '^4[.] [*][*]Obtain informed consent')
STEP3_FLAT=$(flatten_text "$STEP3_SECTION")
STANDING_SECTION=$(section_of_lines "$STEP3_SECTION" '[*][*]standing[*][*]' '[*][*]off[*][*]')
STANDING_FLAT=$(flatten_text "$STANDING_SECTION")
OFF_SECTION=$(section_of_lines "$STEP3_SECTION" '[*][*]off[*][*]' 'ZZZ_NEVER_MATCHES_ZZZ')
OFF_FLAT=$(flatten_text "$OFF_SECTION")
WHICHEVER_SECTION=$(section_of_lines "$STEP3_SECTION" 'Whichever regime or occasion' 'ZZZ_NEVER_MATCHES_ZZZ')
WHICHEVER_FLAT=$(flatten_text "$WHICHEVER_SECTION")

CDW_FLAT=$(flatten_file "$CDW")

# --- REQ-001 (AC-001, AC-002, AC-003, AC-004, AC-031) ----------------------

if [ -n "$AG_KEY_LINE" ] \
  && printf '%s' "$AG_KEY_LINE" | grep -Fq 'standing' \
  && printf '%s' "$AG_KEY_LINE" | grep -Fq 'per-feature' \
  && printf '%s' "$AG_KEY_LINE" | grep -Fq 'off' \
  && ! printf '%s' "$AG_KEY_LINE" | grep -Eiq 'e\.g\.|similar|etc\.|and so on|for example'; then
  pass "TEST-001 the setting's value domain is named as exactly three alternatives, no fourth value, no hedge (AC-001)"
else
  fail "TEST-001 the setting's value domain is named as exactly three alternatives, no fourth value, no hedge (AC-001)"
fi

if grep -Eq '^## Project Settings$' "$AG" && printf '%s' "$AG_PS_FLAT" | grep -Fq "${BANNED_KEY}"; then
  pass "TEST-002 a ## Project Settings heading exists and the setting key is named in a table row under it (AC-002)"
else
  fail "TEST-002 a ## Project Settings heading exists and the setting key is named in a table row under it (AC-002)"
fi

if printf '%s' "$AG_PS_FLAT" | grep -Eiq 'absent.{0,10}section entirely' \
  && printf '%s' "$AG_PS_FLAT" | grep -Fq 'per-feature'; then
  pass "TEST-003 branch 1: a wholly absent Project Settings section is stated to resolve to per-feature (AC-003)"
else
  fail "TEST-003 branch 1: a wholly absent Project Settings section is stated to resolve to per-feature (AC-003)"
fi

if printf '%s' "$AG_PS_FLAT" | grep -Eiq 'absent key' \
  && printf '%s' "$AG_PS_FLAT" | grep -Fq 'per-feature'; then
  pass "TEST-004 branch 2: a present section that omits the setting key is stated to resolve to per-feature (AC-003)"
else
  fail "TEST-004 branch 2: a present section that omits the setting key is stated to resolve to per-feature (AC-003)"
fi

if [ -n "$AG_PS_FLAT" ] && printf '%s' "$AG_PS_FLAT" | grep -Fq "${BANNED_KEY}" \
  && ! printf '%s' "$AG_PS_FLAT" | grep -Eq 'Codex|Claude Code'; then
  pass "TEST-005 the setting's own definition carries no host-name conditional (AC-004)"
else
  fail "TEST-005 the setting's own definition carries no host-name conditional (AC-004)"
fi

if printf '%s' "$AG_PS_FLAT" | grep -Eiq 'off.{0,10}:.{0,40}forbid.{0,30}every host|forbid.{0,30}upload.{0,20}every host'; then
  pass "TEST-006 off's definition states the forbiddance applies on every host, unconditionally (AC-005)"
else
  fail "TEST-006 off's definition states the forbiddance applies on every host, unconditionally (AC-005)"
fi

if [ -n "$STEP3_FLAT" ] && printf '%s' "$STEP3_FLAT" | grep -Fq "${BANNED_KEY}" \
  && ! printf '%s' "$STEP3_FLAT" | grep -Eq 'Codex|Claude Code'; then
  pass "TEST-007 step 3's outer selector carries no tool-presence conditional as part of what the three regimes mean (AC-006)"
else
  fail "TEST-007 step 3's outer selector carries no tool-presence conditional as part of what the three regimes mean (AC-006)"
fi

# --- REQ-003 (AC-007, AC-008, AC-009, AC-030, AC-010) -- standing ----------

if printf '%s' "$STANDING_FLAT" | grep -Eiq 'never produces.{0,10}outcome \(b\)|never produces.{0,10}\(b\)'; then
  pass "TEST-008 under standing, step 3 never produces its 'must be requested' outcome (AC-007)"
else
  fail "TEST-008 under standing, step 3 never produces its 'must be requested' outcome (AC-007)"
fi

if printf '%s' "$STANDING_FLAT" | grep -Fq 'Design-Source'; then
  pass "TEST-009 the standing write is stated to go to the layer file's own Design-Source section specifically (AC-008)"
else
  fail "TEST-009 the standing write is stated to go to the layer file's own Design-Source section specifically (AC-008)"
fi

if printf '%s' "$STANDING_FLAT" | grep -Eq 'Ds-Upload-Consent-Setting: standing[^).]{0,30}(this|that|the current) destination'; then
  pass "TEST-010 the first-occurrence test is scoped to (feature, destination), not the feature alone (AC-009, structural)"
else
  fail "TEST-010 the first-occurrence test is scoped to (feature, destination), not the feature alone (AC-009, structural)"
fi

if printf '%s' "$STANDING_FLAT" | grep -Eiq 'different destination.{0,60}fresh' \
  && printf '%s' "$STANDING_FLAT" | grep -Eiq 'own one-time write|gets its own one-time write'; then
  pass "TEST-011 a different destination for an already-recorded feature triggers a fresh one-time write (AC-030)"
else
  fail "TEST-011 a different destination for an already-recorded feature triggers a fresh one-time write (AC-030)"
fi

if printf '%s' "$STANDING_FLAT" | grep -Fq 'Egress-Consent: granted'; then
  pass "TEST-012 the one-time record's Egress-Consent value is granted, not a new fourth value (AC-010)"
else
  fail "TEST-012 the one-time record's Egress-Consent value is granted, not a new fourth value (AC-010)"
fi

# --- REQ-004 (AC-011, AC-012, AC-013, AC-014) -- off -----------------------

if printf '%s' "$OFF_FLAT" | grep -Eiq 'always resolves to outcome \(c\)'; then
  pass "TEST-013 under off, step 3's resolved outcome is always outcome (c) (AC-011)"
else
  fail "TEST-013 under off, step 3's resolved outcome is always outcome (c) (AC-011)"
fi

if printf '%s' "$OFF_FLAT" | grep -Eiq 'manual fallback[^.]{0,80}no upload attempt|no upload attempt[^.]{0,80}manual fallback'; then
  pass "TEST-014 outcome (c) routes to the manual fallback and no upload is attempted (combined, one clause) (AC-012)"
else
  fail "TEST-014 outcome (c) routes to the manual fallback and no upload is attempted (combined, one clause) (AC-012)"
fi

if printf '%s' "$OFF_FLAT" | grep -Eiq 'write a record|writes a record'; then
  pass "TEST-015 an outcome record is written for the off resolution (existence) (AC-012)"
else
  fail "TEST-015 an outcome record is written for the off resolution (existence) (AC-012)"
fi

if printf '%s' "$OFF_FLAT" | grep -Fq 'Ds-Upload-Consent-Setting: off'; then
  pass "TEST-016 that record carries Ds-Upload-Consent-Setting: off specifically (AC-012)"
else
  fail "TEST-016 that record carries Ds-Upload-Consent-Setting: off specifically (AC-012)"
fi

if printf '%s' "$OFF_FLAT" | grep -Eiq 'persistently.{0,60}as long as the setting reads off' \
  && printf '%s' "$OFF_FLAT" | grep -Eiq 'not the transient per-attempt decline|does not lapse'; then
  pass "TEST-017 off's forbiddance is stated as persistent, distinguished from a transient decline (AC-013)"
else
  fail "TEST-017 off's forbiddance is stated as persistent, distinguished from a transient decline (AC-013)"
fi

if printf '%s' "$AG_PS_FLAT" | grep -Eiq 'off.{0,10}:.{0,40}forbid.{0,30}every host|forbid.{0,30}upload.{0,20}every host' \
  && printf '%s' "$OFF_FLAT" | grep -Eiq 'every host'; then
  pass "TEST-018 the forbiddance holds on every host, in both AGENTS.md and the loop's off branch (AC-014, cross-referencing TEST-006)"
else
  fail "TEST-018 the forbiddance holds on every host, in both AGENTS.md and the loop's off branch (AC-014, cross-referencing TEST-006)"
fi

# --- REQ-005 (AC-015) -- DS-29's own text, unmodified, per span -----------

if printf '%s' "$LOOP_FLAT" | grep -Fq 'The scope is the conjunction of those two coordinates and both must match' \
  && printf '%s' "$LOOP_FLAT" | grep -Fq 'neither does one the operator withdrew mid-session'; then
  pass "TEST-019 step 3(a)'s scope clause is present, unmodified (AC-015)"
else
  fail "TEST-019 step 3(a)'s scope clause is present, unmodified (AC-015)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Fiq 'Consent has not been obtained for this scope' \
  && printf '%s' "$LOOP_FLAT" | grep -Fq 'go to 4'; then
  pass "TEST-020 step 3(b)'s routing clause is present, unmodified (AC-015)"
else
  fail "TEST-020 step 3(b)'s routing clause is present, unmodified (AC-015)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Fq 'This outcome is persistent for the scope' \
  && printf '%s' "$LOOP_FLAT" | grep -Fq 'a decline is transient, binds only the upload attempt it was asked about'; then
  pass "TEST-021 step 3(c)'s not-permitted/persistence/decline-distinction clauses are present, unmodified (AC-015)"
else
  fail "TEST-021 step 3(c)'s not-permitted/persistence/decline-distinction clauses are present, unmodified (AC-015)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Fq 'asserting they have authority to send this content externally' \
  && printf '%s' "$LOOP_FLAT" | grep -Fq 'not knowable from this repository' \
  && printf '%s' "$LOOP_FLAT" | grep -Eiq 'not to a byte sequence'; then
  pass "TEST-022 step 4's informed-consent disclosure content is present, unmodified (AC-015)"
else
  fail "TEST-022 step 4's informed-consent disclosure content is present, unmodified (AC-015)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Fq 'with no bypass' \
  && printf '%s' "$LOOP_FLAT" | grep -Eiq 'does not presume.{0,10}an interactive human is present at this point'; then
  pass "TEST-023 step 5's pre-upload check point text is present, unmodified (AC-015)"
else
  fail "TEST-023 step 5's pre-upload check point text is present, unmodified (AC-015)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Fq 'does not change consent state, because consent is bound to the scope' \
  && printf '%s' "$LOOP_FLAT" | grep -Fq 'resumes at 5 with no re-prompt' \
  && printf '%s' "$LOOP_FLAT" | grep -Eiq "push failure is not 3\\(c\\)'?s persistent"; then
  pass "TEST-024 step 6's push-failure rule is present, unmodified (AC-015)"
else
  fail "TEST-024 step 6's push-failure rule is present, unmodified (AC-015)"
fi

if printf '%s' "$LOOP_FLAT" | grep -Fq 'apply their feedback and return to 2' \
  && printf '%s' "$LOOP_FLAT" | grep -Fq 'The cycle re-enters generation, never the consent step, because the scope has not changed' \
  && printf '%s' "$LOOP_FLAT" | grep -Fq 'Local review is OPTIONAL and non-blocking' \
  && printf '%s' "$LOOP_FLAT" | grep -Fq 'mockup content can reach claude.ai without any human having read it'; then
  pass "TEST-025 step 7's review/regeneration cycle text is present, unmodified (AC-015)"
else
  fail "TEST-025 step 7's review/regeneration cycle text is present, unmodified (AC-015)"
fi

# --- REQ-006 (AC-016, AC-017, AC-018, AC-019, AC-029) ----------------------

if grep -Fq 'Egress-Consent-Party' "$DSL"; then
  pass "TEST-026 Egress-Consent-Party is enumerated by name in the record table (AC-016)"
else
  fail "TEST-026 Egress-Consent-Party is enumerated by name in the record table (AC-016)"
fi

if grep -Fq 'Egress-Consent-At' "$DSL"; then
  pass "TEST-027 Egress-Consent-At is enumerated by name in the record table (AC-016)"
else
  fail "TEST-027 Egress-Consent-At is enumerated by name in the record table (AC-016)"
fi

if grep -Fq 'Ds-Upload-Consent-Setting' "$DSL"; then
  pass "TEST-028 Ds-Upload-Consent-Setting is enumerated by name in the record table (AC-016)"
else
  fail "TEST-028 Ds-Upload-Consent-Setting is enumerated by name in the record table (AC-016)"
fi

if printf '%s' "$DSL_FLAT" | grep -Eiq 'remains? conforming' \
  && printf '%s' "$DSL_FLAT" | grep -Eiq 'DS-29-era|missing (all )?(the )?three|lacking the three|before these fields existed'; then
  pass "TEST-029 the extensibility paragraph states a DS-29-era record remains conforming (AC-017)"
else
  fail "TEST-029 the extensibility paragraph states a DS-29-era record remains conforming (AC-017)"
fi

if grep -Fq 'Egress-Consent-Scope' "$DSL"; then
  pass "TEST-030 Egress-Consent-Scope field name present, unmodified (AC-018)"
else
  fail "TEST-030 Egress-Consent-Scope field name present, unmodified (AC-018)"
fi
if grep -Fq 'Egress-Consent-Subject' "$DSL"; then
  pass "TEST-031 Egress-Consent-Subject field name present, unmodified (AC-018)"
else
  fail "TEST-031 Egress-Consent-Subject field name present, unmodified (AC-018)"
fi
if grep -Fq 'Egress-Destination' "$DSL"; then
  pass "TEST-032 Egress-Destination field name present, unmodified (AC-018)"
else
  fail "TEST-032 Egress-Destination field name present, unmodified (AC-018)"
fi
if grep -Fq 'Egress-Consent-Expiry' "$DSL"; then
  pass "TEST-033 Egress-Consent-Expiry field name present, unmodified (AC-018)"
else
  fail "TEST-033 Egress-Consent-Expiry field name present, unmodified (AC-018)"
fi
if grep -Fq 'Egress-Consent' "$DSL"; then
  pass "TEST-034 Egress-Consent field name present, unmodified (AC-018)"
else
  fail "TEST-034 Egress-Consent field name present, unmodified (AC-018)"
fi
if grep -Fq 'granted' "$DSL"; then
  pass "TEST-035 Egress-Consent domain value granted present, unmodified (AC-018)"
else
  fail "TEST-035 Egress-Consent domain value granted present, unmodified (AC-018)"
fi
if grep -Fq 'not-permitted' "$DSL"; then
  pass "TEST-036 Egress-Consent domain value not-permitted present, unmodified (AC-018)"
else
  fail "TEST-036 Egress-Consent domain value not-permitted present, unmodified (AC-018)"
fi
if grep -Fq 'withdrawn' "$DSL"; then
  pass "TEST-037 Egress-Consent domain value withdrawn present, unmodified (AC-018)"
else
  fail "TEST-037 Egress-Consent domain value withdrawn present, unmodified (AC-018)"
fi

if printf '%s' "$STANDING_FLAT" | grep -Eiq 'never a fabricated' \
  && printf '%s' "$STANDING_FLAT" | grep -Eiq 'per-occurrence identity'; then
  pass "TEST-038 standing's text states Egress-Consent-Party must not name a fabricated per-occurrence identity (AC-019)"
else
  fail "TEST-038 standing's text states Egress-Consent-Party must not name a fabricated per-occurrence identity (AC-019)"
fi

if printf '%s' "$OFF_FLAT" | grep -Eiq 'never a fabricated' \
  && printf '%s' "$OFF_FLAT" | grep -Eiq 'per-occurrence identity'; then
  pass "TEST-039 off's text states Egress-Consent-Party must not name a fabricated per-occurrence identity (AC-019)"
else
  fail "TEST-039 off's text states Egress-Consent-Party must not name a fabricated per-occurrence identity (AC-019)"
fi

if printf '%s' "$STANDING_FLAT" | grep -Fq 'Egress-Consent-Party' \
  && printf '%s' "$STANDING_FLAT" | grep -Fq 'Egress-Consent-At' \
  && printf '%s' "$STANDING_FLAT" | grep -Fq 'Ds-Upload-Consent-Setting'; then
  pass "TEST-040 a standing grant's target text carries all three new fields (AC-029)"
else
  fail "TEST-040 a standing grant's target text carries all three new fields (AC-029)"
fi

if printf '%s' "$WHICHEVER_FLAT" | grep -Eiq 'per-feature grant' \
  && printf '%s' "$WHICHEVER_FLAT" | grep -Fq 'Egress-Consent-Party' \
  && printf '%s' "$WHICHEVER_FLAT" | grep -Fq 'Egress-Consent-At' \
  && printf '%s' "$WHICHEVER_FLAT" | grep -Fq 'Ds-Upload-Consent-Setting: per-feature'; then
  pass "TEST-041 an ordinary per-feature grant's target text carries all three new fields (AC-029)"
else
  fail "TEST-041 an ordinary per-feature grant's target text carries all three new fields (AC-029)"
fi

if printf '%s' "$STEP3_FLAT" | grep -Eiq 'mid-session' \
  && printf '%s' "$STEP3_FLAT" | grep -Eiq 'withdraw' \
  && printf '%s' "$STEP3_FLAT" | grep -Fq 'Egress-Consent-Party' \
  && printf '%s' "$STEP3_FLAT" | grep -Fq 'Egress-Consent-At' \
  && printf '%s' "$STEP3_FLAT" | grep -Fq 'Ds-Upload-Consent-Setting'; then
  pass "TEST-042 a per-feature mid-session withdrawal's target text carries all three new fields (AC-029)"
else
  fail "TEST-042 a per-feature mid-session withdrawal's target text carries all three new fields (AC-029)"
fi

if printf '%s' "$OFF_FLAT" | grep -Fq 'Egress-Consent-Party' \
  && printf '%s' "$OFF_FLAT" | grep -Fq 'Egress-Consent-At' \
  && printf '%s' "$OFF_FLAT" | grep -Fq 'Ds-Upload-Consent-Setting: off'; then
  pass "TEST-043 an off-driven not-permitted outcome's target text carries all three new fields (AC-029)"
else
  fail "TEST-043 an off-driven not-permitted outcome's target text carries all three new fields (AC-029)"
fi

# --- REQ-007 (AC-020, AC-021) ----------------------------------------------

if printf '%s' "$STEP3_FLAT" | grep -Eiq 'every time this step is resolved' \
  && printf '%s' "$STEP3_FLAT" | grep -Eiq 'never.{0,20}cached.{0,30}(earlier|previous) resolution|not cached across resolutions'; then
  pass "TEST-044 step 3's opening sentence states the setting is re-read at every resolution, not cached (AC-020, executable oracle)"
else
  fail "TEST-044 step 3's opening sentence states the setting is re-read at every resolution, not cached (AC-020, executable oracle)"
fi

if printf '%s' "$DSL_FLAT" | grep -Eiq 'never override.{0,60}(current|currently configured) setting|record.{0,60}(never|does not) override.{0,60}setting'; then
  pass "TEST-045 the record-table text states a record's own setting value never overrides the currently configured setting (AC-021)"
else
  fail "TEST-045 the record-table text states a record's own setting value never overrides the currently configured setting (AC-021)"
fi

# --- REQ-008 (AC-022, AC-023, AC-024) -- the fallback ----------------------

# TEST-046's own negative check must never spell out the setting's literal
# key contiguously in this suite's own source (AGENTS.md "Author-time
# sweeps" item 2; requirements.md Edge Case 8) -- BANNED_KEY above is
# assembled from two non-contiguous literals for exactly this reason, and
# is interpolated into the pass/fail label too, following DS-29's own
# TEST-033..036 precedent (the QG fix-cycle addendum that suite recorded
# after finding its own labels had leaked the banned phrase).
if ! printf '%s' "$CDW_FLAT" | grep -Fq -- "${BANNED_KEY}"; then
  pass "TEST-046 claude-design-workflow.md contains no occurrence of the setting's literal key identifier (AC-022)"
else
  fail "TEST-046 claude-design-workflow.md contains no occurrence of the setting's literal key identifier (AC-022)"
fi

if printf '%s' "$CDW_FLAT" | grep -Eiq 'upload-policy setting' \
  && printf '%s' "$CDW_FLAT" | grep -Fq 'Design-Source' \
  && printf '%s' "$CDW_FLAT" | grep -Eiq 'AGENTS\.md|Project Settings'; then
  pass "TEST-047 the new bullet states the setting's value/outcome survive via an indirect reference, naming Design-Source (AC-022)"
else
  fail "TEST-047 the new bullet states the setting's value/outcome survive via an indirect reference, naming Design-Source (AC-022)"
fi

if grep -Fq 'does not automatically inspect, upload, or retain' "$CDW" \
  && ! printf '%s' "$CDW_FLAT" | grep -Eiq 'automatically upload|now uploads|may now upload|will upload'; then
  pass "TEST-048 the existing no-upload statement is present, unmodified, and no new upload-enabling language appears (AC-023)"
else
  fail "TEST-048 the existing no-upload statement is present, unmodified, and no new upload-enabling language appears (AC-023)"
fi

test_049_minimal_diff() {
  prefix_anchor=$(grep -n 'a normal specification edit\.' "$CDW" | head -1 | cut -d: -f1)
  suffix_anchor=$(grep -n 'When no visual input is supplied, record:' "$CDW" | head -1 | cut -d: -f1)
  [ -n "$prefix_anchor" ] || return 1
  [ -n "$suffix_anchor" ] || return 1
  prefix_hash=$(sed -n "1,${prefix_anchor}p" "$CDW" | sha256_of_stdin)
  suffix_hash=$(sed -n "${suffix_anchor},\$p" "$CDW" | sha256_of_stdin)
  [ "$prefix_hash" = "5da4093e27d8533899ded892f50727b953ef8b2e7a9612a9538601d3b9db913a" ] \
    && [ "$suffix_hash" = "8f40b3fef3ce403eeac8f4dd762fbf33b3d37c7c32aab44088fabc620b1a67d6" ]
}
sha256_of_stdin() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | cut -d' ' -f1
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -d' ' -f1
  fi
}
if test_049_minimal_diff; then
  pass "TEST-049 the file's content is unchanged outside the one appended bullet (AC-023, minimal diff, anchor-located byte-identity)"
else
  fail "TEST-049 the file's content is unchanged outside the one appended bullet (AC-023, minimal diff, anchor-located byte-identity)"
fi

# TEST-050's own negative check must never spell out the banned substring
# contiguously in this suite's own source, for the same reason as TEST-046.
if ! printf '%s' "$CDW_FLAT" | grep -Eiq -- "${BANNED_WORD}"; then
  pass "TEST-050 no case-insensitive occurrence of the general banned substring exists anywhere in the fallback file (AC-024)"
else
  fail "TEST-050 no case-insensitive occurrence of the general banned substring exists anywhere in the fallback file (AC-024)"
fi

# --- REQ-009 (AC-025, AC-026) -- baseline-relative regression against DS-29

DSC_CURRENT_SH=$(bash "$DSC_SH" 2>&1)

if no_green_to_red_flip "$BASELINE_SH" "$DSC_CURRENT_SH" \
  && printf '%s\n' "$DSC_CURRENT_SH" | grep -Eq '^PASS: TEST-010 ' \
  && printf '%s\n' "$DSC_CURRENT_SH" | grep -Eq '^PASS: TEST-015 ' \
  && printf '%s\n' "$DSC_CURRENT_SH" | grep -Eq '^PASS: TEST-018 ' \
  && printf '%s\n' "$DSC_CURRENT_SH" | grep -Eq '^PASS: TEST-026 ' \
  && printf '%s\n' "$DSC_CURRENT_SH" | grep -Eq '^PASS: TEST-040 '; then
  pass "TEST-051 zero rows in DS-29's own suite flip from green (baseline) to red (current), TEST-010/015/018/026/040 checked explicitly (AC-025)"
else
  fail "TEST-051 zero rows in DS-29's own suite flip from green (baseline) to red (current), TEST-010/015/018/026/040 checked explicitly (AC-025)"
fi

if grep -Eq '^PASS: TEST-021 ' "$BASELINE_SH" && printf '%s\n' "$DSC_CURRENT_SH" | grep -Eq '^PASS: TEST-021 '; then
  pass "TEST-052 DS-29's own TEST-021 is green in both the baseline and current run, re-verified from this feature's own suite (AC-026)"
else
  fail "TEST-052 DS-29's own TEST-021 is green in both the baseline and current run, re-verified from this feature's own suite (AC-026)"
fi

# --- REQ-010 (AC-027, AC-028) -----------------------------------------------

if grep -Fq 'tests/design-sync-standing-consent.tests.sh' "$RUN_ALL_SH" \
  && grep -Fq 'tests/design-sync-standing-consent.tests.ps1' "$RUN_ALL_PS1"; then
  pass "TEST-053 both suite files are registered in tests/run-all.sh and tests/run-all.ps1 (AC-027)"
else
  fail "TEST-053 both suite files are registered in tests/run-all.sh and tests/run-all.ps1 (AC-027)"
fi

# --- REQ-001 (AC-031, round 3) ----------------------------------------------

if printf '%s' "$AG_PS_FLAT" | grep -Eiq 'not exactly one of.{0,40}lowercase literals' \
  && printf '%s' "$AG_PS_FLAT" | grep -Eiq 'never.{0,5}standing' \
  && printf '%s' "$AG_PS_FLAT" | grep -Eiq 'never.{0,5}off'; then
  pass "TEST-055 branch 3: a present out-of-domain value is stated to resolve to per-feature, never standing, never off (AC-031)"
else
  fail "TEST-055 branch 3: a present out-of-domain value is stated to resolve to per-feature, never standing, never off (AC-031)"
fi

if printf '%s' "$AG_PS_FLAT" | grep -Eiq 'exact.{0,15}case-sensitive' \
  && printf '%s' "$AG_PS_FLAT" | grep -Fq 'Standing'; then
  pass "TEST-056 value matching is stated as exact and case-sensitive, a case variant is named as out-of-domain input (AC-031)"
else
  fail "TEST-056 value matching is stated as exact and case-sensitive, a case variant is named as out-of-domain input (AC-031)"
fi

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"

# ---------------------------------------------------------------------------
# Deferred (non-blocking verification) -- TEST-054 (AC-028)
#
# Presented after the summary line above (mirroring acceptance-tests.md's
# own structural separation of this row into its own "Deferred" section,
# distinct from the main pass/fail Test Matrix, round 2 ruling E), so a
# reviewer scanning PASS/FAIL counts above does not read this row's designed
# RED as an authoring defect. Not counted in PASS/FAIL above; does not
# affect this script's exit code.
# ---------------------------------------------------------------------------

test_054_ci_registered() {
  ci_dir="$CI_DIR"
  [ -d "$ci_dir" ] || return 1
  has_sh=0
  has_ps1=0
  for wf in "$ci_dir"/*.yml "$ci_dir"/*.yaml; do
    [ -f "$wf" ] || continue
    grep -q 'design-sync-standing-consent\.tests\.sh' "$wf" && has_sh=1
    grep -q 'design-sync-standing-consent\.tests\.ps1' "$wf" && has_ps1=1
  done
  [ "$has_sh" -eq 1 ] && [ "$has_ps1" -eq 1 ]
}
if test_054_ci_registered; then
  printf 'PASS: %s\n' "TEST-054 this feature's suite is reachable from a CI entry point (AC-028, deferred)"
else
  printf 'FAIL: %s\n' "TEST-054 this feature's suite is reachable from a CI entry point (AC-028, deferred) -- DESIGNED RED: staged workflow patch not yet applied (REQ-010/AC-028)"
fi

[ "$FAIL" -eq 0 ]
