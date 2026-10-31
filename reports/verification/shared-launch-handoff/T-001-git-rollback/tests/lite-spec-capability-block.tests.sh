#!/usr/bin/env bash
# lite-spec-capability-block.tests.sh (epic-194-a6-lite-integration, T-003,
# design.md Test Strategy item 6, TEST-019, AC-019/AC-020/AC-021).
#
# lite-spec's SKILL.md is agent-facing prose, not executable code, so this
# suite tests it two ways:
#  (a) structural/static: the proposed SKILL.md text names every element
#      design.md's own API/Contract Plan "REQ-005" requires (candidate (a)
#      signal source, the trigger-fragment shape, the --capability-reasons
#      call-site addition, the disabled-legacy skip clause, the
#      non-overridable-by---lite statement, and the "layered with, not a
#      substitute for" ship-time recheck statement).
#  (b) functional/integration: a fixture whose Capability-derived signal
#      names one matched, ineligible Capability -- assembled into REQ-002's
#      own trigger-fragment shape exactly as the new Step 2 documents, NOT
#      via a real Epic A2 evaluate-predicate call (which does not exist yet
#      in this repository, requirements.md Assumptions: every fixture is
#      synthetic) -- Blocks via T-002's own extended check-risk-upgrade
#      contract, same exit-code/message-shape as an existing keyword-match
#      fixture (AC-019).
#
# NOTE: the SKILL.md text under test is the canonical staged human-copy
# content, and the check-risk-upgrade SUT is T-002's own canonical staged
# extended script (already covered by its own suite).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SKILL_PROPOSED="${REPO_ROOT}/specs/epic-194-a6-lite-integration/human-copy/plugins/sdd-lite/skills/lite-spec/SKILL.md"
CHECK_RISK_UPGRADE="${REPO_ROOT}/specs/epic-194-a6-lite-integration/human-copy/plugins/sdd-lite/scripts/check-risk-upgrade.sh"
LIVE_SHIP_SKILL="${REPO_ROOT}/plugins/sdd-ship/skills/ship/SKILL.md"
# tasks.md T-003 Planned Files declares this fixture tree ("a Project Context
# declaring components, a Registry with a matched ineligible Capability, the
# assembled trigger-fragment fixture this signal source produces, and a
# companion fixture confirming the existing ship-time recheck still
# independently Blocks..."). It was declared but never created, and both twins
# built their fixtures inline via heredoc instead, which is also why two
# cross-model slots reported the inputs behind these assertions could not be
# read (T-003 Anthropic slot, Minor). Reading BOTH twins from one file is
# additionally what stops them modelling the Registry differently -- a
# divergence a previous round had to repair by hand.
FIXTURE_CATALOG="${REPO_ROOT}/tests/fixtures/epic-194-lite-spec/scenarios.json"
PASS=0
FAIL=0

ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# (a) Structural checks on the proposed SKILL.md content.
# ---------------------------------------------------------------------------
echo "=== TEST-019-static: proposed SKILL.md names every required element ==="

assert_contains() {
  local label="$1" needle="$2"
  if grep -qF -- "$needle" "$SKILL_PROPOSED"; then
    ok "${label}"
  else
    fail "${label}: expected to find [${needle}] in proposed SKILL.md"
  fi
}

# Whitespace-flattened view of the same file, so a needle that spans a hard
# line wrap in the Markdown source can still be asserted verbatim. Built once;
# `grep -qF` is line-oriented, which is why the raw file cannot serve here.
SKILL_FLAT="$(tr '\n' ' ' < "$SKILL_PROPOSED" | tr -s ' ')"

assert_flat_contains() {
  local label="$1" needle="$2"
  case "$SKILL_FLAT" in
    *"$needle"*) ok "${label}" ;;
    *) fail "${label}: expected to find [${needle}] in the line-flattened proposed SKILL.md" ;;
  esac
}

