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

# The setting's table row's Values/Default cells, precisely isolated from
# the row's free-text Meaning cell (QG cycle-2 Major fix, TEST-001/003/004:
# the round-1 checks only tested for co-occurring substrings anywhere in
# the whole Project Settings section, which a fourth value or a
# Default-cell/prose mismatch elsewhere in the row's own long Meaning cell
# would not have disturbed). Markdown escapes an in-cell "|" as "\|" so it
# is not read as a column separator; a literal "\|" two-character sequence
# is neutralized to a placeholder token first (which itself contains no
# "|"), so the remaining "|" characters awk splits on are only the row's
# true, unescaped column boundaries -- this correctly isolates the Values
# cell (3rd column) and Default cell (4th column) even when their own
# content changes shape (fourth value inserted, value removed, reordered).
AG_VALUES_CELL=$(printf '%s' "$AG_KEY_LINE" | sed 's/\\|/@ESC@/g' | awk -F'|' '{print $3}')
AG_VALUES_SEGCOUNT=$(printf '%s' "$AG_VALUES_CELL" | awk -F'@ESC@' '{print NF}')
AG_DEFAULT_CELL=$(printf '%s' "$AG_KEY_LINE" | sed 's/\\|/@ESC@/g' | awk -F'|' '{print $4}' | tr -s '[:space:]' ' ' | sed 's/^ *//; s/ *$//')

# The Values cell's own segments, individually trimmed and set-compared
# (QG cycle-2 Major-2 fix): AC-001/acceptance-tests.md :85 only commits to
# "exactly three [values], in either order" -- an *order-fixed* full-cell
# string match (the round-1/cycle-2 shape) is stricter than the spec and
# false-positives on a legitimately reordered but still-correct Values
# cell (e.g. "`off` | `per-feature` | `standing`"). Splitting on the
# restored "@ESC@" segment boundaries, trimming each segment individually
# (never collapsing the *inter-segment* newlines `sort` relies on, unlike
# a single `tr -s '[:space:]' ' '` over the whole multi-line blob), then
# sorting the set makes the comparison order-independent while still
# requiring each segment's content to be exactly one of the three
# literals -- an added/renamed/free-text segment still fails.
AG_VALUES_SEGMENTS_SET=$(printf '%s' "$AG_VALUES_CELL" | awk -F'@ESC@' '{for (i = 1; i <= NF; i++) { s = $i; gsub(/^[ \t]+|[ \t]+$/, "", s); print s }}' | sort)
AG_VALUES_SEGMENTS_EXPECTED='`off`
`per-feature`
`standing`'

# QG cycle-3 (evaluator, TEST-001 structural closure): AC-001
# (requirements.md :29) requires that no fourth value be described
# *anywhere in the definition*. Rounds 1-2 each enumerated one specific
# syntactic *shape* a fourth value could take (a Values-cell segment; a
# ":"-terminated branch definition in the Meaning cell; a ","+"value"
# prose sentence in the intro) -- each round closed the shape it named but
# left the class open, since a mutant naming a fourth value in any other
# shape (e.g. a plain sentence with neither a trailing ':' nor a nearby
# "value" word -- "The setting may also be set to `ask` on hosts that
# support interactive prompting.") would satisfy neither prior shape and
# still survive. The cycle-3 ruling: the scanned region (AG_PS_ROW_SCAN
# below -- the section's own intro paragraph plus the setting's own key
# row, same scope as before; the table's header/separator rows are still
# excluded, since their own "Values"/"Default" column-name text carries no
# backtick literals anyway) currently contains exactly 9 distinct
# backtick-quoted literals: `standing`, `per-feature`, `off` (the three
# legitimate values), `Standing` (the intro's own legitimate case-variant
# illustration -- kept as its own distinct allowlist entry, deliberately
# NOT case-folded into `standing`, since folding away the distinction
# between the two is exactly what would let a genuinely different fourth
# literal of some other case hide behind an allowlist entry of a
# different case), `granted`, `ds_upload_consent`, `requirements.md`,
# `design-sync-loop`, `Design-Source` (all incidental to the row's own
# prose, none of them a value). A set-equality allowlist over EVERY
# backtick-quoted literal found in AG_PS_ROW_SCAN -- regardless of what
# syntactic position it occurs in -- closes the class structurally: any
# newly introduced backtick-quoted literal not already on this list fails
# AG_PS_EXTRA_TOKENS below no matter what sentence shape introduces it,
# and dropping any of `standing`/`per-feature`/`off` fails
# AG_PS_HAS_ALL_THREE below.
AG_PS_INTRO_SECTION=$(section_of_lines "$AG_PS_SECTION" '^## Project Settings$' '^[|]')
AG_PS_INTRO_FLAT=$(flatten_text "$AG_PS_INTRO_SECTION")
AG_PS_ROW_SCAN=$(flatten_text "$AG_PS_INTRO_FLAT $AG_KEY_LINE")
AG_PS_ALL_TOKENS=$(printf '%s' "$AG_PS_ROW_SCAN" | grep -oE '`[^`]+`' 2>/dev/null | sed -e 's/^`//' -e 's/`$//' | sort -u)