assert_contains "TEST-019-static-a: names evaluate-predicate as the signal source" "evaluate-predicate"
assert_contains "TEST-019-static-b: names the Project-Context-declared component match" "Project Context already declares"
assert_contains "TEST-019-static-c: names the trigger-fragment eligible/upgrade_reasons shape" '"eligible": false'
assert_contains "TEST-019-static-d: the checker call site gains the new second argument" "--capability-reasons <fragment-path>"
assert_contains "TEST-019-static-e: the .ps1 call site gains its own new parameter" "-CapabilityReasons <fragment-path>"
assert_contains "TEST-019-static-f: disabled-legacy (no Project Context) skip clause present" "skip this step entirely"
# AC-019 names non-overridability as "`--lite` never overrides". The needle
# used here previously was the fragment "regardless of whether the", which
# names neither `--lite` nor any override and would stay green if the whole
# non-override sentence were deleted and that fragment survived anywhere else
# in the file (T-003 Anthropic-panelist review, Major). The needle is now the
# clause AC-019 itself quotes, and the "regardless of ..." half -- the part
# that makes it apply to the Capability-derived signal as well as the keyword
# scan -- is asserted separately as static-g2.
assert_contains "TEST-019-static-g: non-overridable -- the '--lite never overrides' clause is present verbatim (AC-019)" '`--lite` never overrides this decision'
assert_flat_contains "TEST-019-static-g2: that non-override applies to the Capability-derived signal too, not only the keyword scan" "regardless of whether the match came from the keyword scan or from this Capability-derived signal"
assert_contains "TEST-019-static-h: the dedicated fragment-invalid exit-2 diagnostic is documented" "capability-reasons fragment invalid"
assert_contains "TEST-019-static-i: ship-time recheck stays layered, not replaced" "layered with, not a substitute for"
assert_contains "TEST-019-static-j: Boundaries still disclaim reimplementing Predicate-DSL/Registry-matching" "Predicate-DSL/Registry-matching"

# AC-019's second named property: the Block happens "before any
# `specs/<feature>/` file exists". Nothing asserted this (T-003
# Anthropic-panelist review, Major). SKILL.md is agent-facing prose, so the
# property is structural: the Risk-Upgrade Gate section must (a) say so, and
# (b) actually precede the Process step that generates the three
# `specs/<feature>/` files. An ordering check, not a substring presence check
# -- moving the gate after file generation would keep every substring intact
# while destroying the property.
assert_contains "TEST-019-static-p: the gate states it runs before any specs/<feature>/ file is created (AC-019)" 'Before beginning the Process or creating any file under `specs/<feature>/`'
# -x (whole-line), not a prefix match: `grep -n '^## Risk-Upgrade Gate'` also
# matches a renamed heading such as "## Risk-Upgrade Gate (moved)", which is
# exactly the mutation this assertion has to catch. The .ps1 twin uses -eq for
# the same reason.
GATE_LINE="$(grep -nxF '## Risk-Upgrade Gate' "$SKILL_PROPOSED" | head -1 | cut -d: -f1)"
GENERATE_LINE="$(grep -n '次の3ファイルを `specs/<feature>/` に生成' "$SKILL_PROPOSED" | head -1 | cut -d: -f1)"
if [ -n "${GATE_LINE}" ] && [ -n "${GENERATE_LINE}" ] && [ "${GATE_LINE}" -lt "${GENERATE_LINE}" ]; then
  ok "TEST-019-static-q: the Risk-Upgrade Gate section (line ${GATE_LINE}) precedes the specs/<feature>/ generation step (line ${GENERATE_LINE})"
else
  fail "TEST-019-static-q: expected the Risk-Upgrade Gate to precede specs/<feature>/ generation; gate=[${GATE_LINE}] generate=[${GENERATE_LINE}]"
fi

# ---------------------------------------------------------------------------
# (a2) "Attempted and failed" producer-side rule (panelist Critical finding,
# cross-model verdict T-003.panelist-anthropic.verdict.json): a Project
# Context that exists but whose Capability evaluation cannot be completed
# must Block, not silently fall through to the one-argument, keyword-only
# call -- the only legitimate degrade is the second argument's own total
# absence (disabled-legacy). Each failure mode this rule names, plus the
# required outcome, gets its own assertion.
# ---------------------------------------------------------------------------
assert_contains "TEST-019-static-k: names evaluate-predicate absence/non-zero exit as a producer failure mode" "absent or exits non-zero"
assert_contains "TEST-019-static-l: names an unreadable/unparseable Registry as a producer failure mode" "Registry is unreadable or fails to parse"
assert_contains "TEST-019-static-m: names a temp-fragment write failure as a producer failure mode" "writing the temp fragment fails"
assert_contains "TEST-019-static-n: the required outcome is an immediate Block, before the checker ever runs" "Block immediately, before"
assert_contains "TEST-019-static-o: an attempted-and-failed signal is never treated as one never attempted" "never a silent degrade"

# ---------------------------------------------------------------------------
# (b) Functional: assemble a synthetic trigger fragment the way the new
# Step 2 documents (a matched, ineligible Capability, from a synthetic
# Registry + Project Context -- NOT a real evaluate-predicate call, which
# does not exist in this repository yet), then confirm check-risk-upgrade
# Blocks on it, same shape as an existing keyword-match fixture.
# ---------------------------------------------------------------------------
echo "=== TEST-019-functional: assembled Capability-derived fragment Blocks ==="

HAVE_CATALOG=0
if [ ! -f "${FIXTURE_CATALOG}" ]; then
  fail "TEST-019-fixture-catalog: declared fixture tree is missing at ${FIXTURE_CATALOG}"
else
  HAVE_CATALOG=1
  ok "TEST-019-fixture-catalog: the tasks.md-declared fixture tree exists and is read by both twins"
fi

# Union-match simulation (standing in for a real evaluate-predicate call,
# which this feature does not reimplement, Non-goals): a component-name
# equality match, assembled into REQ-002's own trigger-fragment shape.
#
# python3 is probed rather than assumed (T-003 Anthropic-panelist review,
# Minor). Under `set -euo pipefail` an unguarded `python3` on a runner without
# it aborted the whole suite mid-run -- no FAIL line, no trailing "Results:"
# summary, so the tally silently vanished, at odds with the tasks.md
# CI-resilience constraint. The assembler is now selected up front; if neither
# python3 nor a fallback exists, the fragment-dependent assertions print a
# visible `skip -` line and the suite still reaches its own summary.
HAVE_PY3=0
if command -v python3 >/dev/null 2>&1; then HAVE_PY3=1; fi
# Fixture-dependent assertions need BOTH python3 and the catalog.
HAVE_FIXTURES=0
if [ "${HAVE_PY3}" -eq 1 ] && [ "${HAVE_CATALOG}" -eq 1 ]; then HAVE_FIXTURES=1; fi

if [ "${HAVE_FIXTURES}" -eq 1 ]; then
python3 - "${FIXTURE_CATALOG}" "${WORK}" <<'PY'
import json
import sys
from pathlib import Path

catalog = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
work = Path(sys.argv[2])

project_context = catalog["project_context"]
registry = catalog["registry"]

# Materialize the catalog's own Project Context and Registry so the shape
# assertions below read the same bytes the union match consumed.
(work / "project-context.json").write_text(json.dumps(project_context), encoding="utf-8")
(work / "registry.json").write_text(json.dumps(registry, indent=2), encoding="utf-8")
# NOTE: the source bodies are written by the shell below, not here -- the
# keyword-match baseline must still run on a host without python3.

declared = set(project_context["components"])
matched_ineligible = []
for capability in registry["capabilities"]:
    if capability["component"] in declared and capability["lite_policy"]["eligible"] is False:
        matched_ineligible.append({
            "id": capability["id"],
            "eligible": False,
            "upgrade_reasons": capability["lite_policy"].get("upgrade_reasons", []),
        })

(work / "fragment.json").write_text(
    json.dumps({"capabilities": matched_ineligible}), encoding="utf-8"
)

# Shape verdict, computed structurally rather than by grepping serialized
# JSON: the previous grep form was pinned to one exact serialization and
# would silently stop matching the moment the fixture was reformatted.
entry = registry["capabilities"][0]
nested = int("lite_policy" in entry and "eligible" in entry.get("lite_policy", {}))
flat = int("eligible" in entry or "upgrade_reasons" in entry)
(work / "shape-verdict.txt").write_text(
    f"{nested} {flat} {len(matched_ineligible)}\n", encoding="utf-8"
)

# Companion (defense-in-depth) fragment: the eligible:true entry the
# documented assembly rule excludes, so intake does NOT flag the component.
(work / "di-fragment.json").write_text(
    json.dumps(catalog["defense_in_depth"]["fragment"]), encoding="utf-8"
)
PY
fi