# Case-sensitive membership test against the current text's own 9-literal
# allowlist derived above -- an exact-string `awk` comparison per allowed
# literal, not a single alternation regex, so a token containing a regex
# metacharacter (the '.' in `requirements.md`) can never be misread as a
# wildcard. AG_PS_EXTRA_TOKENS lists every extracted literal not on the
# allowlist (empty means the subset check passes); AG_PS_HAS_ALL_THREE
# separately confirms none of the three required values was dropped
# (a mutation could narrow the allowlist-conforming set to just two of the
# three without ever introducing an unknown literal).
AG_PS_EXTRA_TOKENS=$(printf '%s\n' "$AG_PS_ALL_TOKENS" | awk '
  $0 == "standing" || $0 == "per-feature" || $0 == "off" || $0 == "Standing" || $0 == "granted" || $0 == "ds_upload_consent" || $0 == "requirements.md" || $0 == "design-sync-loop" || $0 == "Design-Source" { next }
  { print }
')
AG_PS_HAS_ALL_THREE=$(printf '%s\n' "$AG_PS_ALL_TOKENS" | awk '
  $0 == "standing" { s = 1 }
  $0 == "per-feature" { p = 1 }
  $0 == "off" { o = 1 }
  END { if (s && p && o) print "1"; else print "0" }
')

DSL_FLAT=$(flatten_file "$DSL")
LOOP_SECTION=$(section_between "$DSL" '^## Loop$' '^## ')
LOOP_FLAT=$(flatten_text "$LOOP_SECTION")
STEP3_SECTION=$(section_of_lines "$LOOP_SECTION" '^3[.] [*][*]Resolve egress consent' '^4[.] [*][*]Obtain informed consent')
STEP3_FLAT=$(flatten_text "$STEP3_SECTION")
STANDING_SECTION=$(section_of_lines "$STEP3_SECTION" '[*][*]standing[*][*]' '[*][*]off[*][*]')
STANDING_FLAT=$(flatten_text "$STANDING_SECTION")
# End sentinel closed on the real next-paragraph anchor, not a
# never-matches sentinel (QG cycle-2 Major fix, TEST-043: the prior
# 'ZZZ_NEVER_MATCHES_ZZZ' end pattern let OFF_SECTION run through the rest
# of step 3 -- the withdrawal and "whichever" paragraphs below it -- so a
# deleted `Egress-Consent-Party`/`Egress-Consent-At` line inside the actual
# off bullet was masked by those same field names reappearing downstream).
OFF_SECTION=$(section_of_lines "$STEP3_SECTION" '[*][*]off[*][*]' 'A per-feature mid-session withdrawal')
OFF_FLAT=$(flatten_text "$OFF_SECTION")
WHICHEVER_SECTION=$(section_of_lines "$STEP3_SECTION" 'Whichever regime or occasion' 'ZZZ_NEVER_MATCHES_ZZZ')
WHICHEVER_FLAT=$(flatten_text "$WHICHEVER_SECTION")
# Dedicated scope for the mid-session-withdrawal occasion (QG cycle-2 Major
# fix, TEST-042: previously checked against the whole of STEP3_FLAT, which
# made the three-field-names assertion vacuous with respect to a claim
# reduction specific to this paragraph, since standing/off/per-feature
# text elsewhere in step 3 also names those fields). Starts at the real
# 'A per-feature mid-session withdrawal' anchor (excludes standing/off/
# per-feature bullet text before it) and runs to the natural end of
# STEP3_SECTION -- legitimately including the "Whichever regime or
# occasion" paragraph immediately after it, since that paragraph is what
# actually spells out the three field names for "whichever...occasion
# produces the write" (this withdrawal paragraph names the occasion and
# the "all three new fields" claim; the following paragraph is what makes
# that claim checkable). 'ZZZ_NEVER_MATCHES_ZZZ' is safe to keep here only
# because this is the last paragraph in the already-bounded STEP3_SECTION
# blob -- unlike OFF_SECTION above, there is nothing further for it to
# swallow.
WITHDRAWAL_SECTION=$(section_of_lines "$STEP3_SECTION" 'A per-feature mid-session withdrawal' 'ZZZ_NEVER_MATCHES_ZZZ')
WITHDRAWAL_FLAT=$(flatten_text "$WITHDRAWAL_SECTION")

CDW_FLAT=$(flatten_file "$CDW")

# --- REQ-001 (AC-001, AC-002, AC-003, AC-004, AC-031) ----------------------

# QG cycle-2 Major fix: the round-1 check only tested for the three
# literals' *presence* anywhere in the row plus an absence of hedge words --
# a fourth value (e.g. `auto`, `ask-always`) added anywhere in the Values
# cell, or a reduction to two values, or a free-text cell, all still
# contain/avoid those same substrings and were not caught. Now requires
# the Values cell to contain exactly 3 `|`-delimited segments
# (AG_VALUES_SEGCOUNT), each individually trimmed, whose set (order-
# independent, per acceptance-tests.md :85's "in either order") equals
# exactly the three backtick-quoted literals and nothing else
# (AG_VALUES_SEGMENTS_SET == AG_VALUES_SEGMENTS_EXPECTED) -- see
# AG_VALUES_CELL's own derivation comment above.
#
# QG cycle-3 (evaluator, structural closure): that Values-cell check alone
# still misses a fourth value described *outside* the Values cell, in any
# shape -- see AG_PS_ROW_SCAN's own derivation comment above for the full
# extraction rationale and the specific gap (a novel sentence shape) this
# closes relative to the cycle-2 fix it replaces. Requires
# AG_PS_EXTRA_TOKENS to be empty (no backtick literal outside the current
# 9-item allowlist) and AG_PS_HAS_ALL_THREE to hold (none of the three
# required values dropped).
if [ -n "$AG_KEY_LINE" ] \
  && [ "$AG_VALUES_SEGCOUNT" -eq 3 ] \
  && [ "$AG_VALUES_SEGMENTS_SET" = "$AG_VALUES_SEGMENTS_EXPECTED" ] \
  && [ -z "$AG_PS_EXTRA_TOKENS" ] \
  && [ "$AG_PS_HAS_ALL_THREE" = "1" ] \
  && ! printf '%s' "$AG_KEY_LINE" | grep -Eiq 'e\.g\.|similar|etc\.|and so on|for example'; then
  pass "TEST-001 the setting's value domain is named as exactly three alternatives, no fourth value anywhere in the definition, no hedge (AC-001, order-independent Values-cell set + intro/key-row backtick-literal allowlist)"
else
  fail "TEST-001 the setting's value domain is named as exactly three alternatives, no fourth value anywhere in the definition, no hedge (AC-001, order-independent Values-cell set + intro/key-row backtick-literal allowlist)"
fi

if grep -Eq '^## Project Settings$' "$AG" && printf '%s' "$AG_PS_FLAT" | grep -Fq "${BANNED_KEY}"; then
  pass "TEST-002 a ## Project Settings heading exists and the setting key is named in a table row under it (AC-002)"
else
  fail "TEST-002 a ## Project Settings heading exists and the setting key is named in a table row under it (AC-002)"
fi

# QG cycle-2 Major fix (TEST-003/TEST-004): the round-1 checks were a bare
# co-occurrence heuristic -- the absence-branch phrase and the bare literal
# 'per-feature' anywhere in AG_PS_FLAT -- satisfied even if the Default
# cell read `standing`/`off`/empty, because 'per-feature' also appears
# elsewhere in the row (the Values cell, the Meaning prose). Both branches
# now require an absolute, two-part proof instead: (1) the branch's own
# phrase is tightly adjacent to (not merely co-occurring with) "uses the
# stated default", the row's own indirection to the Default column, and
# (2) the Default cell itself (AG_DEFAULT_CELL, isolated the same way as
# AG_VALUES_CELL above) is exactly `per-feature` -- never `standing`/`off`/
# empty/free prose such as "default of `standing`", which would either
# break the "stated default" adjacency phrase, or the exact Default-cell
# match, or both.
if printf '%s' "$AG_PS_FLAT" | grep -Eiq 'absent.{0,10}section entirely.{0,30}uses the stated default' \
  && [ "$AG_DEFAULT_CELL" = '`per-feature`' ]; then
  pass "TEST-003 branch 1: a wholly absent Project Settings section is stated to resolve to per-feature (AC-003, Default-cell exact match)"
else
  fail "TEST-003 branch 1: a wholly absent Project Settings section is stated to resolve to per-feature (AC-003, Default-cell exact match)"
fi

if printf '%s' "$AG_PS_FLAT" | grep -Eiq 'absent key.{0,60}uses the stated default' \
  && [ "$AG_DEFAULT_CELL" = '`per-feature`' ]; then
  pass "TEST-004 branch 2: a present section that omits the setting key is stated to resolve to per-feature (AC-003, Default-cell exact match)"
else
  fail "TEST-004 branch 2: a present section that omits the setting key is stated to resolve to per-feature (AC-003, Default-cell exact match)"
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

# QG cycle-2 Major fix (TEST-030..TEST-034 ID<->target rebinding): these
# five IDs were bound one position out of step against acceptance-tests.md's
# frozen Test Matrix (TEST-030=Egress-Consent, 031=Egress-Consent-Scope,
# 032=Egress-Consent-Subject, 033=Egress-Destination,
# 034=Egress-Consent-Expiry) -- the suite as first authored instead checked
# TEST-030=Egress-Consent-Scope ... TEST-034=Egress-Consent (a one-position
# rotation). Each of the five underlying checks was already correct; only
# the ID<->target binding was wrong. Rebound here, in Test-Matrix order; no
# check's own logic changed.
if grep -Fq 'Egress-Consent' "$DSL"; then
  pass "TEST-030 Egress-Consent field name present, unmodified (AC-018)"
else
  fail "TEST-030 Egress-Consent field name present, unmodified (AC-018)"
fi
if grep -Fq 'Egress-Consent-Scope' "$DSL"; then
  pass "TEST-031 Egress-Consent-Scope field name present, unmodified (AC-018)"
else
  fail "TEST-031 Egress-Consent-Scope field name present, unmodified (AC-018)"
fi
if grep -Fq 'Egress-Consent-Subject' "$DSL"; then
  pass "TEST-032 Egress-Consent-Subject field name present, unmodified (AC-018)"
else
  fail "TEST-032 Egress-Consent-Subject field name present, unmodified (AC-018)"
fi
if grep -Fq 'Egress-Destination' "$DSL"; then
  pass "TEST-033 Egress-Destination field name present, unmodified (AC-018)"
else
  fail "TEST-033 Egress-Destination field name present, unmodified (AC-018)"
fi
if grep -Fq 'Egress-Consent-Expiry' "$DSL"; then
  pass "TEST-034 Egress-Consent-Expiry field name present, unmodified (AC-018)"
else
  fail "TEST-034 Egress-Consent-Expiry field name present, unmodified (AC-018)"
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

# QG cycle-2 Major fix: checking against the whole of STEP3_FLAT made the
# three-field-names assertion vacuous with respect to this occasion
# specifically -- standing/off/per-feature text elsewhere in step 3 also
# names those fields, so a claim reduction local to the withdrawal
# paragraph itself (e.g. weakening "writes all three new fields" to name
# fewer) would not have been caught. Now scoped to WITHDRAWAL_FLAT (the
# withdrawal paragraph plus the "whichever...occasion" paragraph that
# supplies the concrete field content for it, excluding the unrelated
# standing/off/per-feature-outcome bullets before it -- see WITHDRAWAL_
# SECTION's own derivation comment above) and additionally requires the
# paragraph's own "all three new fields" claim phrase and its
# `Egress-Consent: withdrawn` record-value literal, so weakening that
# specific claim -- even while the field names remain present downstream --
# now fails.
if printf '%s' "$WITHDRAWAL_FLAT" | grep -Eiq 'mid-session' \
  && printf '%s' "$WITHDRAWAL_FLAT" | grep -Eiq 'withdraw' \
  && printf '%s' "$WITHDRAWAL_FLAT" | grep -Fq 'all three new fields' \
  && printf '%s' "$WITHDRAWAL_FLAT" | grep -Fq 'Egress-Consent: withdrawn' \
  && printf '%s' "$WITHDRAWAL_FLAT" | grep -Fq 'Egress-Consent-Party' \
  && printf '%s' "$WITHDRAWAL_FLAT" | grep -Fq 'Egress-Consent-At' \
  && printf '%s' "$WITHDRAWAL_FLAT" | grep -Fq 'Ds-Upload-Consent-Setting'; then
  pass "TEST-042 a per-feature mid-session withdrawal's target text carries all three new fields (AC-029, claim-phrase scoped)"
else
  fail "TEST-042 a per-feature mid-session withdrawal's target text carries all three new fields (AC-029, claim-phrase scoped)"
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

# QG cycle-2 Major fix: the round-1 phrase list only matched a handful of
# exact wordings ('automatically upload', 'now uploads', ...) -- a new
# bullet phrased differently but carrying the same upload+automatic
# meaning (e.g. "Mockups are uploaded ... automatically ..." or "may
# upload the mockup automatically and retain it") was not caught, in or
# out of a bullet. Extended with a bidirectional semantic-class regex
# (upload-word near "automatic[ally]", or "automatic[ally]" near an
# upload/retain-word, either order, one clause apart), mirroring this
# file's own bidirectional-proximity precedent (e.g. TEST-014 above). The
# existing, legitimate "does not automatically inspect, upload, or
# retain" statement itself satisfies that same broadened pattern (it is a
# negated list of three things the workflow does NOT do, one of which is
# "upload", within a few words of "automatically") -- checked for and
# excised from the search text first (its own literal presence is already
# independently required by this same check's positive half), so only
# NEW occurrences of the dangerous pattern elsewhere in the file can fail
# this row.
CDW_FLAT_SANS_NO_UPLOAD_SENTENCE=$(printf '%s' "$CDW_FLAT" | sed 's/does not automatically inspect, upload, or retain//')
if grep -Fq 'does not automatically inspect, upload, or retain' "$CDW" \
  && ! printf '%s' "$CDW_FLAT_SANS_NO_UPLOAD_SENTENCE" | grep -Eiq 'automatically upload|now uploads|may now upload|will upload|upload(s|ed|ing)?[^.]{0,60}automatic|automatic(ally)?[^.]{0,60}(upload|retain)(s|ed|ing)?'; then
  pass "TEST-048 the existing no-upload statement is present, unmodified, and no new upload-enabling language appears (AC-023, semantic-class negative sweep)"
else
  fail "TEST-048 the existing no-upload statement is present, unmodified, and no new upload-enabling language appears (AC-023, semantic-class negative sweep)"
fi

# QG cycle-2 Major fix: the zone strictly between the two anchors (the
# lines after 'a normal specification edit.' and before 'When no visual
# input is supplied, record:') was not covered by either hash -- it was
# genuinely unknown at this suite's original T-001 authoring time (this
# feature's own fallback bullet had not yet landed), but is now live,
# stable content (both this feature's bullet and the sibling
# design-sync-scan feature's own bullet, landed in the same zone) and can
# be pinned. Adds a third, middle-zone hash covering exactly that
# previously-blind span, so the three hashes together cover the anchor's
# own line through EOF with no gap -- an insertion anywhere in that zone
# now changes middle_hash and fails this row.
test_049_minimal_diff() {
  prefix_anchor=$(grep -n 'a normal specification edit\.' "$CDW" | head -1 | cut -d: -f1)
  suffix_anchor=$(grep -n 'When no visual input is supplied, record:' "$CDW" | head -1 | cut -d: -f1)
  [ -n "$prefix_anchor" ] || return 1
  [ -n "$suffix_anchor" ] || return 1
  [ "$suffix_anchor" -gt "$((prefix_anchor + 1))" ] || return 1
  prefix_hash=$(sed -n "1,${prefix_anchor}p" "$CDW" | sha256_of_stdin)
  middle_hash=$(sed -n "$((prefix_anchor + 1)),$((suffix_anchor - 1))p" "$CDW" | sha256_of_stdin)
  suffix_hash=$(sed -n "${suffix_anchor},\$p" "$CDW" | sha256_of_stdin)
  [ "$prefix_hash" = "5da4093e27d8533899ded892f50727b953ef8b2e7a9612a9538601d3b9db913a" ] \
    && [ "$middle_hash" = "8ae7c5cf0d4d5e723f2e032c4c005697f1c9fe49b53277f70db9b851a1d84830" ] \
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
  pass "TEST-049 the file's content is unchanged outside the one appended bullet (AC-023, full anchor-to-EOF byte-identity, no blind zone)"
else
  fail "TEST-049 the file's content is unchanged outside the one appended bullet (AC-023, full anchor-to-EOF byte-identity, no blind zone)"
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