# The union match above must read eligibility through design.md's own Data
# Plan shape (nested under `lite_policy`), and the .ps1 twin must do the same
# -- its fixture used to flatten eligible/upgrade_reasons onto the capability
# object, so the two halves were not exercising the same Registry shape (T-003
# Anthropic-panelist review, Minor). Asserted on both sides so the pair stays
# a real runtime-equivalence check.
# Assert the SHAPE of the Registry fixture, not merely that the match found
# something: a flattened fixture would still yield exactly one match, so a
# count-only assertion would not detect the divergence it exists to catch.
if [ "${HAVE_FIXTURES}" -eq 1 ]; then
  read -r REG_NESTED REG_FLAT MATCHED_COUNT < "${WORK}/shape-verdict.txt"
  if [ "${REG_NESTED}" = "1" ] && [ "${REG_FLAT}" = "0" ] && [ "${MATCHED_COUNT}" = "1" ]; then
    ok "TEST-019-functional-registry-shape: the Registry fixture nests eligibility under lite_policy and exposes no flattened eligible/upgrade_reasons (design.md Data Plan; parity with the .ps1 twin's fixture)"
  else
    fail "TEST-019-functional-registry-shape: Registry fixture shape diverges from design.md's Data Plan and from the .ps1 twin. nested=${REG_NESTED} flat=${REG_FLAT} matched=${MATCHED_COUNT}"
  fi
else
  echo "skip - TEST-019-functional-registry-shape: no fixture catalog: cannot assemble the synthetic trigger fragment"
fi

# Source bodies come from the catalog too, via a python3-free extraction so
# the keyword-match baseline still runs on a host without python3.
extract_source() {
  [ "${HAVE_CATALOG}" -eq 1 ] || { printf ''; return 0; }
  sed -n "s/.*\"$1\": \"\\(.*\\)\",*$/\\1/p" "${FIXTURE_CATALOG}" | head -1
}
printf '%s\n' "$(extract_source clean)" > "${WORK}/source.txt"

# AC-019 requires the Capability-derived Block to carry "the identical exit
# code (10), message shape (full-required: ...) and non-overridability ... as
# an existing keyword-match fixture". The previous assertions hard-coded 10
# and the 'full-required:' prefix, so the labels claimed a comparison the
# suite never performed (T-003 Anthropic-panelist review, Major). The
# keyword-match fixture is now actually RUN, and its observed exit code and
# message prefix are what the Capability-derived run is compared against --
# if the keyword arm's own contract ever moved, this comparison moves with it
# instead of silently diverging from the constant it used to assert.
# Guarded on the catalog, not just on python3: without it extract_source
# yields an EMPTY body, and an empty body legitimately produces
# `lite-eligible`. Running anyway would fail with "the keyword-match
# reference fixture did not Block", blaming the checker for a missing
# fixture -- a misleading failure, and a degraded-path divergence from the
# .ps1 twin, which skips this correctly.
if [ "${HAVE_CATALOG}" -eq 1 ]; then
printf '%s\n' "$(extract_source keyword_match)" > "${WORK}/keyword-source.txt"
KW_OUT=""
KW_EXIT=0
KW_OUT="$(bash "$CHECK_RISK_UPGRADE" "${WORK}/keyword-source.txt" 2>&1)" || KW_EXIT=$?
KW_PREFIX="${KW_OUT%%:*}"
if [ "${KW_EXIT}" -ne 0 ] && [ "${KW_PREFIX}" = "full-required" ]; then
  ok "TEST-019-functional-baseline: the keyword-match reference fixture Blocks (exit ${KW_EXIT}, '${KW_PREFIX}: ...') -- the comparison target AC-019 names actually exists"
else
  fail "TEST-019-functional-baseline: the keyword-match reference fixture did not Block; exit=${KW_EXIT} output=${KW_OUT}. Every parity assertion below is meaningless without it."
fi
else
  echo "skip - TEST-019-functional-baseline: no fixture catalog: cannot assemble the synthetic trigger fragment"
fi

if [ "${HAVE_FIXTURES}" -eq 1 ]; then
OUT=""
EXIT=0
OUT="$(bash "$CHECK_RISK_UPGRADE" "${WORK}/source.txt" --capability-reasons "${WORK}/fragment.json" 2>&1)" || EXIT=$?

if [ "${EXIT}" -eq "${KW_EXIT}" ] && [ "${EXIT}" -eq 10 ]; then
  ok "TEST-019-functional-a: Blocks with the IDENTICAL exit code the keyword-match fixture just produced (${EXIT})"
else
  fail "TEST-019-functional-a: expected the keyword fixture's own exit ${KW_EXIT} (and 10), got ${EXIT}. Output: ${OUT}"
fi
if [ "${OUT%%:*}" = "${KW_PREFIX}" ]; then
  ok "TEST-019-functional-b: message shape is the IDENTICAL '${KW_PREFIX}: ...' shape the keyword-match fixture just produced"
else
  fail "TEST-019-functional-b: expected the keyword fixture's own '${KW_PREFIX}:' prefix, got: ${OUT}"
fi
if [[ "${OUT}" == *"financial_settlement"* ]]; then
  ok "TEST-019-functional-c: the matched Capability's own upgrade_reasons token is present in the Block message"
else
  fail "TEST-019-functional-c: expected 'financial_settlement' in output: ${OUT}"
fi
else
  echo "skip - TEST-019-functional-a: no fixture catalog: cannot assemble the synthetic trigger fragment"
  echo "skip - TEST-019-functional-b: no fixture catalog: cannot assemble the synthetic trigger fragment"
  echo "skip - TEST-019-functional-c: no fixture catalog: cannot assemble the synthetic trigger fragment"
fi

# ---------------------------------------------------------------------------
# Companion fixture (defense-in-depth, design.md Test Strategy item 6,
# panelist Major finding): the OLD version of this companion only grepped
# ship/SKILL.md for the string "check-risk-upgrade" -- true whether or not
# T-003 ever existed, so it discriminated nothing. This version *executes*
# both independent gate positions for a component the intake-time
# Capability-derived evaluation did NOT flag, and separately proves the
# fixture is actually coupled to the proposed SKILL.md text (not a
# tautology) by requiring its own precondition to hold.
# ---------------------------------------------------------------------------
echo "=== TEST-019-defense-in-depth: ship-time recheck independently Blocks a component intake's Capability-derived evaluation did not flag ==="

if grep -qF -- '--capability-reasons <fragment-path>' "${SKILL_PROPOSED}"; then
  ok "TEST-019-defense-in-depth-a: proposed SKILL.md documents the intake-time --capability-reasons contract this fixture drives"
else
  fail "TEST-019-defense-in-depth-a: proposed SKILL.md no longer documents --capability-reasons; the property below cannot be exercised"
fi

# Component "payment-service": its matched Capability is eligible:true, so
# per the documented assembly rule ("Assemble every matched Capability whose
# own lite_policy.eligible is false") it is excluded from the fragment
# entirely -- the intake-time Capability-derived evaluation does not flag it.

printf '%s\n' "$(extract_source clean)" > "${WORK}/di-intake-source.txt"

if [ "${HAVE_FIXTURES}" -eq 1 ]; then
DI_INTAKE_OUT=""
DI_INTAKE_EXIT=0
DI_INTAKE_OUT="$(bash "$CHECK_RISK_UPGRADE" "${WORK}/di-intake-source.txt" --capability-reasons "${WORK}/di-fragment.json" 2>&1)" || DI_INTAKE_EXIT=$?
if [ "${DI_INTAKE_EXIT}" -eq 0 ]; then
  ok "TEST-019-defense-in-depth-b: intake-time evaluation does not flag the eligible:true component (exit 0, lite-eligible)"
else
  fail "TEST-019-defense-in-depth-b: expected intake to pass with exit 0, got ${DI_INTAKE_EXIT}. Output: ${DI_INTAKE_OUT}"
fi
else
  echo "skip - TEST-019-defense-in-depth-b: no fixture catalog: cannot materialize the companion fragment"
fi

# Ship-time recheck: independent invocation, single argument only -- exactly
# ship/SKILL.md's own unmodified command (still just check-risk-upgrade with
# no --capability-reasons at all, per its own live text) -- against a
# task-block+requirements body that DOES carry an unrelated keyword trigger
# for the same component.
# Catalog-guarded for the same reason as the keyword baseline above: an empty
# source body legitimately yields `lite-eligible`, so running it without the
# catalog would blame the checker for a missing fixture.
if [ "${HAVE_CATALOG}" -eq 1 ]; then
printf '%s\n' "$(extract_source defense_in_depth_ship)" > "${WORK}/di-ship-source.txt"
DI_SHIP_OUT=""
DI_SHIP_EXIT=0
DI_SHIP_OUT="$(bash "$CHECK_RISK_UPGRADE" "${WORK}/di-ship-source.txt" 2>&1)" || DI_SHIP_EXIT=$?
if [ "${DI_SHIP_EXIT}" -eq 10 ]; then
  ok "TEST-019-defense-in-depth-c: ship-time recheck independently Blocks (exit 10) even though intake's Capability-derived evaluation did not flag this component"
else
  fail "TEST-019-defense-in-depth-c: expected ship-time recheck to Block with exit 10, got ${DI_SHIP_EXIT}. Output: ${DI_SHIP_OUT}"
fi
else
  echo "skip - TEST-019-defense-in-depth-c: no fixture catalog: cannot materialize the companion fragment"
fi

if [ -f "${LIVE_SHIP_SKILL}" ]; then
  if grep -q "check-risk-upgrade" "${LIVE_SHIP_SKILL}"; then
    ok "TEST-019-defense-in-depth-d: ship/SKILL.md still independently invokes check-risk-upgrade at ship time"
  else
    fail "TEST-019-defense-in-depth-d: ship/SKILL.md no longer mentions check-risk-upgrade -- the independent second stage may have been lost"
  fi
else
  fail "TEST-019-defense-in-depth-d: ship/SKILL.md not found at expected path"
fi

# ---------------------------------------------------------------------------
# TEST-021 (AC-021): single-file, human-copy-only lock.
#
# AC-021 reads: "the designed REQ-005 edit touches only `lite-spec/SKILL.md`,
# staged under the same `specs/epic-194-a6-lite-integration/human-copy/`
# directory TEST-010 verifies, with no separate, REQ-005-specific application
# path introduced". It had NO automated assertion in this task's own suite --
# the only support was the implementation report's own self-assertion, which
# is precisely the implementer claim a blind review cannot credit (T-003
# Anthropic slot, Major). T-001's suite covers the RUNNER contract; these
# three assertions cover T-003's own staged contribution to it.
# ---------------------------------------------------------------------------
echo "=== TEST-021 (AC-021): single-file, human-copy-only lock ==="
HC_ROOT="${REPO_ROOT}/specs/epic-194-a6-lite-integration/human-copy"
SOLE_TARGET='plugins/sdd-lite/skills/lite-spec/SKILL.md'

# (i) The REQ-005 edit touches exactly one staged file: lite-spec/SKILL.md.
# Counted from the staged tree itself, not from a declaration -- a second
# REQ-005 file appearing under skills/ is what this has to catch.
SKILLS_STAGED="$(find "${HC_ROOT}/plugins/sdd-lite/skills" -type f 2>/dev/null | wc -l | tr -d ' ')"
if [ "${SKILLS_STAGED}" = "1" ] && [ -f "${HC_ROOT}/${SOLE_TARGET}" ]; then
  ok "TEST-021a: REQ-005 stages exactly one file under sdd-lite/skills/, and it is ${SOLE_TARGET}"
else
  fail "TEST-021a: expected exactly 1 staged file under sdd-lite/skills/ (${SOLE_TARGET}), found ${SKILLS_STAGED}"
fi

# (ii) It is staged under the same human-copy/ directory TEST-010 verifies,
# with exactly one MANIFEST.sha256 entry, and that entry's digest is correct.
MANIFEST_HITS="$(grep -c "  ${SOLE_TARGET}\$" "${HC_ROOT}/MANIFEST.sha256" 2>/dev/null || true)"
MANIFEST_DIGEST="$(grep "  ${SOLE_TARGET}\$" "${HC_ROOT}/MANIFEST.sha256" 2>/dev/null | awk '{print $1}')"
ACTUAL_DIGEST="$(shasum -a 256 "${HC_ROOT}/${SOLE_TARGET}" 2>/dev/null | awk '{print $1}')"
if [ "${MANIFEST_HITS}" = "1" ] && [ -n "${ACTUAL_DIGEST}" ] && [ "${MANIFEST_DIGEST}" = "${ACTUAL_DIGEST}" ]; then
  ok "TEST-021b: exactly one MANIFEST.sha256 entry names ${SOLE_TARGET}, and its digest matches the staged bytes"
else
  fail "TEST-021b: expected exactly 1 manifest entry with a matching digest for ${SOLE_TARGET}; entries=${MANIFEST_HITS} manifest=${MANIFEST_DIGEST} actual=${ACTUAL_DIGEST}"
fi

# (iii) No separate, REQ-005-specific application path was introduced: the
# only application script staged in this batch is the shared runner T-001
# owns. A REQ-005-specific applier appearing beside it is the failure.
APPLIERS="$(find "${HC_ROOT}" -maxdepth 1 -type f \( -name '*.ps1' -o -name '*.sh' \) 2>/dev/null | sed "s|^${HC_ROOT}/||" | sort | tr '\n' ' ')"
if [ "${APPLIERS}" = "apply-protected-files.ps1 " ]; then
  ok "TEST-021c: the only application path staged is the shared apply-protected-files.ps1 -- no REQ-005-specific applier was introduced"
else
  fail "TEST-021c: expected the shared runner to be the only staged application script, found: [${APPLIERS}]"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
  exit 1
fi
exit 0
